import 'package:campusconnect/models/activity_item.dart';
import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Activity feed UI components for recreating original NotesView dashboard
///
/// These components provide the "Today/This Week" timeline sections and
/// activity cards that match the original student dashboard experience.

/// Section header for activity timeline (e.g., "Today", "This Week")
class ActivitySectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;
  final bool isCollapsed;

  const ActivitySectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.onTap,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (onTap != null) ...[
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual activity list item with notification-style design
class ActivityListItem extends StatelessWidget {
  final ActivityItem activity;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final bool dense;

  const ActivityListItem({
    super.key,
    required this.activity,
    this.onTap,
    this.onMarkAsRead,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(activity.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (!activity.isRead && onMarkAsRead != null) {
          onMarkAsRead!();
          return false; // Don't actually dismiss, just mark as read
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppTheme.success.withOpacity(0.1),
        child: Icon(Icons.check_rounded, color: AppTheme.success),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () => _handleActivityTap(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(dense ? 12 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity icon or avatar
                  _buildActivityIcon(isDark),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                activity.title,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: activity.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.gray900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!activity.isRead) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.description,
                          style: AppTheme.bodySmall.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              activity.timeAgo,
                              style: AppTheme.caption.copyWith(
                                color: isDark
                                    ? AppTheme.gray500
                                    : AppTheme.gray500,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: activity.iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activity.type.displayName,
                                style: AppTheme.caption.copyWith(
                                  color: activity.iconColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build activity icon or avatar
  Widget _buildActivityIcon(bool isDark) {
    if (activity.avatarText != null && activity.avatarText!.isNotEmpty) {
      // Use initials avatar for personal activities (chat, mentorship)
      return InitialsAvatar(name: activity.avatarText!, size: 40);
    } else {
      // Use icon container for system activities (notifications, announcements)
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: activity.iconColor.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activity.iconColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Icon(activity.icon, color: activity.iconColor, size: 18),
      );
    }
  }

  /// Handle activity tap navigation
  void _handleActivityTap(BuildContext context) {
    if (activity.actionData != null && activity.actionData!['route'] != null) {
      final route = activity.actionData!['route'] as String;

      try {
        // Navigate based on activity type and route
        switch (route) {
          case '/notifications':
            Navigator.pushNamed(context, notificationsRoute);
            break;
          case '/chat':
            final chatId = activity.actionData!['chatId'] as String?;
            if (chatId != null && chatId.isNotEmpty) {
              Navigator.pushNamed(context, chatRoute, arguments: chatId);
            } else {
              Navigator.pushNamed(context, chatsListRoute);
            }
            break;
          case '/mentorship-request-detail':
            final requestId = activity.actionData!['requestId'] as String?;
            if (requestId != null && requestId.isNotEmpty) {
              Navigator.pushNamed(
                context,
                mentorshipRequestDetailRoute,
                arguments: requestId,
              );
            } else {
              Navigator.pushNamed(context, mentorshipRequestsRoute);
            }
            break;
          case '/placements-list':
            Navigator.pushNamed(context, placementsListRoute);
            break;
          case '/opportunity-detail':
            final opportunityId =
                activity.actionData!['opportunityId'] as String?;
            if (opportunityId != null && opportunityId.isNotEmpty) {
              Navigator.pushNamed(
                context,
                opportunityDetailRoute,
                arguments: opportunityId,
              );
            } else {
              Navigator.pushNamed(context, opportunitiesRoute);
            }
            break;
          default:
            // Fallback navigation based on activity type
            final defaultRoute = activity.type.defaultRoute;
            if (defaultRoute != null) {
              Navigator.pushNamed(context, defaultRoute);
            }
        }
      } catch (e) {
        debugPrint('Navigation error for activity ${activity.id}: $e');
      }
    }

    // Mark activity as read
    if (!activity.isRead) {
      context.read<ActivityFeedProvider>().markActivityAsRead(activity.id);
    }
  }
}

/// Featured content card for announcements and highlights
class FeaturedCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final String? badge;

  const FeaturedCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTheme.titleSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badge!,
                                style: AppTheme.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onTap != null) ...[
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's activity highlight summary
class TodayHighlight extends StatelessWidget {
  final int totalActivities;
  final int unreadCount;
  final int placementDeadlines;

  const TodayHighlight({
    super.key,
    required this.totalActivities,
    required this.unreadCount,
    required this.placementDeadlines,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Summary',
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Activities',
                  totalActivities.toString(),
                  Icons.timeline_rounded,
                  AppTheme.primaryBlue,
                  isDark,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: isDark ? AppTheme.gray700 : AppTheme.gray200,
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Unread',
                  unreadCount.toString(),
                  Icons.notifications_active_rounded,
                  AppTheme.warning,
                  isDark,
                ),
              ),
              if (placementDeadlines > 0) ...[
                Container(
                  width: 1,
                  height: 32,
                  color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Deadlines',
                    placementDeadlines.toString(),
                    Icons.schedule_rounded,
                    AppTheme.error,
                    isDark,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
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
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Empty state for when no activities are available
class ActivityEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const ActivityEmptyState({
    super.key,
    this.title = 'No activities yet',
    this.subtitle = 'When things happen, they\'ll appear here',
    this.icon = Icons.timeline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.gray600 : AppTheme.gray300).withOpacity(
                0.3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray500 : AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
