/**
 * CampusConnect — Placement Analytics Cloud Functions.
 *
 * Handles:
 *   - `logPlacementView` — record a student viewing a placement drive
 *   - `logPlacementApplication` — record (idempotent) a student applying
 *
 * SEC-1 fix (v9.0): both functions are `onCall` (not `onRequest`) so
 * identity comes from `request.auth.uid`, never from a body-supplied userId.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {logAnalyticsEvent} = require("./helpers/shared");

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
 */
exports.logPlacementApplication = onCall(
    {cors: false},
    async (request) => {
      const uid = request.auth?.uid;

      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in to apply"
        );
      }

      try {
        const {placementId, resumeUrl, company} = request.data;
        // v8.4.1 (T5): Resume snapshot from the student's portfolio resume.
        const resumeVersion = request.data.resumeVersion || null;
        let resumeStoragePath = request.data.resumeStoragePath || null;
        let atsScoreAtApplication = request.data.atsScoreAtApplication || null;

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
