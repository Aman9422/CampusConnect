import 'package:campusconnect/models/application.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/services/firestore/resume_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// v9.1 — Placement Applicants View (Teacher Applicant Review).
///
/// Teacher/alumni drill-down into WHO applied for a placement, the resume
/// snapshot they submitted, and the status actions (Shortlist / Interview /
/// Place / Reject) that advance the pipeline. Status writes go through the
/// `updateApplicationStatus` callable — the ONLY writer of application
/// status (Firestore rules lock both application paths client-side).
///
/// Route: `placementApplicantsRoute` — expects `placementId` as String
/// argument. The placement company/role are read from the provider when
/// available for a nicer header.
class PlacementApplicantsView extends StatefulWidget {
  const PlacementApplicantsView({super.key});

  @override
  State<PlacementApplicantsView> createState() =>
      _PlacementApplicantsViewState();
}

class _PlacementApplicantsViewState extends State<PlacementApplicantsView> {
  List<Application>? _applications;
  final Map<String, StudentProfile?> _profiles = {};
  bool _isLoading = true;
  String? _error;
  String? _actingStudentId; // student whose status action is in flight

  String? get _placementId {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is String && args.isNotEmpty ? args : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final placementId = _placementId;
    if (placementId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No placement selected.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final applications = await context
          .read<PlacementsProvider>()
          .getApplicationsForPlacement(placementId);

      // Join against student profiles for name/department.
      for (final app in applications) {
        if (_profiles.containsKey(app.userId)) continue;
        try {
          final profile = await ProfileService.instance().getProfile(
            app.userId,
          );
          _profiles[app.userId] = profile;
        } catch (_) {
          _profiles[app.userId] = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load applicants.';
      });
    }
  }

  Future<void> _updateStatus(
    Application application,
    String status,
  ) async {
    final placementId = _placementId;
    if (placementId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_statusActionTitle(status)),
        content: Text(
          _statusActionBody(status, application),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actingStudentId = application.userId);
    try {
      final success = await context
          .read<PlacementsProvider>()
          .updateApplicationStatus(
            placementId: placementId,
            studentId: application.userId,
            status: status,
          );

      if (!mounted) return;
      if (success) {
        // Refresh the in-memory status so the chip updates without a reload.
        final index = _applications?.indexWhere(
          (app) => app.userId == application.userId,
        );
        if (index != null && index != -1) {
          setState(() {
            _replaceStatus(index, status);
          });
        }
        // v9.1 audit (BUG-F): refresh applicant-count badges after a status
        // change. The COUNT itself is distinct-students (unchanged by a
        // status transition), but re-running the query picks up any NEW
        // application that arrived while the user sat on this screen — the
        // old bug left the badges stale until a manual refresh.
        context.read<PlacementsProvider>().loadApplicantCounts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_statusLabel(status)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _actingStudentId = null);
    }
  }

  void _replaceStatus(int index, String status) {
    final current = _applications![index];
    _applications![index] = Application(
      id: current.id,
      userId: current.userId,
      placementId: current.placementId,
      resumeUrl: current.resumeUrl,
      appliedAt: current.appliedAt,
      status: status,
      resumeVersion: current.resumeVersion,
      resumeStoragePath: current.resumeStoragePath,
      atsScoreAtApplication: current.atsScoreAtApplication,
    );
  }

  /// v9.1 audit (BUG-G): text-paste applications store the raw pasted text
  /// in `resumeUrl`. Previously, `launchUrl(Uri.parse(text))` threw a
  /// `FormatException` → "Could not open resume" — a dead-feeling button.
  /// A text resume is shown in a scrollable dialog instead of being opened
  /// as a link; only real links/storage paths go to `launchUrl`.
  Future<void> _openResume(Application application) async {
    // Text resume — show the pasted text, never a dead link button.
    if (application.isTextResume) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notes, size: 20, color: AppTheme.secondaryIndigo),
              const SizedBox(width: AppTheme.space8),
              const Text('Resume (text)'),
            ],
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              application.resumeUrl,
              style: AppTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      var url = application.resumeUrl;
      if (url.isEmpty) {
        url =
            await ResumeService.instance().getResumeUrl(application.userId) ??
            '';
      }
      if (url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No resume available for this applicant'),
            ),
          );
        }
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
        );
      }
    }
  }

  void _openPortfolio(Application application) {
    Navigator.of(context).pushNamed(
      portfolioReadOnlyRoute,
      arguments: application.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placement = context
        .read<PlacementsProvider>()
        .getPlacementById(_placementId ?? '');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applicants',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            if (placement != null)
              Text(
                '${placement.company} · ${placement.role}',
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error',
        subtitle: _error!,
        action: ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    final applications = _applications ?? [];
    if (applications.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No applicants yet',
        subtitle: 'Students who apply for this placement will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.space16),
        itemCount: applications.length,
        itemBuilder: (context, index) => _ApplicantCard(
          application: applications[index],
          profile: _profiles[applications[index].userId],
          isUpdating: _actingStudentId == applications[index].userId,
          onUpdateStatus: (status) =>
              _updateStatus(applications[index], status),
          onViewResume: () => _openResume(applications[index]),
          onViewPortfolio: () => _openPortfolio(applications[index]),
        ),
      ),
    );
  }

  String _statusActionTitle(String status) {
    switch (status) {
      case 'shortlisted':
        return 'Shortlist Applicant';
      case 'interviewed':
        return 'Move to Interview';
      case 'placed':
        return 'Place Applicant';
      case 'rejected':
        return 'Reject Applicant';
      default:
        return 'Update Status';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'shortlisted':
        return 'Shortlisted';
      case 'interviewed':
        return 'Interviewed';
      case 'placed':
        return 'Placed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Applied';
    }
  }

  String _statusActionBody(String status, Application application) {
    final name = _displayName(application.userId);
    switch (status) {
      case 'shortlisted':
        return 'Shortlist $name for the next stage? The student will be notified.';
      case 'interviewed':
        return 'Mark $name as interviewed? The student will be notified.';
      case 'placed':
        return 'Confirm placement for $name? The student will be notified.';
      case 'rejected':
        return 'Reject $name\'s application? The student will be notified.';
      default:
        return 'Update $name\'s application status?';
    }
  }

  String _displayName(String userId) {
    final profile = _profiles[userId];
    return profile?.personal.effectiveDisplayName ?? 'This student';
  }
}

class _ApplicantCard extends StatelessWidget {
  final Application application;
  final StudentProfile? profile;
  final bool isUpdating;
  final void Function(String status) onUpdateStatus;
  final VoidCallback onViewResume;
  final VoidCallback onViewPortfolio;

  const _ApplicantCard({
    required this.application,
    required this.profile,
    required this.isUpdating,
    required this.onUpdateStatus,
    required this.onViewResume,
    required this.onViewPortfolio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = profile?.personal.effectiveDisplayName ?? 'Student';
    final program = profile?.academic.program ?? '';
    final college = profile?.academic.college ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                      if (program.isNotEmpty || college.isNotEmpty)
                        Text(
                          [program, college]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTheme.bodySmall.copyWith(
                            color: isDark
                                ? AppTheme.gray400
                                : AppTheme.gray600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: application.status),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space4,
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label:
                      'Applied ${DateFormat('MMM dd, yyyy').format(application.appliedAt)}',
                ),
                if (application.atsScoreAtApplication != null)
                  _InfoChip(
                    icon: Icons.grade_outlined,
                    label: 'ATS ${application.atsScoreAtApplication}/100',
                    color: _atsColor(application.atsScoreAtApplication!),
                  ),
                if (application.resumeVersion != null)
                  _InfoChip(
                    icon: Icons.description_outlined,
                    label: 'Resume v${application.resumeVersion}',
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onViewResume,
                  icon: Icon(
                    application.isTextResume
                        ? Icons.notes
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  // v9.1 audit (BUG-G): text-paste applications show a
                  // "Text Resume" entry that opens a dialog with the pasted
                  // text — not a dead "Resume" button that would try to
                  // launch the raw text as a URL.
                  label: Text(application.isTextResume ? 'Text Resume' : 'Resume'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                OutlinedButton.icon(
                  onPressed: onViewPortfolio,
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Portfolio'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _StatusActions(
                currentStatus: application.status,
                onUpdateStatus: onUpdateStatus,
              ),
          ],
        ),
      ),
    );
  }

  Color _atsColor(int score) {
    if (score >= 80) return const Color(0xFF059669);
    if (score >= 60) return const Color(0xFF0891B2);
    if (score >= 40) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }
}

/// Status action buttons. Shows only the sensible next actions for the
/// current stage: shortlisted → Interview/Reject, interviewed → Place/Reject,
/// terminal states (placed/rejected) show no actions.
class _StatusActions extends StatelessWidget {
  final String currentStatus;
  final void Function(String status) onUpdateStatus;

  const _StatusActions({
    required this.currentStatus,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _availableActions(currentStatus);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppTheme.space8,
      runSpacing: AppTheme.space8,
      children: actions.map((action) {
        return _StatusActionButton(
          status: action,
          onPressed: () => onUpdateStatus(action),
        );
      }).toList(),
    );
  }

  List<String> _availableActions(String status) {
    switch (status) {
      case 'applied':
        return ['shortlisted', 'rejected'];
      case 'shortlisted':
        return ['interviewed', 'rejected'];
      case 'interviewed':
        return ['placed', 'rejected'];
      default:
        // placed / rejected are terminal — no further client actions.
        return [];
    }
  }
}

class _StatusActionButton extends StatelessWidget {
  final String status;
  final VoidCallback onPressed;

  const _StatusActionButton({
    required this.status,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, background, foreground) = _style(status, isDark);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
      child: Text(label, style: AppTheme.bodySmall),
    );
  }

  (String, Color, Color) _style(String status, bool isDark) {
    final primary = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final success = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final error = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

    switch (status) {
      case 'shortlisted':
        return ('Shortlist', primary.withValues(alpha: 0.12), primary);
      case 'interviewed':
        return ('Interview', primary.withValues(alpha: 0.12), primary);
      case 'placed':
        return ('Place', success.withValues(alpha: 0.12), success);
      case 'rejected':
        return ('Reject', error.withValues(alpha: 0.12), error);
      default:
        return (status, primary.withValues(alpha: 0.12), primary);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color, bg) = _style(status, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (String, Color, Color) _style(String status, bool isDark) {
    final primary = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final success = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final warning = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final error = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

    switch (status) {
      case 'shortlisted':
        return ('Shortlisted', primary, primary.withValues(alpha: 0.12));
      case 'interviewed':
        return ('Interviewed', warning, warning.withValues(alpha: 0.12));
      case 'placed':
        return ('Placed', success, success.withValues(alpha: 0.12));
      case 'rejected':
        return ('Rejected', error, error.withValues(alpha: 0.12));
      default:
        return (
          'Applied',
          AppTheme.gray400,
          AppTheme.gray400.withValues(alpha: 0.12),
        );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = color ?? (isDark ? AppTheme.gray400 : AppTheme.gray600);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.gray50,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: AppTheme.space4),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
