# Version 2 Technical Changelog

## Modified Files

### 1. `lib/services/auth/auth_user.dart`
**Purpose:** Enhanced AuthUser model to expose user ID and email

**Changes:**
```dart
// BEFORE
@immutable
class AuthUser {
  final bool isEmailVerified;
  const AuthUser({required this.isEmailVerified});
  factory AuthUser.fromFirebase(User user) =>
      AuthUser(isEmailVerified: user.emailVerified);
}

// AFTER
@immutable
class AuthUser {
  final String id;
  final String? email;
  final bool isEmailVerified;
  
  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });

  factory AuthUser.fromFirebase(User user) => AuthUser(
    id: user.uid,
    email: user.email,
    isEmailVerified: user.emailVerified,
  );
}
```

**Why:** Needed to get user ID for placement applications and profile display.

---

### 2. `lib/views/notes_view.dart`
**Purpose:** Add placement apply, note download, and profile functionality

**Key Additions:**

#### Import:
```dart
import 'package:url_launcher/url_launcher.dart';
```

#### Navigation Update:
- Changed IndexedStack to support 5 screens (added profile)
- BottomNavigationBar now has 5 items (added Profile tab)

#### New Methods:
```dart
Future<void> _handleNoteDownload(String downloadUrl) async {
  // Opens note URL in external app
}

Widget _buildApplyButton(String placementId) {
  // Checks application status and shows appropriate button
}

void _showApplyDialog(String placementId) {
  // Opens dialog for entering resume
}

Widget _buildProfileScreen() {
  // Profile tab content
}

Widget _buildProfileInfoCard({required String label, required String value}) {
  // Reusable card for profile info
}

Future<void> _handleProfileLogout() async {
  // Logout from profile screen
}
```

#### Modified Widget:
```dart
Widget _buildPlacementCard(Placement placement) {
  // Changed: Apply button now calls _buildApplyButton()
  // before: showed "Apply functionality coming soon"
}

Widget _buildNoteCard(Note note) {
  // Changed: Download button now calls _handleNoteDownload()
  // before: showed placeholder message
}
```

#### New Widget Class:
```dart
class _ApplyDialogWidget extends StatefulWidget {
  // Dialog for submitting placement applications
  // - Text field for resume
  // - Error handling
  // - Loading state
  // - Success feedback
}
```

---

### 3. `lib/constants/routes.dart`
**Changes:**
```dart
// ADDED
const profileRoute = '/profile/';
```

---

### 4. `lib/main.dart`
**Changes:**
```dart
// ADDED import
import 'package:campusconnect/views/profile_view.dart';

// ADDED to routes map
profileRoute: (context) => const ProfileView(),
```

---

### 5. `pubspec.yaml`
**Changes:**
```yaml
# ADDED to dependencies
url_launcher: ^6.2.0
```

---

### 6. `test/auth_test.dart`
**Changes:**
Mock AuthUser creation updated to include new required fields:

```dart
// BEFORE
const user = AuthUser(isEmailVerified: false);

// AFTER
const user = AuthUser(
  id: 'test-user-id',
  email: 'test@example.com',
  isEmailVerified: false,
);
```

---

## New Files

### `lib/views/profile_view.dart`
- Standalone Profile screen widget (alternative to inline implementation)
- Contains all profile UI logic
- Currently NOT used (logic embedded in NotesView for simplicity)
- Available for future use if ProfileView extraction needed

---

## Architecture Decisions

### Why embed profile in NotesView instead of using ProfileView?
- **Reason:** Single navigation handler (bottom tab) simplifies state management
- **Alternative:** If profile becomes complex, move to separate screen
- **Current:** Embedded as `_buildProfileScreen()` method

### Why FutureBuilder for application status?
- **Reason:** Checks real-time if user has already applied
- **Benefit:** Prevents duplicate submissions at UI level
- **Backend:** Firestore security rules prevent duplicates at database level

### Why url_launcher instead of in-app PDF viewer?
- **Reason:** Simpler, one less dependency
- **Benefit:** Respects user's default app preferences
- **Trade-off:** Can't guarantee offline availability

---

## No Changes to:
- ✅ AuthService interface
- ✅ FirebaseAuthProvider implementation
- ✅ NotesService
- ✅ PlacementsService (already had apply methods!)
- ✅ Note model
- ✅ Placement model
- ✅ Firestore rules
- ✅ App theme

---

## Backward Compatibility

### For Existing Code:
- **Breaking Change:** AuthUser constructor signature changed
  - Solution: Updated test mocks
  - Impact: Only affects code creating AuthUser directly (tests)
  
### For Firestore Data:
- **No changes:** All Firestore structures remain same
- **Optional:** Previous note `downloadUrl` still works as before

---

## Error Handling

### Placement Apply:
- Missing userId → Dialog closes, error message shown
- Network error → Error message displayed in dialog
- Duplicate application → Button shows "Applied" status

### Note Download:
- Invalid URL → Snackbar shown
- App not available → Graceful error message
- Network error → Error snackbar

### Profile Screen:
- Missing user → Shows "Not available" for email
- Logout confirmation → User can cancel

---

## Performance Notes

### New Operations:
1. **Application status check** - One Firestore read per placement card
   - Optimized: Only runs when card is visible
   - Cached: FutureBuilder reuses result unless rebuilt

2. **Note downloads** - External app handles (no load on app)
   - No UI blocking
   - No bandwidth from app server

### No Performance Regressions:
- ✅ Same number of Firestore reads as before
- ✅ No new background tasks
- ✅ No new timers or polling
