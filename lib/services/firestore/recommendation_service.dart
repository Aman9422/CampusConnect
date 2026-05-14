import 'dart:math';

import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/models/recommendation.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/alumni_directory_service.dart';
import 'package:campusconnect/services/firestore/opportunity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// RecommendationService - v7.4 intelligent recommendation layer
///
/// Stores user-specific recommendations in:
/// users/{uid}/recommendations/{recommendationId}
class RecommendationService {
  final FirebaseFirestore _firestore;
  final AlumniDirectoryService _alumniDirectoryService;
  final OpportunityService _opportunityService;

  RecommendationService({
    FirebaseFirestore? firestore,
    AlumniDirectoryService? alumniDirectoryService,
    OpportunityService? opportunityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _alumniDirectoryService =
           alumniDirectoryService ?? AlumniDirectoryService.instance(),
       _opportunityService =
           opportunityService ?? OpportunityService.instance();

  static final RecommendationService _instance = RecommendationService();
  factory RecommendationService.instance() => _instance;

  CollectionReference<Map<String, dynamic>> _recommendationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recommendations');
  }

  Stream<List<Recommendation>> recommendationsStream(
    String userId, {
    int limit = 20,
  }) {
    return _recommendationsRef(userId)
        .where('isActive', isEqualTo: true)
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Recommendation.fromFirestore(doc))
              .where((rec) => !rec.isExpired)
              .toList(),
        );
  }

  Future<List<Recommendation>> getRecommendationsOnce(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final query = await _recommendationsRef(userId)
          .where('isActive', isEqualTo: true)
          .orderBy('score', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => Recommendation.fromFirestore(doc))
          .where((rec) => !rec.isExpired)
          .toList();
    } catch (e) {
      debugPrint('RecommendationService.getRecommendationsOnce error: $e');
      return [];
    }
  }

  Future<void> createRecommendation(
    String userId,
    Recommendation recommendation,
  ) async {
    try {
      await _recommendationsRef(userId)
          .doc(recommendation.id)
          .set(recommendation.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('RecommendationService.createRecommendation error: $e');
      rethrow;
    }
  }

  Future<void> markRecommendationInteracted(
    String userId,
    String recommendationId,
  ) async {
    try {
      await _recommendationsRef(userId).doc(recommendationId).set({
        'metadata': {'interactedAt': Timestamp.fromDate(DateTime.now())},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        'RecommendationService.markRecommendationInteracted error: $e',
      );
    }
  }

  /// Rebuild all recommendations for the user.
  ///
  /// This powers v7.4 smart mentor/job suggestions and inactivity nudges.
  Future<void> refreshRecommendations({
    required String userId,
    required StudentProfile profile,
  }) async {
    try {
      final results = await Future.wait([
        _alumniDirectoryService.getAlumniDirectory(limit: 80),
        _opportunityService.getActiveOpportunities(limit: 80),
      ]);

      final alumni = results[0] as List<StudentProfile>;
      final opportunities = results[1] as List<Opportunity>;

      final recommendations = <Recommendation>[
        ..._buildMentorRecommendations(userId, profile, alumni),
        ..._buildJobRecommendations(userId, profile, opportunities),
        ..._buildSmartNudges(userId, profile),
      ];

      final batch = _firestore.batch();
      final now = DateTime.now();

      final existing = await _recommendationsRef(
        userId,
      ).where('isActive', isEqualTo: true).get();
      for (final doc in existing.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      for (final recommendation in recommendations.take(20)) {
        final docRef = _recommendationsRef(userId).doc(recommendation.id);
        batch.set(
          docRef,
          recommendation.toFirestore(),
          SetOptions(merge: true),
        );
      }

      final digestRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendations_meta')
          .doc('summary');
      batch.set(digestRef, {
        'updatedAt': Timestamp.fromDate(now),
        'total': recommendations.length,
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('RecommendationService.refreshRecommendations error: $e');
      rethrow;
    }
  }

  List<Recommendation> _buildMentorRecommendations(
    String userId,
    StudentProfile profile,
    List<StudentProfile> alumni,
  ) {
    final profileSkills = _normalizedSet(profile.skills ?? []);
    final userInterests = _normalizedSet([
      ...profile.career.interests,
      ...profile.career.preferredRoles,
      if (profile.careerInterest != null) profile.careerInterest!,
    ]);

    final scored = <MapEntry<StudentProfile, double>>[];

    for (final mentor in alumni) {
      if (mentor.uid == profile.uid) continue;
      final mentorSkills = _normalizedSet(mentor.skills ?? []);
      final overlapSkills = profileSkills.intersection(mentorSkills).length;
      final overlapInterests = userInterests.intersection(
        _normalizedSet([
          mentor.jobRole ?? '',
          mentor.company ?? '',
          mentor.careerInterest ?? '',
        ]),
      );

      double score = 0;
      score += min(45, overlapSkills * 15).toDouble();
      score += min(35, overlapInterests.length * 12).toDouble();

      if (profile.department != null &&
          mentor.department != null &&
          profile.department!.toLowerCase() ==
              mentor.department!.toLowerCase()) {
        score += 10;
      }
      if (profile.graduationYear != null && mentor.graduationYear != null) {
        final yearDistance = (mentor.graduationYear! - profile.graduationYear!)
            .abs();
        score += max(0, 10 - min(10, yearDistance));
      }

      if (score > 0) {
        scored.add(MapEntry(mentor, score.clamp(0, 100)));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(5).map((entry) {
      final mentor = entry.key;
      final score = entry.value.round();
      return Recommendation(
        id: 'mentor_${mentor.uid}',
        userId: userId,
        type: RecommendationType.mentor,
        priority: score >= 75
            ? RecommendationPriority.high
            : RecommendationPriority.medium,
        title: 'Connect with ${mentor.personal.effectiveDisplayName}',
        description:
            '${mentor.jobRole ?? 'Alumni mentor'} at ${mentor.company ?? 'CampusConnect Network'}',
        score: score.toDouble(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        metadata: {
          'alumniId': mentor.uid,
          'company': mentor.company,
          'jobRole': mentor.jobRole,
          'skills': mentor.skills ?? <String>[],
        },
      );
    }).toList();
  }

  List<Recommendation> _buildJobRecommendations(
    String userId,
    StudentProfile profile,
    List<Opportunity> opportunities,
  ) {
    final profileSkills = _normalizedSet(profile.skills ?? []);
    final roleInterests = _normalizedSet([
      ...profile.career.preferredRoles,
      ...profile.career.interests,
      if (profile.careerInterest != null) profile.careerInterest!,
    ]);

    final scored = <Map<String, dynamic>>[];

    for (final opportunity in opportunities) {
      final skills = _normalizedSet(opportunity.skills);
      final title = opportunity.title;
      final company = opportunity.company;

      double score = 0;
      score += min(
        55,
        profileSkills.intersection(skills).length * 18,
      ).toDouble();

      final titleTokens = _normalizedSet([title, company]);
      score += min(
        30,
        roleInterests.intersection(titleTokens).length * 15,
      ).toDouble();

      if (profile.academic.cgpa >= 8.0) {
        score += 10;
      } else if (profile.academic.cgpa >= 7.0) {
        score += 5;
      }

      if (score > 0) {
        scored.add({
          'id': opportunity.id,
          'title': title,
          'company': company,
          'score': (score.clamp(0, 100)).toDouble(),
          'skills': opportunity.skills,
          'postedAt': opportunity.postedAt,
        });
      }
    }

    scored.sort((a, b) {
      final scoreCompare = (b['score'] as double).compareTo(
        a['score'] as double,
      );
      if (scoreCompare != 0) return scoreCompare;
      return (b['postedAt'] as DateTime).compareTo(a['postedAt'] as DateTime);
    });

    return scored.take(5).map((entry) {
      final score = (entry['score'] as double).round();
      return Recommendation(
        id: 'job_${entry['id']}',
        userId: userId,
        type: RecommendationType.job,
        priority: score >= 70
            ? RecommendationPriority.high
            : RecommendationPriority.medium,
        title: '${entry['title']} at ${entry['company']}',
        description: 'AI match score: $score%',
        score: score.toDouble(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        metadata: {
          'opportunityId': entry['id'],
          'skills': entry['skills'] ?? <String>[],
        },
      );
    }).toList();
  }

  List<Recommendation> _buildSmartNudges(
    String userId,
    StudentProfile profile,
  ) {
    final recs = <Recommendation>[];

    if (profile.skills == null || profile.skills!.length < 3) {
      recs.add(
        Recommendation(
          id: 'nudge_skills_${profile.uid}',
          userId: userId,
          type: RecommendationType.skill,
          priority: RecommendationPriority.high,
          title: 'Complete your skills profile',
          description:
              'Add at least 3 skills to unlock stronger mentor/job matches.',
          score: 82,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 2)),
          metadata: {'action': 'profile_update'},
        ),
      );
    }

    recs.add(
      Recommendation(
        id: 'nudge_chat_${profile.uid}',
        userId: userId,
        type: RecommendationType.chat,
        priority: RecommendationPriority.medium,
        title: 'Use AI Career Assistant',
        description:
            'Ask for interview simulation, resume fixes, and skill-gap analysis.',
        score: 68,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 2)),
        metadata: {'action': 'open_ai_chat'},
      ),
    );

    return recs;
  }

  Set<String> _normalizedSet(List<String> values) {
    return values
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}
