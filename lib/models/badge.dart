import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeType {
  topMentor,
  activeStudent,
  consistencyChampion,
  networkingPro,
  profilePro,
}

class Badge {
  final String id;
  final BadgeType type;
  final String title;
  final String description;
  final String icon;
  final DateTime? earnedAt;
  final int progress;
  final int target;
  final bool isFeatured;

  const Badge({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.earnedAt,
    this.progress = 0,
    this.target = 1,
    this.isFeatured = false,
  });

  factory Badge.fromMap(String id, Map<String, dynamic> data) {
    return Badge(
      id: id,
      type: _parseType(data['type'] as String?),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: data['icon'] as String? ?? 'emoji_events',
      earnedAt: (data['earnedAt'] as Timestamp?)?.toDate(),
      progress: data['progress'] as int? ?? 0,
      target: data['target'] as int? ?? 1,
      isFeatured: data['isFeatured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'icon': icon,
      'progress': progress,
      'target': target,
      'isFeatured': isFeatured,
      if (earnedAt != null) 'earnedAt': Timestamp.fromDate(earnedAt!),
    };
  }

  bool get isEarned => earnedAt != null;

  double get progressPercentage {
    if (target <= 0) return 0.0;
    return (progress / target).clamp(0.0, 1.0);
  }

  static BadgeType _parseType(String? value) {
    switch (value) {
      case 'topMentor':
        return BadgeType.topMentor;
      case 'activeStudent':
        return BadgeType.activeStudent;
      case 'consistencyChampion':
        return BadgeType.consistencyChampion;
      case 'networkingPro':
        return BadgeType.networkingPro;
      case 'profilePro':
        return BadgeType.profilePro;
      default:
        return BadgeType.activeStudent;
    }
  }
}
