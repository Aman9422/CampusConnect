import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/theme_provider.dart';
import 'package:campusconnect/services/local_preferences_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// SettingsView - v6.6
///
/// User settings for personalization without backend complexity.
/// - Account: Display name, bio, email
/// - Appearance: Theme, layout density
/// - Notifications: Status and shortcut
/// - About: Version, privacy, terms
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('Failed to load app version: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          // Account Section
          _buildSectionHeader('Account', Icons.person_outline),
          _buildAccountSection(),
          const SizedBox(height: AppTheme.space24),

          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette_outlined),
          _buildAppearanceSection(),
          const SizedBox(height: AppTheme.space24),

          // Notifications Section
          _buildSectionHeader('Notifications', Icons.notifications_outlined),
          _buildNotificationsSection(),
          const SizedBox(height: AppTheme.space24),

          // About Section
          _buildSectionHeader('About', Icons.info_outline),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.space8),
          Text(
            title,
            style: AppTheme.titleSmall.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.profile;
        final displayName = profile?.personal.effectiveDisplayName ?? 'User';
        final email = profile?.personal.email ?? '';
        final bio = profile?.personal.bio ?? '';

        return _buildCard(
          children: [
            // Profile header with initials
            Padding(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Row(
                children: [
                  LargeInitialsAvatar(
                    name: displayName,
                    uid: profile?.uid,
                    size: 60,
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.gray900,
                          ),
                        ),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            bio,
                            style: AppTheme.bodySmall.copyWith(
                              color: isDark
                                  ? AppTheme.gray400
                                  : AppTheme.gray600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Display Name
            _buildSettingsTile(
              icon: Icons.badge_outlined,
              title: 'Display Name',
              subtitle: profile?.personal.displayName.isEmpty == true
                  ? 'Not set (using full name)'
                  : profile?.personal.displayName ?? 'Not set',
              onTap: () => _showEditDisplayNameDialog(context, profile),
            ),

            // Bio
            _buildSettingsTile(
              icon: Icons.description_outlined,
              title: 'Bio',
              subtitle: bio.isEmpty ? 'Add a short bio' : bio,
              onTap: () => _showEditBioDialog(context, profile),
            ),

            // Email (read-only)
            _buildSettingsTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: email,
              trailing: Icon(
                Icons.lock_outline,
                size: 16,
                color: AppTheme.gray400,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceSection() {
    return _buildCard(
      children: [
        // Theme selector
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return _buildSettingsTile(
              icon: themeProvider.icon,
              title: 'Theme',
              subtitle: themeProvider.displayName,
              onTap: () => _showThemeDialog(context, themeProvider),
            );
          },
        ),

        // Layout density
        Consumer<LayoutProvider>(
          builder: (context, layoutProvider, _) {
            return _buildSettingsTile(
              icon: layoutProvider.icon,
              title: 'Layout Density',
              subtitle: layoutProvider.displayName,
              onTap: () => _showDensityDialog(context, layoutProvider),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _buildCard(
      children: [
        _buildSettingsTile(
          icon: Icons.notifications_active_outlined,
          title: 'View Notifications',
          subtitle: 'See all your notifications',
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.gray400,
          ),
          onTap: () => Navigator.pushNamed(context, notificationsRoute),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildCard(
      children: [
        // App version
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'App Version',
          subtitle: _appVersion.isNotEmpty ? _appVersion : 'Loading...',
        ),

        // Privacy Policy
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          trailing: Icon(Icons.open_in_new, size: 16, color: AppTheme.gray400),
          onTap: () => _launchUrl('https://campusconnect.app/privacy'),
        ),

        // Terms of Service
        _buildSettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          trailing: Icon(Icons.open_in_new, size: 16, color: AppTheme.gray400),
          onTap: () => _launchUrl('https://campusconnect.app/terms'),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: isDark ? null : AppTheme.shadowSmall,
        border: isDark ? Border.all(color: AppTheme.gray700) : null,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
                Icon(Icons.chevron_right, color: AppTheme.gray400),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Dialogs ====================

  void _showEditDisplayNameDialog(BuildContext context, dynamic profile) {
    final controller = TextEditingController(
      text: profile?.personal.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Name'),
        content: TextField(
          controller: controller,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'Enter display name',
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (profile != null) {
                final updatedProfile = profile.copyWith(
                  personal: profile.personal.copyWith(displayName: newName),
                );
                await context.read<ProfileProvider>().updateProfile(
                  updatedProfile,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditBioDialog(BuildContext context, dynamic profile) {
    final controller = TextEditingController(text: profile?.personal.bio ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bio'),
        content: TextField(
          controller: controller,
          maxLength: 120,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Tell us about yourself'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newBio = controller.text.trim();
              if (profile != null) {
                final updatedProfile = profile.copyWith(
                  personal: profile.personal.copyWith(bio: newBio),
                );
                await context.read<ProfileProvider>().updateProfile(
                  updatedProfile,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.system,
              'System',
              Icons.brightness_auto,
            ),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.light,
              'Light',
              Icons.light_mode,
            ),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.dark,
              'Dark',
              Icons.dark_mode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider provider,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryBlue : AppTheme.gray600,
      ),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: AppTheme.primaryBlue)
          : null,
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showDensityDialog(BuildContext context, LayoutProvider layoutProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Layout Density'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDensityOption(
              context,
              layoutProvider,
              LayoutDensity.comfortable,
              'Comfortable',
              Icons.view_agenda_outlined,
              'More spacing, easier to read',
            ),
            _buildDensityOption(
              context,
              layoutProvider,
              LayoutDensity.compact,
              'Compact',
              Icons.view_list,
              'Less spacing, see more content',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityOption(
    BuildContext context,
    LayoutProvider provider,
    LayoutDensity density,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = provider.density == density;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryBlue : AppTheme.gray600,
      ),
      title: Text(label),
      subtitle: Text(description, style: AppTheme.caption),
      trailing: isSelected
          ? Icon(Icons.check, color: AppTheme.primaryBlue)
          : null,
      onTap: () {
        provider.setDensity(density);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
