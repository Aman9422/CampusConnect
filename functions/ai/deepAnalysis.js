/**
 * CampusConnect — AI Deep Analysis Cloud Function + helpers.
 *
 * Handles:
 *   - AI deep analysis of resumes (strengths, weaknesses, career suggestions)
 *   - Crash-safe quota reservation (monthly limit + daily sweep)
 *   - Quota rollback on AI failure
 *
 * BUG-2 fix (v9.0): retrofit of crash-safe reservation pattern from
 * `reviewResume` (v8.8.2) and `generateCareerCoachAnalysis` (v9.0).
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const crypto = require("crypto");
const {generateAIResponse} = require("./aiProvider");
const {logAnalyticsEvent} = require("../helpers/shared");
// v9.0 (IMP-15): unified AI quota — `ai_analysis_usage/{uid}` is now a legacy
// mirror; the authoritative store is `user_ai_quotas/{uid}.aiAnalysis`.
const quota = require("./quota");

// ===============================================
// CONSTANTS
// ===============================================

const AI_MONTHLY_LIMIT = 3; // AI deep analysis calls per month
const AI_MAX_RESUME_LENGTH = 5000; // Max resume chars for AI input
const AI_ANALYSIS_USAGE_COLLECTION = "ai_analysis_usage";
/** v9.0 (BUG-2): age after which an un-cleared AI analysis reservation is stale. */
const AI_ANALYSIS_RESERVATION_STALE_HOURS = 24;

// ===============================================
// EXPORTS
// ===============================================

/**
 * generateResumeAnalysis - Firebase Callable Function (v6.95)
 *
 * Sends resume text to a real AI provider (Groq/HuggingFace) for
 * deep analysis including strengths, weaknesses, skill gaps,
 * career suggestions, and improvement roadmap.
 *
 * Flow:
 * 1. Validate auth
 * 2. Check AI usage limit (3/month)
 * 3. Check if analysis already exists for this review
 * 4. Call selected AI provider via abstraction layer
 * 5. Normalize response into structured JSON
 * 6. Save to Firestore (resumeReviews/{id}.aiAnalysis)
 * 7. Update user AI usage counter
 * 8. Return structured result
 *
 * Security:
 * - Auth required (uid from Firebase Auth context)
 * - API keys stored server-side only (env vars)
 * - Resume input sanitized and length-limited
 * - Usage limiting prevents abuse
 */
exports.generateResumeAnalysis = onCall(
    {
      cors: true,
      maxInstances: 5,
      timeoutSeconds: 120,
      // Memory: 256MB is sufficient for API relay
      memory: "256MiB",
    },
    async (request) => {
      // === 1. Validate Authentication ===
      const uid = request.auth?.uid;

      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to use AI analysis."
        );
      }

      const { reviewId, resumeText, targetRole } = request.data;

      // Validate required fields
      if (!reviewId || typeof reviewId !== "string") {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Missing or invalid reviewId."
        );
      }

      if (!resumeText || typeof resumeText !== "string") {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Resume text is required."
        );
      }

      // Sanitize resume input
      const sanitizedResume = resumeText.trim().substring(0, AI_MAX_RESUME_LENGTH);

      if (sanitizedResume.length < 100) {
        throw new admin.functions.https.HttpsError(
            "invalid-argument",
            "Resume text is too short for meaningful analysis (min 100 chars)."
        );
      }

      const safeTargetRole = (targetRole || "General / Entry Level")
          .substring(0, 100)
          .trim();

      console.log(`generateResumeAnalysis: uid=${uid}, reviewId=${reviewId}, ` +
          `resumeLength=${sanitizedResume.length}, role="${safeTargetRole}"`);

      try {
        // === 2. Check if AI analysis already exists ===
        const reviewRef = admin.firestore()
            .collection("users")
            .doc(uid)
            .collection("resumeReviews")
            .doc(reviewId);

        const reviewDoc = await reviewRef.get();

        if (!reviewDoc.exists) {
          throw new admin.functions.https.HttpsError(
              "not-found",
              "Resume review not found. Please submit a review first."
          );
        }

        const reviewData = reviewDoc.data();

        // If AI analysis already exists, return cached result
        if (reviewData.aiAnalysis) {
          console.log(`generateResumeAnalysis: Returning cached analysis for ${reviewId}`);
          return {
            success: true,
            cached: true,
            analysis: reviewData.aiAnalysis,
            providerUsed: reviewData.aiProviderUsed || "unknown",
            generatedAt: reviewData.aiGeneratedAt?.toDate?.()?.toISOString() || null,
          };
        }

        // v9.0 (BUG-2 fix): crash-safe quota reservation. The old flow read
        // `aiUsageCount` outside a transaction and incremented AFTER the AI
        // call — if the function crashed between check and increment, or
        // between the AI call and the increment, the user permanently lost a
        // credit. Now we use the same `pendingRequestId` + `pendingSince`
        // reservation pattern as `reviewResume` (v8.8.2) and
        // `generateCareerCoachAnalysis` (v9.0). A daily compensation sweep
        // refunds any reservation left stale for >24h.
        let usageData;
        const requestId = crypto.randomUUID();
        try {
          usageData = await consumeAIAnalysisQuota(uid, requestId);
        } catch (quotaError) {
          if (quotaError instanceof admin.functions.https.HttpsError) {
            throw quotaError;
          }
          console.error("quota error in generateResumeAnalysis:", quotaError);
          throw new admin.functions.https.HttpsError(
              "internal",
              "Could not verify your AI analysis quota. Please try again."
          );
        }

        // === 4. Call AI Provider ===
        console.log(`generateResumeAnalysis: Calling AI provider...`);
        let aiResult;
        try {
          aiResult = await generateAIResponse(sanitizedResume, safeTargetRole);
          console.log(`generateResumeAnalysis: AI response received from "${aiResult.providerUsed}"`);
        } catch (aiError) {
          // AI failed — roll back the consumed quota so the credit is returned.
          console.error("AI provider error in generateResumeAnalysis:", aiError);
          try {
            await rollbackAIAnalysisUsage(uid, requestId);
            console.log("generateResumeAnalysis: rolled back quota after AI failure");
          } catch (rollbackError) {
            console.error("generateResumeAnalysis: rollback failed:", rollbackError);
          }
          throw new admin.functions.https.HttpsError(
              "internal",
              `AI analysis failed: ${aiError.message || "Unknown error"}`
          );
        }

        // === 5. Save to Firestore ===
        const aiAnalysis = {
          summary: aiResult.summary,
          strengths: aiResult.strengths,
          weaknesses: aiResult.weaknesses,
          missingSkills: aiResult.missingSkills,
          careerSuggestions: aiResult.careerSuggestions,
          improvementRoadmap: aiResult.improvementRoadmap,
        };

        const aiGeneratedAt = admin.firestore.Timestamp.now();

        // Update the resume review document with AI analysis
        await reviewRef.update({
          aiAnalysis: aiAnalysis,
          aiGeneratedAt: aiGeneratedAt,
          aiProviderUsed: aiResult.providerUsed,
        });

        // v9.0 (BUG-2 fix): the analysis completed — keep the credit, clear
        // the reservation so the compensation sweep never refunds it.
        await clearAIAnalysisReservation(uid, requestId);

        // === 6. Log analytics ===
        await logAnalyticsEvent({
          eventType: "ai_resume_analysis_generated",
          userId: uid,
          metadata: {
            reviewId: reviewId,
            provider: aiResult.providerUsed,
            resumeLength: sanitizedResume.length,
            targetRole: safeTargetRole,
            monthlyUsage: usageData.monthlyCount,
          },
        });

        console.log(`generateResumeAnalysis: Success. Provider: ${aiResult.providerUsed}, ` +
            `Usage: ${usageData.monthlyCount}/${AI_MONTHLY_LIMIT}`);

        // === 8. Return result ===
        return {
          success: true,
          cached: false,
          analysis: aiAnalysis,
          providerUsed: aiResult.providerUsed,
          generatedAt: aiGeneratedAt.toDate().toISOString(),
          usage: usageData,
        };
      } catch (error) {
        // Re-throw HttpsError as-is
        if (error.code && error.httpErrorCode) {
          throw error;
        }

        console.error("generateResumeAnalysis error:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            `AI analysis failed: ${error.message || "Unknown error"}`
        );
      }
    }
);

/**
 * v9.0 (BUG-2): daily sweep that refunds AI analysis credits whose
 * reservation was left stale by a crash/500 in `generateResumeAnalysis`.
 *
 * Runs daily at 04:20 UTC (after the Resume Review sweep at 04:00 and the
 * Career Coach sweep at 04:10). Safety contract mirrors both sweeps.
 */
exports.compensateStaleAIAnalysisQuota = onSchedule(
    {
      schedule: "every day 04:20",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - AI_ANALYSIS_RESERVATION_STALE_HOURS * 60 * 60 * 1000
      );

      console.log(
          `compensateStaleAIAnalysisQuota: refunding reservations older than ` +
          `${cutoff.toDate().toISOString()}`
      );

      // v9.0 (IMP-15): the unified `user_ai_quotas/{uid}` doc is now the
      // authoritative quota store, so the sweep must refund BOTH the legacy
      // `ai_analysis_usage/{uid}` mirror AND the unified doc atomically.
      // `runFeatureSweep` queries the union of users with a stale reservation
      // in either store and refunds each user once across both — no double
      // refund, no unified/legacy divergence.
      let compensated = 0;
      try {
        compensated = await quota.runFeatureSweep("aiAnalysis", cutoff);
        console.log(
            `compensateStaleAIAnalysisQuota: refunded ${compensated} stale credit(s)`
        );
      } catch (error) {
        console.error("compensateStaleAIAnalysisQuota error:", error);
      }
    }
);

// ===============================================
// PRIVATE HELPERS
// ===============================================

/**
 * Atomically check the monthly AI analysis limit AND increment the quota,
 * stamping a per-request reservation (`pendingRequestId` / `pendingSince`)
 * so a crash/500 after consumption but before the AI-failure rollback can be
 * refunded by `compensateStaleAIAnalysisQuota`.
 *
 * Mirrors `consumeResumeQuota` and `consumeCareerCoachQuota` exactly.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - Unique id for this analysis request
 * @returns {Promise<object>} Usage data (post-increment)
 * @throws {HttpsError#resource-exhausted} when the monthly limit is reached
 */
async function consumeAIAnalysisQuota(userId, requestId) {
  return quota.consumeFeatureQuota(userId, "aiAnalysis", requestId);
}

/**
 * Clear this request's reservation on the AI analysis usage doc.
 * Called after a successful analysis (credit kept, reservation un-stamped).
 */
async function clearAIAnalysisReservation(userId, requestId) {
  return quota.clearFeatureReservation(userId, "aiAnalysis", requestId);
}

/**
 * Roll back the consumed AI analysis quota when the AI call failed.
 * Decrements the count and clears THIS request's reservation in one transaction.
 */
async function rollbackAIAnalysisUsage(userId, requestId) {
  return quota.rollbackFeatureQuota(userId, "aiAnalysis", requestId);
}
