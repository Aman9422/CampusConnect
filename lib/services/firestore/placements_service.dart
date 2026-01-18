import 'package:campusconnect/models/placement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PlacementsService {
  final FirebaseFirestore _firestore;

  PlacementsService(this._firestore);

  factory PlacementsService.instance() {
    return PlacementsService(FirebaseFirestore.instance);
  }

  // Get all active placements as a stream for real-time updates
  Stream<List<Placement>> getAllPlacements() {
    return _firestore
        .collection('placements')
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Placement.fromFirestore(doc))
              .toList();
        });
  }

  // Get placements filtered by company
  Stream<List<Placement>> getPlacementsByCompany(String company) {
    return _firestore
        .collection('placements')
        .where('company', isEqualTo: company)
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Placement.fromFirestore(doc))
              .toList();
        });
  }

  // Get a single placement by ID
  Future<Placement?> getPlacement(String placementId) async {
    try {
      final doc = await _firestore
          .collection('placements')
          .doc(placementId)
          .get();
      if (doc.exists) {
        return Placement.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Apply for a placement (VERSION 4: Uses Cloud Function for security)
  Future<void> applyForPlacement({
    required String userId,
    required String placementId,
    required String resume,
    String? company,
  }) async {
    try {
      // VERSION 4: Use Cloud Function callable via HTTP
      // This ensures:
      // 1. Application record is created server-side (not blocked by security rules)
      // 2. Duplicate applications are prevented via transaction
      // 3. Both new and old data structures are populated
      // 4. Analytics events are logged

      // Use HTTPS Callable (secure auth context)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'logPlacementApplication',
      );

      final result = await callable
          .call({
            'placementId': placementId,
            'resumeUrl': resume,
            'company': company ?? 'Unknown',
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      // Handle response from HTTPS Callable
      if (result.data is! Map<String, dynamic>) {
        throw Exception('Unexpected response from Cloud Function');
      }

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (!success) {
        throw Exception(data['message'] ?? 'Failed to submit application');
      }

      // Success - application created on backend
    } catch (e) {
      // Cloud Functions returns FirebaseFunctionsException for auth/network errors
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'Failed to submit application');
      }
      // Re-throw other exceptions
      rethrow;
    }
  }

  // VERSION 4: Get all user applications (including closed placements)
  Stream<List<Map<String, dynamic>>> getUserApplicationsWithDetails(
    String userId,
  ) {
    return _firestore
        .collection('applications')
        .where('userId', isEqualTo: userId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final applications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final placementId = data['placementId'] as String;

            // Fetch placement details (even if closed/deleted)
            try {
              final placementDoc = await _firestore
                  .collection('placements')
                  .doc(placementId)
                  .get();

              applications.add({
                'applicationId': doc.id,
                'placementId': placementId,
                'resumeUrl': data['resumeUrl'],
                'appliedAt': data['appliedAt'],
                'status': data['status'] ?? 'applied',
                'placement': placementDoc.exists
                    ? placementDoc.data()
                    : {'company': 'Placement Closed', 'isActive': false},
              });
            } catch (e) {
              // If placement fetch fails, still include the application
              applications.add({
                'applicationId': doc.id,
                'placementId': placementId,
                'resumeUrl': data['resumeUrl'],
                'appliedAt': data['appliedAt'],
                'status': data['status'] ?? 'applied',
                'placement': {'company': 'Unknown', 'isActive': false},
              });
            }
          }

          return applications;
        });
  }

  // Check if user has already applied (VERSION 4: Check new structure)
  Future<bool> hasUserApplied({
    required String userId,
    required String placementId,
  }) async {
    try {
      final applicationId = '${userId}_$placementId';
      final doc = await _firestore
          .collection('applications')
          .doc(applicationId)
          .get();

      if (doc.exists) return true;

      // Fallback: Check old structure for backward compatibility
      final oldDoc = await _firestore
          .collection('placements')
          .doc(placementId)
          .collection('applications')
          .doc(userId)
          .get();
      return oldDoc.exists;
    } catch (e) {
      rethrow;
    }
  }

  // Get user's applications
  Stream<List<String>> getUserApplications(String userId) {
    return _firestore
        .collectionGroup('applications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc['placementId'] as String)
              .toList();
        });
  }
}
