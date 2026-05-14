import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification types for CampusConnect v7.3
enum NotificationType {
  placementApplied, // User applied for a placement
  statusChange, // Application status changed
  announcement, // Admin broadcast notification
  reminder, // Deadline reminders
  system, // System notifications
  // v7.3: New types
  mentorshipRequested, // Student requests mentorship
  mentorshipAccepted, // Alumni accepts request
  mentorshipRejected, // Alumni rejects request
  newMessage, // Chat message received
  newJobPost, // New opportunity posted
  // v7.4: Intelligent notifications
  mentorMatch, // AI mentor recommendation
  jobMatch, // AI job recommendation
  inactiveChatReminder, // Inactive chat reminder
  engagementMilestone, // Streak / engagement milestone
  recommendationDigest, // Consolidated recommendations
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
      // v7.3: New types
      case 'mentorshipRequested':
        return NotificationType.mentorshipRequested;
      case 'mentorshipAccepted':
        return NotificationType.mentorshipAccepted;
      case 'mentorshipRejected':
        return NotificationType.mentorshipRejected;
      case 'newMessage':
        return NotificationType.newMessage;
      case 'newJobPost':
        return NotificationType.newJobPost;
      // v7.4
      case 'mentorMatch':
        return NotificationType.mentorMatch;
      case 'jobMatch':
        return NotificationType.jobMatch;
      case 'inactiveChatReminder':
        return NotificationType.inactiveChatReminder;
      case 'engagementMilestone':
        return NotificationType.engagementMilestone;
      case 'recommendationDigest':
        return NotificationType.recommendationDigest;
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

  /// v7.3: Factory for mentorship requested notification
  factory AppNotification.mentorshipRequested({
    required String requestId,
    required String studentName,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.mentorshipRequested,
      title: 'New Mentorship Request',
      body: '$studentName has requested your mentorship',
      data: {'requestId': requestId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.3: Factory for mentorship accepted notification
  factory AppNotification.mentorshipAccepted({
    required String requestId,
    required String alumniName,
    required String chatId,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.mentorshipAccepted,
      title: 'Mentorship Request Accepted!',
      body: '$alumniName has accepted your mentorship request',
      data: {'requestId': requestId, 'chatId': chatId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.3: Factory for mentorship rejected notification
  factory AppNotification.mentorshipRejected({
    required String requestId,
    required String alumniName,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.mentorshipRejected,
      title: 'Mentorship Request Response',
      body: '$alumniName has declined your mentorship request',
      data: {'requestId': requestId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.3: Factory for new message notification
  factory AppNotification.newMessage({
    required String chatId,
    required String senderName,
    required String messagePreview,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.newMessage,
      title: 'New Message from $senderName',
      body: messagePreview,
      data: {'chatId': chatId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.3: Factory for new job post notification
  factory AppNotification.newJobPost({
    required String opportunityId,
    required String title,
    required String company,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.newJobPost,
      title: 'New Job Opportunity',
      body: '$title at $company',
      data: {'opportunityId': opportunityId},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.4: Factory for mentor match recommendation
  factory AppNotification.mentorMatch({
    required String alumniId,
    required String alumniName,
    required int matchScore,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.mentorMatch,
      title: 'New Mentor Match',
      body: '$alumniName looks like a strong match ($matchScore%)',
      data: {'alumniId': alumniId, 'matchScore': matchScore},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.4: Factory for job match recommendation
  factory AppNotification.jobMatch({
    required String opportunityId,
    required String title,
    required String company,
    required int matchScore,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.jobMatch,
      title: 'New Job Match',
      body: '$title at $company ($matchScore% match)',
      data: {'opportunityId': opportunityId, 'matchScore': matchScore},
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// v7.4: Factory for engagement milestone
  factory AppNotification.engagementMilestone({
    required int streakDays,
    required String milestoneText,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.engagementMilestone,
      title: 'Engagement Milestone',
      body: '$milestoneText • $streakDays day streak',
      data: {'streakDays': streakDays},
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
      // v7.3: New type icons
      case NotificationType.mentorshipRequested:
        return 'school';
      case NotificationType.mentorshipAccepted:
        return 'handshake';
      case NotificationType.mentorshipRejected:
        return 'cancel';
      case NotificationType.newMessage:
        return 'message';
      case NotificationType.newJobPost:
        return 'work';
      case NotificationType.mentorMatch:
        return 'groups';
      case NotificationType.jobMatch:
        return 'recommend';
      case NotificationType.inactiveChatReminder:
        return 'chat';
      case NotificationType.engagementMilestone:
        return 'emoji_events';
      case NotificationType.recommendationDigest:
        return 'tips_and_updates';
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
