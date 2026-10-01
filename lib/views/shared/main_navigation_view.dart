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
  State<MainNavigationView> createState() => MainNavigationViewState();
}

/// State class for MainNavigationView — made public so child widgets
/// can programmatically switch tabs via findAncestorStateOfType.
class MainNavigationViewState extends State<MainNavigationView> {
  late int _selectedIndex;

  /// v9.2 (P1): the set of tabs whose subtree has been built at least once.
  ///
  /// `IndexedStack` eagerly builds EVERY child, so switching to it meant the
  /// first frame after login built all 5 heavy dashboards/tabs at once — the
  /// dominant cause of the "Skipped 45 frames!" startup jank on the emulator.
  /// Tabs are now built lazily on first visit (the selected tab is seeded here)
  /// and, exactly as before, kept alive by `IndexedStack` afterwards, so tab
  /// state (scroll position, controllers, in-flight loads) is preserved and the
  /// visible UI is unchanged.
  late final Set<int> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _visitedTabs = <int>{_selectedIndex};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            // v9.2 (P1): build a tab's subtree only once it has been visited.
            // Unvisited tabs render a zero-cost placeholder, so the first
            // frame only pays for the tab actually on screen.
            if (_visitedTabs.contains(i))
              widget.tabs[i].widget
            else
              const SizedBox.shrink(),
        ],
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
              _visitedTabs.add(index); // v9.2 (P1): build on first visit
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
        _visitedTabs.add(index); // v9.2 (P1): build on first visit
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
        .findAncestorStateOfType<MainNavigationViewState>();
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
