import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/activity_item.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/models/recommendation.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/providers/alumni_group_chat_provider.dart'; // v8.7
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/portfolio_provider.dart'; // v8.4
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/eligibility_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/widgets/home_widgets.dart';
import 'package:campusconnect/widgets/resume_summary_card.dart'; // v8.4.1
// v7.3: Extracted feature views (Phase 1 NotesView decomposition)
import 'package:campusconnect/views/notes/notes_list_view.dart';
import 'package:campusconnect/views/placements/placements_list_view.dart';
import 'package:campusconnect/views/chat/ai_chat_view.dart';
import 'package:campusconnect/views/profile/profile_view.dart'
    as extracted_profile;
import 'package:campusconnect/views/shared/main_navigation_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Menu action enum for popup menu
enum MenuAction { logout }

/// v7.3: Student dashboard - transformed to use extracted feature views with tabbed navigation
///
/// Replaces the legacy monolithic NotesView with clean architecture:
/// - Uses MainNavigationView for consistent tabbed navigation
/// - Routes to extracted feature views instead of embedded widgets
/// - Maintains the same user experience with improved maintainability
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationView(
      tabs: [
        TabConfig(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          widget: _StudentDashboardTab(),
        ),
        TabConfig(
          label: 'Notes',
          icon: Icons.note_outlined,
          activeIcon: Icons.note,
          widget: const NotesListView(),
        ),
        TabConfig(
          label: 'Placements',
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          widget: const PlacementsListView(),
        ),
        TabConfig(
          label: 'AI Chat',
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          widget: const AIChatView(),
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

/// v7.3: Activity feed dashboard tab - matches original NotesView design
///
/// Displays:
/// - Welcome header with date
/// - Featured event card
/// - Today/This Week activity timeline
/// - Connect & Grow 2x2 feature grid
/// - Latest Placements section
class _StudentDashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activityFeed = context.watch<ActivityFeedProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school,
              color: isDark ? Colors.white : AppTheme.gray900,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Student Dashboard',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
          ],
        ),
        actions: [
          // V6.4: Notification badge
          NotificationBadge(
            onTap: () => Navigator.pushNamed(context, notificationsRoute),
          ),
          // v7.3: Chat badge
          ChatBadge(),
          // Popup menu with logout
          PopupMenuButton<MenuAction>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? AppTheme.gray400 : AppTheme.gray700,
            ),
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await _showLogOutDialog(context);
                  if (shouldLogout && context.mounted) {
                    // CRITICAL: Reset ALL stream-based providers BEFORE logout
                    // to prevent Firestore permission errors from triggering
                    // notifyListeners() during AuthGuard's rebuild cycle.
                    context.read<ProfileProvider>().reset();
                    context.read<PlacementsProvider>().reset();
                    context.read<AIUsageProvider>().reset();
                    context.read<ActivityFeedProvider>().reset();
                    context.read<RecommendationProvider>().reset();
                    context.read<EngagementProvider>().reset();
                    context.read<AIChatProvider>().reset();
                    context.read<ChatProvider>().reset();    // Has active Firestore stream subscriptions
                    context.read<NotificationsProvider>().reset(); // Has active Firestore stream
                    context.read<RoleProvider>().reset();
                    context.read<ResumeReviewProvider>().reset();
                    context.read<MentorshipProvider>().reset();
                    context.read<OpportunityProvider>().reset();
                    context.read<AlumniDirectoryProvider>().reset();
                    context.read<TeacherAnalyticsProvider>().reset();
                    context.read<PortfolioProvider>().reset(); // v8.4
                    context.read<AlumniGroupChatProvider>().reset(); // v8.7
                    try {
                      await AuthService.firebase().logOut();
                    } catch (_) {
                      // AuthGuard will handle the state
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<MenuAction>(
                  value: MenuAction.logout,
                  child: Text('Log out'),
                ),
              ];
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        // v8.4.3 (MB1): pull-to-refresh now reloads the portfolio instead of
        // the previous no-op delay — fixes stale resume/summary state after
        // an upload edit (Bugs 1/3).
        onRefresh: () => context.read<PortfolioProvider>().refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Text(
                'Welcome back!',
                style: AppTheme.titleLarge.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d/M/yyyy').format(DateTime.now()),
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
              const SizedBox(height: 20),

              // v8.4.1 (T4): Resume portfolio summary card
              // v8.4.8 (MB15): pass provider.error into the card so a failed
              // load surfaces a banner on the dashboard instead of silently
              // masquerading as a fresh (empty) portfolio — Symptom 1's UI.
              Consumer<PortfolioProvider>(
                builder: (context, portfolioProvider, child) {
                  return ResumeSummaryCard(
                    resume: portfolioProvider.portfolio?.resume,
                    error: portfolioProvider.error,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Featured Event Card
              const FeaturedCard(),
              const SizedBox(height: 24),

              // Today / This Week Section
              _buildTodaySection(context, activityFeed, isDark),
              const SizedBox(height: 24),

              // Connect & Grow Section
              _buildConnectAndGrowSection(context, isDark),
              const SizedBox(height: 24),

              // v7.4: AI recommendations
              _buildAIPicksSection(context, isDark),
              const SizedBox(height: 24),

              // v7.4: Engagement and profile strength
              _buildEngagementSection(context, isDark),
              const SizedBox(height: 24),

              // Latest Placements Section
              Text(
                'Latest Placements',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 16),
              _buildLatestPlacements(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySection(
    BuildContext context,
    ActivityFeedProvider activityFeed,
    bool isDark,
  ) {
    final allActivities = [
      ...activityFeed.todayActivities,
      ...activityFeed.thisWeekActivities,
    ].take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today / This Week',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              // Dynamic activities from ActivityFeedProvider
              if (allActivities.isNotEmpty) ...[
                for (int i = 0; i < allActivities.length; i++) ...[
                  _buildTodayItem(
                    context: context,
                    activity: allActivities[i],
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                ],
              ],
              // Static shortcut: AI Chat
              _buildStaticTodayItem(
                context: context,
                icon: Icons.chat_bubble,
                iconColor: const Color(0xFF7C3AED),
                title: 'Ask CampusConnect AI for guidance',
                subtitle: 'Get help with your career',
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, aiChatRoute),
              ),
              _buildDivider(isDark),
              // Static shortcut: AI Resume Review
              _buildStaticTodayItem(
                context: context,
                icon: Icons.auto_awesome,
                iconColor: AppTheme.success,
                title: 'AI Resume Review',
                subtitle: 'Get ATS score & improvement tips',
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, resumeReviewRoute),
              ),
              _buildDivider(isDark),
              // v8.4: Static shortcut: My Portfolio
              _buildStaticTodayItem(
                context: context,
                icon: Icons.workspace_premium_outlined,
                iconColor: AppTheme.primaryBlue,
                title: 'My Portfolio',
                subtitle: 'Build & view your professional portfolio',
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, studentPortfolioRoute),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: isDark ? AppTheme.gray700 : AppTheme.gray200,
    );
  }

  Widget _buildStaticTodayItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(isDark ? 51 : 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.gray400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayItem({
    required BuildContext context,
    required ActivityItem activity,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => _handleActivityTap(context, activity),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activity.iconColor.withAlpha(isDark ? 51 : 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(activity.icon, color: activity.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.gray400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectAndGrowSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect & Grow',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 16),
        // First row
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                context: context,
                title: 'Alumni Directory',
                subtitle: 'Connect with alumni',
                icon: Icons.people,
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, alumniDirectoryRoute),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(
                context: context,
                title: 'Mentorships',
                subtitle: 'Request mentorship',
                icon: Icons.school,
                isDark: isDark,
                onTap: () =>
                    Navigator.pushNamed(context, mentorshipRequestsRoute),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                context: context,
                title: 'Job Opportunities',
                subtitle: 'Explore career paths',
                icon: Icons.work,
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, opportunitiesRoute),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(
                context: context,
                title: 'AI Career Chat',
                subtitle: 'Get career insights',
                icon: Icons.psychology,
                isDark: isDark,
                onTap: () {
                  // Navigate to AI Chat route
                  Navigator.pushNamed(context, aiChatRoute);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(77)
                  : Colors.black.withAlpha(20),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIPicksSection(BuildContext context, bool isDark) {
    return Consumer<RecommendationProvider>(
      builder: (context, recommendationProvider, child) {
        final picks = recommendationProvider.recommendations.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'AI Smart Picks',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppTheme.secondaryIndigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recommendationProvider.isLoading &&
                recommendationProvider.recommendations.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (picks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                  ),
                ),
                child: Text(
                  'Complete your profile and stay active to unlock personalized mentor and job recommendations.',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              )
            else
              Column(
                children: picks
                    .map(
                      (recommendation) => _buildRecommendationCard(
                        context,
                        recommendation,
                        isDark,
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    Recommendation recommendation,
    bool isDark,
  ) {
    final scoreColor = recommendation.score >= 75
        ? AppTheme.success
        : AppTheme.primaryBlue;

    return InkWell(
      onTap: () async {
        await context.read<RecommendationProvider>().markInteracted(
          recommendation.id,
        );
        if (!context.mounted) return;
        switch (recommendation.type) {
          case RecommendationType.mentor:
          case RecommendationType.mentorship:
            Navigator.pushNamed(context, mentorshipRequestsRoute);
            break;
          case RecommendationType.job:
            Navigator.pushNamed(context, opportunitiesRoute);
            break;
          case RecommendationType.chat:
            Navigator.pushNamed(context, aiChatRoute);
            break;
          case RecommendationType.skill:
            Navigator.pushNamed(context, profileSetupRoute);
            break;
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(isDark ? 46 : 24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _recommendationIcon(recommendation.type),
                color: scoreColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recommendation.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${recommendation.score.round()}%',
                style: AppTheme.caption.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _recommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.mentor:
      case RecommendationType.mentorship:
        return Icons.groups_rounded;
      case RecommendationType.job:
        return Icons.work_outline_rounded;
      case RecommendationType.chat:
        return Icons.chat_bubble_outline_rounded;
      case RecommendationType.skill:
        return Icons.lightbulb_outline_rounded;
    }
  }

  Widget _buildEngagementSection(BuildContext context, bool isDark) {
    return Consumer<EngagementProvider>(
      builder: (context, engagementProvider, child) {
        final profileStrength = engagementProvider.profileStrength;
        final score = engagementProvider.engagementScore;
        final streak = engagementProvider.dailyStreak;
        final badges = engagementProvider.badges.take(2).toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Engagement',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 18,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricProgress(
                label: 'Profile Strength',
                value: profileStrength,
                color: AppTheme.primaryBlue,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildMetricProgress(
                label: 'Engagement Score',
                value: score,
                color: AppTheme.success,
                isDark: isDark,
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges
                      .map(
                        (badge) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryIndigo.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.secondaryIndigo.withAlpha(35),
                            ),
                          ),
                          child: Text(
                            badge.title,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.secondaryIndigo,
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
        );
      },
    );
  }

  Widget _buildMetricProgress({
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    final clamped = value.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const Spacer(),
            Text(
              '$clamped%',
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: clamped / 100,
            color: color,
            backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
      ],
    );
  }

  Widget _buildLatestPlacements(BuildContext context, bool isDark) {
    return Consumer<PlacementsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && !provider.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(child: Text('Error: ${provider.error}'));
        }

        final placements = provider.sortedPlacements;
        if (placements.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No placements available',
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                ),
              ),
            ),
          );
        }

        return Column(
          children: placements.take(2).map((placement) {
            final eligibility = provider.getEligibility(placement.id);
            return _buildPlacementCard(context, placement, eligibility, isDark);
          }).toList(),
        );
      },
    );
  }

  Widget _buildPlacementCard(
    BuildContext context,
    Placement placement,
    PlacementEligibility? eligibility,
    bool isDark,
  ) {
    final placementsProvider = context.read<PlacementsProvider>();
    final hasApplied = placementsProvider.hasApplied(placement.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkSurface, AppTheme.primaryBlue.withAlpha(13)]
              : [Colors.white, AppTheme.primaryBlue.withAlpha(5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placement.company,
                        style: AppTheme.titleMedium.copyWith(
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        placement.role,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: placement.isDeadlinePassed
                            ? AppTheme.errorBg
                            : AppTheme.successBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: placement.isDeadlinePassed
                              ? AppTheme.error.withAlpha(77)
                              : AppTheme.success.withAlpha(77),
                        ),
                      ),
                      child: Text(
                        placement.isDeadlinePassed ? 'Closed' : 'Open',
                        style: AppTheme.label.copyWith(
                          color: placement.isDeadlinePassed
                              ? AppTheme.error
                              : AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    // Eligibility badge
                    if (eligibility != null && !placement.isDeadlinePassed) ...[
                      const SizedBox(height: 8),
                      EligibilityBadge(eligibility: eligibility, compact: true),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              placement.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 14,
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          placement.salary,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Deadline: ${DateFormat('MMM d, yyyy').format(placement.deadline)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Apply button
                if (!placement.isDeadlinePassed)
                  ElevatedButton(
                    onPressed: hasApplied
                        ? null
                        : () => _showApplyDialog(context, placement),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasApplied
                          ? AppTheme.gray400
                          : AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(hasApplied ? 'Applied' : 'Apply'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApplyDialog(BuildContext context, Placement placement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply to ${placement.company}'),
        content: Text(
          'View placement details to submit your application for ${placement.role}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to placements list where user can view details and apply
              Navigator.pushNamed(context, placementsListRoute);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _handleActivityTap(BuildContext context, ActivityItem activity) {
    final actionData = activity.actionData;
    if (actionData == null) return;

    switch (activity.type) {
      case ActivityType.notification:
      case ActivityType.announcement:
        Navigator.pushNamed(context, notificationsRoute);
        break;
      case ActivityType.chatMessage:
        if (actionData['chatId'] != null) {
          Navigator.pushNamed(
            context,
            chatDetailRoute,
            arguments: actionData['chatId'],
          );
        }
        break;
      case ActivityType.mentorshipUpdate:
        Navigator.pushNamed(context, mentorshipRequestsRoute);
        break;
      case ActivityType.newOpportunity:
        Navigator.pushNamed(context, opportunitiesRoute);
        break;
      case ActivityType.placementApplication:
        Navigator.pushNamed(context, placementsListRoute);
        break;
    }
  }

  Future<bool> _showLogOutDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
