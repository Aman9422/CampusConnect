import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/services/firestore/profile_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// AlumniProfileView - v7.2: Multi-role ecosystem
///
/// Detailed view of an alumni profile with mentorship request functionality.
/// Students can view complete alumni information and send mentorship requests.
/// Alumni can view their own profile for verification.
class AlumniProfileView extends StatefulWidget {
  const AlumniProfileView({super.key});

  @override
  State<AlumniProfileView> createState() => _AlumniProfileViewState();
}

class _AlumniProfileViewState extends State<AlumniProfileView> {
  StudentProfile? _alumniProfile;
  Map<String, dynamic>? _publicProjection;
  bool _isPublicView = false;
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAlumniProfile();
  }

  void _loadAlumniProfile() async {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map<String, dynamic> ? routeArgs : null;
    final alumniId = args?['alumniId'] as String?;
    final profileKey = args?['profileKey'] as String?;

    if (profileKey != null && profileKey.isNotEmpty) {
      try {
        final profileService = ProfileService.instance();
        final projection = await profileService.getPublicProfileProjection(
          profileKey,
        );
        final profile = await profileService.getPublicAlumniProfile(profileKey);
        if (mounted) {
          setState(() {
            _publicProjection = projection;
            _isPublicView = true;
            _alumniProfile = profile;
            _isLoading = false;
            _error = profile == null ? 'Public alumni profile not found' : null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Failed to load public alumni profile';
            _isLoading = false;
          });
        }
      }
      return;
    }

    if (alumniId == null) {
      setState(() {
        _error = 'Alumni ID not provided';
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await context
          .read<AlumniDirectoryProvider>()
          .getAlumniById(alumniId);
      if (mounted) {
        setState(() {
          _alumniProfile = profile;
          _isLoading = false;
          _error = profile == null ? 'Alumni profile not found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load alumni profile';
          _isLoading = false;
        });
      }
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
          _isPublicView ? 'Public Alumni Profile' : 'Alumni Profile',
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
      return _buildSkeletonLoader();
    }

    if (_error != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Error Loading Profile',
        subtitle: _error,
        customAction: ElevatedButton(
          onPressed: _loadAlumniProfile,
          child: const Text('Retry'),
        ),
      );
    }

    if (_alumniProfile == null) {
      return EmptyStateWidget(
        icon: Icons.person_off_outlined,
        title: 'Profile Not Found',
        subtitle: 'The alumni profile you\'re looking for doesn\'t exist',
        customAction: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go Back'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header card
          _buildProfileHeader(_alumniProfile!, isDark),
          const SizedBox(height: 16),

          // Professional info
          _buildProfessionalInfo(_alumniProfile!, isDark),
          const SizedBox(height: 16),

          // Academic info
          _buildAcademicInfo(_alumniProfile!, isDark),
          const SizedBox(height: 16),

          // Skills
          if (_alumniProfile!.skills?.isNotEmpty == true) ...[
            _buildSkillsSection(_alumniProfile!, isDark),
            const SizedBox(height: 16),
          ],

          // Contact information
          _buildContactInfo(_alumniProfile!, isDark),
          const SizedBox(height: 24),

          if (_publicProjection != null) ...[
            _buildPublicSnapshot(_publicProjection!, isDark),
            const SizedBox(height: 24),
          ],

          // Action buttons
          _buildActionButtons(_alumniProfile!, isDark),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(StudentProfile profile, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InitialsAvatar(name: profile.personal.effectiveDisplayName, size: 80),
          const SizedBox(height: 16),
          Text(
            profile.personal.effectiveDisplayName,
            style: AppTheme.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (profile.jobRole?.isNotEmpty == true)
            Text(
              profile.jobRole!,
              style: AppTheme.titleMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          if (profile.company?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'at ${profile.company}',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfessionalInfo(StudentProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Information',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (profile.jobRole?.isNotEmpty == true)
            _buildInfoRow(
              Icons.work_outline,
              'Position',
              profile.jobRole!,
              isDark,
            ),
          if (profile.company?.isNotEmpty == true)
            _buildInfoRow(
              Icons.business_outlined,
              'Company',
              profile.company!,
              isDark,
            ),
          if (profile.designation?.isNotEmpty == true)
            _buildInfoRow(
              Icons.badge_outlined,
              'Designation',
              profile.designation!,
              isDark,
            ),
          if (profile.careerInterest?.isNotEmpty == true)
            _buildInfoRow(
              Icons.trending_up_outlined,
              'Career Interest',
              profile.careerInterest!,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo(StudentProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Background',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (profile.academic.program.isNotEmpty)
            _buildInfoRow(
              Icons.school_outlined,
              'Program',
              profile.academic.program,
              isDark,
            ),
          if (profile.department?.isNotEmpty == true)
            _buildInfoRow(
              Icons.category_outlined,
              'Department',
              profile.department!,
              isDark,
            ),
          if (profile.graduationYear != null)
            _buildInfoRow(
              Icons.calendar_month_outlined,
              'Graduation Year',
              '${profile.graduationYear}',
              isDark,
            ),
          if (profile.academic.year > 0)
            _buildInfoRow(
              Icons.grade_outlined,
              'Year of Study',
              '${profile.academic.year}',
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(StudentProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skills & Expertise',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.skills!
                .map(
                  (skill) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      skill,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(StudentProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (profile.linkedinProfile?.isNotEmpty == true)
            _buildContactRow(
              Icons.link_outlined,
              'LinkedIn',
              profile.linkedinProfile!,
              isDark,
              onTap: () => _launchUrl(profile.linkedinProfile!),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.caption.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTheme.bodyMedium.copyWith(
                      color: onTap != null
                          ? AppTheme.primaryBlue
                          : (isDark ? Colors.white : AppTheme.gray900),
                      decoration: onTap != null
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(StudentProfile profile, bool isDark) {
    final currentUser = context.watch<ProfileProvider>().profile;
    final currentRole = context.watch<RoleProvider>().userRole;

    // Only show mentorship request for students viewing alumni profiles
    if (currentRole?.name != 'student' || currentUser?.uid == profile.uid) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _requestMentorship(profile),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.handshake_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Request Mentorship',
                    style: AppTheme.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicSnapshot(Map<String, dynamic> projection, bool isDark) {
    final experience = projection['experience'] as String?;
    final opportunitiesPosted =
        (projection['opportunitiesPosted'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withOpacity(0.3) : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Public Career Snapshot',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 12),
          if (experience != null && experience.isNotEmpty)
            _buildInfoRow(
              Icons.timeline_rounded,
              'Experience',
              experience,
              isDark,
            ),
          _buildInfoRow(
            Icons.work_history_outlined,
            'Opportunities Posted',
            '$opportunitiesPosted',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SkeletonLoader(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 120,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 100,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 80,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }

  void _requestMentorship(StudentProfile alumniProfile) {
    Navigator.pushNamed(
      context,
      createMentorshipRequestRoute,
      arguments: {'alumniProfile': alumniProfile},
    );
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Cannot open URL');
      }
    } catch (e) {
      _showError('Failed to open URL');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
