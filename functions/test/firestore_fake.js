"use strict";

/**
 * CampusConnect v9.2 — minimal in-memory Firestore fake for unit tests.
 *
 * Lets production Cloud Functions modules be tested WITHOUT a live Firestore
 * project or the Firestore emulator. Implemented surface:
 *
 *   db.collection(name).doc(id)                     -> {get, set, collection}
 *   db.collection(name).get()                       -> {docs, empty}
 *   db.collection(name).where(path, op, value)
 *       [.where(...)] [.orderBy(...)] [.startAfter(...)]
 *       .limit(n).get()                             -> {docs, empty}
 *   db.runTransaction(async (tx) => ...)            -> tx.get/set/update
 *   db.batch()                                      -> set/update/delete/commit
 *
 * Supported filter operators: `==`, `!=`, `<`, `<=`, `>`, `>=` (Timestamps
 * compare by instant, numbers numerically; anything else never matches an
 * ordered filter). Repeated `.where()` calls AND together, and a query with no
 * `orderBy` uses Firestore's implicit document-id ordering.
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

// ===============================================
// QUERY FILTER SUPPORT (v9.2.4)
// ===============================================
//
// v9.2.4 (E-3/D-1) extended this fake so the new hardening suites can drive the
// production code paths that need more than `where(path, "<", cutoff)`:
//   - equality filters (`where("isActive", "==", true)`) and `<=`/`>`/`>=`;
//   - repeated `.where()` filters (AND-ed) plus `.limit()`, `.orderBy()` and
//     `.startAfter()` (document-id ordering by default, as Firestore does);
//   - `db.batch()` with set/update/delete/commit.
// The previous `<`-on-timestamps-only behaviour is preserved for existing
// suites (quota sweeps) and generalised to numbers, which is a superset.

/**
 * Equality as Firestore's `==` filter behaves for the value types these tests
 * use: Timestamps compare by instant, primitives by value, everything else by
 * its structural JSON form.
 */
function valueEquals(left, right) {
  if (left === right) return true;
  if (left == null || right == null) return left == null && right == null;
  if (typeof left.toMillis === "function" && typeof right.toMillis === "function") {
    return left.toMillis() === right.toMillis();
  }
  if (typeof left !== "object" || typeof right !== "object") return false;
  return JSON.stringify(left) === JSON.stringify(right);
}

/**
 * Ordered comparison of two Timestamp-or-number values. Returns null when the
 * pair is not orderable (Firestore simply does not match such a filter).
 */
function compareValues(left, right) {
  let a = left;
  let b = right;
  if (a != null && typeof a.toMillis === "function") a = a.toMillis();
  if (b != null && typeof b.toMillis === "function") b = b.toMillis();
  if (typeof a !== "number" || typeof b !== "number") return null;
  return a - b;
}

/** Apply one `{path, op, value}` filter to a stored document. */
function matchesFilter(data, filter) {
  const fieldValue = getPath(data, filter.path);
  if (filter.op === "==") return valueEquals(fieldValue, filter.value);
  if (filter.op === "!=") return !valueEquals(fieldValue, filter.value);
  const comparison = compareValues(fieldValue, filter.value);
  if (comparison === null) return false;
  if (filter.op === "<") return comparison < 0;
  if (filter.op === "<=") return comparison <= 0;
  if (filter.op === ">") return comparison > 0;
  if (filter.op === ">=") return comparison >= 0;
  return false;
}

/** `ref.set(value, opts)` applied directly to the store. */
function applySet(store, ref, value, opts) {
  const colName = ref.__collection;
  if (!store[colName]) store[colName] = {};
  if (opts && opts.merge) {
    if (!store[colName][ref.__id]) store[colName][ref.__id] = {};
    applyMerge(store[colName][ref.__id], value);
  } else {
    store[colName][ref.__id] = clone(value);
  }
}

/** `ref.update(value)` (dotted-path merge) applied directly to the store. */
function applyUpdate(store, ref, value) {
  const colName = ref.__collection;
  if (!store[colName]) store[colName] = {};
  if (!store[colName][ref.__id]) store[colName][ref.__id] = {};
  applyMerge(store[colName][ref.__id], value);
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

    // Chainable query: every `.where()` AND-s another filter.
    function buildQuery(filters) {
      return {
        __limit: Infinity,
        __orderBy: null,
        __startAfter: null,
        where: (path, op, value) => buildQuery([...filters, {path, op, value}]),
        limit(n) {
          this.__limit = n;
          return this;
        },
        orderBy(path, direction) {
          this.__orderBy = {path, direction: direction || "asc"};
          return this;
        },
        startAfter(cursor) {
          // `cursor` is a previous snapshot (implicit document-id ordering).
          this.__startAfter = cursor && cursor.id != null ? cursor.id : cursor;
          return this;
        },
        async get() {
          let ids = Object.keys(store[name]).filter((id) =>
            filters.every((filter) => matchesFilter(store[name][id], filter)));

          if (this.__orderBy) {
            const {path: orderPath, direction} = this.__orderBy;
            const sign = direction === "desc" ? -1 : 1;
            ids.sort((left, right) => {
              const comparison = compareValues(
                  getPath(store[name][left], orderPath),
                  getPath(store[name][right], orderPath));
              return comparison === null ? 0 : comparison * sign;
            });
          } else {
            ids.sort(); // Firestore's implicit document-id ordering
          }

          if (this.__startAfter != null) {
            const cursor = this.__startAfter;
            const index = ids.indexOf(cursor);
            ids = index === -1
              ? ids.filter((id) => id > cursor)
              : ids.slice(index + 1);
          }

          const docs = ids.slice(0, this.__limit).map((id) => ({
            id,
            ref: doc(name, id),
            data: () => clone(store[name][id]),
          }));
          return {docs, empty: docs.length === 0};
        },
      };
    }

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
      where: (path, op, value) => buildQuery([{path, op, value}]),
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
    /**
     * v9.2.4 (E-3): batched writes. Operations are queued and applied on
     * `commit()`, mirroring Firestore (nothing lands if a commit never runs).
     */
    batch() {
      const operations = [];
      return {
        set(ref, value, opts) {
          operations.push(() => applySet(store, ref, value, opts));
        },
        update(ref, value) {
          operations.push(() => applyUpdate(store, ref, value));
        },
        delete(ref) {
          operations.push(() => {
            if (store[ref.__collection]) delete store[ref.__collection][ref.__id];
          });
        },
        async commit() {
          const queued = operations.splice(0, operations.length);
          for (const operation of queued) operation();
        },
      };
    },
    // Test-only handle onto the raw store for assertions.
    __store: store,
  };
}

module.exports = {makeFakeDb, DELETE, increment};
