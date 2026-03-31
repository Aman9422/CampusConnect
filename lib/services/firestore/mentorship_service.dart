import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/models/app_notification.dart'; // v7.3
import 'package:campusconnect/services/firestore/chat_service.dart'; // v7.3
import 'package:campusconnect/services/firestore/notifications_service.dart'; // v7.3
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// MentorshipService - v7.2: Multi-role ecosystem
///
/// Handles all Firestore operations for mentorship requests.
/// Follows ProfileService pattern with strict UID-based access.
class MentorshipService {
  final FirebaseFirestore _firestore;

  MentorshipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final MentorshipService _instance = MentorshipService();
  factory MentorshipService.instance() => _instance;

  // Collection reference
  CollectionReference get _mentorshipRequestsCollection =>
      _firestore.collection('mentorship_requests');

  /// Student Operations
  /// Create a new mentorship request
  Future<String> createRequest({
    required String studentId,
    required String alumniId,
    required String title,
    required String description,
    required List<String> skills,
    required StudentProfile studentProfile,
    required StudentProfile alumniProfile,
  }) async {
    try {
      // Generate document ID
      final docRef = _mentorshipRequestsCollection.doc();

      final request = MentorshipRequest(
        id: docRef.id,
        studentId: studentId,
        alumniId: alumniId,
        title: title,
        description: description,
        skills: skills,
        status: MentorshipRequestStatus.pending,
        createdAt: DateTime.now(),
        studentName: studentProfile.personal.effectiveDisplayName,
        studentEmail: studentProfile.personal.email,
        alumniName: alumniProfile.personal.effectiveDisplayName,
        alumniCompany: alumniProfile.company,
        alumniJobRole: alumniProfile.jobRole,
      );

      await docRef.set(request.toFirestore());

      // v7.3: Notify alumni of new mentorship request
      try {
        final notificationService = NotificationsService.instance();
        await notificationService.createNotification(
          alumniId,
          AppNotification.mentorshipRequested(
            requestId: docRef.id,
            studentName: studentProfile.personal.effectiveDisplayName,
          ),
        );
      } catch (e) {
        debugPrint('Error creating mentorship request notification: $e');
        // Don't fail the request if notification fails
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating mentorship request: $e');
      rethrow;
    }
  }

  /// Get mentorship requests sent by a specific student
  Future<List<MentorshipRequest>> getStudentRequests(String studentId) async {
    try {
      final query = await _mentorshipRequestsCollection
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => MentorshipRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting student requests: $e');
      return [];
    }
  }

  /// Alumni Operations
  /// Get pending mentorship requests for a specific alumni
  Future<List<MentorshipRequest>> getPendingRequestsForAlumni(
    String alumniId,
  ) async {
    try {
      final query = await _mentorshipRequestsCollection
          .where('alumniId', isEqualTo: alumniId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => MentorshipRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending requests for alumni: $e');
      return [];
    }
  }

  /// Get all mentorship requests for a specific alumni (all statuses)
  Future<List<MentorshipRequest>> getAllRequestsForAlumni(
    String alumniId,
  ) async {
    try {
      final query = await _mentorshipRequestsCollection
          .where('alumniId', isEqualTo: alumniId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => MentorshipRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all requests for alumni: $e');
      return [];
    }
  }

  /// Alumni responds to a mentorship request
  /// v7.3: Creates chat conversation if accepted
  Future<String?> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
  }) async {
    try {
      final status = accepted
          ? MentorshipRequestStatus.accepted
          : MentorshipRequestStatus.rejected;

      final updateData = <String, dynamic>{
        'status': status.value,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (responseMessage != null && responseMessage.isNotEmpty) {
        updateData['responseMessage'] = responseMessage;
      }

      // v7.3: Create chat if accepted
      String? chatId;
      if (accepted) {
        final request = await getRequestById(requestId);
        if (request != null) {
          // Import ChatService at top of file
          final chatService = ChatService.instance();
          chatId = await chatService.createChat(
            studentId: request.studentId,
            alumniId: request.alumniId,
            studentName: request.studentName,
            alumniName: request.alumniName,
            mentorshipId: requestId,
          );
          updateData['chatId'] = chatId;
        }
      }

      await _mentorshipRequestsCollection.doc(requestId).update(updateData);

      // v7.3: Notify student of response
      try {
        final request = await getRequestById(requestId);
        if (request != null) {
          final notificationService = NotificationsService.instance();

          if (accepted && chatId != null) {
            await notificationService.createNotification(
              request.studentId,
              AppNotification.mentorshipAccepted(
                requestId: requestId,
                alumniName: request.alumniName,
                chatId: chatId,
              ),
            );
          } else if (!accepted) {
            await notificationService.createNotification(
              request.studentId,
              AppNotification.mentorshipRejected(
                requestId: requestId,
                alumniName: request.alumniName,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error creating response notification: $e');
        // Don't fail the response if notification fails
      }

      return chatId; // Return chatId for navigation
    } catch (e) {
      debugPrint('Error responding to mentorship request: $e');
      rethrow;
    }
  }

  /// Mark mentorship as completed with optional rating and feedback
  /// v7.3: Enhanced with completion data
  Future<void> markCompleted(
    String requestId, {
    int? rating,
    String? feedback,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': MentorshipRequestStatus.completed.value,
        'completedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (rating != null) {
        updateData['rating'] = rating;
      }

      if (feedback != null && feedback.isNotEmpty) {
        updateData['feedback'] = feedback;
      }

      await _mentorshipRequestsCollection.doc(requestId).update(updateData);
    } catch (e) {
      debugPrint('Error marking mentorship as completed: $e');
      rethrow;
    }
  }

  /// Shared Operations
  /// Get a specific mentorship request by ID
  Future<MentorshipRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _mentorshipRequestsCollection.doc(requestId).get();

      if (!doc.exists) {
        return null;
      }

      return MentorshipRequest.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting request by ID: $e');
      return null;
    }
  }

  /// Stream mentorship requests for a specific user (student or alumni)
  Stream<List<MentorshipRequest>> requestsStreamForUser(String userId) {
    return _mentorshipRequestsCollection
        .where('studentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MentorshipRequest.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream mentorship requests received by alumni
  Stream<List<MentorshipRequest>> requestsStreamForAlumni(String alumniId) {
    return _mentorshipRequestsCollection
        .where('alumniId', isEqualTo: alumniId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MentorshipRequest.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get mentorship statistics for alumni dashboard
  Future<Map<String, int>> getMentorshipStatsForAlumni(String alumniId) async {
    try {
      final query = await _mentorshipRequestsCollection
          .where('alumniId', isEqualTo: alumniId)
          .get();

      int pending = 0;
      int accepted = 0;
      int rejected = 0;
      int completed = 0;

      for (final doc in query.docs) {
        final request = MentorshipRequest.fromFirestore(doc);
        switch (request.status) {
          case MentorshipRequestStatus.pending:
            pending++;
            break;
          case MentorshipRequestStatus.accepted:
            accepted++;
            break;
          case MentorshipRequestStatus.rejected:
            rejected++;
            break;
          case MentorshipRequestStatus.completed:
            completed++;
            break;
        }
      }

      return {
        'pending': pending,
        'accepted': accepted,
        'rejected': rejected,
        'completed': completed,
        'total': query.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting mentorship stats: $e');
      return {
        'pending': 0,
        'accepted': 0,
        'rejected': 0,
        'completed': 0,
        'total': 0,
      };
    }
  }

  /// Check if a student has already requested mentorship from specific alumni
  Future<bool> hasActiveRequest(String studentId, String alumniId) async {
    try {
      final query = await _mentorshipRequestsCollection
          .where('studentId', isEqualTo: studentId)
          .where('alumniId', isEqualTo: alumniId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking active request: $e');
      return false;
    }
  }

  /// Search mentorship requests (for admin/analytics purposes)
  Future<List<MentorshipRequest>> searchRequests({
    String? studentId,
    String? alumniId,
    MentorshipRequestStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    try {
      Query query = _mentorshipRequestsCollection;

      if (studentId != null) {
        query = query.where('studentId', isEqualTo: studentId);
      }
      if (alumniId != null) {
        query = query.where('alumniId', isEqualTo: alumniId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }
      if (fromDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
        );
      }
      if (toDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(toDate),
        );
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final results = await query.get();
      return results.docs
          .map((doc) => MentorshipRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching mentorship requests: $e');
      return [];
    }
  }

  /// Delete a mentorship request (admin or user cleanup)
  Future<void> deleteRequest(String requestId) async {
    try {
      await _mentorshipRequestsCollection.doc(requestId).delete();
    } catch (e) {
      debugPrint('Error deleting mentorship request: $e');
      rethrow;
    }
  }
}
