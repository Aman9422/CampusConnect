import 'package:campusconnect/models/application.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PlacementsService - Handles all Firestore operations for placements
///
/// CRITICAL: Application data is always stored with UID-based document IDs
/// - Primary path: placements/{placementId}/applications/{uid}
/// - All queries use userId parameter from authenticated user
/// - Never stores applications without explicit UID binding
///
/// v8.4.2 (S5d/L1 + N4): `applyForPlacement`, `applyForPlacementDirect`,
/// `hasUserApplied`, `getUserApplicationsWithDetails` (N+1 asyncMap) and
/// `getUserApplications` (collectionGroup) removed — all dead code.
/// `PlacementsProvider` owns the apply flow (calls the
/// `logPlacementApplication` callable directly) and only needs
/// `getAllPlacementsOnce` + `getUserApplicationsOnce` here.
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

  /// Create a new placement posting (teacher/alumni management flow)
  Future<String> createPlacement({
    required String createdBy,
    required String company,
    required String role,
    required String description,
    required String eligibility,
    required String salary,
    required DateTime deadline,
    PlacementRequirements requirements = const PlacementRequirements(),
  }) async {
    final docRef = _firestore.collection('placements').doc();
    final now = DateTime.now();

    final placement = Placement(
      id: docRef.id,
      company: company,
      role: role,
      description: description,
      eligibility: eligibility,
      salary: salary,
      deadline: deadline,
      postedAt: now,
      isActive: true,
      requirements: requirements,
    );

    await docRef.set({
      ...placement.toFirestore(),
      'createdBy': createdBy,
      'updatedBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Update an existing placement posting
  Future<void> updatePlacement({
    required String updatedBy,
    required Placement placement,
  }) async {
    await _firestore.collection('placements').doc(placement.id).set({
      ...placement.toFirestore(),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // V5: Get all active placements (one-time fetch)
  Future<List<Placement>> getAllPlacementsOnce() async {
    try {
      final snapshot = await _firestore
          .collection('placements')
          .where('isActive', isEqualTo: true)
          .orderBy('postedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Placement.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // V5: Get user applications (one-time fetch)
  Future<List<Application>> getUserApplicationsOnce(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .orderBy('appliedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
