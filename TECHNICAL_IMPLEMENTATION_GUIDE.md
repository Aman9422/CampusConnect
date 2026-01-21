# CampusConnect - Technical Implementation Guide

**Complete technical documentation for developers**

Version: 5.1.2 (January 21, 2026)

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Version History & Evolution](#version-history--evolution)
3. [Current Implementation (v5.1.2)](#current-implementation-v512)
4. [Provider Lifecycle Management](#provider-lifecycle-management)
5. [Network Awareness & Error Handling](#network-awareness--error-handling)
6. [Firebase Integration](#firebase-integration)
7. [AI Chat System](#ai-chat-system)
8. [Placements System](#placements-system)
9. [Development Guidelines](#development-guidelines)
10. [Testing & Validation](#testing--validation)

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
└─────────────────┬───────────────────────┘
                  │ watch/read
┌─────────────────▼───────────────────────┐
│         State Management Layer          │
│  (Providers - ChangeNotifier pattern)   │
│  - PlacementsProvider                   │
│  - AIUsageProvider                      │
└─────────────────┬───────────────────────┘
                  │ uses
┌─────────────────▼───────────────────────┐
│           Business Logic Layer          │
│        (Services - Singleton)           │
│  - AuthService                          │
│  - PlacementsService                    │
│  - NotesService                         │
│  - AIService                            │
└─────────────────┬───────────────────────┘
                  │ communicates with
┌─────────────────▼───────────────────────┐
│           Data/Backend Layer            │
│  - Firebase Auth                        │
│  - Firestore Database                   │
│  - Cloud Functions (HTTPS Callable)     │
│  - HTTP REST API                        │
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

### v5.1.2 - App-Wide Standardization (Current)
**Extended guardrails to entire app:**
- Network awareness in `AIUsageProvider`
- Offline banner in AI chat
- Pre-flight network checks for AI messages
- User-friendly error translation in AI chat
- Trial expiration banner (persistent vs snackbar)
- Chat input disabled when offline/at limit
- Consistent UX across all network features

---

## Current Implementation (v5.1.2)

### Project Structure

```
lib/
├── main.dart                    # App entry, providers at root
├── constants/
│   └── routes.dart              # Named routes
├── enums/
│   └── menu_action.dart         # Menu actions enum
├── models/
│   ├── chat_message.dart        # AI chat message model
│   ├── note.dart                # Academic note model
│   ├── placement.dart           # Placement model
│   └── auth_user.dart           # User model
├── providers/
│   ├── placements_provider.dart # Placements state (v5.0+)
│   └── ai_usage_provider.dart   # AI usage state (v5.0+)
├── services/
│   ├── auth/
│   │   ├── auth_service.dart    # Auth abstraction
│   │   ├── firebase_auth_provider.dart
│   │   └── auth_exceptions.dart # Typed exceptions
│   ├── firestore/
│   │   ├── placements_service.dart # Placements CRUD
│   │   └── notes_service.dart   # Notes CRUD
│   └── ai/
│       └── ai_service.dart      # AI HTTP client
├── utilities/
│   ├── error_messages.dart      # Error translation (v5.1+)
│   ├── analytics_helper.dart    # Analytics wrapper (v5.1+)
│   └── show_error_dialog.dart   # Error dialog helper
├── views/
│   ├── login_view.dart
│   ├── register_view.dart
│   ├── verify_email_view.dart
│   ├── notes_view.dart          # Main app screen (tabs)
│   └── profile_view.dart
└── widgets/
    ├── offline_banner.dart      # Offline indicator (v5.1+)
    ├── empty_state.dart         # Empty state widget
    └── skeleton_loader.dart     # Loading skeleton
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
- **placements_provider.dart**: Placements state management
- **ai_usage_provider.dart**: AI usage state management
- **error_messages.dart**: Error translation utility
- **offline_banner.dart**: Offline indicator widget
- **notes_view.dart**: Main app screen (tabs: Home, AI Chat, Profile)
- **CHANGELOG.md**: Version history

---

**Last Updated:** January 21, 2026 (v5.1.2)

**Maintainer:** CampusConnect Dev Team
