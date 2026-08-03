import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/constants/routes.dart'; // v7.3
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// MentorshipRequestsView — shared mentorship list used by students and alumni.
///
/// Role-aware:
/// - **Student**: shows requests the student sent to alumni, with the
///   "+ Request Mentorship" action (empty state CTA → alumni directory).
/// - **Alumni**: shows requests students sent to them (all statuses), with
///   Accept/Decline buttons on pending ones, and NO "request" affordance —
///   alumni are the mentors, not the requester. Card headers show the
///   requesting student instead of the alumni's own name.
class MentorshipRequestsView extends StatefulWidget {
  const MentorshipRequestsView({super.key});

  @override
  State<MentorshipRequestsView> createState() => _MentorshipRequestsViewState();
}

class _MentorshipRequestsViewState extends State<MentorshipRequestsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMentorshipProvider();
    });
  }

  void _initializeMentorshipProvider() async {
    final profileProvider = context.read<ProfileProvider>();
    final roleProvider = context.read<RoleProvider>();

    if (profileProvider.profile != null && roleProvider.userRole != null) {
      await context.read<MentorshipProvider>().initWithUser(
        profileProvider.profile!.uid,
        roleProvider.userRole!.name,
      );
    }
  }

  bool get _isAlumni =>
      context.read<RoleProvider>().userRole == UserRole.alumni;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mentorship Requests',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 20,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          // Only students request mentorship — alumni receive requests and
          // should not get a "Request Mentorship" action (that routes to the
          // alumni directory, which makes no sense for an alumni).
          if (!_isAlumni)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _createNewRequest,
              tooltip: 'Request Mentorship',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<MentorshipProvider>(
        builder: (context, mentorshipProvider, child) {
          return _buildRequestsList(mentorshipProvider, isDark);
        },
      ),
    );
  }

  Widget _buildRequestsList(
    MentorshipProvider mentorshipProvider,
    bool isDark,
  ) {
    if (mentorshipProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (mentorshipProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading requests',
              style: AppTheme.titleMedium.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mentorshipProvider.error!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshRequests,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final requests = mentorshipProvider.requests;

    if (requests == null || requests.isEmpty) {
      // Alumni are the mentors — they never "request" mentorship, so the
      // empty state only shows the request CTA for students.
      if (_isAlumni) {
        return const EmptyStateWidget(
          icon: Icons.school_outlined,
          title: 'No mentorship requests yet',
          subtitle: 'When students request your mentorship, their requests '
              'will appear here for you to review.',
        );
      }
      return EmptyStateWidget(
        icon: Icons.school_outlined,
        title: 'No mentorship requests yet',
        subtitle: 'Connect with alumni for career guidance and advice',
        customAction: ElevatedButton.icon(
          onPressed: _createNewRequest,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Request Mentorship'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, isDark);
      },
    );
  }

  Widget _buildRequestCard(MentorshipRequest request, bool isDark) {
    // Alumni view the requests students sent to them, so the header must show
    // the requesting STUDENT. Students view the requests they sent, so the
    // header shows the alumni they asked.
    final isAlumni = _isAlumni;
    final headerName = isAlumni ? request.studentName : request.alumniName;
    final headerSubtitle = isAlumni
        ? request.studentEmail
        : (request.alumniCompany ?? request.alumniJobRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray700.withValues(alpha: 0.3) : AppTheme.gray200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with requesting profile info and status
            Row(
              children: [
                InitialsAvatar(name: headerName, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerName,
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                      if (headerSubtitle != null && headerSubtitle.isNotEmpty)
                        Text(
                          headerSubtitle,
                          style: AppTheme.caption.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.statusDisplay,
                    style: AppTheme.caption.copyWith(
                      color: _getStatusColor(request.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request title
            Text(
              request.title,
              style: AppTheme.titleSmall.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),

            // Request description (truncated)
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 12),

            // Skills tags
            if (request.skills.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: request.skills
                    .take(3)
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          skill,
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Footer with timestamp
            Text(
              'Sent ${request.timeSince}',
              style: AppTheme.caption.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),

            // Action buttons for pending requests (Alumni only)
            if (_shouldShowActionButtons(request))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _respondToRequest(request.id, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.error),
                          foregroundColor: AppTheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _respondToRequest(request.id, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),

            // v7.3: Open Chat button for accepted requests
            if (request.isAccepted && request.chatId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      chatRoute,
                      arguments: request.chatId,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.chat_bubble, size: 18),
                    label: const Text('Open Chat'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowActionButtons(MentorshipRequest request) {
    final roleProvider = context.read<RoleProvider>();
    return roleProvider.userRole == UserRole.alumni &&
        request.status == MentorshipRequestStatus.pending;
  }

  Future<void> _respondToRequest(String requestId, bool accepted) async {
    final mentorshipProvider = context.read<MentorshipProvider>();

    try {
      final chatId = await mentorshipProvider.respondToRequest(
        requestId: requestId,
        accepted: accepted,
        responseMessage: accepted
            ? 'Request accepted!'
            : 'Thank you for your interest.',
      );

      if (chatId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted ? 'Mentorship request accepted!' : 'Request declined',
            ),
            backgroundColor: accepted ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to request: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Color _getStatusColor(MentorshipRequestStatus status) {
    switch (status) {
      case MentorshipRequestStatus.pending:
        return Colors.orange;
      case MentorshipRequestStatus.accepted:
        return AppTheme.success;
      case MentorshipRequestStatus.rejected:
        return AppTheme.error;
      case MentorshipRequestStatus.completed:
        return AppTheme.primaryBlue;
    }
  }

  void _refreshRequests() async {
    await context.read<MentorshipProvider>().refresh();
  }

  void _createNewRequest() {
    // Navigate to alumni directory to select an alumni for mentorship
    Navigator.pushNamed(context, alumniDirectoryRoute);
  }
}
