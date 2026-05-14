import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// ProfileView - Extracted from monolithic NotesView
///
/// Phase 1 of NotesView decomposition: Clean, focused profile management view
/// with comprehensive user information display, settings access, and secure logout.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        if (profileProvider.isLoading && !profileProvider.isInitialized) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

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
              // V6.4: Notification badge
              NotificationBadge(
                onTap: () => Navigator.pushNamed(context, notificationsRoute),
              ),
              // v6.6: Settings button
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
                // Incomplete profile warning
                if (isIncomplete) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3),
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
                            'Complete your profile to get personalized recommendations',
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

                // Profile Header Card
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
                              color: AppTheme.gray200.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // v6.6: Smart initials avatar (no image upload)
                      LargeInitialsAvatar(
                        name: profile?.personal.effectiveDisplayName ?? 'User',
                        uid: profile?.uid,
                        size: 64,
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // v6.6: Use effectiveDisplayName with fallback
                            Text(
                              profile?.personal.effectiveDisplayName ??
                                  'Student Name',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.gray900,
                              ),
                            ),
                            // v6.6: Show bio if available
                            if (profile?.personal.bio.isNotEmpty == true) ...[
                              const SizedBox(height: AppTheme.space4),
                              Text(
                                profile!.personal.bio,
                                style: AppTheme.bodySmall.copyWith(
                                  color: isDark
                                      ? AppTheme.gray400
                                      : AppTheme.gray600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                            Text(
                              (profile?.academic.program.isEmpty ?? true)
                                  ? 'Program not set'
                                  : '${profile!.academic.program}, Year ${profile.academic.year}',
                              style: AppTheme.bodySmall.copyWith(
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Contact Information Section
                Text(
                  'Contact Information',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _ProfileInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: profile?.personal.email ?? 'Not set',
                ),
                _ProfileInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  value: (profile?.personal.phone.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.personal.phone,
                ),
                const SizedBox(height: AppTheme.space24),

                // Academic Information Section (Display-only)
                Text(
                  'Academic Information',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _ProfileInfoTile(
                  icon: Icons.school_outlined,
                  title: 'Program',
                  value: (profile?.academic.program.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.academic.program,
                ),
                _ProfileInfoTile(
                  icon: Icons.business_outlined,
                  title: 'College',
                  value: (profile?.academic.college.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.academic.college,
                ),
                _ProfileInfoTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Year',
                  value:
                      (profile?.academic.year == null ||
                          profile!.academic.year == 0)
                      ? 'Not set'
                      : 'Year ${profile.academic.year}',
                ),
                _ProfileInfoTile(
                  icon: Icons.star_outline,
                  title: 'CGPA',
                  value:
                      (profile?.academic.cgpa == null ||
                          profile!.academic.cgpa == 0.0)
                      ? 'Not set'
                      : '${profile.academic.cgpa.toStringAsFixed(2)} / 10.0',
                ),
                const SizedBox(height: AppTheme.space24),

                // Settings Section
                Text(
                  'Settings',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _ProfileMenuCard(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal & academic information',
                  onTap: () {
                    Navigator.of(context).pushNamed('/edit-profile');
                  },
                ),
                const SizedBox(height: AppTheme.space24),

                // App Info
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
                      Text(
                        'v7.3.0',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.gray600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space32),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleProfileLogout(context),
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

  Future<void> _handleProfileLogout(BuildContext context) async {
    final shouldLogout = await _showLogOutDialog(context);
    if (shouldLogout && context.mounted) {
      // CRITICAL: Reset all providers BEFORE logout to prevent data leakage
      context.read<ProfileProvider>().reset();
      context.read<PlacementsProvider>().reset();
      context.read<AIUsageProvider>().reset();
      context.read<NotificationsProvider>().reset();
      context.read<ResumeReviewProvider>().reset(); // v6.7
      context.read<RoleProvider>().reset(); // v7.1
      context.read<RecommendationProvider>().reset(); // v7.4
      context.read<EngagementProvider>().reset(); // v7.4
      context.read<AIChatProvider>().reset(); // v7.4
      try {
        await AuthService.firebase().logOut();
      } catch (_) {
        // AuthGuard will handle the state
      }
      // AuthGuard handles navigation via StreamBuilder
    }
  }

  Future<bool> _showLogOutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }
}

/// Internal profile menu card widget - extracted from NotesView._buildProfileMenuCard()
class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.2 : 0.1),
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
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Display-only info tile (no tap action) - extracted from NotesView._buildProfileInfoTile()
class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
}
