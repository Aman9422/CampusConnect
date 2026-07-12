import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// v7.5: Modernized Alumni Dashboard matching Student Dashboard quality.
///
/// Hero section with welcome + avatar + stats.
/// Quick Stats row, Activity Feed, Professional Tools grid,
/// My Impact section, and Quick Actions.
class AlumniDashboardView extends StatelessWidget {
  const AlumniDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              color: isDark ? Colors.white : AppTheme.gray900,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Alumni Dashboard',
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
      body: _AlumniDashboardBody(),
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
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum MenuAction { logout }

class _AlumniDashboardBody extends StatefulWidget {
  @override
  State<_AlumniDashboardBody> createState() => _AlumniDashboardBodyState();
}

class _AlumniDashboardBodyState extends State<_AlumniDashboardBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MentorshipProvider>().refresh();
      context.read<OpportunityProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final mentorship = context.watch<MentorshipProvider>();
    final opportunities = context.watch<OpportunityProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final activityFeed = context.watch<ActivityFeedProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<MentorshipProvider>().refresh();
        await context.read<OpportunityProvider>().refresh();
        await context.read<ActivityFeedProvider>().refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context, profile, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildQuickStats(
              context,
              profile,
              mentorship,
              opportunities,
              chatProvider,
              isDark,
            ),
            const SizedBox(height: AppTheme.space24),
            _buildActivityFeed(context, activityFeed, mentorship, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildProfessionalTools(context, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildMyImpact(context, mentorship, opportunities, profile, isDark),
            const SizedBox(height: AppTheme.space24),
            _buildQuickActions(context, isDark),
            const SizedBox(height: AppTheme.space24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    StudentProfile? profile,
    bool isDark,
  ) {
    final name = profile?.personal.effectiveDisplayName ?? 'Alumni';

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
                      'Welcome, $name',
                      style: AppTheme.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      profile?.jobRole ?? 'Professional',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          Row(
            children: [
              _heroStat(
                profile?.company ?? 'Your Network',
                'Company',
                Icons.business_outlined,
              ),
              const SizedBox(width: AppTheme.space12),
              _heroStat(
                '${profile?.skills?.length ?? 0} Skills',
                'Expertise',
                Icons.lightbulb_outline,
              ),
              const SizedBox(width: AppTheme.space12),
              _heroStat(
                profile?.designation ?? 'Alumni',
                'Designation',
                Icons.badge_outlined,
              ),
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
            Text(
              value,
              style: AppTheme.titleSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    StudentProfile? profile,
    MentorshipProvider mentorship,
    OpportunityProvider opportunities,
    ChatProvider chatProvider,
    bool isDark,
  ) {
    final studentsMentored =
        mentorship.completedMentorshipsCount +
        mentorship.acceptedMentorshipsCount;
    final activeChats = chatProvider.chats?.length ?? 0;
    final opportunitiesPosted = opportunities.myOpportunities?.length ?? 0;
    final profileViews = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '$studentsMentored',
                'Students Mentored',
                Icons.people_outline,
                AppTheme.primaryBlue,
                isDark,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: _buildStatCard(
                '$activeChats',
                'Active Chats',
                Icons.chat_outlined,
                AppTheme.success,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '$opportunitiesPosted',
                'Opps. Posted',
                Icons.work_outline,
                AppTheme.warning,
                isDark,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: _buildStatCard(
                '$profileViews',
                'Profile Views',
                Icons.visibility_outlined,
                AppTheme.secondaryIndigo,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
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
              Text(
                value,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
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

  Widget _buildActivityFeed(
    BuildContext context,
    ActivityFeedProvider activityFeed,
    MentorshipProvider mentorship,
    bool isDark,
  ) {
    final activities = <_ActivityItem>[];

    final pendingCount = mentorship.pendingRequestsCount;
    if (pendingCount > 0) {
      activities.add(
        _ActivityItem(
          '$pendingCount pending mentorship request(s)',
          'Review mentorship requests from students',
          Icons.school_outlined,
          AppTheme.warning,
        ),
      );
    }

    final acceptedCount = mentorship.acceptedMentorshipsCount;
    if (acceptedCount > 0) {
      activities.add(
        _ActivityItem(
          '$acceptedCount active mentorship(s)',
          'You are currently mentoring students',
          Icons.handshake_rounded,
          AppTheme.success,
        ),
      );
    }

    final completedCount = mentorship.completedMentorshipsCount;
    if (completedCount > 0) {
      activities.add(
        _ActivityItem(
          '$completedCount completed mentorship(s)',
          'Mentorship journeys successfully finished',
          Icons.celebration_outlined,
          AppTheme.primaryBlue,
        ),
      );
    }

    for (final a in activityFeed.allActivities.take(3)) {
      activities.add(
        _ActivityItem(a.title, a.description, a.icon, a.iconColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
            boxShadow: AppTheme.shadowSmall,
          ),
          child: activities.isEmpty
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
                  children: activities
                      .map((a) => _buildActivityItem(context, a, isDark))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    _ActivityItem activity,
    bool isDark,
  ) {
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
                Text(
                  activity.title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activity.subtitle,
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

  Widget _buildProfessionalTools(BuildContext context, bool isDark) {
    final tools = [
      _ToolItem('Mentorship', Icons.school_outlined, AppTheme.primaryBlue, mentorshipRequestsRoute),
      _ToolItem('Opportunities', Icons.work_outline, AppTheme.success, opportunitiesRoute),
      _ToolItem('Chats', Icons.chat_outlined, AppTheme.warning, chatsListRoute),
      _ToolItem('Profile', Icons.person_outline, AppTheme.secondaryIndigo, profileViewRoute),
      _ToolItem('AI Career', Icons.auto_awesome, AppTheme.primaryBlue, aiChatRoute),
      _ToolItem('Notifications', Icons.notifications_outlined, AppTheme.error, notificationsRoute),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Tools',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
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
          border: Border.all(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
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
            Text(
              tool.title,
              style: AppTheme.caption.copyWith(
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
  }

  Widget _buildMyImpact(
    BuildContext context,
    MentorshipProvider mentorship,
    OpportunityProvider opportunities,
    StudentProfile? profile,
    bool isDark,
  ) {
    final totalMentees =
        mentorship.acceptedMentorshipsCount + mentorship.completedMentorshipsCount;
    final totalOppsShared = opportunities.myOpportunities?.length ?? 0;
    final skillsCount = profile?.skills?.length ?? 0;
    final engagementScore = context.watch<EngagementProvider>().engagementScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Impact',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Icon(Icons.auto_awesome, size: 18, color: AppTheme.secondaryIndigo),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(
              child: _buildImpactCard('Mentees', '$totalMentees', Icons.people, AppTheme.primaryBlue, isDark),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: _buildImpactCard('Opps Shared', '$totalOppsShared', Icons.share_outlined, AppTheme.success, isDark),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(
              child: _buildImpactCard('Skills', '$skillsCount', Icons.lightbulb_outline, AppTheme.warning, isDark),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: _buildImpactCard('Engagement', '$engagementScore%', Icons.trending_up_rounded, AppTheme.secondaryIndigo, isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImpactCard(String title, String value, IconData icon, Color color, bool isDark) {
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

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(child: _buildActionButton(context, icon: Icons.add_circle_outline, label: 'Create Opp.', color: AppTheme.primaryBlue, route: createOpportunityRoute, isDark: isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _buildActionButton(context, icon: Icons.list_alt_outlined, label: 'Manage Opps.', color: AppTheme.success, route: opportunitiesRoute, isDark: isDark)),
            Expanded(child: _buildActionButton(context, icon: Icons.edit_outlined, label: 'Edit Profile', color: AppTheme.warning, route: editProfileRoute, isDark: isDark)),
            const SizedBox(width: AppTheme.space12),
            Expanded(child: _buildActionButton(context, icon: Icons.people_outline, label: 'Directory', color: AppTheme.secondaryIndigo, route: alumniDirectoryRoute, isDark: isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required String route, required bool isDark}) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12, horizontal: AppTheme.space8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          boxShadow: AppTheme.shadowSmall,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(label, style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray800), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  _ActivityItem(this.title, this.subtitle, this.icon, this.color);
}

class _ToolItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  _ToolItem(this.title, this.icon, this.color, this.route);
}
