import 'package:campusconnect/models/app_notification.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/constants/routes.dart'; // v7.3
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// NotificationsView - v6.4
///
/// Displays user's in-app notifications with read/unread states.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.hasUnread) {
                return TextButton(
                  onPressed: () => _markAllAsRead(context, provider),
                  child: const Text('Mark all read'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_read',
                child: Text('Clear read notifications'),
              ),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          // Loading state
          if (provider.isLoading && !provider.isInitialized) {
            return const LoadingWidget(message: 'Loading notifications...');
          }

          // Error state
          if (provider.error != null && provider.notifications.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Something went wrong',
              subtitle: provider.error!,
              actionLabel: 'Retry',
              onAction: () => provider.refresh(),
            );
          }

          // Empty state
          if (provider.notifications.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'You\'re all caught up! Check back later.',
            );
          }

          // Notifications list
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _handleNotificationTap(context, notification),
                  onDismiss: () =>
                      _deleteNotification(context, notification.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _markAllAsRead(BuildContext context, NotificationsProvider provider) {
    provider.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final provider = context.read<NotificationsProvider>();
    switch (action) {
      case 'clear_read':
        _showClearConfirmation(context, provider);
        break;
      case 'refresh':
        provider.refresh();
        break;
    }
  }

  void _showClearConfirmation(
    BuildContext context,
    NotificationsProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear read notifications?'),
        content: const Text(
          'This will permanently delete all read notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.clearReadNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Read notifications cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
  ) {
    final provider = context.read<NotificationsProvider>();

    // Mark as read
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.placementApplied:
      case NotificationType.statusChange:
        final placementId = notification.data?['placementId'] as String?;
        if (placementId != null) {
          // Navigate to placement details
          // Navigator.pushNamed(context, '/placement/$placementId');
        }
        break;
      case NotificationType.announcement:
        _showAnnouncementDetail(context, notification);
        break;
      // v7.3: New notification types
      case NotificationType.mentorshipAccepted:
        final chatId = notification.data?['chatId'] as String?;
        if (chatId != null) {
          Navigator.pushNamed(context, chatRoute, arguments: chatId);
        }
        break;
      case NotificationType.mentorshipRequested:
      case NotificationType.mentorshipRejected:
        final requestId = notification.data?['requestId'] as String?;
        if (requestId != null) {
          Navigator.pushNamed(
            context,
            mentorshipRequestDetailRoute,
            arguments: requestId,
          );
        }
        break;
      case NotificationType.newMessage:
        final chatId = notification.data?['chatId'] as String?;
        if (chatId != null) {
          Navigator.pushNamed(context, chatRoute, arguments: chatId);
        }
        break;
      case NotificationType.newJobPost:
        final opportunityId = notification.data?['opportunityId'] as String?;
        if (opportunityId != null) {
          Navigator.pushNamed(
            context,
            opportunityDetailRoute,
            arguments: opportunityId,
          );
        }
        break;
      case NotificationType.mentorMatch:
        Navigator.pushNamed(context, alumniDirectoryRoute);
        break;
      case NotificationType.jobMatch:
        Navigator.pushNamed(context, opportunitiesRoute);
        break;
      case NotificationType.inactiveChatReminder:
        Navigator.pushNamed(context, chatsListRoute);
        break;
      case NotificationType.engagementMilestone:
      case NotificationType.recommendationDigest:
        // Informational notifications: no deep-link required.
        break;
      default:
        break;
    }
  }

  void _showAnnouncementDetail(
    BuildContext context,
    AppNotification notification,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteNotification(BuildContext context, String notificationId) {
    final provider = context.read<NotificationsProvider>();
    provider.deleteNotification(notificationId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Individual notification tile widget
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Icon(
            _getIcon(),
            color: isUnread ? theme.colorScheme.primary : Colors.grey,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnread
                    ? theme.textTheme.bodyMedium?.color
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.placementApplied:
        return Icons.check_circle;
      case NotificationType.statusChange:
        return Icons.update;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.system:
        return Icons.info;
      // v7.3: New notification types
      case NotificationType.mentorshipRequested:
        return Icons.school;
      case NotificationType.mentorshipAccepted:
        return Icons.handshake;
      case NotificationType.mentorshipRejected:
        return Icons.cancel;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.newJobPost:
        return Icons.work;
      case NotificationType.mentorMatch:
        return Icons.groups;
      case NotificationType.jobMatch:
        return Icons.recommend;
      case NotificationType.inactiveChatReminder:
        return Icons.chat_bubble_outline;
      case NotificationType.engagementMilestone:
        return Icons.emoji_events;
      case NotificationType.recommendationDigest:
        return Icons.tips_and_updates;
    }
  }
}
