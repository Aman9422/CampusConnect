/**
 * CampusConnect — Scheduled Cloud Functions (cron jobs).
 *
 * v9.2 (P1): this module now owns ALL scheduled functions, including the
 * consolidated AI quota compensation sweep (`compensateStaleAIQuotas`).
 * Previously the three per-feature sweeps lived next to their callable
 * modules (careerCoach.js, ai/resumeReview.js, ai/deepAnalysis.js); they were
 * consolidated into one job here that calls the same `quota.runFeatureSweep`.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {recomputeEngagementSummary} = require("../helpers/engagement");
const {maybeCreateNotification} = require("../helpers/shared");
// v9.2 (P1): the three per-feature quota compensation sweeps were consolidated
// into the single `compensateStaleAIQuotas` job below. It calls the SAME
// unchanged `quota.runFeatureSweep(feature, cutoff)` the old jobs called, so
// refund semantics, stale detection, cutoff, limits, reservations and
// no-double-charge protection are preserved exactly.
const quota = require("../ai/quota");

// ===============================================
// CONSTANTS
// ===============================================

const INACTIVITY_REMINDER_HOURS = 48;

/**
 * v9.2 (P1): age after which an un-cleared reservation is considered stale.
 * Identical to the previous per-feature sweeps' 24h safety window (an AI call
 * can take up to the 120s callable timeout, so 24h is generous for genuine
 * in-flight requests and never refunds a live request).
 */
const QUOTA_RESERVATION_STALE_HOURS = 24;

/**
 * v9.2 (P1): the AI features whose stale reservations this consolidated sweep
 * refunds. Order is deterministic; each feature is swept independently so one
 * feature's failure cannot block the others.
 */
const QUOTA_SWEEP_FEATURES = ["resumeReview", "careerCoach", "aiAnalysis"];

/**
 * v9.2.4 (E-3): bulk-write chunk size for opportunity expiry.
 *
 * Firestore rejects a commit containing more than 500 operations, so the
 * previous implementation - which accumulated EVERY expired opportunity into
 * one `batch()` and committed once - threw as soon as the hourly sweep found
 * more than 500 expired documents. The commit is atomic, so on failure NOTHING
 * was expired and the run was lost until the next hour. 400 matches the chunk
 * size already used by `onOpportunityPostedNotifyStudents`
 * (`functions/triggers/index.js`) and `deleteDocsInBatches`
 * (`functions/helpers/shared.js`).
 */
const OPPORTUNITY_EXPIRY_BATCH_SIZE = 400;

/**
 * v9.2.4 (E-3): hard cap on batches per run.
 *
 * The sweep is hourly and idempotent, so anything not expired this run is
 * picked up by the next one. The cap keeps the invocation well inside the
 * Cloud Functions v2 timeout instead of looping unboundedly if a very large
 * backlog ever accumulates.
 */
const OPPORTUNITY_EXPIRY_MAX_BATCHES = 50;

// ===============================================
// EXPORTS
// ===============================================

/**
 * Auto-expire opportunities whose deadline has passed.
 * Runs every 60 minutes.
 */
exports.autoExpireOpportunities = onSchedule(
    {
      schedule: "every 60 minutes",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        const now = admin.firestore.Timestamp.now();
        const opportunities = admin.firestore().collection("opportunities");

        // v9.2.4 (E-3): the previous implementation read EVERY expired
        // opportunity in one unbounded query and committed them in ONE batch.
        // Firestore caps a commit at 500 operations and the commit is atomic,
        // so more than 500 expired documents meant the entire sweep failed and
        // NOTHING was expired until the next hour.
        //
        // The loop below reads at most OPPORTUNITY_EXPIRY_BATCH_SIZE
        // still-active expired documents, marks them inactive, and repeats.
        // It is self-advancing and needs no cursor: every processed document
        // stops matching `isActive == true`, so the next query returns the next
        // chunk. Termination is therefore guaranteed by the write itself, and
        // the job stays idempotent - a re-run finds nothing left to expire.
        let expiredCount = 0;

        for (
          let batchIndex = 0;
          batchIndex < OPPORTUNITY_EXPIRY_MAX_BATCHES;
          batchIndex++
        ) {
          const snapshot = await opportunities
              .where("isActive", "==", true)
              .where("applicationDeadline", "<=", now)
              .limit(OPPORTUNITY_EXPIRY_BATCH_SIZE)
              .get();

          if (snapshot.empty) break;

          const batch = admin.firestore().batch();
          for (const doc of snapshot.docs) {
            batch.update(doc.ref, {
              isActive: false,
              expiredAt: now,
              updatedAt: now,
            });
          }
          await batch.commit();
          expiredCount += snapshot.docs.length;

          // A short chunk means the expired backlog is drained.
          if (snapshot.docs.length < OPPORTUNITY_EXPIRY_BATCH_SIZE) break;
        }

        if (expiredCount === 0) return;

        console.log(
            `autoExpireOpportunities: expired ${expiredCount} opportunity(ies)`
        );

        // Only reachable when every batch ran full - the backlog is larger
        // than one invocation may drain, and the next hourly run continues.
        if (expiredCount >=
            OPPORTUNITY_EXPIRY_BATCH_SIZE * OPPORTUNITY_EXPIRY_MAX_BATCHES) {
          console.warn(
              "autoExpireOpportunities: per-run batch cap reached; remaining " +
              "expired opportunities will be handled by the next hourly run"
          );
        }
      } catch (error) {
        console.error("autoExpireOpportunities error:", error);
      }
    }
);

/**
 * Send inactivity reminders for chats and mentorship requests.
 * Runs daily at 09:00 UTC.
 */
exports.sendInactivityReminders = onSchedule(
    {
      schedule: "every day 09:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        const now = Date.now();
        const inactivityCutoff = admin.firestore.Timestamp.fromMillis(
            now - INACTIVITY_REMINDER_HOURS * 60 * 60 * 1000
        );

        // 1) Inactive chats with unread messages
        const chatsSnapshot = await admin.firestore()
            .collection("chats")
            .where("lastMessageAt", "<", inactivityCutoff)
            .get();

        for (const chatDoc of chatsSnapshot.docs) {
          const chat = chatDoc.data();
          const unreadCount = chat.unreadCount || {};
          const participantIds = chat.participantIds || [];

          for (const participantId of participantIds) {
            if ((unreadCount[participantId] || 0) <= 0) continue;

            await maybeCreateNotification(participantId, "inactiveChatReminder", {
              title: "Chat Reminder",
              body: "You have unread chat messages waiting for your reply.",
              data: {chatId: chatDoc.id},
              priority: "low",
            });
          }
        }

        // 2) Pending mentorship requests older than 3 days
        const mentorshipCutoff = admin.firestore.Timestamp.fromMillis(
            now - 3 * 24 * 60 * 60 * 1000
        );
        const pendingMentorships = await admin.firestore()
            .collection("mentorship_requests")
            .where("status", "==", "pending")
            .where("createdAt", "<=", mentorshipCutoff)
            .get();

        for (const requestDoc of pendingMentorships.docs) {
          const request = requestDoc.data();
          if (request.alumniId) {
            await maybeCreateNotification(request.alumniId, "reminder", {
              title: "Mentorship Request Pending",
              body: `You have a pending request from ${request.studentName || "a student"}.`,
              data: {requestId: requestDoc.id},
              priority: "medium",
            });
          }
          if (request.studentId) {
            await maybeCreateNotification(request.studentId, "reminder", {
              title: "Mentorship Follow-up",
              body: "Your mentorship request is still pending. Try sending a concise follow-up.",
              data: {requestId: requestDoc.id},
              priority: "low",
            });
          }
        }
      } catch (error) {
        console.error("sendInactivityReminders error:", error);
      }
    }
);

/**
 * IMP-8: cursor-based pagination size for bulk user queries.
 */
const USER_PAGE_SIZE = 50;

/**
 * Recompute engagement scores for all completed profiles.
 * Runs daily at 01:00 UTC.
 *
 * IMP-8: paginates through users in batches of 50 (cursor-based) so the
 * function never loads every user doc into memory at once. Each page is
 * processed fully before the next page is fetched.
 *
 * IMP-9: `recomputeEngagementSummary` now uses materialized aggregates
 * (totalPoints, dailyStreak maintained by `logUserActivity`) when available,
 * falling back to a full 250-doc scan only for users who don't have them yet.
 */
exports.recomputeEngagementScores = onSchedule(
    {
      schedule: "every day 01:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        let processed = 0;
        let lastDoc = null;

        // Cursor-based pagination: fetch USER_PAGE_SIZE users at a time.
        for (;;) {
          let query = admin.firestore()
              .collection("users")
              .where("profileCompleted", "==", true)
              .orderBy(admin.firestore.FieldPath.documentId())
              .limit(USER_PAGE_SIZE);

          if (lastDoc) {
            query = query.startAfter(lastDoc.id);
          }

          const page = await query.get();
          if (page.empty) break;

          for (const userDoc of page.docs) {
            await recomputeEngagementSummary(userDoc.id, userDoc.data());
            processed++;
          }

          lastDoc = page.docs[page.docs.length - 1];
          if (page.docs.length < USER_PAGE_SIZE) break; // last page
        }

        console.log(`recomputeEngagementScores: processed ${processed} users`);
      } catch (error) {
        console.error("recomputeEngagementScores error:", error);
      }
    }
);
/**
 * v9.2 (P1): CONSOLIDATED AI quota compensation sweep.
 *
 * Previously three separate Scheduler jobs existed:
 *   - compensateStaleResumeQuota      (functions/ai/resumeReview.js)
 *   - compensateStaleCareerCoachQuota (functions/careerCoach.js)
 *   - compensateStaleAIAnalysisQuota  (functions/ai/deepAnalysis.js)
 *
 * They are consolidated here into ONE daily job that runs the SAME unchanged
 * `quota.runFeatureSweep(feature, cutoff)` for each feature. This preserves
 * refund/compensation behaviour, stale-request detection, cutoff semantics,
 * quota limits, reservation logic, rollback behaviour and no-double-charge
 * protection exactly — only the scheduling envelope changed (3 → 1).
 *
 * Each feature is swept in its own try/catch so a failure in one feature can
 * never prevent compensation for the other two.
 *
 * Runs daily at 04:00 UTC (after recomputeEngagementScores @01:00, before
 * sendInactivityReminders @09:00; no clash with the hourly expiry job).
 */
exports.compensateStaleAIQuotas = onSchedule(
    {
      schedule: "every day 04:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - QUOTA_RESERVATION_STALE_HOURS * 60 * 60 * 1000
      );

      let totalRefunded = 0;
      for (const feature of QUOTA_SWEEP_FEATURES) {
        try {
          const refunded = await quota.runFeatureSweep(feature, cutoff);
          totalRefunded += refunded;
          console.log(
              `compensateStaleAIQuotas(${feature}): refunded ${refunded} stale reservation(s)`
          );
        } catch (error) {
          // Isolate feature failures — one feature must not block the others.
          console.error(`compensateStaleAIQuotas(${feature}) error:`, error);
        }
      }

      console.log(
          `compensateStaleAIQuotas: sweep complete (${totalRefunded} total refunded)`
      );
    }
);
