import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/services/storage/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v8.4 — Resume Upload screen.
///
/// Picks a PDF (≤ 5 MB), uploads it to Firebase Storage at
/// `resumes/{uid}/latest.pdf`, then persists metadata under
/// `users/{uid}/portfolio.resume`. Also supports deleting the stored resume.
class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  bool _isDeleting = false;
  bool _isPicking = false;
  String? _deleteError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Resume Upload',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, portfolioProvider, child) {
          final resume = portfolioProvider.portfolio?.resume;
          final hasResume = resume?.hasResume == true;
          final userId = portfolioProvider.currentUserId;
          final isUploading = portfolioProvider.isUploadingResume;
          // L7: single busy state drives both action buttons. The provider's
          // own `isSaving` handles Save/Delete, `isUploading` handles upload,
          // `_isDeleting` is the local delete-in-progress flag, and
          // `_isPicking` covers the document-picker window (v8.4.10).
          final isBusy =
              portfolioProvider.isSaving ||
              isUploading ||
              _isDeleting ||
              _isPicking;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasResume) ...[
                  _buildCurrentResume(resume!, isDark),
                  const SizedBox(height: AppTheme.space16),
                ],
                if (_deleteError != null) ...[
                  _buildError(_deleteError!, isDark),
                  const SizedBox(height: AppTheme.space16),
                ],
                if (portfolioProvider.error != null) ...[
                  _buildError(portfolioProvider.error!, isDark),
                  const SizedBox(height: AppTheme.space16),
                ],
                if (hasResume) ...[
                  _buildActionButton(
                    isDark,
                    label: 'Replace Resume',
                    icon: Icons.upload_file_outlined,
                    color: AppTheme.primaryBlue,
                    isLoading: isUploading,
                    onPressed: isBusy ? null : () => _pickAndUpload(userId),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  _buildSecondaryButton(
                    isDark,
                    label: 'Remove Resume',
                    icon: Icons.delete_outline,
                    color: AppTheme.error,
                    isLoading: _isDeleting,
                    onPressed: isBusy ? null : () => _deleteResume(userId),
                  ),
                  const SizedBox(height: AppTheme.space12),
                ] else ...[
                  _buildEmptyState(isDark, isUploading || _isPicking, userId),
                  const SizedBox(height: AppTheme.space16),
                ],
                PortfolioSectionCard(
                  title: 'Guidelines',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _GuidelineRow(
                        icon: Icons.picture_as_pdf_outlined,
                        text: 'PDF format only',
                      ),
                      SizedBox(height: AppTheme.space8),
                      _GuidelineRow(
                        icon: Icons.data_usage,
                        text: 'Maximum size: 5 MB',
                      ),
                      SizedBox(height: AppTheme.space8),
                      _GuidelineRow(
                        icon: Icons.refresh,
                        text: 'A new upload always replaces the current resume',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // M6: typed [ResumeMetadata] instead of `dynamic` + casts.
  Widget _buildCurrentResume(ResumeMetadata resume, bool isDark) {
    return PortfolioSectionCard(
      title: 'Current Resume',
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 20),
        color: AppTheme.primaryBlue,
        tooltip: 'Open Resume',
        onPressed: () {
          final url = resume.downloadUrl;
          if (url != null && url.isNotEmpty) _launchUrl(url);
        },
      ),
      child: Column(
        children: [
          _PortfolioResumeRow(
            icon: Icons.description_outlined,
            label: 'File',
            value: resume.fileName ?? 'resume.pdf',
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space8),
          // v8.4.1 (T3): Full storage metadata (docs/Task.md Phase 2).
          if (resume.fileSize != null) ...[
            _PortfolioResumeRow(
              icon: Icons.data_usage_outlined,
              label: 'Size',
              value: _formatFileSize(resume.fileSize!),
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          if (resume.mimeType?.isNotEmpty == true) ...[
            _PortfolioResumeRow(
              icon: Icons.file_present_outlined,
              label: 'Type',
              value: resume.mimeType!,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          if (resume.storagePath?.isNotEmpty == true) ...[
            _PortfolioResumeRow(
              icon: Icons.folder_outlined,
              label: 'Storage Path',
              value: resume.storagePath!,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          if (resume.latestATSScore != null) ...[
            _PortfolioResumeRow(
              icon: Icons.grade_outlined,
              label: 'Latest ATS',
              value: '${resume.latestATSScore}/100',
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          _PortfolioResumeRow(
            icon: Icons.calendar_today_outlined,
            label: 'Uploaded',
            value: resume.uploadedAt != null
                ? DateFormat('MMM d, yyyy').format(resume.uploadedAt!)
                : '—',
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space8),
          _PortfolioResumeRow(
            icon: Icons.update_outlined,
            label: 'Last Updated',
            value: resume.lastUpdated != null
                ? DateFormat('MMM d, yyyy').format(resume.lastUpdated!)
                : '—',
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space8),
          _PortfolioResumeRow(
            icon: Icons.tag,
            label: 'Version',
            value: 'v${resume.version}',
            isDark: isDark,
          ),
          if (resume.reviewCount > 0) ...[
            const SizedBox(height: AppTheme.space8),
            _PortfolioResumeRow(
              icon: Icons.rate_review_outlined,
              label: 'Reviews',
              value: '${resume.reviewCount}',
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  /// v8.4.1 (T3): Human-readable file size (e.g. "1.2 MB").
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Widget _buildEmptyState(bool isDark, bool isUploading, String? userId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 40,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            'No resume uploaded yet',
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Upload your resume PDF to strengthen your portfolio.',
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          _buildActionButton(
            isDark,
            label: 'Upload Resume',
            icon: Icons.upload_file_outlined,
            color: AppTheme.primaryBlue,
            isLoading: isUploading,
            onPressed: isUploading ? null : () => _pickAndUpload(userId),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    bool isDark, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  Widget _buildSecondaryButton(
    bool isDark, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  Widget _buildError(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(String? userId) async {
    if (userId == null) return;

    // v8.4.10: re-entrancy guard — a double-tap (or a tap during the upload
    // window) must never stack a second picker or a second upload while one
    // is already in flight.
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      // C1 fix: `withData: true` is only honoured on Android/iOS/web and
      // `PlatformFile.bytes` is null on desktop. On desktop we rely on
      // `file.size` for validation and pass `filePath` for the upload.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      final file = result.files.single;
      // Use `file.size` — it is populated on every platform, unlike
      // `bytes.length` which is null/0 on desktop.
      final fileLength = file.size;

      final validationError = StorageService.validateResumeFile(
        fileName: file.name,
        length: fileLength,
      );
      if (validationError != null) {
        _showSnack(validationError, error: true);
        return;
      }

      final provider = context.read<PortfolioProvider>();
      final success = await provider.uploadResume(
        userId: userId,
        // Non-web uploads use the file path; web uploads use the in-memory bytes.
        filePath: kIsWeb ? null : file.path,
        bytes: kIsWeb ? file.bytes : null,
        fileName: file.name,
        fileLength: fileLength,
      );
      if (!mounted) return;

      if (success) {
        _showSnack('Resume uploaded successfully!', error: false);
      } else {
        // v8.4.10: surface failures with the same snackbar pattern as
        // success — previously a failed replace was only visible through the
        // banner, making a timeout look like a silent hang.
        _showSnack(
          provider.error ?? 'Failed to upload resume. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      } else {
        _isPicking = false;
      }
    }
  }

  Future<void> _deleteResume(String? userId) async {
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Resume'),
        content: const Text(
          'Are you sure you want to remove your resume from the portfolio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _deleteError = null;
    });
    final provider = context.read<PortfolioProvider>();
    final success = await provider.deleteResume(userId: userId);
    if (!mounted) return;

    setState(() => _isDeleting = false);
    if (success) {
      _showSnack('Resume removed.', error: false);
    } else {
      final error = provider.error;
      setState(() => _deleteError = error ?? 'Failed to remove resume');
    }
  }

  void _showSnack(String message, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack('Could not open resume', error: true);
    }
  }
}

class _GuidelineRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuidelineRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.success),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PortfolioResumeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _PortfolioResumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
        const SizedBox(width: AppTheme.space8),
        Text(
          '$label: ',
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
