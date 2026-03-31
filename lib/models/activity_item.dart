import 'package:flutter/material.dart';

/// ActivityItem - Core model for the student dashboard activity feed
///
/// Represents a unified activity item that can come from multiple data sources:
/// notifications, chat messages, mentorship updates, placement activities, etc.
class ActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? avatarText; // For InitialsAvatar
  final IconData icon;
  final Color iconColor;
  final Map<String, dynamic>? actionData; // Navigation/action data
  final bool isRead;
  final String? sourceId; // Original source item ID
  final int priority; // For sorting (0 = highest priority)

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.avatarText,
    required this.icon,
    required this.iconColor,
    this.actionData,
    this.isRead = false,
    this.sourceId,
    this.priority = 5,
  });

  /// Create ActivityItem from AppNotification
  factory ActivityItem.fromNotification({
    required String id,
    required String title,
    required String description,
    required DateTime timestamp,
    required IconData icon,
    required Color iconColor,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.notification,
      title: title,
      description: description,
      timestamp: timestamp,
      icon: icon,
      iconColor: iconColor,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: isRead ? 7 : 2, // Unread notifications have higher priority
    );
  }

  /// Create ActivityItem from chat message
  factory ActivityItem.fromChatMessage({
    required String id,
    required String senderName,
    required String messagePreview,
    required DateTime timestamp,
    String? avatarText,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.chatMessage,
      title: 'New message from $senderName',
      description: messagePreview,
      timestamp: timestamp,
      avatarText: avatarText ?? senderName,
      icon: Icons.message_rounded,
      iconColor: Colors.blue,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: isRead ? 8 : 3,
    );
  }

  /// Create ActivityItem from mentorship update
  factory ActivityItem.fromMentorshipUpdate({
    required String id,
    required String title,
    required String description,
    required DateTime timestamp,
    required IconData icon,
    required Color iconColor,
    String? avatarText,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.mentorshipUpdate,
      title: title,
      description: description,
      timestamp: timestamp,
      avatarText: avatarText,
      icon: icon,
      iconColor: iconColor,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: 4,
    );
  }

  /// Create ActivityItem from placement activity
  factory ActivityItem.fromPlacementActivity({
    required String id,
    required String title,
    required String description,
    required DateTime timestamp,
    required IconData icon,
    required Color iconColor,
    String? company,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.placementApplication,
      title: title,
      description: description,
      timestamp: timestamp,
      avatarText: company,
      icon: icon,
      iconColor: iconColor,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: 3,
    );
  }

  /// Create ActivityItem from new opportunity
  factory ActivityItem.fromOpportunity({
    required String id,
    required String company,
    required String role,
    required DateTime timestamp,
    String? description,
    String? avatarText,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.newOpportunity,
      title: 'New opportunity at $company',
      description: description ?? 'Role: $role',
      timestamp: timestamp,
      avatarText: avatarText ?? company,
      icon: Icons.work_outline_rounded,
      iconColor: Colors.orange,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: 5,
    );
  }

  /// Create ActivityItem for system announcement
  factory ActivityItem.fromAnnouncement({
    required String id,
    required String title,
    required String description,
    required DateTime timestamp,
    IconData? icon,
    Color? iconColor,
    bool isRead = false,
    String? sourceId,
    Map<String, dynamic>? actionData,
  }) {
    return ActivityItem(
      id: id,
      type: ActivityType.announcement,
      title: title,
      description: description,
      timestamp: timestamp,
      icon: icon ?? Icons.campaign_rounded,
      iconColor: iconColor ?? Colors.purple,
      isRead: isRead,
      sourceId: sourceId,
      actionData: actionData,
      priority: 1, // Announcements have highest priority
    );
  }

  /// Get relative time string (e.g., "2h ago", "3 days ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    }
  }

  /// Check if activity is from today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
           timestamp.month == now.month &&
           timestamp.day == now.day;
  }

  /// Check if activity is from this week (past 7 days)
  bool get isThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return timestamp.isAfter(weekAgo);
  }

  /// Copy with modifications
  ActivityItem copyWith({
    String? id,
    ActivityType? type,
    String? title,
    String? description,
    DateTime? timestamp,
    String? avatarText,
    IconData? icon,
    Color? iconColor,
    Map<String, dynamic>? actionData,
    bool? isRead,
    String? sourceId,
    int? priority,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      avatarText: avatarText ?? this.avatarText,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      actionData: actionData ?? this.actionData,
      isRead: isRead ?? this.isRead,
      sourceId: sourceId ?? this.sourceId,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ActivityItem(id: $id, type: $type, title: $title, timeAgo: $timeAgo)';
  }
}

/// Types of activities that can appear in the feed
enum ActivityType {
  notification,
  chatMessage,
  mentorshipUpdate,
  placementApplication,
  newOpportunity,
  announcement,
}

/// Extension to get display information for activity types
extension ActivityTypeExtension on ActivityType {
  /// Get display name for activity type
  String get displayName {
    switch (this) {
      case ActivityType.notification:
        return 'Notification';
      case ActivityType.chatMessage:
        return 'Message';
      case ActivityType.mentorshipUpdate:
        return 'Mentorship';
      case ActivityType.placementApplication:
        return 'Placement';
      case ActivityType.newOpportunity:
        return 'Opportunity';
      case ActivityType.announcement:
        return 'Announcement';
    }
  }

  /// Get appropriate route for navigation based on activity type
  String? get defaultRoute {
    switch (this) {
      case ActivityType.notification:
        return '/notifications';
      case ActivityType.chatMessage:
        return '/chats-list';
      case ActivityType.mentorshipUpdate:
        return '/mentorship-requests';
      case ActivityType.placementApplication:
        return '/placements-list';
      case ActivityType.newOpportunity:
        return '/opportunities';
      case ActivityType.announcement:
        return null; // Can be custom navigation
    }
  }
}