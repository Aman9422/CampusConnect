import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfile {
  final String uid;
  final PersonalInfo personal;
  final AcademicInfo academic;
  final CareerInfo career;
  final ProfileMetadata metadata;
  final bool profileCompleted; // Root level per Firestore spec

  StudentProfile({
    required this.uid,
    required this.personal,
    required this.academic,
    required this.career,
    required this.metadata,
    this.profileCompleted = false,
  });

  // Create a default/empty profile
  factory StudentProfile.empty(String uid, String email) {
    return StudentProfile(
      uid: uid,
      personal: PersonalInfo(
        fullName: '',
        email: email,
        phone: '',
        avatarUrl: '',
      ),
      academic: AcademicInfo(college: '', program: '', year: 0, cgpa: 0.0),
      career: CareerInfo(interests: [], preferredRoles: []),
      metadata: ProfileMetadata(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      profileCompleted: false,
    );
  }

  // Create from Firestore document
  factory StudentProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return StudentProfile(
      uid: doc.id,
      personal: PersonalInfo.fromMap(data['personal'] ?? {}),
      academic: AcademicInfo.fromMap(data['academic'] ?? {}),
      career: CareerInfo.fromMap(data['career'] ?? {}),
      metadata: ProfileMetadata.fromMap(data['metadata'] ?? {}),
      // Read from root level (fallback to metadata for backward compatibility)
      profileCompleted:
          data['profileCompleted'] ??
          (data['metadata'] as Map<String, dynamic>?)?['profileCompleted'] ??
          false,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'personal': personal.toMap(),
      'academic': academic.toMap(),
      'career': career.toMap(),
      'metadata': metadata.toMap(),
      'profileCompleted': profileCompleted, // Root level per Firestore spec
    };
  }

  // Check if profile is incomplete
  bool get isIncomplete {
    return personal.fullName.isEmpty ||
        academic.college.isEmpty ||
        academic.program.isEmpty ||
        academic.year <= 0;
  }

  // Copy with method for updates
  StudentProfile copyWith({
    PersonalInfo? personal,
    AcademicInfo? academic,
    CareerInfo? career,
    ProfileMetadata? metadata,
    bool? profileCompleted,
  }) {
    return StudentProfile(
      uid: uid,
      personal: personal ?? this.personal,
      academic: academic ?? this.academic,
      career: career ?? this.career,
      metadata: metadata ?? this.metadata,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}

class PersonalInfo {
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String displayName; // v6.6: Optional display name (max 30 chars)
  final String bio; // v6.6: Optional bio (max 120 chars)

  PersonalInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    this.displayName = '',
    this.bio = '',
  });

  /// v6.6: Get display name with fallback to full name
  String get effectiveDisplayName =>
      displayName.isNotEmpty ? displayName : fullName;

  factory PersonalInfo.fromMap(Map<String, dynamic> map) {
    return PersonalInfo(
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      displayName: map['displayName'] ?? '',
      bio: map['bio'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'displayName': displayName,
      'bio': bio,
    };
  }

  PersonalInfo copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? displayName,
    String? bio,
  }) {
    return PersonalInfo(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
    );
  }
}

class AcademicInfo {
  final String college;
  final String program;
  final int year;
  final double cgpa;

  AcademicInfo({
    required this.college,
    required this.program,
    required this.year,
    required this.cgpa,
  });

  factory AcademicInfo.fromMap(Map<String, dynamic> map) {
    return AcademicInfo(
      college: map['college'] ?? '',
      program: map['program'] ?? '',
      year: map['year'] ?? 0,
      cgpa: (map['cgpa'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'college': college, 'program': program, 'year': year, 'cgpa': cgpa};
  }

  AcademicInfo copyWith({
    String? college,
    String? program,
    int? year,
    double? cgpa,
  }) {
    return AcademicInfo(
      college: college ?? this.college,
      program: program ?? this.program,
      year: year ?? this.year,
      cgpa: cgpa ?? this.cgpa,
    );
  }
}

class CareerInfo {
  final List<String> interests;
  final List<String> preferredRoles;

  CareerInfo({required this.interests, required this.preferredRoles});

  factory CareerInfo.fromMap(Map<String, dynamic> map) {
    return CareerInfo(
      interests: List<String>.from(map['interests'] ?? []),
      preferredRoles: List<String>.from(map['preferredRoles'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'interests': interests, 'preferredRoles': preferredRoles};
  }

  CareerInfo copyWith({List<String>? interests, List<String>? preferredRoles}) {
    return CareerInfo(
      interests: interests ?? this.interests,
      preferredRoles: preferredRoles ?? this.preferredRoles,
    );
  }
}

class ProfileMetadata {
  final DateTime createdAt;
  final DateTime updatedAt;

  ProfileMetadata({required this.createdAt, required this.updatedAt});

  factory ProfileMetadata.fromMap(Map<String, dynamic> map) {
    return ProfileMetadata(
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
