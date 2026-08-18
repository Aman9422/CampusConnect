import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/activity_feed_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/providers/alumni_group_chat_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/portfolio_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// TeacherProfileView — v8.9 (Phase 13.5).
///
/// The TEACHER-appropriate profile. Replaces the accidental reuse of the
/// Student-oriented [ProfileView] for teachers.
///
/// Deliberately does NOT show any Student-only surface:
///   - No Student Portfolio
///   - No Resume Upload / Resume Review / ATS summary
///   - No Career Preferences
///   - No Student Projects / Credentials editing
///   - No Placement actions
///   - No Student recommendation controls
///
/// Shows Teacher-appropriate information only: Name, Email, Department,
/// Designation, Institution, Phone/Bio, account + app info.
///
/// Reuses the existing shared profile data model (`users/{uid}` via
/// [ProfileProvider]) — no duplicate user documents. Edits go through the
/// same owner-guarded update path (`ProfileProvider.updateProfile`), so
/// Firestore ownership rules and role immutability protections are intact.
class TeacherProfileView extends StatelessWidget {
  const TeacherProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = profileProvider.profile;
        final isIncomplete = profile?.isIncomplete ?? true;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            title: Text(
              'Profile',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            actions: [
              NotificationBadge(
                onTap: () => Navigator.pushNamed(context, notificationsRoute),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray700,
                ),
                onPressed: () => Navigator.pushNamed(context, settingsRoute),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incomplete profile warning.
                if (isIncomplete) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.warning,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Text(
                            'Complete your teacher profile so students and '
                            'colleagues can recognize you.',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.gray800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space20),
                ],

                // ── Teacher Header Card ──
                Container(
                  padding: const EdgeInsets.all(AppTheme.space20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: isDark ? AppTheme.gray700 : AppTheme.gray200,
                      width: 1,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.gray200.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      LargeInitialsAvatar(
                        name: profile?.personal.effectiveDisplayName ?? 'T',
                        uid: profile?.uid,
                        size: 64,
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.personal.effectiveDisplayName ??
                                  'Teacher Name',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.gray900,
                              ),
                            ),
                            if (profile?.designation?.isNotEmpty == true) ...[
                              const SizedBox(height: AppTheme.space4),
                              Text(
                                profile!.designation!,
                                style: AppTheme.bodySmall.copyWith(
                                  color: isDark
                                      ? AppTheme.gray400
                                      : AppTheme.gray600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              profile?.personal.email ?? 'Email',
                              style: AppTheme.bodySmall.copyWith(
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray600,
                              ),
                            ),
                            if (profile?.department?.isNotEmpty == true) ...[
                              const SizedBox(height: AppTheme.space4),
                              Text(
                                profile!.department!,
                                style: AppTheme.bodySmall.copyWith(
                                  color: isDark
                                      ? AppTheme.gray400
                                      : AppTheme.gray600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // ── Teacher Information ──
                Text(
                  'Teacher Information',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _tile(
                  isDark,
                  Icons.email_outlined,
                  'Email',
                  profile?.personal.email ?? 'Not set',
                ),
                _tile(
                  isDark,
                  Icons.phone_outlined,
                  'Phone',
                  (profile?.personal.phone.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.personal.phone,
                ),
                _tile(
                  isDark,
                  Icons.badge_outlined,
                  'Designation',
                  (profile?.designation?.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.designation!,
                ),
                _tile(
                  isDark,
                  Icons.account_balance_outlined,
                  'Department',
                  (profile?.department?.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.department!,
                ),
                _tile(
                  isDark,
                  Icons.school_outlined,
                  'Institution',
                  (profile?.academic.college.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.academic.college,
                ),
                if ((profile?.personal.bio.isNotEmpty ?? false)) ...[
                  _tile(
                    isDark,
                    Icons.notes_outlined,
                    'Bio',
                    profile!.personal.bio,
                  ),
                ],
                const SizedBox(height: AppTheme.space24),

                // ── Account ──
                Text(
                  'Account',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _menuCard(
                  isDark,
                  Icons.edit_outlined,
                  'Edit Profile',
                  'Update your name, phone, bio, department & designation',
                  () => Navigator.of(context).pushNamed(editProfileRoute),
                ),
                _menuCard(
                  isDark,
                  Icons.shield_outlined,
                  'Role: Teacher',
                  'Faculty & academic staff account',
                  null,
                ),
                const SizedBox(height: AppTheme.space24),

                // ── App Info ──
                Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.gray100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'App Version',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.gray600,
                        ),
                      ),
                      const _AppVersionText(),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space32),

                // ── Logout ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(bool isDark, IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800 : AppTheme.gray100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        title: Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
        ),
        trailing: onTap == null
            ? null
            : Icon(
                Icons.chevron_right,
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
              ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;
    // Reset ALL stateful providers BEFORE logout — identical to the
    // dashboard/settings logout paths — so no stale Student state survives
    // into a Teacher session on the next login.
    context.read<ProfileProvider>().reset();
    context.read<PlacementsProvider>().reset();
    context.read<AIUsageProvider>().reset();
    context.read<NotificationsProvider>().reset();
    context.read<ResumeReviewProvider>().reset();
    context.read<RoleProvider>().reset();
    context.read<MentorshipProvider>().reset();
    context.read<OpportunityProvider>().reset();
    context.read<AlumniDirectoryProvider>().reset();
    context.read<RecommendationProvider>().reset();
    context.read<EngagementProvider>().reset();
    context.read<AIChatProvider>().reset();
    context.read<ActivityFeedProvider>().reset();
    context.read<TeacherAnalyticsProvider>().reset();
    context.read<ChatProvider>().reset();
    context.read<PortfolioProvider>().reset();
    context.read<AlumniGroupChatProvider>().reset();
    try {
      await AuthService.firebase().logOut();
    } catch (_) {
      // AuthGuard handles the state.
    }
  }
}

/// Renders the real app version from package_info_plus.
class _AppVersionText extends StatelessWidget {
  const _AppVersionText();

  Future<String> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v8.9';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadVersion(),
      initialData: 'v8.9',
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? 'v8.9',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.gray600,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
