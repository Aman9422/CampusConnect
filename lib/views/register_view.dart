import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/services/auth/auth_exceptions.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/auth/auth_user.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/show_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  UserRole? _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    _confirmPassword = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    final confirmPassword = _confirmPassword.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      await showErrorDialog(context, 'Please fill in all required fields.');
      return;
    }

    if (password != confirmPassword) {
      await showErrorDialog(context, 'Passwords do not match.');
      return;
    }

    if (_selectedRole == null) {
      await showErrorDialog(context, 'Please select your role.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.firebase().createUser(
        email: email,
        password: password,
      );

      // Store role selection in RoleProvider for use after email verification
      if (mounted) {
        final roleProvider = context.read<RoleProvider>();
        roleProvider.setRole(_selectedRole!);

        // v7.6: Use a retry-safe approach to save role to Firestore.
        // If currentUser is null transiently after registration, retry.
        final authService = AuthService.firebase();
        AuthUser? user = authService.currentUser;
        if (user == null) {
          // Wait briefly for Firebase Auth to settle, then retry
          await Future.delayed(const Duration(milliseconds: 500));
          user = AuthService.firebase().currentUser;
        }
        if (user != null) {
          await roleProvider.saveRole(user.id, _selectedRole!);
        } else {
          // Delegate: save to local store so RoleProvider still has it
          // The role will be persisted to Firestore when it becomes available
          debugPrint('currentUser null post-registration — role saved in-memory only');
        }
      }

      try {
        await AuthService.firebase().sendEmailVerification();
      } catch (e) {
        debugPrint('Failed to send verification email: $e');
        // Don't block registration — user can resend from VerifyEmailView
      }
      if (!mounted) return;
      // Clear navigation stack back to AuthGuard (no longer uses fragile popUntil)
      Navigator.of(context).pushNamedAndRemoveUntil(verifyEmailRoute, (_) => false);
    } on WeakPasswordAuthException {
      if (!mounted) return;
      await showErrorDialog(
        context, 'Weak password. Please choose a stronger password.');
    } on EmailAlreadyInUseAuthException {
      if (!mounted) return;
      await showErrorDialog(
        context, 'Email is already in use. Please use a different email.');
    } on InvalidEmailAuthException {
      if (!mounted) return;
      await showErrorDialog(
        context, 'Invalid email address. Please enter a valid email.');
    } on GenericAuthException {
      if (!mounted) return;
      await showErrorDialog(
        context, 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school_rounded;
      case UserRole.alumni:
        return Icons.work_outline_rounded;
      case UserRole.teacher:
        return Icons.history_edu_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), AppTheme.darkBackground]
                : [
                    const Color(0xFFF0F0FF),
                    const Color(0xFFF8FAFC),
                    Colors.white,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      const SizedBox(height: AppTheme.space16),

                      // Brand icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryIndigo.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space20),

                      Text(
                        'Create Account',
                        style: AppTheme.titleLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.gray900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Join the CampusConnect ecosystem',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space32),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXLarge,
                          ),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.gray700.withValues(alpha: 0.5)
                                : AppTheme.gray200,
                          ),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Role selection
                            Text(
                              'Select Your Role',
                              style: AppTheme.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.gray900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose the role that best describes you',
                              style: AppTheme.caption.copyWith(
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray500,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space12),
                            Row(
                              children: UserRole.values.map((role) {
                                final isSelected = _selectedRole == role;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedRole = role),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: EdgeInsets.only(
                                        right: role != UserRole.teacher ? 8 : 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                                .withOpacity(isDark ? 0.2 : 0.08)
                                            : isDark
                                                ? AppTheme.darkSurfaceVariant
                                                : AppTheme.gray50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryBlue
                                              : isDark
                                                  ? AppTheme.gray700
                                                  : AppTheme.gray200,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            _roleIcon(role),
                                            size: 24,
                                            color: isSelected
                                                ? AppTheme.primaryBlue
                                                : isDark
                                                    ? AppTheme.gray400
                                                    : AppTheme.gray500,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            role.displayName,
                                            style: AppTheme.caption.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isSelected
                                                  ? AppTheme.primaryBlue
                                                  : isDark
                                                      ? AppTheme.gray300
                                                      : AppTheme.gray600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppTheme.space24),

                            // Full Name
                            _buildTextField(
                              controller: _fullName,
                              hint: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: AppTheme.space12),

                            // Email
                            _buildTextField(
                              controller: _email,
                              hint: 'Email address',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              isDark: isDark,
                            ),
                            const SizedBox(height: AppTheme.space12),

                            // Password
                            _buildTextField(
                              controller: _password,
                              hint: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              isDark: isDark,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: isDark
                                      ? AppTheme.gray400
                                      : AppTheme.gray500,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space12),

                            // Confirm Password
                            _buildTextField(
                              controller: _confirmPassword,
                              hint: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              isDark: isDark,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: isDark
                                      ? AppTheme.gray400
                                      : AppTheme.gray500,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space24),

                            // Register button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: AppTheme.button.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.space24),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTheme.bodySmall.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Sign In',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      style: AppTheme.bodyMedium.copyWith(
        color: isDark ? Colors.white : AppTheme.gray900,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.bodyMedium.copyWith(
          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
        ),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.gray50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryBlue,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
