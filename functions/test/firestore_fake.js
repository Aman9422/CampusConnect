"use strict";

/**
 * CampusConnect v9.2 — minimal in-memory Firestore fake for unit tests.
 *
 * Lets the AI quota helpers (`functions/ai/quota.js`) be tested WITHOUT a live
 * Firestore project or the Firestore emulator. It implements exactly the
 * surface those helpers use:
 *
 *   db.collection(name).doc(id)                     -> {get, set}
 *   db.collection(name).where(path, "<", cutoff)
 *       .limit(n).get()                             -> {docs, empty}
 *   db.runTransaction(async (tx) => ...)            -> tx.get/set/update
 *
 * Dotted update/merge paths (e.g. "resumeReview.monthlyCount") and the
 * FieldValue.delete() sentinel are honoured so nested quota maps mutate exactly
 * as Firestore would. Timestamps are value objects (passed through, never
 * cloned) because the real admin Timestamp is used by the production code.
 */

// Sentinel returned by our FieldValue.delete() shim.
const DELETE = {__isDelete: true};

function isDelete(value) {
  return value === DELETE || (value != null && value.__isDelete === true);
}

// Sentinel returned by our FieldValue.increment() shim.
function increment(by) {
  return {__isIncrement: true, __by: by};
}

function isIncrement(value) {
  return value != null && value.__isIncrement === true;
}

/** Apply an increment sentinel to a numeric slot (missing => 0). */
function applyIncrement(current, by) {
  return (typeof current === "number" ? current : 0) + by;
}

// Deterministic unique doc id for a `.doc()` call made without an argument
// (matches Firestore's auto-id behaviour for `collection(...).doc()`).
let autoIdCounter = 0;
function nextAutoId() {
  autoIdCounter += 1;
  return `auto_${autoIdCounter}`;
}

function getPath(obj, path) {
  return path
      .split(".")
      .reduce((acc, key) => (acc == null ? acc : acc[key]), obj);
}

function setPath(obj, path, value) {
  const keys = path.split(".");
  let cursor = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (typeof cursor[keys[i]] !== "object" || cursor[keys[i]] === null) {
      cursor[keys[i]] = {};
    }
    cursor = cursor[keys[i]];
  }
  const last = keys[keys.length - 1];
  if (isDelete(value)) {
    delete cursor[last];
  } else if (isIncrement(value)) {
    cursor[last] = applyIncrement(cursor[last], value.__by);
  } else {
    cursor[last] = value;
  }
}

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  // Treat Timestamp-like values as immutable value objects.
  if (typeof value.toMillis === "function" || typeof value.toDate === "function") {
    return value;
  }
  if (Array.isArray(value)) return value.map(clone);
  const out = {};
  for (const key of Object.keys(value)) out[key] = clone(value[key]);
  return out;
}

function applyMerge(target, value) {
  for (const key of Object.keys(value)) {
    if (key.includes(".")) {
      setPath(target, key, value[key]);
    } else if (isDelete(value[key])) {
      delete target[key];
    } else if (isIncrement(value[key])) {
      target[key] = applyIncrement(target[key], value[key].__by);
    } else {
      target[key] = clone(value[key]);
    }
  }
}

/**
 * Build a fake Firestore instance.
 *
 * @param {object} seed - { collectionName: { docId: dataObject } }
 */
function makeFakeDb(seed) {
  const store = {};
  for (const collection of Object.keys(seed || {})) {
    store[collection] = {};
    for (const id of Object.keys(seed[collection])) {
      store[collection][id] = clone(seed[collection][id]);
    }
  }

  function doc(colName, id) {
    const docId = id == null ? nextAutoId() : id;
    return {
      __collection: colName,
      __id: docId,
      // Nested subcollections are flattened to a "/"-joined store key so
      // `users/{u}/activities` is a distinct collection from a top-level one.
      collection: (sub) => collection(`${colName}/${docId}/${sub}`),
      async get() {
        const data = store[colName] ? store[colName][docId] : undefined;
        return {
          exists: data !== undefined,
          id: docId,
          data: () => (data === undefined ? undefined : clone(data)),
        };
      },
      async set(value, opts) {
        if (!store[colName]) store[colName] = {};
        if (opts && opts.merge) {
          // Merge always applies field transforms (e.g. increment) against the
          // existing doc OR 0 when the doc does not exist yet, exactly as
          // Firestore's `set(..., {merge:true})` does.
          if (!store[colName][docId]) store[colName][docId] = {};
          applyMerge(store[colName][docId], value);
        } else {
          store[colName][docId] = clone(value);
        }
      },
    };
  }

  function collection(name) {
    if (!store[name]) store[name] = {};
    return {
      doc: (id) => doc(name, id),
      async get() {
        const docs = Object.keys(store[name]).map((id) => ({
          id,
          ref: doc(name, id),
          data: () => clone(store[name][id]),
        }));
        return {docs, empty: docs.length === 0};
      },
      where(path, op, value) {
        const query = {
          __limit: Infinity,
          limit(n) {
            this.__limit = n;
            return this;
          },
          async get() {
            const matched = [];
            for (const id of Object.keys(store[name])) {
              const data = store[name][id];
              const fieldValue = getPath(data, path);
              if (
                op === "<" &&
                fieldValue &&
                typeof fieldValue.toMillis === "function" &&
                value &&
                typeof value.toMillis === "function" &&
                fieldValue.toMillis() < value.toMillis()
              ) {
                matched.push({id, data: () => clone(data)});
              }
            }
            return {
              docs: matched.slice(0, this.__limit),
              empty: matched.length === 0,
            };
          },
        };
        return query;
      },
    };
  }

  return {
    collection,
    async runTransaction(fn) {
      const transaction = {
        async get(ref) {
          const data = store[ref.__collection]
            ? store[ref.__collection][ref.__id]
            : undefined;
          return {
            exists: data !== undefined,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        set(ref, value, opts) {
          if (!store[ref.__collection]) store[ref.__collection] = {};
          if (opts && opts.merge) {
            if (!store[ref.__collection][ref.__id]) {
              store[ref.__collection][ref.__id] = {};
            }
            applyMerge(store[ref.__collection][ref.__id], value);
          } else {
            store[ref.__collection][ref.__id] = clone(value);
          }
        },
        update(ref, value) {
          if (!store[ref.__collection]) store[ref.__collection] = {};
          if (!store[ref.__collection][ref.__id]) {
            store[ref.__collection][ref.__id] = {};
          }
          applyMerge(store[ref.__collection][ref.__id], value);
        },
      };
      return fn(transaction);
    },
    // Test-only handle onto the raw store for assertions.
    __store: store,
  };
}

module.exports = {makeFakeDb, DELETE, increment};
