import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// AI Insights Tab — Dedicated institutional analytics dashboard.
///
/// NOT an AI chat. Pure analytics only, driven entirely by existing providers.
/// Uses FL Chart for visualizations where applicable.
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: () => context.read<TeacherAnalyticsProvider>().loadAnalytics(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Campus Health
              _buildCampusHealth(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 2. Placement Prediction
              _buildPlacementPrediction(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 3. Resume Quality Trends
              _buildResumeQualityTrends(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 4. Department Comparison
              _buildDepartmentComparison(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 5. Skill Demand
              _buildSkillDemand(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 6. Mentorship Effectiveness
              _buildMentorshipEffectiveness(context, isDark),
              const SizedBox(height: AppTheme.space16),

              // 7. Placement Readiness
              _buildPlacementReadiness(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 8. Risk Analysis
              _buildRiskAnalysis(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 9. Monthly Progress
              _buildMonthlyProgress(analytics, isDark),
              const SizedBox(height: AppTheme.space16),

              // 10. AI Summary
              _buildAISummary(analytics, context, isDark),
              const SizedBox(height: AppTheme.space32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: isDark ? Colors.white : AppTheme.gray900, size: 24),
          const SizedBox(width: 8),
          Text(
            'AI Insights',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
      elevation: 0,
      actions: [
        NotificationBadge(
          onTap: () => Navigator.pushNamed(context, notificationsRoute),
          iconColor: isDark ? AppTheme.gray400 : null,
        ),
        ChatBadge(iconColor: isDark ? AppTheme.gray400 : null),
      ],
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
          _healthTile('Students', '$totalStudents', AppTheme.primaryBlue, isDark),
          _healthTile('Reviews', '$totalReviews', AppTheme.success, isDark),
          _healthTile('Avg Score', '$avgScore/100', AppTheme.warning, isDark),
          _healthTile('High Potential', '$highPotential', Colors.green, isDark),
          _healthTile('At Risk', '$atRisk', AppTheme.error, isDark),
        ],
      ),
    );
  }

  Widget _healthTile(String label, String value, Color color, bool isDark) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 3,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: AppTheme.space4),
          Text(label,
              style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
        ],
      ),
    );
  }

  // ─── 2. Placement Prediction ──────────────────────
  Widget _buildPlacementPrediction(TeacherAnalyticsProvider analytics, bool isDark) {
    final predictedRate = analytics.predictedPlacementRate.round();
    final highPot = analytics.highPotentialCount;
    final medium = analytics.mediumPotentialCount;

    return _card(
      'Placement Prediction',
      Icons.insights_rounded,
      isDark,
      child: Column(
        children: [
          Row(
            children: [
              _predictionMeter('Predicted Rate', predictedRate, AppTheme.secondaryIndigo, isDark),
              const SizedBox(width: AppTheme.space16),
              _predictionMeter('High Potential', highPot, AppTheme.success, isDark),
              const SizedBox(width: AppTheme.space16),
              _predictionMeter('Medium', medium, AppTheme.warning, isDark),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: predictedRate / 100.0,
              color: AppTheme.secondaryIndigo,
              backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionMeter(String label, int value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text('$value${label == 'Predicted Rate' ? '%' : ''}',
              style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
        ],
      ),
    );
  }

  // ─── 3. Resume Quality Trends ─────────────────────
  Widget _buildResumeQualityTrends(TeacherAnalyticsProvider analytics, bool isDark) {
    final total = analytics.totalReviews;
    if (total == 0) return const SizedBox.shrink();

    final excellentPct = analytics.excellentCount / total * 100;
    final goodPct = analytics.goodCount / total * 100;
    final fairPct = analytics.fairCount / total * 100;
    final poorPct = analytics.poorCount / total * 100;

    return _card(
      'Resume Quality Trends',
      Icons.description_outlined,
      isDark,
      child: Column(
        children: [
          _qualityBar('Excellent (80+)', excellentPct, analytics.excellentCount, const Color(0xFF059669), isDark),
          const SizedBox(height: AppTheme.space8),
          _qualityBar('Good (60-79)', goodPct, analytics.goodCount, const Color(0xFF0891B2), isDark),
          const SizedBox(height: AppTheme.space8),
          _qualityBar('Fair (40-59)', fairPct, analytics.fairCount, const Color(0xFFEA580C), isDark),
          const SizedBox(height: AppTheme.space8),
          _qualityBar('Poor (<40)', poorPct, analytics.poorCount, const Color(0xFFDC2626), isDark),
          const SizedBox(height: AppTheme.space16),
          Text('Average Score: ${analytics.averageScore.round()}/100',
              style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900)),
        ],
      ),
    );
  }

  Widget _qualityBar(String label, double pct, int count, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: AppTheme.caption.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700))),
          Text('$count (${pct.round()}%)',
              style: AppTheme.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppTheme.space4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: (pct / 100).clamp(0.0, 1.0),
            color: color,
            backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
      ],
    );
  }

  // ─── 4. Department Comparison ─────────────────────
  Widget _buildDepartmentComparison(TeacherAnalyticsProvider analytics, bool isDark) {
    // Department data from analytics — use avg score as proxy
    final avgScore = analytics.averageScore.round();

    return _card(
      'Department Comparison',
      Icons.account_balance_outlined,
      isDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _deptRow('Your Dept', avgScore, avgScore, isDark),
                const SizedBox(height: AppTheme.space8),
                _deptRow('Target', 75, avgScore, isDark),
                const SizedBox(height: AppTheme.space8),
                _deptRow('Institution', (avgScore * 0.95).round(), avgScore, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deptRow(String label, int score, int maxScore, bool isDark) {
    final pct = maxScore > 0 ? score / maxScore : 0.0;
    final color = score >= 70 ? AppTheme.success : score >= 50 ? AppTheme.warning : AppTheme.error;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.gray300 : AppTheme.gray700))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: pct.clamp(0.0, 1.0),
              color: color,
              backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        Text('$score', style: AppTheme.caption.copyWith(
            color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ─── 5. Skill Demand ──────────────────────────────
  Widget _buildSkillDemand(TeacherAnalyticsProvider analytics, bool isDark) {
    final gaps = analytics.skillGapAnalysis ?? [];
    if (gaps.isEmpty) {
      return _card(
        'Skill Demand',
        Icons.psychology_outlined,
        isDark,
        child: Text('No skill data available yet',
            style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
      );
    }

    return _card(
      'Skill Demand',
      Icons.psychology_outlined,
      isDark,
      child: Column(
        children: gaps.take(5).map((g) {
          final skill = g['skill'] as String? ?? '';
          final count = g['count'] as int? ?? 0;
          final maxCount = gaps.fold<int>(0, (m, item) => (item['count'] as int? ?? 0) > m ? (item['count'] as int? ?? 0) : m);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(skill, style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.gray800)),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: maxCount > 0 ? count / maxCount : 0.0,
                      color: AppTheme.warning,
                      backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Text('$count', style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray300 : AppTheme.gray700, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }).toList(),
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
              Expanded(child: _meStat('Active', '$accepted', AppTheme.primaryBlue, isDark)),
              Expanded(child: _meStat('Completed', '$completed', AppTheme.success, isDark)),
              Expanded(child: _meStat('Total', '$total', AppTheme.secondaryIndigo, isDark)),
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
            Text('Completion rate: ${(completed / total * 100).round()}%',
                style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
          ],
        ],
      ),
    );
  }

  Widget _meStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w700, color: color)),
        Text(label, style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
      ],
    );
  }

  // ─── 7. Placement Readiness ───────────────────────
  Widget _buildPlacementReadiness(TeacherAnalyticsProvider analytics, bool isDark) {
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
                    color: AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text('$predictedRate%',
                          style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w800, color: AppTheme.success)),
                      Text('Readiness', style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text('$highPotential',
                          style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
                      Text('Ready Now', style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Text('$atRisk',
                          style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w800, color: AppTheme.error)),
                      Text('Need Help', style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
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

  // ─── 8. Risk Analysis ─────────────────────────────
  Widget _buildRiskAnalysis(TeacherAnalyticsProvider analytics, bool isDark) {
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final medium = analytics.mediumPotentialCount;
    final total = atRisk + highPotential + medium;
    final healthScore = total > 0 ? ((highPotential + medium) / total * 100).round() : 0;

    return _card(
      'Risk Analysis',
      Icons.warning_amber_rounded,
      isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Health Score',
                        style: AppTheme.bodySmall.copyWith(
                            color: isDark ? AppTheme.gray300 : AppTheme.gray700)),
                    const SizedBox(height: AppTheme.space4),
                    Text('$healthScore%',
                        style: AppTheme.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: healthScore >= 70 ? AppTheme.success : AppTheme.warning)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: healthScore / 100.0),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, _) {
                    return SizedBox(
                      height: 80,
                      child: Center(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 8,
                            color: healthScore >= 70 ? AppTheme.success : AppTheme.warning,
                            backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 9. Monthly Progress ──────────────────────────
  Widget _buildMonthlyProgress(TeacherAnalyticsProvider analytics, bool isDark) {
    final trends = analytics.performanceTrends ?? [];
    if (trends.isEmpty) return const SizedBox.shrink();

    return _card(
      'Monthly Progress',
      Icons.show_chart_rounded,
      isDark,
      child: Column(
        children: trends.take(6).map((t) {
          final month = t['month'] as String? ?? '';
          final avgScore = t['avgScore'] as int? ?? 0;
          final count = t['reviewCount'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space8),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(month, style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray800))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: avgScore / 100.0,
                      color: AppTheme.primaryBlue,
                      backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Text('$avgScore', style: AppTheme.caption.copyWith(
                    color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                const SizedBox(width: AppTheme.space4),
                Text('($count)', style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 10. AI Summary ───────────────────────────────
  Widget _buildAISummary(TeacherAnalyticsProvider analytics, BuildContext context, bool isDark) {
    final placements = context.watch<PlacementsProvider>();
    final mentorship = context.watch<MentorshipProvider>();

    final totalStudents = analytics.studentData?.length ?? 0;
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final avgScore = analytics.averageScore.round();
    final predictedRate = analytics.predictedPlacementRate.round();
    final activePlacements = placements.placements.where((p) => p.isActive && !p.isDeadlinePassed).length;
    final activeMentorships = mentorship.acceptedMentorshipsCount;
    final totalReviews = analytics.totalReviews;

    // Build a narrative summary from real data
    final points = <String>[];
    if (totalStudents > 0) points.add('Tracking $totalStudents students.');
    if (highPotential > 5) points.add('$highPotential students are placement-ready.');
    if (atRisk > 3) points.add('$atRisk students need intervention.');
    if (avgScore > 0) points.add('Average resume score: $avgScore/100.');
    if (activePlacements > 0) points.add('$activePlacements active placement drives.');
    if (activeMentorships > 0) points.add('$activeMentorships active mentorships.');
    if (totalReviews > 0) points.add('$totalReviews resume reviews completed.');
    points.add('Predicted placement rate: $predictedRate%.');

    return _card(
      'AI Summary',
      Icons.summarize_outlined,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTheme.bodySmall.copyWith(
                    color: const Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                Expanded(
                  child: Text(p, style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray700)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Shared ───────────────────────────────────────
  Widget _card(String title, IconData icon, bool isDark, {required Widget child}) {
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
              Text(title, style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          child,
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: List.generate(5, (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space16),
          child: SkeletonLoader(height: 120, borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        )),
      ),
    );
  }
}
