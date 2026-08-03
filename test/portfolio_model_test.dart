import 'package:campusconnect/models/portfolio/career_preferences.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:campusconnect/models/portfolio/skill_model.dart';
import 'package:campusconnect/models/portfolio/social_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PortfolioModel.isEmpty', () {
    test('empty portfolio is empty', () {
      expect(PortfolioModel.empty().isEmpty, isTrue);
    });

    test('preferences-only portfolio is NOT empty (L1)', () {
      const portfolio = PortfolioModel(
        preferences: CareerPreferences(remotePreference: 'Remote'),
      );
      expect(portfolio.isEmpty, isFalse);
    });

    test('links-only portfolio is not empty', () {
      const portfolio = PortfolioModel(
        links: SocialLinks(github: 'https://github.com/aman'),
      );
      expect(portfolio.isEmpty, isFalse);
    });
  });

  group('PortfolioModel.profileCompletion', () {
    test('empty portfolio scores 0 without education', () {
      expect(PortfolioModel.empty().profileCompletion(), 0);
    });

    test('education points only granted when educationFilled (C2)', () {
      final noEducation = PortfolioModel.empty();
      expect(noEducation.profileCompletion(educationFilled: false), 0);
      expect(noEducation.profileCompletion(educationFilled: true), 10);
    });

    test('weighted score matches section presence (20+15+20+5+10)', () {
      final portfolio = PortfolioModel(
        resume: const ResumeMetadata(downloadUrl: 'https://x/resume.pdf'),
        skills: const [
          SkillModel(name: 'Flutter', category: 'Framework', proficiency: 'Advanced'),
        ],
        projects: const [
          ProjectModel(id: 'p1', title: 'App', technologies: ['Flutter']),
        ],
        certifications: const [],
        experience: const [],
        achievements: const [],
        links: const SocialLinks(github: 'https://github.com/a'),
        preferences: const CareerPreferences(),
      );
      // resume 20 + skills 15 + projects 20 + links 5 + education 10 = 70.
      expect(portfolio.profileCompletion(educationFilled: true), 70);
    });
  });

  group('PortfolioModel.copyWith / serialization', () {
    test('copyWith preserves unchanged fields', () {
      final base = PortfolioModel(
        skills: const [SkillModel(name: 'Dart')],
        preferences: const CareerPreferences(preferredRoles: ['Engineer']),
      );
      final updated = base.copyWith(skills: const [SkillModel(name: 'Flutter')]);
      expect(updated.skills.single.name, 'Flutter');
      expect(updated.preferences.preferredRoles, ['Engineer']);
    });

    test('toMap/fromMap round-trip preserves all sections', () {
      final portfolio = PortfolioModel(
        resume: const ResumeMetadata(
          downloadUrl: 'https://x/resume.pdf',
          fileName: 'resume.pdf',
          version: 3,
        ),
        skills: const [
          SkillModel(name: 'Firebase', category: 'Cloud & DevOps', proficiency: 'Intermediate'),
        ],
        projects: const [
          ProjectModel(id: 'p1', title: 'CampusConnect', technologies: ['Flutter']),
        ],
        certifications: const [],
        experience: const [],
        achievements: const [],
        links: const SocialLinks(linkedin: 'https://linkedin.com/in/a'),
        preferences: const CareerPreferences(
          preferredRoles: ['SDE'],
          preferredLocations: ['Bengaluru'],
          expectedSalary: '₹8-12 LPA',
          remotePreference: 'Hybrid',
          relocationPreference: 'Open',
        ),
      );

      final restored = PortfolioModel.fromMap(portfolio.toMap());
      expect(restored.resume?.downloadUrl, portfolio.resume?.downloadUrl);
      expect(restored.resume?.version, 3);
      expect(restored.skills.single.name, 'Firebase');
      expect(restored.projects.single.id, 'p1');
      expect(restored.links.linkedin, 'https://linkedin.com/in/a');
      expect(restored.preferences.preferredRoles, ['SDE']);
      expect(restored.preferences.expectedSalary, '₹8-12 LPA');
    });

    test('fromMap tolerant of malformed sections (M10)', () {
      final restored = PortfolioModel.fromMap({
        'resume': 'not-a-map',
        'skills': ['also-not-a-map'],
        'projects': <dynamic>['x', 1, null],
        'links': 'bad',
        'preferences': 42,
      });
      expect(restored.resume, isNull);
      expect(restored.skills, isEmpty);
      expect(restored.projects, isEmpty);
      expect(restored.links.isEmpty, isTrue);
      expect(restored.preferences.preferredRoles, isEmpty);
    });
  });

  group('CareerPreferences.isEmpty', () {
    test('defaults-only preferences count as empty', () {
      expect(const CareerPreferences().isEmpty, isTrue);
    });

    test('role/location/salary make preferences non-empty', () {
      expect(
        const CareerPreferences(preferredRoles: ['SDE']).isEmpty,
        isFalse,
      );
      expect(
        const CareerPreferences(expectedSalary: '₹10 LPA').isEmpty,
        isFalse,
      );
    });
  });
}
