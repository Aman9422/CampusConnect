import 'dart:convert';

import 'package:campusconnect/models/student_profile.dart';

/// v9.2.2 (§2) — canonical fingerprint of the recommendation-driving inputs the
/// client can observe.
///
/// The value is used by `RefreshDedupe` to decide whether a recommendation
/// refresh must actually run: an identical fingerprint means the state has not
/// changed, so an unchanged set is never regenerated simply because a widget or
/// provider rebuilt.
///
/// Design rules:
///  * Only fields the engine actually reads are included. `metadata.updatedAt`
///    is DELIBERATELY excluded — it changes on every profile write (including
///    timestamp-only bookkeeping) and would defeat the deduplication.
///  * The encoding is canonical (sorted map keys, stable list order) so two
///    equal states always produce the same string.
///  * No secret is included: only the same career/skills fields the server
///    engine already reads from the user document.

/// The profile-level fields that can change a recommendation.
///
/// `portfolio` is included when present (a caller may pass a raw document map);
/// the `StudentProfile` model itself does not carry the portfolio, so in the
/// app path the portfolio-side changes are handled by the server-side
/// fingerprint in `functions/recommendations/refresh.js`.
const List<String> recommendationFingerprintKeys = <String>[
  'skills',
  'careerInterest',
  'career',
  'department',
  'graduationYear',
  'academic',
  'portfolio',
];

/// Build the canonical fingerprint string for [profile].
///
/// Accepts a [StudentProfile] (the app path) or a raw `Map` (tests / callers
/// that already hold the document shape). Anything else yields the fingerprint
/// of an empty state.
String recommendationFingerprint(Object? profile) {
  final Map<String, dynamic> source;
  if (profile is StudentProfile) {
    source = profile.toFirestore();
  } else if (profile is Map) {
    source = Map<String, dynamic>.from(profile);
  } else {
    source = const <String, dynamic>{};
  }

  final selected = <String, Object?>{};
  for (final key in recommendationFingerprintKeys) {
    final value = source[key];
    if (value == null) continue;
    selected[key] = _canonicalise(value);
  }
  return jsonEncode(selected);
}

/// Recursively normalise a value so equal states encode identically: map keys
/// are sorted, list order is preserved (order is significant), scalars are
/// passed through, and anything else degrades to its `toString()`.
Object? _canonicalise(Object? value) {
  if (value == null) return null;
  if (value is Map) {
    final entries =
        value.entries
            .map((e) => MapEntry(e.key.toString(), _canonicalise(e.value)))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return <String, Object?>{for (final e in entries) e.key: e.value};
  }
  if (value is List) {
    return value.map(_canonicalise).toList();
  }
  if (value is String || value is num || value is bool) return value;
  return value.toString();
}
