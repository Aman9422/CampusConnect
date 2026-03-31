import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
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
              Expanded(child: _PlacementsContent(provider: provider)),
            ],
          );
        },
      ),
    );
  }
}

/// Internal placements content widget - extracted from _buildPlacementsContent
class _PlacementsContent extends StatelessWidget {
  final PlacementsProvider provider;

  const _PlacementsContent({required this.provider});

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
          return _PlacementCard(placement: placement, eligibility: eligibility);
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

  const _PlacementCard({required this.placement, this.eligibility});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

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
                          gradient: placement.isDeadlinePassed
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
                            color: placement.isDeadlinePassed
                                ? AppTheme.error.withOpacity(0.3)
                                : AppTheme.success.withOpacity(0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: placement.isDeadlinePassed
                                  ? AppTheme.error.withOpacity(0.15)
                                  : AppTheme.success.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          placement.isDeadlinePassed ? 'Closed' : 'Open',
                          style: AppTheme.label.copyWith(
                            color: placement.isDeadlinePassed
                                ? AppTheme.error
                                : AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // v6.5: Eligibility badge
                      if (eligibility != null &&
                          !placement.isDeadlinePassed) ...[
                        const SizedBox(height: AppTheme.space8),
                        EligibilityBadge(
                          eligibility: eligibility!,
                          compact: true,
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
                  if (!placement.isDeadlinePassed)
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
