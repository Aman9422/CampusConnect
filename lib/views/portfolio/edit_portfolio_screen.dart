import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/portfolio/career_preferences.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/skill_model.dart';
import 'package:campusconnect/models/portfolio/social_links.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/portfolio_validators.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CampusConnect v8.4 — Edit Portfolio Screen.
///
/// Central editing hub:
/// - Inline skill manager (add/edit/remove skill chips)
/// - Social links (GitHub, LinkedIn, Portfolio, LeetCode, Codeforces, HackerRank)
/// - Career preferences (roles, locations, salary, remote, relocation)
/// - Navigation into the Projects / Certifications / Experience / Achievements
///   managers and the Resume Upload screen.
class EditPortfolioScreen extends StatefulWidget {
  const EditPortfolioScreen({super.key});

  @override
  State<EditPortfolioScreen> createState() => _EditPortfolioScreenState();
}

class _EditPortfolioScreenState extends State<EditPortfolioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _leetcodeController = TextEditingController();
  final _codeforcesController = TextEditingController();
  final _hackerrankController = TextEditingController();
  final _roleController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();

  final _roleChips = <String>[];
  final _locationChips = <String>[];
  String _remotePreference = 'Hybrid';
  String _relocationPreference = 'Open';
  bool _isSaving = false;
  String? _error;
  // H1: Seed the form exactly once. `didChangeDependencies` fires again on
  // any inherited-widget change (theme toggle, provider rebuilds, route
  // changes); without this guard an in-progress, unsaved edit would be
  // silently reset to the last saved portfolio.
  bool _isSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isSeeded) return;
    final portfolio = context.read<PortfolioProvider>().portfolio;
    if (portfolio == null) return; // Not loaded yet — retry on next rebuild.
    _isSeeded = true;
    final links = portfolio.links;
    _githubController.text = links.github ?? '';
    _linkedinController.text = links.linkedin ?? '';
    _portfolioController.text = links.portfolio ?? '';
    _leetcodeController.text = links.leetcode ?? '';
    _codeforcesController.text = links.codeforces ?? '';
    _hackerrankController.text = links.hackerrank ?? '';
    _roleChips
      ..clear()
      ..addAll(portfolio.preferences.preferredRoles);
    _locationChips
      ..clear()
      ..addAll(portfolio.preferences.preferredLocations);
    _salaryController.text = portfolio.preferences.expectedSalary ?? '';
    _remotePreference = portfolio.preferences.remotePreference;
    _relocationPreference = portfolio.preferences.relocationPreference;
  }

  @override
  void dispose() {
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _leetcodeController.dispose();
    _codeforcesController.dispose();
    _hackerrankController.dispose();
    _roleController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit Portfolio',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Form(
          key: _formKey,
          child: Consumer<PortfolioProvider>(
            builder: (context, portfolioProvider, child) {
              final portfolio =
                  portfolioProvider.portfolio ?? PortfolioModel.empty();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manager navigation tiles
                  _buildManagerTile(
                    context,
                    isDark,
                    icon: Icons.folder_special_outlined,
                    title: 'Projects',
                    subtitle:
                        '${portfolio.projects.length} project${portfolio.projects.length == 1 ? '' : 's'} added',
                    color: AppTheme.primaryBlue,
                    route: projectsManagerRoute,
                  ),
                  _buildManagerTile(
                    context,
                    isDark,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Certifications',
                    subtitle:
                        '${portfolio.certifications.length} certification${portfolio.certifications.length == 1 ? '' : 's'} added',
                    color: AppTheme.success,
                    route: certificationsManagerRoute,
                  ),
                  _buildManagerTile(
                    context,
                    isDark,
                    icon: Icons.work_history_outlined,
                    title: 'Experience',
                    subtitle:
                        '${portfolio.experience.length} experience entr${portfolio.experience.length == 1 ? 'y' : 'ies'} added',
                    color: AppTheme.warning,
                    route: experienceManagerRoute,
                  ),
                  _buildManagerTile(
                    context,
                    isDark,
                    icon: Icons.emoji_events_outlined,
                    title: 'Achievements',
                    subtitle:
                        '${portfolio.achievements.length} achievement${portfolio.achievements.length == 1 ? '' : 's'} added',
                    color: AppTheme.secondaryIndigo,
                    route: achievementsManagerRoute,
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Resume
                  PortfolioSectionCard(
                    title: 'Resume',
                    trailing: IconButton(
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      color: AppTheme.primaryBlue,
                      onPressed: () =>
                          Navigator.pushNamed(context, resumeUploadRoute),
                      tooltip: 'Manage Resume',
                    ),
                    child: Text(
                      portfolio.resume?.hasResume == true
                          ? 'Resume attached · v${portfolio.resume!.version}'
                          : 'No resume uploaded yet',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Skills
                  PortfolioSectionCard(
                    title: 'Skills (${portfolio.skills.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      color: AppTheme.primaryBlue,
                      onPressed: () => _addSkill(context, portfolioProvider),
                      tooltip: 'Add Skill',
                    ),
                    child: portfolio.skills.isEmpty
                        ? Text(
                            'Add skills with category and proficiency level.',
                            style: AppTheme.bodySmall.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray600,
                            ),
                          )
                        : Wrap(
                            spacing: AppTheme.space8,
                            runSpacing: AppTheme.space8,
                            children: portfolio.skills.map((skill) {
                              // M1: tap a skill chip to edit its
                              // category/proficiency (and name).
                              return RawChip(
                                label: Text(skill.name),
                                avatar: const Icon(
                                  Icons.tune,
                                  size: 14,
                                  color: AppTheme.primaryBlue,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    _editSkill(context, portfolioProvider, skill),
                                onDeleted: () => _removeSkill(
                                  context,
                                  portfolioProvider,
                                  skill,
                                ),
                                tooltip: 'Edit skill',
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Social Links
                  PortfolioSectionCard(
                    title: 'Social Links',
                    child: Column(
                      children: [
                        _linkField(_githubController, 'GitHub', isDark),
                        const SizedBox(height: AppTheme.space12),
                        _linkField(_linkedinController, 'LinkedIn', isDark),
                        const SizedBox(height: AppTheme.space12),
                        _linkField(
                          _portfolioController,
                          'Portfolio Website',
                          isDark,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        _linkField(_leetcodeController, 'LeetCode', isDark),
                        const SizedBox(height: AppTheme.space12),
                        _linkField(_codeforcesController, 'Codeforces', isDark),
                        const SizedBox(height: AppTheme.space12),
                        _linkField(_hackerrankController, 'HackerRank', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Career Preferences
                  PortfolioSectionCard(
                    title: 'Career Preferences',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChipInput(
                          isDark,
                          label: 'Preferred Roles',
                          controller: _roleController,
                          chips: _roleChips,
                          hint: 'e.g. Software Engineer',
                          onAdd: _addRole,
                        ),
                        const SizedBox(height: AppTheme.space16),
                        _buildChipInput(
                          isDark,
                          label: 'Preferred Locations',
                          controller: _locationController,
                          chips: _locationChips,
                          hint: 'e.g. Bengaluru',
                          onAdd: _addLocation,
                        ),
                        const SizedBox(height: AppTheme.space16),
                        PortfolioTextField(
                          controller: _salaryController,
                          label: 'Expected Salary',
                          hint: 'e.g. ₹8-12 LPA',
                          isDark: isDark,
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: AppTheme.space16),
                        _buildDropdown(
                          isDark,
                          label: 'Remote Preference',
                          value: _remotePreference,
                          options: CareerPreferences.remoteOptions,
                          onChanged: (v) =>
                              setState(() => _remotePreference = v),
                        ),
                        const SizedBox(height: AppTheme.space16),
                        _buildDropdown(
                          isDark,
                          label: 'Relocation Preference',
                          value: _relocationPreference,
                          options: CareerPreferences.relocationOptions,
                          onChanged: (v) =>
                              setState(() => _relocationPreference = v),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: AppTheme.space16),
                    _buildError(isDark),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Manager tiles
  // ──────────────────────────────────────────────
  Widget _buildManagerTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.space8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Skills
  // ──────────────────────────────────────────────
  Future<void> _addSkill(
    BuildContext context,
    PortfolioProvider portfolioProvider,
  ) async {
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final result = await showDialog<SkillModel>(
      context: context,
      builder: (context) => _SkillDialog(
        existingNames: portfolio.skills.map((s) => s.name).toList(),
      ),
    );
    if (result == null) return;
    final updated = portfolio.copyWith(skills: [...portfolio.skills, result]);
    await portfolioProvider.savePortfolio(updated);
  }

  /// M1: Edit an existing skill (replaces the entry with the dialog result).
  Future<void> _editSkill(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    SkillModel skill,
  ) async {
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final result = await showDialog<SkillModel>(
      context: context,
      builder: (context) => _SkillDialog(
        existingNames: portfolio.skills
            .map((s) => s.name)
            .where((name) => name.toLowerCase() != skill.name.toLowerCase())
            .toList(),
        initialSkill: skill,
      ),
    );
    if (result == null) return;
    final updated = portfolio.copyWith(
      skills: portfolio.skills
          .map((s) => s.name == skill.name ? result : s)
          .toList(),
    );
    await portfolioProvider.savePortfolio(updated);
  }

  void _removeSkill(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    SkillModel skill,
  ) {
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final updated = portfolio.copyWith(
      skills: portfolio.skills.where((s) => s.name != skill.name).toList(),
    );
    portfolioProvider.savePortfolio(updated);
  }

  // ──────────────────────────────────────────────
  // Chips (roles / locations)
  // ──────────────────────────────────────────────
  Widget _buildChipInput(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    required List<String> chips,
    required String hint,
    required void Function(String) onAdd,
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
        const SizedBox(height: AppTheme.space8),
        if (chips.isNotEmpty) ...[
          Wrap(
            spacing: AppTheme.space6,
            runSpacing: AppTheme.space6,
            children: chips.map((chip) {
              return Chip(
                label: Text(chip),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => chips.remove(chip)),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.space8),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
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
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space14,
                    vertical: AppTheme.space12,
                  ),
                ),
                style: AppTheme.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
                onFieldSubmitted: (value) => onAdd(value),
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            ElevatedButton(
              onPressed: () => onAdd(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  void _addRole(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_roleChips.any((r) => r.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    setState(() => _roleChips.add(trimmed));
    _roleController.clear();
  }

  void _addLocation(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_locationChips.any((l) => l.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    setState(() => _locationChips.add(trimmed));
    _locationController.clear();
  }

  // ──────────────────────────────────────────────
  // Fields / dropdowns
  // ──────────────────────────────────────────────
  Widget _linkField(
    TextEditingController controller,
    String label,
    bool isDark,
  ) {
    return PortfolioTextField(
      controller: controller,
      label: '$label URL',
      hint: 'https://…',
      isDark: isDark,
      keyboardType: TextInputType.url,
      validator: (value) => PortfolioValidators.optionalUrl(value),
    );
  }

  Widget _buildDropdown(
    bool isDark, {
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
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
        const SizedBox(height: AppTheme.space8),
        DropdownButtonFormField<String>(
          value: value,
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
            contentPadding: const EdgeInsets.all(AppTheme.space14),
          ),
          items: options
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: AppTheme.space8),
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

  // ──────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final portfolioProvider = context.read<PortfolioProvider>();
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();

    final updated = portfolio.copyWith(
      links: SocialLinks(
        github: _githubController.text.trim().isNotEmpty
            ? _githubController.text.trim()
            : null,
        linkedin: _linkedinController.text.trim().isNotEmpty
            ? _linkedinController.text.trim()
            : null,
        portfolio: _portfolioController.text.trim().isNotEmpty
            ? _portfolioController.text.trim()
            : null,
        leetcode: _leetcodeController.text.trim().isNotEmpty
            ? _leetcodeController.text.trim()
            : null,
        codeforces: _codeforcesController.text.trim().isNotEmpty
            ? _codeforcesController.text.trim()
            : null,
        hackerrank: _hackerrankController.text.trim().isNotEmpty
            ? _hackerrankController.text.trim()
            : null,
      ),
      preferences: CareerPreferences(
        preferredRoles: List.from(_roleChips),
        preferredLocations: List.from(_locationChips),
        expectedSalary: _salaryController.text.trim().isNotEmpty
            ? _salaryController.text.trim()
            : null,
        remotePreference: _remotePreference,
        relocationPreference: _relocationPreference,
      ),
    );

    final success = await portfolioProvider.savePortfolio(updated);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _error = success ? null : 'Failed to save portfolio';
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio saved successfully!')),
      );
      Navigator.pop(context);
    }
  }
}

/// Dialog to add (or edit, when [initialSkill] is provided) a skill with
/// name, category and proficiency.
class _SkillDialog extends StatefulWidget {
  final List<String> existingNames;
  final SkillModel? initialSkill;

  const _SkillDialog({required this.existingNames, this.initialSkill});

  @override
  State<_SkillDialog> createState() => _SkillDialogState();
}

class _SkillDialogState extends State<_SkillDialog> {
  final _nameController = TextEditingController();
  String _category = 'Programming Language';
  String _proficiency = 'Intermediate';
  bool _isValid = false;

  bool get _isEdit => widget.initialSkill != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSkill;
    if (initial != null) {
      _nameController.text = initial.name;
      _category = initial.category;
      _proficiency = initial.proficiency;
    }
    _nameController.addListener(() {
      final valid =
          _nameController.text.trim().isNotEmpty &&
          !widget.existingNames.any(
            (name) =>
                name.toLowerCase() == _nameController.text.trim().toLowerCase(),
          );
      if (valid != _isValid) {
        setState(() => _isValid = valid);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Skill' : 'Add Skill'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Skill Name',
                hintText: 'e.g. Flutter',
                errorText: _nameController.text.isEmpty
                    ? null
                    : widget.existingNames.any(
                        (name) =>
                            name.toLowerCase() ==
                            _nameController.text.trim().toLowerCase(),
                      )
                    ? 'This skill already exists'
                    : null,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: SkillModel.suggestionCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: AppTheme.space16),
            DropdownButtonFormField<String>(
              value: _proficiency,
              decoration: const InputDecoration(labelText: 'Proficiency'),
              items: SkillModel.proficiencyLevels
                  .map(
                    (level) =>
                        DropdownMenuItem(value: level, child: Text(level)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _proficiency = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () {
                  Navigator.pop(
                    context,
                    SkillModel(
                      name: _nameController.text.trim(),
                      category: _category,
                      proficiency: _proficiency,
                    ),
                  );
                }
              : null,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
