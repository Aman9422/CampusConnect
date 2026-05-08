import 'dart:async';
import 'package:campusconnect/models/activity_item.dart';
import 'package:campusconnect/models/app_notification.dart';
import 'package:campusconnect/models/chat.dart';
import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// ActivityFeedProvider - Aggregates activity data for student dashboard
///
/// Combines data from multiple providers to create a unified activity feed
/// following the original NotesView dashboard design with Today/This Week sections.
class ActivityFeedProvider extends ChangeNotifier {
  final NotificationsProvider _notificationsProvider;
  final ChatProvider _chatProvider;
  final MentorshipProvider _mentorshipProvider;
  final PlacementsProvider _placementsProvider;
  final OpportunityProvider _opportunityProvider;

  ActivityFeedProvider({
    required NotificationsProvider notificationsProvider,
    required ChatProvider chatProvider,
    required MentorshipProvider mentorshipProvider,
    required PlacementsProvider placementsProvider,
    required OpportunityProvider opportunityProvider,
  }) : _notificationsProvider = notificationsProvider,
       _chatProvider = chatProvider,
       _mentorshipProvider = mentorshipProvider,
       _placementsProvider = placementsProvider,
       _opportunityProvider = opportunityProvider {
    _init();
  }

  // State
  List<ActivityItem> _allActivities = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;

  // Provider change subscriptions
  final List<VoidCallback> _providerListeners = [];

  // Getters
  List<ActivityItem> get allActivities => _allActivities;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Get today's activities (sorted by priority, then timestamp)
  List<ActivityItem> get todayActivities {
    final today = DateTime.now();
    return _allActivities.where((activity) {
      final activityDate = activity.timestamp;
      return activityDate.year == today.year &&
          activityDate.month == today.month &&
          activityDate.day == today.day;
    }).toList()..sort((a, b) {
      // Sort by priority first, then by timestamp (newest first)
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  /// Get this week's activities (past 7 days, excluding today)
  List<ActivityItem> get thisWeekActivities {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    return _allActivities.where((activity) {
      final activityDate = DateTime(
        activity.timestamp.year,
        activity.timestamp.month,
        activity.timestamp.day,
      );
      return activityDate.isAfter(weekAgo) && activityDate.isBefore(today);
    }).toList()..sort((a, b) {
      // Sort by priority first, then by timestamp (newest first)
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  /// Get featured/priority activities
  List<ActivityItem> get featuredActivities {
    return _allActivities
        .where((activity) => activity.priority <= 2) // High priority items
        .take(3) // Limit to 3 featured items
        .toList()
      ..sort((a, b) {
        final priorityComparison = a.priority.compareTo(b.priority);
        if (priorityComparison != 0) return priorityComparison;
        return b.timestamp.compareTo(a.timestamp);
      });
  }

  /// Get unread activity count
  int get unreadCount {
    return _allActivities.where((activity) => !activity.isRead).length;
  }

  /// Initialize provider listeners
  void _init() {
    // Listen to all provider changes
    _addProviderListener(_notificationsProvider, _aggregateActivities);
    _addProviderListener(_chatProvider, _aggregateActivities);
    _addProviderListener(_mentorshipProvider, _aggregateActivities);
    _addProviderListener(_placementsProvider, _aggregateActivities);
    _addProviderListener(_opportunityProvider, _aggregateActivities);

    // Initial aggregation
    _aggregateActivities();
    _isInitialized = true;
  }

  /// Add listener to provider and track for cleanup
  void _addProviderListener(ChangeNotifier provider, VoidCallback listener) {
    provider.addListener(listener);
    _providerListeners.add(() => provider.removeListener(listener));
  }

  /// Aggregate activities from all providers
  Future<void> _aggregateActivities() async {
    if (_isDisposed) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final activities = <ActivityItem>[];

      // Convert notifications to activities
      final notifications = _notificationsProvider.notifications;
      for (final notification in notifications) {
        activities.add(_createActivityFromNotification(notification));
      }

      // Convert recent chats to activities (last 20 messages)
      final recentChats = _chatProvider.chats?.take(10) ?? [];
      for (final chat in recentChats) {
        // Use chat's lastMessage string directly - no Message object needed
        if (chat.lastMessage.isNotEmpty) {
          activities.add(_createActivityFromChat(chat));
        }
      }

      // Convert mentorship requests to activities
      final mentorshipRequests = _mentorshipProvider.requests?.take(15) ?? [];
      for (final request in mentorshipRequests) {
        activities.add(_createActivityFromMentorshipRequest(request));
      }

      // Convert recent placement applications to activities
      final recentApplications = _getRecentPlacementActivities();
      activities.addAll(recentApplications);

      // Convert recent opportunities to activities
      final recentOpportunities =
          _opportunityProvider.opportunities?.take(10) ?? [];
      for (final opportunity in recentOpportunities) {
        activities.add(_createActivityFromOpportunity(opportunity));
      }

      // Sort all activities by timestamp (newest first), then by priority
      activities.sort((a, b) {
        final priorityComparison = a.priority.compareTo(b.priority);
        if (priorityComparison != 0) return priorityComparison;
        return b.timestamp.compareTo(a.timestamp);
      });

      // Limit total activities to prevent memory issues (last 50 activities)
      _allActivities = activities.take(50).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('ActivityFeedProvider error: $e');
    } finally {
      _isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Convert AppNotification to ActivityItem
  ActivityItem _createActivityFromNotification(AppNotification notification) {
    return ActivityItem.fromNotification(
      id: 'notification_${notification.id}',
      title: notification.title,
      description: notification.body,
      timestamp: notification.createdAt,
      icon: _getNotificationIcon(notification),
      iconColor: _getNotificationColor(notification),
      isRead: notification.isRead,
      sourceId: notification.id,
      actionData: {
        'route': '/notifications',
        'notificationId': notification.id,
      },
    );
  }

  /// Convert Chat to ActivityItem
  ActivityItem _createActivityFromChat(Chat chat) {
    final senderName =
        chat.participantNames[chat.lastMessageSenderId] ?? 'Unknown';
    return ActivityItem.fromChatMessage(
      id: 'chat_${chat.id}',
      senderName: senderName,
      messagePreview: _truncateMessage(chat.lastMessage),
      timestamp: chat.lastMessageAt,
      avatarText: senderName,
      isRead: true, // Can check unreadCount if needed
      sourceId: chat.id,
      actionData: {'route': '/chat', 'chatId': chat.id},
    );
  }

  /// Convert MentorshipRequest to ActivityItem
  ActivityItem _createActivityFromMentorshipRequest(MentorshipRequest request) {
    final (title, description, icon, color) = _getMentorshipActivityInfo(
      request,
    );

    return ActivityItem.fromMentorshipUpdate(
      id: 'mentorship_${request.id}',
      title: title,
      description: description,
      timestamp: request.respondedAt ?? request.createdAt,
      icon: icon,
      iconColor: color,
      avatarText: request.alumniName,
      sourceId: request.id,
      actionData: {
        'route': '/mentorship-request-detail',
        'requestId': request.id,
      },
    );
  }

  /// Convert Opportunity to ActivityItem
  ActivityItem _createActivityFromOpportunity(Opportunity opportunity) {
    return ActivityItem.fromOpportunity(
      id: 'opportunity_${opportunity.id}',
      company: opportunity.company,
      role: opportunity.title,
      timestamp: opportunity.postedAt,
      description: 'New job opportunity posted by ${opportunity.alumniName}',
      avatarText: opportunity.company,
      sourceId: opportunity.id,
      actionData: {
        'route': '/opportunity-detail',
        'opportunityId': opportunity.id,
      },
    );
  }

  /// Get recent placement-related activities
  List<ActivityItem> _getRecentPlacementActivities() {
    final activities = <ActivityItem>[];

    // Get recent placements (first 15)
    final recentPlacements = _placementsProvider.placements.take(15);

    for (final placement in recentPlacements) {
      // Create activity for new placement
      activities.add(
        ActivityItem.fromPlacementActivity(
          id: 'placement_new_${placement.id}',
          title: 'New placement at ${placement.company}',
          description:
              'Role: ${placement.role} • Deadline: ${_formatDateTime(placement.deadline)}',
          timestamp: placement.postedAt,
          icon: Icons.business_outlined,
          iconColor: AppTheme.primaryBlue,
          company: placement.company,
          sourceId: placement.id,
          actionData: {
            'route': '/placements-list',
            'placementId': placement.id,
          },
        ),
      );

      // Create activity if user applied to this placement
      final hasApplied = _placementsProvider.hasApplied(placement.id);
      if (hasApplied) {
        final appliedDate = _placementsProvider.getAppliedDate(placement.id);
        if (appliedDate != null) {
          activities.add(
            ActivityItem.fromPlacementActivity(
              id: 'placement_applied_${placement.id}',
              title: 'Applied to ${placement.company}',
              description:
                  'Your application for ${placement.role} was submitted',
              timestamp: appliedDate,
              icon: Icons.check_circle_outline,
              iconColor: AppTheme.success,
              company: placement.company,
              sourceId: placement.id,
              actionData: {
                'route': '/placements-list',
                'placementId': placement.id,
              },
            ),
          );
        }
      }
    }

    return activities;
  }

  /// Get appropriate icon for notification type
  IconData _getNotificationIcon(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.placementApplied:
        return Icons.check_circle_outline;
      case NotificationType.statusChange:
        return Icons.update_rounded;
      case NotificationType.announcement:
        return Icons.campaign_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.mentorshipRequested:
        return Icons.school_outlined;
      case NotificationType.mentorshipAccepted:
        return Icons.handshake_rounded;
      case NotificationType.newMessage:
        return Icons.message_rounded;
      case NotificationType.newJobPost:
        return Icons.work_outline_rounded;
      case NotificationType.system:
      case NotificationType.mentorshipRejected:
        return Icons.notifications_outlined;
    }
  }

  /// Get appropriate color for notification type
  Color _getNotificationColor(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.placementApplied:
      case NotificationType.mentorshipAccepted:
        return AppTheme.success;
      case NotificationType.statusChange:
      case NotificationType.reminder:
        return AppTheme.warning;
      case NotificationType.announcement:
        return AppTheme.primaryBlue;
      case NotificationType.mentorshipRequested:
        return AppTheme.secondaryIndigo;
      case NotificationType.newMessage:
        return Colors.blue;
      case NotificationType.newJobPost:
        return Colors.orange;
      case NotificationType.system:
      case NotificationType.mentorshipRejected:
        return AppTheme.gray500;
    }
  }

  /// Get mentorship activity information based on status
  (String, String, IconData, Color) _getMentorshipActivityInfo(
    MentorshipRequest request,
  ) {
    switch (request.status) {
      case MentorshipRequestStatus.pending:
        return (
          'Mentorship request to ${request.alumniName}',
          'Your request is pending review',
          Icons.hourglass_empty,
          AppTheme.warning,
        );
      case MentorshipRequestStatus.accepted:
        return (
          'Mentorship accepted by ${request.alumniName}',
          'Your mentorship request was approved',
          Icons.check_circle,
          AppTheme.success,
        );
      case MentorshipRequestStatus.rejected:
        return (
          'Mentorship request declined',
          'Request to ${request.alumniName} was not approved',
          Icons.cancel,
          AppTheme.error,
        );
      case MentorshipRequestStatus.completed:
        return (
          'Mentorship completed with ${request.alumniName}',
          'Your mentorship journey has ended successfully',
          Icons.celebration,
          AppTheme.primaryBlue,
        );
    }
  }

  /// Truncate message content for preview
  String _truncateMessage(String content, [int maxLength = 60]) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Refresh all activities
  Future<void> refresh() async {
    await _aggregateActivities();
  }

  /// Mark activity as read
  Future<void> markActivityAsRead(String activityId) async {
    final activityIndex = _allActivities.indexWhere((a) => a.id == activityId);
    if (activityIndex >= 0) {
      _allActivities[activityIndex] = _allActivities[activityIndex].copyWith(
        isRead: true,
      );
      notifyListeners();
    }
  }

  /// Reset state (called on logout)
  void reset() {
    _allActivities.clear();
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Remove all provider listeners
    for (final removeListener in _providerListeners) {
      removeListener();
    }
    _providerListeners.clear();

    super.dispose();
  }
}
