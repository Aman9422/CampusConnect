import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _collegeController;
  late TextEditingController _programController;
  late TextEditingController _cgpaController;
  int _selectedYear = 1;

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
    _selectedYear = (profile?.academic.year ?? 0) == 0
        ? 1
        : profile!.academic.year;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _programController.dispose();
    _cgpaController.dispose();
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.profile;

    if (currentProfile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile not loaded')));
      return;
    }

    // Create updated profile
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
    );

    // Save to Firestore
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  // Full Name
                  Text(
                    'Full Name',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _fullNameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: _inputDecoration(
                      isDark,
                      'Enter your full name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Phone Number
                  Text(
                    'Phone Number',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: _inputDecoration(
                      isDark,
                      'Enter your phone number',
                    ),
                    // Phone is optional, no validator required
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // College
                  Text(
                    'College',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _collegeController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: _inputDecoration(
                      isDark,
                      'Enter your college name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your college name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Program
                  Text(
                    'Program',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _programController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: _inputDecoration(
                      isDark,
                      'e.g., Computer Science',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your program';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Year
                  Text(
                    'Year',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
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
                                color: isDark ? Colors.white : AppTheme.gray900,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value ?? 1;
                      });
                    },
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // CGPA
                  Text(
                    'CGPA',
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _cgpaController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    decoration: _inputDecoration(isDark, 'e.g., 8.5'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your CGPA';
                      }
                      final cgpa = double.tryParse(value.trim());
                      if (cgpa == null) {
                        return 'Please enter a valid number';
                      }
                      if (cgpa < 0 || cgpa > 10) {
                        return 'CGPA must be between 0 and 10';
                      }
                      return null;
                    },
                  ),
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
