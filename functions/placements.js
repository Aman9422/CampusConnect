/**
 * CampusConnect — Placement Analytics Cloud Functions.
 *
 * Handles:
 *   - `logPlacementView` — record a student viewing a placement drive
 *   - `logPlacementApplication` — record (idempotent) a student applying
 *   - `updateApplicationStatus` — teacher/alumni advances an application
 *     through the pipeline (shortlisted → interviewed → placed, or rejected)
 *
 * SEC-1 fix (v9.0): identity functions are `onCall` (not `onRequest`) so
 * identity comes from `request.auth.uid`, never from a body-supplied userId.
 *
 * v9.1: `updateApplicationStatus` is the ONLY writer of `status` on
 * application docs (students may read but never write their own status).
 *
 * v9.1 audit fixes (docs/confirmation.md):
 *   - SEC-3: `updateApplicationStatus` now verifies the actor authored the
 *     placement (`placements/{id}.createdBy == uid`), enforces a server-side
 *     status transition state machine (`applied→[shortlisted,rejected]` …),
 *     and rate-limits per actor (career-coach pattern).
 *   - SEC-4: `logPlacementApplication` validates the placement exists, is
 *     active and is not past its deadline inside the create transaction.
 *   - BUG-A: the mirror doc is guarded in the `updateApplicationStatus`
 *     transaction — a missing mirror no longer aborts the canonical update.
 *   - BUG-E: `logPlacementApplication` null-guards `request.data`.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {logAnalyticsEvent} = require("./helpers/shared");

// ===============================================
// APPLICATION STATUS (v9.1 — Teacher Applicant Review)
// ===============================================

/** Allowed status transitions — single source of truth. */
const APPLICATION_STATUSES = ["shortlisted", "interviewed", "placed", "rejected"];

/**
 * Server-side status transition state machine (SEC-3).
 *
 * The UI's `_StatusActions._availableActions` is client-side only — a
 * malicious teacher/alumni could call the callable directly and jump
 * `applied → placed` or `placed → shortlisted`. This map is enforced inside
 * the transaction so every transition must come from a legal previous state.
 * Terminal states (`placed` / `rejected`) have no outgoing transitions.
 */
const STATUS_TRANSITIONS = {
  applied: ["shortlisted", "rejected"],
  shortlisted: ["interviewed", "rejected"],
  interviewed: ["placed", "rejected"],
  placed: [],
  rejected: [],
};

/** SEC-3: per-actor rate limit for status updates (career-coach pattern). */
const STATUS_RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const STATUS_RATE_LIMIT_MAX = 20; // Max 20 status updates per minute

/**
 * Update a student's application status (teacher/alumni only).
 *
 * v9.1 (project_info__29.md §5.1): both application write paths are locked
 * client-side (`update: false` in firestore.rules), so advancing a pipeline
 * stage MUST go through this Admin-SDK callable. The update is applied to
 * BOTH mirrors atomically inside a Firestore transaction:
 *
 *   - canonical: `applications/{uid}_{placementId}` (field `resumeUrl`)
 *   - mirror:    `placements/{placementId}/applications/{uid}` (field `resume`)
 *
 * The applying student is notified via a `statusChange` notification
 * (`users/{uid}/notifications`), matching the existing `notifyStatusChange`
 * shape the client already parses.
 *
 * v9.1 audit (SEC-3): the transaction also verifies the actor authored the
 * placement, that the requested transition is legal from the application's
 * current status, and that the mirror doc exists (BUG-A — a missing mirror
 * is re-created instead of aborting the whole transaction).
 */
exports.updateApplicationStatus = onCall(
    {cors: false, maxInstances: 20},
    async (request) => {
      const uid = request.auth?.uid;

      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to update an application."
        );
      }

      const {placementId, studentId, status} = request.data || {};

      if (!placementId || typeof placementId !== "string" || placementId.trim() === "") {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Missing required field: placementId"
        );
      }
      if (!studentId || typeof studentId !== "string" || studentId.trim() === "") {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Missing required field: studentId"
        );
      }
      if (!APPLICATION_STATUSES.includes(status)) {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            `Invalid status. Must be one of: ${APPLICATION_STATUSES.join(", ")}`
        );
      }

      try {
        const db = admin.firestore();
        const applicationId = `${studentId}_${placementId}`;
        const canonicalRef = db.collection("applications").doc(applicationId);
        const mirrorRef = db
            .collection("placements")
            .doc(placementId)
            .collection("applications")
            .doc(studentId);
        const placementRef = db.collection("placements").doc(placementId);

        const actorRole = await _getUserRole(uid);
        if (actorRole !== "teacher" && actorRole !== "alumni") {
          throw new admin.functions.https.HttpsError(
              "permission-denied",
              "Only teachers and alumni can update application status."
          );
        }

        // SEC-3: per-actor rate limit — a scripted loop of status writes is
        // throttled the same way Career Coach throttles repeated AI calls.
        const rateLimitCheck = await _checkStatusRateLimit(uid);
        if (!rateLimitCheck.allowed) {
          throw new admin.functions.https.HttpsError(
              "resource-exhausted",
              `Too many status updates. Please wait ${rateLimitCheck.retryAfter} seconds.`,
              {retryAfter: rateLimitCheck.retryAfter}
          );
        }

        const result = await db.runTransaction(async (transaction) => {
          const canonicalDoc = await transaction.get(canonicalRef);
          if (!canonicalDoc.exists) {
            throw new admin.functions.https.HttpsError(
                "not-found",
                "Application not found."
            );
          }

          const canonicalData = canonicalDoc.data();
          if (canonicalData.placementId !== placementId ||
              canonicalData.userId !== studentId) {
            throw new admin.functions.https.HttpsError(
                "invalid-argument",
                "Application does not match the requested placement/student."
            );
          }

          // SEC-3: verify the actor authored the placement. Reading it inside
          // the transaction guarantees a concurrently-deleted placement cannot
          // slip through (the re-read in the transaction would miss it).
          const placementDoc = await transaction.get(placementRef);
          if (!placementDoc.exists) {
            throw new admin.functions.https.HttpsError(
                "not-found",
                "Placement not found."
            );
          }
          const placementData = placementDoc.data();
          if (placementData.createdBy !== uid) {
            throw new admin.functions.https.HttpsError(
                "permission-denied",
                "You can only update applications for placements you created."
            );
          }

          // SEC-3: enforce the server-side transition state machine.
          const previousStatus = canonicalData.status || "applied";
          const legalNext = STATUS_TRANSITIONS[previousStatus] || [];
          if (!legalNext.includes(status)) {
            throw new admin.functions.https.HttpsError(
                "failed-precondition",
                `Cannot transition application from "${previousStatus}" to "${status}".`
            );
          }

          // BUG-A: guard the mirror — a missing mirror (legacy/partial write)
          // used to abort the ENTIRE transaction via `update` on a
          // non-existent doc, rolling back the canonical status write. Now we
          // re-create the mirror instead so the canonical update succeeds.
          //
          // CRITICAL: Firestore transactions require ALL reads to precede
          // ALL writes. The mirror `get` MUST happen before the canonical
          // `update` below — reading after a write makes the SDK throw, which
          // aborted the whole transaction and surfaced to the client as
          // `[firebase_functions/internal] INTERNAL` on every status change.
          const mirrorDoc = await transaction.get(mirrorRef);

          transaction.update(canonicalRef, {status});

          if (mirrorDoc.exists) {
            transaction.update(mirrorRef, {status});
          } else {
            transaction.set(mirrorRef, {
              userId: studentId,
              studentId,
              placementId,
              status,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          return {previousStatus};
        });

        // Student notification (statusChange shape — matches
        // NotificationsService.notifyStatusChange on the client).
        try {
          const placementDoc = await db.collection("placements").doc(placementId).get();
          const placementData = placementDoc.exists ? placementDoc.data() : null;
          await _notifyStatusChange({
            userId: studentId,
            placementId,
            company: placementData?.company || "placement",
            role: placementData?.role || "position",
            status,
          });
        } catch (notifyError) {
          // Non-fatal: the status write succeeded; a failed notification must
          // not roll back the pipeline update.
          console.error("updateApplicationStatus: notification failed:", notifyError);
        }

        await logAnalyticsEvent({
          eventType: "placement_status_updated",
          userId: uid,
          metadata: {
            studentId,
            placementId,
            previousStatus: result.previousStatus,
            status,
          },
        });

        return {
          success: true,
          studentId,
          placementId,
          status,
          previousStatus: result.previousStatus,
        };
      } catch (error) {
        console.error("Error in updateApplicationStatus:", error);
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        throw new admin.functions.https.HttpsError(
            "internal",
            `Failed to update application status: ${error.message}`
        );
      }
    }
);

/**
 * Read the calling user's role from `users/{uid}`.
 * Returns null when the user document is missing or has no role.
 */
async function _getUserRole(uid) {
  try {
    const doc = await admin.firestore().collection("users").doc(uid).get();
    if (!doc.exists) return null;
    return doc.data().role || null;
  } catch (error) {
    console.error("updateApplicationStatus: role lookup failed:", error);
    return null;
  }
}

/**
 * SEC-3: per-minute rate limiting for `updateApplicationStatus`.
 *
 * Mirrors the career-coach rate-limit pattern (`checkCareerCoachRateLimit`):
 * stores timestamps in the window on `placement_status_rate_limits/{uid}`,
 * fails open on errors so a rate-limit store outage never blocks legitimate
 * teachers.
 *
 * @param {string} uid - Actor's Firebase Auth ID
 * @returns {Promise<{allowed: boolean, retryAfter: number}>}
 */
async function _checkStatusRateLimit(uid) {
  const rateLimitRef = admin.firestore()
      .collection("placement_status_rate_limits")
      .doc(uid);

  const now = Date.now();
  const windowStart = now - STATUS_RATE_LIMIT_WINDOW_MS;

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      if (!doc.exists) {
        transaction.set(rateLimitRef, {
          timestamps: [now],
          lastCleanup: now,
        });
        return {allowed: true, retryAfter: 0};
      }

      const data = doc.data();
      let timestamps = data.timestamps || [];

      // Remove old timestamps outside window.
      timestamps = timestamps.filter((ts) => ts > windowStart);

      if (timestamps.length >= STATUS_RATE_LIMIT_MAX) {
        const oldestTimestamp = Math.min(...timestamps);
        const retryAfter = Math.ceil(
            (oldestTimestamp + STATUS_RATE_LIMIT_WINDOW_MS - now) / 1000
        );
        return {allowed: false, retryAfter};
      }

      timestamps.push(now);
      transaction.update(rateLimitRef, {
        timestamps,
        lastCleanup: now,
      });

      return {allowed: true, retryAfter: 0};
    });

    return result;
  } catch (error) {
    console.error("Error checking placement status rate limit:", error);
    // On error, allow the request (fail open).
    return {allowed: true, retryAfter: 0};
  }
}

/**
 * Write a `statusChange` notification for the applying student.
 *
 * Mirrors the client-side `AppNotification.statusChange` shape so the
 * existing notifications UI renders it without changes:
 *   - type: "statusChange"
 *   - data: {placementId, company, role, status}
 */
async function _notifyStatusChange({userId, placementId, company, role, status}) {
  const titles = {
    shortlisted: "Application Shortlisted",
    interviewed: "Interview Scheduled",
    placed: "🎉 Congratulations!",
    rejected: "Application Update",
  };
  const bodies = {
    shortlisted: `You have been shortlisted for ${role} at ${company}.`,
    interviewed: `Your application for ${role} at ${company} has moved to the interview stage.`,
    placed: `You have been selected for ${role} at ${company}!`,
    rejected: `Your application for ${role} at ${company} was not selected. Keep trying!`,
  };

  await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type: "statusChange",
        title: titles[status] || "Application Status Update",
        body: bodies[status] || `Your application for ${role} at ${company} status: ${status}`,
        data: {
          placementId,
          company,
          role,
          status,
        },
        isRead: false,
        priority: "high",
        createdAt: admin.firestore.Timestamp.now(),
      });
}

// ===============================================
// EXPORTS
// ===============================================

/**
 * Log placement view event.
 *
 * SEC-1 fix: migrated from onRequest to onCall. Identity now comes from
 * `request.auth.uid` — body-based userId is no longer trusted.
 */
exports.logPlacementView = onCall(
    {cors: false, maxInstances: 10},
    async (request) => {
      const uid = request.auth?.uid;

      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to log a placement view."
        );
      }

      const {placementId, company} = request.data || {};

      if (!placementId) {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Missing required field: placementId"
        );
      }

      try {
        await logAnalyticsEvent({
          eventType: "placement_viewed",
          userId: uid,
          metadata: {
            placementId,
            company: company || "Unknown",
          },
        });

        return {success: true};
      } catch (error) {
        console.error("Error logging placement view:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Internal server error. Please try again later."
        );
      }
    }
);

/**
 * Log placement application event and create application record (V5).
 *
 * V5 Features:
 * - HTTPS Callable (secure auth context)
 * - Idempotent (safe to call multiple times)
 * - Duplicate prevention via Firestore transaction
 * - Returns existing application if already applied
 * - Dual storage for backward compatibility
 * - Analytics logging
 * - v8.4.1 (T5): resume snapshot at apply time
 * - v8.4.2 (S2a/H1): immutable snapshot copy so bytes survive re-uploads
 *
 * Security: uid extracted from Firebase Auth (cannot be spoofed)
 *
 * v9.1 audit fixes:
 *   - SEC-4: the placement document is read inside the create transaction and
 *     the application is rejected (not-found / failed-precondition) when the
 *     placement is missing, inactive, or past its deadline — closed/fake
 *     placements can no longer be applied to, which previously polluted
 *     teacher analytics and applicant lists.
 *   - BUG-E: `request.data` is null-guarded before destructuring.
 */
exports.logPlacementApplication = onCall(
    {cors: false, maxInstances: 100},
    async (request) => {
      const uid = request.auth?.uid;

      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in to apply"
        );
      }

      try {
        // BUG-E: null-guard request.data — a client calling with no payload
        // used to throw a raw TypeError wrapped as `internal`.
        const {placementId, resumeUrl, company} = request.data || {};
        // v8.4.1 (T5): Resume snapshot from the student's portfolio resume.
        const resumeVersion = request.data?.resumeVersion || null;
        let resumeStoragePath = request.data?.resumeStoragePath || null;
        let atsScoreAtApplication = request.data?.atsScoreAtApplication || null;

        // v8.4.2 (S3a/M2): ownership + range validation.
        if (resumeStoragePath && !resumeStoragePath.startsWith(`resumes/${uid}/`)) {
          resumeStoragePath = null;
        }
        if (typeof atsScoreAtApplication !== "number") {
          atsScoreAtApplication = null;
        } else if (atsScoreAtApplication < 0 || atsScoreAtApplication > 100) {
          atsScoreAtApplication = null;
        } else if (!Number.isInteger(atsScoreAtApplication)) {
          atsScoreAtApplication = Math.round(atsScoreAtApplication);
        }

        // Validate required fields
        if (!placementId) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              "Missing required field: placementId"
          );
        }

        // V5: Idempotent application creation
        const applicationId = `${uid}_${placementId}`;
        let isNewApplication = false;

        // v8.4.2 (S2a/H1): copy the resume to an immutable snapshot path.
        let snapshotStoragePath = resumeStoragePath;
        let snapshotUrl = resumeUrl || "";
        if (resumeStoragePath) {
          try {
            const snapshotPath = `resumes/${uid}/snapshots/app_${applicationId}.pdf`;
            await admin.storage().bucket()
                .file(resumeStoragePath)
                .copy(admin.storage().bucket().file(snapshotPath));
            const [url] = await admin.storage().bucket()
                .file(snapshotPath)
                .getSignedUrl({action: "read", expires: "01-01-2035"});
            snapshotStoragePath = snapshotPath;
            snapshotUrl = url;
          } catch (snapshotError) {
            // Non-fatal: keep the original path/URL if the copy fails.
            console.error("logPlacementApplication: resume snapshot copy failed:", snapshotError);
          }
        }

        await admin.firestore().runTransaction(async (transaction) => {
          // SEC-4: validate the placement exists, is active, and is not past
          // its deadline INSIDE the transaction so the check is atomic with
          // the create — a placement closed mid-request cannot be applied to.
          const placementRef = admin.firestore()
              .collection("placements")
              .doc(placementId);
          const placementDoc = await transaction.get(placementRef);
          if (!placementDoc.exists) {
            throw new admin.functions.https.HttpsError(
                "not-found",
                "Placement not found."
            );
          }
          const placementData = placementDoc.data();
          if (placementData.isActive !== true) {
            throw new admin.functions.https.HttpsError(
                "failed-precondition",
                "This placement is no longer accepting applications."
            );
          }
          const deadline = placementData.deadline;
          if (deadline && deadline.toMillis() <= Date.now()) {
            throw new admin.functions.https.HttpsError(
                "failed-precondition",
                "The application deadline for this placement has passed."
            );
          }

          const existingAppRef = admin.firestore()
              .collection("applications")
              .doc(applicationId);

          const existingApp = await transaction.get(existingAppRef);

          if (existingApp.exists) {
            isNewApplication = false;
            return;
          }

          // Create new application in top-level collection.
          transaction.set(existingAppRef, {
            userId: uid,
            studentId: uid,
            placementId,
            resumeUrl: snapshotUrl,
            resumeStoragePath: snapshotStoragePath,
            resumeVersion,
            atsScoreAtApplication,
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "applied",
          });

          // Mirror to old structure for backward compatibility
          transaction.set(
              admin.firestore()
                  .collection("placements")
                  .doc(placementId)
                  .collection("applications")
                  .doc(uid),
              {
                userId: uid,
                studentId: uid,
                placementId,
                resume: snapshotUrl,
                resumeStoragePath: snapshotStoragePath,
                resumeVersion,
                atsScoreAtApplication,
                appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "applied",
              }
          );

          isNewApplication = true;
        });

        // Log analytics event (even for duplicate attempts)
        await logAnalyticsEvent({
          eventType: "placement_applied",
          userId: uid,
          metadata: {
            placementId,
            company: company || "Unknown",
            isNewApplication,
          },
        });

        return {
          success: true,
          message: isNewApplication
              ? "Application submitted successfully"
              : "Already applied to this placement",
          applicationId,
          isNewApplication,
        };
      } catch (error) {
        console.error("Error in logPlacementApplication:", error);

        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }

        throw new admin.functions.https.HttpsError(
            "internal",
            `Failed to submit application: ${error.message}`
        );
      }
    }
);
