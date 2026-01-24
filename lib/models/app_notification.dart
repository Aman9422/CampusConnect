import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification types for CampusConnect v6.4
enum NotificationType {
  placementApplied, // User applied for a placement
  statusChange, // Application status changed
  announcement, // Admin broadcast notification
  reminder, // Deadline reminders
  system, // System notifications
}

/// AppNotification model for in-app notifications
/// Stored at: users/{uid}/notifications/{notificationId}
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>?
  data; // Additional data (placementId, company, etc.)
  final bool isRead;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.expiresAt,
  });

  /// Create from Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: _parseNotificationType(data['type'] as String?),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      data: data['data'] as Map<String, dynamic>?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Parse notification type from string
  static NotificationType _parseNotificationType(String? typeStr) {
    switch (typeStr) {
      case 'placementApplied':
        return NotificationType.placementApplied;
      case 'statusChange':
        return NotificationType.statusChange;
      case 'announcement':
        return NotificationType.announcement;
      case 'reminder':
        return NotificationType.reminder;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  /// Create a copy with updated fields
  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Factory for placement applied notification
  factory AppNotification.placementApplied({
    required String placementId,
    required String company,
    required String role,
  }) {
    return AppNotification(
      id: '', // Will be set by Firestore
      type: NotificationType.placementApplied,
      title: 'Application Submitted',
      body: 'You have successfully applied for $role at $company',
      data: {'placementId': placementId, 'company': company, 'role': role},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// Factory for status change notification
  factory AppNotification.statusChange({
    required String placementId,
    required String company,
    required String role,
    required String status,
  }) {
    String title;
    String body;

    switch (status) {
      case 'reviewing':
        title = 'Application Under Review';
        body = 'Your application for $role at $company is now being reviewed';
        break;
      case 'accepted':
        title = '🎉 Congratulations!';
        body = 'You have been selected for $role at $company';
        break;
      case 'rejected':
        title = 'Application Update';
        body =
            'Your application for $role at $company was not selected. Keep trying!';
        break;
      default:
        title = 'Application Status Update';
        body = 'Your application for $role at $company status: $status';
    }

    return AppNotification(
      id: '',
      type: NotificationType.statusChange,
      title: title,
      body: body,
      data: {
        'placementId': placementId,
        'company': company,
        'role': role,
        'status': status,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// Factory for announcement notification
  factory AppNotification.announcement({
    required String announcementId,
    required String title,
    required String body,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.announcement,
      title: title,
      body: body,
      data: {'announcementId': announcementId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// Get icon for notification type
  String get iconName {
    switch (type) {
      case NotificationType.placementApplied:
        return 'check_circle';
      case NotificationType.statusChange:
        return 'update';
      case NotificationType.announcement:
        return 'campaign';
      case NotificationType.reminder:
        return 'alarm';
      case NotificationType.system:
        return 'info';
    }
  }

  /// Check if notification is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get relative time string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, type: $type, title: $title, isRead: $isRead)';
  }
}
