import 'package:campusconnect/models/portfolio/portfolio_parse.dart';
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
    // v8.4.7: tolerant reads — dates may arrive as Timestamp, DateTime or
    // ISO-8601 String; numbers may arrive as double; lists may contain
    // non-strings. Never throws; bad entries just degrade to defaults.
    return ProjectModel(
      id: asString(map['id']) ?? '',
      title: asString(map['title']) ?? '',
      description: asString(map['description']) ?? '',
      technologies: parseStringList(map['technologies']),
      githubUrl: asString(map['githubUrl']),
      demoUrl: asString(map['demoUrl']),
      startDate: tsToDate(map['startDate']),
      endDate: tsToDate(map['endDate']),
      currentlyWorking: asBool(map['currentlyWorking']) ?? false,
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
