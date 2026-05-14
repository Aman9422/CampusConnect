// v7.2: Import new providers
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/recommendation_provider.dart';
import 'package:campusconnect/providers/engagement_provider.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart'; // v7.3
import 'package:campusconnect/views/widgets/chat_badge.dart'; // v7.3
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// v7.1: Alumni dashboard - tailored for graduates
class AlumniDashboardView extends StatelessWidget {
  const AlumniDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final name = profile?.personal.effectiveDisplayName ?? 'Alumni';
    final isPublicProfile = profile?.isPublicProfile == true;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Alumni Dashboard',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 20,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          // v7.3: Notification badge
          NotificationBadge(
            onTap: () => Navigator.pushNamed(context, notificationsRoute),
          ),
          // v7.3: Chat badge
          ChatBadge(),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: name, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $name',
                              style: AppTheme.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (profile?.company != null)
                              Text(
                                '${profile!.jobRole ?? "Professional"} at ${profile.company}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature cards
            _featureTile(
              icon: Icons.people_outline_rounded,
              title: 'Mentorship',
              subtitle: 'Connect with students seeking guidance',
              color: AppTheme.primaryBlue,
              isDark: isDark,
              onTap: () =>
                  Navigator.pushNamed(context, mentorshipRequestsRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.description_outlined,
              title: 'Resume Reviews',
              subtitle: 'Help students improve their resumes',
              color: AppTheme.success,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, resumeReviewRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.work_outline_rounded,
              title: 'Job Referrals',
              subtitle: 'Share opportunities from your network',
              color: AppTheme.warning,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, opportunitiesRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.business_center_outlined,
              title: 'Placements',
              subtitle: 'Post and update campus placement drives',
              color: AppTheme.primaryBlue,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, placementsListRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.public_rounded,
              title: 'Public Profile',
              subtitle: isPublicProfile
                  ? 'Visible to everyone with your link'
                  : 'Enable a shareable alumni profile link',
              color: AppTheme.secondaryIndigo,
              isDark: isDark,
              onTap: () => _managePublicProfile(context, profile),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.event_outlined,
              title: 'Campus Events',
              subtitle: 'Connect with fellow alumni',
              color: AppTheme.secondaryIndigo,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, alumniDirectoryRoute),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _managePublicProfile(
    BuildContext context,
    StudentProfile? profile,
  ) async {
    if (profile == null || profile.role != UserRole.alumni) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your alumni profile first')),
      );
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final profileService = ProfileService.instance();
    final key = await profileService.ensurePublicProfileKey(profile);
    if (!context.mounted) return;

    StudentProfile latestProfile = profileProvider.profile ?? profile;
    if ((latestProfile.publicProfileKey == null ||
            latestProfile.publicProfileKey!.isEmpty) &&
        context.mounted) {
      final keySynced = await profileProvider.updateProfile(
        latestProfile.copyWith(publicProfileKey: key),
      );
      if (!keySynced || !context.mounted) return;
      latestProfile = profileProvider.profile ?? latestProfile;
    }

    final profileLink = 'https://campusconnect.app/alumni/$key';
    final isPublic = latestProfile.isPublicProfile;
    final actionLabel = isPublic
        ? 'Disable Public Profile'
        : 'Enable Public Profile';
    final actionIcon = isPublic ? Icons.visibility_off : Icons.public;

    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Public Alumni Profile',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(sheetContext).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPublic
                      ? 'Your profile is public. Anyone with the link can view it.'
                      : 'Your profile is private. Enable it to share with recruiters and peers.',
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(sheetContext).brightness == Brightness.dark
                        ? AppTheme.gray400
                        : AppTheme.gray600,
                  ),
                ),
                const SizedBox(height: 16),
                if (isPublic) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(sheetContext).brightness == Brightness.dark
                          ? AppTheme.darkSurface
                          : AppTheme.gray100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(profileLink, style: AppTheme.bodySmall),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'toggle'),
                    icon: Icon(actionIcon),
                    label: Text(actionLabel),
                  ),
                ),
                if (isPublic) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'copy'),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy Public Link'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'preview'),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Preview Public Profile'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || selectedAction == null) return;

    if (selectedAction == 'copy') {
      await Clipboard.setData(ClipboardData(text: profileLink));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Public profile link copied')),
      );
      return;
    }

    if (selectedAction == 'preview') {
      Navigator.pushNamed(
        context,
        alumniProfileRoute,
        arguments: {'profileKey': key},
      );
      return;
    }

    if (selectedAction == 'toggle') {
      await _setPublicProfileVisibility(
        context,
        latestProfile: latestProfile,
        key: key,
        shouldEnable: !isPublic,
      );
    }
  }

  Future<void> _setPublicProfileVisibility(
    BuildContext context, {
    required StudentProfile latestProfile,
    required String key,
    required bool shouldEnable,
  }) async {
    final updatedProfile = latestProfile.copyWith(
      publicProfileKey: key,
      isPublicProfile: shouldEnable,
    );
    final success = await context.read<ProfileProvider>().updateProfile(
      updatedProfile,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (shouldEnable
                    ? 'Public profile enabled'
                    : 'Public profile disabled')
              : 'Failed to update public profile visibility',
        ),
      ),
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppTheme.gray700.withOpacity(0.5)
                : AppTheme.gray200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleSmall.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<ProfileProvider>().reset();
    context.read<PlacementsProvider>().reset();
    context.read<AIUsageProvider>().reset();
    context.read<NotificationsProvider>().reset();
    context.read<ResumeReviewProvider>().reset();
    context.read<RoleProvider>().reset();
    // v7.2: Reset ecosystem providers
    context.read<MentorshipProvider>().reset();
    context.read<OpportunityProvider>().reset();
    context.read<AlumniDirectoryProvider>().reset();
    context.read<RecommendationProvider>().reset();
    context.read<EngagementProvider>().reset();
    context.read<AIChatProvider>().reset();
    try {
      await AuthService.firebase().logOut();
    } catch (_) {
      // AuthGuard will handle the state
    }
    // AuthGuard StreamBuilder detects sign-out and shows LoginView
  }
}
