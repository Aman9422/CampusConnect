"use strict";

/**
 * CampusConnect v9.2 — AI quota unit tests.
 *
 * Covers the contracts the v9.2 audit/consolidation must preserve:
 *   - the consolidated scheduler sweeps ALL THREE monthly features
 *     (resumeReview, careerCoach, aiAnalysis) from ONE job;
 *   - stale compensation (pendingSince older than the cutoff is refunded);
 *   - no double-refund / no phantom refund (a user stale in BOTH the unified
 *     doc and the legacy mirror is refunded once; a zero-count reservation is
 *     never refunded into a negative credit);
 *   - monthly limit enforcement (no over-charge) and rollback;
 *   - read-reset shows 0 at the start of a new month.
 *
 * No Firestore project or emulator is required: `admin.firestore` is replaced
 * with a small in-memory fake (test/firestore_fake.js) and `admin.functions`
 * is shimmed exactly as the deployed runtime provides it.
 *
 * Run:  node --test test/quota.test.js   (from the functions/ directory)
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared runtime shim BEFORE requiring any production module.
const {Timestamp, seedDb} = require("./setup");

// Require AFTER the shim so quota.js binds to the patched admin.
const quota = require("../ai/quota");

// ── Helpers ──────────────────────────────────────────────────────────────

const HOUR_MS = 60 * 60 * 1000;

function currentMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

/** A reservation timestamp safely OLDER than the sweep cutoff. */
function staleSince() {
  return Timestamp.fromMillis(Date.now() - 48 * HOUR_MS);
}

/** The sweep cutoff: reservations older than 24h are stale. */
function cutoff() {
  return Timestamp.fromMillis(Date.now() - 24 * HOUR_MS);
}

const MONTHLY_FEATURES = ["resumeReview", "careerCoach", "aiAnalysis"];

// ── Tests ────────────────────────────────────────────────────────────────

test("FEATURE_CONFIG: the three sweep features are monthly with correct legacy mirrors", () => {
  for (const feature of MONTHLY_FEATURES) {
    const config = quota.FEATURE_CONFIG[feature];
    assert.equal(config.mode, "monthly", `${feature} must be monthly`);
    assert.ok(config.legacyCollection, `${feature} must have a legacy collection`);
    assert.equal(config.key, feature);
  }
  assert.equal(quota.FEATURE_CONFIG.resumeReview.legacyCollection, "resume_usage");
  assert.equal(quota.FEATURE_CONFIG.careerCoach.legacyCollection, "career_coach_usage");
  assert.equal(quota.FEATURE_CONFIG.aiAnalysis.legacyCollection, "ai_analysis_usage");
  assert.equal(quota.FEATURE_CONFIG.chat.mode, "daily");
});

test("runFeatureSweep: refunds the stale reservation for EACH monthly feature", async () => {
  for (const feature of MONTHLY_FEATURES) {
    const config = quota.FEATURE_CONFIG[feature];
    const db = seedDb({
      user_ai_quotas: {
        u1: {
          [feature]: {
            monthlyCount: 1,
            monthlyLimit: 5,
            lastResetMonth: "2000-01",
            pendingRequestId: "req-1",
            pendingSince: staleSince(),
          },
        },
      },
    });

    const refunded = await quota.runFeatureSweep(feature, cutoff());
    assert.equal(refunded, 1, `${feature}: expected one refund`);

    const map = db.__store.user_ai_quotas.u1[feature];
    assert.equal(map.monthlyCount, 0, `${feature}: credit refunded`);
    assert.equal(map.pendingRequestId, undefined, `${feature}: reservation cleared`);
    assert.equal(map.pendingSince, undefined, `${feature}: pendingSince cleared`);
  }
});

test("runFeatureSweep: does NOT refund a fresh (non-stale) reservation", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u1: {
        resumeReview: {
          monthlyCount: 1,
          monthlyLimit: 5,
          lastResetMonth: currentMonth(),
          pendingRequestId: "req-live",
          pendingSince: Timestamp.now(), // newer than the 24h cutoff
        },
      },
    },
  });

  const refunded = await quota.runFeatureSweep("resumeReview", cutoff());
  assert.equal(refunded, 0, "a live request must never be refunded");
  const map = db.__store.user_ai_quotas.u1.resumeReview;
  assert.equal(map.monthlyCount, 1, "live credit preserved");
  assert.equal(map.pendingRequestId, "req-live", "live reservation preserved");
});

test("runFeatureSweep: never refunds a zero-count reservation into a negative credit", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u1: {
        resumeReview: {
          monthlyCount: 0,
          monthlyLimit: 5,
          lastResetMonth: currentMonth(),
          pendingRequestId: "req-0",
          pendingSince: staleSince(),
        },
      },
    },
  });

  const refunded = await quota.runFeatureSweep("resumeReview", cutoff());
  assert.equal(refunded, 0, "a zero-count reservation has nothing to refund");
  assert.equal(db.__store.user_ai_quotas.u1.resumeReview.monthlyCount, 0);
});

test("runFeatureSweep: a user stale in BOTH stores is refunded ONCE (no double-refund, no divergence)", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u2: {
        resumeReview: {
          monthlyCount: 2,
          monthlyLimit: 5,
          lastResetMonth: currentMonth(),
          pendingRequestId: "req-2",
          pendingSince: staleSince(),
        },
      },
    },
    resume_usage: {
      u2: {
        monthlyCount: 2,
        monthlyLimit: 5,
        lastResetMonth: currentMonth(),
        pendingRequestId: "req-2",
        pendingSince: staleSince(),
      },
    },
  });

  const refunded = await quota.runFeatureSweep("resumeReview", cutoff());
  assert.equal(refunded, 1, "the union dedups — the user is counted once");

  assert.equal(db.__store.user_ai_quotas.u2.resumeReview.monthlyCount, 1,
      "unified mirror decremented once");
  assert.equal(db.__store.resume_usage.u2.monthlyCount, 1,
      "legacy mirror decremented once (no divergence)");
});

test("consumeFeatureQuota: increments the count and stamps a reservation", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u3: {
        resumeReview: {monthlyCount: 0, monthlyLimit: 5, lastResetMonth: currentMonth()},
      },
    },
  });

  const usage = await quota.consumeFeatureQuota("u3", "resumeReview", "req-new");
  assert.equal(usage.monthlyCount, 1);

  const map = db.__store.user_ai_quotas.u3.resumeReview;
  assert.equal(map.monthlyCount, 1);
  assert.equal(map.pendingRequestId, "req-new");
  assert.ok(map.pendingSince, "reservation timestamp stamped");
});

test("consumeFeatureQuota: throws resource-exhausted at the limit (no over-charge)", async () => {
  seedDb({
    user_ai_quotas: {
      u4: {
        resumeReview: {monthlyCount: 5, monthlyLimit: 5, lastResetMonth: currentMonth()},
      },
    },
  });

  await assert.rejects(
      () => quota.consumeFeatureQuota("u4", "resumeReview", "req-over"),
      (error) => error.code === "resource-exhausted",
  );
});

test("consumeFeatureQuota: a new month resets the counter before incrementing", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u5: {
        resumeReview: {monthlyCount: 5, monthlyLimit: 5, lastResetMonth: "2000-01"},
      },
    },
  });

  const usage = await quota.consumeFeatureQuota("u5", "resumeReview", "req-m");
  assert.equal(usage.monthlyCount, 1, "stale month count reset to 0 then incremented");
  assert.equal(db.__store.user_ai_quotas.u5.resumeReview.monthlyCount, 1);
});

test("rollbackFeatureQuota: decrements the credit and clears this request's reservation", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u6: {
        resumeReview: {
          monthlyCount: 3,
          monthlyLimit: 5,
          lastResetMonth: currentMonth(),
          pendingRequestId: "req-r",
          pendingSince: Timestamp.now(),
        },
      },
    },
  });

  await quota.rollbackFeatureQuota("u6", "resumeReview", "req-r");

  const map = db.__store.user_ai_quotas.u6.resumeReview;
  assert.equal(map.monthlyCount, 2, "one credit returned");
  assert.equal(map.pendingRequestId, undefined, "reservation cleared");
});

test("getFeatureUsage: a stale month reports 0 (read reset)", async () => {
  seedDb({
    user_ai_quotas: {
      u7: {
        resumeReview: {monthlyCount: 5, monthlyLimit: 5, lastResetMonth: "2000-01"},
      },
    },
  });

  const usage = await quota.getFeatureUsage("u7", "resumeReview");
  assert.equal(usage.monthlyCount, 0, "start of a new month shows an empty quota");
  assert.equal(usage.monthlyLimit, 5);
});

test("getFeatureUsage: the current month's count is preserved", async () => {
  seedDb({
    user_ai_quotas: {
      u8: {
        resumeReview: {monthlyCount: 2, monthlyLimit: 5, lastResetMonth: currentMonth()},
      },
    },
  });

  const usage = await quota.getFeatureUsage("u8", "resumeReview");
  assert.equal(usage.monthlyCount, 2);
});
