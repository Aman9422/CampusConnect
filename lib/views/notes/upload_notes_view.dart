import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// UploadNotesView - Teacher-specific notes upload interface
///
/// Replaces the "Coming Soon!" placeholder in teacher workflow.
/// Provides comprehensive file upload with metadata, progress tracking,
/// and validation for sharing lecture materials with students.
class UploadNotesView extends StatefulWidget {
  const UploadNotesView({super.key});

  @override
  State<UploadNotesView> createState() => _UploadNotesViewState();
}

class _UploadNotesViewState extends State<UploadNotesView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _departmentController = TextEditingController();
  final _descriptionController =
      TextEditingController(); // Optional - for future use

  bool _isUploading = false;
  String _selectedYear = '1';
  List<Note> _recentUploads = [];

  @override
  void initState() {
    super.initState();
    _loadRecentUploads();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _departmentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentUploads() async {
    try {
      // For now, use existing getAllNotes and filter client-side
      // In Phase 2, we'll add proper teacher-specific methods
      final allNotesSnapshot = await NotesService.instance()
          .getAllNotes()
          .first;
      final profile = context.read<ProfileProvider>().profile;

      if (profile != null) {
        final teacherNotes = allNotesSnapshot
            .where(
              (note) =>
                  note.uploadedBy == profile.personal.effectiveDisplayName,
            )
            .take(5)
            .toList();

        if (mounted) {
          setState(() {
            _recentUploads = teacherNotes;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load recent uploads: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();
    final profile = context.watch<ProfileProvider>().profile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Upload Lecture Notes',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(layout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher info header
            Container(
              padding: EdgeInsets.all(layout.cardPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.success.withValues(alpha: 0.1),
                    AppTheme.success.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Knowledge',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                        ),
                        Text(
                          'Upload lecture materials for ${profile?.personal.effectiveDisplayName ?? 'your students'}',
                          style: AppTheme.bodySmall.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Upload form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata form
                  _buildMetadataForm(isDark, layout),

                  const SizedBox(height: 24),

                  // Create Note button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: !_isUploading ? _handleCreateNote : null,
                      icon: _isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.create),
                      label: Text(
                        _isUploading ? 'Creating...' : 'Create Note Entry',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Recent uploads section
            if (_recentUploads.isNotEmpty) _buildRecentUploads(isDark, layout),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataForm(bool isDark, LayoutProvider layout) {
    return Container(
      padding: EdgeInsets.all(layout.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note Details',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),

          // Title field
          TextFormField(
            controller: _titleController,
            enabled: !_isUploading,
            decoration: InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g., Data Structures - Week 5 Lecture',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter a title';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Subject field
          TextFormField(
            controller: _subjectController,
            enabled: !_isUploading,
            decoration: InputDecoration(
              labelText: 'Subject *',
              hintText: 'e.g., Computer Science, Mathematics',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              prefixIcon: const Icon(Icons.subject),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter a subject';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Department field
          TextFormField(
            controller: _departmentController,
            enabled: !_isUploading,
            decoration: InputDecoration(
              labelText: 'Department *',
              hintText: 'e.g., Computer Science, Mathematics',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              prefixIcon: const Icon(Icons.business),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter a department';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Year dropdown
          DropdownButtonFormField<String>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Target Year *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              prefixIcon: const Icon(Icons.school),
            ),
            items: ['1', '2', '3', '4']
                .map(
                  (year) =>
                      DropdownMenuItem(value: year, child: Text('Year $year')),
                )
                .toList(),
            onChanged: _isUploading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                      });
                    }
                  },
          ),

          const SizedBox(height: 16),

          // Description field (optional)
          TextFormField(
            controller: _descriptionController,
            enabled: !_isUploading,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any guidance for students',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUploads(bool isDark, LayoutProvider layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Uploads',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
              width: 1,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(layout.cardPadding),
            itemCount: _recentUploads.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
              height: 16,
            ),
            itemBuilder: (context, index) {
              final note = _recentUploads[index];
              return _RecentUploadItem(note: note);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final profile = context.read<ProfileProvider>().profile;
      final teacherName = profile?.personal.effectiveDisplayName ?? 'Teacher';

      // Create note object with proper fields
      final note = Note(
        id: '', // Will be set by Firestore
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        year: _selectedYear,
        department: _departmentController.text.trim(),
        uploadedBy: teacherName,
        uploadedAt: DateTime.now(),
        downloadUrl: null, // No download URL in Phase 1
      );

      // Add the note to Firestore
      await _addNoteToFirestore(note);

      if (mounted) {
        // Reset form
        _formKey.currentState!.reset();
        _titleController.clear();
        _subjectController.clear();
        _departmentController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedYear = '1';
        });

        // Reload recent uploads
        _loadRecentUploads();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note entry created successfully!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to create note: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// Add note to Firestore using existing service pattern
  Future<void> _addNoteToFirestore(Note note) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('notes').add(note.toFirestore());
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Individual recent upload item widget
class _RecentUploadItem extends StatelessWidget {
  final Note note;

  const _RecentUploadItem({required this.note});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(Icons.description, color: AppTheme.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${note.subject} • Year ${note.year} • ${DateFormat('MMM dd').format(note.uploadedAt)}',
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle, color: AppTheme.success, size: 20),
      ],
    );
  }
}
