import 'package:campusconnect/models/ai_interaction.dart';
import 'package:campusconnect/models/chat_message.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AIChatProvider extends ChangeNotifier {
  final AIService _aiService;
  final FirebaseFirestore _firestore;

  AIChatProvider({AIService? aiService, FirebaseFirestore? firestore})
    : _aiService = aiService ?? AIService.instance(),
      _firestore = firestore ?? FirebaseFirestore.instance;

  String? _userId;
  bool _isInitialized = false;
  bool _isSending = false;
  String? _error;
  bool _isDisposed = false;
  AIInteractionIntent _lastIntent = AIInteractionIntent.general;
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isInitialized => _isInitialized;
  bool get isSending => _isSending;
  String? get error => _error;
  AIInteractionIntent get lastIntent => _lastIntent;

  List<String> get quickPrompts => const [
    'Review my resume summary and suggest improvements.',
    'Suggest a career path for my current skills.',
    'Run a mock interview for a software role.',
    'What skills am I missing for internships?',
  ];

  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _userId == userId) return;
    _userId = userId;
    _isDisposed = false;
    _isInitialized = true;
    _error = null;
    notifyListeners();
    await _loadRecentInteractions();
  }

  Future<void> _loadRecentInteractions() async {
    if (_userId == null || _isDisposed) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('ai_interactions')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      if (_isDisposed) return;
      _messages.clear();
      final docs = snapshot.docs.reversed;
      for (final doc in docs) {
        final interaction = AIInteraction.fromFirestore(doc);
        _messages.add(
          ChatMessage(
            id: 'user_${interaction.id}',
            content: interaction.prompt,
            isUserMessage: true,
            timestamp: interaction.createdAt,
          ),
        );
        _messages.add(
          ChatMessage(
            id: 'ai_${interaction.id}',
            content: interaction.response,
            isUserMessage: false,
            timestamp: interaction.createdAt,
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('AIChatProvider._loadRecentInteractions error: $e');
    }
  }

  Future<AIResponse?> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isSending || _userId == null || _isDisposed) {
      return null;
    }

    _isSending = true;
    _error = null;
    _messages.add(ChatMessage.user(trimmed));
    notifyListeners();

    try {
      _lastIntent = _aiService.detectIntent(trimmed);
      final response = await _aiService.sendCareerAssistantMessage(
        userId: _userId!,
        message: trimmed,
      );

      if (_isDisposed) return null;
      _messages.add(ChatMessage.ai(response.message));
      await _saveInteraction(trimmed, response.message, _lastIntent);
      return response;
    } catch (e) {
      if (_isDisposed) return null;
      _error = 'Failed to get AI response';
      _messages.add(
        ChatMessage.ai(
          'I could not process that right now. Please try again in a moment.',
        ),
      );
      debugPrint('AIChatProvider.sendMessage error: $e');
      return null;
    } finally {
      _isSending = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> addLocalExchange({
    required String userMessage,
    required String aiMessage,
    AIInteractionIntent intent = AIInteractionIntent.general,
  }) async {
    if (_userId == null || _isDisposed) return;
    final userText = userMessage.trim();
    final aiText = aiMessage.trim();
    if (userText.isEmpty || aiText.isEmpty) return;

    _messages.add(ChatMessage.user(userText));
    _messages.add(ChatMessage.ai(aiText));
    notifyListeners();
    await _saveInteraction(userText, aiText, intent);
  }

  Future<void> _saveInteraction(
    String prompt,
    String response,
    AIInteractionIntent intent,
  ) async {
    if (_userId == null) return;
    try {
      final interaction = AIInteraction(
        id: '',
        userId: _userId!,
        prompt: prompt,
        response: response,
        intent: intent,
        createdAt: DateTime.now(),
        metadata: {'source': 'ai_chat_provider'},
      );

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('ai_interactions')
          .add(interaction.toFirestore());
    } catch (e) {
      debugPrint('AIChatProvider._saveInteraction error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _isDisposed = true;
    _userId = null;
    _isInitialized = false;
    _isSending = false;
    _error = null;
    _lastIntent = AIInteractionIntent.general;
    _messages.clear();
  }
}
