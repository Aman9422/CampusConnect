import 'package:campusconnect/services/auth/auth_user.dart';

abstract class AuthProvider {
  Future<void> initialize();
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges; // V6.3: Auth state stream
  Future<AuthUser> logIn({required String email, required String password});

  Future<AuthUser> createUser({
    required String email,
    required String password,
  });
  Future<void> logOut();
  Future<void> sendEmailVerification();
}
