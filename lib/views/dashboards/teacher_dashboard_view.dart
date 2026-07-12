import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

/// v7.5: Modernized Teacher Dashboard with analytics, charts, and alerts.
///
/// Designed to match the Student Dashboard quality, spacing, responsiveness,
/// animations and architecture while being tailored for faculty needs.
class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, color: isDark ? Colors.white : AppTheme.gray900, size: 24),
            const SizedBox(width: 8),
            Text(
              'Teacher Dashboard',
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? AppTheme.gray400 : AppTheme.gray700),
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(context, profileViewRoute);
                  break;
                case 'settings':
                  Navigator.pushNamed(context, settingsRoute);
                  break;
                case 'logout':
                  final shouldLogout = await _showLogOutDialog(context);
                  if (shouldLogout && context.mounted) {
                    _resetProviders(context);
                    try {
                      await AuthService.firebase().logOut();
                    } catch (_) {}
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline, size: 20, color: isDark ? AppTheme.gray400 : null),
                  title: Text('Profile', style: TextStyle(color: isDark ? Colors.white : null)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined, size: 20, color: isDark ? AppTheme.gray400 : null),
                  title: Text('Settings', style: TextStyle(color: isDark ? Colors.white : null)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Log out'),
              ),
            ],
          ),
        ],
      ),
      body: _TeacherDashboardBody(),
    );
  }

  void _resetProviders(BuildContext context) {
    context.read<ProfileProvider>().reset();
    context.read<PlacementsProvider>().reset();
    context.read<AIUsageProvider>().reset();
    context.read<NotificationsProvider>().reset();
    context.read<ResumeReviewProvider>().reset();
    context.read<RoleProvider>().reset();
    context.read<MentorshipProvider>().reset();
    context.read<OpportunityProvider>().reset();
    context.read<AlumniDirectoryProvider>().reset();
    context.read<RecommendationProvider>().reset();
    context.read<EngagementProvider>().reset();
    context.read<AIChatProvider>().reset();
    context.read<ActivityFeedProvider>().reset();
    context.read<TeacherAnalyticsProvider>().reset();
    context.read<ChatProvider>().reset();
  }

  Future<bool> _showLogOutDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum MenuAction { logout }

class _TeacherDashboardBody extends StatefulWidget {
  @override
  State<_TeacherDashboardBody> createState() => _TeacherDashboardBodyState();
}

class _TeacherDashboardBodyState extends State<_TeacherDashboardBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeacherAnalyticsProvider>().loadAnalytics();
      context.read<PlacementsProvider>().refresh();
      context.read<ResumeReviewProvider>().refreshHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final analytics = context.watch<TeacherAnalyticsProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<TeacherAnalyticsProvider>().loadAnalytics();
        await context.read<PlacementsProvider>().refresh();
        await context.read<ResumeReviewProvider>().refreshHistory();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context, profile, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildAnalyticsCards(context, analytics, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildChartsSection(context, analytics, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildAlertsSection(context, analytics, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildAcademicTools(context, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildRecentActivities(context, isDark),
            const SizedBox(height: AppTheme.space24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, StudentProfile? profile, bool isDark) {
    final name = profile?.personal.effectiveDisplayName ?? 'Professor';
    final department = profile?.department ?? 'Computer Science';
    final placementsProvider = context.watch<PlacementsProvider>();
    final totalPlacements = placementsProvider.placements.length;
    final activePlacements = placementsProvider.placements
        .where((p) => p.isActive && !p.isDeadlinePassed)
        .length;
    final placementRate = totalPlacements > 0 ? (activePlacements / totalPlacements * 100) : 0;

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
                    Text('Welcome, $name',
                        style: AppTheme.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.space4),
                    Text(profile?.designation ?? 'Faculty',
                        style: AppTheme.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          Row(
            children: [
              _heroStat(department, 'Department', Icons.science_outlined),
              const SizedBox(width: AppTheme.space12),
              _heroStat(totalPlacements.toString(), 'Total Drives', Icons.business_outlined),
              const SizedBox(width: AppTheme.space12),
              _heroStat('${placementRate.toStringAsFixed(0)}%', 'Placement Rate', Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: AppTheme.space4),
            Text(value,
                style: AppTheme.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            Text(label,
                style: AppTheme.caption.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards(BuildContext context, TeacherAnalyticsProvider analytics, bool isDark) {
    if (analytics.isLoading && !analytics.hasData) {
      return SizedBox(
        height: 100,
        child: Row(
          children: List.generate(4, (_) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SkeletonLoader(height: 100, borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          )),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Analytics Overview',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(child: _buildAnalyticCard('Students', analytics.studentData?.length.toString() ?? '0', Icons.people_outline, AppTheme.primaryBlue, isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _buildAnalyticCard('Resume Reviews', analytics.totalReviews.toString(), Icons.description_outlined, AppTheme.success, isDark)),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(child: _buildAnalyticCard('Avg Score', '${analytics.averageScore.round()}/100', Icons.star_outline, AppTheme.warning, isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _buildAnalyticCard('Placement Ready', '${analytics.predictedPlacementRate.round()}%', Icons.check_circle_outline, AppTheme.secondaryIndigo, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.gray900)),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(title, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
        ],
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context, TeacherAnalyticsProvider analytics, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Analytics & Charts',
                style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
            const SizedBox(width: AppTheme.space8),
            Icon(Icons.bar_chart_rounded, size: 18, color: AppTheme.primaryBlue),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        if (analytics.hasData && analytics.totalReviews > 0)
          _buildChartCard('Resume Score Distribution',
              SizedBox(height: 200, child: _ResumeScorePieChart(analytics: analytics, isDark: isDark)), isDark),
        if (analytics.hasData && analytics.totalReviews > 0) const SizedBox(height: AppTheme.space12),
        if (analytics.skillGapAnalysis != null && analytics.skillGapAnalysis!.isNotEmpty)
          _buildChartCard('Skill Gap Summary', _buildSkillGapBars(analytics, isDark), isDark),
        if (analytics.skillGapAnalysis != null && analytics.skillGapAnalysis!.isNotEmpty) const SizedBox(height: AppTheme.space12),
        _buildChartCard('Placement Pipeline', _buildPlacementPipelineChart(context, isDark), isDark),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
          const SizedBox(height: AppTheme.space16),
          chart,
        ],
      ),
    );
  }

  Widget _buildPlacementPipelineChart(BuildContext context, bool isDark) {
    final placementsProvider = context.watch<PlacementsProvider>();
    final placements = placementsProvider.placements;

    if (placements.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text('No placement data yet',
              style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
        ),
      );
    }

    final now = DateTime.now();
    final active = placements.where((p) => p.isActive && !p.isDeadlinePassed).length;
    final expired = placements.where((p) => p.isDeadlinePassed || !p.isActive).length;
    final upcoming = placements.where((p) => p.isActive && !p.isDeadlinePassed && p.deadline.difference(now).inDays > 7).length;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: placements.length.toDouble() + 1,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = ['Active', 'Expired', 'Upcoming'];
                  if (value >= 0 && value < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(labels[value.toInt()],
                          style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: active.toDouble(), color: AppTheme.success, width: 28, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expired.toDouble(), color: AppTheme.error, width: 28, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: upcoming.toDouble(), color: AppTheme.primaryBlue, width: 28, borderRadius: BorderRadius.circular(4))]),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillGapBars(TeacherAnalyticsProvider analytics, bool isDark) {
    final gaps = analytics.skillGapAnalysis ?? [];
    if (gaps.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text('No skill gap data',
              style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
        ),
      );
    }

    return Column(
      children: gaps.take(5).map((gap) {
        final skill = gap['skill'] as String? ?? '';
        final count = gap['count'] as int? ?? 0;
        final severity = gap['severity'] as String? ?? 'low';
        final color = severity == 'high' ? AppTheme.error : severity == 'medium' ? AppTheme.warning : AppTheme.success;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(skill, style: AppTheme.bodySmall.copyWith(color: isDark ? Colors.white : AppTheme.gray800, fontWeight: FontWeight.w500)),
                  Text('$count', style: AppTheme.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppTheme.space4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (count / 50.0).clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertsSection(BuildContext context, TeacherAnalyticsProvider analytics, bool isDark) {
    if (!analytics.hasData) return const SizedBox.shrink();

    final alerts = <_AlertItem>[];
    if (analytics.atRiskCount > 0) {
      alerts.add(_AlertItem('${analytics.atRiskCount} at-risk students', 'Students needing placement support', Icons.warning_amber_rounded, AppTheme.error));
    }
    if (analytics.poorCount > 0) {
      alerts.add(_AlertItem('${analytics.poorCount} low resume scores', 'Scores below 40, need improvement', Icons.assignment_late_rounded, AppTheme.warning));
    }
    if (analytics.highPotentialCount > 0) {
      alerts.add(_AlertItem('${analytics.highPotentialCount} high potential', 'Ready for placement opportunities', Icons.trending_up_rounded, AppTheme.success));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Alerts & Insights',
                style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
            const SizedBox(width: AppTheme.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Text('${alerts.length}',
                  style: AppTheme.caption.copyWith(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        ...alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space8),
              child: _buildAlertCard(alert, isDark),
            )),
      ],
    );
  }

  Widget _buildAlertCard(_AlertItem alert, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: alert.color.withValues(alpha: 0.3)),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(alert.icon, color: alert.color, size: 22),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
                const SizedBox(height: AppTheme.space4),
                Text(alert.subtitle,
                    style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: isDark ? AppTheme.gray500 : AppTheme.gray400, size: 20),
        ],
      ),
    );
  }

  Widget _buildAcademicTools(BuildContext context, bool isDark) {
    final tools = [
      _ToolItem('Analytics', Icons.analytics_outlined, AppTheme.primaryBlue, studentAnalyticsRoute),
      _ToolItem('Students', Icons.people_outline, AppTheme.success, studentAnalyticsRoute),
      _ToolItem('Resume Reviews', Icons.description_outlined, AppTheme.warning, resumeReviewRoute),
      _ToolItem('Profile', Icons.person_outline, AppTheme.secondaryIndigo, profileViewRoute),
      _ToolItem('Notes', Icons.note_add_outlined, AppTheme.primaryBlue, teacherNotesRoute),
      _ToolItem('Notifications', Icons.notifications_outlined, AppTheme.error, notificationsRoute),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Academic Tools',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
        const SizedBox(height: AppTheme.space16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppTheme.space12,
            mainAxisSpacing: AppTheme.space12,
            childAspectRatio: 0.85,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _buildToolCard(context, tool, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, _ToolItem tool, bool isDark) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, tool.route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          boxShadow: AppTheme.shadowSmall,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(tool.icon, color: tool.color, size: 22),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(tool.title,
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray800),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context, bool isDark) {
    final activityFeed = context.watch<ActivityFeedProvider>();
    final reviewsProvider = context.watch<ResumeReviewProvider>();
    final activities = <_ActivityItem>[
      if (reviewsProvider.history.isNotEmpty)
        _ActivityItem('${reviewsProvider.history.length} resume reviews completed',
            'Last: ${reviewsProvider.history.first.atsScore}/100', Icons.description_outlined, AppTheme.success),
      ...activityFeed.allActivities.take(5).map((a) => _ActivityItem(a.title, a.description, a.icon, a.iconColor)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activities',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
        const SizedBox(height: AppTheme.space16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
            boxShadow: AppTheme.shadowSmall,
          ),
          child: activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  child: Center(
                    child: Text('No recent activities',
                        style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                  ),
                )
              : Column(children: activities.map((a) => _buildActivityItem(context, a, isDark)).toList()),
        ),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, _ActivityItem activity, bool isDark) {
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
              color: activity.color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(activity.icon, color: activity.color, size: 18),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppTheme.space4),
                Text(activity.subtitle,
                    style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeScorePieChart extends StatelessWidget {
  final TeacherAnalyticsProvider analytics;
  final bool isDark;
  const _ResumeScorePieChart({required this.analytics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = analytics.totalReviews;
    if (total == 0) return const SizedBox.shrink();

    final excellentPct = analytics.excellentCount / total * 100;
    final goodPct = analytics.goodCount / total * 100;
    final fairPct = analytics.fairCount / total * 100;
    final poorPct = analytics.poorCount / total * 100;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(color: const Color(0xFF059669), value: excellentPct, title: '${analytics.excellentCount}', radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                PieChartSectionData(color: const Color(0xFF0891B2), value: goodPct, title: '${analytics.goodCount}', radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                PieChartSectionData(color: const Color(0xFFEA580C), value: fairPct, title: '${analytics.fairCount}', radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                PieChartSectionData(color: const Color(0xFFDC2626), value: poorPct, title: '${analytics.poorCount}', radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendItem('Excellent (80+)', analytics.excellentCount, const Color(0xFF059669), isDark),
              const SizedBox(height: AppTheme.space8),
              _legendItem('Good (60-79)', analytics.goodCount, const Color(0xFF0891B2), isDark),
              const SizedBox(height: AppTheme.space8),
              _legendItem('Fair (40-59)', analytics.fairCount, const Color(0xFFEA580C), isDark),
              const SizedBox(height: AppTheme.space8),
              _legendItem('Poor (<40)', analytics.poorCount, const Color(0xFFDC2626), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String label, int count, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: AppTheme.space8),
        Expanded(child: Text(label, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray300 : AppTheme.gray700, fontSize: 10))),
        Text('$count', style: AppTheme.caption.copyWith(color: isDark ? Colors.white : AppTheme.gray900, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AlertItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _AlertItem(this.title, this.subtitle, this.icon, this.color);
}

class _ToolItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  _ToolItem(this.title, this.icon, this.color, this.route);
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _ActivityItem(this.title, this.subtitle, this.icon, this.color);
}
