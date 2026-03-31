import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// TeacherAnalyticsService - v7.3: Teacher analytics enhancement
///
/// Aggregates student resume review data for teacher dashboard insights.
/// Provides real analytics showing student resume review patterns.
class TeacherAnalyticsService {
  final FirebaseFirestore _firestore;

  TeacherAnalyticsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final TeacherAnalyticsService _instance = TeacherAnalyticsService();
  factory TeacherAnalyticsService.instance() => _instance;

  /// Get resume review aggregate statistics
  /// Returns total reviews, average score, score distribution
  Future<Map<String, dynamic>> getResumeReviewStats() async {
    try {
      // Use collectionGroup to aggregate across all users
      final reviewsQuery = await _firestore
          .collectionGroup('resume_reviews')
          .orderBy('reviewedAt', descending: true)
          .get();

      if (reviewsQuery.docs.isEmpty) {
        return {
          'totalReviews': 0,
          'avgScore': 0.0,
          'scoreDistribution': {
            'excellent': 0, // 80+ score
            'good': 0, // 60-79 score
            'fair': 0, // 40-59 score
            'poor': 0, // <40 score
          },
        };
      }

      int totalReviews = reviewsQuery.docs.length;
      double totalScore = 0;
      Map<String, int> scoreDistribution = {
        'excellent': 0,
        'good': 0,
        'fair': 0,
        'poor': 0,
      };

      for (final doc in reviewsQuery.docs) {
        final data = doc.data();
        final atsScore = data['atsScore'] as int? ?? 0;

        totalScore += atsScore;

        // Categorize score
        if (atsScore >= 80) {
          scoreDistribution['excellent'] = scoreDistribution['excellent']! + 1;
        } else if (atsScore >= 60) {
          scoreDistribution['good'] = scoreDistribution['good']! + 1;
        } else if (atsScore >= 40) {
          scoreDistribution['fair'] = scoreDistribution['fair']! + 1;
        } else {
          scoreDistribution['poor'] = scoreDistribution['poor']! + 1;
        }
      }

      final avgScore = totalScore / totalReviews;

      return {
        'totalReviews': totalReviews,
        'avgScore': avgScore,
        'scoreDistribution': scoreDistribution,
      };
    } catch (e) {
      debugPrint('Error getting resume review stats: $e');
      return {
        'totalReviews': 0,
        'avgScore': 0.0,
        'scoreDistribution': {'excellent': 0, 'good': 0, 'fair': 0, 'poor': 0},
      };
    }
  }

  /// Get student resume data for leaderboard
  /// Returns list of student data sorted by latest score
  Future<List<Map<String, dynamic>>> getStudentResumeData() async {
    try {
      // Get all students with resume reviews
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> studentData = [];

      for (final userDoc in usersQuery.docs) {
        try {
          // Get latest resume review for this student
          final reviewsQuery = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('resume_reviews')
              .orderBy('reviewedAt', descending: true)
              .limit(1)
              .get();

          if (reviewsQuery.docs.isNotEmpty) {
            final latestReview = reviewsQuery.docs.first;
            final reviewData = latestReview.data();

            // Get total review count for this student
            final totalReviewsQuery = await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('resume_reviews')
                .count()
                .get();

            final userData = userDoc.data();
            final studentName = _getStudentName(userData);

            studentData.add({
              'studentId': userDoc.id,
              'studentName': studentName,
              'latestScore': reviewData['atsScore'] as int? ?? 0,
              'reviewCount': totalReviewsQuery.count ?? 0,
              'lastReviewedAt': (reviewData['reviewedAt'] as Timestamp?)
                  ?.toDate(),
            });
          }
        } catch (e) {
          debugPrint('Error processing student ${userDoc.id}: $e');
          // Continue with other students
        }
      }

      // Sort by latest score descending (leaderboard)
      studentData.sort((a, b) {
        final scoreA = a['latestScore'] as int;
        final scoreB = b['latestScore'] as int;
        return scoreB.compareTo(scoreA);
      });

      // Return top 20 students
      return studentData.take(20).toList();
    } catch (e) {
      debugPrint('Error getting student resume data: $e');
      return [];
    }
  }

  /// Extract student name from user data
  /// Handles various name field structures
  String _getStudentName(Map<String, dynamic> userData) {
    // Try different name field structures
    if (userData['personal'] != null) {
      final personal = userData['personal'] as Map<String, dynamic>;

      // Try firstName + lastName
      final firstName = personal['firstName'] as String?;
      final lastName = personal['lastName'] as String?;
      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      }

      // Try displayName
      final displayName = personal['displayName'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }

      // Try fullName
      final fullName = personal['fullName'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }

      // Try email before @ if nothing else
      final email = personal['email'] as String?;
      if (email != null) {
        return email.split('@').first;
      }
    }

    return 'Unknown Student';
  }

  /// Get resume review trends over time (for future enhancement)
  Future<List<Map<String, dynamic>>> getReviewTrends({
    int pastDays = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: pastDays));

      final reviewsQuery = await _firestore
          .collectionGroup('resume_reviews')
          .where(
            'reviewedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('reviewedAt', descending: false)
          .get();

      // Group by day and calculate daily averages
      Map<String, List<int>> dailyScores = {};

      for (final doc in reviewsQuery.docs) {
        final data = doc.data();
        final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
        final atsScore = data['atsScore'] as int? ?? 0;

        if (reviewedAt != null) {
          final dayKey =
              '${reviewedAt.year}-${reviewedAt.month.toString().padLeft(2, '0')}-${reviewedAt.day.toString().padLeft(2, '0')}';
          dailyScores.putIfAbsent(dayKey, () => []).add(atsScore);
        }
      }

      List<Map<String, dynamic>> trends = [];

      for (final entry in dailyScores.entries) {
        final scores = entry.value;
        final avgScore = scores.reduce((a, b) => a + b) / scores.length;

        trends.add({
          'date': entry.key,
          'avgScore': avgScore.round(),
          'reviewCount': scores.length,
        });
      }

      return trends;
    } catch (e) {
      debugPrint('Error getting review trends: $e');
      return [];
    }
  }
}
