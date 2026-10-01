"use strict";

/**
 * CampusConnect v9.2 — placement application STATUS state machine tests.
 *
 * Guards the SEC-3 contract: `updateApplicationStatus` must only accept a
 * transition that is legal from the application's CURRENT status. A scripted
 * teacher/alumni calling the callable directly must not be able to jump
 * `applied → placed` or move a terminal application (`placed`/`rejected`).
 *
 * The transition TABLE is pure data, so it is tested directly against its
 * exported source of truth rather than through a live Firestore transaction.
 * If the table ever drifts (a status added/removed without updating the
 * terminal set, or a terminal state gaining an outgoing edge) this fails.
 *
 * Run:  node --test test/placement_transitions.test.js  (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");

// Install the shared runtime shim BEFORE requiring the production module.
require("./setup");

const placements = require("../placements");

const {APPLICATION_STATUSES, STATUS_TRANSITIONS} = placements;

// ── Helpers ──────────────────────────────────────────────────────────────

/** True when `from -> to` is accepted by the exported state machine. */
function canTransition(from, to) {
  const legalNext = STATUS_TRANSITIONS[from] || [];
  return legalNext.includes(to);
}

// ── Tests ────────────────────────────────────────────────────────────────

test("STATUS_TRANSITIONS: every state is a key (no undefined lookup)", () => {
  const states = ["applied", ...APPLICATION_STATUSES];
  for (const state of states) {
    assert.ok(
        Object.prototype.hasOwnProperty.call(STATUS_TRANSITIONS, state),
        `state "${state}" must exist in the transition table`,
    );
    assert.ok(
        Array.isArray(STATUS_TRANSITIONS[state]),
        `state "${state}" must map to an array of next states`,
    );
  }
});

test("STATUS_TRANSITIONS: every declared next state is a real application status", () => {
  for (const [from, tos] of Object.entries(STATUS_TRANSITIONS)) {
    for (const to of tos) {
      assert.ok(
          APPLICATION_STATUSES.includes(to),
          `transition ${from} -> ${to}: "${to}" is not an APPLICATION_STATUS`,
      );
    }
  }
});

test("SEC-3: the forward pipeline is legal step by step", () => {
  assert.equal(canTransition("applied", "shortlisted"), true);
  assert.equal(canTransition("shortlisted", "interviewed"), true);
  assert.equal(canTransition("interviewed", "placed"), true);
});

test("SEC-3: applied CANNOT jump straight to placed or interviewed", () => {
  assert.equal(canTransition("applied", "placed"), false,
      "applied -> placed must be rejected (the core SEC-3 hole)");
  assert.equal(canTransition("applied", "interviewed"), false,
      "applied -> interviewed must be rejected");
});

test("SEC-3: any non-terminal state may reject", () => {
  assert.equal(canTransition("applied", "rejected"), true);
  assert.equal(canTransition("shortlisted", "rejected"), true);
  assert.equal(canTransition("interviewed", "rejected"), true);
});

test("SEC-3: terminal states have NO outgoing transitions", () => {
  for (const terminal of ["placed", "rejected"]) {
    assert.deepEqual(
        STATUS_TRANSITIONS[terminal],
        [],
        `"${terminal}" is terminal and must have no outgoing transitions`,
    );
    // And nothing may transition INTO itself or backwards from terminal.
    assert.equal(canTransition(terminal, "shortlisted"), false);
    assert.equal(canTransition(terminal, "interviewed"), false);
    assert.equal(canTransition(terminal, "applied"), false);
  }
});

test("SEC-3: no state may transition to itself", () => {
  for (const [from, tos] of Object.entries(STATUS_TRANSITIONS)) {
    assert.equal(tos.includes(from), false, `${from} must not transition to itself`);
  }
});

test("SEC-3: 'applied' is a valid previous state but is not a settable target status", () => {
  // `applied` is the create-time status; the callable may not set it back.
  assert.equal(APPLICATION_STATUSES.includes("applied"), false,
      "'applied' is the initial state, not a transition target");
  assert.equal(canTransition("applied", "applied"), false);
  assert.equal(canTransition("shortlisted", "applied"), false);
});

test("STATUS_TRANSITIONS: only the forward chain increases pipeline stage", () => {
  // Ranking of pipeline depth — a transition must never move backwards except
  // to the terminal `rejected` sink.
  const depth = {applied: 0, shortlisted: 1, interviewed: 2, placed: 3};
  for (const [from, tos] of Object.entries(STATUS_TRANSITIONS)) {
    for (const to of tos) {
      if (to === "rejected") continue; // terminal sink, always allowed from non-terminal
      assert.ok(
          depth[to] > depth[from],
          `${from} -> ${to} must advance the pipeline (no backward moves)`,
      );
    }
  }
});
