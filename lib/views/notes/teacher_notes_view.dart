import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/notes/upload_notes_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// TeacherNotesView - Management interface for teachers to view, edit, delete
/// their uploaded lecture notes. Provides a StreamBuilder over the teacher's
/// own notes with inline edit/delete actions and a floating upload button.
class TeacherNotesView extends StatefulWidget {
  const TeacherNotesView({super.key});

  @override
  State<TeacherNotesView> createState() => _TeacherNotesViewState();
}

class _TeacherNotesViewState extends State<TeacherNotesView> {
  /// Form controllers for the inline edit dialog
  final _editTitleController = TextEditingController();
  final _editSubjectController = TextEditingController();
  final _editDepartmentController = TextEditingController();
  final _editUrlController = TextEditingController();
  String _editYear = '1';

  @override
  void dispose() {
    _editTitleController.dispose();
    _editSubjectController.dispose();
    _editDepartmentController.dispose();
    _editUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final teacherName = profile?.personal.effectiveDisplayName ?? '';
    final layout = context.watch<LayoutProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'My Notes',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
            tooltip:
                'Your uploaded lecture notes. Tap to edit or swipe to delete.',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tap a note to edit. Use the upload button to add new notes.',
                ),
              ),
            ),
          ),
        ],
      ),
      body: teacherName.isEmpty
          ? const Center(child: Text('Profile not loaded'))
          : StreamBuilder<List<Note>>(
              stream: NotesService.instance().getNotesByUploader(teacherName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return _buildEmptyState(isDark, layout);
                }
                return _buildNotesList(context, notes, isDark, layout);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToUpload(context),
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Upload Notes'),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, LayoutProvider layout) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(layout.cardPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.note_add, size: 64, color: AppTheme.success),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes yet',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your first lecture note using\nthe button below',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    List<Note> notes,
    bool isDark,
    LayoutProvider layout,
  ) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.cardPadding,
        layout.cardPadding,
        layout.cardPadding,
        80,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteManagementCard(
          note: note,
          isDark: isDark,
          layout: layout,
          onEdit: () => _showEditDialog(context, note, isDark),
          onDelete: () => _confirmDelete(context, note, isDark),
        );
      },
    );
  }

  void _navigateToUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadNotesView()),
    );
  }

  // ─── EDIT DIALOG ────────────────────────────────────────────────

  void _showEditDialog(BuildContext context, Note note, bool isDark) {
    _editTitleController.text = note.title;
    _editSubjectController.text = note.subject;
    _editDepartmentController.text = note.department;
    _editUrlController.text = note.downloadUrl ?? '';
    _editYear = note.year;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _editTitleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editSubjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editDepartmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: ['1', '2', '3', '4']
                    .map(
                      (y) => DropdownMenuItem(value: y, child: Text('Year $y')),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) _editYear = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editUrlController,
                decoration: const InputDecoration(
                  labelText: 'Download Link (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppTheme.gray400 : null),
            ),
          ),
          ElevatedButton(
            onPressed: () => _saveEdit(context, note.id, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEdit(
    BuildContext context,
    String noteId,
    BuildContext dialogContext,
  ) async {
    final title = _editTitleController.text.trim();
    final subject = _editSubjectController.text.trim();
    final department = _editDepartmentController.text.trim();

    if (title.isEmpty || subject.isEmpty || department.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, subject, and department are required'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final url = _editUrlController.text.trim();

    try {
      await NotesService.instance().updateNote(noteId, {
        'title': title,
        'subject': subject,
        'year': _editYear,
        'department': department,
        'downloadUrl': url.isNotEmpty ? url : null,
      });

      if (dialogContext.mounted) Navigator.pop(dialogContext);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note updated successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update note: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ─── DELETE CONFIRMATION ────────────────────────────────────────

  void _confirmDelete(BuildContext context, Note note, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppTheme.gray400 : null),
            ),
          ),
          ElevatedButton(
            onPressed: () => _executeDelete(context, note.id, ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete(
    BuildContext context,
    String noteId,
    BuildContext dialogContext,
  ) async {
    try {
      await NotesService.instance().deleteNote(noteId);

      if (dialogContext.mounted) Navigator.pop(dialogContext);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete note: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

/// Individual note card with edit/delete actions for teacher management
class _NoteManagementCard extends StatelessWidget {
  final Note note;
  final bool isDark;
  final LayoutProvider layout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteManagementCard({
    required this.note,
    required this.isDark,
    required this.layout,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: layout.itemSpacing - 4),
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(layout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${note.subject} • Year ${note.year}',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploaded: ${DateFormat('MMM dd, yyyy').format(note.uploadedAt)}',
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
