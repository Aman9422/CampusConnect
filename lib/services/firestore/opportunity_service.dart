import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/models/app_notification.dart'; // v7.3
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// OpportunityService - v7.2: Multi-role ecosystem
///
/// Handles all Firestore operations for job opportunities.
/// Alumni create opportunities, students browse them.
/// Follows ProfileService pattern with strict access control.
class OpportunityService {
  final FirebaseFirestore _firestore;

  OpportunityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final OpportunityService _instance = OpportunityService();
  factory OpportunityService.instance() => _instance;

  // Collection reference
  CollectionReference get _opportunitiesCollection =>
      _firestore.collection('opportunities');

  /// Alumni Operations
  /// Create a new job opportunity
  Future<String> createOpportunity({
    required String alumniId,
    required String title,
    required String company,
    required String description,
    required List<String> requirements,
    required String location,
    required String jobType,
    required List<String> skills,
    required StudentProfile alumniProfile,
    String? salaryRange,
    DateTime? applicationDeadline,
    String? applicationUrl,
    String? contactEmail,
  }) async {
    try {
      // Generate document ID
      final docRef = _opportunitiesCollection.doc();

      final opportunity = Opportunity(
        id: docRef.id,
        alumniId: alumniId,
        title: title,
        company: company,
        description: description,
        requirements: requirements,
        location: location,
        jobType: jobType,
        skills: skills,
        postedAt: DateTime.now(),
        isActive: true,
        alumniName: alumniProfile.personal.effectiveDisplayName,
        alumniJobRole: alumniProfile.jobRole,
        salaryRange: salaryRange,
        applicationDeadline: applicationDeadline,
        applicationUrl: applicationUrl,
        contactEmail: contactEmail,
      );

      await docRef.set(opportunity.toFirestore());

      // v7.3: Notify all students of new job opportunity
      try {
        final usersSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();

        if (usersSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();

          for (final userDoc in usersSnapshot.docs) {
            final notification = AppNotification.newJobPost(
              opportunityId: docRef.id,
              title: title,
              company: company,
            );

            final notifRef = _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('notifications')
                .doc();

            batch.set(notifRef, notification.toFirestore());
          }

          await batch.commit();
          debugPrint(
            'Notified ${usersSnapshot.docs.length} students of new job post',
          );
        }
      } catch (e) {
        debugPrint('Error creating job post notifications: $e');
        // Don't fail job posting if notifications fail
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating opportunity: $e');
      rethrow;
    }
  }

  /// Get opportunities posted by a specific alumni
  Future<List<Opportunity>> getAlumniOpportunities(String alumniId) async {
    try {
      final query = await _opportunitiesCollection
          .where('alumniId', isEqualTo: alumniId)
          .orderBy('postedAt', descending: true)
          .get();

      return query.docs.map((doc) => Opportunity.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting alumni opportunities: $e');
      return [];
    }
  }

  /// Update an existing opportunity
  Future<void> updateOpportunity(Opportunity opportunity) async {
    try {
      await _opportunitiesCollection
          .doc(opportunity.id)
          .set(opportunity.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating opportunity: $e');
      rethrow;
    }
  }

  /// Deactivate an opportunity (mark as inactive)
  Future<void> deactivateOpportunity(String opportunityId) async {
    try {
      await _opportunitiesCollection.doc(opportunityId).update({
        'isActive': false,
      });
    } catch (e) {
      debugPrint('Error deactivating opportunity: $e');
      rethrow;
    }
  }

  /// Reactivate an opportunity
  Future<void> reactivateOpportunity(String opportunityId) async {
    try {
      await _opportunitiesCollection.doc(opportunityId).update({
        'isActive': true,
      });
    } catch (e) {
      debugPrint('Error reactivating opportunity: $e');
      rethrow;
    }
  }

  /// Delete an opportunity
  Future<void> deleteOpportunity(String opportunityId) async {
    try {
      await _opportunitiesCollection.doc(opportunityId).delete();
    } catch (e) {
      debugPrint('Error deleting opportunity: $e');
      rethrow;
    }
  }

  /// Student Operations
  /// Get all active opportunities for students to browse
  Future<List<Opportunity>> getActiveOpportunities({int limit = 50}) async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: true)
          .orderBy('postedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => Opportunity.fromFirestore(doc))
          .where((opp) => !opp.isExpired) // Filter out expired opportunities
          .toList();
    } catch (e) {
      debugPrint('Error getting active opportunities: $e');
      return [];
    }
  }

  /// Search opportunities by various criteria
  Future<List<Opportunity>> searchOpportunities({
    String? searchQuery,
    String? company,
    String? jobType,
    String? location,
    List<String>? skills,
    bool onlyActive = true,
    int limit = 100,
  }) async {
    try {
      Query query = _opportunitiesCollection;

      if (onlyActive) {
        query = query.where('isActive', isEqualTo: true);
      }

      if (company != null && company.isNotEmpty) {
        query = query.where('company', isEqualTo: company);
      }

      if (jobType != null && jobType.isNotEmpty) {
        query = query.where('jobType', isEqualTo: jobType);
      }

      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }

      query = query.orderBy('postedAt', descending: true).limit(limit);

      final results = await query.get();
      var opportunities = results.docs
          .map((doc) => Opportunity.fromFirestore(doc))
          .toList();

      // Filter by search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        opportunities = opportunities
            .where(
              (opp) =>
                  opp.title.toLowerCase().contains(queryLower) ||
                  opp.company.toLowerCase().contains(queryLower) ||
                  opp.description.toLowerCase().contains(queryLower) ||
                  opp.location.toLowerCase().contains(queryLower) ||
                  opp.skills.any(
                    (skill) => skill.toLowerCase().contains(queryLower),
                  ),
            )
            .toList();
      }

      // Filter by skills if provided
      if (skills != null && skills.isNotEmpty) {
        opportunities = opportunities
            .where(
              (opp) => skills.any(
                (skill) => opp.skills.any(
                  (oppSkill) =>
                      oppSkill.toLowerCase().contains(skill.toLowerCase()),
                ),
              ),
            )
            .toList();
      }

      // Filter out expired opportunities if only active requested
      if (onlyActive) {
        opportunities = opportunities.where((opp) => !opp.isExpired).toList();
      }

      return opportunities;
    } catch (e) {
      debugPrint('Error searching opportunities: $e');
      return [];
    }
  }

  /// Get recent opportunities (for home feed)
  Future<List<Opportunity>> getRecentOpportunities({int limit = 10}) async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: true)
          .orderBy('postedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => Opportunity.fromFirestore(doc))
          .where((opp) => !opp.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Error getting recent opportunities: $e');
      return [];
    }
  }

  /// Shared Operations
  /// Get a specific opportunity by ID
  Future<Opportunity?> getOpportunityById(String opportunityId) async {
    try {
      final doc = await _opportunitiesCollection.doc(opportunityId).get();

      if (!doc.exists) {
        return null;
      }

      return Opportunity.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting opportunity by ID: $e');
      return null;
    }
  }

  /// Stream active opportunities for real-time updates
  Stream<List<Opportunity>> activeOpportunitiesStream({int limit = 50}) {
    return _opportunitiesCollection
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Opportunity.fromFirestore(doc))
              .where((opp) => !opp.isExpired)
              .toList(),
        );
  }

  /// Stream opportunities for specific alumni
  Stream<List<Opportunity>> alumniOpportunitiesStream(String alumniId) {
    return _opportunitiesCollection
        .where('alumniId', isEqualTo: alumniId)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Opportunity.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get opportunity statistics for alumni dashboard
  Future<Map<String, int>> getOpportunityStatsForAlumni(String alumniId) async {
    try {
      final query = await _opportunitiesCollection
          .where('alumniId', isEqualTo: alumniId)
          .get();

      int active = 0;
      int inactive = 0;
      int expired = 0;

      for (final doc in query.docs) {
        final opportunity = Opportunity.fromFirestore(doc);
        if (opportunity.isExpired) {
          expired++;
        } else if (opportunity.isActive) {
          active++;
        } else {
          inactive++;
        }
      }

      return {
        'active': active,
        'inactive': inactive,
        'expired': expired,
        'total': query.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting opportunity stats: $e');
      return {'active': 0, 'inactive': 0, 'expired': 0, 'total': 0};
    }
  }

  /// Get unique companies from opportunities (for filtering)
  Future<List<String>> getUniqueCompanies() async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: true)
          .get();

      final companies = query.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['company'] as String?)
          .where((company) => company != null && company.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      companies.sort();
      return companies;
    } catch (e) {
      debugPrint('Error getting unique companies: $e');
      return [];
    }
  }

  /// Get unique locations from opportunities (for filtering)
  Future<List<String>> getUniqueLocations() async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: true)
          .get();

      final locations = query.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['location'] as String?)
          .where((location) => location != null && location.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      locations.sort();
      return locations;
    } catch (e) {
      debugPrint('Error getting unique locations: $e');
      return [];
    }
  }

  /// Get popular skills from opportunities (for suggestions)
  Future<List<String>> getPopularSkills({int limit = 20}) async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: true)
          .get();

      final skillCounts = <String, int>{};

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final skills = List<String>.from(data['skills'] ?? []);

        for (final skill in skills) {
          skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;
        }
      }

      final sortedSkills = skillCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedSkills.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('Error getting popular skills: $e');
      return [];
    }
  }

  /// Admin/Analytics Operations
  /// Get opportunities posted in date range
  Future<List<Opportunity>> getOpportunitiesByDateRange({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _opportunitiesCollection;

      if (startDate != null) {
        query = query.where(
          'postedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'postedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.orderBy('postedAt', descending: true).limit(limit);

      final results = await query.get();
      return results.docs.map((doc) => Opportunity.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting opportunities by date range: $e');
      return [];
    }
  }

  /// Clean up expired opportunities (remove inactive expired ones)
  Future<int> cleanupExpiredOpportunities() async {
    try {
      final query = await _opportunitiesCollection
          .where('isActive', isEqualTo: false)
          .get();

      int deletedCount = 0;
      final batch = _firestore.batch();

      for (final doc in query.docs) {
        final opportunity = Opportunity.fromFirestore(doc);

        // Delete opportunities that are inactive and expired for more than 30 days
        if (opportunity.isExpired &&
            opportunity.applicationDeadline != null &&
            DateTime.now().difference(opportunity.applicationDeadline!).inDays >
                30) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
      }

      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning up expired opportunities: $e');
      return 0;
    }
  }
}
