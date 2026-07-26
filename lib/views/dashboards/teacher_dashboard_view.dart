import 'package:campusconnect/constants/routes.dart';
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
import 'package:campusconnect/views/dashboards/widgets/teacher_dashboard_sections.dart';
import 'package:campusconnect/views/dashboards/widgets/teacher_ai_insights_tab.dart';
import 'package:campusconnect/views/placements/placements_list_view.dart';
import 'package:campusconnect/views/profile/profile_view.dart' as extracted_profile;
import 'package:campusconnect/views/shared/main_navigation_view.dart';
import 'package:campusconnect/views/teacher/student_analytics_view.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// TeacherDashboardView — v8.1: Modernized with MainNavigationView
///
/// 5 tabs:
/// 0. Dashboard — comprehensive analytics with 10 sections
/// 1. Students — reuse StudentAnalyticsView
/// 2. Placements — reuse PlacementsListView
/// 3. AI Insights — dedicated analytics dashboard (NOT an AI chat)
/// 4. Profile — reuse extracted_profile.ProfileView
class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationView(
      tabs: [
        TabConfig(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          widget: const _TeacherDashboardTab(),
        ),
        TabConfig(
          label: 'Students',
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          widget: const StudentAnalyticsView(),
        ),
        TabConfig(
          label: 'Placements',
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          widget: const PlacementsListView(),
        ),
        TabConfig(
          label: 'AI Insights',
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome,
          widget: const AIInsightsTab(),
        ),
        TabConfig(
          label: 'Profile',
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          widget: const extracted_profile.ProfileView(),
        ),
      ],
    );
  }
}

/// Dashboard tab — 10 sections: Welcome, Quick Stats, Dept Overview,
/// Placement Pipeline, Resume Analytics, Skill Gap, AI Insights,
/// At-Risk Students, Recent Activity, Quick Actions.
class _TeacherDashboardTab extends StatefulWidget {
  const _TeacherDashboardTab();

  @override
  State<_TeacherDashboardTab> createState() => _TeacherDashboardTabState();
}

class _TeacherDashboardTabState extends State<_TeacherDashboardTab> {
  int _loadRetryCount = 0;
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 4);
  bool _historyRefreshed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAll(firstLoad: true);
    });
  }

  Future<void> _loadAll({bool firstLoad = false}) async {
    await context.read<TeacherAnalyticsProvider>().loadAnalytics();
    await context.read<PlacementsProvider>().refresh();
    // Only refresh resume history on the first attempt — retries skip
    // it since the provider already has the data cached.
    if (firstLoad || !_historyRefreshed) {
      _historyRefreshed = true;
      await context.read<ResumeReviewProvider>().refreshHistory();
    }
    _checkAndRetry();
  }

  void _checkAndRetry() {
    if (_loadRetryCount >= _maxRetries) return;
    if (!mounted) return;

    final analytics = context.read<TeacherAnalyticsProvider>();
    // Retry if we got zero students on the first load — indicates Firestore
    // connection wasn't fully established yet (common on first login).
    final isEmpty = (analytics.pipelineTotalStudents == 0) &&
        (analytics.studentData == null || analytics.studentData!.isEmpty) &&
        !analytics.isLoading;
    if (isEmpty) {
      _loadRetryCount++;
      Future.delayed(_retryDelay, () {
        if (!mounted) return;
        _loadAll();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildAppBar(context, isDark),
        Expanded(
          child: RefreshIndicator(
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
                  // 1. Welcome Header
                  const WelcomeHeader(),
                  const SizedBox(height: AppTheme.space24),

                  // 2. Quick Statistics (8 metrics)
                  const QuickStatistics(),
                  const SizedBox(height: AppTheme.space24),

                  // 3. Department Overview
                  const DepartmentOverview(),
                  const SizedBox(height: AppTheme.space20),

                  // 4. Placement Pipeline
                  const PlacementPipeline(),
                  const SizedBox(height: AppTheme.space20),

                  // 5. Resume Review Analytics
                  const ResumeReviewAnalytics(),
                  const SizedBox(height: AppTheme.space20),

                  // 6. Skill Gap Analysis
                  const SkillGapAnalysis(),
                  const SizedBox(height: AppTheme.space20),

                  // 7. AI Insights Overview
                  const AIInsightsOverview(),
                  const SizedBox(height: AppTheme.space20),

                  // 8. At-Risk Students
                  const AtRiskStudents(),
                  const SizedBox(height: AppTheme.space24),

                  // 9. Student Growth (v8.2 Phase 6)
                  const StudentGrowth(),
                  const SizedBox(height: AppTheme.space24),

                  // 10. Recent Activity
                  const RecentActivity(),
                  const SizedBox(height: AppTheme.space24),

                  // 11. Quick Actions
                  const QuickActionsGrid(),
                  const SizedBox(height: AppTheme.space32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
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
          Icon(Icons.school, color: isDark ? Colors.white : AppTheme.gray900, size: 24),
          const SizedBox(width: AppTheme.space8),
          Text(
            'Dashboard',
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
