import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/career_coach_analysis.dart';
import 'package:campusconnect/providers/career_coach_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/career_coach_navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CampusConnect v9.0 — "AI Career Coach" dashboard section
///
/// Concise "What should I do next?" surface that stays on the main student
/// dashboard (docs/Task.md §13.1):
///   - Shows ONLY the 2–3 highest-priority recommendations from the CACHED
///     analysis — never more, never fabricated.
///   - Each compact card: priority, concise title, 1–2 line explanation,
///     short action, one CTA button.
///   - Bottom: "View all recommendations →" → `/career-coach`.
///   - No analysis yet → empty/loading state with a "Generate analysis"
///     action.
///   - The dashboard refresh icon NEVER calls AI — the section only renders
///     the cached analysis (see CareerCoachProvider.refreshFromCache).
class CareerCoachSection extends StatelessWidget {
  const CareerCoachSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coach = context.watch<CareerCoachProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AI Career Coach',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.auto_awesome, size: 18, color: AppTheme.secondaryIndigo),
            const Spacer(),
            if (coach.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                '${coach.analysesRemaining} left this month',
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (coach.isLoading && !coach.hasAnalysis)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (coach.error != null && !coach.hasAnalysis) ...[
          _ErrorBanner(
            message: coach.error!,
            onRetry: () => coach.generateAnalysis(),
          ),
          const SizedBox(height: 12),
        ] else if (!coach.hasAnalysis) ...[
          _EmptyState(
            onGenerate: coach.canGenerate
                ? () => coach.generateAnalysis()
                : null,
            blockedReason: coach.generateBlockedReason,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
        ] else ...[
          for (final rec in coach.topRecommendations)
            _CoachCard(rec: rec, isDark: isDark),
          const SizedBox(height: 4),
          const _ViewAllButton(),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onGenerate;
  final String? blockedReason;
  final bool isDark;

  const _EmptyState({
    this.onGenerate,
    this.blockedReason,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                color: AppTheme.secondaryIndigo,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Get your AI career plan',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI Career Coach analyzes your skills, projects, resume and '
            'career goal to tell you exactly what to focus on next.',
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (onGenerate != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate analysis'),
              ),
            )
          else if (blockedReason != null)
            Text(
              blockedReason!,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final CareerCoachRecommendation rec;
  final bool isDark;

  const _CoachCard({required this.rec, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(rec.priority, isDark);
    final route = CareerCoachNavigation.routeFor(rec.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: priorityColor.withAlpha(isDark ? 46 : 24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(rec.type), color: priorityColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rec.priority.name.toUpperCase()} PRIORITY',
                      style: AppTheme.caption.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rec.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '💡 ${rec.action}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (rec.estimatedEffort != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 13,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Effort: ${rec.estimatedEffort}',
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ],
          if (route != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(route),
                child: Text(_ctaLabel(rec.type)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _priorityColor(CareerCoachPriority priority, bool isDark) {
    switch (priority) {
      case CareerCoachPriority.high:
        return AppTheme.error;
      case CareerCoachPriority.medium:
        return AppTheme.warning;
      case CareerCoachPriority.low:
        return isDark ? AppTheme.gray300 : AppTheme.gray600;
    }
  }

  static IconData _typeIcon(CareerCoachRecType type) {
    switch (type) {
      case CareerCoachRecType.portfolio:
        return Icons.workspace_premium_outlined;
      case CareerCoachRecType.resume:
        return Icons.description_outlined;
      case CareerCoachRecType.project:
        return Icons.rocket_launch_outlined;
      case CareerCoachRecType.experience:
        return Icons.work_outline;
      case CareerCoachRecType.certification:
        return Icons.verified_outlined;
      case CareerCoachRecType.achievement:
        return Icons.emoji_events_outlined;
      case CareerCoachRecType.profile:
        return Icons.person_outline;
      case CareerCoachRecType.skill:
        return Icons.lightbulb_outline;
      case CareerCoachRecType.interview:
        return Icons.record_voice_over_outlined;
      case CareerCoachRecType.jobSearch:
        return Icons.search_outlined;
    }
  }

  static String _ctaLabel(CareerCoachRecType type) {
    switch (type) {
      case CareerCoachRecType.portfolio:
        return 'Open Portfolio';
      case CareerCoachRecType.resume:
        return 'Improve Resume';
      case CareerCoachRecType.project:
        return 'Manage Projects';
      case CareerCoachRecType.experience:
        return 'Add Experience';
      case CareerCoachRecType.certification:
        return 'Add Certification';
      case CareerCoachRecType.achievement:
        return 'Add Achievement';
      case CareerCoachRecType.profile:
        return 'Complete Profile';
      case CareerCoachRecType.skill:
        return 'Get AI Guidance';
      case CareerCoachRecType.interview:
        return 'Prepare with AI';
      case CareerCoachRecType.jobSearch:
        return 'Explore Jobs';
    }
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pushNamed(careerCoachRoute),
      style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryIndigo),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View all recommendations',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryIndigo,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    );
  }
}
