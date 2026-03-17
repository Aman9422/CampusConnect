import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// v7.1: Role-aware profile setup with dynamic fields
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key});

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  final _formKey = GlobalKey<FormState>();

  // Common fields
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _collegeController;
  late TextEditingController _programController;
  late TextEditingController _cgpaController;
  int _selectedYear = 1;
  String _userEmail = '';

  // v7.1: Student-specific
  late TextEditingController _departmentController;
  late TextEditingController _graduationYearController;
  late TextEditingController _skillsController;
  late TextEditingController _careerInterestController;

  // v7.1: Alumni-specific
  late TextEditingController _companyController;
  late TextEditingController _jobRoleController;
  late TextEditingController _linkedinController;

  // v7.1: Teacher-specific
  late TextEditingController _designationController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;

    _fullNameController = TextEditingController(
      text: profile?.personal.fullName ?? '',
    );
    _phoneController = TextEditingController(
      text: profile?.personal.phone ?? '',
    );
    _collegeController = TextEditingController(
      text: profile?.academic.college ?? '',
    );
    _programController = TextEditingController(
      text: profile?.academic.program ?? '',
    );
    _cgpaController = TextEditingController(
      text: (profile?.academic.cgpa == 0.0 || profile?.academic.cgpa == null)
          ? ''
          : profile!.academic.cgpa.toString(),
    );
    _selectedYear =
        (profile?.academic.year ?? 0) == 0 ? 1 : profile!.academic.year;
    _userEmail = profile?.personal.email ?? '';

    // v7.1 fields
    _departmentController = TextEditingController(
      text: profile?.department ?? '',
    );
    _graduationYearController = TextEditingController(
      text: profile?.graduationYear?.toString() ?? '',
    );
    _skillsController = TextEditingController(
      text: profile?.skills?.join(', ') ?? '',
    );
    _careerInterestController = TextEditingController(
      text: profile?.careerInterest ?? '',
    );
    _companyController = TextEditingController(text: profile?.company ?? '');
    _jobRoleController = TextEditingController(text: profile?.jobRole ?? '');
    _linkedinController = TextEditingController(
      text: profile?.linkedinProfile ?? '',
    );
    _designationController = TextEditingController(
      text: profile?.designation ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _cgpaController.dispose();
    _departmentController.dispose();
    _graduationYearController.dispose();
    _skillsController.dispose();
    _careerInterestController.dispose();
    _companyController.dispose();
    _jobRoleController.dispose();
    _linkedinController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final roleProvider = context.read<RoleProvider>();
      final currentProfile = profileProvider.profile;

      if (currentProfile == null) throw Exception('Profile not loaded');

      final role = roleProvider.role;

      // Parse skills
      final skillsList = _skillsController.text.trim().isEmpty
          ? <String>[]
          : _skillsController.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

      // Build updated profile with role-specific fields
      final updatedProfile = currentProfile.copyWith(
        personal: currentProfile.personal.copyWith(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
        academic: currentProfile.academic.copyWith(
          college: _collegeController.text.trim(),
          program: _programController.text.trim(),
          year: _selectedYear,
          cgpa: double.tryParse(_cgpaController.text.trim()) ?? 0.0,
        ),
        role: role,
        department: _departmentController.text.trim().isNotEmpty
            ? _departmentController.text.trim()
            : null,
        graduationYear: _graduationYearController.text.trim().isNotEmpty
            ? int.tryParse(_graduationYearController.text.trim())
            : null,
        skills: skillsList.isNotEmpty ? skillsList : null,
        careerInterest: _careerInterestController.text.trim().isNotEmpty
            ? _careerInterestController.text.trim()
            : null,
        company: _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : null,
        jobRole: _jobRoleController.text.trim().isNotEmpty
            ? _jobRoleController.text.trim()
            : null,
        linkedinProfile: _linkedinController.text.trim().isNotEmpty
            ? _linkedinController.text.trim()
            : null,
        designation: _designationController.text.trim().isNotEmpty
            ? _designationController.text.trim()
            : null,
      );

      final success = await profileProvider.updateProfile(updatedProfile);
      if (!success) throw Exception('Failed to save profile');

      await ProfileService.instance().markProfileCompleted(currentProfile.uid);
      await profileProvider.refresh();

      if (!mounted) return;
      setState(() => _isSaving = false);
      // Consumer2 in AuthGuard will auto-rebuild after profileProvider.refresh()
      // Just pop back so AuthGuard's StreamBuilder handles routing
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = context.watch<RoleProvider>().role;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Complete Your Profile',
                  style: AppTheme.titleLarge.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role != null
                      ? 'Set up your ${role.displayName.toLowerCase()} profile'
                      : 'Fill in your details to get started',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),

                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Required to access all features',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space32),

                // Form card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.gray700.withOpacity(0.5)
                          : AppTheme.gray200,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Personal Information', isDark),
                      const SizedBox(height: AppTheme.space16),

                      // Full Name
                      _buildFormField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        required: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.space16),

                      // Email (display only)
                      _buildReadOnlyField(
                        label: 'Email',
                        value: _userEmail.isNotEmpty
                            ? _userEmail
                            : 'Email from account',
                        icon: Icons.mail_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppTheme.space16),

                      // Phone
                      _buildFormField(
                        controller: _phoneController,
                        label: 'Phone',
                        hint: 'Enter phone number',
                        icon: Icons.phone_outlined,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: AppTheme.space32),
                      _sectionLabel('Academic Details', isDark),
                      const SizedBox(height: AppTheme.space16),

                      // College
                      _buildFormField(
                        controller: _collegeController,
                        label: 'College / Institution',
                        hint: 'Enter college name',
                        icon: Icons.account_balance_outlined,
                        isDark: isDark,
                        required: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your college name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.space16),

                      // Program
                      _buildFormField(
                        controller: _programController,
                        label: 'Program / Branch',
                        hint: 'e.g., Computer Science',
                        icon: Icons.menu_book_rounded,
                        isDark: isDark,
                        required: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your program';
                          }
                          return null;
                        },
                      ),

                      // Year & CGPA only for students
                      if (role == null || role == UserRole.student) ...[
                        const SizedBox(height: AppTheme.space16),
                        _buildDropdown(isDark),
                        const SizedBox(height: AppTheme.space16),
                        _buildFormField(
                          controller: _cgpaController,
                          label: 'CGPA',
                          hint: 'e.g., 8.5',
                          icon: Icons.grade_outlined,
                          isDark: isDark,
                          required: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your CGPA';
                            }
                            final cgpa = double.tryParse(v.trim());
                            if (cgpa == null) return 'Enter a valid number';
                            if (cgpa < 0 || cgpa > 10) {
                              return 'CGPA must be 0-10';
                            }
                            return null;
                          },
                        ),
                      ],

                      // Role-specific fields
                      if (role != null) ...[
                        const SizedBox(height: AppTheme.space32),
                        _sectionLabel(
                          '${role.displayName} Details',
                          isDark,
                        ),
                        const SizedBox(height: AppTheme.space16),
                        ..._buildRoleFields(role, isDark),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Complete Setup',
                            style: AppTheme.button.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRoleFields(UserRole role, bool isDark) {
    switch (role) {
      case UserRole.student:
        return [
          _buildFormField(
            controller: _departmentController,
            label: 'Department',
            hint: 'e.g., CSE, ECE, ME',
            icon: Icons.domain_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _graduationYearController,
            label: 'Graduation Year',
            hint: 'e.g., 2026',
            icon: Icons.calendar_today_outlined,
            isDark: isDark,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _skillsController,
            label: 'Skills (optional)',
            hint: 'Flutter, Python, ML (comma separated)',
            icon: Icons.code_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _careerInterestController,
            label: 'Career Interest (optional)',
            hint: 'e.g., Software Development',
            icon: Icons.trending_up_rounded,
            isDark: isDark,
          ),
        ];
      case UserRole.alumni:
        return [
          _buildFormField(
            controller: _companyController,
            label: 'Company',
            hint: 'Current company name',
            icon: Icons.business_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _jobRoleController,
            label: 'Job Role',
            hint: 'e.g., Software Engineer',
            icon: Icons.work_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _graduationYearController,
            label: 'Graduation Year',
            hint: 'e.g., 2023',
            icon: Icons.calendar_today_outlined,
            isDark: isDark,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _linkedinController,
            label: 'LinkedIn (optional)',
            hint: 'linkedin.com/in/your-profile',
            icon: Icons.link_rounded,
            isDark: isDark,
            keyboardType: TextInputType.url,
          ),
        ];
      case UserRole.teacher:
        return [
          _buildFormField(
            controller: _departmentController,
            label: 'Department',
            hint: 'e.g., Computer Science',
            icon: Icons.domain_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          _buildFormField(
            controller: _designationController,
            label: 'Designation',
            hint: 'e.g., Associate Professor',
            icon: Icons.badge_outlined,
            isDark: isDark,
          ),
        ];
    }
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.gray300 : AppTheme.gray600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTheme.bodyMedium.copyWith(
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          validator: validator,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.gray300 : AppTheme.gray600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray800 : AppTheme.gray100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                size: 14,
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Year *',
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.gray300 : AppTheme.gray600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: _selectedYear,
          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
          style: AppTheme.bodyMedium.copyWith(
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
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
          items: [1, 2, 3, 4]
              .map(
                (year) => DropdownMenuItem(
                  value: year,
                  child: Text(
                    'Year $year',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedYear = value);
          },
        ),
      ],
    );
  }
}
