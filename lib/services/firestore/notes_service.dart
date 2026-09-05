import 'package:campusconnect/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  final FirebaseFirestore _firestore;

  NotesService(this._firestore);

  factory NotesService.instance() {
    return NotesService(FirebaseFirestore.instance);
  }

  CollectionReference get _notesCollection => _firestore.collection('notes');

  // Get all notes as a stream for real-time updates
  Stream<List<Note>> getAllNotes() {
    return _notesCollection
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
        });
  }

  // NOTE (removed dead code): getNotesBySubject() and getNotesByYear() were
  // removed — no UI ever called them, so they were unused. If subject/year
  // filtering is needed later, recreate them (and add the corresponding
  // composite indexes: notes: subject ↑ uploadedAt ↓ and notes: year ↑
  // uploadedAt ↓).

  // Get notes uploaded by a specific teacher/user
  Stream<List<Note>> getNotesByUploader(String uploaderName) {
    return _notesCollection
        .where('uploadedBy', isEqualTo: uploaderName)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
        });
  }

  // Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    try {
      final doc = await _notesCollection.doc(noteId).get();
      if (doc.exists) {
        return Note.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Add a new note
  Future<void> addNote(Note note) async {
    try {
      await _notesCollection.add(note.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Update an existing note
  Future<void> updateNote(String noteId, Map<String, dynamic> updates) async {
    try {
      await _notesCollection.doc(noteId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      await _notesCollection.doc(noteId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get available subjects
  Future<List<String>> getAvailableSubjects() async {
    try {
      final snapshot = await _notesCollection.get();
      final subjects = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final subject = data?['subject'] as String?;
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
