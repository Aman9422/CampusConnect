# CampusConnect v8.4 — Final Audit & Architecture Stability Review

> Audit date: 2026-08-03 · Scope: `docs/Task.md` v8.4, `docs/issues.md`, `docs/v8_workspace_tracker.md`, `project_info__7.md` → `project_info__10` + full source review of the v8.4 portfolio feature, auth flow, routing, Firestore/storage rules, indexes and Cloud Functions.
> Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low
> This document is the deliverable requested in the final audit task. A mirror copy exists at `project_info__11.md`.

---

## Summary

CampusConnect v8.4 (Student Resume Portfolio) is largely implemented and the previously-reported crash bugs are genuinely fixed in source — the **eye-icon crash** (`PortfolioReadOnlyView.initState` → deferred `_load` via `addPostFrameCallback`), the **C4 login-stuck navigation teardown** (`pushReplacementNamed` + `popUntil`, keeping the root `AuthGuard` alive), the **C1 platform-split resume upload** (`filePath` vs `bytes`, `file.size` validation), and the **C3/H2 storage rules** (`exists()` guard + server-side PDF/5 MB enforcement).

**However, the workspace tracker and `docs/issues.md` claim several fixes that are NOT present in the current source.** H4 (per-section diff saves), L4 (uid guard in `initWithUser`), L5 (`_isDisposed` guard in `refresh`) and most of M8 (dead-code removal) are documented as fixed in the "v8.4.5 Bugfix" section but **do not exist in the code**. A developer trusting the tracker will assume these are landed when they are not.

The audit also found **new, previously-undocumented issues**: an unregistered route (`chatDetailRoute`) that crashes on activity-feed taps, a logic-nesting bug in `MentorshipRequestDetailView` that makes the entire v7.3 mentorship-completion flow unreachable, a role-escalation vulnerability in `firestore.rules` (users can self-write their `role`), and a missing Firestore composite index that silently disables all `maybeCreateNotification`-driven notifications.

---

## 1. Verified-Fixed (code matches the docs)

| Issue | Evidence in source |
|-------|--------------------|
| **Eye-icon crash** (`project_info__10`) | `portfolio_read_only_view.dart` initState now uses `WidgetsBinding.instance.addPostFrameCallback`; `_ModalScopeStatus` crash impossible. Regression test `test/portfolio_read_only_view_test.dart` added. |
| **C4 Login-stuck after email verification** | `register_view.dart` uses `pushReplacementNamed(verifyEmailRoute)`; `verify_email_view.dart` `_backToLogin` calls `logOut()` then `popUntil(route.isFirst)`; `profile_setup_view.dart` `_completeSetup` ends with `popUntil(route.isFirst)`. Test `verify_email_navigation_test.dart` added. |
| **C1 Non-web resume upload** | `resume_upload_screen.dart` `_pickAndUpload`: `withData: kIsWeb`, `filePath: kIsWeb ? null : file.path`, `bytes: kIsWeb ? file.bytes : null`, validates with `file.size`. |
| **C2 Education +10 inflation** | `PortfolioModel.profileCompletion({bool educationFilled = false})`; both owner screen and read-only view compute `educationFilled` from the real profile academic data. |
| **C3 / H2 Storage rules** | `storage.rules`: teacher/alumni read via `firestore.exists(...)` + `.data.role in ['teacher','alumni']` (no dead `request.auth.token.role` branch); write enforces `contentType.matches('application/pdf')` and `size < 5*1024*1024`. |
| **H1 Form re-seeding** | `edit_portfolio_screen.dart` `_isSeeded` guard in `didChangeDependencies`. |
| **H3 `optionalUrl` allowHttp bug** | `portfolio_validators.dart`: `lower.startsWith('https://') \|\| (allowHttp && lower.startsWith('http://'))`. |
| **M1 Skill editing** | `edit_portfolio_screen.dart` RawChip `onPressed` → `_editSkill` dialog with `initialSkill`; duplicate-name check excludes self. |
| **M3 `userRole()` exists guard** | `firestore.rules` helper wrapped in `exists(...)`. |
| **M5 Portfolio tile gating** | `profile_view.dart` "My Portfolio" only when `roleProvider.userRole == UserRole.student`. |
| **M6 Typed project/resume tiles** | `student_portfolio_screen.dart` `_buildProjectTile(ProjectModel project)`, `resume_upload_screen.dart` `_buildCurrentResume(ResumeMetadata resume)`. |
| **M9 Inverted date guard** | Read-only view + student preview `_periodLabel`/`_formatProjectDuration` guard `end.isBefore(start)`. ⚠️ *Not* applied in the two manager screens (see §3.5). |
| **M12 Teacher logout resets PortfolioProvider** | `teacher_dashboard_view.dart` `_resetProviders` includes `PortfolioProvider().reset()`. Also present in student + alumni dashboards. |
| **M13 Dynamic version label** | `profile_view.dart` `_AppVersionText` uses `package_info_plus`. |
| **L1/L4-preferences in isEmpty** | `PortfolioModel.isEmpty` includes `preferences.isEmpty`; `CareerPreferences.isEmpty` considers non-default remote/relocation. Tests in `portfolio_model_test.dart`. |
| **L7 Single busy flag** | `resume_upload_screen.dart` `isBusy = isSaving \|\| isUploading \|\| _isDeleting`. |
| **L2 Project tile durations/links** | `student_portfolio_screen.dart` renders duration, "Ongoing", GitHub/Demo chips. |

---

## 2. 🔴 Declared fixed in docs but NOT in the code

A developer reading `docs/v8_workspace_tracker.md` v8.4.5 and `docs/issues.md` will believe these are landed. **They are not.** This is a documentation-accuracy failure as much as a code failure.

### 2.1 H4 — Whole-map `savePortfolio` clobbering (STATUS: UNFIXED)
- **Docs claim**: "`portfolio_service.dart` — **H4 per-section diff saves (`previous` param)**"; "`portfolio_provider.dart` — **H4 passes `previous`**".
- **Actual code**: `PortfolioService.savePortfolio` still performs one `set({'portfolio': portfolio.toMap(), ...}, merge: true)` — a top-level whole-map replace. `PortfolioProvider.savePortfolio(PortfolioModel)` takes no `previous` parameter. The provider's `_portfolio` is the only state, so **any save overwrites every portfolio field with the client's in-memory copy**, clobbering device-B edits, future server-side updates (ATS score, parser) and admin changes.
- **Impact**: Real multi-device edit conflict; the `atsScore: null` forced into `ResumeMetadata` on every upload (`uploadResume`) will clobber any server-populated ATS score when combined with a later unrelated save.
- **Fix (still needed)**: per-section dotted paths (`portfolio.skills`, `portfolio.projects`, `portfolio.links`, `portfolio.preferences`, `portfolio.resume`) with merge, or document single-device assumption.

### 2.2 L4 — `initWithUser` different-UID guard (STATUS: UNFIXED)
- **Docs claim**: "`portfolio_provider.dart` — **L4 re-init on different uid**".
- **Actual code**:
  ```dart
  if (_isInitialized && _portfolio != null) { return; }
  ```
  No `_lastUid != userId` comparison. The `_lastUid` field is written but never read for the guard.
- **Impact**: Currently masked only because every logout path calls `reset()`. If any logout path is missed (a one-line regression), the previous user's portfolio — including their resume URL and contact links — renders for the next user. **This is a privacy boundary held up by discipline, not code.**
- **Fix (still needed)**: `if (_isInitialized && _portfolio != null && _lastUid == userId) return;`

### 2.3 L5 — `refresh()` can notify after reset/dispose (STATUS: UNFIXED)
- **Docs claim**: "`portfolio_provider.dart` — **L5 `_isDisposed` guard in `refresh`**".
- **Actual code**: `refresh()` has no `_isDisposed` check anywhere; the `finally` block calls `notifyListeners()` unconditionally. A pull-to-refresh racing logout calls `notifyListeners()` on a reset provider.
- **Impact**: `FlutterError` "A PortfolioProvider was used after being disposed" in debug; race-dependent crashes in release.
- **Fix (still needed)**: guard `finally { if (!_isDisposed) { _isLoading = false; notifyListeners(); } }`.

### 2.4 M8 — Dead code (STATUS: PARTIALLY applied)
- **Removed**: `duplicateSkill`, `isValidProject`, `maxResumeBytes` from `portfolio_validators.dart` (the file now contains only `required` + `optionalUrl`).
- **NOT removed (still present and unreachable)**:
  - `PortfolioService.updateResumeMetadata(...)` — never called.
  - `PortfolioService.deletePortfolio(...)` — never called.
  - `ResumeUploadResult.toMetadataMap()` and `ResumeUploadResult.version` — `StorageService.uploadResume` still returns `version: 1` and builds `toMetadataMap`; `PortfolioProvider.uploadResume` ignores both and recomputes version. The tracker claims the result was "slimmed".

### 2.5 M11 — Resume filename discarded (STATUS: UNCHANGED, acknowledged)
- `StorageService.uploadResume` always stores `fileName: resumeFileName` (`resume.pdf`); the picked `fileName` is only used for validation. The preview always shows "resume.pdf". Cosmetic, documented in the original issue.

---

## 3. 🆕 New bugs found in this audit (not in any prior doc)

### 3.1 CRITICAL — `chatDetailRoute` is referenced but never registered → crash on activity tap
- **File**: `lib/constants/routes.dart` defines `chatDetailRoute = '/chat-detail'`; `lib/views/dashboards/student_dashboard_view.dart` `_handleActivityTap` does `Navigator.pushNamed(context, chatDetailRoute, arguments: ...)` for `ActivityType.chatMessage`.
- **Problem**: `main.dart`'s named `routes:` map has **no `chatDetailRoute` entry**, and `onGenerateRoute` only handles `resumeReviewDetailRoute`, `chatRoute`, `completeMentorshipRoute`. Tapping a "new chat message" activity throws `onUnknownRoute` → **red error screen / app-kill in release**.
- **Fix**: either add `chatDetailRoute: (context) => const ChatView()`-style entry to `routes:` + argument handling in `onGenerateRoute` (mirroring `chatRoute`), or change `_handleActivityTap` to use `chatRoute`.

### 3.2 HIGH — Mentorship completion flow is unreachable (logic nesting bug)
- **File**: `lib/views/mentorship/mentorship_request_detail_view.dart`.
- The entire v7.3 completion block — "Mark as Completed" button (`if (request.isAccepted && !request.isCompleted)`) and the completed-info card (`if (request.isCompleted)`) — is **nested inside `if (request.status == MentorshipRequestStatus.pending) ... [ ... ]`**.
- For `accepted` or `completed` requests, `status == pending` is false, so **nothing in that block renders**. The "Mark as Completed" button can never appear, and the completion summary (rating, feedback, completed date) never displays. The `completeMentorshipRoute` is therefore only reachable if some other screen pushes it (none does).
- **Impact**: The v7.3 "mentorship journey finished" loop is dead UI; users can never rate/complete a mentorship from the detail view.
- **Fix**: Move the `if (request.isAccepted && !request.isCompleted)` and `if (request.isCompleted)` blocks **outside** the `status == pending` block.

### 3.3 CRITICAL — Firestore rules allow self-elevation of role → full data exposure
- **File**: `firestore.rules`.
- `match /users/{userId} { allow read, write: if isOwner(userId); ... }` — a user can write their **own document**, including the `role` field. There is no rule preventing a signed-in student from setting `role: 'teacher'` or `role: 'alumni'` on their own doc.
- **Consequence chain**:
  1. Student flips their own `role` to `teacher`.
  2. `isTeacher()` becomes true → they can now `read` **any user document** (`allow read: if isTeacher()`) — full PII (phone, email, academic, work history) of all students and alumni.
  3. `storage.rules` teacher branch also passes → they can download **any student's resume PDF**.
  4. They can also read all `collectionGroup('resumeReviews')` and `collectionGroup('applications')` (teacher read rules).
- **Fix**: restrict role writes server-side. Either (a) prohibit writing `role` from the client (rules deny if `'role' in request.resource.data.diff(resource.data).affectedKeys()`), with role changes only via Cloud Functions/admin, or (b) write role to a separate `users/{uid}/meta/role` subcollection with `write: if false` and query from there. At minimum: `allow create: if isOwner(userId) && request.resource.data.role == request.auth.token.role-or-missing` is insufficient — pair with an explicit `role` write-denial.
- This is the single most severe architectural/security finding in the assessment. The v8.4 portfolio + read-only views multiply the blast radius (any student now has read access to every student's portfolio, resume and PII).

### 3.4 MEDIUM — Missing composite index silently disables notification creation
- **File**: `functions/index.js` `maybeCreateNotification`:
  ```js
  .where("type", "==", type).where("createdAt", ">=", recentCutoff)
  ```
- **Firestore requirement**: composite index `notifications`: `type ASC, createdAt ASC` (range on last field ⇒ ASC).
- **`firestore.indexes.json`** contains only: `notes`, `recommendations`, `notifications (type ASC, createdAt DESC)`, `opportunities`, `mentorship_requests`. The direction mismatch (**DESC** for createdAt) means the query fails with "requires an index" → error is caught → **mentor-match, job-match, engagement-milestone and reminder notifications are silently never created**.
- **Fix**: add `{ "collectionGroup": "notifications", "fields": [{"fieldPath":"type","order":"ASCENDING"},{"fieldPath":"createdAt","order":"ASCENDING"}] }` to `firestore.indexes.json` and run `firebase deploy --only firestore:indexes`.

### 3.5 LOW — Inverted-date display guard missing in the two manager screens
- `projects_manager_screen.dart` `_formatDuration` and `experience_manager_screen.dart` `_formatDuration` have **no** `end.isBefore(start)` guard (the read-only view and student preview do — M9). Data seeded by older/legacy clients can render "Dec 2024 — Aug 2024" inside the managers.

### 3.6 LOW — Read-only view cannot distinguish "empty" from "error/permission-denied"
- `PortfolioService.getPortfolio` catches ALL errors and returns `PortfolioModel.empty()`. `ProfileService.getProfile` returns null on error. So in `PortfolioReadOnlyView`, a failed/denied read renders the empty-portfolio message ("This student has not added portfolio details yet.") with a working "View Resume" button that will 403. The `_error` state is effectively unreachable except for the null-argument case. Misleading for teachers/alumni on real permission failures or network issues.

### 3.7 LOW — `StudentPortfolioScreen` still uses `dynamic profile` in two methods
- `_buildCompletionHeader(dynamic profile, ...)` and `_buildEducationSection(dynamic profile, ...)` — M6 applied to project/resume tiles but not these. No runtime risk today (accesses are guarded), but defeats static analysis.

### 3.8 LOW — `PortfolioProvider.uploadResume`/`deleteResume` set `_lastUid` but never check `_isDisposed`
- Logout during an in-flight upload/delete → `notifyListeners()` on a reset provider. Same class of bug as unfixed L5.

### 3.9 INFO — Version mismatch
- `pubspec.yaml` says `version: 5.1.2+3`. The M13 dynamic label will now display "v5.1.2" everywhere, while docs/UI copy describes v8.4. Users/support will see a stale, credibly-wrong version. Consider bumping `pubspec.yaml` to `8.4.0+84` or similar to match the product version.

### 3.10 INFO — `firebase.json` storage rules registered but Storage not provisioned
- `firebase.json` has `"storage": { "rules": "storage.rules" }`, but the previous deployment note stands: `firebase deploy --only storage` is blocked until Firebase Storage is enabled in the console. Until then, storage rules are **not enforced anywhere** — the client-side validation in `StorageService` is the only guard, and there is no storage at all, so uploads will fail with a storage-bucket-not-found error rather than a rules denial.

---

## 4. Routing Audit

| Route | Status |
|-------|--------|
| `studentPortfolioRoute`, `editPortfolioRoute`, `projectsManagerRoute`, `certificationsManagerRoute`, `experienceManagerRoute`, `achievementsManagerRoute`, `resumeUploadRoute`, `portfolioReadOnlyRoute` | ✅ All 8 registered in `main.dart` `routes:`. |
| `portfolioReadOnlyRoute` argument handling | ✅ Raw String uid read via `ModalRoute.of(context)` post-frame. Both entry points (teacher eye icon `student_analytics_view.dart`; alumni `mentorship_request_detail_view.dart`) pass a raw String. |
| `chatRoute`, `resumeReviewDetailRoute`, `completeMentorshipRoute` | ✅ Handled in `onGenerateRoute` with argument validation + safe fallback. |
| **`chatDetailRoute`** | 🔴 **Defined in constants, referenced in `student_dashboard_view.dart`, NOT registered anywhere.** See §3.1. |
| `chatDetailRoute` fallback | ❌ None — `onGenerateRoute` returns null, named-route lookup fails → crash. |

---

## 5. Firestore Rules Audit (incl. role-based problems)

| Rule block | Verdict |
|-----------|---------|
| `users/{userId}` owner read/write | 🔴 **Self-role-elevation vulnerability** (§3.3). Also: the owner-write rule allows a student to mutate `profileCompleted`, `department`, `graduationYear` etc. arbitrarily (design choice, but feeds analytics). |
| Teacher read (`isTeacher`) | ⚠️ Correct intent; dangerously coupled to the self-writable `role` field. |
| Alumni read of student docs (v8.4) | ⚠️ **M2 privacy trade-off retained** (whole-doc read — phone/email/PII). Documented decision, but with §3.3 any student can also become "alumni" and read every student's whole doc. **M2 becomes critical once self-elevation is realized.** |
| `notifications/{id}` `allow create: if isAuthenticated()` | ⚠️ Any authenticated user can create a notification doc under ANY user (`userId` from path is not checked against the caller!). Path is `users/{userId}/notifications/...` but the rule `allow create: if isAuthenticated()` ignores `userId`. A student can spam arbitrary notifications to themselves or others. Pre-existing (v7.3) but worth fixing: `allow create: if isOwner(userId)`. |
| `resumeReviews`, `engagement_summary` teacher reads | ✅ Correct via collectionGroup + per-doc rules. |
| `applications` collectionGroup teacher read | ✅. |
| Storage `resumes/{uid}/{fileName}` | ✅ Owner write (PDF + 5 MB); owner/teacher/alumni read with `exists()` guard. Blast radius expands only via the role-escalation hole. |

---

## 6. Indexes Audit

`firestore.indexes.json` has 5 indexes. **Missing**:

| Collection | Required composite | Query needing it | Impact if missing |
|-----------|-------------------|-----------------|-------------------|
| `notifications` | `type ASC, createdAt ASC` | `maybeCreateNotification` (Cloud Function) | 🔴 All deduped notifications silently dropped |
| `mentorship_requests` | `status ASC, createdAt ASC` | present ✅ | — |
| `opportunities` | `isActive ASC, applicationDeadline ASC` | present ✅ | — |
| `notifications` (existing) | `type ASC, createdAt DESC` | UI provider queries (reverse chronology) | ✅ correct for UI; **does NOT satisfy the function's range query** |

Note: `TeacherAnalyticsService` uses `count()` on `users where role == 'student'` (single-field, auto-indexed) and manually falls back to `get()` — the fallback comments about "missing composite index" are not accurate for single-field equality, but the defensive code is harmless.

---

## 7. Cloud Functions Audit

| Function | Verdict |
|----------|---------|
| `askAI` | ✅ Rate-limit, spam, usage, trial all transactional and fail-open. No auth check on HTTP body (by design — `userId` from body); acceptable for v4 but flag: anyone can spend your AI quota with a forged `userId`. |
| `reviewResume` / `generateResumeAnalysis` | ✅ Monthly limits, length caps, sanitized input; callable uses real auth `uid`. |
| `onProfileUpdatedRefreshAI` | ⚠️ Fires on **every** user-doc write (including portfolio saves from v8.4). The `changed` diff excludes portfolio fields so v8.4 writes early-return — correct today, but fragile: future portfolio-influencing fields added to the diff will silently re-trigger a full recommendation recompute per save. |
| `onOpportunityPostedNotifyStudents` | ⚠️ Writes notifications directly (no dedup) — OK; but notification reads by students rely on the notifications index only for UI queries (are OK). |
| `maybeCreateNotification` | 🔴 **Requires the missing composite index** (§3.4). |
| `sendInactivityReminders` / `recomputeEngagementScores` | ⚠️ Sequential per-user iteration inside scheduled functions; fine at demo scale, will hit invocation timeouts at 500+ users. |

---

## 8. Architecture Stability Assessment

### Strengths
- Provider lifecycle mirrors `ProfileProvider` (`initWithUser`/`reset`/`_isDisposed`); all three dashboards + AuthGuard reset `PortfolioProvider` on logout.
- Portfolio stored as a nested map under `users/{uid}/portfolio` with merge-set — backward compatible with the existing user-document schema, no migration needed.
- 16 unit/widget tests added (portfolio model/validators/read-only-view regression + auth navigation).
- Clean separation: models / service / provider / validators / screens / shared widgets.

### Fragilities (the "will bite later" list)
1. **Security model relies on the role field being trustworthy — it is not** (§3.3). This is the #1 architectural stability risk. Until role writes are server-controlled, "owner-only portfolio editing", "teacher read-only analytics" and "alumni read-only portfolios" are all bypassable by any user.
2. **Whole-map portfolio saves** (§2.1) make the portfolio single-device-only in practice and will clobber future server-written fields (ATS score, parserVersion).
3. **Provider state boundaries are upheld by convention, not code** (§2.2) — one missed `reset()` away from a cross-user data leak.
4. **Notification pipeline is silently broken** (§3.4) — the engagement/gamification loop (badges, streaks, mentor/job matches) visually degrades without any error surface.
5. **The mentorship completion loop is dead code** (§3.2) — v7.3 feature regression hidden behind a logic-nesting bug.
6. **Per-student analytics is N+1**: `getStudentResumeData` / `getDepartmentAnalytics` / `getEngagementAggregates` issue 1–3 sequential Firestore reads per student (30 students ⇒ 30–90 reads). Fine for a demo; will exceed the free tier and feels slow at an institution scale. A materialized aggregate collection or collectionGroup + `where` is the right fix.

---

## 9. Prioritized Fix List

| # | Sev | Area | Fix |
|---|-----|------|-----|
| 1 | 🔴 | Security | Deny client writes to `role` (and `profileCompleted`) in `firestore.rules`; route role changes through a Cloud Function/admin. Deploy immediately. |
| 2 | 🔴 | Routing | Register `chatDetailRoute` or route activity taps to `chatRoute`. |
| 3 | 🔴 | Indexes | Add `notifications` `type ASC, createdAt ASC` index; `firebase deploy --only firestore:indexes`. |
| 4 | 🟠 | Logic | Move "Mark as Completed" + completion-info out of the `status == pending` block in `mentorship_request_detail_view.dart`. |
| 5 | 🟠 | Portfolio | Implement H4 per-section saves (`portfolio.skills`, `portfolio.projects`, `portfolio.links`, `portfolio.preferences`, `portfolio.resume` dotted paths). |
| 6 | 🟠 | Provider | Add `_lastUid` guard to `initWithUser` (L4) and `_isDisposed` guards to `refresh`/`uploadResume`/`deleteResume` (L5). |
| 7 | 🟡 | Rules | Tighten `users/{userId}/notifications` create rule to `isOwner(userId)`. |
| 8 | 🟡 | Privacy | Decide M2: either migrate portfolio to `users/{uid}/portfolio` subcollection (architectural change) or accept + document the whole-doc exposure (already commented). With fix #1 in place this is no longer exploitable by self-elevation. |
| 9 | 🟡 | Code quality | Remove dead `updateResumeMetadata`/`deletePortfolio`/`toMetadataMap`/`version` (finish M8). |
| 10 | 🟡 | UX | Make read-only view distinguish error/permission-denied from empty portfolio (`getPortfolio` should rethrow or return a result object). |
| 11 | 🔵 | Display | Add inverted-date guard to `projects_manager_screen.dart` / `experience_manager_screen.dart` `_formatDuration`. |
| 12 | 🔵 | Hygiene | Type `StudentPortfolioScreen` `dynamic profile` params; bump `pubspec.yaml` version to match v8.4; update `docs/issues.md`/tracker to reflect the actual H4/L4/L5/M8 state (or land those fixes). |
| 13 | 🔵 | Release | Enable Firebase Storage in the console and run `firebase deploy --only storage` so `storage.rules` (PDF/5 MB/role reads) actually take effect. Until then, note that Android/iOS uploads will fail with a bucket-not-found error. |

---

## 10. Improvements for Future Versions

1. **Server-side role enforcement** (non-negotiable before any production rollout) — cover §3.3.
2. **Portfolio as a subcollection** (`users/{uid}/portfolio`) instead of a nested map — eliminates whole-doc alumni reads (M2), enables per-field rules, and naturally supports resume history/versioning (a declared future version).
3. **Materialized analytics**: keep a `teacher_analytics/summary` doc updated by a Cloud Function (onDocumentWritten on resumeReviews/engagement_summary) to replace the N+1 reads.
4. **Offline-first**: `PortfolioService` currently does one-shot `get()`; switching to `snapshots()` (the `portfolioStream` already exists) would make portfolio edits instant and conflict-safe once H4 lands.
5. **App Check** — the logs show `No AppCheckProvider installed` on every request. Enabling App Check closes the forged-`userId` AI-spend hole and raises the bar on rule bypasses.
6. **Stale-code cleanup**: the legacy `notesRoute` → `StudentDashboardView` aliasing, the dead `pipelineTotalPlacements` getter, and the `dynamic`-profile methods are maintenance debt worth a cleanup pass.
7. **Unify versioning**: single source of truth for the app version (pubspec) and make docs stop claiming fixes that aren't in source — the current tracker/`issues.md`/code mismatch is a real hazard for the next engineer.

---

## 11. Suggested Reading Order

1. `lib/main.dart` — provider registration, AuthGuard lifecycle, route wiring; explains C4 and the chatRoute gap.
2. `lib/services/firestore/portfolio_service.dart` + `lib/providers/portfolio_provider.dart` — the H4/L4/L5 gaps live here.
3. `lib/views/portfolio/portfolio_read_only_view.dart` — the (fixed) crash site + how read-only views load data.
4. `firestore.rules` + `storage.rules` — the role-elevation hole and the v8.4 read-only permission model.
5. `functions/index.js` (`maybeCreateNotification`, `refreshRecommendationsForStudent`) — the notification index break and the user-doc write-trigger coupling.
6. `lib/views/mentorship/mentorship_request_detail_view.dart` — the unreachable completion block.
7. `lib/views/dashboards/student_dashboard_view.dart` (`_handleActivityTap`) — unregistered `chatDetailRoute` crash.
