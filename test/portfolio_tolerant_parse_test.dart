import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/resume_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

/// v8.4.7 regression test — "Firestore has the data, but the app shows an
/// empty portfolio at 10% strength".
///
/// Root cause: strict casts in `PortfolioModel.fromMap`/sub-model `fromMap`s
/// threw a TypeError when a stored field had an unexpected shape (dates as
/// ISO-8601 strings from console edits/foreign writers, numbers as doubles,
/// or list sections containing non-maps). `PortfolioProvider` then silently
/// fell back to `PortfolioModel.empty()` while Firestore still held all the
/// data. These tests pin the tolerant-parse contract: a malformed section
/// degrades only that section; valid sections are always preserved.
void main() {
  group('PortfolioModel.fromMap — tolerant reads (v8.4.7)', () {
    test('string ISO dates + double numbers parse without throwing', () {
      final portfolio = PortfolioModel.fromMap({
        'resume': {
          'storagePath': 'resumes/u1/latest.pdf',
          'fileName': 'Resume.pdf',
          'fileSize': 200000.0, // double instead of int
          'uploadedAt': '2026-06-01T10:00:00.000Z', // ISO string not Timestamp
          'latestATSScore': 88.0, // double instead of int
          'reviewCount': 4.0, // double instead of int
          'version': 2.0, // double instead of int
        },
        'skills': [
          {'name': 'Flutter', 'category': 'Framework', 'proficiency': 'Advanced'},
        ],
        'projects': [
          {
            'id': 'p1',
            'title': 'CampusConnect',
            'technologies': ['Flutter', 'Firebase'],
            'startDate': '2026-01-15T00:00:00.000Z',
          },
        ],
        'languages': ['English', 'Hindi'],
      });

      // The resume must survive — this is the "resume in Firestore" case.
      expect(portfolio.resume, isNotNull);
      expect(portfolio.resume!.hasResume, isTrue);
      expect(portfolio.resume!.fileSize, 200000);
      expect(portfolio.resume!.latestATSScore, 88);
      expect(portfolio.resume!.reviewCount, 4);
      expect(portfolio.resume!.version, 2);
      expect(portfolio.resume!.uploadedAt, DateTime.utc(2026, 6, 1, 10));

      // Valid sections are preserved.
      expect(portfolio.skills.single.name, 'Flutter');
      expect(portfolio.projects.single.title, 'CampusConnect');
      expect(portfolio.projects.single.technologies, ['Flutter', 'Firebase']);
      expect(
        portfolio.projects.single.startDate,
        DateTime.utc(2026, 1, 15),
      );
      expect(portfolio.languages, ['English', 'Hindi']);
    });

    test('one malformed entry skips only that entry', () {
      final portfolio = PortfolioModel.fromMap({
        'projects': [
          'not-a-map',
          {
            'id': 'ok',
            'title': 'Valid Project',
            'technologies': ['Dart'],
            'currentlyWorking': 'yes', // string instead of bool
          },
        ],
      });
      expect(portfolio.projects, hasLength(1));
      expect(portfolio.projects.single.id, 'ok');
      expect(portfolio.projects.single.currentlyWorking, isFalse);
    });

    test('string-list sections with non-strings never throw', () {
      final portfolio = PortfolioModel.fromMap({
        'languages': ['English', 42, null, 'Hindi'],
        'preferences': {
          'preferredRoles': ['SDE', 7, 'ML Engineer'],
        },
      });
      expect(portfolio.languages, ['English', 'Hindi']);
      expect(portfolio.preferences.preferredRoles, ['SDE', 'ML Engineer']);
    });

    test('a wholly malformed resume section degrades instead of throwing', () {
      final portfolio = PortfolioModel.fromMap({
        'resume': {'downloadUrl': 123}, // wrong shapes everywhere
      });
      expect(portfolio.resume, isNotNull);
      expect(portfolio.resume!.hasResume, isFalse);
      expect(portfolio.resume!.downloadUrl, isNull);
    });

    test('round-trip with dates as Timestamps still works (regression guard)', () {
      final source = PortfolioModel.fromMap({
        'resume': {
          'storagePath': 'resumes/u1/latest.pdf',
          'fileSize': 200000,
          'latestATSScore': 88,
        },
      });
      final restored = PortfolioModel.fromMap(source.toMap());
      expect(restored.resume?.hasResume, isTrue);
      expect(restored.resume?.fileSize, 200000);
      expect(restored.resume?.latestATSScore, 88);
      // toMap currently emits Timestamps for dates; the tolerant reader must
      // accept them as before.
      expect(source.resume?.uploadedAt, restored.resume?.uploadedAt);
    });
  });

  group('ResumeMetadata.fromMap — legacy & tolerant reads', () {
    test('legacy v8.4 keys still work (uploadDate/lastUpdated/atsScore)', () {
      final meta = ResumeMetadata.fromMap({
        'storagePath': 'resumes/u1/latest.pdf',
        'uploadDate': '2026-05-01T00:00:00.000Z',
        'lastUpdated': '2026-05-15T00:00:00.000Z',
        'atsScore': 74.0,
      });
      expect(meta.hasResume, isTrue);
      expect(meta.uploadedAt, DateTime.utc(2026, 5, 1));
      expect(meta.updatedAt, DateTime.utc(2026, 5, 15));
      expect(meta.latestATSScore, 74);
    });

    test('bad dates degrade to null, not a crash', () {
      final meta = ResumeMetadata.fromMap({
        'storagePath': 'resumes/u1/latest.pdf',
        'uploadedAt': 'not-a-date',
        'lastReviewAt': 42,
      });
      expect(meta.hasResume, isTrue);
      expect(meta.uploadedAt, isNull);
      expect(meta.lastReviewAt, isNull);
    });
  });
}
