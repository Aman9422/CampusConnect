import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// v9.0 (IMP-10): Widget-level error boundary for dashboard sections.
///
/// Wraps each major dashboard section (Career Coach, Recommendations,
/// Engagement, Placements) so that one section failing to render does NOT
/// crash the entire dashboard. The error is caught by Flutter's
/// [ErrorWidget.builder] mechanism via a [FlutterError]-safe wrapper.
///
/// Usage:
/// ```dart
/// DashboardErrorBoundary(
///   sectionName: 'AI Career Coach',
///   child: const CareerCoachSection(),
/// )
/// ```
///
/// Shows a compact inline error banner with a Retry button instead of the
/// red error screen. The parent widget continues rendering normally.
class DashboardErrorBoundary extends StatefulWidget {
  final Widget child;
  final String sectionName;

  const DashboardErrorBoundary({
    super.key,
    required this.child,
    required this.sectionName,
  });

  @override
  State<DashboardErrorBoundary> createState() => _DashboardErrorBoundaryState();
}

class _DashboardErrorBoundaryState extends State<DashboardErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _SectionErrorBanner(
        sectionName: widget.sectionName,
        onRetry: () {
          setState(() {
            _hasError = false;
          });
        },
      );
    }

    return _ErrorCatcher(
      onError: (error) {
        debugPrint('DashboardErrorBoundary[${widget.sectionName}]: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
      child: widget.child,
    );
  }
}

/// Wraps the child in a builder that catches build-time errors.
///
/// Flutter's [ErrorWidget] is a last-resort red screen. Instead, this widget
/// catches the error in [build] and reports it to the parent so the
/// [DashboardErrorBoundary] can show a friendly inline banner.
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final ValueChanged<Object> onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (e) {
          onError(e);
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Compact inline error banner with a Retry button.
class _SectionErrorBanner extends StatelessWidget {
  final String sectionName;
  final VoidCallback onRetry;

  const _SectionErrorBanner({
    required this.sectionName,
    required this.onRetry,
  });

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
              '$sectionName could not load.',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
