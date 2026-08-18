/**
 * CampusConnect — Scheduled Cloud Functions (cron jobs).
 *
 * All `onSchedule` functions live here EXCEPT the quota compensation sweeps
 * (those live next to their respective callable modules for cohesion).
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {recomputeEngagementSummary} = require("../helpers/engagement");
const {maybeCreateNotification} = require("../helpers/shared");

// ===============================================
// CONSTANTS
// ===============================================

const INACTIVITY_REMINDER_HOURS = 48;

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
        const snapshot = await admin.firestore()
            .collection("opportunities")
            .where("isActive", "==", true)
            .where("applicationDeadline", "<=", now)
            .get();

        if (snapshot.empty) return;

        const batch = admin.firestore().batch();
        for (const doc of snapshot.docs) {
          batch.update(doc.ref, {
            isActive: false,
            expiredAt: now,
            updatedAt: now,
          });
        }
        await batch.commit();
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
