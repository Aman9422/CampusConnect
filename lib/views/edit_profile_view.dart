import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// EditProfileView — v7.5: Role-aware editing.
///
/// - Students/teachers: edit personal info + academic fields (unchanged).
/// - Alumni: edit personal info + professional fields (company, job role,
///   industry, social links, skills, etc.).
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();

  // Shared controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  // Student-only controllers
  late TextEditingController _collegeController;
  late TextEditingController _programController;
  late TextEditingController _cgpaController;
  int _selectedYear = 1;
  // v8.9.1: recommendation-relevant student fields (career interest feeds the
  // engine's domain signals; department/graduationYear/skills are the other
  // profile fields the recommendation system uses).
  late TextEditingController _careerInterestController;
  late TextEditingController _graduationYearController;

  // Teacher-specific controllers (v8.9 Phase 13.5)
  late TextEditingController _departmentController;
  late TextEditingController _designationController;

  // Alumni-specific controllers
  late TextEditingController _companyController;
  late TextEditingController _jobRoleController;
  late TextEditingController _linkedinController;
  late TextEditingController _industryController;
  late TextEditingController _workLocationController;
  late TextEditingController _githubController;
  late TextEditingController _portfolioController;
  late TextEditingController _websiteController;
  late TextEditingController _leetcodeController;
  late TextEditingController _hackerrankController;
  late TextEditingController _skillsController; // comma-separated
  String _employmentType = 'Full-time';
  String _workMode = 'Remote';

  static const _employmentTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Self-employed',
  ];
  static const _workModes = ['Remote', 'Hybrid', 'On-site'];

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
    _bioController = TextEditingController(text: profile?.personal.bio ?? '');

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
    _selectedYear = (profile?.academic.year ?? 0) == 0
        ? 1
        : profile!.academic.year;
    _careerInterestController = TextEditingController(
      text: profile?.careerInterest ?? '',
    );
    _graduationYearController = TextEditingController(
      text: profile?.graduationYear?.toString() ?? '',
    );

    _departmentController = TextEditingController(
      text: profile?.department ?? '',
    );
    _designationController = TextEditingController(
      text: profile?.designation ?? '',
    );

    _companyController = TextEditingController(text: profile?.company ?? '');
    _jobRoleController = TextEditingController(text: profile?.jobRole ?? '');
    _linkedinController = TextEditingController(
      text: profile?.linkedinProfile ?? '',
    );
    _industryController = TextEditingController(text: profile?.industry ?? '');
    _workLocationController = TextEditingController(
      text: profile?.workLocation ?? '',
    );
    _githubController = TextEditingController(text: profile?.githubUrl ?? '');
    _portfolioController = TextEditingController(
      text: profile?.portfolioUrl ?? '',
    );
    _websiteController = TextEditingController(text: profile?.websiteUrl ?? '');
    _leetcodeController = TextEditingController(
      text: profile?.leetcodeUrl ?? '',
    );
    _hackerrankController = TextEditingController(
      text: profile?.hackerrankUrl ?? '',
    );
    _skillsController = TextEditingController(
      text: profile?.skills?.join(', ') ?? '',
    );
    _employmentType = profile?.employmentType ?? 'Full-time';
    _workMode = profile?.workMode ?? 'Remote';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _cgpaController.dispose();
    _careerInterestController.dispose();
    _graduationYearController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _companyController.dispose();
    _jobRoleController.dispose();
    _linkedinController.dispose();
    _industryController.dispose();
    _workLocationController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    _websiteController.dispose();
    _leetcodeController.dispose();
    _hackerrankController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(bool isDark, String? hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? AppTheme.gray500 : AppTheme.gray500),
      filled: true,
      fillColor: isDark ? AppTheme.darkSurface : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(color: AppTheme.error),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: Text(
        title,
        style: AppTheme.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.gray900,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    TextInputType? keyboardType, {
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.label.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray800,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.gray900),
            decoration: _inputDecoration(isDark, hint),
            validator: validator,
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.profile;
    final userRole = context.read<RoleProvider>().userRole;
    final isAlumni = userRole == UserRole.alumni;
    final isTeacher = userRole == UserRole.teacher;

    if (currentProfile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile not loaded')));
      return;
    }

    // Parse skills from comma-separated string
    final skills = _skillsController.text.trim().isNotEmpty
        ? _skillsController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : null;

    final updatedProfile = isTeacher
        ? // v8.9 (Phase 13.5): Teacher-specific edit — personal info +
          // department + designation. No academic/CGPA form and no alumni
          // professional fields. Operates only on the authenticated
          // teacher's own users/{uid} doc (owner-guarded by rules).
          currentProfile.copyWith(
            personal: currentProfile.personal.copyWith(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
              bio: _bioController.text.trim(),
            ),
            department: _departmentController.text.trim().isEmpty
                ? null
                : _departmentController.text.trim(),
            designation: _designationController.text.trim().isEmpty
                ? null
                : _designationController.text.trim(),
          )
        : isAlumni
        ? currentProfile.copyWith(
            personal: currentProfile.personal.copyWith(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
              bio: _bioController.text.trim(),
            ),
            company: _companyController.text.trim().isEmpty
                ? null
                : _companyController.text.trim(),
            jobRole: _jobRoleController.text.trim().isEmpty
                ? null
                : _jobRoleController.text.trim(),
            linkedinProfile: _linkedinController.text.trim().isEmpty
                ? null
                : _linkedinController.text.trim(),
            industry: _industryController.text.trim().isEmpty
                ? null
                : _industryController.text.trim(),
            employmentType: _employmentType,
            workMode: _workMode,
            workLocation: _workLocationController.text.trim().isEmpty
                ? null
                : _workLocationController.text.trim(),
            githubUrl: _githubController.text.trim().isEmpty
                ? null
                : _githubController.text.trim(),
            portfolioUrl: _portfolioController.text.trim().isEmpty
                ? null
                : _portfolioController.text.trim(),
            websiteUrl: _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
            leetcodeUrl: _leetcodeController.text.trim().isEmpty
                ? null
                : _leetcodeController.text.trim(),
            hackerrankUrl: _hackerrankController.text.trim().isEmpty
                ? null
                : _hackerrankController.text.trim(),
            skills: skills,
          )
        : currentProfile.copyWith(
            personal: currentProfile.personal.copyWith(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
              bio: _bioController.text.trim(),
            ),
            academic: currentProfile.academic.copyWith(
              college: _collegeController.text.trim(),
              program: _programController.text.trim(),
              year: _selectedYear,
              cgpa: double.tryParse(_cgpaController.text.trim()) ?? 0.0,
            ),
            // v8.9.1: persist the recommendation-relevant student fields —
            // these feed the engine's domain/career signals.
            department: _departmentController.text.trim().isNotEmpty
                ? _departmentController.text.trim()
                : null,
            graduationYear: _graduationYearController.text.trim().isNotEmpty
                ? int.tryParse(_graduationYearController.text.trim())
                : null,
            skills: skills,
            careerInterest: _careerInterestController.text.trim().isNotEmpty
                ? _careerInterestController.text.trim()
                : null,
          );

    final success = await profileProvider.updateProfile(updatedProfile);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.error ?? 'Failed to update profile'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final userRole = context.watch<RoleProvider>().userRole;
    final isAlumni = userRole == UserRole.alumni;
    final isTeacher = userRole == UserRole.teacher;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Personal Information (all roles) ──
                  _sectionHeader('Personal Information', isDark),
                  _field(
                    'Full Name',
                    _fullNameController,
                    TextInputType.text,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  _field(
                    'Phone Number',
                    _phoneController,
                    TextInputType.phone,
                    hint: 'Optional',
                  ),
                  _field(
                    'Bio',
                    _bioController,
                    TextInputType.text,
                    hint: 'Short bio (optional)',
                  ),

                  if (isTeacher) ...[
                    const SizedBox(height: AppTheme.space8),

                    // ── Teacher Information (v8.9 Phase 13.5) ──
                    _sectionHeader('Teacher Information', isDark),
                    _field(
                      'Department',
                      _departmentController,
                      TextInputType.text,
                      hint: 'e.g., Computer Science',
                    ),
                    _field(
                      'Designation',
                      _designationController,
                      TextInputType.text,
                      hint: 'e.g., Assistant Professor',
                    ),
                  ] else if (isAlumni) ...[
                    const SizedBox(height: AppTheme.space8),

                    // ── Professional Information (alumni only) ──
                    _sectionHeader('Professional Information', isDark),
                    _field(
                      'Company',
                      _companyController,
                      TextInputType.text,
                      hint: 'Current company',
                    ),
                    _field(
                      'Job Title',
                      _jobRoleController,
                      TextInputType.text,
                      hint: 'Current job title',
                    ),

                    // Employment Type dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employment Type',
                          style: AppTheme.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        DropdownButtonFormField<String>(
                          value: _employmentType,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                          decoration: _inputDecoration(isDark, null),
                          items: _employmentTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.gray900,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _employmentType = v ?? 'Full-time',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),

                    // Work Mode dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Mode',
                          style: AppTheme.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        DropdownButtonFormField<String>(
                          value: _workMode,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                          decoration: _inputDecoration(isDark, null),
                          items: _workModes
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.gray900,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _workMode = v ?? 'Remote'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),

                    _field(
                      'Industry',
                      _industryController,
                      TextInputType.text,
                      hint: 'e.g., Software, Finance',
                    ),
                    _field(
                      'Work Location',
                      _workLocationController,
                      TextInputType.text,
                      hint: 'City / Region',
                    ),
                    const SizedBox(height: AppTheme.space8),

                    // ── Skills (alumni) ──
                    _sectionHeader('Skills & Expertise', isDark),
                    _field(
                      'Skills',
                      _skillsController,
                      TextInputType.text,
                      hint: 'Comma-separated, e.g., Flutter, Python, React',
                    ),
                    const SizedBox(height: AppTheme.space8),

                    // ── Social Links (alumni) ──
                    _sectionHeader('Social Links', isDark),
                    _field(
                      'LinkedIn URL',
                      _linkedinController,
                      TextInputType.url,
                      hint: 'https://linkedin.com/in/...',
                    ),
                    _field(
                      'GitHub URL',
                      _githubController,
                      TextInputType.url,
                      hint: 'https://github.com/...',
                    ),
                    _field(
                      'Portfolio URL',
                      _portfolioController,
                      TextInputType.url,
                      hint: 'https://...',
                    ),
                    _field(
                      'Website URL',
                      _websiteController,
                      TextInputType.url,
                      hint: 'https://...',
                    ),
                    _field(
                      'LeetCode URL',
                      _leetcodeController,
                      TextInputType.url,
                      hint: 'https://leetcode.com/...',
                    ),
                    _field(
                      'HackerRank URL',
                      _hackerrankController,
                      TextInputType.url,
                      hint: 'https://hackerrank.com/...',
                    ),
                  ] else ...[
                    const SizedBox(height: AppTheme.space8),

                    // ── Academic Information (student/teacher only) ──
                    _sectionHeader('Academic Information', isDark),
                    _field(
                      'College',
                      _collegeController,
                      TextInputType.text,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your college name';
                        }
                        return null;
                      },
                    ),
                    _field(
                      'Program',
                      _programController,
                      TextInputType.text,
                      hint: 'e.g., Computer Science',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your program';
                        }
                        return null;
                      },
                    ),

                    // Year dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Year',
                          style: AppTheme.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        DropdownButtonFormField<int>(
                          value: _selectedYear,
                          dropdownColor: isDark
                              ? AppTheme.darkSurface
                              : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                          decoration: _inputDecoration(isDark, null),
                          items: [1, 2, 3, 4]
                              .map(
                                (year) => DropdownMenuItem(
                                  value: year,
                                  child: Text(
                                    'Year $year',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.gray900,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedYear = v ?? 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),

                    _field(
                      'CGPA',
                      _cgpaController,
                      const TextInputType.numberWithOptions(decimal: true),
                      hint: 'e.g., 8.5',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your CGPA';
                        }
                        final cgpa = double.tryParse(v.trim());
                        if (cgpa == null) return 'Please enter a valid number';
                        if (cgpa < 0 || cgpa > 10) {
                          return 'CGPA must be between 0 and 10';
                        }
                        return null;
                      },
                    ),

                    // ── Career & Skills (students — v8.9.1) ──
                    // These feed the recommendation engine's domain/career
                    // signals. Career Interest is required at profile setup;
                    // it stays editable here (pre-filled) for correction.
                    _sectionHeader('Career & Skills', isDark),
                    _field(
                      'Career Interest',
                      _careerInterestController,
                      TextInputType.text,
                      hint: 'e.g., Software Development, Data Analysis',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your career interest / target domain';
                        }
                        return null;
                      },
                    ),
                    _field(
                      'Skills',
                      _skillsController,
                      TextInputType.text,
                      hint: 'Comma-separated, e.g., Flutter, Python, React',
                    ),
                    _field(
                      'Department',
                      _departmentController,
                      TextInputType.text,
                      hint: 'e.g., CSE, ECE, ME',
                    ),
                    _field(
                      'Graduation Year',
                      _graduationYearController,
                      TextInputType.number,
                      hint: 'e.g., 2026',
                    ),
                  ],

                  const SizedBox(height: AppTheme.space32),

                  // Save Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: profileProvider.isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        disabledBackgroundColor: AppTheme.primaryBlue
                            .withValues(alpha: 0.5),
                      ),
                      child: profileProvider.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text('Save Profile', style: AppTheme.button),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
