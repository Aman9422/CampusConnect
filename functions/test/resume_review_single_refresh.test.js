"use strict";

/**
 * CampusConnect v9.2.4 — resume-review single-refresh tests (D-1).
 *
 * The v9.2.3 audit found that `onResumeReviewCreatedRefreshMatches` wrote the
 * resume counters back onto the PARENT `users/{uid}` document, which fired
 * `onProfileUpdatedRefreshAI`; that trigger saw a `portfolio` change and ran a
 * SECOND, concurrent recommendation refresh with a DIFFERENT fingerprint (no
 * `options.resumeData`). Net effect per resume review: two full engine runs,
 * two AI enrichments, a stored fingerprint that thrashed between two variants,
 * and 3 extra `profileUpdated` engagement points.
 *
 * These tests drive the REAL trigger handler and prove:
 *   - the metadata-only merge the resume trigger performs is IGNORED by the
 *     profile trigger (no second refresh, no engagement points);
 *   - a genuine portfolio/profile change still triggers exactly one refresh;
 *   - the fingerprint CONVERGES: the resume-review path (persisted signals read
 *     back from the document) and every other caller (no options passthrough)
 *     hash the same document state to the SAME value.
 *
 * Run:  node --test test/resume_review_single_refresh.test.js
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared admin shim BEFORE requiring any production module.
const {Timestamp, seedDb} = require("./setup");

// Stub the v2 Firestore trigger registration so each handler is directly
// callable with a hand-built event.
const firestoreFnPath = require.resolve("firebase-functions/v2/firestore");
require.cache[firestoreFnPath] = {
  id: firestoreFnPath,
  filename: firestoreFnPath,
  loaded: true,
  exports: {
    onDocumentWritten: (_options, handler) => handler,
    onDocumentCreated: (_options, handler) => handler,
  },
};

// Patch the refresh orchestrator BEFORE requiring the trigger module, so the
// trigger's destructured binding is the spy. The real fingerprint function is
// left untouched and used for the convergence tests.
const refresh = require("../recommendations/refresh");
const refreshCalls = [];
refresh.refreshRecommendationsForStudent =
    async (userId, userData, options, refreshOptions) => {
      refreshCalls.push({userId, userData, options, refreshOptions});
      return {skipped: false, fingerprint: "spy"};
    };

const {isResumeReviewMetadataOnlyChange} = require("../helpers/shared");
const triggers = require("../triggers");

// ── Fixtures ─────────────────────────────────────────────────────────────

const STUDENT_ID = "student_1";

/** A student document that is eligible for the profile trigger's work. */
function studentDoc({reviewCount, latestATSScore, latestMissingKeywords, skills}) {
  return {
    role: "student",
    profileCompleted: true,
    updatedAt: Timestamp.fromMillis(1_700_000_000_000),
    skills: skills || [],
    portfolio: {
      metadata: {updatedAt: Timestamp.fromMillis(1_700_000_000_000)},
      skills: ["Dart"],
      resume: {
        fileName: "resume.pdf",
        storagePath: "resumes/student_1/latest.pdf",
        hasResume: true,
        reviewCount,
        latestATSScore,
        latestMissingKeywords,
      },
    },
  };
}

function snapshot(data) {
  return {exists: data !== null, data: () => data};
}

/** Fire the real profile trigger with a before/after pair. */
async function fireProfileTrigger(before, after) {
  await triggers.onProfileUpdatedRefreshAI({
    params: {userId: STUDENT_ID},
    data: {before: snapshot(before), after: snapshot(after)},
  });
}

/** The resume-review counter merge `onResumeReviewCreatedRefreshMatches` writes. */
function resumeReviewMergeDoc(base, {reviewCount, atsScore, keywords}) {
  return {
    ...base,
    portfolio: {
      ...base.portfolio,
      resume: {
        ...base.portfolio.resume,
        reviewCount,
        lastReviewAt: Timestamp.fromMillis(1_800_000_000_000),
        updatedAt: Timestamp.fromMillis(1_800_000_000_000),
        latestATSScore: atsScore,
        latestMissingKeywords: keywords,
      },
    },
  };
}

function resetSpy() {
  refreshCalls.length = 0;
}

// ── The guard (pure) ─────────────────────────────────────────────────────

test("isResumeReviewMetadataOnlyChange: recognises the resume-review counter merge", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = resumeReviewMergeDoc(before, {
    reviewCount: 2,
    atsScore: 72,
    keywords: ["Docker"],
  });

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), true);
});

test("isResumeReviewMetadataOnlyChange: a genuine portfolio edit is NOT metadata-only", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = resumeReviewMergeDoc(before, {
    reviewCount: 2,
    atsScore: 72,
    keywords: ["Docker"],
  });
  // A real portfolio change alongside the counter merge.
  after.portfolio.skills = ["Dart", "Flutter"];

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), false);
});

test("isResumeReviewMetadataOnlyChange: a resume FILE change is NOT metadata-only", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = resumeReviewMergeDoc(before, {
    reviewCount: 2,
    atsScore: 72,
    keywords: ["Docker"],
  });
  after.portfolio.resume.fileName = "new-resume.pdf";

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), false);
});

test("isResumeReviewMetadataOnlyChange: a root-level change is NOT metadata-only", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = resumeReviewMergeDoc(before, {
    reviewCount: 2,
    atsScore: 72,
    keywords: ["Docker"],
  });
  after.skills = ["Kotlin"];

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), false);
});

test("isResumeReviewMetadataOnlyChange: a non-portfolio-only write is NOT metadata-only", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  after.department = "Computer Engineering"; // portfolio identical

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), false);
});

test("isResumeReviewMetadataOnlyChange: an unchanged document is NOT a metadata change", () => {
  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});

  assert.equal(isResumeReviewMetadataOnlyChange(before, after), false);
});

// ── The trigger ──────────────────────────────────────────────────────────

test("onProfileUpdatedRefreshAI: the resume-review counter merge triggers NO second refresh", async () => {
  const db = seedDb({});
  resetSpy();

  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = resumeReviewMergeDoc(before, {
    reviewCount: 2,
    atsScore: 72,
    keywords: ["Docker"],
  });

  await fireProfileTrigger(before, after);

  assert.equal(refreshCalls.length, 0,
      "the resume review must result in exactly ONE effective refresh (the " +
      "one the resume-review trigger already performed)");

  // E-2 of the brief: no engagement points for the metadata write.
  const activities = (db.__store[`users/${STUDENT_ID}/activities`]) || {};
  assert.equal(Object.keys(activities).length, 0,
      "no profileUpdated engagement points are awarded by the metadata write");
});

test("onProfileUpdatedRefreshAI: a genuine portfolio content change still refreshes once", async () => {
  seedDb({});
  resetSpy();

  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  after.portfolio.skills = ["Dart", "Flutter"];

  await fireProfileTrigger(before, after);

  assert.equal(refreshCalls.length, 1,
      "a legitimate portfolio change must still trigger recommendations");
});

test("onProfileUpdatedRefreshAI: a root-level skills change still refreshes once", async () => {
  seedDb({});
  resetSpy();

  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  after.skills = ["Kotlin"];

  await fireProfileTrigger(before, after);

  assert.equal(refreshCalls.length, 1);
});

test("onProfileUpdatedRefreshAI: an incomplete profile is ignored", async () => {
  seedDb({});
  resetSpy();

  const before = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  const after = studentDoc({reviewCount: 1, latestATSScore: 60, latestMissingKeywords: []});
  after.skills = ["Kotlin"];
  after.profileCompleted = false;

  await fireProfileTrigger(before, after);

  assert.equal(refreshCalls.length, 0,
      "recommendations are not built for an incomplete profile");
});

// ── Fingerprint convergence ──────────────────────────────────────────────

test("fingerprint: the persisted resume signal converges every caller to one value", () => {
  const userData = studentDoc({
    reviewCount: 2,
    latestATSScore: 72,
    latestMissingKeywords: ["Docker", "Kubernetes"],
  });

  // The resume-review trigger refreshes WITHOUT an options passthrough, and so
  // do the client bootstrap and the profile trigger.
  const noOptions = refresh.computeRecommendationFingerprint({userData});
  const emptyOptions = refresh.computeRecommendationFingerprint({userData, options: {}});

  // A legacy caller that still passes the review payload must agree, because
  // the values are the same ones persisted on the document.
  const withPassthrough = refresh.computeRecommendationFingerprint({
    userData,
    options: {resumeData: {atsScore: 72, missingKeywords: ["Docker", "Kubernetes"]}},
  });

  assert.equal(noOptions, emptyOptions, "the ignored options argument changes nothing");
  assert.equal(noOptions, withPassthrough,
      "the resume-review and non-resume-review paths must hash the same state " +
      "to the SAME fingerprint (no thrash)");
});

test("fingerprint: a new resume review still moves the fingerprint", () => {
  const before = studentDoc({
    reviewCount: 1,
    latestATSScore: 60,
    latestMissingKeywords: ["Docker"],
  });
  const after = studentDoc({
    reviewCount: 2,
    latestATSScore: 72,
    latestMissingKeywords: ["Docker", "Kubernetes"],
  });

  assert.notEqual(
      refresh.computeRecommendationFingerprint({userData: before}),
      refresh.computeRecommendationFingerprint({userData: after}),
      "a genuinely changed resume signal must invalidate the fingerprint so " +
      "the recommendations regenerate");
});

test("fingerprint: a portfolio.metadata-only flutter does NOT move it", () => {
  const base = studentDoc({
    reviewCount: 1,
    latestATSScore: 60,
    latestMissingKeywords: ["Docker"],
  });
  const fluttered = {
    ...base,
    portfolio: {
      ...base.portfolio,
      metadata: {updatedAt: Timestamp.fromMillis(1_900_000_000_000)},
    },
  };

  assert.equal(
      refresh.computeRecommendationFingerprint({userData: base}),
      refresh.computeRecommendationFingerprint({userData: fluttered}));
});
