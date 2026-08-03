import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/portfolio_validators.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v8.4 — Projects Manager.
///
/// List + add/edit form + delete for portfolio projects.
class ProjectsManagerScreen extends StatelessWidget {
  const ProjectsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Projects',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppTheme.primaryBlue,
            tooltip: 'Add Project',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, portfolioProvider, child) {
          final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
          final projects = portfolio.projects;

          if (projects.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return RefreshIndicator(
            onRefresh: () => portfolioProvider.refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: projects.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.space12),
              itemBuilder: (context, index) {
                final project = projects[index];
                return _buildProjectCard(context, project, portfolioProvider, isDark);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.gray400),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No projects yet',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Add projects to showcase your work.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            ElevatedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Project'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    ProjectModel project,
    PortfolioProvider portfolioProvider,
    bool isDark,
  ) {
    final technologies = project.technologies;

    return PortfolioSectionCard(
      title: project.title.isEmpty ? 'Untitled Project' : project.title,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
        onSelected: (value) {
          if (value == 'edit') {
            _openForm(context, project: project);
          } else if (value == 'delete') {
            _confirmDelete(context, portfolioProvider, project);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (project.description.isNotEmpty) ...[
            Text(
              project.description,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          if (technologies.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: technologies
                  .map(
                    (tech) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        tech,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          if (project.startDate != null || project.currentlyWorking || project.endDate != null)
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDuration(project),
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ),
                if (project.currentlyWorking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Ongoing',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          if (project.githubUrl != null || project.demoUrl != null) ...[
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                if (project.githubUrl != null)
                  _linkChip(context, 'GitHub', project.githubUrl!, Icons.code, AppTheme.gray700, isDark),
                if (project.githubUrl != null && project.demoUrl != null)
                  const SizedBox(width: AppTheme.space8),
                if (project.demoUrl != null)
                  _linkChip(context, 'Demo', project.demoUrl!, Icons.open_in_new, AppTheme.primaryBlue, isDark),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _linkChip(
    BuildContext context,
    String label,
    String url,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  String _formatDuration(ProjectModel project) {
    final start = project.startDate;
    if (start == null) {
      return project.currentlyWorking ? 'Ongoing' : '—';
    }
    final startStr = DateFormat('MMM yyyy').format(start);
    if (project.currentlyWorking) return '$startStr — Present';
    final end = project.endDate;
    if (end == null) return startStr;
    // F10: defensively guard against stored inverted ranges from legacy data.
    if (end.isBefore(start)) return startStr;
    return '$startStr — ${DateFormat('MMM yyyy').format(end)}';
  }

  void _openForm(BuildContext context, {ProjectModel? project}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProjectFormScreen(project: project),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    ProjectModel project,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final updated = portfolio.copyWith(
      projects: portfolio.projects.where((p) => p.id != project.id).toList(),
    );
    final success = await portfolioProvider.savePortfolio(updated);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Project deleted.' : 'Failed to delete project.'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

/// Full-screen add/edit form for a single project.
class _ProjectFormScreen extends StatefulWidget {
  final ProjectModel? project;

  const _ProjectFormScreen({this.project});

  @override
  State<_ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<_ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _techController;
  late final TextEditingController _githubController;
  late final TextEditingController _demoController;
  final _techChips = <String>[];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _currentlyWorking = false;
  bool _isSaving = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _titleController = TextEditingController(text: project?.title ?? '');
    _descriptionController = TextEditingController(text: project?.description ?? '');
    _techController = TextEditingController();
    _githubController = TextEditingController(text: project?.githubUrl ?? '');
    _demoController = TextEditingController(text: project?.demoUrl ?? '');
    if (project != null) {
      _techChips.addAll(project.technologies);
      _startDate = project.startDate;
      _endDate = project.endDate;
      _currentlyWorking = project.currentlyWorking;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _techController.dispose();
    _githubController.dispose();
    _demoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Project' : 'Add Project',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortfolioSectionCard(
                title: 'Project Details',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g. CampusConnect',
                      isDark: isDark,
                      validator: (value) => PortfolioValidators.required(value, 'Title'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'What did you build and what problem does it solve?',
                      isDark: isDark,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space20),
              _buildTechnologiesSection(isDark),
              const SizedBox(height: AppTheme.space20),
              _buildDatesSection(isDark),
              const SizedBox(height: AppTheme.space20),
              PortfolioSectionCard(
                title: 'Links',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _githubController,
                      label: 'GitHub URL',
                      hint: 'https://github.com/…',
                      isDark: isDark,
                      keyboardType: TextInputType.url,
                      validator: (value) => PortfolioValidators.optionalUrl(value),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _demoController,
                      label: 'Demo URL',
                      hint: 'https://…',
                      isDark: isDark,
                      keyboardType: TextInputType.url,
                      validator: (value) => PortfolioValidators.optionalUrl(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechnologiesSection(bool isDark) {
    return PortfolioSectionCard(
      title: 'Technologies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_techChips.isNotEmpty) ...[
            Wrap(
              spacing: AppTheme.space6,
              runSpacing: AppTheme.space6,
              children: _techChips.map((tech) {
                return Chip(
                  label: Text(tech),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _techChips.remove(tech)),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _techController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Flutter, Firebase, Dart',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.space14, vertical: AppTheme.space12),
                  ),
                  style: AppTheme.bodyMedium.copyWith(color: isDark ? Colors.white : AppTheme.gray900),
                  onFieldSubmitted: (value) => _addTech(value),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              ElevatedButton(
                onPressed: () => _addTech(_techController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: AppTheme.space12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addTech(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_techChips.any((t) => t.toLowerCase() == trimmed.toLowerCase())) return;
    setState(() => _techChips.add(trimmed));
    _techController.clear();
  }

  Widget _buildDatesSection(bool isDark) {
    return PortfolioSectionCard(
      title: 'Duration',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _datePickerField(
                  isDark,
                  label: 'Start Date',
                  date: _startDate,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: _datePickerField(
                  isDark,
                  label: 'End Date',
                  date: _currentlyWorking ? null : _endDate,
                  onTap: _currentlyWorking ? null : () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Checkbox(
                value: _currentlyWorking,
                onChanged: (value) => setState(() {
                  _currentlyWorking = value ?? false;
                  if (_currentlyWorking) _endDate = null;
                }),
              ),
              const SizedBox(width: AppTheme.space4),
              Text(
                'I am currently working on this project',
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePickerField(
    bool isDark, {
    required String label,
    required DateTime? date,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
          ),
          filled: true,
          fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
        ),
        child: Text(
          date != null ? DateFormat('MMM yyyy').format(date) : '—',
          style: AppTheme.bodyMedium.copyWith(
            color: date != null ? (isDark ? Colors.white : AppTheme.gray900) : (isDark ? AppTheme.gray400 : AppTheme.gray500),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = isStart ? DateTime(now.year - 10) : (_startDate ?? DateTime(now.year - 10));
    final lastDate = isStart ? now : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now.subtract(const Duration(days: 30))) : (_endDate ?? now),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isStart ? 'Select start date' : 'Select end date',
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_techChips.isEmpty) {
      _showSnack('Add at least one technology.');
      return;
    }

    setState(() => _isSaving = true);
    final portfolioProvider = context.read<PortfolioProvider>();
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final existing = widget.project;

    final model = ProjectModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      technologies: List.from(_techChips),
      githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
      demoUrl: _demoController.text.trim().isNotEmpty ? _demoController.text.trim() : null,
      startDate: _startDate,
      endDate: _currentlyWorking ? null : _endDate,
      currentlyWorking: _currentlyWorking,
    );

    final projects = List<ProjectModel>.from(portfolio.projects);
    if (existing != null) {
      final index = projects.indexWhere((p) => p.id == existing.id);
      if (index >= 0) {
        projects[index] = model;
      } else {
        projects.add(model);
      }
    } else {
      projects.add(model);
    }

    final updated = portfolio.copyWith(projects: projects);
    final success = await portfolioProvider.savePortfolio(updated);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (success) {
      _showSnack(_isEdit ? 'Project updated.' : 'Project added.');
      Navigator.pop(context);
    } else {
      _showSnack('Failed to save project. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.gray800),
    );
  }
}
