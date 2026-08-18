import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/career_coach_analysis.dart';

/// CampusConnect v9.0 — Career Coach navigation map (Phase 8)
///
/// Maps each supported AI recommendation type to the app destination that
/// lets the student ACT on it. Used by both the dashboard section and the
/// full `/career-coach` screen so behavior stays consistent.
///
/// Contract (docs/Task.md §3/§13.2): `profileSetupRoute` is NEVER opened
/// from a recommendation card — it is reserved for the first-run AuthGuard
/// onboarding flow.
class CareerCoachNavigation {
  const CareerCoachNavigation._();

  /// Route name for a recommendation type.
  ///
  /// Returns `null` for types without a meaningful destination — the caller
  /// keeps the card non-navigating instead of mis-routing.
  static String? routeFor(CareerCoachRecType type) {
    switch (type) {
      case CareerCoachRecType.portfolio:
        return studentPortfolioRoute;
      case CareerCoachRecType.resume:
        return resumeReviewRoute;
      case CareerCoachRecType.project:
        return projectsManagerRoute;
      case CareerCoachRecType.experience:
        return experienceManagerRoute;
      case CareerCoachRecType.certification:
        return certificationsManagerRoute;
      case CareerCoachRecType.achievement:
        return achievementsManagerRoute;
      case CareerCoachRecType.profile:
        // Profile-related actions → Edit Profile → Career & Skills.
        return editProfileRoute;
      case CareerCoachRecType.skill:
      case CareerCoachRecType.interview:
        // Skill learning / interview preparation → AI Career Chat.
        return aiChatRoute;
      case CareerCoachRecType.jobSearch:
        return opportunitiesRoute;
    }
  }

  static String labelFor(CareerCoachRecType type) {
    switch (type) {
      case CareerCoachRecType.portfolio:
        return 'Portfolio';
      case CareerCoachRecType.resume:
        return 'Resume';
      case CareerCoachRecType.project:
        return 'Project';
      case CareerCoachRecType.experience:
        return 'Experience';
      case CareerCoachRecType.certification:
        return 'Certification';
      case CareerCoachRecType.achievement:
        return 'Achievement';
      case CareerCoachRecType.profile:
        return 'Profile';
      case CareerCoachRecType.skill:
        return 'Skill Development';
      case CareerCoachRecType.interview:
        return 'Interview Prep';
      case CareerCoachRecType.jobSearch:
        return 'Job Search';
    }
  }
}
