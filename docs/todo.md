# CampusConnect Todo List

> Source: `docs/Task.md` · Base: 8.8.0+91 · Current target: **v9.1 (Audit Fixes)**
> Historical versions 8.9.0–9.1.0 are summarized below (details in `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md`). Completed tasks have been removed from the tracker and consolidated into the audit report in `docs/confirmation.md` (v9.1 Final Comprehensive Audit Report, 2026-08-20).

---

## Deployment Log — 2026-08-29 (v9.1.1+98 backend)

Backend deployed to **campusconnect-firebase-project** (us-central1):

- [x] **Cloud Functions** — 22 functions deployed & live (Node.js 22, 2nd Gen), `functions/.env` loaded (`AI_PROVIDER=groq`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, model overrides, `AI_RETENTION_DAYS=90`):
  - Callables: `askAI`, `deleteAIHistory`, `generateCareerCoachAnalysis`, `generateResumeAnalysis`, `logPlacementApplication`, `logPlacementView`, `refreshRecommendations`, `reviewResume`, `updateApplicationStatus`
  - Scheduled: `autoExpireOpportunities`, `cleanupExpiredAIConversations`, `compensateStaleAIAnalysisQuota`, `compensateStaleCareerCoachQuota`, `compensateStaleResumeQuota`, `recomputeEngagementScores`, `sendInactivityReminders`
  - Triggers: `onChatMessageCreated`, `onMentorshipRequestCreated`, `onMentorshipRequestResponseNotifyStudent`, `onOpportunityPostedNotifyStudents`, `onProfileUpdatedRefreshAI`, `onResumeReviewCreatedRefreshMatches`
- [x] **Firestore rules** — `firestore.rules` compiled & released (includes v9.1 SEC-1/SEC-2/SEC-5 placement/application hardening + `user_ai_quotas`/`ai_analysis_usage` quota rules).
- [x] **Firestore indexes** — `firestore.indexes.json` deployed.
- [x] **Storage rules** — `storage.rules` compiled, already up to date.

Notes / follow-ups:
- CLI warned `firebase-functions` is outdated in `functions/package.json` (`^5.0.0`) — optional `npm install --save firebase-functions@latest`; breaking changes possible, so deferred.
- Deploy kept existing project indexes/field-overrides not present in the indexes file (`chats` composite index; field overrides for `applications.placementId`, `applications.userId`, `resumeReviews.createdAt`). Consider adding these to `firestore.indexes.json` for a deterministic deploy.
- **App Check (from debug log 2026-08-29, run 2):** ✅ progress — the `Firebase App Check API has not been used in project 955671967432 before or it is disabled` error is **GONE** (the `firebaseappcheck.googleapis.com` API is now enabled). The app logs in, loads resume reviews, regenerates recommendations and loads teacher analytics — all working.
  - **Remaining error:** `Error getting App Check token; using placeholder token instead. ... code: 403 body: App attestation failed.` → the **debug token presented this run (`91fc31d7-3e81-4bdd-af0a-68c8d4f17455`) is NOT registered** in the allowlist. The previously-registered token `37f1bcfd-660b-409c-876b-b263fe5ed85f` no longer matches — the debug token **rotated** (it is tied to the app build/install; a rebuild or reinstall can change it). App Check currently falls back to a placeholder token, so it only works because **enforcement is OFF**.
  - **Action:** under **Firebase Console → App Check → Apps → Manage debug tokens → Add debug token**, register the **current** token **`91fc31d7-3e81-4bdd-af0a-68c8d4f17455`** (and any other token that prints at startup — if you rebuild/reinstall, it may change again; register each new one). You can also delete the stale `37f1bcfd-…` after it's no longer used.
  - **Keep enforcement OFF** until the `Error getting App Check token` warnings no longer appear in the log. Then set **App Check → Apps → Manage enforcement → Enforce** (Android Play Integrity / iOS DeviceCheck / Web reCAPTCHA v3).
- **Web release build flag** — must be built with `--dart-define=WEB_RECAPTCHA_V3_SITE_KEY=<your reCAPTCHA v3 site key>`.
- Re-verify after the fix: relaunch the app and confirm the `Error getting App Check token` warnings are gone and the log prints `App Check` issuing a real token.

---

## History (complete)

### v8.9.0 — Role/placement/skill-gap engine + Teacher Profile ✅ deployed 2026-08-16
- Deterministic engine (`functions/recommendations/engine.js` + `career_roles.js`), role/placement/skill-gap/mentor/job recs, AI explanation enrichment via `callAIProvider`, teacher recommendation insights + teacher profile, security + 292 tests. Version `8.9.0+92`.

### v8.9.1 — Portfolio-first gate ✅ deployed
- All personalized recs gated behind `hasMeaningfulPortfolioContent`; intent-only students get only the "Complete your portfolio first" card. Version `8.9.1+93`.

### v8.9.2 — Wiped-doc self-heal ✅ client-only, no deploy
- `createProfile` merge-safe; `shouldTriggerPortfolioRestore` divergence flag + auto-restore; dashboard banner; 9 sync-state tests. Version `8.9.2+94`.

### v8.9.3 — Recommendations show nothing / gate disappears ✅ deployed
- Fixed nested `career.careerInterest` (R1a), token-overlap keyword match (R1b), experience/cert evidence pool (R1c), threshold 30→20 (R2), server candidate logging (R4), empty-state copy (R5), 120s client timeout (R6), nested career-map trigger (R7). 307/307 tests. Version `8.9.3+95`.

### v9.0 — AI Career Coach ✅ deployed 2026-08-18
- Routing fix, fake-66% removal, `functions/recommendations/career_coach.js`, callable + quota + cache (`functions/careerCoach.js`), Dart models/service/provider, dashboard + full view UI, navigation map, tests A–G. 347/347 tests. Version `9.0.0+96`.

### v9.0 — Audit Fixes (project_info__28.md) ✅ COMPLETE
- FIX-1..FIX-8: career_coach + career_coach_usage rules (owner read, write:false), `notifyListeners()` in provider reset, unknown-recommendation-type → null, dead `trackResumeUsage` removed, inline `HttpsError` fixed, `profileCompleted` gate, validation. `node --check` ✅.

### v9.0 — Confirmation Audit Fixes (docs/confirmation.md) ✅ COMPLETE
- Completed portions: BUG-1..3 (teacher dashboard CC reset, crash-safe `generateResumeAnalysis` reservation, flattened-portfolio auto-heal), ROUTE-1..3, ARCH-1..5, ROLE-1..6, SEC-1/2/4/5/6, RULES-1..6, FUNCS-1..3, EDGE-1..7, IMP-1..5/7/10/13/14.
- **Open (unmarked) items carried over to the v9.1 tracker below:** App Check (SEC-3/IMP-6), pagination (IMP-8), engagement aggregates (IMP-9), `ai_conversations` deprecation (IMP-11), AI prompt sanitization (IMP-12), unified AI quota (IMP-15), CC Firestore index (IMP-16). See "Open Improvements (carried-over)" below.

### v9.1 — Teacher Applicant Review ✅ implemented as `9.1.0+97` (audit fixes in progress)
- Version shipped `9.1.0+97`; the phase checklist below was left `- [ ]` (INT-5 drift). The 2026-08-20 audit (`project_info__30.md`/`project_info__31.md` → `docs/confirmation.md`) found 3 HIGH security holes + 2 HIGH robustness bugs. Phases stay open until the audit fixes land (same v9.1 version line, bump `9.1.1+98`).

---

## v9.1 — Teacher Applicant Review (from project_info__29.md) — ✅ DEPLOYED

> Source: `project_info__29.md` — Placement Applications Gap. Students could apply (resume snapshot → two Firestore locations via `logPlacementApplication`), but teachers saw only pipeline *counts* with zero drill-down into *who* applied, *what* resume they submitted, or *what to do next*. Status writes were impossible client-side (`update: false` on both application paths). This build adds: a new `updateApplicationStatus` Cloud Function, `getApplicationsForPlacement` (collectionGroup + dedupe), "View Applicants" teacher UI on placement cards, real shortlisted/interviewed/placed pipeline stages, and a student status-change notification. Shipped `9.1.0+97`.

### Phase Checklist (feature build — complete)
- [x] **Phase 1 — Cloud Function**: `updateApplicationStatus` in `functions/placements.js` — teacher/alumni-only `onCall`, validates `status ∈ {shortlisted, interviewed, placed, rejected}`, transactional dual-mirror update (canonical `applications/{uid}_{placementId}` + mirror `placements/{placementId}/applications/{uid}`), student notification (`statusChange` shape) + analytics. Re-exported in `index.js`.
- [x] **Phase 2 — Service**: `PlacementsService.getApplicationsForPlacement` (collectionGroup `applications` filtered by `placementId`, deduped by `userId`, prefers the doc that carries `resumeUrl` — mirror docs use `resume`) + `getApplicantCounts` (unique students per placement).
- [x] **Phase 3 — Provider**: `PlacementsProvider` — applicant-counts state + `loadApplicantCounts`, `getApplicationsForPlacement`, `updateApplicationStatus` callable wrapper (30s timeout, friendly errors).
- [x] **Phase 4 — View**: `PlacementApplicantsView` — applicant list joined against `users/{uid}` (name/dept), applied date, ATS score at application, resume version, View Resume (`resumeUrl` or `ResumeService` fallback), View Portfolio (`portfolioReadOnlyRoute`), status actions (Shortlist/Interview/Place/Reject with confirm). New route `placementApplicantsRoute` registered in `main.dart`.
- [x] **Phase 5 — Cards**: teacher/alumni placement cards show applicant count + "View Applicants" action; `PlacementsListView` is a StatefulWidget for one-time count load.
- [x] **Phase 6 — Pipeline**: `TeacherAnalyticsService.getApplicationPipelineCounts` buckets statuses into per-stage distinct-student counts; `PlacementPipelineData.isStageTracked` → true for all stages; dashboard widget shows real shortlisted/interviewed/placed values.
- [x] **Phase 7 — Rules**: alumni read access added to the `applications` collectionGroup rule (alumni manage placements; application docs are placement-scoped).
- [x] **Phase 8 — Tests**: `application_pipeline_test.dart` (counts dedupe) + `application_applicants_test.dart` (applicant dedupe prefers `resumeUrl`) mirroring service logic. Full suite green.
- [x] **Phase 9 — Validate**: `node --check` ✅ (functions), `flutter analyze` ✅, `flutter test` ✅ — no regressions.
- [x] Version bump `pubspec.yaml` → `9.1.0+97`

---

## v9.1 — Audit Fixes (from project_info__30.md / project_info__31.md) — ✅ COMPLETE (9.1.1+98)

> Source: `docs/confirmation.md` — V9.1 Final Comprehensive Audit Report (2026-08-20).
> **3 HIGH security** (SEC-1..SEC-4) · **2 HIGH/robustness bugs** (BUG-A) · **3 MEDIUM** (BUG-B, BUG-D, INT-1) · **5 LOW** (SEC-6, BUG-E/F/G/H) · **1 MEDIUM** (SEC-5) · carried-over open improvements (App Check, IMP-8/9/11/12/15/16).
> V9.1 as shipped (`9.1.0+97`) is **NOT production-safe** until SEC-1/SEC-2 (rules) and SEC-3/SEC-4 (functions) are fixed.
>
> **Progress (2026-08-20):** Phases 1–3 complete — all 4 HIGH security holes (SEC-1..SEC-4), the HIGH robustness bug (BUG-A), BUG-E, and SEC-5 are fixed on disk. Remaining: Phase 4 (UI/Integration: BUG-D, BUG-F, BUG-G, SEC-6, INT-1), Phase 5 (tests), Phase 6 (validate), version bump to `9.1.1+98`. See `docs/confirmation.md` §12 "Resolution Status" for item-by-item details.

### Phase Checklist
- [x] **Phase 1 — Rules (SEC-1, SEC-2, SEC-5)**: `firestore.rules` — placements `create/update/delete` require `createdBy == request.auth.uid` + schema validation helper (`isValidPlacementData`: deadline is Timestamp, required fields non-empty); application `create: if false` locked on BOTH canonical `applications/{applicationId}` and mirror `placements/{placementId}/applications/{appUserId}` paths (closes self-promotion + phishing-resume chain — `logPlacementApplication` Admin SDK bypasses rules so clients never need direct create); collectionGroup owner rule now `resource.data.userId == request.auth.uid` instead of `isOwner(appId)`.
- [x] **Phase 2 — Functions (SEC-3, SEC-4, BUG-A, BUG-E)**: `functions/placements.js` — `updateApplicationStatus`: actor-must-author placement (`placements/{id}.createdBy == uid`), server-side transition state machine (`STATUS_TRANSITIONS`: applied→[shortlisted,rejected], shortlisted→[interviewed,rejected], interviewed→[placed,rejected], terminal states []), mirror-missing guard inside transaction (get → `set` fallback so canonical update doesn't roll back), per-actor rate limit (`_checkStatusRateLimit`, career-coach pattern); `logPlacementApplication`: placement doc read in-transaction, rejects missing/inactive/past-deadline (`not-found`/`failed-precondition`), `request.data` null-guarded. Re-exported in `index.js`.
- [x] **Phase 3 — Models (BUG-B, BUG-H)**: `lib/models/application.dart` — `userId: data['userId'] as String? ?? data['studentId'] as String? ?? ''` (no hard cast crash on legacy mirror docs); stale status doc comment fixed (`applied | shortlisted | interviewed | placed | rejected`). `lib/models/placement.dart` — `Placement.fromFirestore` tolerant of malformed `deadline`/`postedAt` (Timestamp check with sane fallbacks; defense in depth vs SEC-1 DoS).
- [x] **Phase 4 — UI / Integration (BUG-D, BUG-F, BUG-G, SEC-6, INT-1)**: `lib/views/dashboards/widgets/teacher_dashboard_sections.dart` — `QuickStatistics`/`DepartmentOverview` use real `analytics.pipelinePlaced` for placement rate instead of activeDrives÷students; `placement_applicants_view.dart` — refresh applicant counts after successful status update, show "text resume" state instead of dead Resume button; `main.dart` — role-gate `placementApplicantsRoute` (`_guardPlacementApplicants` → `_PlacementApplicantsDeniedView`, `_guardStudentPortfolio`/`_guardAlumniGroupChat` pattern); `AlumniDashboardView` — add "Placements" quick action to `placementsListRoute`, actions row converted to a `LayoutBuilder`+`Wrap` (4-per-row) so 5 items flow without overflow.
- [x] **Phase 5 — Tests**: two new files (`placement_application_guards_test.dart`, `placement_models_tolerant_parse_test.dart`) — status transition validation, actor-must-author, mirror-missing guard, placement-existence validation, tolerant `Application.fromFirestore`, `Placement.fromFirestore` malformed-data handling, `isTextResume` detection, BUG-D rate formula. **Bonus fix surfaced by tests:** `Placement.fromFirestore` hard cast on a non-map `requirements` field crashed every placements-list render — now guarded (degrades to open-to-all default). Full suite green: **404/404**.
- [x] **Phase 6 — Validate**: `node --check` ✅ (functions), `flutter analyze` ✅ (only pre-existing infos — the one new `unused_local_variable` warning from BUG-D was fixed), `flutter test` ✅ 404/404 — no regressions.
- [x] Version bump `pubspec.yaml` → `9.1.1+98`

---

## Open Improvements (carried-over, unmarked from previous audits) — IN PROGRESS

> These were the only unmarked items remaining in the v9.0 confirmation audit section. Combined into `docs/confirmation.md` §8 and tracked here. Not part of the v9.1 audit-fix phase checklist above. Implementation begun 2026-08-29 (see `docs/think.md`; tracked against `docs/Task.md` §8–§12, §16).

- [x] **IMP-15 [ENHANCEMENT]:** Unified AI Quota Management — consolidate 4 separate quota systems (`ai_usage`, `resume_usage`, `career_coach_usage`, `users/{uid}.aiUsageCount`) into a single `user_ai_quotas/{uid}` document with nested maps. Simplifies monitoring and new feature additions.
  - [x] `functions/ai/quota.js` — unified quota module (`getFeatureUsage`, `consumeFeatureQuota`, `clearFeatureReservation`, `rollbackFeatureQuota`, `incrementDailyUsage`, `runFeatureSweep`). Backward-compatible dual-write (unified + legacy mirror), lazy migration from legacy on first read, month/day reset, crash-safe reservation, atomic refund. `node --check` ✅.
  - [x] `functions/ai/deepAnalysis.js` — `consumeAIAnalysisQuota`/`clearAIAnalysisReservation`/`rollbackAIAnalysisUsage` now delegate to `quota`; `compensateStaleAIAnalysisQuota` sweep uses `quota.runFeatureSweep("aiAnalysis", ...)`. `node --check` ✅.
  - [x] `functions/careerCoach.js` — `getCareerCoachUsage`/`consumeCareerCoachQuota`/`clearCareerCoachReservation`/`rollbackCareerCoachUsage` now delegate to `quota`; `compensateStaleCareerCoachQuota` sweep uses `quota.runFeatureSweep("careerCoach", ...)`. `node --check` ✅.
  - [x] `functions/ai/chat.js` — `trackUsage` → `quota.incrementDailyUsage(userId, "chat")`. `node --check` ✅.
  - [x] `functions/ai/resumeReview.js` — `compensateStaleResumeQuota` sweep → `quota.runFeatureSweep("resumeReview", ...)` (refunds BOTH the unified mirror AND the legacy doc atomically). `node --check` ✅.
  - [x] `firestore.rules` — `user_ai_quotas/{uid}` + `ai_analysis_usage/{uid}` owner-read / `write:false` rules added (Cloud Functions managed).

- [x] **IMP-6 / SEC-3 [MEDIUM]:** Add App Check — Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web). Reduces the "modified client writes directly to Firestore" attack class.
  - [x] `pubspec.yaml` — added `firebase_app_check: ^0.4.1+3`.
  - [x] `lib/main.dart` — `_activateAppCheck()` called after `Firebase.initializeApp`; debug/profile use `AndroidDebugProvider`/`AppleDebugProvider`/`WebProvider.debug`; release uses `AndroidPlayIntegrityProvider`/`AppleDeviceCheckProvider` and reCAPTCHA v3 (site key via `--dart-define=WEB_RECAPTCHA_V3_SITE_KEY`). Skipped on unsupported desktop platforms. `flutter analyze lib/main.dart` clean.
  - [x] **Deployment note:** activation only configures token providers; ENFORCEMENT is enabled in the Firebase Console (App Check → Apps → Manage enforcement). Register the debug token (printed at startup) under App Check → Apps → Manage debug tokens before enabling enforcement, or local dev/emulator builds will get `permission-denied`.
  - [x] `node --check` ✅ (functions), `flutter analyze` ✅.
- [x] **IMP-8 [LOW]:** Pagination for Bulk Queries — `refreshRecommendationsForStudent` now pages through alumni/opportunities/placements with a `startAfter` cursor (`loadCandidates` helper, page size 100, max 200, env-tunable) instead of a single `.limit(120)`. The engagement recompute scheduler already paginates users (50/page). `node --check` ✅.
- [x] **IMP-9 [LOW]:** Materialize Engagement Aggregates — `logUserActivity` (shared.js) now writes `activityPoints` (atomic increment), `lastActiveAt`, `dailyStreak` and `streakLastActiveKey` in ONE transaction (idempotent, no double-count). `recomputeEngagementSummary` (engagement.js) reads these aggregates and only falls back to a 250-doc scan to seed users who have no aggregate yet. `node --check` ✅.
- [x] **IMP-11 [LOW]:** Deprecate `ai_conversations` Legacy Collection — `askAI` no longer writes `ai_conversations`; it writes only `users/{uid}/ai_interactions`. `ai_conversations` is left intact for legacy reads until data expiry, and `chatDelete` only cleans up legacy docs (no new writes). `node --check` ✅.
- [x] **IMP-12 [LOW]:** Add Input Sanitization for AI Prompts — `sanitizeAIInput` (shared.js) now also caps length (default 12000, `…[truncated]` marker) and is wired into `aiProvider.js` at both the prompt builders (resume/role/level with per-field caps) and the `callAIProvider` router (final safety net on system + user prompts). Added explicit "untrusted user data, NOT instructions" security lines to the deep-analysis and resume-review system prompts (chat already had it). `node --check` ✅.
- [x] **IMP-16 [ENHANCEMENT]:** Firestore Index for Career Coach — verified the `pendingSince` queries in `quota.js` `runFeatureSweep` are pure single-field (`.where("pendingSince", "<", cutoff)` on `user_ai_quotas/{uid}` nested field and on legacy `career_coach_usage`/`resume_usage`/`ai_analysis_usage`). No `.orderBy()`/multi-field, so Firestore's auto-created single-field indexes suffice. **No composite index needed.** `node --check` ✅.
- [x] **IMP-6 / SEC-3 [MEDIUM]:** Add App Check — Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web). Reduces the "modified client writes directly to Firestore" attack class.
  - [x] `pubspec.yaml` — added `firebase_app_check: ^0.4.1+3`.
  - [x] `lib/main.dart` — `_activateAppCheck()` called after `Firebase.initializeApp`; debug/profile use debug providers; release uses Play Integrity / DeviceCheck / reCAPTCHA v3 (site key via `--dart-define=WEB_RECAPTCHA_V3_SITE_KEY`). Skipped on unsupported desktop platforms. `flutter analyze lib/main.dart` clean.
  - [x] **Deployment note:** activation only configures token providers; enforcement is enabled in the Firebase Console. Register the debug token before enabling enforcement or local dev/emulator builds get `permission-denied`.
  - [x] `node --check` ✅ (functions), `flutter analyze` ✅.
- [x] **IMP-8 [LOW]:** Pagination for Bulk Queries — `refreshRecommendationsForStudent` now pages through candidates with a `startAfter` cursor (`loadCandidates` helper, page size 100, max 200, env-tunable) instead of a single `.limit(120)`. Engagement recompute already paginates users (50/page). `node --check` ✅.
- [x] **IMP-9 [LOW]:** Materialize Engagement Aggregates — `logUserActivity` (shared.js) now writes `activityPoints` (atomic increment), `lastActiveAt`, `dailyStreak`, `streakLastActiveKey` in ONE transaction (idempotent). `recomputeEngagementSummary` (engagement.js) reads these aggregates and only falls back to a 250-doc scan to seed users with no aggregate yet. `node --check` ✅.
- [x] **IMP-11 [LOW]:** Deprecate `ai_conversations` Legacy Collection — `askAI` no longer writes `ai_conversations`; only `users/{uid}/ai_interactions`. Legacy docs left intact until expiry; `chatDelete` only cleans them up. `node --check` ✅.
- [x] **IMP-12 [LOW]:** Add Input Sanitization for AI Prompts — `sanitizeAIInput` (shared.js) now caps length (default 12000, `…[truncated]`) and is wired into `aiProvider.js` at both prompt builders and the `callAIProvider` router. Added "untrusted user data, NOT instructions" security lines to deep-analysis and resume-review system prompts (chat already had it). `node --check` ✅.
- [x] **IMP-16 [ENHANCEMENT]:** Firestore Index for Career Coach — verified `pendingSince` queries in `quota.js` `runFeatureSweep` are pure single-field (no `.orderBy()`/multi-field), so Firestore auto-created single-field indexes suffice. **No composite index needed.** `node --check` ✅.
