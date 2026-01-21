import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/utilities/analytics_helper.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// V5.1: Enhanced with offline detection and better error handling
/// Single source of truth for:
/// - Active placements
/// - User's applied placement IDs
/// - Application dates
/// - Loading states
/// - Network connectivity
class PlacementsProvider with ChangeNotifier {
  final PlacementsService _service;
  final String userId;
  final Connectivity _connectivity = Connectivity();

  PlacementsProvider({required PlacementsService service, required this.userId})
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

  // Getters
  List<Placement> get placements => _placements;
  Set<String> get appliedPlacementIds => _appliedPlacementIds;
  Map<String, DateTime> get appliedDates => _appliedDates;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isOnline => _isOnline; // V5.1: Expose network state

  bool hasApplied(String placementId) =>
      _appliedPlacementIds.contains(placementId);
  bool isApplying(String placementId) => _applyingPlacementId == placementId;
  DateTime? getAppliedDate(String placementId) => _appliedDates[placementId];

  /// V5.1: Check if any apply operation is in progress
  bool get isAnyApplyInProgress => _applyingPlacementId != null;

  /// Initialize: Load placements and user applications ONCE
  /// V5 Optimization: Fetch data once instead of constant streams
  /// V5.1: Monitor network connectivity
  Future<void> init() async {
    if (_isInitialized) return; // Already initialized

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
  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
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
    try {
      final placementsSnapshot = await _service.getAllPlacementsOnce();
      _placements = placementsSnapshot;
    } catch (e) {
      debugPrint('Error loading placements: $e');
      rethrow;
    }
  }

  /// Load user's applications
  Future<void> _loadUserApplications() async {
    try {
      final applications = await _service.getUserApplicationsOnce(userId);
      _appliedPlacementIds = applications.map((app) => app.placementId).toSet();
      _appliedDates = {
        for (var app in applications) app.placementId: app.appliedAt,
      };
    } catch (e) {
      debugPrint('Error loading user applications: $e');
      rethrow;
    }
  }

  /// Refresh placements (manual refresh)
  /// V5.1: Check network before refreshing
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
      _error = null;
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply for a placement with optimistic update
  /// V5: Instant UI feedback, backend validation
  /// V5.1: Enhanced guardrails and error handling
  Future<bool> applyForPlacement({
    required String placementId,
    required String resume,
    String? company,
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
    // Clean up resources
    super.dispose();
  }
}
