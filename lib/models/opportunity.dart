import 'package:cloud_firestore/cloud_firestore.dart';

/// Opportunity - v7.2: Multi-role ecosystem
///
/// Represents a job/internship opportunity posted by alumni.
/// Follows StudentProfile patterns for Firestore serialization.
class Opportunity {
  final String id;
  final String alumniId;
  final String title;
  final String company;
  final String description;
  final List<String> requirements;
  final String location;
  final String jobType;
  final String? salaryRange;
  final List<String> skills;
  final DateTime postedAt;
  final DateTime? applicationDeadline;
  final bool isActive;
  final String? applicationUrl;
  final String? contactEmail;

  // Cached alumni info for display (avoid extra Firestore reads)
  final String alumniName;
  final String? alumniJobRole;

  Opportunity({
    required this.id,
    required this.alumniId,
    required this.title,
    required this.company,
    required this.description,
    required this.requirements,
    required this.location,
    required this.jobType,
    required this.skills,
    required this.postedAt,
    required this.isActive,
    required this.alumniName,
    this.salaryRange,
    this.applicationDeadline,
    this.applicationUrl,
    this.contactEmail,
    this.alumniJobRole,
  });

  /// Create from Firestore document
  factory Opportunity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Opportunity(
      id: doc.id,
      alumniId: data['alumniId'] ?? '',
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      description: data['description'] ?? '',
      requirements: List<String>.from(data['requirements'] ?? []),
      location: data['location'] ?? '',
      jobType: data['jobType'] ?? 'Full-time',
      skills: List<String>.from(data['skills'] ?? []),
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      applicationDeadline: (data['applicationDeadline'] as Timestamp?)
          ?.toDate(),
      isActive: data['isActive'] ?? true,
      salaryRange: data['salaryRange'] as String?,
      applicationUrl: data['applicationUrl'] as String?,
      contactEmail: data['contactEmail'] as String?,
      alumniName: data['alumniName'] ?? '',
      alumniJobRole: data['alumniJobRole'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'alumniId': alumniId,
      'title': title,
      'company': company,
      'description': description,
      'requirements': requirements,
      'location': location,
      'jobType': jobType,
      'skills': skills,
      'postedAt': Timestamp.fromDate(postedAt),
      'isActive': isActive,
      'alumniName': alumniName,
    };

    // Optional fields
    if (salaryRange != null) map['salaryRange'] = salaryRange;
    if (applicationDeadline != null) {
      map['applicationDeadline'] = Timestamp.fromDate(applicationDeadline!);
    }
    if (applicationUrl != null) map['applicationUrl'] = applicationUrl;
    if (contactEmail != null) map['contactEmail'] = contactEmail;
    if (alumniJobRole != null) map['alumniJobRole'] = alumniJobRole;

    return map;
  }

  /// Copy with method for updates
  Opportunity copyWith({
    String? title,
    String? company,
    String? description,
    List<String>? requirements,
    String? location,
    String? jobType,
    String? salaryRange,
    List<String>? skills,
    DateTime? applicationDeadline,
    bool? isActive,
    String? applicationUrl,
    String? contactEmail,
    String? alumniName,
    String? alumniJobRole,
  }) {
    return Opportunity(
      id: id,
      alumniId: alumniId,
      title: title ?? this.title,
      company: company ?? this.company,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      location: location ?? this.location,
      jobType: jobType ?? this.jobType,
      salaryRange: salaryRange ?? this.salaryRange,
      skills: skills ?? this.skills,
      postedAt: postedAt,
      applicationDeadline: applicationDeadline ?? this.applicationDeadline,
      isActive: isActive ?? this.isActive,
      applicationUrl: applicationUrl ?? this.applicationUrl,
      contactEmail: contactEmail ?? this.contactEmail,
      alumniName: alumniName ?? this.alumniName,
      alumniJobRole: alumniJobRole ?? this.alumniJobRole,
    );
  }

  /// Check if opportunity has expired
  bool get isExpired {
    if (applicationDeadline == null) return false;
    return DateTime.now().isAfter(applicationDeadline!);
  }

  /// Check if opportunity is available (active and not expired)
  bool get isAvailable => isActive && !isExpired;

  /// Get time since opportunity was posted
  String get timeSince {
    final now = DateTime.now();
    final difference = now.difference(postedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just posted';
    }
  }

  /// Get time until deadline
  String? get timeUntilDeadline {
    if (applicationDeadline == null) return null;

    final now = DateTime.now();
    if (now.isAfter(applicationDeadline!)) return 'Expired';

    final difference = applicationDeadline!.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Expiring soon';
    }
  }

  /// Get display format for job type
  String get jobTypeDisplay {
    switch (jobType.toLowerCase()) {
      case 'full-time':
      case 'fulltime':
        return 'Full-time';
      case 'part-time':
      case 'parttime':
        return 'Part-time';
      case 'internship':
        return 'Internship';
      case 'contract':
        return 'Contract';
      case 'freelance':
        return 'Freelance';
      default:
        return jobType.isEmpty ? 'Full-time' : jobType;
    }
  }
}

/// Job type constants for validation
class JobType {
  static const String fullTime = 'Full-time';
  static const String partTime = 'Part-time';
  static const String internship = 'Internship';
  static const String contract = 'Contract';
  static const String freelance = 'Freelance';

  static const List<String> all = [
    fullTime,
    partTime,
    internship,
    contract,
    freelance,
  ];
}
