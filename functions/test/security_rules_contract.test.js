"use strict";

/**
 * CampusConnect v9.2.4 — Firestore security-rule contract tests.
 *
 * The v9.2.3 audit's HIGH findings D-9, D-10 and D-11 are all *rule* defects:
 *
 *   D-9  `opportunities` create/update/delete required only
 *        `isAuthenticated()`, so ANY signed-in user could publish a posting by
 *        setting `alumniId` to their own uid — and publication broadcasts a
 *        notification to every student and injects a recommendation candidate.
 *   D-10 `opportunities` had NO schema validator at all (contrast
 *        `isValidPlacementData()`), so a malformed document still triggered
 *        that broadcast.
 *   D-11 the owner write on `users/{uid}` protected ONLY `role`, leaving
 *        `profileCompleted` (trusted as a QUERY FILTER by rules and Cloud
 *        Functions) and `isVerified` client-writable.
 *
 * Rules cannot be executed without the Firestore emulator, so — exactly like
 * the existing `test/security_rules_mirror_test.dart` on the client side —
 * these tests assert the deployed rule TEXT. They fail if a future edit
 * removes a guard, which is the regression that matters.
 *
 * A `SEC-1` guard test is included too: the v9.2 recursive `{subcollection=**}`
 * catch-all under `users/{uid}` must never come back, because it silently
 * voided every `write: false` beneath it.
 *
 * Run:  node --test test/security_rules_contract.test.js
 */

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");

/** The raw rule file. */
const rawRules = fs.readFileSync(RULES_PATH, "utf8");

/**
 * The rule file with `//` line comments removed. Comments discuss the defects
 * being fixed (they quote the removed catch-all verbatim), so assertions must
 * run against executable text only.
 */
const rules = rawRules
    .split("\n")
    .map((line) => {
      const commentAt = line.indexOf("//");
      return commentAt === -1 ? line : line.slice(0, commentAt);
    })
    .join("\n");

/**
 * Slice out a brace-balanced block starting at `marker`.
 *
 * The scan begins after the marker itself, so a marker that already contains a
 * `{...}` path segment (e.g. `match /users/{userId}`) does not confuse the
 * depth counter.
 *
 * @param {string} source
 * @param {string} marker
 * @returns {string}
 */
function extractBlock(source, marker) {
  const markerAt = source.indexOf(marker);
  assert.ok(markerAt >= 0, `expected to find "${marker}" in firestore.rules`);

  let depth = 0;
  let started = false;
  for (let i = markerAt + marker.length; i < source.length; i++) {
    const character = source[i];
    if (character === "{") {
      depth += 1;
      started = true;
    } else if (character === "}") {
      depth -= 1;
      if (started && depth === 0) return source.slice(markerAt, i + 1);
    }
  }
  throw new Error(`unbalanced braces after "${marker}"`);
}

// ── Baseline ─────────────────────────────────────────────────────────────

test("rules: the default-deny fallback is present and last", () => {
  assert.match(rules, /match \/\{document=\*\*\} \{\s*allow read, write: if false;/,
      "an unmatched path must always deny");
});

test("SEC-1: the recursive users catch-all has NOT come back", () => {
  assert.ok(!/allow read, write: if isOwner\(userId\);/.test(rules),
      "the `{subcollection=**}` catch-all granted the owner unconditional " +
      "write on users/{uid} itself and voided every `write: false` beneath it");
  assert.ok(!/\{subcollection=\*\*\}/.test(rules),
      "no recursive users wildcard may exist");
});

test("role protection is intact (canWriteRole still gates the owner write)", () => {
  const usersBlock = extractBlock(rules, "match /users/{userId}");
  assert.match(usersBlock, /canWriteRole\(userId\)/,
      "the immutable-role guard must still gate the owner write");
});

// ── D-9: opportunity authorization ───────────────────────────────────────

test("D-9: opportunity create requires the alumni role", () => {
  const block = extractBlock(rules, "match /opportunities/{opportunityId}");

  assert.match(block, /allow create:[\s\S]*?userRole\(\) == 'alumni'/,
      "any authenticated user could previously broadcast an opportunity");
});

test("D-9: opportunity update and delete require the alumni role AND ownership", () => {
  const block = extractBlock(rules, "match /opportunities/{opportunityId}");

  assert.match(block, /allow update:[\s\S]*?userRole\(\) == 'alumni'/);
  assert.match(block, /allow update:[\s\S]*?resource\.data\.alumniId == request\.auth\.uid/);
  assert.match(block, /allow delete:[\s\S]*?userRole\(\) == 'alumni'/);
  assert.match(block, /allow delete:[\s\S]*?resource\.data\.alumniId == request\.auth\.uid/);
});

test("D-9: opportunity reads stay open to authenticated users", () => {
  const block = extractBlock(rules, "match /opportunities/{opportunityId}");
  assert.match(block, /allow read: if isAuthenticated\(\);/,
      "tightening writes must not have closed reads");
});

// ── D-10: opportunity schema validation ──────────────────────────────────

test("D-10: isValidOpportunityData() exists", () => {
  assert.match(rules, /function isValidOpportunityData\(\)/);
});

test("D-10: the validator checks every required field and type", () => {
  const validator = extractBlock(rules, "function isValidOpportunityData() {");

  for (const required of [
    "request.resource.data.alumniId == request.auth.uid",
    "request.resource.data.title is string",
    "request.resource.data.company is string",
    "request.resource.data.description is string",
    "request.resource.data.location is string",
    "request.resource.data.jobType is string",
    "request.resource.data.postedAt is timestamp",
    "request.resource.data.isActive is bool",
    "request.resource.data.applicationDeadline is timestamp",
  ]) {
    assert.ok(validator.includes(required),
        `isValidOpportunityData must validate: ${required}`);
  }
});

test("D-10: every opportunity write applies the validator", () => {
  const block = extractBlock(rules, "match /opportunities/{opportunityId}");

  assert.match(block, /allow create:[\s\S]*?isValidOpportunityData\(\)/,
      "a malformed document must be rejected BEFORE it can broadcast");
  assert.match(block, /allow update:[\s\S]*?isValidOpportunityData\(\)/);
});

test("D-10: the placement validator is untouched", () => {
  assert.match(rules, /function isValidPlacementData\(\)/);
  const block = extractBlock(rules, "match /placements/{placementId}");
  assert.match(block, /allow create:[\s\S]*?isValidPlacementData\(\)/);
});

// ── D-11: profile flag hardening ─────────────────────────────────────────

test("D-11: the profile-flag guards exist", () => {
  assert.match(rules, /function canWriteProfileFlags\(\)/);
  assert.match(rules, /function profileCompletedWriteOk\(\)/);
  assert.match(rules, /function isVerifiedWriteOk\(\)/);
});

test("D-11: the users owner write applies canWriteProfileFlags()", () => {
  const block = extractBlock(rules, "match /users/{userId}");
  assert.match(block, /allow write:[\s\S]*?canWriteProfileFlags\(\)/,
      "profileCompleted / isVerified must not stay freely client-writable");
});

test("D-11: profileCompleted can only be asserted alongside the required sections", () => {
  const guard = extractBlock(rules, "function profileCompletedWriteOk()");

  for (const required of [
    "personal.fullName is string",
    "academic.college is string",
    "academic.program is string",
    "academic.year is int",
  ]) {
    assert.ok(guard.includes(required),
        `a genuine completion transition must carry: ${required}`);
  }

  // The unchanged-value branch keeps ordinary profile edits (and legacy flat
  // documents) working.
  assert.match(guard, /resource\.data\.get\('profileCompleted', false\)/,
      "an UNCHANGED flag write must stay allowed");
});

test("D-11: isVerified is server-owned", () => {
  const guard = extractBlock(rules, "function isVerifiedWriteOk()");
  assert.match(guard, /request\.resource\.data\.get\('isVerified', false\) ==/,
      "a client write may only ever keep the existing isVerified value");
  assert.ok(!/isVerified == true/.test(guard),
      "no client path may assert isVerified: true");
});

test("D-11: profileCompleted is trusted as a query filter elsewhere (why this matters)", () => {
  assert.match(rules, /resource\.data\.profileCompleted == true/,
      "the alumni-directory read rule depends on the flag being trustworthy");
});
