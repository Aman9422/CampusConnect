import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CampusConnect v6.8 - Resume Review History View
///
/// Displays list of past resume reviews with ATS scores and timestamps.
/// User can tap to view full review details.

class ResumeReviewHistoryView extends StatefulWidget {
  const ResumeReviewHistoryView({super.key});

  @override
  State<ResumeReviewHistoryView> createState() =>
      _ResumeReviewHistoryViewState();
}

class _ResumeReviewHistoryViewState extends State<ResumeReviewHistoryView> {
  @override
  void initState() {
    super.initState();
    // Ensure history is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ResumeReviewProvider>();
      if (!provider.historyInitialized) {
        provider.refreshHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
      appBar: AppBar(
        title: const Text('Review History'),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ResumeReviewProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoadingHistory && !provider.historyInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.historyError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                  ),
                  const SizedBox(height: AppTheme.space16),
                  Text(
                    provider.historyError!,
                    style: AppTheme.bodyLarge.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space24),
                  ElevatedButton.icon(
                    onPressed: () => provider.refreshHistory(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (provider.history.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'No Review History',
              subtitle:
                  'Your resume reviews will appear here.\n'
                  'Start by creating your first review!',
              action: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(resumeReviewRoute);
                },
                icon: const Icon(Icons.add),
                label: const Text('Get Started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }

          // History list
          return RefreshIndicator(
            onRefresh: () => provider.refreshHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: provider.history.length,
              itemBuilder: (context, index) {
                final review = provider.history[index];
                return _HistoryCard(
                  review: review,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushNamed(resumeReviewDetailRoute, arguments: review.id);
                  },
                  onDelete: () => _confirmDelete(context, review),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ResumeReviewHistory review,
  ) async {
    final provider = context.read<ResumeReviewProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text(
          'Are you sure you want to delete this review? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteHistoryItem(review.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Review deleted' : 'Failed to delete review'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final ResumeReviewHistory review;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.review,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              // ATS Score Circle
              _ScoreCircle(score: review.atsScore),
              const SizedBox(width: AppTheme.space16),

              // Review Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Role or "General Review"
                    Text(
                      review.targetRole ?? 'General Review',
                      style: AppTheme.titleMedium.copyWith(
                        color: isDark ? Colors.white : AppTheme.gray900,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.space4),

                    // Date
                    Text(
                      _formatDate(review.createdAt),
                      style: AppTheme.bodySmall.copyWith(
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                    ),

                    // Score Label
                    const SizedBox(height: AppTheme.space8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space8,
                            vertical: AppTheme.space4,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(
                              review.atsScore,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            _getScoreLabel(review.atsScore),
                            style: AppTheme.bodySmall.copyWith(
                              color: _getScoreColor(review.atsScore),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppTheme.error),
                        SizedBox(width: AppTheme.space8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.primaryBlue;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.error;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Work';
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;

  const _ScoreCircle({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$score',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ).copyWith(color: color),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.primaryBlue;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.error;
  }
}
