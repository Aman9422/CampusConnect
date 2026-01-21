import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/menu_action.dart';
import 'package:campusconnect/models/chat_message.dart';
import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:campusconnect/widgets/empty_state.dart';
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Placements',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'AI Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusConnect'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
        actions: [
          PopupMenuButton<MenuAction>(
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await _showLogOutDialog();
                  if (shouldLogout && mounted) {
                    await AuthService.firebase().logOut();
                    if (!mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(loginRoute, (_) => false);
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Quick Access Cards
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAccessCard(
                  context,
                  icon: Icons.note,
                  label: 'Notes',
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.business,
                  label: 'Placements',
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                  },
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.chat,
                  label: 'AI Chat',
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Placements
            Text(
              'Latest Placements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Consumer<PlacementsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && !provider.isInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(child: Text('Error: ${provider.error}'));
                }

                final placements = provider.placements;
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
                    return _buildPlacementCard(placement);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.blue.shade400),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(note.subject),
                  backgroundColor: Colors.blue.shade100,
                ),
                Chip(
                  label: Text('Year: ${note.year}'),
                  backgroundColor: Colors.green.shade100,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placements'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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

    final placements = provider.placements;

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
        itemCount: placements.length,
        itemBuilder: (context, index) {
          final placement = placements[index];
          return _buildPlacementCard(placement);
        },
      ),
    );
  }

  Widget _buildPlacementCard(Placement placement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placement.company,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        placement.role,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (placement.isDeadlinePassed)
                  Chip(
                    label: const Text('Closed'),
                    backgroundColor: Colors.red.shade100,
                  )
                else
                  Chip(
                    label: const Text('Open'),
                    backgroundColor: Colors.green.shade100,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              placement.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salary: ${placement.salary}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Deadline: ${DateFormat('MMM dd, yyyy').format(placement.deadline)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                if (!placement.isDeadlinePassed)
                  _buildApplyButton(placement.id, placement.company),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton(String placementId, String company) {
    return Consumer<PlacementsProvider>(
      builder: (context, provider, child) {
        final hasApplied = provider.hasApplied(placementId);
        final isApplying = provider.isApplying(placementId);
        final appliedDate = provider.getAppliedDate(placementId);
        final isOffline = !provider.isOnline;
        final anyApplyInProgress = provider.isAnyApplyInProgress;

        // Show "Applied" chip with date
        if (hasApplied && !isApplying) {
          return Chip(
            label: Text(
              appliedDate != null
                  ? 'Applied • ${DateFormat('MMM dd').format(appliedDate)}'
                  : 'Applied',
            ),
            backgroundColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 12),
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
            label: const Text('Applying...'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade300,
            ),
          );
        }

        // V5.1: Disable button if offline or another apply is in progress
        final isDisabled = isOffline || anyApplyInProgress;

        // Show apply button
        return ElevatedButton(
          onPressed: isDisabled
              ? null
              : () => _showApplyDialog(placementId, company),
          child: Text(isOffline ? 'Offline' : 'Apply'),
        );
      },
    );
  }

  void _showApplyDialog(String placementId, String company) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
      ),
      body: Column(
        children: [
          // V5.1.x: Offline banner for AI chat
          OfflineBanner(isOffline: !aiProvider.isOnline),
          // Trial warning banner
          if (aiProvider.isInTrial && aiProvider.daysRemainingInTrial <= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiProvider.daysRemainingInTrial == 1
                          ? 'AI trial expires tomorrow!'
                          : 'AI trial expires in ${aiProvider.daysRemainingInTrial} days',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy, size: 64, color: Colors.blue.shade400),
            const SizedBox(height: 16),
            Text(
              'CampusConnect AI',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal AI mentor for academics and career guidance',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('How to prepare for placements?'),
                _buildSuggestionChip('Study tips for exams'),
                _buildSuggestionChip('Career guidance'),
                _buildSuggestionChip('Resume help'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () => _handleSendMessage(text),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUserMessage
              ? Colors.blue.shade400
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isUserMessage ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: message.isUserMessage
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'AI is thinking...',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final aiProvider = context.watch<AIUsageProvider>();
    final isDisabled =
        _isLoadingAIResponse ||
        !aiProvider.isOnline ||
        aiProvider.hasReachedLimit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              enabled: !isDisabled,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: !aiProvider.isOnline
                    ? 'Offline - connect to send messages'
                    : aiProvider.hasReachedLimit
                    ? 'Daily limit reached'
                    : 'Ask me anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(_chatController.text),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isDisabled
                ? null
                : () => _handleSendMessage(_chatController.text),
            icon: Icon(
              Icons.send,
              color: isDisabled ? Colors.grey : Colors.blue.shade400,
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
    final user = AuthService.firebase().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Student',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Account Information
            Text(
              'Account Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildProfileInfoCard(
              label: 'Email',
              value: user?.email ?? 'Not available',
            ),
            _buildProfileInfoCard(label: 'App Version', value: 'v2.0.0'),
            const SizedBox(height: 32),

            // Settings Section
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              subtitle: const Text('Update your password'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Change password coming in a future update'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notifications'),
              subtitle: const Text('Manage your notifications'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification settings coming soon'),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleProfileLogout(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard({required String label, required String value}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileLogout() async {
    final shouldLogout = await _showLogOutDialog();
    if (shouldLogout && mounted) {
      await AuthService.firebase().logOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(loginRoute, (_) => false);
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
}

class _ApplyDialogWidget extends StatefulWidget {
  final String placementId;
  final String company;

  const _ApplyDialogWidget({required this.placementId, required this.company});

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
