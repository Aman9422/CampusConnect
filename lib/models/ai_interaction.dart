/// Models for the AI chat history stored at `users/{uid}/ai_interactions`.
///
/// **v9.2.4 (D-7) — single-writer contract.**
/// The Cloud Function `askAI` (`functions/ai/chat.js`) is the ONLY writer of
/// `users/{uid}/ai_interactions`. It appends **one document per chat turn**:
///
/// ```js
/// // user turn
/// { role: "user",      message, timestamp: serverTimestamp(), status: "processed" }
/// // assistant turn
/// { role: "assistant", message, timestamp: serverTimestamp(),
///   isAIResponse: true, status: "delivered" }
/// ```
///
/// Before v9.2.4 the Flutter client *also* wrote its own documents with a
/// different schema (`prompt`/`response`/`intent`/`createdAt`), so every
/// exchange cost three writes and the retention sweep
/// (`functions/ai/chatDelete.js::cleanupExpiredAIConversations`, which filters
/// on `timestamp`) could never see the client's `createdAt` rows.
///
/// The client serialisation helpers (`toFirestore`) and the duplicate writer
/// were removed with this change. There is exactly one timestamp field —
/// `timestamp` — shared by the writer, the reader and the retention sweep.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// The user's detected intent for a chat message.
///
/// This is a **client-only** classification used to steer the prompt
/// (`AIService._withCareerIntentPrefix`). It is deliberately NOT persisted to
/// `ai_interactions` any more: the server schema has no `intent` field, and
/// keeping one writer means the schema is defined server-side.
enum AIInteractionIntent {
  resumeImprovement,
  careerPath,
  interviewPrep,
  skillGap,
  general,
}

/// The author of a single stored chat turn — mirrors the server's `role`.
enum AIChatRole {
  user,
  assistant;

  /// Parses the server-written `role` value. Unknown/missing values are
  /// treated as [AIChatRole.assistant] so an unrecognised document can never
  /// be rendered as if the student had typed it.
  static AIChatRole fromFirestoreValue(Object? value) {
    return value == 'user' ? AIChatRole.user : AIChatRole.assistant;
  }
}

/// One stored chat turn in the server's `ai_interactions` schema.
///
/// A single user↔assistant exchange is therefore **two** documents with the
/// same `timestamp` ordering field, which is exactly what `askAI` writes.
class AIInteraction {
  final String id;
  final AIChatRole role;
  final String message;
  final DateTime timestamp;
  final bool isAIResponse;
  final String status;

  const AIInteraction({
    required this.id,
    required this.role,
    required this.message,
    required this.timestamp,
    required this.isAIResponse,
    required this.status,
  });

  /// True when this turn was authored by the student.
  bool get isUserTurn => role == AIChatRole.user;

  /// Parses a document written by `askAI`.
  factory AIInteraction.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return AIInteraction.fromMap(id: doc.id, data: data);
  }

  /// Pure, storage-free parser for the server's `ai_interactions` schema.
  ///
  /// Split out of [AIInteraction.fromFirestore] so the tolerant field handling
  /// is directly unit-testable — `DocumentSnapshot` is a sealed class and so
  /// cannot be faked inside a `flutter test` process.
  ///
  /// Every field is read defensively: a partially-written document must never
  /// throw inside the history loader.
  factory AIInteraction.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final timestamp = data['timestamp'];
    return AIInteraction(
      id: id,
      role: AIChatRole.fromFirestoreValue(data['role']),
      message: data['message'] as String? ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isAIResponse: data['isAIResponse'] as bool? ?? false,
      status: data['status'] as String? ?? '',
    );
  }
}
