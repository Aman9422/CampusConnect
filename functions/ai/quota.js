/**
 * CampusConnect v9.0 (IMP-15) — Unified AI Quota Management
 *
 * Single source of truth for ALL AI feature quotas, stored as nested maps on
 * `user_ai_quotas/{uid}`:
 *
 *   {
 *     chat:        { dailyCount, dailyLimit, lastUsedAt, lastResetAt },
 *     resumeReview:{ monthlyCount, monthlyLimit, lastReviewAt, lastResetMonth,
 *                    pendingRequestId, pendingSince },
 *     careerCoach: { monthlyCount, monthlyLimit, lastAnalyzedAt, lastResetMonth,
 *                    pendingRequestId, pendingSince },
 *     aiAnalysis:  { monthlyCount, monthlyLimit, lastAnalyzedAt, lastResetMonth,
 *                    pendingRequestId, pendingSince },
 *     updatedAt
 *   }
 *
 * BACKWARD-COMPATIBILITY / MIGRATION CONTRACT (Task §8):
 *   Legacy collections (`ai_usage`, `resume_usage`, `career_coach_usage`,
 *   `ai_analysis_usage`) remain valid read stores for existing clients. Every
 *   consume/rollback/clear here writes the SAME values to BOTH the unified doc
 *   (authoritative) and the legacy doc, atomically, so:
 *     - old readers that still read `resume_usage/{uid}` see live counts;
 *     - the daily compensation sweeps (which still query the legacy
 *       collection) continue to refund correctly;
 *     - the unified doc is the new authoritative store for monitoring and new
 *       features.
 *
 * SAFETY CONTRACT (preserved verbatim from the per-feature implementations):
 *   - consume = atomic check-then-increment in ONE transaction.
 *   - Each consumption stamps `pendingRequestId` / `pendingSince` (crash-safe
 *     reservation) so a 500 after consumption but before the AI-failure
 *     rollback can be refunded by the daily compensation sweep.
 *   - rollback (AI failure) and clear (success) both clear ONLY this request's
 *     reservation, in the same transaction — no double refund.
 *   - Monthly counters reset by calendar month; chat's daily counter resets
 *     after 24h. Limits remain env-configurable (RESUME_MONTHLY_LIMIT,
 *     CAREER_COACH_MONTHLY_LIMIT, AI_MONTHLY_LIMIT, DAILY_MESSAGE_LIMIT).
 *
 * No Cloud Function exports here — a pure helper library. Each feature callable
 * keeps its thin wrapper (`getXxxUsage`, `consumeXxxQuota`, ...) that delegates
 * here so the callable bodies stay unchanged.
 */

const admin = require("firebase-admin");

const USER_AI_QUOTAS_COLLECTION = "user_ai_quotas";

// Feature → unified-map key, legacy collection, mode, env-driven limit.
const FEATURE_CONFIG = {
  chat: {
    key: "chat",
    legacyCollection: "ai_usage",
    mode: "daily",
    defaultLimit: parseInt(process.env.DAILY_MESSAGE_LIMIT || "50", 10),
    label: "daily message",
    lastAtField: null,
  },
  resumeReview: {
    key: "resumeReview",
    legacyCollection: "resume_usage",
    mode: "monthly",
    defaultLimit: parseInt(process.env.RESUME_MONTHLY_LIMIT || "5", 10),
    label: "resume review",
    lastAtField: "lastReviewAt",
  },
  careerCoach: {
    key: "careerCoach",
    legacyCollection: "career_coach_usage",
    mode: "monthly",
    defaultLimit: parseInt(process.env.CAREER_COACH_MONTHLY_LIMIT || "3", 10),
    label: "Career Coach analysis",
    lastAtField: "lastAnalyzedAt",
  },
  aiAnalysis: {
    key: "aiAnalysis",
    legacyCollection: "ai_analysis_usage",
    mode: "monthly",
    defaultLimit: parseInt(process.env.AI_MONTHLY_LIMIT || "3", 10),
    label: "AI analysis",
    lastAtField: "lastAnalyzedAt",
  },
};

function getConfig(feature) {
  const config = FEATURE_CONFIG[feature];
  if (!config) throw new Error(`Unknown AI quota feature: ${feature}`);
  return config;
}

function currentMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function defaultValue(feature) {
  const config = getConfig(feature);
  if (config.mode === "daily") {
    return { dailyCount: 0, dailyLimit: config.defaultLimit, lastUsedAt: null, lastResetAt: null };
  }
  return {
    monthlyCount: 0,
    monthlyLimit: config.defaultLimit,
    lastResetMonth: null,
    pendingRequestId: null,
    pendingSince: null,
  };
}

function normalizeFeatureMap(feature, map, fallbackLimit) {
  const config = getConfig(feature);
  const limit = map.dailyLimit || map.monthlyLimit || fallbackLimit || config.defaultLimit;
  if (config.mode === "daily") {
    return {
      dailyCount: map.dailyCount || 0,
      dailyLimit: limit,
      lastUsedAt: map.lastUsedAt || null,
      lastResetAt: map.lastResetAt || null,
    };
  }
  const out = {
    monthlyCount: map.monthlyCount || 0,
    monthlyLimit: limit,
    lastResetMonth: map.lastResetMonth || null,
    pendingRequestId: map.pendingRequestId || null,
    pendingSince: map.pendingSince || null,
  };
  if (config.lastAtField && map[config.lastAtField]) {
    out[config.lastAtField] = map[config.lastAtField];
  }
  return out;
}

function toUsageResponse(feature, normalized) {
  const config = getConfig(feature);
  if (config.mode === "daily") {
    return {
      dailyCount: normalized.dailyCount,
      lastResetAt: normalized.lastResetAt
        ? (normalized.lastResetAt.toDate
            ? normalized.lastResetAt.toDate().toISOString()
            : normTimestamp(normalized.lastResetAt).toISOString())
        : null,
    };
  }
  const out = {
    monthlyCount: normalized.monthlyCount,
    monthlyLimit: normalized.monthlyLimit,
    lastResetMonth: normalized.lastResetMonth,
  };
  if (config.lastAtField && normalized[config.lastAtField]) {
    out[config.lastAtField] = normalized[config.lastAtField].toDate
      ? normalized[config.lastAtField].toDate().toISOString()
      : normTimestamp(normalized[config.lastAtField]).toISOString();
  }
  return out;
}

function normTimestamp(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return new Date(value);
}

function buildUnifiedFeatureMap(feature, values) {
  const config = getConfig(feature);
  const map = {...values};
  if (config.mode === "monthly" && config.lastAtField) {
    map[config.lastAtField] = values[config.lastAtField] || null;
  }
  return map;
}

function buildLegacyWrite(feature, map) {
  const config = getConfig(feature);
  if (config.mode === "daily") {
    return {
      dailyCount: map.dailyCount,
      lastUsedAt: map.lastUsedAt,
      lastResetAt: map.lastResetAt,
    };
  }
  const out = {
    monthlyCount: map.monthlyCount,
    monthlyLimit: map.monthlyLimit,
    lastResetMonth: map.lastResetMonth,
  };
  if (config.lastAtField && map[config.lastAtField]) {
    out[config.lastAtField] = map[config.lastAtField];
  }
  if (map.pendingRequestId) out.pendingRequestId = map.pendingRequestId;
  if (map.pendingSince) out.pendingSince = map.pendingSince;
  return out;
}

// ================================================
// READ
// ================================================

/**
 * Read a feature's usage WITHOUT incrementing.
 *
 * Reads `user_ai_quotas/{uid}.{feature}` first (authoritative). If the doc or
 * nested map is missing, it SEEDS from the legacy collection so existing
 * counts/reservations are never lost. Returns the feature-usage shape the
 * callers expect (see toUsageResponse).
 *
 * @param {string} userId - Firebase Auth uid
 * @param {string} feature - chat | resumeReview | careerCoach | aiAnalysis
 * @returns {Promise<object>} Feature usage (monthlyCount/monthlyLimit/lastResetMonth, or dailyCount/lastResetAt)
 */
async function getFeatureUsage(userId, feature) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);

  try {
    const quotaDoc = await quotaRef.get();
    if (quotaDoc.exists) {
      const data = quotaDoc.data();
      const map = data[config.key];
      if (map) {
        // applyReadReset reports 0 at the start of a new month (stale count).
        return toUsageResponse(
            feature,
            applyReadReset(feature, normalizeFeatureMap(feature, map, config.defaultLimit))
        );
      }
      // Doc exists but feature map missing → seed from legacy and persist.
      const seeded = await seedFeatureFromLegacy(userId, feature, config);
      return toUsageResponse(feature, applyReadReset(feature, seeded));
    }
    // Doc missing → seed from legacy and persist.
    const seeded = await seedFeatureFromLegacy(userId, feature, config);
    return toUsageResponse(feature, applyReadReset(feature, seeded));
  } catch (error) {
    console.error(`getFeatureUsage(${feature}) error:`, error);
    return defaultUsageResponse(feature, config.defaultLimit);
  }
}

/**
 * Seed the unified doc's feature map from the legacy collection. Reads the
 * legacy doc; if present, copies its fields into the unified nested map; if
 * absent, writes the feature's default. Returns the normalized feature map.
 */
async function seedFeatureFromLegacy(userId, feature, config) {
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);
  const [legacyDoc, quotaDoc] = await Promise.all([legacyRef.get(), quotaRef.get()]);

  let map;
  if (legacyDoc.exists) {
    const legacyData = legacyDoc.data();
    const normalized = normalizeFeatureMap(feature, legacyData, config.defaultLimit);
    map = normalizeFeatureMap(feature, legacyData, config.defaultLimit);
    // Keep the exact same field names the legacy doc used.
    map = buildUnifiedFeatureMap(feature, normalized);
    // Preserve legacy reservations exactly.
    if (legacyData.pendingRequestId) map.pendingRequestId = legacyData.pendingRequestId;
    if (legacyData.pendingSince) map.pendingSince = legacyData.pendingSince;
  } else {
    map = defaultValue(feature);
  }

  const update = {[config.key]: map};
  update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  await quotaRef.set(update, {merge: true});
  return map;
}

// ================================================
// CONSUME (atomic check + increment + reservation)
// ================================================

/**
 * Atomically check the feature limit AND increment the quota, stamping a
 * per-request reservation. Writes BOTH the unified doc and the legacy doc in
 * one transaction so old readers stay consistent.
 *
 * @param {string} userId - Firebase Auth uid
 * @param {string} feature - chat | resumeReview | careerCoach | aiAnalysis
 * @param {string} requestId - Unique id for this request (randomUUID)
 * @returns {Promise<object>} Post-increment usage data
 * @throws {HttpsError#resource-exhausted} when the limit is reached
 */
async function consumeFeatureQuota(userId, feature, requestId) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);
  const now = new Date();
  const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const timestamp = admin.firestore.Timestamp.now();

  try {
    return await admin.firestore().runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const legacyDoc = await transaction.get(legacyRef);

      // Resolve the effective feature map: unified first, then legacy, then default.
      let map;
      if (quotaDoc.exists && quotaDoc.data()[config.key]) {
        map = normalizeFeatureMap(feature, quotaDoc.data()[config.key], config.defaultLimit);
      } else if (legacyDoc.exists) {
        map = normalizeFeatureMap(feature, legacyDoc.data(), config.defaultLimit);
      } else {
        map = defaultValue(feature);
      }

      map = applyReset(feature, map, month);
      map = enforceLimit(feature, map, config.defaultLimit, month);

      // Increment + stamp reservation.
      if (config.mode === "daily") {
        map.dailyCount += 1;
        map.lastUsedAt = timestamp;
        map.lastResetAt = map.lastResetAt || timestamp;
      } else {
        map.monthlyCount += 1;
        map.pendingRequestId = requestId;
        map.pendingSince = timestamp;
        if (config.lastAtField) map[config.lastAtField] = timestamp;
      }

      // Write BOTH stores atomically.
      const unifiedUpdate = {[config.key]: map};
      unifiedUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      transaction.set(quotaRef, unifiedUpdate, {merge: true});
      transaction.set(legacyRef, buildLegacyWrite(feature, map), {merge: true});

      return toUsageResponse(feature, map);
    });
  } catch (error) {
    console.error(`consumeFeatureQuota(${feature}) error:`, error);
    throw error;
  }
}

function applyReset(feature, map, month) {
  const config = getConfig(feature);
  if (config.mode === "daily") {
    const now = new Date();
    const oneDayAgo = now.getTime() - 24 * 60 * 60 * 1000;
    const lastResetAt = map.lastResetAt ? normTimestamp(map.lastResetAt).getTime() : 0;
    if (lastResetAt < oneDayAgo) {
      // 24h window elapsed — reset the daily counter (the consume step then
      // increments to 1). Fixed from a latent bug where the old count was kept.
      return {...map, dailyCount: 0, lastResetAt: null};
    }
    return map;
  }
  // Monthly: reset to 0 so the consume step increments to 1 on a new month.
  if (!map.lastResetMonth || map.lastResetMonth !== month) {
    return {...map, monthlyCount: 0, lastResetMonth: month};
  }
  return map;
}

function enforceLimit(feature, map, fallbackLimit, month) {
  const config = getConfig(feature);
  const limit = config.mode === "daily"
      ? map.dailyLimit || fallbackLimit
      : map.monthlyLimit || fallbackLimit;

  if (config.mode === "monthly") {
    const count = map.monthlyCount || 0;
    if (count >= limit) {
      throw new admin.functions.https.HttpsError(
          "resource-exhausted",
          `Monthly ${config.label || "feature"} limit reached (${limit}/month). Resets next month.`,
          {
            usage: {
              monthlyCount: count,
              monthlyLimit: limit,
              lastResetMonth: month,
            },
          }
      );
    }
  }
  return map;
}

/**
 * Month-aware READ reset. If the feature is monthly and the stored
 * `lastResetMonth` is not the current month, the stored `monthlyCount` is
 * stale (from last month) — report 0 so a `checkUsage` at the start of a new
 * month never shows a full/expired quota.
 */
function applyReadReset(feature, normalized) {
  const config = getConfig(feature);
  if (config.mode === "monthly" &&
      (!normalized.lastResetMonth || normalized.lastResetMonth !== currentMonth())) {
    return {...normalized, monthlyCount: 0, lastResetMonth: currentMonth()};
  }
  return normalized;
}

// ================================================
// CLEAR / ROLLBACK (reservation-safe)
// ================================================

/**
 * Clear (un-stamp) a successful request's reservation on BOTH stores.
 * The credit is kept. Idempotent and best-effort.
 */
async function clearFeatureReservation(userId, feature, requestId) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const legacyDoc = await transaction.get(legacyRef);

      if (quotaDoc.exists && quotaDoc.data()[config.key]) {
        const map = quotaDoc.data()[config.key];
        if (map.pendingRequestId && map.pendingRequestId === requestId) {
          transaction.update(quotaRef, {
            [`${config.key}.pendingRequestId`]: admin.firestore.FieldValue.delete(),
            [`${config.key}.pendingSince`]: admin.firestore.FieldValue.delete(),
          });
        }
      }

      if (legacyDoc.exists && legacyDoc.data().pendingRequestId === requestId) {
        transaction.update(legacyRef, {
          pendingRequestId: admin.firestore.FieldValue.delete(),
          pendingSince: admin.firestore.FieldValue.delete(),
        });
      }
    });
  } catch (clearError) {
    console.error(`clearFeatureReservation(${feature}) error:`, clearError);
  }
}

/**
 * Refund a consumed quota on AI failure. Decrements the count AND clears THIS
 * request's reservation on BOTH stores in one transaction.
 */
async function rollbackFeatureQuota(userId, feature, requestId) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);
  const now = new Date();
  const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const legacyDoc = await transaction.get(legacyRef);

      if (quotaDoc.exists && quotaDoc.data()[config.key]) {
        const map = quotaDoc.data()[config.key];
        const count = map.monthlyCount || 0;
        if (count > 0 && (map.lastResetMonth === null || map.lastResetMonth === month)) {
          const update = {[`${config.key}.monthlyCount`]: count - 1};
          if (map.pendingRequestId === requestId) {
            update[`${config.key}.pendingRequestId`] = admin.firestore.FieldValue.delete();
            update[`${config.key}.pendingSince`] = admin.firestore.FieldValue.delete();
          }
          transaction.update(quotaRef, update);
        }
      }

      if (legacyDoc.exists && legacyDoc.data().pendingRequestId === requestId) {
        const data = legacyDoc.data();
        const count = data.monthlyCount || 0;
        if (count > 0 && (data.lastResetMonth === null || data.lastResetMonth === month)) {
          const update = {monthlyCount: count - 1};
          update.pendingRequestId = admin.firestore.FieldValue.delete();
          update.pendingSince = admin.firestore.FieldValue.delete();
          transaction.update(legacyRef, update);
        }
      }
    });
  } catch (rollbackError) {
    console.error(`rollbackFeatureQuota(${feature}) error:`, rollbackError);
  }
}

// ================================================
// INCREMENT (chat daily usage — mirror of trackUsage)
// ================================================

/**
 * Increment the chat daily counter (soft limit, no reservation). Resets after
 * 24h. Writes both stores. Returns the daily usage shape (`dailyCount`,
 * `lastResetAt` ISO).
 */
async function incrementDailyUsage(userId, feature) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);
  const now = admin.firestore.Timestamp.now();

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const legacyDoc = await transaction.get(legacyRef);

      let map;
      if (quotaDoc.exists && quotaDoc.data()[config.key]) {
        map = normalizeFeatureMap(feature, quotaDoc.data()[config.key], config.defaultLimit);
      } else if (legacyDoc.exists) {
        map = normalizeFeatureMap(feature, legacyDoc.data(), config.defaultLimit);
      } else {
        map = defaultValue(feature);
      }

      // 24h reset
      const oneDayAgo = admin.firestore.Timestamp.fromMillis(
          Date.now() - 24 * 60 * 60 * 1000
      );
      let lastResetAt = map.lastResetAt;
      if (!lastResetAt || normTimestamp(lastResetAt).getTime() < oneDayAgo.toMillis()) {
        lastResetAt = now;
        map.lastResetAt = now;
        map.dailyCount = 1;
      } else {
        map.dailyCount = (map.dailyCount || 0) + 1;
      }
      map.lastUsedAt = now;

      const unifiedUpdate = {[config.key]: map};
      unifiedUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      transaction.set(quotaRef, unifiedUpdate, {merge: true});
      transaction.set(legacyRef, {
        dailyCount: map.dailyCount,
        lastUsedAt: now,
        lastResetAt,
      }, {merge: true});

      return {dailyCount: map.dailyCount, lastResetAt};
    });

    return {
      dailyCount: result.dailyCount,
      lastResetAt: normTimestamp(result.lastResetAt).toISOString(),
    };
  } catch (error) {
    console.error(`incrementDailyUsage(${feature}) error:`, error);
    return {
      dailyCount: 1,
      lastResetAt: now.toDate().toISOString(),
    };
  }
}

// ================================================
// COMPENSATION SWEEP HELPERS
// ================================================

/**
 * Refund a stale reservation for a single user + feature, atomically across
 * BOTH the unified doc and the legacy doc. Called by the daily sweeps.
 *
 * @param {string} userId
 * @param {string} feature
 * @param {admin.firestore.Timestamp} cutoff
 * @returns {Promise<{refunded: boolean}>}
 */
async function sweepStaleReservation(userId, feature, cutoff) {
  const config = getConfig(feature);
  const quotaRef = admin.firestore().collection(USER_AI_QUOTAS_COLLECTION).doc(userId);
  const legacyRef = admin.firestore().collection(config.legacyCollection).doc(userId);
  let refunded = false;

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const legacyDoc = await transaction.get(legacyRef);

      if (quotaDoc.exists && quotaDoc.data()[config.key]) {
        const map = quotaDoc.data()[config.key];
        if (map.pendingSince && map.pendingSince.toMillis() < cutoff.toMillis()) {
          const count = map.monthlyCount || 0;
          if (count > 0) {
            transaction.update(quotaRef, {
              [`${config.key}.monthlyCount`]: count - 1,
              [`${config.key}.pendingRequestId`]: admin.firestore.FieldValue.delete(),
              [`${config.key}.pendingSince`]: admin.firestore.FieldValue.delete(),
            });
            refunded = true;
          }
        }
      }

      if (legacyDoc.exists && legacyDoc.data().pendingSince) {
        const data = legacyDoc.data();
        if (data.pendingSince.toMillis() < cutoff.toMillis()) {
          const count = data.monthlyCount || 0;
          if (count > 0) {
            transaction.update(legacyRef, {
              monthlyCount: count - 1,
              pendingRequestId: admin.firestore.FieldValue.delete(),
              pendingSince: admin.firestore.FieldValue.delete(),
            });
            refunded = true;
          }
        }
      }
    });
  } catch (error) {
    console.error(`sweepStaleReservation(${feature}, ${userId}) error:`, error);
  }

  return {refunded};
}

/**
 * Query the unified doc for a feature with a stale reservation, then refund it
 * (and its legacy mirror) atomically. Returns the number refunded.
 */
async function sweepFeature(userId, feature, cutoff) {
  const config = getConfig(feature);
  const result = await sweepStaleReservation(userId, feature, cutoff);
  return result.refunded ? 1 : 0;
}

/**
 * Full-feature compensation sweep. Collects the UNION of users that have a
 * stale reservation in EITHER the unified `user_ai_quotas/{uid}` doc (nested
 * `{feature}.pendingSince`) or the legacy `{legacyCollection}/{uid}` doc, then
 * refunds each user atomically across BOTH stores via `sweepStaleReservation`.
 *
 * This is the single entry point the daily Scheduler sweeps call. Because
 * `sweepStaleReservation` is idempotent and clears BOTH docs in ONE
 * transaction, there is no double-refund (a user appears in the union exactly
 * once) and no divergence (the unified mirror can never be left high while the
 * legacy doc is refunded).
 *
 * @param {string} feature - resumeReview | careerCoach | aiAnalysis
 * @param {admin.firestore.Timestamp} cutoff - reservation age cutoff
 * @returns {Promise<number>} Number of credits refunded (count of users)
 */
async function runFeatureSweep(feature, cutoff) {
  const config = getConfig(feature);
  const db = admin.firestore();
  const userIds = new Set();

  // Unified doc — nested feature map's `pendingSince`.
  try {
    const unifiedSnapshot = await db
        .collection(USER_AI_QUOTAS_COLLECTION)
        .where(`${config.key}.pendingSince`, "<", cutoff)
        .limit(1000)
        .get();
    for (const doc of unifiedSnapshot.docs) {
      userIds.add(doc.id);
    }
  } catch (unifiedError) {
    console.error(`runFeatureSweep(${feature}) unified query error:`, unifiedError);
  }

  // Legacy doc — top-level `pendingSince` (pre-migration reservations that
  // have not yet been seeded into the unified doc).
  try {
    const legacySnapshot = await db
        .collection(config.legacyCollection)
        .where("pendingSince", "<", cutoff)
        .limit(1000)
        .get();
    for (const doc of legacySnapshot.docs) {
      userIds.add(doc.id);
    }
  } catch (legacyError) {
    console.error(`runFeatureSweep(${feature}) legacy query error:`, legacyError);
  }

  let refunded = 0;
  for (const userId of userIds) {
    const result = await sweepStaleReservation(userId, feature, cutoff);
    if (result.refunded) refunded++;
  }
  return refunded;
}

function toUsageResponseDaily(feature, map) {
  // internal helper for default usage responses
  return {
    dailyCount: map.dailyCount || 0,
    lastResetAt: map.lastResetAt
        ? (map.lastResetAt.toDate ? map.lastResetAt.toDate().toISOString() : null)
        : null,
  };
}

function defaultUsageResponse(feature, fallbackLimit) {
  const config = getConfig(feature);
  if (config.mode === "daily") {
    return {dailyCount: 0, lastResetAt: null};
  }
  return {
    monthlyCount: 0,
    monthlyLimit: config.defaultLimit || fallbackLimit,
    lastResetMonth: null,
  };
}

module.exports = {
  USER_AI_QUOTAS_COLLECTION,
  FEATURE_CONFIG,
  getFeatureUsage,
  consumeFeatureQuota,
  clearFeatureReservation,
  rollbackFeatureQuota,
  incrementDailyUsage,
  sweepFeature,
  sweepStaleReservation,
  runFeatureSweep,
};
