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
    notifyListeners();
  }
}
