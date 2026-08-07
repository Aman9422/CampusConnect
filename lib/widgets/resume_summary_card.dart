import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CampusConnect v8.4.1 (T4) — Student Dashboard Resume Summary Card.
///
/// Replaces the simple ATS resume card on the student dashboard with a
/// compact portfolio summary:
/// - Resume Uploaded status
/// - Latest ATS score
/// - Resume Age
/// - Last Review
/// - Open Portfolio / Upload-Replace actions
///
/// The card is a pure, stateless presentation of [ResumeMetadata]; it does
/// not perform any I/O itself. When [resume] is null (or has no resume),
/// the card shows the upload CTA instead.
///
/// v8.4.8 (MB15): [error] surfaces a failed portfolio load so a transient
/// read failure can never silently masquerade as a fresh (empty) portfolio
/// on the dashboard — Symptom 1's exact UI.
class ResumeSummaryCard extends StatelessWidget {
  final ResumeMetadata? resume;
  final String? error;
  final VoidCallback? onOpenPortfolio;
  final VoidCallback? onUploadReplace;

  const ResumeSummaryCard({
    super.key,
    this.resume,
    this.error,
    this.onOpenPortfolio,
    this.onUploadReplace,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasResume = resume?.hasResume == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          Row(
            children: [
              Text(
                'Resume Portfolio',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const Spacer(),
              if (hasResume)
                _StatusChip(
                  label: 'Resume Uploaded',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.success,
                  isDark: isDark,
                )
              else
                _StatusChip(
                  label: 'No Resume',
                  icon: Icons.pending_outlined,
                  color: AppTheme.warning,
                  isDark: isDark,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          if (hasResume) ...[
            _MetricRow(
              label: 'Latest ATS',
              value: resume!.latestATSScore != null
                  ? '${resume!.latestATSScore}/100'
                  : '—',
              icon: Icons.grade_outlined,
              accent: AppTheme.primaryBlue,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
            _MetricRow(
              label: 'Resume Age',
              value: resume!.uploadedAt != null
                  ? '${resume!.resumeAgeInDays} day${resume!.resumeAgeInDays == 1 ? '' : 's'}'
                  : '—',
              icon: Icons.hourglass_bottom_outlined,
              accent: AppTheme.warning,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
            _MetricRow(
              label: 'Last Review',
              value: resume!.lastReviewAt != null
                  ? DateFormat('MMM d, yyyy').format(resume!.lastReviewAt!)
                  : 'Not reviewed yet',
              icon: Icons.rate_review_outlined,
              accent: AppTheme.secondaryIndigo,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenPortfolio ??
                        () => Navigator.pushNamed(
                              context,
                              studentPortfolioRoute,
                            ),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Open Portfolio'),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUploadReplace ??
                        () => Navigator.pushNamed(
                              context,
                              resumeUploadRoute,
                            ),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload / Replace'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Upload your resume PDF to unlock ATS scoring and strengthen '
              'your portfolio.',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenPortfolio ??
                        () => Navigator.pushNamed(
                              context,
                              studentPortfolioRoute,
                            ),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Open Portfolio'),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUploadReplace ??
                        () => Navigator.pushNamed(
                              context,
                              resumeUploadRoute,
                            ),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload Resume'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pill showing resume status.
class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single metric line (icon + label + value).
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: AppTheme.space8),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ],
    );
  }
}
