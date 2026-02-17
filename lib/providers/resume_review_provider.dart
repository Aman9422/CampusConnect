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
    monthlyLimit: 3,
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
    _usage = const ResumeReviewUsage(monthlyCount: 0, monthlyLimit: 3);
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
}
