import 'package:campusconnect/constants/routes.dart'; // v6.8
import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v6.7 - Resume Review View
///
/// AI-powered resume analysis and ATS optimization.
/// Features:
/// - Resume text input (paste)
/// - Optional target role
/// - ATS score display
/// - Detailed feedback sections
/// - Usage tracking display

class ResumeReviewView extends StatefulWidget {
  const ResumeReviewView({super.key});

  @override
  State<ResumeReviewView> createState() => _ResumeReviewViewState();

  /// v6.8: Static method to build results view (reusable in history detail)
  static Widget buildResultsView(ResumeReview review) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return _buildResultsContent(review, isDark);
      },
    );
  }

  static Widget _buildResultsContent(ResumeReview review, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ATS Score Card
        _ATSScoreCard(score: review.atsScore, isDark: isDark),
        const SizedBox(height: 16),

        // Hireability Verdict
        _VerdictCard(verdict: review.hireabilityVerdict, isDark: isDark),
        const SizedBox(height: 16),

        // Strengths
        if (review.strengths.isNotEmpty) ...[
          _SectionCard(
            title: 'Strengths',
            icon: Icons.thumb_up,
            iconColor: Colors.green,
            isDark: isDark,
            child: Column(
              children: review.strengths
                  .map((s) => _buildListItem(s, Colors.green, isDark))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Missing Keywords
        if (review.missingKeywords.isNotEmpty) ...[
          _SectionCard(
            title: 'Missing Keywords',
            icon: Icons.search_off,
            iconColor: Colors.orange,
            isDark: isDark,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.missingKeywords
                  .map((k) => _KeywordChip(keyword: k, isDark: isDark))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Format Issues
        if (review.formatIssues.isNotEmpty) ...[
          _SectionCard(
            title: 'Format Issues',
            icon: Icons.warning_amber,
            iconColor: Colors.amber,
            isDark: isDark,
            child: Column(
              children: review.formatIssues
                  .map((i) => _buildListItem(i, Colors.amber, isDark))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Bullet Improvements
        if (review.bulletImprovements.isNotEmpty) ...[
          _SectionCard(
            title: 'Bullet Point Improvements',
            icon: Icons.auto_fix_high,
            iconColor: AppTheme.primaryBlue,
            isDark: isDark,
            child: Column(
              children: review.bulletImprovements
                  .map(
                    (b) =>
                        _BulletImprovementCard(improvement: b, isDark: isDark),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Section Advice
        if (review.sectionAdvice.nonNullSections.isNotEmpty) ...[
          _SectionCard(
            title: 'Section Advice',
            icon: Icons.lightbulb_outline,
            iconColor: AppTheme.success,
            isDark: isDark,
            child: Column(
              children: review.sectionAdvice.nonNullSections.entries
                  .map(
                    (e) => _SectionAdviceItem(
                      sectionName: e.key,
                      advice: e.value,
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Overall Advice
        if (review.overallAdvice.isNotEmpty) ...[
          _SectionCard(
            title: 'Overall Advice',
            icon: Icons.tips_and_updates,
            iconColor: AppTheme.primaryBlue,
            isDark: isDark,
            child: Text(
              review.overallAdvice,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                height: 1.5,
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  static Widget _buildListItem(String text, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeReviewViewState extends State<ResumeReviewView> {
  final _resumeController = TextEditingController();
  final _roleController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _resumeController.dispose();
    _roleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ResumeReviewProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
      appBar: AppBar(
        title: const Text('Resume Review'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.gray900,
        elevation: 0,
        actions: [
          // v6.8: History button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).pushNamed(resumeReviewHistoryRoute);
            },
            tooltip: 'Review History',
          ),

          // Usage indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceVariant
                      : AppTheme.gray100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${provider.reviewsRemaining}/${provider.usage.monthlyLimit} left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: provider.usage.hasReachedLimit
                        ? Colors.red
                        : (isDark ? AppTheme.gray400 : AppTheme.gray600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          OfflineBanner(isOffline: !provider.isOnline),

          // Main content
          Expanded(
            child: provider.hasReview
                ? _buildReviewResults(context, provider.currentReview!, isDark)
                : _buildInputForm(context, provider, isDark),
          ),
        ],
      ),
    );
  }

  /// Build the resume input form
  Widget _buildInputForm(
    BuildContext context,
    ResumeReviewProvider provider,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          _buildHeaderCard(isDark),
          const SizedBox(height: 20),

          // v8.4.3 (MB6): surface the uploaded portfolio resume so the resume
          // review screen is connected to the PDF the student actually
          // maintains. PDF auto-fill requires a text-extraction parser, so
          // this is the UX bridge (Bug 4): file name / version / ATS chip +
          // View/Download action. The text field below remains for users who
          // prefer to paste.
          _buildUploadedResumeCard(context, isDark),
          const SizedBox(height: 20),

          // Target role input (optional)
          _buildSectionLabel('Target Role (Optional)', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _roleController,
            decoration: _inputDecoration(
              'e.g., Software Engineer, Data Analyst',
              Icons.work_outline,
              isDark,
            ),
            style: TextStyle(color: isDark ? Colors.white : AppTheme.gray900),
          ),
          const SizedBox(height: 20),

          // Resume text input
          _buildSectionLabel('Resume Text', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _resumeController,
            decoration:
                _inputDecoration(
                  'Paste your resume content here...',
                  Icons.description_outlined,
                  isDark,
                ).copyWith(
                  alignLabelWithHint: true,
                  counterText:
                      '${_resumeController.text.length} / 5000 characters',
                  counterStyle: TextStyle(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    fontSize: 12,
                  ),
                ),
            style: TextStyle(color: isDark ? Colors.white : AppTheme.gray900),
            maxLines: 12,
            minLines: 8,
            maxLength: 5000,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // Character count hint
          Text(
            'Minimum 100 characters required',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 24),

          // Error message
          if (provider.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  provider.canSubmitReview &&
                      _resumeController.text.length >= 100
                  ? () => _submitReview(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? AppTheme.gray700
                    : AppTheme.gray300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          provider.submitBlockedReason != null
                              ? 'Cannot Review'
                              : 'Analyze Resume',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Blocked reason
          if (provider.submitBlockedReason != null && !provider.isLoading) ...[
            const SizedBox(height: 8),
            Text(
              provider.submitBlockedReason!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 32),

          // Info section
          _buildInfoSection(isDark),
        ],
      ),
    );
  }

  /// Build the header card explaining the feature
  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Resume Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ATS Optimization & Feedback',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Get actionable feedback to improve your resume\'s ATS score and increase your chances of landing interviews.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// v8.4.3 (MB6): "Using your uploaded resume" card — connects the resume
  /// review screen to the PDF stored in the student portfolio (Bug 4). Shows
  /// the file name, version and latest ATS score, with an Open/Download
  /// action. Hidden entirely when no resume has been uploaded.
  Widget _buildUploadedResumeCard(BuildContext context, bool isDark) {
    final resume = context.watch<PortfolioProvider>().portfolio?.resume;
    if (resume == null || !resume.hasResume) {
      return const SizedBox.shrink();
    }

    final fileName = resume.fileName?.isNotEmpty == true
        ? resume.fileName!
        : 'resume.pdf';
    final ats = resume.latestATSScore;
    final url = resume.downloadUrl?.isNotEmpty == true
        ? resume.downloadUrl!
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  color: AppTheme.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Using your uploaded resume',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ),
              if (ats != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ATS $ats/100',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${resume.version} · PDF · Uploaded ${resume.resumeAgeInDays} day${resume.resumeAgeInDays == 1 ? '' : 's'} ago',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 12),
          if (url != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openResumeUrl(context, url),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: BorderSide(color: AppTheme.success),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open Uploaded Resume'),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Review uses pasted text below. PDF text extraction (auto-fill from '
            'your uploaded resume) is planned — paste the resume text for now.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResumeUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume file')),
        );
      }
    }
  }

  /// Build info section with what AI does/doesn't do
  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you\'ll get:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            Icons.check_circle,
            'ATS compatibility score',
            Colors.green,
            isDark,
          ),
          _buildInfoItem(
            Icons.check_circle,
            'Missing keywords detection',
            Colors.green,
            isDark,
          ),
          _buildInfoItem(
            Icons.check_circle,
            'Bullet point improvements',
            Colors.green,
            isDark,
          ),
          _buildInfoItem(
            Icons.check_circle,
            'Section-by-section advice',
            Colors.green,
            isDark,
          ),
          const SizedBox(height: 12),
          Text(
            'We won\'t:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            Icons.cancel,
            'Invent fake experience',
            Colors.red,
            isDark,
          ),
          _buildInfoItem(
            Icons.cancel,
            'Add false achievements',
            Colors.red,
            isDark,
          ),
          _buildInfoItem(
            Icons.cancel,
            'Rewrite your entire resume',
            Colors.red,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppTheme.gray900,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
      prefixIcon: Icon(
        icon,
        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkSurfaceVariant : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : AppTheme.gray200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
    );
  }

  Future<void> _submitReview(ResumeReviewProvider provider) async {
    FocusScope.of(context).unfocus();

    final success = await provider.submitReview(
      resumeText: _resumeController.text,
      targetRole: _roleController.text.isNotEmpty ? _roleController.text : null,
    );

    if (success && mounted) {
      // Wait for the results view to be built, then scroll to top
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Build the review results view
  Widget _buildReviewResults(
    BuildContext context,
    ResumeReview review,
    bool isDark,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New review button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<ResumeReviewProvider>().clearReview();
                _resumeController.clear();
                _roleController.clear();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Review Another Resume'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Use static method for results display
          ResumeReviewView._buildResultsContent(review, isDark),
        ],
      ),
    );
  }
}

// === Result Display Widgets ===

class _ATSScoreCard extends StatelessWidget {
  final int score;
  final bool isDark;

  const _ATSScoreCard({required this.score, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.gray200),
      ),
      child: Column(
        children: [
          const Text(
            'ATS Compatibility Score',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: isDark
                        ? AppTheme.darkSurfaceVariant
                        : AppTheme.gray100,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      _getScoreLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor() {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.teal;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel() {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Work';
  }
}

class _VerdictCard extends StatelessWidget {
  final String verdict;
  final bool isDark;

  const _VerdictCard({required this.verdict, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.1),
            AppTheme.success.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.gavel,
              color: AppTheme.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hiring Verdict',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verdict,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final String keyword;
  final bool isDark;

  const _KeywordChip({required this.keyword, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Text(
        keyword,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _BulletImprovementCard extends StatelessWidget {
  final BulletImprovement improvement;
  final bool isDark;

  const _BulletImprovementCard({
    required this.improvement,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original (Before)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Before',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  improvement.original,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Improved (After)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'After',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  improvement.improved,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ),
            ],
          ),

          // Reason
          if (improvement.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    improvement.reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
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

class _SectionAdviceItem extends StatelessWidget {
  final String sectionName;
  final String advice;
  final bool isDark;

  const _SectionAdviceItem({
    required this.sectionName,
    required this.advice,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            advice,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
