import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  final String id;
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUserMessage: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.ai(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUserMessage: false,
      timestamp: DateTime.now(),
    );
  }
}
