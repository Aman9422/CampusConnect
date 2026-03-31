import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/mentorship_service.dart';
import 'package:flutter/material.dart';

/// MentorshipProvider - v7.2: Multi-role ecosystem
///
/// Manages mentorship request state and operations.
/// Follows ProfileProvider pattern with proper lifecycle management.
class MentorshipProvider extends ChangeNotifier {
  final MentorshipService _mentorshipService;

  MentorshipProvider({MentorshipService? service})
    : _mentorshipService = service ?? MentorshipService.instance();

  // State variables (following ProfileProvider pattern)
  List<MentorshipRequest>? _requests;
  List<MentorshipRequest>? _pendingRequests;
  Map<String, int>? _stats;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  String? _userId;
  bool _isSending = false;
  bool _isResponding = false;

  // Getters
  List<MentorshipRequest>? get requests => _requests;
  List<MentorshipRequest>? get pendingRequests => _pendingRequests;
  Map<String, int>? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasRequests => _requests?.isNotEmpty ?? false;
  String? get error => _error;
  bool get isSending => _isSending;
  bool get isResponding => _isResponding;

  /// Initialize provider with user ID and load appropriate requests
  Future<void> initWithUser(String userId, String userRole) async {
    if (_isInitialized && _userId == userId) return;

    _isDisposed = false;
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (userRole == 'student') {
        _requests = await _mentorshipService.getStudentRequests(userId);
      } else if (userRole == 'alumni') {
        _requests = await _mentorshipService.getAllRequestsForAlumni(userId);
        _pendingRequests = await _mentorshipService.getPendingRequestsForAlumni(
          userId,
        );
        _stats = await _mentorshipService.getMentorshipStatsForAlumni(userId);
      }

      if (_isDisposed) return;

      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load mentorship requests';
      _isInitialized = true;
      debugPrint('MentorshipProvider init error: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Student Operations
  /// Create a new mentorship request
  Future<bool> createRequest({
    required String studentId,
    required String alumniId,
    required String title,
    required String description,
    required List<String> skills,
    required StudentProfile studentProfile,
    required StudentProfile alumniProfile,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      // Check if student already has an active request with this alumni
      final hasActive = await _mentorshipService.hasActiveRequest(
        studentId,
        alumniId,
      );
      if (hasActive) {
        throw Exception('You already have an active request with this alumni');
      }

      await _mentorshipService.createRequest(
        studentId: studentId,
        alumniId: alumniId,
        title: title,
        description: description,
        skills: skills,
        studentProfile: studentProfile,
        alumniProfile: alumniProfile,
      );

      // Refresh requests list
      await _refreshStudentRequests(studentId);

      _isSending = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isSending = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('MentorshipProvider create request error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get student's sent requests
  Future<void> loadStudentRequests(String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _requests = await _mentorshipService.getStudentRequests(studentId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load your mentorship requests';
      debugPrint('MentorshipProvider load student requests error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Alumni Operations
  /// Respond to a mentorship request
  /// v7.3: Returns chatId for navigation after acceptance
  Future<String?> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
  }) async {
    _isResponding = true;
    _error = null;
    notifyListeners();

    try {
      final chatId = await _mentorshipService.respondToRequest(
        requestId: requestId,
        accepted: accepted,
        responseMessage: responseMessage,
      );

      // Update local state
      if (_requests != null) {
        final requestIndex = _requests!.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1) {
          final updatedRequest = _requests![requestIndex].copyWith(
            status: accepted
                ? MentorshipRequestStatus.accepted
                : MentorshipRequestStatus.rejected,
            respondedAt: DateTime.now(),
            responseMessage: responseMessage,
            chatId: chatId, // v7.3: Include chatId
          );
          _requests![requestIndex] = updatedRequest;
        }
      }

      // Update pending requests
      if (_pendingRequests != null) {
        _pendingRequests!.removeWhere((r) => r.id == requestId);
      }

      _isResponding = false;
      _error = null;
      notifyListeners();
      return chatId; // Return chatId for UI navigation
    } catch (e) {
      _isResponding = false;
      _error = 'Failed to respond to request';
      debugPrint('MentorshipProvider respond error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Load alumni's received requests
  Future<void> loadAlumniRequests(String alumniId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _requests = await _mentorshipService.getAllRequestsForAlumni(alumniId);
      _pendingRequests = await _mentorshipService.getPendingRequestsForAlumni(
        alumniId,
      );
      _stats = await _mentorshipService.getMentorshipStatsForAlumni(alumniId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load mentorship requests';
      debugPrint('MentorshipProvider load alumni requests error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark mentorship as completed with optional rating and feedback
  /// v7.3: Enhanced with completion data
  Future<bool> markCompleted(
    String requestId, {
    int? rating,
    String? feedback,
  }) async {
    try {
      await _mentorshipService.markCompleted(
        requestId,
        rating: rating,
        feedback: feedback,
      );

      // Update local state
      if (_requests != null) {
        final requestIndex = _requests!.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1) {
          final updatedRequest = _requests![requestIndex].copyWith(
            status: MentorshipRequestStatus.completed,
            completedAt: DateTime.now(),
            rating: rating,
            feedback: feedback,
          );
          _requests![requestIndex] = updatedRequest;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to mark mentorship as completed';
      debugPrint('MentorshipProvider mark completed error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Shared Operations
  /// Get specific request by ID
  Future<MentorshipRequest?> getRequestById(String requestId) async {
    try {
      return await _mentorshipService.getRequestById(requestId);
    } catch (e) {
      debugPrint('MentorshipProvider get request by ID error: $e');
      return null;
    }
  }

  /// Refresh current user's requests
  Future<void> refresh() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Determine user role from existing requests
      if (_pendingRequests != null) {
        // This is an alumni user
        await loadAlumniRequests(_userId!);
      } else {
        // This is a student user
        await _refreshStudentRequests(_userId!);
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh requests';
      debugPrint('MentorshipProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper method to refresh student requests
  Future<void> _refreshStudentRequests(String studentId) async {
    _requests = await _mentorshipService.getStudentRequests(studentId);
  }

  /// Stream methods for real-time updates
  /// Start listening to student requests
  void startListeningToStudentRequests(String studentId) {
    _mentorshipService
        .requestsStreamForUser(studentId)
        .listen(
          (requests) {
            if (!_isDisposed) {
              _requests = requests;
              notifyListeners();
            }
          },
          onError: (error) {
            if (!_isDisposed) {
              _error = 'Real-time update failed';
              debugPrint('MentorshipProvider student stream error: $error');
              notifyListeners();
            }
          },
        );
  }

  /// Start listening to alumni requests
  void startListeningToAlumniRequests(String alumniId) {
    _mentorshipService
        .requestsStreamForAlumni(alumniId)
        .listen(
          (requests) {
            if (!_isDisposed) {
              _requests = requests;
              _pendingRequests = requests
                  .where((r) => r.status == MentorshipRequestStatus.pending)
                  .toList();
              notifyListeners();
            }
          },
          onError: (error) {
            if (!_isDisposed) {
              _error = 'Real-time update failed';
              debugPrint('MentorshipProvider alumni stream error: $error');
              notifyListeners();
            }
          },
        );
  }

  /// Utility methods
  /// Get requests by status
  List<MentorshipRequest> getRequestsByStatus(MentorshipRequestStatus status) {
    if (_requests == null) return [];
    return _requests!.where((r) => r.status == status).toList();
  }

  /// Get pending requests count
  int get pendingRequestsCount => _pendingRequests?.length ?? 0;

  /// Get accepted mentorships count
  int get acceptedMentorshipsCount {
    if (_requests == null) return 0;
    return _requests!
        .where((r) => r.status == MentorshipRequestStatus.accepted)
        .length;
  }

  /// Get completed mentorships count
  int get completedMentorshipsCount {
    if (_requests == null) return 0;
    return _requests!
        .where((r) => r.status == MentorshipRequestStatus.completed)
        .length;
  }

  /// Check if user can send request to specific alumni
  bool canSendRequestTo(String alumniId) {
    if (_requests == null) return true;

    // Check if there's already an active request to this alumni
    return !_requests!.any(
      (r) =>
          r.alumniId == alumniId &&
          (r.status == MentorshipRequestStatus.pending ||
              r.status == MentorshipRequestStatus.accepted),
    );
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider (on logout)
  void reset() {
    _isDisposed = true;
    _requests = null;
    _pendingRequests = null;
    _stats = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _userId = null;
    _isSending = false;
    _isResponding = false;
    notifyListeners();
  }
}
