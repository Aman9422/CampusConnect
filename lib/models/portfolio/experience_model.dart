import 'package:campusconnect/models/portfolio/portfolio_parse.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4 — Student portfolio experience entry.
///
/// Distinct from `WorkExperience` in student_profile.dart (which is used by
/// the alumni career timeline and lacks `employmentType`).
class ExperienceModel {
  final String id;
  final String company;
  final String role;
  final String employmentType; // Full-time | Part-time | Internship | Contract | Freelance
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool currentlyWorking;

  const ExperienceModel({
    required this.id,
    required this.company,
    required this.role,
    this.employmentType = 'Internship',
    this.description = '',
    this.startDate,
    this.endDate,
    this.currentlyWorking = false,
  });

  factory ExperienceModel.empty() {
    return ExperienceModel(id: '', company: '', role: '');
  }

  factory ExperienceModel.fromMap(Map<String, dynamic> map) {
    // v8.4.7: tolerant reads — dates may arrive as Timestamp, DateTime or
    // ISO-8601 String; never throws; bad fields degrade to defaults.
    return ExperienceModel(
      id: asString(map['id']) ?? '',
      company: asString(map['company']) ?? '',
      role: asString(map['role']) ?? '',
      employmentType: asString(map['employmentType']) ?? 'Internship',
      description: asString(map['description']) ?? '',
      startDate: tsToDate(map['startDate']),
      endDate: tsToDate(map['endDate']),
      currentlyWorking: asBool(map['currentlyWorking']) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'role': role,
      'employmentType': employmentType,
      'description': description,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'currentlyWorking': currentlyWorking,
    };
  }

  ExperienceModel copyWith({
    String? id,
    String? company,
    String? role,
    String? employmentType,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? currentlyWorking,
  }) {
    return ExperienceModel(
      id: id ?? this.id,
      company: company ?? this.company,
      role: role ?? this.role,
      employmentType: employmentType ?? this.employmentType,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentlyWorking: currentlyWorking ?? this.currentlyWorking,
    );
  }

  /// Effective end for display — today when currently working.
  DateTime get effectiveEndDate => currentlyWorking
      ? DateTime.now()
      : (endDate ?? startDate ?? DateTime.now());

  /// True when the entry has no meaningful content.
  bool get isEmpty => company.trim().isEmpty && role.trim().isEmpty;
}
