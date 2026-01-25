# CampusConnect - Technical Implementation Guide

**Complete technical documentation for developers**

Version: 6.6.0 (January 25, 2026)

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Version History & Evolution](#version-history--evolution)
3. [Current Implementation (v6.6)](#current-implementation-v66)
4. [Provider Lifecycle Management](#provider-lifecycle-management)
5. [Network Awareness & Error Handling](#network-awareness--error-handling)
6. [Theme & Personalization System](#theme--personalization-system)
7. [Profile System](#profile-system)
8. [Eligibility Engine](#eligibility-engine)
9. [Firebase Integration](#firebase-integration)
10. [AI Chat System](#ai-chat-system)
11. [Placements System](#placements-system)
12. [Development Guidelines](#development-guidelines)
13. [Testing & Validation](#testing--validation)

---

## Architecture Overview

### Tech Stack
- **Framework:** Flutter 3.10.4+
- **Language:** Dart
- **State Management:** Provider pattern
- **Backend:** Firebase (Auth, Firestore, Cloud Functions)
- **AI Backend:** HTTP REST API (Cloud Functions)
- **Network Monitoring:** connectivity_plus

### Core Architecture Pattern

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Views - Stateful/Stateless Widgets)   │
│  - Modern UI with AppTheme tokens       │
│  - Dark mode support throughout         │
└─────────────────┬───────────────────────┘
                  │ watch/read
┌─────────────────▼───────────────────────┐
│         State Management Layer          │
│  (Providers - ChangeNotifier pattern)   │
│  - PlacementsProvider                   │
│  - AIUsageProvider                      │
│  - ProfileProvider (v6.1+)              │
│  - ThemeProvider (v6.6+)                │
│  - LayoutProvider (v6.6+)               │
└─────────────────┬───────────────────────┘
                  │ uses
┌─────────────────▼───────────────────────┐
│           Business Logic Layer          │
│        (Services - Singleton)           │
│  - AuthService                          │
│  - PlacementsService                    │
│  - NotesService                         │
│  - AIService                            │
│  - LocalPreferencesService (v6.6+)      │
└─────────────────┬───────────────────────┘
                  │ communicates with
┌─────────────────▼───────────────────────┐
│           Data/Backend Layer            │
│  - Firebase Auth                        │
│  - Firestore Database                   │
│  - Cloud Functions (HTTPS Callable)     │
│  - HTTP REST API                        │
│  - SharedPreferences (local)            │
└─────────────────────────────────────────┘
```

---

## Version History & Evolution

### v1.0 - Foundation (MVP)
- Basic Firebase auth (email/password)
- Notes module (Firestore real-time)
- Placements listing (read-only)
- AI Chat UI (no backend)
- Material 3 design system

### v2.0 - Enhanced UI & UX
- Profile screen
- Improved navigation
- Better error handling (typed exceptions)
- Loading states and skeletons
- Empty state illustrations

### v3.0 - Apply to Placements
- Apply button functionality
- Application tracking
- Status indicators (Applied vs Available)
- Date formatting (Applied • Jan 15)
- Basic error handling

### v4.0 - AI Chat Integration
- Integrated HTTP-based AI service
- Trial system (5-day free trial)
- Daily usage limits (50 messages/day)
- Usage tracking and warnings
- Trial expiration notifications

### v5.0 - Provider Architecture Migration
**Major Refactor:** Moved from StatefulWidgets to Provider pattern
- Created `PlacementsProvider` (ChangeNotifier)
- Created `AIUsageProvider` (ChangeNotifier)
- One-time data fetch (vs constant streams)
- Optimistic UI updates
- Centralized state management
- Performance improvements

### v5.1 - Stability & UX Polish
**Production-ready guardrails for Placements:**
- Offline detection (`connectivity_plus`)
- Network pre-flight checks
- User-friendly error messages (`ErrorMessages` utility)
- Analytics tracking (`AnalyticsHelper`)
- 5 comprehensive guardrails:
  1. Already applied check
  2. Re-entrant call prevention
  3. Network connectivity check
  4. Input validation
  5. Apply with analytics
- `OfflineBanner` widget
- Enhanced apply button (network-aware, status-aware)

### v5.1.1 - Critical Bugfix
**Provider Lifecycle Crash Fixed:**
- **Bug:** ProviderNotFoundException after logout → login flow
- **Root Cause:** Providers created conditionally, disposed on auth change
- **Solution:**
  - Moved providers to root level (always present)
  - Made `userId` nullable in providers
  - Added `initWithUser()` method (called after login)
  - Added `reset()` method (called on logout)
  - Providers persist, state resets

### v5.1.2 - App-Wide Standardization
**Extended guardrails to entire app:**
- Network awareness in `AIUsageProvider`
- Offline banner in AI chat
- Pre-flight network checks for AI messages
- User-friendly error translation in AI chat
- Trial expiration banner (persistent vs snackbar)
- Chat input disabled when offline/at limit
- Consistent UX across all network features

### v6.0 - Complete UI Redesign
**Modern design system overhaul:**
- Created `AppTheme` class with centralized design tokens
- Primary color: Deep Blue (#1A365D)
- Accent gradient: Blue to Teal (#2563EB → #0D9488)
- Consistent spacing, typography, and elevation
- Card-based layout system
- Professional color palette (gray scale, semantic colors)
- Light theme foundation with dark mode preparation

### v6.1 - Profile System Enhancement
**Complete profile data model:**
- Created `UserProfile` model with 15+ fields
- `ProfileProvider` for state management
- Academic info (branch, year, CGPA, backlogs)
- Skills array for competency tracking
- Resume URL storage
- Profile completeness calculation

### v6.2 - Profile Setup & Auth Flow
**First-time user onboarding:**
- Multi-step `ProfileSetupView` (4 steps)
- Auth flow integration (register → verify → setup)
- Skip option with incomplete profile warning
- Form validation and error handling
- Smooth animations between steps

### v6.3 - Edit Profile
**Profile modification capability:**
- `EditProfileView` with tabbed interface
- Personal, Academic, Skills tabs
- Pre-populated form fields
- Save/discard changes flow
- Real-time validation

### v6.4 - In-App Notifications
**User notification system:**
- `NotificationBadge` widget
- `NotificationsView` with categorized list
- Notification types (placements, system, profile)
- Read/unread state management
- Timestamp formatting

### v6.5 - Placement Intelligence (Eligibility)
**Smart placement matching:**
- `EligibilityResult` model with status enum
- `PlacementsProvider.checkEligibility()` method
- Criteria: CGPA, backlogs, branch, year
- Visual indicators (Eligible/Not Eligible/Partial)
- Missing criteria explanation
- Filter placements by eligibility

### v6.6 - Personalization & Dark Mode (Current)
**User customization features:**
- `LocalPreferencesService` (SharedPreferences wrapper)
- `ThemeProvider` with Light/Dark/System modes
- `LayoutProvider` with Comfortable/Compact density
- `SettingsView` for user preferences
- Complete dark mode support across all screens
- `InitialsAvatar` widget for profile display
- Display name and bio editing
- Persisted preferences (survives app restart)

---

## Current Implementation (v6.6)

### Project Structure

```
lib/
├── main.dart                    # App entry, providers at root
├── firebase_options.dart        # Firebase configuration
├── constants/
│   └── routes.dart              # Named routes
├── enums/
│   └── menu_action.dart         # Menu actions enum
├── models/
│   ├── chat_message.dart        # AI chat message model
│   ├── note.dart                # Academic note model
│   ├── placement.dart           # Placement model (with eligibility)
│   ├── auth_user.dart           # User model
│   ├── user_profile.dart        # Profile model (v6.1+)
│   └── eligibility_result.dart  # Eligibility model (v6.5+)
├── providers/
│   ├── placements_provider.dart # Placements state (v5.0+)
│   ├── ai_usage_provider.dart   # AI usage state (v5.0+)
│   ├── profile_provider.dart    # Profile state (v6.1+)
│   ├── theme_provider.dart      # Theme state (v6.6+)
│   └── layout_provider.dart     # Layout density state (v6.6+)
├── services/
│   ├── auth/
│   │   ├── auth_service.dart    # Auth abstraction
│   │   ├── firebase_auth_provider.dart
│   │   └── auth_exceptions.dart # Typed exceptions
│   ├── firestore/
│   │   ├── placements_service.dart # Placements CRUD
│   │   └── notes_service.dart   # Notes CRUD
│   ├── ai/
│   │   └── ai_service.dart      # AI HTTP client
│   └── local_preferences_service.dart # Local storage (v6.6+)
├── theme/
│   └── app_theme.dart           # Design tokens & themes (v6.0+)
├── utilities/
│   ├── error_messages.dart      # Error translation (v5.1+)
│   ├── analytics_helper.dart    # Analytics wrapper (v5.1+)
│   └── show_error_dialog.dart   # Error dialog helper
├── views/
│   ├── login_view.dart          # Auth (dark mode support)
│   ├── register_view.dart       # Auth (dark mode support)
│   ├── verify_email_view.dart   # Email verification
│   ├── notes_view.dart          # Main app screen (5 tabs)
│   ├── profile_setup_view.dart  # Onboarding (v6.2+)
│   ├── edit_profile_view.dart   # Profile editing (v6.3+)
│   ├── notifications_view.dart  # Notifications (v6.4+)
│   └── settings_view.dart       # Settings (v6.6+)
└── widgets/
    ├── offline_banner.dart      # Offline indicator (v5.1+)
    ├── empty_state.dart         # Empty state widget
    ├── skeleton_loader.dart     # Loading skeleton
    ├── notification_badge.dart  # Notification count (v6.4+)
    ├── initials_avatar.dart     # Profile avatar (v6.6+)
    └── home_widgets.dart        # Home screen widgets (v6.0+)
```

### Key Dependencies

```yaml
dependencies:
  flutter_sdk: ^3.10.4
  provider: ^6.1.2              # State management
  firebase_core: ^4.3.0
  firebase_auth: ^6.1.3
  cloud_firestore: ^6.1.1
  cloud_functions: ^6.0.5
  firebase_analytics: ^12.1.0
  connectivity_plus: ^6.1.0     # Network monitoring (v5.1+)
  shared_preferences: ^2.2.2    # Local storage (v6.6+)
  http: ^1.2.2                  # AI service HTTP
  intl: ^0.19.0                 # Date formatting
  url_launcher: ^6.3.1          # Open URLs
```

---

## Provider Lifecycle Management

### Problem (v5.0 - v5.1.0)

Providers were created conditionally inside authenticated branch:

```dart
// WRONG - Providers disposed on logout
if (user != null && user.isEmailVerified) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PlacementsProvider(userId: user.id)),
    ],
    child: const NotesView(),
  );
}
// On logout → MultiProvider removed → Providers disposed → Login → CRASH
```

### Solution (v5.1.1+)

**Providers at root level** - always present, never disposed:

```dart
// lib/main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(  // ← Always present (root level)
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlacementsProvider(
            service: PlacementsService.instance(),
            // No userId here - initialized later
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AIUsageProvider(
            aiService: AIService.instance(),
            // No userId here - initialized later
          ),
        ),
      ],
      child: MaterialApp(...),  // ← Providers wrap entire app
    );
  }
}

// HomePage - Initialize after login, reset on logout
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService.firebase().initialize(),
      builder: (context, snapshot) {
        final user = AuthService.firebase().currentUser;
        
        if (user != null && user.isEmailVerified) {
          // ✅ Initialize providers with userId after login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<PlacementsProvider>().initWithUser(user.id);
            context.read<AIUsageProvider>().initWithUser(user.id);
          });
          return const NotesView();
        } else {
          // ✅ Reset providers on logout
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<PlacementsProvider>().reset();
            context.read<AIUsageProvider>().reset();
          });
          return const LoginView();
        }
      },
    );
  }
}
```

### Provider Pattern Implementation

```dart
// Example: PlacementsProvider
class PlacementsProvider with ChangeNotifier {
  final PlacementsService _service;
  String? userId;  // ← Nullable (can be null when logged out)
  
  PlacementsProvider({required PlacementsService service, this.userId})
      : _service = service;

  // State
  List<Placement> _placements = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  // ✅ Initialize with user ID (called after login)
  Future<void> initWithUser(String newUserId) async {
    if (userId == newUserId && _isInitialized) return; // Skip if same user
    userId = newUserId;
    await init();
  }

  // ✅ Reset state (called on logout)
  void reset() {
    userId = null;
    _placements = [];
    _isInitialized = false;
    _isLoading = false;
    notifyListeners();
  }

  // Load data
  Future<void> init() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();
    
    // Load placements...
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }
}
```

**Benefits:**
- ✅ Providers always available (no ProviderNotFoundException)
- ✅ Clean lifecycle management
- ✅ No race conditions
- ✅ Easy to test
- ✅ Safe for UI redesigns

---

## Network Awareness & Error Handling

### Connectivity Monitoring Pattern

Every provider that makes network calls should monitor connectivity:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class YourProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;  // Expose to UI

  Future<void> init() async {
    _startConnectivityMonitoring();
    // ... rest of init
  }

  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        debugPrint('Network: ${_isOnline ? "online" : "offline"}');
        notifyListeners();  // Notify UI
      }
    });
  }
}
```

### Pre-Flight Network Guards

Before any network call, check connectivity:

```dart
Future<void> performNetworkAction() async {
  // ✅ Pre-flight check
  if (!_isOnline) {
    throw Exception("You're offline. Please reconnect and try again.");
  }
  
  // Check other conditions...
  
  // Make API call
  final result = await _service.callAPI();
}
```

### Error Translation Utility

Centralized error translation prevents technical errors from reaching users:

```dart
// lib/utilities/error_messages.dart
class ErrorMessages {
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Check your internet connection and try again';
    }

    // Auth errors
    if (errorString.contains('unauthenticated')) {
      return 'Please log in again to continue';
    }

    // Timeout
    if (errorString.contains('timeout')) {
      return 'Request took too long. Please try again';
    }

    // Default
    return 'Something went wrong. Please try again';
  }
}
```

**Usage in catch blocks:**

```dart
try {
  await performNetworkAction();
} catch (e) {
  final friendlyError = ErrorMessages.getUserFriendlyMessage(e);
  // Show friendlyError to user
  debugPrint('Technical error: $e');  // Still log for debugging
}
```

### Offline Banner Widget

```dart
// lib/widgets/offline_banner.dart
class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  
  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();  // Hide when online
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text('You are offline', style: TextStyle(color: Colors.orange.shade900)),
        ],
      ),
    );
  }
}
```

**Usage:**

```dart
Widget build(BuildContext context) {
  final provider = context.watch<YourProvider>();
  
  return Column(
    children: [
      OfflineBanner(isOffline: !provider.isOnline),  // ← Add to any screen
      // ... rest of UI
    ],
  );
}
```

---

## Theme & Personalization System

### AppTheme Design Tokens (v6.0+)

```dart
// lib/theme/app_theme.dart
class AppTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF1A365D);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentTeal = Color(0xFF0D9488);
  
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentBlue, accentTeal],
  );
  
  // Gray Scale
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray900 = Color(0xFF111827);
  
  // Theme Data
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: gray50,
    // ... complete theme configuration
  );
  
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: darkBackground,
    // ... complete dark theme configuration
  );
}
```

### LocalPreferencesService (v6.6+)

```dart
// lib/services/local_preferences_service.dart
class LocalPreferencesService {
  static const String _themeKey = 'theme_mode';
  static const String _layoutKey = 'layout_density';
  
  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }
  
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }
  
  Future<void> setLayoutDensity(String density) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutKey, density);
  }
  
  Future<String> getLayoutDensity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_layoutKey) ?? 'comfortable';
  }
}
```

### ThemeProvider (v6.6+)

```dart
// lib/providers/theme_provider.dart
enum ThemeMode { light, dark, system }

class ThemeProvider with ChangeNotifier {
  final LocalPreferencesService _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemeData getTheme(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppTheme.lightTheme;
      case ThemeMode.dark:
        return AppTheme.darkTheme;
      case ThemeMode.system:
        final brightness = MediaQuery.of(context).platformBrightness;
        return brightness == Brightness.dark 
            ? AppTheme.darkTheme 
            : AppTheme.lightTheme;
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setThemeMode(mode.name);
    notifyListeners();
  }
  
  Future<void> loadFromPrefs() async {
    final saved = await _prefs.getThemeMode();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }
}
```

### LayoutProvider (v6.6+)

```dart
// lib/providers/layout_provider.dart
enum LayoutDensity { comfortable, compact }

class LayoutProvider with ChangeNotifier {
  final LocalPreferencesService _prefs;
  LayoutDensity _density = LayoutDensity.comfortable;
  
  LayoutDensity get density => _density;
  bool get isCompact => _density == LayoutDensity.compact;
  
  // Dynamic spacing values
  double get cardPadding => isCompact ? 12.0 : 16.0;
  double get listItemPadding => isCompact ? 10.0 : 16.0;
  double get itemSpacing => isCompact ? 10.0 : 16.0;
  
  Future<void> setDensity(LayoutDensity density) async {
    _density = density;
    await _prefs.setLayoutDensity(density.name);
    notifyListeners();
  }
}
```

### Dark Mode Implementation Pattern

```dart
// In any widget that needs dark mode support:
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return Container(
    color: isDark ? AppTheme.darkSurface : Colors.white,
    child: Text(
      'Hello',
      style: TextStyle(
        color: isDark ? Colors.white : AppTheme.gray900,
      ),
    ),
  );
}
```

### Using Layout Provider in UI

```dart
Widget build(BuildContext context) {
  final layout = context.watch<LayoutProvider>();
  
  return Card(
    child: Padding(
      padding: EdgeInsets.all(layout.cardPadding),  // 12 or 16
      child: Column(
        children: [
          Text('Title', style: TextStyle(
            fontSize: layout.isCompact ? 16 : 18,
          )),
          SizedBox(height: layout.itemSpacing),  // 10 or 16
          // ... more content
        ],
      ),
    ),
  );
}
```

---

## Profile System

### UserProfile Model (v6.1+)

```dart
// lib/models/user_profile.dart
class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? bio;
  final String? branch;
  final int? year;
  final double? cgpa;
  final int? backlogs;
  final List<String> skills;
  final String? resumeUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.bio,
    this.branch,
    this.year,
    this.cgpa,
    this.backlogs,
    this.skills = const [],
    this.resumeUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  // Profile completeness calculation
  double get completeness {
    int filled = 0;
    int total = 7;
    
    if (displayName != null && displayName!.isNotEmpty) filled++;
    if (branch != null && branch!.isNotEmpty) filled++;
    if (year != null) filled++;
    if (cgpa != null) filled++;
    if (backlogs != null) filled++;
    if (skills.isNotEmpty) filled++;
    if (resumeUrl != null && resumeUrl!.isNotEmpty) filled++;
    
    return filled / total;
  }
  
  bool get isComplete => completeness >= 0.8;
}
```

### ProfileProvider (v6.1+)

```dart
// lib/providers/profile_provider.dart
class ProfileProvider with ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;
  
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;
  
  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        _profile = UserProfile.fromFirestore(doc);
      }
    } catch (e) {
      _error = ErrorMessages.getUserFriendlyMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    // Optimistic update + Firestore sync
  }
}
```

### InitialsAvatar Widget (v6.6+)

```dart
// lib/widgets/initials_avatar.dart
class InitialsAvatar extends StatelessWidget {
  final String? name;
  final String? email;
  final double size;
  
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name![0].toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return '?';
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
```

---

## Eligibility Engine

### EligibilityResult Model (v6.5+)

```dart
// lib/models/eligibility_result.dart
enum EligibilityStatus { eligible, notEligible, partiallyEligible }

class EligibilityResult {
  final EligibilityStatus status;
  final List<String> metCriteria;
  final List<String> unmetCriteria;
  final String? reason;
  
  EligibilityResult({
    required this.status,
    this.metCriteria = const [],
    this.unmetCriteria = const [],
    this.reason,
  });
  
  bool get isEligible => status == EligibilityStatus.eligible;
  bool get isPartial => status == EligibilityStatus.partiallyEligible;
}
```

### Eligibility Checking Logic

```dart
// In PlacementsProvider
EligibilityResult checkEligibility(Placement placement, UserProfile profile) {
  final met = <String>[];
  final unmet = <String>[];
  
  // CGPA Check
  if (placement.minCgpa != null) {
    if (profile.cgpa != null && profile.cgpa! >= placement.minCgpa!) {
      met.add('CGPA: ${profile.cgpa} >= ${placement.minCgpa}');
    } else {
      unmet.add('CGPA: Required ${placement.minCgpa}, you have ${profile.cgpa ?? "N/A"}');
    }
  }
  
  // Backlogs Check
  if (placement.maxBacklogs != null) {
    if (profile.backlogs != null && profile.backlogs! <= placement.maxBacklogs!) {
      met.add('Backlogs: ${profile.backlogs} <= ${placement.maxBacklogs}');
    } else {
      unmet.add('Backlogs: Max ${placement.maxBacklogs}, you have ${profile.backlogs ?? "N/A"}');
    }
  }
  
  // Branch Check
  if (placement.eligibleBranches != null && placement.eligibleBranches!.isNotEmpty) {
    if (profile.branch != null && placement.eligibleBranches!.contains(profile.branch)) {
      met.add('Branch: ${profile.branch} is eligible');
    } else {
      unmet.add('Branch: ${profile.branch ?? "Not set"} not in eligible branches');
    }
  }
  
  // Determine status
  EligibilityStatus status;
  if (unmet.isEmpty) {
    status = EligibilityStatus.eligible;
  } else if (met.isEmpty) {
    status = EligibilityStatus.notEligible;
  } else {
    status = EligibilityStatus.partiallyEligible;
  }
  
  return EligibilityResult(
    status: status,
    metCriteria: met,
    unmetCriteria: unmet,
  );
}
```

### UI Integration

```dart
Widget _buildEligibilityBadge(EligibilityResult result) {
  Color color;
  IconData icon;
  String text;
  
  switch (result.status) {
    case EligibilityStatus.eligible:
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Eligible';
      break;
    case EligibilityStatus.partiallyEligible:
      color = Colors.orange;
      icon = Icons.warning;
      text = 'Partial Match';
      break;
    case EligibilityStatus.notEligible:
      color = Colors.red;
      icon = Icons.cancel;
      text = 'Not Eligible';
      break;
  }
  
  return Chip(
    avatar: Icon(icon, color: color, size: 16),
    label: Text(text),
    backgroundColor: color.withOpacity(0.1),
  );
}
```

---

## Firebase Integration

### Authentication Flow

```dart
// lib/services/auth/auth_service.dart
abstract class AuthService {
  factory AuthService.firebase() => FirebaseAuthProvider();
  
  Future<void> initialize();
  AuthUser? get currentUser;
  Future<AuthUser> logIn({required String email, required String password});
  Future<AuthUser> createUser({required String email, required String password});
  Future<void> logOut();
  Future<void> sendEmailVerification();
}
```

**Typed Exceptions:**

```dart
// lib/services/auth/auth_exceptions.dart
class UserNotFoundAuthException implements Exception {}
class WrongPasswordAuthException implements Exception {}
class WeakPasswordAuthException implements Exception {}
class EmailAlreadyInUseAuthException implements Exception {}
class InvalidEmailAuthException implements Exception {}
class GenericAuthException implements Exception {}
```

### Firestore Structure

```
firestore/
├── users/{userId}/
│   ├── profile: { name, email, createdAt }
│   └── applications/{applicationId}/
│       └── { placementId, resumeUrl, coverLetter, appliedAt }
├── placements/{placementId}/
│   └── { company, role, ctc, location, deadline, ... }
└── notes/{noteId}/
    └── { title, subject, year, fileUrl, uploadedAt }
```

### Cloud Functions (HTTPS Callable)

```dart
// Apply to placement
final callable = FirebaseFunctions.instance.httpsCallable('applyToPlacement');
final result = await callable.call({
  'userId': userId,
  'placementId': placementId,
  'resume': resumeText,
  'coverLetter': coverLetterText,
});
```

**Backend validation happens server-side.**

---

## AI Chat System

### Architecture

```
User Input → NotesView → AIService (HTTP) → Cloud Function → AI Model → Response
                ↓                                                           ↓
         AIUsageProvider ←──────────────── Usage Metadata ←────────────────┘
```

### AIService Implementation

```dart
// lib/services/ai/ai_service.dart
class AIService {
  static const String _cloudFunctionUrl = 'https://...cloudfunctions.net/askAI';
  final http.Client _httpClient;

  Future<AIResponse> sendMessage({
    required String userId,
    required String message,
  }) async {
    // Input validation
    if (message.trim().isEmpty) throw Exception('Message cannot be empty');
    if (message.length > 1000) throw Exception('Message too long');

    // HTTP POST request
    final response = await _httpClient.post(
      Uri.parse(_cloudFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'message': message}),
    ).timeout(const Duration(seconds: 30));

    // Parse response
    if (response.statusCode == 200) {
      return AIResponse.fromJson(json.decode(response.body));
    }
    throw Exception('AI service error: ${response.statusCode}');
  }
}
```

### AIResponse Model

```dart
class AIResponse {
  final String message;           // AI's response text
  final TrialInfo? trial;        // Trial status
  final UsageInfo? usage;        // Daily usage info
  
  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      message: json['message'] as String,
      trial: json['trial'] != null ? TrialInfo.fromJson(json['trial']) : null,
      usage: json['usage'] != null ? UsageInfo.fromJson(json['usage']) : null,
    );
  }
}

class TrialInfo {
  final bool isActive;
  final int daysRemaining;
}

class UsageInfo {
  final int dailyCount;
  final int dailyLimit;
}
```

### Chat Message Handling (v5.1.2)

```dart
Future<void> _handleSendMessage(String text) async {
  final message = text.trim();
  if (message.isEmpty) return;

  // ✅ Network pre-flight guard
  final aiProvider = context.read<AIUsageProvider>();
  if (!aiProvider.isOnline) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You're offline. Please reconnect.")),
    );
    return;
  }

  // Add user message to UI
  setState(() {
    _chatMessages.add(ChatMessage.user(message));
    _isLoadingAIResponse = true;
  });

  try {
    // Call AI service
    final aiResponse = await _aiService.sendMessage(
      userId: userId,
      message: message,
    );

    // Update UI with response
    setState(() {
      _chatMessages.add(ChatMessage.ai(aiResponse.message));
      _isLoadingAIResponse = false;
    });

    // Update provider state
    if (aiResponse.usage != null) {
      aiProvider.updateUsageInfo(
        messagesUsed: aiResponse.usage!.dailyCount,
        dailyLimit: aiResponse.usage!.dailyLimit,
      );
    }
  } catch (e) {
    // ✅ User-friendly error translation
    final friendlyError = ErrorMessages.getUserFriendlyMessage(e);
    setState(() {
      _chatMessages.add(ChatMessage.ai(
        'Sorry, I couldn\'t process your message.\n\n$friendlyError',
      ));
      _isLoadingAIResponse = false;
    });
  }
}
```

---

## Placements System

### PlacementsProvider (v5.1.2)

**State:**
- `List<Placement> _placements` - All active placements
- `Set<String> _appliedPlacementIds` - IDs user has applied to
- `Map<String, DateTime> _appliedDates` - Application timestamps
- `bool _isOnline` - Network connectivity state
- `String? _applyingPlacementId` - Track in-progress application

**5 Guardrails:**

```dart
Future<bool> applyForPlacement({
  required String placementId,
  required String resume,
  required String coverLetter,
}) async {
  // GUARD 1: Already applied check
  if (_appliedPlacementIds.contains(placementId)) {
    throw Exception('You have already applied to this placement');
  }

  // GUARD 2: Re-entrant call prevention
  if (_applyingPlacementId != null) {
    throw Exception('Another application is in progress');
  }

  // GUARD 3: Network check
  if (!_isOnline) {
    throw Exception("You're offline. Please reconnect and try again.");
  }

  // GUARD 4: Input validation
  if (resume.trim().isEmpty) {
    throw Exception('Resume cannot be empty');
  }

  // GUARD 5: Apply with analytics
  _applyingPlacementId = placementId;
  notifyListeners();

  try {
    await _service.applyToPlacement(
      userId: userId!,
      placementId: placementId,
      resume: resume,
      coverLetter: coverLetter,
    );

    // Update state (optimistic)
    _appliedPlacementIds.add(placementId);
    _appliedDates[placementId] = DateTime.now();
    
    // Analytics
    AnalyticsHelper.logPlacementApplySuccess(placementId);
    
    return true;
  } catch (e) {
    AnalyticsHelper.logPlacementApplyFailure(placementId, e.toString());
    rethrow;
  } finally {
    _applyingPlacementId = null;
    notifyListeners();
  }
}
```

### Apply Button UI

```dart
Widget _buildApplyButton(Placement placement, PlacementsProvider provider) {
  final hasApplied = provider.hasApplied(placement.id);
  final isApplying = provider.isApplying(placement.id);
  final isOffline = !provider.isOnline;
  final isAnyApplyInProgress = provider.isAnyApplyInProgress;

  // Show applied date
  if (hasApplied) {
    final appliedDate = provider.getAppliedDate(placement.id);
    return Text(
      'Applied • ${DateFormat('MMM d').format(appliedDate!)}',
      style: TextStyle(color: Colors.green),
    );
  }

  return ElevatedButton(
    onPressed: (isOffline || isApplying || isAnyApplyInProgress)
        ? null
        : () => _showApplyDialog(placement),
    child: isApplying
        ? const CircularProgressIndicator(color: Colors.white)
        : Text(isOffline ? 'Offline' : 'Apply Now'),
  );
}
```

---

## Development Guidelines

### Adding a New Network-Dependent Feature

**1. Create Provider:**

```dart
class NewFeatureProvider with ChangeNotifier {
  final NewFeatureService _service;
  final Connectivity _connectivity = Connectivity();
  String? userId;
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;

  Future<void> initWithUser(String newUserId) async {
    userId = newUserId;
    _startConnectivityMonitoring();
    await init();
  }

  void reset() {
    userId = null;
    _isOnline = true;
    notifyListeners();
  }

  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }
}
```

**2. Add to main.dart:**

```dart
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(
      create: (_) => NewFeatureProvider(service: NewFeatureService.instance()),
    ),
  ],
  child: MaterialApp(...),
);
```

**3. Initialize in HomePage:**

```dart
if (user != null && user.isEmailVerified) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<NewFeatureProvider>().initWithUser(user.id);
  });
}
```

**4. Add UI with offline awareness:**

```dart
Widget build(BuildContext context) {
  final provider = context.watch<NewFeatureProvider>();
  
  return Column(
    children: [
      OfflineBanner(isOffline: !provider.isOnline),
      // ... your UI
    ],
  );
}
```

**5. Add pre-flight checks:**

```dart
Future<void> performAction() async {
  if (!provider.isOnline) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You're offline. Please reconnect.")),
    );
    return;
  }
  
  try {
    await provider.doSomething();
  } catch (e) {
    final friendlyError = ErrorMessages.getUserFriendlyMessage(e);
    // Show friendlyError
  }
}
```

### Code Style Guidelines

- Use `const` constructors where possible
- Prefer named parameters for clarity
- Add doc comments for public APIs
- Use `debugPrint()` for logging (stripped in release)
- Handle `!mounted` checks in async methods
- Use `addPostFrameCallback` when calling providers from build

---

## Testing & Validation

### Pre-Commit Checklist

```bash
# 1. Run flutter analyze
flutter analyze
# Should see: "No issues found" or only deprecation warnings

# 2. Check for compilation errors
flutter build apk --debug
# Should complete without errors

# 3. Test key flows:
# - Login/logout (no Provider crash)
# - Go offline → online transitions
# - Apply to placement while online
# - Try to apply while offline (should be blocked)
# - Send AI message while online
# - Try AI message while offline (should be blocked)
```

### Critical Test Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Fresh app launch | Auth screen loads, no errors |
| Login with valid credentials | Dashboard appears, providers initialize |
| Logout → Login again | No ProviderNotFoundException, smooth transition |
| Go offline mid-session | Orange banner appears, actions disabled |
| Try action while offline | Pre-flight check blocks, shows friendly message |
| Network error during API call | Friendly error shown, technical error logged |
| Apply to placement | Optimistic UI update, button shows "Applied • Jan 21" |
| Send AI message | Response appears, usage count updates |
| Hit daily AI limit | Input disabled, hint shows "Daily limit reached" |
| Toggle dark mode | All screens update colors immediately |
| Switch to compact layout | Padding/spacing reduces across app |
| Check eligibility | Badge shows Eligible/Partial/Not Eligible |
| Edit profile | Changes save to Firestore, UI updates |
| Complete profile setup | Redirect to main app, profile loaded |
| Open settings | Theme and layout options visible |
| Change display name | Avatar initials update, Firestore synced |

---

## Appendix

### Useful Commands

```bash
# Run on Android emulator
flutter run -d emulator-5554

# Run on Windows (requires Developer Mode)
flutter run -d windows

# Build release APK
flutter build apk --release

# Clear build cache
flutter clean

# Update dependencies
flutter pub get

# Check for outdated packages
flutter pub outdated
```

### Key Files Quick Reference

- **main.dart**: App entry, provider setup
- **app_theme.dart**: Design tokens, light/dark themes
- **placements_provider.dart**: Placements state + eligibility
- **ai_usage_provider.dart**: AI usage state management
- **profile_provider.dart**: User profile state
- **theme_provider.dart**: Theme mode management
- **layout_provider.dart**: Layout density management
- **local_preferences_service.dart**: SharedPreferences wrapper
- **error_messages.dart**: Error translation utility
- **offline_banner.dart**: Offline indicator widget
- **initials_avatar.dart**: Profile avatar widget
- **notes_view.dart**: Main app screen (5 tabs: Home, Notes, Placements, Chat, Profile)
- **settings_view.dart**: User preferences screen
- **edit_profile_view.dart**: Profile editing screen
- **profile_setup_view.dart**: Onboarding flow

---

**Last Updated:** January 25, 2026 (v6.6.0)

**Maintainer:** CampusConnect Dev Team
