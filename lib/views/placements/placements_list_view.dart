import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:campusconnect/views/widgets/eligibility_badge.dart';
import 'package:campusconnect/widgets/empty_state.dart';
import 'package:campusconnect/widgets/offline_banner.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// PlacementsListView - Extracted from monolithic NotesView
///
/// Phase 1 of NotesView decomposition: Clean, focused placement browsing view
/// for students. Displays placement opportunities with application functionality.
class PlacementsListView extends StatelessWidget {
  const PlacementsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = context.watch<RoleProvider>().userRole;
    final canManagePlacements =
        role == UserRole.teacher || role == UserRole.alumni;
    final canApplyPlacements = role == UserRole.student;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Placements',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        actions: [
          if (canManagePlacements)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add placement',
              onPressed: () => _showPlacementEditorDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<PlacementsProvider>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<PlacementsProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // V5.1: Offline banner
              OfflineBanner(isOffline: !provider.isOnline),

              // Content
              Expanded(
                child: _PlacementsContent(
                  provider: provider,
                  canManagePlacements: canManagePlacements,
                  canApplyPlacements: canApplyPlacements,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPlacementEditorDialog(
    BuildContext context, {
    Placement? placement,
  }) {
    final provider = context.read<PlacementsProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: _PlacementEditorDialog(existingPlacement: placement),
      ),
    );
  }
}

/// Internal placements content widget - extracted from _buildPlacementsContent
class _PlacementsContent extends StatelessWidget {
  final PlacementsProvider provider;
  final bool canManagePlacements;
  final bool canApplyPlacements;

  const _PlacementsContent({
    required this.provider,
    required this.canManagePlacements,
    required this.canApplyPlacements,
  });

  @override
  Widget build(BuildContext context) {
    // Show skeleton loaders while initializing
    if (provider.isLoading && !provider.isInitialized) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const PlacementCardSkeleton(),
      );
    }

    // Show error state
    if (provider.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error loading placements',
        subtitle: provider.error!,
        action: ElevatedButton.icon(
          onPressed: () => provider.refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    // v6.5: Use sorted placements (eligible first)
    final placements = provider.sortedPlacements;
    final eligiblePlacements = provider.eligiblePlacements;

    // Show empty state
    if (placements.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'No placements available',
        subtitle: 'New opportunities will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: placements.length + (eligiblePlacements.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // v6.5: Show "Recommended for You" header before eligible placements
          if (eligiblePlacements.isNotEmpty && index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecommendedHeader(count: eligiblePlacements.length),
                const SizedBox(height: AppTheme.space8),
              ],
            );
          }

          // Adjust index for header
          final placementIndex = eligiblePlacements.isNotEmpty
              ? index - 1
              : index;
          final placement = placements[placementIndex];
          final eligibility = provider.getEligibility(placement.id);
          return _PlacementCard(
            placement: placement,
            eligibility: eligibility,
            canManagePlacements: canManagePlacements,
            canApplyPlacements: canApplyPlacements,
          );
        },
      ),
    );
  }
}

/// v6.5: Recommended section header - extracted from _buildRecommendedHeader
class _RecommendedHeader extends StatelessWidget {
  final int count;

  const _RecommendedHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.primaryBlue.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: AppTheme.space8),
          Text(
            'Recommended for You',
            style: AppTheme.titleSmall.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$count eligible',
              style: AppTheme.caption.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal placement card widget - extracted from _buildPlacementCard
class _PlacementCard extends StatelessWidget {
  final Placement placement;
  final PlacementEligibility? eligibility;
  final bool canManagePlacements;
  final bool canApplyPlacements;

  const _PlacementCard({
    required this.placement,
    this.eligibility,
    required this.canManagePlacements,
    required this.canApplyPlacements,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();
    final isClosed = placement.isDeadlinePassed || !placement.isActive;

    return Card(
      margin: EdgeInsets.only(bottom: layout.itemSpacing),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkSurface, AppTheme.primaryBlue.withOpacity(0.05)]
                : [Colors.white, AppTheme.primaryBlue.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(layout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          placement.company,
                          style: AppTheme.titleMedium.copyWith(
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          placement.role,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge (Open/Closed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space12,
                          vertical: AppTheme.space4,
                        ),
                        decoration: BoxDecoration(
                          gradient: isClosed
                              ? LinearGradient(
                                  colors: [
                                    AppTheme.errorBg,
                                    AppTheme.errorBg.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    AppTheme.successBg,
                                    AppTheme.successBg.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: isClosed
                                ? AppTheme.error.withOpacity(0.3)
                                : AppTheme.success.withOpacity(0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isClosed
                                  ? AppTheme.error.withOpacity(0.15)
                                  : AppTheme.success.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          isClosed ? 'Closed' : 'Open',
                          style: AppTheme.label.copyWith(
                            color: isClosed ? AppTheme.error : AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // v6.5: Eligibility badge
                      if (eligibility != null && !isClosed) ...[
                        const SizedBox(height: AppTheme.space8),
                        EligibilityBadge(
                          eligibility: eligibility!,
                          compact: true,
                        ),
                      ],
                      if (canManagePlacements) ...[
                        const SizedBox(height: AppTheme.space8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit placement',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showPlacementEditorDialog(context),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                placement.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray700,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            size: 14,
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            placement.salary,
                            style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.gray800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            'Deadline: ${DateFormat('MMM dd, yyyy').format(placement.deadline)}',
                            style: AppTheme.caption.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (canApplyPlacements && !isClosed)
                    _ApplyButton(
                      placementId: placement.id,
                      company: placement.company,
                      role: placement.role,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlacementEditorDialog(BuildContext context) {
    final provider = context.read<PlacementsProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: _PlacementEditorDialog(existingPlacement: placement),
      ),
    );
  }
}

/// Apply button widget - extracted from _buildApplyButton
class _ApplyButton extends StatelessWidget {
  final String placementId;
  final String company;
  final String role;

  const _ApplyButton({
    required this.placementId,
    required this.company,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlacementsProvider>(
      builder: (context, provider, child) {
        final hasApplied = provider.hasApplied(placementId);
        final isApplying = provider.isApplying(placementId);
        final appliedDate = provider.getAppliedDate(placementId);
        final isOffline = !provider.isOnline;
        final anyApplyInProgress = provider.isAnyApplyInProgress;

        // Show "Applied" chip with date
        if (hasApplied && !isApplying) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space12,
              vertical: AppTheme.space8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.12),
                  AppTheme.primaryBlue.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  appliedDate != null
                      ? 'Applied • ${DateFormat('MMM dd').format(appliedDate)}'
                      : 'Applied',
                  style: AppTheme.label.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }

        // Show loading button while applying
        if (isApplying) {
          return ElevatedButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            label: Text(
              'Applying...',
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          );
        }

        // V5.1: Disable button if offline or another apply is in progress
        final isDisabled = isOffline || anyApplyInProgress;

        // Show apply button
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlue.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled
                  ? null
                  : () => _showApplyDialog(context, placementId, company, role),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space20,
                  vertical: AppTheme.space12,
                ),
                child: Text(
                  isOffline ? 'Offline' : 'Apply',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showApplyDialog(
    BuildContext context,
    String placementId,
    String company,
    String role,
  ) {
    // Capture the provider before showing the dialog
    final provider = context.read<PlacementsProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) =>
          ChangeNotifierProvider<PlacementsProvider>.value(
            value: provider,
            child: _ApplyDialogWidget(
              placementId: placementId,
              company: company,
              role: role,
            ),
          ),
    );
  }
}

/// Apply dialog widget - extracted from _ApplyDialogWidget
class _ApplyDialogWidget extends StatefulWidget {
  final String placementId;
  final String company;
  final String role;

  const _ApplyDialogWidget({
    required this.placementId,
    required this.company,
    required this.role,
  });

  @override
  State<_ApplyDialogWidget> createState() => _ApplyDialogWidgetState();
}

class _ApplyDialogWidgetState extends State<_ApplyDialogWidget> {
  late final TextEditingController _resumeController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resumeController = TextEditingController();
  }

  @override
  void dispose() {
    _resumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply for Placement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resumeController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste your resume or brief background...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitApplication,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submitApplication() async {
    final resume = _resumeController.text.trim();
    if (resume.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide your resume or background information.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use Provider to apply
      final provider = context.read<PlacementsProvider>();
      final success = await provider.applyForPlacement(
        placementId: widget.placementId,
        resume: resume,
        company: widget.company,
        role: widget.role,
      );

      if (mounted && success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // V5.1: Use error message utility for user-friendly errors
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMessages.getUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }
}

/// Create/Edit placement dialog for teacher/alumni management
class _PlacementEditorDialog extends StatefulWidget {
  final Placement? existingPlacement;

  const _PlacementEditorDialog({this.existingPlacement});

  @override
  State<_PlacementEditorDialog> createState() => _PlacementEditorDialogState();
}

class _PlacementEditorDialogState extends State<_PlacementEditorDialog> {
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _salaryController;
  late final TextEditingController _eligibilityController;

  bool _isSaving = false;
  String? _errorMessage;
  late DateTime _deadline;

  bool get _isEdit => widget.existingPlacement != null;

  @override
  void initState() {
    super.initState();
    final placement = widget.existingPlacement;
    _companyController = TextEditingController(text: placement?.company ?? '');
    _roleController = TextEditingController(text: placement?.role ?? '');
    _descriptionController = TextEditingController(
      text: placement?.description ?? '',
    );
    _salaryController = TextEditingController(text: placement?.salary ?? '');
    _eligibilityController = TextEditingController(
      text: placement?.eligibility ?? '',
    );
    _deadline =
        placement?.deadline ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _eligibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Placement' : 'Add Placement'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _companyController,
                label: 'Company',
                hint: 'e.g., Google',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _roleController,
                label: 'Role',
                hint: 'e.g., Software Engineer Intern',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Brief role summary',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _salaryController,
                label: 'Salary',
                hint: 'e.g., ₹50,000/month',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _eligibilityController,
                label: 'Eligibility',
                hint: 'e.g., CGPA 7.0+, CSE/IT',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deadline: ${DateFormat('MMM dd, yyyy').format(_deadline)}',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _pickDeadline,
                    child: const Text('Change'),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePlacement,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Update' : 'Post'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _deadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _deadline.hour,
        _deadline.minute,
      );
    });
  }

  Future<void> _savePlacement() async {
    final company = _companyController.text.trim();
    final role = _roleController.text.trim();
    final description = _descriptionController.text.trim();
    final salary = _salaryController.text.trim();
    final eligibility = _eligibilityController.text.trim();

    if (company.isEmpty ||
        role.isEmpty ||
        description.isEmpty ||
        salary.isEmpty ||
        eligibility.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields before saving.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final provider = context.read<PlacementsProvider>();
    bool success;

    if (_isEdit) {
      final existing = widget.existingPlacement!;
      final updatedPlacement = Placement(
        id: existing.id,
        company: company,
        role: role,
        description: description,
        eligibility: eligibility,
        salary: salary,
        deadline: _deadline,
        postedAt: existing.postedAt,
        isActive: existing.isActive,
        requirements: existing.requirements,
      );
      success = await provider.updatePlacement(updatedPlacement);
    } else {
      success = await provider.createPlacement(
        company: company,
        role: role,
        description: description,
        eligibility: eligibility,
        salary: salary,
        deadline: _deadline,
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Placement updated successfully'
                : 'Placement posted successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = false;
      _errorMessage = provider.error ?? 'Failed to save placement';
    });
  }
}
