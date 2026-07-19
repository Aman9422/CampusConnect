import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/shared/main_navigation_view.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// =============================================================================
// Shared helpers
// =============================================================================
Widget _sectionHeader(String title, bool isDark, {IconData? icon}) {
  if (icon != null) {
    return Row(children: [
      Icon(icon, size: 18, color: isDark ? AppTheme.gray300 : AppTheme.gray700),
      const SizedBox(width: AppTheme.space8),
      Text(title, style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
    ]);
  }
  return Text(title, style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900));
}

/// Common card decoration with modern shadow
BoxDecoration _cardDecoration(bool isDark) {
  return BoxDecoration(
    color: isDark ? AppTheme.darkSurface : AppTheme.surface,
    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
    boxShadow: isDark ? null : AppTheme.shadowSmall,
  );
}

// =============================================================================
// 1. Welcome Header
// =============================================================================
class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final name = profile?.personal.effectiveDisplayName ?? 'Professor';
    final dept = profile?.department ?? 'Computer Science';
    final designation = profile?.designation ?? 'Faculty';

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryIndigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: name, size: 52),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $name',
                        style: AppTheme.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.space4),
                    if (designation.isNotEmpty)
                      Text(designation,
                          style: AppTheme.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(child: _chipInfo(dept, Icons.science_outlined)),
              const SizedBox(width: AppTheme.space12),
              Expanded(child: _chipInfo(dateStr, Icons.calendar_today_outlined)),
              const SizedBox(width: AppTheme.space12),
              Expanded(child: _chipInfo(greeting, Icons.wb_sunny_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipInfo(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8, horizontal: AppTheme.space8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: AppTheme.space4),
          Flexible(
            child: Text(text,
                style: AppTheme.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}

// =============================================================================
// 2. Quick Statistics
// =============================================================================
class QuickStatistics extends StatelessWidget {
  const QuickStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();
    final reviews = context.watch<ResumeReviewProvider>();
    final mentorship = context.watch<MentorshipProvider>();

    if (analytics.isLoading && !analytics.hasData) {
      return _rowOfTwo(
        _skeletonCard(isDark), _skeletonCard(isDark),
        _skeletonCard(isDark), _skeletonCard(isDark),
      );
    }

    final totalStudents = analytics.studentData?.length ?? 0;
    final totalPlacements = placements.placements.length;
    final avgScore = reviews.totalReviews > 0 ? reviews.averageScore : analytics.averageScore;
    final placementRate = totalStudents > 0
        ? ((placements.placements.where((p) => p.isActive).length / totalStudents) * 100).round()
        : 0;
    final activeMentorships = mentorship.acceptedMentorshipsCount;
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quick Statistics', isDark),
        const SizedBox(height: AppTheme.space12),
        _rowOfTwo(
          _statCard('Total Students', '$totalStudents', Icons.people_outline, AppTheme.primaryBlue, isDark),
          _statCard('Active Placements', '$totalPlacements', Icons.business_outlined, AppTheme.success, isDark),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard('Placement Rate', '$placementRate%', Icons.trending_up_rounded, AppTheme.secondaryIndigo, isDark),
          _statCard('Avg Resume Score', '${avgScore.round()}/100', Icons.star_outline, AppTheme.warning, isDark),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard('At Risk', '$atRisk', Icons.warning_amber_rounded, AppTheme.error, isDark),
          _statCard('High Potential', '$highPotential', Icons.emoji_events_outlined, AppTheme.success, isDark),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard('Mentorships', '$activeMentorships', Icons.school_outlined, AppTheme.primaryBlue, isDark),
          _statCard('Reviews', '${reviews.totalReviews}', Icons.description_outlined, AppTheme.warning, isDark),
        ),
      ],
    );
  }

  Widget _rowOfTwo(Widget a, Widget b, [Widget? c, Widget? d]) {
    if (c == null) {
      return Row(children: [Expanded(child: a), const SizedBox(width: AppTheme.space8), Expanded(child: b)]);
    }
    return Column(
      children: [
        Row(children: [Expanded(child: a), const SizedBox(width: AppTheme.space8), Expanded(child: b)]),
        if (d != null) ...[
          const SizedBox(height: AppTheme.space8),
          Row(children: [Expanded(child: c), const SizedBox(width: AppTheme.space8), Expanded(child: d)]),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.gray900)),
                Text(label,
                    style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard(bool isDark) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: SkeletonLoader(height: 36, width: double.infinity),
      ),
    );
  }
}

// =============================================================================
// 3. Department Overview
// =============================================================================
class DepartmentOverview extends StatelessWidget {
  const DepartmentOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();

    if (!analytics.hasData) return const SizedBox.shrink();

    final studentData = analytics.studentData ?? [];
    final placementsCount = placements.placements.length;
    final avgScore = analytics.averageScore.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Department Overview', isDark, icon: Icons.account_balance_outlined),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              _deptStat('Students', '${studentData.length}', Colors.blue, isDark),
              const SizedBox(width: AppTheme.space8),
              _deptStat('Avg Score', '$avgScore/100', Colors.green, isDark),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              _deptStat('Placements', '$placementsCount', Colors.orange, isDark),
              const SizedBox(width: AppTheme.space8),
              _deptStat(
                'Placement %',
                studentData.isNotEmpty ? '${((placementsCount / studentData.length) * 100).round()}%' : '0%',
                AppTheme.secondaryIndigo, isDark),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          _buildTopSkills(analytics, isDark),
        ],
      ),
    );
  }

  Widget _deptStat(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12, horizontal: AppTheme.space12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.gray900)),
            Text(label, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSkills(TeacherAnalyticsProvider analytics, bool isDark) {
    final gaps = analytics.skillGapAnalysis ?? [];
    if (gaps.isEmpty) return const SizedBox.shrink();

    final topSkills = gaps.take(4).map((g) => g['skill'] as String? ?? '').where((s) => s.isNotEmpty).toList();
    if (topSkills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Department Skills', style: AppTheme.label.copyWith(color: isDark ? AppTheme.gray300 : AppTheme.gray700)),
        const SizedBox(height: AppTheme.space8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: topSkills.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
            ),
            child: Text(s, style: AppTheme.caption.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
          )).toList(),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. Placement Pipeline (Horizontal)
// =============================================================================
class PlacementPipeline extends StatelessWidget {
  const PlacementPipeline({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placements = context.watch<PlacementsProvider>();
    final allPlacements = placements.placements;

    final active = allPlacements.where((p) => p.isActive && !p.isDeadlinePassed).length;
    final expired = allPlacements.where((p) => p.isDeadlinePassed || !p.isActive).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Placement Pipeline', isDark, icon: Icons.rocket_launch_outlined),
          const SizedBox(height: AppTheme.space16),
          if (allPlacements.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Text('No placement data yet',
                    style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
              ),
            )
          else
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _pipelineStep('Eligible', '${allPlacements.length}', AppTheme.primaryBlue, isDark),
                  _pipelineArrow(isDark),
                  _pipelineStep('Shortlisted', '${(active * 0.6).round()}', AppTheme.warning, isDark),
                  _pipelineArrow(isDark),
                  _pipelineStep('Applied', '$active', AppTheme.secondaryIndigo, isDark),
                  _pipelineArrow(isDark),
                  _pipelineStep('Placed', '${(active * 0.3).round()}', AppTheme.success, isDark),
                  _pipelineArrow(isDark),
                  _pipelineStep('Expired', '$expired', AppTheme.error, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pipelineStep(String label, String count, Color color, bool isDark) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: isDark ? null : [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w800, color: color)),
          Text(label, style: AppTheme.caption.copyWith(fontSize: 9, color: isDark ? AppTheme.gray300 : AppTheme.gray700)),
        ],
      ),
    );
  }

  Widget _pipelineArrow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? AppTheme.gray500 : AppTheme.gray400),
    );
  }
}

// =============================================================================
// 5. Resume Review Analytics
// =============================================================================
class ResumeReviewAnalytics extends StatelessWidget {
  const ResumeReviewAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final reviews = context.watch<ResumeReviewProvider>();

    if (!analytics.hasData) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Resume Review Analytics', isDark, icon: Icons.description_outlined),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(child: _rrStat('Total', '${analytics.totalReviews}', AppTheme.primaryBlue, isDark)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _rrStat('Average', '${analytics.averageScore.round()}/100', AppTheme.success, isDark)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _rrStat('Excellent', '${analytics.excellentCount}', Colors.green, isDark)),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(child: _rrStat('Good', '${analytics.goodCount}', Colors.cyan, isDark)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _rrStat('Fair', '${analytics.fairCount}', Colors.orange, isDark)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _rrStat('Poor', '${analytics.poorCount}', AppTheme.error, isDark)),
            ],
          ),
          if (reviews.history.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            Text('Latest Reviews', style: AppTheme.label.copyWith(color: isDark ? AppTheme.gray300 : AppTheme.gray700)),
            const SizedBox(height: AppTheme.space8),
            ...reviews.history.take(3).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _scoreColor(r.atsScore).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text('${r.atsScore}', style: AppTheme.caption.copyWith(
                      color: _scoreColor(r.atsScore), fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(r.strengths.isNotEmpty ? r.strengths.first : 'Review completed',
                      style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray300 : AppTheme.gray700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _rrStat(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppTheme.caption.copyWith(fontSize: 10, color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF059669);
    if (score >= 60) return const Color(0xFF0891B2);
    if (score >= 40) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }
}

// =============================================================================
// 6. Skill Gap Analysis
// =============================================================================
class SkillGapAnalysis extends StatelessWidget {
  const SkillGapAnalysis({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final gaps = analytics.skillGapAnalysis ?? [];

    if (gaps.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Skill Gap Analysis', isDark, icon: Icons.psychology_outlined),
          const SizedBox(height: AppTheme.space16),
          ...gaps.take(6).map((g) {
            final skill = g['skill'] as String? ?? '';
            final count = g['count'] as int? ?? 0;
            final severity = g['severity'] as String? ?? 'medium';
            final color = severity == 'high' ? AppTheme.error : severity == 'medium' ? AppTheme.warning : AppTheme.success;
            final maxCount = gaps.fold<int>(0, (max, item) => (item['count'] as int? ?? 0) > max ? (item['count'] as int? ?? 0) : max);
            final progress = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(skill, style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppTheme.gray800))),
                    Text('$count', style: AppTheme.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: AppTheme.space4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6, value: progress.clamp(0.0, 1.0), color: color,
                      backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// 7. AI Insights Overview
// =============================================================================
class AIInsightsOverview extends StatelessWidget {
  const AIInsightsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();

    if (!analytics.hasData) return const SizedBox.shrink();

    final totalStudents = analytics.studentData?.length ?? 0;
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final avgScore = analytics.averageScore.round();
    final placementRate = analytics.predictedPlacementRate.round();

    final insights = <_Insight>[];

    if (atRisk > 0) {
      insights.add(_Insight(
        '$atRisk student${atRisk > 1 ? 's' : ''} need${atRisk == 1 ? 's' : ''} intervention',
        'Low ATS scores — prioritize mentorship and resume workshops',
        Icons.warning_amber_rounded, AppTheme.error));
    }
    if (highPotential > 0) {
      insights.add(_Insight(
        '$highPotential high-potential student${highPotential > 1 ? 's' : ''}',
        'Ready for placement opportunities — encourage applications',
        Icons.emoji_events_outlined, AppTheme.success));
    }
    if (avgScore > 65) {
      insights.add(_Insight(
        'Resume quality is strong', 'Average score $avgScore/100 — above threshold',
        Icons.thumb_up_alt_outlined, AppTheme.success));
    } else {
      insights.add(_Insight(
        'Resume quality needs improvement', 'Average score $avgScore/100 — below 70 target',
        Icons.trending_down_rounded, AppTheme.warning));
    }
    if (placementRate > 60) {
      insights.add(_Insight(
        'Placement readiness positive', 'Predicted placement rate $placementRate%',
        Icons.insights_rounded, AppTheme.primaryBlue));
    }
    if (totalStudents > 0 && placements.placements.isNotEmpty) {
      insights.add(_Insight(
        '${placements.placements.length} active placements',
        '${(placements.placements.where((p) => p.isActive && !p.isDeadlinePassed).length)} currently open',
        Icons.business_outlined, AppTheme.secondaryIndigo));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('AI Insights Overview', isDark, icon: Icons.auto_awesome),
          const SizedBox(height: AppTheme.space16),
          ...insights.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: i.color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(i.icon, color: i.color, size: 16),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title, style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
                      if (i.subtitle.isNotEmpty)
                        Text(i.subtitle, style: AppTheme.caption.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _Insight {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _Insight(this.title, this.subtitle, this.icon, this.color);
}

// =============================================================================
// 8. At-Risk Students
// =============================================================================
class AtRiskStudents extends StatelessWidget {
  const AtRiskStudents({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();

    if (!analytics.hasData || analytics.studentData == null) return const SizedBox.shrink();

    final atRisk = analytics.studentData!
        .where((s) {
          final score = s['latestScore'] as int? ?? 0;
          return score < 50;
        })
        .take(5)
        .toList();

    if (atRisk.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        boxShadow: isDark ? null : [
          BoxShadow(color: AppTheme.error.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: AppTheme.error.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.error),
            const SizedBox(width: AppTheme.space8),
            Text('At-Risk Students',
                style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
              child: Text('${atRisk.length}', style: AppTheme.caption.copyWith(color: AppTheme.error, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppTheme.space16),
          ...atRisk.map((s) {
            final name = s['studentName'] as String? ?? 'Unknown Student';
            final score = s['latestScore'] as int? ?? 0;
            final reviewCount = s['reviewCount'] as int? ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.space8),
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : AppTheme.errorBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: name, size: 36),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
                        Text('Score: $score/100 • $reviewCount review${reviewCount != 1 ? 's' : ''}',
                            style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, studentAnalyticsRoute),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: Text('View', style: AppTheme.caption.copyWith(color: AppTheme.primaryBlue)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// 9. Recent Activity
// =============================================================================
class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activityFeed = context.watch<ActivityFeedProvider>();

    final items = <_ActItem>[];
    items.addAll(activityFeed.allActivities.take(5).map((a) =>
        _ActItem(a.title, a.description, a.icon, a.iconColor)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Activity', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          decoration: _cardDecoration(isDark),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  child: Center(child: Text('No recent activities',
                      style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500))),
                )
              : Column(children: items.map((a) => _activityItem(a, isDark)).toList()),
        ),
      ],
    );
  }

  Widget _activityItem(_ActItem a, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: AppTheme.space12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(a.icon, color: a.color, size: 18),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(a.subtitle, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _ActItem(this.title, this.subtitle, this.icon, this.color);
}

// =============================================================================
// 10. Quick Actions
// =============================================================================
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = <_QAction>[
      _QAction('Review Resume', Icons.description_outlined, AppTheme.primaryBlue, resumeReviewRoute),
      _QAction('Student Analytics', Icons.analytics_outlined, AppTheme.success, studentAnalyticsRoute),
      _QAction('Placement Reports', Icons.assessment_outlined, AppTheme.secondaryIndigo, placementsListRoute),
      _QAction('Skill Gap', Icons.psychology_outlined, AppTheme.warning, studentAnalyticsRoute),
      _QAction('AI Insights', Icons.auto_awesome, const Color(0xFF7C3AED), ''), // Switches to tab 3
      _QAction('Announcements', Icons.campaign_outlined, AppTheme.error, notificationsRoute),
      _QAction('Export Report', Icons.download_outlined, Colors.teal, studentAnalyticsRoute),
      _QAction('Manage Opps', Icons.work_outline, AppTheme.primaryBlue, opportunitiesRoute),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quick Actions', isDark),
        const SizedBox(height: AppTheme.space12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: AppTheme.space8,
            mainAxisSpacing: AppTheme.space8,
            childAspectRatio: 0.85,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final a = actions[index];
            return InkWell(
              onTap: () {
                if (index == 4) {
                  _switchToTab(context, 3);
                } else {
                  Navigator.pushNamed(context, a.route);
                }
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: _cardDecoration(isDark),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(a.label, style: AppTheme.caption.copyWith(fontSize: 9, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray800), textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  _QAction(this.label, this.icon, this.color, this.route);
}

/// Switch to a specific tab in the parent MainNavigationView
void _switchToTab(BuildContext context, int tabIndex) {
  final navState = context.findAncestorStateOfType<MainNavigationViewState>();
  navState?.setSelectedIndex(tabIndex);
}
