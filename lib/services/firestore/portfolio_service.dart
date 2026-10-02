import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/portfolio_snapshot.dart';
import 'package:campusconnect/services/firestore/portfolio_migration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.4 — PortfolioService
///
/// Handles all Firestore operations for the student resume portfolio.
///
/// The portfolio lives as a nested map under `users/{uid}/portfolio` in the
/// existing users collection. All writes use `SetOptions(merge: true)` so the
/// rest of the user document (role, academic info, root skills, etc.) is
/// never touched — keeping v8.4 fully compatible with the current schema.
class PortfolioService {
  final FirebaseFirestore _firestore;

  PortfolioService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final PortfolioService _instance = PortfolioService();
  factory PortfolioService.instance() => _instance;

  /// Cap on a single portfolio write before it is treated as hung.
  /// Shared by the provider's save path and ResumeService's metadata write.
  static const Duration saveTimeout = Duration(seconds: 20);

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Builds the Firestore payload for a portfolio write.
  ///
  /// The portfolio is ALWAYS addressed as the canonical NESTED map —
  /// `{'portfolio': {'resume': {...}, 'skills': […]}}` — and never through
  /// dot-notation keys such as `'portfolio.resume'`.
  ///
  /// Rationale (v9.2.7, RESUME-WRITE fix): dot notation is a feature of
  /// `update()` / `SetOptions(mergeFields:)` only. In a `set(…, merge: true)`
  /// payload Firestore stores a key containing a dot as a literal root-level
  /// field NAME. Both writers of this project did exactly that:
  ///   * the client (`PortfolioService.savePortfolio`) wrote `portfolio.resume`,
  ///     `portfolio.skills`, … and
  ///   * `onResumeReviewCreatedRefreshMatches` in `functions/triggers/index.js`
  ///     wrote `portfolio.resume.reviewCount`, `…latestATSScore`, …
  /// which is the "flattened" document shape this file's reader has always
  /// compensated for. It stayed harmless only while the document had no nested
  /// map. Once [migrateFlattenedPortfolio] had written the canonical nested
  /// `portfolio` map, the reader started preferring it — and every later dotted
  /// write landed in flat fields the reader ignores, so a resume
  /// upload/replace/remove reported success (the Storage object really was
  /// written/deleted) while the stored metadata and download URL never changed.
  ///
  /// [updatedAt] is written as a nested `metadata.updatedAt` stamp for the same
  /// reason, so the value reaches the field the recommendation trigger reads
  /// instead of a literal `metadata.updatedAt` root field.
  ///
  /// Static (no Firestore instance required) so the payload shape is unit
  /// testable — see `test/portfolio_write_payload_test.dart`.
  @visibleForTesting
  static Map<String, dynamic> buildPortfolioWritePayload({
    required Map<String, dynamic> changedSections,
    required Object updatedAt,
  }) {
    return <String, dynamic>{
      if (changedSections.isNotEmpty) 'portfolio': changedSections,
      'metadata': <String, dynamic>{'updatedAt': updatedAt},
    };
  }

  /// Extract the portfolio section map from a user document.
  ///
  /// v8.4.9 (MB17): the app writes the canonical NESTED shape
  /// (`portfolio.skills`, `portfolio.projects`, …), but Firebase-console JSON
  /// edits and legacy writers store FLATTENED root-level keys whose NAMES
  /// contain dots (`portfolio.resume`, `portfolio.projects`,
  /// `portfolio.resume.downloadUrl`, …). The reader previously looked only at
  /// `data['portfolio']`, so a flattened doc returned empty even though the
  /// console clearly held all the data — the confirmed mechanism behind
  /// Symptom 1. This helper handles both shapes:
  ///   1. Nested `portfolio` map → returned as-is.
  ///   2. Otherwise, any root-level key starting with `portfolio.` is
  ///      un-flattened through `_unflattenPaths` into a (possibly nested)
  ///      portfolio map. Keys with a LONGER path than one segment are
  ///      re-nested under their section (e.g. `portfolio.resume.downloadUrl`
  ///      becomes `portfolios['resume']['downloadUrl']`).
  ///   3. No nested map and no dotted keys → null (caller returns empty).
  Map<String, dynamic>? _extractPortfolioMap(Map<String, dynamic>? data) {
    if (data == null) return null;

    final nested = data['portfolio'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }

    // v9.2.2 (§4): flatten detection + un-flattening are now SHARED with the
    // migration planner (`portfolio_migration.dart`) so the tolerant reader and
    // the migrator interpret the legacy shape identically.
    final flatPortfolioKeys = flattenedPortfolioKeys(data);
    if (flatPortfolioKeys.isEmpty) {
      return null;
    }

    final flat = <String, dynamic>{};
    for (final key in flatPortfolioKeys) {
      flat[key.substring(portfolioKeyPrefix.length)] = data[key];
    }
    return unflattenPortfolioPaths(flat);
  }

  /// Fetch the portfolio for a specific user by UID.
  /// Returns an empty portfolio when the document or portfolio key is missing.
  ///
  /// F9: genuine errors (permission denied, network failure) are rethrown so
  /// callers can distinguish "no portfolio yet" from "failed to load". The
  /// previous behaviour swallowed every error and returned an empty portfolio,
  /// which made the read-only view show "no portfolio" on permission errors.
  ///
  /// v8.4.8 (MB13): when a user document EXISTS but has no `portfolio` key, a
  /// diagnostic is printed with the uid and the keys actually present on the
  /// doc. This distinguishes the two "console has data, app shows empty"
  /// scenarios in one debug run:
  ///   - UID mismatch (candidate A): the console data lives under a DIFFERENT
  ///     uid than the one the app is logged in as — the doc for THIS uid has
  ///     no `portfolio` key.
  ///   - Wiped doc (candidates B/C): the doc for THIS uid exists but its
  ///     `portfolio` was overwritten/never written (e.g. `createProfile`'s
  ///     non-merge `set()`).
  /// The `portfolio` value is also read with a type check instead of a cast
  /// so a malformed (non-map) `portfolio` field degrades to empty + logs
  /// rather than throwing a TypeError.
  ///
  /// v8.4.9 (MB17): a doc with FLATTENED root-level `portfolio.*` keys (see
  /// [_extractPortfolioMap]) now parses to the real portfolio instead of
  /// empty — this was the true root cause of "console has data, app shows
  /// empty" confirmed on-device by the MB13 diagnostic.
  Future<PortfolioModel> getPortfolio(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return PortfolioModel.empty();

    final data = doc.data() as Map<String, dynamic>?;
    final portfolioData = _extractPortfolioMap(data);
    if (portfolioData == null) {
      // v8.8.3 (audit-discovered noise): only Students maintain a portfolio.
      // Alumni/Teachers legitimately have no `portfolio` key — a missing key
      // for them is the EXPECTED state, not the "console has data, app shows
      // empty" symptom the MB13 diagnostic was built to catch. Gate the
      // diagnostic on the student role so alumni/teacher sessions stop
      // logging a confusing "portfolio key is MISSING" line on every cold
      // start. Students keep the diagnostic — it remains the key debug
      // signal for student portfolio read failures.
      final isStudent = data?['role'] == 'student';
      final rawPortfolio = data?['portfolio'];
      if (isStudent) {
        debugPrint(
          'PortfolioService.getPortfolio: doc USERS/$uid EXISTS but '
          'portfolio key is ${rawPortfolio == null ? 'MISSING' : 'not a map'}. '
          'Doc keys present: ${data?.keys ?? const []}',
        );
      }
      return PortfolioModel.empty();
    }

    return PortfolioModel.fromMap(portfolioData);
  }

  /// Reads the portfolio PREFERRING the server, so a user-initiated refresh can
  /// never adopt a stale locally cached value.
  ///
  /// v9.2.7: [getPortfolio] uses the default source, which may serve the local
  /// cache. That is fine for a first paint, but a refresh or a post-write
  /// reconciliation must see server truth — otherwise a cached pre-write
  /// snapshot can overwrite the value the user just saved (the "pull to
  /// refresh and the removed resume is back" symptom). When the server read
  /// fails (offline) the local cache is used and the result is flagged
  /// [PortfolioSnapshot.isFromCache] so the caller can keep its own value.
  Future<PortfolioSnapshot> readPortfolioSnapshot(String uid) async {
    final docRef = _usersCollection.doc(uid);
    try {
      final doc = await docRef.get(const GetOptions(source: Source.server));
      return _toSnapshot(doc);
    } catch (e) {
      debugPrint('PortfolioService.readPortfolioSnapshot server read: $e');
      final doc = await docRef.get();
      return _toSnapshot(doc);
    }
  }

  /// Persist the portfolio under `users/{uid}/portfolio`.
  ///
  /// H4 (F5): saves are per-section diffs. When [previous] is supplied, only
  /// the sections whose value actually changed are written, so sibling/remote
  /// edits made on another device are not clobbered. When [previous] is null
  /// every section is written (first save / repair).
  ///
  /// v9.2.7 (RESUME-WRITE fix): the payload is the canonical NESTED map —
  /// `{'portfolio': {'resume': {...}, …}}` — and never dot-notation keys such
  /// as `'portfolio.resume'`. See [buildPortfolioWritePayload] for why the
  /// dotted form silently wrote to fields no reader looks at.
  ///
  /// Merge semantics still hold: `portfolio` is a map value, so Firestore
  /// deep-merges it into the existing nested map and only the supplied
  /// sections are touched. A changed section is written verbatim, so a cleared
  /// resume arrives as `resume: null` and replaces the whole map (scalars and
  /// nulls replace, maps merge).
  Future<void> savePortfolio(
    String uid,
    PortfolioModel portfolio, {
    PortfolioModel? previous,
  }) async {
    try {
      final incoming = portfolio.toMap();
      final prior = previous?.toMap() ?? const <String, dynamic>{};
      final changedSections = <String, dynamic>{};

      incoming.forEach((key, value) {
        final changed =
            !prior.containsKey(key) || !_deepEquals(prior[key], value);
        if (changed) {
          changedSections[key] = value;
        }
      });

      await _usersCollection
          .doc(uid)
          .set(
            buildPortfolioWritePayload(
              changedSections: changedSections,
              updatedAt: FieldValue.serverTimestamp(),
            ),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('PortfolioService: Error saving portfolio: $e');
      rethrow;
    }
  }

  /// Structural equality across the primitive/nested shapes produced by
  /// `PortfolioModel.toMap()` (DateTime, Timestamp, List, Map, String, int).
  bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a is DateTime && b is DateTime) return a == b;
    if (a is Timestamp && b is Timestamp) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      final aMap = Map<Object?, Object?>.from(a);
      final bMap = Map<Object?, Object?>.from(b);
      if (aMap.length != bMap.length) return false;
      for (final key in aMap.keys) {
        if (!bMap.containsKey(key) || !_deepEquals(aMap[key], bMap[key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  /// Check whether the raw Firestore document for [uid] has a flattened
  /// portfolio shape (root-level `portfolio.*` keys instead of a nested
  /// `portfolio` map). When true, the next `savePortfolio` call should use
  /// a full (non-diff) write to reconstitute the canonical nested shape.
  ///
  /// v9.0 (BUG-3 fix): detects the flattened shape so the provider can
  /// force a full save that overwrites the flat keys with the nested map.
  ///
  /// v9.2.2 (§4): kept as the **fallback** signal for when the automatic
  /// migration cannot run (offline / permission). The primary path is now
  /// [migrateFlattenedPortfolio], which performs the migration instead of
  /// only flagging it.
  Future<bool> hasFlattenedPortfolioShape(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      return planPortfolioMigration(data) != null;
    } catch (e) {
      debugPrint('PortfolioService.hasFlattenedPortfolioShape error: $e');
      return false;
    }
  }

  /// v9.2.2 (§4 — Portfolio compatibility cleanup): perform the SAFE, one-time,
  /// idempotent migration of a legacy FLATTENED portfolio document into the
  /// canonical nested shape.
  ///
  /// The legacy shape stores the portfolio as root-level keys whose names carry
  /// dots (`portfolio.resume`, `portfolio.projects`,
  /// `portfolio.resume.downloadUrl`, …). Reads already tolerate it (MB17) and
  /// the engine mirrors that tolerance, but until the document is rewritten the
  /// compatibility path runs on **every login** — the repeated runtime-log line
  /// `detected flattened portfolio shape … next save will use full (non-diff)
  /// write` — and the previous v9.0 behaviour required a manual user save that
  /// also never removed the legacy keys.
  ///
  /// This method reconstructs the nested map from the flattened values
  /// (verbatim — see [planPortfolioMigration]) and, in **one atomic merge
  /// write**, writes it under `portfolio` while DELETING every legacy flat key
  /// and stamping `metadata.portfolioMigratedAt`. No portfolio content is lost,
  /// transformed or invented.
  ///
  /// Idempotent: after it runs, the document has the nested map, so
  /// [planPortfolioMigration] returns `null` and a second run is a no-op.
  ///
  /// Returns [PortfolioMigrationResult.migrated] only when a write was issued,
  /// [PortfolioMigrationResult.notApplicable] when there was nothing to do or
  /// the caller is not the portfolio owner, and [PortfolioMigrationResult.failed]
  /// when the write could not complete (callers keep the flag-and-full-save
  /// fallback in that case).
  Future<PortfolioMigrationResult> migrateFlattenedPortfolio(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return PortfolioMigrationResult.notApplicable;
      final data = doc.data() as Map<String, dynamic>?;
      final plan = planPortfolioMigration(data);
      if (plan == null) return PortfolioMigrationResult.notApplicable;

      final update = <String, dynamic>{
        // Canonical nested map — replaces the flattened representation.
        'portfolio': plan.nestedPortfolio,
        // Observability stamp only; carries no user data.
        //
        // v9.2.7: written as a NESTED `metadata` map. A dotted
        // `'metadata.portfolioMigratedAt'` key in a merge-set payload is a
        // literal root-level field name, not a field path, so the stamp used
        // to land beside the real `metadata` map instead of inside it.
        'metadata': <String, dynamic>{
          'portfolioMigratedAt': FieldValue.serverTimestamp(),
        },
      };
      // Remove the legacy root-level dotted keys so the document is canonical
      // and the compatibility path is never needed again.
      //
      // These keys are LITERAL field names that happen to contain dots (the
      // flattened shape), so naming them verbatim is exactly right here: the
      // delete target is the flat field, not a nested path.
      for (final key in plan.flattenedKeysToDelete) {
        update[key] = FieldValue.delete();
      }

      await _usersCollection
          .doc(uid)
          .set(update, SetOptions(merge: true))
          .timeout(saveTimeout);
      debugPrint(
        'PortfolioService: migrated flattened portfolio for $uid '
        '(${plan.flattenedKeysToDelete.length} legacy keys removed)',
      );
      return PortfolioMigrationResult.migrated;
    } catch (e) {
      debugPrint('PortfolioService.migrateFlattenedPortfolio error: $e');
      return PortfolioMigrationResult.failed;
    }
  }

  /// Parses a document snapshot into a [PortfolioSnapshot], preserving the
  /// Firestore cache/pending-write flags.
  ///
  /// v8.4.9 (MB17) tolerance preserved: the same [_extractPortfolioMap] is
  /// used for streams and one-shot reads, so a document whose portfolio is
  /// stored as flattened root-level `portfolio.*` keys still parses to the
  /// real portfolio instead of an empty one.
  PortfolioSnapshot _toSnapshot(DocumentSnapshot doc) {
    final metadata = doc.metadata;
    final data = doc.exists ? doc.data() as Map<String, dynamic>? : null;
    final portfolioData = _extractPortfolioMap(data);
    return PortfolioSnapshot(
      portfolio: portfolioData == null
          ? PortfolioModel.empty()
          : PortfolioModel.fromMap(portfolioData),
      isFromCache: metadata.isFromCache,
      hasPendingWrites: metadata.hasPendingWrites,
    );
  }

  /// Streams portfolios WITH their cache/pending-write flags.
  ///
  /// v9.2.7: this is the stream the provider listens to. `isFromCache` is what
  /// lets the listener refuse to overwrite committed in-memory state with a
  /// replayed pre-write snapshot — the mechanism that used to resurrect a
  /// removed resume and revert a freshly uploaded one.
  Stream<PortfolioSnapshot> portfolioSnapshotStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) => _toSnapshot(doc));
  }

  /// Stream portfolio changes in real time (owner is the only writer).
  ///
  /// Model-only convenience over [portfolioSnapshotStream] for callers that do
  /// not need the cache flags.
  Stream<PortfolioModel> portfolioStream(String uid) =>
      portfolioSnapshotStream(uid).map((snapshot) => snapshot.portfolio);
}
