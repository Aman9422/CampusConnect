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
  Future<void> createProfile(String uid, String email) async {
    try {
      final profile = StudentProfile.empty(uid, email);
      await _usersCollection.doc(uid).set(profile.toFirestore());
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
}
