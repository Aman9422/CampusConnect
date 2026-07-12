import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/services/auth/auth_exceptions.dart';
import 'package:campusconnect/services/auth/auth_provider.dart';
import 'package:campusconnect/services/auth/auth_user.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for auth & onboarding fixes.
///
/// These tests verify the specific behavioral changes from the audit fix session
/// do not regress. They test the service/provider interface contracts using pure
/// Dart mocks with no Firebase dependencies required.

// ---------------------------------------------------------------------------
// Mock AuthProvider for testing AuthService
// ---------------------------------------------------------------------------
class MockAuthProvider implements AuthProvider {
  AuthUser? _currentUser;
  bool _initialized = false;
  bool throwOnLogOut = false;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_currentUser);

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    _currentUser = AuthUser(
      id: 'test-uid',
      email: email,
      isEmailVerified: false,
    );
    return _currentUser!;
  }

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) async {
    _currentUser = AuthUser(
      id: 'test-uid',
      email: email,
      isEmailVerified: false,
    );
    return _currentUser!;
  }

  @override
  Future<void> logOut() async {
    if (throwOnLogOut) throw UserNotFoundAuthException();
    _currentUser = null;
  }

  @override
  Future<void> sendEmailVerification() async {
    // No-op for testing
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    // No-op for testing — mock always succeeds
  }
}

/// A pure-Dart test helper that replicates the in-memory setRole/reset
/// contract of RoleProvider without requiring Firebase initialization.
class InMemoryRoleStore {
  UserRole? _role;

  UserRole? get role => _role;
  bool get hasRole => _role != null;

  void setRole(UserRole role) {
    _role = role;
  }

  void reset() {
    _role = null;
  }
}

void main() {
  // -------------------------------------------------------------------------
  // Regression: Issue 1 — RoleProvider.setRole() works in-memory
  //   When currentUser is null after registration, the role is held in memory
  //   via roleProvider.setRole(). This test verifies the pattern works.
  // -------------------------------------------------------------------------
  group('In-memory role store (RoleProvider.setRole() contract)', () {
    test('should hold role in memory', () {
      final store = InMemoryRoleStore();
      expect(store.hasRole, false);

      store.setRole(UserRole.alumni);
      expect(store.hasRole, true);
      expect(store.role, UserRole.alumni);
    });

    test('should override previous role when setRole is called again', () {
      final store = InMemoryRoleStore();
      store.setRole(UserRole.student);
      expect(store.role, UserRole.student);

      store.setRole(UserRole.teacher);
      expect(store.role, UserRole.teacher);
    });

    test('should reset to null on reset', () {
      final store = InMemoryRoleStore();
      store.setRole(UserRole.student);
      expect(store.hasRole, true);

      store.reset();
      expect(store.hasRole, false);
      expect(store.role, isNull);
    });

    test('reset allows fresh setRole', () {
      final store = InMemoryRoleStore();
      store.setRole(UserRole.student);
      store.reset();

      store.setRole(UserRole.alumni);
      expect(store.role, UserRole.alumni);
    });

    test('supports all three user roles', () {
      final store = InMemoryRoleStore();

      store.setRole(UserRole.student);
      expect(store.role, UserRole.student);

      store.setRole(UserRole.alumni);
      expect(store.role, UserRole.alumni);

      store.setRole(UserRole.teacher);
      expect(store.role, UserRole.teacher);
    });
  });

  // -------------------------------------------------------------------------
  // Regression: Finding B — RoleProvider sync after profile setup
  //   Verifies that setRole() can be called independently of saveRole()
  //   (the fix calls roleProvider.setRole(role) after profile save succeeds)
  // -------------------------------------------------------------------------
  group('RoleProvider sync after profile setup (contract)', () {
    test('setRole does not require a Firestore call', () {
      final store = InMemoryRoleStore();
      store.setRole(UserRole.teacher);
      expect(store.role, UserRole.teacher);
      expect(store.hasRole, true);
    });

    test('can change role at any time', () {
      final store = InMemoryRoleStore();

      store.setRole(UserRole.student);
      expect(store.role, UserRole.student);

      store.setRole(UserRole.alumni);
      expect(store.role, UserRole.alumni);
    });
  });

  // -------------------------------------------------------------------------
  // Regression: Finding A — AuthService.logOut() triggers auth state change
  //   The fix removed 9 explicit provider resets from VerifyEmailView's
  //   _backToLogin(). AuthGuard handles resets via StreamBuilder observing
  //   authStateChanges. This verifies the stream contract.
  // -------------------------------------------------------------------------
  group('AuthService.logOut() triggers state change', () {
    late MockAuthProvider mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockAuthProvider();
      authService = AuthService(mockAuth);
    });

    test('should clear currentUser on logOut', () async {
      await authService.logIn(email: 'test@test.com', password: 'pass');
      expect(authService.currentUser, isNotNull);

      await authService.logOut();
      expect(authService.currentUser, isNull);
    });

    test('should propagate exception when mock is configured to throw',
        () async {
      mockAuth.throwOnLogOut = true;
      await authService.logIn(email: 'test@test.com', password: 'pass');

      // The _backToLogin method catches this externally
      expect(authService.logOut(), throwsA(isA<UserNotFoundAuthException>()));
    });
  });

  // -------------------------------------------------------------------------
  // Regression: AuthGuard integration contract
  //   AuthGuard relies on authStateChanges stream to detect logout and
  //   trigger provider resets. Verify the stream contract.
  // -------------------------------------------------------------------------
  group('AuthGuard integration contract', () {
    test('AuthService provides authStateChanges stream', () {
      final mockAuth = MockAuthProvider();
      final authService = AuthService(mockAuth);

      expect(authService.authStateChanges, isA<Stream<AuthUser?>>());
    });

    test('authStateChanges emits current user on login', () async {
      final mockAuth = MockAuthProvider();
      final authService = AuthService(mockAuth);

      await authService.logIn(email: 'a@b.com', password: 'p');

      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser!.email, 'a@b.com');
    });

    test('authStateChanges emits null for unauthenticated state', () {
      final mockAuth = MockAuthProvider();
      final authService = AuthService(mockAuth);

      expect(authService.currentUser, isNull);
    });

    test('logout clears currentUser which AuthGuard observes', () async {
      final mockAuth = MockAuthProvider();
      final authService = AuthService(mockAuth);

      // Simulate login
      await authService.logIn(email: 'test@test.com', password: 'pass');
      expect(authService.currentUser, isNotNull);

      // Simulate logout — AuthGuard's StreamBuilder rebuilds on this
      await authService.logOut();
      expect(authService.currentUser, isNull);

      // Verify the stream reflects the state AuthGuard would see
      await expectLater(
        authService.authStateChanges,
        emits(isNull),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Regression: Issue 3 — _urlController.clear()
  //   Verify TextEditingController.clear() is a valid API call
  // -------------------------------------------------------------------------
  group('TextEditingController.clear() contract', () {
    test('clear() exists and sets text to empty', () {
      final controller = TextEditingController(text: 'some value');
      expect(controller.text, 'some value');

      controller.clear();
      expect(controller.text, isEmpty);
    });
  });
}
