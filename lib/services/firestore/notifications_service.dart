import 'package:campusconnect/models/app_notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// NotificationsService - Handles all Firestore operations for notifications
///
/// v6.4: In-app notifications for placements and announcements
///
/// Firestore Structure:
/// - User notifications: users/{uid}/notifications/{notificationId}
/// - Announcements: announcements/{announcementId} (read-only for users)
class NotificationsService {
  final FirebaseFirestore _firestore;

  NotificationsService(this._firestore);

  factory NotificationsService.instance() {
    return NotificationsService(FirebaseFirestore.instance);
  }

  /// Get reference to user's notifications collection
  CollectionReference _getUserNotificationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  /// Get user notifications as a stream (real-time updates)
  Stream<List<AppNotification>> getUserNotificationsStream(String userId) {
    return _getUserNotificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit to last 50 notifications
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .where((n) => !n.isExpired) // Filter out expired
              .toList();
        });
  }

  /// Get user notifications once (one-time fetch)
  Future<List<AppNotification>> getUserNotificationsOnce(String userId) async {
    try {
      final snapshot = await _getUserNotificationsRef(
        userId,
      ).orderBy('createdAt', descending: true).limit(50).get();

      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((n) => !n.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      rethrow;
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _getUserNotificationsRef(
        userId,
      ).where('isRead', isEqualTo: false).get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Create a notification for user
  Future<void> createNotification(
    String userId,
    AppNotification notification,
  ) async {
    try {
      await _getUserNotificationsRef(userId).add(notification.toFirestore());
      debugPrint('Notification created for user: $userId');
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _getUserNotificationsRef(
        userId,
      ).doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _getUserNotificationsRef(
        userId,
      ).where('isRead', isEqualTo: false).get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('Marked ${snapshot.docs.length} notifications as read');
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _getUserNotificationsRef(userId).doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Delete all read notifications (cleanup)
  Future<void> deleteReadNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _getUserNotificationsRef(
        userId,
      ).where('isRead', isEqualTo: true).get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Deleted ${snapshot.docs.length} read notifications');
    } catch (e) {
      debugPrint('Error deleting read notifications: $e');
      rethrow;
    }
  }

  // NOTE (removed dead code): getAnnouncementsStream() was removed — no view
  // ever called it. Announcements are served through user-level notifications
  // (type: announcement). If a dedicated announcements board is needed later,
  // recreate it (and add the composite index: announcements: isActive ↑
  // createdAt ↓).

  // ============================================
  // HELPER METHODS FOR PLACEMENT NOTIFICATIONS
  // ============================================

  /// Create notification when user applies for placement
  Future<void> notifyPlacementApplied({
    required String userId,
    required String placementId,
    required String company,
    required String role,
  }) async {
    final notification = AppNotification.placementApplied(
      placementId: placementId,
      company: company,
      role: role,
    );
    await createNotification(userId, notification);
  }

  /// Create notification when application status changes
  Future<void> notifyStatusChange({
    required String userId,
    required String placementId,
    required String company,
    required String role,
    required String status,
  }) async {
    final notification = AppNotification.statusChange(
      placementId: placementId,
      company: company,
      role: role,
      status: status,
    );
    await createNotification(userId, notification);
  }
}
