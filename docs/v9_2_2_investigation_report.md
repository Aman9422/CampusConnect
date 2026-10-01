# CampusConnect — v9.2.2 Investigation Report

**Version under investigation:** `9.1.2+99` (`pubspec.yaml`)
**Source of evidence:** `docs/logs.md` — one full runtime session on the **Google Pixel 9, Android 16.0 (API 36) emulator**, `sdk gphone16k x86 64`, Flutter **debug** build (pid 32037), spanning cold launch → login → logout → re-login across three accounts.
**Scope of this report:** the *investigation only* — what the log proves, what the source code proves, and the root cause of each reported symptom. The fixes are tracked separately in `docs/v9_2_2_optimization_report.md`.
**Method:** full read of every source file cited, cross-referenced against the exact log lines that triggered the section. Where a claim depends on the deployed Firebase project or the emulator rather than on source, it is marked as such instead of asserted.

---

## 0. Log digest — what the session actually contains

| Log evidence | Count in session | Affected account(s) | Section |
|---|---|---|---|
| `Skipped 77 frames` / `Skipped 30 frames` / `Skipped 32 frames` | 1 / 1 / 1 (all in the first ~2 s of cold start) | n/a | §1 |
| `RecommendationService: server regenerated recommendations for <uid>` | **2** for `ynleASY3m0dJ0dVkQ6D9K1xMVKv2`, **1** each for the other two | all three | §2 |
| `ResumeReviewProvider: Loaded 0 history items` → `Refreshed 0 history items` | once, back-to-back | `hcx8p4flzNc9YsRyipqG5mLg5hC3` (teacher) | §3 |
| `PortfolioProvider: detected flattened portfolio shape … next save will use full (non-diff) write` | **2** (once per login of the same account) | `ynleASY3m0dJ0dVkQ6D9K1xMVKv2` | §4 |
| `403 App attestation failed` / `Too many attempts` / `using placeholder token` | 15+ | all three | §5 |
| `DeadObjectException` / `Phenotype.API is not available` / `Unknown calling package name 'com.google.android.gms'` / `DEVELOPER_ERROR` | 20+ | n/a (GMS) | §6 |
| `TeacherAnalyticsProvider: Loaded 3 reviews, 1 students, 1 depts, 1 pipeline eligible, 1 engagement summaries` | **1** | teacher | §7 |
| `WatchStream … NOT_FOUND Target id not found` | **0** | — | §8 |

### Accounts exercised (from `FirebaseAuth` log lines)

| Login order | Email | uid | Role inferred from log |
|---|---|---|---|
| 1 | `ajayak@jdcoem.ac.in` | `ynleASY3m0dJ0dVkQ6D9K1xMVKv2` | Student (portfolio + 2 resume reviews) |
| 2 | `blitz14e@gmail.com` | `hcx8p4flzNc9YsRyipqG5mLg5hC3` | Teacher (analytics load fired) |
| 3 | `aman9422a@gmail.com` | `pUUuRiE17FVzUePhSIngBC54Y963` | Student (1 resume review) |
| 4 (re-login) | `ajayak@jdcoem.ac.in` | `ynleASY3m0dJ0dVkQ6D9K1xMVKv2` | Student (repeat) |

---

## 1. Startup performance — root cause of `Skipped 77/30/32 frames`

### What the log shows

```
D/FlutterJNI: Beginning load of flutter...
D/FlutterJNI: flutter (null) was loaded normally!
I/flutter: Using the Impeller rendering backend (OpenGLES).
... hiddenapi / WindowExtensionsImpl / Compiler allocated 5057KB ...
Connecting to VM Service ...
W/GmsClient: IGmsServiceBroker.getService failed  (DeadObjectException)
I/Choreographer: Skipped 77 frames!
D/WindowLayoutComponentImpl: Register WindowLayoutInfoListener ...
D/ProfileInstaller: Installing profile for io.campusconnect.campusconnect
D/…DebugAppCheckProvider: Enter this debug secret into the allow list … 2d0591e7-52f3-466f-a31a-8be966ccbf69
I/Choreographer: Skipped 30 frames!
I/Choreographer: Skipped 32 frames!
```

### What this proves

* **No Dart `debugPrint` appears before the first `Skipped 77 frames`.** The application's own first observable act is the App Check debug-secret print, which happens *after* the 77-frame skip. Whatever consumed those 77 frames ran **before any of our Dart code logged anything** — i.e. in the Engine bring-up / plugin registration / embedding phase, and in the Android `ViewRootImpl.performTraversals()` compilation the log explicitly reports (`Compiler allocated 5057KB to compile void android.view.ViewRootImpl.performTraversals()`).
* The `Skipped 30/32 frames` pair brackets **`ProfileInstaller: Installing profile`** and the **App Check debug provider** activation — again native work, not Dart work.
* `main()` in `lib/main.dart` does exactly three things before `runApp`: `WidgetsFlutterBinding.ensureInitialized()`, `await Firebase.initializeApp(...)`, `await _activateAppCheck()`. All three are **required for correctness** (Auth depends on Firebase; every backend call depends on App Check being configured) and all three are **native** calls whose cost is not reducible from Dart.

### Root cause

The remaining startup jank is **not caused by Dart-side application work**. It is dominated by:

1. **Flutter Engine / Impeller GL context bring-up** on an emulator using software or emulated GPU — the single largest contributor to the 77-frame skip.
2. **Android `performTraversals()` JIT compilation** on first layout (explicitly logged).
3. **Firebase Core + Firebase Auth + Firebase App Check native initialisation**, including the GMS service-broker round-trips that fail with `DeadObjectException` (§6) and the debug App Check handshake.

### What the Dart side can and cannot influence

| Dart-side candidate | Verdict |
|---|---|
| `await Firebase.initializeApp()` before `runApp` | **Required.** Cannot be deferred — `AuthGuard` reads `FirebaseAuth.instance` on first build. |
| `await _activateAppCheck()` before `runApp` | **Required** to configure providers; it is a cheap configuration call (the token fetch is lazy). Not a frame-budget consumer. |
| `MultiProvider` (21 providers declared) | **Not a startup cost.** `provider` creates `ChangeNotifierProvider`s lazily; the two that *are* created on the first frame (`ThemeProvider`, `LayoutProvider`, watched by the `Consumer<ThemeProvider>` around `MaterialApp`) only kick off a fire-and-forget `..init()` whose `SharedPreferences.getInstance()` is async and never awaited inside `build`. |
| Dashboard tab construction | **Already fixed in v9.2** — `MainNavigationView` builds tabs lazily (`IndexedStack` no longer eagerly builds all five heavy tabs). |
| Provider initialisation (`initWithUser` …) | **Already deferred in v9.2** to `addPostFrameCallback`s guarded by `_providerInitScheduled` / `_ecosystemInitScheduled`, and runs only *after* the user is authenticated — it never touches the cold-start frame budget. |
| SharedPreferences / local storage | Async, not awaited in build. Not a first-frame cost. |
| Image / font loading | No custom fonts declared in `pubspec.yaml`; no startup image assets. Not a factor. |

### Conclusion for §1

**The `Skipped 77/30/32 frames` are attributable to engine + Android + Firebase/GMS native initialisation on the emulator, not to application Dart code.** The only defensible Dart-side action is *measurement*: v9.2.2 adds lightweight phase/frame instrumentation so the profile-mode DevTools capture can attribute the seconds precisely, and documents the native baseline. No speculative Dart "optimisation" is applied, because there is no Dart-side evidence to justify one.

---
## 2. Recommendation refresh — root cause of the duplicate `server regenerated recommendations`

### What the log shows

For `ynleASY3m0dJ0dVkQ6D9K1xMVKv2`, two identical client lines, seconds apart:

```
I/flutter: ResumeReviewProvider: Loaded 2 history items
I/flutter: RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
... GoogleApiManager / FirebaseContextProvider errors ...
I/flutter: RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
... FirebaseAuth: sign-out ...
```

The other two accounts each show exactly one such line per login.

### Every caller of recommendation regeneration (traced through the source)

The printed line is emitted **only** by `RecommendationService.refreshRecommendations`
(`lib/services/firestore/recommendation_service.dart`, line 127-129) after a **successful**
`httpsCallable('refreshRecommendations')`. An exhaustive text search over `lib/` for
`refreshRecommendations` / `recommendationProvider.refresh` / `RecommendationProvider`
returns exactly **two** client call sites:

| # | Call site | File / line | Trigger |
|---|---|---|---|
| C1 | `RecommendationProvider.initWithUser` → `_service.refreshRecommendations(...)` | `lib/providers/recommendation_provider.dart:65` | `AuthGuard` ecosystem bootstrap (post-frame, once per session) |
| C2 | `RecommendationProvider.refresh` → `_service.refreshRecommendations(...)` | `lib/providers/recommendation_provider.dart:83` | Student dashboard **manual** refresh button (`student_dashboard_view.dart:754`) |

And exactly **two** server-side callers of the engine orchestrator
`refreshRecommendationsForStudent`:

| # | Call site | File | Trigger |
|---|---|---|---|
| S1 | `onProfileUpdatedRefreshAI` | `functions/triggers/index.js` | any `users/{uid}` write that changes skills / careerInterest / department / graduationYear / `career` / `updatedAt` / portfolio content |
| S2 | `onResumeReviewCreatedRefreshMatches` | `functions/triggers/index.js` | a new `users/{uid}/resumeReviews/{reviewId}` |

### Root cause

Two independent defects compound:

**Defect A — the client has no in-flight or fingerprint de-duplication.**
`RecommendationService.refreshRecommendations` unconditionally invokes the callable every time it is
called. `RecommendationProvider.initWithUser` guards re-entry with `if (_isInitialized && _userId == userId) return;`
— but `_isInitialized` is set to `true` **only inside the stream listener callback**
(`recommendations_provider.dart:52-63`), i.e. asynchronously, after the first Firestore snapshot
arrives. On a cold start that snapshot arrives *after* the `await`ed callable has already been
dispatched, so any caller that reaches `initWithUser` again inside that window starts a **second**
`refreshRecommendations` call (and a second label-printing pass). There is no shared in-flight future
and no record of "this exact profile already triggered a refresh this session". The v9.2 `LoadDedupe`
gate was applied to `TeacherAnalyticsProvider` but **not** to recommendations.

**Defect B — the server always regenerates, even for identical inputs.**
`refreshRecommendationsForStudent` (`functions/recommendations/refresh.js`) has no notion of
"already materialised for this state". It loads candidates, runs the deterministic engine, calls the AI
enrichment (`enrichRecommendationExplanations` — the expensive Groq→HF path), deletes stale docs and
rewrites every recommendation document, on every invocation. Because the profile-update trigger (S1)
and the client bootstrap (C1) fire in the same login window, one login can produce **two full
server-side regenerations** for the same unchanged profile — exactly what the log shows for
`ynle…`.

The two defects are independent: fixing only the client leaves the trigger + callable double
regeneration; fixing only the server leaves the client issuing a redundant network round-trip (which
would then be correctly skipped by the server, but would still burn a callable invocation).

### Aggravating factor (not the cause)

`RepositoryConventions` aside, note that `RecommendationProvider.initWithUser` also *subscribes* the
`recommendationsStream` **before** calling `refreshRecommendations`, so the first stream snapshot it
receives is the **pre-refresh** document set. When the callable then rewrites the documents the stream
emits again. This is correct behaviour, but it means a duplicate refresh produces two extra stream
emissions and two dashboard rebuilds — amplifying the visible cost.

### Conclusion for §2

The duplicate is **not** caused by `AuthGuard` alone, by `Career Coach`, or by the recommendation
freshness checks. It is caused by (a) the client lacking any refresh de-duplication for a
profile/provider state it has already refreshed, and (b) the server regenerating unconditionally.
The fix must therefore be **end-to-end**: a client-side in-flight + fingerprint gate *and* a
server-side fingerprint gate, with regeneration still guaranteed whenever the intelligence inputs
actually change.

---
## 3. Resume Review provider — root cause of `Loaded 0 history items` → `Refreshed 0 history items`

### What the log shows

```
I/flutter: ResumeReviewProvider: Loaded 0 history items
I/flutter: TeacherAnalyticsProvider: Loaded 3 reviews, 1 students, 1 depts, ...
I/flutter: ResumeReviewProvider: Refreshed 0 history items
```

Both lines come from `lib/providers/resume_review_provider.dart`:

* `Loaded N history items` — `_loadHistory()` (line 481-499), called from `initWithUser` (line 209).
* `Refreshed N history items` — `refreshHistory()` (line 504-523).

### Root cause

`AuthGuard` calls `ResumeReviewProvider.initWithUser` during its post-frame provider bootstrap,
which runs `_loadHistory()` → **read #1** (`users/{uid}/resumeReviews`).

`_TeacherDashboardTab._loadAll` (`lib/views/dashboards/teacher_dashboard_view.dart`) then did:

```dart
if (firstLoad || !_historyRefreshed) {
  _historyRefreshed = true;
  await resumeReviewProvider.refreshHistory();   // ← identical read again
}
```

On the first load `_historyRefreshed` is `false`, so `refreshHistory()` runs unconditionally —
**read #2**, identical, against the same collection for the same user, milliseconds after the first.
The `_historyRefreshed` flag only prevented *retries* from refreshing; it never prevented the first
redundant refresh. This is the exact pair the log shows.

Note the consumer: `ResumeReviewAnalytics` in `teacher_dashboard_sections.dart:873` watches
`ResumeReviewProvider` for its "Latest Reviews" list. That is the only teacher-dashboard consumer, and
it needs the history *once* — not twice.

### Conclusion for §3

`_loadHistory()` and `refreshHistory()` are redundantly executed on every teacher-dashboard open.
The provider itself is correct: `initWithUser` loads history in the background, `refreshHistory()`
is the explicit user/pull-to-refresh path, and `submitReview()` calls `refreshHistory()` after a new
review so the new item appears. The defect is purely in the **caller**, which must not force a second
read when the provider already holds current data.

---

## 4. Portfolio compatibility — root cause of the repeated `detected flattened portfolio shape`

### What the log shows

Twice, once per login of `ynleASY3m0dJ0dVkQ6D9K1xMVKv2`:

```
I/flutter: PortfolioProvider: detected flattened portfolio shape for ynleASY3m0dJ0dVkQ6D9K1xMVKv2 —
           next save will use full (non-diff) write to reconstitute nested map.
```

### Why the shape exists (established v8.4.9, unchanged)

The canonical portfolio is the nested map `users/{uid}.portfolio.{skills,projects,resume,…}`.
Some legacy/console-edited documents instead store the portfolio as **root-level keys whose names
contain dots** — `portfolio.resume`, `portfolio.projects`, `portfolio.resume.downloadUrl`, … .
`PortfolioService._extractPortfolioMap` (v8.4.9 MB17) tolerates both shapes for **reads**, and
`extractPortfolio` in `functions/recommendations/engine.js` mirrors that tolerance for the
recommendation engine.

### Root cause

The v9.0 "BUG-3" fix only **flagged** the flattened shape:

```dart
// lib/providers/portfolio_provider.dart — initWithUser
_forceFullSave = await _portfolioService.hasFlattenedPortfolioShape(userId);
if (_forceFullSave) { debugPrint('…detected flattened portfolio shape…'); }
```

`_forceFullSave` then made the **next user-initiated save** write every section with
`previous: null`, which re-nests the data — but it **never deleted the legacy root-level
`portfolio.*` keys** and, critically, it required the user to actually open the portfolio and save.
Until that happened:

1. Every login re-ran `hasFlattenedPortfolioShape()` and re-printed the warning — the repeated log
   line.
2. The flattened keys stayed in the document indefinitely, so the "compatibility path" was
   permanently active rather than a one-time transition.
3. Even after a forced full save, the document ended up carrying **both** the new nested `portfolio`
   map *and* the old `portfolio.*` flat keys (orphaned duplicates), because a merge-write of
   `portfolio.<section>` paths never removes the differently-named flat keys.

This is a **migration that was designed but never performed**: it was left as a manual, user-triggered,
non-cleaning step.

### Safety analysis of migrating

* The flattened values are re-nested **verbatim** by the existing `_unflattenPaths` logic — no
  portfolio field is invented, dropped or transformed.
* The proposal is a single atomic merge-write: set `portfolio` to the reconstructed nested map and
  `FieldValue.delete()` every flat key.
* Because the write is keyed on the **absence of the nested map**, it is naturally idempotent — the
  second run sees `data['portfolio'] is Map` and does nothing.
* Firestore security rules must permit the write. `firestore.rules` grants the owner write on the
  `users/{uid}` document subject to `canWriteRole` (which only freezes `role`), and the field paths
  written here (`portfolio`, `portfolio.*`, `metadata.portfolioMigratedAt`) are all owner-writable
  under the v9.2 rule set. **No rule change is required.**

### Conclusion for §4

The repeated warning is the symptom of an **incomplete migration**: detection without remediation.
The fix is a safe, controlled, idempotent migration executed automatically at init when the flattened
shape is present, which writes the canonical nested map and deletes the legacy keys. After it runs
once, no account needs the compatibility path again, and no orphaned flat keys remain.

---
## 5. App Check debug configuration — root cause of `403 App attestation failed` / `Too many attempts`

### What the log shows

```
D/…DebugAppCheckProvider: Enter this debug secret into the allow list in the Firebase Console for your project: 2d0591e7-52f3-466f-a31a-8be966ccbf69
W/LocalRequestInterceptor: Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: Error returned from API. code: 403 body: App attestation failed.
W/FirebaseContextProvider: Error getting App Check token. Error: com.google.firebase.FirebaseException: Too many attempts.
```

…repeated for every backend request of every account (Auth sign-in, Firestore reads, callables).

### What the code does (verified correct)

`lib/main.dart → _activateAppCheck()`:

| Build | Provider selected | Verdict |
|---|---|---|
| Debug / Profile | `AndroidDebugProvider()` (+ `AppleDebugProvider()` on iOS) | Correct — release attestation is unavailable in a non-release build. |
| Release (Android) | `const AndroidPlayIntegrityProvider()` | Correct — production attestation preserved. |
| Release (iOS/macOS) | `const AppleDeviceCheckProvider()` | Correct. |
| Web | `ReCaptchaV3Provider(webSiteKey)` from `--dart-define` | Correct; skipped when the Site Key is absent. |
| Unsupported desktops (Windows/Linux) | skipped | Correct for the supported-platform list. |

No token is hard-coded anywhere in the repository; the debug token in the log is printed by the
**Firebase SDK**, not by application code (verified by search — there is no app-side print of a debug
token).

### Root cause

`403 body: App attestation failed` means the token the client presented was **not accepted by the
backend for the project it is talking to**. The two possible causes:

1. **The debug token is not allow-listed (most likely).** The app Check debug secret
   `2d0591e7-52f3-466f-a31a-8be966ccbf69` must be registered in **Firebase Console → App Check → Apps
   → the Android app → Manage debug tokens** *for this exact project*. When it is missing, every token
   request is rejected with 403 and the SDK escalates to `Too many attempts`. The debug token is
   **per debug keystore** — rebuilding, reinstalling on a different machine, or a different
   `android/app/debug.keystore` produces a *different* secret, and the previous allow-list entry no
   longer applies.
2. **Project mismatch.** The debug token is allow-listed on a *different* Firebase project than the
   one the emulator build talks to. Both the app config and the CLI default are verified here and
   **agree**: `lib/firebase_options.dart` → `projectId: 'campusconnect-firebase-project'` (all
   platforms), and `.firebaserc` → `"default": "campusconnect-firebase-project"`. So the project is
   **not** mismatched — the token is simply not registered.

### What this does **not** block (verified in the log)

Firebase Authentication and Firestore operations continue on the placeholder token path, because
Firestore/Storage rules authenticate via `request.auth` (Firebase Auth), **not** `app.check()`.
The log confirms successful logins (`Notifying auth state listeners about user (…)` after each
`Logging in as …`) and successful `resumeReviews` reads. So the failures are **noise + wasted retries**,
not a functional outage — but they are a **P0 validation item** because App Check enforcement is
intended to be switched on, and at that point the missing allow-list entry would become fatal.

### Conclusion for §5

**Configuration issue, not an application-code issue.** The client provider selection is correct for
debug and release. The action is to register the emulator's current debug token in the Firebase
Console for `campusconnect-firebase-project` (or, better, to keep a stable token via
`adb shell setprop debug.firebase.appcheck.debug.token <TOKEN>` / a documented debug token). No code
change is required, and none should be made that could weaken production enforcement.

---

## 6. Google Play Services / emulator diagnostics

### The messages

```
W/GmsClient: IGmsServiceBroker.getService failed / android.os.DeadObjectException
E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR, …}
W/FlagRegistrar: API: Phenotype.API is not available on this device. Connection failed with: … DEVELOPER_ERROR
W/FlagStore: Unable to update local snapshot for com.google.android.gms.providerinstaller#io.campusconnect.campusconnect
W/DynamiteModule: Local module descriptor class for com.google.android.gms.providerinstaller.dynamite not found.
W/ProviderInstaller: Failed to load providerinstaller module: No acceptable module … found.
```

### Classification

Every one of these originates from the **`com.google.android.gms` (Google Play Services) process
inside the emulator**, identifiable by the stack frames — they are all in `com.google.android.gms@…`
Dynamite modules (`blbr`, `bkfr`, `bkfp`, `griu`, `hsbd`, `fwqn`, …) and in the
`dynamite_measurementdynamite` split. None originates in `io.campusconnect.campusconnect`.

| Message | Classification | Reasoning |
|---|---|---|
| `DeadObjectException` in `GmsClient` | **Emulator / Google Play Services** | The GMS binder service died mid-call (common right after emulator boot / cold-start resource pressure). |
| `Unknown calling package name 'com.google.android.gms'` | **Emulator / Google Play Services** | The emulator image's package-manager visibility rules reject the GMS self-identification — an image/Play-Services-version artifact, not an app permission. |
| `Phenotype.API is not available on this device` | **Emulator / Google Play Services** | Phenotype is GMS's server-config/flag API; the emulator image does not expose it. |
| `DEVELOPER_ERROR` | **Emulator / Google Play Services** | The GMS connection result for the unavailable Phenotype API. |
| `providerinstaller … module not found` | **Emulator / Google Play Services** | The emulator has no `com.google.android.gms.providerinstaller` Dynamite module. |

### Does the app need to change?

**No.** Per the task's own constraint (§13: "Do not modify application logic merely to suppress
external emulator noise") and the acceptance in §6 of the brief ("No unnecessary application-code
changes should be made for emulator-only noise"), these are correctly classified as
**environment-specific**. The app's own Firebase operations are unaffected — verified by the successful
auth + reads in the same log.

Note the interaction with §5: the GMS `DeadObjectException`/`DEVELOPER_ERROR` occurs exactly in the
window where App Check's debug provider and Firebase Core initialise, which is one of the reasons the
30/32-frame skip lands there (§1). The GMS noise is therefore best understood as a *contributor to the
startup window*, not as an application defect.

---

## 7. Teacher Analytics — regression status

### What the log shows

Exactly **one** load for the teacher account:

```
I/flutter: TeacherAnalyticsProvider: Loaded 3 reviews, 1 students, 1 depts, 1 pipeline eligible, 1 engagement summaries
```

(For comparison, the pre-v9.2 symptom was the same line printed ~3× per navigation.)

### Verdict

**Regression-free.** The v9.2 `LoadDedupe` gate in `lib/utilities/load_dedupe.dart`, wired into
`TeacherAnalyticsProvider.loadAnalytics` (`lib/providers/teacher_analytics_provider.dart:106+`), is
active and functioning: concurrent callers share the in-flight future, a non-forced call with data
already present is a no-op, and `reset()` invalidates the epoch so a stale load cannot commit after a
logout. The single log line is the expected output of one load cycle.

The v9.2.2 change in §3 does **not** touch this path — it only removes a redundant
`ResumeReviewProvider` read (`ResumeReviewAnalytics` still renders from the same provider).

---

## 8. Listener lifecycle — regression status

### What the log shows

The session contains **four** full logout/login transitions (three logins + one re-login) and
**zero** occurrences of:

```
WatchStream … NOT_FOUND Target id not found
```

which was the pre-v9.2 symptom of a Firestore listener surviving a logout.

### Verdict

**Regression-free.** The v9.2 listener-lifecycle fixes are active and evidenced:

* `OpportunityProvider` — subscriptions retained (`_activeOpportunitiesSubscription`,
  `_alumniOpportunitiesSubscription`) and cancelled in `reset()` + `dispose()`.
* `AlumniDirectoryProvider` — `_alumniUpdatesSubscription` retained and cancelled.
* `PortfolioProvider` — `dispose()` override added; stream cancelled in `reset()`.
* `AuthGuard` — resets the full provider set on logout (verified in `lib/main.dart`: the
  `_isLoggedOut` reset block covers Profile, Placements, AIUsage, Notifications, ResumeReview, Role,
  Mentorship, Opportunity, AlumniDirectory, Chat, TeacherAnalytics, ActivityFeed, Recommendation,
  Engagement, AIChat, Portfolio, AlumniGroupChat, CareerCoach).
* `AlumniGroupChatProvider.setRoleForStream` still gates the group-chat listener on the alumni role,
  so no guaranteed `PERMISSION_DENIED` stream is opened for students/teachers.

The four transitions in `docs/logs.md` therefore re-verify the v9.2 fix on-device. No architecture
change is warranted, per the task's explicit instruction ("Do not rewrite working listener
architecture without evidence").

---

## 9. Logging — current state and gaps

### Kept (verified present and useful)

`TeacherAnalyticsProvider: Loaded …`, `ResumeReviewProvider: Loaded/Refreshed …`,
`RecommendationService: server regenerated recommendations …`,
`PortfolioProvider: detected flattened portfolio shape …`,
`PortfolioProvider: restored portfolio to server …`.

### Not logged anywhere in the app (verified by search)

Passwords, API keys, App Check debug tokens, Firebase ID tokens, private resume text, private user
data. The only debug token in the log is printed by the Firebase SDK.

### Gaps that block the §11/§12 measurements

1. **No startup phase timings** — the log cannot attribute the cold-start seconds to
   Firebase-init vs App-Check vs first-frame.
2. **No recommendation refresh *reason*** — the log prints "regenerated" with no indication of *why*
   (init vs manual vs fingerprint change) and no indication when a refresh was **skipped** as a
   duplicate.
3. **No cache hit/miss signal** for the recommendation refresh.
4. **No timing on expensive Firestore operations** (teacher analytics load, workbook reads).

v9.2.2 adds exactly these, debug/profile-only, and never logs a secret or personal datum.

---

## 10. Summary of root causes

| # | Symptom (from `docs/logs.md`) | Root cause | Category |
|---|---|---|---|
| 1 | `Skipped 77/30/32 frames` | Flutter Engine/Impeller bring-up + Android `performTraversals()` JIT + Firebase/GMS native init on the emulator. **No Dart-side cause.** | Performance / environment |
| 2 | Duplicate `server regenerated recommendations` | (A) client refresh has no in-flight or fingerprint de-duplication; (B) server regenerates unconditionally. | Correctness / cost |
| 3 | `Loaded 0 history items` → `Refreshed 0 history items` | Teacher dashboard forces a second identical `refreshHistory()` right after `initWithUser` already loaded it. | Cost / caller defect |
| 4 | Repeated `detected flattened portfolio shape` | Migration was **detected but never performed** — flagged and deferred to a manual save that also never deletes the legacy keys. | Data migration |
| 5 | `403 App attestation failed` / `Too many attempts` | The emulator's App Check **debug token is not allow-listed** on `campusconnect-firebase-project` (project itself is verified correct). | Configuration |
| 6 | GMS `DeadObjectException` / `Phenotype.API` / `DEVELOPER_ERROR` | Google Play Services inside the emulator image. | Environment |
| 7 | Teacher analytics one-load | Fix active — no action. | Regression check |
| 8 | No `NOT_FOUND Target id not found` | Listener-lifecycle fix active — no action. | Regression check |
| 9 | Missing measurement signals | No startup/reason/skip/cache logging. | Observability |

---

## 11. Fix plan implied by this investigation

| Section | Fix | Files |
|---|---|---|
| §1 | Debug-only startup phase + frame instrumentation; document the native baseline. **No speculative Dart change.** | `lib/utilities/startup_profiler.dart` (new), `lib/main.dart` |
| §2 | (a) Client `RefreshDedupe` gate (in-flight sharing + fingerprint skip + reset), (b) server fingerprint stored in `recommendations_meta/summary` with a `force` bypass, (c) reason/skip logging. | `lib/utilities/refresh_dedupe.dart` (new), `lib/services/firestore/recommendation_service.dart`, `lib/providers/recommendation_provider.dart`, `lib/views/dashboards/student_dashboard_view.dart`, `functions/recommendations/refresh.js` |
| §3 | Guard the teacher-dashboard history refresh on `historyInitialized` / `isLoadingHistory`. | `lib/views/dashboards/teacher_dashboard_view.dart` |
| §4 | Idempotent auto-migration of the flattened shape (nested write + legacy key deletion). | `lib/services/firestore/portfolio_migration.dart` (new), `lib/services/firestore/portfolio_service.dart`, `lib/providers/portfolio_provider.dart` |
| §5 | Verify + document; no code change. | report docs |
| §6 | Classify + document; no code change. | report docs |
| §7 | Re-verify + keep the existing tests. | `test/teacher_analytics_load_dedupe_test.dart` (existing) |
| §8 | Re-verify + document. | report docs |
| §9 | Add the four missing diagnostics (debug-only). | all touched files |
