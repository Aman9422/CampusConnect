import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// OpportunityDetailView - v7.2: Multi-role ecosystem
///
/// Detailed view for a specific job opportunity.
/// Students can apply directly from this view.
class OpportunityDetailView extends StatefulWidget {
  const OpportunityDetailView({super.key});

  @override
  State<OpportunityDetailView> createState() => _OpportunityDetailViewState();
}

class _OpportunityDetailViewState extends State<OpportunityDetailView> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final opportunity = arguments?['opportunity'] as Opportunity?;

    if (opportunity == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          title: Text(
            'Opportunity Details',
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
        body: const Center(child: Text('Error: No opportunity data found')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Opportunity Details',
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
            // Company and Title
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
                    opportunity.title,
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opportunity.company,
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        opportunity.location,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.work_outline,
                        size: 16,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        opportunity.jobType,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                        ),
                      ),
                    ],
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
                    opportunity.description,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Requirements
            if (opportunity.requirements.isNotEmpty) ...[
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
                      'Requirements',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...opportunity.requirements.map((requirement) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                requirement,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.gray300
                                      : AppTheme.gray700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Contact Information
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
                    'Contact Information',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Posted by: ${opportunity.alumniName}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                    ),
                  ),
                  if (opportunity.contactEmail?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Email: ${opportunity.contactEmail}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Apply Button (for students only)
            Consumer<RoleProvider>(
              builder: (context, roleProvider, child) {
                if (roleProvider.userRole == UserRole.student && !opportunity.isExpired) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _applyForJob(opportunity),
                      icon: Icon(opportunity.applicationUrl != null
                          ? Icons.work_outline
                          : Icons.contact_mail),
                      label: Text(opportunity.applicationUrl != null
                          ? 'Apply Now'
                          : 'Contact to Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyForJob(Opportunity opportunity) async {
    if (opportunity.applicationUrl == null) {
      // Show contact information when no application URL is available
      _showContactDialog(opportunity);
      return;
    }

    try {
      final uri = Uri.parse(opportunity.applicationUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opening application portal...', isError: false);
      } else {
        _showSnackBar('Could not open application link', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening application: $e', isError: true);
    }
  }

  void _showContactDialog(Opportunity opportunity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact for Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To apply for "${opportunity.title}" at ${opportunity.company}, please contact:',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    opportunity.alumniName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (opportunity.contactEmail != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(opportunity.contactEmail!),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'You can reach out directly to learn more about the position and application process.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (opportunity.contactEmail != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final subject = Uri.encodeComponent('Application for ${opportunity.title}');
                final body = Uri.encodeComponent(
                  'Hi ${opportunity.alumniName},\n\nI am interested in applying for the ${opportunity.title} position at ${opportunity.company}. Could you please provide more information about the application process?\n\nThank you,\n[Your Name]'
                );
                final uri = Uri.parse('mailto:${opportunity.contactEmail}?subject=$subject&body=$body');
                launchUrl(uri);
              },
              child: const Text('Send Email'),
            ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.error : AppTheme.success,
        ),
      );
    }
  }
}
