import 'dart:async';

/// v9.2 (P1): de-duplication + staleness gate for one-shot, cancel-safe loads.
///
/// Several providers (e.g. `TeacherAnalyticsProvider`) need to:
///   - run at most ONE backend load at a time — concurrent callers (eager
///     `IndexedStack` tabs building together, an empty-result retry, a
///     pull-to-refresh) must share the in-flight future instead of firing
///     duplicate Firestore reads; and
///   - discard a load that finishes AFTER a logout/reset so a stale result can
///     never be written into freshly-reset state.
///
/// This is the exact behaviour the provider relies on, extracted here so it can
/// be unit-tested without Firestore or a widget tree.
///
/// Usage:
/// ```dart
/// final inFlight = _dedupe.inFlight;
/// if (inFlight != null) return inFlight;      // piggyback
/// if (!force && hasData) return;              // nothing to do
/// final epoch = _dedupe.epoch;
/// _dedupe.begin(_runLoad(epoch));
/// // inside _runLoad, before committing results:
/// if (!_dedupe.owns(epoch)) return;           // a reset superseded us
/// ```
class LoadDedupe {
  Future<void>? _active;
  int _epoch = 0;

  /// True while a load is in flight — a concurrent caller should piggyback.
  bool get isActive => _active != null;

  /// The in-flight load, if any. Callers must return this instead of starting a
  /// new load, so concurrent triggers share a single backend round-trip.
  Future<void>? get inFlight => _active;

  /// The current epoch. Capture it at the start of a load and check it with
  /// [owns] before committing results.
  int get epoch => _epoch;

  /// Register [future] as the active load and auto-clear the handle when it
  /// completes — but ONLY if it is still the current handle, so a [invalidate]
  /// in between is never clobbered by a late completion.
  void begin(Future<void> future) {
    _active = future;
    // v9.2 audit (BUG-8): `whenComplete` returns a NEW future that forwards the
    // original error; that future was discarded, so if the guarded load ever
    // completed with an error it became an unhandled async error (a zone-level
    // crash in tests, a red screen in debug). Swallow it on the tracker copy
    // only — the caller still observes the error on the original `future`.
    future.whenComplete(() {
      if (identical(_active, future)) {
        _active = null;
      }
    }).catchError((Object _) {
      // Intentionally ignored: error handling is the caller's responsibility.
    });
  }

  /// Invalidate any in-flight load (logout/reset): bump the epoch and drop the
  /// handle so a post-re-login load starts immediately and any stale load can no
  /// longer commit. Returns the new epoch.
  int invalidate() {
    _active = null;
    return ++_epoch;
  }

  /// Whether a load that captured [capturedEpoch] still owns the current epoch
  /// — i.e. no [invalidate] happened while it was running.
  bool owns(int capturedEpoch) => capturedEpoch == _epoch;
}
