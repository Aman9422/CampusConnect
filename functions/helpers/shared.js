/**
 * CampusConnect — Shared helper utilities.
 *
 * Pure utility functions used across multiple Cloud Function modules
 * (triggers, schedulers, AI callables). No Cloud Function exports here.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const admin = require("firebase-admin");

// ===============================================
// INPUT SANITIZATION
// ===============================================

/**
 * v9.0 (IMP-12): Sanitize user input before sending to AI providers.
 *
 * Strips ASCII control characters (except newlines/tabs) and zero-width
 * Unicode characters that could be used for invisible prompt injection.
 * Preserves normal Unicode characters, URLs, Markdown and code (it never
 * alters the semantic content). Also caps the total length so an oversized
 * resume or message cannot blow up the model context window. Truncation cuts
 * on a UTF-16 code-unit boundary and appends a clear "[truncated]…" marker.
 *
 * @param {string} text - Raw user input
 * @param {number} [maxLength=12000] - Maximum allowed length
 * @returns {string} Sanitized text safe for AI prompt insertion
 */
function sanitizeAIInput(text, maxLength = 12000) {
  if (typeof text !== "string") return "";
  // Strip ASCII control characters (0x00-0x1F except \n \t, plus 0x7F)
  // and zero-width Unicode characters that could be used for invisible
  // instruction injection.
  let sanitized = text
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
      .replace(/[\u200B\u200C\u200D\uFEFF\u200E\u200F\u202A-\u202E\u2066-\u2069]/g, "")
      .trim();

  if (sanitized.length > maxLength) {
    sanitized = `${sanitized.slice(0, maxLength)}…[truncated]`;
  }
  return sanitized;
}

// ===============================================
// ANALYTICS EVENT LOGGING
// ===============================================

/**
 * Log analytics events to Firestore (VERSION 4)
 *
 * Stores events for tracking AI usage, placements, and other activities.
 *
 * @param {object} eventData - Event data {eventType, userId, metadata}
 * @return {Promise<void>}
 */
async function logAnalyticsEvent(eventData) {
  try {
    await admin.firestore()
        .collection("analytics_events")
        .add({
          ...eventData,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
  } catch (error) {
    // Don't fail the request if analytics logging fails
    console.error("Error logging analytics event:", error);
  }
}

// ===============================================
// BATCH DELETE
// ===============================================

/**
 * v8.8 (P5): delete a Firestore document list in safe batches.
 *
 * Splits into chunks of 400 (well under the 500-write batch cap) so large
 * histories never exceed Firestore limits. Idempotent: missing docs are
 * simply skipped by a delete.
 *
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} docs
 * @returns {Promise<number>} Number of docs deleted
 */
async function deleteDocsInBatches(docs) {
  let deleted = 0;
  for (let i = 0; i < docs.length; i += 400) {
    const chunk = docs.slice(i, i + 400);
    const batch = admin.firestore().batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

// ===============================================
// NOTIFICATIONS
// ===============================================

/**
 * Create a notification only if no duplicate of the same type was created
 * within the last 20 hours.
 */
async function maybeCreateNotification(userId, type, payload) {
  const recentCutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 20 * 60 * 60 * 1000
  );

  const recent = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .where("type", "==", type)
      .where("createdAt", ">=", recentCutoff)
      .limit(1)
      .get();

  if (!recent.empty) return;

  await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type,
        title: payload.title || "Notification",
        body: payload.body || "",
        data: payload.data || {},
        isRead: false,
        priority: payload.priority || "low",
        createdAt: admin.firestore.Timestamp.now(),
      });
}

// ===============================================
// DAY-KEY HELPERS (IMP-9)
// ===============================================

/**
 * Return a UTC day key ("YYYY-M-D", no zero padding) for a Date. Used to
 * track the streak aggregate without scanning the full activity history.
 */
function dayKey(date) {
  return `${date.getUTCFullYear()}-${date.getUTCMonth() + 1}-${date.getUTCDate()}`;
}

/**
 * Return the UTC day key for the day immediately before the given day key.
 */
function previousDayKey(dayKeyStr) {
  const [y, m, d] = dayKeyStr.split("-").map(Number);
  return dayKey(new Date(Date.UTC(y, m - 1, d - 1)));
}

// ===============================================
// ACTIVITY LOGGING
// ===============================================

/**
 * Log a user activity event (engagement system).
 *
 * IMP-9: also maintains running aggregates (activityPoints, dailyStreak,
 * streakLastActiveKey, lastActiveAt) on the engagement summary doc. The
 * activity write and the aggregate update happen in a single atomic
 * transaction so a retried invocation cannot double-count points or corrupt
 * the streak (idempotency).
 */
async function logUserActivity(userId, eventType, points, metadata = {}) {
  const firestore = admin.firestore();
  const activityRef = firestore
      .collection("users")
      .doc(userId)
      .collection("activities")
      .doc();
  const summaryRef = firestore
      .collection("users")
      .doc(userId)
      .collection("engagement_summary")
      .doc("summary");

  try {
    // Read-modify-write in a single transaction so dailyStreak is maintained
    // (and never double-counted) for arbitrarily long streaks. The activity
    // write and the aggregate update commit atomically: a retried invocation
    // cannot log the activity twice or corrupt the streak.
    await firestore.runTransaction(async (tx) => {
      const summarySnap = await tx.get(summaryRef);
      const existing = summarySnap.exists ? summarySnap.data() : {};
      const todayKey = dayKey(new Date());
      const lastKey = existing.streakLastActiveKey;
      const lastStreak = existing.dailyStreak || 0;
      const nextStreak = lastKey === todayKey
          ? lastStreak
          : (lastKey === previousDayKey(todayKey) ? lastStreak + 1 : 1);

      tx.set(activityRef, {
        userId,
        eventType,
        points,
        metadata,
        occurredAt: admin.firestore.Timestamp.now(),
      });
      tx.set(summaryRef, {
        activityPoints: admin.firestore.FieldValue.increment(points),
        lastActiveAt: admin.firestore.Timestamp.now(),
        dailyStreak: nextStreak,
        streakLastActiveKey: todayKey,
      }, {merge: true});
    });
  } catch (error) {
    console.error("logUserActivity error:", error);
    throw error;
  }
}

// ===============================================
// PORTFOLIO CHANGE DETECTION
// ===============================================

/**
 * v8.4.3 (MB5) + v8.9 (Phase 10): true when a `users/{userId}` write only
 * changed the `portfolio` nested map AND that change is limited to the
 * portfolio's own `metadata.updatedAt` stamp (a pure metadata flutter).
 *
 * v8.9 refinement: the v8.4.3 guard skipped ALL portfolio-only writes, which
 * also skipped recommendation-relevant portfolio content changes (skills,
 * projects, preferences, resume ATS metadata, languages, certifications,
 * experience). Phase 10 requires recommendations to refresh when those
 * meaningful signals change. This version preserves MB5's
 * write-amplification fix — harmless saves that only stamp `updatedAt` still
 * skip the refresh — while genuine portfolio content edits fall through so
 * the profile trigger can refresh.
 */
function isPortfolioMetadataOnlyChange(before, after) {
  if (!before || !after) return false;

  const beforePortfolio = before.portfolio ?? null;
  const afterPortfolio = after.portfolio ?? null;
  if (JSON.stringify(beforePortfolio) === JSON.stringify(afterPortfolio)) {
    return false;
  }

  // Every top-level key other than portfolio/metadata must be byte-identical.
  for (const key of Object.keys(after)) {
    if (key === "portfolio" || key === "metadata") continue;
    const beforeValue = before[key] ?? null;
    const afterValue = after[key] ?? null;
    if (JSON.stringify(beforeValue) !== JSON.stringify(afterValue)) {
      return false;
    }
  }

  // Portfolio changed, but only inside its own metadata — no
  // recommendation-relevant content changed.
  const beforeContent = {...(beforePortfolio ?? {})};
  const afterContent = {...(afterPortfolio ?? {})};
  delete beforeContent.metadata;
  delete afterContent.metadata;
  return JSON.stringify(beforeContent) === JSON.stringify(afterContent);
}

/**
 * v8.9 (Phase 10): true when the portfolio map changed in a way that
 * affects recommendations (skills, projects, preferences, resume ATS
 * metadata, languages, certifications, experience) — i.e. any portfolio
 * change that is NOT a pure metadata flutter.
 */
function portfolioContentChanged(before, after) {
  if (!before || !after) return false;
  const beforePortfolio = before.portfolio ?? null;
  const afterPortfolio = after.portfolio ?? null;
  if (JSON.stringify(beforePortfolio) === JSON.stringify(afterPortfolio)) {
    return false;
  }
  const beforeContent = {...(beforePortfolio ?? {})};
  const afterContent = {...(afterPortfolio ?? {})};
  delete beforeContent.metadata;
  delete afterContent.metadata;
  return JSON.stringify(beforeContent) !== JSON.stringify(afterContent);
}

module.exports = {
  sanitizeAIInput,
  logAnalyticsEvent,
  deleteDocsInBatches,
  maybeCreateNotification,
  logUserActivity,
  isPortfolioMetadataOnlyChange,
  portfolioContentChanged,
  // IMP-9: engagement aggregate helpers
  dayKey,
  previousDayKey,
};
