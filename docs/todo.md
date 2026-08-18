# CampusConnect Todo List

> Source: `docs/Task.md` · Base: 8.8.0+91 · Current target: **v9.0 (AI Career Coach)**
> Historical versions 8.9.0–8.9.3 are summarized below (details in `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md`).

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

---

## v9.0 — AI Career Coach (replaces static skill-gap engine) — ✅ COMPLETE

> Spec: `docs/Task.md` (AI-first career reasoning; deterministic code only for facts/validation/caching/quota/navigation). Validated structured JSON from **Groq → HuggingFace** (`callAIProvider`). Cached analysis, fingerprint-based staleness, monthly quota (Resume Review pattern). Dashboard shows top 2–3 coach recs + "View all →"; full analysis on `/career-coach`. Fake 66% scores and "Learn X" cards removed. Routing bug fixed (no `profileSetupRoute` from cards).

### Phase Checklist
- [x] **docs**: condensed `docs/todo.md` (this file) + spec in `docs/Task.md` (done above)
- [x] **Phase 1 — Routing fix**: `skill`/`role` cards → `editProfileRoute` (never `profileSetupRoute`); add `careerCoachRoute`
- [x] **Phase 2 — Remove fake 66%**: engine stops emitting `skill_*` rows (`buildSkillGapRecommendations` removed from composition)
- [x] **Phase 3 — Backend module**: `functions/recommendations/career_coach.js` — privacy-minimized input builder, stable fingerprint, 14-rule prompt, strict-JSON validator, supported types/priorities, analysis version + `generateCareerCoaching` AI wrapper (callAIProvider → validate)
- [x] **Phase 4 — Callable + quota + cache**: dedicated `functions/careerCoach.js` (registered via side-effect require from `index.js` to keep it lean) — server reads `users/{uid}`, computes fingerprint, serves cached when fresh, transactional quota consume/reserve/rollback (Resume Review pattern), `compensateStaleCareerCoachQuota` daily sweep, stores `users/{uid}/career_coach/summary`. `node --check` ✅
- [x] **Phase 5 — Dart models**: `career_coach_analysis.dart` (analysis, recommendation, usage) — tolerant parse, safe fallback
- [x] **Phase 6 — Service + provider**: `career_coach_service.dart` (callable + stream + fetchSummaryOnce), `career_coach_provider.dart` (cached analysis, re-analyze, usage, refresh-never-calls-AI)
- [x] **Phase 7 — UI**: `career_coach_section.dart` (dashboard top 2–3 + view-all), `career_coach_view.dart` (full analysis, re-analyze, usage); wired into dashboard + `main.dart` (provider, route, AuthGuard init, logout reset)
- [x] **Phase 8 — Navigation map**: `career_coach_navigation.dart` (rec type → destination: portfolio/resume/projects/certs/experience/achievements/edit-profile/AI chat/opportunities)
- [x] **Phase 9 — Tests A–G**: `test/career_coach_validation_test.dart` (validator + input normalization + no-personal-data + sparse-profile); update `test/skill_gap_recommendation_test.dart` → no-skill-row contract. Fixed unknown-type test to match FIX-4 behavior (excluded, not profile fallback). 347/347 tests pass.
- [x] **Phase 10 — Validate**: `node --check` ✅ (all function files), `flutter analyze` ✅ (0 errors, 76 pre-existing info lints), `flutter test` ✅ (347/347 passed)
- [x] Version bump `pubspec.yaml` → `9.0.0+96`

---

## v9.0 — Audit Fixes (from project_info__28.md) — ✅ COMPLETE

> Source: `project_info__28.md` — Final Audit Report (2026-08-18). **2 HIGH, 4 MEDIUM, 5 LOW findings** + dead code + improvement suggestions.

### Fix Checklist

- [x] **FIX-1 (HIGH-1):** Add explicit Firestore security rule for `career_coach_usage/{userId}` — owner read, write:false
- [x] **FIX-2 (MEDIUM-1):** Add explicit Firestore security rule for `career_coach` subcollection — owner read, write:false (prevent client bypassing AI + quota system)
- [x] **FIX-3 (MEDIUM-2):** Add `notifyListeners()` to `CareerCoachProvider.reset()` so UI rebuilds on logout
- [x] **FIX-4 (MEDIUM-4):** Return `null` for unknown recommendation types in `CareerCoachRecommendation.fromJson` instead of silent fallback to `profile`
- [x] **FIX-5 (O1):** Remove dead `trackResumeUsage` function from `functions/index.js` (replaced by `consumeResumeQuota`)
- [x] **FIX-6 (O3):** Fix inline `require("firebase-functions/v2/https").HttpsError` in `generateResumeAnalysis` — use the already-imported `admin.functions.https.HttpsError`
- [x] **FIX-7 (IMP-4):** Add `profileCompleted` gate to `generateCareerCoachAnalysis` callable — reject students without a completed profile
- [x] **FIX-8:** Verify all fixes — `node --check` passed ✅ (functions), `flutter analyze` deferred to Phase 10

---

## v9.0 — Confirmation Audit Fixes (from docs/confirmation.md) — ✅ COMPLETE

> Source: `docs/confirmation.md` — Final Comprehensive Audit Report (2026-08-18).
> **3 bugs** (1 HIGH, 2 MEDIUM) · **4 security findings** (1 HIGH, 2 MEDIUM, 1 LOW) · **5 architecture concerns** · **6 role notes** · **3 routing items** · **7 edge cases** · **6 rules/functions items** · **16 improvements**.

---

### 2. Bugs & Logical Errors

- [x] **BUG-1 [HIGH]:** Add `CareerCoachProvider.reset()` to teacher dashboard `_resetProviders()` in `lib/views/dashboards/teacher_dashboard_view.dart` — state leak between user sessions
- [x] **BUG-2 [MEDIUM]:** Apply crash-safe quota reservation pattern to `generateResumeAnalysis` in `functions/index.js` — add `pendingRequestId`/`pendingSince` + rollback + daily compensation sweep to prevent permanent credit loss on crash. Fixed stale `aiUsageCount` variable reference → `usageData.monthlyCount`. `node --check` ✅
- [x] **BUG-3 [MEDIUM]:** Auto-heal flattened portfolio shape — `PortfolioService.hasFlattenedPortfolioShape()` detects flattened `portfolio.*` keys; `PortfolioProvider._forceFullSave` flag forces full (non-diff) write on next `savePortfolio` call, overwriting flat keys with canonical nested map

---

### 3. Routing Problems

- [x] **ROUTE-1 [RESOLVED]:** Recommendation cards routing fix — `skill`/`role` → `editProfileRoute`, `placement` → `placementsListRoute`, `portfolio` → `studentPortfolioRoute` (✅ FIXED in v9.0 Phase 1)
- [x] **ROUTE-2 [OK]:** Career Coach navigation completeness — all 10 `CareerCoachRecType` values map to valid routes (✅ Verified)
- [x] **ROUTE-3 [OK]:** Dynamic route handling in `onGenerateRoute` — `resumeReviewDetailRoute`, `chatRoute`/`chatDetailRoute`, `completeMentorshipRoute` all handle missing args with safe fallbacks (✅ Verified)

---

### 4. Architecture Issues & Stability

- [x] **ARCH-1 [OK]:** Single-writer contract intact — `refreshRecommendationsForStudent` is the ONLY writer to recommendations; `generateCareerCoachAnalysis` is the ONLY writer to career_coach/summary (✅ Verified)
- [x] **ARCH-2 [NOTE]:** `index.js` monolith (3000+ lines) — Extracted into modules: `helpers/shared.js` (sanitizeAIInput, logAnalyticsEvent, deleteDocsInBatches, maybeCreateNotification, logUserActivity, portfolio change detection), `helpers/engagement.js` (recomputeEngagementSummary, buildBadge, computeStreakFromActivities, computeProfileStrength), `ai/chat.js` (askAI + rate limiting + spam detection + usage + trial), `ai/resumeReview.js` (reviewResume + PDF extraction + crash-safe resume quota + compensation sweep), `ai/deepAnalysis.js` (generateResumeAnalysis + crash-safe AI analysis quota + compensation sweep), `ai/chatDelete.js` (deleteAIHistory + retention cleanup), `recommendations/refresh.js` (refreshRecommendations callable + refreshRecommendationsForStudent orchestrator), `placements.js` (logPlacementView + logPlacementApplication — both onCall), `triggers/index.js` (6 Firestore triggers), `schedulers/index.js` (3 scheduled functions). `index.js` is now a ~90-line thin entry point that requires + re-exports all Cloud Functions. `node --check` ✅ on all 12 modules.
- [x] **ARCH-3 [NOTE]:** Duplicate eligibility logic — created `docs/eligibility_rules.md` documenting the 5 shared rules (deadline, applied, CGPA, year, program/branch) with sync policy. Added ARCH-3 cross-reference comments to `EligibilityEngine` (client) and `checkMandatoryEligibility` (server) pointing to the shared doc.
- [x] **ARCH-4 [NOTE]:** Provider initialization ordering in AuthGuard — 15+ providers in two-phase `addPostFrameCallback`. Accepted: the two-phase approach is correct and documented. Any provider that throws could block subsequent ones, but this is an accepted risk.
- [x] **ARCH-5 [LOW]:** `JSON.stringify` for deep comparison in `isPortfolioMetadataOnlyChange`/`portfolioContentChanged` — order-sensitive and Timestamp-unsafe in theory. Accepted: consistent in practice since both `before`/`after` come from the same Firestore event.

---

### 5. Role-Based Access Problems

- [x] **ROLE-1 [OK]:** Role immutability enforcement — `canWriteRole()` rule prevents role self-elevation (✅ Verified)
- [x] **ROLE-2 [OK]:** Alumni portfolio guard — `_guardStudentPortfolio()` blocks Alumni from editing; read-only view still works (✅ Verified)
- [x] **ROLE-3 [OK]:** Alumni group chat guard — `_guardAlumniGroupChat()` blocks non-Alumni; Firestore rules enforce `userRole() == 'alumni'` (✅ Verified)
- [x] **ROLE-4 [OK]:** Teacher profile isolation — `_RoleAwareProfileView` routes Teachers to `TeacherProfileView` (✅ Verified)
- [x] **ROLE-5 [NOTE]:** Teachers can read ALL user documents — `allow read: if isTeacher()` gives full access. Accepted for college setting; needs role-scoping if multi-tenant.
- [x] **ROLE-6 [NOTE]:** Alumni can read ALL student documents — accepted trade-off of nested-map design (documented as M2 privacy note).

---

### 6. Security Audit

- [x] **SEC-1 [HIGH]:** Migrate `logPlacementView` from `onRequest` (body-based identity) to `onCall` (auth context) in `functions/index.js` — identity now comes from `request.auth.uid`, body `userId` no longer trusted. `node --check` ✅
- [x] **SEC-2 [MEDIUM]:** Add per-minute rate limiting to `generateCareerCoachAnalysis` in `functions/careerCoach.js` — `checkCareerCoachRateLimit()` uses dedicated `career_coach_rate_limits` collection (60s window, max 1 call/min). Fail-open on errors.
- [ ] **SEC-3 [MEDIUM]:** No App Check — `No AppCheckProvider installed` warning. Enable Firebase App Check with Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web). **Improvement — track for future sprint.**
- [x] **SEC-4 [LOW]:** AI prompt injection surface — accepted risk. Mitigations present: input length limits (1000/5000 chars), response validation (strict JSON parsing), no API keys in prompts. The `normalizeChatText` strips markdown but doesn't filter injection patterns.
- [x] **SEC-5 [OK]:** Storage rules — owner-only writes, PDF-only + 5 MB limit, teacher/alumni read via role lookup (✅ Verified)
- [x] **SEC-6 [OK]:** Resume ownership check — `resumeTextFromStorage` validates `storagePath === 'resumes/${uid}/latest.pdf'` exactly (✅ Verified)

---

### 7. Firebase Rules & Functions Audit

- [x] **RULES-1 [OK]:** `career_coach` subcollection — owner read, write: false (✅ Verified)
- [x] **RULES-2 [OK]:** `career_coach_usage` collection — owner read, write: false (✅ Verified)
- [x] **RULES-3 [OK]:** Catch-all under users `{subcollection=**}` — owner read/write. More specific rules (recommendations, engagement_summary, career_coach, etc.) take precedence. **Note:** Consider inverting to deny-by-default for future subcollections.
- [x] **RULES-4 [OK]:** Activities rule — restricts client writes to `eventType == 'resumeReviewed' && points == 5` only (✅ Verified)
- [x] **RULES-5 [OK]:** Chat rules — limits updates to `lastMessage`, `lastMessageSenderId`, `lastMessageAt`, `unreadCount` only (✅ Verified)
- [x] **RULES-6 [NOTE]:** `ai_conversations` legacy collection — still in use by `askAI` + `deleteAIHistory` + `cleanupExpiredAIConversations`. Technical debt — could be migrated to `users/{uid}/ai_interactions`. **Improvement — IMP-11.**
- [x] **FUNCS-1 [OK]:** Scheduled functions — all 6 schedules verified (recomputeEngagementScores, cleanupExpiredAIConversations, compensateStaleResumeQuota, compensateStaleCareerCoachQuota, autoExpireOpportunities, sendInactivityReminders). No overlaps, correct regions/timezones.
- [x] **FUNCS-2 [OK]:** Firestore triggers — all 6 triggers verified with `maxInstances` limits and error handling. `onProfileUpdatedRefreshAI` correctly handles portfolio-metadata-only detection.
- [x] **FUNCS-3 [OK]:** Node.js runtime — `package.json` specifies Node 22, well within 2026-10-30 deadline.

---

### 8. Edge Cases & Boundary Problems

- [x] **EDGE-1 [NOTE]:** Empty Career Coach input — student with `profileCompleted: true` but zero portfolio content. AI receives minimal data, produces "complete your portfolio" recommendations. By design: prompt rule says "DO NOT invent experience/skills".
- [x] **EDGE-2 [NOTE]:** Career Coach cache invalidation on profile update — deterministic recommendations refresh immediately via trigger, but CC analysis stays stale until user navigates to Career Coach screen. By design: Task.md §8 says "Regenerate ONLY when meaningful career data changes OR student requests 'Re-analyze'".
- [x] **EDGE-3 [OK]:** Concurrent Career Coach requests — Firestore transaction ensures atomicity; only one of two simultaneous calls succeeds. (✅ Correct)
- [x] **EDGE-4 [NOTE]:** `pdf-parse` edge cases — 2017-era pdf.js. Unusual xref tables, encrypted PDFs, image-only PDFs, >5MB all handled with appropriate errors. Known limitation.
- [x] **EDGE-5 [OK]:** Portfolio provider divergence detection — `shouldTriggerPortfolioRestore` correctly distinguishes stale replay from genuine wipe. Pure top-level function, unit-testable. (✅ Correct)
- [x] **EDGE-6 [NOTE]:** Recommendation type deduplication — server and client both deduplicate by type (first wins), server caps at 5. By design per Task.md §4. Could lose nuanced advice if AI returns multiple of same type.
- [x] **EDGE-7 [LOW]:** `isPortfolioMetadataOnlyChange` false positive — `JSON.stringify` comparison could break if Timestamp format changes. Accepted: Firebase SDK consistently returns `Timestamp` objects.

---

### 9. Improvements & Recommendations

#### HIGH Priority (actionable fixes — same as bugs/security above)
- [x] **IMP-1 [HIGH]:** Fix Teacher Dashboard Logout Reset → **BUG-1** (done above)
- [x] **IMP-2 [HIGH]:** Migrate `logPlacementView` to Callable → **SEC-1** (done above)
- [x] **IMP-3 [HIGH]:** Apply Reservation Pattern to `generateResumeAnalysis` → **BUG-2** (done above)

#### MEDIUM Priority
- [x] **IMP-4 [MEDIUM]:** Add Per-Minute Rate Limiting to Career Coach → **SEC-2** (done above)
- [x] **IMP-5 [MEDIUM]:** Split `index.js` into Modules — extracted into `ai/chat.js`, `ai/resumeReview.js`, `ai/deepAnalysis.js`, `ai/chatDelete.js`, `placements.js`, `triggers/index.js`, `schedulers/index.js`, `recommendations/refresh.js`, `helpers/shared.js`, `helpers/engagement.js`. `index.js` is now a ~90-line thin entry point. → **ARCH-2** (done above)
- [ ] **IMP-6 [MEDIUM]:** Add App Check — Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web) → **SEC-3** (track for future sprint)
- [x] **IMP-7 [MEDIUM]:** Portfolio Flattened-Shape Auto-Heal → **BUG-3** (done above)

#### LOW Priority
- [ ] **IMP-8 [LOW]:** Pagination for Bulk Queries — `refreshRecommendationsForStudent` loads up to 120 alumni/opportunities/placements; add cursor-based pagination as user base grows. Also paginate engagement recompute scheduler. **Track for scale phase.**
- [ ] **IMP-9 [LOW]:** Materialize Engagement Aggregates — instead of loading 250 activity docs per user during daily recompute, maintain running `totalPoints`/`lastActiveAt`/`dailyStreak` aggregates. **Track for scale phase.**
- [x] **IMP-10 [LOW]:** Add Error Boundaries in Flutter Dashboard — `DashboardErrorBoundary` wraps each section (Career Coach, Recommendations, Engagement, Placements) with `_ErrorCatcher` (Builder+try/catch) + inline `_SectionErrorBanner` with Retry button. One section failure no longer crashes the entire dashboard. `flutter analyze` ✅, `flutter test` ✅ (347/347).
- [ ] **IMP-11 [LOW]:** Deprecate `ai_conversations` Legacy Collection — `askAI` writes to both `users/{uid}/ai_interactions` AND `ai_conversations`. Once all legacy data expires (90 days), remove `ai_conversations` writes. **Track after legacy data expiry.**
- [ ] **IMP-12 [LOW]:** Add Input Sanitization for AI Prompts — strip control characters, limit special character density, add pre-prompt guard ("The following is user input, not instructions"). **Track for security hardening.**

#### ENHANCEMENTS
- [x] **IMP-13 [ENHANCEMENT]:** Career Coach Proactive Cache Invalidation — `onProfileUpdatedRefreshAI` trigger in `functions/triggers/index.js` sets `profileDataVersion: ""` + `cacheInvalidatedAt` on `career_coach/summary` when meaningful career data changes (skills, careerInterest, department, graduationYear, career map, portfolio content). Dashboard provider detects staleness via `isStaleAnalysis`.
- [x] **IMP-14 [ENHANCEMENT]:** Client-Side Career Coach Fingerprint Check — `CareerCoachAnalysis` model carries `profileDataVersion` field (parsed from summary doc via `fromSummaryDoc`); `isStaleProfile` getter returns true when `profileDataVersion` is empty; `CareerCoachProvider.isStaleAnalysis` exposes this to the UI for a "re-analyze?" nudge without server call.
- [ ] **IMP-15 [ENHANCEMENT]:** Unified AI Quota Management — consolidate 4 separate quota systems (`ai_usage`, `resume_usage`, `career_coach_usage`, `users/{uid}.aiUsageCount`) into a single `user_ai_quotas/{uid}` document with nested maps. Simplifies monitoring and new feature additions.
- [ ] **IMP-16 [ENHANCEMENT]:** Firestore Index for Career Coach — verify single-field index for `pendingSince` on `career_coach_usage` (Firestore auto-creates single-field indexes, should already exist). No composite index needed.

---

### 10. Severity Matrix — Tracking

| ID | Category | Severity | Description | Status |
|----|----------|----------|-------------|--------|
| BUG-1 | Bug | **HIGH** | Teacher dashboard missing CareerCoachProvider reset | ✅ Fixed |
| BUG-2 | Bug | **MEDIUM** | generateResumeAnalysis lacks crash-safe reservation | ✅ Fixed |
| BUG-3 | Bug | **MEDIUM** | Flattened portfolio shape self-heal gap | ✅ Fixed |
| SEC-1 | Security | **HIGH** | logPlacementView uses body-based identity | ✅ Fixed |
| SEC-2 | Security | **MEDIUM** | No per-minute rate limiting on Career Coach | ✅ Fixed |
| SEC-3 | Security | **MEDIUM** | No App Check | 📋 Documented |
| SEC-4 | Security | LOW | AI prompt injection surface | ✅ Accepted risk |
| ARCH-1 | Architecture | OK | Single-writer contract intact | ✅ Verified |
| ARCH-2 | Architecture | NOTE | index.js monolith (3000+ lines) | ✅ Extracted into 10 modules |
| ARCH-3 | Architecture | NOTE | Duplicate eligibility logic | ✅ Shared doc + cross-refs |
| ARCH-4 | Architecture | NOTE | 15+ provider init in AuthGuard | ✅ Accepted |
| ARCH-5 | Architecture | LOW | JSON.stringify comparison fragility | ✅ Accepted |
| ROLE-1 | Roles | OK | Role immutability enforced | ✅ Verified |
| ROLE-2 | Roles | OK | Alumni portfolio guard | ✅ Verified |
| ROLE-3 | Roles | OK | Alumni group chat guard | ✅ Verified |
| ROLE-4 | Roles | OK | Teacher profile isolation | ✅ Verified |
| ROLE-5 | Roles | NOTE | Teachers read all user docs | ✅ Accepted |
| ROLE-6 | Roles | NOTE | Alumni read all student docs | ✅ Accepted |
| ROUTE-1 | Routing | OK | Recommendation routing fixed | ✅ Verified |
| ROUTE-2 | Routing | OK | Career Coach navigation complete | ✅ Verified |
| ROUTE-3 | Routing | OK | Dynamic route handling | ✅ Verified |
| EDGE-1 | Edge case | NOTE | Empty career coach input | ✅ By design |
| EDGE-2 | Edge case | NOTE | Stale CC cache after profile update | ✅ By design |
| EDGE-3 | Edge case | OK | Concurrent CC requests handled | ✅ Correct |
| EDGE-4 | Edge case | NOTE | pdf-parse edge cases | ✅ Known limitation |
| EDGE-5 | Edge case | OK | Portfolio divergence detection | ✅ Correct |
| EDGE-6 | Edge case | NOTE | Recommendation type deduplication | ✅ By design |
| EDGE-7 | Edge case | LOW | isPortfolioMetadataOnlyChange fragility | ✅ Accepted |
| RULES-1 | Rules | OK | career_coach subcollection | ✅ Verified |
| RULES-2 | Rules | OK | career_coach_usage collection | ✅ Verified |
| RULES-3 | Rules | OK | Catch-all under users | ✅ Verified |
| RULES-4 | Rules | OK | Activities rule | ✅ Verified |
| RULES-5 | Rules | OK | Chat rules | ✅ Verified |
| RULES-6 | Rules | NOTE | ai_conversations legacy | 📋 IMP-11 |
| FUNCS-1 | Functions | OK | Scheduled functions | ✅ Verified |
| FUNCS-2 | Functions | OK | Firestore triggers | ✅ Verified |
| FUNCS-3 | Functions | OK | Node.js runtime | ✅ Verified |
| SEC-5 | Security | OK | Storage rules | ✅ Verified |
| SEC-6 | Security | OK | Resume ownership check | ✅ Verified |
