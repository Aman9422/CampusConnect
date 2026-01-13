import 'package:campusconnect/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  final FirebaseFirestore _firestore;

  NotesService(this._firestore);

  factory NotesService.instance() {
    return NotesService(FirebaseFirestore.instance);
  }

  // Get all notes as a stream for real-time updates
  Stream<List<Note>> getAllNotes() {
    return _firestore
        .collection('notes')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
        });
  }

  // Get notes filtered by subject
  Stream<List<Note>> getNotesBySubject(String subject) {
    return _firestore
        .collection('notes')
        .where('subject', isEqualTo: subject)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
        });
  }

  // Get notes filtered by year
  Stream<List<Note>> getNotesByYear(String year) {
    return _firestore
        .collection('notes')
        .where('year', isEqualTo: year)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
        });
  }

  // Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    try {
      final doc = await _firestore.collection('notes').doc(noteId).get();
      if (doc.exists) {
        return Note.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get available subjects
  Future<List<String>> getAvailableSubjects() async {
    try {
      final snapshot = await _firestore.collection('notes').get();
      final subjects = <String>{};
      for (var doc in snapshot.docs) {
        final subject = (doc.data())['subject'] as String?;
        if (subject != null && subject.isNotEmpty) {
          subjects.add(subject);
        }
      }
      return subjects.toList()..sort();
    } catch (e) {
      rethrow;
    }
  }
}
