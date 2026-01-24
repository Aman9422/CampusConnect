import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// NotificationBadge - v6.4
///
/// AppBar action button with badge showing unread count.
class NotificationBadge extends StatelessWidget {
  final VoidCallback onTap;
  final Color? iconColor;

  const NotificationBadge({super.key, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;

        return IconButton(
          onPressed: onTap,
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(fontSize: 10),
            ),
            child: Icon(Icons.notifications_outlined, color: iconColor),
          ),
          tooltip: 'Notifications',
        );
      },
    );
  }
}

/// Animated notification badge that pulses when new notifications arrive
class AnimatedNotificationBadge extends StatefulWidget {
  final VoidCallback onTap;
  final Color? iconColor;

  const AnimatedNotificationBadge({
    super.key,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<AnimatedNotificationBadge> createState() =>
      _AnimatedNotificationBadgeState();
}

class _AnimatedNotificationBadgeState extends State<AnimatedNotificationBadge>
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

  void _checkForNewNotifications(int currentCount) {
    if (currentCount > _previousCount && _previousCount > 0) {
      _controller.forward().then((_) => _controller.reverse());
    }
    _previousCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;
        _checkForNewNotifications(unreadCount);

        return IconButton(
          onPressed: widget.onTap,
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(fontSize: 10),
              ),
              child: Icon(
                unreadCount > 0
                    ? Icons.notifications
                    : Icons.notifications_outlined,
                color: widget.iconColor,
              ),
            ),
          ),
          tooltip: unreadCount > 0
              ? '$unreadCount unread notifications'
              : 'Notifications',
        );
      },
    );
  }
}
