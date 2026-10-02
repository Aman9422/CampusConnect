import 'package:campusconnect/services/firestore/portfolio_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// v9.2.7 — RESUME-WRITE regression: the portfolio write payload shape.
///
/// The reported defect: on the student dashboard, uploading a replacement
/// resume (or removing it) showed the green "Resume uploaded successfully!"
/// / "Resume removed." snackbar, but the resume card never changed and
/// "Open Resume" returned `403 Permission denied` in the browser.
///
/// Root cause: `savePortfolio` built a `set(…, merge: true)` payload from
/// DOT-NOTATION keys — `'portfolio.resume'`, `'portfolio.skills'`, … — and
/// Firestore treats a key containing a dot in a `set(merge:)` payload as a
/// LITERAL root-level field name (dot notation is an `update()` feature). The
/// writes therefore landed in flat fields named `portfolio.resume`, while
/// every reader (`_extractPortfolioMap`, the recommendation engine, the
/// Cloud Functions) read the NESTED `portfolio` map. Storage really did
/// receive/delete the PDF, so the snackbar was honest — only the stored
/// metadata never moved.
///
/// The 403 has the same origin on the storage side: a Firebase Storage
/// download URL carries a token that is rotated whenever the object at the
/// same path is overwritten, and every upload overwrites
/// `resumes/{uid}/latest.pdf`. The stored `downloadUrl` was stale because
/// this very write never landed (that half is covered by
/// `ResumeService.getResumeUrl`, which now resolves a fresh URL).
void main() {
  group(
    'PortfolioService.buildPortfolioWritePayload — canonical nested map',
    () {
      test('addresses the portfolio as ONE nested map, never dotted keys', () {
        final payload = PortfolioService.buildPortfolioWritePayload(
          changedSections: {
            'resume': {'version': 2, 'fileName': 'cv.pdf'},
          },
          updatedAt: 'TS',
        );

        expect(payload.keys, contains('portfolio'));
        expect(payload['portfolio'], {
          'resume': {'version': 2, 'fileName': 'cv.pdf'},
        });

        // The invariant that shipped broken: NO key anywhere may carry a dot,
        // because a dotted key in a merge-set payload is a literal field name.
        expect(
          payload.keys.where((key) => key.contains('.')),
          isEmpty,
          reason:
              'dotted keys are stored literally and are invisible to readers',
        );
      });

      test(
        'stamps metadata.updatedAt as a NESTED map (the trigger reads it '
        'from there, not from a literal "metadata.updatedAt" root field)',
        () {
          final payload = PortfolioService.buildPortfolioWritePayload(
            changedSections: {'skills': []},
            updatedAt: 'TS',
          );

          expect(payload['metadata'], {'updatedAt': 'TS'});
          expect(payload.containsKey('metadata.updatedAt'), isFalse);
        },
      );

      test('a CLEARED resume is written as an explicit null INSIDE the nested '
          'map, so the merge replaces the resume section (Remove Resume could '
          'never stick with the dotted form)', () {
        final payload = PortfolioService.buildPortfolioWritePayload(
          changedSections: {'resume': null},
          updatedAt: 'TS',
        );

        expect(payload['portfolio'], {'resume': null});
        final portfolio = payload['portfolio'] as Map<String, dynamic>;
        expect(portfolio.containsKey('resume'), isTrue);
        expect(portfolio['resume'], isNull);
      });

      test('every changed section travels inside the same nested map — one '
          'write for skills, projects, resume and preferences alike', () {
        final payload = PortfolioService.buildPortfolioWritePayload(
          changedSections: {
            'resume': {'version': 3},
            'skills': [
              {'name': 'Dart'},
            ],
            'projects': [
              {'title': 'CampusConnect'},
            ],
            'preferences': {
              'targetRoles': ['Backend Engineer'],
            },
          },
          updatedAt: 'TS',
        );

        final portfolio = payload['portfolio'] as Map<String, dynamic>;
        expect(
          portfolio.keys,
          unorderedEquals(['resume', 'skills', 'projects', 'preferences']),
        );
        for (final key in payload.keys) {
          expect(key.contains('.'), isFalse);
        }
      });

      test('omits the portfolio key entirely when nothing changed — a no-op '
          'save must never blank a section', () {
        final payload = PortfolioService.buildPortfolioWritePayload(
          changedSections: const {},
          updatedAt: 'TS',
        );

        expect(payload.containsKey('portfolio'), isFalse);
        expect(payload['metadata'], {'updatedAt': 'TS'});
      });
    },
  );
}
