import 'dart:async';

import 'package:campusconnect/utilities/load_dedupe.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2 — Teacher Analytics load de-duplication contract.
///
/// Regression cover for the v9.2 (P1) fixes that removed the repeated
/// "Loaded … reviews, … students, … depts …" startup flood:
///   1. the two eager `IndexedStack` tabs building together share ONE load;
///   2. an empty-result retry (forced) also piggybacks while a load runs;
///   3. a normal (non-forced) load is a no-op once data is present;
///   4. pull-to-refresh (forced) DOES start a fresh load;
///   5. `reset()` (logout) invalidates an in-flight load so a stale result can
///      never be written into freshly-reset state.
///
/// The gate itself is the REAL [LoadDedupe] used by
/// `TeacherAnalyticsProvider` (lib/utilities/load_dedupe.dart). Only the
/// provider's 3-branch decision is mirrored here — the provider cannot be
/// constructed in a unit test because `TeacherAnalyticsService`'s constructor
/// touches `FirebaseFirestore.instance`.
void main() {
  group('LoadDedupe — real gate', () {
    test('begin exposes the in-flight future and clears it on completion', () {
      final gate = LoadDedupe();
      expect(gate.isActive, isFalse);
      expect(gate.inFlight, isNull);

      final completer = Completer<void>();
      gate.begin(completer.future);
      expect(gate.isActive, isTrue);
      expect(gate.inFlight, same(completer.future));

      completer.complete();
      // whenComplete clears the handle on the microtask that follows.
      return Future<void>.value().then((_) {
        expect(gate.isActive, isFalse);
        expect(gate.inFlight, isNull);
      });
    });

    test('invalidate bumps the epoch and makes a captured epoch stale', () {
      final gate = LoadDedupe();
      final captured = gate.epoch;
      expect(gate.owns(captured), isTrue);

      gate.invalidate();
      expect(gate.owns(captured), isFalse, reason: 'old epoch is superseded');
      expect(gate.owns(gate.epoch), isTrue, reason: 'new epoch owns');
    });

    test('a late completion of a superseded load does not clear the new '
        'handle', () {
      final gate = LoadDedupe();

      final first = Completer<void>();
      gate.begin(first.future);

      // A reset, then a brand-new load begins.
      gate.invalidate();
      expect(gate.isActive, isFalse);

      final second = Completer<void>();
      gate.begin(second.future);
      expect(gate.inFlight, same(second.future));

      // The OLD load finally completes — it must NOT null out the new handle.
      first.complete();
      return Future<void>.value().then((_) {
        expect(
          gate.inFlight,
          same(second.future),
          reason: 'the stale handle must not clobber the current one',
        );
      });
    });
  });

  group('provider load decision (mirror) — no duplicate reads', () {
    late _LoadController controller;

    setUp(() => controller = _LoadController());

    test('two concurrent triggers (both tabs) share ONE load', () {
      final a = controller.load();
      final b = controller.load();

      expect(controller.loads, 1, reason: 'only one backend load started');
      expect(identical(a, b), isTrue, reason: 'the second call piggybacks');
    });

    test('a non-forced load is a no-op once data is present', () async {
      controller.load();
      controller.completeLoad();
      await Future<void>.value();
      expect(controller.hasData, isTrue);
      expect(controller.loads, 1);

      await controller.load(); // no force, data present
      expect(controller.loads, 1, reason: 'idempotent — nothing re-fetched');
    });

    test('refresh (force) starts a fresh load even when data is present',
        () async {
      controller.load();
      controller.completeLoad();
      await Future<void>.value();
      expect(controller.loads, 1);

      final pending = controller.refresh(); // do not await: it stays in flight
      expect(controller.loads, 2, reason: 'pull-to-refresh forces a reload');

      controller.completeLoad();
      await pending;
      expect(controller.hasData, isTrue);
    });

    test('an empty-result retry (forced) still de-dups while a load runs',
        () async {
      controller.load(force: true); // retry #1 fires a load
      controller.load(force: true); // retry #2 while in flight

      expect(
        controller.loads,
        1,
        reason: 'forced retries must not stampede the backend',
      );
    });

    test('reset (logout) invalidates an in-flight load so it cannot commit',
        () async {
      controller.load();
      controller.reset(); // logout while the load is in flight
      controller.completeLoad(); // the stale load finishes late
      await Future<void>.value();

      expect(
        controller.hasData,
        isFalse,
        reason: 'a load that lost its epoch must not write stale data',
      );
    });

    test('after reset a fresh load starts immediately (re-login)', () async {
      controller.load();
      controller.completeLoad();
      await Future<void>.value();
      expect(controller.loads, 1);

      controller.reset();
      controller.load();

      expect(
        controller.loads,
        2,
        reason: 'the re-login load is not blocked by the previous handle',
      );
    });
  });
}

/// A faithful mirror of `TeacherAnalyticsProvider.loadAnalytics`'s 3-branch
/// decision, built on the REAL [LoadDedupe] so the de-dup/staleness semantics
/// under test are the production ones.
class _LoadController {
  final LoadDedupe gate = LoadDedupe();
  bool hasData = false;
  bool disposed = false;
  int loads = 0;

  Completer<void>? _pending;

  Future<void> load({bool force = false}) {
    if (disposed) return Future<void>.value();

    final inFlight = gate.inFlight;
    if (inFlight != null) return inFlight;

    if (!force && hasData) return Future<void>.value();

    final future = _run();
    gate.begin(future);
    return future;
  }

  Future<void> refresh() => load(force: true);

  Future<void> _run() async {
    final epoch = gate.epoch;
    loads++;
    _pending = Completer<void>();
    await _pending!.future;
    if (disposed || !gate.owns(epoch)) return;
    hasData = true;
  }

  void completeLoad() => _pending!.complete();

  void reset() {
    gate.invalidate();
    hasData = false;
  }
}
