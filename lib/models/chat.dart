import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat - v7.3: Real-time chat system
///
/// Represents a chat conversation between two users (Student ↔ Alumni).
/// Follows Opportunity model patterns for Firestore serialization.
class Chat {
  final String id;
  final List<String> participantIds; // [studentId, alumniId]
  final Map<String, String> participantNames; // {userId: displayName}
  final String? relatedMentorshipId;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final Map<String, int> unreadCount; // {userId: count}

  Chat({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.createdAt,
    required this.unreadCount,
    this.relatedMentorshipId,
  });

  /// Create from Firestore document
  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Chat(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      relatedMentorshipId: data['relatedMentorshipId'] as String?,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'participantIds': participantIds,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCount': unreadCount,
    };

    // Optional fields
    if (relatedMentorshipId != null) {
      map['relatedMentorshipId'] = relatedMentorshipId;
    }

    return map;
  }

  /// Copy with method for updates
  Chat copyWith({
    List<String>? participantIds,
    Map<String, String>? participantNames,
    String? relatedMentorshipId,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    Map<String, int>? unreadCount,
  }) {
    return Chat(
      id: id,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      relatedMentorshipId: relatedMentorshipId ?? this.relatedMentorshipId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Get the other participant's ID (not current user)
  String? getOtherParticipantId(String currentUserId) {
    try {
      return participantIds.firstWhere((id) => id != currentUserId);
    } catch (e) {
      return null;
    }
  }

  /// Get the other participant's name (not current user)
  String? getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    if (otherId == null) return null;
    return participantNames[otherId];
  }

  /// Get unread count for specific user
  int unreadCountFor(String userId) {
    return unreadCount[userId] ?? 0;
  }

  /// Check if user has unread messages
  bool hasUnreadFor(String userId) {
    return unreadCountFor(userId) > 0;
  }

  /// Get time since last message
  String get timeSince {
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted date/time for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inDays == 0) {
      // Today: show time
      final hour = lastMessageAt.hour % 12 == 0 ? 12 : lastMessageAt.hour % 12;
      final minute = lastMessageAt.minute.toString().padLeft(2, '0');
      final period = lastMessageAt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastMessageAt.day}/${lastMessageAt.month}/${lastMessageAt.year}';
    }
  }
}

/// Message - v7.3: Real-time chat message
///
/// Represents a single message in a chat conversation.
/// Stored in subcollection: chats/{chatId}/messages/{messageId}
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isRead;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isRead = false,
  });

  /// Create from Firestore document
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Message(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
    };
  }

  /// Copy with method for updates
  Message copyWith({
    String? chatId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return Message(
      id: id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Check if message is from specific user
  bool isFromUser(String userId) {
    return senderId == userId;
  }

  /// Get time since message was sent
  String get timeSince {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted time for message bubble
  String get formattedTime {
    final hour = sentAt.hour % 12 == 0 ? 12 : sentAt.hour % 12;
    final minute = sentAt.minute.toString().padLeft(2, '0');
    final period = sentAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Get full date-time format
  String get fullDateTime {
    return '${sentAt.day}/${sentAt.month}/${sentAt.year} $formattedTime';
  }
}
