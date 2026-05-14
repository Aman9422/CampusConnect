import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CreateMentorshipRequestView - v7.2: Multi-role ecosystem
///
/// Form for students to create mentorship requests to alumni.
/// Includes validation, skill selection, and proper error handling.
class CreateMentorshipRequestView extends StatefulWidget {
  const CreateMentorshipRequestView({super.key});

  @override
  State<CreateMentorshipRequestView> createState() =>
      _CreateMentorshipRequestViewState();
}

class _CreateMentorshipRequestViewState
    extends State<CreateMentorshipRequestView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skillsController = TextEditingController();

  StudentProfile? _alumniProfile;
  final List<String> _selectedSkills = [];
  bool _isSubmitting = false;
  String? _error;

  // Pre-defined skills for quick selection
  final List<String> _commonSkills = [
    'Software Development',
    'Data Science',
    'Product Management',
    'Marketing',
    'Finance',
    'Business Strategy',
    'Leadership',
    'Communication',
    'Project Management',
    'Entrepreneurship',
    'Research',
    'Design',
    'Sales',
    'Consulting',
    'Analytics',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map<String, dynamic> ? routeArgs : null;
    _alumniProfile = args?['alumniProfile'] as StudentProfile?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_alumniProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Mentorship')),
        body: const Center(child: Text('Alumni profile not found')),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Request Mentorship',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alumni info card
              _buildAlumniInfoCard(_alumniProfile!, isDark),
              const SizedBox(height: 24),

              // Request form
              _buildRequestForm(isDark),
              const SizedBox(height: 24),

              // Submit button
              _buildSubmitButton(isDark),

              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorWidget(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlumniInfoCard(StudentProfile alumni, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: alumni.personal.effectiveDisplayName, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumni.personal.effectiveDisplayName,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                if (alumni.jobRole != null || alumni.company != null)
                  Text(
                    '${alumni.jobRole ?? "Professional"} at ${alumni.company ?? "Company"}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                    ),
                  ),
                if (alumni.department != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    alumni.department!,
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mentorship Request Details',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 20),

          // Title field
          _buildTextField(
            controller: _titleController,
            label: 'Request Title',
            hint: 'Brief title for your mentorship request',
            isDark: isDark,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title for your request';
              }
              if (value.trim().length < 10) {
                return 'Title should be at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description field
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint:
                'Describe what you hope to learn and why you want this mentorship...',
            isDark: isDark,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe your mentorship goals';
              }
              if (value.trim().length < 50) {
                return 'Description should be at least 50 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Skills section
          _buildSkillsSection(isDark),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.gray600 : AppTheme.gray300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.gray600 : AppTheme.gray300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.error, width: 1),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
            contentPadding: const EdgeInsets.all(14),
          ),
          style: AppTheme.bodyMedium.copyWith(
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skills You Want to Learn',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select or add skills you want to develop through this mentorship.',
          style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
        ),
        const SizedBox(height: 12),

        // Selected skills
        if (_selectedSkills.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedSkills
                .map(
                  (skill) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          skill,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeSkill(skill),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Add skill input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _skillsController,
                decoration: InputDecoration(
                  hintText: 'Type a skill and press Add',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                style: AppTheme.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
                onFieldSubmitted: (value) => _addSkill(value),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _addSkill(_skillsController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Common skills suggestions
        Text(
          'Quick Add:',
          style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _commonSkills
              .where((skill) => !_selectedSkills.contains(skill))
              .take(8)
              .map(
                (skill) => GestureDetector(
                  onTap: () => _addSkill(skill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.gray700.withOpacity(0.5)
                          : AppTheme.gray100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                      ),
                    ),
                    child: Text(
                      skill,
                      style: AppTheme.caption.copyWith(
                        color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sending Request...',
                    style: AppTheme.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded),
                  const SizedBox(width: 8),
                  Text(
                    'Send Mentorship Request',
                    style: AppTheme.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _addSkill(String skill) {
    final trimmedSkill = skill.trim();
    if (trimmedSkill.isNotEmpty && !_selectedSkills.contains(trimmedSkill)) {
      setState(() {
        _selectedSkills.add(trimmedSkill);
      });
      _skillsController.clear();
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSkills.isEmpty) {
      setState(() {
        _error = 'Please select at least one skill you want to learn';
      });
      return;
    }

    final currentUser = context.read<ProfileProvider>().profile;
    if (currentUser == null) {
      setState(() {
        _error = 'User profile not found. Please try logging in again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final profileProvider = context.read<ProfileProvider>();
      final currentProfile = profileProvider.profile!;

      await context.read<MentorshipProvider>().createRequest(
        studentId: currentProfile.uid,
        alumniId: _alumniProfile!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        skills: _selectedSkills,
        studentProfile: currentProfile,
        alumniProfile: _alumniProfile!,
      );

      // Success - show snackbar and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mentorship request sent successfully!'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to send request. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
