import 'dart:async';

import 'package:campusconnect/models/application.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/eligibility_engine.dart';
import 'package:campusconnect/services/firestore/notifications_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/utilities/analytics_helper.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// V5.1.1: Enhanced with proper lifecycle management
/// V6.4: Added notification creation on successful application
/// V6.5: Added rule-based eligibility checking
/// Single source of truth for:
/// - Active placements
/// - User's applied placement IDs
/// - Application dates
/// - Loading states
/// - Network connectivity
/// - Eligibility status (v6.5)
class PlacementsProvider with ChangeNotifier {
  final PlacementsService _service;
  final NotificationsService _notificationsService =
      NotificationsService.instance();
  String? userId; // V5.1.1: Made nullable for logout handling
  final Connectivity _connectivity = Connectivity();
  // v8.4.2 (S3c/M5): keep the subscription so it can be cancelled on
  // reset()/dispose() — prevents leaks + duplicate notifyListeners across
  // logins and notify-after-reset.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // V6.5: Student profile for eligibility checking
  StudentProfile? _userProfile;

  PlacementsProvider({required PlacementsService service, this.userId})
    : _service = service;

  // State
  List<Placement> _placements = [];
  Set<String> _appliedPlacementIds = {};
  Map<String, DateTime> _appliedDates = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _applyingPlacementId; // Track which placement is being applied to
  bool _isOnline = true; // V5.1: Network state

  // V6.5: Eligibility cache
  Map<String, PlacementEligibility> _eligibilityCache = {};

  // v9.1: Applicant counts (teacher/alumni) — placementId → unique students
  Map<String, int> _applicantCounts = {};
  bool _applicantCountsLoaded = false;

  // Getters
  List<Placement> get placements => _placements;
  Set<String> get appliedPlacementIds => _appliedPlacementIds;
  Map<String, DateTime> get appliedDates => _appliedDates;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isOnline => _isOnline; // V5.1: Expose network state

  // v9.1: applicant count getters
  int applicantCountFor(String placementId) =>
      _applicantCounts[placementId] ?? 0;
  bool get hasApplicantCounts => _applicantCountsLoaded;

  bool hasApplied(String placementId) =>
      _appliedPlacementIds.contains(placementId);
  bool isApplying(String placementId) => _applyingPlacementId == placementId;
  DateTime? getAppliedDate(String placementId) => _appliedDates[placementId];

  // V6.5: Eligibility getters
  PlacementEligibility? getEligibility(String placementId) =>
      _eligibilityCache[placementId];

  bool isEligible(String placementId) =>
      _eligibilityCache[placementId]?.isEligible ?? false;

  /// V6.5: Get eligible placements only
  List<Placement> get eligiblePlacements => _placements
      .where((p) => _eligibilityCache[p.id]?.isEligible ?? false)
      .toList();

  /// V6.5: Get placements sorted by eligibility (eligible first)
  List<Placement> get sortedPlacements {
    if (_eligibilityCache.isEmpty) return _placements;
    return EligibilityEngine.sortByEligibility(
      placements: _placements,
      eligibilityMap: _eligibilityCache,
    );
  }

  /// V5.1: Check if any apply operation is in progress
  bool get isAnyApplyInProgress => _applyingPlacementId != null;

  /// V6.5: Update user profile for eligibility checking
  void updateUserProfile(StudentProfile profile) {
    _userProfile = profile;
    _recalculateEligibility();
  }

  /// V5.1.1: Initialize with user ID (called after login)
  Future<void> initWithUser(String newUserId) async {
    // Only reinitialize if userId changed or not initialized
    if (userId == newUserId && _isInitialized) {
      return;
    }

    userId = newUserId;
    await init();
  }

  /// V5.1.1: Reset state (called on logout)
  void reset() {
    userId = null;
    _placements = [];
    _appliedPlacementIds = {};
    _appliedDates = {};
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _applyingPlacementId = null;
    _userProfile = null;
    _eligibilityCache = {};
    // v9.1: clear applicant counts on logout (teacher session leak guard)
    _applicantCounts = {};
    _applicantCountsLoaded = false;
    _isDisposed = true; // V6.3: Mark as disposed to stop any pending operations
    // v8.4.2 (S3c/M5): cancel the connectivity subscription so no listener
    // survives logout (prevents leaks + duplicates on the next login).
    _cancelConnectivityMonitoring();
    notifyListeners();
  }

  // V6.3: Flag to stop operations after logout
  bool _isDisposed = false;

  /// Initialize: Load placements and user applications ONCE
  /// V5 Optimization: Fetch data once instead of constant streams
  /// V5.1: Monitor network connectivity
  Future<void> init() async {
    if (_isInitialized) return; // Already initialized
    if (userId == null) return; // V6.3: Don't init without user

    _isDisposed = false; // V6.3: Reset disposed flag on init

    // V5.1: Start monitoring network connectivity
    _startConnectivityMonitoring();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load placements (one-time fetch)
      await _loadPlacements();

      // Load user applications (one-time fetch)
      await _loadUserApplications();

      _isInitialized = true;
      _error = null;
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
      debugPrint('PlacementsProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// V5.1: Monitor network connectivity changes
  /// v8.4.2 (S3c/M5): the subscription is kept so it can be cancelled on
  /// reset()/dispose(); the callback guards with [_isDisposed] so it never
  /// notifies listeners after logout/provider disposal.
  void _startConnectivityMonitoring() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (_isDisposed) return; // v8.4.2 (S3c/M5): no notify after dispose

      // Convert List<ConnectivityResult> to bool
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        debugPrint(
          'Network status changed: ${_isOnline ? "Online" : "Offline"}',
        );
        notifyListeners();
      }
    });
  }

  /// v8.4.2 (S3c/M5): cancel the connectivity subscription and clear the
  /// reference so it can be re-established on the next [init].
  void _cancelConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// V5.1: Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return _isOnline; // Return last known state
    }
  }

  /// Load all active placements
  Future<void> _loadPlacements() async {
    if (_isDisposed || userId == null) return; // V6.3: Stop if logged out
    try {
      final placementsSnapshot = await _service.getAllPlacementsOnce();
      if (_isDisposed) return; // V6.3: Check again after async operation
      _placements = placementsSnapshot;
    } catch (e) {
      if (_isDisposed) return; // V6.3: Don't rethrow if logged out
      debugPrint('Error loading placements: $e');
      rethrow;
    }
  }

  /// Load user's applications
  /// V5.1.1: Safely handle null userId
  Future<void> _loadUserApplications() async {
    if (userId == null || _isDisposed) {
      debugPrint('Cannot load applications: userId is null');
      return; // Skip loading if not logged in
    }

    try {
      final applications = await _service.getUserApplicationsOnce(userId!);
      _appliedPlacementIds = applications.map((app) => app.placementId).toSet();
      _appliedDates = {
        for (var app in applications) app.placementId: app.appliedAt,
      };
    } catch (e) {
      debugPrint('Error loading user applications: $e');
      rethrow;
    }
  }

  /// V6.5: Recalculate eligibility for all placements
  void _recalculateEligibility() {
    if (_userProfile == null || _placements.isEmpty) {
      _eligibilityCache = {};
      return;
    }

    _eligibilityCache = EligibilityEngine.checkAllEligibility(
      placements: _placements,
      profile: _userProfile!,
      appliedPlacementIds: _appliedPlacementIds,
    );

    notifyListeners();
  }

  /// Refresh placements (manual refresh)
  /// V5.1: Check network before refreshing
  /// V6.5: Recalculate eligibility after refresh
  Future<void> refresh() async {
    // V5.1: Check connectivity
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      _error = 'No internet connection';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadPlacements();
      await _loadUserApplications();
      _recalculateEligibility(); // V6.5
      _error = null;
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a placement posting (teacher/alumni management)
  Future<bool> createPlacement({
    required String company,
    required String role,
    required String description,
    required String eligibility,
    required String salary,
    required DateTime deadline,
    PlacementRequirements requirements = const PlacementRequirements(),
  }) async {
    if (userId == null || _isDisposed) {
      _error = 'You must be logged in to post a placement';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.createPlacement(
        createdBy: userId!,
        company: company,
        role: role,
        description: description,
        eligibility: eligibility,
        salary: salary,
        deadline: deadline,
        requirements: requirements,
      );

      await _loadPlacements();
      _recalculateEligibility();
      _error = null;
      return true;
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
      debugPrint('PlacementsProvider createPlacement error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing placement posting (teacher/alumni management)
  Future<bool> updatePlacement(Placement placement) async {
    if (userId == null || _isDisposed) {
      _error = 'You must be logged in to update a placement';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updatePlacement(updatedBy: userId!, placement: placement);

      final index = _placements.indexWhere((p) => p.id == placement.id);
      if (index != -1) {
        _placements[index] = placement;
      } else {
        await _loadPlacements();
      }

      _recalculateEligibility();
      _error = null;
      return true;
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
      debugPrint('PlacementsProvider updatePlacement error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply for a placement with optimistic update
  /// V5: Instant UI feedback, backend validation
  /// V5.1: Enhanced guardrails and error handling
  /// V6.4: Added notification creation on success
  ///
  /// v8.4.1 (T5): Optionally snapshots the student's portfolio resume at
  /// apply time — `resumeVersion`, `resumeStoragePath` and
  /// `atsScoreAtApplication` are forwarded to the Cloud Function so the
  /// application preserves the exact resume used (docs/Task.md Phase 8).
  Future<bool> applyForPlacement({
    required String placementId,
    required String resume,
    String? company,
    String? role,
    int? resumeVersion,
    String? resumeStoragePath,
    int? atsScoreAtApplication,
  }) async {
    // V5.1: GUARDRAIL - Check if already applied
    if (_appliedPlacementIds.contains(placementId)) {
      debugPrint('Already applied to placement: $placementId');
      return true; // Already applied, return success
    }

    // V5.1: GUARDRAIL - Prevent re-entrant calls
    if (_applyingPlacementId != null) {
      throw Exception('Another application is already in progress');
    }

    // V5.1: GUARDRAIL - Check network connectivity
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      throw Exception('No internet connection. Please check your network');
    }

    // V5.1: GUARDRAIL - Validate resume
    if (resume.trim().isEmpty) {
      throw Exception('Resume information is required');
    }

    // Set applying state (prevents double-tap)
    _applyingPlacementId = placementId;
    notifyListeners();

    // Optimistic update: Add to applied set immediately
    _appliedPlacementIds.add(placementId);
    _appliedDates[placementId] = DateTime.now();
    notifyListeners();

    try {
      // Call Cloud Function (HTTPS Callable)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'logPlacementApplication',
      );

      final result = await callable
          .call({
            'placementId': placementId,
            'resumeUrl': resume,
            // v8.4.1 (T5): Resume snapshot at apply time.
            'resumeVersion': resumeVersion,
            'resumeStoragePath': resumeStoragePath,
            'atsScoreAtApplication': atsScoreAtApplication,
            'company': company ?? 'Unknown',
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      // Validate response
      if (result.data is! Map<String, dynamic>) {
        throw Exception('Unexpected response from server');
      }

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (!success) {
        final message =
            data['message'] as String? ?? 'Failed to submit application';
        throw Exception(message);
      }

      // Success: Keep optimistic update
      _applyingPlacementId = null;
      notifyListeners();

      // V6.4: Create notification for successful application
      if (userId != null) {
        await _notificationsService.notifyPlacementApplied(
          userId: userId!,
          placementId: placementId,
          company: company ?? 'Unknown',
          role: role ?? 'Position',
        );
      }

      // V5.1: Log analytics success
      await AnalyticsHelper.logPlacementApplySuccess(
        placementId: placementId,
        company: company ?? 'Unknown',
      );

      return true;
    } catch (e) {
      // Rollback optimistic update on error
      _appliedPlacementIds.remove(placementId);
      _appliedDates.remove(placementId);
      _applyingPlacementId = null;
      notifyListeners();

      debugPrint('Error applying for placement: $e');

      // V5.1: Log analytics failure
      await AnalyticsHelper.logPlacementApplyFailure(
        placementId: placementId,
        company: company ?? 'Unknown',
        errorReason: e.toString(),
      );

      // V5.1: Throw user-friendly error
      throw Exception(ErrorMessages.getUserFriendlyMessage(e));
    }
  }

  /// v9.1: Unique applicant count per placement (teacher/alumni cards).
  ///
  /// One-time load; callers decide when to refresh. Non-fatal on failure —
  /// cards degrade to showing no count rather than blocking the list.
  Future<void> loadApplicantCounts({List<String>? placementIds}) async {
    if (_isDisposed) return;
    final ids = placementIds ?? _placements.map((p) => p.id).toList();
    if (ids.isEmpty) return;

    try {
      final counts = await _service.getApplicantCounts(ids);
      if (_isDisposed) return;
      _applicantCounts = counts;
      _applicantCountsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PlacementsProvider loadApplicantCounts error: $e');
    }
  }

  /// v9.1: All applicants for a placement (teacher/alumni drill-down).
  Future<List<Application>> getApplicationsForPlacement(
      String placementId) async {
    return _service.getApplicationsForPlacement(placementId);
  }

  /// v9.1: Advance an application through the pipeline
  /// (`shortlisted` → `interviewed` → `placed`, or `rejected`).
  ///
  /// Wraps the `updateApplicationStatus` onCall with a 30s timeout and
  /// friendly error translation. Callers should refresh applicant counts or
  /// re-fetch the list after a success.
  Future<bool> updateApplicationStatus({
    required String placementId,
    required String studentId,
    required String status,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'updateApplicationStatus',
      );

      final result = await callable
          .call({
            'placementId': placementId,
            'studentId': studentId,
            'status': status,
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      if (result.data is! Map<String, dynamic>) {
        throw Exception('Unexpected response from server');
      }

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(
          data['message'] as String? ?? 'Failed to update application status',
        );
      }

      return true;
    } catch (e) {
      debugPrint('PlacementsProvider updateApplicationStatus error: $e');
      throw Exception(ErrorMessages.getUserFriendlyMessage(e));
    }
  }

  /// Get placement by ID
  Placement? getPlacementById(String placementId) {
    try {
      return _placements.firstWhere((p) => p.id == placementId);
    } catch (e) {
      return null;
    }
  }

  /// Filter placements by company
  List<Placement> getPlacementsByCompany(String company) {
    return _placements.where((p) => p.company == company).toList();
  }

  @override
  void dispose() {
    // v8.4.2 (S3c/M5): cancel the connectivity subscription to prevent leaks
    // when the provider is disposed (e.g. app teardown).
    _cancelConnectivityMonitoring();
    _isDisposed = true;
    super.dispose();
  }
}
