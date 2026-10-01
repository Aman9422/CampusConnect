"use strict";

/**
 * v9.2.2 (§2) — server-side recommendation refresh de-duplication.
 *
 * The v9.2.2 runtime log showed `RecommendationService: server regenerated
 * recommendations` twice for one login of the same user. Two independent
 * defectors compounded: (a) the client issued the callable more than once, and
 * (b) `refreshRecommendationsForStudent` regenerated unconditionally — the
 * profile trigger (S1) and the client bootstrap callable (C1) fired in the same
 * window and each ran the engine + AI enrichment + a full document rewrite.
 *
 * The server fix stores a FINGERPRINT of everything the deterministic engine
 * reads on `recommendations_meta/summary` and SKIPS the work when the same
 * fingerprint is presented again (unless the caller forces it, the caller has
 * no materialized set, or an active recommendation has expired).
 *
 * `computeRecommendationFingerprint` is pure — this suite proves its
 * determinism and its coverage of the engine's inputs, plus the module's
 * export contract, without Firestore or an emulator.
 */

// Install the in-memory firebase-admin shim before requiring any production
// module that touches `admin.firestore()` / `admin.functions`.
require("./setup");

const test = require("node:test");
const assert = require("node:assert");

const refresh = require("../recommendations/refresh");
const {computeRecommendationFingerprint} = refresh;

/** A representative student document with real portfolio evidence. */
function studentData(overrides = {}) {
  return {
    role: "student",
    department: "CSE",
    graduationYear: 2026,
    skills: ["flutter", "dart", "firebase"],
    careerInterest: "App Development",
    career: {interests: ["App Development"], preferredRoles: []},
    academic: {college: "JDCOEM", program: "BE", year: 4, cgpa: 8.5},
    portfolio: {
      skills: ["flutter"],
      projects: [{id: "p1", title: "Campus App"}],
      metadata: {updatedAt: {seconds: 1, nanoseconds: 0}},
    },
    ...overrides,
  };
}

function fingerprintFor(userData, options = {}) {
  return computeRecommendationFingerprint({
    userData,
    options,
    candidateIds: ["a1", "o1", "p1"],
    appliedPlacementIds: new Set(["pl1"]),
  });
}

test("export contract: the orchestrator and fingerprint are exported", () => {
  assert.strictEqual(
      typeof refresh.refreshRecommendationsForStudent,
      "function",
      "refreshRecommendationsForStudent must be exported for triggers",
  );
  assert.strictEqual(
      typeof refresh.computeRecommendationFingerprint,
      "function",
      "computeRecommendationFingerprint must be exported for tests",
  );
  assert.strictEqual(
      typeof refresh.refreshRecommendations,
      "function",
      "refreshRecommendations must remain the client callable",
  );
});

test("determinism: identical inputs produce the identical fingerprint", () => {
  const a = fingerprintFor(studentData());
  const b = fingerprintFor(studentData());
  assert.strictEqual(a, b);
  // sha256 hex digest.
  assert.match(a, /^[0-9a-f]{64}$/);
});

test("determinism: object key ORDER does not change the fingerprint", () => {
  const a = fingerprintFor({
    skills: ["dart"],
    department: "CSE",
  });
  const b = fingerprintFor({
    department: "CSE",
    skills: ["dart"],
  });
  assert.strictEqual(a, b);
});

test("a portfolio.metadata-ONLY change does NOT change the fingerprint", () => {
  const base = studentData();
  const metadataFluttered = studentData({
    portfolio: {
      ...base.portfolio,
      metadata: {updatedAt: {seconds: 999, nanoseconds: 500}},
    },
  });
  assert.strictEqual(
      fingerprintFor(base),
      fingerprintFor(metadataFluttered),
      "a `portfolio.metadata.updatedAt` flutter must never invalidate the " +
      "fingerprint (mirrors isPortfolioMetadataOnlyChange)",
  );
});

test("a PORTFOLIO CONTENT change DOES change the fingerprint", () => {
  const base = studentData();
  const changed = studentData({
    portfolio: {
      ...base.portfolio,
      skills: ["flutter", "dart"],
    },
  });
  assert.notStrictEqual(fingerprintFor(base), fingerprintFor(changed));
});

test("a SKILLS change DOES change the fingerprint", () => {
  assert.notStrictEqual(
      fingerprintFor(studentData({skills: ["dart"]})),
      fingerprintFor(studentData({skills: ["dart", "firebase"]})),
  );
});

test("a DEPARTMENT / graduationYear / academic change DOES change it", () => {
  const base = studentData();
  assert.notStrictEqual(
      fingerprintFor(base),
      fingerprintFor(studentData({department: "IT"})),
  );
  assert.notStrictEqual(
      fingerprintFor(base),
      fingerprintFor(studentData({graduationYear: 2027})),
  );
  assert.notStrictEqual(
      fingerprintFor(base),
      fingerprintFor(studentData({
        academic: {college: "JDCOEM", program: "BE", year: 4, cgpa: 9.9},
      })),
  );
});

test("a resume-review input change DOES change the fingerprint", () => {
  const base = studentData();
  const withReview = {
    resumeData: {atsScore: 72, missingKeywords: ["docker"]},
  };
  const changedReview = {
    resumeData: {atsScore: 72, missingKeywords: ["docker", "kubernetes"]},
  };

  const without = fingerprintFor(base);
  const first = fingerprintFor(base, withReview);
  const second = fingerprintFor(base, changedReview);

  assert.notStrictEqual(without, first, "a review must alter the fingerprint");
  assert.notStrictEqual(first, second, "changed keywords must alter it");
});

test("applied placement ids: Set and Array agree, ORDER does not matter", () => {
  const userData = studentData();
  const fromSet = computeRecommendationFingerprint({
    userData,
    appliedPlacementIds: new Set(["pl2", "pl1"]),
  });
  const fromArray = computeRecommendationFingerprint({
    userData,
    appliedPlacementIds: ["pl1", "pl2"],
  });
  const reordered = computeRecommendationFingerprint({
    userData,
    appliedPlacementIds: ["pl2", "pl1"],
  });

  assert.strictEqual(fromSet, fromArray);
  assert.strictEqual(fromArray, reordered);
});

test("candidate ids: ORDER does not matter, but the SET does", () => {
  const userData = studentData();
  const a = computeRecommendationFingerprint({
    userData,
    candidateIds: ["o1", "a1"],
  });
  const b = computeRecommendationFingerprint({
    userData,
    candidateIds: ["a1", "o1"],
  });
  const different = computeRecommendationFingerprint({
    userData,
    candidateIds: ["a1", "o1", "new-opportunity"],
  });

  assert.strictEqual(a, b, "candidate order must not invalidate the cache");
  assert.notStrictEqual(a, different, "a new candidate must re-run the engine");
});

test("missing / empty inputs collapse to a stable fingerprint", () => {
  const bare = computeRecommendationFingerprint();
  assert.strictEqual(bare, computeRecommendationFingerprint({}));
  assert.strictEqual(bare, computeRecommendationFingerprint({userData: {}}));
  assert.match(bare, /^[0-9a-f]{64}$/);
  // An explicitly-empty options bag equals an absent one.
  assert.strictEqual(bare, computeRecommendationFingerprint({
    userData: {},
    options: {},
    candidateIds: [],
    appliedPlacementIds: [],
  }));
});

test("null vs absent resumeData are equivalent", () => {
  const userData = studentData();
  assert.strictEqual(
      computeRecommendationFingerprint({userData, options: {resumeData: null}}),
      computeRecommendationFingerprint({userData, options: {}}),
  );
});
