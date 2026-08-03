import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/views/login_view.dart';
import 'package:campusconnect/views/verify_email_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('VerifyEmailView back-to-login navigation (C4 regression)', () {
    testWidgets(
        'Back to Sign In pops to the root without stacking a second LoginView',
        (tester) async {
      await _pumpApp(tester);

      // Mirror the real flow: LoginView pushes RegisterView on top of the
      // root AuthGuard home route.
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('simulate registration complete'), findsOneWidget);

      // Register success: replace the register route with the verify screen.
      // The root home route must be preserved (this is the C4 fix in
      // RegisterView — the old pushNamedAndRemoveUntil removed it).
      await tester.tap(find.text('simulate registration complete'));
      await tester.pumpAndSettle();

      // On the verify screen now, with the root still alive below: the
      // back-to-login handler pops to root rather than stacking a login.
      expect(find.byType(VerifyEmailView), findsOneWidget);

      // Tap "Back to Sign In".
      await tester.tap(find.text('Back to Sign In'));
      await tester.pumpAndSettle();

      // No exception (logOut failure is intentionally swallowed — the user may
      // already be signed out; AuthGuard handles the state).
      expect(tester.takeException(), isNull);

      // The stale pushed route is gone: exactly one LoginView (the root home)
      // is on screen. With the old bugs this assertion failed two ways:
      //   - RegisterView removing the home route → 0 LoginViews
      //   - _backToLogin pushing a second login route → 2 LoginViews
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(VerifyEmailView), findsNothing);
    });

    testWidgets('home route survives the register→verify replacement', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('simulate registration complete'));
      await tester.pumpAndSettle();

      // The replacement must NOT have disposed the root home route. Verify
      // by popping the verify screen and confirming LoginView still renders.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}

/// Pumps the app under test with a tall viewport and settles the LoginView
/// entrance animation. LoginView's 800ms FadeTransition/SlideTransition
/// leaves its widgets at opacity 0 on the first frame, which makes the
/// "Register" link un-hittable — so the animation must run to completion
/// before any tap. Returns once the home route is fully interactive.
Future<void> _pumpApp(WidgetTester tester) async {
  // LoginView is a tall single-scroll layout; give the test a taller
  // viewport so the "Register" link is on-screen and tappable.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // The app's root route (`home`) — represents AuthGuard rendering
      // LoginView while signed out.
      home: const LoginView(),
      routes: {
        // Stand-in for RegisterView's success navigation: on "register
        // complete" it replaces the current route with the verify screen,
        // exactly like RegisterView._handleRegister does now.
        registerRoute: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushReplacementNamed(verifyEmailRoute),
              child: const Text('simulate registration complete'),
            ),
          ),
        ),
        verifyEmailRoute: (context) => const VerifyEmailView(),
      },
    ),
  );

  // Settle the LoginView entrance animation before the first tap.
  await tester.pumpAndSettle();
}
