import 'package:campusconnect/views/notes_view.dart';
import 'package:flutter/material.dart';

/// v7.1: Student dashboard - wraps existing NotesView (full feature set)
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Students get the full existing experience
    return const NotesView();
  }
}
