import 'package:campusconnect/models/placement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Apply for a placement (VERSION 4: Improved application tracking)
  Future<void> applyForPlacement({
    required String userId,
    required String placementId,
    required String resume,
  }) async {
    try {
      // VERSION 4: Store application in a top-level collection
      // This preserves applications even if placement is deleted/closed
      final applicationId = '${userId}_$placementId';

      await _firestore.collection('applications').doc(applicationId).set({
        'userId': userId,
        'placementId': placementId,
        'resumeUrl': resume,
        'appliedAt': FieldValue.serverTimestamp(),
        'status': 'applied', // applied | shortlisted | rejected
      });

      // VERSION 4: Also update the old structure for backward compatibility
      // This maintains existing functionality while adding new structure
      await _firestore
          .collection('placements')
          .doc(placementId)
          .collection('applications')
          .doc(userId)
          .set({
            'userId': userId,
            'placementId': placementId,
            'resume': resume,
            'appliedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
    } catch (e) {
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
