import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/activity_item.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/chat_badge.dart';
import 'package:campusconnect/views/widgets/eligibility_badge.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/widgets/home_widgets.dart';
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
                    // CRITICAL: Reset all providers BEFORE logout
                    context.read<ProfileProvider>().reset();
                    context.read<PlacementsProvider>().reset();
                    context.read<AIUsageProvider>().reset();
                    context.read<ActivityFeedProvider>().reset();
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
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
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

              // Featured Event Card
              const FeaturedCard(),
              const SizedBox(height: 24),

              // Today / This Week Section
              _buildTodaySection(context, activityFeed, isDark),
              const SizedBox(height: 24),

              // Connect & Grow Section
              _buildConnectAndGrowSection(context, isDark),
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
