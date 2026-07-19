# v8.1 — Runtime Problems & Solutions

## Problem 1: Flutter Crash — `setState() / markNeedsBuild() called during build`

### Symptoms
When launching the app as a teacher, the app crashes immediately with:
```
════════ Exception caught by foundation library ════════════════
setState() or markNeedsBuild() called during build.
```

Repeated many times as the `StudentAnalyticsView` (Tab 1) tries to load analytics during widget construction.

### Root Cause
`lib/views/teacher/student_analytics_view.dart` — `initState()` calls Provider methods synchronously:

```dart
// ❌ BROKEN: called loadAnalytics directly in initState
@override
void initState() {
  super.initState();
  _loadAnalytics(); // Calls notifyListeners() during build phase → crash
}
```

`TeacherAnalyticsProvider.loadAnalytics()` sets `_isLoading = true` and calls `notifyListeners()`. Since `initState()` executes during the framework's build phase, `notifyListeners()` triggers a widget rebuild before the framework is ready — causing the crash.

### Why it didn't crash before v8.1
`StudentAnalyticsView` was a standalone page navigated to via `Navigator.pushNamed()`. It was never mounted as a tab by `IndexedStack` before. With v8.1, it's Tab 1 and gets mounted immediately when the dashboard renders.

### ✅ Fix Applied
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _loadAnalytics();
  });
}
```

**File:** `lib/views/teacher/student_analytics_view.dart`

---

## Problem 2: Firestore Permission Denied — `PERMISSION_DENIED`

### Symptoms
Every `TeacherAnalyticsService` query fails:
```
[cloud_firestore/permission-denied] The caller does not have permission
```

All 5 analytics queries fail:
1. `getResumeReviewStats()` — queries `collectionGroup('resumeReviews')`
2. `getStudentResumeData()` — queries `collection('users').where('role',==,'student')`
3. `getPlacementPredictionIndicators()` — calls `getStudentResumeData()`
4. `getSkillGapAnalysis()` — queries `collectionGroup('resumeReviews')`
5. `getPerformanceTrendInsights()` — queries `collectionGroup('resumeReviews')` with where

### Root Cause
`firestore.rules` only allowed users to read their own documents:
```javascript
match /users/{userId} {
  allow read: if isOwner(userId);  // Only own profile
  
  match /resumeReviews/{reviewId} {
    allow read: if isOwner(userId);  // Only own reviews
  }
}
```

No rule existed allowing a teacher to:
- Read other users' profiles (`users` collection with `role == 'student'` filter)
- Read other users' resume reviews (`collectionGroup('resumeReviews')`)

### ✅ Fix Applied

**File:** `firestore.rules`

Three changes:

**1. Added `isTeacher()` helper:**
```javascript
function isTeacher() {
  return isAuthenticated() && userRole() == 'teacher';
}
```

**2. Users collection — teachers can read all user profiles:**
```javascript
match /users/{userId} {
  allow read: if isOwner(userId);
  allow read: if isTeacher();  // v8.1: teacher analytics
  // alumni directory rule unchanged...
  
  match /resumeReviews/{reviewId} {
    allow read: if isOwner(userId) || isTeacher(); // v8.1
  }
}
```

**3. Top-level collectionGroup rule for teacher analytics:**
```javascript
match /{path=**}/resumeReviews/{reviewId} {
  allow read: if isTeacher();
}
```

This enables the `collectionGroup('resumeReviews')` queries used by `TeacherAnalyticsService.getResumeReviewStats()`, `getSkillGapAnalysis()`, and `getPerformanceTrendInsights()`.

---

## Deployment

### To deploy Firestore rules:
```bash
firebase deploy --only firestore:rules
```

### Files Modified
| File | Change |
|------|--------|
| `lib/views/teacher/student_analytics_view.dart` | Wrapped `_loadAnalytics()` in `addPostFrameCallback` |
| `firestore.rules` | Added `isTeacher()` function + read permissions for users + collectionGroup |
| `docs/sol.md` | This file |

---

## Summary

| # | Problem | File | Severity | Status |
|---|---------|------|----------|--------|
| 1 | `setState() during build` crash | `lib/views/teacher/student_analytics_view.dart` | 🔴 Crash | ✅ Fixed |
| 2 | Firestore PERMISSION_DENIED | `firestore.rules` | 🔴 All analytics fail | ✅ Fixed |
