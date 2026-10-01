"use strict";

/**
 * CampusConnect v9.2 — consolidated scheduler tests.
 *
 * Drives the REAL `compensateStaleAIQuotas` handler from
 * functions/schedulers/index.js against the in-memory Firestore fake, proving
 * the 3→1 consolidation introduced in v9.2 preserves behaviour:
 *   - ONE daily job sweeps ALL THREE monthly AI features;
 *   - each feature's stale reservation is refunded;
 *   - a failure in one feature does not block the other two (isolation).
 *
 * `onSchedule` is stubbed so requiring the module is side-effect free and the
 * wrapped handler can be invoked directly.
 *
 * Run:  node --test test/schedulers.test.js   (from the functions/ directory)
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared admin shim BEFORE requiring any production module.
const {Timestamp, seedDb} = require("./setup");

// Stub the v2 scheduler so requiring schedulers/index.js does not register real
// jobs and the handler is directly callable.
const schedulerPath = require.resolve("firebase-functions/v2/scheduler");
require.cache[schedulerPath] = {
  id: schedulerPath,
  filename: schedulerPath,
  loaded: true,
  exports: {onSchedule: (_options, handler) => handler},
};

const quota = require("../ai/quota");
const schedulers = require("../schedulers");

// ── Helpers ──────────────────────────────────────────────────────────────

const HOUR_MS = 60 * 60 * 1000;
const MONTHLY_FEATURES = ["resumeReview", "careerCoach", "aiAnalysis"];

function currentMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

/** A reservation 48h old — stale relative to the job's 24h cutoff. */
function staleSince() {
  return Timestamp.fromMillis(Date.now() - 48 * HOUR_MS);
}

function staleMap() {
  return {
    monthlyCount: 1,
    monthlyLimit: 5,
    lastResetMonth: currentMonth(),
    pendingRequestId: "req-stale",
    pendingSince: staleSince(),
  };
}

/** Wrap quota.runFeatureSweep with a spy; returns a restore function. */
function spyOnSweep(onCall) {
  const original = quota.runFeatureSweep;
  quota.runFeatureSweep = async (feature, cutoff) => {
    onCall(feature);
    return original(feature, cutoff);
  };
  return () => {
    quota.runFeatureSweep = original;
  };
}

// ── Tests ────────────────────────────────────────────────────────────────

test("compensateStaleAIQuotas: one job sweeps all three features and refunds each", async () => {
  const db = seedDb({
    user_ai_quotas: {
      u_resume: {resumeReview: staleMap()},
      u_coach: {careerCoach: staleMap()},
      u_ai: {aiAnalysis: staleMap()},
    },
  });

  const swept = [];
  const restore = spyOnSweep((feature) => swept.push(feature));
  try {
    assert.equal(
        typeof schedulers.compensateStaleAIQuotas,
        "function",
        "the consolidated job is exported",
    );
    await schedulers.compensateStaleAIQuotas();
  } finally {
    restore();
  }

  assert.deepEqual(swept, MONTHLY_FEATURES,
      "all three features are swept, once each, in deterministic order");

  assert.equal(db.__store.user_ai_quotas.u_resume.resumeReview.monthlyCount, 0,
      "resumeReview refunded");
  assert.equal(db.__store.user_ai_quotas.u_coach.careerCoach.monthlyCount, 0,
      "careerCoach refunded");
  assert.equal(db.__store.user_ai_quotas.u_ai.aiAnalysis.monthlyCount, 0,
      "aiAnalysis refunded");
});

test("compensateStaleAIQuotas: a failure in one feature does not block the others", async () => {
  seedDb({
    user_ai_quotas: {
      u_resume: {resumeReview: staleMap()},
      u_ai: {aiAnalysis: staleMap()},
    },
  });

  const called = [];
  const restore = spyOnSweep((feature) => {
    called.push(feature);
    if (feature === "careerCoach") {
      throw new Error("simulated careerCoach sweep failure");
    }
  });

  try {
    await assert.doesNotReject(
        () => schedulers.compensateStaleAIQuotas(),
        "the job must absorb per-feature failures",
    );
  } finally {
    restore();
  }

  assert.deepEqual(called, MONTHLY_FEATURES,
      "a careerCoach failure did not prevent aiAnalysis from being swept");
});
