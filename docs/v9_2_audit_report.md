# CampusConnect v9.2 — Whole-App Audit, Optimization & Stability

**Scope:** technical audit + targeted fixes only. No UI/UX redesign (v9.3) was started; the
existing UI is visually unchanged.

**Status:** complete for the implemented workstreams. Every claim below is grounded in the
current source tree (file + symbol references included).

**Validation:** `flutter analyze` → **No issues found** · `flutter test` → **422 passing** ·
`node --test` (Functions) → **13 passing** · `node --check` on every changed Functions file →
clean. Release APK build was intentionally deferred (product decision: optimization pass only).

---

## 1. Critical Findings

| P | Area | Problem | Root Cause | Impact | Fix applied |
|---|------|---------|-----------|--------|-------------|
| P1 | Startup jank | `Skipped 45/56 frames!` on cold start | `MainNavigationView` used `IndexedStack`, which eagerly builds **all** dashboard tabs on the first frame after login | Every heavy tab (dashboard, notes, placements, AI, profile) ran its build + provider reads before first paint → severe main-thread jank | Lazy tab building in `MainNavigationView` (`_visitedTabs`) — only the visible tab builds; others are `SizedBox.shrink()` until first visit, then kept alive |
| P1 | Startup | Theme/Layout prefs blocked startup | `LocalPreferencesService.init()` awaited on the startup path before `runApp` (~171 skipped frames historically) | First frame stalled on disk I/O | Removed from `main()`; Theme/Layout providers self-init lazily (`..init()`), UI converges a few frames later |
| P1 | State mgmt | AuthGuard re-scheduled init callbacks on **every rebuild** | `addPostFrameCallback` guarded only by a data condition, not by a "scheduled once" flag | Repeated `updateUserProfile` / `setRoleForStream` / ecosystem `initWithUser` calls | `_profileSynced` + `_ecosystemInitScheduled` one-shot flags (reset on logout/re-login) |
| P1 | Teacher analytics | `Loaded 3 reviews…` logged ~3× on navigation | Both `IndexedStack` tabs + the empty-result retry each triggered `loadAnalytics()` concurrently | Duplicate Firestore reads (roster, `resumeReviews` collectionGroup, applications, engagement) | `LoadDedupe` gate: in-flight future de-dup + idempotent guard + epoch-based stale-load discard |
| P1 | Teacher analytics cost | 9 aggregate calls re-issued overlapping queries | No load-scoped cache in `TeacherAnalyticsService` | N× duplicate reads per load (roster scan, count() reads, collectionGroup) | `service.beginLoad()` clears a load-scoped read cache; each underlying query runs once per cycle |
| P1 | Teacher analytics cost | Per-student N+1 review reads | `_latestReviewFor` ran a per-student `orderBy('createdAt').limit(1)` query (+ a `reviewedAt` fallback) for EVERY student | Up to ~2×N extra reads per load, dominating the cost | Derive the latest review per student in memory from the shared `collectionGroup('resumeReviews')` scan (`pickLatestReviewPerUser`) — same selection rule, 0 extra reads |
| P1 | Cloud cost | 3 standalone `compensateStale*` scheduler jobs | Each AI feature shipped its own sweep job | 3 daily invocations + 3 separate quota queries per sweep | Consolidated → single `compensateStaleAIQuotas` job (`sweepFeature` per feature, failure-isolated) |
| P2 | Firestore listeners | `WatchStream … NOT_FOUND` around logout | `OpportunityProvider.startListeningTo*` and `AlumniDirectoryProvider.startListeningToAlumniUpdates` created **untracked** subscriptions; `PortfolioProvider` had no `dispose()` | Listeners survived logout → duplicate listeners + target-not-found warnings on next login | Retained handles; cancelled in `reset()` **and** new `dispose()` on all three providers |
| P3 | Analyzer | 32 `info` issues (deprecations + `use_build_context_synchronously`) | API drift (`withOpacity`, `DropdownButtonFormField.value`) and context-after-await | Noisy analyzer, latent async-UI correctness risk | All 32 fixed; `flutter analyze` clean |
| P3 | Legacy | Dead `notes_view_legacy.dart` | Superseded by NotesView decomposition | Dead code in repo | Verified unreferenced (no imports/routes/tests) → removed |

---

## 2. Startup Performance Investigation (frame skips)

### Root cause

The reported message was:

```
Skipped 45 frames!
```

(a second run showed `Skipped 56 frames!`).

This was **not** suppressed — the underlying cause was found and fixed. The dominant cause was
`MainNavigationView` wrapping every dashboard tab in a plain `IndexedStack`:

```dart
// BEFORE — IndexedStack eagerly builds EVERY child on the first frame
IndexedStack(index: _selectedIndex, children: widget.tabs.map((t) => t.widget).toList())
```

`IndexedStack` builds all children (it lays out only one, but every child's `build()`,
`initState()` and any post-frame loads run). For the Teacher/Student/Alumni dashboards that is
5 heavy subtrees — statistics grids, analytics, placement pipeline, AI insights, profile — all
building in the same frame that first renders after login. On the emulator (software rendering,
no JIT warm-up) that work overran the 16 ms frame budget by ~45–56 frames.

### Fix

Tabs are now built lazily and kept alive afterwards, so behaviour and state preservation are
unchanged:

```dart
// AFTER — build a tab only once it has been visited
late final Set<int> _visitedTabs = {_selectedIndex};
...
IndexedStack(
  index: _selectedIndex,
  children: [
    for (var i = 0; i < widget.tabs.length; i++)
      if (_visitedTabs.contains(i)) widget.tabs[i].widget
      else const SizedBox.shrink(),
  ],
)
```

### Root cause of the *foundation* of the jank (historical, already landed pre-v9.2)

- Firebase `initializeApp` + App Check activation remain **before** `runApp()` — this is
  correctness-critical (App Check must be configured before any Firebase SDK call) and is
  unchanged.
- `LocalPreferencesService.init()` was removed from `main()`: ThemeProvider/LayoutProvider now
  self-init lazily, so the first frame renders with defaults and converges to the stored theme a
  few frames later instead of stalling on disk I/O.

### Result

- First frame after login pays only for the tab actually on screen.
- Tabs are created on first visit (and kept alive by `IndexedStack` thereafter) so scroll
  position, controllers and in-flight loads are preserved exactly as before.
- No UI change is visible; the change is purely about *when* each subtree is built.

> Note: emulator frame timings are not deterministic run-to-run; the structural cause (eager
> build of N heavy tabs in one frame) is removed, which is the reproducible part. A numeric
> before/after frame count should be re-measured on-device with DevTools before/after a
> `flutter run --profile` session if a hard number is required.

---

## 3. Teacher Analytics Duplicate Loading

**Symptom (from logs):** `Loaded 3 reviews, 1 students, 1 depts, 1 pipeline eligible, 1 engagement summaries`
printed ~3× consecutively.

**Root cause:** the two dashboard tabs that consume analytics each called
`TeacherAnalyticsProvider.loadAnalytics()` from their own `initState` post-frame callback, and
the empty-result retry fired a third call — none of which knew about the others.

**Fix — `LoadDedupe`** (`lib/utilities/load_dedupe.dart`), a small reusable, unit-testable gate:

- `inFlight` — concurrent callers return the **same** future (one backend round-trip).
- idempotent guard — a non-forced call with data present is a no-op.
- `epoch` / `invalidate()` / `owns()` — a load in flight across a logout is discarded instead of
  writing into freshly-reset state.

`TeacherAnalyticsProvider.loadAnalytics({force})` now:

1. returns the in-flight future if one exists;
2. returns immediately if data is present and `force == false`;
3. otherwise starts exactly one `_runLoad()`, which captures the epoch and commits results only
   if `_loadGate.owns(epoch)` still holds.

`reset()` calls `_loadGate.invalidate()`, so logout → re-login starts a fresh load immediately and
a late result can never clobber reset state. Pull-to-refresh (`refresh() → loadAnalytics(force:true)`)
and the empty-result retry both go through the same gate, so neither can create duplicate loads.

**Cost:** the 9 service calls in `_runLoad()` now share one load-scoped read cache
(`service.beginLoad()` at the top of `_runLoad`), so the student roster, `resumeReviews`
collectionGroup, applications and per-student latest review are each read **once per cycle**
instead of once per aggregate.

**N+1 removal (v9.2 P1):** `_latestReviewFor(userId)` — used by both the leaderboard
(`_buildStudentResumeData`) and the department aggregation — previously ran a
`users/{uid}/resumeReviews orderBy('createdAt').limit(1)` query **per student**, plus a
`reviewedAt` fallback query whenever the first returned nothing. The shared
`collectionGroup('resumeReviews')` scan already holds every review, so the per-student latest is
now computed in memory by the pure function `pickLatestReviewPerUser` (module-level in the
service) with the **same selection rule** — newest `createdAt`, else newest `reviewedAt`. This
removes the N+1 entirely (0 additional reads) and is unit-tested without Firestore.

**Test:** `test/teacher_analytics_load_dedupe_test.dart` (9 tests) exercises the real gate
(concurrent piggyback, force, reset invalidation, stale-discard).
---

## 4. Cloud Scheduler & Cost Audit

Every scheduled job was mapped back to source (`functions/index.js` → `functions/schedulers/index.js`).

### Before

| Job | Source | Schedule | Verdict |
|-----|--------|----------|---------|
| `autoExpireOpportunities` | schedulers | every 60 min | **KEEP** — required; bounded query + batch write |
| `sendInactivityReminders` | schedulers | daily 09:00 | **KEEP** — product feature |
| `recomputeEngagementScores` | schedulers | daily 01:00 | **KEEP** — already paginated (50/page, cursor) + materialized aggregates |
| `cleanupExpiredAIConversations` | `ai/chatDelete.js` | daily | **KEEP** — retention policy (data hygiene) |
| `compensateStaleResumeQuota` | `ai/resumeReview.js` | daily | **MERGE** |
| `compensateStaleCareerCoachQuota` | `careerCoach.js` | daily | **MERGE** |
| `compensateStaleAIAnalysisQuota` | `ai/deepAnalysis.js` | daily | **MERGE** |

### After

| Job | Schedule | Change |
|-----|----------|--------|
| `autoExpireOpportunities` | every 60 min | unchanged |
| `sendInactivityReminders` | daily 09:00 | unchanged |
| `recomputeEngagementScores` | daily 01:00 | unchanged |
| `cleanupExpiredAIConversations` | daily | unchanged |
| **`compensateStaleAIQuotas`** | **daily 04:00** | **new — replaces the 3 per-feature sweeps** |

**Net: 7 scheduler jobs → 5.** The consolidated job sweeps `["resumeReview", "careerCoach", "aiAnalysis"]`
with a 24 h cutoff, running the **unchanged** `quota.runFeatureSweep(feature, cutoff)` per feature,
each in its own `try/catch` so one feature's failure cannot block the other two. Refund semantics,
stale detection, cutoff, limits, reservations and no-double-charge protection are identical to the
previous per-feature jobs — only the scheduling envelope changed (3 → 1).

**Do-not-delete note:** nothing was removed without confirming its dependency. The consolidated job
calls the same exported quota helper, and `functions/index.js` re-exports the single new name.
The remaining 4 jobs were left untouched (each still required and compatible with the current
architecture).

---

## 5. AI Quota Architecture

Unified store: **`user_ai_quotas/{uid}`** (nested per-feature maps), authoritative.

| Feature | Unified key | Legacy mirror | Mode | Default limit |
|---------|-------------|---------------|------|---------------|
| Chat | `chat` | `ai_usage` | daily (24 h) | 50/day |
| Resume review | `resumeReview` | `resume_usage` | monthly | 5/month |
| Career Coach | `careerCoach` | `career_coach_usage` | monthly | 3/month |
| AI analysis | `aiAnalysis` | `ai_analysis_usage` | monthly | 3/month |

**Verified intact** (`functions/ai/quota.js`):

- **Request reservations** — `consumeFeatureQuota` is an atomic check-then-increment **transaction**
  that stamps `pendingRequestId` + `pendingSince` (crash-safe).
- **Rollback** — `rollbackFeatureQuota` decrements **and** clears *this request's* reservation in one
  transaction (no double refund).
- **Clear** — `clearFeatureReservation` un-stamps a successful request's reservation; credit kept.
- **Stale compensation** — `runFeatureSweep` collects the **union** of users with a stale reservation
  in the unified doc *or* the legacy mirror and refunds each atomically across both (`sweepStaleReservation`),
  so a user appears once → no double refund and no divergence.
- **Legacy mirrors** — every consume/rollback/clear writes **both** stores atomically (backward
  compatibility for old readers and for the sweep's legacy query). Classified **KEEP (deprecate later)**,
  not removed.

No duplicate quota system was introduced and no limits or reservation semantics were changed.

---

## 6. Firestore Listener Lifecycle

| Provider | Leak | Fix |
|----------|------|-----|
| `OpportunityProvider` | `startListeningToActiveOpportunities` / `…AlumniOpportunities` created untracked subscriptions | retained as `_activeOpportunitiesSubscription` / `_alumniOpportunitiesSubscription`; cancelled in `reset()` **and** new `dispose()` |
| `AlumniDirectoryProvider` | `startListeningToAlumniUpdates` created an untracked subscription | retained as `_alumniUpdatesSubscription`; cancelled in `reset()` **and** new `dispose()` |
| `PortfolioProvider` | stream cancelled in `reset()` but no `dispose()` override existed | `dispose()` added that cancels `_streamSubscription` |

AuthGuard's logout path already resets every listener-holding provider (`reset()` → cancel), so the
new `dispose()` overrides cover the teardown path (app exit without a prior logout). This removes the
`WatchStream … NOT_FOUND` warning's cause: subscriptions no longer outlive the session, so a fresh
login cannot inherit a stale listener's target.

> Runtime re-verification (logout → login → re-login shows no `NOT_FOUND`) is still an open item —
> it needs a device/emulator session, which this pass deliberately skipped.

---

## 7. Memory & Resource Audit

- **Streams** — the three provider fixes above are the concrete leaks found during the audit.
- **Disposal** — `TeacherAnalyticsProvider.dispose()` sets `_isDisposed`; `reset()` deliberately does
  **not** (documented) so logout → re-login still works.
- **Timers / controllers** — no new timers were introduced; `Future.delayed` retries in
  `teacher_dashboard_view` are `mounted`-guarded.
- **Cache** — the teacher-analytics read cache is load-scoped (cleared by `beginLoad()`), so it cannot
  grow unbounded across sessions.

---

## 8. Security Audit (no regressions)

- **App Check** (`lib/main.dart::_activateAppCheck`) — debug/profile builds use the platform
  `debug` providers; **release** builds use Play Integrity (Android) / DeviceCheck (iOS) / reCAPTCHA
  v3 (Web). Debug tokens are never committed to source. Correct platforms only; desktop is skipped
  so startup cannot throw. Initialization order is correct: after `Firebase.initializeApp`, before
  `runApp`. Enforcement remains a Console-side setting (documented in-code).
- **Role gating** — route guards in `lib/main.dart` (`_guardStudentPortfolio`, `_guardAlumniGroupChat`,
  `_guardPlacementApplicants`) are client-side UX guards; the audit confirmed the corresponding
  Firestore rules / callables remain the server-side authority (e.g. `updateApplicationStatus`,
  alumni-only `alumni_group_messages`).
- **Quota manipulation** — quotas are consumed/rolled back only inside Admin-SDK transactions, and
  limits are enforced server-side (`enforceLimit` throws `resource-exhausted`). No client can raise a
  limit.
- **Secrets** — no API keys / tokens introduced into client code or logs during this pass.

No rule files (`firestore.rules`, `storage.rules`) were modified in v9.2.

---

## 9. Recommendation Engine — Preserved

The unified recommendation architecture was **not** modified. Confirmed in source: a single writer
(`functions/recommendations/engine.js` + `refresh.js`), the `recommendations_meta/summary` cache, and
the shared `RecommendationProvider` consumed by Dashboard / Career Coach / Teacher Insights. No second
engine was created and no scoring logic was changed. The teacher-analytics dedupe removes duplicate
*reads* only, not recommendation refreshes.

---

## 10. Legacy Code

| Component | Classification | Action |
|-----------|----------------|--------|
| `lib/views/archived/notes_view_legacy.dart` | **REMOVE** | removed — verified no imports/routes/tests reference it (`notesRoute` maps to `StudentDashboardView`) |
| legacy quota collections (`ai_usage`, `resume_usage`, `career_coach_usage`, `ai_analysis_usage`) | **KEEP (DEPRECATE)** | left in place — live write mirrors + sweep query depend on them |
| `ai_conversations` | **KEEP (DEPRECATE)** | not deleted — retention job still manages it |

No compatibility code was removed without verifying its data dependency.

---

## 11. Tests

- **Functions** (`node --test`, 13 passing):
  `functions/test/quota.test.js` (11) + `functions/test/schedulers.test.js` (2) cover the consolidated
  sweep: all three features refunded, stale detection, no double-refund, per-feature failure isolation.
  Shared fakes in `functions/test/firestore_fake.js` / `setup.js`.
- **Flutter** (`flutter test`, 422 passing):
  `test/teacher_analytics_load_dedupe_test.dart` (9) exercises the real `LoadDedupe` gate;
  `test/teacher_analytics_latest_review_test.dart` (9) covers `pickLatestReviewPerUser` (newest
  `createdAt`, `reviewedAt` fallback, `createdAt` precedence, empty-uid and undated exclusions).
  No existing tests were deleted.

---

## 12. Analyzer / Lint Cleanup

`flutter analyze`: **32 → 0** (`No issues found`).

- **8 ×** `withOpacity` → `withValues(alpha:)` (activity_feed_widgets ×3, register_view,
  resume_insights_view ×2, student_analytics_view, home_widgets).
- **12 ×** `DropdownButtonFormField(value:)` → `initialValue:`. Verified behaviour-preserving against
  the Flutter SDK source: `value` maps 1:1 to `FormField.initialValue`, and `didUpdateWidget` calls
  `setValue(widget.initialValue)` when it changes — so a post-build value change still updates the
  dropdown exactly as before.
- **12 ×** `use_build_context_synchronously`:
  - `teacher_dashboard_view` — capture providers before awaits (`_loadAll`, `onRefresh`).
  - `teacher_notes_view` / `resume_review_detail_view` — `mounted` → `context.mounted` (the guarded
    `context` is a method **parameter**, so the State's `mounted` was "unrelated" to it).
  - `upload_notes_view` — read `ProfileProvider` before the await.

---

## 13. Validation Results

| Check | Result |
|-------|--------|
| `flutter analyze` | **No issues found!** (11.4 s) |
| `flutter test` | **All tests passed! (422)** |
| `node --test` (functions) | **13 pass** |
| `node --check` (changed Functions files) | clean |
| `flutter build apk --release` | **deferred** (product decision — optimization pass only) |

---

## 14. Cost-Impact Analysis

| Area | Before | After | Type |
|------|--------|-------|------|
| Scheduler jobs (quota sweeps) | 3 invocations/day | 1 invocation/day | **Structural reduction** (evidence: `functions/index.js` exports) |
| Teacher analytics reads | N× duplicate per load (9 aggregates) | 1× per query per load cycle | **Structural reduction** (evidence: `beginLoad()` cache) |
| Teacher analytics per-student reads | up to ~2×N `orderBy` queries per load | 0 (derived from the shared scan) | **Structural reduction** (evidence: `pickLatestReviewPerUser` + shared `_resumeReviewDocs()`) |
| Startup work before first frame | all tabs + prefs init | visible tab only | **Structural reduction** (evidence: lazy `_visitedTabs`) |

> Per the task's rule, no numeric cost-saving figure is claimed without console evidence. The
> changes above are *structural* (fewer jobs, fewer duplicate queries, less first-frame work); the
> exact read/invocation deltas should be read from Firebase Usage & GCP billing after deployment.

---

## 15. Remaining Issues / Open Items

1. **Runtime logout→re-login** verification (no `NOT_FOUND`) — needs a device session.
2. **On-device frame timing** before/after for a precise skipped-frame number (DevTools, profile mode).
3. **App Check enforcement** — must be turned on in the Console after registering debug tokens
   (development) / verifying Play Integrity (production).
4. **Full audit breadth** — this pass fixed the identified P1/P2 items and cleared the analyzer; a
   deeper point-by-point sweep of every §1 checklist item (indexes, dependency currency, APK size,
   every screen) is ongoing and not yet exhaustively signed off.

---

## 16. Recommended Next Step

**v9.3 — Modern UI/UX Redesign**, now that the foundation is stable, duplicate initialization is
removed, listeners have correct lifecycles, the analyzer is clean, and tests pass.
---

## 17. Deployment Checklist (what must be (re)deployed)

The v9.2 changes touch **Cloud Functions** and **Flutter client code** only. Rules, indexes and
Storage rules do **not** change.

| Artifact | Change in v9.2? | Action required |
|----------|-----------------|-----------------|
| **Cloud Functions** (`functions/`) | **Yes** — scheduler consolidation (`index.js` + `schedulers/index.js`) | `firebase deploy --only functions` |
| **Cloud Scheduler jobs** | **Yes** — 3 jobs → 1 | handled automatically by the Functions deploy (see below) |
| **Flutter app** (`lib/`) | **Yes** — startup/analytics/perf + analyzer fixes | rebuild + re-release the APK/App Bundle |
| **Firestore rules** (`firestore.rules`) | **No** | none |
| **Firestore indexes** (`firestore.indexes.json`) | **No** | none |
| **Storage rules** (`storage.rules`) | **No** | none |
| **App Check enforcement** | **No file change** | Console-side toggle only (see §8) |

### Functions deploy — exact command

```bash
firebase deploy --only functions
```

Non-interactive (CI) form, which also confirms the removals without a prompt:

```bash
firebase deploy --only functions --force
```

**What this deploy does:**

1. **Creates** the new scheduled function `compensateStaleAIQuotas` (daily 04:00 UTC) and its Cloud
   Scheduler job.
2. **Deletes** the three functions that no longer exist in `functions/index.js`
   (`compensateStaleResumeQuota`, `compensateStaleCareerCoachQuota`, `compensateStaleAIAnalysisQuota`)
   together with their Cloud Scheduler jobs. The Firebase CLI removes functions that disappear from
   the source tree; the `--force` flag only suppresses the confirmation prompt for that deletion.
   This is safe — the consolidated job sweeps the same three features daily with the unchanged
   `quota.runFeatureSweep`.
3. Redeploys the other unchanged functions (`autoExpireOpportunities`, `sendInactivityReminders`,
   `recomputeEngagementScores`, the callables and triggers) with no behaviour change.

> **No data migration is required.** The consolidated job reads the same `user_ai_quotas/{uid}` and
> legacy mirror docs the old jobs read; no collection is created, renamed or backfilled.

### Client deploy

The Dart changes (lazy `MainNavigationView` tabs, `LoadDedupe`, listener-lifecycle fixes, the
`TeacherAnalyticsService` N+1 removal, analyzer fixes) ship with a normal app build:

```bash
flutter build apk --release      # or: flutter build appbundle --release
```

### Why rules/indexes are untouched

- The teacher analytics read now relies on `collectionGroup('resumeReviews')`, which was **already**
  permitted by `firestore.rules` line ~450 (`match /{path=**}/resumeReviews/{reviewId} { allow read:
  if isTeacher(); }`) and was already the query used before the N+1 removal — so removing the
  per-student `users/{uid}/resumeReviews orderBy` queries can only *reduce* the rule surface.
- No new composite index is needed: the removed queries used a single-field `orderBy` (auto-indexed)
  and the retained `collectionGroup('resumeReviews')` / `collectionGroup('applications')` scans
  carry no `where`/`orderBy` on a second field.
