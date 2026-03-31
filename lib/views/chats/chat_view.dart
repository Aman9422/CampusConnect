import 'package:campusconnect/models/chat.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/views/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// ChatView - v7.3: Real-time chat system
///
/// Displays conversation messages between two users.
/// Real-time message updates with proper bubble UI.
class ChatView extends StatefulWidget {
  final String chatId;

  const ChatView({super.key, required this.chatId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Chat? _chat;
  late ChatProvider _chatProvider; // Store provider reference for safe disposal

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>(); // Save provider reference
    _initChat();
  }

  Future<void> _initChat() async {
    // Start listening to messages for this chat
    _chatProvider.listenToChatMessages(widget.chatId);

    // Mark chat as read
    await _chatProvider.markChatAsRead(widget.chatId);

    // Get chat details
    _chat = await _chatProvider.getChatById(widget.chatId);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // Stop listening to messages when leaving chat - use stored reference
    _chatProvider.stopListeningToChatMessages(widget.chatId);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = context.watch<ChatProvider>();

    // Get user ID from provider (we'll need to add a getter)
    // For now, use chat to get current user
    String? currentUserId;
    if (_chat != null && chatProvider.chats != null) {
      // Find current user from chats list
      final userChats = chatProvider.chats!;
      if (userChats.isNotEmpty) {
        final firstChat = userChats.first;
        // Compare participants to find which one we are
        // This is a workaround - better to expose userId from provider
        currentUserId = firstChat.participantIds.first; // Placeholder
      }
    }

    final otherParticipantName = _chat != null && currentUserId != null
        ? _chat!.getOtherParticipantName(currentUserId)
        : 'Loading...';

    return Scaffold(
      appBar: AppBar(
        title: Text(otherParticipantName ?? 'Chat'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(child: _buildMessagesList(chatProvider, currentUserId)),
          // Message input
          _buildMessageInput(theme, chatProvider),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatProvider provider, String? userId) {
    final messages = provider.messagesForChat(widget.chatId);

    if (messages == null) {
      return const LoadingWidget(message: 'Loading messages...');
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Auto-scroll to bottom when new message arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = userId != null && message.isFromUser(userId);

        // Show date separator if it's a new day
        final showDateSeparator =
            index == 0 ||
            !_isSameDay(messages[index - 1].sentAt, message.sentAt);

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.sentAt),
            _MessageBubble(message: message, isMe: isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    String dateText;
    if (difference.inDays == 0) {
      dateText = 'Today';
    } else if (difference.inDays == 1) {
      dateText = 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dateText = weekdays[date.weekday - 1];
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildMessageInput(ThemeData theme, ChatProvider provider) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: provider.isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendMessage(provider),
                      padding: EdgeInsets.zero,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(ChatProvider provider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately
    _messageController.clear();

    // Send message
    final success = await provider.sendMessage(widget.chatId, text);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          duration: Duration(seconds: 2),
        ),
      );

      // Restore text if failed
      _messageController.text = text;
    }
  }
}

/// Individual message bubble widget
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
