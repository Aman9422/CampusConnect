import 'dart:async';

/// v9.2.2 (§2) — end-to-end de-duplication for expensive, fingerprint-able
/// refreshes.
///
/// Recommendation regeneration is expensive: it is a Cloud Functions callable
/// that loads candidates, runs the deterministic engine and calls the AI
/// provider chain for explanation enrichment. Independent callers can
/// legitimately want the same refresh in the same window — the AuthGuard
/// provider bootstrap, a dashboard rebuild, a profile-synchronisation pass —
/// and each used to start its own server regeneration for the same user and
/// the same unchanged state (the duplicate
/// `RecommendationService: server regenerated recommendations …` line in the
/// runtime log).
///
/// This gate guarantees:
///
///  1. **Concurrency** — callers registered for the same key share ONE
///     in-flight future, so N concurrent requests become one backend call.
///  2. **Freshness** — a repeat call whose [fingerprint] equals the last
///     SUCCESSFULLY applied fingerprint is skipped: an unchanged state is
///     never regenerated "just because a widget rebuilt". A non-zero [maxAge]
///     re-runs it once that age elapses, so a long-lived session still picks
///     up server-side expiry.
///  3. **Force** — an explicit user action passes `force: true` and always
///     runs (explicit refresh functionality is preserved).
///  4. **Reset** — [invalidate] drops all state on logout so a new session
///     starts clean and an in-flight result cannot leak across accounts.
///
/// Pure Dart (no Firebase, no Flutter) so the behaviour is unit-testable.
class RefreshDedupe {
  RefreshDedupe({
    this.maxAge = const Duration(hours: 6),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long a recorded fingerprint stays authoritative. Once it is older
  /// than this, an identical (non-forced) request runs again. `Duration.zero`
  /// disables the age check (skip while the fingerprint is unchanged).
  final Duration maxAge;

  final DateTime Function() _clock;

  Future<void>? _activeFuture;
  String? _activeKey;
  int _epoch = 0;
  final Map<String, _RefreshRecord> _records = <String, _RefreshRecord>{};

  /// The in-flight refresh for [key], or null. A caller that receives a
  /// non-null value must await it instead of starting a new refresh.
  Future<void>? inFlightFor(String key) =>
      _activeKey == key ? _activeFuture : null;

  /// True while any refresh is in flight.
  bool get isActive => _activeFuture != null;

  /// The current epoch — bumped by [invalidate] so a caller can discard a
  /// result that belongs to a previous session.
  int get epoch => _epoch;

  /// Whether a refresh for [key]/[fingerprint] should run.
  ///
  /// Returns true when there is no record, when the fingerprint changed, when
  /// [force] is set, or when the record is older than [maxAge]. Returns false
  /// only when an identical fingerprint was recorded recently enough.
  bool shouldRun(String key, String fingerprint, {bool force = false}) {
    if (force) return true;
    final record = _records[key];
    if (record == null) return true;
    if (record.fingerprint != fingerprint) return true;
    if (maxAge > Duration.zero && _clock().difference(record.at) >= maxAge) {
      return true;
    }
    return false;
  }

  /// Register [future] as the active refresh for [key] and auto-clear the
  /// handle when it settles — but only if it is still the current handle, so a
  /// concurrent [invalidate] is never clobbered by a late completion.
  void begin(String key, Future<void> future) {
    _activeKey = key;
    _activeFuture = future;
    future
        .whenComplete(() {
          if (identical(_activeFuture, future) && _activeKey == key) {
            _activeFuture = null;
            _activeKey = null;
          }
        })
        .catchError((Object _) {
          // Tracked copy only — the caller still observes the error on the
          // original future (v9.2 BUG-8 pattern).
        });
  }

  /// Record a SUCCESSFUL refresh so an identical repeat can be skipped.
  /// Failures are deliberately not recorded, so a retry is always allowed.
  void record(String key, String fingerprint) {
    _records[key] = _RefreshRecord(fingerprint, _clock());
  }

  /// Drop the recorded fingerprint for [key], or for every key when [key] is
  /// null. Does not touch an in-flight refresh.
  void clear([String? key]) {
    if (key == null) {
      _records.clear();
    } else {
      _records.remove(key);
    }
  }

  /// Full reset (logout): cancel the in-flight handle, drop every recorded
  /// fingerprint, and bump the epoch. Returns the new epoch.
  int invalidate() {
    _activeFuture = null;
    _activeKey = null;
    _records.clear();
    return ++_epoch;
  }
}

class _RefreshRecord {
  const _RefreshRecord(this.fingerprint, this.at);

  final String fingerprint;
  final DateTime at;
}
