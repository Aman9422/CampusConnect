import 'package:cloud_firestore/cloud_firestore.dart';

enum AIInteractionIntent {
  resumeImprovement,
  careerPath,
  interviewPrep,
  skillGap,
  general,
}

class AIInteraction {
  final String id;
  final String userId;
  final String prompt;
  final String response;
  final AIInteractionIntent intent;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const AIInteraction({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.response,
    required this.intent,
    required this.createdAt,
    this.metadata,
  });

  factory AIInteraction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIInteraction(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      prompt: data['prompt'] as String? ?? '',
      response: data['response'] as String? ?? '',
      intent: _parseIntent(data['intent'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'prompt': prompt,
      'response': response,
      'intent': intent.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata ?? <String, dynamic>{},
    };
  }

  static AIInteractionIntent _parseIntent(String? value) {
    switch (value) {
      case 'resumeImprovement':
        return AIInteractionIntent.resumeImprovement;
      case 'careerPath':
        return AIInteractionIntent.careerPath;
      case 'interviewPrep':
        return AIInteractionIntent.interviewPrep;
      case 'skillGap':
        return AIInteractionIntent.skillGap;
      case 'general':
      default:
        return AIInteractionIntent.general;
    }
  }
}
