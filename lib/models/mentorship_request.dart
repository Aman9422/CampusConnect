import 'package:cloud_firestore/cloud_firestore.dart';

/// MentorshipRequest - v7.2: Multi-role ecosystem
///
/// Represents a mentorship request from a student to an alumni.
/// Follows StudentProfile patterns for Firestore serialization.
class MentorshipRequest {
  final String id;
  final String studentId;
  final String alumniId;
  final String title;
  final String description;
  final List<String> skills;
  final MentorshipRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseMessage;

  // Cached profile info for display (avoid extra Firestore reads)
  final String studentName;
  final String studentEmail;
  final String alumniName;
  final String? alumniCompany;
  final String? alumniJobRole;

  MentorshipRequest({
    required this.id,
    required this.studentId,
    required this.alumniId,
    required this.title,
    required this.description,
    required this.skills,
    required this.status,
    required this.createdAt,
    required this.studentName,
    required this.studentEmail,
    required this.alumniName,
    this.respondedAt,
    this.responseMessage,
    this.alumniCompany,
    this.alumniJobRole,
  });

  /// Create from Firestore document
  factory MentorshipRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MentorshipRequest(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      alumniId: data['alumniId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      status: MentorshipRequestStatus.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      responseMessage: data['responseMessage'] as String?,
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      alumniName: data['alumniName'] ?? '',
      alumniCompany: data['alumniCompany'] as String?,
      alumniJobRole: data['alumniJobRole'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'studentId': studentId,
      'alumniId': alumniId,
      'title': title,
      'description': description,
      'skills': skills,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'studentName': studentName,
      'studentEmail': studentEmail,
      'alumniName': alumniName,
    };

    // Optional fields
    if (respondedAt != null) {
      map['respondedAt'] = Timestamp.fromDate(respondedAt!);
    }
    if (responseMessage != null) map['responseMessage'] = responseMessage;
    if (alumniCompany != null) map['alumniCompany'] = alumniCompany;
    if (alumniJobRole != null) map['alumniJobRole'] = alumniJobRole;

    return map;
  }

  /// Copy with method for updates
  MentorshipRequest copyWith({
    String? title,
    String? description,
    List<String>? skills,
    MentorshipRequestStatus? status,
    DateTime? respondedAt,
    String? responseMessage,
    String? studentName,
    String? studentEmail,
    String? alumniName,
    String? alumniCompany,
    String? alumniJobRole,
  }) {
    return MentorshipRequest(
      id: id,
      studentId: studentId,
      alumniId: alumniId,
      title: title ?? this.title,
      description: description ?? this.description,
      skills: skills ?? this.skills,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      alumniName: alumniName ?? this.alumniName,
      alumniCompany: alumniCompany ?? this.alumniCompany,
      alumniJobRole: alumniJobRole ?? this.alumniJobRole,
    );
  }

  /// Check if request is pending
  bool get isPending => status == MentorshipRequestStatus.pending;

  /// Check if request was accepted
  bool get isAccepted => status == MentorshipRequestStatus.accepted;

  /// Check if request was rejected
  bool get isRejected => status == MentorshipRequestStatus.rejected;

  /// Check if mentorship is completed
  bool get isCompleted => status == MentorshipRequestStatus.completed;

  /// Get display text for status
  String get statusDisplay => status.displayName;

  /// Get time since request was created
  String get timeSince {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

/// Status enum for mentorship requests
enum MentorshipRequestStatus {
  pending,
  accepted,
  rejected,
  completed;

  String get value => name;

  String get displayName {
    switch (this) {
      case MentorshipRequestStatus.pending:
        return 'Pending';
      case MentorshipRequestStatus.accepted:
        return 'Accepted';
      case MentorshipRequestStatus.rejected:
        return 'Rejected';
      case MentorshipRequestStatus.completed:
        return 'Completed';
    }
  }

  /// Create from string value
  static MentorshipRequestStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'accepted':
        return MentorshipRequestStatus.accepted;
      case 'rejected':
        return MentorshipRequestStatus.rejected;
      case 'completed':
        return MentorshipRequestStatus.completed;
      case 'pending':
      default:
        return MentorshipRequestStatus.pending;
    }
  }
}
