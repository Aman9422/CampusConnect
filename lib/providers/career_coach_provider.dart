import 'dart:async';

import 'package:campusconnect/models/career_coach_analysis.dart';
import 'package:campusconnect/services/ai/career_coach_service.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v9.0 — AI Career Coach Provider
///
/// State management for the AI Career Coach. Handles:
///   - live cached analysis (`users/{uid}/career_coach/summary` stream)
///   - explicit "Re-analyze" (calls the callable → AI + quota consumed)
///   - "Generate analysis" for students with no analysis yet
///   - monthly usage counter
///   - refresh that NEVER calls AI — it re-reads the cached document only
///     (dashboard refresh + pull-to-refresh must not burn quota)
///
/// Contract (docs/Task.md §8/§13.1): no AI request happens on dashboard
/// open/rebuild/refresh. The callable itself also serves the cached analysis
/// when the fingerprint is unchanged, so even the explicit generate call is
/// cheap when nothing meaningful changed.
class CareerCoachProvider extends ChangeNotifier {
  final CareerCoachService _service;

  CareerCoachProvider({CareerCoachService? service})
    : _service = service ?? CareerCoachService.instance();

  // === State ===

  CareerCoachAnalysis? _analysis;
  CareerCoachAnalysis? get analysis => _analysis;

  CareerCoachUsage _usage = const CareerCoachUsage();
  CareerCoachUsage get usage => _usage;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _error;
  String? get error => _error;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isDisposed = false;

  String? _userId;
  StreamSubscription<CareerCoachAnalysis?>? _subscription;

  /// Has a cached analysis been loaded at least once?
  bool get hasAnalysis => _analysis != null && _analysis!.hasContent;

  /// Top recommendations for the dashboard (2–3, priority order preserved).
  List<CareerCoachRecommendation> get topRecommendations =>
      _analysis?.recommendations.take(3).toList() ?? const [];

  /// Analyses remaining this month.
  int get analysesRemaining => _usage.analysesRemaining;

  /// Whether the student can request a fresh analysis right now.
  bool get canGenerate =>
      !_isGenerating && !_usage.hasReachedLimit && _userId != null;

  /// v9.0 IMP-14: True when the server has invalidated the cache (profile
  /// data changed). The dashboard shows a "Your career plan may be outdated"
  /// nudge without making a server call.
  bool get isStaleAnalysis => _analysis?.isStaleProfile ?? false;

  /// User-friendly reason generation is blocked.
  String? get generateBlockedReason {
    if (_usage.hasReachedLimit) {
      return 'Monthly limit reached (${_usage.monthlyLimit} analyses/month). '
          'Resets next month.';
    }
    if (_userId == null) return 'Please log in to use the AI Career Coach.';
    return null;
  }

  // === Lifecycle ===

  /// Initialize with the user id — subscribes to the cached summary stream.
  /// NEVER triggers an AI request.
  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _userId == userId) return;

    _userId = userId;
    _isDisposed = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = _service.summaryStream(userId).listen(
      (analysis) {
        if (_isDisposed) return;
        _analysis = analysis;
        _isLoading = false;
        _isInitialized = true;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Failed to load your career analysis.';
        _isLoading = false;
        notifyListeners();
      },
    );

    _loadUsage();
  }

  /// Read the cached analysis once — used by the dashboard refresh path.
  /// NEVER calls AI and NEVER consumes quota.
  Future<void> refreshFromCache() async {
    final userId = _userId;
    if (userId == null || _isDisposed) return;

    try {
      final cached = await _service.fetchSummaryOnce(userId);
      if (_isDisposed) return;
      _analysis = cached;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('CareerCoachProvider.refreshFromCache error: $e');
    }
  }

  /// Reset state (call on logout).
  void reset() {
    _isDisposed = true;
    _subscription?.cancel();
    _subscription = null;
    _analysis = null;
    _usage = const CareerCoachUsage();
    _isLoading = false;
    _isGenerating = false;
    _error = null;
    _isInitialized = false;
    _userId = null;
    notifyListeners();
  }

  /// Reload usage from the backend (no quota consumed).
  Future<void> _loadUsage() async {
    final userId = _userId;
    if (userId == null || _isDisposed) return;
    try {
      final usage = await _service.checkUsage();
      if (_isDisposed) return;
      _usage = usage;
      notifyListeners();
    } catch (e) {
      debugPrint('CareerCoachProvider._loadUsage error: $e');
    }
  }

  // === Actions ===

  /// Generate (or fetch the cached) analysis.
  ///
  /// [forceRefresh] — false: the server returns the cached analysis when the
  /// career-data fingerprint is unchanged (dashboard "Generate" button after
  /// the profile gained data; no quota if nothing changed). true: explicit
  /// "Re-analyze" — always performs a fresh AI request and consumes a
  /// monthly credit.
  Future<bool> generateAnalysis({bool forceRefresh = false}) async {
    final userId = _userId;
    if (userId == null || _isDisposed) return false;

    if (_usage.hasReachedLimit) {
      _error = generateBlockedReason;
      notifyListeners();
      return false;
    }

    if (_isGenerating) return false;

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.generateAnalysis(
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) return false;

      _analysis = response.analysis;
      _usage = response.usage;
      _isInitialized = true;
      _error = null;
      notifyListeners();
      return true;
    } on CareerCoachQuotaException catch (e) {
      _error = e.message;
      if (e.usage != null) _usage = e.usage!;
      notifyListeners();
      return false;
    } on CareerCoachException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('CareerCoachProvider.generateAnalysis error: $e');
      _error = 'Could not generate your career analysis. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Explicit "Re-analyze" — fresh AI request (consumes a monthly credit).
  Future<bool> reanalyze() => generateAnalysis(forceRefresh: true);

  /// Clear the current error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
