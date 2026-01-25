import 'package:campusconnect/services/local_preferences_service.dart';
import 'package:flutter/material.dart';

/// LayoutProvider - v6.6
///
/// Manages layout density (comfortable/compact) with local persistence.
/// Affects padding, card spacing, and list item height.
/// No Firestore writes - uses SharedPreferences only.
class LayoutProvider extends ChangeNotifier {
  final LocalPreferencesService _prefs;
  LayoutDensity _density = LayoutDensity.comfortable;
  bool _isInitialized = false;

  LayoutProvider({LocalPreferencesService? prefs})
    : _prefs = prefs ?? LocalPreferencesService.instance();

  // Getters
  LayoutDensity get density => _density;
  bool get isInitialized => _isInitialized;
  bool get isCompact => _density == LayoutDensity.compact;
  bool get isComfortable => _density == LayoutDensity.comfortable;

  // Convenience getters for spacing values
  double get cardPadding => _density.cardPadding;
  double get listItemPadding => _density.listItemPadding;
  double get itemSpacing => _density.itemSpacing;

  /// Initialize from local storage
  Future<void> init() async {
    await _prefs.init();
    _density = _prefs.getLayoutDensity();
    _isInitialized = true;
    notifyListeners();
  }

  /// Set density and persist
  Future<void> setDensity(LayoutDensity density) async {
    if (_density == density) return;

    _density = density;
    notifyListeners();

    await _prefs.setLayoutDensity(density);
  }

  /// Convenience methods
  Future<void> setComfortable() => setDensity(LayoutDensity.comfortable);
  Future<void> setCompact() => setDensity(LayoutDensity.compact);

  /// Toggle density
  Future<void> toggle() async {
    if (_density == LayoutDensity.compact) {
      await setComfortable();
    } else {
      await setCompact();
    }
  }

  /// Get display name
  String get displayName => _density.displayName;

  /// Get icon for current density
  IconData get icon {
    switch (_density) {
      case LayoutDensity.comfortable:
        return Icons.view_agenda_outlined;
      case LayoutDensity.compact:
        return Icons.view_list;
    }
  }
}
