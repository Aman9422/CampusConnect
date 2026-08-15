import 'dart:async';
import 'dart:convert';
import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/models/user_activity.dart';
import 'package:campusconnect/services/ai/resume_review_service.dart';
import 'package:campusconnect/services/firestore/engagement_service.dart';
import 'package:campusconnect/services/firestore/resume_history_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v6.7+ - Resume Review Provider
///
/// State management for AI resume reviews./// Handles:
/// - Review submission and results
/// - Monthly usage tracking
/// - Network connectivity awareness
/// - Loading and error states
/// v6.8: Added review history support

class ResumeReviewProvider with ChangeNotifier {
  final ResumeReviewService _service;
  final ResumeHistoryService _historyService; // v6.8
  final EngagementService _engagementService;
  final Connectivity _connectivity = Connectivity();
  // v8.6 (HIGH 2): keep the subscription so it can be cancelled on
  // reset()/dispose() — prevents leaks + duplicate notifyListeners across
  // logins and notify-after-dispose (the M5 fix v8.4.2 applied to
  // PlacementsProvider but not here).
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String? userId;

  ResumeReviewProvider({
    required ResumeReviewService service,
    ResumeHistoryService? historyService, // v6.8
    EngagementService? engagementService,
    this.userId,
  }) : _service = service,
       _historyService = historyService ?? ResumeHistoryService.instance(),
       _engagementService = engagementService ?? EngagementService.instance();

  // === State ===

  /// Current review result (null if not reviewed yet)
  ResumeReview? _currentReview;
  ResumeReview? get currentReview => _currentReview;

  /// Usage tracking
  ResumeReviewUsage _usage = const ResumeReviewUsage(
    monthlyCount: 0,
    monthlyLimit: 5,
  );
  ResumeReviewUsage get usage => _usage;

  /// Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Error message (if any)
  String? _error;
  String? get error => _error;

  /// Network state
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Whether provider has been initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // v8.8.2 (E): consecutive transient-failure cooldown. After N consecutive
  // server-unavailable/network failures (which the `connectivity_plus` guard
  // can't see — e.g. DNS-level loss), submissions pause for [retryCooldown]
  // so retry storms do not burn monthly quota on a dead backend.
  static const int maxConsecutiveTransientFailures = 2;
  static const Duration retryCooldown = Duration(seconds: 30);

  int _consecutiveTransientFailures = 0;
  DateTime? _retryBlockedUntil;

  int get consecutiveTransientFailures => _consecutiveTransientFailures;

  /// True while repeated transient failures are on cooldown.
  bool get isRetryBlocked {
    final blockedUntil = _retryBlockedUntil;
    if (blockedUntil == null) return false;
    return DateTime.now().isBefore(blockedUntil);
  }

  /// Remaining cooldown (zero when not blocked).
  Duration get retryCooldownRemaining {
    if (!isRetryBlocked) return Duration.zero;
    return _retryBlockedUntil!.difference(DateTime.now());
  }

  // v8.6 (HIGH 2): flag to stop operations/listeners after logout/dispose.
  bool _isDisposed = false;

  // v6.8: History state
  List<ResumeReviewHistory> _history = [];
  List<ResumeReviewHistory> get history => _history;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String? _historyError;
  String? get historyError => _historyError;

  bool _historyInitialized = false;
  bool get historyInitialized => _historyInitialized;

  // v6.95: AI Deep Analysis state
  AIAnalysis? _aiAnalysis;
  AIAnalysis? get aiAnalysis => _aiAnalysis;

  bool _isAILoading = false;
  bool get isAILoading => _isAILoading;

  String? _aiError;
  String? get aiError => _aiError;

  AIAnalysisUsage _aiUsage = const AIAnalysisUsage();
  AIAnalysisUsage get aiUsage => _aiUsage;

  String? _aiProviderUsed;
  String? get aiProviderUsed => _aiProviderUsed;

  // === Computed Getters ===

  /// Can user submit a new review?
  bool get canSubmitReview =>
      _isOnline &&
      !_isLoading &&
      !_usage.hasReachedLimit &&
      !isRetryBlocked && // v8.8.2 (E): paused after repeated transient failures
      userId != null;

  /// User-friendly message for why they can't submit
  String? get submitBlockedReason {
    if (!_isOnline) return "You're offline. Please reconnect.";
    if (isRetryBlocked) {
      // v8.8.2 (E): repeated server/network failures — pause retries so the
      // monthly quota is not burnt on a dead backend.
      final seconds = retryCooldownRemaining.inSeconds.clamp(1, 9999);
      return 'Too many recent failures. Try again in $seconds seconds.';
    }
    if (_usage.hasReachedLimit) {
      return 'Monthly limit reached (${_usage.monthlyLimit} reviews/month). '
          'Resets next month.';
    }
    if (userId == null) return 'Please log in to use resume review.';
    return null;
  }

  /// Reviews remaining this month
  int get reviewsRemaining => _usage.reviewsRemaining;

  /// Has active review result?
  bool get hasReview => _currentReview != null;

  // v6.9: Analytics & Intelligence Getters

  /// History sorted by date (oldest to newest) for chart display
  List<ResumeReviewHistory> get sortedHistory {
    final sorted = List<ResumeReviewHistory>.from(_history);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Average ATS score across all reviews
  double get averageScore {
    if (_history.isEmpty) return 0;
    final sum = _history.fold<int>(0, (sum, review) => sum + review.atsScore);
    return sum / _history.length;
  }

  /// Highest ATS score ever achieved
  int get highestScore {
    if (_history.isEmpty) return 0;
    return _history.map((r) => r.atsScore).reduce((a, b) => a > b ? a : b);
  }

  /// Lowest ATS score ever received
  int get lowestScore {
    if (_history.isEmpty) return 0;
    return _history.map((r) => r.atsScore).reduce((a, b) => a < b ? a : b);
  }

  /// Total number of reviews
  int get totalReviews => _history.length;

  /// Number of reviews this month
  int get reviewsThisMonth {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _history.where((r) => r.monthKey == currentMonth).length;
  }

  // === Lifecycle ===

  /// Initialize with user ID (call after login)
  Future<void> initWithUser(String newUserId) async {
    if (userId == newUserId && _isInitialized) return;

    // v8.6 (HIGH 2): a fresh init revives the provider after reset().
    _isDisposed = false;
    userId = newUserId;
    _startConnectivityMonitoring();
    await _loadUsage();
    _isInitialized = true;

    // v6.8: Load history in background (don't block initialization)
    _loadHistory();

    notifyListeners();
  }

  /// Reset state (call on logout)
  void reset() {
    userId = null;
    _currentReview = null;
    _usage = const ResumeReviewUsage(monthlyCount: 0, monthlyLimit: 5);
    _isLoading = false;
    _error = null;
    _isInitialized = false;

    // v6.8: Clear history
    _history = [];
    _isLoadingHistory = false;
    _historyError = null;
    _historyInitialized = false;

    // v6.95: Clear AI analysis state
    _aiAnalysis = null;
    _isAILoading = false;
    _aiError = null;
    _aiUsage = const AIAnalysisUsage();
    _aiProviderUsed = null;

    // v8.6 (HIGH 2): mark disposed + cancel the connectivity subscription so
    // no listener survives logout (prevents leaks + duplicate notifyListeners
    // on the next login).
    _isDisposed = true;
    _cancelConnectivityMonitoring();

    // v8.8.2 (E): clear the retry cooldown on logout so a fresh login starts
    // clean (the new session's own failures re-arm it).
    _consecutiveTransientFailures = 0;
    _retryBlockedUntil = null;

    notifyListeners();
  }

  /// Start monitoring network connectivity
  /// v8.6 (HIGH 2): the subscription is retained so it can be cancelled on
  /// reset()/dispose(); the callback guards with [_isDisposed] so it never
  /// notifies listeners after logout/provider disposal (M5 pattern).
  void _startConnectivityMonitoring() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (_isDisposed) return; // v8.6 (HIGH 2): no notify after dispose

      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        // v8.8.2 (E): when the connectivity guard finally reports a restore,
        // clear the transient-failure cooldown so the user can retry
        // immediately.
        if (_isOnline) {
          _consecutiveTransientFailures = 0;
          _retryBlockedUntil = null;
        }
        debugPrint(
          'ResumeReviewProvider: Network ${_isOnline ? "online" : "offline"}',
        );
        notifyListeners();
      }
    });
  }

  /// v8.6 (HIGH 2): cancel the connectivity subscription and clear the
  /// reference so it can be re-established on the next [initWithUser].
  void _cancelConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Load current usage from backend
  Future<void> _loadUsage() async {
    if (userId == null) return;

    try {
      _usage = await _service.checkUsage(userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load resume review usage: $e');
      // Keep default usage, don't block user
    }
  }

  // === Actions ===

  /// Submit resume for AI review
  ///
  /// [resumeText] - Resume content as plain text (used when [storagePath]
  /// is not provided).
  /// [storagePath] - v8.5: optional storage path of the uploaded resume PDF
  /// (`resumes/{uid}/latest.pdf`). When provided the server downloads and
  /// extracts the text from the PDF, so [resumeText] may be empty.
  /// [targetRole] - Optional target job role
  ///
  /// Returns true on success, false on failure
  Future<bool> submitReview({
    String? resumeText,
    String? storagePath,
    String? targetRole,
  }) async {
    // v8.5: explicit validation for each input path (service enforces the
    // same rules server-side too).
    final hasStoragePath = storagePath != null && storagePath.isNotEmpty;
    if (!hasStoragePath && (resumeText == null || resumeText.trim().isEmpty)) {
      _error = 'Please provide resume text or upload a resume PDF.';
      notifyListeners();
      return false;
    }
    // Pre-flight checks
    if (userId == null) {
      _error = 'Please log in to use resume review.';
      notifyListeners();
      return false;
    }

    if (!_isOnline) {
      _error = "You're offline. Please reconnect and try again.";
      notifyListeners();
      return false;
    }

    // v8.8.2 (E): repeated transient failures put submissions on a short
    // cooldown so a dead backend cannot burn monthly quota on retry storms
    // (connectivity_plus can't detect DNS-level loss — the pid 24538 case).
    if (isRetryBlocked) {
      _error =
          'Too many recent failures. Please wait '
          '${retryCooldownRemaining.inSeconds.clamp(1, 9999)} seconds '
          'and try again.';
      notifyListeners();
      return false;
    }

    if (_usage.hasReachedLimit) {
      _error =
          'You have reached your monthly review limit '
          '(${_usage.monthlyLimit} reviews/month).';
      notifyListeners();
      return false;
    }

    if (_isLoading) {
      return false; // Prevent duplicate submissions
    }

    // Start loading
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('ResumeReviewProvider: Submitting review...');

      final response = await _service.reviewResume(
        userId: userId!,
        resumeText: resumeText,
        storagePath: storagePath,
        targetRole: targetRole,
      );

      // Success! Update state
      _currentReview = response.review;
      _usage = response.usage;
      _error = null;

      // v8.8.2 (E): a successful review clears the transient-failure streak /
      // cooldown — the backend is healthy again.
      _consecutiveTransientFailures = 0;
      _retryBlockedUntil = null;

      debugPrint(
        'ResumeReviewProvider: Review complete. ATS Score: ${response.review.atsScore}',
      );

      // v6.8: Save to history
      if (userId != null) {
        _saveToHistory(response.review, targetRole).catchError((e) {
          debugPrint('Failed to save review to history: $e');
          // Don't fail the operation if history save fails
        });

        _engagementService
            .logActivity(
              userId: userId!,
              eventType: ActivityEventType.resumeReviewed,
              points: 5,
              metadata: {'targetRole': targetRole},
            )
            .catchError((e) {
              debugPrint('Failed to log resume review activity: $e');
            });
      }

      notifyListeners();
      return true;
    } on ResumeReviewUnavailableException catch (e) {
      // v8.8.2 (E): transient server failure — count it toward the cooldown
      // so a dead backend cannot burn the monthly quota on retry storms.
      _registerTransientFailure();
      _error = e.message;
      notifyListeners();
      return false;
    } on ResumeReviewNetworkException catch (e) {
      // v8.8.2 (E): client-side network failure (DNS-level loss the
      // connectivity guard can't see) — same cooldown treatment.
      _registerTransientFailure();
      _error = e.message;
      notifyListeners();
      return false;
    } on ResumeReviewQuotaException catch (e) {
      // v8.8.2 (E): quota rejections are NOT transient — do not count them.
      _error = e.message;
      if (e.usage != null) {
        _usage = e.usage!;
      }
      notifyListeners();
      return false;
    } on ResumeReviewException catch (e) {
      // Non-transient application error (validation etc.) — leave cooldown
      // state untouched and just surface the message.
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('ResumeReviewProvider error: $e');
      _error = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// v8.8.2 (E): record a consecutive transient failure and arm the retry
  /// cooldown once the threshold is reached.
  void _registerTransientFailure() {
    _consecutiveTransientFailures++;
    if (_consecutiveTransientFailures >= maxConsecutiveTransientFailures) {
      _retryBlockedUntil = DateTime.now().add(retryCooldown);
      _consecutiveTransientFailures =
          0; // Re-arm after cooldown with fresh count.
    }
  }

  /// Clear current review (to start fresh)
  void clearReview() {
    _currentReview = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh usage data from backend
  Future<void> refreshUsage() async {
    await _loadUsage();
  }

  // === v6.8: History Management ===

  /// Load review history from Firestore
  Future<void> _loadHistory() async {
    if (userId == null) return;

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      _history = await _historyService.fetchHistory(userId!);
      _historyInitialized = true;
      debugPrint(
        'ResumeReviewProvider: Loaded ${_history.length} history items',
      );
    } catch (e) {
      debugPrint('ResumeReviewProvider: Error loading history: $e');
      _historyError = 'Failed to load review history';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Refresh history (pull-to-refresh)
  Future<void> refreshHistory() async {
    if (userId == null) return;

    _historyError = null;

    try {
      _history = await _historyService.fetchHistory(userId!);
      _historyInitialized = true;
      debugPrint(
        'ResumeReviewProvider: Refreshed ${_history.length} history items',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('ResumeReviewProvider: Error refreshing history: $e');
      _historyError = 'Failed to refresh history';
      notifyListeners();
    }
  }

  /// Save current review to history
  Future<void> _saveToHistory(ResumeReview review, String? targetRole) async {
    if (userId == null) return;

    try {
      final reviewId = await _historyService.saveReview(
        userId: userId!,
        review: review,
        targetRole: targetRole,
      );

      debugPrint('ResumeReviewProvider: Saved review to history: $reviewId');

      // Refresh history to include new review
      await refreshHistory();
    } catch (e) {
      debugPrint('ResumeReviewProvider: Failed to save to history: $e');
      rethrow;
    }
  }

  /// Delete a review from history
  Future<bool> deleteHistoryItem(String reviewId) async {
    if (userId == null) return false;

    try {
      await _historyService.deleteReview(userId: userId!, reviewId: reviewId);

      // Remove from local list
      _history.removeWhere((item) => item.id == reviewId);
      notifyListeners();

      debugPrint('ResumeReviewProvider: Deleted review $reviewId');
      return true;
    } catch (e) {
      debugPrint('ResumeReviewProvider: Error deleting review: $e');
      return false;
    }
  }

  /// Get a specific review by ID
  Future<ResumeReviewHistory?> getHistoryItem(String reviewId) async {
    if (userId == null) return null;

    // Check cache first
    try {
      final cached = _history.firstWhere((item) => item.id == reviewId);
      return cached;
    } catch (e) {
      // Not in cache, fetch from Firestore
      return await _historyService.getReviewById(
        userId: userId!,
        reviewId: reviewId,
      );
    }
  }

  // === v6.9: Intelligence & Analytics ===

  /// Generate growth analysis based on review history
  ResumeGrowthAnalysis generateGrowthAnalysis() {
    if (_history.isEmpty) {
      return const ResumeGrowthAnalysis(
        trend: 'no_data',
        insights: ['Submit your first resume review to see insights!'],
        consistentlyStrong: false,
        keywordTrend: 'no_data',
      );
    }

    if (_history.length == 1) {
      final review = _history.first;
      return ResumeGrowthAnalysis(
        trend: review.atsScore >= 70 ? 'strong' : 'needs_improvement',
        insights: [
          'You\'ve completed your first review with a score of ${review.atsScore}.',
          review.atsScore >= 70
              ? 'Great start! Your resume shows strong ATS compatibility.'
              : 'Good first step! Review the suggestions to improve your score.',
        ],
        consistentlyStrong: review.atsScore >= 70,
        keywordTrend: review.missingKeywords.isEmpty ? 'good' : 'needs_work',
      );
    }

    // Calculate trends for 2+ reviews
    final sorted = sortedHistory;
    final latest = sorted.last;
    final previous = sorted[sorted.length - 2];
    final scoreDiff = latest.atsScore - previous.atsScore;
    final scoreImprovement = previous.atsScore > 0
        ? ((scoreDiff / previous.atsScore) * 100)
        : 0.0;

    // Determine trend
    String trend;
    if (scoreDiff > 5) {
      trend = 'improving';
    } else if (scoreDiff < -5) {
      trend = 'declining';
    } else {
      trend = 'stable';
    }

    // Check consistency (all scores >= 70)
    final consistentlyStrong = _history.every((r) => r.atsScore >= 70);

    // Keyword trend
    String keywordTrend;
    if (latest.missingKeywords.length < previous.missingKeywords.length) {
      keywordTrend = 'improving';
    } else if (latest.missingKeywords.length >
        previous.missingKeywords.length) {
      keywordTrend = 'declining';
    } else {
      keywordTrend = 'stable';
    }

    // Generate insights
    final insights = <String>[];

    if (scoreDiff > 0) {
      insights.add(
        'Your score improved by ${scoreDiff.abs()} points (${scoreImprovement.abs().toStringAsFixed(1)}%) since last review!',
      );
    } else if (scoreDiff < 0) {
      insights.add(
        'Your score decreased by ${scoreDiff.abs()} points since last review.',
      );
    } else {
      insights.add('Your score remained stable at ${latest.atsScore}.');
    }

    if (consistentlyStrong) {
      insights.add(
        'You consistently score above 70 — excellent ATS compatibility!',
      );
    }

    if (keywordTrend == 'improving') {
      insights.add('Missing keywords trend is decreasing — great progress!');
    }

    if (averageScore >= 75) {
      insights.add(
        'Your average score is ${averageScore.toStringAsFixed(1)} — well above industry standards.',
      );
    }

    return ResumeGrowthAnalysis(
      scoreImprovement: scoreImprovement,
      trend: trend,
      insights: insights,
      consistentlyStrong: consistentlyStrong,
      keywordTrend: keywordTrend,
    );
  }

  /// Compare two reviews to show improvement
  ResumeComparison? compareReviews(String reviewId1, String reviewId2) {
    try {
      final review1 = _history.firstWhere((r) => r.id == reviewId1);
      final review2 = _history.firstWhere((r) => r.id == reviewId2);

      // Ensure review1 is older (for consistent comparison)
      final older = review1.createdAt.isBefore(review2.createdAt)
          ? review1
          : review2;
      final newer = review1.createdAt.isBefore(review2.createdAt)
          ? review2
          : review1;

      final scoreDiff = newer.atsScore - older.atsScore;

      // Find added/removed strengths
      final oldStrengths = Set<String>.from(older.strengths);
      final newStrengths = Set<String>.from(newer.strengths);
      final added = newStrengths.difference(oldStrengths).toList();
      final removed = oldStrengths.difference(newStrengths).toList();

      // Calculate format issues resolved
      final resolvedIssues =
          older.formatIssues.length - newer.formatIssues.length;

      // Calculate keyword improvement
      final keywordImprovement =
          older.missingKeywords.length - newer.missingKeywords.length;

      // Determine direction
      String direction;
      if (scoreDiff > 5) {
        direction = 'improved';
      } else if (scoreDiff < -5) {
        direction = 'declined';
      } else {
        direction = 'same';
      }

      return ResumeComparison(
        review1: older,
        review2: newer,
        scoreDifference: scoreDiff,
        addedStrengths: added,
        removedStrengths: removed,
        resolvedFormatIssues: resolvedIssues.clamp(0, 999),
        keywordImprovement: keywordImprovement,
        direction: direction,
      );
    } catch (e) {
      debugPrint('ResumeReviewProvider: Error comparing reviews: $e');
      return null;
    }
  }

  // === v6.95: AI Deep Analysis ===

  /// Whether AI analysis is available for a given review
  bool hasAIAnalysis(String reviewId) {
    try {
      final review = _history.firstWhere((r) => r.id == reviewId);
      return review.aiAnalysis != null;
    } catch (_) {
      return false;
    }
  }

  /// Get cached AI analysis for a specific review
  AIAnalysis? getAIAnalysisForReview(String reviewId) {
    try {
      final review = _history.firstWhere((r) => r.id == reviewId);
      return review.aiAnalysis;
    } catch (_) {
      return null;
    }
  }

  /// Whether user can request AI analysis (has remaining quota and online)
  bool get canRequestAIAnalysis =>
      _isOnline && !_isAILoading && !_aiUsage.hasReachedLimit && userId != null;

  /// User-friendly reason for AI analysis block
  String? get aiBlockedReason {
    if (!_isOnline) return "You're offline. Please reconnect.";
    if (_aiUsage.hasReachedLimit) {
      return 'AI analysis limit reached (${_aiUsage.aiMonthlyLimit}/month). '
          'Resets next month.';
    }
    if (userId == null) return 'Please log in.';
    return null;
  }

  /// AI analyses remaining this month
  int get aiAnalysesRemaining => _aiUsage.remaining;

  /// Request AI deep analysis for a specific resume review
  ///
  /// Calls the `generateResumeAnalysis` Cloud Function which:
  /// 1. Checks usage limits
  /// 2. Calls Groq/HuggingFace AI provider
  /// 3. Saves result to Firestore
  /// 4. Returns structured analysis
  ///
  /// [reviewId] - ID of the review to analyze
  /// [resumeText] - Original resume text (needed for AI input)
  /// [targetRole] - Target job role for tailored advice
  ///
  /// Returns true on success, false on failure
  Future<bool> requestAIAnalysis({
    required String reviewId,
    required String resumeText,
    String? targetRole,
  }) async {
    if (userId == null) {
      _aiError = 'Please log in to use AI analysis.';
      notifyListeners();
      return false;
    }

    if (!_isOnline) {
      _aiError = "You're offline. Please reconnect and try again.";
      notifyListeners();
      return false;
    }

    if (_isAILoading) return false;

    // Check if already analyzed (return cached)
    final existing = getAIAnalysisForReview(reviewId);
    if (existing != null) {
      _aiAnalysis = existing;
      _aiError = null;
      notifyListeners();
      return true;
    }

    _isAILoading = true;
    _aiError = null;
    _aiAnalysis = null;
    notifyListeners();

    try {
      debugPrint('ResumeReviewProvider: Requesting AI analysis for $reviewId');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateResumeAnalysis',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'reviewId': reviewId,
        'resumeText': resumeText,
        'targetRole': targetRole ?? 'General / Entry Level',
      });

      final data = result.data;

      if (data['success'] == true && data['analysis'] != null) {
        // Deep-convert to Map<String, dynamic> — Firebase SDK returns
        // nested maps as Map<Object?, Object?> which fails type casts.
        final analysisMap = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(data['analysis'])) as Map,
        );
        _aiAnalysis = AIAnalysis.fromJson(analysisMap);
        _aiProviderUsed = data['providerUsed'] as String?;

        // Update usage if present
        if (data['usage'] != null) {
          final usageMap = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(data['usage'])) as Map,
          );
          _aiUsage = AIAnalysisUsage.fromJson(usageMap);
        }

        // Update local history cache with AI analysis
        _updateHistoryWithAI(reviewId, _aiAnalysis!, _aiProviderUsed);

        debugPrint(
          'ResumeReviewProvider: AI analysis received. '
          'Provider: $_aiProviderUsed, Cached: ${data['cached']}',
        );

        notifyListeners();
        return true;
      } else {
        _aiError = 'AI analysis returned an unexpected response.';
        notifyListeners();
        return false;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'ResumeReviewProvider: AI function error: ${e.code} - ${e.message}',
      );

      switch (e.code) {
        case 'resource-exhausted':
          _aiError =
              e.message ?? 'AI analysis limit reached. Resets next month.';
          break;
        case 'not-found':
          _aiError = 'Resume review not found. Please refresh and try again.';
          break;
        case 'unauthenticated':
          _aiError = 'Please log in to use AI analysis.';
          break;
        case 'invalid-argument':
          _aiError = e.message ?? 'Invalid request. Please try again.';
          break;
        default:
          _aiError = e.message ?? 'AI analysis failed. Please try again.';
      }

      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('ResumeReviewProvider: AI analysis error: $e');
      _aiError = 'Something went wrong with AI analysis. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isAILoading = false;
      notifyListeners();
    }
  }

  /// Clear AI analysis state (e.g., when switching reviews)
  void clearAIAnalysis() {
    _aiAnalysis = null;
    _aiError = null;
    _aiProviderUsed = null;
    notifyListeners();
  }

  /// Update local history cache when AI analysis is received
  void _updateHistoryWithAI(
    String reviewId,
    AIAnalysis analysis,
    String? providerUsed,
  ) {
    final index = _history.indexWhere((r) => r.id == reviewId);
    if (index == -1) return;

    final old = _history[index];
    _history[index] = ResumeReviewHistory(
      id: old.id,
      userId: old.userId,
      atsScore: old.atsScore,
      strengths: old.strengths,
      missingKeywords: old.missingKeywords,
      formatIssues: old.formatIssues,
      bulletImprovements: old.bulletImprovements,
      sectionAdvice: old.sectionAdvice,
      overallAdvice: old.overallAdvice,
      hireabilityVerdict: old.hireabilityVerdict,
      targetRole: old.targetRole,
      createdAt: old.createdAt,
      monthKey: old.monthKey,
      aiAnalysis: analysis,
      aiGeneratedAt: DateTime.now(),
      aiProviderUsed: providerUsed,
    );
  }

  @override
  void dispose() {
    // v8.6 (HIGH 2): cancel the connectivity subscription to prevent leaks
    // when the provider is disposed (e.g. app teardown) — M5 pattern.
    _cancelConnectivityMonitoring();
    _isDisposed = true;
    super.dispose();
  }
}
