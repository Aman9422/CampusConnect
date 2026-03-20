import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/alumni_directory_service.dart';
import 'package:flutter/material.dart';

/// AlumniDirectoryProvider - v7.2: Multi-role ecosystem
///
/// Manages alumni directory search and filtering functionality.
/// Students can discover alumni by various criteria.
/// Follows ProfileProvider pattern with proper lifecycle management.
class AlumniDirectoryProvider extends ChangeNotifier {
  final AlumniDirectoryService _alumniDirectoryService;

  AlumniDirectoryProvider({AlumniDirectoryService? service})
    : _alumniDirectoryService = service ?? AlumniDirectoryService.instance();

  // State variables (following ProfileProvider pattern)
  List<StudentProfile>? _alumni;
  List<StudentProfile>? _filteredAlumni;
  List<StudentProfile>? _recentAlumni;
  List<StudentProfile>? _featuredAlumni;
  Map<String, List<String>>? _filterOptions;
  Map<String, int>? _stats;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  bool _isSearching = false;
  String? _searchQuery;
  Map<String, String?> _activeFilters = {};

  // Search state
  String? _selectedCompany;
  String? _selectedJobRole;
  int? _selectedGraduationYear;
  String? _selectedDepartment;
  List<String> _selectedSkills = [];

  // Getters
  List<StudentProfile>? get alumni => _filteredAlumni ?? _alumni;
  List<StudentProfile>? get allAlumni => _alumni;
  List<StudentProfile>? get recentAlumni => _recentAlumni;
  List<StudentProfile>? get featuredAlumni => _featuredAlumni;
  Map<String, List<String>>? get filterOptions => _filterOptions;
  Map<String, int>? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasAlumni => alumni?.isNotEmpty ?? false;
  bool get hasRecentAlumni => _recentAlumni?.isNotEmpty ?? false;
  bool get hasFeaturedAlumni => _featuredAlumni?.isNotEmpty ?? false;
  String? get error => _error;
  bool get isSearching => _isSearching;
  String? get searchQuery => _searchQuery;
  Map<String, String?> get activeFilters => _activeFilters;

  // Filter getters
  String? get selectedCompany => _selectedCompany;
  String? get selectedJobRole => _selectedJobRole;
  int? get selectedGraduationYear => _selectedGraduationYear;
  String? get selectedDepartment => _selectedDepartment;
  List<String> get selectedSkills => _selectedSkills;

  /// Check if any filters are active
  bool get hasActiveFilters =>
      _searchQuery?.isNotEmpty == true ||
      _selectedCompany != null ||
      _selectedJobRole != null ||
      _selectedGraduationYear != null ||
      _selectedDepartment != null ||
      _selectedSkills.isNotEmpty;

  /// Initialize provider
  Future<void> init() async {
    if (_isInitialized) return;

    _isDisposed = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load initial data
      await Future.wait([
        _loadAlumniDirectory(),
        _loadFilterOptions(),
        _loadRecentAlumni(),
        _loadFeaturedAlumni(),
        _loadStats(),
      ]);

      if (_isDisposed) return;

      _isInitialized = true;
      _error = null;
    } catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to load alumni directory';
      _isInitialized = true;
      debugPrint('AlumniDirectoryProvider init error: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Load alumni directory
  Future<void> _loadAlumniDirectory() async {
    _alumni = await _alumniDirectoryService.getAlumniDirectory();
  }

  /// Load filter options for UI
  Future<void> _loadFilterOptions() async {
    _filterOptions = await _alumniDirectoryService.getFilterOptions();
  }

  /// Load recent alumni
  Future<void> _loadRecentAlumni() async {
    _recentAlumni = await _alumniDirectoryService.getRecentAlumni();
  }

  /// Load featured alumni
  Future<void> _loadFeaturedAlumni() async {
    _featuredAlumni = await _alumniDirectoryService.getFeaturedAlumni();
  }

  /// Load stats
  Future<void> _loadStats() async {
    _stats = await _alumniDirectoryService.getAlumniStats();
  }

  /// Search Operations
  /// Search alumni with text query
  Future<void> searchAlumni(String query) async {
    _searchQuery = query.trim();
    _updateActiveFilters();
    await _performSearch();
  }

  /// Filter by company
  Future<void> filterByCompany(String? company) async {
    _selectedCompany = company;
    _updateActiveFilters();
    await _performSearch();
  }

  /// Filter by job role
  Future<void> filterByJobRole(String? jobRole) async {
    _selectedJobRole = jobRole;
    _updateActiveFilters();
    await _performSearch();
  }

  /// Filter by graduation year
  Future<void> filterByGraduationYear(int? year) async {
    _selectedGraduationYear = year;
    _updateActiveFilters();
    await _performSearch();
  }

  /// Filter by department
  Future<void> filterByDepartment(String? department) async {
    _selectedDepartment = department;
    _updateActiveFilters();
    await _performSearch();
  }

  /// Filter by skills
  Future<void> filterBySkills(List<String> skills) async {
    _selectedSkills = skills;
    _updateActiveFilters();
    await _performSearch();
  }

  /// Add skill to filter
  void addSkillFilter(String skill) {
    if (!_selectedSkills.contains(skill)) {
      _selectedSkills.add(skill);
      _updateActiveFilters();
      _performSearch();
    }
  }

  /// Remove skill from filter
  void removeSkillFilter(String skill) {
    _selectedSkills.remove(skill);
    _updateActiveFilters();
    _performSearch();
  }

  /// Apply multiple filters at once
  Future<void> applyFilters({
    String? searchQuery,
    String? company,
    String? jobRole,
    int? graduationYear,
    String? department,
    List<String>? skills,
  }) async {
    _searchQuery = searchQuery?.trim();
    _selectedCompany = company;
    _selectedJobRole = jobRole;
    _selectedGraduationYear = graduationYear;
    _selectedDepartment = department;
    _selectedSkills = skills ?? [];

    _updateActiveFilters();
    await _performSearch();
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    _searchQuery = null;
    _selectedCompany = null;
    _selectedJobRole = null;
    _selectedGraduationYear = null;
    _selectedDepartment = null;
    _selectedSkills = [];
    _activeFilters = {};

    _filteredAlumni = null;
    notifyListeners();
  }

  /// Perform search with current filters
  Future<void> _performSearch() async {
    if (!hasActiveFilters) {
      _filteredAlumni = null;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _filteredAlumni = await _alumniDirectoryService.searchAlumni(
        searchQuery: _searchQuery?.isNotEmpty == true ? _searchQuery : null,
        company: _selectedCompany,
        jobRole: _selectedJobRole,
        graduationYear: _selectedGraduationYear,
        department: _selectedDepartment,
        skills: _selectedSkills.isNotEmpty ? _selectedSkills : null,
      );
      _error = null;
    } catch (e) {
      _error = 'Search failed. Please try again.';
      debugPrint('AlumniDirectoryProvider search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Update active filters map for UI display
  void _updateActiveFilters() {
    _activeFilters = {
      'search': _searchQuery?.isNotEmpty == true ? _searchQuery : null,
      'company': _selectedCompany,
      'jobRole': _selectedJobRole,
      'graduationYear': _selectedGraduationYear?.toString(),
      'department': _selectedDepartment,
      'skills': _selectedSkills.isNotEmpty ? _selectedSkills.join(', ') : null,
    };
    _activeFilters.removeWhere((key, value) => value == null);
  }

  /// Get alumni by specific criteria
  Future<List<StudentProfile>> getAlumniByCompany(String company) async {
    try {
      return await _alumniDirectoryService.getAlumniByCompany(company);
    } catch (e) {
      debugPrint('AlumniDirectoryProvider get by company error: $e');
      return [];
    }
  }

  Future<List<StudentProfile>> getAlumniByGraduationYear(int year) async {
    try {
      return await _alumniDirectoryService.getAlumniByGraduationYear(year);
    } catch (e) {
      debugPrint('AlumniDirectoryProvider get by year error: $e');
      return [];
    }
  }

  Future<List<StudentProfile>> getAlumniByDepartment(String department) async {
    try {
      return await _alumniDirectoryService.getAlumniByDepartment(department);
    } catch (e) {
      debugPrint('AlumniDirectoryProvider get by department error: $e');
      return [];
    }
  }

  /// Get specific alumni profile
  Future<StudentProfile?> getAlumniById(String alumniId) async {
    try {
      return await _alumniDirectoryService.getAlumniById(alumniId);
    } catch (e) {
      debugPrint('AlumniDirectoryProvider get alumni by ID error: $e');
      return null;
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadAlumniDirectory(),
        _loadFilterOptions(),
        _loadRecentAlumni(),
        _loadFeaturedAlumni(),
        _loadStats(),
      ]);

      // Re-apply current filters if any
      if (hasActiveFilters) {
        await _performSearch();
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to refresh alumni directory';
      debugPrint('AlumniDirectoryProvider refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more alumni (pagination support)
  Future<void> loadMore() async {
    if (_isLoading || _isSearching) return;

    try {
      final currentCount = _alumni?.length ?? 0;
      final moreAlumni = await _alumniDirectoryService.getAlumniDirectory(
        limit: 50, // Load 50 more
      );

      if (moreAlumni.length > currentCount) {
        _alumni = moreAlumni;

        // Re-apply filters if active
        if (hasActiveFilters) {
          await _performSearch();
        } else {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('AlumniDirectoryProvider load more error: $e');
    }
  }

  /// Stream methods for real-time updates
  void startListeningToAlumniUpdates() {
    _alumniDirectoryService.alumniDirectoryStream().listen(
      (alumni) {
        if (!_isDisposed) {
          _alumni = alumni;

          // Re-apply current filters
          if (hasActiveFilters) {
            _performSearch();
          } else {
            notifyListeners();
          }
        }
      },
      onError: (error) {
        if (!_isDisposed) {
          _error = 'Real-time update failed';
          debugPrint('AlumniDirectoryProvider stream error: $error');
          notifyListeners();
        }
      },
    );
  }

  /// Utility methods
  /// Get alumni count
  int get totalAlumniCount => _alumni?.length ?? 0;

  /// Get filtered alumni count
  int get filteredAlumniCount => _filteredAlumni?.length ?? totalAlumniCount;

  /// Get companies list for autocomplete
  List<String> get companiesList => _filterOptions?['companies'] ?? [];

  /// Get job roles list for autocomplete
  List<String> get jobRolesList => _filterOptions?['jobRoles'] ?? [];

  /// Get departments list for autocomplete
  List<String> get departmentsList => _filterOptions?['departments'] ?? [];

  /// Get graduation years list
  List<String> get graduationYearsList =>
      _filterOptions?['graduationYears'] ?? [];

  /// Get skills list for autocomplete
  List<String> get skillsList => _filterOptions?['skills'] ?? [];

  /// Search alumni locally (instant search for better UX)
  List<StudentProfile> searchAlumniLocally(String query) {
    if (_alumni == null) return [];
    if (query.isEmpty) return _alumni!;

    final queryLower = query.toLowerCase();
    return _alumni!
        .where(
          (profile) =>
              profile.personal.fullName.toLowerCase().contains(queryLower) ||
              profile.personal.effectiveDisplayName.toLowerCase().contains(
                queryLower,
              ) ||
              (profile.company?.toLowerCase().contains(queryLower) ?? false) ||
              (profile.jobRole?.toLowerCase().contains(queryLower) ?? false) ||
              (profile.department?.toLowerCase().contains(queryLower) ?? false),
        )
        .toList();
  }

  /// Get recent graduation years for quick filters
  List<int> get recentGraduationYears {
    final currentYear = DateTime.now().year;
    return List.generate(5, (i) => currentYear - i);
  }

  /// Get popular companies (most alumni)
  List<String> get popularCompanies {
    if (_filterOptions?['companies'] == null) return [];
    return _filterOptions!['companies']!.take(10).toList();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider (on logout)
  void reset() {
    _isDisposed = true;
    _alumni = null;
    _filteredAlumni = null;
    _recentAlumni = null;
    _featuredAlumni = null;
    _filterOptions = null;
    _stats = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _isSearching = false;
    _searchQuery = null;
    _activeFilters = {};
    _selectedCompany = null;
    _selectedJobRole = null;
    _selectedGraduationYear = null;
    _selectedDepartment = null;
    _selectedSkills = [];
    notifyListeners();
  }
}
