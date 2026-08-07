import 'package:campusconnect/models/portfolio/achievement_model.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/portfolio_validators.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CampusConnect v8.4 — Achievements Manager.
///
/// List + add/edit form + delete for portfolio achievements.
class AchievementsManagerScreen extends StatelessWidget {
  const AchievementsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Achievements',
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
            tooltip: 'Add Achievement',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, portfolioProvider, child) {
          final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
          final achievements = portfolio.achievements;

          if (achievements.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return RefreshIndicator(
            onRefresh: () => portfolioProvider.refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: achievements.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.space12),
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return _buildAchievementCard(
                  context,
                  achievement,
                  portfolioProvider,
                  isDark,
                );
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
            Icon(Icons.emoji_events_outlined, size: 48, color: AppTheme.gray400),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No achievements yet',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Add academic, sports or technical achievements.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            ElevatedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Achievement'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    AchievementModel achievement,
    PortfolioProvider portfolioProvider,
    bool isDark,
  ) {
    return PortfolioSectionCard(
      title: achievement.title.isEmpty ? 'Untitled Achievement' : achievement.title,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
        onSelected: (value) {
          if (value == 'edit') {
            _openForm(context, achievement: achievement);
          } else if (value == 'delete') {
            _confirmDelete(context, portfolioProvider, achievement);
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  achievement.category,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.secondaryIndigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (achievement.date != null)
                Text(
                  DateFormat('MMM yyyy').format(achievement.date!),
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
            ],
          ),
          if (achievement.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              achievement.description,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {AchievementModel? achievement}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AchievementFormScreen(achievement: achievement),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    AchievementModel achievement,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Achievement'),
        content: Text('Are you sure you want to delete "${achievement.title}"?'),
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
      achievements: portfolio.achievements.where((a) => a.id != achievement.id).toList(),
    );
    final success = await portfolioProvider.savePortfolio(updated);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Achievement deleted.' : 'Failed to delete achievement.'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

/// Full-screen add/edit form for a single achievement.
class _AchievementFormScreen extends StatefulWidget {
  final AchievementModel? achievement;

  const _AchievementFormScreen({this.achievement});

  @override
  State<_AchievementFormScreen> createState() => _AchievementFormScreenState();
}

class _AchievementFormScreenState extends State<_AchievementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String _category = 'Academic';
  DateTime? _date;
  bool _isSaving = false;

  bool get _isEdit => widget.achievement != null;

  @override
  void initState() {
    super.initState();
    final achievement = widget.achievement;
    _titleController = TextEditingController(text: achievement?.title ?? '');
    _descriptionController = TextEditingController(text: achievement?.description ?? '');
    if (achievement != null) {
      _category = achievement.category;
      _date = achievement.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
          _isEdit ? 'Edit Achievement' : 'Add Achievement',
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
                title: 'Achievement Details',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g. Winner — Smart India Hackathon 2025',
                      isDark: isDark,
                      validator: (value) => PortfolioValidators.required(value, 'Title'),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'What did you achieve and why does it matter?',
                      isDark: isDark,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 1000,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space20),
              PortfolioSectionCard(
                title: 'Category & Date',
                child: Column(
                  children: [
                    _buildCategoryField(isDark),
                    const SizedBox(height: AppTheme.space16),
                    _buildDateField(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        DropdownButtonFormField<String>(
          value: _category,
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
          items: AchievementModel.suggestionCategories
              .map((category) => DropdownMenuItem(value: category, child: Text(category)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
      ],
    );
  }

  Widget _buildDateField(bool isDark) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
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
          _date != null ? DateFormat('MMM d, yyyy').format(_date!) : 'Select date',
          style: AppTheme.bodyMedium.copyWith(
            color: _date != null
                ? (isDark ? Colors.white : AppTheme.gray900)
                : (isDark ? AppTheme.gray400 : AppTheme.gray500),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Select achievement date',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final portfolioProvider = context.read<PortfolioProvider>();
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final existing = widget.achievement;

    final model = AchievementModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _date,
      category: _category,
    );

    final achievements = List<AchievementModel>.from(portfolio.achievements);
    if (existing != null) {
      final index = achievements.indexWhere((a) => a.id == existing.id);
      if (index >= 0) {
        achievements[index] = model;
      } else {
        achievements.add(model);
      }
    } else {
      achievements.add(model);
    }

    final updated = portfolio.copyWith(achievements: achievements);
    final success = await portfolioProvider.savePortfolio(updated);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Achievement saved.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save achievement. Please try again.')),
      );
    }
  }
}
