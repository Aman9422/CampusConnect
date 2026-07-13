import 'package:campusconnect/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// v7.5: Professional work experience entry for alumni career timeline
class WorkExperience {
  final String id;
  final String company;
  final String role;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;

  WorkExperience({
    required this.id,
    required this.company,
    required this.role,
    this.description,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
  });

  factory WorkExperience.fromMap(Map<String, dynamic> map) {
    return WorkExperience(
      id: map['id'] ?? '',
      company: map['company'] ?? '',
      role: map['role'] ?? '',
      description: map['description'] as String?,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      isCurrent: map['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'role': role,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isCurrent': isCurrent,
    };
  }

  WorkExperience copyWith({
    String? id,
    String? company,
    String? role,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
  }) {
    return WorkExperience(
      id: id ?? this.id,
      company: company ?? this.company,
      role: role ?? this.role,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

/// v7.5: Professional achievement entry for alumni
class Achievement {
  final String id;
  final String title;
  final String? issuer;
  final String? description;
  final DateTime? date;
  final String type; // certification, award, publication, openSource, volunteer

  Achievement({
    required this.id,
    required this.title,
    this.issuer,
    this.description,
    this.date,
    this.type = 'certification',
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      issuer: map['issuer'] as String?,
      description: map['description'] as String?,
      date: (map['date'] as Timestamp?)?.toDate(),
      type: map['type'] ?? 'certification',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'issuer': issuer,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'type': type,
    };
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? issuer,
    String? description,
    DateTime? date,
    String? type,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      issuer: issuer ?? this.issuer,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
    );
  }
}

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
  final bool isPublicProfile; // v7.4 optional public alumni profile
  final String? publicProfileKey; // v7.4 shareable profile key

  // v7.5: Alumni professional networking fields
  final int? yearsOfExperience;
  final String? industry;
  final String? employmentType;
  final String? workMode;
  final String? workLocation;
  final String? githubUrl;
  final String? portfolioUrl;
  final String? websiteUrl;
  final String? leetcodeUrl;
  final String? hackerrankUrl;
  final int? maxMentees;
  final List<String>? mentorshipTopics;
  final String? officeHours;
  final List<String>? languages;
  final List<WorkExperience>? workHistory;
  final List<Achievement>? achievements;

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
    this.isPublicProfile = false,
    this.publicProfileKey,
    // v7.5: Alumni professional fields
    this.yearsOfExperience,
    this.industry,
    this.employmentType,
    this.workMode,
    this.workLocation,
    this.githubUrl,
    this.portfolioUrl,
    this.websiteUrl,
    this.leetcodeUrl,
    this.hackerrankUrl,
    this.maxMentees,
    this.mentorshipTopics,
    this.officeHours,
    this.languages,
    this.workHistory,
    this.achievements,
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
              interests:
                  (data['interests'] as List<dynamic>?)?.cast<String>() ?? [],
              preferredRoles:
                  (data['preferredRoles'] as List<dynamic>?)?.cast<String>() ??
                  [],
            ),
      // Metadata - fallback to current timestamp if not available
      metadata: metadataData != null
          ? ProfileMetadata.fromMap(metadataData)
          : ProfileMetadata(
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              updatedAt:
                  (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      isPublicProfile: data['isPublicProfile'] as bool? ?? false,
      publicProfileKey: data['publicProfileKey'] as String?,
      // v7.5: Alumni professional networking fields
      yearsOfExperience: data['yearsOfExperience'] as int?,
      industry: data['industry'] as String?,
      employmentType: data['employmentType'] as String?,
      workMode: data['workMode'] as String?,
      workLocation: data['workLocation'] as String?,
      githubUrl: data['githubUrl'] as String?,
      portfolioUrl: data['portfolioUrl'] as String?,
      websiteUrl: data['websiteUrl'] as String?,
      leetcodeUrl: data['leetcodeUrl'] as String?,
      hackerrankUrl: data['hackerrankUrl'] as String?,
      maxMentees: data['maxMentees'] as int?,
      mentorshipTopics: (data['mentorshipTopics'] as List<dynamic>?)?.cast<String>(),
      officeHours: data['officeHours'] as String?,
      languages: (data['languages'] as List<dynamic>?)?.cast<String>(),
      workHistory: (data['workHistory'] as List<dynamic>?)
          ?.map((e) => WorkExperience.fromMap(e as Map<String, dynamic>))
          .toList(),
      achievements: (data['achievements'] as List<dynamic>?)
          ?.map((e) => Achievement.fromMap(e as Map<String, dynamic>))
          .toList(),
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
    map['isPublicProfile'] = isPublicProfile;
    if (publicProfileKey != null) map['publicProfileKey'] = publicProfileKey;

    // v7.5: Alumni professional fields
    if (yearsOfExperience != null) map['yearsOfExperience'] = yearsOfExperience;
    if (industry != null) map['industry'] = industry;
    if (employmentType != null) map['employmentType'] = employmentType;
    if (workMode != null) map['workMode'] = workMode;
    if (workLocation != null) map['workLocation'] = workLocation;
    if (githubUrl != null) map['githubUrl'] = githubUrl;
    if (portfolioUrl != null) map['portfolioUrl'] = portfolioUrl;
    if (websiteUrl != null) map['websiteUrl'] = websiteUrl;
    if (leetcodeUrl != null) map['leetcodeUrl'] = leetcodeUrl;
    if (hackerrankUrl != null) map['hackerrankUrl'] = hackerrankUrl;
    if (maxMentees != null) map['maxMentees'] = maxMentees;
    if (mentorshipTopics != null) map['mentorshipTopics'] = mentorshipTopics;
    if (officeHours != null) map['officeHours'] = officeHours;
    if (languages != null) map['languages'] = languages;
    if (workHistory != null) {
      map['workHistory'] = workHistory!.map((e) => e.toMap()).toList();
    }
    if (achievements != null) {
      map['achievements'] = achievements!.map((e) => e.toMap()).toList();
    }

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
    bool? isPublicProfile,
    String? publicProfileKey,
    // v7.5: Alumni professional fields
    int? yearsOfExperience,
    String? industry,
    String? employmentType,
    String? workMode,
    String? workLocation,
    String? githubUrl,
    String? portfolioUrl,
    String? websiteUrl,
    String? leetcodeUrl,
    String? hackerrankUrl,
    int? maxMentees,
    List<String>? mentorshipTopics,
    String? officeHours,
    List<String>? languages,
    List<WorkExperience>? workHistory,
    List<Achievement>? achievements,
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
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      publicProfileKey: publicProfileKey ?? this.publicProfileKey,
      // v7.5: Alumni professional fields
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      industry: industry ?? this.industry,
      employmentType: employmentType ?? this.employmentType,
      workMode: workMode ?? this.workMode,
      workLocation: workLocation ?? this.workLocation,
      githubUrl: githubUrl ?? this.githubUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      leetcodeUrl: leetcodeUrl ?? this.leetcodeUrl,
      hackerrankUrl: hackerrankUrl ?? this.hackerrankUrl,
      maxMentees: maxMentees ?? this.maxMentees,
      mentorshipTopics: mentorshipTopics ?? this.mentorshipTopics,
      officeHours: officeHours ?? this.officeHours,
      languages: languages ?? this.languages,
      workHistory: workHistory ?? this.workHistory,
      achievements: achievements ?? this.achievements,
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
