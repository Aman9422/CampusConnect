import 'dart:async';
import 'package:campusconnect/models/chat.dart';
import 'package:campusconnect/services/firestore/chat_service.dart';
import 'package:flutter/foundation.dart';

/// ChatProvider - v7.3: Real-time chat system
///
/// Manages chat state with proper lifecycle handling.
/// Provides real-time updates for chat list and messages.
/// Follows NotificationsProvider pattern EXACTLY for stream management.
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  ChatProvider({ChatService? service})
    : _chatService = service ?? ChatService.instance();

  // State
  List<Chat>? _chats;
  Map<String, List<Message>> _chatMessages = {}; // chatId -> messages
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSending = false;
  String? _error;
  bool _isDisposed = false;
  String? _userId;

  // Stream subscriptions
  StreamSubscription? _chatsSubscription;
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  // Getters
  List<Chat>? get chats => _chats;
  List<Message>? messagesForChat(String chatId) => _chatMessages[chatId];
  String? get userId => _userId; // Expose userId for UI
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isSending => _isSending;
  String? get error => _error;

  /// Get total unread count across all chats
  int get unreadCount {
    if (_chats == null || _userId == null) return 0;
    return _chats!.fold(0, (sum, chat) => sum + chat.unreadCountFor(_userId!));
  }

  /// Check if user has any unread messages
  bool get hasUnread => unreadCount > 0;

  /// Initialize with user ID (called after login)
  Future<void> initWithUser(String newUserId) async {
    if (_userId == newUserId && _isInitialized) {
      return; // Already initialized for this user
    }

    _userId = newUserId;
    _isDisposed = false;
    await _init();
  }

  /// Internal initialization
  Future<void> _init() async {
    if (_userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel existing subscription
      await _chatsSubscription?.cancel();

      // Start listening to chats stream
      _chatsSubscription = _chatService
          .getUserChatsStream(_userId!)
          .listen(
            (chats) {
              if (_isDisposed) return; // Safety check
              _chats = chats;
              _isLoading = false;
              _error = null;
              _isInitialized = true;
              notifyListeners();
            },
            onError: (error) {
              if (_isDisposed) return; // Safety check
              _error = 'Failed to load chats';
              _isLoading = false;
              debugPrint('Chats stream error: $error');
              notifyListeners();
            },
          );
    } catch (e) {
      if (_isDisposed) return; // Safety check
      _error = 'Failed to initialize chats';
      _isLoading = false;
      debugPrint('ChatProvider init error: $e');
      notifyListeners();
    }
  }

  /// Listen to messages for a specific chat
  /// Called when user opens a chat view
  void listenToChatMessages(String chatId) {
    // Don't create duplicate subscriptions
    if (_messageSubscriptions.containsKey(chatId)) return;
    if (_isDisposed) return;

    try {
      _messageSubscriptions[chatId] = _chatService
          .getMessagesStream(chatId)
          .listen(
            (messages) {
              if (_isDisposed) return; // Safety check
              _chatMessages[chatId] = messages;
              notifyListeners();
            },
            onError: (error) {
              if (_isDisposed) return; // Safety check
              debugPrint('Messages stream error for chat $chatId: $error');
            },
          );

      debugPrint('Started listening to messages for chat: $chatId');
    } catch (e) {
      debugPrint('Error starting messages stream: $e');
    }
  }

  /// Stop listening to messages for a specific chat
  /// Called when user leaves a chat view
  void stopListeningToChatMessages(String chatId) {
    final subscription = _messageSubscriptions[chatId];
    if (subscription != null) {
      subscription.cancel();
      _messageSubscriptions.remove(chatId);
      _chatMessages.remove(chatId); // Clear cached messages
      debugPrint('Stopped listening to messages for chat: $chatId');
    }
  }

  /// Send a message in a chat
  Future<bool> sendMessage(String chatId, String text) async {
    if (_userId == null || _isDisposed) return false;
    if (text.trim().isEmpty) return false;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      // Get chat to find sender name
      final chat = _chats?.firstWhere((c) => c.id == chatId);
      final senderName = chat?.participantNames[_userId] ?? 'User';

      await _chatService.sendMessage(
        chatId: chatId,
        senderId: _userId!,
        senderName: senderName,
        text: text.trim(),
      );

      _isSending = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false; // Safety check
      _isSending = false;
      _error = 'Failed to send message';
      debugPrint('Error sending message: $e');
      notifyListeners();
      return false;
    }
  }

  /// Mark a chat as read
  /// Called when user opens a chat view
  Future<void> markChatAsRead(String chatId) async {
    if (_userId == null || _isDisposed) return;

    try {
      await _chatService.markAsRead(chatId, _userId!);

      // Optimistic update
      if (_chats != null) {
        final index = _chats!.indexWhere((c) => c.id == chatId);
        if (index != -1) {
          final chat = _chats![index];
          final updatedUnreadCount = Map<String, int>.from(chat.unreadCount);
          updatedUnreadCount[_userId!] = 0;

          _chats![index] = chat.copyWith(unreadCount: updatedUnreadCount);
          notifyListeners();
        }
      }

      debugPrint('Marked chat as read: $chatId');
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
      // Stream will auto-correct if failed
    }
  }

  /// Get a chat by ID (from cache or service)
  Future<Chat?> getChatById(String chatId) async {
    try {
      // Check cache first
      if (_chats != null) {
        final cachedChat = _chats!.firstWhere(
          (c) => c.id == chatId,
          orElse: () => _chats!.first, // Dummy, will be caught
        );
        if (cachedChat.id == chatId) return cachedChat;
      }

      // Fetch from service
      return await _chatService.getChatById(chatId);
    } catch (e) {
      debugPrint('Error getting chat by ID: $e');
      return null;
    }
  }

  /// Refresh chats manually
  Future<void> refresh() async {
    if (_userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _chats = await _chatService.getUserChats(_userId!);
      _error = null;
    } catch (e) {
      if (_isDisposed) return; // Safety check
      _error = 'Failed to refresh chats';
      debugPrint('Refresh error: $e');
    } finally {
      _isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Reset state (called on logout) - CRITICAL pattern from NotificationsProvider
  void reset() {
    _isDisposed = true; // Set FIRST

    // Cancel chats subscription immediately and synchronously
    final chatsSubscription = _chatsSubscription;
    _chatsSubscription = null;
    chatsSubscription?.cancel();

    // Cancel all message subscriptions
    for (var sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    _messageSubscriptions.clear();

    // Clear all state
    _userId = null;
    _chats = null;
    _chatMessages = {};
    _isLoading = false;
    _isInitialized = false;
    _isSending = false;
    _error = null;

    // DON'T call notifyListeners() after setting _isDisposed
    // This prevents any further updates
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatsSubscription?.cancel();
    for (var sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
