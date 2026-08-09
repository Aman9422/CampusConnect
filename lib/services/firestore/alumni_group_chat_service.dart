import 'package:campusconnect/models/alumni_group_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.7 — AlumniGroupChatService
///
/// Firestore operations for the shared Alumni Group Chat.
///
/// Single collection: `alumni_group_messages/{messageId}`.
/// Security is enforced by `firestore.rules` (Alumni-only read/create,
/// `senderId == request.auth.uid`, own-message update/delete) — the client
/// never trusts a user-supplied sender id; the signed-in user's UID is always
/// passed from the authenticated session via the provider.
///
/// The message query orders by `createdAt` ASC — a single-field order that
/// needs no composite index (verified against firestore.indexes.json).
class AlumniGroupChatService {
  final FirebaseFirestore _firestore;

  AlumniGroupChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final AlumniGroupChatService _instance = AlumniGroupChatService();
  factory AlumniGroupChatService.instance() => _instance;

  CollectionReference get _messagesCollection =>
      _firestore.collection('alumni_group_messages');

  /// Real-time stream of group messages, oldest first.
  ///
  /// Soft-deleted messages are filtered client-side (a `where('isDeleted')`
  /// filter combined with `orderBy('createdAt')` would require a composite
  /// index; filtering here avoids it — Task §16).
  Stream<List<AlumniGroupMessage>> getMessagesStream() {
    return _messagesCollection
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlumniGroupMessage.fromFirestore(doc))
              .where((message) => !message.isDeleted)
              .toList(),
        );
  }

  /// Send a group message.
  ///
  /// [senderId] must be the authenticated user's UID (Firestore rules reject
  /// any other value). [createdAt] uses `FieldValue.serverTimestamp()` so the
  /// ordering timestamp comes from the server, never the client clock.
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String message,
  }) async {
    try {
      await _messagesCollection.add({
        'senderId': senderId,
        'senderName': senderName,
        if (senderPhotoUrl != null && senderPhotoUrl.isNotEmpty)
          'senderPhotoUrl': senderPhotoUrl,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });
      debugPrint('AlumniGroupChatService: message sent by $senderId');
    } catch (e) {
      debugPrint('AlumniGroupChatService: send error: $e');
      rethrow;
    }
  }

  /// Soft-delete a group message (own messages only — enforced by rules).
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'isDeleted': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('AlumniGroupChatService: deleted message $messageId');
    } catch (e) {
      debugPrint('AlumniGroupChatService: delete error: $e');
      rethrow;
    }
  }
}
