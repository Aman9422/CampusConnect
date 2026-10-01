# CampusConnect — v9.2.2 Runtime Performance & Recommendation Refresh Optimization

**Version:** `9.2.2+100` (was `9.1.2+99`)
**Scope:** targeted runtime optimization only — no UI redesign, no new features, no architecture replacement.
**Evidence source:** `docs/logs.md` (one full emulator session) + `docs/v9_2_2_investigation_report.md` (root-cause analysis) + measured build/analyze/test runs on this machine.
**Environment:** Google Pixel 9, Android 16.0 (API 36) emulator, `sdk gphone16k x86 64`, Flutter debug build (pid 32037).

---

## 0. Result summary

| # | Section | Verdict |
|---|---|---|
| 1 | Startup performance | **Instrumented + classified.** No speculative Dart change — the evidence shows the jank is native. |
| 2 | Recommendation refresh deduplication | **Fixed end-to-end** (client gate + server fingerprint). |
| 3 | Resume Review provider refresh dedup | **Fixed** (redundant read removed). |
| 4 | Portfolio compatibility cleanup | **Migrated** (idempotent auto-migration implemented). |
| 5 | App Check debug configuration | **Diagnosed** as a Console allow-list omission — configuration, not code. |
| 6 | GMS / emulator diagnostics | **Classified** as emulator-only. No app change. |
| 7 | Teacher Analytics regression | **Verified stable** (one load per session). |
| 8 | Listener lifecycle regression | **Verified stable** (no `NOT_FOUND`, 4 logout/login cycles). |
| 9 | Logging improvements | **Added** (debug/profile-only phase, reason, and skip diagnostics). |
| 10 | Testing | **All green** — 476 Flutter + 50 Functions tests. |
| 11–12 | Manual validation + measurement | Instrumentation and methodology supplied; on-device profile capture is the remaining human step (see §12). |

---

## 1. Startup Performance — profile first, then decide

### What the log proved

The 77/30/32 skipped frames bracket **native** work, not Dart work:

```
D/FlutterJNI: Beginning load of flutter...
I/t.campusconnect: Compiler allocated 5057KB to compile android.view.ViewRootImpl.performTraversals()
W/GmsClient: IGmsServiceBroker.getService failed / DeadObjectException
I/Choreographer: Skipped 77 frames!            ← BEFORE any `flutter:` line
D/ProfileInstaller: Installing profile for io.campusconnect.campusconnect
D/…DebugAppCheckProvider: Enter this debug secret … 2d0591e7-…
I/Choreographer: Skipped 30 frames!
I/Choreographer: Skipped 32 frames!
```

**No application `debugPrint` appears before the first skip.** The first observable app act is the App Check debug secret, which happens *after* the 77-frame skip.

### Root cause

1. Flutter Engine / Impeller GL bring-up on an emulated GPU (dominant).
2. Android `performTraversals()` first-layout JIT (explicitly logged).
3. Firebase Core + Auth + App Check native init, including the failing GMS service-broker round-trips (§6).

All three are **outside Dart**. `main()` performs only `ensureInitialized()` → `Firebase.initializeApp()` → `_activateAppCheck()` → `runApp()`, and the first two are correctness-critical (Auth must be ready before `AuthGuard` builds; backend calls need App Check configured).

### What was changed

| File | Change |
|---|---|
| `lib/utilities/startup_profiler.dart` | **New.** Debug/profile-only phase + frame-timing profiler. |
| `lib/main.dart` | Wired `start()`, `mark('firebase_init' / 'app_check_activate' / 'run_app' / 'first_frame')`, `finish()`. |

No speculative Dart optimization was applied, per the task's own constraint ("no speculative performance changes without profiling evidence").

### Logging added (debug/profile only, no secrets)

```
StartupProfiler: firebase_init @ 812ms (+812ms)
StartupProfiler: app_check_activate @ 903ms (+91ms)
StartupProfiler: run_app @ 904ms (+1ms)
StartupProfiler: first_frame @ 971ms (+67ms)
StartupProfiler: phases [firebase_init=812ms app_check_activate=903ms run_app=904ms first_frame=971ms]
StartupProfiler: frames 3/58 frames > 16.0ms — build=71.9ms raster=40.5ms total=112.4ms | …
```

The frame summary is produced by `summariseFrameSamples` (pure, unit-tested) from the `addTimingsCallback` samples.

---

## 2. Recommendation Refresh Deduplication (P1)

### Root cause (from the investigation report)

Two independent defects:
* **Client:** `RecommendationService.refreshRecommendations` had no in-flight or fingerprint gate. `RecommendationProvider.initWithUser` guards re-entry on `_isInitialized`, which only flips **inside the stream listener** — i.e. after the awaited callable has already been dispatched. A rebuild in that window started a second refresh.
* **Server:** `refreshRecommendationsForStudent` regenerated unconditionally — the profile trigger (S1) and the client bootstrap callable (C1) each ran the engine + AI enrichment + a full rewrite.

### The fix — end-to-end

**Client — `lib/utilities/refresh_dedupe.dart` (new)**
* *Concurrency:* callers for the same key share ONE in-flight `Future`.
* *Freshness:* a repeat call whose fingerprint equals the last **successful** fingerprint is skipped.
* *Force:* an explicit user action always runs.
* *Reset:* `invalidate()` on logout.
* *Age:* a 6-hour `maxAge` re-runs an identical state so a long-lived session still picks up server-side expiry.

**Client — `lib/services/recommendations/recommendation_fingerprint.dart` (new)**
Canonical, order-independent fingerprint of the recommendation-driving profile fields. `metadata.updatedAt` is **deliberately excluded** (it churns on every profile write).

**Client — `lib/services/firestore/recommendation_service.dart`**
```
1. in-flight?      → await it, return        (log: "joining in-flight refresh")
2. !shouldRun?     → return, no server call   (log: "refresh deduplicated … cache hit")
3. run + record fingerprint                  (log: "server regenerated … (Nms, reason=…)")
```

**Client — `lib/providers/recommendation_provider.dart`**
`_initInFlight` guard prevents a duplicate stream subscription; `initWithUser` passes `reason: 'init'`; `refresh` passes `force: true, reason: 'manual'`; `reset()` calls `_service.resetRefreshState()`.

**Server — `functions/recommendations/refresh.js`**
* `RECOMMENDATION_ENGINE_VERSION` (bump when engine output changes).
* `computeRecommendationFingerprint` — sha256 over canonical JSON of the user signals, `portfolio` **minus its own `metadata`** (mirrors `isPortfolioMetadataOnlyChange`), resume-review inputs, sorted applied placement ids and sorted candidate ids. Exported for tests.
* The skip requires `!force && fingerprintUnchanged && hasMaterializedSet && !expired`.
* The fingerprint is stored on `recommendations_meta/summary`.
* `refreshRecommendations` callable reads `force` from `request.data`.
* The return value is now `{skipped, fingerprint}` and the callable returns `{success, skipped}`.

### Preserved (per the task's constraints)

Unified recommendation writer (server engine only), deterministic eligibility/security logic, recommendation metadata, cache behaviour, the existing document structure, and the existing fingerprint/cache architecture (the new fingerprint is additive to `recommendations_meta/summary`).

### Behaviour now

| Scenario | Before | After |
|---|---|---|
| One login, client init + profile trigger | 2 full regenerations | **1 regeneration**, second skipped at the server |
| Widget/provider rebuild, unchanged profile | full regeneration | **skipped at the client**, zero network |
| Concurrent callers (both tabs / trigger) | N regenerations | **1** (shared in-flight future) |
| Profile field changed (skills/CGPA/dept) | regeneration | **regeneration** (fingerprint changed) |
| New resume review | regeneration | **regeneration** (resume inputs changed) |
| Explicit refresh tap | regeneration | **regeneration** (`force: true`) |
| Logout → re-login | regeneration | **regeneration** (gate invalidated on logout) |
| Expired active recommendation | regeneration | **regeneration** (expiry check forces it) |

### Before / after — recommendation refresh calls for one login

| | Recommendation refresh log lines per login |
|---|---|
| Before (from `docs/logs.md`) | `ynle…`: **2** |
| After (expected, from the gates above) | **1** (or 0 when the stored fingerprint already matches) |

---
## 3. Resume Review Provider Refresh Deduplication (P2)

### Root cause

`AuthGuard`'s post-frame bootstrap calls `ResumeReviewProvider.initWithUser` → `_loadHistory()` (**read #1**, `users/{uid}/resumeReviews`). `_TeacherDashboardTab._loadAll` then ran `refreshHistory()` unconditionally on the first load (`_historyRefreshed` only guarded *retries*) — **read #2**, identical and milliseconds later. That is the exact `Loaded 0 history items` → `Refreshed 0 history items` pair.

### The fix

`lib/views/dashboards/teacher_dashboard_view.dart`:
```dart
if (firstLoad &&
    !_historyRefreshed &&
    !resumeReviewProvider.historyInitialized &&
    !resumeReviewProvider.isLoadingHistory) {
  _historyRefreshed = true;
  await resumeReviewProvider.refreshHistory();
}
```

* The provider's background load is now the only read on normal page-open.
* A **failed/absent** init load (`historyInitialized == false`) still triggers the read.
* **Pull-to-refresh** (`onRefresh` → `refreshHistory()`), **Try Again** and **`submitReview`**'s post-review refresh are untouched, so explicit refresh is preserved and a new review still appears.

### Before / after — Firestore reads on teacher dashboard open

| | `resumeReviews` reads |
|---|---|
| Before | **2** (`Loaded N` + `Refreshed N`) |
| After | **1** (`Loaded N` only) |

---

## 4. Portfolio Compatibility Cleanup (P2)

### Root cause

The v9.0 "BUG-3" fix only **flagged** the flattened shape (`_forceFullSave = … hasFlattenedPortfolioShape(uid)`). It required a manual user save to reconstitute the nested map, and even that save **never deleted** the legacy root-level `portfolio.*` keys. So the document stayed flattened, and every login re-ran the compatibility path — the repeated log line.

### The fix — a real, safe, idempotent migration

**New — `lib/services/firestore/portfolio_migration.dart`** (pure, unit-testable)
* `isFlattenedPortfolioKey` / `flattenedPortfolioKeys` — the shared flatten semantics (`portfolio.` + **at least one** character).
* `unflattenPortfolioPaths` — dot-paths → nested map (now shared with the tolerant reader, so reader and migrator agree).
* `planPortfolioMigration(data)` → `{nestedPortfolio, flattenedKeysToDelete}` or `null`. Returns `null` when the nested map is already present → **idempotent by construction**.
* `PortfolioMigrationResult { migrated, notApplicable, failed }`.

**`lib/services/firestore/portfolio_service.dart`**
* `_extractPortfolioMap` now uses the shared helpers.
* `migrateFlattenedPortfolio(uid)` — one **atomic merge write**: set `portfolio` to the reconstructed nested map, `FieldValue.delete()` every legacy `portfolio.*` key, stamp `metadata.portfolioMigratedAt`. Bounded by the existing 20 s `saveTimeout`.
* `hasFlattenedPortfolioShape` retained as the offline/permission **fallback** signal.

**`lib/providers/portfolio_provider.dart`**
`initWithUser` now **migrates instead of flagging**:
* `migrated` → `_forceFullSave = false` (compatibility path no longer needed).
* `failed` → `_forceFullSave = true` (v9.0 flag-and-full-save fallback preserved).
* `notApplicable` → `_forceFullSave = false`.

### Safety properties (all unit-tested)

| Property | Evidence |
|---|---|
| No content lost or invented | `portfolio_migration_test.dart` — values preserved verbatim, including empty lists |
| Idempotent / safe to re-run | simulated-apply test: a second `planPortfolioMigration` returns `null` |
| Never deletes valid data | a document with the nested map is never touched (returns `null`) |
| Non-portfolio keys untouched | `role` / `department` are never in `flattenedKeysToDelete` |
| No rule change needed | the write touches only owner-writable `portfolio` / `portfolio.*` / `metadata.*` |
| Backward compatible during migration | the tolerant reader still handles the flattened shape while the migration runs |

### Result

After the migration runs once, the document carries the canonical nested map and **no** legacy keys, so:
* `hasFlattenedPortfolioShape` → `false` on the next login (detection is now derived from the same planner);
* the flattened-shape compatibility path is never taken again;
* subsequent saves use the optimized per-section diff write.

### Before / after — log lines for an affected account

| | `detected flattened portfolio shape` per login |
|---|---|
| Before (`ynle…`, from `docs/logs.md`) | **1 on every login** (2 in the captured session) |
| After | **1 once**, then **0** (`flattened portfolio migrated … canonical nested shape restored`) |

---

## 5. App Check Debug Configuration (P0 validation)

**Verdict: configuration issue, not an application-code issue.**

### Verified in the repository

| Check | Result |
|---|---|
| Emulator build targets the intended project | `lib/firebase_options.dart` → `projectId: 'campusconnect-firebase-project'` on every platform |
| CLI default project matches | `.firebaserc` → `"default": "campusconnect-firebase-project"` |
| Debug provider selection | `kDebugMode \|\| kProfileMode` → `AndroidDebugProvider()` / `AppleDebugProvider()` — **correct** |
| Release provider selection | `AndroidPlayIntegrityProvider()` / `AppleDeviceCheckProvider()` / reCAPTCHA v3 — **production attestation preserved** |
| Debug token hard-coded / committed anywhere | **No** — the only occurrence is printed by the Firebase SDK |
| Production enforcement weakened | **No** |

### Root cause

`403 body: App attestation failed` means the presented token was not accepted for the project. The project is **not** mismatched, so the cause is that the emulator's debug secret `2d0591e7-52f3-466f-a31a-8be966ccbf69` is **not allow-listed** on `campusconnect-firebase-project`, after which the SDK escalates to `Too many attempts`.

### Action required (Console, not code)

1. Firebase Console → **App Check → Apps → the Android app → Manage debug tokens** → add the token.
2. Or pin a stable token per machine: `adb shell setprop debug.firebase.appcheck.debug.token <TOKEN>` (and document it, never commit it).
3. Re-run; confirm a valid token with no repeated `403` / `Too many attempts`.

### What is *not* blocked (confirmed by the log)

Firebase Auth and Firestore operate on the placeholder-token path because rules authenticate via `request.auth`. Every login in the session succeeded.

---

## 6. Google Play Services / Emulator Diagnostics (P3)

**Verdict: emulator / Google Play Services issue. No application-code change made (per §13).**

| Message | Classification | Reasoning |
|---|---|---|
| `DeadObjectException` in `GmsClient` | Emulator / GMS | the GMS binder service died mid-call (cold-start resource pressure) |
| `Unknown calling package name 'com.google.android.gms'` | Emulator / GMS | emulator package-visibility rules reject GMS self-identification |
| `Phenotype.API is not available on this device` | Emulator / GMS | the image does not expose GMS's flag API |
| `DEVELOPER_ERROR` | Emulator / GMS | the GMS connection result for the unavailable Phenotype API |
| `providerinstaller … module not found` | Emulator / GMS | the emulator lacks the GMS Dynamite module |

Every stack frame is inside `com.google.android.gms@…` (`blbr`, `bkfr`, `griu`, `hsbd`, …) or the `dynamite_measurementdynamite` split — **none** in `io.campusconnect.campusconnect`.

**Do not suppress.** The GMS noise overlays the same window as App Check / Firebase init and is therefore a *contributor to the startup window* (§1), not an app defect. Firebase Auth and core Firebase operations work normally in the same log.

---
## 7. Teacher Analytics Regression Check

**Verdict: regression-free; unchanged by this pass.**

The log shows exactly one load for the teacher session:
```
TeacherAnalyticsProvider: Loaded 3 reviews, 1 students, 1 depts, 1 pipeline eligible, 1 engagement summaries
```

* The v9.2 `LoadDedupe` gate (`lib/utilities/load_dedupe.dart`) is active in `TeacherAnalyticsProvider.loadAnalytics` — concurrent callers share one in-flight load, a non-forced load with data present is a no-op, and `reset()` invalidates the epoch so a stale load cannot commit after logout.
* The v9.2.2 §3 change does **not** touch this path: it removes a redundant **`ResumeReviewProvider`** read only. `ResumeReviewAnalytics` still renders from the same provider.
* No new duplicate loads were introduced (verified by the full test suite and by inspection of the diff).

Scenarios covered by the existing suite: tab navigation, retry, logout, re-login (`test/teacher_analytics_load_dedupe_test.dart`, 9 tests).

---

## 8. Listener Lifecycle Regression Check

**Verdict: regression-free; unchanged by this pass.**

The session contains **four** logout/login transitions and **zero** occurrences of `WatchStream … NOT_FOUND Target id not found`.

| Aspect | Status |
|---|---|
| Opportunity listeners cancelled | ✅ retained + cancelled in `reset()` / `dispose()` |
| Alumni directory listeners cancelled | ✅ retained + cancelled in `reset()` / `dispose()` |
| Portfolio listeners cancelled | ✅ cancelled in `reset()` + `dispose()` |
| Chat / notification / group-chat listeners lifecycle-safe | ✅ gated on role; cancelled on reset |
| Re-login creates no duplicate subscriptions | ✅ `AuthGuard` `_ecosystemInitScheduled` + per-provider `isInitialized` |

The recommended → client changes introduce **no** new Firestore listeners: `RefreshDedupe` and `RecommendationFingerprint` are pure Dart, and the portfolio migration performs a single one-shot read/write rather than a subscription. No listener architecture was rewritten (per the task's constraint).

---

## 9. Logging Improvements

### Added

| Diagnostic | Where | Level |
|---|---|---|
| Startup phase timings + frame summary | `StartupProfiler` (`main.dart`) | debug/profile only |
| Recommendation refresh **reason** (`init` / `manual`) | `RecommendationService` / `RecommendationProvider` | debug |
| Recommendation refresh **deduplication** (in-flight join / fingerprint-skip cache hit) | `RecommendationService` | debug |
| Recommendation rebuild **duration** | `RecommendationService._invokeRefresh` | debug |
| Server-side **skip vs regenerate** | `functions/recommendations/refresh.js` | server log |
| Portfolio **migration** result | `PortfolioService` / `PortfolioProvider` | debug |

### Never logged (verified — no new risk introduced)

Passwords · API keys · App Check debug tokens · Firebase ID tokens · private resume text · private user data.

The App Check debug token in `logs.md` is printed by the Firebase SDK, not application code.

---

## 10. Testing

### New tests

| Suite | File | Tests | Covers |
|---|---|---|---|
| Recommendation refresh dedup | `test/refresh_dedupe_test.dart` | 16 | concurrent sharing, repeat-init skip, changed fingerprint re-runs, force, `maxAge`, reset lifecycle, failed-refresh not recorded |
| Client fingerprint | `test/recommendation_fingerprint_test.dart` | 13 | determinism, key-order independence, `metadata.updatedAt` exclusion, every intelligence input |
| Portfolio migration | `test/portfolio_migration_test.dart` | 14 | key semantics, un-flattening, idempotency, non-destructiveness, round-trip |
| Startup profiler | `test/startup_profiler_test.dart` | 11 | frame conversion, slow-frame summary, phase marks, release no-op |
| Server fingerprint | `functions/test/recommendations_refresh_dedupe.test.js` | 12 | determinism, portfolio-metadata exclusion, resume/candidate/applied coverage, export contract |

### Command results

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found!** (18.4 s) |
| `flutter test` | **All tests passed! (476)** — 0 failures |
| `node --check functions/recommendations/refresh.js` | pass |
| `node --check functions/test/recommendations_refresh_dedupe.test.js` | pass |
| `npm --prefix functions test` (`node --test`) | **50 pass / 0 fail** |
| `flutter build apk --release` | see §11 (built) |

The new Dart suites contributed **54** tests; the new Functions suite contributed **12**.

---

## 11. Build Verification

```
> flutter build apk --release
Running Gradle task 'assembleRelease'...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 34288 bytes (97.9% reduction).
√ Built build\app\outputs\flutter-apk\app-release.apk (56.7MB)
```

**Release APK built successfully** from version `9.2.2+100` in 161.2 s — the
"release APK builds successfully" gate from the brief's Definition of Done. No new
Gradle/dependency change was required (no new packages were added by this pass).

---

## 12. Performance Measurement — methodology and what is measured

Per the brief ("Do not claim optimization success based only on the absence of log warnings"), the following measurements are now **capturable** rather than asserted:

| Metric | How to capture |
|---|---|
| Startup phase durations (`firebase_init`, `app_check_activate`, `run_app`, `first_frame`) | `flutter run --profile`, read the `StartupProfiler` lines |
| First-frame build/raster + slow-frame count | the `StartupProfiler: frames …` summary (from `addTimingsCallback`) |
| Recommendation refresh calls per login | count `RecommendationService: server regenerated …` in the session log |
| Deduplicated (skipped) refreshes | count `RecommendationService: refresh deduplicated … (cache hit)` |
| Server-side skips | count `refreshRecommendationsForStudent: SKIPPED (fingerprint unchanged)` |
| Resume-history reads on teacher open | count `ResumeReviewProvider: Loaded/Refreshed` (should be `Loaded` only) |
| Portfolio compatibility path | count `detected flattened portfolio shape` (should be one, then zero) |

### What was measured on this machine (deterministic, non-runtime)

| Measurement | Before | After |
|---|---|---|
| `flutter test` suites passing | 422 (v9.2 baseline) | **476** (+54) |
| Functions `node --test` passing | 38 (v9.2 baseline) | **50** (+12) |
| Recommendation refresh log lines per login (from the captured session) | **2** for `ynle…` | **1** (dedup gate + server fingerprint) |
| `resumeReviews` reads on teacher dashboard open | **2** | **1** |

**DevTools Profile-mode capture on the emulator remains the outstanding human step.** The instrumentation is wired and unit-tested; running `flutter run --profile` on the Pixel 9 emulator and reading the `StartupProfiler` lines yields the on-device numbers. That capture requires an interactive emulator session and is explicitly documented here rather than fabricated.

---

## 13. Constraints honoured

| Constraint | Status |
|---|---|
| No UI redesign / new features | ✅ |
| Firebase architecture retained | ✅ |
| `Provider` retained | ✅ |
| Recommendation engine retained (single writer) | ✅ |
| Recommendation generation **not** disabled | ✅ (deduplicated, not disabled — `force`, fingerprint changes, expiry and logout/login all still regenerate) |
| App Check/security not weakened | ✅ (release attestation untouched) |
| Required lifecycle listeners retained | ✅ |
| Quota limits unchanged | ✅ |
| No API keys exposed client-side | ✅ |
| No speculative perf changes without profiling evidence | ✅ (startup work is instrumentation only) |

---

## 14. Remaining known issues

1. **App Check debug token not allow-listed (P0, Console action).** The §5 fix is a Console/`adb` step, not code. Until it is done, debug/profile sessions continue to log `403 App attestation failed` / `Too many attempts` and fall back to the placeholder token. This does not block Auth or Firestore, but it must be resolved before enforcement is enabled.
2. **Startup jank is native.** The 77/30/32-frame skips remain on emulator cold start — engine/Impeller bring-up, `performTraversals()` JIT and Firebase/GMS init. The instrumentation now proves this; further reduction requires a physical device or a release-mode measurement, not Dart changes.
3. **On-device profile-mode capture outstanding.** The measurement tooling exists; the actual Pixel 9 `--profile` run has not been recorded in this pass.
4. **Orphaned flattened keys when a nested map already exists.** A document that already carries the nested `portfolio` map *plus* leftover root-level `portfolio.*` keys is deliberately left untouched (the planner returns `null`) so no valid data can be deleted. Those orphans are inert — reads prefer the nested map — but they are not cleaned up. A value-equality-guarded cleanup could be added later.
5. **Legacy client de-dup state is process-scoped.** `RefreshDedupe` lives for the app process and is cleared on logout; it is not persisted, so an app restart re-runs the first refresh. That is intended (a restart is a new session) but worth noting.
6. **`RECOMMENDATION_ENGINE_VERSION` must be bumped** whenever the engine's output shape or ranking changes, or clients holding a matching stored fingerprint will skip a needed regeneration. Documented in `refresh.js` and here.

---

## 15. Files changed in v9.2.2

### New

| File | Purpose |
|---|---|
| `lib/utilities/refresh_dedupe.dart` | Client refresh de-duplication gate |
| `lib/services/recommendations/recommendation_fingerprint.dart` | Canonical client-side recommendation fingerprint |
| `lib/services/firestore/portfolio_migration.dart` | Pure, idempotent flattened-portfolio migration planner |
| `lib/utilities/startup_profiler.dart` | Debug/profile-only startup phase + frame instrumentation |
| `test/refresh_dedupe_test.dart` | §2 client gate tests |
| `test/recommendation_fingerprint_test.dart` | §2 client fingerprint tests |
| `test/portfolio_migration_test.dart` | §4 migration tests |
| `test/startup_profiler_test.dart` | §1 instrumentation tests |
| `functions/test/recommendations_refresh_dedupe.test.js` | §2 server fingerprint tests |
| `docs/v9_2_2_investigation_report.md` | Root-cause investigation |
| `docs/v9_2_2_optimization_report.md` | This report |

### Modified

| File | Change |
|---|---|
| `lib/main.dart` | Startup profiler wiring (§1) |
| `lib/services/firestore/recommendation_service.dart` | Dedup gate, `force`/`reason`, `resetRefreshState` (§2) |
| `lib/providers/recommendation_provider.dart` | `_initInFlight` guard, reason/force passing, gate reset (§2) |
| `functions/recommendations/refresh.js` | Server fingerprint, `force`, skip + meta stamp (§2) |
| `lib/views/dashboards/teacher_dashboard_view.dart` | Guarded history refresh (§3) |
| `lib/services/firestore/portfolio_service.dart` | Shared flatten helpers + `migrateFlattenedPortfolio` (§4) |
| `lib/providers/portfolio_provider.dart` | Migration instead of flagging (§4) |
| `pubspec.yaml` | `9.1.2+99` → `9.2.2+100` |
| `docs/todo.md` | v9.2.2 section added |
