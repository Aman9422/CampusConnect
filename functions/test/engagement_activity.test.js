"use strict";

/**
 * CampusConnect v9.2 — engagement ACTIVITY aggregate tests (TEST-1).
 *
 * Covers the server engagement writer `logUserActivity`
 * (`functions/helpers/shared.js`), which is the single writer after the
 * BUG-2/BUG-10 fixes. It maintains a materialized `engagement_summary/summary`
 * (activityPoints / dailyStreak / streakLastActiveKey) inside the SAME
 * transaction as the `activities` write, using `FieldValue.increment(points)`.
 *
 * These tests pin the aggregate arithmetic that the score/badges derive from:
 *   - a first activity seeds streak=1 and activityPoints=points;
 *   - a SECOND activity on the SAME UTC day does not advance the streak
 *     (idempotent streak) while it DOES accumulate points;
 *   - an activity on the day AFTER the last active day extends the streak;
 *   - a GAP of more than one day resets the streak to 1.
 *
 * Run:  node --test test/engagement_activity.test.js  (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared runtime shim BEFORE requiring the production module.
const {seedDb} = require("./setup");

const shared = require("../helpers/shared");
const {logUserActivity, dayKey, previousDayKey} = shared;

// ── Helpers ──────────────────────────────────────────────────────────────

/** The materialized engagement summary for a user, or undefined. */
function readSummary(db, uid) {
  const col = db.__store[`users/${uid}/engagement_summary`];
  return col ? col.summary : undefined;
}

/** The activities collection size for a user. */
function activityCount(db, uid) {
  const col = db.__store[`users/${uid}/activities`] || {};
  return Object.keys(col).length;
}

// ── Pure day-key helpers ─────────────────────────────────────────────────

test("dayKey: formats a UTC day as YYYY-M-D (no zero padding)", () => {
  assert.equal(dayKey(new Date(Date.UTC(2026, 0, 2))), "2026-1-2");
  assert.equal(dayKey(new Date(Date.UTC(2026, 11, 31))), "2026-12-31");
});

test("previousDayKey: steps back one UTC day across month and year rollovers", () => {
  assert.equal(previousDayKey("2026-1-2"), "2026-1-1");
  // Month rollover (1 Mar -> 28 Feb in a non-leap year).
  assert.equal(previousDayKey("2026-3-1"), "2026-2-28");
  // Year rollover.
  assert.equal(previousDayKey("2026-1-1"), "2025-12-31");
});

// ── Aggregate behaviour ──────────────────────────────────────────────────

test("logUserActivity: a first activity seeds streak=1 and activityPoints=points", async () => {
  const uid = "user_first";
  const db = seedDb({});

  await logUserActivity(uid, "resumeReviewed", 5);

  const summary = readSummary(db, uid);
  assert.ok(summary, "the summary doc must be created");
  assert.equal(summary.dailyStreak, 1, "first activity starts the streak at 1");
  assert.equal(summary.activityPoints, 5, "points start at the event's value");
  assert.equal(
      summary.streakLastActiveKey,
      dayKey(new Date()),
      "the streak pointer is stamped with today's UTC day key",
  );
  assert.equal(activityCount(db, uid), 1, "exactly one activity doc is written");
});

test("logUserActivity: a second activity on the SAME UTC day accumulates points but does NOT advance the streak (idempotent streak)", async () => {
  const uid = "user_sameday";
  const db = seedDb({});

  await logUserActivity(uid, "resumeReviewed", 5);
  await logUserActivity(uid, "resumeReviewed", 5);

  const summary = readSummary(db, uid);
  assert.equal(summary.activityPoints, 10, "points accumulate across same-day activity");
  assert.equal(
      summary.dailyStreak,
      1,
      "the streak must not double-increment for same-day activity",
  );
  assert.equal(activityCount(db, uid), 2, "each call logs its own activity doc");
});

test("logUserActivity: an activity on the day AFTER the last active day extends the streak", async () => {
  const uid = "user_consecutive";
  const today = dayKey(new Date());
  const yesterday = previousDayKey(today);

  // Seed a user last active YESTERDAY with a 3-day streak / 20 points.
  const db = seedDb({
    [`users/${uid}/engagement_summary`]: {
      summary: {
        dailyStreak: 3,
        activityPoints: 20,
        streakLastActiveKey: yesterday,
      },
    },
  });

  await logUserActivity(uid, "resumeReviewed", 5);

  const summary = readSummary(db, uid);
  assert.equal(summary.dailyStreak, 4, "consecutive day extends the streak");
  assert.equal(summary.activityPoints, 25, "points add to the existing total");
  assert.equal(summary.streakLastActiveKey, today, "the pointer advances to today");
});

test("logUserActivity: a gap of more than one day resets the streak to 1", async () => {
  const uid = "user_gap";
  const today = dayKey(new Date());
  // Two days ago — a gap, so the streak must break.
  const staleKey = previousDayKey(previousDayKey(today));

  const db = seedDb({
    [`users/${uid}/engagement_summary`]: {
      summary: {
        dailyStreak: 9,
        activityPoints: 100,
        streakLastActiveKey: staleKey,
      },
    },
  });

  await logUserActivity(uid, "resumeReviewed", 5);

  const summary = readSummary(db, uid);
  assert.equal(summary.dailyStreak, 1, "a gap resets the streak to 1");
  assert.equal(summary.activityPoints, 105, "points still accumulate across the gap");
  assert.equal(summary.streakLastActiveKey, today);
});

test("logUserActivity: increment applies to a missing baseline as 0 (no NaN)", async () => {
  const uid = "user_nobaseline";
  const db = seedDb({});

  await logUserActivity(uid, "profileCompleted", 15);

  const summary = readSummary(db, uid);
  assert.equal(summary.activityPoints, 15, "missing activityPoints is treated as 0");
  assert.ok(Number.isFinite(summary.activityPoints), "activityPoints is a finite number");
});
