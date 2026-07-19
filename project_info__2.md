# Runtime Crash Analysis — Two Distinct Bugs Found

## Bug 1: `setState() / markNeedsBuild() called during build` ⚠️

### Root Cause
In `lib/views/teacher/student_analytics_view.dart`, lines 25-28:
```dart
@override
void initState() {
  super.initState();
  _loadAnalytics();  // ← Calls Provider methods during build phase
}
```

`_loadAnalytics()` calls `context.read<TeacherAnalyticsProvider>().loadAnalytics()` which sets `_isLoading = true` and calls `notifyListeners()`. Since `initState()` runs during the widget build phase, `notifyListeners()` triggers a rebuild while the framework is already building — causing the crash:

```
#4 TeacherAnalyticsProvider.loadAnalytics (teacher_analytics_provider.dart:39)
#5 _StudentAnalyticsViewState._loadAnalytics (student_analytics_view.dart:35)
#6 _StudentAnalyticsViewState.initState (student_analytics_view.dart:27)
```

### Fix
The Teacher Dashboard's `_TeacherDashboardTab` already does this correctly:
```dart
// teacher_dashboard_view.dart — CORRECT pattern ✅
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.read<TeacherAnalyticsProvider>().loadAnalytics();
    // ...
  });
}
```

But `StudentAnalyticsView` does **not** use `addPostFrameCallback`:
```dart
// student_analytics_view.dart — BROKEN pattern ❌
@override
void initState() {
  super.initState();
  _loadAnalytics();  // Should be wrapped in addPostFrameCallback
}
```

**This is a pre-existing bug** (from v7.2), not introduced by v8.1. It was latent because `StudentAnalyticsView` was never navigated to on initial app load before. Now that it's Tab 1 of the Teacher Dashboard, `IndexedStack` mounts it immediately.

---

## Bug 2: Firestore PERMISSION_DENIED for Teacher Analytics

### Root Cause
`TeacherAnalyticsService` queries:
1. `collectionGroup('resumeReviews')` — to get all students' resume reviews
2. `collection('users').where('role', isEqualTo: 'student')` — to get all student profiles

But the Firestore rules only allow:
```javascript
match /users/{userId} {
  allow read: if isOwner(userId);  // Only own profile
  match /resumeReviews/{reviewId} {
    allow read: if isOwner(userId);  // Only own reviews
  }
}
```

There is **no rule** allowing a teacher to read other users' profiles or resume reviews. Every query is denied.

### Service Requirements (from `teacher_analytics_service.dart`)
The service needs to:
- Read all student profiles (`users where role==student`)
- Read all resume reviews (`collectionGroup('resumeReviews')`)
- Read counts (`collection('users/{uid}/resumeReviews').count()`)

### Fix Required in `firestore.rules`
Add teacher access rules:
```javascript
function isTeacher() {
  return isAuthenticated() && userRole() == 'teacher';
}

match /users/{userId} {
  // Allow teachers to read any user for analytics
  allow read: if isAuthenticated() && (
    isOwner(userId) ||
    isTeacher() ||
    (resource.data.role == 'alumni' && resource.data.profileCompleted == true)
  );

  match /resumeReviews/{reviewId} {
    allow read: if isOwner(userId) || isTeacher();
    allow create: if isOwner(userId);
    allow update, delete: if isOwner(userId);
  }
}
```

Additionally, a top-level collectionGroup rule:
```javascript
// Allow teacher collectionGroup queries on resumeReviews
match /{path=**}/resumeReviews/{reviewId} {
  allow read: if isAuthenticated() && (
    request.auth.uid == resource.data.userId ||
    isTeacher()
  );
}
```

---

## Summary

| Bug | Severity | File | Type |
|-----|----------|------|------|
| `setState() during build` | 🔴 Crash | `lib/views/teacher/student_analytics_view.dart` | Flutter lifecycle bug — pre-existing v7.2 |
| Firestore permission denied | 🔴 All analytics fail | `firestore.rules` | Security rules — never configured for teacher role |

Both bugs need fixing for the app to work with a teacher account. Bug 1 is a 1-line fix wrapping `_loadAnalytics()` in `addPostFrameCallback`. Bug 2 requires adding `isTeacher()` rules to Firestore security rules.