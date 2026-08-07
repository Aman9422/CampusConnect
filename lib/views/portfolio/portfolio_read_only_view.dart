import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/portfolio_service.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/services/firestore/resume_service.dart'; // v8.4.2 (S4c)
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v8.4 — Read-only Portfolio View (Teacher / Alumni).
///
/// Opens a student's complete portfolio without allowing edits. Unlike
/// [StudentPortfolioScreen] (which reads from the PortfolioProvider of the
/// signed-in user), this view loads the target student's data directly from
/// Firestore via [PortfolioService] / [ProfileService], so it works for any
/// viewer with read access (teachers and alumni).
///
/// Expects the target user id passed as route `arguments` (String).
class PortfolioReadOnlyView extends StatefulWidget {
  const PortfolioReadOnlyView({super.key});

  @override
  State<PortfolioReadOnlyView> createState() => _PortfolioReadOnlyViewState();
}

class _PortfolioReadOnlyViewState extends State<PortfolioReadOnlyView> {
  PortfolioModel? _portfolio;
  StudentProfile? _profile;
  bool _isLoading = true;
  String? _error;
  // v8.4.2 (S4c/N2): target student's uid — needed to resolve the resume URL
  // via ResumeService when the stored metadata only has a storagePath.
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Defer the load to after the first frame: _load() calls
    // ModalRoute.of(context), which is an inherited-widget lookup and is
    // illegal during initState (throws _ModalScopeStatus dependency error).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final userId = args is String && args.isNotEmpty ? args : null;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No student selected.';
      });
      return;
    }
    _userId = userId;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        PortfolioService.instance().getPortfolio(userId),
        ProfileService.instance().getProfile(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _portfolio = results[0] as PortfolioModel;
        _profile = results[1] as StudentProfile?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load portfolio.';
      });
    }
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
          'Student Portfolio',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.gray400),
              const SizedBox(height: AppTheme.space16),
              Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final portfolio = _portfolio ?? PortfolioModel.empty();
    final profile = _profile;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentHeader(profile, portfolio, isDark),
            const SizedBox(height: AppTheme.space16),

            // Resume
            _buildResumeSection(portfolio, isDark),
            const SizedBox(height: AppTheme.space16),

            // Skills
            if (portfolio.skills.isNotEmpty) ...[
              _buildSkillsSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            // Projects
            if (portfolio.projects.isNotEmpty) ...[
              _buildProjectsSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            // Experience
            if (portfolio.experience.isNotEmpty) ...[
              _buildExperienceSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            // Certifications
            if (portfolio.certifications.isNotEmpty) ...[
              _buildCertificationsSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            // Education (from the student's profile)
            _buildEducationSection(profile, isDark),
            const SizedBox(height: AppTheme.space16),

            // Achievements
            if (portfolio.achievements.isNotEmpty) ...[
              _buildAchievementsSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            // Social Links
            _buildSocialLinksSection(portfolio, isDark),
            const SizedBox(height: AppTheme.space16),

            // Career Preferences
            _buildPreferencesSection(portfolio, isDark),
            const SizedBox(height: AppTheme.space16),

            // Languages (v8.4.1 T3)
            if (portfolio.languages.isNotEmpty) ...[
              _buildLanguagesSection(portfolio, isDark),
              const SizedBox(height: AppTheme.space16),
            ],

            if (portfolio.isEmpty) ...[
              const SizedBox(height: AppTheme.space16),
              Text(
                'This student has not added portfolio details yet.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeader(StudentProfile? profile, PortfolioModel portfolio, bool isDark) {
    final name = profile?.personal.effectiveDisplayName ?? 'Student';
    final program = profile?.academic.program ?? '';
    final college = profile?.academic.college ?? '';
    // Education lives in the user profile — award the +10 completion points
    // only when the profile actually carries academic data (issue C2).
    final educationFilled = college.isNotEmpty || program.isNotEmpty;
    final completion = portfolio.profileCompletion(
      educationFilled: educationFilled,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: AppTheme.primaryBlue, size: 30),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                if (program.isNotEmpty || college.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [program, college].where((s) => s.isNotEmpty).join(' · '),
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completion%',
                style: AppTheme.titleSmall.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'complete',
                style: AppTheme.caption.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(PortfolioModel portfolio, bool isDark) {
    final resume = portfolio.resume;
    final hasResume = resume?.hasResume == true;

    return PortfolioSectionCard(
      title: 'Resume',
      child: hasResume
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v8.4.1 (T3): Resume Status chip (docs/Task.md Phase 3).
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resume Uploaded',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                PortfolioInfoRow(
                  icon: Icons.description_outlined,
                  label: 'File',
                  value: resume!.fileName ?? 'resume.pdf',
                ),
                // v8.4.1 (T3): Latest ATS + resume age.
                if (resume.latestATSScore != null)
                  PortfolioInfoRow(
                    icon: Icons.grade_outlined,
                    label: 'Latest ATS Score',
                    value: '${resume.latestATSScore}/100',
                  ),
                PortfolioInfoRow(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Resume Age',
                  value: resume.uploadedAt != null
                      ? '${resume.resumeAgeInDays} day${resume.resumeAgeInDays == 1 ? '' : 's'}'
                      : '—',
                ),
                PortfolioInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Uploaded',
                  value: resume.uploadedAt != null
                      ? DateFormat('MMM d, yyyy').format(resume.uploadedAt!)
                      : '—',
                ),
                PortfolioInfoRow(
                  icon: Icons.update_outlined,
                  label: 'Last Updated',
                  value: resume.lastUpdated != null
                      ? DateFormat('MMM d, yyyy').format(resume.lastUpdated!)
                      : '—',
                ),
                PortfolioInfoRow(
                  icon: Icons.tag,
                  label: 'Version',
                  value: 'v${resume.version}',
                ),
                PortfolioInfoRow(
                  icon: Icons.rate_review_outlined,
                  label: 'Reviews',
                  value: '${resume.reviewCount}',
                ),
                PortfolioInfoRow(
                  icon: Icons.event_note_outlined,
                  label: 'Last Review',
                  value: resume.lastReviewAt != null
                      ? DateFormat('MMM d, yyyy').format(resume.lastReviewAt!)
                      : '—',
                ),
                // v8.4.1 (T3): Storage metadata rows.
                if (resume.fileSize != null)
                  PortfolioInfoRow(
                    icon: Icons.data_usage_outlined,
                    label: 'Size',
                    value: _formatFileSize(resume.fileSize!),
                  ),
                if (resume.mimeType?.isNotEmpty == true)
                  PortfolioInfoRow(
                    icon: Icons.file_present_outlined,
                    label: 'Type',
                    value: resume.mimeType!,
                  ),
                if (resume.storagePath?.isNotEmpty == true)
                  PortfolioInfoRow(
                    icon: Icons.folder_outlined,
                    label: 'Storage Path',
                    value: resume.storagePath!,
                  ),
                const SizedBox(height: AppTheme.space12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openResume,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Resume'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v8.4.1 (T3): "Not uploaded" status chip.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_outlined,
                        size: 16,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No Resume Uploaded',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'No resume uploaded yet.',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
    );
  }

  /// v8.4.1 (T3): Human-readable file size (e.g. "1.2 MB").
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Widget _buildSkillsSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Skills (${portfolio.skills.length})',
      child: Wrap(
        spacing: AppTheme.space8,
        runSpacing: AppTheme.space8,
        children: portfolio.skills.map((skill) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '${skill.name} · ${skill.proficiency}',
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectsSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Projects (${portfolio.projects.length})',
      child: Column(
        children: portfolio.projects.map((project) {
          return _buildReadOnlyTile(
            isDark,
            title: project.title,
            subtitle: project.description,
            extra: project.technologies,
            footer: _periodLabel(
              start: project.startDate,
              end: project.endDate,
              current: project.currentlyWorking,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExperienceSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Experience (${portfolio.experience.length})',
      child: Column(
        children: portfolio.experience.map((exp) {
          return _buildReadOnlyTile(
            isDark,
            title: exp.role,
            subtitle: '${exp.company} · ${exp.employmentType}',
            description: exp.description,
            footer: _periodLabel(
              start: exp.startDate,
              end: exp.endDate,
              current: exp.currentlyWorking,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCertificationsSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Certifications (${portfolio.certifications.length})',
      child: Column(
        children: portfolio.certifications.map((cert) {
          return _buildReadOnlyTile(
            isDark,
            title: cert.title,
            subtitle: cert.issuer.isNotEmpty ? cert.issuer : null,
            footer: cert.issueDate != null
                ? DateFormat('MMM yyyy').format(cert.issueDate!)
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEducationSection(StudentProfile? profile, bool isDark) {
    final academic = profile?.academic;
    final college = academic?.college ?? '';
    final program = academic?.program ?? '';
    final year = academic?.year ?? 0;
    final cgpa = academic?.cgpa ?? 0.0;

    return PortfolioSectionCard(
      title: 'Education',
      child: Column(
        children: [
          if (college.isNotEmpty)
            PortfolioInfoRow(
              icon: Icons.business_outlined,
              label: 'College',
              value: college,
            ),
          if (program.isNotEmpty)
            PortfolioInfoRow(
              icon: Icons.school_outlined,
              label: 'Program',
              value: program,
            ),
          if (year > 0)
            PortfolioInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Current Year',
              value: 'Year $year',
            ),
          if (cgpa > 0)
            PortfolioInfoRow(
              icon: Icons.grade_outlined,
              label: 'CGPA',
              value: cgpa.toStringAsFixed(2),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Achievements (${portfolio.achievements.length})',
      child: Column(
        children: portfolio.achievements.map((achievement) {
          return _buildReadOnlyTile(
            isDark,
            title: achievement.title,
            subtitle: achievement.category,
            description: achievement.description,
            footer: achievement.date != null
                ? DateFormat('MMM yyyy').format(achievement.date!)
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSocialLinksSection(PortfolioModel portfolio, bool isDark) {
    final links = portfolio.links.activeLinks;
    if (links.isEmpty) return const SizedBox.shrink();

    return PortfolioSectionCard(
      title: 'Social Links',
      child: Column(
        children: links.entries.map((entry) {
          return InkWell(
            onTap: () => _launchUrl(context, entry.value),
            child: PortfolioInfoRow(
              icon: _linkIcon(entry.key),
              label: _linkLabel(entry.key),
              value: entry.value,
              isLink: true,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreferencesSection(PortfolioModel portfolio, bool isDark) {
    final prefs = portfolio.preferences;
    // M4: show the section even when only the default remote/relocation
    // preferences are set — otherwise the section disappears while the edit
    // screen always exposes those fields.
    final hasContent = !prefs.isEmpty;

    if (!hasContent) return const SizedBox.shrink();

    return PortfolioSectionCard(
      title: 'Career Preferences',
      child: Column(
        children: [
          if (prefs.preferredRoles.isNotEmpty)
            PortfolioInfoRow(
              icon: Icons.work_outline,
              label: 'Preferred Roles',
              value: prefs.preferredRoles.join(', '),
            ),
          if (prefs.preferredLocations.isNotEmpty)
            PortfolioInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Preferred Locations',
              value: prefs.preferredLocations.join(', '),
            ),
          if (prefs.expectedSalary?.isNotEmpty == true)
            PortfolioInfoRow(
              icon: Icons.currency_rupee,
              label: 'Expected Salary',
              value: prefs.expectedSalary!,
            ),
          // v8.4.1 (T3): Career objective (docs/Task.md Phase 3).
          if (prefs.careerObjective?.isNotEmpty == true)
            PortfolioInfoRow(
              icon: Icons.flag_outlined,
              label: 'Career Objective',
              value: prefs.careerObjective!,
            ),
          PortfolioInfoRow(
            icon: Icons.wifi_tethering_outlined,
            label: 'Remote',
            value: prefs.remotePreference,
          ),
          PortfolioInfoRow(
            icon: Icons.near_me_outlined,
            label: 'Relocation',
            value: prefs.relocationPreference,
          ),
        ],
      ),
    );
  }

  /// v8.4.1 (T3): Languages section (docs/Task.md Phase 3).
  Widget _buildLanguagesSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Languages',
      child: Wrap(
        spacing: AppTheme.space8,
        runSpacing: AppTheme.space8,
        children: portfolio.languages.map((language) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.secondaryIndigo.withValues(
                alpha: isDark ? 0.2 : 0.1,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: AppTheme.secondaryIndigo.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              language,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Shared read-only entry tile used by projects / experience / certs / achievements.
  Widget _buildReadOnlyTile(
    bool isDark, {
    required String title,
    String? subtitle,
    String? description,
    List<String>? extra,
    String? footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.gray50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Untitled' : title,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space6),
            Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (extra != null && extra.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extra
                  .map(
                    (tech) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
          ],
          if (footer != null && footer.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space6),
            Text(
              footer,
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _periodLabel({
    DateTime? start,
    DateTime? end,
    required bool current,
  }) {
    if (start == null) return current ? 'Present' : null;
    final startStr = DateFormat('MMM yyyy').format(start);
    if (current) return '$startStr — Present';
    if (end == null) return startStr;
    // M9: defensively guard against stored inverted ranges from legacy data.
    if (end.isBefore(start)) return startStr;
    return '$startStr — ${DateFormat('MMM yyyy').format(end)}';
  }

  IconData _linkIcon(String key) {
    switch (key) {
      case 'github':
        return Icons.code;
      case 'linkedin':
        return Icons.link;
      case 'portfolio':
        return Icons.language;
      case 'leetcode':
        return Icons.terminal;
      case 'codeforces':
        return Icons.bolt;
      case 'hackerrank':
        return Icons.grid_view;
      default:
        return Icons.link;
    }
  }

  String _linkLabel(String key) {
    const labels = {
      'github': 'GitHub',
      'linkedin': 'LinkedIn',
      'portfolio': 'Portfolio',
      'leetcode': 'LeetCode',
      'codeforces': 'Codeforces',
      'hackerrank': 'HackerRank',
    };
    return labels[key] ?? key;
  }

  /// v8.4.2 (S4c/N2): Opens the resume via [ResumeService.getResumeUrl] so a
  /// storagePath-only legacy resume (no cached `downloadUrl`) resolves through
  /// Storage instead of crashing on a null-assert. Uses the State's own
  /// [context] so the `mounted` guards satisfy the analyzer.
  Future<void> _openResume() async {
    final uid = _userId;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
        );
      }
      return;
    }
    try {
      final url = await ResumeService.instance().getResumeUrl(uid);
      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resume URL could not be resolved')),
          );
        }
        return;
      }
      if (!mounted) return;
      await _launchUrl(context, url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
        );
      }
    }
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
}
