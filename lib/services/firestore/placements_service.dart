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

  // Apply for a placement
  Future<void> applyForPlacement({
    required String userId,
    required String placementId,
    required String resume,
  }) async {
    try {
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

  // Check if user has already applied
  Future<bool> hasUserApplied({
    required String userId,
    required String placementId,
  }) async {
    try {
      final doc = await _firestore
          .collection('placements')
          .doc(placementId)
          .collection('applications')
          .doc(userId)
          .get();
      return doc.exists;
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
