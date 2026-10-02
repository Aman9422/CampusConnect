"use strict";

/**
 * CampusConnect v9.2.4 — `autoExpireOpportunities` bulk-safety tests (E-3).
 *
 * The v9.2.3 audit found the hourly expiry sweep accumulated EVERY expired
 * opportunity into ONE Firestore batch and committed once. Firestore caps a
 * commit at 500 operations and a failed commit is atomic, so more than 500
 * expired documents meant the whole sweep failed and NOTHING was expired.
 *
 * These tests drive the REAL handler from `functions/schedulers/index.js`
 * against the in-memory Firestore fake and prove:
 *   - an empty result is a no-op;
 *   - a small result is expired;
 *   - a multi-batch backlog is chunked (NO commit exceeds the 400-op chunk
 *     size) and every eligible opportunity still becomes inactive;
 *   - the sweep is idempotent (a second run expires nothing new);
 *   - documents that are already inactive are left alone.
 *
 * Run:  node --test test/schedulers_expiry.test.js   (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared admin shim BEFORE requiring any production module.
const {Timestamp, seedDb} = require("./setup");

// Stub the v2 scheduler so requiring schedulers/index.js registers no real jobs
// and each `onSchedule(options, handler)` call returns the handler directly.
const schedulerPath = require.resolve("firebase-functions/v2/scheduler");
require.cache[schedulerPath] = {
  id: schedulerPath,
  filename: schedulerPath,
  loaded: true,
  exports: {onSchedule: (_options, handler) => handler},
};

const schedulers = require("../schedulers");

// ── Helpers ──────────────────────────────────────────────────────────────

const HOUR_MS = 60 * 60 * 1000;

/** The chunk size the production sweep must respect. */
const EXPECTED_CHUNK_SIZE = 400;

/** A deadline one hour in the past — every seeded document is expire-eligible. */
function expiredDeadline() {
  return Timestamp.fromMillis(Date.now() - HOUR_MS);
}

/** A deadline one hour in the future — must never be expired. */
function futureDeadline() {
  return Timestamp.fromMillis(Date.now() + HOUR_MS);
}

/**
 * Seed `count` active + expired opportunities (`opp_0`, `opp_1`, …).
 */
function seedExpiredOpportunities(count) {
  const opportunities = {};
  for (let i = 0; i < count; i++) {
    opportunities[`opp_${String(i).padStart(4, "0")}`] = {
      title: `Role ${i}`,
      company: "Acme",
      isActive: true,
      applicationDeadline: expiredDeadline(),
    };
  }
  return opportunities;
}

/**
 * Wrap `db.batch()` so each commit is recorded, capturing how many operations
 * it carried. Returns the array commit sizes are appended to.
 */
function recordBatchCommits(db) {
  const commitSizes = [];
  const originalBatch = db.batch.bind(db);
  db.batch = () => {
    const inner = originalBatch();
    let operations = 0;
    return {
      set: inner.set,
      delete: inner.delete,
      update: (ref, value) => {
        operations += 1;
        inner.update(ref, value);
      },
      commit: async () => {
        commitSizes.push(operations);
        await inner.commit();
      },
    };
  };
  return commitSizes;
}

function activeCount(db) {
  return Object.values(db.__store.opportunities || {})
      .filter((doc) => doc.isActive === true).length;
}

// ── Tests ────────────────────────────────────────────────────────────────

test("autoExpireOpportunities: an empty result is a no-op", async () => {
  const db = seedDb({opportunities: {}});
  const commits = recordBatchCommits(db);

  await assert.doesNotReject(
      () => schedulers.autoExpireOpportunities(),
      "the sweep must not throw on an empty backlog",
  );

  assert.deepEqual(commits, [], "no batch is committed when nothing expired");
});

test("autoExpireOpportunities: a small result expires every eligible opportunity", async () => {
  const db = seedDb({opportunities: seedExpiredOpportunities(3)});

  await schedulers.autoExpireOpportunities();

  const stored = db.__store.opportunities;
  for (const id of Object.keys(stored)) {
    assert.equal(stored[id].isActive, false, `${id} is deactivated`);
    assert.ok(stored[id].expiredAt, `${id} records expiredAt`);
    assert.ok(stored[id].updatedAt, `${id} records updatedAt`);
  }
  assert.equal(activeCount(db), 0, "no active opportunity remains");
});

test("autoExpireOpportunities: a backlog larger than one chunk is chunked, never one big batch", async () => {
  const total = EXPECTED_CHUNK_SIZE * 2 + 100; // 900 → 400 + 400 + 100
  const db = seedDb({opportunities: seedExpiredOpportunities(total)});
  const commits = recordBatchCommits(db);

  await schedulers.autoExpireOpportunities();

  assert.ok(commits.length > 1,
      `a ${total}-document backlog must be split across commits (got ${commits.length})`);

  for (const size of commits) {
    assert.ok(size <= EXPECTED_CHUNK_SIZE,
        `every commit must stay within the ${EXPECTED_CHUNK_SIZE}-op chunk size (saw ${size})`);
  }

  assert.equal(
      commits.reduce((sum, size) => sum + size, 0),
      total,
      "every eligible opportunity is written exactly once",
  );
  assert.equal(activeCount(db), 0,
      "a backlog above the batch cap must still be fully expired");
});

test("autoExpireOpportunities: the sweep is idempotent", async () => {
  const db = seedDb({opportunities: seedExpiredOpportunities(5)});

  await schedulers.autoExpireOpportunities();
  const commits = recordBatchCommits(db);

  await schedulers.autoExpireOpportunities();

  assert.deepEqual(commits, [],
      "a re-run finds nothing left to expire and commits nothing");
  assert.equal(activeCount(db), 0, "state is unchanged by the re-run");
});

test("autoExpireOpportunities: already-inactive and not-yet-expired documents are untouched", async () => {
  const db = seedDb({
    opportunities: {
      alreadyInactive: {
        isActive: false,
        applicationDeadline: expiredDeadline(),
      },
      stillActive: {
        isActive: true,
        applicationDeadline: futureDeadline(),
      },
      expiredActive: {
        isActive: true,
        applicationDeadline: expiredDeadline(),
      },
    },
  });

  await schedulers.autoExpireOpportunities();

  const stored = db.__store.opportunities;
  assert.equal(stored.alreadyInactive.isActive, false,
      "an inactive document is not rewritten");
  assert.equal(stored.alreadyInactive.expiredAt, undefined,
      "an inactive document gains no expiredAt");
  assert.equal(stored.stillActive.isActive, true,
      "a live opportunity is never expired early");
  assert.equal(stored.stillActive.expiredAt, undefined);
  assert.equal(stored.expiredActive.isActive, false,
      "the genuinely expired active opportunity is deactivated");
});
