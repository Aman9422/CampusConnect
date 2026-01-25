import 'dart:async';
import 'package:campusconnect/models/app_notification.dart';
import 'package:campusconnect/services/firestore/notifications_service.dart';
import 'package:flutter/foundation.dart';

/// NotificationsProvider - v6.4
///
/// Manages in-app notification state with proper lifecycle handling.
/// Provides real-time updates for notification count badge.
class NotificationsProvider extends ChangeNotifier {
  final NotificationsService _service;
  String? userId;

  NotificationsProvider({NotificationsService? service})
    : _service = service ?? NotificationsService.instance();

  // State
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  StreamSubscription? _notificationsSubscription;

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;
  bool get hasUnread => unreadCount > 0;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Initialize with user ID (called after login)
  Future<void> initWithUser(String newUserId) async {
    if (userId == newUserId && _isInitialized) {
      return;
    }

    userId = newUserId;
    _isDisposed = false;
    await _init();
  }

  /// Internal initialization
  Future<void> _init() async {
    if (userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel existing subscription
      await _notificationsSubscription?.cancel();

      // Start listening to notifications stream
      _notificationsSubscription = _service
          .getUserNotificationsStream(userId!)
          .listen(
            (notifications) {
              if (_isDisposed) return;
              _notifications = notifications;
              _isLoading = false;
              _error = null;
              _isInitialized = true;
              notifyListeners();
            },
            onError: (error) {
              if (_isDisposed) return;
              _error = 'Failed to load notifications';
              _isLoading = false;
              debugPrint('Notifications stream error: $error');
              notifyListeners();
            },
          );
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to initialize notifications';
      _isLoading = false;
      debugPrint('NotificationsProvider init error: $e');
      notifyListeners();
    }
  }

  /// Reset state (called on logout)
  void reset() {
    _isDisposed = true;

    // Cancel subscription immediately and synchronously clear reference
    final subscription = _notificationsSubscription;
    _notificationsSubscription = null;
    subscription?.cancel();

    userId = null;
    _notifications = [];
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    // Don't notify after dispose to prevent any further updates
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    if (userId == null || _isDisposed) return;

    try {
      await _service.markAsRead(userId!, notificationId);
      // Optimistic update
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
      // Stream will auto-correct if failed
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (userId == null || _isDisposed) return;

    try {
      await _service.markAllAsRead(userId!);
      // Optimistic update
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (userId == null || _isDisposed) return;

    try {
      await _service.deleteNotification(userId!, notificationId);
      // Optimistic update
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Delete all read notifications
  Future<void> clearReadNotifications() async {
    if (userId == null || _isDisposed) return;

    try {
      await _service.deleteReadNotifications(userId!);
      // Optimistic update
      _notifications.removeWhere((n) => n.isRead);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing read notifications: $e');
    }
  }

  /// Add notification locally (called when user performs action)
  Future<void> addNotification(AppNotification notification) async {
    if (userId == null || _isDisposed) return;

    try {
      await _service.createNotification(userId!, notification);
      // Stream will auto-update
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  /// Refresh notifications manually
  Future<void> refresh() async {
    if (userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _service.getUserNotificationsOnce(userId!);
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh notifications';
      debugPrint('Refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get notifications by type
  List<AppNotification> getByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
