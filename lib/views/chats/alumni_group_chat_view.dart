import 'package:campusconnect/models/alumni_group_message.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/alumni_group_chat_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/loading_widget.dart';
import 'package:campusconnect/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CampusConnect v8.7 — AlumniGroupChatView
///
/// The shared Alumni Community group chat. A single group where verified
/// Alumni communicate with other Alumni in real time.
///
/// Features:
/// - Real-time Firestore message stream (oldest first)
/// - Own messages visually distinguished (right-aligned, primary color)
/// - Other messages show sender name + avatar + timestamp
/// - Empty / loading / error / sending states
/// - Automatic scroll to the latest message
///
/// Access is Alumni-only: entry points are role-gated and Firestore rules
/// deny Students/Teachers/unauthenticated users.
class AlumniGroupChatView extends StatefulWidget {
  const AlumniGroupChatView({super.key});

  @override
  State<AlumniGroupChatView> createState() => _AlumniGroupChatViewState();
}

class _AlumniGroupChatViewState extends State<AlumniGroupChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AlumniGroupChatProvider>();
    final profile = context.watch<ProfileProvider>().profile;

    // Auto-scroll to the latest message only when NEW messages arrive —
    // not on every rebuild (typing would otherwise fight the scroll).
    if (provider.messages.isNotEmpty &&
        provider.messages.length != _lastMessageCount) {
      _lastMessageCount = provider.messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
      appBar: AppBar(
        title: const Text('Alumni Community'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.gray900,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesBody(provider, profile?.uid ?? '', isDark),
          ),
          _buildMessageInput(provider, profile, isDark),
        ],
      ),
    );
  }

  Widget _buildMessagesBody(
    AlumniGroupChatProvider provider,
    String currentUserId,
    bool isDark,
  ) {
    if (provider.isLoading && !provider.isInitialized) {
      return const LoadingWidget(message: 'Loading community...');
    }

    if (provider.error != null && provider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: AppTheme.space16),
            Text(
              provider.error!,
              style: AppTheme.bodyLarge.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space24),
            ElevatedButton.icon(
              onPressed: () => provider.clearError(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.messages.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'No Messages Yet',
        subtitle:
            'Welcome to the Alumni Community!\n'
            'Be the first to start the conversation.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        final isMe = message.isFromUser(currentUserId);
        final showDateSeparator =
            index == 0 ||
            !_isSameDay(
              provider.messages[index - 1].createdAt,
              message.createdAt,
            );
        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(message.createdAt, isDark),
            _MessageBubble(message: message, isMe: isMe, isDark: isDark),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space6,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.gray200,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            dateText,
            style: AppTheme.caption.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _buildMessageInput(
    AlumniGroupChatProvider provider,
    StudentProfile? profile,
    bool isDark,
  ) {
    final canSend =
        !provider.isSending && _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  fillColor: isDark
                      ? AppTheme.darkSurfaceVariant
                      : AppTheme.gray100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space10,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
                maxLength: 1000,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            _SendButton(
              enabled: canSend,
              sending: provider.isSending,
              onPressed: () => _sendMessage(provider, profile),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(
    AlumniGroupChatProvider provider,
    StudentProfile? profile,
  ) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final uid = profile?.uid;
    final name = profile?.personal.effectiveDisplayName ?? 'Alumni';
    if (uid == null || uid.isEmpty) return;

    // Clear the input immediately for optimistic UX.
    _messageController.clear();
    setState(() {});

    final success = await provider.sendMessage(
      senderId: uid,
      senderName: name,
      message: text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to send message'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
      // Restore the text so the user doesn't lose their message.
      _messageController.text = text;
      setState(() {});
    }
  }
}

/// Circular send button with a busy spinner while sending.
class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback? onPressed;

  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 24,
      backgroundColor: enabled || sending
          ? theme.colorScheme.primary
          : AppTheme.gray400,
      child: sending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: enabled ? onPressed : null,
              tooltip: 'Send',
            ),
    );
  }
}

/// A single message bubble for the Alumni group chat.
class _MessageBubble extends StatelessWidget {
  final AlumniGroupMessage message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            InitialsAvatar(
              name: message.senderName,
              uid: message.senderId,
              size: 32,
            ),
            const SizedBox(width: AppTheme.space8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space14,
                vertical: AppTheme.space10,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : (isDark ? AppTheme.darkSurfaceVariant : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMedium),
                  topRight: const Radius.circular(AppTheme.radiusMedium),
                  bottomLeft: Radius.circular(isMe ? AppTheme.radiusMedium : 4),
                  bottomRight: Radius.circular(
                    isMe ? 4 : AppTheme.radiusMedium,
                  ),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Text(
                      message.senderName,
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                  ],
                  Text(
                    message.message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.gray900),
                      height: 1.35,
                    ),
                  ),
                  if (message.isEdited) ...[
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      'edited',
                      style: AppTheme.caption.copyWith(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : (isDark ? AppTheme.gray400 : AppTheme.gray500),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    message.formattedTime,
                    style: AppTheme.caption.copyWith(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : (isDark ? AppTheme.gray400 : AppTheme.gray500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: AppTheme.space8),
        ],
      ),
    );
  }
}
