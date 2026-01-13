import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/menu_action.dart';
import 'package:campusconnect/models/note.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notes_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download functionality coming soon'),
                    ),
                  );
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
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Apply functionality coming soon'),
                        ),
                      );
                    },
                    child: const Text('Apply'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
