import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/models/ai_placement_insight.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// EligibilityBadge - v6.5
///
/// Displays eligibility status for a placement.
class EligibilityBadge extends StatelessWidget {
  final PlacementEligibility eligibility;
  final bool compact;

  const EligibilityBadge({
    super.key,
    required this.eligibility,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();
    final label = _getLabel();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          if (eligibility.passedChecks.isNotEmpty ||
              eligibility.failedChecks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...eligibility.passedChecks.map(
              (check) =>
                  _buildCheckItem(check, Icons.check_circle, AppTheme.success),
            ),
            ...eligibility.failedChecks.map(
              (check) => _buildCheckItem(check, Icons.cancel, AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (eligibility.status) {
      case EligibilityStatus.eligible:
        return AppTheme.success;
      case EligibilityStatus.notEligible:
        return AppTheme.error;
      case EligibilityStatus.deadlinePassed:
        return AppTheme.gray500;
      case EligibilityStatus.alreadyApplied:
        return AppTheme.primaryBlue;
      case EligibilityStatus.unknown:
        return AppTheme.gray500;
    }
  }

  IconData _getIcon() {
    switch (eligibility.status) {
      case EligibilityStatus.eligible:
        return Icons.check_circle;
      case EligibilityStatus.notEligible:
        return Icons.cancel;
      case EligibilityStatus.deadlinePassed:
        return Icons.schedule;
      case EligibilityStatus.alreadyApplied:
        return Icons.task_alt;
      case EligibilityStatus.unknown:
        return Icons.help_outline;
    }
  }

  String _getLabel() {
    switch (eligibility.status) {
      case EligibilityStatus.eligible:
        return 'Eligible';
      case EligibilityStatus.notEligible:
        return 'Not Eligible';
      case EligibilityStatus.deadlinePassed:
        return 'Deadline Passed';
      case EligibilityStatus.alreadyApplied:
        return 'Applied';
      case EligibilityStatus.unknown:
        return 'Unknown';
    }
  }
}

/// MatchScoreBadge - v6.5.1
///
/// Displays AI match score for a placement.
class MatchScoreBadge extends StatelessWidget {
  final AIPlacementInsight insight;
  final bool showDetails;
  final VoidCallback? onTap;

  const MatchScoreBadge({
    super.key,
    required this.insight,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return GestureDetector(
      onTap: onTap ?? () => _showDetailsDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '${insight.matchScore}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (onTap != null || showDetails) ...[
              const SizedBox(width: 2),
              Icon(Icons.info_outline, size: 12, color: color.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    switch (insight.matchLevel) {
      case MatchLevel.excellent:
        return Colors.green;
      case MatchLevel.good:
        return AppTheme.primaryBlue;
      case MatchLevel.fair:
        return Colors.orange;
      case MatchLevel.low:
        return Colors.red;
    }
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: _getColor()),
            const SizedBox(width: 8),
            Text('Match Score: ${insight.matchScore}%'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (insight.reasons.isNotEmpty) ...[
              const Text(
                'Why it\'s a good match:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...insight.reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r)),
                    ],
                  ),
                ),
              ),
            ],
            if (insight.missing.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Areas to improve:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...insight.missing.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Combined eligibility and match score row
class PlacementStatusRow extends StatelessWidget {
  final PlacementEligibility? eligibility;
  final AIPlacementInsight? insight;

  const PlacementStatusRow({super.key, this.eligibility, this.insight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (eligibility != null)
          EligibilityBadge(eligibility: eligibility!, compact: true),
        if (eligibility != null && insight != null) const SizedBox(width: 8),
        if (insight != null && !insight!.isExpired && insight!.matchScore > 0)
          MatchScoreBadge(insight: insight!),
      ],
    );
  }
}
