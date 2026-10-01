# v9.2 — Whole-App Optimization & Stability — TODO

Source of truth for remaining work. Updated after each sub-task.
Priority legend: **P0** crash/security/data-corruption · **P1** startup/perf/cost · **P2** correctness/reliability · **P3** maintainability · **P4** optional.

---

## 0. Whole-App Audit Fixes — `docs/confirmation.md` (V9.2) — ACTIVE

Audit verdict: **NOT production-safe** — 1 CRITICAL + 3 HIGH + 6 MEDIUM + 7 LOW.
Every item below is a small, local fix except SEC-2↔BUG-2, which must ship together.

### P0 — Security (ship immediately)

- [x] **SEC-1 [CRITICAL] — remove the `users/{userId}` catch-all.** `match /{subcollection=**}`
      under `rules_version = '2'` matches **zero** segments, so it also matches the
      `users/{uid}` **document itself** and grants the owner an unconditional `write`,
      bypassing `canWriteRole` → any user can `update({role:'teacher'})` and read every
      user doc, all resume reviews, all analytics and all applications.
      Fix: delete the catch-all; enumerate the genuinely client-writable subcollections.
      Add a rules-contract test asserting a client `role` write is denied.
- [x] **SEC-2 [HIGH] — make the rules state the real writer per collection.** The same
      catch-all voids `write:false` on `recommendations`, `recommendations_meta`,
      `engagement_summary`, `ai_insights`, `career_coach`, the `activities` MED-5
      points guard and the `ai_interactions` `update:false`. Fix falls out of SEC-1 once
      the catch-all is narrowed — but each subcollection must be decided explicitly.
- [x] **BUG-2 [HIGH] — one engagement writer.** Client `EngagementService.recomputeEngagement`
      (every login) and the server `logUserActivity`/`recomputeEngagementSummary` both
      write `users/{uid}/engagement_summary/summary` with divergent point/streak
      algorithms (≈2× points, IST-vs-UTC streak drift). Make the **server** the sole
      writer; client only reads `engagementSummaryStream`; drop the redundant client
      `resumeReviewed` activity write. SEC-2 and BUG-2 ship together.

### P1 — High-severity correctness

- [x] **BUG-1 [HIGH] — AI retention never deletes anything.** `askAI` writes
      `timestamp`; `cleanupExpiredAIConversations` queried `createdAt`. Fixed the
      field name (the dead `ai_conversations` branch is kept for the transition
      window) and added the `ai_interactions.timestamp` COLLECTION_GROUP single-field
      index (`firestore.indexes.json` → `fieldOverrides`) the range query needs.
- [x] **BUG-11 [MED] — verify the shipped engine fix + add a test.** Declared-interest
      profiles emit **zero** role cards; undeclared profiles keep discovery cards.
      Verified by `functions/test/recommendations_engine.test.js` (3 tests: declared →
      0 cards, undeclared → discovery cards, `isDeclaredRole` exact-phrase/token).

### P2 — Medium correctness, integrity & cost

- [x] **BUG-3 [MED] — duplicate apply overwrites the "immutable" snapshot.** The
      Storage copy is now gated on `snapshotFile.exists()` — snapshot bytes are
      write-once, and a duplicate apply no longer pays a copy + `getSignedUrl`.
- [x] **BUG-4 [MED] — placement callables have no `timeoutSeconds`.** Set 120 s
      (`logPlacementApplication`), 60 s (`updateApplicationStatus`, `logPlacementView`).
- [x] **BUG-5 [MED] — teacher "Resume Review" metrics read the teacher's OWN history.**
      `_buildOverviewMetrics` now sources "Resume Reviews"/"Avg Review Score" from
      `TeacherAnalyticsProvider` (cross-student collectionGroup scan), the duplicate
      "Resume Review Insights" section (`_buildResumeInsights`) was removed, and the
      view no longer reads `ResumeReviewProvider` at all.
- [x] **BUG-6 [MED] — `updateApplicationStatus` re-creates a partial mirror + redundant
      placement read.** The mirror now copies `resume`/`resumeStoragePath`/
      `resumeVersion`/`atsScoreAtApplication`/`appliedAt` from the canonical doc, and
      the placement fields read inside the transaction are returned to the caller so
      the notification no longer re-reads the placement.
- [x] **PERF-1 [MED] — teacher analytics N+1 `engagement_summary` reads + unbounded
      scans.** `getEngagementAggregates` now batches the per-student
      `engagement_summary/summary` reads into chunked (500) `getAll()` calls
      instead of a serial `get()` per student — same documents, same aggregate
      values. (The unbounded roster/resumeReview scans remain deliberately exact
      per the v9.2 brief; materializing an `analytics/teacher_snapshot` is the
      larger follow-up under §9 "architecture bets".)

### P3 — Low-severity hygiene

- [x] **BUG-7** — `= request.data || {}` in `ai/deepAnalysis.js` (line 82).
- [x] **BUG-8** — `LoadDedupe.begin` now chains `.catchError((Object _) {…})` onto the
      future returned by `whenComplete`, so a rejected load can never surface as an
      unhandled async error (`lib/utilities/load_dedupe.dart` 46-56).
- [x] **BUG-9** — the profile-sync guard is now an IDENTITY check on the last-synced
      profile object (`_lastSyncedProfile`) instead of a one-shot boolean, so an
      in-session profile edit re-runs `PlacementsProvider.updateUserProfile`; still
      cleared on logout / re-login (`lib/main.dart` ~710-846).
- [x] **BUG-10** — delete the dead `EngagementProvider.trackActivity` (+ client activity write).
- [x] **INT-1** — placement snapshots were unreachable via `storage.rules`; the 2035
      signed URL is a decade-long bearer capability. Added
      `match /resumes/{userId}/snapshots/{fileName}` (read: owner/teacher/alumni,
      write: false) so the object is no longer URL-only; the path being rule-covered
      means a future drop to on-demand short-lived URLs needs no further rule change.
      (The signed URL is kept for now because the client opens the stored URL directly
      and has no liveness fallback.)
- [x] **Chat delete** — `chats/*/messages/*` update/delete is bound to
      `resource.data.senderId == request.auth.uid` (parity with
      `alumni_group_messages`); a participant can no longer delete a peer's message
      (`firestore.rules` ~516-519).
- [x] **`resumeReviews` tamper** — closed by making the collection
      SERVER-writable only: `reviewResume` now persists the review with the Admin
      SDK (`persistResumeReview`, returning `reviewId`), the owner create/update
      rules are `false`, the client `saveReview`/`_saveToHistory` writers were
      deleted, and the provider refreshes history instead of writing it.
- [x] **TEST-1** — added four `node --test` suites (fakes extended with `increment`,
      auto-ids and nested subcollections to drive `logUserActivity`):
      `placement_transitions.test.js` (9 — SEC-3 state machine),
      `retention_snapshot_contract.test.js` (6 — BUG-1 reader==writer field + index,
      BUG-3 copy gated on `exists()`), `engagement_activity.test.js` (7 — `dayKey`/
      `previousDayKey` + `logUserActivity` points/streak aggregate, same-day idempotent
      streak, next-day extend, gap reset), `recommendations_engine.test.js` (3 — BUG-11),
      plus the existing `quota.test.js` (11) + `schedulers.test.js` (2). `node --test`
      → **38 pass**.

### Validation for this section

- [x] `flutter analyze` clean — **No issues found!**
- [x] `flutter test` green — **All tests passed! (422)**
- [x] `node --check` on every changed Functions file — all pass
- [x] `node --test` green (functions) — **38 pass** (was 31 before TEST-1)
- [x] Firestore rules + indexes + Storage rules updated to match the code


## 1. Startup Performance — P1

- [x] Defer non-critical work until after first frame (lazy `MainNavigationView` tabs)
- [x] Lazy-build dashboard tabs — `IndexedStack` no longer builds all 5 heavy tabs in the first frame (primary "Skipped 45 frames!" cause)
- [x] Keep Firebase + App Check init before `runApp()` (correctness-critical; unchanged)
- [x] Remove duplicate initialisation — AuthGuard profile-sync + ecosystem-init post-frame callbacks now scheduled once per session
- [x] Idempotent analytics load (provider) + lazy tabs remove the startup duplicate reads
- [x] Document before/after startup sequence + skipped-frame behaviour — `docs/v9_2_audit_report.md` §2

## 2. Teacher Analytics Duplicate Loading — P1

- [x] Add re-entrancy guard (`_activeLoad` future de-dup) to `loadAnalytics()`
- [x] Stop `IndexedStack` tabs from both triggering the initial load (idempotent + de-dup)
- [x] Ensure empty-result retry cannot create concurrent duplicate loads (retry uses `force`)
- [x] Preserve pull-to-refresh (`refresh()` forces)
- [x] Reset state correctly on logout / re-login (epoch-based stale-load discard)

## 3. Teacher Analytics Firestore Cost — P1

- [x] Deduplicate queries within one load lifecycle (load-scoped cache in service)
- [x] Reuse already-loaded student data (single roster scan; `getStudentResumeData` cached)
- [x] Remove unnecessary repeated service calls (N count() reads → derived from one scan)
- [x] Preserve analytics correctness (no approximations)
- [x] Bound `collectionGroup('resumeReviews')` — verdict: kept exact (deduped to a single scan); capping would under-count reviews
- [x] Removed the per-student N+1 reads — `_latestReviewFor` now derives the latest review from the SHARED `collectionGroup('resumeReviews')` scan via `pickLatestReviewPerUser` (was one + a fallback `orderBy` query PER student); same selection rule, 0 extra reads
- [x] Wire `service.beginLoad()` into provider `_runLoad()` (clears caches each cycle)

## 4. Cloud Scheduler Consolidation — P1

- [x] Create consolidated quota-sweep scheduler (resumeReview + careerCoach + aiAnalysis)
- [x] Remove the 3 standalone `compensateStale*` onSchedule exports
- [x] Update `functions/index.js` exports
- [x] Preserve refund/compensation + no-double-charge semantics
- [x] Leave the other 4 scheduled jobs unchanged

## 5. Firestore Listener Lifecycle — P2

- [x] Audit subscriptions (chat, notifications, alumni group chat, portfolio, engagement, recommendation, career coach, mentorship
- [x] Cancel every subscription in `reset()` / `dispose()`
- [x] **OpportunityProvider** — `startListeningTo*` created untracked subscriptions → now retained (`_activeOpportunitiesSubscription` / `_alumniOpportunitiesSubscription`) and cancelled in `reset()` + new `dispose()`
- [x] **AlumniDirectoryProvider** — `startListeningToAlumniUpdates` created an untracked subscription → now retained (`_alumniUpdatesSubscription`) and cancelled in `reset()` + new `dispose()`
- [x] **PortfolioProvider** — stream was cancelled in `reset()` but there was no `dispose()` override → added
- [x] Verified AuthGuard logout resets every listener-holding provider (reset → `_cancelStream`/`cancel`)
- [ ] Runtime verify logout → login → re-login produces no `WatchStream ... NOT_FOUND`

## 6. AI Quota Architecture — Verify (no removal) — P2

- [x] Verify reservations / pendingRequestId / pendingSince / rollback — confirmed in `functions/ai/quota.js` (`consumeFeatureQuota`/`rollbackFeatureQuota`/`clearFeatureReservation`, all transactional)
- [x] Verify stale compensation still works with consolidated scheduler — `compensateStaleAIQuotas` calls the unchanged `quota.runFeatureSweep` per feature
- [x] Keep legacy mirrors for compatibility — unified + legacy written atomically on every consume/rollback/clear

## 7. Recommendation Engine — Preserve — P2

- [x] Verify no duplicate refreshes introduced by optimization changes — recommendation engine untouched; analytics dedupe removes duplicate *reads* only
- [x] Verify Dashboard / Career Coach / Teacher stay consistent — single writer (`recommendations/engine.js`) + shared `RecommendationProvider`, unchanged

## 8. Legacy Cleanup — P3

- [x] Verified `lib/views/archived/notes_view_legacy.dart` had no imports / routes / tests (only self-references; `notesRoute` maps to `StudentDashboardView`, legacy import was commented out) — **REMOVED**
- [x] Keep `ai_conversations` (classified **DEPRECATE**, not deleted — retention job still manages it)

## 9. Tests — P2

- [x] Functions tests: quota sweep (all three features, stale compensation, no double-refund) — `functions/test/quota.test.js` (11) + `functions/test/schedulers.test.js` (2); consolidated `compensateStaleAIQuotas` sweeps all 3 features and isolates failures.
- [x] Functions tests (audit §0 TEST-1): `placement_transitions.test.js` (9), `retention_snapshot_contract.test.js` (6), `engagement_activity.test.js` (7), `recommendations_engine.test.js` (3). `node --test` → **38 pass**.
- [x] Flutter tests: analytics duplicate-load guard, empty-result retry, refresh after reset — `test/teacher_analytics_load_dedupe_test.dart` (9 pass) exercises the REAL `LoadDedupe` gate (lib/utilities/load_dedupe.dart) used by `TeacherAnalyticsProvider`.
- [x] Flutter tests: latest-review-per-student derivation — `test/teacher_analytics_latest_review_test.dart` (9 pass) covers `pickLatestReviewPerUser` (newest `createdAt`, `reviewedAt` fallback, `createdAt` precedence, empty-uid and undated exclusions).
- [ ] Listener lifecycle test where testable
- [x] Do not delete existing tests (none removed)

## 10. Logging — P3

- [x] Keep useful diagnostics (analytics load, scheduler, quota sweep, errors all retained)
- [x] Remove repeated noisy logs — the duplicate `TeacherAnalyticsProvider: Loaded …` print (was ~3× per navigation) now prints once per load after the `LoadDedupe` fix
- [x] Never log secrets/tokens/keys — verified; App Check debug tokens are printed by the Firebase SDK only, never by app code

## 11. Validation — Required

- [x] `flutter analyze` passes — **No issues found!** (was 32 → 0; all fixes below)
- [x] `flutter test` passes — **All tests passed! (422 tests)**
- [x] `node --check` passes for every changed Functions file
- [x] Functions tests pass (`node --test` → 38 pass)
- [~] `flutter build apk --release` — **deferred** (user: "don't build it, we are just optimizing it")

## 12. Documentation — Required

- [x] Record startup init changes — audit report §2
- [x] Record analytics loading changes — audit report §3
- [x] Record scheduler consolidation — audit report §4
- [x] Record listener lifecycle changes — audit report §6
- [x] Record test coverage — audit report §11

## 13. Analyzer / Lint Cleanup — P3

- [x] Fix 8 `withOpacity` → `withValues(alpha:)` deprecations
      (activity_feed_widgets ×3, register_view, resume_insights_view ×2,
      student_analytics_view, home_widgets)
- [x] Fix 12 `DropdownButtonFormField(value:)` → `initialValue:` deprecations
      (edit_profile_view ×3, teacher_notes_view, upload_notes_view,
      create_opportunity_view, achievements_manager_screen,
      edit_portfolio_screen ×3, experience_manager_screen, profile_setup_view).
      Verified behaviour-preserving against the Flutter SDK: `value` maps 1:1
      to `FormField.initialValue` and `didUpdateWidget` calls
      `setValue(widget.initialValue)` when it changes.
- [x] Fix 12 `use_build_context_synchronously` sites
      - teacher_dashboard_view — capture providers before awaits (`_loadAll`, `onRefresh`)
      - teacher_notes_view — `mounted` → `context.mounted` (context is a param)
      - upload_notes_view — read `ProfileProvider` before the await
      - resume_review_detail_view — `mounted` → `context.mounted` (context is a param)

## 14. Deployment — Required (see audit report §17)

- [ ] Redeploy Cloud Functions — `firebase deploy --only functions` (or `--force` in CI). This creates `compensateStaleAIQuotas` and auto-removes the 3 orphaned `compensateStale*` functions **and their Cloud Scheduler jobs**.
- [ ] Rebuild + release the Flutter app (APK/App Bundle) for the startup/analytics/listener/N+1 changes.
- [x] Firestore rules — **no change** (teacher `collectionGroup('resumeReviews')` read already permitted; removing per-student reads only shrinks the surface).
- [x] Firestore indexes — **no change** (no new composite index required).
- [x] Storage rules — **no change**.
- [ ] App Check enforcement — Console-side toggle only (no file change).

## 15. Explicitly Out of Scope

- [ ] v9.3 UI/UX redesign — **NOT STARTED** (must remain untouched)
- [ ] New product features — **NOT REQUIRED**

---

# v9.2.2 — Runtime Performance & Recommendation Refresh Optimization — `docs/Task.md`

Baseline: `9.1.2+99` → released `9.2.2+100`.
Full write-up: `docs/v9_2_2_optimization_report.md` (fixes) + `docs/v9_2_2_investigation_report.md` (root causes).

## 1. Startup Performance — P0/P1 — DONE (instrumented, classified)

- [x] Profiled the cold-start window from `docs/logs.md` — no Dart output precedes the first `Skipped 77 frames`
- [x] Identified the contributors: Impeller/engine bring-up, `performTraversals()` JIT, Firebase/GMS/App Check native init (all outside Dart)
- [x] Inspected `main.dart`, Firebase init, App Check init, `AuthGuard`, `MultiProvider`, provider constructors, dashboards, prefs, fonts
- [x] Confirmed v9.2 deferred provider init + lazy tabs already removed the Dart-side first-frame work
- [x] Added lightweight startup instrumentation (phase marks + frame timings) — debug/profile only, no secrets
- [x] Did **not** add speculative Dart delays or "fixes" without evidence

## 2. Recommendation Refresh Deduplication — P1 — DONE

- [x] Traced every caller: client `initWithUser` / `refresh`, server `onProfileUpdatedRefreshAI` / `onResumeReviewCreatedRefreshMatches` + the callable
- [x] Client in-flight sharing (concurrent callers → one backend call) — `lib/utilities/refresh_dedupe.dart`
- [x] Client fingerprint skip (unchanged state → no server call) — `recommendation_fingerprint.dart`
- [x] Server fingerprint gate stored on `recommendations_meta/summary` + `force` bypass — `functions/recommendations/refresh.js`
- [x] Regeneration preserved for: profile/portfolio/resume change, candidate change, expiry, explicit refresh, logout/login
- [x] Unified writer, eligibility/security logic, metadata, cache and document structure preserved
- [x] Refresh reason + skip/cache-hit diagnostics added (debug only)
- [x] Regression tests: `test/refresh_dedupe_test.dart` (16), `test/recommendation_fingerprint_test.dart` (13), `functions/test/recommendations_refresh_dedupe.test.js` (12)

## 3. Resume Review Provider Refresh Deduplication — P2 — DONE

- [x] Traced the init path (`initWithUser` → `_loadHistory`)
- [x] Confirmed the redundant caller (`_TeacherDashboardTab._loadAll` → `refreshHistory`)
- [x] Guarded on `firstLoad && !_historyRefreshed && !historyInitialized && !isLoadingHistory`
- [x] Explicit refresh (pull-to-refresh / Try Again / post-review) preserved
- [x] Failed/absent init still reads; a new review still appears

## 4. Portfolio Compatibility Cleanup — P2 — DONE

- [x] Inspected the schema + compatibility handling (`_extractPortfolioMap`, `hasFlattenedPortfolioShape`)
- [x] Confirmed the canonical structure `users/{uid}.portfolio` with nested fields
- [x] Implemented a safe, controlled, idempotent migration (`portfolio_migration.dart` + `migrateFlattenedPortfolio`)
- [x] No valid portfolio information deleted; values re-nested verbatim
- [x] Backward compatible during migration (tolerant reader retained)
- [x] After migration, saves use the optimized nested/diff-write path
- [x] Regression tests: `test/portfolio_migration_test.dart` (14)

## 5. App Check Debug Configuration — P0 validation — DONE (diagnosis)

- [x] Verified the project (`firebase_options.dart` == `.firebaserc` == `campusconnect-firebase-project`)
- [x] Confirmed the debug token is printed by the SDK, not app code; no token is committed
- [x] Confirmed debug/release provider selection is correct (release keeps Play Integrity/DeviceCheck)
- [x] Root cause: the emulator debug token is not allow-listed for the project
- [ ] **Console action (human):** register `2d0591e7-…` under App Check → Manage debug tokens (or pin via `adb shell setprop`)
- [ ] Re-verify a debug session obtains a valid token with no repeated `403` / `Too many attempts`

## 6. Google Play Services / Emulator Diagnostics — P3 — DONE (classified)

- [x] Determined these originate from `com.google.android.gms`, not the app (stack frames verified)
- [x] Made **no** application change to suppress emulator noise
- [x] Documented them separately as environment-specific
- [x] Verified Firebase Auth + core Firebase ops still work in the same session

## 7. Teacher Analytics Regression Check — DONE

- [x] Confirmed one load per session (`Loaded 3 reviews, 1 students, …`)
- [x] `LoadDedupe` cache + in-flight dedup still active
- [x] No new duplicate loads introduced by this pass
- [x] Existing suite still green (`test/teacher_analytics_load_dedupe_test.dart`, 9)

## 8. Listener Lifecycle Regression Check — DONE

- [x] Opportunity / alumni-directory / portfolio / chat / notification / group-chat listeners cancelled correctly
- [x] 4 logout/login cycles in the log with no `NOT_FOUND Target id not found`
- [x] Re-login creates no duplicate subscriptions
- [x] No listener architecture rewritten

## 9. Logging Improvements — DONE

- [x] Startup phase timings + provider init timing (`StartupProfiler`)
- [x] Recommendation refresh reason + dedup + cache hit/miss
- [x] Portfolio migration result; expensive Firestore op durations
- [x] No passwords / API keys / App Check tokens / ID tokens / private resume text / private user data

## 10. Testing — DONE

- [x] Flutter: startup profiler, recommendation dedup, fingerprint, portfolio migration (54 new tests)
- [x] Functions: `computeRecommendationFingerprint` determinism/coverage (12 new tests)
- [x] `flutter analyze` → **No issues found!**
- [x] `flutter test` → **All tests passed! (476)**
- [x] `node --check` on every changed JS file → pass
- [x] `npm --prefix functions test` → **50 pass / 0 fail**
- [x] `flutter build apk --release` → built (version `9.2.2+100`)

## 11–12. Manual Validation + Performance Measurement

- [x] Instrumentation + measurement methodology documented (`docs/v9_2_2_optimization_report.md` §12)
- [x] Deterministic before/after recorded (test counts, refresh-call counts, read counts)
- [ ] On-device `flutter run --profile` Pixel 9 capture (human step — tooling is in place)

## 13. Constraints — honoured

- [x] No UI redesign · no new features · Firebase architecture retained · `Provider` retained
- [x] Recommendation engine retained; regeneration deduplicated, **not disabled**
- [x] App Check / security not weakened · lifecycle listeners retained · quotas unchanged
- [x] No API keys client-side · no speculative perf change without evidence

## 14. Documentation — DONE

- [x] `docs/v9_2_2_investigation_report.md` — problems + root causes
- [x] `docs/v9_2_2_optimization_report.md` — fixes, files changed, before/after, dedup behaviour, migration result, App Check result, emulator warnings, test results, remaining issues
