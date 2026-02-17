import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/resume_review_view.dart' as review_view;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CampusConnect v6.8 - Resume Review Detail View
///
/// Displays full details of a past resume review from history.
/// Shows all sections: ATS score, verdict, strengths, issues, improvements, etc.

class ResumeReviewDetailView extends StatefulWidget {
  final String reviewId;

  const ResumeReviewDetailView({super.key, required this.reviewId});

  @override
  State<ResumeReviewDetailView> createState() => _ResumeReviewDetailViewState();
}

class _ResumeReviewDetailViewState extends State<ResumeReviewDetailView> {
  ResumeReviewHistory? _review;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<ResumeReviewProvider>();
      final review = await provider.getHistoryItem(widget.reviewId);

      if (mounted) {
        setState(() {
          _review = review;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load review';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
      appBar: AppBar(
        title: const Text('Review Details'),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Delete icon
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete Review',
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
              _error!,
              style: AppTheme.bodyLarge.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            ElevatedButton.icon(
              onPressed: _loadReview,
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

    if (_review == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'Review not found',
              style: AppTheme.bodyLarge.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with metadata
          _HeaderCard(review: _review!),
          const SizedBox(height: AppTheme.space24),

          // Use the existing review view components from resume_review_view.dart
          // by converting ResumeReviewHistory to ResumeReview
          review_view.ResumeReviewView.buildResultsView(
            _review!.toResumeReview(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
      final success = await provider.deleteHistoryItem(widget.reviewId);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // Go back to history list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete review'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final ResumeReviewHistory review;

  const _HeaderCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Role
            if (review.targetRole != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 20,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      review.targetRole!,
                      style: AppTheme.titleMedium.copyWith(
                        color: isDark ? Colors.white : AppTheme.gray900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
            ],

            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  _formatDate(review.createdAt),
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                  ),
                ),
              ],
            ),

            // Month Key (for debugging/transparency)
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                Icon(
                  Icons.label_outline,
                  size: 18,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Month: ${review.monthKey}',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, y \'at\' h:mm a').format(date);
  }
}
