import 'package:campusconnect/models/chat.dart';
import 'package:campusconnect/models/app_notification.dart'; // v7.3
import 'package:campusconnect/services/firestore/notifications_service.dart'; // v7.3
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ChatService - v7.3: Real-time chat system
///
/// Handles all Firestore operations for chat conversations and messages.
/// Enables Student ↔ Alumni messaging after mentorship acceptance.
/// Follows OpportunityService pattern with streams for real-time updates.
class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final ChatService _instance = ChatService();
  factory ChatService.instance() => _instance;

  // Collection reference
  CollectionReference get _chatsCollection => _firestore.collection('chats');

  /// Create a new chat conversation
  /// Called when mentorship request is accepted
  Future<String> createChat({
    required String studentId,
    required String alumniId,
    required String studentName,
    required String alumniName,
    String? mentorshipId,
  }) async {
    try {
      // Generate document ID
      final docRef = _chatsCollection.doc();

      final chat = Chat(
        id: docRef.id,
        participantIds: [studentId, alumniId],
        participantNames: {studentId: studentName, alumniId: alumniName},
        relatedMentorshipId: mentorshipId,
        lastMessage: 'Chat created',
        lastMessageSenderId: studentId,
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        unreadCount: {studentId: 0, alumniId: 0},
      );

      await docRef.set(chat.toFirestore());
      debugPrint('Chat created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  /// Get user's chat conversations as stream (real-time updates)
  Stream<List<Chat>> getUserChatsStream(String userId) {
    return _chatsCollection
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList(),
        );
  }

  /// Get user's chats once (no real-time updates)
  Future<List<Chat>> getUserChats(String userId) async {
    try {
      final query = await _chatsCollection
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .get();

      return query.docs.map((doc) => Chat.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user chats: $e');
      return [];
    }
  }

  /// Get messages for a chat as stream (real-time updates)
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy(
          'sentAt',
          descending: false,
        ) // Chronological order (oldest first)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList(),
        );
  }

  /// Get messages once (no real-time updates)
  Future<List<Message>> getMessages(String chatId, {int limit = 50}) async {
    try {
      final query = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: false)
          .limit(limit)
          .get();

      return query.docs.map((doc) => Message.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Send a message in a chat
  /// Updates both the chat document and creates a message in subcollection
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      // Use batch write for atomic operation
      final batch = _firestore.batch();

      // Create message in subcollection
      final messageRef = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc();

      final message = Message(
        id: messageRef.id,
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        text: text,
        sentAt: DateTime.now(),
        isRead: false,
      );

      batch.set(messageRef, message.toFirestore());

      // Update chat document with last message info
      final chatRef = _chatsCollection.doc(chatId);

      // Get current chat to update unread counts
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        throw Exception('Chat not found');
      }

      final chat = Chat.fromFirestore(chatDoc);

      // Increment unread count for other participant
      final otherParticipantId = chat.getOtherParticipantId(senderId);
      final updatedUnreadCount = Map<String, int>.from(chat.unreadCount);

      if (otherParticipantId != null) {
        updatedUnreadCount[otherParticipantId] =
            (updatedUnreadCount[otherParticipantId] ?? 0) + 1;
      }

      batch.update(chatRef, {
        'lastMessage': text,
        'lastMessageSenderId': senderId,
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'unreadCount': updatedUnreadCount,
      });

      await batch.commit();

      // v7.3: Notify recipient of new message
      try {
        final chat = Chat.fromFirestore(chatDoc);
        final recipientId = chat.getOtherParticipantId(senderId);
        if (recipientId != null) {
          final notificationService = NotificationsService.instance();
          final messagePreview = text.length > 50
              ? '${text.substring(0, 50)}...'
              : text;

          await notificationService.createNotification(
            recipientId,
            AppNotification.newMessage(
              chatId: chatId,
              senderName: senderName,
              messagePreview: messagePreview,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error creating message notification: $e');
        // Don't fail message sending if notification fails
      }

      debugPrint('Message sent in chat: $chatId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Mark all messages in a chat as read for a specific user
  /// Resets unread count to 0
  Future<void> markAsRead(String chatId, String userId) async {
    try {
      final chatRef = _chatsCollection.doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        debugPrint('Chat not found: $chatId');
        return;
      }

      final chat = Chat.fromFirestore(chatDoc);
      final updatedUnreadCount = Map<String, int>.from(chat.unreadCount);
      updatedUnreadCount[userId] = 0;

      await chatRef.update({'unreadCount': updatedUnreadCount});

      debugPrint('Chat marked as read: $chatId for user: $userId');
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
      rethrow;
    }
  }

  /// Get a specific chat by ID
  Future<Chat?> getChatById(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();

      if (!doc.exists) {
        return null;
      }

      return Chat.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting chat by ID: $e');
      return null;
    }
  }

  /// Get chat by mentorship request ID
  /// Useful for navigating from mentorship to chat
  Future<Chat?> getChatByMentorshipId(String mentorshipId) async {
    try {
      final query = await _chatsCollection
          .where('relatedMentorshipId', isEqualTo: mentorshipId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      return Chat.fromFirestore(query.docs.first);
    } catch (e) {
      debugPrint('Error getting chat by mentorship ID: $e');
      return null;
    }
  }

  /// Check if a chat exists between two users
  Future<Chat?> getChatBetweenUsers(String userId1, String userId2) async {
    try {
      final query = await _chatsCollection
          .where('participantIds', arrayContains: userId1)
          .get();

      for (final doc in query.docs) {
        final chat = Chat.fromFirestore(doc);
        if (chat.participantIds.contains(userId2)) {
          return chat;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting chat between users: $e');
      return null;
    }
  }

  /// Get total unread count for a user across all chats
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final chats = await getUserChats(userId);
      int totalUnread = 0;

      for (final chat in chats) {
        totalUnread += chat.unreadCountFor(userId);
      }

      return totalUnread;
    } catch (e) {
      debugPrint('Error getting total unread count: $e');
      return 0;
    }
  }

  /// Delete a chat conversation (and all its messages)
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();

      for (final messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      // Delete chat document
      batch.delete(_chatsCollection.doc(chatId));

      await batch.commit();
      debugPrint('Chat deleted: $chatId');
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      rethrow;
    }
  }
}
