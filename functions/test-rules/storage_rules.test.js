"use strict";

/**
 * CampusConnect v9.2.4 — Storage security-rule EXECUTION tests.
 *
 * Companion to `firestore_rules.test.js`. This suite actually RUNS
 * `storage.rules` in the Storage emulator and asserts the allow/deny outcome of
 * real client uploads, reads and deletes. It is the behavioural counterpart to
 * the source-contract assertions in `security_rules_contract.test.js`, which can
 * only prove a guard is *present*, not that it is *correct*.
 *
 * Contracts asserted here (from `storage.rules`):
 *   - resumes/{uid}/{fileName}
 *       write: owner only, `application/pdf`, size <= 5 MB (null resource = delete)
 *       read : owner, or a Firestore user whose role is teacher / alumni
 *   - resumes/{uid}/snapshots/{fileName}   (v9.2 audit INT-1)
 *       read : same as above — so the immutable placement snapshot is reachable
 *              by path instead of only through the long-lived signed URL
 *       write: false — snapshots are write-once, Admin SDK only
 *   - everything else: deny-all
 *
 * The teacher/alumni branches call `firestore.get()` on `users/{uid}`, so the
 * Firestore emulator must be running too — hence `--only firestore,storage`.
 *
 * Run (repository root; the emulators need Java):
 *   firebase emulators:exec --only firestore,storage --project campusconnect-firebase-project ^
 *       "node --test functions/test-rules/storage_rules.test.js"
 * or:  npm --prefix functions run test:storage-rules
 * or:  npm --prefix functions run test:all-rules      (both rule sets, one emulator boot)
 *
 * The plain `npm test` run deliberately does NOT include this file — the
 * functions test glob is `test/**`, not `test-rules/**`.
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
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require("firebase/storage");

const { doc, setDoc } = require("firebase/firestore");

const PROJECT_ID = "campusconnect-firebase-project";
const STORAGE_RULES_PATH = path.join(__dirname, "..", "..", "storage.rules");
const FIRESTORE_RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");

const OWNER_UID = "student-owner-0001";
const OTHER_UID = "student-other-0001";
const TEACHER_UID = "teacher-uid-0001";
const ALUMNI_UID = "alumni-uid-0001";

const PDF = "application/pdf";
const NOT_PDF = "text/plain";
const FIVE_MB = 5 * 1024 * 1024;

/** Where the app stores a resume: `resumes/{uid}/latest.pdf`. */
function resumePath(uid) {
  return `resumes/${uid}/latest.pdf`;
}

/** Where `logPlacementApplication` copies the frozen resume (two segments). */
function snapshotPath(uid, applicationId) {
  return `resumes/${uid}/snapshots/app_${applicationId}.pdf`;
}

/** Body content is irrelevant — the rules only read the metadata. */
const SMALL_PDF = new Uint8Array([0x25, 0x50, 0x44, 0x46]); // "%PDF"

/** One oversize buffer, reused; `subarray` yields an exact 5 MB view of it. */
const OVERSIZE = new Uint8Array(FIVE_MB + 1);

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(FIRESTORE_RULES_PATH, "utf8") },
    storage: { rules: fs.readFileSync(STORAGE_RULES_PATH, "utf8") },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

/**
 * Fresh Storage bucket plus the `users/*` role documents the read rule consults.
 * Seeded with rules disabled so the seed itself never depends on the rules under
 * test.
 */
async function seed() {
  await testEnv.clearStorage();
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", OWNER_UID), { role: "student" });
    await setDoc(doc(db, "users", OTHER_UID), { role: "student" });
    await setDoc(doc(db, "users", TEACHER_UID), { role: "teacher" });
    await setDoc(doc(db, "users", ALUMNI_UID), { role: "alumni" });
  });
}

test.beforeEach(seed);

/** A Storage client bound to `uid`. */
function storageFor(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

/** Upload `bytes` to `storagePath` as `uid`, declaring `contentType`. */
function uploadAs(uid, storagePath, bytes, contentType) {
  return uploadBytes(ref(storageFor(uid), storagePath), bytes, { contentType });
}

// ── owner access ─────────────────────────────────────────────────────────

test("owner may upload a PDF resume (PDF MIME allowed)", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
});

test("owner may read back their own resume", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertSucceeds(
      getBytes(ref(storageFor(OWNER_UID), resumePath(OWNER_UID))),
  );
});

test("owner may delete their own resume (null-resource branch)", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertSucceeds(
      deleteObject(ref(storageFor(OWNER_UID), resumePath(OWNER_UID))),
  );
});

// ── MIME restriction ─────────────────────────────────────────────────────

test("a non-PDF content type is denied", async () => {
  await assertFails(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, NOT_PDF),
  );
});

test("a PDF content type with a charset suffix is denied (exact MIME match)", async () => {
  await assertFails(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, `${PDF}; charset=utf-8`),
  );
});

// ── size ceiling ─────────────────────────────────────────────────────────

test("a file larger than 5 MB is denied", async () => {
  await assertFails(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), OVERSIZE, PDF),
  );
});

test("exactly 5 MB is allowed (the `<=` boundary the client validator uses)", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), OVERSIZE.subarray(0, FIVE_MB), PDF),
  );
});

// ── non-owner and unauthenticated access ─────────────────────────────────

test("a non-owner may NOT write into another user's folder", async () => {
  await assertFails(
      uploadAs(OTHER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
});

test("a non-owner student may NOT read another user's resume", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertFails(
      getBytes(ref(storageFor(OTHER_UID), resumePath(OWNER_UID))),
  );
});

test("an unauthenticated client may NOT upload a resume", async () => {
  await assertFails(
      uploadBytes(
          ref(testEnv.unauthenticatedContext().storage(), resumePath(OWNER_UID)),
          SMALL_PDF,
          { contentType: PDF },
      ),
  );
});

test("an unauthenticated client may NOT read a resume", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertFails(
      getBytes(
          ref(testEnv.unauthenticatedContext().storage(), resumePath(OWNER_UID)),
      ),
  );
});

// ── the teacher / alumni read branch (Firestore role lookup) ─────────────

test("a teacher may read a student's resume", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertSucceeds(
      getBytes(ref(storageFor(TEACHER_UID), resumePath(OWNER_UID))),
  );
});

test("an alumni may read a student's resume", async () => {
  await assertSucceeds(
      uploadAs(OWNER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
  await assertSucceeds(
      getBytes(ref(storageFor(ALUMNI_UID), resumePath(OWNER_UID))),
  );
});

test("a teacher may NOT write into a student's folder", async () => {
  await assertFails(
      uploadAs(TEACHER_UID, resumePath(OWNER_UID), SMALL_PDF, PDF),
  );
});

// ── INT-1: placement snapshots ───────────────────────────────────────────

test("placement snapshots are client-immutable (owner upload denied)", async () => {
  await assertFails(
      uploadAs(OWNER_UID, snapshotPath(OWNER_UID, "app1"), SMALL_PDF, PDF),
  );
});

test("the owner may read a placement snapshot once it exists", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(
        ref(context.storage(), snapshotPath(OWNER_UID, "app1")),
        SMALL_PDF,
        { contentType: PDF },
    );
  });
  await assertSucceeds(
      getBytes(ref(storageFor(OWNER_UID), snapshotPath(OWNER_UID, "app1"))),
  );
});

test("a non-owner student may NOT read another student's placement snapshot", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(
        ref(context.storage(), snapshotPath(OWNER_UID, "app2")),
        SMALL_PDF,
        { contentType: PDF },
    );
  });
  await assertFails(
      getBytes(ref(storageFor(OTHER_UID), snapshotPath(OWNER_UID, "app2"))),
  );
});

// ── deny-all fallback ────────────────────────────────────────────────────

test("paths outside resumes/ are denied entirely", async () => {
  await assertFails(
      uploadAs(OWNER_UID, `other/${OWNER_UID}/file.pdf`, SMALL_PDF, PDF),
  );
});
