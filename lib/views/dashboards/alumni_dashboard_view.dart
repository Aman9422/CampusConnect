import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/recommendation.dart';
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
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/views/mentorship/mentorship_requests_view.dart';
import 'package:campusconnect/views/opportunities/opportunities_view.dart';
import 'package:campusconnect/views/chat/ai_chat_view.dart';
import 'package:campusconnect/views/profile/profile_view.dart' as extracted_profile;
import 'package:campusconnect/views/shared/main_navigation_view.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// AlumniDashboardView — v7.5: Professional tabbed dashboard for alumni.
///
/// 5 tabs:
/// 0. Dashboard — clean professional overview with activity feed, key metrics, AI picks
/// 1. Mentorship — reuse MentorshipRequestsView
/// 2. Opportunities — reuse OpportunitiesView
/// 3. AI Chat — reuse AIChatView
/// 4. Profile — reuse extracted_profile.ProfileView
class AlumniDashboardView extends StatelessWidget {
  const AlumniDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationView(
      tabs: [
        TabConfig(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          widget: const _AlumniDashboardTab(),
        ),
        TabConfig(
          label: 'Mentorship',
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          widget: const MentorshipRequestsView(),
        ),
        TabConfig(
          label: 'Opportunities',
          icon: Icons.work_outline,
          activeIcon: Icons.work,
          widget: const OpportunitiesView(),
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

/// Dashboard tab body — clean, professional layout with compact metrics, activity,
/// AI picks, and quick actions. No overlapping or redundant sections.
class _AlumniDashboardTab extends StatefulWidget {
  const _AlumniDashboardTab();

  @override
  State<_AlumniDashboardTab> createState() => _AlumniDashboardTabState();
}

class _AlumniDashboardTabState extends State<_AlumniDashboardTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final engagement = context.watch<EngagementProvider>();
    final mentorship = context.watch<MentorshipProvider>();
    final opportunities = context.watch<OpportunityProvider>();
    final activityFeed = context.watch<ActivityFeedProvider>();
    context.watch<ChatProvider>();
    final recommendation = context.watch<RecommendationProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, isDark),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<EngagementProvider>().refresh();
          await context.read<ActivityFeedProvider>().refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome + Key Metrics (compact row)
              _buildWelcomeRow(context, profile, engagement, isDark),
              const SizedBox(height: AppTheme.space20),

              // 2. Key Metrics Grid (compact 2×2)
              _buildMetricsGrid(profile, mentorship, opportunities, engagement, isDark),
              const SizedBox(height: AppTheme.space24),

              // 3. AI Smart Picks
              _buildAIPicksSection(context, recommendation, isDark),
              const SizedBox(height: AppTheme.space24),

              // 4. Quick Actions
              _buildQuickActions(context, isDark),
              const SizedBox(height: AppTheme.space24),

              // 5. Recent Activity
              _buildRecentActivity(context, activityFeed, mentorship, isDark),
              const SizedBox(height: AppTheme.space24),

              // 6. Engagement & Badges
              _buildEngagementBadges(context, engagement, isDark),
              const SizedBox(height: AppTheme.space24),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      title: Text(
        'Dashboard',
        style: AppTheme.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.gray900,
        ),
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
          icon: Icon(
            Icons.more_vert,
            color: isDark ? AppTheme.gray400 : AppTheme.gray700,
          ),
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
                  // CRITICAL: Reset ALL stream-based providers BEFORE logout
                  // to prevent Firestore permission errors from firing on
                  // active listeners after signOut() revokes the token.
                  // Mirrors StudentDashboardView / TeacherDashboardView.
                  context.read<ProfileProvider>().reset();
                  context.read<PlacementsProvider>().reset();
                  context.read<AIUsageProvider>().reset();
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
                  context.read<NotificationsProvider>().reset();
                  context.read<PortfolioProvider>().reset();
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
    );
  }

  // ──────────────────────────────────────────────
  // 1. Welcome + Key Metrics
  // ──────────────────────────────────────────────
  Widget _buildWelcomeRow(
    BuildContext context,
    StudentProfile? profile,
    EngagementProvider engagement,
    bool isDark,
  ) {
    final name = profile?.personal.effectiveDisplayName ?? 'Alumni';
    final company = profile?.company;
    final designation = profile?.designation ?? profile?.jobRole ?? 'Professional';
    final streak = engagement.dailyStreak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryIndigo.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InitialsAvatar(name: name, size: 48),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  '$designation${company != null ? ' · $company' : ''}',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 16, color: Colors.yellowAccent),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: AppTheme.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2. Key Metrics Grid (compact 2×2)
  // ──────────────────────────────────────────────
  Widget _buildMetricsGrid(
    StudentProfile? profile,
    MentorshipProvider mentorship,
    OpportunityProvider opportunities,
    EngagementProvider engagement,
    bool isDark,
  ) {
    final totalMentees =
        mentorship.acceptedMentorshipsCount + mentorship.completedMentorshipsCount;
    final totalOpps = opportunities.myOpportunities?.length ?? 0;
    final skillsCount = profile?.skills?.length ?? 0;
    final profileStrength = engagement.profileStrength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'At a Glance',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(child: _metricTile('$totalMentees', 'Mentees', Icons.people_outline, AppTheme.primaryBlue, isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _metricTile('$totalOpps', 'Opportunities', Icons.work_outline, AppTheme.success, isDark)),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(child: _metricTile('$skillsCount', 'Skills', Icons.lightbulb_outline, AppTheme.warning, isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _metricTile('$profileStrength%', 'Profile', Icons.trending_up_rounded, AppTheme.secondaryIndigo, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _metricTile(String value, String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space16, horizontal: AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppTheme.space12),
          Column(
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
                style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 3. AI Smart Picks
  // ──────────────────────────────────────────────
  Widget _buildAIPicksSection(BuildContext context, RecommendationProvider recommendation, bool isDark) {
    final picks = recommendation.recommendations.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AI Smart Picks',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Icon(Icons.auto_awesome, size: 16, color: AppTheme.secondaryIndigo),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        if (recommendation.isLoading && recommendation.recommendations.isEmpty)
          const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (picks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
            ),
            child: Text(
              'Complete your profile and stay active to unlock personalized recommendations.',
              style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
            ),
            child: Column(
              children: picks.map((r) => _recommendationCard(context, r, isDark)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _recommendationCard(BuildContext context, Recommendation recommendation, bool isDark) {
    final scoreColor = recommendation.score >= 75 ? AppTheme.success : AppTheme.primaryBlue;

    return InkWell(
      onTap: () async {
        await context.read<RecommendationProvider>().markInteracted(recommendation.id);
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(_recommendationIcon(recommendation.type), color: scoreColor, size: 18),
            ),
            const SizedBox(width: AppTheme.space12),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '${recommendation.score.round()}%',
                style: AppTheme.caption.copyWith(color: scoreColor, fontWeight: FontWeight.w700),
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

  // ──────────────────────────────────────────────
  // 4. Quick Actions (professional button row)
  // ──────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _QuickAction('Create Job', Icons.add_circle_outline, AppTheme.primaryBlue, createOpportunityRoute),
      _QuickAction('Resume Review', Icons.description_outlined, AppTheme.success, resumeReviewRoute),
      _QuickAction('Mentorship', Icons.school_outlined, AppTheme.warning, mentorshipRequestsRoute),
      _QuickAction('Directory', Icons.people_outline, AppTheme.secondaryIndigo, alumniDirectoryRoute),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: actions.map((a) => Expanded(child: _actionButton(context, a, isDark))).toList(),
        ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, _QuickAction action, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space8),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, action.route),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: AppTheme.space8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            children: [
              Icon(action.icon, color: action.color, size: 22),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 5. Recent Activity
  // ──────────────────────────────────────────────
  Widget _buildRecentActivity(
    BuildContext context,
    ActivityFeedProvider activityFeed,
    MentorshipProvider mentorship,
    bool isDark,
  ) {
    final activities = <_ActivityItem>[];

    final pendingCount = mentorship.pendingRequestsCount;
    if (pendingCount > 0) {
      activities.add(_ActivityItem(
        '$pendingCount pending mentorship request${pendingCount > 1 ? 's' : ''}',
        'Review mentorship requests from students',
        Icons.school_outlined,
        AppTheme.warning,
      ));
    }
    final acceptedCount = mentorship.acceptedMentorshipsCount;
    if (acceptedCount > 0) {
      activities.add(_ActivityItem(
        '$acceptedCount active mentorship${acceptedCount > 1 ? 's' : ''}',
        'You are currently mentoring students',
        Icons.handshake_rounded,
        AppTheme.success,
      ));
    }
    final completedCount = mentorship.completedMentorshipsCount;
    if (completedCount > 0) {
      activities.add(_ActivityItem(
        '$completedCount completed mentorship${completedCount > 1 ? 's' : ''}',
        'Mentorship journeys finished',
        Icons.celebration_outlined,
        AppTheme.primaryBlue,
      ));
    }

    for (final a in activityFeed.allActivities.take(3)) {
      activities.add(_ActivityItem(a.title, a.description, a.icon, a.iconColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: activities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppTheme.space24),
                  child: Center(child: Text('No recent activities')),
                )
              : Column(children: activities.map((a) => _activityItem(a, isDark)).toList()),
        ),
      ],
    );
  }

  Widget _activityItem(_ActivityItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: AppTheme.space12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtitle,
                  style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
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

  // ──────────────────────────────────────────────
  // 6. Engagement & Badges (compact card)
  // ──────────────────────────────────────────────
  Widget _buildEngagementBadges(BuildContext context, EngagementProvider engagement, bool isDark) {
    final score = engagement.engagementScore;
    final strength = engagement.profileStrength;
    final streak = engagement.dailyStreak;
    final badges = engagement.badges.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
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
              Text(
                'Engagement',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const Spacer(),
              if (streak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 4),
                    Text(
                      '$streak day${streak > 1 ? 's' : ''}',
                      style: AppTheme.caption.copyWith(
                        color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Engagement', style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: score.clamp(0, 100) / 100,
                        color: AppTheme.success,
                        backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$score%', style: AppTheme.caption.copyWith(color: AppTheme.success, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile', style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: strength.clamp(0, 100) / 100,
                        color: AppTheme.primaryBlue,
                        backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$strength%', style: AppTheme.caption.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: badges
                  .map((badge) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          border: Border.all(color: AppTheme.secondaryIndigo.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          badge.title,
                          style: AppTheme.caption.copyWith(color: AppTheme.secondaryIndigo, fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Shared helpers
  // ──────────────────────────────────────────────
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

/// Internal data classes
class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _ActivityItem(this.title, this.subtitle, this.icon, this.color);
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  _QuickAction(this.label, this.icon, this.color, this.route);
}
