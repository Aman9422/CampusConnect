import 'package:campusconnect/models/portfolio/career_preferences.dart';
import 'package:campusconnect/models/portfolio/certification_model.dart';
import 'package:campusconnect/models/portfolio/experience_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/models/portfolio/skill_model.dart';

/// CampusConnect v8.9 — Normalized recommendation input model.
///
/// A single, tolerant, derived view of a student's career data assembled
/// from the profile + portfolio. This model is a **derivation** — it is
/// never persisted to Firestore and never duplicates any collection.
///
/// The recommendation engine (client + server) consumes only this shape, so
/// missing fields degrade to safe defaults:
///   - [skills] falls back to the root profile skills when the structured
///     portfolio skills are absent.
///   - Nullable ATS signals are null when no resume review exists.
class CareerProfileInput {
  /// Root-level skills from the student profile (`users/{uid}.skills`).
  final List<String> profileSkills;

  /// Structured portfolio skills (`users/{uid}/portfolio.skills`).
  final List<SkillModel> portfolioSkills;

  /// Portfolio languages.
  final List<String> languages;

  /// Portfolio project technologies + titles (role signal).
  final List<ProjectModel> projects;

  /// Portfolio certifications (titles + issuers).
  final List<CertificationModel> certifications;

  /// Portfolio experience entries.
  final List<ExperienceModel> experience;

  /// Career preferences from `users/{uid}/portfolio.preferences`.
  final CareerPreferences preferences;

  /// Root career interests (`users/{uid}/career.interests`).
  final List<String> careerInterests;

  /// Root preferred roles (`users/{uid}/career.preferredRoles`).
  final List<String> careerPreferredRoles;

  /// Root `careerInterest` fallback signal.
  final String? careerObjective;

  /// Resume metadata (ATS/latest score/reviews) — nullable when not present.
  final ResumeSignal? resume;

  /// Department of the student (`users/{uid}.department`).
  final String? department;

  /// Graduation year (`users/{uid}.graduationYear`).
  final int? graduationYear;

  const CareerProfileInput({
    this.profileSkills = const [],
    this.portfolioSkills = const [],
    this.languages = const [],
    this.projects = const [],
    this.certifications = const [],
    this.experience = const [],
    this.preferences = const CareerPreferences(),
    this.careerInterests = const [],
    this.careerPreferredRoles = const [],
    this.careerObjective,
    this.resume,
    this.department,
    this.graduationYear,
  });

  /// Derive the single effective skill set (lowercased, trimmed, unique)
  /// used by every matcher. Structured portfolio skills take precedence;
  /// root profile skills fill the gaps.
  List<String> get effectiveSkills {
    final merged = <String>{};
    for (final skill in portfolioSkills) {
      final name = skill.name.trim().toLowerCase();
      if (name.isNotEmpty) merged.add(name);
    }
    for (final skill in profileSkills) {
      final name = skill.trim().toLowerCase();
      if (name.isNotEmpty) merged.add(name);
    }
    return merged.toList()..sort();
  }

  /// All career signals in one normalized token set (interests + roles +
  /// career objective) — mirrors the server's `careerSignals` logic.
  List<String> get careerSignals {
    final signals = <String>{};
    signals.addAll(
      careerInterests.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
    );
    signals.addAll(
      careerPreferredRoles.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
    );
    signals.addAll(
      preferences.preferredRoles.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
    );
    final objective = careerObjective?.trim().toLowerCase();
    if (objective != null && objective.isNotEmpty) signals.add(objective);
    return signals.toList()..sort();
  }

  /// Project technologies + titles as a normalized signal set.
  List<String> get projectSignals {
    final signals = <String>{};
    for (final project in projects) {
      signals.addAll(
        project.technologies.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
      );
      final title = project.title.trim().toLowerCase();
      if (title.isNotEmpty) signals.add(title);
    }
    return signals.toList()..sort();
  }

  /// True when the student has any portfolio/profile career content at all.
  bool get hasAnyContent =>
      effectiveSkills.isNotEmpty ||
      languages.isNotEmpty ||
      projects.isNotEmpty ||
      certifications.isNotEmpty ||
      experience.isNotEmpty ||
      !preferences.isEmpty ||
      careerSignals.isNotEmpty;
}

/// Lightweight resume signal — the subset of `ResumeMetadata` the
/// recommendation engine actually consumes.
class ResumeSignal {
  final int? latestATSScore;
  final int reviewCount;
  final DateTime? lastReviewAt;
  final DateTime? uploadedAt;

  const ResumeSignal({
    this.latestATSScore,
    this.reviewCount = 0,
    this.lastReviewAt,
    this.uploadedAt,
  });

  /// ATS score or a neutral 50 when never reviewed.
  int get effectiveAtsScore => latestATSScore ?? 50;

  /// Days since the resume was uploaded (0 when missing).
  int get resumeAgeInDays {
    final uploaded = uploadedAt;
    if (uploaded == null) return 0;
    return DateTime.now().difference(uploaded).inDays;
  }
}
