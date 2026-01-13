import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/menu_action.dart';
import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  int _selectedIndex = 0;
  final NotesService _notesService = NotesService.instance();
  final PlacementsService _placementsService = PlacementsService.instance();

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
            StreamBuilder<List<Placement>>(
              stream: _placementsService.getAllPlacements(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final placements = snapshot.data ?? [];
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
      ),
      body: StreamBuilder<List<Placement>>(
        stream: _placementsService.getAllPlacements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final placements = snapshot.data ?? [];
          if (placements.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No placements available'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: placements.length,
            itemBuilder: (context, index) {
              final placement = placements[index];
              return _buildPlacementCard(placement);
            },
          );
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
                  _buildApplyButton(placement.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton(String placementId) {
    final userId = AuthService.firebase().currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _placementsService.hasUserApplied(
        userId: userId,
        placementId: placementId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          );
        }

        final hasApplied = snapshot.data ?? false;

        if (hasApplied) {
          return Chip(
            label: const Text('Applied'),
            backgroundColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: Colors.blue.shade700),
          );
        }

        return ElevatedButton(
          onPressed: () => _showApplyDialog(placementId),
          child: const Text('Apply'),
        );
      },
    );
  }

  void _showApplyDialog(String placementId) {
    showDialog(
      context: context,
      builder: (context) => _ApplyDialogWidget(
        placementId: placementId,
        placementsService: _placementsService,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 64,
                          color: Colors.blue.shade400,
                        ),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Ask me anything...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chat functionality coming soon'),
                          ),
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
  final PlacementsService placementsService;

  const _ApplyDialogWidget({
    required this.placementId,
    required this.placementsService,
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

    final userId = AuthService.firebase().currentUser?.id;
    if (userId == null) {
      setState(() => _errorMessage = 'User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.placementsService.applyForPlacement(
        userId: userId,
        placementId: widget.placementId,
        resume: resume,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error submitting application. Please try again.';
          _isLoading = false;
        });
      }
    }
  }
}
