import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// v9.2.2 (§1) — lightweight, DEBUG/PROFILE-ONLY startup instrumentation.
///
/// The v9.2.2 runtime log showed `Skipped 77/30/32 frames` on cold start with
/// **no Dart `debugPrint` before them**, which places the bottleneck in the
/// native layer (engine/Impeller bring-up, Android `performTraversals()` JIT,
/// Firebase/GMS/App Check initialisation). This utility exists so that claim can
/// be *measured* — in profile-mode DevTools runs — rather than asserted:
///
///  * [start] / [mark] / [finish] record named startup **phase durations** from
///    the first Dart statement to the first frame.
///  * A one-shot timings callback records the worst **frame build/raster**
///    times during startup so the frame-budget consumption is attributable.
///
/// Nothing runs — and nothing is logged — outside debug/profile builds, and
/// only phase names + durations are printed: never a token, key, id or any
/// personal datum.
class StartupProfiler {
  StartupProfiler._();

  static final StartupProfiler instance = StartupProfiler._();

  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, int> _marks = <String, int>{};

  bool _enabled = false;
  bool _finished = false;
  bool _framesHooked = false;
  int _lastElapsedMs = 0;
  int _baselineElapsedMs = 0;
  final List<FrameSample> _samples = <FrameSample>[];

  /// True only in debug/profile builds after [start].
  bool get isEnabled => _enabled;

  /// Recorded phase → elapsed milliseconds since [start].
  Map<String, int> get marks => Map<String, int>.unmodifiable(_marks);

  /// Duration of the most recent [mark] call.
  int get lastElapsedMs => _lastElapsedMs;

  /// Frame samples captured during startup (empty unless profiling is on).
  List<FrameSample> get frameSamples =>
      List<FrameSample>.unmodifiable(_samples);

  /// Begin profiling. A no-op (and never throws) in release builds.
  void start() {
    if (!(kDebugMode || kProfileMode)) return;
    _enabled = true;
    _finished = false;
    _samples.clear();
    _marks.clear();
    _lastElapsedMs = 0;
    _stopwatch
      ..reset()
      ..start();
    _hookFrameTimings();
  }

  /// Record the interval between the previous mark (or [start]) and now.
  void mark(String phase) {
    if (!_enabled) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    _marks[phase] = elapsed;
    _lastElapsedMs = elapsed - _baselineElapsedMs;
    _baselineElapsedMs = elapsed;
    debugPrint('StartupProfiler: $phase @ ${elapsed}ms (+${_lastElapsedMs}ms)');
  }

  /// Finish profiling and print a one-line summary of every phase. Safe to
  /// call more than once (only the first call prints).
  void finish() {
    if (!_enabled || _finished) return;
    _finished = true;
    final phases = _marks.entries.map((e) => '${e.key}=${e.value}ms').join(' ');
    final frames = summariseFrameSamples(_samples);
    debugPrint('StartupProfiler: phases [$phases]');
    if (frames.isNotEmpty) {
      debugPrint('StartupProfiler: frames $frames');
    }
  }

  void _hookFrameTimings() {
    if (_framesHooked) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _framesHooked = true;
    } catch (e) {
      // Never let instrumentation break startup.
      debugPrint('StartupProfiler: frame hook unavailable ($e)');
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_enabled || _finished) return;
    for (final timing in timings) {
      _samples.add(frameTimingToSample(timing));
    }
  }

  /// Test seam: reset all state (debug/profile only).
  @visibleForTesting
  void resetForTesting() {
    _enabled = false;
    _finished = false;
    _framesHooked = false;
    _samples.clear();
    _marks.clear();
    _lastElapsedMs = 0;
    _baselineElapsedMs = 0;
    _stopwatch.stop();
  }

  /// Test seam: force-enable without a real clock (debug/profile only).
  @visibleForTesting
  void enableForTesting() {
    _enabled = kDebugMode || kProfileMode;
    _stopwatch
      ..reset()
      ..start();
  }
}

/// A single rendered frame's build + raster cost, in milliseconds.
@immutable
class FrameSample {
  const FrameSample({required this.buildMs, required this.rasterMs});

  final double buildMs;
  final double rasterMs;

  double get totalMs => buildMs + rasterMs;

  @override
  String toString() =>
      'build=${buildMs.toStringAsFixed(1)}ms '
      'raster=${rasterMs.toStringAsFixed(1)}ms '
      'total=${totalMs.toStringAsFixed(1)}ms';
}

/// Convert raw frame build/raster durations (in microseconds) into a
/// [FrameSample]. Pure and unit-testable — it has no `dart:ui` dependency, so
/// the conversion does not depend on the `FrameTiming` constructor (whose
/// signature varies across Flutter versions).
FrameSample frameDurationsToSample({
  required int buildMicros,
  required int rasterMicros,
}) {
  return FrameSample(
    buildMs: buildMicros / 1000.0,
    rasterMs: rasterMicros / 1000.0,
  );
}

/// Convert a Flutter [FrameTiming] into a [FrameSample].
FrameSample frameTimingToSample(FrameTiming timing) => frameDurationsToSample(
  buildMicros: timing.buildDuration.inMicroseconds,
  rasterMicros: timing.rasterDuration.inMicroseconds,
);

/// v9.2.2 (§1): summarise the frames that exceeded [thresholdMs] (default 16 ms
/// ≈ one 60 Hz frame). Pure and unit-testable — returns an empty string when no
/// frame was slow, otherwise a compact line naming the count and the [worst]
/// slowest frames by total cost.
String summariseFrameSamples(
  List<FrameSample> samples, {
  double thresholdMs = 16.0,
  int worst = 3,
}) {
  if (samples.isEmpty) return '';
  final slow = samples.where((s) => s.totalMs > thresholdMs).toList()
    ..sort((a, b) => b.totalMs.compareTo(a.totalMs));
  if (slow.isEmpty) return 'all ${samples.length} frames ≤ ${thresholdMs}ms';
  final top = slow.take(worst).map((s) => s.toString()).join(' | ');
  return '${slow.length}/${samples.length} frames > ${thresholdMs}ms — $top';
}
