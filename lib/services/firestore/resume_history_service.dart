import 'package:campusconnect/models/resume_review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v6.8 - Resume Review History Service
///
/// Manages Firestore operations for resume review history.
/// Stores and retrieves past reviews for user reference.

class ResumeHistoryService {
  final FirebaseFirestore _firestore;

  ResumeHistoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static ResumeHistoryService? _instance;
  static ResumeHistoryService instance() {
    _instance ??= ResumeHistoryService();
    return _instance!;
  }

  /// Get reference to user's resume reviews subcollection
  CollectionReference _getUserReviewsCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('resumeReviews');
  }

  /// Save a new resume review to history
  Future<String> saveReview({
    required String userId,
    required ResumeReview review,
    String? targetRole,
  }) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final docRef = await _getUserReviewsCollection(userId).add({
        'userId': userId,
        'atsScore': review.atsScore,
        'strengths': review.strengths,
        'missingKeywords': review.missingKeywords,
        'formatIssues': review.formatIssues,
        'bulletImprovements': review.bulletImprovements
            .map((b) => b.toJson())
            .toList(),
        'sectionAdvice': review.sectionAdvice.toJson(),
        'overallAdvice': review.overallAdvice,
        'hireabilityVerdict': review.hireabilityVerdict,
        'targetRole': targetRole,
        'createdAt': FieldValue.serverTimestamp(),
        'monthKey': monthKey,
      });

      debugPrint('ResumeHistoryService: Saved review ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('ResumeHistoryService: Error saving review: $e');
      rethrow;
    }
  }

  /// Fetch all reviews for a user (sorted by createdAt desc)
  Future<List<ResumeReviewHistory>> fetchHistory(String userId) async {
    try {
      final snapshot = await _getUserReviewsCollection(
        userId,
      ).orderBy('createdAt', descending: true).get();

      return snapshot.docs
          .map(
            (doc) => ResumeReviewHistory.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('ResumeHistoryService: Error fetching history: $e');
      return [];
    }
  }

  /// Get a single review by ID
  Future<ResumeReviewHistory?> getReviewById({
    required String userId,
    required String reviewId,
  }) async {
    try {
      final doc = await _getUserReviewsCollection(userId).doc(reviewId).get();

      if (!doc.exists) return null;

      return ResumeReviewHistory.fromFirestore(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('ResumeHistoryService: Error fetching review: $e');
      return null;
    }
  }

  /// Delete a specific review
  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  }) async {
    try {
      await _getUserReviewsCollection(userId).doc(reviewId).delete();
      debugPrint('ResumeHistoryService: Deleted review $reviewId');
    } catch (e) {
      debugPrint('ResumeHistoryService: Error deleting review: $e');
      rethrow;
    }
  }

  /// Delete all reviews for a user (used on account deletion)
  Future<void> deleteAllReviews(String userId) async {
    try {
      final snapshot = await _getUserReviewsCollection(userId).get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('ResumeHistoryService: Deleted all reviews for user');
    } catch (e) {
      debugPrint('ResumeHistoryService: Error deleting all reviews: $e');
      rethrow;
    }
  }

  /// Stream of review history (real-time updates)
  Stream<List<ResumeReviewHistory>> streamHistory(String userId) {
    return _getUserReviewsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ResumeReviewHistory.fromFirestore(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  /// Get review count for current month
  Future<int> getMonthlyReviewCount(String userId) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final snapshot = await _getUserReviewsCollection(
        userId,
      ).where('monthKey', isEqualTo: monthKey).get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('ResumeHistoryService: Error getting monthly count: $e');
      return 0;
    }
  }
}
