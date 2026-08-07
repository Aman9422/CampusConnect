import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;

  ProfileProvider({ProfileService? service})
    : _profileService = service ?? ProfileService.instance();

  // State
  StudentProfile? _profile;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isSaving = false;

  // Getters
  StudentProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isSaving => _isSaving;
  bool get hasProfile => _profile != null;
  bool get isProfileIncomplete => _profile?.isIncomplete ?? true;
  bool get isProfileCompleted =>
      _profile?.profileCompleted ?? false; // Root level field

  // V6.3: Flag to stop operations after logout
  bool _isDisposed = false;

  // v8.4.9 (MB18): uid for which the email backfill was already attempted —
  // prevents re-reading the Firestore doc to re-check `personal.email` on
  // every rebuild. Cleared on reset so a re-login tries again.
  String? _emailBackfillUid;

  /// Initialize provider with userId (called from HomePage after auth)
  Future<void> initWithUser(String userId, String email) async {
    // Don't re-initialize if already done for this user
    if (_isInitialized && _profile?.uid == userId) {
      return;
    }
    
    _isDisposed = false; // V6.3: Reset disposed flag

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _profileService.initializeProfile(userId, email);
      if (_isDisposed) return; // V6.3: Stop if logged out during async

      // v8.4.9 (MB18): backfill the auth email into `personal.email` for docs
      // that stored a blank value (docs predating the denormalized field or
      // an older write that authored `personal` without email). The service
      // only writes a targeted `personal.email` merge (portfolio untouched)
      // when the stored value is blank; `_emailBackfillUid` makes this a
      // once-per-user attempt so we don't re-read the doc on every rebuild.
      if (_emailBackfillUid != userId && email.isNotEmpty) {
        _emailBackfillUid = userId;
        final didBackfill = await _profileService.backfillEmail(
          userId,
          email,
        );
        if (didBackfill) {
          // Mirror into memory so the setup/edit screens show the email now
          // (the profile's personal.copyWith is pure — no Firestore write).
          final current = _profile;
          if (current != null &&
              current.personal.email.isEmpty &&
              !_isDisposed) {
            _profile = current.copyWith(
              personal: current.personal.copyWith(email: email),
            );
          }
        }
      }

      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return; // V6.3: Don't handle errors if logged out
      _error = 'Failed to load profile';
      debugPrint('ProfileProvider init error: $e');
      // Create fallback empty profile
      _profile = StudentProfile.empty(userId, email);
      _isInitialized = true;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Update profile
  Future<bool> updateProfile(StudentProfile updatedProfile) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _profileService.updateProfile(updatedProfile);
      _profile = updatedProfile;
      _isSaving = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = 'Failed to update profile';
      debugPrint('ProfileProvider update error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Mark profile as completed (wraps service call + internal state update)
  Future<bool> markProfileCompleted() async {
    if (_profile == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _profileService.markProfileCompleted(_profile!.uid);
      _profile = _profile!.copyWith(profileCompleted: true);
      _isSaving = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = 'Failed to mark profile as completed';
      debugPrint('ProfileProvider markProfileCompleted error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Refresh profile from Firestore
  Future<void> refresh() async {
    if (_profile == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final freshProfile = await _profileService.getProfile(_profile!.uid);
      if (freshProfile != null) {
        _profile = freshProfile;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh profile';
      debugPrint('ProfileProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset provider (on logout)
  void reset() {
    _isDisposed = true; // V6.3: Mark as disposed first
    _profile = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _isSaving = false;
    _emailBackfillUid = null; // v8.4.9 (MB18): retry backfill on next login
    notifyListeners();
  }
}
