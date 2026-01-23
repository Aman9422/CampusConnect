import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// First-time profile setup screen (mandatory after login)
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key});

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _collegeController;
  late TextEditingController _programController;
  late TextEditingController _cgpaController;
  int _selectedYear = 1;
  bool _isSaving = false;
  String _userEmail = '';

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
    _userEmail = profile?.personal.email ?? '';
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

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final currentProfile = profileProvider.profile;

      if (currentProfile == null) {
        throw Exception('Profile not loaded');
      }

      // Update profile with required fields
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

      // Save profile
      final success = await profileProvider.updateProfile(updatedProfile);

      if (!success) {
        throw Exception('Failed to save profile');
      }

      // Mark profile as completed
      await ProfileService.instance().markProfileCompleted(currentProfile.uid);

      // Refresh profile to get updated data
      await profileProvider.refresh();

      if (!mounted) return;

      // Navigate to root - AuthGuard will route to NotesView since profile is now complete
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.gray900,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryBlue,
                        size: 24,
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Text(
                          'Please complete your profile to continue using CampusConnect',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.gray800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space32),

                // Full Name
                Text(
                  'Full Name *',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.space20),

                // Email (Display only - from auth)
                Text(
                  'Email',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.gray100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.gray300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        color: AppTheme.gray500,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Text(
                          _userEmail.isNotEmpty
                              ? _userEmail
                              : 'Email from account',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.gray700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.lock_outline,
                        color: AppTheme.gray400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space20),

                // Phone Number
                Text(
                  'Phone Number',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Enter your phone number',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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
                const SizedBox(height: AppTheme.space20),

                // College
                Text(
                  'College *',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _collegeController,
                  decoration: InputDecoration(
                    hintText: 'Enter your college name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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
                  'Program *',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _programController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Computer Science, Mechanical',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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
                  'Year *',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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
                  items: [1, 2, 3, 4]
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text('Year $year'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedYear = value);
                    }
                  },
                ),
                const SizedBox(height: AppTheme.space20),

                // CGPA
                Text(
                  'CGPA *',
                  style: AppTheme.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _cgpaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., 8.5',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: AppTheme.gray300),
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

                // Complete Setup Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.space16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Complete Setup',
                          style: AppTheme.button.copyWith(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
