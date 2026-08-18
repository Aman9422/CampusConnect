import 'package:campusconnect/models/career_coach_analysis.dart';
import 'package:campusconnect/providers/career_coach_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/career_coach_navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CampusConnect v9.0 — Full AI Career Coach screen (`/career-coach`).
///
/// Shows the complete analysis: career readiness, career focus, all
/// recommendations with full details, re-analyze button, and usage counter.
///
/// The dashboard top-2–3 surface lives in `career_coach_section.dart`.
class CareerCoachView extends StatelessWidget {
  const CareerCoachView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coach = context.watch<CareerCoachProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('AI Career Coach'),
            const SizedBox(width: 8),
            Icon(Icons.auto_awesome, size: 20, color: AppTheme.secondaryIndigo),
          ],
        ),
        actions: [
          if (coach.hasAnalysis)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh cached analysis',
              onPressed: coach.isLoading
                  ? null
                  : () => coach.refreshFromCache(),
            ),
        ],
      ),
      body: _Body(isDark: isDark, coach: coach),
    );
  }
}

class _Body extends StatelessWidget {
  final bool isDark;
  final CareerCoachProvider coach;

  const _Body({required this.isDark, required this.coach});

  @override
  Widget build(BuildContext context) {
    if (coach.isLoading && !coach.hasAnalysis) {
      return const Center(child: CircularProgressIndicator());
    }

    if (coach.error != null && !coach.hasAnalysis) {
      return _ErrorState(
        message: coach.error!,
        onRetry: () => coach.generateAnalysis(),
        isDark: isDark,
      );
    }

    if (!coach.hasAnalysis) {
      return _EmptyState(coach: coach, isDark: isDark);
    }

    return _AnalysisContent(coach: coach, isDark: isDark);
  }
}

// ---------------------------------------------------------------------------
// Empty / Error states
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final CareerCoachProvider coach;
  final bool isDark;

  const _EmptyState({required this.coach, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 56,
              color: AppTheme.secondaryIndigo,
            ),
            const SizedBox(height: 16),
            Text(
              'Your AI Career Coach',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get a personalized career plan based on your skills, projects, '
              'resume, and career goal. The AI analyzes your complete profile '
              'to tell you exactly what to focus on next.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (coach.canGenerate)
              ElevatedButton.icon(
                onPressed: () => coach.generateAnalysis(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate analysis'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              )
            else if (coach.generateBlockedReason != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(isDark ? 36 : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  coach.generateBlockedReason!,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analysis content
// ---------------------------------------------------------------------------

class _AnalysisContent extends StatelessWidget {
  final CareerCoachProvider coach;
  final bool isDark;

  const _AnalysisContent({required this.coach, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final analysis = coach.analysis!;

    return RefreshIndicator(
      onRefresh: coach.refreshFromCache,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Readiness + Focus ────────────────────────────────────
          _ReadinessCard(
            readiness: analysis.careerReadiness,
            focus: analysis.careerFocus,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // ── Usage bar + Re-analyze ──────────────────────────────
          _UsageBar(coach: coach, isDark: isDark),
          const SizedBox(height: 20),

          // ── Recommendations header ──────────────────────────────
          Text(
            'Recommendations',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 12),

          // ── Recommendation cards ────────────────────────────────
          for (final rec in analysis.recommendations)
            _FullRecommendationCard(rec: rec, isDark: isDark),

          if (analysis.recommendations.isEmpty)
            Text(
              'No recommendations at this time. Your career profile looks solid!',
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),

          // ── Provider attribution ────────────────────────────────
          if (analysis.providerUsed != null) ...[
            const SizedBox(height: 24),
            Text(
              'Powered by ${analysis.providerUsed}',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Readiness card
// ---------------------------------------------------------------------------

class _ReadinessCard extends StatelessWidget {
  final CareerReadiness readiness;
  final String? focus;
  final bool isDark;

  const _ReadinessCard({
    required this.readiness,
    this.focus,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                Icons.insights,
                size: 20,
                color: AppTheme.secondaryIndigo,
              ),
              const SizedBox(width: 8),
              Text(
                'Career Readiness',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const Spacer(),
              _ReadinessChip(level: readiness.level),
            ],
          ),
          if (readiness.hasContent) ...[
            const SizedBox(height: 10),
            Text(
              readiness.summary,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                height: 1.5,
              ),
            ),
          ],
          if (focus != null && focus!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryIndigo.withAlpha(isDark ? 30 : 16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 Career Focus',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondaryIndigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    focus!,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray200 : AppTheme.gray800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  final CareerReadinessLevel level;

  const _ReadinessChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: AppTheme.caption.copyWith(
          color: _bgColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color get _bgColor {
    switch (level) {
      case CareerReadinessLevel.strong:
        return AppTheme.success;
      case CareerReadinessLevel.solid:
        return AppTheme.secondaryIndigo;
      case CareerReadinessLevel.developing:
        return AppTheme.warning;
      case CareerReadinessLevel.sparse:
        return AppTheme.error;
    }
  }
}

// ---------------------------------------------------------------------------
// Usage bar + Re-analyze
// ---------------------------------------------------------------------------

class _UsageBar extends StatelessWidget {
  final CareerCoachProvider coach;
  final bool isDark;

  const _UsageBar({required this.coach, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final remaining = coach.analysesRemaining;
    final usage = coach.usage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            size: 18,
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$remaining / ${usage.monthlyLimit} analyses remaining this month',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (coach.isGenerating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: coach.canGenerate
                  ? () => _confirmReanalyze(context)
                  : null,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Re-analyze'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.secondaryIndigo,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmReanalyze(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-analyze?'),
        content: Text(
          'This will use one of your ${coach.usage.monthlyLimit} monthly '
          'analyses. The AI will produce a fresh career analysis based on '
          'your current profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Re-analyze'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) coach.reanalyze();
    });
  }
}

// ---------------------------------------------------------------------------
// Full recommendation card
// ---------------------------------------------------------------------------

class _FullRecommendationCard extends StatelessWidget {
  final CareerCoachRecommendation rec;
  final bool isDark;

  const _FullRecommendationCard({required this.rec, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(rec.priority, isDark);
    final route = CareerCoachNavigation.routeFor(rec.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + title + priority ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: priorityColor.withAlpha(isDark ? 46 : 24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _typeIcon(rec.type),
                  color: priorityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
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
          const SizedBox(height: 14),

          // ── Reason ─────────────────────────────────────────────
          Text(
            rec.reason,
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          // ── Recommended action ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(isDark ? 26 : 14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '💡 ${rec.action}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),

          // ── Why it matters ─────────────────────────────────────
          if (rec.whyItMatters != null && rec.whyItMatters!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Why it matters: ${rec.whyItMatters}',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],

          // ── Estimated effort ───────────────────────────────────
          if (rec.estimatedEffort != null &&
              rec.estimatedEffort!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 5),
                Text(
                  'Estimated effort: ${rec.estimatedEffort}',
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ],

          // ── CTA button ────────────────────────────────────────
          if (route != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
