import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/constants/routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// ChatBadge - v7.3: Real-time chat system
///
/// AppBar action button with badge showing unread chat count.
/// Follows NotificationBadge pattern exactly.
class ChatBadge extends StatelessWidget {
  final Color? iconColor;

  const ChatBadge({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;

        return IconButton(
          onPressed: () => Navigator.pushNamed(context, chatsListRoute),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(fontSize: 10),
            ),
            child: Icon(
              unreadCount > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: iconColor,
            ),
          ),
          tooltip: unreadCount > 0
              ? '$unreadCount unread messages'
              : 'Messages',
        );
      },
    );
  }
}

/// Animated chat badge that pulses when new messages arrive
/// Follows AnimatedNotificationBadge pattern exactly
class AnimatedChatBadge extends StatefulWidget {
  final Color? iconColor;

  const AnimatedChatBadge({super.key, this.iconColor});

  @override
  State<AnimatedChatBadge> createState() => _AnimatedChatBadgeState();
}

class _AnimatedChatBadgeState extends State<AnimatedChatBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkForNewMessages(int currentCount) {
    if (currentCount > _previousCount && _previousCount > 0) {
      _controller.forward().then((_) => _controller.reverse());
    }
    _previousCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;
        _checkForNewMessages(unreadCount);

        return IconButton(
          onPressed: () => Navigator.pushNamed(context, chatsListRoute),
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(fontSize: 10),
              ),
              child: Icon(
                unreadCount > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: widget.iconColor,
              ),
            ),
          ),
          tooltip: unreadCount > 0
              ? '$unreadCount unread messages'
              : 'Messages',
        );
      },
    );
  }
}
