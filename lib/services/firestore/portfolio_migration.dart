import 'package:flutter/foundation.dart';

/// v9.2.2 (§4 — Portfolio compatibility cleanup).
///
/// Some legacy user documents store the portfolio as ROOT-LEVEL keys whose
/// NAMES contain dots (`portfolio.resume`, `portfolio.projects`,
/// `portfolio.resume.downloadUrl`, …) instead of the canonical nested
/// `users/{uid}.portfolio` map. That shape comes from Firebase-console JSON
/// edits and older writers. The reader tolerates it (v8.4.9 MB17) and the
/// writer can reconstitute the nested map on the next save (v9.0 BUG-3), but
/// until a save happens the document stays flattened, so every login re-runs
/// the compatibility path — the repeated runtime-log line
/// `detected flattened portfolio shape … next save will use full (non-diff)
/// write`.
///
/// This module holds the PURE, testable planning half of the migration: given
/// a raw `users/{uid}` document map it decides whether a migration is needed
/// and produces the canonical nested portfolio plus the list of legacy keys
/// to delete. The Firebase write itself lives in `PortfolioService`.
///
/// Everything here is IDEMPOTENT and NON-DESTRUCTIVE:
///  * flattened values are re-nested verbatim — no portfolio content is
///    dropped or invented;
///  * a document that already has the nested map is never touched (returns
///    `null`), so a second run is a no-op;
///  * a document with neither shape returns `null`.

/// The root-document key prefix used by the legacy flattened portfolio shape.
const String portfolioKeyPrefix = 'portfolio.';

/// A flattened key must be the prefix plus at least one character, i.e. the
/// 10-character `portfolio.` prefix followed by a non-empty section name
/// (minimum total length 11). The bare `portfolio.` key is NOT a portfolio
/// section and is deliberately excluded.
const int _minFlattenedKeyLength = 11; // 'portfolio.'.length + 1

/// True when [key] is a legacy flattened portfolio key
/// (`portfolio.<something>`).
bool isFlattenedPortfolioKey(String key) =>
    key.startsWith(portfolioKeyPrefix) && key.length >= _minFlattenedKeyLength;

/// Every legacy flattened portfolio key present on [data], or an empty list.
List<String> flattenedPortfolioKeys(Map<String, dynamic>? data) {
  if (data == null) return const <String>[];
  return data.keys.where(isFlattenedPortfolioKey).toList(growable: false);
}

/// The canonical nested portfolio map for [data], or null when there is
/// nothing to migrate.
@immutable
class PortfolioMigrationPlan {
  const PortfolioMigrationPlan({
    required this.nestedPortfolio,
    required this.flattenedKeysToDelete,
  });

  /// The nested portfolio map to write under `users/{uid}.portfolio`.
  final Map<String, dynamic> nestedPortfolio;

  /// Root-level `portfolio.*` keys to delete once the nested map is written,
  /// so the document stays canonical and the compatibility path is never
  /// needed again.
  final List<String> flattenedKeysToDelete;

  bool get isEmpty =>
      nestedPortfolio.isEmpty && flattenedKeysToDelete.isEmpty;
}

/// Plan the migration of a legacy flattened portfolio document.
///
/// Returns `null` when there is nothing to migrate:
///  * no document data,
///  * the canonical nested `portfolio` map is already present, or
///  * there are no flattened `portfolio.*` keys.
///
/// Pure and idempotent: after the plan has been applied (nested map written +
/// flattened keys deleted) a second call returns `null`.
PortfolioMigrationPlan? planPortfolioMigration(Map<String, dynamic>? data) {
  if (data == null) return null;
  // A document that already carries the nested map is canonical — never touch
  // it (this is what makes the migration idempotent).
  if (data['portfolio'] is Map) return null;

  final flatKeys = flattenedPortfolioKeys(data);
  if (flatKeys.isEmpty) return null;

  final flat = <String, dynamic>{};
  for (final key in flatKeys) {
    flat[key.substring(portfolioKeyPrefix.length)] = data[key];
  }

  return PortfolioMigrationPlan(
    nestedPortfolio: unflattenPortfolioPaths(flat),
    flattenedKeysToDelete: flatKeys,
  );
}

/// Converts dot-path keys into a nested map, e.g.:
///   `resume.downloadUrl` → `{ 'resume': { 'downloadUrl': value } }`
///   `projects` (list)     → `{ 'projects': [...] }`
///
/// Shared by the tolerant reader (`PortfolioService._extractPortfolioMap`) and
/// the migration so both interpret the flattened shape identically.
Map<String, dynamic> unflattenPortfolioPaths(Map<String, dynamic> flat) {
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

/// Outcome of a migration attempt.
enum PortfolioMigrationResult {
  /// The document was flattened and has been reconstituted into the canonical
  /// nested shape (legacy keys deleted).
  migrated,

  /// Nothing to do — missing document, already canonical, or no flattened
  /// keys. Also returned when a previous migration already ran.
  notApplicable,

  /// The migration could not run (network / permission). The caller should
  /// fall back to the flag-and-full-save path on the next save.
  failed,
}
