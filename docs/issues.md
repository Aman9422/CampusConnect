# CampusConnect v8.4 — Student Resume Portfolio: Issue Audit

> Audit date: 2026-08-02 · Scope: `docs/Task.md` v8.4 feature set (models, services, provider, validators, UI, rules, integration).
> Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

## ✅ Fix Status (2026-08-02)

All issues below were verified against source and fixed unless noted. See `project_info__9_bugfix_of_v8.4.md` for the implementation report.

| Issue | Status | Deploy note |
|-------|--------|-------------|
| C1, C2, C3 | ✅ Fixed in code | — |
| C4 (login stuck after email verification) | ✅ Fixed in code | Wait for the fix in `verify_email_view.dart` |
| H1–H5 | ✅ Fixed in code | H5 = 41/41 tests passing |
| H2, C3 (`storage.rules`) | ✅ Fixed in file | **Blocked**: Firebase Storage not yet provisioned in the console — run `Get Started` at Storage, then `firebase deploy --only storage` |
| M3 (`firestore.rules`) | ✅ Fixed + **deployed** | `firebase deploy --only firestore:rules` succeeded |
| M1, M4, M5, M6, M8, M9, M10, M12, M13 | ✅ Fixed in code | — |
| M2 | 📋 Documented decision | Alumni whole-doc read retained (nested-map design) — comment added in `firestore.rules` |
| M7 | ⏳ Deferred | Shared preview widget extraction — cleanup pass |
| L1, L2, L4, L5, L7 | ✅ Fixed in code | — |
| L3, L6 | ⏸️ Intentional / pre-existing | No change |

---

## 🔴 Critical

### C4. New verified account can't log in — root AuthGuard route torn down mid-flow
- **Files**: `lib/views/register_view.dart` (`_handleRegister`), `lib/views/verify_email_view.dart` (`_backToLogin`), `lib/views/profile_setup_view.dart` (`_completeSetup`), `lib/main.dart` (`AuthGuard` home widget)
- **Problem**: After registering, verifying the email, and tapping "Back to Sign In", the user can't get past the login screen even though the credentials are accepted (Firebase logs "Notifying auth state listeners about user"). Restarting the app goes straight to "Complete Your Profile" — proving auth is fine and the bug is in the **navigation stack**. Two coupled bugs, both variants of the same root-cause family (`pushNamedAndRemoveUntil(…, (_) => false)` removing the app's root `AuthGuard` route):
  1. **`RegisterView`** called `Navigator.pushNamedAndRemoveUntil(verifyEmailRoute, (_) => false)` after account creation. Because `AuthGuard` is the app's `home` route, that removed the root route **and AuthGuard itself** from the stack — destroying the `StreamBuilder` that listens to `authStateChanges`. With no listener, a later successful login had no effect until the app was restarted (a fresh stack brings AuthGuard back → straight to Profile Setup).
  2. **`VerifyEmailView._backToLogin`** called `Navigator.pushNamedAndRemoveUntil(loginRoute, (_) => false)` when the user tapped "Back to Sign In", pushing a **second** `LoginView` on top of whatever root remained. Login `AuthGuard` would rebuild underneath, but the stale pushed `LoginView` stayed on top, so the UI never changed.
- **Fix**:
  - `RegisterView`: `pushReplacementNamed(verifyEmailRoute)` — replaces only the register route, keeping the root `AuthGuard` route (and its `authStateChanges` listener) alive.
  - `VerifyEmailView._backToLogin`: `Navigator.popUntil((route) => route.isFirst)` — pops back to the live root; AuthGuard's home already shows `LoginView` while signed out.
  - `ProfileSetupView._completeSetup`: same teardown pattern at the end of profile setup — `pushNamedAndRemoveUntil(dashboardRoute, (_) => false)` also removed the root. Now it just calls `popUntil((route) => route.isFirst)`; `markProfileCompleted()` + `setRole()` already notify the providers, and AuthGuard's `Consumer2` rebuilds to the role-aware dashboard. This keeps AuthGuard alive so logout from the dashboard still routes back to the login screen without a restart.
- **Regression test**: `test/verify_email_navigation_test.dart` mirrors the register→verify→Back-to-Sign-In flow (with a placeholder register screen that replaces itself via `pushReplacementNamed`) and asserts exactly one `LoginView` remains — the old bugs would yield 0 (root removed) or 2 (duplicate login pushed).

### C1. Resume upload is broken on every non-web platform (Android/iOS/desktop)
- **Files**: `lib/views/portfolio/resume_upload_screen.dart` (`_pickAndUpload`), `lib/services/storage/storage_service.dart` (`uploadResume`)
- **Problem**: The picker always calls `provider.uploadResume(bytes: …)` and **never passes `filePath`**. In `StorageService.uploadResume`, the non-web branch (`kIsWeb == false`) requires `filePath != null`:
  ```dart
  } else {
    final path = filePath;
    if (path == null || path.isEmpty) {
      throw const StorageServiceException('Could not read the selected file.');
    }
  ```
  `_pickAndUpload` never supplies `filePath`, so **every upload on Android, iOS, Windows, macOS and Linux throws** and the UI shows "Could not read the selected file." The feature only works on web.
- **Additional wrinkle**: file_picker's `withData: true` is only honoured on Android/iOS/web; on desktop `PlatformFile.bytes` is `null`, which also makes the `length == 0 → "The selected file is empty."` check fail before upload even starts.
- **Fix**: detect platform in `_pickAndUpload` — pass `filePath: file.path` on non-web, `bytes: file.bytes` on web; validate using `file.size` instead of `bytes.length`; drop `withData: true` on desktop.

### C2. `PortfolioModel.educationFilled` is hardcoded to `true`
- **File**: `lib/models/portfolio/portfolio_model.dart`
- **Problem**:
  ```dart
  bool get educationFilled => true; // Academic info lives in the user profile
  ```
  The getter **always returns true**, so `profileCompletion` always awards `+10` for education. Every portfolio — even one with zero academic data — starts at ≥10% "Portfolio Strength". The completion score is inflated and misleading, and it is displayed prominently (`Portfolio Strength` header, read-only header `% complete`).
- **Fix**: remove the education points from `profileCompletion` (the model has no access to the profile), or pass academic data into the calculation. The comment "Academic info lives in the user profile" confirms the model cannot know this — the +10 should be deleted or the UI should source it from `ProfileProvider`.

### C3. Teachers cannot download/view student resumes (broken Storage rule)
- **File**: `storage.rules`
- **Problem**:
  ```
  allow read: if request.auth != null &&
    (request.auth.uid == userId ||
     request.auth.token.role == 'teacher' ||
     firestore.get(.../users/$(request.auth.uid)).data.role == 'alumni');
  ```
  - `request.auth.token.role` refers to a **custom claim** named `role`. No `setCustomUserClaims` exists anywhere in `functions/index.js` or `scripts/seed_firestore/seed.js` — the user's role lives in Firestore, not in the auth token. This branch is always `false`, so **teachers get `permission-denied` when tapping "View Resume"** in the read-only portfolio view (reachable from `student_analytics_view.dart`).
  - The alumni branch calls `firestore.get(...)` with **no `exists()` guard**: if the viewer's user document is missing (or the role field is absent), the rule throws and denies the read.
- **Fix**: drop the token-claim branch; keep owner + alumni (with `exists()` + role check), and for teachers use the same `firestore.get` role check used elsewhere:
  ```
  match /resumes/{userId}/{fileName} {
    allow read: if request.auth != null &&
      (request.auth.uid == userId ||
       firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role in ['teacher', 'alumni']);
  }
  ```

---

## 🟠 High

### H1. Edit Portfolio re-seeds form fields and can wipe unsaved edits
- **File**: `lib/views/portfolio/edit_portfolio_screen.dart` (`didChangeDependencies`)
- **Problem**: `didChangeDependencies` unconditionally overwrites all `TextEditingController`s, `_roleChips`, `_locationChips` and the remote/relocation values from the portfolio. It runs again on any inherited-widget change (theme toggle, route changes, provider rebuilds). A student who types link/salary edits and then, say, adds a skill (which triggers `savePortfolio` → `notifyListeners`) can have their in-progress, not-yet-saved input silently reset to the last saved portfolio.
- **Fix**: seed fields once — move the seeding logic into `initState` (portfolio is already initialized before this screen is pushed) or guard with an `_isSeeded` flag.

### H2. Storage rules do not enforce PDF-only or 5 MB limit server-side
- **File**: `storage.rules`
- **Problem**: Task validation says "PDF upload only, maximum resume size", but `allow write` only checks `request.auth.uid == userId`. A malicious or buggy client can upload arbitrary content-types and arbitrarily large files to `resumes/{uid}/…`. The limit exists only client-side.
- **Fix**: enforce in rules:
  ```
  allow write: if request.auth != null && request.auth.uid == userId &&
    request.resource.contentType.matches('application/pdf') &&
    request.resource.size < 5 * 1024 * 1024;
  ```

### H3. `PortfolioValidators.optionalUrl` bug when `allowHttp: false`
- **File**: `lib/utilities/portfolio_validators.dart`
- **Problem**:
  ```dart
  final hasValidScheme =
      lower.startsWith('https://') ||
      lower.startsWith('http://') ||
      (!allowHttp && lower.startsWith('https://'));
  ```
  The second clause accepts `http://` **unconditionally**, so `allowHttp: false` is ineffective (an `http://` URL still passes). The third clause is dead logic (first clause already accepts `https://`).
- **Fix**: `final hasValidScheme = lower.startsWith('https://') || (allowHttp && lower.startsWith('http://'));`

### H4. `savePortfolio` writes the entire nested `portfolio` map → stale-overwrite risk
- **File**: `lib/services/firestore/portfolio_service.dart`
- **Problem**: every save (`savePortfolio`, upload, delete) does a merge-set of `{'portfolio': portfolio.toMap()}` — i.e. a **whole-map read-modify-write** from the in-memory copy loaded at login. If the user edits on a second device (or a future admin/automation updates portfolio fields), the next save on the first device silently clobbers those fields because Firestore merge merges at the top level only (`portfolio` key), not per-field.
- **Fix**: write per-section paths (`portfolio.skills`, `portfolio.projects`, …) with merge for the sections actually changed, or document the single-device assumption.

### H5. No test coverage for the new feature
- **Files**: `test/` (only `auth_test.dart`, `auth_regression_test.dart` exist)
- **Problem**: zero unit tests for `PortfolioModel` (completion, copyWith, empty), models' `fromMap/toMap` round-trips, validators (required/URL/duplicate), `StorageService.validateResumeFile`, and provider save/upload/delete flows. For a "production-quality" feature this is a gap.
- **Fix**: add `test/portfolio_model_test.dart`, `test/portfolio_validators_test.dart`, and a provider test with mock services.

---

## 🟡 Medium

### M1. `EditPortfolioScreen` skill chips are add/remove only — no editing category/proficiency
- **File**: `lib/views/portfolio/edit_portfolio_screen.dart`
- Once added, a skill's category/proficiency can never be changed (only delete + re-add). Also chips render only the skill name, hiding category/proficiency in the editor. Suggest an edit-on-tap dialog.

### M2. Read-only portfolio access exposes full PII of any student
- **File**: `firestore.rules`
- `allow read: if isAuthenticated() && userRole() == 'alumni' && resource.data.role == 'student';` grants alumni the **whole user document** (phone, email, academic data) for any student, not just `portfolio`. The mentorship context only needs the portfolio. Consider a `users/{userId}/portfolio` subcollection or an `allow read` scoped to `resource.data.portfolio` field (not possible for whole-doc reads) — at minimum flag this as a privacy decision.

### M3. `userRole()` helper in `firestore.rules` has no `exists()` guard
- **File**: `firestore.rules`
- `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role` throws if the requesting user’s doc is missing → all rule checks that use it deny. Safer: `get(...).data.role in ['teacher','alumni']` wrapped in an exists() check. Same pattern issue as C3.

### M4. Career Preferences section hidden when only defaults are set
- **Files**: `student_portfolio_screen.dart`, `portfolio_read_only_view.dart`
- `hasContent` only checks roles/locations/salary, but remote/relocation always have defaults (`Hybrid`/`Open`). If the student only picked remote preference (defaults), the whole section disappears; conversely the edit screen always shows remote/relocation. Inconsistent presentation.

### M5. "My Portfolio" entry appears on the Teacher profile
- **File**: `lib/views/profile/profile_view.dart`
- The profile view branches on `isAlumni`, so teachers fall into the student branch and see the "My Portfolio" menu tile (which pushes the **editable** `studentPortfolioRoute`). Teachers would unknowingly be able to build/edit their own portfolio. Students-only gating is missing.

### M6. Preview screens use `dynamic` casts instead of typed models
- **Files**: `student_portfolio_screen.dart` (`_buildProjectTile(dynamic project)`), `resume_upload_screen.dart` (`_buildCurrentResume(dynamic resume)`)
- Both receive `ProjectModel`/`ResumeMetadata` already — the `dynamic` + `as` casts are unnecessary and defeat static analysis (a runtime cast error would crash the widget).

### M7. Redundant preview implementation duplicated in read-only view
- **Files**: `student_portfolio_screen.dart` vs `portfolio_read_only_view.dart`
- The skill chips, project tiles, education section, social-link icons/labels, and link-launch code are near-duplicates. Extract a shared `PortfolioPreviewSections` widget so both screens stay consistent.

### M8. Dead code
- `PortfolioService.updateResumeMetadata(...)` and `PortfolioService.deletePortfolio(...)` — never called (upload/delete go through `savePortfolio`).
- `ResumeUploadResult.version`/`toMetadataMap()` — value is ignored by `PortfolioProvider.uploadResume` (it recomputes version) and `toMetadataMap` is never used.
- `PortfolioValidators.duplicateSkill` / `isValidProject` — never invoked by any screen (duplicate check is inline in `_SkillDialog`; project form enforces via Title + tech-chips). Note: `isValidProject` exists because spec says "prevent empty projects", but description is optional and the real guard is "≥1 technology required".
- `PortfolioValidators.maxResumeBytes` duplicates `StorageService.maxResumeBytes` — two sources of truth for the 5 MB constant.

### M9. Teachers at-risk: project/experience `endDate < startDate` not validated on load
- **Files**: `projects_manager_screen.dart`, `experience_manager_screen.dart` pickers reset the other date, but data seeded/stored by older clients could render "Aug 2024 — Dec 2023". No defensive sort on display. Low likelihood, worth a guard in the formatter.

### M10. `PortfolioModel.fromMap` assumptions can throw on corrupted/historical data
- **File**: `lib/models/portfolio/portfolio_model.dart`
- Hard casts like `map['resume'] as Map<String, dynamic>` and `e as Map<String, dynamic>` will throw if a field is malformed. `getPortfolio`/`portfolioStream` swallow errors (`getPortfolio`) but `portfolioStream` maps directly and would surface an error on the stream → potential crash. Use tolerant casts with fallbacks (as the scalar fields already do).

### M11. Resume filename is always re-written as `resume.pdf`
- **Files**: `storage_service.dart` (`fileName: resumeFileName`), `portfolio_provider.dart`
- The original picked filename (`fileName` param) is discarded; metadata stores the canonical `resume.pdf`. Acceptable for the fixed storage path, but the parameter is misleading and the preview shows "resume.pdf" even if the user uploaded `My_Resume_v9.pdf`.

### M12. Teacher dashboard logout does not reset `PortfolioProvider`
- **File**: `lib/views/dashboards/teacher_dashboard_view.dart` (`_resetProviders`)
- The auth-guard safety net in `main.dart` does reset it, so no data leak today, but the teacher logout path omits it while the student path includes it — inconsistent and fragile if the safety net changes.

### M13. Stale hardcoded app version labels
- **File**: `lib/views/profile/profile_view.dart` — `'v7.3.0'` / `'v7.5.0'` hardcoded while `pubspec.yaml` says `5.1.2+3` and the app is on v8.4. Cosmetic, but misleads users/support.

---

## 🔵 Low

### L1. `PortfolioModel.isEmpty` ignores `preferences`
A portfolio containing only career-preferences data is still flagged "empty" → the "Build your portfolio" empty-state CTA shows on top of the preferences section.

### L2. Projects preview omits durations/links
`StudentPortfolioScreen._buildProjectTile` does not render dates/"Ongoing", GitHub/demo links (unlike the read-only view and the manager). Inconsistent presentation of the same data.

### L3. `project` save requires ≥1 technology
Editing a legacy/imported project with an empty `technologies` list is impossible without adding a tech — consider allowing empty tech list when title/description exist (`isValidProject`).

### L4. `initWithUser` early-return ignores a different `userId`
`if (_isInitialized && _portfolio != null) return;` — if a second user logs in without a `reset()` in between, the previous user's portfolio persists. Safe today only because every logout path resets; a guard comparing `_lastUid != userId` would make it robust.

### L5. `refresh()` can `notifyListeners()` after `reset()`
No `_isDisposed` guard in `refresh()`'s `finally` (unlike `initWithUser`). A pull-to-refresh racing a logout could notify on a disposed provider.

### L6. Docs/Task says "Only owner can edit" — this holds, but subcollection catch-all grants broad write
`match /{subcollection=**} { allow read, write: if isOwner(userId); }` — pre-existing, not introduced by v8.4, but worth noting the portfolio fields are protected only by the whole-doc owner rule.

### L7. `resume_upload_screen.dart` delete button loop
`onPressed: isSaving || isUploading ? null : () => _deleteResume(userId)` — `isSaving` is true during a delete, so the "Remove Resume" button disables itself correctly, but `_isDeleting` also drives the spinner — double flag for one state.

---

## Reachability summary (everything new is wired up)

| Feature | Entry point | Status |
|---|---|---|
| Student Portfolio preview | Student dashboard "My Portfolio" shortcut + Profile "My Portfolio" tile | ✅ |
| Edit Portfolio | Preview app-bar edit + empty-state CTA | ✅ |
| Projects / Certs / Experience / Achievements managers | Edit Portfolio tiles | ✅ |
| Resume upload | Preview + Edit + empty state | ✅ (but see C1) |
| Teacher read-only view | `StudentAnalyticsView` leaderboard eye icon (`portfolioReadOnlyRoute`, arg = studentId) | ✅ |
| Alumni read-only view | `MentorshipRequestDetailView` "View Student Portfolio" (role-gated) | ✅ |
| Provider init/reset | `main.dart` AuthGuard (init after role/profile; reset on logout) | ✅ |
| Routes registered | `main.dart` `routes:` map | ✅ |

## Top fixes to ship before calling v8.4 done

1. **C1** — pass `filePath` on mobile/desktop, use `file.size`, drop `withData` on desktop. Verify on one Android device + one desktop target.
2. **C2** — remove the fake +10 education completion points (or compute from profile).
3. **C3** — fix `storage.rules` teacher/alumni read (remove token claim; add `exists()`).
4. **H2** — enforce PDF + 5 MB in storage rules.
5. **H1** — seed the edit form once (initState/`_isSeeded`).
6. **H3** — fix `optionalUrl` allowHttp logic.
7. **H5** — add portfolio unit tests.
