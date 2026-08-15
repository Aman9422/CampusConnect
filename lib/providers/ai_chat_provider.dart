import 'package:campusconnect/models/ai_interaction.dart';
import 'package:campusconnect/models/chat_message.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      // v8.8.3 (MED-3): surface the mapped friendly error text instead of the
      // canned message — `AIService.sendMessage` already converts callable
      // codes (unauthenticated / limit / timeout / unavailable) into readable
      // copy, so the user should see WHY the request failed.
      final friendlyError = ErrorMessages.getUserFriendlyMessage(e);
      _error = friendlyError;
      _messages.add(ChatMessage.ai(friendlyError));
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

  /// v8.8 (P5): Delete the user's entire AI chat history.
  ///
  /// Calls the `deleteAIHistory` Cloud Function, which removes BOTH the
  /// client-facing `users/{uid}/ai_interactions` subcollection AND the legacy
  /// `ai_conversations` store — owner-scoped server-side via
  /// `request.auth.uid` (a client-supplied userId is never trusted).
  /// After the server confirms, the in-memory chat is cleared immediately and
  /// the history view reflects the empty state.
  ///
  /// Returns true on success, false on failure.
  Future<bool> deleteHistory() async {
    if (_userId == null || _isDisposed) return false;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteAIHistory',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      // v8.8.1 (regression fix): call without the generic type parameter. The
      // callable SDK decodes the response as `Map<Object?, Object?>`; the old
      // `.call<Map<String, dynamic>>({})` downcast throws
      // `_Map<Object?, Object?> is not a subtype of type Map<String, dynamic>`
      // (same bug as AIService.sendMessage — see ai_service.dart). The
      // `{deleted: n}` body is intentionally ignored.
      // v8.8.3 (MED-8): the callable now has a 120 s client timeout matching
      // the server's deleteAIHistory timeout (large histories delete in
      // batches server-side; the default 60 s SDK timeout could abort it).
      await callable.call({}).timeout(const Duration(seconds: 120));
    } catch (e) {
      debugPrint('AIChatProvider.deleteHistory error: $e');
      return false;
    }

    if (_isDisposed) return false;
    _messages.clear();
    notifyListeners();
    // Reload from Firestore — should be empty, keeps provider state honest.
    await _loadRecentInteractions();
    return true;
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
