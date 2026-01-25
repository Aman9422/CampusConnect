import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/services/auth/auth_exceptions.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/show_error_dialog.dart';
import 'package:flutter/material.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
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
                    AppTheme.secondaryIndigo.withOpacity(0.1),
                    AppTheme.darkBackground,
                  ]
                : [
                    AppTheme.accentGradient.colors[0].withOpacity(0.05),
                    AppTheme.accentGradient.colors[1].withOpacity(0.02),
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
                  // Logo/Title with gradient
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondaryIndigo.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: AppTheme.titleLarge.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Sign up to get started with CampusConnect',
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

                  // Register button
                  ElevatedButton(
                    onPressed: () async {
                      final email = _email.text.trim();
                      final password = _password.text.trim();

                      if (email.isEmpty || password.isEmpty) {
                        await showErrorDialog(
                          context,
                          'Email and password cannot be empty',
                        );
                        return;
                      }

                      try {
                        await AuthService.firebase().createUser(
                          email: email,
                          password: password,
                        );
                        AuthService.firebase().sendEmailVerification();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamed(verifyEmailRoute);
                      } on WeakPasswordAuthException {
                        await showErrorDialog(
                          context,
                          'Weak password. Please choose a stronger password.',
                        );
                      } on EmailAlreadyInUseAuthException {
                        await showErrorDialog(
                          context,
                          'Email is already in use. Please use a different email.',
                        );
                      } on InvalidEmailAuthException {
                        await showErrorDialog(
                          context,
                          'Invalid email address. Please enter a valid email.',
                        );
                      } on GenericAuthException {
                        if (!context.mounted) return;
                        await showErrorDialog(
                          context,
                          'Registration failed. Please try again.',
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
                      'Register',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil(loginRoute, (_) => false);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Login',
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
