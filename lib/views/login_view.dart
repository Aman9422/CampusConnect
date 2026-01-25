import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/services/auth/auth_exceptions.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/show_error_dialog.dart';
import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    AppTheme.darkBackground,
                  ]
                : [
                    AppTheme.primaryBlue.withOpacity(0.05),
                    AppTheme.primaryBlueLight.withOpacity(0.02),
                    Colors.white,
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title with gradient background
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.shadowColored,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: AppTheme.titleLarge.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Sign in to continue to CampusConnect',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space40),

                  // Email field
                  TextField(
                    controller: _email,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),

                  // Password field
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),

                  // Login button
                  ElevatedButton(
                    onPressed: () async {
                      final email = _email.text.trim();
                      final password = _password.text.trim();

                      if (email.isEmpty || password.isEmpty) {
                        if (!context.mounted) return;
                        await showErrorDialog(
                          context,
                          'Email and password cannot be empty.',
                        );
                        return;
                      }

                      try {
                        await AuthService.firebase().logIn(
                          email: email,
                          password: password,
                        );

                        final user = AuthService.firebase().currentUser;

                        if (!context.mounted) return;

                        if (user?.isEmailVerified ?? false) {
                          // Navigate to root - AuthGuard will check profile completion
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/', (_) => false);
                        } else {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            verifyEmailRoute,
                            (_) => false,
                          );
                        }
                      } on UserNotFoundAuthException {
                        await showErrorDialog(
                          context,
                          'No account found for that email.',
                        );
                      } on WrongPasswordAuthException {
                        await showErrorDialog(context, 'Incorrect password.');
                      } on InvalidEmailAuthException {
                        if (!context.mounted) return;
                        await showErrorDialog(
                          context,
                          'Incorrect email or password.',
                        );
                      } on InvalidCredentialAuthException {
                        if (!context.mounted) return;
                        await showErrorDialog(
                          context,
                          'Invalid credentials provided.',
                        );
                      } on GenericAuthException {
                        if (!context.mounted) return;
                        await showErrorDialog(
                          context,
                          'Authentication error. Please try again.',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    child: Text(
                      'Login',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            registerRoute,
                            (_) => false,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Register',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
