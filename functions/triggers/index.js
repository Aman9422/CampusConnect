/**
 * CampusConnect — Firestore Trigger Functions.
 *
 * All `onDocumentWritten` / `onDocumentCreated` triggers live here.
 * Each trigger handles a specific document-level event and delegates to
 * the appropriate engine/worker module.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onDocumentWritten, onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const {refreshRecommendationsForStudent} = require("../recommendations/refresh");
const {recomputeEngagementSummary} = require("../helpers/engagement");
const {
  logAnalyticsEvent,
  logUserActivity,
  maybeCreateNotification,
  isPortfolioMetadataOnlyChange,
  portfolioContentChanged,
} = require("../helpers/shared");

// ===============================================
// PROFILE UPDATE TRIGGER
// ===============================================

exports.onProfileUpdatedRefreshAI = onDocumentWritten(
    {
      document: "users/{userId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const userId = event.params.userId;
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;

      if (!after) return;
      if (after.role !== "student" || after.profileCompleted !== true) return;

      // v8.9 (Phase 10): skip ONLY pure portfolio metadata flutters.
      if (isPortfolioMetadataOnlyChange(before, after)) return;

      const updatedAtChanged = () => {
        if (!before.updatedAt || !after.updatedAt) {
          return before.updatedAt !== after.updatedAt;
        }
        const beforeMillis = typeof before.updatedAt.toMillis === "function"
            ? before.updatedAt.toMillis()
            : Date.parse(before.updatedAt);
        const afterMillis = typeof after.updatedAt.toMillis === "function"
            ? after.updatedAt.toMillis()
            : Date.parse(after.updatedAt);
        return beforeMillis !== afterMillis;
      };
      const changed =
        !before ||
        JSON.stringify(before.skills || []) !== JSON.stringify(after.skills || []) ||
        before.careerInterest !== after.careerInterest ||
        before.department !== after.department ||
        before.graduationYear !== after.graduationYear ||
        JSON.stringify(before.career || {}) !== JSON.stringify(after.career || {}) ||
        updatedAtChanged() ||
        portfolioContentChanged(before, after);

      if (!changed) return;

      try {
        await refreshRecommendationsForStudent(userId, after);
        await logUserActivity(userId, "profileUpdated", 3, {source: "profile_trigger"});
        await recomputeEngagementSummary(userId, after);

        // v9.0 (IMP-13): Proactively invalidate the Career Coach cache when
        // meaningful career data changes.
        try {
          await admin.firestore()
              .collection("users")
              .doc(userId)
              .collection("career_coach")
              .doc("summary")
              .set({
                profileDataVersion: "",
                cacheInvalidatedAt: admin.firestore.Timestamp.now(),
              }, {merge: true});
        } catch (ccError) {
          console.error("onProfileUpdatedRefreshAI: CC cache invalidation error:", ccError);
        }
      } catch (error) {
        console.error("onProfileUpdatedRefreshAI error:", error);
      }
    }
);

// ===============================================
// RESUME REVIEW CREATED TRIGGER
// ===============================================

exports.onResumeReviewCreatedRefreshMatches = onDocumentCreated(
    {
      document: "users/{userId}/resumeReviews/{reviewId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const userId = event.params.userId;
      const resumeData = event.data.data();

      try {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) return;
        const userData = userDoc.data();
        const isStudent = userData.role === "student";

        const hasPortfolioResume = !!(userData.portfolio && userData.portfolio.resume);

        if (hasPortfolioResume) {
          const atsScore = Number.isInteger(resumeData.atsScore)
              ? resumeData.atsScore
              : null;
          const portfolioResumeMerge = {
            "portfolio.resume.reviewCount": admin.firestore.FieldValue.increment(1),
            "portfolio.resume.lastReviewAt": admin.firestore.Timestamp.now(),
            "portfolio.resume.updatedAt": admin.firestore.Timestamp.now(),
          };
          if (atsScore !== null) {
            portfolioResumeMerge["portfolio.resume.latestATSScore"] = atsScore;
          }
          await admin.firestore().collection("users").doc(userId)
              .set(portfolioResumeMerge, {merge: true});
        }

        if (isStudent) {
          await refreshRecommendationsForStudent(userId, userData, {resumeData});
        }

        await logUserActivity(userId, "resumeReviewed", 5, {
          reviewId: event.params.reviewId,
          atsScore: resumeData.atsScore || 0,
        });
        await recomputeEngagementSummary(userId, userData);
      } catch (error) {
        console.error("onResumeReviewCreatedRefreshMatches error:", error);
      }
    }
);

// ===============================================
// OPPORTUNITY POSTED TRIGGER
// ===============================================

exports.onOpportunityPostedNotifyStudents = onDocumentCreated(
    {
      document: "opportunities/{opportunityId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const opportunityId = event.params.opportunityId;
      const opportunity = event.data.data();

      try {
        const studentsSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "==", "student")
            .where("profileCompleted", "==", true)
            .get();

        if (studentsSnapshot.empty) return;

        const now = admin.firestore.Timestamp.now();
        let batch = admin.firestore().batch();
        let writes = 0;

        for (const student of studentsSnapshot.docs) {
          const notificationRef = admin.firestore()
              .collection("users")
              .doc(student.id)
              .collection("notifications")
              .doc();

          batch.set(notificationRef, {
            type: "newJobPost",
            title: "New Job Opportunity",
            body: `${opportunity.title || "Role"} at ${opportunity.company || "Company"}`,
            data: {opportunityId},
            isRead: false,
            priority: "medium",
            createdAt: now,
          });

          writes++;
          if (writes >= 400) {
            await batch.commit();
            batch = admin.firestore().batch();
            writes = 0;
          }
        }

        if (writes > 0) {
          await batch.commit();
        }
      } catch (error) {
        console.error("onOpportunityPostedNotifyStudents error:", error);
      }
    }
);

// ===============================================
// MENTORSHIP TRIGGERS
// ===============================================

exports.onMentorshipRequestCreated = onDocumentCreated(
    {
      document: "mentorship_requests/{requestId}",
      region: "us-central1",
      maxInstances: 5,
    },
    async (event) => {
      const requestId = event.params.requestId;
      const request = event.data.data();

      if (!request || !request.alumniId) return;

      try {
        const notificationRef = admin.firestore()
            .collection("users")
            .doc(request.alumniId)
            .collection("notifications")
            .doc(`mentorship_requested_${requestId}`);

        await notificationRef.set({
          type: "mentorshipRequested",
          title: "New Mentorship Request",
          body: `${request.studentName || "A student"} has requested your mentorship`,
          data: {requestId},
          isRead: false,
          priority: "medium",
          createdAt: admin.firestore.Timestamp.now(),
        });
      } catch (error) {
        console.error("onMentorshipRequestCreated error:", error);
      }
    }
);

exports.onMentorshipRequestResponseNotifyStudent = onDocumentWritten(
    {
      document: "mentorship_requests/{requestId}",
      region: "us-central1",
      maxInstances: 5,
    },
    async (event) => {
      const requestId = event.params.requestId;
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;

      if (!before || !after) return;
      if (before.status === after.status) return;
      if (after.status !== "accepted" && after.status !== "rejected") return;
      if (!after.studentId) return;

      try {
        const isAccepted = after.status === "accepted";
        const data = {requestId};
        if (isAccepted && after.chatId) {
          data.chatId = after.chatId;
        }

        const notificationRef = admin.firestore()
            .collection("users")
            .doc(after.studentId)
            .collection("notifications")
            .doc(`mentorship_response_${requestId}`);

        await notificationRef.set({
          type: isAccepted ? "mentorshipAccepted" : "mentorshipRejected",
          title: isAccepted
              ? "Mentorship Request Accepted!"
              : "Mentorship Request Response",
          body: isAccepted
              ? `${after.alumniName || "Your mentor"} has accepted your mentorship request`
              : `${after.alumniName || "Your mentor"} has declined your mentorship request`,
          data,
          isRead: false,
          priority: "medium",
          createdAt: admin.firestore.Timestamp.now(),
        });
      } catch (error) {
        console.error("onMentorshipRequestResponseNotifyStudent error:", error);
      }
    }
);

// ===============================================
// CHAT MESSAGE TRIGGER
// ===============================================

exports.onChatMessageCreated = onDocumentCreated(
    {
      document: "chats/{chatId}/messages/{messageId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const {chatId, messageId} = event.params;
      const message = event.data.data();

      if (!message || !message.senderId) return;

      try {
        // v8.4.3 (MB8): skip messages backfilled by batch operations
        const sentAt = message.sentAt;
        const expirationCutoff = admin.firestore.Timestamp.fromMillis(
            Date.now() - 30 * 24 * 60 * 60 * 1000
        );
        if (sentAt && sentAt.toMillis() < expirationCutoff.toMillis()) return;

        const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
        if (!chatDoc.exists) return;
        const chat = chatDoc.data();

        const participantIds = chat.participantIds || [];
        const recipientId = participantIds.find((id) => id !== message.senderId);
        if (!recipientId) return;

        const senderName = message.senderName || "Someone";
        const text = message.text || "";
        const preview = text.length > 50 ? `${text.substring(0, 50)}...` : text;

        const notificationRef = admin.firestore()
            .collection("users")
            .doc(recipientId)
            .collection("notifications")
            .doc(`new_message_${messageId}`);

        await notificationRef.set({
          type: "newMessage",
          title: `New Message from ${senderName}`,
          body: preview,
          data: {chatId},
          isRead: false,
          priority: "low",
          createdAt: admin.firestore.Timestamp.now(),
        });
      } catch (error) {
        console.error("onChatMessageCreated error:", error);
      }
    }
);
