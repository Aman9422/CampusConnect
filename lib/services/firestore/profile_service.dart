import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ProfileService - Handles all Firestore operations for user profiles
///
/// CRITICAL: All methods use strict UID-based document access
/// - Every read/write uses users/{uid} where uid = FirebaseAuth.currentUser.uid
/// - Never queries the collection without a specific UID
/// - Ensures complete data isolation between users
class ProfileService {
  final FirebaseFirestore _firestore;

  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Singleton pattern (matches existing service architecture)
  static final ProfileService _instance = ProfileService();
  factory ProfileService.instance() => _instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Get profile for a specific user by UID (strict UID-scoped access)
  Future<StudentProfile?> getProfile(String uid) async {
    try {
      // Direct document access - never use queries or .limit()
      final doc = await _usersCollection.doc(uid).get();

      if (!doc.exists) {
        return null;
      }

      return StudentProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  /// Create a new profile (first login)
  ///
  /// v8.9.2 (project_info__25/26 — "No New Recommendations After Filling
  /// Portfolio (80% Strength)"): BOTH branches now write with
  /// `SetOptions(merge: true)`. The previous `else` branch was the ONLY
  /// non-merge `set()` on `users/{uid}` in the whole codebase, and a
  /// non-merge `set()` REPLACES the entire document. Any execution of that
  /// branch against a doc that already existed (a race with
  /// `updateUserRole`, a stale `profileExists` read, or a re-init after
  /// logout/re-login) permanently wiped the student's profile AND portfolio
  /// — leaving exactly the observed empty shell
  /// `(metadata, role, personal.email)`. merge:true creates the doc when
  /// missing and only fills missing fields when present, so the full
  /// user document can never be destroyed by this path again.
  Future<void> createProfile(String uid, String email) async {
    try {
      final profile = StudentProfile.empty(uid, email);
      final docRef = _usersCollection.doc(uid);
      await docRef.set(profile.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating profile: $e');
      rethrow;
    }
  }

  /// Update profile
  Future<void> updateProfile(StudentProfile profile) async {
    try {
      // Update the updatedAt timestamp
      final updatedProfile = profile.copyWith(
        metadata: ProfileMetadata(
          createdAt: profile.metadata.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      await _usersCollection
          .doc(profile.uid)
          .set(updatedProfile.toFirestore(), SetOptions(merge: true));

      // v7.4: Keep optional public profile projection in sync for alumni
      if (updatedProfile.role == UserRole.alumni) {
        await syncPublicProfile(updatedProfile);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  /// Mark profile as completed (called after first-time setup)
  Future<void> markProfileCompleted(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'profileCompleted': true, // Root level per Firestore spec
        'metadata.updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error marking profile as completed: $e');
      rethrow;
    }
  }

  /// Stream profile changes
  Stream<StudentProfile?> profileStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return StudentProfile.fromFirestore(doc);
    });
  }

  /// Check if profile exists
  Future<bool> profileExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking profile existence: $e');
      return false;
    }
  }

  /// v7.1: Update user role
  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      await _usersCollection.doc(uid).set({
        'role': role.name,
        'metadata': {'updatedAt': Timestamp.fromDate(DateTime.now())},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  /// v8.4.9 (MB18): Backfill the auth email into `personal.email` when the
  /// stored document has a blank/missing value (docs that predate the
  /// denormalized field, or an older write that authored `personal` without
  /// the email). Uses a targeted merge on `personal.email` only, so the
  /// `portfolio` map and every other section are untouched. Returns true when
  /// a write was issued; false when nothing needed changing.
  Future<bool> backfillEmail(String uid, String email) async {
    if (email.isEmpty) return false;
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      final personal = data?['personal'] as Map<String, dynamic>?;
      if (personal?['email'] is String &&
          (personal!['email'] as String).isNotEmpty) {
        return false; // already populated
      }
      await _usersCollection.doc(uid).set({
        'personal.email': email,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error backfilling email: $e');
      return false; // non-fatal — the profile still loads
    }
  }

  /// Initialize profile (get or create)
  Future<StudentProfile> initializeProfile(String uid, String email) async {
    try {
      // Check if profile exists
      final exists = await profileExists(uid);

      if (!exists) {
        // Create new profile
        await createProfile(uid, email);
      }

      // Get the profile
      final profile = await getProfile(uid);

      if (profile == null) {
        // Fallback: return empty profile
        return StudentProfile.empty(uid, email);
      }

      return profile;
    } catch (e) {
      debugPrint('Error initializing profile: $e');
      // Fallback: return empty profile
      return StudentProfile.empty(uid, email);
    }
  }

  /// v7.4: Ensure alumni has a stable public profile key.
  Future<String> ensurePublicProfileKey(StudentProfile profile) async {
    if (profile.publicProfileKey != null &&
        profile.publicProfileKey!.isNotEmpty) {
      return profile.publicProfileKey!;
    }

    final baseName = profile.personal.effectiveDisplayName.isNotEmpty
        ? profile.personal.effectiveDisplayName
        : 'alumni';
    final slug = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final uidSuffix = profile.uid.length >= 6
        ? profile.uid.substring(profile.uid.length - 6)
        : profile.uid;
    final key = '${slug.isEmpty ? 'alumni' : slug}-$uidSuffix';

    await _usersCollection.doc(profile.uid).set({
      'publicProfileKey': key,
      'metadata.updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    return key;
  }

  /// v7.4: Sync public profile projection for shareable alumni links.
  Future<void> syncPublicProfile(StudentProfile profile) async {
    final key = profile.publicProfileKey;
    if (key == null || key.isEmpty || !profile.isPublicProfile) {
      if (key != null && key.isNotEmpty) {
        await _firestore
            .collection('public_profiles')
            .doc(key)
            .delete()
            .catchError((_) {
              // Ignore when projection does not exist yet
            });
      }
      return;
    }

    final opportunitiesCount = await _firestore
        .collection('opportunities')
        .where('alumniId', isEqualTo: profile.uid)
        .count()
        .get();

    await _firestore.collection('public_profiles').doc(key).set({
      'uid': profile.uid,
      'profileKey': key,
      'isPublic': true,
      'name': profile.personal.effectiveDisplayName,
      'jobRole': profile.jobRole,
      'company': profile.company,
      'designation': profile.designation,
      'careerInterest': profile.careerInterest,
      'skills': profile.skills ?? <String>[],
      'linkedinProfile': profile.linkedinProfile,
      'experience':
          '${profile.jobRole ?? "Alumni"} at ${profile.company ?? "CampusConnect Network"}',
      'opportunitiesPosted': opportunitiesCount.count ?? 0,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// v7.4: Resolve a public profile key to full alumni profile.
  Future<StudentProfile?> getPublicAlumniProfile(String profileKey) async {
    try {
      final publicDoc = await _firestore
          .collection('public_profiles')
          .doc(profileKey)
          .get();
      if (!publicDoc.exists) return null;
      final data = publicDoc.data();
      if (data == null || data['isPublic'] != true) return null;
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;
      return getProfile(uid);
    } catch (e) {
      debugPrint('Error getting public alumni profile: $e');
      return null;
    }
  }

  /// v7.4: Get public profile projection data by key.
  Future<Map<String, dynamic>?> getPublicProfileProjection(
    String profileKey,
  ) async {
    try {
      final publicDoc = await _firestore
          .collection('public_profiles')
          .doc(profileKey)
          .get();
      if (!publicDoc.exists) return null;
      final data = publicDoc.data();
      if (data == null || data['isPublic'] != true) return null;
      return data;
    } catch (e) {
      debugPrint('Error getting public profile projection: $e');
      return null;
    }
  }
}
