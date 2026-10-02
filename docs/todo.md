# CampusConnect — Master TODO

Active workstream: **v9.2.4 — Critical Security, Correctness & Production Hardening**.

---

# v9.2.4 — Critical Security, Correctness & Production Hardening — `docs/Task.md` — ACTIVE

Source: `docs/v9_2_3_audit_report.md` (whole-application deep audit) → `docs/Task.md` (v9.2.4 scope).
Baseline: `9.2.2+100`. Target: `9.2.4+101`.
No UI redesign · no new features · no architecture rewrite · no mass dependency upgrade · no Firestore data deletion.

**Deployment scope (v9.2.4 re-scope):** final-year academic project — **no Google Play publication**.
Firebase backend → signed Flutter **release APK** → **direct install on phone/emulator** → demonstration.
No Play Console account, no $25 fee, no Play upload/testing. See `docs/Task.md` §0.
App Check is **configured and deliberately NOT enforced** for this distribution (`docs/app_check_status.md` §4);
the security guarantee rests on Auth + Firestore/Storage rules + callable auth/role checks + quotas, all of which stay enforced.

## 1. Release Signing — C-1 — P0 — DONE

Direct-distribution release key (not a Play upload key — see the deployment scope above).

- [x] Configure a release signing config in `android/app/build.gradle.kts` — release build **aborts** without credentials, never falls back to the debug key
- [x] Load credentials from `key.properties` (git-ignored), with a `.template` for reproducibility
- [x] Keep the debug signing config for the `debug` build type only
- [x] Wire the `release` build type to the real release signing config
- [x] Confirm `key.properties` + `*.jks`/`*.keystore` stay Git-ignored (`android/.gitignore`)
- [x] Document the signing setup (`docs/release_signing.md`), including the **direct install** path (`adb install -r …`)
- [x] Runtime-verified: APK + AAB built and proven release-signed with `apksigner verify --print-certs` (≠ debug key digests); throwaway validation keystore removed afterwards

## 2. App Check — C-2 — P0 — DONE (re-scoped for non-Play distribution)

- [x] Provider selection already correct — extracted to `lib/services/app_check/app_check_config.dart`, pinned by `test/app_check_config_test.dart`
- [x] Document the final App Check state + the non-Play posture (`docs/app_check_status.md`)
- [x] Confirm no debug tokens are committed (C-2 source-contract test)
- [x] Record that Play Integrity's non-Play path needs a Play Console API link → **out of scope**, so enforcement stays **OFF** by design
- [x] No insecure App Check bypass and no custom attestation backend introduced
- [ ] Console actions (operator, optional): allow-list the development debug token. **Do not enable enforcement** unless the Play Console link in `docs/app_check_status.md` §7 is completed

## 3. Resume Review Trigger Chain — D-1 — P0 — DONE

- [x] Added a resume-review-metadata-only change guard to `onProfileUpdatedRefreshAI` (`functions/triggers/index.js`, guard in `functions/helpers/shared.js`)
- [x] Exported the guard from `helpers/shared.js` (pure, unit-testable)
- [x] Preserved `reviewCount` / `lastReviewAt` / `latestATSScore` / portfolio resume data
- [x] Preserved the unified recommendation writer + server fingerprint mechanism
- [x] Ensured one resume review ⇒ exactly one effective recommendation refresh
- [x] Ensured engagement points are awarded once (no `profileUpdated` on the metadata write)
- [x] Tests: `functions/test/resume_review_single_refresh.test.js`

## 4. Placement Apply Reliability — D-2 — P1 — DONE

- [x] Raised client timeout for `logPlacementApplication` 30 s → 120 s (matches server)
- [x] Raised client timeout for `updateApplicationStatus` 30 s → 60 s (matches server)
- [x] No rollback of `_appliedPlacementIds` on timeout — pending/reconciliation state introduced (`lib/providers/placements_provider.dart`)
- [x] Reconciles server state with one read after a timeout
- [x] Preserved server-side idempotency + duplicate prevention
- [x] Tests: `test/placement_timeout_reconciliation_test.dart`

## 5. Placement Eligibility Parity — D-3 — P1 — DONE

- [x] Aligned `lib/services/eligibility_engine.dart` with `checkMandatoryEligibility`
      (`programs` / `branches` treated as alternatives, not both required)
- [x] Updated `docs/eligibility_rules.md` to match the actual implementation
- [x] No second eligibility engine created
- [x] Table-driven test: programs only · branches only · both · match program ·
      match branch · non-match program · non-match branch · missing student program
      → `test/eligibility_parity_test.dart`

## 6. Opportunity Authorization — D-9 — P0 — DONE

- [x] Require `userRole() == 'alumni'` for opportunity create (`firestore.rules`)
- [x] Preserved ownership checks for update/delete
- [x] Rule tests: alumni create allowed · student denied · teacher denied ·
      unauthenticated denied · owner update/delete allowed · non-owner denied
      → `functions/test/security_rules_contract.test.js` (source contract) +
      `functions/test-rules/firestore_rules.test.js` (**executed** against the Firestore emulator)

## 7. Opportunity Schema Validation — D-10 — P1 — DONE

- [x] Added `isValidOpportunityData()` at least as strong as `isValidPlacementData()` (`firestore.rules`)
- [x] Applied to both create and update
- [x] Validates: title, company, description, type, location, postedAt,
      applicationDeadline, isActive, alumniId == request.auth.uid
      (field list reconciled against the real writer, `lib/models/opportunity.dart::toFirestore`)
- [x] Rule tests: `functions/test/security_rules_contract.test.js` (source contract) +
      the executed emulator matrix (malformed writes denied, the well-formed one accepted)

## 8. Users Profile Flag Hardening — D-11 — P1 — DONE

- [x] Restricted `profileCompleted` to a validated transition (absent/false → true, and only with the profile sections present) — `firestore.rules`
- [x] Made `isVerified` client-immutable (clients may not change it)
- [x] Preserved the legitimate profile-completion workflow (`updateProfile()` then `markProfileCompleted()` verifies against the real code path)
- [x] Did not change `role` behaviour
- [x] Rule tests for both flags — `functions/test/security_rules_contract.test.js` (source contract)
      and the executed emulator matrix (tampering denied, genuine completion allowed)

## 9. AI Chat Single-Writer — D-7 — P1 — DONE

- [x] Server remains the single writer for `users/{uid}/ai_interactions`
- [x] Removed the client `_saveInteraction` Firestore write + `AIInteraction.toFirestore` (`lib/providers/ai_chat_provider.dart`, `lib/models/ai_interaction.dart`)
- [x] Updated the Flutter reader to the server schema (`message` / `role` / `timestamp`)
- [x] Verified retention cleanup + history loading use the same schema
- [x] Preserved `deleteAIHistory`; `ai_conversations` writes were not restored
- [x] Tests: `test/ai_chat_single_writer_test.dart`, `test/ai_chat_deletion_test.dart`

## 10. Scheduler Bulk Safety — E-3 — P1 — DONE

- [x] `autoExpireOpportunities` chunks writes (400/batch) instead of one batch (`functions/schedulers/index.js`)
- [x] Preserved scheduler behaviour + idempotency; job count unchanged (still 5)
- [x] Tests: `functions/test/schedulers_expiry.test.js` (empty · small · multi-batch)

## 11. Error Handling Consistency — E-18 — P3 — DONE

- [x] `functions/ai/deepAnalysis.js` → `instanceof admin.functions.https.HttpsError`; the duck-typed check is gone
- [x] Pinned by `functions/test/hardening_source_contracts.test.js` (E-18 group)

## 12. Regression Tests — P1 — DONE

- [x] Resume-review trigger guard (single refresh) — `functions/test/resume_review_single_refresh.test.js`
- [x] Recommendation fingerprint convergence — same suite (3 convergence tests: options-agnostic, new-review invalidation, `portfolio.metadata` flutter ignored)
- [x] Placement timeout + pending/reconciliation — `test/placement_timeout_reconciliation_test.dart`
- [x] Client/server eligibility parity (table-driven) — `test/eligibility_parity_test.dart`
- [x] Opportunity authorization rules — `functions/test/security_rules_contract.test.js` (text contract) + **executed** in `functions/test-rules/firestore_rules.test.js`
- [x] Opportunity schema validation rules — same two suites
- [x] `profileCompleted` / `isVerified` write restrictions — same two suites
- [x] Firestore rules **executed against the Firestore emulator** — D-9 / D-10 / D-11 / SEC-1 / SEC-2 / D-7, **37 allow/deny assertions**, `npm --prefix functions run test:rules`
- [x] AI chat single-writer — `test/ai_chat_single_writer_test.dart`
- [x] Scheduler multi-batch expiry — `functions/test/schedulers_expiry.test.js`
- [x] `HttpsError` handling — `functions/test/hardening_source_contracts.test.js` (E-18 group)
- [x] Release signing / App Check config — `functions/test/hardening_source_contracts.test.js` (C-1 / C-2 groups) + `test/app_check_config_test.dart`
- [x] Do not remove existing tests — none removed

## 13. Documentation & Versioning — P2 — DONE

- [x] `pubspec.yaml` → `9.2.4+101`
- [x] `docs/v9_2_4_hardening_report.md` — full report (§1–§20)
- [x] Security/rules documentation — D-9 / D-10 / D-11 recorded in the report §6
- [x] Eligibility documentation — `docs/eligibility_rules.md` corrected to the shipped semantics
- [x] App Check status documentation — `docs/app_check_status.md` rewritten for the **non-Play / direct-APK** posture
- [x] Release signing documentation — `docs/release_signing.md` rewritten for a **direct-distribution release key** (incl. `apksigner` check and `adb install`)
- [x] Correct v9.2.3 audit metadata — `docs/v9_2_3_audit_report.md` §AD (date 2026-10-02, v9.2.3 = audit-only vs v9.2.4 = implementation, test-count wording reconciled without changing historical results)
- [x] `docs/Task.md` §0 deployment scope + `v9.2.4 re-scope` notes + re-scoped Definition of Done (Google Play publication explicitly out of scope)
- [x] `docs/confirmation.md` — v9.2.4 DoD confirmation

## 14. Automated Validation — Required — DONE

All runs 2026-10-02, after the final source change. Full evidence in
`docs/v9_2_4_hardening_report.md` §15 and `docs/confirmation.md` §3.

- [x] `flutter pub get` — resolved; **no dependency version changed in v9.2.4**
- [x] `flutter analyze` clean — **No issues found! (ran in 13.5s)**, exit 0
- [x] `flutter test` green — **All tests passed! (540)**, exit 0
- [x] `npm --prefix functions test` green — **97 tests / 97 pass / 0 fail / 0 skipped**
- [x] `node --check` on every changed Functions file — exit 0 on all 6
- [x] `flutter build apk --release` — `app-release.apk`, 56.7 MB
- [x] `apksigner verify --print-certs` — release signer, **not** the debug key (different DN and SHA-256)
- [x] `flutter build appbundle --release` *(optional per `docs/Task.md` §0)* — `app-release.aab`, 46.8 MB
- [x] `firebase deploy --only functions --dry-run` — **`+  Dry run complete!`**, exit 0
- [x] Firestore rules validated **two ways** — source contract
      (`functions/test/security_rules_contract.test.js`) **and executed** against the
      Firestore emulator (`functions/test-rules/firestore_rules.test.js` →
      **37 tests / 37 pass / 0 fail / 0 skipped**, `npm --prefix functions run test:rules`, exit 0)
- [x] No secrets committed — `git ls-files` has no `key.properties` / `*.jks` / `*.keystore`
- [ ] `adb install` on the demo device + the manual matrix (`docs/Task.md` §15)
      — **operator action**, no device attached to this environment
- [ ] Deploy the hardened rules + Functions — **operator action**, nothing deployed in v9.2.4

---
# v9.2 — Whole-App Optimization & Stability — TODO (COMPLETE)

Source of truth for remaining work. Updated after each sub-task.
Priority legend: **P0** crash/security/data-corruption · **P1** startup/perf/cost · **P2** correctness/reliability · **P3** maintainability · **P4** optional.

---

## 0. Whole-App Audit Fixes — `docs/confirmation.md` (V9.2) — COMPLETE

Audit verdict: **NOT production-safe** — 1 CRITICAL + 3 HIGH + 6 MEDIUM + 7 LOW.
Every item below is a small, local fix except SEC-2↔BUG-2, which shipped together.

### P0 — Security

- [x] **SEC-1 [CRITICAL] — remove the `users/{userId}` catch-all.**
- [x] **SEC-2 [HIGH] — make the rules state the real writer per collection.**
- [x] **BUG-2 [HIGH] — one engagement writer.**

### P1 — High-severity correctness

- [x] **BUG-1 [HIGH] — AI retention never deletes anything.**
- [x] **BUG-11 [MED] — verify the shipped engine fix + add a test.**

### P2 — Medium correctness, integrity & cost

- [x] **BUG-3 [MED] — duplicate apply overwrites the "immutable" snapshot.**
- [x] **BUG-4 [MED] — placement callables have no `timeoutSeconds`.**
- [x] **BUG-5 [MED] — teacher "Resume Review" metrics read the teacher's OWN history.**
- [x] **BUG-6 [MED] — `updateApplicationStatus` re-creates a partial mirror + redundant placement read.**
- [x] **PERF-1 [MED] — teacher analytics N+1 `engagement_summary` reads + unbounded scans.**

### P3 — Low-severity hygiene

- [x] **BUG-7** — `= request.data || {}` in `ai/deepAnalysis.js`.
- [x] **BUG-8** — `LoadDedupe.begin` chained `catchError`.
- [x] **BUG-9** — profile-sync guard is an identity check.
- [x] **BUG-10** — delete the dead `EngagementProvider.trackActivity`.
- [x] **INT-1** — placement snapshots reachable via `storage.rules`.
- [x] **Chat delete** — `chats/*/messages/*` update/delete bound to `senderId`.
- [x] **`resumeReviews` tamper** — server-writable only (`persistResumeReview`).
- [x] **TEST-1** — added four `node --test` suites.

### Validation for this section

- [x] `flutter analyze` clean — **No issues found!**
- [x] `flutter test` green — **All tests passed! (422)**
- [x] `node --check` on every changed Functions file — all pass
- [x] `node --test` green (functions) — **38 pass**
- [x] Firestore rules + indexes + Storage rules updated to match the code

## 1. Startup Performance — P1 — DONE

- [x] Defer non-critical work until after first frame (lazy `MainNavigationView` tabs)
- [x] Lazy-build dashboard tabs
- [x] Keep Firebase + App Check init before `runApp()`
- [x] Remove duplicate initialisation
- [x] Idempotent analytics load (provider)
- [x] Document before/after startup sequence — `docs/v9_2_audit_report.md` §2

## 2. Teacher Analytics Duplicate Loading — P1 — DONE

- [x] Add re-entrancy guard to `loadAnalytics()`
- [x] Stop `IndexedStack` tabs from both triggering the initial load
- [x] Ensure empty-result retry cannot create concurrent duplicate loads
- [x] Preserve pull-to-refresh
- [x] Reset state correctly on logout / re-login

## 3. Teacher Analytics Firestore Cost — P1 — DONE

- [x] Deduplicate queries within one load lifecycle
- [x] Reuse already-loaded student data
- [x] Remove unnecessary repeated service calls
- [x] Preserve analytics correctness
- [x] Bound `collectionGroup('resumeReviews')` — verdict: kept exact (deduped to a single scan)
- [x] Removed the per-student N+1 reads (`pickLatestReviewPerUser`)
- [x] Wire `service.beginLoad()` into provider `_runLoad()`

## 4. Cloud Scheduler Consolidation — P1 — DONE

- [x] Create consolidated quota-sweep scheduler
- [x] Remove the 3 standalone `compensateStale*` onSchedule exports
- [x] Update `functions/index.js` exports
- [x] Preserve refund/compensation + no-double-charge semantics
- [x] Leave the other 4 scheduled jobs unchanged

## 5. Firestore Listener Lifecycle — P2 — DONE (runtime verify open)

- [x] Audit subscriptions
- [x] Cancel every subscription in `reset()` / `dispose()`
- [x] **OpportunityProvider** — retained subscriptions + `dispose()`
- [x] **AlumniDirectoryProvider** — retained subscription + `dispose()`
- [x] **PortfolioProvider** — added `dispose()`
- [x] Verified AuthGuard logout resets every listener-holding provider
- [ ] Runtime verify logout → login → re-login produces no `WatchStream ... NOT_FOUND`

## 6. AI Quota Architecture — Verify (no removal) — P2 — DONE

- [x] Verify reservations / pendingRequestId / pendingSince / rollback
- [x] Verify stale compensation still works with consolidated scheduler
- [x] Keep legacy mirrors for compatibility

## 7. Recommendation Engine — Preserve — P2 — DONE

- [x] Verify no duplicate refreshes introduced by optimization changes
- [x] Verify Dashboard / Career Coach / Teacher stay consistent

## 8. Legacy Cleanup — P3 — DONE

- [x] Verified `lib/views/archived/notes_view_legacy.dart` removed
- [x] Keep `ai_conversations` (classified **DEPRECATE**)

## 9. Tests — P2 — DONE

- [x] Functions tests: quota sweep — `quota.test.js` (11) + `schedulers.test.js` (2)
- [x] Functions tests (audit §0 TEST-1): 38 pass total
- [x] Flutter tests: analytics duplicate-load guard — `teacher_analytics_load_dedupe_test.dart` (9)
- [x] Flutter tests: latest-review-per-student derivation — `teacher_analytics_latest_review_test.dart` (9)
- [ ] Listener lifecycle test where testable
- [x] Do not delete existing tests (none removed)

## 10. Logging — P3 — DONE

- [x] Keep useful diagnostics
- [x] Remove repeated noisy logs
- [x] Never log secrets/tokens/keys

## 11. Validation — Required — DONE

- [x] `flutter analyze` passes — **No issues found!**
- [x] `flutter test` passes — **All tests passed! (422 tests)**
- [x] `node --check` passes for every changed Functions file
- [x] Functions tests pass (`node --test` → 38 pass)
- [~] `flutter build apk --release` — **deferred** (user: "don't build it, we are just optimizing it")

## 12. Documentation — Required — DONE

- [x] Record startup init changes — audit report §2
- [x] Record analytics loading changes — audit report §3
- [x] Record scheduler consolidation — audit report §4
- [x] Record listener lifecycle changes — audit report §6
- [x] Record test coverage — audit report §11

## 13. Analyzer / Lint Cleanup — P3 — DONE

- [x] Fix 8 `withOpacity` → `withValues(alpha:)` deprecations
- [x] Fix 12 `DropdownButtonFormField(value:)` → `initialValue:` deprecations
- [x] Fix 12 `use_build_context_synchronously` sites

## 14. Deployment — Required

- [ ] Redeploy Cloud Functions — `firebase deploy --only functions`
- [ ] Rebuild + release the Flutter app (APK/App Bundle)
- [x] Firestore rules — **no change**
- [x] Firestore indexes — **no change**
- [x] Storage rules — **no change**
- [ ] App Check enforcement — Console-side toggle only (no file change)

## 15. Explicitly Out of Scope

- [ ] v9.3 UI/UX redesign — **NOT STARTED** (must remain untouched)
- [ ] New product features — **NOT REQUIRED**

---
# v9.2.2 — Runtime Performance & Recommendation Refresh Optimization — COMPLETE

Baseline: `9.1.2+99` → released `9.2.2+100`.
Full write-up: `docs/v9_2_2_optimization_report.md` (fixes) + `docs/v9_2_2_investigation_report.md` (root causes).

## 1. Startup Performance — P0/P1 — DONE (instrumented, classified)

- [x] Profiled the cold-start window from `docs/logs.md`
- [x] Identified the contributors: Impeller/engine bring-up, `performTraversals()` JIT, Firebase/GMS/App Check native init
- [x] Inspected `main.dart`, Firebase init, App Check init, `AuthGuard`, `MultiProvider`, provider constructors, dashboards, prefs, fonts
- [x] Confirmed v9.2 deferred provider init + lazy tabs already removed the Dart-side first-frame work
- [x] Added lightweight startup instrumentation (phase marks + frame timings)
- [x] Did **not** add speculative Dart delays or "fixes" without evidence

## 2. Recommendation Refresh Deduplication — P1 — DONE

- [x] Traced every caller
- [x] Client in-flight sharing — `lib/utilities/refresh_dedupe.dart`
- [x] Client fingerprint skip — `recommendation_fingerprint.dart`
- [x] Server fingerprint gate stored on `recommendations_meta/summary` + `force` bypass
- [x] Regeneration preserved for: profile/portfolio/resume change, candidate change, expiry, explicit refresh, logout/login
- [x] Unified writer, eligibility/security logic, metadata, cache and document structure preserved
- [x] Refresh reason + skip/cache-hit diagnostics added (debug only)
- [x] Regression tests: `test/refresh_dedupe_test.dart` (16), `test/recommendation_fingerprint_test.dart` (13), `functions/test/recommendations_refresh_dedupe.test.js` (12)

## 3. Resume Review Provider Refresh Deduplication — P2 — DONE

- [x] Traced the init path (`initWithUser` → `_loadHistory`)
- [x] Confirmed the redundant caller
- [x] Guarded on `firstLoad && !_historyRefreshed && !historyInitialized && !isLoadingHistory`
- [x] Explicit refresh preserved
- [x] Failed/absent init still reads; a new review still appears

## 4. Portfolio Compatibility Cleanup — P2 — DONE

- [x] Inspected the schema + compatibility handling
- [x] Confirmed the canonical structure `users/{uid}.portfolio` with nested fields
- [x] Implemented a safe, controlled, idempotent migration
- [x] No valid portfolio information deleted
- [x] Backward compatible during migration
- [x] After migration, saves use the optimized nested/diff-write path
- [x] Regression tests: `test/portfolio_migration_test.dart` (14)

## 5. App Check Debug Configuration — P0 validation — DONE (diagnosis)

- [x] Verified the project
- [x] Confirmed the debug token is printed by the SDK, not app code; no token is committed
- [x] Confirmed debug/release provider selection is correct
- [x] Root cause: the emulator debug token is not allow-listed for the project
- [ ] **Console action (human):** register the debug token under App Check → Manage debug tokens
- [ ] Re-verify a debug session obtains a valid token with no repeated `403` / `Too many attempts`

## 6. Google Play Services / Emulator Diagnostics — P3 — DONE (classified)

- [x] Determined these originate from `com.google.android.gms`, not the app
- [x] Made **no** application change to suppress emulator noise
- [x] Documented them separately as environment-specific
- [x] Verified Firebase Auth + core Firebase ops still work in the same session

## 7. Teacher Analytics Regression Check — DONE

- [x] Confirmed one load per session
- [x] `LoadDedupe` cache + in-flight dedup still active
- [x] No new duplicate loads introduced by this pass
- [x] Existing suite still green

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

- [x] Instrumentation + measurement methodology documented
- [x] Deterministic before/after recorded
- [ ] On-device `flutter run --profile` Pixel 9 capture (human step — tooling is in place)

## 13. Constraints — honoured

- [x] No UI redesign · no new features · Firebase architecture retained · `Provider` retained
- [x] Recommendation engine retained; regeneration deduplicated, **not disabled**
- [x] App Check / security not weakened · lifecycle listeners retained · quotas unchanged
- [x] No API keys client-side · no speculative perf change without evidence

## 14. Documentation — DONE

- [x] `docs/v9_2_2_investigation_report.md` — problems + root causes
- [x] `docs/v9_2_2_optimization_report.md` — fixes, files changed, before/after, dedup behaviour, migration result, App Check result, emulator warnings, test results, remaining issues
