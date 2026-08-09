import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.7 — Alumni Group Chat message.
///
/// A single message in the shared Alumni Group Chat collection
/// `alumni_group_messages/{messageId}`.
///
/// Field contract (enforced by Firestore rules):
/// - [senderId]     — MUST equal `request.auth.uid` at write time.
/// - [senderName]   — display name of the sender (denormalized).
/// - [senderPhotoUrl] — optional avatar URL.
/// - [message]      — the message body.
/// - [createdAt]    — server timestamp.
/// - [editedAt]     — optional, set when the sender edits the message.
/// - [isDeleted]    — optional soft-delete flag.
class AlumniGroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String message;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  const AlumniGroupMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.message,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
  });

  /// Create from a Firestore document snapshot.
  factory AlumniGroupMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return AlumniGroupMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  /// Convert to a Firestore document map.
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      if (senderPhotoUrl != null && senderPhotoUrl!.isNotEmpty)
        'senderPhotoUrl': senderPhotoUrl,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      'isDeleted': isDeleted,
    };
  }

  /// Copy with named parameter overrides.
  AlumniGroupMessage copyWith({
    String? senderName,
    String? senderPhotoUrl,
    String? message,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return AlumniGroupMessage(
      id: id,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// True when this message was sent by the given user.
  bool isFromUser(String userId) => senderId == userId;

  /// True when the message has been edited since creation.
  bool get isEdited => editedAt != null;

  /// Formatted time for message bubbles (e.g. "3:45 PM").
  String get formattedTime {
    final hour = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Compact relative time (e.g. "5m ago", "2h ago", "Jan 3").
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      if (difference.inDays >= 7) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${createdAt.day} ${months[createdAt.month - 1]}';
      }
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
