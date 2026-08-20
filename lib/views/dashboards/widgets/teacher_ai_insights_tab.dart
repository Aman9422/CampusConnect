import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Score category threshold constants
const int _scoreExcellent = 80;
const int _scoreGood = 60;
const int _scoreFair = 40;

Color _scoreColor(int score) {
  if (score >= _scoreExcellent) return const Color(0xFF059669);
  if (score >= _scoreGood) return const Color(0xFF0891B2);
  if (score >= _scoreFair) return const Color(0xFFEA580C);
  return const Color(0xFFDC2626);
}

/// AI Insights Tab — v8.2: Dedicated institutional analytics dashboard.
///
/// Uses FL Chart for rich visualizations:
/// - PieChart for resume distribution
/// - BarChart for placement funnel, department comparison, skill gaps
/// - LineChart for monthly trends, engagement trends
///
/// NOT an AI chat. Pure analytics only, driven entirely by existing providers.
class AIInsightsTab extends StatefulWidget {
  const AIInsightsTab({super.key});

  @override
  State<AIInsightsTab> createState() => _AIInsightsTabState();
}

class _AIInsightsTabState extends State<AIInsightsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeacherAnalyticsProvider>().loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();

    if (analytics.isLoading && !analytics.hasData) {
      return _buildSkeleton(isDark);
    }

    return Column(
      children: [
        // AppBar equivalent — rendered as a fixed header at the top
        _buildAppBar(isDark),
        // Body content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                context.read<TeacherAnalyticsProvider>().loadAnalytics(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Campus Health
                  _buildCampusHealth(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 2. Resume Distribution (PieChart)
                  _buildResumeDistributionChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 3. Placement Funnel (BarChart)
                  _buildPlacementFunnelChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 4. Department Comparison (BarChart)
                  _buildDepartmentComparisonChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 5. Skill Gap Distribution (BarChart)
                  _buildSkillGapChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 5.5. v8.9 (Phase 13): Recommendation Insights — career
                  // goals, target roles, skill gaps, placement tier
                  // distribution, strong-match / gap student counts.
                  _buildRecommendationInsights(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 6. Mentorship Effectiveness
                  _buildMentorshipEffectiveness(context, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 7. Placement Readiness
                  _buildPlacementReadiness(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 8. Risk Distribution (PieChart)
                  _buildRiskDistributionChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 9. Monthly Resume Trend (LineChart)
                  _buildMonthlyTrendChart(analytics, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // 10. AI Summary — v8.2 dynamic narrative
                  _buildAISummary(analytics, context, isDark),
                  const SizedBox(height: AppTheme.space32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── AppBar ────────────────────────────────────────
  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        bottom: AppTheme.space8,
        left: AppTheme.space16,
        right: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? Colors.white : AppTheme.gray900,
            size: 24,
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            'AI Insights',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const Spacer(),
          NotificationBadge(
            onTap: () => Navigator.pushNamed(context, notificationsRoute),
            iconColor: isDark ? AppTheme.gray400 : null,
          ),
          const SizedBox(width: AppTheme.space4),
          ChatBadge(iconColor: isDark ? AppTheme.gray400 : null),
          const SizedBox(width: AppTheme.space8),
        ],
      ),
    );
  }

  // ─── 1. Campus Health ─────────────────────────────
  Widget _buildCampusHealth(TeacherAnalyticsProvider analytics, bool isDark) {
    final totalStudents = analytics.studentData?.length ?? 0;
    final totalReviews = analytics.totalReviews;
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final avgScore = analytics.averageScore.round();

    return _card(
      'Campus Health',
      Icons.favorite_outlined,
      isDark,
      child: Wrap(
        spacing: AppTheme.space8,
        runSpacing: AppTheme.space8,
        children: [
          _healthTile(
            'Students',
            '$totalStudents',
            AppTheme.primaryBlue,
            isDark,
          ),
          _healthTile('Reviews', '$totalReviews', AppTheme.success, isDark),
          _healthTile('Avg Score', '$avgScore/100', AppTheme.warning, isDark),
          _healthTile('High Potential', '$highPotential', Colors.green, isDark),
          if (atRisk > 0)
            _healthTile('At Risk', '$atRisk', AppTheme.error, isDark),
          _healthTile(
            'Engagement',
            '${analytics.avgEngagement}',
            AppTheme.success,
            isDark,
          ),
          _healthTile(
            'Profile Strength',
            '${analytics.avgProfileStrength}',
            AppTheme.primaryBlue,
            isDark,
          ),
          _healthTile(
            'Alumni',
            '${analytics.activeAlumni}',
            const Color(0xFF7C3AED),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _healthTile(String label, String value, Color color, bool isDark) {
    // Use LayoutBuilder to compute width from actual available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - 24) / 4; // 4 cols with 3 gaps of 8
        return Container(
          width: tileWidth > 60 ? tileWidth : 60,
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 2. Resume Distribution (PieChart) ────────────
  Widget _buildResumeDistributionChart(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final total = analytics.totalReviews;
    if (total == 0) {
      return _card(
        'Resume Distribution',
        Icons.pie_chart_outline,
        isDark,
        child: Text(
          'No review data yet',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    final excellent = analytics.excellentCount.toDouble();
    final good = analytics.goodCount.toDouble();
    final fair = analytics.fairCount.toDouble();
    final poor = analytics.poorCount.toDouble();

    return _card(
      'Resume Distribution',
      Icons.pie_chart_outline,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: [
                  _pieSection('Excellent', excellent, const Color(0xFF059669)),
                  _pieSection('Good', good, const Color(0xFF0891B2)),
                  _pieSection('Fair', fair, const Color(0xFFEA580C)),
                  _pieSection('Poor', poor, const Color(0xFFDC2626)),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(
                'Excellent (80+)',
                const Color(0xFF059669),
                excellent.round(),
              ),
              _legendDot('Good (60-79)', const Color(0xFF0891B2), good.round()),
              _legendDot('Fair (40-59)', const Color(0xFFEA580C), fair.round()),
              _legendDot('Poor (<40)', const Color(0xFFDC2626), poor.round()),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Average Score: ${analytics.averageScore.round()}/100',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(String label, double value, Color color) {
    return PieChartSectionData(
      value: value > 0 ? value : 0.1, // tiny wedge for visibility
      color: color,
      radius: 40,
      title: value > 0 ? '${value.round()}' : '',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _legendDot(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  // ─── 3. Placement Funnel (BarChart) — v8.2.3 ─────
  //
  // Defensive scaling: dynamic Y-axis, never hardcoded, never overflows.
  // All stages represent unique student counts (not application counts).
  // Empty state: "No placement data available" when eligible == 0.
  // Tooltips: show full stage name with student count and plural suffix.
  Widget _buildPlacementFunnelChart(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final pipelineData = analytics.pipelineData;
    // Fallback to studentData?.length when pipeline query returns 0 but
    // student resume data exists (e.g. count query requires a composite index).
    final eligible =
        pipelineData?.eligibleStudents ?? analytics.studentData?.length ?? 0;
    final applied = pipelineData?.appliedStudents ?? 0;

    if (eligible == 0) {
      return _card(
        'Placement Funnel',
        Icons.share_arrival_time_outlined,
        isDark,
        child: Text(
          'No placement data available',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    // Dynamic Y-axis: 20% padding above the max value — never hardcoded
    final maxValue = [
      eligible,
      applied,
      0,
      0,
      0,
    ].reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = maxValue > 0 ? maxValue * 1.2 : 100.0;

    return _card(
      'Placement Funnel',
      Icons.share_arrival_time_outlined,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.center,
                maxY: maxY, // Dynamic Y-axis — bars never overflow
                barGroups: [
                  _barGroup(
                    0,
                    eligible.toDouble(),
                    AppTheme.primaryBlue,
                    'Eligible',
                  ),
                  _barGroup(
                    1,
                    applied.toDouble(),
                    AppTheme.secondaryIndigo,
                    'Applied',
                  ),
                  _barGroup(2, 0, AppTheme.gray400, 'Shortlisted'),
                  _barGroup(3, 0, AppTheme.gray400, 'Interview'),
                  _barGroup(4, 0, AppTheme.gray400, 'Placed'),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = [
                          'Eligible',
                          'Applied',
                          'Short.',
                          'Interview',
                          'Placed',
                        ];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const longLabels = [
                        'Eligible Students',
                        'Students Applied',
                        'Students Shortlisted',
                        'Students Interviewed',
                        'Students Placed',
                      ];
                      final idx = group.x.toInt();
                      final label = idx >= 0 && idx < longLabels.length
                          ? longLabels[idx]
                          : '';
                      final count = rod.toY.round();
                      final suffix = count == 1 ? 'student' : 'students';
                      return BarTooltipItem(
                        '$label\n$count $suffix',
                        const TextStyle(color: Colors.white, fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color, String label) {
    final isEmpty = y <= 0;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: isEmpty ? 0.5 : y, // Barely visible stub for zero-value stages
          color: isEmpty ? Colors.grey.withValues(alpha: 0.08) : color,
          width: 18,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  // ─── 4. Department Comparison (BarChart) ──────────
  Widget _buildDepartmentComparisonChart(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final depts = analytics.departmentAnalytics ?? [];
    if (depts.isEmpty) {
      return _card(
        'Department Comparison',
        Icons.account_balance_outlined,
        isDark,
        child: Text(
          'No department data',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    final displayDepts = depts.take(5).toList();
    final maxScore = 100.0;

    return _card(
      'Department Comparison',
      Icons.account_balance_outlined,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxScore,
                barGroups: List.generate(displayDepts.length, (i) {
                  final dept = displayDepts[i];
                  final avgScore = (dept['avgScore'] as int? ?? 0).toDouble();
                  final color = _scoreColor(avgScore.round());
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: avgScore,
                        color: color,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayDepts.length) {
                          return const SizedBox.shrink();
                        }
                        final name =
                            (displayDepts[idx]['department'] as String? ?? '');
                        final short = name.length > 8
                            ? '${name.substring(0, 7)}.'
                            : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            short,
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      final deptName = idx >= 0 && idx < displayDepts.length
                          ? (displayDepts[idx]['department'] as String? ?? '')
                          : '';
                      return BarTooltipItem(
                        '$deptName\n${rod.toY.round()}/100',
                        const TextStyle(color: Colors.white, fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Skill Gap Distribution (BarChart) ─────────
  Widget _buildSkillGapChart(TeacherAnalyticsProvider analytics, bool isDark) {
    final gaps = analytics.skillGapAnalysis ?? [];
    if (gaps.isEmpty) {
      return _card(
        'Skill Gap Distribution',
        Icons.psychology_outlined,
        isDark,
        child: Text(
          'No skill data available yet',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    final displayGaps = gaps.take(5).toList();
    final maxCount = displayGaps.fold<int>(
      0,
      (m, g) => (g['count'] as int? ?? 0) > m ? (g['count'] as int? ?? 0) : m,
    );

    return _card(
      'Skill Gap Distribution',
      Icons.psychology_outlined,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxCount * 1.2).toDouble(),
                barGroups: List.generate(displayGaps.length, (i) {
                  final g = displayGaps[i];
                  final count = (g['count'] as int? ?? 0).toDouble();
                  final severity = g['severity'] as String? ?? 'medium';
                  final color = severity == 'high'
                      ? AppTheme.error
                      : severity == 'medium'
                      ? AppTheme.warning
                      : AppTheme.success;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: color,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayGaps.length) {
                          return const SizedBox.shrink();
                        }
                        final skill =
                            (displayGaps[idx]['skill'] as String? ?? '');
                        final short = skill.length > 7
                            ? '${skill.substring(0, 6)}.'
                            : skill;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            short,
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5.5. Recommendation Insights (v8.9 Phase 13) ─
  Widget _buildRecommendationInsights(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final careerGoals = analytics.careerGoalDistribution;
    final skillGaps = analytics.recommendationSkillGaps;
    final tiers = analytics.placementTierDistribution;
    final strongMatch = analytics.strongMatchStudents;
    final gapStudents = analytics.significantGapStudents;

    final hasData =
        careerGoals.isNotEmpty ||
        skillGaps.isNotEmpty ||
        tiers.isNotEmpty ||
        strongMatch > 0 ||
        gapStudents > 0;

    if (!hasData) {
      return _card(
        'Recommendation Insights',
        Icons.recommend_outlined,
        isDark,
        child: Text(
          'No recommendation data yet. Students receive personalized '
          'recommendations as they build their profiles and apply to placements.',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    return _card(
      'Recommendation Insights',
      Icons.recommend_outlined,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student spotlight counts.
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space8,
            children: [
              _insightStat(
                'Strong Matches',
                '$strongMatch',
                AppTheme.success,
                isDark,
              ),
              _insightStat(
                'Skill Gaps',
                '$gapStudents',
                AppTheme.warning,
                isDark,
              ),
            ],
          ),
          // v9.0: Career Goals and Target Roles showed the same data
          // (role title vs role ID from the same recommendation doc).
          // Merged into a single "Career Goals" section using human-readable
          // titles. The `targetRole` metadata remains on individual rec cards.
          if (careerGoals.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            Text(
              'Career Goals',
              style: AppTheme.label.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray800,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ..._rankedRows(
              careerGoals.take(5).toList(),
              AppTheme.primaryBlue,
              isDark,
            ),
          ],
          if (skillGaps.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Text(
              'Common Skill Gaps',
              style: AppTheme.label.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray800,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ..._rankedRows(
              skillGaps.take(5).toList(),
              AppTheme.warning,
              isDark,
            ),
          ],
          if (tiers.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Text(
              'Placement Match Distribution',
              style: AppTheme.label.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray800,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                for (final entry in tiers.entries)
                  _tierChip(entry.key, entry.value, isDark),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightStat(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal ranked bars for counted-label lists.
  List<Widget> _rankedRows(
    List<Map<String, dynamic>> items,
    Color color,
    bool isDark,
  ) {
    if (items.isEmpty) return const [];
    final maxCount = items
        .map((e) => (e['count'] as int? ?? 0))
        .fold<int>(0, (a, b) => a > b ? a : b);
    return items.map((entry) {
      final label = (entry['label'] as String? ?? '').trim();
      final count = entry['count'] as int? ?? 0;
      final fraction = maxCount > 0 ? count / maxCount : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: fraction.clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: AppTheme.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _tierChip(String tier, int count, bool isDark) {
    final color = switch (tier) {
      'strong' => AppTheme.success,
      'potential' => AppTheme.primaryBlue,
      _ => AppTheme.warning,
    };
    final label = switch (tier) {
      'strong' => 'Strong Match',
      'potential' => 'Potential',
      'skill_gap' => 'Skill Gap',
      _ => tier,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label ($count)',
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── 6. Mentorship Effectiveness ──────────────────
  Widget _buildMentorshipEffectiveness(BuildContext context, bool isDark) {
    final mentorship = context.watch<MentorshipProvider>();
    final accepted = mentorship.acceptedMentorshipsCount;
    final completed = mentorship.completedMentorshipsCount;
    final total = accepted + completed;

    return _card(
      'Mentorship Effectiveness',
      Icons.school_outlined,
      isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _meStat(
                  'Active',
                  '$accepted',
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
              Expanded(
                child: _meStat(
                  'Completed',
                  '$completed',
                  AppTheme.success,
                  isDark,
                ),
              ),
              Expanded(
                child: _meStat(
                  'Total',
                  '$total',
                  AppTheme.secondaryIndigo,
                  isDark,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppTheme.space12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: completed / total,
                color: AppTheme.success,
                backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
              ),
            ),
            Text(
              'Completion rate: ${(completed / total * 100).round()}%',
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      ],
    );
  }

  // ─── 7. Placement Readiness ───────────────────────
  Widget _buildPlacementReadiness(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final predictedRate = analytics.predictedPlacementRate.round();
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;

    return _card(
      'Placement Readiness',
      Icons.work_outline,
      isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$predictedRate%',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success,
                        ),
                      ),
                      Text(
                        'Readiness',
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$highPotential',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      Text(
                        'Ready Now',
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$atRisk',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.error,
                        ),
                      ),
                      Text(
                        'Need Help',
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 8. Risk Distribution (PieChart) ──────────────
  Widget _buildRiskDistributionChart(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final highPotential = analytics.highPotentialCount.toDouble();
    final medium = analytics.mediumPotentialCount.toDouble();
    final atRisk = analytics.atRiskCount.toDouble();
    final total = highPotential + medium + atRisk;

    if (total == 0) {
      return _card(
        'Risk Distribution',
        Icons.warning_amber_rounded,
        isDark,
        child: Text(
          'No risk data',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    final healthScore = ((highPotential + medium) / total * 100).round();

    return _card(
      'Risk Distribution',
      Icons.warning_amber_rounded,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: highPotential > 0 ? highPotential : 0.1,
                    color: AppTheme.success,
                    radius: 35,
                    title: highPotential > 0 ? '${highPotential.round()}' : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: medium > 0 ? medium : 0.1,
                    color: AppTheme.warning,
                    radius: 35,
                    title: medium > 0 ? '${medium.round()}' : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: atRisk > 0 ? atRisk : 0.1,
                    color: AppTheme.error,
                    radius: 35,
                    title: atRisk > 0 ? '${atRisk.round()}' : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
                centerSpaceRadius: 25,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Wrap(
            spacing: 12,
            children: [
              _legendDot(
                'High Potential',
                AppTheme.success,
                highPotential.round(),
              ),
              _legendDot('Medium', AppTheme.warning, medium.round()),
              _legendDot('At Risk', AppTheme.error, atRisk.round()),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Student Health Score: $healthScore%',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: healthScore >= 70 ? AppTheme.success : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 9. Monthly Resume Trend (LineChart) ──────────
  Widget _buildMonthlyTrendChart(
    TeacherAnalyticsProvider analytics,
    bool isDark,
  ) {
    final trends = analytics.performanceTrends ?? [];
    if (trends.isEmpty) {
      return _card(
        'Monthly Resume Trend',
        Icons.show_chart_rounded,
        isDark,
        child: Text(
          'No trend data available yet',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      final avgScore = (trends[i]['avgScore'] as int? ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), avgScore));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY) * 0.2).clamp(5, 20);

    return _card(
      'Monthly Resume Trend',
      Icons.show_chart_rounded,
      isDark,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (trends.length - 1).toDouble(),
                minY: (minY - yPad).clamp(0, 100),
                maxY: (maxY + yPad).clamp(0, 100),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primaryBlue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trends.length) {
                          return const SizedBox.shrink();
                        }
                        final month = (trends[idx]['month'] as String? ?? '');
                        // Show only last 3 chars of month key
                        final short = month.length >= 7
                            ? month.substring(5)
                            : month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            short,
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final month = idx >= 0 && idx < trends.length
                            ? (trends[idx]['month'] as String? ?? '')
                            : '';
                        return LineTooltipItem(
                          '$month\n${spot.y.round()} pts',
                          const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 10. AI Summary — v8.2 dynamic narrative ──────
  Widget _buildAISummary(
    TeacherAnalyticsProvider analytics,
    BuildContext context,
    bool isDark,
  ) {
    final placements = context.watch<PlacementsProvider>();
    final mentorship = context.watch<MentorshipProvider>();

    final totalStudents = analytics.studentData?.length ?? 0;
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final avgScore = analytics.averageScore.round();
    final predictedRate = analytics.predictedPlacementRate.round();
    final activePlacements = placements.placements
        .where((p) => p.isActive && !p.isDeadlinePassed)
        .length;
    final totalPlacements = placements.placements.length;
    final activeMentorships = mentorship.acceptedMentorshipsCount;
    final totalReviews = analytics.totalReviews;
    final avgEngagement = analytics.avgEngagement;
    final avgProfileStrength = analytics.avgProfileStrength;
    final totalApplied = analytics.pipelineApplied;

    // Track trend direction from performance trends
    final trends = analytics.performanceTrends ?? [];
    bool scoreImproving = false;
    bool scoreDeclining = false;
    if (trends.length >= 2) {
      final first = trends.first['avgScore'] as int? ?? 0;
      final last = trends.last['avgScore'] as int? ?? 0;
      scoreImproving = last > first;
      scoreDeclining = last < first;
    }

    // Build the department with highest / lowest avg score
    // CRITICAL: Copy the list before sorting to avoid mutating the provider's list
    String topDept = '';
    String weakestDept = '';
    final depts = analytics.departmentAnalytics ?? [];
    if (depts.length >= 2) {
      final sortedAsc = List<Map<String, dynamic>>.from(depts)
        ..sort(
          (a, b) => ((a['avgScore'] as int? ?? 0)).compareTo(
            b['avgScore'] as int? ?? 0,
          ),
        );
      weakestDept = sortedAsc.first['department'] as String? ?? '';
      topDept = sortedAsc.last['department'] as String? ?? '';
    } else if (depts.length == 1) {
      topDept = depts.first['department'] as String? ?? '';
      weakestDept = topDept;
    }

    // Generate narrative paragraphs
    final paragraphs = <String>[];

    // Opening — placement readiness
    if (totalStudents > 0) {
      paragraphs.add(
        'Overall placement readiness is at $predictedRate%, tracking $totalStudents students across '
        '$depts.length department${depts.length != 1 ? 's' : ''}. '
        '${totalReviews > 0 ? 'A total of $totalReviews resume reviews have been completed, ' : ''}'
        'with an average ATS score of $avgScore/100.'
        '${scoreImproving ? ' Scores are trending upward.' : ''}'
        '${scoreDeclining ? ' Scores have declined recently.' : ''}',
      );
    }

    // Department insights
    if (topDept.isNotEmpty &&
        weakestDept.isNotEmpty &&
        topDept != weakestDept) {
      paragraphs.add(
        '$topDept students have the strongest resume scores, while $weakestDept requires the most improvement. '
        'Consider targeted resume workshops for $weakestDept students.',
      );
    }

    // At-risk and high-potential
    if (atRisk > 0) {
      paragraphs.add(
        '$atRisk students are flagged as at-risk due to low ATS scores, limited engagement, or lack of mentorship. '
        'Recommended intervention: schedule one-on-one reviews and mentorship assignments.',
      );
    }
    if (highPotential > 0) {
      paragraphs.add(
        '$highPotential students are placement-ready and should be encouraged to apply for active opportunities.',
      );
    }

    // Engagement and profile trends
    if (avgEngagement > 0 || avgProfileStrength > 0) {
      final engagementDir = avgEngagement >= 60
          ? 'positive'
          : 'needs improvement';
      paragraphs.add(
        'Average student engagement is $avgEngagement/100 ($engagementDir), '
        'with profile strength averaging $avgProfileStrength/100. '
        '${activeMentorships > 0 ? '$activeMentorships active mentorships are helping drive engagement.' : 'Mentorship programs can help improve these metrics.'}',
      );
    }

    // Application and placement activity
    if (totalApplied > 0 || totalPlacements > 0) {
      paragraphs.add(
        'There are $totalPlacements placement drives ($activePlacements active), '
        'with $totalApplied applications submitted across all students. '
        '${activePlacements > 0 ? 'Encourage students to apply for the open positions.' : 'Consider posting new opportunities to increase placement activity.'}',
      );
    }

    // Closing recommendation
    if (atRisk > 3 || avgScore < 60) {
      paragraphs.add(
        'Recommended intervention: conduct a resume workshop for final year students, '
        'with focused sessions on addressing the most common skill gaps identified in the analysis.',
      );
    } else if (highPotential > 5 && activePlacements > 0) {
      paragraphs.add(
        'The cohort is well-positioned for placements. Maintain momentum by keeping students informed '
        'of new opportunities and encouraging mentor-driven preparation.',
      );
    }

    // Fallback if no data
    if (paragraphs.isEmpty) {
      paragraphs.add(
        'No analytics data available yet. Start by reviewing student resumes to generate insights.',
      );
    }

    return _card(
      'AI Summary',
      Icons.summarize_outlined,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space8),
                child: Text(
                  p,
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                    height: 1.5,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Shared ───────────────────────────────────────
  Widget _card(
    String title,
    IconData icon,
    bool isDark, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
              const SizedBox(width: AppTheme.space8),
              Text(
                title,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          child,
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkBackground : AppTheme.background,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space16),
            child: SkeletonLoader(
              height: 120,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
      ),
    );
  }
}
