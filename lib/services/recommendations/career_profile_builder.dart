import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/recommendations/career_profile_input.dart';
import 'package:campusconnect/models/student_profile.dart';

/// CampusConnect v8.9 — Assembles the normalized [CareerProfileInput] from
/// the student's existing profile + portfolio data.
///
/// This is a **derived** view: it reads the in-memory `StudentProfile` and
/// `PortfolioModel` (themselves derived from `users/{uid}`) and produces the
/// single input shape the recommendation engine consumes. It never writes to
/// Firestore and never creates permanent collections.
///
/// Missing data is handled gracefully by [CareerProfileInput] defaults — a
/// student with an incomplete portfolio (or none at all) still produces a
/// valid input and therefore still receives recommendations.
class CareerProfileBuilder {
  /// Build a [CareerProfileInput] from a student profile + portfolio.
  ///
  /// [profile] may be a fully loaded profile or an empty default;
  /// [portfolio] may be an empty portfolio (no resume, no sections). Both
  /// are tolerant inputs — this builder never throws.
  CareerProfileInput build({
    required StudentProfile profile,
    required PortfolioModel portfolio,
  }) {
    final resumeMetadata = portfolio.resume;
    final portfolioPreferences = portfolio.preferences;

    // The root profile `careerInterest` is the free-text fallback signal;
    // the portfolio `careerObjective` is more explicit and preferred when
    // both exist (the portfolio is the student-authored career intent).
    final careerObjective = portfolioPreferences.careerObjective?.isNotEmpty ==
            true
        ? portfolioPreferences.careerObjective
        : profile.careerInterest;

    return CareerProfileInput(
      profileSkills: profile.skills ?? const [],
      portfolioSkills: portfolio.skills,
      languages: portfolio.languages,
      projects: portfolio.projects,
      certifications: portfolio.certifications,
      experience: portfolio.experience,
      preferences: portfolioPreferences,
      careerInterests: profile.career.interests,
      careerPreferredRoles: profile.career.preferredRoles,
      careerObjective: careerObjective,
      resume: resumeMetadata != null
          ? ResumeSignal(
              latestATSScore: resumeMetadata.latestATSScore,
              reviewCount: resumeMetadata.reviewCount,
              lastReviewAt: resumeMetadata.lastReviewAt,
              uploadedAt: resumeMetadata.uploadedAt,
            )
          : null,
      department: profile.department,
      graduationYear: profile.graduationYear,
    );
  }
}
