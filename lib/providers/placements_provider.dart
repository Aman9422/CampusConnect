import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// V5: Centralized state management for placements
/// Single source of truth for:
/// - Active placements
/// - User's applied placement IDs
/// - Application dates
/// - Loading states
class PlacementsProvider with ChangeNotifier {
  final PlacementsService _service;
  final String userId;

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

  // Getters
  List<Placement> get placements => _placements;
  Set<String> get appliedPlacementIds => _appliedPlacementIds;
  Map<String, DateTime> get appliedDates => _appliedDates;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  bool hasApplied(String placementId) =>
      _appliedPlacementIds.contains(placementId);
  bool isApplying(String placementId) => _applyingPlacementId == placementId;
  DateTime? getAppliedDate(String placementId) => _appliedDates[placementId];

  /// Initialize: Load placements and user applications ONCE
  /// V5 Optimization: Fetch data once instead of constant streams
  Future<void> init() async {
    if (_isInitialized) return; // Already initialized

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
      _error = 'Failed to load placements: ${e.toString()}';
      debugPrint('PlacementsProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadPlacements();
      await _loadUserApplications();
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply for a placement with optimistic update
  /// V5: Instant UI feedback, backend validation
  Future<bool> applyForPlacement({
    required String placementId,
    required String resume,
    String? company,
  }) async {
    // Prevent duplicate applies
    if (_appliedPlacementIds.contains(placementId)) {
      return true; // Already applied
    }

    // Set applying state
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
        throw Exception(data['message'] ?? 'Failed to submit application');
      }

      // Success: Keep optimistic update
      _applyingPlacementId = null;
      notifyListeners();
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      _appliedPlacementIds.remove(placementId);
      _appliedDates.remove(placementId);
      _applyingPlacementId = null;
      notifyListeners();

      debugPrint('Error applying for placement: $e');
      rethrow;
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
