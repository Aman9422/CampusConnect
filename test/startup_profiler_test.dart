import 'package:campusconnect/utilities/startup_profiler.dart';
import 'package:flutter_test/flutter_test.dart';

/// v9.2.2 (§1) — startup profiler instrumentation tests.
///
/// The profiler exists to *measure* the startup timeline and the frame budget
/// so the cold-start attribution is evidence-based. Its pure frame-summary
/// helper is unit-tested here, plus the phase-mark bookkeeping via the
/// debug-only test seams.
void main() {
  group('FrameSample', () {
    test('totalMs is build + raster', () {
      const sample = FrameSample(buildMs: 8.0, rasterMs: 5.5);
      expect(sample.totalMs, 13.5);
    });

    test('toString reports build, raster and total', () {
      const sample = FrameSample(buildMs: 8.0, rasterMs: 5.0);
      final text = sample.toString();
      expect(text, contains('build=8.0ms'));
      expect(text, contains('raster=5.0ms'));
      expect(text, contains('total=13.0ms'));
    });
  });

  group('frameDurationsToSample', () {
    test('converts microsecond durations to milliseconds', () {
      final sample = frameDurationsToSample(
        buildMicros: 8000,
        rasterMicros: 5000,
      );
      expect(sample.buildMs, closeTo(8.0, 0.01));
      expect(sample.rasterMs, closeTo(5.0, 0.01));
      expect(sample.totalMs, closeTo(13.0, 0.01));
    });

    test('handles zero durations', () {
      final sample = frameDurationsToSample(buildMicros: 0, rasterMicros: 0);
      expect(sample.totalMs, 0.0);
    });
  });

  group('summariseFrameSamples', () {
    test('returns an empty string when there are no frames', () {
      expect(summariseFrameSamples(const <FrameSample>[]), isEmpty);
    });

    test('reports "all frames within budget" when none are slow', () {
      final samples = List<FrameSample>.generate(
        30,
        (_) => const FrameSample(buildMs: 4.0, rasterMs: 3.0),
      );
      final summary = summariseFrameSamples(samples);
      expect(summary, contains('30 frames'));
      expect(summary, contains('16.0ms'));
    });

    test('counts the slow frames and names the worst by total cost', () {
      final samples = <FrameSample>[
        const FrameSample(buildMs: 2.0, rasterMs: 2.0), // fast
        const FrameSample(buildMs: 60.0, rasterMs: 20.0), // 80 ms — worst
        const FrameSample(buildMs: 30.0, rasterMs: 5.0), // 35 ms — second
        const FrameSample(buildMs: 18.0, rasterMs: 1.0), // 19 ms — third
      ];
      final summary = summariseFrameSamples(samples);
      expect(summary, contains('3/4 frames'));
      // The 80 ms frame must be reported first (worst-first ordering).
      final worstIndex = summary.indexOf('total=80.0ms');
      final secondIndex = summary.indexOf('total=35.0ms');
      expect(worstIndex, greaterThanOrEqualTo(0));
      expect(secondIndex, greaterThan(worstIndex));
    });

    test('honours the worst-N limit', () {
      final samples = <FrameSample>[
        const FrameSample(buildMs: 50.0, rasterMs: 0), // 50
        const FrameSample(buildMs: 40.0, rasterMs: 0), // 40
        const FrameSample(buildMs: 30.0, rasterMs: 0), // 30
        const FrameSample(buildMs: 20.0, rasterMs: 0), // 20
      ];
      final summary = summariseFrameSamples(samples, worst: 2);
      expect(summary, contains('4/4 frames'));
      expect(summary, contains('total=50.0ms'));
      expect(summary, contains('total=40.0ms'));
      expect(summary, isNot(contains('total=30.0ms')));
    });

    test('honours a custom threshold', () {
      final samples = <FrameSample>[
        const FrameSample(buildMs: 20.0, rasterMs: 0),
      ];
      expect(
        summariseFrameSamples(samples, thresholdMs: 16.0),
        contains('1/1 frames'),
      );
      expect(
        summariseFrameSamples(samples, thresholdMs: 33.0),
        contains('all 1 frames'),
      );
    });
  });

  group('StartupProfiler phase marks', () {
    test('records named phases in order once enabled', () {
      final profiler = StartupProfiler.instance;
      profiler.resetForTesting();
      profiler.enableForTesting();

      profiler.mark('firebase_init');
      profiler.mark('app_check_activate');
      profiler.mark('first_frame');

      final marks = profiler.marks;
      expect(
        marks.keys,
        containsAll(<String>[
          'firebase_init',
          'app_check_activate',
          'first_frame',
        ]),
      );
      // Elapsed values are monotonic non-negative millisecond readings.
      expect(marks['firebase_init']!, greaterThanOrEqualTo(0));
      expect(
        marks['first_frame']!,
        greaterThanOrEqualTo(marks['firebase_init']!),
      );
      expect(profiler.lastElapsedMs, greaterThanOrEqualTo(0));

      profiler.resetForTesting();
    });

    test('is a no-op before enabling (release-safe)', () {
      final profiler = StartupProfiler.instance;
      profiler.resetForTesting();
      profiler.mark('ignored');
      expect(profiler.isEnabled, isFalse);
      expect(profiler.marks, isEmpty);
    });

    test('finish() is idempotent and never throws', () {
      final profiler = StartupProfiler.instance;
      profiler.resetForTesting();
      profiler.enableForTesting();
      profiler.mark('run_app');
      expect(profiler.finish, returnsNormally);
      expect(profiler.finish, returnsNormally);
      profiler.resetForTesting();
    });
  });
}
