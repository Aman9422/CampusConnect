import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// NotesListView - Extracted from monolithic NotesView
///
/// Phase 1 of NotesView decomposition: Clean, focused notes browsing view
/// for students. Displays lecture notes with download functionality.
class NotesListView extends StatelessWidget {
  const NotesListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Lecture Notes',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ),
      body: StreamBuilder<List<Note>>(
        stream: NotesService.instance().getAllNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notes available yet'),
                ],
              ),
            );
          }

          final layout = context.watch<LayoutProvider>();

          return ListView.builder(
            padding: EdgeInsets.all(layout.cardPadding),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteCard(note: note);
            },
          );
        },
      ),
    );
  }
}

/// Internal note card widget - extracted from _buildNoteCard in NotesView
class _NoteCard extends StatelessWidget {
  final Note note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.itemSpacing - 4),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withValues(alpha: 0.1),
                        AppTheme.primaryBlue.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    note.subject,
                    style: AppTheme.label.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successBg,
                        AppTheme.successBg.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Year: ${note.year}',
                    style: AppTheme.label.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Uploaded: ${DateFormat('MMM dd, yyyy').format(note.uploadedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (note.downloadUrl != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await _handleNoteDownload(context, note.downloadUrl!);
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handle note download - extracted from NotesView._handleNoteDownload()
  static Future<void> _handleNoteDownload(
    BuildContext context,
    String downloadUrl,
  ) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the link')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening note')));
      }
    }
  }
}
