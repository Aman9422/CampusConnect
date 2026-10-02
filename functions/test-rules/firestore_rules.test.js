"use strict";

/**
 * CampusConnect v9.2.4 — Firestore security-rule EXECUTION tests.
 *
 * This is the behavioural counterpart to
 * `functions/test/security_rules_contract.test.js`. That suite asserts the rule
 * TEXT (it fails if a guard is deleted or weakened); this suite actually RUNS
 * `firestore.rules` in the Firestore emulator and asserts the allow/deny outcome
 * of real client reads and writes. A guard that is present but semantically
 * wrong passes the contract suite and fails here.
 *
 * Covered findings (v9.2.3 audit):
 *   SEC-1 — a client must never be able to change its own `role`.
 *   SEC-2 — `write: false` subcollections must truly deny the owner, and
 *           `ai_interactions` must stay append-only.
 *   D-9   — only alumni may create/update/delete `opportunities`.
 *   D-10  — `isValidOpportunityData()` rejects malformed opportunity writes.
 *   D-11  — `profileCompleted` only via a genuine validated transition;
 *           `isVerified` and `role` are client-immutable.
 *
 * Run (repository root; the emulator must be available — Java required):
 *   firebase emulators:exec --only firestore --project campusconnect-firebase-project ^
 *       "node --test functions/test-rules/firestore_rules.test.js"
 * or:  npm --prefix functions run test:rules
 *
 * The plain `npm test` run deliberately does NOT include this file — it needs
 * the emulator, and the functions test glob is `test/**`, not `test-rules/**`.
 */

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
} = require("firebase/firestore");

const PROJECT_ID = "campusconnect-firebase-project";
const RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");

const ALUMNI_UID = "alumni-uid-0001";
const OTHER_ALUMNI_UID = "alumni-uid-0002";
const STUDENT_UID = "student-uid-0001";
const TEACHER_UID = "teacher-uid-0001";

/** A document that satisfies `isValidOpportunityData()` exactly. */
function validOpportunity(alumniId) {
  return {
    alumniId,
    title: "Backend Engineering Intern",
    company: "Acme Systems",
    description: "Build and operate internal services.",
    location: "Remote",
    jobType: "Internship",
    postedAt: Timestamp.fromDate(new Date()),
    isActive: true,
  };
}

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(RULES_PATH, "utf8") },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

/** Re-seed the users + one valid opportunity, bypassing rules. */
async function seed() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", ALUMNI_UID), { role: "alumni" });
    await setDoc(doc(db, "users", OTHER_ALUMNI_UID), { role: "alumni" });
    await setDoc(doc(db, "users", STUDENT_UID), { role: "student" });
    await setDoc(doc(db, "users", TEACHER_UID), { role: "teacher" });
    await setDoc(
        doc(db, "opportunities", "seed-opportunity"),
        validOpportunity(ALUMNI_UID),
    );
  });
}

test.beforeEach(seed);

/** A client SDK bound to `uid`. */
function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

// ── D-9: opportunity authorization ───────────────────────────────────────

test("D-9: an alumni may create a valid opportunity", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertSucceeds(
      setDoc(doc(db, "opportunities", "new-opp"), validOpportunity(ALUMNI_UID)),
  );
});

test("D-9: a student may NOT create an opportunity", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "opportunities", "student-opp"),
          validOpportunity(STUDENT_UID)),
  );
});

test("D-9: a teacher may NOT create an opportunity", async () => {
  const db = dbFor(TEACHER_UID);
  await assertFails(
      setDoc(doc(db, "opportunities", "teacher-opp"),
          validOpportunity(TEACHER_UID)),
  );
});

test("D-9: an unauthenticated client may NOT create an opportunity", async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(
      setDoc(doc(db, "opportunities", "anon-opp"),
          validOpportunity(ALUMNI_UID)),
  );
});

test("D-9: the owning alumni may update their opportunity", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertSucceeds(
      updateDoc(doc(db, "opportunities", "seed-opportunity"), { isActive: false }),
  );
});

test("D-9: another alumni may NOT update someone else's opportunity", async () => {
  const db = dbFor(OTHER_ALUMNI_UID);
  await assertFails(
      updateDoc(doc(db, "opportunities", "seed-opportunity"), { isActive: false }),
  );
});

test("D-9: the owning alumni may delete their opportunity", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertSucceeds(
      deleteDoc(doc(db, "opportunities", "seed-opportunity")),
  );
});

test("D-9: another alumni may NOT delete someone else's opportunity", async () => {
  const db = dbFor(OTHER_ALUMNI_UID);
  await assertFails(
      deleteDoc(doc(db, "opportunities", "seed-opportunity")),
  );
});

test("D-9: authenticated users may still READ opportunities", async () => {
  const db = dbFor(STUDENT_UID);
  await assertSucceeds(
      getDoc(doc(db, "opportunities", "seed-opportunity")),
  );
});
// ── D-10: opportunity schema validation ──────────────────────────────────

test("D-10: an alumni may NOT create an opportunity missing `description`", async () => {
  const db = dbFor(ALUMNI_UID);
  const malformed = validOpportunity(ALUMNI_UID);
  delete malformed.description;
  await assertFails(setDoc(doc(db, "opportunities", "bad-1"), malformed));
});

test("D-10: an alumni may NOT create an opportunity with an empty `title`", async () => {
  const db = dbFor(ALUMNI_UID);
  const malformed = {...validOpportunity(ALUMNI_UID), title: ""};
  await assertFails(setDoc(doc(db, "opportunities", "bad-2"), malformed));
});

test("D-10: an alumni may NOT create an opportunity with a wrong-typed `isActive`", async () => {
  const db = dbFor(ALUMNI_UID);
  const malformed = {...validOpportunity(ALUMNI_UID), isActive: "yes"};
  await assertFails(setDoc(doc(db, "opportunities", "bad-3"), malformed));
});

test("D-10: an alumni may NOT create an opportunity with a non-timestamp `postedAt`", async () => {
  const db = dbFor(ALUMNI_UID);
  const malformed = {...validOpportunity(ALUMNI_UID), postedAt: "2026-01-01"};
  await assertFails(setDoc(doc(db, "opportunities", "bad-4"), malformed));
});

test("D-10: an alumni may NOT author an opportunity under another user's alumniId", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertFails(
      setDoc(doc(db, "opportunities", "bad-5"),
          validOpportunity(OTHER_ALUMNI_UID)),
  );
});

test("D-10: an update that empties a required field is rejected", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertFails(
      updateDoc(doc(db, "opportunities", "seed-opportunity"), { company: "" }),
  );
});

test("D-10: a valid optional `applicationDeadline` timestamp is accepted", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertSucceeds(
      setDoc(doc(db, "opportunities", "good-deadline"), {
        ...validOpportunity(ALUMNI_UID),
        applicationDeadline: Timestamp.fromDate(new Date(Date.now() + 86400000)),
      }),
  );
});

// ── SEC-1 + D-11: the users document ─────────────────────────────────────

test("SEC-1: a student may NOT self-elevate their role to teacher", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID), { role: "teacher" }, { merge: true }),
  );
});

test("SEC-1: an alumni may NOT change their role to student", async () => {
  const db = dbFor(ALUMNI_UID);
  await assertFails(
      setDoc(doc(db, "users", ALUMNI_UID), { role: "student" }, { merge: true }),
  );
});

test("D-11: an owner may NOT assert profileCompleted without the profile sections", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID),
          { profileCompleted: true }, { merge: true }),
  );
});

test("D-11: the genuine completion transition (flag + required sections) is allowed", async () => {
  const db = dbFor(STUDENT_UID);
  await assertSucceeds(
      setDoc(doc(db, "users", STUDENT_UID), {
        profileCompleted: true,
        personal: { fullName: "Asha Rao" },
        academic: {
          college: "JD College of Engineering",
          program: "CSE",
          year: 4,
        },
      }, { merge: true }),
  );
});

test("D-11: an owner may NOT set isVerified", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID),
          { isVerified: true }, { merge: true }),
  );
});

test("D-11: an ordinary profile edit that preserves the flags is allowed", async () => {
  const db = dbFor(STUDENT_UID);
  await assertSucceeds(
      setDoc(doc(db, "users", STUDENT_UID),
          { phone: "+91 90000 00000" }, { merge: true }),
  );
});

test("D-11: a completion transition that ALSO changes role is denied", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID), {
        role: "alumni",
        profileCompleted: true,
        personal: { fullName: "Asha Rao" },
        academic: { college: "JD", program: "CSE", year: 4 },
      }, { merge: true }),
  );
});

test("D-11: a first-time write on a new account may persist its role", async () => {
  const freshUid = "fresh-uid-0001";
  const db = dbFor(freshUid);
  await assertSucceeds(
      setDoc(doc(db, "users", freshUid), { role: "student" }),
  );
});

// ── SEC-2: `write: false` subcollections must truly deny the owner ───────

test("SEC-2: the owner may NOT write recommendations_meta", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "recommendations_meta", "summary"),
          { fingerprint: "forged" }),
  );
});

test("SEC-2: the owner may NOT write engagement_summary", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "engagement_summary", "summary"),
          { engagementScore: 100 }),
  );
});

test("SEC-2: the owner may NOT write career_coach", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "career_coach", "summary"),
          { summary: "forged" }),
  );
});

test("SEC-2: the owner may NOT write ai_insights", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "ai_insights", "row"),
          { insight: "forged" }),
  );
});

test("SEC-2: the owner may NOT create activities", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "activities", "row"),
          { eventType: "resumeReviewed", points: 5 }),
  );
});

test("SEC-2: the owner may NOT create recommendations", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "recommendations", "row"),
          { score: 100, title: "Forged" }),
  );
});

test("SEC-2: the owner may NOT create resumeReviews", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "resumeReviews", "row"),
          { atsScore: 99 }),
  );
});

test("D-7: the owner MAY append to ai_interactions (single-writer client read path)", async () => {
  const db = dbFor(STUDENT_UID);
  await assertSucceeds(
      setDoc(doc(db, "users", STUDENT_UID, "ai_interactions", "turn-1"),
          { role: "user", message: "hi", timestamp: Timestamp.fromDate(new Date()) }),
  );
});

test("D-7: ai_interactions stays append-only (update denied)", async () => {
  const db = dbFor(STUDENT_UID);
  await assertSucceeds(
      setDoc(doc(db, "users", STUDENT_UID, "ai_interactions", "turn-2"),
          { role: "user", message: "hi", timestamp: Timestamp.fromDate(new Date()) }),
  );
  await assertFails(
      updateDoc(doc(db, "users", STUDENT_UID, "ai_interactions", "turn-2"),
          { message: "rewritten" }),
  );
});

test("the owner may NOT write an unknown subcollection under users/{uid}", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "users", STUDENT_UID, "some_future_collection", "row"),
          { anything: true }),
  );
});

// ── placements: unchanged authorization still holds ──────────────────────

test("placements: a student may NOT create a placement", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "placements", "p1"), {
        deadline: Timestamp.fromDate(new Date(Date.now() + 86400000)),
        postedAt: Timestamp.fromDate(new Date()),
        isActive: true,
        createdBy: STUDENT_UID,
        company: "Acme",
        role: "SWE",
        description: "Build things",
        eligibility: "CSE, year 4",
        salary: "10 LPA",
      }),
  );
});

test("placements: a teacher MAY create a valid placement", async () => {
  const db = dbFor(TEACHER_UID);
  await assertSucceeds(
      setDoc(doc(db, "placements", "p2"), {
        deadline: Timestamp.fromDate(new Date(Date.now() + 86400000)),
        postedAt: Timestamp.fromDate(new Date()),
        isActive: true,
        createdBy: TEACHER_UID,
        company: "Acme",
        role: "SWE",
        description: "Build things",
        eligibility: "CSE, year 4",
        salary: "10 LPA",
      }),
  );
});

test("placements: a client may NOT forge an application", async () => {
  const db = dbFor(STUDENT_UID);
  await assertFails(
      setDoc(doc(db, "placements", "p2", "applications", STUDENT_UID),
          { status: "placed" }),
  );
});
