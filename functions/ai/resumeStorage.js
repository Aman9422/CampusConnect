"use strict";

/**
 * CampusConnect v9.2.5 — resume PDF retrieval from Cloud Storage.
 *
 * WHY THIS MODULE EXISTS
 * ----------------------
 * `reviewResume` read the uploaded PDF with
 *
 *     admin.storage().bucket().file(storagePath)
 *
 * i.e. with NO bucket name. Firebase Admin resolves a nameless bucket from
 * `app.options.storageBucket` and, when that is unset, falls back to
 * `${projectId}.appspot.com` — the LEGACY default bucket name. Newer Firebase
 * projects are provisioned with `${projectId}.firebasestorage.app` instead
 * (this project's `android/app/google-services.json` and
 * `lib/firebase_options.dart` both carry
 * `campusconnect-firebase-project.firebasestorage.app`).
 *
 * The Flutter client uploads through `FirebaseStorage.instance`, which uses the
 * bucket from `FirebaseOptions` — the `firebasestorage.app` one. When the
 * function's implicit bucket name disagrees, every uploaded-PDF review failed
 * to find a file that genuinely exists, and the `not-found` was then swallowed
 * (see `helpers/https_error.js`).
 *
 * This module removes the guesswork: it probes every plausible bucket name for
 * the object and reports exactly what happened, so "no file" and "wrong bucket"
 * are distinguishable in the log and in the client message.
 *
 * The candidate list is a PURE function so it is unit-testable without
 * Firebase; only `downloadResumeBuffer` touches the network.
 */

const admin = require("firebase-admin");

/** Hard ceiling mirroring `StorageService.maxResumeBytes` on the client. */
const RESUME_MAX_BYTES = 5 * 1024 * 1024;

/**
 * Bucket names worth trying for this project, most likely first, deduped.
 *
 * Order: an explicit `STORAGE_BUCKET` override, then whatever Firebase Admin
 * itself would pick, then the two known default naming schemes.
 *
 * @param {object} [params]
 * @param {string} [params.configuredBucket] - `app.options.storageBucket`
 * @param {string} [params.projectId] - GCP project id
 * @returns {string[]} Candidate bucket names (possibly empty)
 */
function resumeBucketCandidates({configuredBucket, projectId} = {}) {
  const candidates = [];
  const push = (name) => {
    if (typeof name === "string" && name.trim().length > 0 &&
        !candidates.includes(name.trim())) {
      candidates.push(name.trim());
    }
  };

  push(process.env.STORAGE_BUCKET);
  push(configuredBucket);
  if (typeof projectId === "string" && projectId.trim().length > 0) {
    const id = projectId.trim();
    // New default-bucket naming first, then the legacy naming.
    push(`${id}.firebasestorage.app`);
    push(`${id}.appspot.com`);
  }
  return candidates;
}

/**
 * Candidate buckets derived from the running Admin app.
 *
 * Tolerates a runtime with no initialised app (the unit-test shim replaces
 * `firebase-admin` wholesale) — the env vars still contribute in that case.
 */
function configuredBucketCandidates() {
  let options = {};
  try {
    if (typeof admin.app === "function") {
      const app = admin.app();
      options = (app && app.options) || {};
    }
  } catch (error) {
    options = {};
  }
  return resumeBucketCandidates({
    configuredBucket: options.storageBucket,
    projectId: options.projectId ||
      process.env.GCLOUD_PROJECT ||
      process.env.GCP_PROJECT,
  });
}

/** True for the @google-cloud/storage "object (or bucket) not found" shapes. */
function isNotFoundError(error) {
  if (!error) return false;
  const code = error.code;
  if (code === 404 || code === "404" || code === "not-found") return true;
  if (error.statusCode === 404) return true;
  const message = typeof error.message === "string" ? error.message : "";
  return /not found|does not exist|no such object/i.test(message);
}

/**
 * Read the resume object, trying every candidate bucket name.
 *
 * Never throws for an expected outcome — the caller maps the typed result to
 * the right `HttpsError`:
 *   - `not-found`   → the object exists in no candidate bucket (or no candidate
 *                     bucket name could be derived at all)
 *   - `unreadable`  → a bucket answered but the read failed
 *   - `too-large`   → the object exceeds [RESUME_MAX_BYTES]
 *
 * @param {string} storagePath - e.g. `resumes/{uid}/latest.pdf`
 * @returns {Promise<
 *   {ok: true, buffer: Buffer, bucket: string} |
 *   {ok: false, reason: string, detail: string, bucketsTried: string[]}
 * >}
 */
async function downloadResumeBuffer(storagePath) {
  const buckets = configuredBucketCandidates();

  if (buckets.length === 0) {
    return {
      ok: false,
      reason: "not-found",
      detail: "No Cloud Storage bucket name could be resolved.",
      bucketsTried: [],
    };
  }

  let lastError = null;

  for (const bucketName of buckets) {
    const file = admin.storage().bucket(bucketName).file(storagePath);
    try {
      const [metadata] = await file.getMetadata();

      // `metadata.size` is a STRING in the Storage API.
      const size = Number(metadata && metadata.size);
      if (Number.isFinite(size) && size > RESUME_MAX_BYTES) {
        console.error(
            `resumeStorage: ${storagePath} in ${bucketName} is ${size} ` +
            `bytes (limit ${RESUME_MAX_BYTES}).`
        );
        return {
          ok: false,
          reason: "too-large",
          detail: `Resume is ${size} bytes; the limit is ${RESUME_MAX_BYTES}.`,
          bucketsTried: buckets,
        };
      }

      const [buffer] = await file.download();
      if (!buffer || buffer.length === 0) {
        console.error(
            `resumeStorage: ${storagePath} in ${bucketName} is empty.`
        );
        return {
          ok: false,
          reason: "unreadable",
          detail: `Object ${storagePath} is empty in ${bucketName}.`,
          bucketsTried: buckets,
        };
      }

      console.log(
          `resumeStorage: read ${buffer.length} bytes from ` +
          `${bucketName}/${storagePath}`
      );
      return {ok: true, buffer, bucket: bucketName};
    } catch (error) {
      lastError = error;
      if (isNotFoundError(error)) {
        // Wrong bucket name, or the object is genuinely absent — either way,
        // the next candidate is what we want to try.
        continue;
      }
      console.error(
          `resumeStorage: read failed for ${bucketName}/${storagePath}:`,
          error && error.message ? error.message : error
      );
      return {
        ok: false,
        reason: "unreadable",
        detail: `${error && error.message ? error.message : error}`,
        bucketsTried: buckets,
      };
    }
  }

  console.error(
      `resumeStorage: ${storagePath} was not found in any candidate bucket ` +
      `[${buckets.join(", ")}]` +
      `${lastError ? ` — last error: ${lastError.message}` : ""}`
  );

  return {
    ok: false,
    reason: "not-found",
    detail: `Object ${storagePath} is absent from every candidate bucket ` +
      `[${buckets.join(", ")}].`,
    bucketsTried: buckets,
  };
}

module.exports = {
  RESUME_MAX_BYTES,
  resumeBucketCandidates,
  configuredBucketCandidates,
  downloadResumeBuffer,
  isNotFoundError,
};
