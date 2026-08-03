import 'package:campusconnect/views/portfolio/portfolio_read_only_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the v8.4 "Portfolio Eye-Icon Crash".
///
/// The bug: [PortfolioReadOnlyView.initState] called `_load()` synchronously,
/// and `_load()`'s first line called `ModalRoute.of(context)` — an inherited
/// widget lookup that is illegal before the element is mounted into the tree.
/// This threw:
///   Unhandled Exception: dependOnInheritedWidgetOfExactType<_ModalScopeStatus>()
///   was called before _PortfolioReadOnlyViewState.initState() completed.
///
/// The fix defers `_load()` to a post-frame callback. These tests verify the
/// first frame renders without throwing, both when the route carries a String
/// argument (teacher eye icon / alumni "View Student Portfolio") and when it
/// carries none (error state).
void main() {
  group('PortfolioReadOnlyView lifecycle (v8.4 crash regression)', () {
    testWidgets(
        'first frame does not throw when route arguments contain a student id',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  // Mimic both real entry points: teacher leaderboard eye
                  // icon and alumni "View Student Portfolio" push the same
                  // route with a raw String uid argument.
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        arguments: 'student-uid-123',
                      ),
                      builder: (_) => const PortfolioReadOnlyView(),
                    ),
                  ),
                  child: const Text('open portfolio'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open portfolio'));

      // First frame of the pushed route — this is exactly where the old
      // code threw the _ModalScopeStatus dependency error.
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Let the route transition finish and the post-frame _load run.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PortfolioReadOnlyView), findsOneWidget);
    });

    testWidgets('shows clean error state when no arguments',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PortfolioReadOnlyView()),
      );

      // First frame(s): no exception (previously crashed here). The spinner
      // may already have been replaced by the error state by the time this
      // assertion runs, since the post-frame _load fires at the end of the
      // first pumped frame — so only the no-exception contract is asserted.
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Post-frame _load resolves: no route arguments -> clean error state.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No student selected.'), findsOneWidget);
    });
  });
}
