import 'package:campusconnect/models/portfolio/portfolio_parse.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CampusConnect v8.4 — Student portfolio achievement entry.
///
/// Distinct from `Achievement` in student_profile.dart (which is used by
/// the alumni profile and uses `type` ∈ {certification, award, ...}).
class AchievementModel {
  final String id;
  final String title;
  final String description;
  final DateTime? date;
  final String category; // Academic | Sports | Technical | Cultural | Other

  const AchievementModel({
    required this.id,
    required this.title,
    this.description = '',
    this.date,
    this.category = 'Academic',
  });

  factory AchievementModel.empty() {
    return AchievementModel(id: '', title: '');
  }

  factory AchievementModel.fromMap(Map<String, dynamic> map) {
    // v8.4.7: tolerant reads — dates may arrive as Timestamp, DateTime or
    // ISO-8601 String; never throws; bad fields degrade to defaults.
    return AchievementModel(
      id: asString(map['id']) ?? '',
      title: asString(map['title']) ?? '',
      description: asString(map['description']) ?? '',
      date: tsToDate(map['date']),
      category: asString(map['category']) ?? 'Academic',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'category': category,
    };
  }

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? category,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }

  /// True when the entry has no meaningful content.
  bool get isEmpty => title.trim().isEmpty && description.trim().isEmpty;

  static const List<String> suggestionCategories = [
    'Academic',
    'Sports',
    'Technical',
    'Cultural',
    'Other',
  ];
}
