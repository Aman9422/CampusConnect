import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// AlumniDirectoryService - v7.2: Multi-role ecosystem
///
/// Handles alumni discovery by querying the existing users collection.
/// Students can search and filter alumni by various criteria.
/// Follows ProfileService pattern with read-only operations.
class AlumniDirectoryService {
  final FirebaseFirestore _firestore;

  AlumniDirectoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final AlumniDirectoryService _instance = AlumniDirectoryService();
  factory AlumniDirectoryService.instance() => _instance;

  // Collection reference (reuse existing users collection)
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Get all alumni profiles (for directory listing)
  Future<List<StudentProfile>> getAlumniDirectory({int limit = 100}) async {
    try {
      // v7.2: Remove orderBy to work with both flat and nested data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true)
          .limit(limit)
          .get();

      final profiles = query.docs
          .map((doc) {
            try {
              return StudentProfile.fromFirestore(doc);
            } catch (e) {
              debugPrint('🎓 ERROR parsing profile ${doc.id}: $e');
              return null;
            }
          })
          .whereType<StudentProfile>()
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();

      // Sort in memory instead
      profiles.sort((a, b) => b.metadata.updatedAt.compareTo(a.metadata.updatedAt));

      return profiles;
    } catch (e) {
      debugPrint('🎓 ERROR getting alumni directory: $e');
      return [];
    }
  }

  /// Search alumni by various criteria
  Future<List<StudentProfile>> searchAlumni({
    String? searchQuery,
    String? company,
    String? jobRole,
    int? graduationYear,
    String? department,
    List<String>? skills,
    int limit = 50,
  }) async {
    try {
      Query query = _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true);

      // Apply specific filters that can be queried directly
      if (company != null && company.isNotEmpty) {
        query = query.where('company', isEqualTo: company);
      }

      if (jobRole != null && jobRole.isNotEmpty) {
        query = query.where('jobRole', isEqualTo: jobRole);
      }

      if (graduationYear != null) {
        query = query.where('graduationYear', isEqualTo: graduationYear);
      }

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      query = query.limit(limit);

      final results = await query.get();
      var alumni = results.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();

      // Apply client-side filtering for complex queries
      if (searchQuery != null && searchQuery.isNotEmpty) {
        alumni = _filterBySearchQuery(alumni, searchQuery);
      }

      if (skills != null && skills.isNotEmpty) {
        alumni = _filterBySkills(alumni, skills);
      }

      return alumni;
    } catch (e) {
      debugPrint('Error searching alumni: $e');
      return [];
    }
  }

  /// Get alumni by company
  Future<List<StudentProfile>> getAlumniByCompany(String company) async {
    try {
      // v7.2: Remove orderBy to work with flat data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('company', isEqualTo: company)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();
    } catch (e) {
      debugPrint('Error getting alumni by company: $e');
      return [];
    }
  }

  /// Get alumni by graduation year
  Future<List<StudentProfile>> getAlumniByGraduationYear(int year) async {
    try {
      // v7.2: Remove orderBy to work with flat data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('graduationYear', isEqualTo: year)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();
    } catch (e) {
      debugPrint('Error getting alumni by graduation year: $e');
      return [];
    }
  }

  /// Get alumni by department
  Future<List<StudentProfile>> getAlumniByDepartment(String department) async {
    try {
      // v7.2: Remove orderBy to work with flat data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('department', isEqualTo: department)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();
    } catch (e) {
      debugPrint('Error getting alumni by department: $e');
      return [];
    }
  }

  /// Get specific alumni profile by ID
  Future<StudentProfile?> getAlumniById(String alumniId) async {
    try {
      final doc = await _usersCollection.doc(alumniId).get();

      if (!doc.exists) {
        return null;
      }

      final profile = StudentProfile.fromFirestore(doc);

      // Verify it's actually an alumni profile
      if (profile.role != UserRole.alumni || !_isValidAlumniProfile(profile)) {
        return null;
      }

      return profile;
    } catch (e) {
      debugPrint('Error getting alumni by ID: $e');
      return null;
    }
  }

  /// Stream alumni directory for real-time updates
  Stream<List<StudentProfile>> alumniDirectoryStream({int limit = 100}) {
    return _usersCollection
        .where('role', isEqualTo: UserRole.alumni.name)
        .where('profileCompleted', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentProfile.fromFirestore(doc))
              .where((profile) => _isValidAlumniProfile(profile))
              .toList(),
        );
  }

  /// Get filter options for UI dropdowns
  Future<Map<String, List<String>>> getFilterOptions() async {
    try {
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true)
          .get();

      final companies = <String>{};
      final jobRoles = <String>{};
      final departments = <String>{};
      final graduationYears = <int>{};
      final allSkills = <String>{};

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final company = data['company'] as String?;
        if (company != null && company.isNotEmpty) {
          companies.add(company);
        }

        final jobRole = data['jobRole'] as String?;
        if (jobRole != null && jobRole.isNotEmpty) {
          jobRoles.add(jobRole);
        }

        final department = data['department'] as String?;
        if (department != null && department.isNotEmpty) {
          departments.add(department);
        }

        final graduationYear = data['graduationYear'] as int?;
        if (graduationYear != null && graduationYear > 1900) {
          graduationYears.add(graduationYear);
        }

        final skills = data['skills'] as List<dynamic>?;
        if (skills != null) {
          allSkills.addAll(skills.cast<String>());
        }
      }

      final sortedCompanies = companies.toList()..sort();
      final sortedJobRoles = jobRoles.toList()..sort();
      final sortedDepartments = departments.toList()..sort();
      final sortedYears = graduationYears.toList()
        ..sort((a, b) => b.compareTo(a));
      final sortedSkills = allSkills.toList()..sort();

      return {
        'companies': sortedCompanies,
        'jobRoles': sortedJobRoles,
        'departments': sortedDepartments,
        'graduationYears': sortedYears.map((year) => year.toString()).toList(),
        'skills': sortedSkills,
      };
    } catch (e) {
      debugPrint('Error getting filter options: $e');
      return {
        'companies': [],
        'jobRoles': [],
        'departments': [],
        'graduationYears': [],
        'skills': [],
      };
    }
  }

  /// Get recent alumni profiles (recently updated)
  Future<List<StudentProfile>> getRecentAlumni({int limit = 10}) async {
    try {
      // v7.2: Remove orderBy to work with flat data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent alumni: $e');
      return [];
    }
  }

  /// Get featured alumni (alumni with complete profiles from top companies)
  Future<List<StudentProfile>> getFeaturedAlumni({int limit = 5}) async {
    try {
      // v7.2: Remove orderBy to work with flat data structures
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true)
          .get();

      final alumni = query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();

      // Sort by profile completeness and company presence
      alumni.sort((a, b) {
        final aScore = _calculateProfileScore(a);
        final bScore = _calculateProfileScore(b);
        return bScore.compareTo(aScore);
      });

      return alumni.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting featured alumni: $e');
      return [];
    }
  }

  /// Get alumni count by filters (for analytics)
  Future<Map<String, int>> getAlumniStats() async {
    try {
      final query = await _usersCollection
          .where('role', isEqualTo: UserRole.alumni.name)
          .where('profileCompleted', isEqualTo: true)
          .get();

      final alumni = query.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => _isValidAlumniProfile(profile))
          .toList();

      final stats = <String, int>{
        'total': alumni.length,
        'withCompany': alumni
            .where((a) => a.company?.isNotEmpty == true)
            .length,
        'withLinkedIn': alumni
            .where((a) => a.linkedinProfile?.isNotEmpty == true)
            .length,
        'withSkills': alumni.where((a) => a.skills?.isNotEmpty == true).length,
      };

      // Count by graduation year ranges
      final currentYear = DateTime.now().year;
      stats['recent'] = alumni
          .where(
            (a) =>
                a.graduationYear != null &&
                (currentYear - a.graduationYear!) <= 3,
          )
          .length;

      return stats;
    } catch (e) {
      debugPrint('Error getting alumni stats: $e');
      return {'total': 0};
    }
  }

  /// Private helper methods

  /// Check if alumni profile has minimum required information
  bool _isValidAlumniProfile(StudentProfile profile) {
    // v7.2: Alumni directory - email is optional for privacy, only require fullName
    return profile.role == UserRole.alumni &&
        profile.profileCompleted &&
        profile.personal.fullName.isNotEmpty;
  }

  /// Filter alumni by search query (client-side)
  List<StudentProfile> _filterBySearchQuery(
    List<StudentProfile> alumni,
    String query,
  ) {
    final queryLower = query.toLowerCase();

    return alumni
        .where(
          (profile) =>
              profile.personal.fullName.toLowerCase().contains(queryLower) ||
              profile.personal.effectiveDisplayName.toLowerCase().contains(
                queryLower,
              ) ||
              (profile.company?.toLowerCase().contains(queryLower) ?? false) ||
              (profile.jobRole?.toLowerCase().contains(queryLower) ?? false) ||
              (profile.department?.toLowerCase().contains(queryLower) ??
                  false) ||
              (profile.skills?.any(
                    (skill) => skill.toLowerCase().contains(queryLower),
                  ) ??
                  false),
        )
        .toList();
  }

  /// Filter alumni by skills (client-side)
  List<StudentProfile> _filterBySkills(
    List<StudentProfile> alumni,
    List<String> targetSkills,
  ) {
    return alumni
        .where(
          (profile) =>
              profile.skills != null &&
              targetSkills.any(
                (targetSkill) => profile.skills!.any(
                  (profileSkill) => profileSkill.toLowerCase().contains(
                    targetSkill.toLowerCase(),
                  ),
                ),
              ),
        )
        .toList();
  }

  /// Calculate profile completeness score for featured sorting
  int _calculateProfileScore(StudentProfile profile) {
    int score = 0;

    if (profile.company?.isNotEmpty == true) score += 2;
    if (profile.jobRole?.isNotEmpty == true) score += 2;
    if (profile.linkedinProfile?.isNotEmpty == true) score += 1;
    if (profile.skills?.isNotEmpty == true) score += 1;
    if (profile.graduationYear != null) score += 1;
    if (profile.personal.bio.isNotEmpty) score += 1;

    return score;
  }
}
