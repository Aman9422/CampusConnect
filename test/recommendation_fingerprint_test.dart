import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/recommendations/recommendation_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

/// v9.2.2 (§2) — client-side recommendation fingerprint tests.
///
/// The fingerprint decides whether a recommendation refresh is a legitimate
/// state change or an implicit duplicate. It must therefore:
///  * be deterministic for equal states (incl. map key order);
///  * EXCLUDE bookkeeping fields such as `metadata.updatedAt` (which changes
///    on every profile write and would defeat the deduplication);
///  * include every recommendation-driving field the engine reads.
void main() {
  StudentProfile profileWith({
    List<String> skills = const ['dart', 'firebase'],
    String careerInterest = 'software',
    String? department = 'CSE',
    int? graduationYear = 2026,
    Map<String, dynamic>? academic,
    DateTime? updatedAt,
  }) {
    return StudentProfile(
      uid: 'uid-1',
      personal: PersonalInfo(
        fullName: 'Ajay A',
        email: 'ajay@example.com',
        phone: '',
        avatarUrl: '',
      ),
      academic: AcademicInfo.fromMap(
        academic ??
            {'college': 'JDCOEM', 'program': 'BE', 'year': 4, 'cgpa': 8.5},
      ),
      career: CareerInfo(interests: const [], preferredRoles: const []),
      metadata: ProfileMetadata(
        createdAt: DateTime(2026, 1, 1),
        updatedAt: updatedAt ?? DateTime(2026, 1, 1),
      ),
      skills: skills,
      careerInterest: careerInterest,
      department: department,
      graduationYear: graduationYear,
    );
  }

  group('recommendationFingerprint — determinism', () {
    test('two calls for the same state are identical', () {
      final profile = profileWith();
      expect(
        recommendationFingerprint(profile),
        recommendationFingerprint(profile),
      );
    });

    test('map key ORDER does not change the fingerprint', () {
      final a = <String, dynamic>{
        'skills': ['dart', 'firebase'],
        'department': 'CSE',
      };
      final b = <String, dynamic>{
        'department': 'CSE',
        'skills': ['dart', 'firebase'],
      };
      expect(recommendationFingerprint(a), recommendationFingerprint(b));
    });

    test('nested map key order does not change the fingerprint', () {
      final a = <String, dynamic>{
        'academic': {'college': 'X', 'program': 'Y'},
      };
      final b = <String, dynamic>{
        'academic': {'program': 'Y', 'college': 'X'},
      };
      expect(recommendationFingerprint(a), recommendationFingerprint(b));
    });

    test('null / non-map input yields a stable empty-state fingerprint', () {
      expect(recommendationFingerprint(null), recommendationFingerprint(null));
      expect(
        recommendationFingerprint(42),
        recommendationFingerprint(const {}),
      );
    });
  });

  group('recommendationFingerprint — excluded bookkeeping fields', () {
    test('metadata.updatedAt does NOT change the fingerprint', () {
      final earlier = profileWith(updatedAt: DateTime(2026, 1, 1));
      final later = profileWith(updatedAt: DateTime(2026, 6, 30, 23, 59));
      expect(
        recommendationFingerprint(earlier),
        recommendationFingerprint(later),
      );
    });

    test('an unrelated map field does NOT change the fingerprint', () {
      final base = <String, dynamic>{
        'skills': ['dart'],
        'isPublicProfile': false,
        'personal': {'fullName': 'A'},
      };
      final changed = <String, dynamic>{
        'skills': ['dart'],
        'isPublicProfile': true,
        'personal': {'fullName': 'A. Renamed'},
      };
      expect(
        recommendationFingerprint(base),
        recommendationFingerprint(changed),
      );
    });
  });

  group('recommendationFingerprint — included intelligence inputs', () {
    test('a skills change alters the fingerprint', () {
      expect(
        recommendationFingerprint(profileWith(skills: const ['dart'])),
        isNot(
          recommendationFingerprint(
            profileWith(skills: const ['dart', 'firebase']),
          ),
        ),
      );
    });

    test('a careerInterest change alters the fingerprint', () {
      expect(
        recommendationFingerprint(profileWith(careerInterest: 'software')),
        isNot(recommendationFingerprint(profileWith(careerInterest: 'data'))),
      );
    });

    test('a department change alters the fingerprint', () {
      expect(
        recommendationFingerprint(profileWith(department: 'CSE')),
        isNot(recommendationFingerprint(profileWith(department: 'IT'))),
      );
    });

    test('a graduationYear change alters the fingerprint', () {
      expect(
        recommendationFingerprint(profileWith(graduationYear: 2026)),
        isNot(recommendationFingerprint(profileWith(graduationYear: 2027))),
      );
    });

    test('an academic change alters the fingerprint', () {
      expect(
        recommendationFingerprint(
          profileWith(
            academic: {'college': 'X', 'program': 'BE', 'year': 4, 'cgpa': 8.5},
          ),
        ),
        isNot(
          recommendationFingerprint(
            profileWith(
              academic: {
                'college': 'X',
                'program': 'BE',
                'year': 4,
                'cgpa': 9.1,
              },
            ),
          ),
        ),
      );
    });

    test(
      'a portfolio change alters the fingerprint when a raw map is passed',
      () {
        final base = <String, dynamic>{
          'skills': ['dart'],
          'portfolio': {
            'skills': ['flutter'],
          },
        };
        final changed = <String, dynamic>{
          'skills': ['dart'],
          'portfolio': {
            'skills': ['flutter', 'dart'],
          },
        };
        expect(
          recommendationFingerprint(base),
          isNot(recommendationFingerprint(changed)),
        );
      },
    );

    test('a mixed Map and StudentProfile with the same signals agree on the '
        'shared fields', () {
      final profile = profileWith(skills: const ['dart']);
      // `StudentProfile.toFirestore()` always writes the nested `career` map
      // (interests + preferredRoles), so the raw-map equivalent must carry it
      // too for the two fingerprints to be comparable.
      final asMap = <String, dynamic>{
        'skills': ['dart'],
        'careerInterest': 'software',
        'department': 'CSE',
        'graduationYear': 2026,
        'academic': {
          'college': 'JDCOEM',
          'program': 'BE',
          'year': 4,
          'cgpa': 8.5,
        },
        'career': {'interests': <String>[], 'preferredRoles': <String>[]},
      };
      expect(
        recommendationFingerprint(profile),
        recommendationFingerprint(asMap),
      );
    });
  });
}
