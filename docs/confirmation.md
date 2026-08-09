# CampusConnect v8.5.2 — Final Audit & Architecture Stability Review

> ## v8.7 Resolution Banner (2026-08-09)
>
> **v8.7 delivered — Alumni Experience Simplification & Alumni Group Chat (8.6.0+89 → 8.7.0+90).**
> - **Role separation**: Portfolio is a Student career-development feature. The Alumni dashboard's `ResumeSummaryCard` + portfolio refresh were removed (replaced with an **Alumni Community** card + quick action); the Alumni profile's "My Portfolio" tile was removed; the Resume Reviewer hides the uploaded-resume card / upload CTA for Alumni (text-input only). The 7 Student Portfolio editing routes are now role-gated (`_guardStudentPortfolio`) — Alumni who manually access them get a safe blocked view. `portfolioReadOnlyRoute` stays open so Alumni can still VIEW a Student's portfolio. **The Student Portfolio subsystem is NOT deleted.**
> - **Alumni text-based Resume Reviewer**: Alumni paste resume text → the SAME `reviewResume` callable → existing ATS pipeline (no second engine, no second storage). Quota (`resume_usage/{uid}`) and history (`users/{uid}/resumeReviews`) reused unchanged, UID-scoped.
> - **Alumni Group Chat**: `alumni_group_messages/{messageId}` (senderId, senderName, senderPhotoUrl?, message, createdAt, editedAt?, isDeleted?) with `AlumniGroupChatService` → `AlumniGroupChatProvider` → `AlumniGroupChatView` (Material 3 chat: sender name + timestamp, own-message bubbles, empty/loading/error/sending states, auto-scroll on new messages). No composite index needed (single-field `orderBy('createdAt')`). Provider registered/initialized/reset at all 5 logout sites.
> - **Security**: `firestore.rules` `alumni_group_messages` block — read Alumni-only; create Alumni-only with `senderId == request.auth.uid`; update/delete own messages only. Students/Teachers/unauthenticated denied server-side. Existing rules not weakened.
> - **Validation**: `flutter analyze` **0 errors / 0 warnings** (68 pre-existing info lints); `flutter test` **124/124 passed** (83 existing + 41 new v8.7/v8.7.1 tests); `node --check functions/index.js` pass; `dart format` clean.
> - **Deployment**: ✅ **DEPLOYED 2026-08-09** — `firebase deploy --only firestore:rules` **SUCCESS** (alumni_group_messages Alumni-only rules live). A follow-up v8.7.1 pass made the dashboard activity badge role-aware (Alumni see **"Active Alumni"** instead of "Active Student") and deployed the functions (15/15 success).
> - **v8.7.1 badge fix (user report)**: both badge engines (client `EngagementService` + server `recomputeEngagementSummary`) hardcoded "Active Student"; now role-aware in both so the badge can never flicker between writers. See `docs/issues.md` v8.7.1 entry.
> - On-device manual matrix per `docs/Task.md` §22 remains.
>
> Full delivery log: **`docs/issues.md` — v8.7 section** · **`docs/v8_workspace_tracker.md` — v8.7 / v8.7.1 sections** · **`docs/todo.md` — v8.7 checklist**.

> ## v8.6 Resolution Banner (2026-08-09)
>
> **All code findings from this audit are FIXED — the v8.6 pass resolved every actionable item on the Prioritized Fix List (§10).**
> - 🔴 Deploy gap (#1): code verified; has been carried into B14 (`firebase deploy --only functions` + `--only firestore:indexes`) — flagged for the deploy owner.
> - 🟠 HIGH #2–#6: all fixed (`OpportunityService` client notification batch removed; `ResumeReviewProvider` subscription leak fixed; `reviewResume` quota now consumes atomically + rolls back on AI failure; `ResumeService.uploadResume` preserves `reviewCount`/`lastReviewAt`; composite indexes added to `firestore.indexes.json`).
> - 🟡 MED #7–#10: all fixed (`onProfileUpdatedRefreshAI` timestamp value-comparison; single recommendation writer — client delegates to the new `refreshRecommendations` callable; atomic quota; ProfileView logout provider-reset parity).
> - 🔵 LOW: short-PDF message, phantom-portfolio guard, and badge threshold ≥85 fixed in code; PDF-truncation notice surfaced via callable `warning`; remaining LOW items explicitly deferred in `docs/issues.md` (v8.6 section).
> - 🟡 MED #9 (engagement write contention) + the remaining LOW items are documented Known Limitations — no code change.
> - **Validation**: `node --check functions/index.js` pass; `flutter analyze` / `flutter test` results recorded in B12 (see `docs/todo.md`).
>
> Full fix log (each finding → root cause → fix → files): **`docs/issues.md` — v8.6 section**.

---

> Audit date: 2026-08-09 · Scope: `docs/Task.md` (v8.5.2 goal), `docs/todo.md` (A1–A8), `docs/v8_workspace_tracker.md`, `project_info__16_v8.5.2_Alumni_Resume_Reviewer_Audit.md`, and full source review of the v8.5.2 delivery — `functions/index.js` (trigger + callables), `lib/views/profile/profile_view.dart`, `lib/views/dashboards/alumni_dashboard_view.dart`, `test/alumni_resume_review_test.dart`, plus the entire resume/portfolio subsystem (`ResumeService`, `PortfolioService`, `StorageService`, `PortfolioProvider`, `ResumeReviewProvider`, `ResumeReviewService`, `ResumeHistoryService`, `PortfolioCacheService`, `PortfolioModel`, `ResumeMetadata`), all dashboards, `main.dart`/routes, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, placement/mentorship/opportunity/chat/notification/analytics services, and the test suite.
> Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low
> This document supersedes the v8.4.1 final audit previously stored here. The v8.4.1 audit's content is preserved in the git history and referenced from `docs/v8_workspace_tracker.md` (Cross-Cutting Notes).

---

## 1. Executive Summary

**v8.5.2's stated goal is met in code**: the Alumni Resume Reviewer integration is correctly wired — Alumni have a "My Portfolio" tile (`ProfileView` A3), a `ResumeSummaryCard` dashboard surface (`alumni_dashboard_view.dart` A4), and the `onResumeReviewCreatedRefreshMatches` trigger now merges ATS metadata for **any** role (`functions/index.js` A2) while keeping the student-only recommendation enrichment gated. The reviewer itself is role-agnostic, `request.auth.uid` is the sole callable identity, and the read-only student portfolio remains strictly read-only. **83/83 tests, 0 analyze errors, and `node --check` pass are consistent with what the code shows.**

**However, the audit found 1 critical deployment gap, 5 high-severity bugs (3 of them old/pre-existing code that v8.4.3 / v8.4.2 missed), and a cluster of index/scale/edge issues.**

### Root cause of the original v8.5.2 defect (A1 audit — already fixed in code)

`onResumeReviewCreatedRefreshMatches` early-returned `if (userData.role !== "student")` before merging `portfolio.resume.{reviewCount,lastReviewAt,updatedAt,latestATSScore}`, so Alumni reviews never persisted ATS data. The A2 fix (verified present): the ATS → `portfolio.resume` merge now runs for **any** role; `refreshRecommendationsForStudent` stays gated to `role === "student"`; activity logging + engagement recompute run for every review author.

### 🔴 CRITICAL — not a code bug, a deployment gap
- **The v8.5.2 trigger change (`functions/index.js` A2) is NOT deployed.** `docs/todo.md` A8 and `docs/v8_workspace_tracker.md` both state deployment pending. Production therefore **still runs the old `if (userData.role !== "student") return;` gate** — Alumni ATS sync is **broken in production right now** until `firebase deploy --only functions` is run.

### 🟠 HIGH (new findings this audit)
1. **`OpportunityService.createOpportunity` still writes cross-user notifications client-side** — the exact Bug 5 pattern that v8.4.3 (MB8) removed from mentorship and chat but **missed in OpportunityService**. The batch write to `users/{studentUid}/notifications/...` always hits `PERMISSION_DENIED` under rule F7 (owner-only create), producing the same log noise Bug 5 produced, and with >500 students exceeds Firestore's 500-write batch cap. The `onOpportunityPostedNotifyStudents` trigger already delivers these correctly server-side, so the client write is redundant legacy code that must be removed.
2. **`ResumeReviewProvider` connectivity subscription leaks** — `_startConnectivityMonitoring()` calls `_connectivity.onConnectivityChanged.listen(...)` and discards the subscription; `reset()` never cancels it. Every login stacks a new listener; after provider disposal a late callback can fire `notifyListeners()` → "used after being disposed" crash class in debug. This is exactly the M5 leak v8.4.2 fixed in `PlacementsProvider` but **the same fix was never applied to `ResumeReviewProvider`**.
3. **`reviewResume` consumes the monthly quota even when the AI provider fails** — `trackResumeUsage(userId)` increments BEFORE `generateResumeReviewAI(...)`. On AI error the user loses a review credit with no rollback. The code comment says "increment only after quota check passes" — it does, but there is no compensation on the AI-failure path.
4. **Resume replacement wipes `portfolio.resume.reviewCount` + `lastReviewAt`** — `ResumeService.uploadResume` builds a fresh `ResumeMetadata(...)` that starts `reviewCount` at 0 and `lastReviewAt` at null. The ATS score is (correctly) cleared, but the user's review-history counters on the dashboard / portfolio are reset even though `users/{uid}/resumeReviews` still holds every past review.
5. **Missing composite indexes in `firestore.indexes.json`** — the codebase queries composite combinations that are not declared in the repo (details in §5). They only work today because v8.4.2's deploy preserved pre-existing remote-only indexes. A fresh project / CI deploy will fail with "index required" on Chat, Opportunities, and Mentorship screens.

### 🟡 MEDIUM (logical / architectural)
6. **`onProfileUpdatedRefreshAI` compares Firestore `Timestamp`s with `!==` (identity), which is always true** — `before.updatedAt !== after.updatedAt` is true for any two snapshot objects, so every non-portfolio `users/{uid}` write by a completed student (profile save, email backfill, any `metadata.updatedAt` stamp) spins the recommendation + engagement recompute. The `isPortfolioOnlyChange` guard stops portfolio diffs, but the `updatedAt` comparison is a logical error (should be `.toMillis()` / `.isEqual`).
7. **Two competing recommendation engines** — the server-side `refreshRecommendationsForStudent` (`functions/index.js`) and the client-side `RecommendationService.refreshRecommendations` (`lib`) both write `users/{uid}/recommendations/{id}` with the **same doc IDs but different scoring models** (server: `overlapSkills*18`, limit 4+4; client: `min(45, overlap*15)`, limit 5+5). Profile updates / resume reviews trigger the server engine; app init / refresh triggers the client engine. They can clobber each other's output, so the AI Smart Picks feed is unstable depending on which writer runs last.
8. **Quota race in `reviewResume`** — `getResumeUsage` (outside transaction) then `trackResumeUsage` (transaction) are not atomic together; two concurrent calls can both pass the limit check and increment → 6+ reviews in a month. Low likelihood, but the check-then-increment should be one transaction.
9. **`generateResumeAnalysis` and `onProfileUpdatedRefreshAI` engagement writes contend** — multiple triggers call `recomputeEngagementSummary` with last-writer-wins `set(merge)`. Acceptable at current scale; becomes noisy under load.
10. **ProfileView logout resets fewer providers than dashboard logout** — `_handleProfileLogout` omits Chat, Mentorship, Opportunity, AlumniDirectory, TeacherAnalytics, ActivityFeed. It is currently covered by AuthGuard's post-logout safety net, but the inconsistency is fragile — if AuthGuard's fallback ever changes, streaming providers survive logout.

### 🔵 LOW (edge / boundary)
- `resumeTextFromStorage` rejects extracted text < 100 chars as "image-based" — a genuine short resume PDF gets a misleading message.
- PDF text is silently truncated to 5000 chars before analysis (matches the manual-path ceiling; the user is not told).
- `logPlacementApplication` copies the resume snapshot BEFORE the idempotency transaction — duplicate apply attempts re-copy / re-sign the snapshot needlessly.
- `onResumeReviewCreatedRefreshMatches` creates a phantom `portfolio` / `portfolio.resume` map on users with **no portfolio** (manual-paste review; no upload). Harmless today (models treat no-storagePath resumes as empty) but pollutes documents and will suppress the MB13 "portfolio missing" diagnostic.
- Server badge threshold (`profile_pro` earned at 100) differs from client badge logic (earned at ≥85).
- `Application.fromFirestore` ignores the stored `studentId` alias (harmless; `userId` is canonical).
- Scheduler `recomputeEngagementScores` iterates all completed users sequentially — will exceed the 540s function timeout at ~1000+ users (documented Known Limitation 2).

---

## 2. Root Cause (v8.5.2) — State of the Fix

Verified in source (`functions/index.js` → `onResumeReviewCreatedRefreshMatches`):

```js
const isStudent = userData.role === "student";
// portfolio.resume merge — runs for ANY role (A2 fix)
await admin.firestore().collection("users").doc(userId)
    .set(portfolioResumeMerge, {merge: true});
// student-only enrichment stays gated
if (isStudent) { await refreshRecommendationsForStudent(...); }
// activity log + engagement recompute — role-agnostic (unchanged)
```

The fix is **correct and minimal**: ATS merge role-agnostic, recommendations still student-gated, engagement/activity run for every author. The two UX gaps (A3 profile tile, A4 dashboard card) are present and correctly route Alumni to the role-agnostic `studentPortfolioRoute` / `resumeUploadRoute`.

> **v8.6 note**: this trigger's merge now carries a phantom-portfolio guard (the ATS merge only runs when `userData.portfolio.resume` already exists), and a `refreshRecommendations` callable was added as the single client entry point.

**Deployment state**: `docs/todo.md` A8 = pending; `docs/v8_workspace_tracker.md` = "NOT deployed — pending code review + deploy". **Deploy is the immediate next step.**

---

## 3. Role-Based / Security Verification (v8.5.2 tasks §3, §11)

| Requirement | Status / Evidence |
|---|---|
| Student flow unchanged (upload → review → ATS → history) | ✅ `ResumeUploadScreen`, `ResumeReviewView`, `_saveToHistory` all UID-scoped |
| Alumni equivalent personal flow | ✅ A2/A3/A4 — same UID-scoped services; own `resumes/{uid}/latest.pdf` |
| Reviewer strictly personal (`request.auth.uid === owner`) | ✅ `resumeTextFromStorage` exact-match `resumes/{uid}/latest.pdf`; cross-UID path → `invalid-argument` |
| Alumni cannot upload/replace/delete/review a student's resume | ✅ `PortfolioReadOnlyView` renders View Resume only; no write actions; storage/firestore rules deny |
| Alumni cannot modify student ATS / create review on student's behalf | ✅ rules + callable identity |
| Review history isolated per UID (`users/{uid}/resumeReviews`) | ✅ `firestore.rules` owner-scoped + `ResumeHistoryService`; collectionGroup teacher read only |
| Role immutability (F1) | ✅ `canWriteRole` guard in `firestore.rules` |
| Alumni directory / teacher reads | ✅ as designed (M2 whole-doc caveat documented) |
| Client never sends a UID for authorization | ✅ `ResumeReviewService.reviewResume` no longer transmits `userId`; callable derives from auth |

**Unverified in this session** (read-only scope at audit time): `EditPortfolioScreen` and the six manager screens (`projects/certifications/experience/achievements` + `career_preferences`, `social_links` sub-screens). The v8.5.2 Alumni flow routes through `studentPortfolioRoute` → its **Edit action** → `editPortfolioRoute`. `StudentPortfolioScreen` itself is role-agnostic, but the edit screen and managers need explicit verification — **any role gate or student-only assumption inside them would break the Alumni portfolio edit path**. This is the one gap in audit coverage; verify before declaring Alumni editing complete.

> **v8.6 RESOLVED (B10)**: `EditPortfolioScreen`, `ProjectsManagerScreen`, `CertificationsManagerScreen`, `ExperienceManagerScreen`, `AchievementsManagerScreen`, plus the in-file `career_preferences`/`social_links` sub-sections were all read. None branch on `role`; each writes through the shared `PortfolioProvider` → `PortfolioService.savePortfolio` (UID-scoped, role-agnostic). Alumni portfolio editing is confirmed safe.

---

## 4. Data Flow — Alumni Review (v8.5.2 target path, traced)

1. Alumni taps "My Portfolio" (new tile, `profile_view.dart` A3) → `studentPortfolioRoute` → `StudentPortfolioScreen` (reads signed-in `PortfolioProvider`).
2. Portfolio → Resume → Replace/Upload → `ResumeUploadScreen` → `PortfolioProvider.uploadResume` → `ResumeService.uploadResume` → `StorageService` `resumes/{uid}/latest.pdf` (5 MB PDF owner-write rule) → per-section Firestore diff.
3. Resume → (Reviewer entry) `resumeReviewRoute` → `ResumeReviewView` → "Review Uploaded Resume" → `storagePath = portfolio.resume.storagePath` (fallback `resumes/${currentUserId}/latest.pdf`) → `ResumeReviewProvider.submitReview(storagePath:)`.
4. `reviewResume` callable → `request.auth.uid` → exact path match → Admin SDK download ≤ 5 MB → `pdf-parse` → text (≥100 chars, ≤5000) → existing AI/ATS pipeline → `{review, usage}`.
5. Client `_saveToHistory` → `users/{uid}/resumeReviews` → **trigger** → ATS merge into `portfolio.resume` (A2, any role) + activity + engagement.
6. Dashboard `ResumeSummaryCard` (A4) shows Latest ATS / Review count / Last Review — from merged metadata; Alumni pull-to-refresh calls `PortfolioProvider.refresh()`.

**Placement snapshots are untouched by this flow** — `resumes/{uid}/snapshots/app_{applicationId}.pdf` is immutable at apply time; replacing `latest.pdf` never modifies snapshots. ✅

---

## 5. Firestore Indexes — Missing-from-Repo Audit

`firestore.indexes.json` declares: notes (uploadedBy/uploadedAt), recommendations (isActive/score/createdAt), notifications (type/createdAt ASC+DESC), opportunities (isActive/applicationDeadline; company/isActive/postedAt), mentorship_requests (status/createdAt), applications (userId/appliedAt), placements (isActive/postedAt; company/isActive/postedAt).

**Queries in code WITHOUT a matching declared index:**

| Query (file) | Required composite | Repo? |
|---|---|---|
| `chats.where(participantIds, arrayContains: userId).orderBy(lastMessageAt, desc)` — `chat_service.dart` (stream + once) | `chats: participantIds ASC / lastMessageAt DESC` | ❌ **MISSING** |
| `opportunities.where(isActive, ==true).orderBy(postedAt, desc)` — `opportunity_service.dart` (getActive/getRecent/stream) | `opportunities: isActive ASC / postedAt DESC` | ❌ **MISSING** |
| `opportunities.where(alumniId, ==X).orderBy(postedAt, desc)` — `opportunity_service.dart` (getAlumni/stream) | `opportunities: alumniId ASC / postedAt DESC` | ❌ **MISSING** |
| `opportunities` search combos (jobType/location + isActive + orderBy) | several composites | ❌ **MISSING** |
| `mentorship_requests.where(studentId, ==X).orderBy(createdAt, desc)` — `mentorship_service.dart` | `mentorship_requests: studentId ASC / createdAt DESC` | ❌ **MISSING** |
| `mentorship_requests.where(alumniId, ==X).orderBy(createdAt, desc)` | `alumniId ASC / createdAt DESC` | ❌ **MISSING** |
| `mentorship_requests.where(alumniId).where(status, ==).orderBy(createdAt, desc)` | `alumniId ASC / status ASC / createdAt DESC` | ❌ **MISSING** |
| `mentorship_requests.where(studentId).where(alumniId).where(status, whereIn)` — `hasActiveRequest` | `studentId ASC / alumniId ASC / status ASC` | ❌ **MISSING** |
| `recommendations` (users/{uid}/recommendations) where isActive + orderBy score desc + createdAt desc | `recommendations: isActive ASC / score DESC / createdAt DESC` | ✅ declared (collectionGroup COLLECTION scope serves the scoped query) |

**Effect**: These work on the deployed project only because v8.4.2's non-interactive deploy preserved pre-existing remote-only composite indexes. A fresh project, CI environment, or index re-deploy that drops undeclared indexes will break Chat lists, Opportunities browse/filter, and Mentorship tabs with "index required" errors. Add all of the above to `firestore.indexes.json`.

> **v8.6 RESOLVED (B6)**: all of the above composites are now declared in `firestore.indexes.json` (21 indexes total). `firebase deploy --only firestore:indexes` is included in B14.

**Rules audit** — `storage.rules` and `firestore.rules` verified:
- Storage write: owner + `request.resource == null` delete branch + `<= 5 MB` PDF — ✅ (C1/L3 fixed).
- Storage read: owner + teacher/alumni via Firestore role lookup with `exists()` guard — ✅ (C3 fixed).
- Firestore: F1 role immutability, F7 notifications owner-create, S5a owner-delete on notifications, resumeReviews owner + teacher collectionGroup read, applications collectionGroup teacher read — all ✅.
- Notifications subcollection `allow delete: if isOwner(userId)` — ✅ present (S5a).
- One gap worth noting: `match /{subcollection=**}` under `users/{userId}` grants the **owner** read/write to ALL current/future subcollections — acceptable given the F7 rules override for notifications and the resumeReviews-specific rule, but any future sensitive subcollection must remember the catch-all.

---

## 6. Cloud Functions — Detailed Findings

| Function | Verdict |
|---|---|
| `askAI` | Callable + auth-only identity (S6b). Rate/spam fail-open, soft daily limit. Pre-existing acceptable. |
| `logPlacementApplication` | Ownership validation on `resumeStoragePath` (`startsWith resumes/{uid}/`) — note it does **not** enforce `.pdf`/`latest.pdf` (harmless — copy fails non-fatally). Resume snapshot copy happens before the idempotency transaction (redundant on duplicates). `atsScoreAtApplication` coerced / range-checked. |
| `reviewResume` | Auth ✅; `checkUsage` flag ✅; exact-path storage review ✅; **v8.6 FIXED — quota consumed atomically (`consumeResumeQuota`) + rolled back on AI failure (`rollbackResumeUsage`)**; PDF truncation surfaced via `warning: "truncated"` in the callable response. |
| `resumeTextFromStorage` | Exact path = `resumes/{uid}/latest.pdf`; 5 MB metadata check; friendly `not-found` / `invalid-argument`; **v8.6 FIXED — short-text resumes now get an accurate "too short" message instead of the image-only mislabel**. |
| `generateResumeAnalysis` | Owner-scoped review read; cached-result path correct; usage increments only on new analysis — ✅. |
| `onProfileUpdatedRefreshAI` | **v8.6 FIXED (MED #6)** — `updatedAt` compared by value via `.toMillis()` (string fallback); `changed` is now only true for real diffs. |
| `onResumeReviewCreatedRefreshMatches` | v8.5.2 A2 fix verified correct; **v8.6 FIXED — phantom-portfolio guard added (merge only when `userData.portfolio.resume` exists)**; engagement write contention (MED #9) remains a documented Known Limitation. |
| `refreshRecommendations` (new callable) | **v8.6 ADDED (MED #7)** — single client entry point delegating to the server engine; auth-uid-scoped. |
| `onOpportunityPostedNotifyStudents` | Correct server-side notification; unbounded student query — batches at 400, fine at current scale; **v8.6 FIXED — the redundant client-side twin in `OpportunityService` was removed (HIGH #1)**. |
| `onMentorshipRequestCreated` / `ResponseNotifyStudent` / `onChatMessageCreated` | Deterministic doc IDs = idempotent; 30-day backfill guard on chat; ✅. |
| Schedulers | `autoExpireOpportunities` index covered; `sendInactivityReminders` index covered; `recomputeEngagementScores` sequential iteration — timeout risk at scale (LOW, deferred). |
| `refreshRecommendationsForStudent` | **v8.6 RESOLVED (MED #7)** — now the single writer; client engine removed. |

---

## 7. Routing Audit

All 40+ routes declared in `lib/constants/routes.dart` are registered in `main.dart` (`routes:` or `onGenerateRoute`).
✅ `resumeReviewDetailRoute`, `chatRoute`/`chatDetailRoute`, `completeMentorshipRoute` argument handling in `onGenerateRoute` — correct with fallbacks.
✅ `studentPortfolioRoute`, `editPortfolioRoute`, six managers, `resumeUploadRoute`, `portfolioReadOnlyRoute` — registered.
✅ `portfolioReadOnlyRoute` consumers pass a String uid (`mentorship_requests_view.dart` → `request.studentId`).
⚠️ `profileRoute` and `profileViewRoute` both map to `ProfileView` (duplicate alias — harmless).
No dangling route references found.

---

## 8. Edge & Boundary Cases

- **Replace resume**: `version` increments; `latestATSScore` correctly nulled; **v8.6 FIXED (HIGH #4)** — `reviewCount`/`lastReviewAt` carried forward from the previous portfolio resume metadata.
- **Delete resume**: `copyWithoutResume()` clears all resume metadata; idempotent; rules allow owner delete (S1a). ✅
- **5 MB boundary**: `<= 5 MB` client and rule — aligned. ✅
- **storagePath-only legacy resumes**: `ResumeService.getResumeUrl` resolves via Storage; apply dialog + preview + read-only all use it (S4c/N2). ✅
- **Concurrent quota**: **v8.6 FIXED (MED #8)** — check+increment in a single transaction.
- **0-byte / wrong-type files**: client + server + rules all reject. ✅
- **Image-only PDFs**: friendly `invalid-argument`, no OCR (documented limitation). ✅
- **Inverted dates**: guarded in projects, preview, read-only (F10/M9) — the experience manager includes the guard too. ✅
- **Empty portfolio feed**: `PortfolioProvider` stale-stream guards (v8.4.4 / v8.4.8) verified intact in `_listenToPortfolio` + `refresh`. ✅
- **Teacher on portfolio**: no tile (M5); provider initialized but unused. ✅

---

## 9. Validation Status (as recorded; not re-run in this session)

- `flutter analyze` → recorded 0 errors / 0 warnings (68 pre-existing info lints).
- `flutter test` → recorded **83/83** (71 existing + 12 `alumni_resume_review_test.dart`).
- `node --check functions/index.js` → recorded pass.

> **v8.6 B12 re-validation**: see `docs/todo.md` B12 for the freshly run results (`node --check` re-run after all v8.6 function edits; `flutter analyze` / `flutter test` re-run).

- Deployment → **NOT deployed** (v8.5.2 trigger change + v8.6 functions/indexes pending).

---

## 10. Prioritized Fix List (next version / Act Mode)

| # | Sev | Item |
|---|-----|------|
| 1 | 🔴 | Deploy the A2 trigger: `firebase deploy --only functions --non-interactive` (fixes Alumni ATS in production). |
| 2 | 🟠 | Remove the redundant client-side cross-user notification batch in `OpportunityService.createOpportunity` (Bug 5 pattern — v8.4.3 missed it). |
| 3 | 🟠 | Fix `ResumeReviewProvider`: retain + cancel the connectivity `StreamSubscription` in `reset()`/`dispose()` with a `_isDisposed` guard (apply the M5 fix). |
| 4 | 🟠 | Quota integrity in `reviewResume`: roll back `trackResumeUsage` on AI failure (or increment after success). |
| 5 | 🟠 | Preserve `reviewCount`/`lastReviewAt` across resume replacement (`ResumeService.uploadResume`: carry forward from `previousPortfolio.resume`). |
| 6 | 🟠 | Add the missing composite indexes to `firestore.indexes.json` (§5 table) and deploy `firestore:indexes`. |
| 7 | 🟡 | Fix `onProfileUpdatedRefreshAI` `updatedAt` comparison to a value comparison (`toMillis()`/`isEqual`). |
| 8 | 🟡 | Reconcile the two recommendation engines (server vs client) or gate one to avoid clobbering. |
| 9 | 🟡 | Verify `EditPortfolioScreen` + six manager screens for hidden role gates (Alumni edit path). |
| 10 | 🟡 | Make the quota check+increment atomic in `reviewResume`. |
| 11 | 🔵 | Phantom-portfolio creation on no-portfolio reviews; short-PDF message; silent PDF truncation notice; badge threshold alignment; snapshot-copy-before-idempotency; ProfileView logout provider-reset consistency. |

> **v8.6 disposition**: items 2–8, 10, and 11 (phantom-portfolio guard, short-PDF message, truncation warning, badge ≥85, ProfileView logout reset) — **FIXED**. Item 9 — **VERIFIED clean**. Item 1 — code verified, deployment carried into B14. See `docs/issues.md` v8.6 section for the full log.

---

## 11. Improvements for the Project (roadmap)

**Correctness / stability first**
1. **Enable App Check** (long-standing): install `firebase_app_check`, configure Play Integrity + DeviceCheck, opt the rules in — closes the remaining forged-request surface and removes the AppCheck warning on every login.
2. **Materialize teacher analytics** — replace the per-student N+1 loops (`getStudentResumeData`, `getEngagementAggregates`, `getDepartmentAnalytics`) with a Cloud Function-maintained `teacher_analytics/summary` doc; scale past the free tier.
3. **Unify the two recommendation engines** — keep the server-side `refreshRecommendationsForStudent` as canonical and stop the client from recomputing (or vice-versa), then write a contract test asserting a single writer. *(v8.6 delivered the single-writer contract; a contract test can be added in a later pass.)*
4. **Scheduled recompute** — shard by batches / `Promise.all` with concurrency caps, or trigger-per-user on write instead of a daily full scan.
5. **Move notifications fully server-side** — audit every remaining client-side cross-user write (like finding #2) and delete the dead ones.
6. **Index hygiene** — declare ALL composite indexes in the repo; add a CI check (`firestore.indexes.json` vs a query inventory) to prevent drift. *(v8.6 declared all 21; CI check is a follow-up.)*

**Product**
7. **Resume version history UI** — `resumes/{uid}/history/v{n}.pdf` + `historyPath` are pre-wired; copy-to-history on replace + a picker delivers the placement-snapshot "resume at apply time" for real.
8. **Clean up archived legacy views** — `lib/views/archived/` is the source of most of the 68 info lints; deleting it + migrating `withOpacity`/`value:` to `withValues`/`initialValue` gets to 0 clean.
9. **Add the missing contract tests** — EditPortfolio/manager role-agnosticism, opportunity-notification removal, quota-rollback path, write-amplification regression for the trigger.
10. **Seeder parity** — extend `seed.js` so Teacher portfolio drill-down + Alumni dashboard resume card have realistic data (`isDemoData: true`).

---

## 12. Files Inventory (most significant, this audit)

**v8.5.2 changed files (verified correct):** `functions/index.js` (A2), `lib/views/profile/profile_view.dart` (A3), `lib/views/dashboards/alumni_dashboard_view.dart` (A4), `test/alumni_resume_review_test.dart` (A5), `pubspec.yaml` (8.5.2+88), `docs/todo.md` / `docs/issues.md` / `docs/v8_workspace_tracker.md`.

**Bug sites identified (files to change next):** `lib/services/firestore/opportunity_service.dart` (#2), `lib/providers/resume_review_provider.dart` (#3), `functions/index.js` (#4 quota, #6 trigger, #8 race, #9 contention), `lib/services/firestore/resume_service.dart` (#5), `firestore.indexes.json` (#6), `lib/services/firestore/recommendation_service.dart` + `functions/index.js` (#7).

**v8.6 changed files:** `lib/services/firestore/opportunity_service.dart`, `lib/providers/resume_review_provider.dart`, `lib/services/firestore/resume_service.dart`, `lib/services/firestore/recommendation_service.dart`, `lib/views/profile/profile_view.dart`, `functions/index.js` (quota + callable + phantom guard + badge + short-PDF + timestamp), `firestore.indexes.json`, `docs/todo.md`, `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md`, `pubspec.yaml`.

**Key files NOT re-read this session (coverage gaps):** `lib/views/placements/placements_list_view.dart` apply dialog, `functions/ai/groqProvider.js`/`huggingfaceProvider.js`, `lib/providers/chat_provider.dart`, `lib/providers/ai_chat_provider.dart`. *(The EditPortfolio + manager coverage gap from this audit was closed in v8.6 B10.)*
