"use strict";

/**
 * CampusConnect v9.2.5 — the real `HttpsError` for every Functions module.
 *
 * WHY THIS MODULE EXISTS
 * ----------------------
 * Every Functions module in this tree signals a client-visible failure by
 * constructing `new admin.functions.https.HttpsError(code, message, details)`.
 * That convention only works if `admin.functions` exists — and it does NOT.
 * `firebase-admin` (verified against 12.7.0 in this repository's
 * `node_modules`) exposes `auth`, `firestore`, `storage`, `messaging`, …, but
 * **no `functions` provider**, and requiring `firebase-functions` does not
 * add one.
 *
 * `admin.functions` is therefore `undefined`, so every one of those
 * constructions threw
 *
 *     TypeError: Cannot read properties of undefined (reading 'https')
 *
 * `firebase-functions`' `onCall` wrapper turns any non-`HttpsError` thrown by a
 * handler into `HttpsError("internal", "INTERNAL")`. The observable result was:
 *
 *   - a quota rejection (`resource-exhausted` plus its `usage` details) reached
 *     the client as a generic "Server error", so the "monthly limit reached"
 *     UI could never appear;
 *   - `invalid-argument` (too short / too long / bad storage path),
 *     `not-found` (missing resume PDF) and every other specific failure were
 *     collapsed into the same opaque `internal` / `INTERNAL`;
 *   - the function log showed a `TypeError` from this shim's absence instead of
 *     the real cause, and — because the throw also replaced the error inside
 *     `catch` blocks that test `error instanceof HttpsError` — a mislabelled
 *     error could be re-wrapped again on the way out.
 *
 * `installHttpsError()` restores the intended contract by attaching the REAL
 * `HttpsError` class (the same one `firebase-functions/v2/https` exports, so
 * `instanceof` checks inside these modules keep working) to
 * `admin.functions.https`.
 *
 * It is idempotent and never clobbers an already-present value, so:
 *   - the deployed runtime gets the real class exactly once, and
 *   - the unit-test shim (`functions/test/setup.js`) keeps its own stand-in.
 *
 * `functions/index.js` must call `installHttpsError()` **before** requiring any
 * feature module.
 */

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");

/**
 * Attach the real `HttpsError` to `admin.functions.https` when absent.
 *
 * @returns {typeof HttpsError} The class now reachable as
 *   `admin.functions.https.HttpsError`.
 */
function installHttpsError() {
  const existing = admin.functions?.https?.HttpsError;
  if (existing) return existing;

  admin.functions = admin.functions || {};
  admin.functions.https = admin.functions.https || {};
  admin.functions.https.HttpsError = HttpsError;
  return HttpsError;
}

module.exports = {HttpsError, installHttpsError};
