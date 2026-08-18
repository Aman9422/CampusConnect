import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// v8.9.2 (project_info__25.md / project_info__26.md) —
/// "No New Recommendations After Filling Portfolio (80% Strength)".
///
/// Regression mirror for the portfolio ↔ Firestore divergence rule.
///
/// Background: the user's Firestore doc held only `(metadata, role,
/// personal.email)` while the app showed 80% portfolio strength from
/// memory/SharedPreferences. The v8.9.1 engine correctly gates every
/// personalized recommendation on `hasMeaningfulPortfolioContent` — and it
/// reads Firestore, not the local cache — so each refresh wrote only the
/// "Complete your portfolio first" gate card. The data the user "filled" was
/// never visible to the server (wiped doc or never-persisted writes).
///
/// The v8.4.4 stale-guards were built to ignore EMPTY server reads so a
/// local-cache replay can never wipe a just-uploaded resume — but that same
/// protection silently hid a genuinely-empty server doc. This test pins the
/// v8.9.2 rule that distinguishes the two cases and unlocks the self-heal.
void main() {
  group(
    'shouldTriggerPortfolioRestore — v8.9.2 divergence rule '
    '(memory has data, server doc empty)', () {
      test('FALSE on the first empty event when the server never reported '
          'content AND nothing was restored from cache — treated as a '
          'stale/cache replay (v8.4.4 guard kept)', () {
        expect(
          shouldTriggerPortfolioRestore(
            serverHadContent: false,
            restoreAlreadyAttempted: false,
            restoredFromCache: false,
          ),
          isFalse,
        );
      });

      test('TRUE when the server confirmed content earlier and a LATER empty '
          'read arrives — the document was wiped mid-session, restore is '
          'safe', () {
        expect(
          shouldTriggerPortfolioRestore(
            serverHadContent: true,
            restoreAlreadyAttempted: false,
            restoredFromCache: false,
          ),
          isTrue,
        );
      });

      test('TRUE when memory was restored from the local cache at startup '
          '(last-known-good) and the server reads empty — the user\'s exact '
          '"80% strength but server has no portfolio" state; the v8.4.4 '
          'write-in-flight guard already covers the stale-replay case',
          () {
        expect(
          shouldTriggerPortfolioRestore(
            serverHadContent: false,
            restoreAlreadyAttempted: false,
            restoredFromCache: true,
          ),
          isTrue,
        );
      });

      test('FALSE once a restore was already attempted — no infinite '
          'write/stream/retry loop', () {
        // Once attempted, nothing re-triggers — regardless of source.
        expect(
          shouldTriggerPortfolioRestore(
            serverHadContent: true,
            restoreAlreadyAttempted: true,
            restoredFromCache: false,
          ),
          isFalse,
        );
        expect(
          shouldTriggerPortfolioRestore(
            serverHadContent: false,
            restoreAlreadyAttempted: true,
            restoredFromCache: true,
          ),
          isFalse,
        );
      });

      test('FALSE for every combination once an attempt has been made', () {
        for (final serverHadContent in [false, true]) {
          for (final restoredFromCache in [false, true]) {
            expect(
              shouldTriggerPortfolioRestore(
                serverHadContent: serverHadContent,
                restoreAlreadyAttempted: true,
                restoredFromCache: restoredFromCache,
              ),
              isFalse,
            );
          }
        }
      });
    },
  );

  group('isServerSynced mirror — v8.9.2 banner condition', () {
    // Mirrors PortfolioProvider.isServerSynced:
    //   _serverNonEmpty || _portfolio == null || _portfolio!.isEmpty
    bool mirroredIsServerSynced({
      required bool serverNonEmpty,
      required bool hasPortfolio,
      required bool portfolioEmpty,
    }) =>
        serverNonEmpty || !hasPortfolio || portfolioEmpty;

    test('fresh user (no portfolio yet) is "synced" — no scary banner', () {
      expect(
        mirroredIsServerSynced(
          serverNonEmpty: false,
          hasPortfolio: true,
          portfolioEmpty: true,
        ),
        isTrue,
      );
    });

    test('server confirmed content — synced even while holding nothing '
        'non-empty in memory', () {
      expect(
        mirroredIsServerSynced(
          serverNonEmpty: true,
          hasPortfolio: true,
          portfolioEmpty: true,
        ),
        isTrue,
      );
    });

    test('healthiest normal state — server has content AND memory has content '
        'is synced', () {
      expect(
        mirroredIsServerSynced(
          serverNonEmpty: true,
          hasPortfolio: true,
          portfolioEmpty: false,
        ),
        isTrue,
      );
    });

    test('THE BUG STATE — memory holds data (80% strength) but the server '
        'document never confirmed content AND nothing was cached-restored: '
        'NOT synced → banner surfaces', () {
      expect(
        mirroredIsServerSynced(
          serverNonEmpty: false,
          hasPortfolio: true,
          portfolioEmpty: false,
        ),
        isFalse,
      );
    });
  });
}
