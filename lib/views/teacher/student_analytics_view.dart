import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart'; // v7.3
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

/// StudentAnalyticsView - v7.2: Multi-role ecosystem
///
/// Analytics dashboard for teachers to view student progress,
/// placement statistics, and performance metrics.
class StudentAnalyticsView extends StatefulWidget {
  const StudentAnalyticsView({super.key});

  @override
  State<StudentAnalyticsView> createState() => _StudentAnalyticsViewState();
}

class _StudentAnalyticsViewState extends State<StudentAnalyticsView> {
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    // Load data from existing providers
    context.read<PlacementsProvider>().refresh();
    context.read<ResumeReviewProvider>().refreshHistory();
    // v7.3: Load teacher analytics
    context.read<TeacherAnalyticsProvider>().loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Student Analytics',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body:
          Consumer3<
            PlacementsProvider,
            ResumeReviewProvider,
            TeacherAnalyticsProvider
          >(
            builder:
                (
                  context,
                  placementsProvider,
                  resumeProvider,
                  analyticsProvider,
                  child,
                ) {
                  if (placementsProvider.isLoading ||
                      resumeProvider.isLoading ||
                      analyticsProvider.isLoading) {
                    return _buildSkeletonLoader();
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _loadAnalytics(),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview metrics
                          _buildOverviewMetrics(
                            placementsProvider,
                            resumeProvider,
                            isDark,
                          ),
                          const SizedBox(height: 20),

                          // Placement trends chart
                          _buildPlacementTrends(placementsProvider, isDark),
                          const SizedBox(height: 20),

                          // Resume review insights
                          _buildResumeInsights(resumeProvider, isDark),
                          const SizedBox(height: 20),

                          // v7.3: Resume Review Aggregates
                          _buildResumeAggregates(analyticsProvider, isDark),
                          const SizedBox(height: 20),

                          // v7.3: Student Resume Leaderboard
                          _buildStudentLeaderboard(analyticsProvider, isDark),
                          const SizedBox(height: 20),

                          // Department-wise breakdown
                          _buildDepartmentBreakdown(placementsProvider, isDark),
                        ],
                      ),
                    ),
                  );
                },
          ),
    );
  }

  Widget _buildOverviewMetrics(
    PlacementsProvider placementsProvider,
    ResumeReviewProvider resumeProvider,
    bool isDark,
  ) {
    final placements = placementsProvider.placements;
    final reviews = resumeProvider.history;

    // Calculate meaningful analytics for teachers
    final totalOpportunities = placements.length;
    final activeOpportunities = placements
        .where((p) => p.isActive && !p.isDeadlinePassed)
        .length;
    final totalReviews = reviews.length;
    final avgReviewScore = reviews.isNotEmpty
        ? reviews.map((r) => r.atsScore).reduce((a, b) => a + b) /
              reviews.length
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.gray700.withValues(alpha: 0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview Metrics',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Job Opportunities',
                  totalOpportunities.toString(),
                  Icons.work_outline,
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Active Openings',
                  activeOpportunities.toString(),
                  Icons.business_center_outlined,
                  AppTheme.success,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Resume Reviews',
                  totalReviews.toString(),
                  Icons.description_outlined,
                  AppTheme.warning,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Avg Review Score',
                  totalReviews > 0
                      ? '${avgReviewScore.toStringAsFixed(1)}/10'
                      : 'N/A',
                  Icons.star_outline,
                  AppTheme.secondaryIndigo,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.caption.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementTrends(
    PlacementsProvider placementsProvider,
    bool isDark,
  ) {
    final placements = placementsProvider.placements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.gray700.withValues(alpha: 0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Opportunities Status',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (placements.isEmpty)
            SizedBox(
              height: 200,
              child: EmptyStateWidget(
                icon: Icons.work_outline,
                title: 'No job opportunities',
                subtitle: 'Job opportunity analytics will appear here',
              ),
            )
          else
            SizedBox(
              height: 200,
              child: _buildPlacementChart(placements, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacementChart(List<Placement> placements, bool isDark) {
    // Group placements by company (or status for meaningful teacher analytics)
    Map<String, int> statusCounts = {
      'Active': 0,
      'Expired': 0,
      'Recent': 0,
      'Upcoming': 0,
    };

    final now = DateTime.now();
    for (var placement in placements) {
      if (!placement.isActive) {
        statusCounts['Expired'] = statusCounts['Expired']! + 1;
      } else if (placement.isDeadlinePassed) {
        statusCounts['Expired'] = statusCounts['Expired']! + 1;
      } else if (placement.deadline.difference(now).inDays <= 7) {
        statusCounts['Recent'] = statusCounts['Recent']! + 1;
      } else {
        statusCounts['Active'] = statusCounts['Active']! + 1;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            statusCounts.values.reduce((a, b) => a > b ? a : b).toDouble() + 2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final titles = statusCounts.keys.toList();
                if (value >= 0 && value < titles.length) {
                  return Text(
                    titles[value.toInt()],
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: statusCounts.entries.map((entry) {
          final index = statusCounts.keys.toList().indexOf(entry.key);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: AppTheme.primaryBlue,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResumeInsights(
    ResumeReviewProvider resumeProvider,
    bool isDark,
  ) {
    final reviews = resumeProvider.history;
    final totalReviews = reviews.length;
    final avgRating = reviews.isNotEmpty
        ? reviews.map((r) => r.atsScore).reduce((a, b) => a + b) /
              reviews.length
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.gray700.withValues(alpha: 0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resume Review Insights',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Reviews',
                  totalReviews.toString(),
                  Icons.description_outlined,
                  AppTheme.success,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Avg Score',
                  totalReviews > 0
                      ? '${avgRating.toStringAsFixed(1)}/10'
                      : 'N/A',
                  Icons.star_outline,
                  AppTheme.warning,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentBreakdown(
    PlacementsProvider placementsProvider,
    bool isDark,
  ) {
    final placements = placementsProvider.placements;

    // Group by company instead of department
    Map<String, int> companyCounts = {};
    for (var placement in placements) {
      final company = placement.company.isNotEmpty
          ? placement.company
          : 'Unknown';
      companyCounts[company] = (companyCounts[company] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.gray700.withValues(alpha: 0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company-wise Breakdown',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (companyCounts.isEmpty)
            EmptyStateWidget(
              icon: Icons.business_outlined,
              title: 'No company data',
              subtitle: 'Company breakdown will appear here',
            )
          else
            ...companyCounts.entries
                .take(5)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isDark ? Colors.white : AppTheme.gray900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.value.toString(),
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          if (companyCounts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${companyCounts.length - 5} more companies',
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// v7.3: Resume Review Aggregates Section
  Widget _buildResumeAggregates(
    TeacherAnalyticsProvider provider,
    bool isDark,
  ) {
    if (!provider.hasData) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      'Resume Review Analytics',
      isDark,
      child: Column(
        children: [
          // Metric cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Reviews',
                  provider.totalReviews.toString(),
                  Icons.assessment_outlined,
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Avg Score',
                  '${provider.averageScore.round()}/100',
                  Icons.grade_outlined,
                  AppTheme.success,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Score distribution pie chart
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildPieChartSections(provider),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPieChartLegend(
                        'Excellent (80+)',
                        provider.excellentCount,
                        const Color(0xFF059669),
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildPieChartLegend(
                        'Good (60-79)',
                        provider.goodCount,
                        const Color(0xFF0891B2),
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildPieChartLegend(
                        'Fair (40-59)',
                        provider.fairCount,
                        const Color(0xFFEA580C),
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildPieChartLegend(
                        'Poor (<40)',
                        provider.poorCount,
                        const Color(0xFFDC2626),
                        isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// v7.3: Student Resume Leaderboard Section
  Widget _buildStudentLeaderboard(
    TeacherAnalyticsProvider provider,
    bool isDark,
  ) {
    if (!provider.hasData || provider.studentData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final topStudents = provider.getTopStudents(10);

    return _buildSection(
      'Top Students by Resume Score',
      isDark,
      child: Column(
        children: topStudents.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          final score = student['latestScore'] as int;
          final name = student['studentName'] as String;
          final reviewCount = student['reviewCount'] as int;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: index < 3
                  ? provider.getScoreColor(score).withOpacity(0.05)
                  : (isDark ? AppTheme.gray800 : AppTheme.gray50),
              borderRadius: BorderRadius.circular(8),
              border: index < 3
                  ? Border.all(
                      color: provider.getScoreColor(score).withOpacity(0.3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? provider.getScoreColor(score)
                        : (isDark ? AppTheme.gray600 : AppTheme.gray400),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                      Text(
                        '$reviewCount review${reviewCount != 1 ? 's' : ''}',
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: provider.getScoreColor(score),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$score/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    TeacherAnalyticsProvider provider,
  ) {
    final total = provider.totalReviews;
    if (total == 0) return [];

    return [
      PieChartSectionData(
        color: const Color(0xFF059669),
        value: provider.excellentCount / total * 100,
        title: '${provider.excellentCount}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFF0891B2),
        value: provider.goodCount / total * 100,
        title: '${provider.goodCount}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFEA580C),
        value: provider.fairCount / total * 100,
        title: '${provider.fairCount}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFDC2626),
        value: provider.poorCount / total * 100,
        title: '${provider.poorCount}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildPieChartLegend(
    String label,
    int count,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count',
                style: AppTheme.caption.copyWith(
                  color: isDark ? Colors.white : AppTheme.gray900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SkeletonLoader(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 250,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 150,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }

  /// Helper method to build a consistent section layout
  Widget _buildSection(String title, bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.gray700.withValues(alpha: 0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
