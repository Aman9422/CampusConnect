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

  /// v9.2.4 (D-7): how many stored *turns* to load from the server schema.
  ///
  /// `askAI` writes TWO documents per exchange (one `role: 'user'`, one
  /// `role: 'assistant'`), so 20 turns ≈ 10 exchanges — the same history depth
  /// the previous 8-exchange client-side read provided, now read from the
  /// server's single writer instead of the removed client mirror.
  static const int _historyTurnCount = 20;

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

  /// v9.2.4 (D-7): loads history from the SERVER schema only.
  ///
  /// `askAI` stores ONE document per chat turn (`role` = `user` | `assistant`)
  /// with a single `timestamp` field. The newest [_historyTurnCount] *turns*
  /// are fetched ordered by `timestamp` (descending) and then reversed into
  /// chronological order so the transcript reads top-to-bottom.
  ///
  /// The previous implementation ordered by `createdAt` — a field that only
  /// the removed client-side writer emitted — so it could not see the server's
  /// own documents at all. Reading `timestamp` here matches the writer AND the
  /// retention sweep (`functions/ai/chatDelete.js`), which filters on
  /// `timestamp`.
  Future<void> _loadRecentInteractions() async {
    if (_userId == null || _isDisposed) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('ai_interactions')
          .orderBy('timestamp', descending: true)
          .limit(_historyTurnCount)
          .get();

      if (_isDisposed) return;
      _messages.clear();
      for (final doc in snapshot.docs.reversed) {
        final interaction = AIInteraction.fromFirestore(doc);
        if (interaction.message.isEmpty) continue;
        _messages.add(
          ChatMessage(
            id: interaction.id,
            content: interaction.message,
            isUserMessage: interaction.isUserTurn,
            timestamp: interaction.timestamp,
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
      // v9.2.4 (D-7): no client-side persistence. `askAI` has already written
      // the user turn and this assistant turn to `users/{uid}/ai_interactions`
      // (schema: role/message/timestamp), so writing a third document here
      // would duplicate every exchange and re-introduce the second schema
      // (`createdAt`) the retention sweep cannot see.
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
    _lastIntent = intent;
    notifyListeners();
    // v9.2.4 (D-7): deliberately NOT persisted. These are locally-generated
    // exchanges (client-side eligibility answers, and the local error
    // fallback) that never reach `askAI`, so there is no server document to
    // mirror. Keeping them visible in-session only is the cost of having a
    // single writer; writing them here would re-create a second schema in
    // `ai_interactions`. See docs/v9_2_4_hardening_report.md.
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
