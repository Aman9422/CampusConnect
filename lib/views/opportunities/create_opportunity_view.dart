import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CreateOpportunityView - v7.2: Multi-role ecosystem
///
/// Form for alumni to create and edit job opportunities.
/// Includes validation, skill tagging, and deadline management.
class CreateOpportunityView extends StatefulWidget {
  const CreateOpportunityView({super.key});

  @override
  State<CreateOpportunityView> createState() => _CreateOpportunityViewState();
}

class _CreateOpportunityViewState extends State<CreateOpportunityView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryRangeController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _skillsController = TextEditingController();

  Opportunity? _existingOpportunity;
  String _selectedJobType = 'Full-time';
  List<String> _selectedSkills = [];
  List<String> _requirements = [];
  DateTime? _applicationDeadline;
  bool _isSubmitting = false;
  String? _error;

  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Freelance',
    'Remote',
    'Hybrid',
  ];

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
    'Analytics',
    'Customer Success',
  ];

  final List<String> _commonRequirements = [
    'Bachelor\'s degree',
    '2+ years experience',
    'Strong communication skills',
    'Team collaboration',
    'Problem-solving abilities',
    'Self-motivated',
    'Detail-oriented',
    'Leadership experience',
    'Industry knowledge',
    'Technical proficiency',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map<String, dynamic> ? routeArgs : null;
    _existingOpportunity = args?['opportunity'] as Opportunity?;

    if (_existingOpportunity != null) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final opp = _existingOpportunity!;
    _titleController.text = opp.title;
    _companyController.text = opp.company;
    _descriptionController.text = opp.description;
    _locationController.text = opp.location;
    _selectedJobType = opp.jobType;
    _selectedSkills = List.from(opp.skills);
    _requirements = List.from(opp.requirements);
    _applicationDeadline = opp.applicationDeadline;
    _salaryRangeController.text = opp.salaryRange ?? '';
    _applicationUrlController.text = opp.applicationUrl ?? '';
    _contactEmailController.text = opp.contactEmail ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _locationController.dispose();
    _salaryRangeController.dispose();
    _applicationUrlController.dispose();
    _contactEmailController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = _existingOpportunity != null;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Opportunity' : 'Post New Opportunity',
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
              // Basic Information
              _buildSection('Basic Information', [
                _buildTextField(
                  controller: _titleController,
                  label: 'Job Title',
                  hint: 'e.g., Senior Software Engineer, Product Manager',
                  isDark: isDark,
                  validator: (value) => _validateRequired(value, 'Job title'),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _companyController,
                  label: 'Company',
                  hint: 'Company or organization name',
                  isDark: isDark,
                  validator: (value) => _validateRequired(value, 'Company'),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'e.g., San Francisco, CA or Remote',
                  isDark: isDark,
                  validator: (value) => _validateRequired(value, 'Location'),
                ),
                const SizedBox(height: 16),
                _buildJobTypeDropdown(isDark),
              ], isDark),
              const SizedBox(height: 20),

              // Job Description
              _buildSection('Job Description', [
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint:
                      'Describe the role, responsibilities, and what the candidate will be doing...',
                  isDark: isDark,
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a job description';
                    }
                    if (value.trim().length < 100) {
                      return 'Description should be at least 100 characters';
                    }
                    return null;
                  },
                ),
              ], isDark),
              const SizedBox(height: 20),

              // Requirements
              _buildSection('Requirements', [
                _buildRequirementsSection(isDark),
              ], isDark),
              const SizedBox(height: 20),

              // Skills
              _buildSection('Required Skills', [
                _buildSkillsSection(isDark),
              ], isDark),
              const SizedBox(height: 20),

              // Additional Details
              _buildSection('Additional Details', [
                _buildTextField(
                  controller: _salaryRangeController,
                  label: 'Salary Range (Optional)',
                  hint: 'e.g., \$80k - \$120k, Negotiable',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _applicationUrlController,
                  label: 'Application URL (Optional)',
                  hint: 'Link to application form or job posting',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _contactEmailController,
                  label: 'Contact Email (Optional)',
                  hint: 'Email for inquiries',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildDeadlineSelector(isDark),
              ], isDark),
              const SizedBox(height: 24),

              // Submit button
              _buildSubmitButton(isDark, isEditing),

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

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withValues(alpha: 0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
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

  Widget _buildJobTypeDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Type',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedJobType,
          decoration: InputDecoration(
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
            filled: true,
            fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
            contentPadding: const EdgeInsets.all(14),
          ),
          items: _jobTypes.map((String jobType) {
            return DropdownMenuItem<String>(
              value: jobType,
              child: Text(jobType),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedJobType = newValue!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRequirementsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Requirements',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),

        // Current requirements
        if (_requirements.isNotEmpty) ...[
          Column(
            children: _requirements
                .map(
                  (req) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isDark ? Colors.white : AppTheme.gray900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeRequirement(req),
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: AppTheme.error,
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

        // Add requirement input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _requirementsController,
                decoration: InputDecoration(
                  hintText: 'Type a requirement and press Add',
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
                onFieldSubmitted: (value) => _addRequirement(value),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _addRequirement(_requirementsController.text),
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
        const SizedBox(height: 12),

        // Common requirements suggestions
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
          children: _commonRequirements
              .where((req) => !_requirements.contains(req))
              .take(6)
              .map(
                (req) => GestureDetector(
                  onTap: () => _addRequirement(req),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.gray700.withValues(alpha: 0.5)
                          : AppTheme.gray100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                      ),
                    ),
                    child: Text(
                      req,
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

  Widget _buildSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Skills',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),

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
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
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
        const SizedBox(height: 12),

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
                          ? AppTheme.gray700.withValues(alpha: 0.5)
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

  Widget _buildDeadlineSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application Deadline (Optional)',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDeadline,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : AppTheme.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.gray600 : AppTheme.gray300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _applicationDeadline != null
                        ? '${_applicationDeadline!.day}/${_applicationDeadline!.month}/${_applicationDeadline!.year}'
                        : 'Select application deadline',
                    style: AppTheme.bodyMedium.copyWith(
                      color: _applicationDeadline != null
                          ? (isDark ? Colors.white : AppTheme.gray900)
                          : (isDark ? AppTheme.gray400 : AppTheme.gray500),
                    ),
                  ),
                ),
                if (_applicationDeadline != null)
                  GestureDetector(
                    onTap: () => setState(() => _applicationDeadline = null),
                    child: Icon(
                      Icons.clear,
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark, bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitOpportunity,
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
                    isEditing ? 'Updating...' : 'Publishing...',
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
                  Icon(
                    isEditing ? Icons.update_rounded : Icons.publish_rounded,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Update Opportunity' : 'Publish Opportunity',
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
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
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

  // Helper methods
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
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

  void _addRequirement(String requirement) {
    final trimmedReq = requirement.trim();
    if (trimmedReq.isNotEmpty && !_requirements.contains(trimmedReq)) {
      setState(() {
        _requirements.add(trimmedReq);
      });
      _requirementsController.clear();
    }
  }

  void _removeRequirement(String requirement) {
    setState(() {
      _requirements.remove(requirement);
    });
  }

  void _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _applicationDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _applicationDeadline = picked;
      });
    }
  }

  void _submitOpportunity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_requirements.isEmpty) {
      setState(() {
        _error = 'Please add at least one requirement';
      });
      return;
    }

    if (_selectedSkills.isEmpty) {
      setState(() {
        _error = 'Please add at least one required skill';
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
      final provider = context.read<OpportunityProvider>();

      if (_existingOpportunity != null) {
        // Update existing opportunity
        final updatedOpportunity = _existingOpportunity!.copyWith(
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          requirements: _requirements,
          location: _locationController.text.trim(),
          jobType: _selectedJobType,
          skills: _selectedSkills,
          salaryRange: _salaryRangeController.text.trim().isNotEmpty
              ? _salaryRangeController.text.trim()
              : null,
          applicationDeadline: _applicationDeadline,
          applicationUrl: _applicationUrlController.text.trim().isNotEmpty
              ? _applicationUrlController.text.trim()
              : null,
          contactEmail: _contactEmailController.text.trim().isNotEmpty
              ? _contactEmailController.text.trim()
              : null,
        );

        await provider.updateOpportunity(updatedOpportunity);
      } else {
        // Create new opportunity
        await provider.createOpportunity(
          alumniId: currentUser.uid,
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          requirements: _requirements,
          location: _locationController.text.trim(),
          jobType: _selectedJobType,
          skills: _selectedSkills,
          alumniProfile: currentUser,
          salaryRange: _salaryRangeController.text.trim().isNotEmpty
              ? _salaryRangeController.text.trim()
              : null,
          applicationDeadline: _applicationDeadline,
          applicationUrl: _applicationUrlController.text.trim().isNotEmpty
              ? _applicationUrlController.text.trim()
              : null,
          contactEmail: _contactEmailController.text.trim().isNotEmpty
              ? _contactEmailController.text.trim()
              : null,
        );
      }

      // Success - show snackbar and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingOpportunity != null
                  ? 'Opportunity updated successfully!'
                  : 'Opportunity published successfully!',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = _existingOpportunity != null
            ? 'Failed to update opportunity. Please try again.'
            : 'Failed to publish opportunity. Please try again.';
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
