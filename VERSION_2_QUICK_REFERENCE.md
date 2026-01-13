# Version 2 Quick Reference

## What Was Added

### 1. Placement Applications
- ✅ Students can apply for placements
- ✅ Application prevents duplicates
- ✅ Status shows "Applied" after submission
- ✅ Dialog collects resume information

**Flow:**
```
User taps "Apply" → Check status → Dialog → Submit → Show "Applied" badge
```

### 2. Note Downloads
- ✅ Download button opens notes in external app
- ✅ Safe (doesn't load file into app memory)
- ✅ Works offline if file already downloaded

**Flow:**
```
User taps "Download" → Parse URL → Open in browser/viewer
```

### 3. Profile Tab
- ✅ Shows student email
- ✅ Shows app version (v2.0.0)
- ✅ Logout button with confirmation
- ✅ Settings placeholders for future features

**Layout:**
```
Avatar + Name
↓
Account Info (Email, Version)
↓
Settings (Change Password, Notifications)
↓
Logout Button
```

---

## Code Locations - By Feature

### Placement Apply
| Component | Location |
|-----------|----------|
| Dialog UI | [notes_view.dart#L645-L713](lib/views/notes_view.dart#L645-L713) |
| Button Logic | [notes_view.dart#L430-L470](lib/views/notes_view.dart#L430-L470) |
| Card Integration | [notes_view.dart#L430](lib/views/notes_view.dart#L430) |
| Service Used | [placements_service.dart](lib/services/firestore/placements_service.dart) |

### Note Download
| Component | Location |
|-----------|----------|
| Handler Method | [notes_view.dart#L505-L520](lib/views/notes_view.dart#L505-L520) |
| Button Update | [notes_view.dart#L305-L310](lib/views/notes_view.dart#L305-L310) |
| Import | [notes_view.dart#L10](lib/views/notes_view.dart#L10) |

### Profile Screen
| Component | Location |
|-----------|----------|
| Build Method | [notes_view.dart#L681-L735](lib/views/notes_view.dart#L681-L735) |
| Navigation Setup | [notes_view.dart#L34-L36](lib/views/notes_view.dart#L34-L36) |
| Route Definition | [main.dart#L24](lib/main.dart#L24) |
| Info Cards | [notes_view.dart#L737-L755](lib/views/notes_view.dart#L737-L755) |

---

## Key Model Changes

### AuthUser (UPDATED)
```dart
const user = AuthService.firebase().currentUser;

// Now provides:
user.id          // User's Firebase UID
user.email       // User's email
user.isEmailVerified  // Email verification status
```

---

## Firestore Changes

### Collections Used (Unchanged)
```
placements/{placementId}
└── applications/{userId}
    ├── userId
    ├── placementId  
    ├── resume
    ├── appliedAt (timestamp)
    └── status: 'pending'
```

**No schema changes needed.**

---

## Testing Quick Start

### Test Placement Apply
```
1. Go to Placements tab
2. Find an open (non-expired) placement
3. Tap "Apply" button
4. Enter some resume text
5. Tap "Submit"
6. See "Applied" badge appear
7. Refresh/reopen - badge persists
```

### Test Note Download
```
1. Ensure a note has downloadUrl in Firestore
2. Go to Notes tab
3. Tap "Download" button on that note
4. Browser/viewer opens
5. File downloads or opens
```

### Test Profile
```
1. Tap Profile tab (5th icon)
2. See student email and v2.0.0
3. Tap "Logout" button
4. Confirm logout
5. Return to login screen
```

---

## Debugging Tips

### Application Not Submitting?
- Check user ID: `AuthService.firebase().currentUser?.id`
- Check Firestore rules allow writes to `placements/{id}/applications/{userId}`
- Check network: Ensure Firebase is reachable

### Download Not Opening?
- Check `downloadUrl` is a valid HTTP/HTTPS URL
- Check URL works in browser manually
- Check app has internet permission in manifest

### Profile Tab Missing?
- Ensure `pubspec.yaml` saved
- Run `flutter clean` then `flutter pub get`
- Restart app

---

## Dependencies Added

```yaml
url_launcher: ^6.2.0  # For opening URLs
```

All other dependencies unchanged from v1.

---

## Safety Checklist

- ✅ No existing code was rewritten
- ✅ All v1 features still work
- ✅ No new permissions required
- ✅ Firestore security rules unchanged
- ✅ Material 3 design maintained
- ✅ No breaking changes to interfaces

---

## Version Info

- **Current:** v2.0.0
- **Release Date:** January 13, 2026
- **Branch:** v2-development
- **Stable Base:** v1.0.0

---

## Next Major Features (v3+)

- AI Chat integration
- Resume management
- Change password
- Notification settings
- Email preferences
