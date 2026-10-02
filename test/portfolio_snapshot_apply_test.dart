import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/portfolio_snapshot.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// v9.2.7 — "the resume reverted / came back / never updated" regression.
///
/// The Firestore SDK replays its locally cached document as a normal stream
/// event. Those replays are the snapshot taken BEFORE an upload/remove landed
/// (or a pre-logout state). The provider used to apply them unconditionally,
/// then compensate with a guess ("if memory still has a resume, drop every
/// event that lacks it") — a guess that could lock a REMOVED resume back into
/// the UI forever, and that reverted a replaced resume to the previous file.
///
/// The fix carries Firestore's own `isFromCache` flag through
/// [PortfolioSnapshot] and applies one simple rule:
///
///   * a snapshot the SERVER confirmed always applies — including one that
///     removes the resume (that is what makes "Remove Resume" stick);
///   * a CACHE-sourced snapshot may bootstrap empty state (offline-first) but
///     may never overwrite a value this session already holds.
void main() {
  group('shouldApplyPortfolioSnapshot — v9.2.7 cache-replay rule', () {
    test('a SERVER snapshot applies when memory is empty', () {
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: false, hasLocalData: false),
        isTrue,
      );
    });

    test('a SERVER snapshot applies when memory holds data — it is '
        'authoritative, which is what lets a removed resume leave the UI', () {
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: false, hasLocalData: true),
        isTrue,
      );
    });

    test('a CACHE snapshot still bootstraps EMPTY state (offline-first '
        'first paint must not be blocked)', () {
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: true, hasLocalData: false),
        isTrue,
      );
    });

    test('a CACHE snapshot NEVER overwrites committed in-memory data — this '
        'is the rule that stops a pre-write replay from reverting a fresh '
        'upload or resurrecting a removed resume', () {
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: true, hasLocalData: true),
        isFalse,
      );
    });

    test('the rule is a pure function of the two flags — every combination '
        'is pinned', () {
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: false, hasLocalData: false),
        isTrue,
      );
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: false, hasLocalData: true),
        isTrue,
      );
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: true, hasLocalData: false),
        isTrue,
      );
      expect(
        shouldApplyPortfolioSnapshot(isFromCache: true, hasLocalData: true),
        isFalse,
      );
    });
  });

  group('PortfolioSnapshot — carries the flags the rule needs', () {
    test('reports the empty portfolio a document with no portfolio key '
        'produces, while keeping its cache flag', () {
      final snapshot = PortfolioSnapshot(
        portfolio: PortfolioModel.empty(),
        isFromCache: true,
        hasPendingWrites: false,
      );

      expect(snapshot.portfolio.isEmpty, isTrue);
      expect(snapshot.isFromCache, isTrue);
      expect(snapshot.hasPendingWrites, isFalse);
    });

    test('toString surfaces both flags — the runtime log is the only '
        'diagnostic when a snapshot is being ignored', () {
      final snapshot = PortfolioSnapshot(
        portfolio: PortfolioModel.empty(),
        isFromCache: false,
        hasPendingWrites: true,
      );

      final text = snapshot.toString();
      expect(text.contains('fromCache: false'), isTrue);
      expect(text.contains('pendingWrites: true'), isTrue);
    });
  });
}
