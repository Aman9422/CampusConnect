/**
 * CampusConnect — AI Chat History Deletion + Retention Cleanup.
 *
 * Handles:
 *   - `deleteAIHistory` — delete the authenticated user's AI chat history
 *   - `cleanupExpiredAIConversations` — daily scheduled cleanup of expired data
 *
 * IMP-11: legacy `ai_conversations` writes removed from askAI. The cleanup
 * scheduler still cleans the legacy collection during the transition window.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {deleteDocsInBatches} = require("../helpers/shared");

// ===============================================
// CONSTANTS
// ===============================================

/** v8.8 (P6): retention window for expired AI conversations (days). */
const AI_RETENTION_DAYS = parseInt(process.env.AI_RETENTION_DAYS || "90", 10);

// ===============================================
// EXPORTS
// ===============================================

/**
 * v8.8 (P5): delete the authenticated user's own AI chat history.
 *
 * Deletes BOTH stores:
 *   - users/{uid}/ai_interactions/*  (client-facing chat history)
 *   - ai_conversations/*             (legacy askAI server store, owner-scoped)
 *
 * Ownership is authoritative: identity comes from `request.auth.uid` only,
 * never from a client-supplied userId. Deletes are batched (max 490 writes
 * per batch) and idempotent.
 *
 * @returns {Promise<{deleted: number}>}
 */
exports.deleteAIHistory = onCall(
    {maxInstances: 10, timeoutSeconds: 120},
    async (request) => {
      const userId = request.auth?.uid;
      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to delete your AI chat history."
        );
      }

      try {
        let deleted = 0;

        // 1) users/{uid}/ai_interactions (client-facing history).
        const interactionsSnapshot = await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("ai_interactions")
            .get();

        deleted += await deleteDocsInBatches(interactionsSnapshot.docs);

        // 2) legacy ai_conversations owned by this user.
        const conversationsSnapshot = await admin.firestore()
            .collection("ai_conversations")
            .where("userId", "==", userId)
            .get();

        deleted += await deleteDocsInBatches(conversationsSnapshot.docs);

        console.log(`deleteAIHistory: deleted ${deleted} docs for user ${userId}`);

        return {deleted};
      } catch (error) {
        console.error("deleteAIHistory error:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Could not delete your AI chat history. Please try again later."
        );
      }
    }
);

/**
 * v8.8 (P6): automatically remove expired AI conversation data.
 *
 * Runs daily and deletes ONLY:
 *   - users/{uid}/ai_interactions/* with createdAt < cutoff
 *   - ai_conversations/*            with timestamp < cutoff
 *
 * Retention period is configurable via AI_RETENTION_DAYS (default 90).
 */
exports.cleanupExpiredAIConversations = onSchedule(
    {
      schedule: "every day 03:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      const retentionDays = Number.isFinite(AI_RETENTION_DAYS) && AI_RETENTION_DAYS > 0
          ? AI_RETENTION_DAYS
          : 90;
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - retentionDays * 24 * 60 * 60 * 1000
      );

      console.log(
          `cleanupExpiredAIConversations: retentionDays=${retentionDays}, ` +
          `cutoff=${cutoff.toDate().toISOString()}`
      );

      let deleted = 0;

      try {
        const interactionsSnapshot = await admin.firestore()
            .collectionGroup("ai_interactions")
            .where("createdAt", "<", cutoff)
            .limit(5000)
            .get();
        deleted += await deleteDocsInBatches(interactionsSnapshot.docs);

        const conversationsSnapshot = await admin.firestore()
            .collection("ai_conversations")
            .where("timestamp", "<", cutoff)
            .limit(5000)
            .get();
        deleted += await deleteDocsInBatches(conversationsSnapshot.docs);

        console.log(
            `cleanupExpiredAIConversations: deleted ${deleted} expired docs ` +
            `(older than ${retentionDays} days)`
        );
      } catch (error) {
        console.error("cleanupExpiredAIConversations error:", error);
      }
    }
);
