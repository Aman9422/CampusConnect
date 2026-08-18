import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// AlumniProfileSections — v7.5: Professional networking sections for alumni profile.
///
/// These widgets are only used when the logged-in user role is `UserRole.alumni`.
/// Student and Teacher profiles remain unchanged.

// ──────────────────────────────────────────────
// 1. Professional Header
// ──────────────────────────────────────────────
class AlumniProfileHeader extends StatelessWidget {
  final StudentProfile? profile;
  final bool isDark;

  const AlumniProfileHeader({super.key, required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = profile?.personal.effectiveDisplayName ?? 'Alumni';
    final jobRole = profile?.jobRole;
    final company = profile?.company;
    final yearsExp = profile?.yearsOfExperience;
    final skills = profile?.skills ?? [];
    final isPublic = profile?.isPublicProfile ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryIndigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LargeInitialsAvatar(
            name: name,
            uid: profile?.uid,
            size: 80,
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            name,
            style: AppTheme.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          if (jobRole != null || company != null) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              '${jobRole ?? ''}${jobRole != null && company != null ? ' at ' : ''}${company ?? ''}',
              style: AppTheme.titleSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppTheme.space12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (yearsExp != null)
                _headerBadge(Icons.work_history_rounded, '$yearsExp yr${yearsExp > 1 ? 's' : ''}'),
              if (skills.length > 2)
                _headerBadge(Icons.lightbulb_outline, '${skills.length} skills'),
              if (isPublic)
                _headerBadge(Icons.public_rounded, 'Public'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 2. About Section
// ──────────────────────────────────────────────
class AlumniAboutSection extends StatelessWidget {
  final String? bio;
  final bool isDark;

  const AlumniAboutSection({super.key, required this.bio, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = bio?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// 3. Quick Impact Strip
// ──────────────────────────────────────────────
class AlumniImpactStrip extends StatelessWidget {
  const AlumniImpactStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mentorship = context.watch<MentorshipProvider>();
    final opportunities = context.watch<OpportunityProvider>();
    final engagement = context.watch<EngagementProvider>();

    final totalMentees = mentorship.acceptedMentorshipsCount + mentorship.completedMentorshipsCount;
    final oppsPosted = opportunities.myOpportunities?.length ?? 0;
    final score = engagement.engagementScore;
    final strength = engagement.profileStrength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quick Impact', isDark),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(child: _impactChip('$totalMentees', 'Mentees', Icons.people_outline, AppTheme.primaryBlue, isDark)),
            const SizedBox(width: AppTheme.space8),
            Expanded(child: _impactChip('$oppsPosted', 'Opps Posted', Icons.work_outline, AppTheme.success, isDark)),
            const SizedBox(width: AppTheme.space8),
            Expanded(child: _impactChip('$score%', 'Engagement', Icons.favorite_outline, AppTheme.warning, isDark)),
            const SizedBox(width: AppTheme.space8),
            Expanded(child: _impactChip('$strength%', 'Strength', Icons.trending_up_rounded, AppTheme.secondaryIndigo, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _impactChip(String value, String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12, horizontal: AppTheme.space8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          Text(
            label,
            style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 4. Professional Info
// ──────────────────────────────────────────────
class AlumniProfessionalInfo extends StatelessWidget {
  final StudentProfile? profile;
  final bool isDark;

  const AlumniProfessionalInfo({super.key, required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final fields = <_InfoField>[
      if (profile!.company != null) _InfoField('Company', profile!.company!, Icons.business_outlined),
      if (profile!.jobRole != null) _InfoField('Job Title', profile!.jobRole!, Icons.work_outline),
      if (profile!.industry != null) _InfoField('Industry', profile!.industry!, Icons.category_outlined),
      if (profile!.employmentType != null) _InfoField('Employment Type', profile!.employmentType!, Icons.event_outlined),
      if (profile!.workMode != null) _InfoField('Work Mode', profile!.workMode!, Icons.settings_ethernet_outlined),
      if (profile!.workLocation != null) _InfoField('Location', profile!.workLocation!, Icons.location_on_outlined),
      if (profile!.yearsOfExperience != null) _InfoField('Experience', '${profile!.yearsOfExperience!} years', Icons.history_rounded),
    ];

    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Professional Information', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            children: fields.map((f) => _infoRow(f, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(_InfoField field, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        children: [
          Icon(field.icon, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
                const SizedBox(height: 2),
                Text(field.value, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoField {
  final String label;
  final String value;
  final IconData icon;
  _InfoField(this.label, this.value, this.icon);
}

// ──────────────────────────────────────────────
// 5. Skills & Expertise
// ──────────────────────────────────────────────
class AlumniSkillsSection extends StatelessWidget {
  final List<String>? skills;
  final bool isDark;

  const AlumniSkillsSection({super.key, required this.skills, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final list = skills ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Skills & Expertise', isDark),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.15)),
            ),
            child: Text(s, style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
          )).toList(),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// 6. Career Timeline
// ──────────────────────────────────────────────
class AlumniCareerTimeline extends StatelessWidget {
  final List<WorkExperience>? workHistory;
  final bool isDark;

  const AlumniCareerTimeline({super.key, required this.workHistory, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final history = workHistory ?? [];
    if (history.isEmpty) return const SizedBox.shrink();

    // Sort by start date descending (most recent first)
    final sorted = List<WorkExperience>.from(history)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Career Journey', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            children: List.generate(sorted.length, (i) {
              final exp = sorted[i];
              final isLast = i == sorted.length - 1;
              return _timelineEntry(exp, isLast, isDark);
            }),
          ),
        ),
      ],
    );
  }

  Widget _timelineEntry(WorkExperience exp, bool isLast, bool isDark) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: exp.isCurrent ? AppTheme.success : AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp.role,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  Text(
                    exp.company,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    _formatDateRange(exp.startDate, exp.endDate, exp.isCurrent),
                    style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
                  ),
                  if (exp.description != null && exp.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      exp.description!,
                      style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startStr = '${months[start.month - 1]} ${start.year}';
    if (isCurrent) return '$startStr — Present';
    if (end == null) return startStr;
    final endStr = '${months[end.month - 1]} ${end.year}';
    return '$startStr — $endStr';
  }
}

// ──────────────────────────────────────────────
// 7. Mentorship Profile
// ──────────────────────────────────────────────
class AlumniMentorshipSection extends StatelessWidget {
  final StudentProfile? profile;
  final bool isDark;

  const AlumniMentorshipSection({super.key, required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mentorship = context.watch<MentorshipProvider>();
    final active = mentorship.acceptedMentorshipsCount;
    final completed = mentorship.completedMentorshipsCount;
    final maxMentees = profile?.maxMentees;
    final topics = profile?.mentorshipTopics ?? [];
    final languages = profile?.languages ?? [];

    if (active == 0 && completed == 0 && topics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Mentorship Profile', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _mentorshipStat('$active', 'Active', Icons.school_outlined, AppTheme.success, isDark),
                  const SizedBox(width: AppTheme.space16),
                  _mentorshipStat('$completed', 'Completed', Icons.celebration_outlined, AppTheme.primaryBlue, isDark),
                  if (maxMentees != null) ...[
                    const SizedBox(width: AppTheme.space16),
                    _mentorshipStat('$maxMentees', 'Max Mentees', Icons.people_outline, AppTheme.secondaryIndigo, isDark),
                  ],
                ],
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space12),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.space12),
                Text('Preferred Topics', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray800)),
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: topics.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t, style: AppTheme.caption.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
              if (languages.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Languages: ${languages.join(', ')}',
                  style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _mentorshipStat(String value, String label, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppTheme.space4),
          Text(value, style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.gray900)),
          Text(label, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 8. Social Links
// ──────────────────────────────────────────────
class AlumniSocialLinks extends StatelessWidget {
  final StudentProfile? profile;
  final bool isDark;

  const AlumniSocialLinks({super.key, required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final links = <_LinkItem>[
      if (p?.linkedinProfile?.isNotEmpty == true)
        _LinkItem('LinkedIn', p!.linkedinProfile!, Icons.link_outlined, 'https://linkedin.com'),
      if (p?.githubUrl?.isNotEmpty == true)
        _LinkItem('GitHub', p!.githubUrl!, Icons.code_outlined, 'https://github.com'),
      if (p?.portfolioUrl?.isNotEmpty == true)
        _LinkItem('Portfolio', p!.portfolioUrl!, Icons.web_outlined, null),
      if (p?.websiteUrl?.isNotEmpty == true)
        _LinkItem('Website', p!.websiteUrl!, Icons.language_outlined, null),
      if (p?.leetcodeUrl?.isNotEmpty == true)
        _LinkItem('LeetCode', p!.leetcodeUrl!, Icons.code_outlined, 'https://leetcode.com'),
      if (p?.hackerrankUrl?.isNotEmpty == true)
        _LinkItem('HackerRank', p!.hackerrankUrl!, Icons.code_outlined, 'https://hackerrank.com'),
      if (p?.personal.email.isNotEmpty == true)
        _LinkItem('Email', p!.personal.email, Icons.email_outlined, null),
      if (p?.personal.phone.isNotEmpty == true)
        _LinkItem('Phone', p!.personal.phone, Icons.phone_outlined, null),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Social & Contact', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            children: links.map((l) => _linkRow(l, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _linkRow(_LinkItem link, bool isDark) {
    return InkWell(
      onTap: () {
        final url = link.url.startsWith('http') ? link.url : 'https://${link.url}';
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
        child: Row(
          children: [
            Icon(link.icon, size: 20, color: AppTheme.primaryBlue),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.label, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                  Text(link.url, style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }
}

class _LinkItem {
  final String label;
  final String url;
  final IconData icon;
  final String? prefix;
  _LinkItem(this.label, this.url, this.icon, this.prefix);
}

// ──────────────────────────────────────────────
// 9. Achievements
// ──────────────────────────────────────────────
class AlumniAchievementsSection extends StatelessWidget {
  final List<Achievement>? achievements;
  final bool isDark;

  const AlumniAchievementsSection({super.key, required this.achievements, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final list = achievements ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Achievements', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            children: list.map((a) => _achievementRow(a, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _achievementRow(Achievement achievement, bool isDark) {
    IconData icon;
    Color color;
    switch (achievement.type) {
      case 'award':
        icon = Icons.emoji_events_outlined;
        color = AppTheme.warning;
        break;
      case 'publication':
        icon = Icons.article_outlined;
        color = AppTheme.primaryBlue;
        break;
      case 'openSource':
        icon = Icons.code_rounded;
        color = AppTheme.success;
        break;
      case 'volunteer':
        icon = Icons.favorite_outline;
        color = AppTheme.error;
        break;
      default:
        icon = Icons.verified_outlined;
        color = AppTheme.secondaryIndigo;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.gray900)),
                if (achievement.issuer != null) Text(achievement.issuer!, style: AppTheme.caption.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
                if (achievement.description != null && achievement.description!.isNotEmpty)
                  Text(achievement.description!, style: AppTheme.bodySmall.copyWith(color: isDark ? AppTheme.gray400 : AppTheme.gray600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 10. Public Profile — toggle + shareable key
// ──────────────────────────────────────────────
class AlumniPublicProfileSection extends StatelessWidget {
  final bool isPublic;
  final String? publicKey;
  final bool isDark;
  final ValueChanged<bool>? onToggle;

  const AlumniPublicProfileSection({
    super.key,
    required this.isPublic,
    this.publicKey,
    required this.isDark,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Public Profile', isDark),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPublic ? Icons.public_rounded : Icons.public_off_outlined,
                    color: isPublic ? AppTheme.success : AppTheme.gray400,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      isPublic ? 'Profile is Public' : 'Profile is Private',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPublic ? AppTheme.success : (isDark ? AppTheme.gray400 : AppTheme.gray600),
                      ),
                    ),
                  ),
                  Switch(
                    value: isPublic,
                    onChanged: onToggle,
                    activeThumbColor: AppTheme.success,
                  ),
                ],
              ),
              if (isPublic && publicKey != null) ...[
                const SizedBox(height: AppTheme.space12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12, vertical: AppTheme.space8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.gray800 : AppTheme.gray100,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          publicKey!,
                          style: AppTheme.bodySmall.copyWith(
                            color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: publicKey!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile key copied')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Shared helpers
// ──────────────────────────────────────────────
Widget _sectionTitle(String title, bool isDark) {
  return Text(
    title,
    style: AppTheme.bodyLarge.copyWith(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : AppTheme.gray900,
    ),
  );
}
