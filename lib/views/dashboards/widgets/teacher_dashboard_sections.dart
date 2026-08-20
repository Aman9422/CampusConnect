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
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppTheme.gray300 : AppTheme.gray700,
        ),
        const SizedBox(width: AppTheme.space8),
        Text(
          title,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ],
    );
  }
  return Text(
    title,
    style: AppTheme.titleSmall.copyWith(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : AppTheme.gray900,
    ),
  );
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

/// Score categories — single source of truth for thresholds
const int _scoreExcellent = 80;
const int _scoreGood = 60;
const int _scoreFair = 40;

Color _scoreColor(int score) {
  if (score >= _scoreExcellent) return const Color(0xFF059669);
  if (score >= _scoreGood) return const Color(0xFF0891B2);
  if (score >= _scoreFair) return const Color(0xFFEA580C);
  return const Color(0xFFDC2626);
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
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
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
                    Text(
                      '$greeting, $name',
                      style: AppTheme.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    if (designation.isNotEmpty)
                      Text(
                        designation,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
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
              Expanded(
                child: _chipInfo(dateStr, Icons.calendar_today_outlined),
              ),
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
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space8,
        horizontal: AppTheme.space8,
      ),
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
            child: Text(
              text,
              style: AppTheme.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }
}

// =============================================================================
// 2. Quick Statistics — 8 target metrics
// =============================================================================
class QuickStatistics extends StatelessWidget {
  const QuickStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();
    final mentorship = context.watch<MentorshipProvider>();

    if (analytics.isLoading && !analytics.hasData) {
      return _rowOfTwo(
        _skeletonCard(isDark),
        _skeletonCard(isDark),
        _skeletonCard(isDark),
        _skeletonCard(isDark),
      );
    }

    final totalStudents = analytics.pipelineTotalStudents > 0
        ? analytics.pipelineTotalStudents
        : (analytics.studentData?.length ?? 0);
    // v9.1 audit (BUG-D): the "Placement Rate" used to be
    // activeDrives ÷ students — it could exceed 100% and was semantically
    // wrong. V9.1 wired REAL distinct-student counts into the pipeline
    // (TeacherAnalyticsService.getApplicationPipelineCounts); use
    // `analytics.pipelinePlaced` for the numerator, falling back gracefully
    // (0) when pipeline data hasn't loaded or the apps query failed.
    final activeDrives = placements.placements.where((p) => p.isActive).length;
    final placedStudents = analytics.pipelinePlaced;
    final avgScore = analytics.averageScore;
    final placementRate = totalStudents > 0
        ? ((placedStudents / totalStudents) * 100).round()
        : 0;
    final activeMentorships = mentorship.acceptedMentorshipsCount;
    final avgEngagement = analytics.avgEngagement;
    final avgProfileStrength = analytics.avgProfileStrength;
    final activeAlumni = analytics.activeAlumni;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quick Statistics', isDark),
        const SizedBox(height: AppTheme.space12),
        _rowOfTwo(
          _statCard(
            'Total Students',
            '$totalStudents',
            Icons.people_outline,
            AppTheme.primaryBlue,
            isDark,
          ),
          _statCard(
            'Active Drives',
            '$activeDrives',
            Icons.business_outlined,
            AppTheme.success,
            isDark,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard(
            'Placement Rate',
            '$placementRate%',
            Icons.trending_up_rounded,
            AppTheme.secondaryIndigo,
            isDark,
          ),
          _statCard(
            'Avg Resume Score',
            '${avgScore.round()}/100',
            Icons.star_outline,
            AppTheme.warning,
            isDark,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard(
            'Avg Engagement',
            '$avgEngagement/100',
            Icons.favorite_outline,
            AppTheme.success,
            isDark,
          ),
          _statCard(
            'Avg Profile Strength',
            '$avgProfileStrength/100',
            Icons.shield_outlined,
            AppTheme.primaryBlue,
            isDark,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        _rowOfTwo(
          _statCard(
            'Active Alumni',
            '$activeAlumni',
            Icons.groups_outlined,
            const Color(0xFF7C3AED),
            isDark,
          ),
          _statCard(
            'Active Mentorships',
            '$activeMentorships',
            Icons.school_outlined,
            AppTheme.warning,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _rowOfTwo(Widget a, Widget b, [Widget? c, Widget? d]) {
    if (c == null) {
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: AppTheme.space8),
          Expanded(child: b),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: AppTheme.space8),
            Expanded(child: b),
          ],
        ),
        if (d != null) ...[
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(child: c),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: d),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
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
                Text(
                  value,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
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
// 3. Department Overview — per-department cards (v8.2)
// =============================================================================
class DepartmentOverview extends StatelessWidget {
  const DepartmentOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    // v9.1 audit (BUG-D): `placements` was previously read for
    // `placements.placements.length` in the now-fixed "Active/Student"
    // metric; the rate is computed from `analytics.pipelinePlaced` so the
    // provider read is gone.
    if (!analytics.hasData) return const SizedBox.shrink();

    final depts = analytics.departmentAnalytics ?? [];
    final totalStudents = analytics.pipelineTotalStudents > 0
        ? analytics.pipelineTotalStudents
        : (analytics.studentData?.length ?? 0);
    // v9.1 audit (BUG-D): "Active/Student" used to be totalDrives ÷ students —
    // same fake metric as QuickStatistics. Use the REAL distinct-student
    // placed count from the pipeline (analytics.pipelinePlaced).
    final placedStudents = analytics.pipelinePlaced;
    final overallPlacementPct = totalStudents > 0
        ? ((placedStudents / totalStudents) * 100).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Department Overview',
            isDark,
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: AppTheme.space12),
          // Overall department summary
          Row(
            children: [
              _deptStat(
                'Total Students',
                '$totalStudents',
                AppTheme.primaryBlue,
                isDark,
              ),
              const SizedBox(width: AppTheme.space8),
              _deptStat(
                'Active/Student',
                '$overallPlacementPct%',
                AppTheme.secondaryIndigo,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),

          // Per-department cards
          if (depts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
              child: Center(
                child: Text(
                  'No department data available',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
              ),
            )
          else
            ...depts.take(6).map((dept) {
              final deptName = dept['department'] as String? ?? 'Unknown';
              final studentCount = dept['studentCount'] as int? ?? 0;
              final avgScore = dept['avgScore'] as int? ?? 0;
              final riskLevel = dept['riskLevel'] as String? ?? 'low';
              final topSkills =
                  (dept['topSkills'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  [];
              final riskColor = riskLevel == 'high'
                  ? AppTheme.error
                  : riskLevel == 'medium'
                  ? AppTheme.warning
                  : AppTheme.success;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space12),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.gray800 : AppTheme.gray50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border(
                      left: BorderSide(color: riskColor, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deptName,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.gray900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: riskColor),
                                const SizedBox(width: 4),
                                Text(
                                  riskLevel.toUpperCase(),
                                  style: AppTheme.caption.copyWith(
                                    color: riskColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Row(
                        children: [
                          _deptMiniStat(
                            'Students',
                            '$studentCount',
                            AppTheme.primaryBlue,
                            isDark,
                          ),
                          const SizedBox(width: AppTheme.space12),
                          _deptMiniStat(
                            'Avg Score',
                            '$avgScore/100',
                            _scoreColor(avgScore),
                            isDark,
                          ),
                        ],
                      ),
                      if (topSkills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: topSkills
                              .map(
                                (s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: isDark ? 0.2 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    s,
                                    style: AppTheme.caption.copyWith(
                                      fontSize: 9,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _deptStat(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.space12,
          horizontal: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTheme.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.gray900,
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
      ),
    );
  }

  Widget _deptMiniStat(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Text(
            value,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: AppTheme.space4),
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
}

// =============================================================================
// 4. Placement Pipeline — REAL data only (v8.2 Phase 1)
// =============================================================================
class PlacementPipeline extends StatelessWidget {
  const PlacementPipeline({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();

    final totalStudents = analytics.pipelineTotalStudents > 0
        ? analytics.pipelineTotalStudents
        : (analytics.studentData?.length ?? 0);
    final totalApplied = analytics.pipelineApplied;
    // v9.1: real status-bucketed distinct-student counts — applications
    // carry a `status` field (applied | shortlisted | interviewed | placed |
    // rejected) written by `updateApplicationStatus`, and
    // `TeacherAnalyticsService.getApplicationPipelineCounts` buckets each
    // student at their highest reached stage. No more "Not tracked".
    final shortlisted = analytics.pipelineShortlisted;
    final interviewed = analytics.pipelineInterviewed;
    final placed = analytics.pipelinePlaced;
    final allPlacements = placements.placements;
    final activePlacements = allPlacements
        .where((p) => p.isActive && !p.isDeadlinePassed)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Placement Pipeline',
            isDark,
            icon: Icons.rocket_launch_outlined,
          ),
          const SizedBox(height: AppTheme.space16),
          if (totalStudents == 0)
            SizedBox(
              height: 100,
              child: Center(
              child: Text(
                'No placement data available',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _pipelineStep(
                    'Eligible',
                    '$totalStudents',
                    AppTheme.primaryBlue,
                    isDark,
                    subtitle: 'All students',
                  ),
                  _pipelineArrow(isDark),
                  _pipelineStep(
                    'Applied',
                    '$totalApplied',
                    AppTheme.secondaryIndigo,
                    isDark,
                    subtitle: totalApplied > 0
                        ? '$activePlacements active drives'
                        : 'Applications',
                  ),
                  _pipelineArrow(isDark),
                  _pipelineStep(
                    'Shortlisted',
                    '$shortlisted',
                    AppTheme.warning,
                    isDark,
                    subtitle: 'Shortlisted',
                  ),
                  _pipelineArrow(isDark),
                  _pipelineStep(
                    'Interview',
                    '$interviewed',
                    AppTheme.secondaryIndigo,
                    isDark,
                    subtitle: 'Interviewed',
                  ),
                  _pipelineArrow(isDark),
                  _pipelineStep(
                    'Placed',
                    '$placed',
                    AppTheme.success,
                    isDark,
                    subtitle: 'Placed',
                  ),
                ],
              ),
            ),
          if (totalApplied == 0 && totalStudents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space8),
              child: Text(
                'Applications collection is empty — pipeline will update as students apply.',
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pipelineStep(
    String label,
    String count,
    Color color,
    bool isDark, {
    String subtitle = '',
  }) {
    final isAvailable = count != 'N/A';
    final actualColor = isAvailable ? color : AppTheme.gray500;
    final bgOpacity = isAvailable ? (isDark ? 0.2 : 0.1) : 0.05;

    return Container(
      width: 90,
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: actualColor.withValues(alpha: bgOpacity),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: actualColor.withValues(alpha: 0.3)),
        boxShadow: isDark || !isAvailable
            ? null
            : [
                BoxShadow(
                  color: actualColor.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: actualColor,
              fontSize: isAvailable ? 16 : 14,
            ),
          ),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              fontSize: 9,
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: AppTheme.caption.copyWith(
                fontSize: 7,
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pipelineArrow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: isDark ? AppTheme.gray500 : AppTheme.gray400,
      ),
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
          _sectionHeader(
            'Resume Review Analytics',
            isDark,
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: _rrStat(
                  'Total',
                  '${analytics.totalReviews}',
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _rrStat(
                  'Average',
                  '${analytics.averageScore.round()}/100',
                  AppTheme.success,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _rrStat(
                  'Excellent',
                  '${analytics.excellentCount}',
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(
                child: _rrStat(
                  'Good',
                  '${analytics.goodCount}',
                  Colors.cyan,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _rrStat(
                  'Fair',
                  '${analytics.fairCount}',
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _rrStat(
                  'Poor',
                  '${analytics.poorCount}',
                  AppTheme.error,
                  isDark,
                ),
              ),
            ],
          ),
          if (reviews.history.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            Text(
              'Latest Reviews',
              style: AppTheme.label.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ...reviews.history
                .take(3)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _scoreColor(
                              r.atsScore,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            '${r.atsScore}',
                            style: AppTheme.caption.copyWith(
                              color: _scoreColor(r.atsScore),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Text(
                          r.strengths.isNotEmpty
                              ? r.strengths.first
                              : 'Review completed',
                          style: AppTheme.caption.copyWith(
                            color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
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
              fontSize: 10,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
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
          _sectionHeader(
            'Skill Gap Analysis',
            isDark,
            icon: Icons.psychology_outlined,
          ),
          const SizedBox(height: AppTheme.space16),
          ...gaps.take(6).map((g) {
            final skill = g['skill'] as String? ?? '';
            final count = g['count'] as int? ?? 0;
            final severity = g['severity'] as String? ?? 'medium';
            final color = severity == 'high'
                ? AppTheme.error
                : severity == 'medium'
                ? AppTheme.warning
                : AppTheme.success;
            final maxCount = gaps.fold<int>(
              0,
              (max, item) => (item['count'] as int? ?? 0) > max
                  ? (item['count'] as int? ?? 0)
                  : max,
            );
            final progress = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          skill,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : AppTheme.gray800,
                          ),
                        ),
                      ),
                      Text(
                        '$count',
                        style: AppTheme.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress.clamp(0.0, 1.0),
                      color: color,
                      backgroundColor: isDark
                          ? AppTheme.gray700
                          : AppTheme.gray200,
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

    final totalStudents = analytics.pipelineTotalStudents > 0
        ? analytics.pipelineTotalStudents
        : (analytics.studentData?.length ?? 0);
    final atRisk = analytics.atRiskCount;
    final highPotential = analytics.highPotentialCount;
    final avgScore = analytics.averageScore.round();
    final placementRate = analytics.predictedPlacementRate.round();

    final insights = <_Insight>[];

    if (atRisk > 0) {
      insights.add(
        _Insight(
          '$atRisk student${atRisk > 1 ? 's' : ''} need${atRisk == 1 ? 's' : ''} intervention',
          'Low ATS scores — prioritize mentorship and resume workshops',
          Icons.warning_amber_rounded,
          AppTheme.error,
        ),
      );
    }
    if (highPotential > 0) {
      insights.add(
        _Insight(
          '$highPotential high-potential student${highPotential > 1 ? 's' : ''}',
          'Ready for placement opportunities — encourage applications',
          Icons.emoji_events_outlined,
          AppTheme.success,
        ),
      );
    }
    if (avgScore > 65) {
      insights.add(
        _Insight(
          'Resume quality is strong',
          'Average score $avgScore/100 — above threshold',
          Icons.thumb_up_alt_outlined,
          AppTheme.success,
        ),
      );
    } else {
      insights.add(
        _Insight(
          'Resume quality needs improvement',
          'Average score $avgScore/100 — below 70 target',
          Icons.trending_down_rounded,
          AppTheme.warning,
        ),
      );
    }
    if (placementRate > 60) {
      insights.add(
        _Insight(
          'Placement readiness positive',
          'Predicted placement rate $placementRate%',
          Icons.insights_rounded,
          AppTheme.primaryBlue,
        ),
      );
    }
    if (totalStudents > 0 && placements.placements.isNotEmpty) {
      insights.add(
        _Insight(
          '${placements.placements.length} active placements',
          '${(placements.placements.where((p) => p.isActive && !p.isDeadlinePassed).length)} currently open',
          Icons.business_outlined,
          AppTheme.secondaryIndigo,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'AI Insights Overview',
            isDark,
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: AppTheme.space16),
          ...insights.map(
            (i) => Padding(
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
                        Text(
                          i.title,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                        ),
                        if (i.subtitle.isNotEmpty)
                          Text(
                            i.subtitle,
                            style: AppTheme.caption.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
// 8. At-Risk Students — Multi-signal detection (v8.2 Phase 5)
//
// Evaluates risk using only signals computable from available per-student data.
// We DO NOT check teacher-level properties like appliedPlacementIds or
// acceptedMentorshipsCount — those belong to the logged-in teacher, not students.
// =============================================================================
class AtRiskStudents extends StatelessWidget {
  const AtRiskStudents({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    // NOTE: placements and mentorship providers hold the TEACHER's own data,
    // not per-student data. Do NOT use them for per-student risk signals.

    if (!analytics.hasData || analytics.studentData == null) {
      return const SizedBox.shrink();
    }

    // Evaluate multi-signal risk for each student using only available per-student data
    final atRiskStudents = <Map<String, dynamic>>[];
    for (final s in analytics.studentData!) {
      final signals = <String>[];
      final score = s['latestScore'] as int? ?? 0;
      final reviewCount = s['reviewCount'] as int? ?? 0;

      // Signal 1: Low ATS (< 50)
      if (score < 50) signals.add('Low ATS score ($score/100)');

      // Signal 2: No resume reviews (indicates inactivity)
      if (reviewCount == 0) signals.add('No resume reviews');

      // Signal 3: Few reviews + weak score = low engagement
      if (reviewCount <= 1 && score < 60) signals.add('Limited engagement');

      // Signal 4: Score >= 50 but only 1 review (borderline engagement)
      if (reviewCount == 1 && score >= 50 && score < 70) {
        signals.add('Minimal activity');
      }

      // Note: Placement applications, mentorship status, and engagement score
      // require per-student subcollection queries (not available in dashboard).
      // A future enhancement could add these via TeacherAnalyticsService.

      // Only consider students with at least 1 signal
      if (signals.isNotEmpty) {
        // Determine priority
        String priority;
        String intervention;
        if (signals.length >= 3) {
          priority = 'URGENT';
          intervention =
              'Schedule one-on-one review, mandatory resume workshop, assign mentor';
        } else if (signals.length >= 2) {
          priority = 'MODERATE';
          intervention =
              'Recommend resume review and suggest mentorship sign-up';
        } else {
          priority = 'LOW';
          intervention =
              'Encourage resume improvement and application activity';
        }

        atRiskStudents.add({
          'studentName': s['studentName'] as String? ?? 'Unknown Student',
          'department': s['department'] as String? ?? 'Unknown',
          'latestScore': score,
          'reviewCount': reviewCount,
          'signals': signals,
          'priority': priority,
          'intervention': intervention,
        });
      }
    }

    // Sort by priority (URGENT first, then MODERATE, then LOW)
    atRiskStudents.sort((a, b) {
      const priorityOrder = {'URGENT': 0, 'MODERATE': 1, 'LOW': 2};
      final aOrder = priorityOrder[a['priority']] ?? 3;
      final bOrder = priorityOrder[b['priority']] ?? 3;
      return aOrder.compareTo(bOrder);
    });

    if (atRiskStudents.isEmpty) return const SizedBox.shrink();

    final displayCount = atRiskStudents.length > 5 ? 5 : atRiskStudents.length;
    final totalRiskCount = atRiskStudents.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppTheme.error,
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                'At-Risk Students',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$totalRiskCount',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          ...atRiskStudents.take(displayCount).map((s) {
            final name = s['studentName'] as String;
            final dept = s['department'] as String;
            final score = s['latestScore'] as int? ?? 0;
            final signals = s['signals'] as List<String>;
            final priority = s['priority'] as String;
            final intervention = s['intervention'] as String;

            final priorityColor = priority == 'URGENT'
                ? AppTheme.error
                : priority == 'MODERATE'
                ? AppTheme.warning
                : AppTheme.gray500;

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.space8),
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.gray800
                    : AppTheme.errorBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border(
                  left: BorderSide(color: priorityColor, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: name, size: 32),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.gray900,
                              ),
                            ),
                            Text(
                              dept,
                              style: AppTheme.caption.copyWith(
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          priority,
                          style: AppTheme.caption.copyWith(
                            color: priorityColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Row(
                    children: [
                      _riskChip('ATS', '$score', _scoreColor(score)),
                      const SizedBox(width: AppTheme.space8),
                      _riskChip(
                        'Reviews',
                        '${s['reviewCount']}',
                        AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  // Risk reasons
                  ...signals.map(
                    (signal) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 10,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              signal,
                              style: AppTheme.caption.copyWith(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.gray300
                                    : AppTheme.gray700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  // Suggested intervention
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 12,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            intervention,
                            style: AppTheme.caption.copyWith(
                              fontSize: 10,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (atRiskStudents.length > displayCount)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space4),
              child: Center(
                child: Text(
                  '+ ${atRiskStudents.length - displayCount} more at-risk students',
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _riskChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.caption.copyWith(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
    items.addAll(
      activityFeed.allActivities
          .take(5)
          .map((a) => _ActItem(a.title, a.description, a.icon, a.iconColor)),
    );

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
                  child: Center(
                    child: Text(
                      'No recent activities',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: items.map((a) => _activityItem(a, isDark)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _activityItem(_ActItem a, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
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
                Text(
                  a.title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  a.subtitle,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
// 10. Student Growth — Phase 6 (v8.2)
// =============================================================================
class StudentGrowth extends StatelessWidget {
  const StudentGrowth({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = context.watch<TeacherAnalyticsProvider>();
    final placements = context.watch<PlacementsProvider>();

    if (!analytics.hasData) return const SizedBox.shrink();

    // Compute growth metrics from performance trends
    final trends = analytics.performanceTrends ?? [];
    double avgAtsImprovement = 0;
    if (trends.length >= 2) {
      final first = trends.first['avgScore'] as int? ?? 0;
      final last = trends.last['avgScore'] as int? ?? 0;
      avgAtsImprovement = (last - first).toDouble();
    }

    // Profile improvement from engagement aggregates
    final profileImprovement = analytics.avgProfileStrength;
    final engagementScore = analytics.avgEngagement;

    // Applications growth — compare applied count vs total students
    final totalStudents = analytics.pipelineTotalStudents > 0
        ? analytics.pipelineTotalStudents
        : (analytics.studentData?.length ?? 0);
    final appliedCount = analytics.pipelineApplied;
    final applicationRate = totalStudents > 0
        ? ((appliedCount / totalStudents) * 100).round()
        : 0;

    // Placement growth — active placements
    final activePlacements = placements.placements
        .where((p) => p.isActive && !p.isDeadlinePassed)
        .length;
    final totalPlacements = placements.placements.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Student Growth',
            isDark,
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: AppTheme.space16),

          // Growth metrics in 2x2 grid
          Row(
            children: [
              Expanded(
                child: _growthTile(
                  'ATS Improvement',
                  trends.length >= 2
                      ? '${avgAtsImprovement > 0 ? '+' : ''}${avgAtsImprovement.round()} pts'
                      : 'N/A',
                  Icons.description_outlined,
                  avgAtsImprovement >= 0 ? AppTheme.success : AppTheme.warning,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _growthTile(
                  'Profile Strength',
                  '$profileImprovement/100',
                  Icons.shield_outlined,
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(
                child: _growthTile(
                  'Engagement',
                  '$engagementScore/100',
                  Icons.favorite_outline,
                  AppTheme.success,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _growthTile(
                  'Application Rate',
                  '$applicationRate%',
                  Icons.how_to_vote_outlined,
                  AppTheme.secondaryIndigo,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(
                child: _growthTile(
                  'Total Placements',
                  '$totalPlacements',
                  Icons.business_outlined,
                  AppTheme.warning,
                  isDark,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _growthTile(
                  'Active Drives',
                  '$activePlacements',
                  Icons.rocket_launch_outlined,
                  AppTheme.success,
                  isDark,
                ),
              ),
            ],
          ),

          // Monthly trend summary
          if (trends.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            Text(
              'Monthly ATS Trend',
              style: AppTheme.label.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ...trends.map((t) {
              final month = t['month'] as String? ?? '';
              final avgScore = t['avgScore'] as int? ?? 0;
              final count = t['reviewCount'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        month,
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: avgScore / 100.0,
                          color: _scoreColor(avgScore),
                          backgroundColor: isDark
                              ? AppTheme.gray700
                              : AppTheme.gray200,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      '$avgScore',
                      style: AppTheme.caption.copyWith(
                        color: _scoreColor(avgScore),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Text(
                      '($count)',
                      style: AppTheme.caption.copyWith(
                        color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _growthTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 10,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 11. Quick Actions
// =============================================================================
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = <_QAction>[
      _QAction(
        'Review Resume',
        Icons.description_outlined,
        AppTheme.primaryBlue,
        resumeReviewRoute,
      ),
      _QAction(
        'Student Analytics',
        Icons.analytics_outlined,
        AppTheme.success,
        studentAnalyticsRoute,
      ),
      _QAction(
        'Placement Reports',
        Icons.assessment_outlined,
        AppTheme.secondaryIndigo,
        placementsListRoute,
      ),
      _QAction(
        'Skill Gap',
        Icons.psychology_outlined,
        AppTheme.warning,
        studentAnalyticsRoute,
      ),
      _QAction(
        'AI Insights',
        Icons.auto_awesome,
        const Color(0xFF7C3AED),
        '',
      ), // Switches to tab 3
      _QAction(
        'Announcements',
        Icons.campaign_outlined,
        AppTheme.error,
        notificationsRoute,
      ),
      _QAction(
        'Export Report',
        Icons.download_outlined,
        Colors.teal,
        studentAnalyticsRoute,
      ),
      _QAction(
        'Manage Opps',
        Icons.work_outline,
        AppTheme.primaryBlue,
        opportunitiesRoute,
      ),
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      a.label,
                      style: AppTheme.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
