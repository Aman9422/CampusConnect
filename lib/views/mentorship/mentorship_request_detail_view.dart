import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/mentorship_request.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// MentorshipRequestDetailView - v7.2: Multi-role ecosystem
///
/// Detailed view for a specific mentorship request.
/// Alumni can accept/reject pending requests.
class MentorshipRequestDetailView extends StatefulWidget {
  const MentorshipRequestDetailView({super.key});

  @override
  State<MentorshipRequestDetailView> createState() => _MentorshipRequestDetailViewState();
}

class _MentorshipRequestDetailViewState extends State<MentorshipRequestDetailView> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final request = arguments?['request'] as MentorshipRequest?;

    if (request == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          title: Text(
            'Request Details',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppTheme.gray900,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Error: No request data found')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Mentorship Request',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'From: ${request.studentName}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Created: ${_formatDate(request.createdAt)}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      request.status.toString().split('.').last.toUpperCase(),
                      style: AppTheme.bodySmall.copyWith(
                        color: _getStatusColor(request.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    request.description,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Skills
            if (request.skills.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills Requested',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: request.skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            skill,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Response (if responded)
            if (request.responseMessage?.isNotEmpty == true) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.gray600 : AppTheme.gray300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alumni Response',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray900,
                      ),
                    ),
                    if (request.respondedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Responded: ${_formatDate(request.respondedAt!)}',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      request.responseMessage!,
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons (for alumni with pending requests)
            if (request.status == MentorshipRequestStatus.pending) ...[
              Consumer<RoleProvider>(
                builder: (context, roleProvider, child) {
                  if (roleProvider.userRole == UserRole.alumni) {
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respondToRequest(request.id, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.error),
                              foregroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respondToRequest(String requestId, bool accepted) async {
    final mentorshipProvider = context.read<MentorshipProvider>();

    try {
      final success = await mentorshipProvider.respondToRequest(
        requestId: requestId,
        accepted: accepted,
        responseMessage: accepted ? 'Request accepted!' : 'Thank you for your interest.',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accepted ? 'Mentorship request accepted!' : 'Request declined'),
            backgroundColor: accepted ? AppTheme.success : AppTheme.error,
          ),
        );
        // Go back to refresh the list
        Navigator.pop(context);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Color _getStatusColor(MentorshipRequestStatus status) {
    switch (status) {
      case MentorshipRequestStatus.pending:
        return Colors.orange;
      case MentorshipRequestStatus.accepted:
        return Colors.green;
      case MentorshipRequestStatus.rejected:
        return Colors.red;
      case MentorshipRequestStatus.completed:
        return AppTheme.primaryBlue;
    }
  }
}
