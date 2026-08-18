/**
 * CampusConnect v9.0 — AI Career Coach (callable + quota + cache)
 *
 * Dedicated top-level module so the 3000+ line `index.js` stays lean. This
 * module owns:
 *
 *   - `generateCareerCoachAnalysis`  — the callable the Flutter app calls
 *   - `compensateStaleCareerCoachQuota` — daily crash-safe refund sweep
 *
 * Deterministic orchestration only (per docs/Task.md §5):
 *
 *   - reads the student doc
 *   - builds the privacy-minimized input + stable fingerprint
 *   - serves the cached analysis when fresh (fingerprint + analysisVersion)
 *   - consumes the monthly quota transactionally (Resume Review pattern)
 *   - calls the existing AI router (`generateCareerCoaching` →
 *     `callAIProvider`: Groq → HuggingFace)
 *   - rolls back quota on AI failure, clears reservation on success
 *   - stores `users/{uid}/career_coach/summary`
 *
 * The AI itself lives in `functions/recommendations/career_coach.js` — this
 * file never builds prompts or interprets AI output.
 *
 * Cache contract (docs/Task.md §8):
 *   - Regenerate ONLY when the fingerprint changes OR the student taps
 *     "Re-analyze" (`forceRefresh: true`). Dashboard refresh NEVER calls AI
 *     — it re-reads the cached `summary` document.
 */

const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const crypto = require("crypto");

// SEC-2 fix: per-minute rate limiting for Career Coach to prevent rapid-fire
// quota exhaustion. Reuses the `ai_rate_limits` collection pattern from `askAI`.
const CAREER_COACH_RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const CAREER_COACH_RATE_LIMIT_MAX = 1; // Max 1 call per minute (3/month quota)

const {extractPortfolio} = require("./recommendations/engine");
const {
  ANALYSIS_VERSION: CAREER_COACH_ANALYSIS_VERSION,
  buildCareerAnalysisInput,
  computeCareerInputFingerprint,
  generateCareerCoaching,
} = require("./recommendations/career_coach");

// ===============================================
// v9.0: CAREER COACH CONSTANTS
// ===============================================

/**
 * Monthly AI analysis limit (configurable). Mirrors `RESUME_MONTHLY_LIMIT`.
 * Override via Firebase env config: `CAREER_COACH_MONTHLY_LIMIT`.
 */
const CAREER_COACH_MONTHLY_LIMIT = parseInt(
    process.env.CAREER_COACH_MONTHLY_LIMIT || "3",
    10
);

/**
 * v9.0: age after which an un-cleared reservation is considered stale.
 * Same safety window as the Resume Review sweep (AI calls can take up to
 * the 120 s callable timeout, so 24 h is generous for genuine in-flight
 * requests).
 */
const CAREER_COACH_RESERVATION_STALE_HOURS = 24;

// ===============================================
// v9.0: GENERATE CAREER COACH ANALYSIS (CALLABLE)
// ===============================================

/**
 * Generate (or return the cached) AI career-coach analysis.
 *
 * Payload flags:
 *   - `{checkUsage: true}`     → read-only usage check, no AI call
 *   - `{forceRefresh: true}`   → skip cache + regenerate (Re-analyze button)
 *
 * Flow (docs/Task.md §8):
 *   dashboard opens
 *     → check cached `users/{uid}/career_coach/summary`
 *     → valid? → display cached (no AI call, no quota)
 *     → missing/stale? → transactional quota consume
 *     → AI call
 *     → strict validation
 *     → save analysis
 *     → display analysis
 *
 * Security: uid from `request.auth.uid` only — a forged body userId can
 * never spend quota or read another user's analysis.
 *
 * @returns {Promise<{
 *   cached: boolean,
 *   analysis: object,
 *   usage: object,
 *   generatedAt: string|null,
 *   providerUsed: string|null
 * }>}
 */
exports.generateCareerCoachAnalysis = onCall(
    {maxInstances: 5, timeoutSeconds: 120, memory: "512MiB"},
    async (request) => {
      const userId = request.auth?.uid;
      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to use the AI Career Coach."
        );
      }

      // Read-only usage check (client polls this without spending quota).
      if (request.data?.checkUsage === true) {
        const usage = await getCareerCoachUsage(userId);
        return {usage};
      }

      // SEC-2 fix: per-minute rate limiting to prevent rapid-fire quota
      // exhaustion. An attacker calling 3 times in 3 seconds would exhaust
      // the monthly quota before getting any value. This check ensures at
      // least 60 seconds between Career Coach calls.
      const rateLimitCheck = await checkCareerCoachRateLimit(userId);
      if (!rateLimitCheck.allowed) {
        throw new admin.functions.https.HttpsError(
            "resource-exhausted",
            `Please wait ${rateLimitCheck.retryAfter} seconds before requesting another analysis.`,
            {retryAfter: rateLimitCheck.retryAfter}
        );
      }

      const forceRefresh = request.data?.forceRefresh === true;

      try {
        // 1) Read the student doc + extracted portfolio (nested or
        //    flattened dotted keys — same fallback the engine uses).
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();
        if (!userDoc.exists) {
          throw new admin.functions.https.HttpsError(
              "not-found",
              "User profile not found."
          );
        }
        const userData = userDoc.data();

        // v9.0 (IMP-4): reject students without a completed profile — the
        // AI Career Coach needs meaningful career data to produce useful
        // recommendations. Without it, the AI generates generic filler.
        if (userData.profileCompleted !== true) {
          throw new admin.functions.https.HttpsError(
              "failed-precondition",
              "Please complete your profile before using the AI Career Coach."
          );
        }

        const portfolio = extractPortfolio(userData);

        // 2) Privacy-minimized input + stable fingerprint.
        const input = buildCareerAnalysisInput(userData, portfolio);
        const fingerprint = computeCareerInputFingerprint(input);

        const coachRef = admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("career_coach")
            .doc("summary");

        // 3) Serve the cached analysis when fresh. Never regenerate on
        //    dashboard refresh — only on meaningful career-data changes
        //    (fingerprint mismatch) or an explicit Re-analyze.
        if (!forceRefresh) {
          const cachedSnapshot = await coachRef.get();
          if (cachedSnapshot.exists) {
            const cached = cachedSnapshot.data();
            const isFresh =
                cached.analysisVersion === CAREER_COACH_ANALYSIS_VERSION &&
                cached.profileDataVersion === fingerprint &&
                !!cached.analysis;
            if (isFresh) {
              const usage = await getCareerCoachUsage(userId);
              return {
                cached: true,
                analysis: cached.analysis,
                usage,
                generatedAt: cached.generatedAt
                    ? cached.generatedAt.toDate().toISOString()
                    : null,
                providerUsed: cached.providerUsed || null,
              };
            }
          }
        }

        // 4) Consume the monthly quota atomically (Resume Review pattern).
        const requestId = crypto.randomUUID();
        let usageData;
        try {
          usageData = await consumeCareerCoachQuota(userId, requestId);
        } catch (quotaError) {
          if (quotaError instanceof admin.functions.https.HttpsError) {
            throw quotaError;
          }
          console.error("generateCareerCoachAnalysis quota error:", quotaError);
          throw new admin.functions.https.HttpsError(
              "internal",
              "Could not verify your Career Coach quota. Please try again."
          );
        }

        // 5) AI call through the existing provider router. Failure → refund.
        let analysis;
        try {
          analysis = await generateCareerCoaching(input);
          console.log(
              `generateCareerCoachAnalysis: provider=${analysis.providerUsed}, ` +
              `recs=${analysis.recommendations.length}`
          );
        } catch (aiError) {
          console.error("AI provider error in generateCareerCoachAnalysis:", aiError);
          await rollbackCareerCoachUsage(userId, requestId);
          throw new admin.functions.https.HttpsError(
              "internal",
              "AI Career Coach is temporarily unavailable. Please try again later."
          );
        }

        // 6) Persist the validated analysis + clear the reservation.
        const timestamp = admin.firestore.Timestamp.now();
        await coachRef.set({
          analysis: {
            careerReadiness: analysis.careerReadiness,
            careerFocus: analysis.careerFocus,
            recommendations: analysis.recommendations,
            analysisVersion: analysis.analysisVersion,
          },
          generatedAt: timestamp,
          profileDataVersion: fingerprint,
          analysisVersion: CAREER_COACH_ANALYSIS_VERSION,
          providerUsed: analysis.providerUsed || null,
          usageCount: usageData.monthlyCount,
        }, {merge: true});

        await clearCareerCoachReservation(userId, requestId);

        // 7) Aggregate analytics only — never personal content.
        try {
          await admin.firestore()
              .collection("analytics_events")
              .add({
                eventType: "career_coach_analysis_generated",
                userId,
                metadata: {
                  provider: analysis.providerUsed || null,
                  recommendationCount: analysis.recommendations.length,
                  readinessLevel: analysis.careerReadiness.level,
                  monthlyUsage: usageData.monthlyCount,
                },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
              });
        } catch (analyticsError) {
          console.error("generateCareerCoachAnalysis analytics error:", analyticsError);
        }

        return {
          cached: false,
          analysis: {
            careerReadiness: analysis.careerReadiness,
            careerFocus: analysis.careerFocus,
            recommendations: analysis.recommendations,
            analysisVersion: analysis.analysisVersion,
          },
          usage: usageData,
          generatedAt: timestamp.toDate().toISOString(),
          providerUsed: analysis.providerUsed || null,
        };
      } catch (error) {
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        console.error("generateCareerCoachAnalysis error:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Could not generate your career analysis. Please try again later."
        );
      }
    }
);

// ===============================================
// v9.0: USAGE HELPERS (Resume Review pattern)
// ===============================================

/**
 * Read the career-coach usage doc without incrementing. Month-aware reset.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @returns {Promise<object>} {monthlyCount, monthlyLimit, lastResetMonth}
 */
async function getCareerCoachUsage(userId) {
  try {
    const usageDoc = await admin.firestore()
        .collection("career_coach_usage")
        .doc(userId)
        .get();

    if (!usageDoc.exists) {
      return {
        monthlyCount: 0,
        monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
        lastResetMonth: null,
      };
    }

    const data = usageDoc.data();
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    if (data.lastResetMonth !== currentMonth) {
      return {
        monthlyCount: 0,
        monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
        lastResetMonth: currentMonth,
      };
    }

    return {
      monthlyCount: data.monthlyCount || 0,
      monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
      lastResetMonth: data.lastResetMonth,
    };
  } catch (error) {
    console.error("Error getting career coach usage:", error);
    return {
      monthlyCount: 0,
      monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
    };
  }
}

/**
 * Atomically check the monthly limit AND increment the quota, stamping a
 * per-request reservation (`pendingRequestId` / `pendingSince`) so a
 * crash/500 after consumption but before the AI-failure rollback can be
 * refunded by `compensateStaleCareerCoachQuota`.
 *
 * Mirrors `consumeResumeQuota` (functions/index.js) exactly.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - Unique id for this analysis request
 * @returns {Promise<object>} Usage data (post-increment)
 * @throws {HttpsError#resource-exhausted} when the monthly limit is reached
 */
async function consumeCareerCoachQuota(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("career_coach_usage")
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
        // First analysis this month — create the usage doc, already consumed.
        const firstUsage = {
          monthlyCount: 1,
          monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
          lastAnalyzedAt: timestamp,
          lastResetMonth: currentMonth,
          ...reservationFields,
        };
        transaction.set(usageRef, firstUsage);
        return {
          monthlyCount: 1,
          monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
          lastResetMonth: currentMonth,
        };
      }

      const data = usageDoc.data();
      const lastResetMonth = data.lastResetMonth || "";

      // New month → reset the counter to 1 (this call is the first analysis).
      if (lastResetMonth !== currentMonth) {
        const resetData = {
          monthlyCount: 1,
          monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
          lastAnalyzedAt: timestamp,
          lastResetMonth: currentMonth,
          ...reservationFields,
        };
        transaction.update(usageRef, resetData);
        return {
          monthlyCount: 1,
          monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
          lastResetMonth: currentMonth,
        };
      }

      // Same month → enforce the limit inside the transaction (atomic).
      const monthlyCount = data.monthlyCount || 0;
      if (monthlyCount >= CAREER_COACH_MONTHLY_LIMIT) {
        throw new admin.functions.https.HttpsError(
            "resource-exhausted",
            `Career Coach monthly limit reached (${CAREER_COACH_MONTHLY_LIMIT} analyses/month). Resets next month.`,
            {
              usage: {
                monthlyCount,
                monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
                lastResetMonth: currentMonth,
              },
            }
        );
      }

      const updatedData = {
        monthlyCount: monthlyCount + 1,
        monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
        lastAnalyzedAt: timestamp,
        lastResetMonth: currentMonth,
        ...reservationFields,
      };
      transaction.update(usageRef, updatedData);
      return {
        monthlyCount: updatedData.monthlyCount,
        monthlyLimit: CAREER_COACH_MONTHLY_LIMIT,
        lastResetMonth: currentMonth,
      };
    });
  } catch (error) {
    console.error("Error consuming career coach quota:", error);
    throw error;
  }
}

/**
 * Clear this request's reservation on the usage doc. Called after a
 * successful analysis (the credit is kept — the reservation is just
 * un-stamped so the compensation sweep never refunds a delivered analysis).
 * Idempotent and best-effort: a stale reservation is harmless because the
 * daily sweep refunds it.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function clearCareerCoachReservation(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("career_coach_usage")
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
    console.error("Error clearing career coach reservation:", clearError);
  }
}

/**
 * Refund the consumed quota when the AI analysis call failed. Decrements the
 * count and clears THIS request's reservation in the same transaction so the
 * compensation sweep never double-refunds. Best-effort, never throws.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function rollbackCareerCoachUsage(userId, requestId) {
  const usageRef = admin.firestore()
      .collection("career_coach_usage")
      .doc(userId);

  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      if (!usageDoc.exists) return;

      const data = usageDoc.data();
      const lastResetMonth = data.lastResetMonth || "";
      if (lastResetMonth !== currentMonth) return; // already reset

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
    console.error("Error rolling back career coach usage:", rollbackError);
  }
}

// ===============================================
// v9.0: PER-MINUTE RATE LIMITING (SEC-2 fix)
// ===============================================

/**
 * SEC-2: check per-minute rate limiting for Career Coach calls.
 *
 * Uses the `career_coach_rate_limits` collection (separate from `ai_rate_limits`
 * used by `askAI` to avoid cross-contamination). Stores an array of timestamps
 * within the 60-second window. Fail-open on errors so a rate-limit store outage
 * never blocks legitimate users.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @returns {Promise<{allowed: boolean, retryAfter: number}>}
 */
async function checkCareerCoachRateLimit(userId) {
  const rateLimitRef = admin.firestore()
      .collection("career_coach_rate_limits")
      .doc(userId);

  const now = Date.now();
  const windowStart = now - CAREER_COACH_RATE_LIMIT_WINDOW_MS;

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

      // Remove old timestamps outside window
      timestamps = timestamps.filter((ts) => ts > windowStart);

      if (timestamps.length >= CAREER_COACH_RATE_LIMIT_MAX) {
        const oldestTimestamp = Math.min(...timestamps);
        const retryAfter = Math.ceil(
            (oldestTimestamp + CAREER_COACH_RATE_LIMIT_WINDOW_MS - now) / 1000
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
    console.error("Error checking career coach rate limit:", error);
    // On error, allow the request (fail open)
    return {allowed: true, retryAfter: 0};
  }
}

// ===============================================
// v9.0: CRASH-SAFE QUOTA COMPENSATION (daily)
// ===============================================

/**
 * v9.0: refund career-coach credits whose reservation was left stale by a
 * crash/500 in `generateCareerCoachAnalysis`.
 *
 * If a function container dies AFTER `consumeCareerCoachQuota` incremented
 * the count but BEFORE the AI-failure rollback could run, the usage doc
 * carries a `pendingRequestId` / `pendingSince` reservation with no one left
 * to clear it. This daily sweep refunds those credits so the user is never
 * permanently charged for an analysis that was never delivered.
 *
 * Runs daily at 04:10 UTC (just after the Resume Review sweep at 04:00).
 * Safety contract mirrors `compensateStaleResumeQuota`:
 *   - Only touches docs where `pendingSince` is older than 24h.
 *   - Decrement + reservation clear happen atomically per user.
 *   - Never clears below 0; never touches docs without a reservation.
 *   - Aggregate log only (userId + refunded count) — never analysis content.
 */
exports.compensateStaleCareerCoachQuota = onSchedule(
    {
      schedule: "every day 04:10",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - CAREER_COACH_RESERVATION_STALE_HOURS * 60 * 60 * 1000
      );

      console.log(
          `compensateStaleCareerCoachQuota: refunding reservations older than ` +
          `${cutoff.toDate().toISOString()}`
      );

      let compensated = 0;

      try {
        const snapshot = await admin.firestore()
            .collection("career_coach_usage")
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
                `compensateStaleCareerCoachQuota: failed for user ${userId}:`,
                perUserError
            );
          }
        }

        console.log(
            `compensateStaleCareerCoachQuota: refunded ${compensated} stale credit(s)`
        );
      } catch (error) {
        console.error("compensateStaleCareerCoachQuota error:", error);
      }
    }
);
