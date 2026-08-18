import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/portfolio/career_preferences.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/models/portfolio/skill_model.dart';
import 'package:campusconnect/models/recommendations/career_profile_input.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/recommendations/career_profile_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final builder = CareerProfileBuilder();

  StudentProfile profileWith({
    List<String> skills = const [],
    String? careerInterest,
    List<String> interests = const [],
    List<String> preferredRoles = const [],
    String? department,
  }) {
    return StudentProfile(
      uid: 'student-1',
      personal: PersonalInfo(
        fullName: 'Aman',
        email: 'aman@campus.com',
        phone: '',
        avatarUrl: '',
      ),
      academic: AcademicInfo(
        college: 'Campus College',
        program: 'Computer Science',
        year: 3,
        cgpa: 8.2,
      ),
      career: CareerInfo(interests: interests, preferredRoles: preferredRoles),
      metadata: ProfileMetadata(
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      role: UserRole.student,
      skills: skills,
      careerInterest: careerInterest,
      department: department,
      graduationYear: 2027,
    );
  }

  group('CareerProfileBuilder.build', () {
    test('merges complete profile + portfolio into the normalized input', () {
      final input = builder.build(
        profile: profileWith(
          skills: ['Flutter', 'Dart'],
          interests: ['Mobile Development'],
          preferredRoles: ['Mobile Developer'],
          department: 'CSE',
          careerInterest: 'Become a mobile engineer',
        ),
        portfolio: const PortfolioModel(
          resume: ResumeMetadata(
            latestATSScore: 82,
            reviewCount: 3,
          ),
          skills: [
            SkillModel(
              name: 'Firebase',
              category: 'Cloud & DevOps',
              proficiency: 'Intermediate',
            ),
          ],
          projects: [
            ProjectModel(
              id: 'p1',
              title: 'CampusConnect',
              technologies: ['Flutter', 'Firebase'],
            ),
          ],
          languages: ['English', 'Hindi'],
          preferences: CareerPreferences(
            preferredRoles: ['Mobile Developer'],
            careerObjective: 'Build world-class mobile products',
          ),
        ),
      );

      expect(input.profileSkills, contains('Flutter'));
      expect(input.portfolioSkills.single.name, 'Firebase');
      expect(input.languages, contains('English'));
      expect(input.projects.single.title, 'CampusConnect');
      expect(input.resume?.latestATSScore, 82);
      expect(input.resume?.reviewCount, 3);
      expect(input.department, 'CSE');
      expect(input.graduationYear, 2027);
      // Portfolio career objective is preferred over the root careerInterest.
      expect(input.careerObjective, 'Build world-class mobile products');
    });

    test('empty portfolio falls back to profile skills + no resume signal', () {
      final input = builder.build(
        profile: profileWith(skills: ['Python']),
        portfolio: PortfolioModel.empty(),
      );

      expect(input.effectiveSkills, ['python']);
      expect(input.portfolioSkills, isEmpty);
      expect(input.resume, isNull);
      expect(input.projects, isEmpty);
      expect(input.hasAnyContent, isTrue); // still has profile skills
    });

    test('empty profile + empty portfolio still yields a valid input', () {
      final input = builder.build(
        profile: StudentProfile.empty('student-1', 'a@b.com'),
        portfolio: PortfolioModel.empty(),
      );

      expect(input.effectiveSkills, isEmpty);
      expect(input.careerSignals, isEmpty);
      expect(input.hasAnyContent, isFalse);
      expect(input.resume, isNull);
    });

    test('root careerInterest used when portfolio career objective is absent', () {
      final input = builder.build(
        profile: profileWith(careerInterest: 'Data science enthusiast'),
        portfolio: const PortfolioModel(preferences: CareerPreferences()),
      );

      expect(input.careerObjective, 'Data science enthusiast');
    });
  });

  group('CareerProfileInput derived signals', () {
    test('effectiveSkills are lowered, trimmed, deduped and merged', () {
      const input = CareerProfileInput(
        profileSkills: ['Flutter', ' Dart ', 'python'],
        portfolioSkills: [
          SkillModel(
            name: 'Flutter',
            category: 'Framework',
            proficiency: 'Advanced',
          ),
          SkillModel(
            name: 'Python',
            category: 'Programming Language',
            proficiency: 'Intermediate',
          ),
        ],
      );

      expect(input.effectiveSkills, ['dart', 'flutter', 'python']);
    });

    test('careerSignals combines interests, roles, preferences and objective', () {
      const input = CareerProfileInput(
        careerInterests: ['AI'],
        careerPreferredRoles: ['Data Analyst'],
        preferences: CareerPreferences(preferredRoles: ['Machine Learning']),
        careerObjective: 'Become an ML engineer',
      );

      final signals = input.careerSignals;
      expect(signals, contains('ai'));
      expect(signals, contains('data analyst'));
      expect(signals, contains('machine learning'));
      expect(signals, contains('become an ml engineer'));
    });

    test('projectSignals include technologies and titles', () {
      const input = CareerProfileInput(
        projects: [
          ProjectModel(
            id: 'p1',
            title: 'CampusConnect',
            technologies: ['Flutter', 'Firebase'],
          ),
        ],
      );

      final signals = input.projectSignals;
      expect(signals, contains('flutter'));
      expect(signals, contains('firebase'));
      expect(signals, contains('campusconnect'));
    });
  });

  group('ResumeSignal', () {
    test('effectiveAtsScore falls back to a neutral 50 when never reviewed', () {
      const noReview = ResumeSignal();
      expect(noReview.effectiveAtsScore, 50);
      expect(noReview.resumeAgeInDays, 0);
    });

    test('effectiveAtsScore uses the latest ATS score when present', () {
      const reviewed = ResumeSignal(latestATSScore: 91);
      expect(reviewed.effectiveAtsScore, 91);
    });
  });
}
