import 'package:campusconnect/services/auth/auth_provider.dart';
import 'package:campusconnect/services/auth/firebase_auth_provider.dart';
import 'package:campusconnect/services/auth/auth_user.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;
  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) => provider.createUser(email: email, password: password);

  @override
  AuthUser? get currentUser => provider.currentUser;

  // V6.3: Auth state changes stream
  @override
  Stream<AuthUser?> get authStateChanges => provider.authStateChanges;

  @override
  Future<AuthUser> logIn({required String email, required String password}) =>
      provider.logIn(email: email, password: password);

  @override
  Future<void> logOut() => provider.logOut();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();

  @override
  Future<void> initialize() => provider.initialize();

  /// v7.6: Send password reset email
  @override
  Future<void> sendPasswordReset({required String email}) =>
      provider.sendPasswordReset(email: email);
}
