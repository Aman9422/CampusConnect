# CampusConnect v9.0 — Final Comprehensive Audit Report

**Date:** 2026-08-18
**Version audited:** 8.9.3+95 (Flutter) + v9.0 Career Coach (Cloud Functions)
**Scope:** Full application — bugs, logic errors, routing, architecture, roles, security, edge cases, Firebase rules/functions, improvements

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Bugs & Logical Errors](#2-bugs--logical-errors)
3. [Routing Problems](#3-routing-problems)
4. [Architecture Issues & Stability](#4-architecture-issues--stability)
5. [Role-Based Access Problems](#5-role-based-access-problems)
6. [Security Audit](#6-security-audit)
7. [Firebase Rules & Functions Audit](#7-firebase-rules--functions-audit)
8. [Edge Cases & Boundary Problems](#8-edge-cases--boundary-problems)
9. [Improvements & Recommendations](#9-improvements--recommendations)
10. [Severity Matrix](#10-severity-matrix)

---

## 1. Executive Summary

CampusConnect is a mature, well-documented Flutter + Firebase application at v9.0. The codebase shows evidence of **14+ iterative audit cycles** (v8.2 through v8.9) with extensive defensive programming. The v9.0 Career Coach feature follows the established single-writer + quota + cache contract. However, several issues persist across the stack:

- **3 bugs** (1 HIGH, 2 MEDIUM)
- **5 architectural concerns** (maintainability, scale)
- **4 security findings** (1 HIGH, 2 MEDIUM, 1 LOW)
- **7 edge cases** (2 could affect users)
- **10+ improvement recommendations**

The overall architecture is **stable and well-reasoned**. The single-writer contract, crash-safe quota reservation, portfolio-first gating, and role-based UI guards are all correctly implemented. The primary risks are the `logPlacementView` authentication gap, missing per-minute rate limiting on Career Coach, and scale limitations in bulk Firestore queries.

---

## 2. Bugs & Logical Errors

### BUG-1 [HIGH] — Teacher Dashboard Missing CareerCoachProvider Reset on Logout

**File:** `lib/views/dashboards/teacher_dashboard_view.dart` → `_resetProviders()`
**Impact:** State leak between user sessions on the same device

The Teacher dashboard's `_resetProviders()` method does NOT call `context.read<CareerCoachProvider>().reset()`. Both the Student dashboard (`_StudentDashboardTabState` logout handler) and the Alumni dashboard (`_AlumniDashboardTabState` logout handler) DO reset it. If a Teacher logs out and a Student logs in on the same device, the stale `CareerCoachProvider` state from a prior session could leak into the new session.

**Evidence:**
```dart
// teacher_dashboard_view.dart _resetProviders()
context.read<PortfolioProvider>().reset();
context.read<AlumniGroupChatProvider>().reset(); // v8.7
// CareerCoachProvider.reset() is MISSING here
```

vs Student dashboard:
```dart
context.read<CareerCoachProvider>().reset(); // v9.0 — PRESENT
```

The AuthGuard fallback logout path in `main.dart` DOES reset CareerCoachProvider, so this bug only manifests when the Teacher dashboard's explicit logout fires without the AuthGuard fallback running first (which is the normal path — the dashboard resets providers BEFORE calling `AuthService.logOut()`).

**Fix:** Add `context.read<CareerCoachProvider>().reset();` to `_resetProviders()` in teacher_dashboard_view.dart.

---

### BUG-2 [MEDIUM] — `generateResumeAnalysis` Lacks Crash-Safe Quota Reservation

**File:** `functions/index.js` → `generateResumeAnalysis` callable
**Impact:** Permanent credit loss on function crash

The v6.95 `generateResumeAnalysis` function uses a simple `aiUsageCount` increment without the reservation/rollback pattern that `reviewResume` (v8.8.2) and `generateCareerCoachAnalysis` (v9.0) both implement. If the function crashes AFTER the usage check but BEFORE storing the AI result, the user permanently loses a monthly AI analysis credit.

The v8.8.2 crash-safe pattern (`pendingRequestId` + `pendingSince` + daily compensation sweep) was designed exactly for this scenario and was applied to `reviewResume` and `generateCareerCoachAnalysis` — but `generateResumeAnalysis` was never retrofitted.

**Impact assessment:** Low frequency (requires a function crash in a narrow window), but when it happens the user has no recovery path. The newer functions have the sweep at 04:00 UTC; this function has no equivalent.

**Fix:** Apply the `consumeResumeQuota` / `clearResumeReservation` / `rollbackResumeUsage` pattern (or a dedicated equivalent for the AI analysis quota) to `generateResumeAnalysis`.

---

### BUG-3 [MEDIUM] — Portfolio Flattened-Shape Self-Heal Gap on No-Change Save

**File:** `lib/services/firestore/portfolio_service.dart` → `savePortfolio()`
**Impact:** Flattened portfolio documents remain flattened until a user edits data

When a document has the flattened `portfolio.*` shape (from console edits or legacy writers), `getPortfolio()` reads it correctly via `_extractPortfolioMap` + `_unflattenPaths`. However, if the user opens Edit Portfolio and taps Save WITHOUT changing anything, the diff-based save (`previous` argument) detects no changes and writes nothing. The document remains in the flattened shape permanently.

The `_attemptRestore` path in PortfolioProvider bypasses this by calling `savePortfolio(userId, toRestore)` WITHOUT `previous`, which writes all sections. But the normal "user opens Edit Portfolio, doesn't change anything, taps Save" path doesn't trigger a self-heal.

**Fix:** When reading a flattened-shape document, flag it in the provider and force a full (non-diff) save on the next `savePortfolio` call, OR set `previous: null` when the detected shape is flattened.

---

## 3. Routing Problems

### ROUTE-1 [RESOLVED] — Recommendation Cards Routing to `profileSetupRoute`

**Status:** ✅ FIXED in v9.0 Phase 1

The `student_dashboard_view.dart` now correctly routes:
- `RecommendationType.skill` → `editProfileRoute` ✓
- `RecommendationType.role` → `editProfileRoute` ✓
- `RecommendationType.placement` → `placementsListRoute` ✓
- `RecommendationType.portfolio` → `studentPortfolioRoute` ✓

The `CareerCoachNavigation.routeFor()` utility correctly maps ALL recommendation types to appropriate destinations. **No recommendation card ever routes to `profileSetupRoute`.**

### ROUTE-2 [OK] — Career Coach Navigation Completeness

All 10 `CareerCoachRecType` values map to valid routes:
| Type | Route | Correct? |
|------|-------|----------|
| portfolio | studentPortfolioRoute | ✅ |
| resume | resumeReviewRoute | ✅ |
| project | projectsManagerRoute | ✅ |
| experience | experienceManagerRoute | ✅ |
| certification | certificationsManagerRoute | ✅ |
| achievement | achievementsManagerRoute | ✅ |
| profile | editProfileRoute | ✅ |
| skill | aiChatRoute | ✅ |
| interview | aiChatRoute | ✅ |
| jobSearch | opportunitiesRoute | ✅ |

### ROUTE-3 [OK] — Dynamic Route Handling in `onGenerateRoute`

The `onGenerateRoute` in `main.dart` correctly handles:
- `resumeReviewDetailRoute` — falls back to history view on missing args ✅
- `chatRoute` / `chatDetailRoute` — falls back to chat list on missing args ✅
- `completeMentorshipRoute` — falls back to requests view on wrong args ✅

All other routes use simple named route mapping without dynamic arguments.

---

## 4. Architecture Issues & Stability

### ARCH-1 — Single-Writer Contract: INTACT ✅

The core architectural invariant — **single writer for recommendations** — is maintained:
- Server: `refreshRecommendationsForStudent()` is the ONLY writer to `users/{uid}/recommendations/*` and `recommendations_meta/summary`
- Client: `RecommendationProvider` reads the stream + `markInteracted` only
- Career Coach: `generateCareerCoachAnalysis` callable is the ONLY writer to `users/{uid}/career_coach/summary`
- Client: `CareerCoachProvider` reads the stream + calls callable for generation

No competing client-side engines exist. The v8.6 audit correctly removed the client scoring engine.

### ARCH-2 — `index.js` Monolith (3000+ lines)

The `functions/index.js` file contains:
- `askAI` (chat function) + rate limiting + spam detection + trial management
- `reviewResume` + PDF extraction + quota management
- `generateResumeAnalysis` (AI deep analysis)
- `deleteAIHistory` + retention cleanup
- `refreshRecommendations` + the full `refreshRecommendationsForStudent` engine
- 5+ Firestore triggers (profile update, resume review, opportunity, mentorship, chat message)
- 4+ scheduled functions (engagement recompute, opportunity expiry, inactivity reminders, retention cleanup, quota compensation)
- Helper functions (logging, notifications, engagement, profile strength)

The v9.0 Career Coach was correctly extracted to `careerCoach.js`, but the remaining functions weren't. This creates:
- Merge conflicts when multiple features are developed in parallel
- Difficulty finding specific functions
- Cognitive overload for new developers

**Recommendation:** Extract into modules: `ai/` (askAI, reviewResume, generateResumeAnalysis), `triggers/` (Firestore triggers), `schedulers/` (cron jobs), `recommendations/` (already done).

### ARCH-3 — Duplicate Eligibility Logic

Client-side `EligibilityEngine` (`lib/services/eligibility_engine.dart`) and server-side `checkMandatoryEligibility` (`functions/recommendations/engine.js`) implement identical eligibility rules:
- CGPA minimum
- Allowed years
- Program/branch
- Deadline check
- Applied check

Both must be updated in sync. The server is authoritative (deterministic — never AI-overridable), and the client duplicates it for UX purposes (showing eligibility badges before the server runs). This is documented and intentional but creates a maintenance risk.

### ARCH-4 — Provider Initialization Ordering in AuthGuard

The `AuthGuard` in `main.dart` initializes 15+ providers in `addPostFrameCallback`. The initialization sequence is:
1. `placementsProvider.initWithUser`
2. `aiProvider.initWithUser`
3. `notificationsProvider.initWithUser`
4. `resumeReviewProvider.initWithUser`
5. `roleProvider.initWithUser`
6. `chatProvider.initWithUser`
7. `aiChatProvider.initWithUser`
8. `alumniGroupChatProvider.initWithUser`
9. `careerCoachProvider.initWithUser`
10. `profileProvider.initWithUser`

Then a SECOND callback (when profile + role are loaded) initializes:
11. `mentorshipProvider.initWithUser`
12. `opportunityProvider.initWithUser`
13. `recommendationProvider.initWithUser`
14. `engagementProvider.initWithUser`
15. `portfolioProvider.initWithUser`

This two-phase approach is correct (ecosystem providers need the role), but the sheer number of providers initialized makes the startup path fragile. Any provider that throws could prevent subsequent providers from initializing.

### ARCH-5 — `JSON.stringify` for Deep Comparison

Both `isPortfolioMetadataOnlyChange` and `portfolioContentChanged` in `functions/index.js` use `JSON.stringify` for deep object comparison. This is:
- **Order-sensitive:** if Firestore returns fields in different order, comparison fails
- **Not null-safe for special types:** `JSON.stringify(Timestamp)` returns `{}` (not a comparable value)

In practice, since both `before` and `after` come from Firestore events on the same document, field ordering is consistent. But this is a latent fragility if the comparison code is ever reused outside the trigger context.

---

## 5. Role-Based Access Problems

### ROLE-1 [OK] — Role Immutability Enforcement ✅

The `canWriteRole()` Firestore rule correctly prevents role self-elevation:
```
function canWriteRole(userId) {
  return !exists(/databases/$(database)/documents/users/$(userId))
    || !('role' in resource.data)
    || !('role' in request.resource.data)
    || resource.data.role == request.resource.data.role;
}
```

A student CANNOT change their role to teacher/alumni via client writes. This was the F1 security fix from v8.4.6 and is intact.

### ROLE-2 [OK] — Alumni Portfolio Guard ✅

The `_guardStudentPortfolio()` function in `main.dart` correctly blocks Alumni from entering Student Portfolio editing screens. Non-Alumni (Students, Teachers) pass through. The read-only portfolio route (`portfolioReadOnlyRoute`) is NOT guarded so Alumni can still VIEW student portfolios.

### ROLE-3 [OK] — Alumni Group Chat Guard ✅

The `_guardAlumniGroupChat()` function correctly blocks non-Alumni. The Firestore rules enforce `userRole() == 'alumni'` for all read/write operations on `alumni_group_messages`.

### ROLE-4 [OK] — Teacher Profile Isolation ✅

The `_RoleAwareProfileView` in `main.dart` correctly routes:
- Teachers → `TeacherProfileView` (no student portfolio/ATS/career features)
- Students/Alumni → `ProfileView` (role-aware branch within)

### ROLE-5 [NOTE] — Teachers Can Read ALL User Documents

The Firestore rule `allow read: if isTeacher()` on `users/{userId}` gives teachers access to ALL user data — including other teachers, alumni, phone numbers, emails, academic data, etc. This is documented as intentional for analytics. However:
- Teachers can read other teachers' personal data
- Teachers can read alumni personal data
- The `users` document includes the nested portfolio map with all career data

**Risk:** Low in a college setting where teachers are trusted administrators. But if the app scales to multi-tenant, this needs role-scoping.

### ROLE-6 [NOTE] — Alumni Can Read ALL Student Documents

Similarly, `allow read: if isAuthenticated() && userRole() == 'alumni' && resource.data.role == 'student'` gives any alumni read access to ALL student docs. The M2 privacy note documents this trade-off of the nested-map design.

---

## 6. Security Audit

### SEC-1 [HIGH] — `logPlacementView` Uses `onRequest` with Body-Based Identity

**File:** `functions/index.js` → `logPlacementView`

All user-facing functions were migrated to `onCall` (callable) in v8.4.2 so that `request.auth.uid` provides authoritative identity. `logPlacementView` was NOT migrated — it's still `onRequest` and accepts `userId` from the request body:

```javascript
exports.logPlacementView = onRequest({cors: true}, async (request, response) => {
  const {userId, placementId, company} = request.body;
  // userId is from the request body, NOT from auth context
```

An attacker can forge placement view events for any user by supplying arbitrary `userId` values. While this only affects analytics data (not security-critical), it violates the architectural principle that ALL user identity comes from `request.auth.uid`.

**Fix:** Migrate to `onCall` or extract uid from `request.auth`.

### SEC-2 [MEDIUM] — No Per-Minute Rate Limiting on Career Coach Callable

**File:** `functions/careerCoach.js` → `generateCareerCoachAnalysis`

The Career Coach callable has monthly quota (3/month) and crash-safe reservation. But unlike `askAI` (which has 5 msgs/min rate limiting + spam detection), there's no per-minute rate limiting. An attacker could:
1. Call `generateCareerCoachAnalysis` 3 times in 3 seconds
2. Exhaust the user's monthly quota before they get any value
3. The quota is consumed even if the AI response is garbage

The monthly limit of 3 makes this a limited attack surface, but the first-call-ever should be protected from rapid-fire exhaustion.

**Fix:** Add a per-minute rate limit check (similar to `checkRateLimit` in `askAI`) or at minimum a cooldown between calls.

### SEC-3 [MEDIUM] — No App Check

**Documented:** workspace tracker note #6

`No AppCheckProvider installed` appears as a WARNING on every session. Firestore/Storage rules authenticate via `request.auth` (Firebase Auth), not `app.check()`. This means:
- Any valid Firebase Auth token grants access
- Automated scripts with valid credentials can call all functions
- Bot traffic is not filtered

**Impact:** Low in a college app. Medium if the app scales or if API keys/costs matter.

### SEC-4 [LOW] — AI Prompt Injection Surface

All AI functions (`askAI`, `reviewResume`, `generateResumeAnalysis`, `generateCareerCoachAnalysis`) accept user-controlled text that is sent to the AI model. The system prompts instruct the AI to return specific JSON structures, but a malicious user could craft input that attempts to:
- Override the system prompt
- Extract API keys or internal context
- Generate harmful content

The AI providers (Groq, HuggingFace) have their own safety layers, but the application does NOT sanitize user input for prompt injection patterns. The `normalizeChatText` function strips markdown but doesn't filter injection attempts.

**Mitigations present:**
- Input length limits (1000 chars for chat, 5000 chars for resume)
- Response validation (strict JSON parsing, type checking)
- No API keys in prompts or responses

**Risk:** Low. The outputs are validated before storage/display. But a determined attacker could waste API credits or produce confusing outputs.

### SEC-5 [OK] — Storage Rules ✅

- Owner-only writes to `resumes/{uid}/{fileName}`
- PDF-only + 5 MB limit enforced server-side
- Teacher/alumni read via Firestore role lookup (not auth token)
- All other paths denied

### SEC-6 [OK] — Resume Ownership Check ✅

`resumeTextFromStorage` validates `storagePath === 'resumes/${uid}/latest.pdf'` exactly. Cross-UID attempts are rejected with `invalid-argument`. This is correct and tested.

---

## 7. Firebase Rules & Functions Audit

### RULES-1 [OK] — `career_coach` Subcollection

```javascript
match /career_coach/{docId} {
  allow read: if isOwner(userId);
  allow write: if false; // Server-only (Admin SDK)
}
```
Correct. Client can read their own analysis. Only the server (Admin SDK) can write.

### RULES-2 [OK] — `career_coach_usage` Collection

```javascript
match /career_coach_usage/{userId} {
  allow read: if isOwner(userId);
  allow write: if false; // Server-only (Admin SDK)
}
```
Correct. Mirrors the `resume_usage` pattern.

### RULES-3 [OK] — Catch-All Under Users

```javascript
match /{subcollection=**} {
  allow read, write: if isOwner(userId);
}
```
This is a broad catch-all. However, more specific rules above it take precedence in Firestore:
- `recommendations` → write: false (server-only)
- `recommendations_meta` → write: false
- `engagement_summary` → write: false
- `career_coach` → write: false
- `career_coach_usage` → write: false
- `ai_insights` → write: false

The catch-all applies to any subcollection NOT explicitly listed (e.g., future subcollections). This means a developer who adds a new subcollection under `users/{uid}` without explicit rules gets owner-read-write by default. This is generally safe but could be surprising if a server-only subcollection is added without explicit rules.

**Recommendation:** Consider inverting the pattern — deny by default, allow explicitly.

### RULES-4 [OK] — Activities Rule

The `activities` rule correctly restricts client writes to `eventType == 'resumeReviewed' && points == 5` only. Arbitrary point/event injection is blocked.

### RULES-5 [OK] — Chat Rules

The `chats` rule correctly limits updates to `lastMessage`, `lastMessageSenderId`, `lastMessageAt`, `unreadCount` only. Full-document rewrite (participants/mentorshipId) is denied. Delete is denied (Admin SDK only).

### RULES-6 [NOTE] — `ai_conversations` Legacy Collection

The `ai_conversations` collection still has `allow read: if isAuthenticated() && resource.data.userId == request.auth.uid; allow write: if false;`. The `askAI` function writes to this collection via Admin SDK. The `deleteAIHistory` callable also reads/deletes from it. This is correct but represents technical debt — the collection could be fully migrated to `users/{uid}/ai_interactions`.

### FUNCS-1 [OK] — Scheduled Functions

| Function | Schedule | Purpose | Status |
|----------|----------|---------|--------|
| `recomputeEngagementScores` | Daily 01:00 UTC | Recompute all user engagement | ✅ |
| `cleanupExpiredAIConversations` | Daily 03:00 UTC | Remove expired AI chats | ✅ |
| `compensateStaleResumeQuota` | Daily 04:00 UTC | Refund stale resume quota | ✅ |
| `compensateStaleCareerCoachQuota` | Daily 04:10 UTC | Refund stale career coach quota | ✅ |
| `autoExpireOpportunities` | Every 60 min | Deactivate expired opportunities | ✅ |
| `sendInactivityReminders` | Daily 09:00 UTC | Chat/mentorship reminders | ✅ |

All scheduled functions use `region: "us-central1"` and `timeZone: "UTC"`. No overlaps or conflicts.

### FUNCS-2 [OK] — Firestore Triggers

| Trigger | Document | Action |
|---------|----------|--------|
| `onProfileUpdatedRefreshAI` | `users/{userId}` | Refresh recommendations + engagement |
| `onResumeReviewCreatedRefreshMatches` | `users/{uid}/resumeReviews/{id}` | ATS merge + recommendations |
| `onOpportunityPostedNotifyStudents` | `opportunities/{id}` | Notify all students |
| `onMentorshipRequestCreated` | `mentorship_requests/{id}` | Notify alumni |
| `onMentorshipRequestResponseNotifyStudent` | `mentorship_requests/{id}` | Notify student |
| `onChatMessageCreated` | `chats/{id}/messages/{id}` | Notify recipient |

All triggers have `maxInstances` limits and error handling. The `onProfileUpdatedRefreshAI` trigger correctly handles the portfolio-metadata-only change detection (v8.9 Phase 10).

### FUNCS-3 [OK] — Node.js Runtime

`functions/package.json` specifies `"node": "22"`. This was updated from Node 20 in v8.8.3 (HIGH-3). The deploy deadline was 2026-10-30 — well within the current date (2026-08-18).

---

## 8. Edge Cases & Boundary Problems

### EDGE-1 — Empty Career Coach Input

A student with a completed profile but ZERO portfolio content (no skills, no projects, no experience, no resume, no certifications) calls `generateCareerCoachAnalysis`.

**Behavior:**
- `profileCompleted === true` → passes the precondition check ✓
- `buildCareerAnalysisInput` produces an input with empty arrays and null values
- The AI receives minimal data and should produce "complete your portfolio" type recommendations
- The server's `hasAnyCareerData()` function exists but is NOT used as a gate

**Risk:** The AI might produce generic/unhelpful recommendations for a nearly-empty profile. This is by design (Task.md test case G: "Very little profile data → limited guidance from available data only"), but the AI prompt should handle this gracefully.

**Mitigation present:** The 14-rule prompt includes: "If the student has very little data, DO NOT invent experience, skills, certificates, or achievements."

### EDGE-2 — Career Coach Cache Invalidation on Profile Update

The `onProfileUpdatedRefreshAI` trigger refreshes the deterministic recommendations when career data changes. But it does NOT invalidate the Career Coach cache. The Career Coach cache is invalidated by its own fingerprint (`computeCareerInputFingerprint`), which is computed from the `CareerAnalysisInput`. Since the Career Coach callable reads the user doc and recomputes the fingerprint at call time, the cache is effectively invalidated when the data changes.

However, the Career Coach section on the dashboard reads from the `users/{uid}/career_coach/summary` stream. If the user updates their profile, the deterministic recommendations refresh immediately (trigger), but the Career Coach analysis stays stale until the user manually requests a re-analysis or the fingerprint changes.

**This is by design** — Task.md §8 says "Regenerate ONLY when meaningful career data changes OR the student explicitly requests 'Re-analyze'." The stream will show the old analysis, and when the student opens the Career Coach screen, the callable will detect the fingerprint mismatch and regenerate.

**Potential issue:** The dashboard shows stale Career Coach recommendations until the user explicitly navigates to the Career Coach screen. This is correct behavior but could confuse users who expect the dashboard to update immediately after a profile edit.

### EDGE-3 — Concurrent Career Coach Requests

Two devices/browsers with the same user calling `generateCareerCoachAnalysis` simultaneously:
- Both pass the cache check
- Both try to `consumeCareerCoachQuota` in a Firestore transaction
- The transaction ensures only one succeeds (the second sees the incremented count)
- If the limit is 3 and count is 2, one call gets count=3 (passes) and the other sees count=3 (resource-exhausted)

This is correct — the transaction provides atomicity.

### EDGE-4 — `pdf-parse` Edge Cases

The `resumeTextFromStorage` function uses `pdf-parse@^1.1.1` which bundles a 2017-era pdf.js. Known issues:
- Some PDFs with unusual xref tables may fail to parse
- Encrypted PDFs return empty text (treated as image-based)
- Very large PDFs (>5MB) are rejected by the metadata check
- PDFs with only images return empty text (correctly detected as image-based)

These are all handled with appropriate error messages.

### EDGE-5 — Portfolio Provider Divergence Detection

The v8.9.2 divergence detection (`shouldTriggerPortfolioRestore`) correctly distinguishes:
- **Stale replay:** Empty event racing a just-made local write (v8.4.4 guard)
- **Genuine wipe:** Server confirmed content earlier but now reads empty (v8.9.2 detection)

The `shouldTriggerPortfolioRestore` function is a pure top-level function (unit-testable) and correctly returns `true` when `serverHadContent || restoredFromCache` AND `!restoreAlreadyAttempted`.

### EDGE-6 — Recommendation Type Deduplication

Both the server (`validateCareerCoachResponse` in `career_coach.js`) and the client (`CareerCoachAnalysis.fromJson` in `career_coach_analysis.dart`) deduplicate recommendations by type, keeping only the first of each type. The server caps at 5 recommendations.

If the AI returns two `portfolio` recommendations (e.g., "Build a project" and "Deploy your app"), only the first survives. This is by design per Task.md §4 ("3–5 HIGH-VALUE recommendations — never 10–20"), but could lose valuable nuanced advice.

### EDGE-7 — `isPortfolioMetadataOnlyChange` False Positive

The `isPortfolioMetadataOnlyChange` function compares `before` and `after` documents to detect portfolio-metadata-only changes (stamps). It uses `JSON.stringify` for comparison. If the `metadata.updatedAt` timestamp changes format (e.g., from `Timestamp` to ISO string due to a Firebase SDK update), the comparison could incorrectly classify a metadata-only change as a content change, triggering unnecessary recommendation refreshes.

**Risk:** Low — Firebase SDK consistently returns `Timestamp` objects from Firestore events.

---

## 9. Improvements & Recommendations

### IMP-1 [HIGH-Priority] — Fix Teacher Dashboard Logout Reset (BUG-1)

Add `context.read<CareerCoachProvider>().reset();` to `_resetProviders()` in `lib/views/dashboards/teacher_dashboard_view.dart`.

### IMP-2 [HIGH-Priority] — Migrate `logPlacementView` to Callable (SEC-1)

Convert from `onRequest` to `onCall` so identity comes from `request.auth.uid`. This is the last remaining HTTPS function with body-based identity.

### IMP-3 [HIGH-Priority] — Apply Reservation Pattern to `generateResumeAnalysis` (BUG-2)

Retrofit the crash-safe quota reservation (`pendingRequestId` + `pendingSince` + daily sweep) to the `generateResumeAnalysis` function. Create a dedicated `ai_analysis_usage/{uid}` collection or reuse the existing `users/{uid}` `aiUsageCount` field with reservation stamps.

### IMP-4 [MEDIUM-Priority] — Add Per-Minute Rate Limiting to Career Coach (SEC-2)

Add a lightweight per-minute check before `consumeCareerCoachQuota`. Options:
- Reuse the `ai_rate_limits` collection pattern from `askAI`
- Or add a simple cooldown (e.g., 60 seconds between Career Coach calls)

### IMP-5 [MEDIUM-Priority] — Split `index.js` into Modules (ARCH-2)

Extract into:
- `functions/ai/chat.js` — askAI + rate limiting + spam detection
- `functions/ai/resumeReview.js` — reviewResume + PDF extraction + quota
- `functions/ai/deepAnalysis.js` — generateResumeAnalysis
- `functions/triggers/` — all Firestore triggers
- `functions/schedulers/` — all scheduled functions
- `functions/helpers/` — shared utilities (notifications, engagement, logging)

### IMP-6 [MEDIUM-Priority] — Add App Check (SEC-3)

Enable Firebase App Check with:
- Android: Play Integrity API
- iOS: DeviceCheck
- Web: reCAPTCHA v3

This prevents automated bot traffic and protects Cloud Functions from abuse.

### IMP-7 [MEDIUM-Priority] — Portfolio Flattened-Shape Auto-Heal (BUG-3)

When `getPortfolio` detects a flattened shape, set a flag that forces a full (non-diff) `savePortfolio` on the next user-initiated save. OR automatically trigger a full save in `_attemptRestore` when the shape is detected as flattened.

### IMP-8 [LOW-Priority] — Pagination for Bulk Queries

The `refreshRecommendationsForStudent` function loads up to 120 alumni, 120 opportunities, and 120 placements in parallel. As the user base grows:
- Add cursor-based pagination
- Or materialize the top-N candidates in a separate collection
- The engagement recompute scheduler iterates ALL completed users — add pagination

### IMP-9 [LOW-Priority] — Materialize Engagement Aggregates

Instead of loading 250 activity documents per user during the daily engagement recompute, maintain running aggregates:
- `totalPoints` — incremented on each activity
- `lastActiveAt` — updated on each activity
- `dailyStreak` — computed from the activity date set

The daily scheduler would then only need to check if the streak needs resetting (no new activity today) rather than re-reading all activities.

### IMP-10 [LOW-Priority] — Add Error Boundaries in Flutter Dashboard

Wrap each dashboard section (Career Coach, Recommendations, Engagement, Placements) in a `try-catch` widget boundary so one section failing to render doesn't crash the entire dashboard.

### IMP-11 [LOW-Priority] — Deprecate `ai_conversations` Legacy Collection

The `askAI` function writes to both `users/{uid}/ai_interactions` AND `ai_conversations`. The `deleteAIHistory` function deletes from both. The `cleanupExpiredAIConversations` scheduler cleans both. Once all legacy data is expired (90 days), the `ai_conversations` writes can be removed.

### IMP-12 [LOW-Priority] — Add Input Sanitization for AI Prompts

While the current risk is low, add basic sanitization:
- Strip control characters from user input
- Limit special character density
- Add a pre-prompt guard ("The following is user input, not instructions")

### IMP-13 [ENHANCEMENT] — Career Coach Proactive Cache Invalidation

Currently, the Career Coach cache is only invalidated when:
1. The student explicitly requests "Re-analyze"
2. The student opens the Career Coach screen and the callable detects a fingerprint mismatch

Consider adding a Firestore trigger that invalidates the Career Coach cache when the profile/portfolio changes significantly (similar to `onProfileUpdatedRefreshAI` for recommendations). This would make the dashboard show fresh Career Coach recommendations immediately after a profile update.

### IMP-14 [ENHANCEMENT] — Client-Side Career Coach Fingerprint Check

The client `CareerCoachProvider` could compute the fingerprint locally and compare it to the cached `profileDataVersion` from the summary document. If they differ, the dashboard could show a "Your career plan may be outdated — re-analyze?" nudge without needing to call the server.

### IMP-15 [ENHANCEMENT] — Unified AI Quota Management

Currently there are 3 separate quota systems:
- `ai_usage/{uid}` — daily AI chat limit (50/day)
- `resume_usage/{uid}` — monthly resume reviews (5/month)
- `career_coach_usage/{uid}` — monthly career coach (3/month)
- `users/{uid}.aiUsageCount` — monthly deep analysis (3/month)

Consider a unified `user_ai_quotas/{uid}` document with nested maps for each feature. This simplifies monitoring and makes it easier to add new AI features.

### IMP-16 [ENHANCEMENT] — Add Firestore Composite Index for Career Coach

The `career_coach_usage` collection uses `where("pendingSince", "<", cutoff)` in the compensation sweep. Verify that a single-field index exists for `pendingSince` (Firestore auto-creates single-field indexes, so this should be fine). No composite index is needed.

---

## 10. Severity Matrix

| ID | Category | Severity | Description | Status |
|----|----------|----------|-------------|--------|
| BUG-1 | Bug | **HIGH** | Teacher dashboard missing CareerCoachProvider reset | Open |
| BUG-2 | Bug | **MEDIUM** | generateResumeAnalysis lacks crash-safe reservation | Open |
| BUG-3 | Bug | **MEDIUM** | Flattened portfolio shape self-heal gap | Open |
| SEC-1 | Security | **HIGH** | logPlacementView uses body-based identity | Open |
| SEC-2 | Security | **MEDIUM** | No per-minute rate limiting on Career Coach | Open |
| SEC-3 | Security | **MEDIUM** | No App Check | Documented |
| SEC-4 | Security | LOW | AI prompt injection surface | Accepted risk |
| ARCH-1 | Architecture | OK | Single-writer contract intact | ✅ Verified |
| ARCH-2 | Architecture | NOTE | index.js monolith (3000+ lines) | Improvement |
| ARCH-3 | Architecture | NOTE | Duplicate eligibility logic | Improvement |
| ARCH-4 | Architecture | NOTE | 15+ provider init in AuthGuard | Accepted |
| ARCH-5 | Architecture | LOW | JSON.stringify comparison fragility | Accepted |
| ROLE-1 | Roles | OK | Role immutability enforced | ✅ Verified |
| ROLE-2 | Roles | OK | Alumni portfolio guard | ✅ Verified |
| ROLE-3 | Roles | OK | Alumni group chat guard | ✅ Verified |
| ROLE-4 | Roles | OK | Teacher profile isolation | ✅ Verified |
| ROLE-5 | Roles | NOTE | Teachers read all user docs | Accepted |
| ROLE-6 | Roles | NOTE | Alumni read all student docs | Accepted |
| ROUTE-1 | Routing | OK | Recommendation routing fixed | ✅ Verified |
| ROUTE-2 | Routing | OK | Career Coach navigation complete | ✅ Verified |
| EDGE-1 | Edge case | NOTE | Empty career coach input | By design |
| EDGE-2 | Edge case | NOTE | Stale CC cache after profile update | By design |
| EDGE-3 | Edge case | OK | Concurrent CC requests handled | ✅ Correct |
| EDGE-4 | Edge case | NOTE | pdf-parse edge cases | Known limitation |
| EDGE-5 | Edge case | OK | Portfolio divergence detection | ✅ Correct |
| EDGE-6 | Edge case | NOTE | Recommendation type deduplication | By design |
| EDGE-7 | Edge case | LOW | isPortfolioMetadataOnlyChange fragility | Accepted |

---

## Summary of Required Fixes

| Priority | Fix | File(s) |
|----------|-----|---------|
| **HIGH** | Add CareerCoachProvider reset to teacher logout | `lib/views/dashboards/teacher_dashboard_view.dart` |
| **HIGH** | Migrate logPlacementView to callable | `functions/index.js` |
| **MEDIUM** | Apply reservation pattern to generateResumeAnalysis | `functions/index.js` |
| **MEDIUM** | Add per-minute rate limiting to Career Coach | `functions/careerCoach.js` |
| **MEDIUM** | Auto-heal flattened portfolio shape | `lib/services/firestore/portfolio_service.dart` |

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v9.0 | 2026-08-18 | AI Career Coach (callable + quota + cache + UI) |
| v8.9.3+95 | 2026-08-18 | Portfolio-first fix, engine tuning, career signal fixes |
| v8.9.1 | 2026-08-16 | Portfolio-first gate, relevance gate, stale-doc cleanup |
| v8.9 | 2026-08-16 | Recommendation engine, career roles, placement matching |
| v8.8.3 | 2026-08-15 | askAI timeout, Node 22, rules fixes |
| v8.8.2 | 2026-08-15 | Crash-safe quota reservation, alumni chat role-gate |
| v8.8 | 2026-08-15 | AI provider migration, chat deletion, retention cleanup |
| v8.7 | 2026-08-09 | Alumni simplification, group chat |
| v8.6 | 2026-08-09 | Single-writer restoration, architecture stability |
| v8.5 | 2026-08-07 | Resume reviewer integration, PDF intelligence |
| v8.4 | 2026-08-07 | Student resume portfolio system |
