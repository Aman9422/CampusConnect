/**
 * CampusConnect — AI Resume Review Cloud Function + helpers.
 *
 * Handles:
 *   - Resume review (ATS score, missing keywords, feedback)
 *   - PDF extraction from Firebase Storage
 *   - Crash-safe quota reservation (monthly limit + daily sweep)
 *   - Quota rollback on AI failure
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const crypto = require("crypto");
// v8.5 (R2): server-side PDF → text extraction for the Resume Reviewer.
// Deep require avoids pdf-parse's main-entry test-data side effect; the
// extractor is pure-JS and runs on the Node 20 functions runtime.
const pdfParse = require("pdf-parse/lib/pdf-parse.js");
const {generateResumeReviewAI} = require("./aiProvider");
const {logAnalyticsEvent} = require("../helpers/shared");

// ===============================================
// CONSTANTS
// ===============================================

const RESUME_MONTHLY_LIMIT = 5; // Free reviews per month
const RESUME_MAX_LENGTH = 5000; // Maximum resume characters
const RESUME_MIN_LENGTH = 100; // Minimum resume characters
/** v8.8.2 (A): age after which an un-cleared reservation is considered stale. */
const RESUME_RESERVATION_STALE_HOURS = 24;

// ===============================================
// EXPORTS
// ===============================================

/**
 * AI Resume Review Cloud Function (Version 6.7)
 *
 * Analyzes resumes for ATS compatibility and provides actionable feedback.
 *
 * Features:
 * - ATS score calculation
 * - Missing keywords detection
 * - Bullet point improvements
 * - Section-by-section advice
 * - Monthly usage limits (free tier)
 *
 * @param {object} request - Contains userId, resumeText, targetRole
 * @param {object} response - Returns review analysis and usage metadata
 */
// v8.4.2 (S6b/P3): CALLABLE (was HTTPS onRequest). The authenticated uid comes
// from `request.auth.uid` — a forged body/query `userId` can no longer spend
// the monthly quota or attach reviews to another account. The GET usage-check
// path is now the `{checkUsage: true}` callable flag.
exports.reviewResume = onCall(
    {maxInstances: 5, timeoutSeconds: 120, memory: "512MiB"},
    async (request) => {
      // v8.4.2 (S6b/P3): uid from Firebase Auth is the only identity source.
      const userId = request.auth?.uid;

      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to review your resume."
        );
      }

      // Usage check without submitting a review (replaces the old GET path).
      if (request.data?.checkUsage === true) {
        const usage = await getResumeUsage(userId);
        return {usage};
      }

      try {
        // Extract data from request
        const { resumeText, storagePath, targetRole, experienceLevel } =
            request.data || {};

        // v8.5 (R3): resolve the resume text either from the uploaded PDF
        // (`storagePath`) or the pasted manual text fallback.
        let trimmedResume;
        let reviewSource = "pasted";
        if (storagePath) {
          trimmedResume = await resumeTextFromStorage(userId, storagePath);
          reviewSource = "uploaded";
        } else {
          if (!resumeText) {
            throw new admin.functions.https.HttpsError(
                "invalid-argument",
                "Resume text is required."
            );
          }
          trimmedResume = resumeText.trim();
        }

        // Validate resume length (PDF path already truncated to max).
        if (trimmedResume.length < RESUME_MIN_LENGTH) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              `Resume too short. Minimum ${RESUME_MIN_LENGTH} characters required.`
          );
        }
        if (trimmedResume.length > RESUME_MAX_LENGTH) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              `Resume too long. Maximum ${RESUME_MAX_LENGTH} characters allowed.`
          );
        }

        console.log(`Resume review request from user: ${userId} (${reviewSource})`);
        console.log(`Resume length: ${trimmedResume.length} characters`);
        console.log(`Target role: ${targetRole || "General"}`);

        // v8.6 (MED 8): quota check + increment are now ONE transaction
        // (`consumeResumeQuota`) so two concurrent calls cannot both pass
        // the limit and exceed 5 monthly reviews. `getResumeUsage` is kept
        // for the read-only `checkUsage` path only.
        // v8.8.2 (A, HIGH): crash-safe reservation. `consumeResumeQuota`
        // stamps a per-request `pendingRequestId` / `pendingSince` on the
        // usage doc, so a 500/function-crash AFTER quota consumption but
        // BEFORE the AI-failure rollback no longer permanently burns a
        // credit — the daily `compensateStaleResumeQuota` sweep refunds any
        // reservation left stale for >24h. The reservation is cleared on
        // success (credit kept, review delivered) and on AI-failure rollback
        // (credit returned).
        let usageData;
        const requestId = crypto.randomUUID();
        try {
          usageData = await consumeResumeQuota(userId, requestId);
        } catch (quotaError) {
          if (quotaError instanceof admin.functions.https.HttpsError) {
            throw quotaError;
          }
          console.error("quota error in reviewResume:", quotaError);
          throw new admin.functions.https.HttpsError(
              "internal",
              "Could not verify your review quota. Please try again."
          );
        }

        // Generate AI review (Real AI via Groq/HuggingFace).
        let reviewResult;
        try {
          const aiResult = await generateResumeReviewAI(
              trimmedResume,
              targetRole || "General / Entry Level",
              experienceLevel || "Student / Fresher"
          );
          reviewResult = aiResult.review;
          console.log(`Resume review from provider: ${aiResult.providerUsed}`);
          // v8.8.2 (A): the review completed — keep the credit, clear the
          // reservation so the compensation sweep never refunds it.
          await clearResumeReservation(userId, requestId);
        } catch (aiError) {
          // v8.6 (HIGH 3): the AI provider failed — the user gets NO review
          // but already paid a credit. Roll it back so the quota is only
          // consumed for completed reviews.
          console.error("AI provider error in reviewResume:", aiError);
          try {
            await rollbackResumeUsage(userId, requestId);
            console.log("reviewResume: rolled back quota after AI failure");
          } catch (rollbackError) {
            console.error(
                "reviewResume: rollback of consumed quota failed:",
                rollbackError
            );
          }
          throw new admin.functions.https.HttpsError(
              "internal",
              "AI analysis failed. Please try again later."
          );
        }

        // Log analytics event
        await logAnalyticsEvent({
          eventType: "resume_review_completed",
          userId: userId,
          metadata: {
            resumeLength: trimmedResume.length,
            source: reviewSource,
            storagePath: storagePath || null,
            targetRole: targetRole || "General",
            atsScore: reviewResult.atsScore,
            monthlyUsage: usageData.monthlyCount,
          },
        });

        // Return successful response (unchanged shape for the client).
        return {
          review: reviewResult,
          usage: usageData,
        };

      } catch (error) {
        // Re-throw validation/quota HttpsError as-is.
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        console.error("Error in reviewResume function:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Failed to analyze resume. Please try again later."
        );
      }
    }
);

/**
 * v8.8.2 (A, HIGH): daily sweep that refunds resume review credits whose
 * reservation was left stale by a crash/500 in `reviewResume`.
 *
 * If a function container dies AFTER `consumeResumeQuota` incremented the
 * count but BEFORE the AI-failure rollback could run, the usage doc carries a
 * `pendingRequestId` / `pendingSince` reservation with no one left to clear
 * it. This daily sweep refunds those credits so the user is never permanently
 * charged for a review that was never delivered.
 *
 * Safety contract:
 *   - Runs daily at 04:00 UTC (after the 03:00 AI-conversation cleanup).
 *   - Only touches docs where `pendingSince` is older than 24h — genuine
 *     in-flight requests (AI calls can take up to the 120s timeout) are
 *     never refunded out from under a running request.
 *   - Decrement + reservation clear happen atomically per user in a
 *     transaction (no double-refund: `clearResumeReservation` and
 *     `rollbackResumeUsage` clear the reservation too).
 *   - Never clears `monthlyCount` below 0 and never touches documents
 *     without a reservation.
 *   - Aggregate log only (userId + refunded count) — no review content.
 */
exports.compensateStaleResumeQuota = onSchedule(
    {
      schedule: "every day 04:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - RESUME_RESERVATION_STALE_HOURS * 60 * 60 * 1000
      );

      console.log(
          `compensateStaleResumeQuota: refunding reservations older than ` +
          `${cutoff.toDate().toISOString()}`
      );

      let compensated = 0;

      try {
        const snapshot = await admin.firestore()
            .collection("resume_usage")
            .where("pendingSince", "<", cutoff)
            .limit(1000)
            .get();

        for (const usageDoc of snapshot.docs) {
          const userId = usageDoc.id;
          const data = usageDoc.data();
          const monthlyCount = data.monthlyCount || 0;
          if (monthlyCount <= 0) continue;

          try {
            await admin.firestore().runTransaction(async (transaction) => {
              // Re-read inside the transaction: the reservation may have been
              // cleared (success/rollback) between the query and now.
              const freshDoc = await transaction.get(usageDoc.ref);
              if (!freshDoc.exists) return;

              const freshData = freshDoc.data();
              // Only refund if the reservation is STILL stale and un-cleared.
              if (!freshData.pendingSince) return;
              if (freshData.pendingSince.toMillis() >= cutoff.toMillis()) return;

              const count = freshData.monthlyCount || 0;
              if (count <= 0) return;

              transaction.update(usageDoc.ref, {
                monthlyCount: count - 1,
                pendingRequestId: admin.firestore.FieldValue.delete(),
                pendingSince: admin.firestore.FieldValue.delete(),
              });
            });
            compensated++;
          } catch (perUserError) {
            console.error(
                `compensateStaleResumeQuota: failed for user ${userId}:`,
                perUserError
            );
          }
        }

        console.log(
            `compensateStaleResumeQuota: refunded ${compensated} stale credit(s)`
        );
      } catch (error) {
        console.error("compensateStaleResumeQuota error:", error);
      }
    }
);

// ===============================================
// PRIVATE HELPERS
// ===============================================

/**
 * v8.5 (R2/R3): Extract resume text from the authenticated user's uploaded
 * resume PDF in Firebase Storage.
 *
 * Security contract enforced here (never trust client-supplied identity):
 *   - [uid] is `request.auth.uid` from the callable context (authoritative).
 *   - [storagePath] is allowed ONLY when it exactly equals
 *     `resumes/{uid}/latest.pdf`. Any other path (other user, other file,
 *     different layout) is rejected with `invalid-argument`.
 *
 * @param {string} uid - Authenticated user id
 * @param {string} storagePath - Client-supplied storage path
 * @returns {Promise<string>} Extracted resume text (max RESUME_MAX_LENGTH)
 * @throws {HttpsError#invalid-argument|not-found}
 */
async function resumeTextFromStorage(uid, storagePath) {
  const expectedPath = `resumes/${uid}/latest.pdf`;
  if (typeof storagePath !== "string" || storagePath !== expectedPath) {
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "The supplied resume path is not a valid resume for this account."
    );
  }

  let data;
  try {
    const file = admin.storage().bucket().file(storagePath);
    const [metadata] = await file.getMetadata();
    if (metadata.size != null && metadata.size > 5 * 1024 * 1024) {
      throw new admin.functions.https.HttpsError(
          "invalid-argument",
          "Resume exceeds the 5 MB limit."
      );
    }
    const [buffer] = await file.download();
    data = buffer;
  } catch (error) {
    if (error instanceof admin.functions.https.HttpsError) throw error;
    if (error && (error.code === 404 || error.code === "not-found")) {
      throw new admin.functions.https.HttpsError(
          "not-found",
          "Resume file not found. Please upload your resume and try again."
      );
    }
    throw new admin.functions.https.HttpsError(
        "internal",
        "Could not read your resume. Please try again later."
    );
  }

  if (!data || data.length === 0) {
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF."
    );
  }

  let text;
  try {
    const parsed = await pdfParse(data);
    text = (parsed.text || "").replace(/\u0000/g, "").trim();
  } catch (parseError) {
    console.error(
        `resumeTextFromStorage: PDF parse failed for ${storagePath}:`,
        parseError.message || parseError
    );
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF."
    );
  }

  // v8.6 (LOW): a PDF with SOME text but under the minimum is a genuine short
  // resume, not an image — give it an accurate message instead of the
  // image-based mislabel. Only a completely empty extraction is treated as
  // scanned/image-only.
  if (text.length < RESUME_MIN_LENGTH) {
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        text.length > 0
            ? `This resume is too short (${text.length} characters). Please upload a resume with at least ${RESUME_MIN_LENGTH} characters of text.`
            : "This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF."
    );
  }

  // Truncate to the same ceiling the manual path enforces.
  if (text.length > RESUME_MAX_LENGTH) {
    text = text.substring(0, RESUME_MAX_LENGTH);
  }

  console.log(
      `resumeTextFromStorage: extracted ${text.length} characters from ${storagePath}`
  );
  return text;
}

/**
 * Get resume usage without incrementing
 *
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Usage data
 */
async function getResumeUsage(userId) {
  try {
    const usageDoc = await admin.firestore()
        .collection("resume_usage")
        .doc(userId)
        .get();

    if (!usageDoc.exists) {
      return {
        monthlyCount: 0,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastResetMonth: null,
      };
    }

    const data = usageDoc.data();
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    // Check if month has reset
    if (data.lastResetMonth !== currentMonth) {
      return {
        monthlyCount: 0,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastResetMonth: currentMonth,
      };
    }

    return {
      monthlyCount: data.monthlyCount || 0,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
      lastResetMonth: data.lastResetMonth,
      lastReviewAt: data.lastReviewAt?.toDate?.()?.toISOString() || null,
    };
  } catch (error) {
    console.error("Error getting resume usage:", error);
    return {
      monthlyCount: 0,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
    };
  }
}

/**
 * v8.6 (MED 8): atomically check the monthly limit AND increment the quota.
 *
 * The old flow (`getResumeUsage` outside a transaction, then
 * `trackResumeUsage` inside one) was not atomic together: two concurrent
 * calls could both read `monthlyCount = 4`, both pass the check, and both
 * increment → 6+ reviews in a month. This helper performs check-then-increment
 * in a SINGLE transaction.
 *
 * v8.8.2 (A, HIGH): the consumed credit is now a per-request RESERVATION.
 * `pendingRequestId` / `pendingSince` are stamped on the usage doc at
 * consumption time so a crash/500 between consumption and the AI-failure
 * rollback can be detected and refunded by `compensateStaleResumeQuota`.
 * The reservation is cleared by [clearResumeReservation] on success and by
 * [rollbackResumeUsage] on AI failure.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - Unique id for this review request
 * @returns {Promise<object>} Usage data (post-increment)
 * @throws {HttpsError#resource-exhausted} when the monthly limit is reached
 */
async function consumeResumeQuota(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("resume_usage")
      .doc(userId);

  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const timestamp = admin.firestore.Timestamp.now();

  try {
    return await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      const reservationFields = {
        pendingRequestId: requestId,
        pendingSince: timestamp,
      };

      if (!usageDoc.exists) {
        // First review this month — create the usage doc, already consumed.
        const firstUsage = {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastReviewAt: timestamp,
          lastResetMonth: currentMonth,
          ...reservationFields,
        };
        transaction.set(usageRef, firstUsage);
        return {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastResetMonth: currentMonth,
        };
      }

      const data = usageDoc.data();
      const lastResetMonth = data.lastResetMonth || "";

      // New month → reset the counter to 1 (this call is the first review).
      if (lastResetMonth !== currentMonth) {
        const resetData = {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastReviewAt: timestamp,
          lastResetMonth: currentMonth,
          ...reservationFields,
        };
        transaction.update(usageRef, resetData);
        return {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastResetMonth: currentMonth,
        };
      }

      // Same month → enforce the limit inside the transaction (atomic).
      const monthlyCount = data.monthlyCount || 0;
      if (monthlyCount >= RESUME_MONTHLY_LIMIT) {
        throw new admin.functions.https.HttpsError(
            "resource-exhausted",
            `Monthly review limit reached (${RESUME_MONTHLY_LIMIT} reviews/month). Resets next month.`,
            {
              usage: {
                monthlyCount: monthlyCount,
                monthlyLimit: RESUME_MONTHLY_LIMIT,
                lastResetMonth: currentMonth,
              },
            }
        );
      }

      const updatedData = {
        monthlyCount: monthlyCount + 1,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastReviewAt: timestamp,
        lastResetMonth: currentMonth,
        ...reservationFields,
      };
      transaction.update(usageRef, updatedData);
      return {
        monthlyCount: updatedData.monthlyCount,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastResetMonth: currentMonth,
      };
    });
  } catch (error) {
    console.error("Error consuming resume quota:", error);
    throw error;
  }
}

/**
 * v8.8.2 (A, HIGH): clear the pending reservation on a usage doc.
 *
 * Called after a successful review (credit is kept — the reservation is just
 * un-stamped so the compensation sweep never refunds a delivered review).
 * Idempotent and best-effort: a stale reservation is harmless because
 * [compensateStaleResumeQuota] refunds it.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function clearResumeReservation(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("resume_usage")
      .doc(userId);

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      if (!usageDoc.exists) return;

      const data = usageDoc.data();
      // Only clear OUR reservation — never touch another in-flight request.
      if (!data.pendingRequestId || data.pendingRequestId !== requestId) return;

      transaction.update(usageRef, {
        pendingRequestId: admin.firestore.FieldValue.delete(),
        pendingSince: admin.firestore.FieldValue.delete(),
      });
    });
  } catch (clearError) {
    console.error("Error clearing resume reservation:", clearError);
  }
}

/**
 * v8.6 (HIGH 3): compensate a consumed quota when the AI review call failed.
 *
 * `reviewResume` consumes the quota BEFORE the AI provider call so the limit
 * is enforced atomically. If the provider then fails, the user has paid a
 * credit without receiving a review — decrement it so credits are only spent
 * on completed reviews. Does not throw (best-effort rollback).
 *
 * v8.8.2 (A, HIGH): the rollback now also CLEARS this request's reservation
 * (`pendingRequestId` / `pendingSince`) in the SAME transaction, so the
 * compensation sweep never double-refunds (decrement + clear is atomic).
 * The requestId guard means only OUR failed request's reservation is
 * cleared — another in-flight request's reservation is never touched.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function rollbackResumeUsage(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("resume_usage")
      .doc(userId);

  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      if (!usageDoc.exists) return;

      const data = usageDoc.data();
      const lastResetMonth = data.lastResetMonth || "";
      if (lastResetMonth !== currentMonth) return; // already reset — nothing to roll back

      const monthlyCount = data.monthlyCount || 0;
      if (monthlyCount <= 0) return;

      const update = {
        monthlyCount: monthlyCount - 1,
      };
      // Only clear OUR reservation — never touch another in-flight request.
      if (data.pendingRequestId && data.pendingRequestId === requestId) {
        update.pendingRequestId = admin.firestore.FieldValue.delete();
        update.pendingSince = admin.firestore.FieldValue.delete();
      }

      transaction.update(usageRef, update);
    });
  } catch (rollbackError) {
    console.error("Error rolling back resume usage:", rollbackError);
  }
}
