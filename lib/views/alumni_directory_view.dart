import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// AlumniDirectoryView - v7.2: Multi-role ecosystem
///
/// Students can discover alumni by searching and filtering.
/// Features: Search, company filter, graduation year, skills.
/// Follows AppTheme design patterns and card-based layout.
class AlumniDirectoryView extends StatefulWidget {
  const AlumniDirectoryView({super.key});

  @override
  State<AlumniDirectoryView> createState() => _AlumniDirectoryViewState();
}

class _AlumniDirectoryViewState extends State<AlumniDirectoryView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // Initialize alumni directory when view loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlumniDirectoryProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Alumni Directory',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 20,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showFilters ? AppTheme.primaryBlue : null,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<AlumniDirectoryProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Search bar
              Container(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkBackground
                            : AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _searchFocus.hasFocus
                              ? AppTheme.primaryBlue
                              : isDark
                              ? AppTheme.gray700
                              : AppTheme.gray200,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText:
                              'Search alumni by name, company, or skills...',
                          hintStyle: AppTheme.bodyMedium.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: isDark
                                        ? AppTheme.gray400
                                        : AppTheme.gray500,
                                  ),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: (query) => _performSearch(provider, query),
                      ),
                    ),

                    // Active filters display
                    if (provider.hasActiveFilters) ...[
                      const SizedBox(height: 12),
                      _buildActiveFilters(provider, isDark),
                    ],
                  ],
                ),
              ),

              // Filter panel
              if (_showFilters) _buildFilterPanel(provider, isDark),

              // Alumni list
              Expanded(child: _buildAlumniList(provider, isDark)),
            ],
          );
        },
      ),
    );
  }

  /// Build active filters chips
  Widget _buildActiveFilters(AlumniDirectoryProvider provider, bool isDark) {
    final filters = provider.activeFilters;
    if (filters.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: filters.entries.map((entry) {
        return Chip(
          label: Text(
            '${_getFilterDisplayName(entry.key)}: ${entry.value}',
            style: AppTheme.caption.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryBlue,
          deleteIcon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white,
          ),
          onDeleted: () => _clearSpecificFilter(provider, entry.key),
        );
      }).toList(),
    );
  }

  /// Build expandable filter panel
  Widget _buildFilterPanel(AlumniDirectoryProvider provider, bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Alumni',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              if (provider.hasActiveFilters)
                TextButton(
                  onPressed: () => _clearAllFilters(provider),
                  child: Text(
                    'Clear All',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter dropdowns
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFilterDropdown(
                'Company',
                provider.selectedCompany,
                provider.companiesList,
                (value) => provider.filterByCompany(value),
                isDark,
              ),
              _buildFilterDropdown(
                'Job Role',
                provider.selectedJobRole,
                provider.jobRolesList,
                (value) => provider.filterByJobRole(value),
                isDark,
              ),
              _buildFilterDropdown(
                'Department',
                provider.selectedDepartment,
                provider.departmentsList,
                (value) => provider.filterByDepartment(value),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build filter dropdown
  Widget _buildFilterDropdown(
    String label,
    String? selectedValue,
    List<String> options,
    Function(String?) onChanged,
    bool isDark,
  ) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: selectedValue,
            hint: Text(
              'Any',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: AppTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Build alumni list
  Widget _buildAlumniList(AlumniDirectoryProvider provider, bool isDark) {
    if (!provider.isInitialized) {
      return _buildSkeletonLoader();
    }

    if (provider.isLoading) {
      return _buildSkeletonLoader();
    }

    if (provider.error != null) {
      return ErrorStateWidget(
        message: provider.error!,
        onRetry: () => provider.refresh(),
      );
    }

    final alumni = provider.alumni;
    if (alumni == null || alumni.isEmpty) {
      return EmptyStateWidget(
        icon: provider.hasActiveFilters
            ? Icons.search_off
            : Icons.school_outlined,
        title: provider.hasActiveFilters
            ? 'No matching alumni'
            : 'No alumni found',
        subtitle: provider.hasActiveFilters
            ? 'Try adjusting your search or filters'
            : 'Check back later as more alumni join the platform',
        customAction: provider.hasActiveFilters
            ? ElevatedButton(
                onPressed: () => _clearAllFilters(provider),
                child: const Text('Clear Filters'),
              )
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alumni.length,
        itemBuilder: (context, index) {
          final alumniProfile = alumni[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAlumniCard(alumniProfile, isDark),
          );
        },
      ),
    );
  }

  /// Build alumni card
  Widget _buildAlumniCard(dynamic alumniProfile, bool isDark) {
    return InkWell(
      onTap: () => _navigateToAlumniProfile(alumniProfile),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppTheme.gray700.withValues(alpha: 0.3)
                : AppTheme.gray200,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.gray900.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Avatar
            InitialsAvatar(
              name: alumniProfile.personal.effectiveDisplayName,
              size: 48,
            ),

            const SizedBox(width: 16),

            // Profile info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    alumniProfile.personal.effectiveDisplayName,
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Job info
                  if (alumniProfile.jobRole != null ||
                      alumniProfile.company != null) ...[
                    Text(
                      '${alumniProfile.jobRole ?? "Professional"} at ${alumniProfile.company ?? "Company"}',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Graduation year and department
                  Row(
                    children: [
                      if (alumniProfile.graduationYear != null) ...[
                        Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${alumniProfile.graduationYear}',
                          style: AppTheme.caption.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                          ),
                        ),
                      ],
                      if (alumniProfile.graduationYear != null &&
                          alumniProfile.department != null)
                        Text(
                          ' • ',
                          style: AppTheme.caption.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                          ),
                        ),
                      if (alumniProfile.department != null)
                        Expanded(
                          child: Text(
                            alumniProfile.department!,
                            style: AppTheme.caption.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),

                  // Skills
                  if (alumniProfile.skills != null &&
                      alumniProfile.skills!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: alumniProfile.skills!.take(3).map<Widget>((
                        skill,
                      ) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            skill,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }

  /// Build skeleton loader
  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonLoader(
            width: double.infinity,
            height: 100,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  /// Event handlers
  void _onSearchChanged(String query) {
    // Perform local search for instant results
    setState(() {});
  }

  void _performSearch(AlumniDirectoryProvider provider, String query) {
    provider.searchAlumni(query);
    _searchFocus.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<AlumniDirectoryProvider>().clearFilters();
  }

  void _clearAllFilters(AlumniDirectoryProvider provider) {
    _searchController.clear();
    provider.clearFilters();
  }

  void _clearSpecificFilter(
    AlumniDirectoryProvider provider,
    String filterKey,
  ) {
    switch (filterKey) {
      case 'search':
        _searchController.clear();
        provider.searchAlumni('');
        break;
      case 'company':
        provider.filterByCompany(null);
        break;
      case 'jobRole':
        provider.filterByJobRole(null);
        break;
      case 'department':
        provider.filterByDepartment(null);
        break;
    }
  }

  void _refreshData() {
    context.read<AlumniDirectoryProvider>().refresh();
  }

  void _navigateToAlumniProfile(dynamic alumniProfile) {
    Navigator.pushNamed(
      context,
      alumniProfileRoute,
      arguments: {'alumniId': alumniProfile.uid},
    );
  }

  String _getFilterDisplayName(String filterKey) {
    switch (filterKey) {
      case 'search':
        return 'Search';
      case 'company':
        return 'Company';
      case 'jobRole':
        return 'Role';
      case 'graduationYear':
        return 'Year';
      case 'department':
        return 'Dept';
      default:
        return filterKey;
    }
  }
}
