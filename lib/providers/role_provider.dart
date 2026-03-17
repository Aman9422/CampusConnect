import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:flutter/material.dart';

/// v7.1: RoleProvider - Manages user role state and role-based navigation
class RoleProvider extends ChangeNotifier {
  final ProfileService _profileService;

  RoleProvider({ProfileService? service})
    : _profileService = service ?? ProfileService.instance();

  UserRole? _role;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  String? _userId;

  // Getters
  UserRole? get role => _role;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasRole => _role != null;
  String? get error => _error;

  /// Initialize with user ID - fetches role from Firestore
  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _userId == userId) return;

    _isDisposed = false;
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _profileService.getProfile(userId);
      if (_isDisposed) return;

      _role = profile?.role;
      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load user role';
      _isInitialized = true;
      debugPrint('RoleProvider init error: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Set role (during registration or role selection)
  void setRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  /// Save role to Firestore
  Future<bool> saveRole(String userId, UserRole role) async {
    try {
      await _profileService.updateUserRole(userId, role);
      _role = role;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('RoleProvider saveRole error: $e');
      return false;
    }
  }

  /// Reset on logout
  void reset() {
    _isDisposed = true;
    _role = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _userId = null;
    notifyListeners();
  }
}
