import 'package:flutter/material.dart';

/// EmptyStateWidget - v6.4
///
/// Consistent empty state display used throughout the app.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (customAction != null) ...[
              const SizedBox(height: 24),
              customAction!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state widget with retry action
class ErrorStateWidget extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      title: title ?? 'Something went wrong',
      subtitle: _getUserFriendlyMessage(message),
      actionLabel: onRetry != null ? 'Try again' : null,
      onAction: onRetry,
    );
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyMessage(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('network') ||
        errorLower.contains('socket') ||
        errorLower.contains('connection')) {
      return 'Please check your internet connection and try again.';
    }

    if (errorLower.contains('permission') ||
        errorLower.contains('unauthorized')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorLower.contains('not found') || errorLower.contains('404')) {
      return 'The requested content could not be found.';
    }

    if (errorLower.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }

    if (errorLower.contains('firebase') || errorLower.contains('firestore')) {
      return 'There was a problem connecting to the server. Please try again.';
    }

    // Default: show the original message if it's short enough
    if (error.length <= 100) {
      return error;
    }

    return 'An unexpected error occurred. Please try again.';
  }
}

/// No results found for search
class NoResultsWidget extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onClear;

  const NoResultsWidget({super.key, required this.searchQuery, this.onClear});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No results found',
      subtitle: 'We couldn\'t find anything matching "$searchQuery"',
      actionLabel: onClear != null ? 'Clear search' : null,
      onAction: onClear,
    );
  }
}

/// Coming soon placeholder
class ComingSoonWidget extends StatelessWidget {
  final String feature;

  const ComingSoonWidget({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.construction,
      title: 'Coming Soon',
      subtitle: '$feature will be available in a future update.',
    );
  }
}
