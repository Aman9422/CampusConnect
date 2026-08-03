/// CampusConnect v8.4 — Structured portfolio skill.
///
/// Unlike the flat root-level `skills: List<String>` used by alumni directory,
/// teacher analytics and engagement scoring, portfolio skills carry a
/// category and a proficiency level. Portfolio skills live under
/// `users/{uid}/portfolio.skills` and never replace the root field.
class SkillModel {
  final String name;
  final String category;
  final String proficiency; // Beginner | Intermediate | Advanced

  const SkillModel({
    required this.name,
    this.category = 'General',
    this.proficiency = 'Beginner',
  });

  factory SkillModel.fromMap(Map<String, dynamic> map) {
    return SkillModel(
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      proficiency: map['proficiency'] as String? ?? 'Beginner',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'category': category, 'proficiency': proficiency};
  }

  SkillModel copyWith({
    String? name,
    String? category,
    String? proficiency,
  }) {
    return SkillModel(
      name: name ?? this.name,
      category: category ?? this.category,
      proficiency: proficiency ?? this.proficiency,
    );
  }

  static const List<String> proficiencyLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const List<String> suggestionCategories = [
    'Programming Language',
    'Framework',
    'Database',
    'Cloud & DevOps',
    'AI & ML',
    'Soft Skill',
    'Design',
    'Other',
  ];
}
