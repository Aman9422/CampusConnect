import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String subject;
  final String year;
  final String department;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String? downloadUrl;

  const Note({
    required this.id,
    required this.title,
    required this.subject,
    required this.year,
    required this.department,
    required this.uploadedBy,
    required this.uploadedAt,
    this.downloadUrl,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      subject: data['subject'] ?? '',
      year: data['year'] ?? '',
      department: data['department'] ?? '',
      uploadedBy: data['uploadedBy'] ?? 'Admin',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      downloadUrl: data['downloadUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subject': subject,
      'year': year,
      'department': department,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'downloadUrl': downloadUrl,
    };
  }
}
