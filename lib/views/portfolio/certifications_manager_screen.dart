import 'package:campusconnect/models/portfolio/certification_model.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/portfolio_validators.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v8.4 — Certifications Manager.
///
/// List + add/edit form + delete for portfolio certifications.
class CertificationsManagerScreen extends StatelessWidget {
  const CertificationsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Certifications',
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
            tooltip: 'Add Certification',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, portfolioProvider, child) {
          final portfolio =
              portfolioProvider.portfolio ?? PortfolioModel.empty();
          final certifications = portfolio.certifications;

          if (certifications.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return RefreshIndicator(
            onRefresh: () => portfolioProvider.refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: certifications.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.space12),
              itemBuilder: (context, index) {
                final cert = certifications[index];
                return _buildCertCard(context, cert, portfolioProvider, isDark);
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
            Icon(
              Icons.workspace_premium_outlined,
              size: 48,
              color: AppTheme.gray400,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No certifications yet',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Add certifications to showcase your credentials.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            ElevatedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Certification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertCard(
    BuildContext context,
    CertificationModel cert,
    PortfolioProvider portfolioProvider,
    bool isDark,
  ) {
    return PortfolioSectionCard(
      title: cert.title.isEmpty ? 'Untitled Certification' : cert.title,
      trailing: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
        ),
        onSelected: (value) {
          if (value == 'edit') {
            _openForm(context, certification: cert);
          } else if (value == 'delete') {
            _confirmDelete(context, portfolioProvider, cert);
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
          if (cert.issuer.isNotEmpty) ...[
            Text(
              cert.issuer,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
          ],
          if (cert.issueDate != null)
            Text(
              DateFormat('MMM yyyy').format(cert.issueDate!),
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          if (cert.credentialId != null && cert.credentialId!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              'Credential ID: ${cert.credentialId}',
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
          if (cert.credentialUrl != null && cert.credentialUrl!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            InkWell(
              onTap: () => _launchUrl(context, cert.credentialUrl!),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verify Credential',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  void _openForm(BuildContext context, {CertificationModel? certification}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CertFormScreen(certification: certification),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PortfolioProvider portfolioProvider,
    CertificationModel cert,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Certification'),
        content: Text('Are you sure you want to delete "${cert.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
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
      certifications: portfolio.certifications
          .where((c) => c.id != cert.id)
          .toList(),
    );
    final success = await portfolioProvider.savePortfolio(updated);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Certification deleted.'
              : 'Failed to delete certification.',
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

/// Full-screen add/edit form for a single certification.
class _CertFormScreen extends StatefulWidget {
  final CertificationModel? certification;

  const _CertFormScreen({this.certification});

  @override
  State<_CertFormScreen> createState() => _CertFormScreenState();
}

class _CertFormScreenState extends State<_CertFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _issuerController;
  late final TextEditingController _credentialIdController;
  late final TextEditingController _credentialUrlController;
  DateTime? _issueDate;
  bool _isSaving = false;

  bool get _isEdit => widget.certification != null;

  @override
  void initState() {
    super.initState();
    final cert = widget.certification;
    _titleController = TextEditingController(text: cert?.title ?? '');
    _issuerController = TextEditingController(text: cert?.issuer ?? '');
    _credentialIdController = TextEditingController(
      text: cert?.credentialId ?? '',
    );
    _credentialUrlController = TextEditingController(
      text: cert?.credentialUrl ?? '',
    );
    _issueDate = cert?.issueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _issuerController.dispose();
    _credentialIdController.dispose();
    _credentialUrlController.dispose();
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
          _isEdit ? 'Edit Certification' : 'Add Certification',
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
                title: 'Certification Details',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g. AWS Certified Solutions Architect',
                      isDark: isDark,
                      validator: (value) =>
                          PortfolioValidators.required(value, 'Title'),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _issuerController,
                      label: 'Issuer',
                      hint: 'e.g. Amazon Web Services',
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    _buildIssueDateField(isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space20),
              PortfolioSectionCard(
                title: 'Credential',
                child: Column(
                  children: [
                    PortfolioTextField(
                      controller: _credentialIdController,
                      label: 'Credential ID',
                      hint: 'Optional',
                      isDark: isDark,
                      maxLength: 200,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    PortfolioTextField(
                      controller: _credentialUrlController,
                      label: 'Credential URL',
                      hint: 'https://…',
                      isDark: isDark,
                      keyboardType: TextInputType.url,
                      validator: (value) =>
                          PortfolioValidators.optionalUrl(value),
                      maxLength: 500,
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

  Widget _buildIssueDateField(bool isDark) {
    return InkWell(
      onTap: _pickIssueDate,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Issue Date',
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
          filled: true,
          fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
        ),
        child: Text(
          _issueDate != null
              ? DateFormat('MMM d, yyyy').format(_issueDate!)
              : 'Select date',
          style: AppTheme.bodyMedium.copyWith(
            color: _issueDate != null
                ? (isDark ? Colors.white : AppTheme.gray900)
                : (isDark ? AppTheme.gray400 : AppTheme.gray500),
          ),
        ),
      ),
    );
  }

  Future<void> _pickIssueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _issueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final portfolioProvider = context.read<PortfolioProvider>();
    final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
    final existing = widget.certification;

    final model = CertificationModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      issuer: _issuerController.text.trim(),
      issueDate: _issueDate,
      credentialId: _credentialIdController.text.trim().isNotEmpty
          ? _credentialIdController.text.trim()
          : null,
      credentialUrl: _credentialUrlController.text.trim().isNotEmpty
          ? _credentialUrlController.text.trim()
          : null,
    );

    final certifications = List<CertificationModel>.from(
      portfolio.certifications,
    );
    if (existing != null) {
      final index = certifications.indexWhere((c) => c.id == existing.id);
      if (index >= 0) {
        certifications[index] = model;
      } else {
        certifications.add(model);
      }
    } else {
      certifications.add(model);
    }

    final updated = portfolio.copyWith(certifications: certifications);
    final success = await portfolioProvider.savePortfolio(updated);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Certification saved.')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save certification. Please try again.'),
        ),
      );
    }
  }
}
