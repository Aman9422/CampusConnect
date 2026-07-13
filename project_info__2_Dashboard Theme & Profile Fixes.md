# CampusConnect — Dashboard Theme & Profile Fixes

## Summary

Fixed theme responsiveness (dark/light mode) for Alumni and Teacher dashboards, and added Profile + Settings navigation to both dashboards so these roles can change themes like students.

---

## Changes Applied

### 1. Theme Fix: Alumni Dashboard (`lib/views/dashboards/alumni_dashboard_view.dart`)

**Problem:** The outer `Scaffold` and `AppBar` used hardcoded light-mode colors (`AppTheme.background`, `AppTheme.surface`, `AppTheme.gray900`). When user switched to dark mode via Settings → Theme, the AppBar and background stayed light while body content went dark.

**Fix:** Added `isDark` check from `Theme.of(context).brightness` and applied dark-mode-aware colors:
- `Scaffold.backgroundColor`: `isDark ? AppTheme.darkBackground : AppTheme.background`
- `AppBar.backgroundColor`: `isDark ? AppTheme.darkSurface : AppTheme.surface`
- Title icon/text colors: `isDark ? Colors.white : AppTheme.gray900`
- NotificationBadge & ChatBadge icon colors: `isDark ? AppTheme.gray400 : null`
- Popup menu icon color: `isDark ? AppTheme.gray400 : AppTheme.gray700`

---

### 2. Theme Fix: Teacher Dashboard (`lib/views/dashboards/teacher_dashboard_view.dart`)

**Same problem and fix as Alumni Dashboard** — AppBar and Scaffold now respond to theme changes.

---

### 3. Profile & Settings Navigation (Both Dashboards)

**Problem:** Students had quick access to Profile and Settings via their tabbed navigation and popup menu. Alumni and Teacher dashboards only had "Log out" in their popup menu — no way to reach Settings/Profile to change theme.

**Fix:** 
- Changed `PopupMenuButton<MenuAction>` to `PopupMenuButton<String>` to support multiple action types
- Added two menu items before logout:
  - **Profile** — navigates to `profileViewRoute`
  - **Settings** — navigates to `settingsRoute` (where theme toggle lives)
- Added "Profile" to the Professional Tools / Academic Tools grid in both dashboards (replacing "Public Profile" / "AI Insights" which were less useful)

---

### 4. Profile Route Registration (already existed)

`profileViewRoute` (`/profile-view`) was already registered in `main.dart` routes. The extracted `ProfileView` widget was already imported. No route changes needed.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/views/dashboards/alumni_dashboard_view.dart` | Theme-aware Scaffold/AppBar + Profile & Settings in popup menu + Profile in tool grid |
| `lib/views/dashboards/teacher_dashboard_view.dart` | Theme-aware Scaffold/AppBar + Profile & Settings in popup menu + Profile in tool grid |

---

## How to Test

1. Log in as Alumni or Teacher
2. Tap the three-dot menu in the AppBar → **Settings**
3. Go to **Appearance → Theme** and switch to Dark
4. Return to dashboard — entire AppBar and background should now be dark
5. Verify the same works for the other role
