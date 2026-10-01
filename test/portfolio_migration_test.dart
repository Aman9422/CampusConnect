import 'package:campusconnect/services/firestore/portfolio_migration.dart';
import 'package:flutter_test/flutter_test.dart';

/// v9.2.2 (§4) — portfolio flattened-shape migration tests.
///
/// Covers the acceptance criteria of the v9.2.2 brief §4:
///  * the canonical nested shape is produced from the legacy flattened shape;
///  * no portfolio content is lost, transformed or invented;
///  * the migration is IDEMPOTENT (a second run is a no-op);
///  * a document that already carries the nested map is never touched.
void main() {
  group('isFlattenedPortfolioKey', () {
    test('accepts a prefix followed by one or more characters', () {
      expect(isFlattenedPortfolioKey('portfolio.x'), isTrue);
      expect(isFlattenedPortfolioKey('portfolio.resume'), isTrue);
      expect(isFlattenedPortfolioKey('portfolio.resume.downloadUrl'), isTrue);
    });

    test('rejects the bare prefix, the bare key, and unrelated keys', () {
      expect(isFlattenedPortfolioKey('portfolio.'), isFalse);
      expect(isFlattenedPortfolioKey('portfolio'), isFalse);
      expect(isFlattenedPortfolioKey('portfolioX'), isFalse);
      expect(isFlattenedPortfolioKey('skills'), isFalse);
      expect(isFlattenedPortfolioKey('role'), isFalse);
    });
  });

  group('flattenedPortfolioKeys', () {
    test('collects only the flattened portfolio keys', () {
      final data = <String, dynamic>{
        'role': 'student',
        'portfolio.skills': ['dart'],
        'portfolio.resume.downloadUrl': 'https://x/y.pdf',
        'portfolio': null, // explicit null must not suppress detection
        'skills': ['root'],
      };
      expect(
        flattenedPortfolioKeys(data),
        containsAll(<String>[
          'portfolio.skills',
          'portfolio.resume.downloadUrl',
        ]),
      );
      expect(flattenedPortfolioKeys(data).length, 2);
    });

    test('returns an empty list for null / clean documents', () {
      expect(flattenedPortfolioKeys(null), isEmpty);
      expect(
        flattenedPortfolioKeys(<String, dynamic>{'role': 'student'}),
        isEmpty,
      );
    });
  });

  group('unflattenPortfolioPaths', () {
    test('re-nests a depth-1 key', () {
      expect(
        unflattenPortfolioPaths(<String, dynamic>{
          'skills': ['dart'],
        }),
        <String, dynamic>{
          'skills': ['dart'],
        },
      );
    });

    test('re-nests a depth-2 key', () {
      expect(
        unflattenPortfolioPaths(<String, dynamic>{
          'resume.downloadUrl': 'https://x/y.pdf',
          'resume.fileName': 'cv.pdf',
        }),
        <String, dynamic>{
          'resume': {'downloadUrl': 'https://x/y.pdf', 'fileName': 'cv.pdf'},
        },
      );
    });

    test('re-nests a depth-3 key and keeps siblings together', () {
      expect(
        unflattenPortfolioPaths(<String, dynamic>{
          'resume.meta.size': 12345,
          'resume.fileName': 'cv.pdf',
        }),
        <String, dynamic>{
          'resume': {
            'meta': {'size': 12345},
            'fileName': 'cv.pdf',
          },
        },
      );
    });
  });

  group('planPortfolioMigration', () {
    test('returns null when there is nothing to migrate', () {
      expect(planPortfolioMigration(null), isNull);
      expect(planPortfolioMigration(<String, dynamic>{}), isNull);
      expect(
        planPortfolioMigration(<String, dynamic>{'role': 'student'}),
        isNull,
      );
    });

    test('returns null when the canonical nested map is ALREADY present '
        '(idempotency — a second run never re-migrates)', () {
      final canonical = <String, dynamic>{
        'portfolio': {
          'skills': ['dart'],
          'resume': {'downloadUrl': 'https://x/y.pdf'},
        },
        'role': 'student',
      };
      expect(planPortfolioMigration(canonical), isNull);
    });

    test('never touches a document that has BOTH the nested map and legacy '
        'flat keys', () {
      // The nested map is authoritative — leave the document alone so no
      // valid data can be deleted.
      final both = <String, dynamic>{
        'portfolio': {
          'skills': ['dart'],
        },
        'portfolio.skills': ['node'],
      };
      expect(planPortfolioMigration(both), isNull);
    });

    test('plans the nested map + legacy key deletion for a flattened doc', () {
      final flattened = <String, dynamic>{
        'role': 'student',
        'department': 'CSE',
        'portfolio.skills': ['dart', 'firebase'],
        'portfolio.projects': [
          {'id': 'p1', 'title': 'App'},
        ],
        'portfolio.resume.downloadUrl': 'https://x/y.pdf',
        'portfolio.resume.fileName': 'cv.pdf',
      };

      final plan = planPortfolioMigration(flattened);
      expect(plan, isNotNull);
      expect(plan!.isEmpty, isFalse);

      expect(plan.nestedPortfolio, <String, dynamic>{
        'skills': ['dart', 'firebase'],
        'projects': [
          {'id': 'p1', 'title': 'App'},
        ],
        'resume': {'downloadUrl': 'https://x/y.pdf', 'fileName': 'cv.pdf'},
      });

      expect(
        plan.flattenedKeysToDelete,
        containsAll(<String>[
          'portfolio.skills',
          'portfolio.projects',
          'portfolio.resume.downloadUrl',
          'portfolio.resume.fileName',
        ]),
      );
      expect(plan.flattenedKeysToDelete.length, 4);
      // Non-portfolio keys are never scheduled for deletion.
      expect(plan.flattenedKeysToDelete, isNot(contains('role')));
      expect(plan.flattenedKeysToDelete, isNot(contains('department')));
    });

    test('preserves values verbatim — no content is lost or invented', () {
      final resumeMeta = <String, dynamic>{
        'fileName': 'cv.pdf',
        'fileSize': 98765,
        'uploadedAt': '2026-01-01T00:00:00.000Z',
      };
      final flattened = <String, dynamic>{
        'portfolio.resume.fileSize': 98765,
        'portfolio.resume.fileName': 'cv.pdf',
        'portfolio.resume.uploadedAt': '2026-01-01T00:00:00.000Z',
        'portfolio.skills': const <String>[],
        'portfolio.certifications': const <dynamic>[],
      };

      final plan = planPortfolioMigration(flattened)!;

      // The exact values survive, including empty lists.
      expect(plan.nestedPortfolio['resume'], resumeMeta);
      expect(plan.nestedPortfolio['skills'], isEmpty);
      expect(plan.nestedPortfolio['certifications'], isEmpty);
    });

    test('the nested result round-trips: a simulated apply makes a second '
        'plan return null', () {
      final flattened = <String, dynamic>{
        'role': 'student',
        'portfolio.skills': ['dart'],
        'portfolio.resume.downloadUrl': 'https://x/y.pdf',
      };

      final plan = planPortfolioMigration(flattened)!;

      // Simulate the service write: set the nested map, delete the flat keys.
      final after = <String, dynamic>{'role': 'student'};
      after['portfolio'] = plan.nestedPortfolio;
      for (final key in plan.flattenedKeysToDelete) {
        after.remove(key);
      }

      expect(after.containsKey('portfolio.skills'), isFalse);
      expect(after['portfolio'], isA<Map<String, dynamic>>());
      // Idempotent: nothing left to migrate.
      expect(planPortfolioMigration(after), isNull);
    });
  });
}
