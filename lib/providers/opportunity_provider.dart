import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/opportunity_service.dart';
import 'package:flutter/material.dart';

/// OpportunityProvider - v7.2: Multi-role ecosystem
///
/// Manages job opportunity state and operations.
/// Alumni create opportunities, students browse them.
/// Follows ProfileProvider pattern with proper lifecycle management.
class OpportunityProvider extends ChangeNotifier {
  final OpportunityService _opportunityService;

  OpportunityProvider({OpportunityService? service})
    : _opportunityService = service ?? OpportunityService.instance();

  // State variables (following ProfileProvider pattern)
  List<Opportunity>? _opportunities;
  List<Opportunity>?
  _myOpportunities; // For alumni - their posted opportunities
  List<Opportunity>? _recentOpportunities;
  Map<String, List<String>>? _filterOptions;
  Map<String, int>? _stats;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  String? _userId;
  bool _isCreating = false;
  bool _isUpdating = false;
  String? _searchQuery;
  Map<String, String?> _activeFilters = {};

  // Getters
  List<Opportunity>? get opportunities => _opportunities;
  List<Opportunity>? get myOpportunities => _myOpportunities;
  List<Opportunity>? get recentOpportunities => _recentOpportunities;
  Map<String, List<String>>? get filterOptions => _filterOptions;
  Map<String, int>? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasOpportunities => _opportunities?.isNotEmpty ?? false;
  bool get hasMyOpportunities => _myOpportunities?.isNotEmpty ?? false;
  String? get error => _error;
  bool get isCreating => _isCreating;
  bool get isUpdating => _isUpdating;
  String? get searchQuery => _searchQuery;
  Map<String, String?> get activeFilters => _activeFilters;

  // Additional getters needed for the UI
  bool get hasActiveFilters =>
      _activeFilters.values.any((v) => v != null && v.isNotEmpty) ||
      (_searchQuery?.isNotEmpty == true);

  List<String> get companiesList =>
      _filterOptions?['companies']?.cast<String>() ?? [];
  List<String> get jobTypesList => [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Remote',
  ];
  List<String> get locationsList =>
      _filterOptions?['locations']?.cast<String>() ?? [];

  String? get selectedCompany => _activeFilters['company'];
  String? get selectedJobType => _activeFilters['jobType'];
  String? get selectedLocation => _activeFilters['location'];

  /// Initialize provider with user ID and role
  Future<void> initWithUser(String userId, String userRole) async {
    if (_isInitialized && _userId == userId) return;

    _isDisposed = false;
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (userRole == 'student') {
        // Students browse all active opportunities
        _opportunities = await _opportunityService.getActiveOpportunities();
        _recentOpportunities = await _opportunityService
            .getRecentOpportunities();
      } else if (userRole == 'alumni') {
        // Alumni see their own opportunities and can browse others
        _myOpportunities = await _opportunityService.getAlumniOpportunities(
          userId,
        );
        _opportunities = await _opportunityService.getActiveOpportunities();
        _stats = await _opportunityService.getOpportunityStatsForAlumni(userId);
      }

      if (_isDisposed) return;

      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load opportunities';
      _isInitialized = true;
      debugPrint('OpportunityProvider init error: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Alumni Operations
  /// Create a new job opportunity
  Future<bool> createOpportunity({
    required String alumniId,
    required String title,
    required String company,
    required String description,
    required List<String> requirements,
    required String location,
    required String jobType,
    required List<String> skills,
    required StudentProfile alumniProfile,
    String? salaryRange,
    DateTime? applicationDeadline,
    String? applicationUrl,
    String? contactEmail,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      await _opportunityService.createOpportunity(
        alumniId: alumniId,
        title: title,
        company: company,
        description: description,
        requirements: requirements,
        location: location,
        jobType: jobType,
        skills: skills,
        alumniProfile: alumniProfile,
        salaryRange: salaryRange,
        applicationDeadline: applicationDeadline,
        applicationUrl: applicationUrl,
        contactEmail: contactEmail,
      );

      // Refresh alumni's opportunities
      await _refreshAlumniOpportunities(alumniId);

      // Refresh general opportunities list
      await _refreshActiveOpportunities();

      _isCreating = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isCreating = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('OpportunityProvider create error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update an existing opportunity
  Future<bool> updateOpportunity(Opportunity opportunity) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _opportunityService.updateOpportunity(opportunity);

      // Update local state
      if (_myOpportunities != null) {
        final index = _myOpportunities!.indexWhere(
          (o) => o.id == opportunity.id,
        );
        if (index != -1) {
          _myOpportunities![index] = opportunity;
        }
      }

      if (_opportunities != null) {
        final index = _opportunities!.indexWhere((o) => o.id == opportunity.id);
        if (index != -1) {
          _opportunities![index] = opportunity;
        }
      }

      _isUpdating = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isUpdating = false;
      _error = 'Failed to update opportunity';
      debugPrint('OpportunityProvider update error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Deactivate an opportunity
  Future<bool> deactivateOpportunity(String opportunityId) async {
    try {
      await _opportunityService.deactivateOpportunity(opportunityId);

      // Update local state
      _updateOpportunityStatus(opportunityId, false);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to deactivate opportunity';
      debugPrint('OpportunityProvider deactivate error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reactivate an opportunity
  Future<bool> reactivateOpportunity(String opportunityId) async {
    try {
      await _opportunityService.reactivateOpportunity(opportunityId);

      // Update local state
      _updateOpportunityStatus(opportunityId, true);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reactivate opportunity';
      debugPrint('OpportunityProvider reactivate error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete an opportunity
  Future<bool> deleteOpportunity(String opportunityId) async {
    try {
      await _opportunityService.deleteOpportunity(opportunityId);

      // Remove from local state
      _myOpportunities?.removeWhere((o) => o.id == opportunityId);
      _opportunities?.removeWhere((o) => o.id == opportunityId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete opportunity';
      debugPrint('OpportunityProvider delete error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Load alumni's posted opportunities
  Future<void> loadAlumniOpportunities(String alumniId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myOpportunities = await _opportunityService.getAlumniOpportunities(
        alumniId,
      );
      _stats = await _opportunityService.getOpportunityStatsForAlumni(alumniId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load your opportunities';
      debugPrint('OpportunityProvider load alumni opportunities error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Student Operations
  /// Load active opportunities for browsing
  Future<void> loadActiveOpportunities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _opportunities = await _opportunityService.getActiveOpportunities();
      _recentOpportunities = await _opportunityService.getRecentOpportunities();
      _error = null;
    } catch (e) {
      _error = 'Failed to load opportunities';
      debugPrint('OpportunityProvider load opportunities error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search opportunities with filters
  Future<void> searchOpportunitiesWithFilters({
    String? searchQuery,
    String? company,
    String? jobType,
    String? location,
    List<String>? skills,
  }) async {
    _isLoading = true;
    _searchQuery = searchQuery;
    _activeFilters = {
      'company': company,
      'jobType': jobType,
      'location': location,
      // Note: skills is handled separately
    };
    _error = null;
    notifyListeners();

    try {
      _opportunities = await _opportunityService.searchOpportunities(
        searchQuery: searchQuery,
        company: company,
        jobType: jobType,
        location: location,
        skills: skills,
      );
      _error = null;
    } catch (e) {
      _error = 'Search failed. Please try again.';
      debugPrint('OpportunityProvider search error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear search and filters
  Future<void> clearSearch() async {
    _searchQuery = null;
    _activeFilters = {};
    await loadActiveOpportunities();
  }

  /// Shared Operations
  /// Get specific opportunity by ID
  Future<Opportunity?> getOpportunityById(String opportunityId) async {
    try {
      return await _opportunityService.getOpportunityById(opportunityId);
    } catch (e) {
      debugPrint('OpportunityProvider get opportunity by ID error: $e');
      return null;
    }
  }

  /// Load filter options for search UI
  Future<void> loadFilterOptions() async {
    try {
      final companies = await _opportunityService.getUniqueCompanies();
      final locations = await _opportunityService.getUniqueLocations();
      final skills = await _opportunityService.getPopularSkills();

      _filterOptions = {
        'companies': companies,
        'locations': locations,
        'jobTypes': JobType.all,
        'skills': skills,
      };

      notifyListeners();
    } catch (e) {
      debugPrint('OpportunityProvider load filter options error: $e');
    }
  }

  /// Refresh current data
  Future<void> refresh() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Determine user role and refresh appropriate data
      if (_myOpportunities != null) {
        // This is an alumni user
        await loadAlumniOpportunities(_userId!);
      }

      // Always refresh active opportunities for browsing
      await _refreshActiveOpportunities();

      _error = null;
    } catch (e) {
      _error = 'Failed to refresh opportunities';
      debugPrint('OpportunityProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper method to refresh active opportunities
  Future<void> _refreshActiveOpportunities() async {
    _opportunities = await _opportunityService.getActiveOpportunities();
    _recentOpportunities = await _opportunityService.getRecentOpportunities();
  }

  /// Helper method to refresh alumni opportunities
  Future<void> _refreshAlumniOpportunities(String alumniId) async {
    _myOpportunities = await _opportunityService.getAlumniOpportunities(
      alumniId,
    );
    _stats = await _opportunityService.getOpportunityStatsForAlumni(alumniId);
  }

  /// Helper method to update opportunity active status in local state
  void _updateOpportunityStatus(String opportunityId, bool isActive) {
    if (_myOpportunities != null) {
      final index = _myOpportunities!.indexWhere((o) => o.id == opportunityId);
      if (index != -1) {
        _myOpportunities![index] = _myOpportunities![index].copyWith(
          isActive: isActive,
        );
      }
    }

    if (_opportunities != null) {
      final index = _opportunities!.indexWhere((o) => o.id == opportunityId);
      if (index != -1) {
        _opportunities![index] = _opportunities![index].copyWith(
          isActive: isActive,
        );
      }
    }
  }

  /// Stream methods for real-time updates
  /// Start listening to active opportunities
  void startListeningToActiveOpportunities() {
    _opportunityService.activeOpportunitiesStream().listen(
      (opportunities) {
        if (!_isDisposed) {
          _opportunities = opportunities;
          notifyListeners();
        }
      },
      onError: (error) {
        if (!_isDisposed) {
          _error = 'Real-time update failed';
          debugPrint('OpportunityProvider stream error: $error');
          notifyListeners();
        }
      },
    );
  }

  /// Start listening to alumni's opportunities
  void startListeningToAlumniOpportunities(String alumniId) {
    _opportunityService
        .alumniOpportunitiesStream(alumniId)
        .listen(
          (opportunities) {
            if (!_isDisposed) {
              _myOpportunities = opportunities;
              notifyListeners();
            }
          },
          onError: (error) {
            if (!_isDisposed) {
              _error = 'Real-time update failed';
              debugPrint('OpportunityProvider alumni stream error: $error');
              notifyListeners();
            }
          },
        );
  }

  /// Utility methods
  /// Get opportunities by job type
  List<Opportunity> getOpportunitiesByJobType(String jobType) {
    if (_opportunities == null) return [];
    return _opportunities!.where((o) => o.jobType == jobType).toList();
  }

  /// Get active opportunities count
  int get activeOpportunitiesCount => _opportunities?.length ?? 0;

  /// Get alumni's active opportunities count
  int get myActiveOpportunitiesCount {
    if (_myOpportunities == null) return 0;
    return _myOpportunities!.where((o) => o.isActive).length;
  }

  /// Get expired opportunities count for alumni
  int get myExpiredOpportunitiesCount {
    if (_myOpportunities == null) return 0;
    return _myOpportunities!.where((o) => o.isExpired).length;
  }

  /// Filter opportunities by query locally (for instant search)
  List<Opportunity> filterOpportunitiesLocally(String query) {
    if (_opportunities == null) return [];
    if (query.isEmpty) return _opportunities!;

    final queryLower = query.toLowerCase();
    return _opportunities!
        .where(
          (opp) =>
              opp.title.toLowerCase().contains(queryLower) ||
              opp.company.toLowerCase().contains(queryLower) ||
              opp.description.toLowerCase().contains(queryLower) ||
              opp.location.toLowerCase().contains(queryLower),
        )
        .toList();
  }

  /// Get latest opportunities (sorted by posted date)
  List<Opportunity> get latestOpportunities {
    if (_opportunities == null) return [];
    final sorted = List<Opportunity>.from(_opportunities!)
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return sorted;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Additional methods needed for the UI
  /// Initialize without parameters (for UI convenience)
  Future<void> init() async {
    if (_isInitialized) return;
    await loadActiveOpportunities();
    await loadFilterOptions();
  }

  /// Search with just a query string (UI convenience method)
  Future<void> searchOpportunities(String query) async {
    await searchOpportunitiesWithFilters(searchQuery: query);
  }

  /// Clear all filters and search
  Future<void> clearFilters() async {
    _searchQuery = null;
    _activeFilters.clear();
    await loadActiveOpportunities();
  }

  /// Filter by specific criteria
  Future<void> filterByCompany(String? company) async {
    _activeFilters['company'] = company;
    await _applyFilters();
  }

  Future<void> filterByJobType(String? jobType) async {
    _activeFilters['jobType'] = jobType;
    await _applyFilters();
  }

  Future<void> filterByLocation(String? location) async {
    _activeFilters['location'] = location;
    await _applyFilters();
  }

  /// Apply current filters
  Future<void> _applyFilters() async {
    await searchOpportunitiesWithFilters(
      searchQuery: _searchQuery,
      company: _activeFilters['company'],
      jobType: _activeFilters['jobType'],
      location: _activeFilters['location'],
    );
  }

  /// Reset provider (on logout)
  void reset() {
    _isDisposed = true;
    _opportunities = null;
    _myOpportunities = null;
    _recentOpportunities = null;
    _filterOptions = null;
    _stats = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _userId = null;
    _isCreating = false;
    _isUpdating = false;
    _searchQuery = null;
    _activeFilters = {};
    notifyListeners();
  }
}
