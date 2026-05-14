import 'package:campusconnect/models/application.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// PlacementsService - Handles all Firestore operations for placements
///
/// CRITICAL: Application data is always stored with UID-based document IDs
/// - Primary path: placements/{placementId}/applications/{uid}
/// - All queries use userId parameter from authenticated user
/// - Never stores applications without explicit UID binding
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

  /// Direct client-side apply (fallback if Cloud Function unavailable)
  /// Stores at: placements/{placementId}/applications/{uid}
  /// CRITICAL: Always uses UID as document ID for strict isolation
  Future<void> applyForPlacementDirect({
    required String userId,
    required String placementId,
    required String resume,
    String? company,
  }) async {
    try {
      // Check if already applied
      final alreadyApplied = await hasUserApplied(
        userId: userId,
        placementId: placementId,
      );

      if (alreadyApplied) {
        throw Exception('You have already applied for this placement');
      }

      // Create application at placements/{placementId}/applications/{uid}
      await _firestore
          .collection('placements')
          .doc(placementId)
          .collection('applications')
          .doc(userId) // UID as document ID for strict isolation
          .set({
            'userId': userId,
            'placementId': placementId,
            'resumeUrl': resume,
            'company': company ?? 'Unknown',
            'appliedAt': FieldValue.serverTimestamp(),
            'status': 'applied',
          });
    } catch (e) {
      debugPrint('Error applying for placement: $e');
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
  /// CRITICAL: Always uses UID-scoped access - placements/{placementId}/applications/{uid}
  Future<bool> hasUserApplied({
    required String userId,
    required String placementId,
  }) async {
    try {
      // PRIMARY: Check exact path placements/{placementId}/applications/{uid}
      final docInPlacement = await _firestore
          .collection('placements')
          .doc(placementId)
          .collection('applications')
          .doc(userId)
          .get();

      if (docInPlacement.exists) return true;

      // FALLBACK: Check global applications collection with compound ID
      final applicationId = '${userId}_$placementId';
      final doc = await _firestore
          .collection('applications')
          .doc(applicationId)
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
