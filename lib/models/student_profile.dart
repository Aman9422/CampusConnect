import 'package:campusconnect/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class StudentProfile {
  final String uid;
  final PersonalInfo personal;
  final AcademicInfo academic;
  final CareerInfo career;
  final ProfileMetadata metadata;
  final bool profileCompleted; // Root level per Firestore spec
  final UserRole? role; // v7.1: Role-based access

  // v7.1: Role-specific optional fields (stored at root level in Firestore)
  final String? department;
  final int? graduationYear;
  final List<String>? skills;
  final String? careerInterest;
  final String? company;
  final String? jobRole;
  final String? linkedinProfile;
  final String? designation;

  StudentProfile({
    required this.uid,
    required this.personal,
    required this.academic,
    required this.career,
    required this.metadata,
    this.profileCompleted = false,
    this.role,
    this.department,
    this.graduationYear,
    this.skills,
    this.careerInterest,
    this.company,
    this.jobRole,
    this.linkedinProfile,
    this.designation,
  });

  // Create a default/empty profile
  factory StudentProfile.empty(String uid, String email, {UserRole? role}) {
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
      role: role,
    );
  }

  // Create from Firestore document (v7.2: Backward compatible with flat data)
  factory StudentProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // v7.2: Backward compatibility - handle both nested and flat data structures
    final personalData = data['personal'] as Map<String, dynamic>?;
    final academicData = data['academic'] as Map<String, dynamic>?;
    final careerData = data['career'] as Map<String, dynamic>?;
    final metadataData = data['metadata'] as Map<String, dynamic>?;

    return StudentProfile(
      uid: doc.id,
      // Personal info - fallback to flat fields if nested doesn't exist
      personal: personalData != null
          ? PersonalInfo.fromMap(personalData)
          : PersonalInfo(
              fullName: data['fullName'] ?? '',
              email: data['email'] ?? '',
              phone: data['phone'] ?? '',
              avatarUrl: data['avatarUrl'] ?? '',
              displayName: data['displayName'] ?? '',
              bio: data['bio'] ?? '',
            ),
      // Academic info - fallback to flat fields or defaults
      academic: academicData != null
          ? AcademicInfo.fromMap(academicData)
          : AcademicInfo(
              college: data['college'] ?? '',
              program: data['program'] ?? '',
              year: data['year'] ?? 0,
              cgpa: (data['cgpa'] ?? 0.0).toDouble(),
            ),
      // Career info - fallback to flat fields or defaults
      career: careerData != null
          ? CareerInfo.fromMap(careerData)
          : CareerInfo(
              interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? [],
              preferredRoles: (data['preferredRoles'] as List<dynamic>?)?.cast<String>() ?? [],
            ),
      // Metadata - fallback to current timestamp if not available
      metadata: metadataData != null
          ? ProfileMetadata.fromMap(metadataData)
          : ProfileMetadata(
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ),
      // Read from root level (fallback to metadata for backward compatibility)
      profileCompleted:
          data['profileCompleted'] ??
          (data['metadata'] as Map<String, dynamic>?)?['profileCompleted'] ??
          false,
      // v7.1: Role
      role: UserRole.fromString(data['role'] as String?),
      // v7.1: Role-specific fields
      department: data['department'] as String?,
      graduationYear: data['graduationYear'] as int?,
      skills: (data['skills'] as List<dynamic>?)?.cast<String>(),
      careerInterest: data['careerInterest'] as String?,
      company: data['company'] as String?,
      jobRole: data['jobRole'] as String?,
      linkedinProfile: data['linkedinProfile'] as String?,
      designation: data['designation'] as String?,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'personal': personal.toMap(),
      'academic': academic.toMap(),
      'career': career.toMap(),
      'metadata': metadata.toMap(),
      'profileCompleted': profileCompleted, // Root level per Firestore spec
    };

    // v7.1: Only write role fields if set
    if (role != null) map['role'] = role!.name;
    if (department != null) map['department'] = department;
    if (graduationYear != null) map['graduationYear'] = graduationYear;
    if (skills != null) map['skills'] = skills;
    if (careerInterest != null) map['careerInterest'] = careerInterest;
    if (company != null) map['company'] = company;
    if (jobRole != null) map['jobRole'] = jobRole;
    if (linkedinProfile != null) map['linkedinProfile'] = linkedinProfile;
    if (designation != null) map['designation'] = designation;

    return map;
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
    UserRole? role,
    String? department,
    int? graduationYear,
    List<String>? skills,
    String? careerInterest,
    String? company,
    String? jobRole,
    String? linkedinProfile,
    String? designation,
  }) {
    return StudentProfile(
      uid: uid,
      personal: personal ?? this.personal,
      academic: academic ?? this.academic,
      career: career ?? this.career,
      metadata: metadata ?? this.metadata,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      role: role ?? this.role,
      department: department ?? this.department,
      graduationYear: graduationYear ?? this.graduationYear,
      skills: skills ?? this.skills,
      careerInterest: careerInterest ?? this.careerInterest,
      company: company ?? this.company,
      jobRole: jobRole ?? this.jobRole,
      linkedinProfile: linkedinProfile ?? this.linkedinProfile,
      designation: designation ?? this.designation,
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
