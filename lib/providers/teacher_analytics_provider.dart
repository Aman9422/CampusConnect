import 'package:campusconnect/services/firestore/teacher_analytics_service.dart';
import 'package:flutter/material.dart';

/// TeacherAnalyticsProvider - v7.3: Teacher analytics enhancement
///
/// Simple provider for teacher analytics (no streams needed, one-time load).
/// Manages analytics data for resume review aggregations.
class TeacherAnalyticsProvider extends ChangeNotifier {
  final TeacherAnalyticsService _analyticsService;

  TeacherAnalyticsProvider({TeacherAnalyticsService? service})
    : _analyticsService = service ?? TeacherAnalyticsService.instance();

  // State
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _studentData;
  Map<String, dynamic>? _predictionIndicators;
  List<Map<String, dynamic>>? _skillGapAnalysis;
  List<Map<String, dynamic>>? _performanceTrends;
  bool _isLoading = false;
  String? _error;
  bool _isDisposed = false;

  // Getters
  Map<String, dynamic>? get stats => _stats;
  List<Map<String, dynamic>>? get studentData => _studentData;
  Map<String, dynamic>? get predictionIndicators => _predictionIndicators;
  List<Map<String, dynamic>>? get skillGapAnalysis => _skillGapAnalysis;
  List<Map<String, dynamic>>? get performanceTrends => _performanceTrends;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all analytics data
  Future<void> loadAnalytics() async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load both stats and student data in parallel
      final results = await Future.wait([
        _analyticsService.getResumeReviewStats(),
        _analyticsService.getStudentResumeData(),
        _analyticsService.getPlacementPredictionIndicators(),
        _analyticsService.getSkillGapAnalysis(),
        _analyticsService.getPerformanceTrendInsights(),
      ]);

      if (_isDisposed) return; // Safety check

      _stats = results[0] as Map<String, dynamic>;
      _studentData = results[1] as List<Map<String, dynamic>>;
      _predictionIndicators = results[2] as Map<String, dynamic>;
      _skillGapAnalysis = results[3] as List<Map<String, dynamic>>;
      _performanceTrends = results[4] as List<Map<String, dynamic>>;
      _error = null;
    } catch (e) {
      if (_isDisposed) return; // Safety check
      _error = 'Failed to load analytics data';
      debugPrint('TeacherAnalyticsProvider load error: $e');
    } finally {
      _isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Refresh analytics data
  Future<void> refresh() async {
    await loadAnalytics();
  }

  /// Get specific stat value with fallback
  T getStat<T>(String key, T fallback) {
    if (_stats == null) return fallback;
    return _stats![key] as T? ?? fallback;
  }

  /// Get total reviews count
  int get totalReviews => getStat('totalReviews', 0);

  /// Get average score
  double get averageScore => getStat('avgScore', 0.0);

  /// Get score distribution map
  Map<String, int> get scoreDistribution =>
      getStat('scoreDistribution', <String, int>{});

  /// Get excellent scores count (80+)
  int get excellentCount => scoreDistribution['excellent'] ?? 0;

  /// Get good scores count (60-79)
  int get goodCount => scoreDistribution['good'] ?? 0;

  /// Get fair scores count (40-59)
  int get fairCount => scoreDistribution['fair'] ?? 0;

  /// Get poor scores count (<40)
  int get poorCount => scoreDistribution['poor'] ?? 0;

  /// Check if analytics have been loaded
  bool get hasData => _stats != null && _studentData != null;

  int get highPotentialCount =>
      (_predictionIndicators?['highPotential'] as int?) ?? 0;
  int get mediumPotentialCount =>
      (_predictionIndicators?['mediumPotential'] as int?) ?? 0;
  int get atRiskCount => (_predictionIndicators?['atRisk'] as int?) ?? 0;
  double get predictedPlacementRate =>
      (_predictionIndicators?['predictedPlacementRate'] as num? ?? 0.0)
          .toDouble();

  /// Get top N students by score
  List<Map<String, dynamic>> getTopStudents(int count) {
    if (_studentData == null) return [];
    return _studentData!.take(count).toList();
  }

  /// Get students by score range
  List<Map<String, dynamic>> getStudentsByScoreRange({
    required int minScore,
    required int maxScore,
  }) {
    if (_studentData == null) return [];
    return _studentData!.where((student) {
      final score = student['latestScore'] as int? ?? 0;
      return score >= minScore && score <= maxScore;
    }).toList();
  }

  /// Get students with excellent scores (80+)
  List<Map<String, dynamic>> get excellentStudents =>
      getStudentsByScoreRange(minScore: 80, maxScore: 100);

  /// Get students with good scores (60-79)
  List<Map<String, dynamic>> get goodStudents =>
      getStudentsByScoreRange(minScore: 60, maxScore: 79);

  /// Get students with fair scores (40-59)
  List<Map<String, dynamic>> get fairStudents =>
      getStudentsByScoreRange(minScore: 40, maxScore: 59);

  /// Get students with poor scores (<40)
  List<Map<String, dynamic>> get poorStudents =>
      getStudentsByScoreRange(minScore: 0, maxScore: 39);

  /// Format score as percentage
  String formatScore(int score) {
    return '$score/100';
  }

  /// Get badge color for score
  Color getScoreColor(int score) {
    if (score >= 80) {
      return const Color(0xFF059669); // Green for excellent
    } else if (score >= 60) {
      return const Color(0xFF0891B2); // Blue for good
    } else if (score >= 40) {
      return const Color(0xFFEA580C); // Orange for fair
    } else {
      return const Color(0xFFDC2626); // Red for poor
    }
  }

  /// Get score category text
  String getScoreCategory(int score) {
    if (score >= 80) {
      return 'Excellent';
    } else if (score >= 60) {
      return 'Good';
    } else if (score >= 40) {
      return 'Fair';
    } else {
      return 'Needs Improvement';
    }
  }

  /// Reset state (called on logout)
  void reset() {
    _isDisposed = true; // Set FIRST

    // Clear all state
    _stats = null;
    _studentData = null;
    _predictionIndicators = null;
    _skillGapAnalysis = null;
    _performanceTrends = null;
    _isLoading = false;
    _error = null;

    // DON'T call notifyListeners() after setting _isDisposed
    // This prevents any further updates
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
