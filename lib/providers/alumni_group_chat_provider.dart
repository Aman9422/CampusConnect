import 'dart:async';

import 'package:campusconnect/models/alumni_group_message.dart';
import 'package:campusconnect/services/firestore/alumni_group_chat_service.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v8.7 — AlumniGroupChatProvider
///
/// State management for the shared Alumni Group Chat.
///
/// Follows ChatProvider's lifecycle discipline exactly:
/// - real-time stream with a retained [StreamSubscription] that is cancelled
///   in [reset] / [dispose]
/// - `_isDisposed` guards so no listener survives logout
/// - `initWithUser` / `reset` pairing for the AuthGuard lifecycle
///
/// The provider is Alumni-only by construction — the UI entry points are
/// gated by role and the Firestore rules deny non-Alumni read/write. If
/// rules deny an Alumni access (should not happen), the stream surfaces an
/// error state in the view.
class AlumniGroupChatProvider extends ChangeNotifier {
  final AlumniGroupChatService _service;

  AlumniGroupChatProvider({AlumniGroupChatService? service})
    : _service = service ?? AlumniGroupChatService.instance();

  // State
  List<AlumniGroupMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSending = false;
  String? _error;
  bool _isDisposed = false;
  String? _userId;

  // Stream subscription
  StreamSubscription<List<AlumniGroupMessage>>? _messagesSubscription;

  // Getters
  List<AlumniGroupMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get userId => _userId;

  /// Initialize with the authenticated user (called after login).
  Future<void> initWithUser(String newUserId) async {
    if (_userId == newUserId && _isInitialized) {
      return; // Already initialized for this user
    }

    _isDisposed = false;
    _userId = newUserId;
    await _init();
  }

  Future<void> _init() async {
    if (_userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel any previous subscription before starting a fresh one.
      await _messagesSubscription?.cancel();
      _messagesSubscription = _service.getMessagesStream().listen(
        (messages) {
          if (_isDisposed) return;
          _messages = messages;
          _isLoading = false;
          _error = null;
          _isInitialized = true;
          notifyListeners();
        },
        onError: (Object error) {
          if (_isDisposed) return;
          _error = 'Failed to load alumni messages';
          _isLoading = false;
          debugPrint('AlumniGroupChatProvider stream error: $error');
          notifyListeners();
        },
      );
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to initialize alumni chat';
      _isLoading = false;
      debugPrint('AlumniGroupChatProvider init error: $e');
      notifyListeners();
    }
  }

  /// Send a message to the group.
  ///
  /// [senderName] is the alumni's display name; [senderId] is the
  /// authenticated user's UID (rules enforce `senderId == request.auth.uid`).
  Future<bool> sendMessage({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String message,
  }) async {
    final text = message.trim();
    if (_userId == null) return false;
    if (_isDisposed) return false;
    if (text.isEmpty) return false;
    if (_isSending) return false;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      await _service.sendMessage(
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        message: text,
      );
      _isSending = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _isSending = false;
      _error = 'Failed to send message';
      debugPrint('AlumniGroupChatProvider send error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Soft-delete one of the current user's own messages.
  Future<bool> deleteMessage(String messageId) async {
    if (_userId == null || _isDisposed) return false;

    try {
      await _service.deleteMessage(messageId);
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _error = 'Failed to delete message';
      debugPrint('AlumniGroupChatProvider delete error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clear any transient error state (e.g. after retrying).
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset state (called on logout) — cancels the stream subscription.
  void reset() {
    _isDisposed = true; // Set FIRST so no late stream event re-notifies.

    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _messages = [];
    _isLoading = false;
    _isInitialized = false;
    _isSending = false;
    _error = null;
    _userId = null;

    // No notifyListeners() — provider is disposed for this session.
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
