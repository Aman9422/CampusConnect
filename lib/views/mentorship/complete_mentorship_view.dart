import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CompleteMentorshipView - v7.3: Mentorship completion flow
///
/// Allows students/alumni to mark mentorship as completed with rating/feedback.
/// Follows CreateMentorshipRequestView pattern for form layout and validation.
class CompleteMentorshipView extends StatefulWidget {
  final MentorshipRequest request;

  const CompleteMentorshipView({super.key, required this.request});

  @override
  State<CompleteMentorshipView> createState() => _CompleteMentorshipViewState();
}

class _CompleteMentorshipViewState extends State<CompleteMentorshipView> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Complete Mentorship',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mentorship summary card
              _buildSummaryCard(isDark),
              const SizedBox(height: 24),

              // Rating section
              _buildRatingSection(isDark),
              const SizedBox(height: 24),

              // Feedback section
              _buildFeedbackSection(isDark),
              const SizedBox(height: 32),

              // Complete button
              _buildCompleteButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mentorship Summary',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.request.title,
            style: AppTheme.titleSmall.copyWith(
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),

          // Alumni info
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mentor: ${widget.request.alumniName}',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                  ),
                ),
              ),
            ],
          ),
          if (widget.request.alumniCompany != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 16,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.request.alumniCompany!,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Skills
          if (widget.request.skills.isNotEmpty) ...[
            Text(
              'Skills Covered',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.gray300 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.request.skills
                  .take(5)
                  .map(
                    (skill) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        skill,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate Your Experience *',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How would you rate this mentorship experience?',
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 16),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: index < _rating
                        ? Colors.amber
                        : (isDark ? AppTheme.gray600 : AppTheme.gray400),
                    size: 40,
                  ),
                ),
              );
            }),
          ),

          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feedback (Optional)',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your thoughts about this mentorship experience',
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _feedbackController,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'What did you learn? How was the experience? Any suggestions...',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.gray800 : AppTheme.gray50,
              counterStyle: TextStyle(
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
            style: TextStyle(color: isDark ? Colors.white : AppTheme.gray900),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _rating > 0 && !_isSubmitting
            ? () => _completeRequest()
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Complete Mentorship',
                    style: AppTheme.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _completeRequest() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rating'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final mentorshipProvider = context.read<MentorshipProvider>();
      final success = await mentorshipProvider.markCompleted(
        widget.request.id,
        rating: _rating,
        feedback: _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mentorship completed successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.of(context).pop(); // Go back to detail view
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to complete mentorship. Please try again.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
