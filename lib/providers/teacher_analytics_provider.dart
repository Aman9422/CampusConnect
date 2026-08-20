import 'package:campusconnect/models/placement_pipeline_data.dart';
import 'package:campusconnect/services/firestore/teacher_analytics_service.dart';
import 'package:flutter/material.dart';

/// TeacherAnalyticsProvider - v8.2
///
/// Simple provider for teacher analytics (no streams needed, one-time load).
/// Manages analytics data for resume review aggregations.
/// v8.2: Added department analytics, pipeline counts, engagement aggregates.
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

  // v8.2: New data
  List<Map<String, dynamic>>? _departmentAnalytics;
  PlacementPipelineData? _pipelineData;
  Map<String, dynamic>? _engagementAggregates;

  // v8.9 (Phase 8): recommendation intelligence aggregates
  Map<String, dynamic>? _recommendationAggregates;

  // Getters
  Map<String, dynamic>? get stats => _stats;
  List<Map<String, dynamic>>? get studentData => _studentData;
  Map<String, dynamic>? get predictionIndicators => _predictionIndicators;
  List<Map<String, dynamic>>? get skillGapAnalysis => _skillGapAnalysis;
  List<Map<String, dynamic>>? get performanceTrends => _performanceTrends;
  List<Map<String, dynamic>>? get departmentAnalytics => _departmentAnalytics;

  /// Pipeline data — typed, always represents unique student counts.
  PlacementPipelineData? get pipelineData => _pipelineData;

  Map<String, dynamic>? get engagementAggregates => _engagementAggregates;

  /// v8.9 (Phase 8): recommendation aggregate getters.
  Map<String, dynamic>? get recommendationAggregates =>
      _recommendationAggregates;
  List<Map<String, dynamic>> get careerGoalDistribution =>
      (_recommendationAggregates?['careerGoals'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
  List<Map<String, dynamic>> get targetRoleDistribution =>
      (_recommendationAggregates?['targetRoles'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
  List<Map<String, dynamic>> get recommendationSkillGaps =>
      (_recommendationAggregates?['topSkillGaps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
  Map<String, int> get placementTierDistribution =>
      (_recommendationAggregates?['placementTiers'] as Map<String, dynamic>? ??
              <String, dynamic>{})
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  int get strongMatchStudents =>
      (_recommendationAggregates?['strongMatchStudents'] as int? ?? 0);
  int get significantGapStudents =>
      (_recommendationAggregates?['significantGapStudents'] as int? ?? 0);

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// v8.2: Engagement aggregate getters
  int get avgEngagement =>
      (_engagementAggregates?['avgEngagement'] as num? ?? 0).round();
  int get avgProfileStrength =>
      (_engagementAggregates?['avgProfileStrength'] as num? ?? 0).round();
  int get activeAlumni => (_engagementAggregates?['activeAlumni'] as int? ?? 0);
  int get engagementStudentCount =>
      (_engagementAggregates?['studentCount'] as int? ?? 0);

  /// v8.2.3: Pipeline getters — backward-compatible, all return unique student counts.
  PlacementPipelineData? get pipelineCounts => _pipelineData;
  int get pipelineEligible => _pipelineData?.eligibleStudents ?? 0;
  int get pipelineApplied => _pipelineData?.appliedStudents ?? 0;
  // v9.1: real shortlisted/interviewed/placed counts — status-bucketed
  // distinct-student counts from `TeacherAnalyticsService
  // .getApplicationPipelineCounts`.
  int get pipelineShortlisted => _pipelineData?.shortlistedStudents ?? 0;
  int get pipelineInterviewed => _pipelineData?.interviewedStudents ?? 0;
  int get pipelinePlaced => _pipelineData?.placedStudents ?? 0;
  int get pipelineTotalStudents => _pipelineData?.eligibleStudents ?? 0;
  int get pipelineTotalPlacements =>
      0; // Dead getter — placement count comes from PlacementsProvider
  @Deprecated('Use pipelineData instead')
  List<int> get allStageValues => _pipelineData?.allStageValues ?? [];

  /// Load all analytics data
  Future<void> loadAnalytics() async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all data in parallel — v8.2 adds 3 more queries
      final results = await Future.wait([
        _analyticsService.getResumeReviewStats(),
        _analyticsService.getStudentResumeData(),
        _analyticsService.getPlacementPredictionIndicators(),
        _analyticsService.getSkillGapAnalysis(),
        _analyticsService.getPerformanceTrendInsights(),
        _analyticsService.getDepartmentAnalytics(),
        _analyticsService.getApplicationPipelineCounts(),
        _analyticsService.getEngagementAggregates(),
        // v8.9 (Phase 8): recommendation intelligence aggregates.
        _analyticsService.getRecommendationAggregates(),
      ]);

      if (_isDisposed) return; // Safety check

      _stats = results[0] as Map<String, dynamic>;
      _studentData = results[1] as List<Map<String, dynamic>>;
      _predictionIndicators = results[2] as Map<String, dynamic>;
      _skillGapAnalysis = results[3] as List<Map<String, dynamic>>;
      _performanceTrends = results[4] as List<Map<String, dynamic>>;
      _departmentAnalytics = results[5] as List<Map<String, dynamic>>;
      _pipelineData = results[6] as PlacementPipelineData;
      _engagementAggregates = results[7] as Map<String, dynamic>;
      _recommendationAggregates = results[8] as Map<String, dynamic>;
      _error = null;

      debugPrint(
        'TeacherAnalyticsProvider: Loaded '
        '${_stats?['totalReviews'] ?? 0} reviews, '
        '${_studentData?.length ?? 0} students, '
        '${_departmentAnalytics?.length ?? 0} depts, '
        '${_pipelineData?.eligibleStudents ?? 0} pipeline eligible, '
        '${_engagementAggregates?['studentCount'] ?? 0} engagement summaries',
      );
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

  /// Reset state (called on logout).
  /// Clears all analytics data so the provider is ready for a fresh load
  /// on the next login. Does NOT set _isDisposed — that is only for
  /// actual widget tree disposal, not for logout/reset cycles.
  void reset() {
    // Clear all state — do NOT set _isDisposed here, otherwise
    // loadAnalytics() will be permanently blocked after logout→relogin.
    _stats = null;
    _studentData = null;
    _predictionIndicators = null;
    _skillGapAnalysis = null;
    _performanceTrends = null;
    _departmentAnalytics = null;
    _pipelineData = null;
    _engagementAggregates = null;
    _recommendationAggregates = null;
    _isLoading = false;
    _error = null;

    // notifyListeners is safe here because _isDisposed is still false
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
