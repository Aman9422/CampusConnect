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

  /// v9.1: All applications for a placement, deduped by student.
  ///
  /// A collectionGroup query on `applications` matches BOTH mirrors:
  ///   - canonical: `applications/{uid}_{placementId}` (field `resumeUrl`)
  ///   - mirror:    `placements/{placementId}/applications/{uid}` (field `resume`)
  ///
  /// Each student appears in both docs, so we dedupe by [userId] and prefer
  /// the canonical doc — the one that carries `resumeUrl`.
  Future<List<Application>> getApplicationsForPlacement(
      String placementId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('applications')
          .where('placementId', isEqualTo: placementId)
          .get();

      final byUser = <String, Application>{};
      final hadResumeUrl = <String, bool>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String? ?? data['studentId'] as String?;
        if (userId == null) continue;

        final carriesResumeUrl = data.containsKey('resumeUrl');
        final current = byUser[userId];
        final currentCarriesResumeUrl = hadResumeUrl[userId] ?? false;

        // Keep first match; replace only when the new doc is canonical
        // (`resumeUrl`) and the kept doc was only a mirror (`resume`).
        if (current == null || (carriesResumeUrl && !currentCarriesResumeUrl)) {
          byUser[userId] = Application.fromFirestore(doc);
          hadResumeUrl[userId] = carriesResumeUrl;
        }
      }

      final applications = byUser.values.toList()
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
      return applications;
    } catch (e) {
      rethrow;
    }
  }

  /// v9.1: Unique applicant count per placement.
  ///
  /// Uses a collectionGroup query (same dedupe concern as
  /// [getApplicationsForPlacement]) and counts DISTINCT students — the two
  /// mirrors for one student count once. [placementIds] is batched into
  /// chunks of 10 (`whereIn` Firestore limit).
  Future<Map<String, int>> getApplicantCounts(
      List<String> placementIds) async {
    if (placementIds.isEmpty) return {};

    final uniqueByPlacement = <String, Set<String>>{};

    for (var start = 0; start < placementIds.length; start += 10) {
      final end = start + 10 < placementIds.length
          ? start + 10
          : placementIds.length;
      final chunk = placementIds.sublist(start, end);

      final snapshot = await _firestore
          .collectionGroup('applications')
          .where('placementId', whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final placementId = data['placementId'] as String?;
        final userId = data['userId'] as String? ?? data['studentId'] as String?;
        if (placementId == null || userId == null) continue;
        uniqueByPlacement
            .putIfAbsent(placementId, () => <String>{})
            .add(userId);
      }
    }

    return uniqueByPlacement
        .map((placementId, students) => MapEntry(placementId, students.length));
  }
}
