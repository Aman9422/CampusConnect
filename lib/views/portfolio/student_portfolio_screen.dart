import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/portfolio/portfolio_model.dart';
import 'package:campusconnect/models/portfolio/project_model.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/firestore/resume_service.dart'; // v8.4.2 (S4c)
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/portfolio/widgets/portfolio_section_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// CampusConnect v8.4 — Student Portfolio Screen (preview).
///
/// View-only rendering of the student's complete portfolio. Entry point for
/// editing (Edit Portfolio), the managers and resume upload. Reads the
/// portfolio from [PortfolioProvider] and the academic info from
/// [ProfileProvider] so education is always consistent with the profile.
class StudentPortfolioScreen extends StatelessWidget {
  const StudentPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Portfolio',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
            onPressed: () => Navigator.pushNamed(context, editPortfolioRoute),
            tooltip: 'Edit Portfolio',
          ),
        ],
      ),
      body: Consumer2<PortfolioProvider, ProfileProvider>(
        builder: (context, portfolioProvider, profileProvider, child) {
          if (portfolioProvider.isLoading && !portfolioProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          final portfolio = portfolioProvider.portfolio ?? PortfolioModel.empty();
          final profile = profileProvider.profile;

          return RefreshIndicator(
            onRefresh: () => portfolioProvider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompletionHeader(portfolio, profile, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // v8.9.2 (project_info__25/26): when the app holds
                  // portfolio data but the live Firestore document is empty
                  // (wiped doc / failed persistence), explain the gap
                  // between the 80% strength shown here and the "Complete
                  // your portfolio first" recommendation gate — the server
                  // cannot see the data the user saved. Self-heal pushes it
                  // back automatically; on failure, re-saving fixes it.
                  if (!portfolioProvider.isServerSynced &&
                      portfolioProvider.restoreMessage != null) ...[
                    _buildSyncWarning(portfolioProvider.restoreMessage!, isDark),
                    const SizedBox(height: AppTheme.space16),
                  ],

                  // v8.4.7: a failed load/refresh must be visible, never a
                  // silent "fresh 10% portfolio" while Firestore holds data.
                  if (portfolioProvider.error != null) ...[
                    _buildErrorBanner(portfolioProvider.error!, isDark),
                    const SizedBox(height: AppTheme.space16),
                  ],

                  // Resume
                  _buildResumeSection(context, portfolio, isDark),
                  const SizedBox(height: AppTheme.space16),

                  // Skills
                  if (portfolio.skills.isNotEmpty) ...[
                    _buildSkillsSection(portfolio, isDark),
                    const SizedBox(height: AppTheme.space16),
                  ],

                  // Projects
                  if (portfolio.projects.isNotEmpty) ...[
                    _buildProjectsSection(context, portfolio, isDark),
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

                  // Education
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
                    _buildEmptyCta(context, isDark),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletionHeader(
    PortfolioModel portfolio,
    StudentProfile? profile,
    bool isDark,
  ) {
    // Education lives in the user profile — award the +10 completion points
    // only when the profile actually carries academic data (issue C2).
    final academic = profile?.academic;
    final educationFilled =
        (academic?.college.isNotEmpty ?? false) ||
        (academic?.program.isNotEmpty ?? false);
    final completion = portfolio.profileCompletion(
      educationFilled: educationFilled,
    );
    final color = completion >= 70
        ? AppTheme.success
        : completion >= 40
        ? AppTheme.warning
        : AppTheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: AppTheme.space8),
              Text(
                'Portfolio Strength',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray900,
                ),
              ),
              const Spacer(),
              Text(
                '$completion%',
                style: AppTheme.titleSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: completion / 100,
              color: color,
              backgroundColor: isDark ? AppTheme.gray700 : AppTheme.gray200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(
    BuildContext context,
    PortfolioModel portfolio,
    bool isDark,
  ) {
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
                    color: AppTheme.success.withValues(alpha: isDark ? 0.2 : 0.1),
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
                if (resume.latestATSScore != null)
                  PortfolioInfoRow(
                    icon: Icons.grade_outlined,
                    label: 'Latest ATS Score',
                    value: '${resume.latestATSScore}/100',
                  ),
                // v8.4.1 (T3): Resume age in days.
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openResume(context, portfolioProviderUid: context.read<PortfolioProvider>().currentUserId),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, resumeUploadRoute),
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('Replace'),
                      ),
                    ),
                  ],
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
                    color: AppTheme.warning.withValues(alpha: isDark ? 0.2 : 0.1),
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
                  'Upload your resume PDF to complete your portfolio.',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, resumeUploadRoute),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Resume'),
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
          final color = _proficiencyColor(skill.proficiency);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skill.name,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                Text(
                  '${skill.category} · ${skill.proficiency}',
                  style: AppTheme.caption.copyWith(
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectsSection(
    BuildContext context,
    PortfolioModel portfolio,
    bool isDark,
  ) {
    return PortfolioSectionCard(
      title: 'Projects (${portfolio.projects.length})',
      child: Column(
        children: portfolio.projects.map((project) {
          return _buildProjectTile(context, project, isDark);
        }).toList(),
      ),
    );
  }

  /// M6: typed [ProjectModel] instead of `dynamic` + casts.
  /// L2: renders duration/"Ongoing" and GitHub/Demo links like the other views.
  Widget _buildProjectTile(
    BuildContext context,
    ProjectModel project,
    bool isDark,
  ) {
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
            project.title.isEmpty ? 'Untitled Project' : project.title,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              project.description,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (project.technologies.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.technologies
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
          ],
          if (project.startDate != null ||
              project.currentlyWorking ||
              project.endDate != null) ...[
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatProjectDuration(project),
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
          ],
          if (project.githubUrl != null || project.demoUrl != null) ...[
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                if (project.githubUrl != null)
                  _buildLinkChip(
                    context,
                    'GitHub',
                    project.githubUrl!,
                    Icons.code,
                    AppTheme.gray700,
                    isDark,
                  ),
                if (project.githubUrl != null && project.demoUrl != null)
                  const SizedBox(width: AppTheme.space8),
                if (project.demoUrl != null)
                  _buildLinkChip(
                    context,
                    'Demo',
                    project.demoUrl!,
                    Icons.open_in_new,
                    AppTheme.primaryBlue,
                    isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatProjectDuration(ProjectModel project) {
    final start = project.startDate;
    if (start == null) {
      return project.currentlyWorking ? 'Ongoing' : '—';
    }
    final startStr = DateFormat('MMM yyyy').format(start);
    if (project.currentlyWorking) return '$startStr — Present';
    final end = project.endDate;
    if (end == null) return startStr;
    // M9: defensively guard against stored inverted ranges from legacy data.
    if (end.isBefore(start)) return startStr;
    return '$startStr — ${DateFormat('MMM yyyy').format(end)}';
  }

  Widget _buildLinkChip(
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

  Widget _buildExperienceSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Experience (${portfolio.experience.length})',
      child: Column(
        children: portfolio.experience.map((exp) {
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
                  exp.role,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${exp.company} · ${exp.employmentType}',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
                if (exp.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    exp.description,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
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
                  cert.title,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cert.issuer.isNotEmpty ? cert.issuer : 'Issuer not specified',
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
                if (cert.issueDate != null) ...[
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    DateFormat('MMM yyyy').format(cert.issueDate!),
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ],
              ],
            ),
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
            PortfolioInfoRow(icon: Icons.business_outlined, label: 'College', value: college),
          if (program.isNotEmpty)
            PortfolioInfoRow(icon: Icons.school_outlined, label: 'Program', value: program),
          if (year > 0)
            PortfolioInfoRow(icon: Icons.calendar_today_outlined, label: 'Current Year', value: 'Year $year'),
          if (cgpa > 0)
            PortfolioInfoRow(icon: Icons.grade_outlined, label: 'CGPA', value: cgpa.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(PortfolioModel portfolio, bool isDark) {
    return PortfolioSectionCard(
      title: 'Achievements (${portfolio.achievements.length})',
      child: Column(
        children: portfolio.achievements.map((achievement) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                    ),
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
                  ],
                ),
                if (achievement.description.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    achievement.description,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
          return PortfolioInfoRow(
            icon: _linkIcon(entry.key),
            label: _linkLabel(entry.key),
            value: entry.value,
            isLink: true,
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

  /// v8.4.7: visible error banner — a failed load/refresh is surfaced instead
  /// of silently rendering an empty portfolio while Firestore holds the data.
  Widget _buildErrorBanner(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v8.9.2 (project_info__25/26): warning banner shown while the device
  /// holds portfolio data the live Firestore document no longer has. The
  /// "Portfolio Strength" number above reads from memory/cache, so this
  /// banner explains why recommendations are still gated ("Complete your
  /// portfolio first") — the server cannot see the data.
  Widget _buildSyncWarning(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: AppTheme.warning, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCta(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.rocket_launch_outlined, color: AppTheme.primaryBlue, size: 32),
          const SizedBox(height: AppTheme.space12),
          Text(
            'Build your portfolio to get discovered by teachers, alumni and employers.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppTheme.gray800,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, editPortfolioRoute),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Start Building'),
          ),
        ],
      ),
    );
  }

  Color _proficiencyColor(String proficiency) {
    switch (proficiency) {
      case 'Advanced':
        return AppTheme.success;
      case 'Intermediate':
        return AppTheme.primaryBlue;
      default:
        return AppTheme.warning;
    }
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
  /// Storage instead of crashing on a null-assert.
  Future<void> _openResume(
    BuildContext context, {
    required String? portfolioProviderUid,
  }) async {
    final uid = portfolioProviderUid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
        );
      }
      return;
    }
    try {
      final url = await ResumeService.instance().getResumeUrl(uid);
      if (url == null || url.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resume URL could not be resolved')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      await _launchUrl(context, url);
    } catch (_) {
      if (context.mounted) {
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
