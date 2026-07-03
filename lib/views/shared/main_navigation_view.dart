import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// TabConfig - Configuration for each navigation tab
///
/// Defines the structure for tabs in the main navigation container.
/// Used by MainNavigationView to create consistent tab-based navigation.
class TabConfig {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget widget;

  const TabConfig({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.widget,
  });
}

/// MainNavigationView - Reusable navigation container extracted from NotesView
///
/// Phase 1 of NotesView decomposition: Shared navigation component that provides
/// the same IndexedStack + BottomNavigationBar pattern used throughout the app.
/// Supports dynamic tab configuration for different user roles and dashboards.
class MainNavigationView extends StatefulWidget {
  final List<TabConfig> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const MainNavigationView({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
  });

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.tabs.map((tab) => tab.widget).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppTheme.gray700
                  : AppTheme.gray200.withValues(alpha: 0.5),
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
          items: widget.tabs
              .map(
                (tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  activeIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ),
              )
              .toList(),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            widget.onTabChanged?.call(index);
          },
        ),
      ),
    );
  }

  /// Public method to programmatically change the selected tab
  /// Useful for deep linking or cross-tab navigation
  void setSelectedIndex(int index) {
    if (index >= 0 && index < widget.tabs.length) {
      setState(() {
        _selectedIndex = index;
      });
      widget.onTabChanged?.call(index);
    }
  }
}

/// TabbedNavigationMixin - Optional mixin for views that need tab switching capability
///
/// Provides helper methods for views that need to programmatically switch tabs
/// in the MainNavigationView from child widgets.
mixin TabbedNavigationMixin {
  /// Switch to a specific tab by index
  void switchToTab(BuildContext context, int tabIndex) {
    // Find the MainNavigationView in the widget tree and switch tabs
    final navState = context
        .findAncestorStateOfType<_MainNavigationViewState>();
    navState?.setSelectedIndex(tabIndex);
  }

  /// Switch to Notes tab (assuming standard tab order)
  void switchToNotes(BuildContext context) => switchToTab(context, 1);

  /// Switch to Placements tab (assuming standard tab order)
  void switchToPlacements(BuildContext context) => switchToTab(context, 2);

  /// Switch to AI Chat tab (assuming standard tab order)
  void switchToAIChat(BuildContext context) => switchToTab(context, 3);

  /// Switch to Profile tab (assuming standard tab order)
  void switchToProfile(BuildContext context) => switchToTab(context, 4);
}
