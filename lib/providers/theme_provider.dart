import 'package:campusconnect/services/local_preferences_service.dart';
import 'package:flutter/material.dart';

/// ThemeProvider - v6.6
///
/// Manages app theme (light/dark/system) with local persistence.
/// No Firestore writes - uses SharedPreferences only.
class ThemeProvider extends ChangeNotifier {
  final LocalPreferencesService _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeProvider({LocalPreferencesService? prefs})
    : _prefs = prefs ?? LocalPreferencesService.instance();

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Initialize from local storage
  Future<void> init() async {
    await _prefs.init();
    _themeMode = _prefs.getThemeMode();
    _isInitialized = true;
    notifyListeners();
  }

  /// Set theme mode and persist
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    await _prefs.setThemeMode(mode);
  }

  /// Convenience methods
  Future<void> setLight() => setThemeMode(ThemeMode.light);
  Future<void> setDark() => setThemeMode(ThemeMode.dark);
  Future<void> setSystem() => setThemeMode(ThemeMode.system);

  /// Toggle between light and dark (ignores system)
  Future<void> toggle() async {
    if (_themeMode == ThemeMode.dark) {
      await setLight();
    } else {
      await setDark();
    }
  }

  /// Get display name for current theme
  String get displayName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get icon for current theme
  IconData get icon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
