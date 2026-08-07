import 'package:campusconnect/models/portfolio/experience_model.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CampusConnect v8.4 — Experience Manager.
///
/// List + add/edit form + delete for portfolio work experience.
class ExperienceManagerScreen extends StatelessWidget {
  const ExperienceManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Experience',
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
            tooltip: 'Add Experience',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, portfolioProvider, child) {
          final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
          final experience = portfolio.experience;

          if (experience.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return RefreshIndicator(
            onRefresh: () => portfolioProvider.refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: experience.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.space12),
              itemBuilder: (context, index) {
                final exp = experience[index];
                return _buildExpCard(context, exp, portfolioProvider, isDark);
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
            Icon(Icons.work_history_outlined, size: 48, color: AppTheme.gray400),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No experience yet',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Add internships and work experience.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            ElevatedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Experience'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpCard(
    BuildContext context,
    ExperienceModel exp,
    PortfolioProvider portfolioProvider,
    bool isDark,
  ) {
    return PortfolioSectionCard(
      title: exp.role.isEmpty ? 'Untitled Role' : exp.role,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
        onSelected: (value) {
          if (value == 'edit') {
            _openForm(context, experience: exp);
          } else if (value == 'delete') {
            _confirmDelete(context, portfolioProvider, exp);
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
          if (exp.company.isNotEmpty)
            Text(
              '${exp.company} · ${exp.employmentType}',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          if (exp.startDate != null || exp.currentlyWorking || exp.endDate != null) ...[
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDuration(exp),
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ),
                if (exp.currentlyWorking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Current',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (exp.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              exp.description,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(ExperienceModel exp) {
    final start = exp.startDate;
    if (start == null) {
      return exp.currentlyWorking ? 'Current' : '—';
    }
    final startStr = DateFormat('MMM yyyy').format(start);
    if (exp.currentlyWorking) return '$startStr — Present';
    final end = exp.endDate;
    if (end == null) return startStr;
    // v8.4.2 (S4a/M3): guard inverted legacy ranges ("Dec 2024 — Aug 2024")
    // — mirrors the F10 guard used by projects manager, preview and
    // read-only views.
    if (end.isBefore(start)) return startStr;
    return '$startStr — ${DateFormat('MMM yyyy').format(end)}';
  }

  void _openForm(BuildContext context, {ExperienceModel? experience}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ExpFormScreen(experience: experience),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    ExperienceModel exp,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Experience'),
        content: Text('Are you sure you want to delete "${exp.role}" at ${exp.company}?'),
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
      experience: portfolio.experience.where((e) => e.id != exp.id).toList(),
    );
    final success = await portfolioProvider.savePortfolio(updated);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Experience deleted.' : 'Failed to delete experience.'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

/// Full-screen add/edit form for a single experience entry.
class _ExpFormScreen extends StatefulWidget {
  final ExperienceModel? experience;

  const _ExpFormScreen({this.experience});

  @override
  State<_ExpFormScreen> createState() => _ExpFormScreenState();
}

class _ExpFormScreenState extends State<_ExpFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roleController;
  late final TextEditingController _companyController;
  late final TextEditingController _descriptionController;
  String _employmentType = 'Internship';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _currentlyWorking = false;
  bool _isSaving = false;

  bool get _isEdit => widget.experience != null;

  static const List<String> _employmentTypes = [
    'Full-time',
    'Part-time',
    'Internship',
    'Contract',
    'Freelance',
  ];

  @override
  void initState() {
    super.initState();
    final exp = widget.experience;
    _roleController = TextEditingController(text: exp?.role ?? '');
    _companyController = TextEditingController(text: exp?.company ?? '');
    _descriptionController = TextEditingController(text: exp?.description ?? '');
    if (exp != null) {
      _employmentType = exp.employmentType;
      _startDate = exp.startDate;
      _endDate = exp.endDate;
      _currentlyWorking = exp.currentlyWorking;
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Experience' : 'Add Experience',
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
                title: 'Role',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _roleController,
                      label: 'Role / Title',
                      hint: 'e.g. Software Development Intern',
                      isDark: isDark,
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Role is required' : null,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _companyController,
                      label: 'Company',
                      hint: 'e.g. Google',
                      isDark: isDark,
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Company is required' : null,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    _buildEmploymentTypeField(isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space20),
              _buildDurationSection(isDark),
              const SizedBox(height: AppTheme.space20),
              PortfolioSectionCard(
                title: 'Description',
                child: PortfolioTextField(
                  controller: _descriptionController,
                  label: 'What did you do?',
                  hint: 'Describe your responsibilities and impact…',
                  isDark: isDark,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 1000,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmploymentTypeField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Employment Type',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        DropdownButtonFormField<String>(
          value: _employmentType,
          decoration: InputDecoration(
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
            contentPadding: const EdgeInsets.all(AppTheme.space14),
          ),
          items: _employmentTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _employmentType = value);
          },
        ),
      ],
    );
  }

  Widget _buildDurationSection(bool isDark) {
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
                'I currently work here',
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

    setState(() => _isSaving = true);
    final portfolioProvider = context.read<PortfolioProvider>();
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final existing = widget.experience;

    final model = ExperienceModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      company: _companyController.text.trim(),
      role: _roleController.text.trim(),
      employmentType: _employmentType,
      description: _descriptionController.text.trim(),
      startDate: _startDate,
      endDate: _currentlyWorking ? null : _endDate,
      currentlyWorking: _currentlyWorking,
    );

    final experience = List<ExperienceModel>.from(portfolio.experience);
    if (existing != null) {
      final index = experience.indexWhere((e) => e.id == existing.id);
      if (index >= 0) {
        experience[index] = model;
      } else {
        experience.add(model);
      }
    } else {
      experience.add(model);
    }

    final updated = portfolio.copyWith(experience: experience);
    final success = await portfolioProvider.savePortfolio(updated);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience saved.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save experience. Please try again.')),
      );
    }
  }
}
