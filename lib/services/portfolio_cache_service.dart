import 'dart:convert';

import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CampusConnect v8.4.3 (MB2) — Offline-first portfolio cache.
///
/// Persists a lightweight JSON snapshot of the student portfolio in
/// SharedPreferences so the last-known-good state survives logout/re-login
/// and short network flaps (Bugs 1/3 — "resume vanishes on refresh" and
/// "portfolio wiped after logout").
///
/// Firestore [Timestamp] values cannot be JSON-encoded, so they are replaced
/// with a marker map `{'__ts__': iso8601}` during encode and restored to real
/// [Timestamp] instances on decode — [PortfolioModel.fromMap] keeps receiving
/// the same shapes it gets from a Firestore snapshot.
class PortfolioCacheService {
  PortfolioCacheService._();

  static final PortfolioCacheService _instance = PortfolioCacheService._();
  factory PortfolioCacheService.instance() => _instance;

  static const String _keyPrefix = 'portfolio_cache_';
  static const String _timestampMarkerKey = '__ts__';

  String _keyFor(String uid) => '$_keyPrefix$uid';

  /// Persist [portfolio] for [uid]. Safe to call on any write.
  Future<void> cache(String uid, PortfolioModel portfolio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(uid), jsonEncode(_encode(portfolio.toMap())));
  }

  /// Last cached portfolio for [uid], or null when none exists yet.
  Future<PortfolioModel?> restore(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final withTimestamps = _decode(Map<String, dynamic>.from(decoded));
      return PortfolioModel.fromMap(withTimestamps);
    } catch (e) {
      return null;
    }
  }

  /// Drop the cached snapshot for [uid].
  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(uid));
  }

  Map<String, dynamic> _encode(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  Object? _encodeValue(Object? value) {
    if (value is Timestamp) {
      return {_timestampMarkerKey: value.toDate().toIso8601String()};
    }
    if (value is Map) {
      return _encode(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  Map<String, dynamic> _decode(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _decodeValue(value)));
  }

  Object? _decodeValue(Object? value) {
    if (value is Map) {
      final asMap = Map<String, dynamic>.from(value);
      if (asMap.length == 1 && asMap.containsKey(_timestampMarkerKey)) {
        final iso = asMap[_timestampMarkerKey] as String?;
        final parsed = iso != null ? DateTime.tryParse(iso) : null;
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      return _decode(asMap);
    }
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    return value;
  }
}
