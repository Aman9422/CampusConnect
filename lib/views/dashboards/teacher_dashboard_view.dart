import 'package:campusconnect/constants/routes.dart';
// v7.2: Import new providers
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart'; // v7.3
import 'package:campusconnect/views/widgets/chat_badge.dart'; // v7.3
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// v7.1: Teacher dashboard - tailored for faculty
class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().profile;
    final name = profile?.personal.effectiveDisplayName ?? 'Professor';

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Teacher Dashboard',
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
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.3),
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
                            if (profile?.designation != null)
                              Text(
                                profile!.designation!,
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
              icon: Icons.analytics_outlined,
              title: 'Student Analytics',
              subtitle: 'View placement stats and academic trends',
              color: AppTheme.primaryBlue,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, studentAnalyticsRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.upload_file_outlined,
              title: 'Upload Notes',
              subtitle: 'Share lecture materials with students',
              color: AppTheme.success,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, uploadNotesRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.campaign_outlined,
              title: 'Announcements',
              subtitle: 'Share updates via lecture notes',
              color: AppTheme.warning,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, uploadNotesRoute),
            ),
            const SizedBox(height: 12),
            _featureTile(
              icon: Icons.assessment_outlined,
              title: 'Placement Reports',
              subtitle: 'Access placement analytics dashboard',
              color: AppTheme.secondaryIndigo,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, studentAnalyticsRoute),
            ),
          ],
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
    try {
      await AuthService.firebase().logOut();
    } catch (_) {
      // AuthGuard will handle the state
    }
    // AuthGuard StreamBuilder detects sign-out and shows LoginView
  }
}
