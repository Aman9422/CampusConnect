import 'package:campusconnect/models/portfolio/portfolio_model.dart';
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

  CollectionReference get _usersCollection => _firestore.collection('users');

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

    final flatPortfolioKeys = data.keys
        .where((key) => key.startsWith('portfolio.') && key.length > 10)
        .toList();
    if (flatPortfolioKeys.isEmpty) {
      return null;
    }

    final flat = <String, dynamic>{};
    for (final key in flatPortfolioKeys) {
      flat[key.substring('portfolio.'.length)] = data[key];
    }
    return _unflattenPaths(flat);
  }

  /// Converts dot-path keys into a nested map, e.g.:
  ///   `resume.downloadUrl` → `{ 'resume': { 'downloadUrl': value } }`
  ///   `projects` (list)     → `{ 'projects': [...] }`
  Map<String, dynamic> _unflattenPaths(Map<String, dynamic> flat) {
    final result = <String, dynamic>{};
    for (final entry in flat.entries) {
      final path = entry.key.split('.');
      var cursor = result;
      for (var i = 0; i < path.length - 1; i++) {
        final segment = path[i];
        cursor = cursor.putIfAbsent(segment, () => <String, dynamic>{})
            as Map<String, dynamic>;
      }
      cursor[path.last] = entry.value;
    }
    return result;
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
      final rawPortfolio = data?['portfolio'];
      debugPrint(
        'PortfolioService.getPortfolio: doc USERS/$uid EXISTS but '
        'portfolio key is ${rawPortfolio == null ? 'MISSING' : 'not a map'}. '
        'Doc keys present: ${data?.keys ?? const []}',
      );
      return PortfolioModel.empty();
    }

    return PortfolioModel.fromMap(portfolioData);
  }

  /// Persist the portfolio under `users/{uid}/portfolio`.
  ///
  /// H4 (F5): saves are now per-section diffs. When [previous] is supplied,
  /// only the sections whose value actually changed are written, and each is
  /// written as a dotted path (`portfolio.skills`, `portfolio.projects`, …)
  /// with merge semantics. The old whole-map write replaced every section on
  /// every save, clobbering sibling/remote edits performed on another device.
  /// When [previous] is null this writes every section (first save).
  Future<void> savePortfolio(
    String uid,
    PortfolioModel portfolio, {
    PortfolioModel? previous,
  }) async {
    try {
      final incoming = portfolio.toMap();
      final prior = previous?.toMap() ?? const <String, dynamic>{};
      final update = <String, dynamic>{};

      incoming.forEach((key, value) {
        final changed =
            !prior.containsKey(key) || !_deepEquals(prior[key], value);
        if (changed) {
          update['portfolio.$key'] = value;
        }
      });

      await _usersCollection.doc(uid).set({
        ...update,
        'metadata.updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

  /// Stream portfolio changes in real time (owner is the only writer).
  ///
  /// v8.4.9 (MB17): uses the same tolerant [_extractPortfolioMap] as
  /// [getPortfolio] so a doc whose portfolio is stored as flattened
  /// root-level `portfolio.*` keys (Firebase-console edits / legacy writers)
  /// stream the REAL portfolio instead of an empty one.
  Stream<PortfolioModel> portfolioStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return PortfolioModel.empty();
      final data = doc.data() as Map<String, dynamic>?;
      final portfolioData = _extractPortfolioMap(data);
      if (portfolioData == null) return PortfolioModel.empty();
      return PortfolioModel.fromMap(portfolioData);
    });
  }
}
