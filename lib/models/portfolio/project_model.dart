import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4 — Student portfolio project entry.
class ProjectModel {
  final String id;
  final String title;
  final String description;
  final List<String> technologies;
  final String? githubUrl;
  final String? demoUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool currentlyWorking;

  const ProjectModel({
    required this.id,
    required this.title,
    this.description = '',
    this.technologies = const [],
    this.githubUrl,
    this.demoUrl,
    this.startDate,
    this.endDate,
    this.currentlyWorking = false,
  });

  factory ProjectModel.empty() {
    return ProjectModel(
      id: '',
      title: '',
      description: '',
      technologies: const [],
    );
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      technologies:
          (map['technologies'] as List<dynamic>?)?.cast<String>() ?? const [],
      githubUrl: map['githubUrl'] as String?,
      demoUrl: map['demoUrl'] as String?,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      currentlyWorking: map['currentlyWorking'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'technologies': technologies,
      'githubUrl': githubUrl,
      'demoUrl': demoUrl,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'currentlyWorking': currentlyWorking,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? technologies,
    String? githubUrl,
    String? demoUrl,
    DateTime? startDate,
    DateTime? endDate,
    bool? currentlyWorking,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      technologies: technologies ?? this.technologies,
      githubUrl: githubUrl ?? this.githubUrl,
      demoUrl: demoUrl ?? this.demoUrl,
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
  bool get isEmpty => title.trim().isEmpty && description.trim().isEmpty;
}
