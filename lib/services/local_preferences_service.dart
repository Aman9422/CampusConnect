import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocalPreferencesService - v6.6
///
/// Manages local-only preferences using SharedPreferences.
/// Persists across app restarts and logout.
/// No Firestore writes - privacy-first design.
class LocalPreferencesService {
  static LocalPreferencesService? _instance;
  SharedPreferences? _prefs;

  LocalPreferencesService._();

  static LocalPreferencesService instance() {
    _instance ??= LocalPreferencesService._();
    return _instance!;
  }

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError(
        'LocalPreferencesService not initialized. Call init() first.',
      );
    }
    return _prefs!;
  }

  // ==================== Theme Preferences ====================

  static const String _keyThemeMode = 'theme_mode';

  /// Get saved theme mode (0=system, 1=light, 2=dark)
  ThemeMode getThemeMode() {
    final value = _safePrefs.getInt(_keyThemeMode) ?? 0;
    switch (value) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Save theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    int value;
    switch (mode) {
      case ThemeMode.light:
        value = 1;
        break;
      case ThemeMode.dark:
        value = 2;
        break;
      case ThemeMode.system:
        value = 0;
        break;
    }
    await _safePrefs.setInt(_keyThemeMode, value);
  }

  // ==================== Layout Density ====================

  static const String _keyLayoutDensity = 'layout_density';

  /// Get saved layout density (0=comfortable, 1=compact)
  LayoutDensity getLayoutDensity() {
    final value = _safePrefs.getInt(_keyLayoutDensity) ?? 0;
    return value == 1 ? LayoutDensity.compact : LayoutDensity.comfortable;
  }

  /// Save layout density
  Future<void> setLayoutDensity(LayoutDensity density) async {
    final value = density == LayoutDensity.compact ? 1 : 0;
    await _safePrefs.setInt(_keyLayoutDensity, value);
  }

  // ==================== Notification Preferences ====================

  static const String _keyNotificationsEnabled = 'notifications_enabled';

  /// Check if notifications are enabled (default true)
  bool getNotificationsEnabled() {
    return _safePrefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Save notification preference
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _safePrefs.setBool(_keyNotificationsEnabled, enabled);
  }

  // ==================== Clear All ====================

  /// Clear all preferences (for debugging/testing)
  Future<void> clearAll() async {
    await _safePrefs.clear();
  }
}

/// Layout density enum - v6.6
enum LayoutDensity { comfortable, compact }

/// Extension for density values
extension LayoutDensityExtension on LayoutDensity {
  /// Card padding
  double get cardPadding {
    switch (this) {
      case LayoutDensity.comfortable:
        return 16.0;
      case LayoutDensity.compact:
        return 12.0;
    }
  }

  /// List item vertical padding
  double get listItemPadding {
    switch (this) {
      case LayoutDensity.comfortable:
        return 16.0;
      case LayoutDensity.compact:
        return 10.0;
    }
  }

  /// Spacing between items
  double get itemSpacing {
    switch (this) {
      case LayoutDensity.comfortable:
        return 16.0;
      case LayoutDensity.compact:
        return 10.0;
    }
  }

  /// Display name
  String get displayName {
    switch (this) {
      case LayoutDensity.comfortable:
        return 'Comfortable';
      case LayoutDensity.compact:
        return 'Compact';
    }
  }
}
