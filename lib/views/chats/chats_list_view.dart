import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/chat.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// ChatsListView - v7.3: Real-time chat system
///
/// Displays user's chat conversations with other participants.
/// Shows last message preview, timestamp, and unread count.
class ChatsListView extends StatelessWidget {
  const ChatsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              return TextButton(
                onPressed: () => provider.refresh(),
                child: const Text('Refresh'),
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          // Loading state
          if (provider.isLoading && !provider.isInitialized) {
            return const LoadingWidget(message: 'Loading conversations...');
          }

          // Error state
          if (provider.error != null &&
              (provider.chats == null || provider.chats!.isEmpty)) {
            return EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Something went wrong',
              subtitle: provider.error!,
              actionLabel: 'Retry',
              onAction: () => provider.refresh(),
            );
          }

          // Empty state
          if (provider.chats == null || provider.chats!.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              subtitle:
                  'Start a conversation by accepting a mentorship request!',
            );
          }

          // Chats list
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.chats!.length,
              itemBuilder: (context, index) {
                final chat = provider.chats![index];
                return _ChatTile(
                  chat: chat,
                  onTap: () => _handleChatTap(context, chat),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleChatTap(BuildContext context, Chat chat) {
    // Navigate to chat view
    Navigator.pushNamed(context, chatRoute, arguments: chat.id);
  }
}

/// Individual chat tile widget
class _ChatTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = context.watch<ChatProvider>();
    final userId = chatProvider.userId; // Exposed getter

    if (userId == null) {
      return const SizedBox.shrink(); // Safety check
    }

    final otherParticipantName =
        chat.getOtherParticipantName(userId) ?? 'Unknown';
    final unreadCount = chat.unreadCountFor(userId);
    final hasUnread = unreadCount > 0;

    // Get first letter for avatar
    final initial = otherParticipantName.isNotEmpty
        ? otherParticipantName[0].toUpperCase()
        : '?';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: hasUnread
            ? theme.colorScheme.primary.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        child: Text(
          initial,
          style: TextStyle(
            color: hasUnread ? theme.colorScheme.primary : Colors.grey[700],
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 20,
          ),
        ),
      ),
      title: Text(
        otherParticipantName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.lastMessage.length > 40
                ? '${chat.lastMessage.substring(0, 40)}...'
                : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread
                  ? theme.textTheme.bodyMedium?.color
                  : Colors.grey,
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chat.formattedTime,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: hasUnread
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(Icons.chevron_right, color: Colors.grey[400]),
      isThreeLine: true,
    );
  }
}
