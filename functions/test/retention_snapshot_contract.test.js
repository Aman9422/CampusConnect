"use strict";

/**
 * CampusConnect v9.2 — retention + immutable-snapshot CONTRACT tests.
 *
 * These two v9.2 HIGH/MED defects were both *field/order mismatches*, not
 * runtime logic bugs, and both are invisible to a functional test that only
 * exercises the happy path:
 *
 *   - BUG-1: `cleanupExpiredAIConversations` filtered `ai_interactions` by
 *     `createdAt`, but `askAI` writes `timestamp` — so the retention query
 *     matched ZERO documents and the 90-day window was never enforced.
 *   - BUG-3: `logPlacementApplication` copied the resume snapshot
 *     UNCONDITIONALLY, BEFORE the idempotency check — a duplicate apply
 *     re-copied the CURRENT resume over the submitted snapshot.
 *
 * The retention job needs a COLLECTION_GROUP query and the apply path needs
 * Google Cloud Storage; neither is available under the in-memory fake. So
 * these assertions read the production SOURCE and lock the invariants that the
 * fix depends on (reader field == writer field; copy gated on exists()), which
 * is exactly the class of regression that shipped the bug in the first place.
 *
 * Run:  node --test test/retention_snapshot_contract.test.js  (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

// ── Source loaders ───────────────────────────────────────────────────────

const FUNCTIONS_ROOT = path.join(__dirname, "..");
const REPO_ROOT = path.join(FUNCTIONS_ROOT, "..");

function readSource(relativePath) {
  return fs.readFileSync(path.join(FUNCTIONS_ROOT, relativePath), "utf8");
}

const chatDeleteSource = readSource("ai/chatDelete.js");
const chatSource = readSource("ai/chat.js");
const placementsSource = readSource("placements.js");
const indexes = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, "firestore.indexes.json"), "utf8"),
);

/** The `collectionGroup("ai_interactions")...get()` retention query block. */
function aiInteractionsRetentionQuery() {
  const match = chatDeleteSource.match(
      /collectionGroup\("ai_interactions"\)[\s\S]*?\.get\(\);/,
  );
  assert.ok(match, "chatDelete.js must contain a collectionGroup(\"ai_interactions\") retention query");
  return match[0];
}

// ── BUG-1: retention deletes the field askAI actually writes ──────────────

test("BUG-1: the retention query filters ai_interactions by `timestamp` (what askAI writes)", () => {
  const query = aiInteractionsRetentionQuery();
  assert.match(
      query,
      /\.where\(\s*"timestamp"\s*,\s*"<"\s*,\s*cutoff\s*\)/,
      "the retention query must filter by `timestamp`, not `createdAt`",
  );
});

test("BUG-1: the retention query does NOT filter ai_interactions by `createdAt`", () => {
  const query = aiInteractionsRetentionQuery();
  assert.doesNotMatch(
      query,
      /\.where\(\s*"createdAt"/,
      "`createdAt` is never written to ai_interactions — filtering by it deletes nothing",
  );
});

test("BUG-1: askAI writes `timestamp` into ai_interactions (reader field must exist)", () => {
  // Both the user turn and the assistant turn are written with `timestamp`.
  const writer = /\.collection\("ai_interactions"\)\s*\.add\(\{[\s\S]*?\}\)/g;
  const turns = chatSource.match(writer) || [];
  assert.ok(turns.length >= 2, "askAI must write both the user and assistant turns");
  for (const turn of turns) {
    assert.match(
        turn,
        /timestamp:\s*admin\.firestore\.FieldValue\.serverTimestamp\(\)/,
        "each ai_interactions write must carry the `timestamp` field",
    );
  }
});

test("BUG-1: firestore.indexes.json declares a COLLECTION_GROUP index on ai_interactions.timestamp", () => {
  const overrides = indexes.fieldOverrides || [];
  const override = overrides.find(
      (o) => o.collectionGroup === "ai_interactions" && o.fieldPath === "timestamp",
  );
  assert.ok(
      override,
      "the collection-group range query needs a fieldOverride on ai_interactions.timestamp",
  );
  const scopes = (override.indexes || []).map((i) => i.queryScope);
  assert.ok(
      scopes.includes("COLLECTION_GROUP"),
      "the override must include a COLLECTION_GROUP scope for the collectionGroup() query",
  );
});

// ── BUG-3: the immutable snapshot is write-once ───────────────────────────

test("BUG-3: the snapshot copy is gated on `exists()` (write-once)", () => {
  // The `.exists()` probe must appear BEFORE the copy, and the copy must be
  // inside the `if (!…exists)` guard — a duplicate apply must not copy.
  const existsIdx = placementsSource.indexOf("snapshotFile.exists()");
  const copyIdx = placementsSource.indexOf(".copy(snapshotFile)");
  assert.ok(existsIdx !== -1, "apply path must probe snapshot existence");
  assert.ok(copyIdx !== -1, "apply path must still perform the initial copy");
  assert.ok(
      existsIdx < copyIdx,
      "the existence probe must run BEFORE the copy (BUG-3 ordering)",
  );

  // The copy must be guarded: `if (!snapshotExists) { ... copy ... }`.
  const guard = placementsSource.slice(existsIdx, copyIdx);
  assert.match(
      guard,
      /if\s*\(\s*!\s*snapshotExists\s*\)/,
      "the copy must be inside `if (!snapshotExists)` so it never overwrites a submitted snapshot",
  );
});

test("BUG-3: no unconditional top-level copy of the resume snapshot remains", () => {
  // The pre-fix code copied before the idempotency transaction. Assert the only
  // `.copy(` call on the resume path is the guarded snapshot copy.
  const copyCalls = placementsSource.match(/\.copy\(/g) || [];
  assert.equal(
      copyCalls.length,
      1,
      "exactly one Storage copy (the guarded snapshot copy) may exist in placements.js",
  );
});

