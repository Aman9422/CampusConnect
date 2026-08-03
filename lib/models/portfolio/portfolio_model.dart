import 'package:campusconnect/models/portfolio/achievement_model.dart';
import 'package:campusconnect/models/portfolio/career_preferences.dart';
import 'package:campusconnect/models/portfolio/certification_model.dart';
import 'package:campusconnect/models/portfolio/experience_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/models/portfolio/skill_model.dart';
import 'package:campusconnect/models/portfolio/social_links.dart';

/// CampusConnect v8.4 — Complete student resume portfolio.
///
/// Stored as a nested map under `users/{uid}/portfolio` via merge-set writes
/// so it stays fully compatible with the existing user document schema.
///
/// IMPORTANT: This is distinct from the root-level `skills` list on the user
/// document. Root `skills` feeds alumni directory, teacher analytics and
/// engagement scoring — portfolio data never replaces it.
class PortfolioModel {
  final ResumeMetadata? resume;
  final List<SkillModel> skills;
  final List<ProjectModel> projects;
  final List<CertificationModel> certifications;
  final List<ExperienceModel> experience;
  final List<AchievementModel> achievements;
  final SocialLinks links;
  final CareerPreferences preferences;

  const PortfolioModel({
    this.resume,
    this.skills = const [],
    this.projects = const [],
    this.certifications = const [],
    this.experience = const [],
    this.achievements = const [],
    this.links = const SocialLinks(),
    this.preferences = const CareerPreferences(),
  });

  factory PortfolioModel.empty() => const PortfolioModel();

  factory PortfolioModel.fromMap(Map<String, dynamic> map) {
    return PortfolioModel(
      resume: map['resume'] is Map<String, dynamic>
          ? ResumeMetadata.fromMap(map['resume'] as Map<String, dynamic>)
          : null,
      skills:
          (map['skills'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SkillModel.fromMap)
              .toList() ??
          const [],
      projects:
          (map['projects'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ProjectModel.fromMap)
              .toList() ??
          const [],
      certifications:
          (map['certifications'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CertificationModel.fromMap)
              .toList() ??
          const [],
      experience:
          (map['experience'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ExperienceModel.fromMap)
              .toList() ??
          const [],
      achievements:
          (map['achievements'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AchievementModel.fromMap)
              .toList() ??
          const [],
      links: map['links'] is Map<String, dynamic>
          ? SocialLinks.fromMap(map['links'] as Map<String, dynamic>)
          : const SocialLinks(),
      preferences: map['preferences'] is Map<String, dynamic>
          ? CareerPreferences.fromMap(
              map['preferences'] as Map<String, dynamic>,
            )
          : const CareerPreferences(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'resume': resume?.toMap(),
      'skills': skills.map((e) => e.toMap()).toList(),
      'projects': projects.map((e) => e.toMap()).toList(),
      'certifications': certifications.map((e) => e.toMap()).toList(),
      'experience': experience.map((e) => e.toMap()).toList(),
      'achievements': achievements.map((e) => e.toMap()).toList(),
      'links': links.toMap(),
      'preferences': preferences.toMap(),
    };
  }

  PortfolioModel copyWith({
    ResumeMetadata? resume,
    List<SkillModel>? skills,
    List<ProjectModel>? projects,
    List<CertificationModel>? certifications,
    List<ExperienceModel>? experience,
    List<AchievementModel>? achievements,
    SocialLinks? links,
    CareerPreferences? preferences,
  }) {
    return PortfolioModel(
      resume: resume ?? this.resume,
      skills: skills ?? this.skills,
      projects: projects ?? this.projects,
      certifications: certifications ?? this.certifications,
      experience: experience ?? this.experience,
      achievements: achievements ?? this.achievements,
      links: links ?? this.links,
      preferences: preferences ?? this.preferences,
    );
  }

  /// A resume can only be cleared explicitly — used by UI to remove it.
  PortfolioModel copyWithoutResume() {
    return PortfolioModel(
      resume: null,
      skills: skills,
      projects: projects,
      certifications: certifications,
      experience: experience,
      achievements: achievements,
      links: links,
      preferences: preferences,
    );
  }

  /// True when the portfolio carries no meaningful content at all.
  ///
  /// Reflects the whole portfolio (including career preferences) so the
  /// "Build your portfolio" empty-state CTA no longer appears on top of a
  /// portfolio that only has preferences set (issues L1 / M4).
  bool get isEmpty =>
      (resume == null || !resume!.hasResume) &&
      skills.isEmpty &&
      projects.isEmpty &&
      certifications.isEmpty &&
      experience.isEmpty &&
      achievements.isEmpty &&
      links.isEmpty &&
      preferences.isEmpty;

  /// Portfolios with only default career preferences still count as empty —
  /// tests rely on [preferences] having a value for roles/locations/salary.
  bool get hasOnlyDefaultPreferences =>
      skills.isEmpty &&
      projects.isEmpty &&
      certifications.isEmpty &&
      experience.isEmpty &&
      achievements.isEmpty &&
      links.isEmpty &&
      !preferences.isEmpty;

  /// Weighted "Portfolio Strength" score (0–100).
  ///
  /// Education lives in the user profile, not the portfolio model, so the
  /// caller must supply `educationFilled` (true when the profile has academic
  /// data). Previously the getter hardcoded education to true and inflated
  /// every portfolio by +10 (issue C2).
  int profileCompletion({bool educationFilled = false}) {
    var score = 0;
    if (resume?.hasResume == true) score += 20;
    if (skills.isNotEmpty) score += 15;
    if (projects.isNotEmpty) score += 20;
    if (certifications.isNotEmpty) score += 15;
    if (experience.isNotEmpty) score += 10;
    if (educationFilled) score += 10;
    if (achievements.isNotEmpty) score += 5;
    if (links.isNotEmpty) score += 5;
    return score.clamp(0, 100);
  }
}
