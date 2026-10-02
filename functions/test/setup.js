"use strict";

/**
 * CampusConnect v9.2 — shared test runtime shim.
 *
 * Prepares a Node process so the production Functions modules can be required
 * and driven WITHOUT a Firebase project or emulator:
 *
 *   - `firebase-admin`'s getter-only `firestore` is replaced (via the require
 *     cache) with a small in-memory fake (test/firestore_fake.js);
 *   - `admin.functions.https.HttpsError` is provided as the callable-error
 *     stand-in for these tests. NOTE (v9.2.5): the deployed Cloud Functions
 *     runtime does NOT provide `admin.functions` at all — in production the
 *     REAL class is installed by `helpers/https_error.js`, which
 *     `functions/index.js` runs before it requires any feature module. This
 *     stand-in exists so the production modules can be driven here without a
 *     firebase-functions callable runtime;
 *   - the real firebase-admin `Timestamp` value class is preserved so quota
 *     maps under test use the same timestamp type as production.
 *
 * Require this module BEFORE requiring any production module that uses
 * `admin.firestore()` / `admin.functions`.
 */

const {makeFakeDb, DELETE, increment} = require("./firestore_fake");

// Real firebase-admin (for the Timestamp value class only).
const adminPath = require.resolve("firebase-admin");
const realAdmin = require(adminPath);
const Timestamp = realAdmin.firestore.Timestamp;

/** HttpsError stand-in matching firebase-functions' callable error shape. */
class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

let currentDb = makeFakeDb({});

function fakeFirestore() {
  return currentDb;
}
fakeFirestore.Timestamp = Timestamp;
fakeFirestore.FieldValue = {
  delete: () => DELETE,
  serverTimestamp: () => ({__serverTimestamp: true}),
  increment: (by) => increment(by),
};

// Replace the cached firebase-admin export so every production module that does
// `require("firebase-admin")` receives the fake (the property itself is
// getter-only and cannot be reassigned).
require.cache[adminPath].exports = {
  firestore: fakeFirestore,
  functions: {https: {HttpsError: FakeHttpsError}},
};

/**
 * Install a fresh in-memory database as the active Firestore instance.
 * @param {object} seed - { collectionName: { docId: dataObject } }
 * @returns {object} the fake db (with `__store` for assertions)
 */
function seedDb(seed) {
  currentDb = makeFakeDb(seed);
  return currentDb;
}

module.exports = {Timestamp, seedDb, FakeHttpsError};
