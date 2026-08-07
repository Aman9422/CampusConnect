import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4.7 — Tolerant Firestore map parsing helpers.
///
/// Every portfolio `fromMap` is fed data that is supposed to come from
/// `PortfolioModel.toMap()`, but in practice a document can be written by an
/// older client, edited in the Firebase console, or stored from a foreign
/// writer. A strict cast (`map['x'] as Timestamp?`) on such a document threw
/// a `TypeError` inside `PortfolioModel.fromMap`, and `PortfolioProvider`
/// then silently fell back to `PortfolioModel.empty()` — the app showed a
/// fresh 10%-strength portfolio while Firestore had all the data.
///
/// These helpers never throw: a field with an unexpected shape degrades to
/// its default instead of blanking the whole portfolio.

/// Reads a date that may arrive as a Firestore [Timestamp], a [DateTime],
/// or an ISO-8601 [String] (console edits / foreign writers). Returns null
/// for anything else.
DateTime? tsToDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Reads an int that may arrive as `int` or `num` (Firestore returns a
/// `double` for fractional values stored as `150000.0`). Returns null for
/// non-numeric values.
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// Reads a bool, returning null for anything else.
bool? asBool(Object? value) => value is bool ? value : null;

/// Reads a String, returning null for anything else.
String? asString(Object? value) => value is String ? value : null;

/// Coerces a nested map field to `Map<String, dynamic>`. Returns null when
/// the value is not a map or its keys are not strings (never throws).
Map<String, dynamic>? asMap(Object? value) {
  if (value is! Map) return null;
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    return null;
  }
}

/// Parses a section map (resume / links / preferences) with a [parser],
/// returning [fallback] when the field is absent, not a map, or fails to
/// parse. One malformed section can never fail the whole portfolio.
T parseMap<T>(
  Object? value,
  T Function(Map<String, dynamic> map) parser,
  T fallback,
) {
  final map = asMap(value);
  if (map == null) return fallback;
  try {
    return parser(map);
  } catch (_) {
    return fallback;
  }
}

/// Parses a list-of-maps section (skills / projects / experience / …),
/// skipping entries that are not maps or that fail to parse individually.
/// Returns an empty list for any non-list value.
List<T> parseMapList<T>(
  Object? value,
  T Function(Map<String, dynamic> map) itemParser,
) {
  if (value is! List) return const [];
  final result = <T>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    try {
      result.add(itemParser(Map<String, dynamic>.from(entry)));
    } catch (_) {
      // Skip a malformed entry instead of failing the whole portfolio.
    }
  }
  return result;
}

/// Parses a list of strings, skipping non-string entries. Returns an empty
/// list for any non-list value. This replaces the eager/lazy
/// `.cast<String>()` calls which threw a `TypeError` on the first non-string
/// element (often at render time, not parse time).
List<String> parseStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
