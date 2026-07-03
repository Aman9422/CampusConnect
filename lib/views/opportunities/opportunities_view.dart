import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/models/opportunity.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/empty_state_widget.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// OpportunitiesView - Students can browse job opportunities shared by alumni
class OpportunitiesView extends StatefulWidget {
  const OpportunitiesView({super.key});

  @override
  State<OpportunitiesView> createState() => _OpportunitiesViewState();
}

class _OpportunitiesViewState extends State<OpportunitiesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOpportunityProvider();
    });
  }

  void _initializeOpportunityProvider() async {
    final profileProvider = context.read<ProfileProvider>();
    final roleProvider = context.read<RoleProvider>();

    if (profileProvider.profile != null && roleProvider.userRole != null) {
      await context.read<OpportunityProvider>().initWithUser(
        profileProvider.profile!.uid,
        roleProvider.userRole!.name,
      );
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
          'Job Opportunities',
          style: AppTheme.titleLarge.copyWith(
            fontSize: 20,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilters,
            tooltip: 'Filter Opportunities',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshOpportunities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<OpportunityProvider>(
        builder: (context, opportunityProvider, child) {
          return _buildOpportunitiesList(opportunityProvider, isDark);
        },
      ),
      floatingActionButton: _buildCreateOpportunityFAB(isDark),
    );
  }

  Widget _buildOpportunitiesList(OpportunityProvider opportunityProvider, bool isDark) {
    if (opportunityProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (opportunityProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading opportunities',
              style: AppTheme.titleMedium.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opportunityProvider.error!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshOpportunities,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final opportunities = opportunityProvider.opportunities;

    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        if (opportunities == null || opportunities.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.work_outline,
            title: 'No opportunities available',
            subtitle: roleProvider.userRole == UserRole.alumni
                ? 'Share job opportunities with students by posting them here'
                : 'Job opportunities shared by alumni will appear here',
            customAction: roleProvider.userRole == UserRole.alumni
                ? ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, createOpportunityRoute),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Post First Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _refreshOpportunities,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: opportunities.length,
          itemBuilder: (context, index) {
            final opportunity = opportunities[index];
            return _buildOpportunityCard(opportunity, isDark, roleProvider.userRole);
          },
        );
      },
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity, bool isDark, UserRole? userRole) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            // Header with company info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business_center,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.title,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opportunity.company,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray300 : AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    opportunity.jobTypeDisplay,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location and salary
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                const SizedBox(width: 4),
                Text(
                  opportunity.location,
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                ),
                if (opportunity.salaryRange != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                  Text(
                    opportunity.salaryRange!,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Description (truncated)
            Text(
              opportunity.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray300 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 12),

            // Skills tags
            if (opportunity.skills.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: opportunity.skills.take(4).map((skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Footer with posted time and alumni info
            Row(
              children: [
                InitialsAvatar(name: opportunity.alumniName, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Posted by ${opportunity.alumniName}',
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
                const Spacer(),
                Text(
                  opportunity.timeSince,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
              ],
            ),

            // Deadline warning if applicable
            if (opportunity.timeUntilDeadline != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: opportunity.isExpired
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opportunity.isExpired ? Icons.schedule : Icons.access_time,
                      size: 12,
                      color: opportunity.isExpired ? AppTheme.error : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      opportunity.timeUntilDeadline!,
                      style: AppTheme.caption.copyWith(
                        color: opportunity.isExpired ? AppTheme.error : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Apply Now button for students
            if (_shouldShowApplyButton(opportunity, userRole))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildCreateOpportunityFAB(bool isDark) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        // Only show FAB for alumni
        if (roleProvider.userRole != UserRole.alumni) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, createOpportunityRoute);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Post Job'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        );
      },
    );
  }

  bool _shouldShowApplyButton(Opportunity opportunity, UserRole? userRole) {
    // Show apply button for students on non-expired jobs
    return userRole == UserRole.student && !opportunity.isExpired;
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
        title: Text('Contact for Application'),
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<OpportunityProvider>(
        builder: (context, provider, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Opportunities',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (provider.companiesList.isNotEmpty) ...[
                  Text(
                    'Company',
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    value: provider.selectedCompany,
                    hint: const Text('Select Company'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Companies'),
                      ),
                      ...provider.companiesList.map((company) =>
                        DropdownMenuItem<String?>(
                          value: company,
                          child: Text(company),
                        ),
                      ),
                    ],
                    onChanged: (value) => provider.filterByCompany(value),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Job Type',
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: provider.selectedJobType,
                  hint: const Text('Select Job Type'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    ...provider.jobTypesList.map((jobType) =>
                      DropdownMenuItem<String?>(
                        value: jobType,
                        child: Text(jobType),
                      ),
                    ),
                  ],
                  onChanged: (value) => provider.filterByJobType(value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          provider.clearFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear Filters'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _refreshOpportunities() async {
    await context.read<OpportunityProvider>().refresh();
  }
}