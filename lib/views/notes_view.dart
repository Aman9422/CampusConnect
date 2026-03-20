import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/menu_action.dart';
import 'package:campusconnect/models/chat_message.dart';
import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart'; // v6.7
import 'package:campusconnect/providers/role_provider.dart'; // v7.1
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:campusconnect/views/widgets/eligibility_badge.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:campusconnect/views/widgets/notification_badge.dart';
import 'package:campusconnect/widgets/empty_state.dart';
import 'package:campusconnect/widgets/home_widgets.dart';
import 'package:campusconnect/widgets/offline_banner.dart';
import 'package:campusconnect/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  int _selectedIndex = 0;
  final NotesService _notesService = NotesService.instance();
  final AIService _aiService = AIService.instance();

  // Chat state
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isLoadingAIResponse = false;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          _buildNotesScreen(),
          _buildPlacementsScreen(),
          _buildChatScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppTheme.gray700
                  : AppTheme.gray200.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: isDark ? AppTheme.gray400 : AppTheme.gray500,
          selectedLabelStyle: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTheme.caption,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.note_outlined),
              activeIcon: Icon(Icons.note),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Placements',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school,
              color: isDark ? Colors.white : AppTheme.gray900,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Student Dashboard',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
          ],
        ),
        actions: [
          // V6.4: Notification badge
          NotificationBadge(
            onTap: () => Navigator.pushNamed(context, notificationsRoute),
          ),
          PopupMenuButton<MenuAction>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? AppTheme.gray400 : AppTheme.gray700,
            ),
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await _showLogOutDialog();
                  if (shouldLogout && mounted) {
                    // CRITICAL: Reset all providers BEFORE logout to prevent data leakage
                    context.read<ProfileProvider>().reset();
                    context.read<PlacementsProvider>().reset();
                    context.read<AIUsageProvider>().reset();
                    context.read<NotificationsProvider>().reset();
                    context.read<ResumeReviewProvider>().reset(); // v6.7
                    context.read<RoleProvider>().reset(); // v7.1
                    try {
                      await AuthService.firebase().logOut();
                    } catch (_) {
                      // AuthGuard will handle the state
                    }
                    // AuthGuard handles navigation via StreamBuilder
                  }
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<MenuAction>(
                  value: MenuAction.logout,
                  child: Text('Log out'),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(layout.cardPadding + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Welcome back!',
              style: AppTheme.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              DateFormat('EEEE, d/M/yyyy').format(DateTime.now()),
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            SizedBox(height: layout.itemSpacing + 8),

            // Featured Event Card
            const FeaturedCard(),
            SizedBox(height: layout.itemSpacing + 8),

            // Today / This Week Section
            _buildTodaySection(),
            SizedBox(height: layout.itemSpacing + 8),

            // v7.2: Quick Access Cards for Multi-Role Ecosystem
            _buildQuickAccessSection(),
            SizedBox(height: layout.itemSpacing + 8),

            // Latest Placements Section
            Text(
              'Latest Placements',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Consumer<PlacementsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && !provider.isInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(child: Text('Error: ${provider.error}'));
                }

                // v6.5: Use sorted placements (eligible first)
                final placements = provider.sortedPlacements;
                if (placements.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No placements available'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: placements.length.clamp(0, 2),
                  itemBuilder: (context, index) {
                    final placement = placements[index];
                    final eligibility = provider.getEligibility(placement.id);
                    return _buildPlacementCard(placement, eligibility);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today / This Week',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
              width: 1,
            ),
            boxShadow: isDark ? null : AppTheme.shadowSmall,
          ),
          child: Column(
            children: [
              _buildTodayItem(
                icon: Icons.event_available,
                iconColor: AppTheme.error,
                title: 'Placement deadline approaching',
                subtitle: 'Google - Apply by March 15',
                onTap: () {
                  //  Navigate to placements screen
                  setState(() => _selectedIndex = 2);
                },
              ),
              _buildDivider(),
              _buildTodayItem(
                icon: Icons.description,
                iconColor: AppTheme.primaryBlue,
                title: 'New lecture notes uploaded',
                subtitle: 'Data Structures - Unit 3',
                onTap: () {
                  // Navigate to notes screen
                  setState(() => _selectedIndex = 1);
                },
              ),
              _buildDivider(),
              _buildTodayItem(
                icon: Icons.check_circle,
                iconColor: AppTheme.success,
                title: 'You applied to NVIDIA',
                subtitle: 'Application submitted 2 days ago',
                onTap: () {
                  // Navigate to placements screen
                  setState(() => _selectedIndex = 2);
                },
              ),
              _buildDivider(),
              _buildTodayItem(
                icon: Icons.chat_bubble,
                iconColor: Color(0xFF7C3AED),
                title: 'Ask CampusConnect AI for guidance',
                subtitle: 'Get help with your career',
                onTap: () {
                  setState(() => _selectedIndex = 3);
                },
              ),
              _buildDivider(),
              // v6.7: Resume Review entry
              _buildTodayItem(
                icon: Icons.auto_awesome,
                iconColor: AppTheme.success,
                title: 'AI Resume Review',
                subtitle: 'Get ATS score & improvement tips',
                onTap: () {
                  Navigator.of(context).pushNamed(resumeReviewRoute);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.cardPadding,
          vertical: layout.listItemPadding - 4,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(layout.isCompact ? 6 : 8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: layout.isCompact ? 18 : 20,
              ),
            ),
            SizedBox(width: layout.itemSpacing - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.gray400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      height: 1,
      color: isDark ? AppTheme.gray700 : AppTheme.gray200,
    );
  }

  Widget _buildNotesScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Lecture Notes',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _notesService.getAllNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notes available yet'),
                ],
              ),
            );
          }

          final layout = context.watch<LayoutProvider>();

          return ListView.builder(
            padding: EdgeInsets.all(layout.cardPadding),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _buildNoteCard(note);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return Card(
      margin: EdgeInsets.only(bottom: layout.itemSpacing - 4),
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(layout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.gray900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.itemSpacing - 4),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.1),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    note.subject,
                    style: AppTheme.label.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successBg,
                        AppTheme.successBg.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Year: ${note.year}',
                    style: AppTheme.label.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Uploaded: ${DateFormat('MMM dd, yyyy').format(note.uploadedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (note.downloadUrl != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await _handleNoteDownload(note.downloadUrl!);
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementsScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Placements',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<PlacementsProvider>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<PlacementsProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // V5.1: Offline banner
              OfflineBanner(isOffline: !provider.isOnline),

              // Content
              Expanded(child: _buildPlacementsContent(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlacementsContent(PlacementsProvider provider) {
    // Show skeleton loaders while initializing
    if (provider.isLoading && !provider.isInitialized) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const PlacementCardSkeleton(),
      );
    }

    // Show error state
    if (provider.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error loading placements',
        subtitle: provider.error!,
        action: ElevatedButton.icon(
          onPressed: () => provider.refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    // v6.5: Use sorted placements (eligible first)
    final placements = provider.sortedPlacements;
    final eligiblePlacements = provider.eligiblePlacements;

    // Show empty state
    if (placements.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'No placements available',
        subtitle: 'New opportunities will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: placements.length + (eligiblePlacements.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // v6.5: Show "Recommended for You" header before eligible placements
          if (eligiblePlacements.isNotEmpty && index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecommendedHeader(eligiblePlacements.length),
                const SizedBox(height: AppTheme.space8),
              ],
            );
          }

          // Adjust index for header
          final placementIndex = eligiblePlacements.isNotEmpty
              ? index - 1
              : index;
          final placement = placements[placementIndex];
          final eligibility = provider.getEligibility(placement.id);
          return _buildPlacementCard(placement, eligibility);
        },
      ),
    );
  }

  /// v6.5: Recommended section header
  Widget _buildRecommendedHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.primaryBlue.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: AppTheme.space8),
          Text(
            'Recommended for You',
            style: AppTheme.titleSmall.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$count eligible',
              style: AppTheme.caption.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v6.5: Updated to accept eligibility parameter
  Widget _buildPlacementCard(
    Placement placement,
    PlacementEligibility? eligibility,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return Card(
      margin: EdgeInsets.only(bottom: layout.itemSpacing),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkSurface, AppTheme.primaryBlue.withOpacity(0.05)]
                : [Colors.white, AppTheme.primaryBlue.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(layout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          placement.company,
                          style: AppTheme.titleMedium.copyWith(
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          placement.role,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge (Open/Closed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space12,
                          vertical: AppTheme.space4,
                        ),
                        decoration: BoxDecoration(
                          gradient: placement.isDeadlinePassed
                              ? LinearGradient(
                                  colors: [
                                    AppTheme.errorBg,
                                    AppTheme.errorBg.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    AppTheme.successBg,
                                    AppTheme.successBg.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: placement.isDeadlinePassed
                                ? AppTheme.error.withOpacity(0.3)
                                : AppTheme.success.withOpacity(0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: placement.isDeadlinePassed
                                  ? AppTheme.error.withOpacity(0.15)
                                  : AppTheme.success.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          placement.isDeadlinePassed ? 'Closed' : 'Open',
                          style: AppTheme.label.copyWith(
                            color: placement.isDeadlinePassed
                                ? AppTheme.error
                                : AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // v6.5: Eligibility badge
                      if (eligibility != null &&
                          !placement.isDeadlinePassed) ...[
                        const SizedBox(height: AppTheme.space8),
                        EligibilityBadge(
                          eligibility: eligibility,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                placement.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: isDark ? AppTheme.gray400 : AppTheme.gray700,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            size: 14,
                            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            placement.salary,
                            style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.gray800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            'Deadline: ${DateFormat('MMM dd, yyyy').format(placement.deadline)}',
                            style: AppTheme.caption.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!placement.isDeadlinePassed)
                    _buildApplyButton(
                      placement.id,
                      placement.company,
                      placement.role,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton(String placementId, String company, String role) {
    return Consumer<PlacementsProvider>(
      builder: (context, provider, child) {
        final hasApplied = provider.hasApplied(placementId);
        final isApplying = provider.isApplying(placementId);
        final appliedDate = provider.getAppliedDate(placementId);
        final isOffline = !provider.isOnline;
        final anyApplyInProgress = provider.isAnyApplyInProgress;

        // Show "Applied" chip with date
        if (hasApplied && !isApplying) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space12,
              vertical: AppTheme.space8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.12),
                  AppTheme.primaryBlue.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  appliedDate != null
                      ? 'Applied • ${DateFormat('MMM dd').format(appliedDate)}'
                      : 'Applied',
                  style: AppTheme.label.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }

        // Show loading button while applying
        if (isApplying) {
          return ElevatedButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            label: Text(
              'Applying...',
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          );
        }

        // V5.1: Disable button if offline or another apply is in progress
        final isDisabled = isOffline || anyApplyInProgress;

        // Show apply button
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlue.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled
                  ? null
                  : () => _showApplyDialog(placementId, company, role),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space20,
                  vertical: AppTheme.space12,
                ),
                child: Text(
                  isOffline ? 'Offline' : 'Apply',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showApplyDialog(String placementId, String company, String role) {
    // Capture the provider before showing the dialog
    final provider = context.read<PlacementsProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) =>
          ChangeNotifierProvider<PlacementsProvider>.value(
            value: provider,
            child: _ApplyDialogWidget(
              placementId: placementId,
              company: company,
              role: role,
            ),
          ),
    );
  }

  Future<void> _handleNoteDownload(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening note')));
      }
    }
  }

  Widget _buildChatScreen() {
    final aiProvider = context.watch<AIUsageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          onPressed: () {
            setState(() => _selectedIndex = 0);
          },
        ),
        title: Text(
          'CampusConnect AI',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ),
      body: Column(
        children: [
          // V5.1.x: Offline banner for AI chat
          OfflineBanner(isOffline: !aiProvider.isOnline),
          // v6.0: Modern trial warning banner
          if (aiProvider.isInTrial && aiProvider.daysRemainingInTrial <= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
              decoration: AppTheme.bannerDecoration(AppTheme.warningBg),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 18,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      aiProvider.daysRemainingInTrial == 1
                          ? 'AI trial expires tomorrow!'
                          : 'AI trial expires in ${aiProvider.daysRemainingInTrial} days',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.gray800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _chatMessages.isEmpty
                ? _buildEmptyChatState()
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      return _buildChatBubble(_chatMessages[index]);
                    },
                  ),
          ),
          if (_isLoadingAIResponse) _buildLoadingIndicator(),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.shadowColored,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Text(
              'CampusConnect AI',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Your personal AI mentor for academics and career guidance',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space32),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              alignment: WrapAlignment.center,
              children: [
                // v6.5: Smart suggestion that uses eligibility engine
                _buildSuggestionChip('Which placements am I eligible for?'),
                _buildSuggestionChip('How to prepare for placements?'),
                _buildSuggestionChip('Study tips for exams'),
                _buildSuggestionChip('Resume help'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _handleSendMessage(text),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
            width: 1,
          ),
          boxShadow: isDark ? null : AppTheme.shadowSmall,
        ),
        child: Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? Colors.white : AppTheme.gray700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.space12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: message.isUserMessage ? AppTheme.primaryGradient : null,
          color: message.isUserMessage ? null : AppTheme.gray100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusLarge),
            topRight: const Radius.circular(AppTheme.radiusLarge),
            bottomLeft: Radius.circular(
              message.isUserMessage ? AppTheme.radiusLarge : AppTheme.space4,
            ),
            bottomRight: Radius.circular(
              message.isUserMessage ? AppTheme.space4 : AppTheme.radiusLarge,
            ),
          ),
          boxShadow: message.isUserMessage
              ? AppTheme.shadowColored
              : AppTheme.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: AppTheme.bodyMedium.copyWith(
                color: message.isUserMessage ? Colors.white : AppTheme.gray900,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: AppTheme.caption.copyWith(
                color: message.isUserMessage
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Text(
            'AI is thinking...',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.gray600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiProvider = context.watch<AIUsageProvider>();
    final isDisabled =
        _isLoadingAIResponse ||
        !aiProvider.isOnline ||
        aiProvider.hasReachedLimit;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            width: 1,
          ),
        ),
        boxShadow: isDark ? null : AppTheme.shadowSmall,
      ),
      child: Row(
        children: [
          // v6.7: Resume Review quick access button
          Tooltip(
            message: 'AI Resume Review',
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(resumeReviewRoute);
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.gray800 : AppTheme.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.success,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: TextField(
              controller: _chatController,
              enabled: !isDisabled,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
              decoration: InputDecoration(
                hintText: !aiProvider.isOnline
                    ? 'Offline - connect to send messages'
                    : aiProvider.hasReachedLimit
                    ? 'Daily limit reached'
                    : 'Ask me anything...',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.gray800 : AppTheme.gray50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(color: AppTheme.gray200),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(_chatController.text),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Container(
            decoration: BoxDecoration(
              color: isDisabled ? AppTheme.gray300 : AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isDisabled
                  ? null
                  : () => _handleSendMessage(_chatController.text),
              icon: Icon(
                Icons.send_rounded,
                color: isDisabled ? AppTheme.gray600 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || _isLoadingAIResponse) return;

    final userId = AuthService.firebase().currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    // V5.1.x: Network pre-flight guard
    final aiProvider = context.read<AIUsageProvider>();
    if (!aiProvider.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're offline. Please reconnect and try again."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Clear input
    _chatController.clear();

    // Add user message
    setState(() {
      _chatMessages.add(ChatMessage.user(message));
      _isLoadingAIResponse = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    // v6.5: Check if this is an eligibility-related question
    final eligibilityResponse = _handleEligibilityQuestion(message);
    if (eligibilityResponse != null) {
      // Answer from v6.5 intelligence - no AI call needed!
      setState(() {
        _chatMessages.add(ChatMessage.ai(eligibilityResponse));
        _isLoadingAIResponse = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      // Call AI service (VERSION 4: Returns AIResponse with metadata)
      final aiResponse = await _aiService.sendMessage(
        userId: userId,
        message: message,
      );

      // Add AI response
      setState(() {
        _chatMessages.add(ChatMessage.ai(aiResponse.message));
        _isLoadingAIResponse = false;
      });

      // VERSION 4: Update provider with latest usage info
      if (aiResponse.trial != null) {
        aiProvider.updateTrialInfo(
          isInTrial: aiResponse.trial!.isActive,
          daysRemaining: aiResponse.trial!.daysRemaining,
        );
      }

      if (aiResponse.usage != null) {
        aiProvider.updateUsageInfo(
          messagesUsed: aiResponse.usage!.dailyCount,
          dailyLimit: aiResponse.usage!.dailyLimit,
        );
      }

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      // V5.1.x: User-friendly error translation
      final friendlyError = ErrorMessages.getUserFriendlyMessage(e);

      setState(() {
        _chatMessages.add(
          ChatMessage.ai(
            'Sorry, I couldn\'t process your message.\n\n$friendlyError',
          ),
        );
        _isLoadingAIResponse = false;
      });
      _scrollToBottom();

      debugPrint('AI Chat error: $e');
    }
  }

  /// v6.5: Detect eligibility-related questions and answer from v6.5 intelligence
  String? _handleEligibilityQuestion(String message) {
    final lowerMessage = message.toLowerCase();

    // Detect eligibility intent
    final isEligibilityQuestion =
        lowerMessage.contains('eligible') ||
        lowerMessage.contains('eligibility') ||
        lowerMessage.contains('can i apply') ||
        lowerMessage.contains('qualify') ||
        (lowerMessage.contains('which') &&
            lowerMessage.contains('placement')) ||
        (lowerMessage.contains('what') &&
            lowerMessage.contains('placement') &&
            lowerMessage.contains('for me'));

    if (!isEligibilityQuestion) {
      return null; // Not an eligibility question, let AI handle it
    }

    // Get data from v6.5 intelligence
    final placementsProvider = context.read<PlacementsProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return "I couldn't find your profile. Please complete your profile setup first to check placement eligibility.";
    }

    final eligiblePlacements = placementsProvider.eligiblePlacements;
    final allPlacements = placementsProvider.placements;

    if (allPlacements.isEmpty) {
      return "There are no active placements available right now. Check back later for new opportunities!";
    }

    if (eligiblePlacements.isEmpty) {
      // Build helpful response explaining why
      final buffer = StringBuffer();
      buffer.writeln(
        "Based on your profile, you're currently not eligible for any active placements.\n",
      );
      buffer.writeln("📋 Your Profile:");
      buffer.writeln("• Program: ${profile.academic.program}");
      buffer.writeln("• Year: ${profile.academic.year}");
      buffer.writeln("• CGPA: ${profile.academic.cgpa.toStringAsFixed(2)}\n");
      buffer.writeln("💡 Tips to unlock more opportunities:");
      buffer.writeln("• Keep improving your CGPA");
      buffer.writeln("• Build skills in high-demand areas");
      buffer.writeln("• Update your profile regularly\n");
      buffer.writeln(
        "Check the Placements tab to see all opportunities and their requirements.",
      );
      return buffer.toString();
    }

    // Build personalized response with eligible placements
    final buffer = StringBuffer();
    buffer.writeln(
      "🎯 Great news! Based on your profile, you're eligible for ${eligiblePlacements.length} placement${eligiblePlacements.length > 1 ? 's' : ''}:\n",
    );

    for (int i = 0; i < eligiblePlacements.length && i < 5; i++) {
      final placement = eligiblePlacements[i];
      final daysUntilDeadline = placement.deadline
          .difference(DateTime.now())
          .inDays;

      buffer.writeln("${i + 1}. ${placement.company} - ${placement.role}");
      buffer.writeln("   💰 ${placement.salary}");
      if (daysUntilDeadline <= 7) {
        buffer.writeln(
          "   ⚠️ Deadline: ${daysUntilDeadline} day${daysUntilDeadline != 1 ? 's' : ''} left!",
        );
      } else {
        buffer.writeln(
          "   📅 Deadline: ${DateFormat('MMM dd, yyyy').format(placement.deadline)}",
        );
      }
      buffer.writeln("");
    }

    if (eligiblePlacements.length > 5) {
      buffer.writeln("...and ${eligiblePlacements.length - 5} more!\n");
    }

    buffer.writeln("📋 Your Profile:");
    buffer.writeln("• Program: ${profile.academic.program}");
    buffer.writeln("• Year: ${profile.academic.year}");
    buffer.writeln("• CGPA: ${profile.academic.cgpa.toStringAsFixed(2)}\n");

    buffer.writeln("👉 Go to the Placements tab to apply!");

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // V5.1.2: Trial and usage warnings now shown via banner in chat screen (removed snackbar methods)

  Widget _buildProfileScreen() {
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
                _buildProfileInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: profile?.personal.email ?? 'Not set',
                ),
                _buildProfileInfoTile(
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
                _buildProfileInfoTile(
                  icon: Icons.school_outlined,
                  title: 'Program',
                  value: (profile?.academic.program.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.academic.program,
                ),
                _buildProfileInfoTile(
                  icon: Icons.business_outlined,
                  title: 'College',
                  value: (profile?.academic.college.isEmpty ?? true)
                      ? 'Not set'
                      : profile!.academic.college,
                ),
                _buildProfileInfoTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Year',
                  value:
                      (profile?.academic.year == null ||
                          profile!.academic.year == 0)
                      ? 'Not set'
                      : 'Year ${profile.academic.year}',
                ),
                _buildProfileInfoTile(
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
                _buildProfileMenuCard(
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
                        'v6.0.0',
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
                    onPressed: () => _handleProfileLogout(),
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

  Widget _buildProfileMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return Container(
      margin: EdgeInsets.only(bottom: layout.itemSpacing - 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: layout.cardPadding,
          vertical: layout.isCompact ? 4 : 8,
        ),
        leading: Container(
          padding: EdgeInsets.all(layout.isCompact ? 6 : 8),
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

  /// Display-only info tile (no tap action)
  Widget _buildProfileInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = context.watch<LayoutProvider>();

    return Container(
      margin: EdgeInsets.only(bottom: layout.isCompact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: layout.cardPadding,
        vertical: layout.listItemPadding - 4,
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
            padding: EdgeInsets.all(layout.isCompact ? 6 : 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800 : AppTheme.gray100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              size: layout.isCompact ? 16 : 18,
            ),
          ),
          SizedBox(width: layout.itemSpacing - 4),
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

  Future<void> _handleProfileLogout() async {
    final shouldLogout = await _showLogOutDialog();
    if (shouldLogout && mounted) {
      // CRITICAL: Reset all providers BEFORE logout to prevent data leakage
      context.read<ProfileProvider>().reset();
      context.read<PlacementsProvider>().reset();
      context.read<AIUsageProvider>().reset();
      context.read<NotificationsProvider>().reset();
      context.read<ResumeReviewProvider>().reset(); // v6.7
      context.read<RoleProvider>().reset(); // v7.1
      try {
        await AuthService.firebase().logOut();
      } catch (_) {
        // AuthGuard will handle the state
      }
      // AuthGuard handles navigation via StreamBuilder
    }
  }

  Future<bool> _showLogOutDialog() {
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

  // v7.2: Connect & Grow Section - Full feature set
  Widget _buildQuickAccessSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect & Grow',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        // First row
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                title: 'Alumni Directory',
                subtitle: 'Connect with alumni',
                icon: Icons.people,
                onTap: () {
                  Navigator.pushNamed(context, alumniDirectoryRoute);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(
                title: 'Mentorships',
                subtitle: 'Request mentorship',
                icon: Icons.school,
                onTap: () {
                  Navigator.pushNamed(context, mentorshipRequestsRoute);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                title: 'Job Opportunities',
                subtitle: 'Explore career paths',
                icon: Icons.work,
                onTap: () {
                  Navigator.pushNamed(context, opportunitiesRoute);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(
                title: 'AI Career Chat',
                subtitle: 'Get career insights',
                icon: Icons.psychology,
                onTap: () {
                  setState(() {
                    _selectedIndex = 3; // Switch to AI Chat tab
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyDialogWidget extends StatefulWidget {
  final String placementId;
  final String company;
  final String role;

  const _ApplyDialogWidget({
    required this.placementId,
    required this.company,
    required this.role,
  });

  @override
  State<_ApplyDialogWidget> createState() => _ApplyDialogWidgetState();
}

class _ApplyDialogWidgetState extends State<_ApplyDialogWidget> {
  late final TextEditingController _resumeController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resumeController = TextEditingController();
  }

  @override
  void dispose() {
    _resumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply for Placement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resumeController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste your resume or brief background...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitApplication,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submitApplication() async {
    final resume = _resumeController.text.trim();
    if (resume.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide your resume or background information.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use Provider to apply
      final provider = context.read<PlacementsProvider>();
      final success = await provider.applyForPlacement(
        placementId: widget.placementId,
        resume: resume,
        company: widget.company,
        role: widget.role,
      );

      if (mounted && success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // V5.1: Use error message utility for user-friendly errors
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMessages.getUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }
}
