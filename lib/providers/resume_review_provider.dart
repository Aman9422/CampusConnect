import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/services/ai/resume_review_service.dart';
import 'package:campusconnect/services/firestore/resume_history_service.dart';
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
  final Connectivity _connectivity = Connectivity();

  String? userId;

  ResumeReviewProvider({
    required ResumeReviewService service,
    ResumeHistoryService? historyService, // v6.8
    this.userId,
  }) : _service = service,
       _historyService = historyService ?? ResumeHistoryService.instance();

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

  // v6.8: History state
  List<ResumeReviewHistory> _history = [];
  List<ResumeReviewHistory> get history => _history;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String? _historyError;
  String? get historyError => _historyError;

  bool _historyInitialized = false;
  bool get historyInitialized => _historyInitialized;

  // === Computed Getters ===

  /// Can user submit a new review?
  bool get canSubmitReview =>
      _isOnline && !_isLoading && !_usage.hasReachedLimit && userId != null;

  /// User-friendly message for why they can't submit
  String? get submitBlockedReason {
    if (!_isOnline) return "You're offline. Please reconnect.";
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

    notifyListeners();
  }

  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        debugPrint(
          'ResumeReviewProvider: Network ${_isOnline ? "online" : "offline"}',
        );
        notifyListeners();
      }
    });
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
  /// [resumeText] - Resume content as plain text
  /// [targetRole] - Optional target job role
  ///
  /// Returns true on success, false on failure
  Future<bool> submitReview({
    required String resumeText,
    String? targetRole,
  }) async {
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
        targetRole: targetRole,
      );

      // Success! Update state
      _currentReview = response.review;
      _usage = response.usage;
      _error = null;

      debugPrint(
        'ResumeReviewProvider: Review complete. ATS Score: ${response.review.atsScore}',
      );

      // v6.8: Save to history
      if (userId != null) {
        _saveToHistory(response.review, targetRole).catchError((e) {
          debugPrint('Failed to save review to history: $e');
          // Don't fail the operation if history save fails
        });
      }

      notifyListeners();
      return true;
    } on ResumeReviewQuotaException catch (e) {
      _error = e.message;
      if (e.usage != null) {
        _usage = e.usage!;
      }
      notifyListeners();
      return false;
    } on ResumeReviewException catch (e) {
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
}
