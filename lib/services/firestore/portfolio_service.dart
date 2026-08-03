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

  /// Fetch the portfolio for a specific user by UID.
  /// Returns an empty portfolio when the document or portfolio key is missing.
  ///
  /// F9: genuine errors (permission denied, network failure) are rethrown so
  /// callers can distinguish "no portfolio yet" from "failed to load". The
  /// previous behaviour swallowed every error and returned an empty portfolio,
  /// which made the read-only view show "no portfolio" on permission errors.
  Future<PortfolioModel> getPortfolio(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return PortfolioModel.empty();

    final data = doc.data() as Map<String, dynamic>?;
    final portfolioData = data?['portfolio'] as Map<String, dynamic>?;
    if (portfolioData == null) return PortfolioModel.empty();

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
  Stream<PortfolioModel> portfolioStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return PortfolioModel.empty();
      final data = doc.data() as Map<String, dynamic>?;
      final portfolioData = data?['portfolio'] as Map<String, dynamic>?;
      if (portfolioData == null) return PortfolioModel.empty();
      return PortfolioModel.fromMap(portfolioData);
    });
  }
}
