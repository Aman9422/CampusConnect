# CampusConnect — Workspace Tracker

## Status: IMPLEMENTATION COMPLETE — ✅ DEPLOYED (2026-08-09, v8.7: `firestore.rules` for `alumni_group_messages`)
## Version: CampusConnect v8.7.0+90 — Alumni Experience Simplification & Alumni Group Chat (2026-08-09)

---

## v8.7 — Alumni Experience Simplification & Alumni Group Chat

> Source: `docs/Task.md` (v8.7 goal) · Executed via `docs/todo.md` (Phase 1–5) · Architecture report: `project_info__19.md` (2026-08-09) · Issues log: `docs/issues.md` (v8.7 section) · Confirmation: `docs/confirmation.md` (v8.7 Resolution Banner)

### Objective

Simplify the Alumni experience based on the actual intended Alumni role. **Portfolio is a Student career-development feature.** Alumni use a lightweight profile (already required at registration) + an optional text-based AI Resume Review + the Alumni Community Chat. Alumni are no longer required to upload a PDF resume, maintain a portfolio, or enter education/projects/certifications/skills/experience/social links/career preferences into CampusConnect. The full Student Portfolio subsystem is unchanged.

### Why Alumni Portfolio access was removed

v8.5.2 deliberately routed Alumni into the Student Portfolio editing workflow (an Alumni "My Portfolio" profile tile + a dashboard `ResumeSummaryCard` wired to `PortfolioProvider` with upload/replace actions). The Alumni role is meant to be **low-friction** — a lightweight profile, an optional ATS text review, and Alumni community participation — not portfolio maintenance. This version removes/hides every Alumni-facing portfolio surface. This is a **role-based UI/access change only**: the Student Portfolio subsystem (`users/{uid}/portfolio` nested map, `resumes/{uid}/latest.pdf`, all 10 portfolio screens, read-only views, placement snapshots) is fully intact.

### What Shipped

| # | Item | Deliverable |
|---|------|-------------|
| P1 | **Role separation (UI/access)** | Alumni dashboard: `ResumeSummaryCard` + `PortfolioProvider` refresh removed; replaced with an **Alumni Community** primary card + quick action (Task §10). Alumni profile: the v8.5.2 "My Portfolio" tile removed — only Edit Profile remains (Task §11). `ResumeReviewView`: the uploaded-resume card / upload CTA is hidden for Alumni (`if (!isAlumni)`) — text-input only (Task §2/§5). The 7 Student Portfolio editing routes are wrapped in `_guardStudentPortfolio` in `main.dart` — Alumni who manually access them get a safe blocked view ("Portfolios are for Students" + CTA to Alumni Community) (Task §5/§14). `portfolioReadOnlyRoute` stays open so Alumni can still VIEW a Student's portfolio (Task §13). |
| P2 | **Alumni text-based Resume Reviewer** | Alumni paste resume text (≥100, ≤5000 chars — existing `ResumeReviewService` validation) → `ResumeReviewProvider.submitReview(resumeText:)` → the **SAME `reviewResume` callable** (Task §3). No second AI/ATS engine, no second resume storage. Quota (`resume_usage/{uid}`, atomic `consumeResumeQuota`) and history (`users/{uid}/resumeReviews`) are UID-scoped and reused unchanged (Task §4/§18). Cloud Function analytics already tags `source: "pasted"` vs `"uploaded"` (Task §19) — no function change. Student uploaded-PDF reviews are untouched. |
| P3 | **Alumni Group Chat** | New `alumni_group_messages/{messageId}` collection. `AlumniGroupChatService` — real-time `orderBy('createdAt')` stream (single-field order ⇒ **no composite index needed**, Task §16; client-side soft-delete filter avoids a `where('isDeleted')`+orderBy composite), `sendMessage` with `FieldValue.serverTimestamp()`, `deleteMessage` soft-delete. `AlumniGroupChatProvider` — ChatProvider lifecycle discipline: `initWithUser`/`reset`, `_isDisposed`, stream subscription cancelled on reset/dispose, `isSending`/`error` states. `AlumniGroupChatView` — Material 3 chat: sender name + initials avatar + timestamp, own messages right-aligned in primary color, date separators, empty/loading/error/sending states, **auto-scroll only when the message count grows**. `alumniGroupChatRoute` registered + `_guardAlumniGroupChat` (non-Alumni → denied view). |
| P4 | **Registry / lifecycle** | `AlumniGroupChatProvider` registered in `MultiProvider`; initialized in AuthGuard post-frame; **reset at all 5 logout sites** (AuthGuard fallback, Alumni dashboard, Profile view, Student dashboard, Teacher dashboard) — no Firestore permission errors from live listeners on logout. |
| P5 | **Security rules** | `firestore.rules` gained `alumni_group_messages`: read Alumni-only; create Alumni-only with `senderId == request.auth.uid`; update/delete own messages only (soft-delete). Students/Teachers/unauthenticated denied. Sender identity is authoritative from Firebase Auth — a client-supplied `senderId` never matches `request.auth.uid` and is rejected (Task §8). Existing rules not weakened; bottom catch-all deny retained. |
| P6 | **Version + docs** | `pubspec.yaml` `8.6.0+89` → `8.7.0+90` (Task §25). `docs/todo.md`, `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md` updated (Task §24). |

### Architecture (final)

**Student:** Dashboard → My Portfolio → Full Portfolio → Uploaded PDF Resume → Review Uploaded Resume (server extraction) → ATS → Review History → Placement Resume Snapshot. **Unchanged.**

**Alumni:** Dashboard → Lightweight Profile → Text Resume Reviewer (paste → existing `reviewResume` pipeline) → ATS / Feedback → Review History → Alumni Community Chat (single shared group). **No PDF, no portfolio, no metadata entry required.**

**Alumni → Student:** read-only portfolio access only (`portfolioReadOnlyRoute`) — no upload / replace / delete / review / ATS-write actions. Firestore + storage rules already enforce this (v8.5.2, unchanged).

### Files Changed

**Created:** `lib/models/alumni_group_message.dart`, `lib/services/firestore/alumni_group_chat_service.dart`, `lib/providers/alumni_group_chat_provider.dart`, `lib/views/chats/alumni_group_chat_view.dart`, `test/alumni_group_chat_test.dart` (17 tests), `test/alumni_resume_text_review_test.dart` (13 tests), `test/alumni_portfolio_access_test.dart` (8 tests)

**Modified:** `lib/constants/routes.dart` (`alumniGroupChatRoute`), `lib/main.dart` (`AlumniGroupChatProvider` wiring + AuthGuard init + logout resets + `_guardStudentPortfolio`/`_guardAlumniGroupChat` + blocked/denied views), `lib/views/dashboards/alumni_dashboard_view.dart` (Alumni Community card; removed `ResumeSummaryCard`/portfolio refresh), `lib/views/profile/profile_view.dart` (removed Alumni "My Portfolio" tile), `lib/views/resume_review_view.dart` (Alumni text-only reviewer), `firestore.rules` (`alumni_group_messages`), `pubspec.yaml` (`8.7.0+90`)

**Unchanged by design:** `firestore.indexes.json` (no new index), all Student portfolio screens, `ResumeReviewProvider`/`ResumeReviewService` (quota + history reused as-is). `functions/index.js` was untouched in the v8.7 core pass (no AI/ATS/quota/history changes); the only function change is the v8.7.1 role-aware badge rule (see the v8.7.1 section below).

### Validation (Task §23)

- `flutter analyze` → **0 errors / 0 warnings** (68 pre-existing info lints, none in v8.7 files)
- `flutter test` → **124/124 passed** (83 pre-existing + 41 new v8.7/v8.7.1 tests: group-chat security/state contract, alumni text-review pipeline/quota/history contract, alumni portfolio access + read-only, role-aware badge title)
- `node --check functions/index.js` → pass (functions unchanged in v8.7)
- `dart format` → clean on all changed files

### Deployment Status

✅ **DEPLOYED 2026-08-09** — `firebase deploy --only firestore:rules --non-interactive` **SUCCESS** (`rules file firestore.rules compiled successfully`; `released rules firestore.rules to cloud.firestore`). The `alumni_group_messages` **Alumni-only** rules (read Alumni-only; create Alumni-only with `senderId == request.auth.uid`; update/delete own messages only) are **live in production**. Functions were deployed in the v8.7.1 badge-fix pass (15/15 updated). On-device manual matrix per `docs/Task.md` §22 remains: Student portfolio regression, Alumni text review, Alumni Community chat (send/receive/logout-login), Student/Teacher/anon chat denial, Alumni → Student read-only.

---

## v8.7.1 — Alumni Dashboard Badge Title Fix (2026-08-09)

> Reported by the user during v8.7 review: the Alumni dashboard's Engagement card showed the Student-flavored badge **"Active Student"**.

### Root cause

Both badge engines hardcoded "Active Student": client `EngagementService._buildBadges` (`lib/services/firestore/engagement_service.dart`) and the server `recomputeEngagementSummary` (`functions/index.js` → `engagement_summary/summary`). Alumni share the same engagement pipeline, so every Alumni saw the Student-oriented title.

### Fix

Role-aware activity badge — Alumni now see **"Active Alumni"**; students keep "Active Student". Applied identically in BOTH writers so the badge never flickers between client/server recompute (same class as the v8.6 badge-threshold conflict):

- `lib/services/firestore/engagement_service.dart` — `recomputeEngagement` passes `profile.role ?? UserRole.student` into `_buildBadges`, which computes the title/description from the role; new public static `EngagementService.activeBadgeTitle(UserRole)` is the single source of truth for the client.
- `functions/index.js` — `recomputeEngagementSummary` computes `activeTitle`/`activeDescription` from `userData.role === "alumni"` before building the badge list.
- Badge `id`/`type` (`active_student` / `activeStudent`) untouched — no schema change. Existing stored summaries self-heal on the next recompute (app init, dashboard refresh, or the daily `recomputeEngagementScores` scheduler).

### Files

`lib/services/firestore/engagement_service.dart`, `functions/index.js`, `test/alumni_badge_title_test.dart` (new, 3 tests).

### Validation & Deployment

- `flutter analyze` → **0 errors / 0 warnings** (68 pre-existing info lints)
- `flutter test` → **124/124 passed** (121 + 3 new badge-title tests)
- `node --check functions/index.js` → pass
- `dart format` → clean
- ✅ **DEPLOYED 2026-08-09** — `firebase deploy --only functions --non-interactive` **SUCCESS** (15/15 functions updated; server badge rule live in production)

---

## v8.6 — Final Audit & Architecture Stability Fixes

> Source: `project_info__17.md` / `project_info__18.md` (2026-08-09 final audit) · Executed via `docs/todo.md` (B1–B14) · Issues log: `docs/issues.md` (v8.6 section) · Confirmation: `docs/confirmation.md` (v8.6 Resolution Banner)

### Objective

Resolve every actionable item on the audit's Prioritized Fix List (§10) — 1 critical deploy gap, 5 HIGH, 5 MEDIUM, and a curated set of LOW items — restoring single-writer / single-source-of-truth contracts and closing the audit's one coverage gap (EditPortfolio + manager screens).

### What Shipped

| # | Item | Fix |
|---|------|-----|
| B2 | **HIGH 1** — `OpportunityService` client-side cross-user notification batch | Removed entirely — server trigger `onOpportunityPostedNotifyStudents` is the only notifier (no more `PERMISSION_DENIED` noise, no 500-write batch cap risk) |
| B3 | **HIGH 2** — `ResumeReviewProvider` connectivity subscription leak | M5 fix applied: retained `_connectivitySubscription`, `_isDisposed` guard, cancelled in `reset()`/`dispose()` |
| B4 | **HIGH 3 + MED 8** — `reviewResume` quota consumed before AI call + non-atomic check | `consumeResumeQuota` (single transaction check+increment) + `rollbackResumeUsage` on AI failure; `getResumeUsage` kept for `checkUsage` only |
| B5 | **HIGH 4** — resume replacement wiped `reviewCount`/`lastReviewAt` | `ResumeService.uploadResume` carries both forward from the previous portfolio resume metadata |
| B6 | **HIGH 5** — missing composite indexes | All 21 composites declared in `firestore.indexes.json` (chats, opportunities ×5, mentorship_requests ×4 + existing 9) |
| B7 | **MED 6** — `onProfileUpdatedRefreshAI` Timestamp identity comparison | Value comparison via `.toMillis()` (string fallback for legacy values) |
| B8 | **MED 7** — two competing recommendation engines | Single-writer restored: new `refreshRecommendations` callable; client `RecommendationService.refreshRecommendations` delegates (no client-side writes); provider reads the Firestore stream |
| B9 | **MED 10** — ProfileView logout reset fewer providers | `_handleProfileLogout` now resets the same provider set as the dashboard logout |
| B10 | **MED gap #9** — EditPortfolio + manager screens unverified | All 5 screens + in-file career-preferences/social-links sub-sections read — **no role gates**; writes go through role-agnostic `PortfolioProvider`/`PortfolioService` |
| B11 | **LOW** — short-PDF message, phantom-portfolio guard, badge threshold | `resumeTextFromStorage` distinguishes "too short" from image-only; ATS merge only when `portfolio.resume` exists; server `profile_pro` badge threshold aligned to ≥85; PDF truncation surfaced via callable `warning: "truncated"` |

### Files Changed

- `lib/services/firestore/opportunity_service.dart` — B2
- `lib/providers/resume_review_provider.dart` — B3
- `functions/index.js` — B4/B7/B8/B11 (`consumeResumeQuota`, `rollbackResumeUsage`, timestamp value-compare, `refreshRecommendations` callable, phantom-portfolio guard, short-PDF message, badge ≥85)
- `lib/services/firestore/resume_service.dart` — B5
- `firestore.indexes.json` — B6 (21 indexes)
- `lib/services/firestore/recommendation_service.dart` — B8 (client delegates; removed the competing client scoring engine)
- `lib/views/profile/profile_view.dart` — B9
- `docs/todo.md`, `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md`, `pubspec.yaml` — version `8.5.2+88` → `8.6.0+89`

### Validation (freshly re-run in B12)

- `flutter analyze` → **0 errors / 0 warnings** (68 pre-existing info lints, none in changed files)
- `flutter test` → **83/83 passed**
- `node --check functions/index.js` → pass
- `dart format` → clean on all changed files

### Deployment Status

✅ **DEPLOYED 2026-08-09 (B14)** — `firebase deploy --only functions --non-interactive` **SUCCESS** (15/15 functions updated/created, incl. the new `refreshRecommendations` callable); `firebase deploy --only firestore:indexes --non-interactive` **SUCCESS** (21 indexes deployed; 1 pre-existing remote index + 2 field overrides preserved). This also closed the 🔴 v8.5.2 deploy gap (A2 trigger) — Alumni ATS sync is live in production. On-device manual matrix remains.

---

## v8.5.2 — Alumni Resume Reviewer & Portfolio Integration

> Source: `docs/Task.md` (v8.5.2 goal) · Executed via `docs/todo.md` (A1–A8) · Audit: `project_info__16_v8.5.2_Alumni_Resume_Reviewer_Audit.md`

### Objective

Ensure Students AND Alumni can independently review their own uploaded resume (My Portfolio → Resume → Review Uploaded Resume → ATS → Review history), while Alumni viewing a student's portfolio remain strictly read-only. Integration + hardening only — no second pipeline, no second storage location, no duplicate ATS data, no UI redesign (Task §19).

### Root Cause (A1 audit — documented before fixing)

**Cloud Function trigger `onResumeReviewCreatedRefreshMatches` early-returned `if (userData.role !== "student")`** before merging `portfolio.resume.{reviewCount,lastReviewAt,updatedAt,latestATSScore}`. Alumni reviews therefore:

1. landed in `users/{uid}/resumeReviews` ✅ (client `_saveToHistory` — role-agnostic)
2. incremented `resume_usage/{uid}` ✅ (callable — role-agnostic)
3. **never merged ATS → `users/{uid}/portfolio.resume`** ❌ → Alumni portfolio/dashboard showed `Latest ATS —` and 0 reviews.

Also two UX gaps: `ProfileView._buildAlumniProfile` had no "My Portfolio" tile (student-only), and the Alumni dashboard had no `ResumeSummaryCard` surface.

### Architecture Decision

- **Single source of truth unchanged**: `users/{uid}/portfolio.resume` for resume metadata + ATS, for BOTH roles (Task §7).
- **ATS merge is role-agnostic**: runs for any review author. Student-only enrichment (`refreshRecommendationsForStudent`) stays gated to `role === "student"`; activity log + engagement recompute run for every author (Alumni dashboard reads those).
- **Reviewer stays strictly personal** (`request.auth.uid === owner`, exact `resumes/{uid}/latest.pdf`) — the server remains authoritative; an Alumni can never review a student's resume.
- **Read-only student portfolio preserved**: `PortfolioReadOnlyView` (View Resume only) + firestore/storage rules (alumni read, never write).

### Files Changed

- `functions/index.js` — A2: relaxed the role gate in `onResumeReviewCreatedRefreshMatches` (ATS merge for any role; recommendations still student-gated)
- `lib/views/profile/profile_view.dart` — A3: "My Portfolio" tile added to the Alumni profile → `studentPortfolioRoute`
- `lib/views/dashboards/alumni_dashboard_view.dart` — A4: `ResumeSummaryCard` added (Open Portfolio / Upload-Replace routed to shared `studentPortfolioRoute`/`resumeUploadRoute`); portfolio refresh added to pull-to-refresh
- `test/alumni_resume_review_test.dart` — A5: NEW, 12 contract tests (ATS merge for alumni, student-only gating preserved, own storage path enforced, history isolated per UID, student regression)
- `pubspec.yaml` — version `8.5.0+86` → `8.5.2+88`
- `docs/todo.md`, `docs/issues.md`, `docs/v8_workspace_tracker.md`

### Student Behavior

Unchanged: My Portfolio → Resume → Review Uploaded Resume → PDF analyzed → ATS → Review history; dashboard `ResumeSummaryCard`; placement snapshot with `resumeVersion`/`resumeStoragePath`/`atsScoreAtApplication`; `onResumeReviewCreatedRefreshMatches` still refreshes their recommendations/engagement.

### Alumni Behavior

Equivalent personal flow (Task §3): Dashboard `ResumeSummaryCard` (Upload / Open / Review / ATS) → Portfolio → Resume → Review Uploaded Resume → PDF analyzed → ATS persisted into `users/{uid}/portfolio.resume` → Review history under `users/{uid}/resumeReviews` (own-UID only). Manual-paste fallback preserved (Task §6). No Alumni-only storage system — reuses `resumes/{uid}/latest.pdf`.

### Read-Only Student Portfolio Behavior (Alumni → Student)

Strictly read-only: open portfolio, view resume (View Resume), see allowed ATS/skills/projects/etc. NO upload / replace / delete / review / ATS-write actions (Task §3/§11). `reviewResume` rejects `resumes/OTHER_USER/latest.pdf` server-side even if a malicious client supplies the path.

### Security

- Personal reviewer: `request.auth.uid == current user's UID`
- Storage: owner-only writes `resumes/{uid}/latest.pdf`; teachers/alumni read via Firestore role lookup
- Reviewer: exact-match `resumes/{uid}/latest.pdf` (cross-UID rejected)
- Review history: `users/{uid}/resumeReviews` owner-scoped (firestore.rules + ResumeHistoryService)
- Alumni cannot modify a student's portfolio (read-only)

### Validation

- `flutter analyze` → **0 errors / 0 warnings** (68 pre-existing info lints, none in changed files)
- `flutter test` → **83/83 passed** (71 existing + 12 new alumni tests)
- `node --check functions/index.js` → pass

### Deployment Status

✅ **DEPLOYED 2026-08-09** (v8.6 B14) — `firebase deploy --only functions --non-interactive` **SUCCESS**. The A2 trigger (ATS merge for any role) is live in production; the v8.6 deploy also shipped the new `refreshRecommendations` callable and quota/rollback helpers in the same codebase.

### Remaining Manual Tests (device)

Planned: Alumni upload → review PDF → ATS appears in Alumni portfolio + dashboard → review history → replace resume → review again; Alumni → Student portfolio read-only (no upload/replace/delete/review); cross-UID review attempt rejected; Student regression (upload/review/ATS/dashboard/placement snapshot).

---

## Phase Progress

| Phase | Description | Status |
|-------|-------------|--------|
| 0–8 | v8.2 Teacher Intelligence & Analytics workspace | ✅ |
| 9 | **v8.2.1 — Data Pipeline Fix** | ✅ |
| 10 | **v8.2.2 — Layout Fix & Data Pipeline Investigation** | ✅ |
| 11 | **v8.3 — Codebase Architecture Documentation** | ✅ |
| 12 | **v8.3 — Firestore Demo Data Seeder** | ✅ |
| 13 | **v8.4 — Student Resume Portfolio** | ✅ |
| 14 | **v8.4.6 — Final Audit Fixes (F1–F12)** | ✅ |
| 15 | **v8.4.1 — Resume Portfolio & Firebase Storage Foundation** | ✅ |
| 16 | **v8.4.2 — Issues Hardening (S1–S7)** | ✅ **DEPLOYED** (2026-08-07) |
| 17 | **v8.4.3 — Manual-Test Bug Fixes (MB1–MB10) + notification triggers deployed** | ✅ **DEPLOYED** (2026-08-07) |
| 18 | **v8.4.4 — On-Device Re-Verification Fix (MB2R)** | ✅ |
| 19 | **v8.4.8 — Portfolio Read Failure & Refresh-Wipe Fix (MB11–MB16)** | ✅ |
| 20 | **v8.4.9 — Flattened-Shape Portfolio Read Fix + Email Backfill (MB17–MB19)** | ✅ |
| 21 | **v8.5 — Resume Reviewer Integration & PDF Intelligence (R1–R9, MB7 delivered)** | ✅ implementation — ⏳ deployment pending |

**Overall Progress: 100% (implementation)**

---

## v8.5 — Resume Reviewer Integration & PDF Intelligence

> Source: `docs/Task.md` (v8.5 goal) · Executed via `docs/todo.md` (R1–R10) · Audit: `project_info__15_v8.5_R1_Resume_Review_Integration_Audit.md`

### Objective

Make the student's uploaded resume `resumes/{uid}/latest.pdf` the **actual source** for the existing Resume Reviewer. Complete the unfinished v8.4.3 item **MB7 — PDF → text for Resume Review** server-side: the reviewer consumes the uploaded PDF directly instead of pasted text, while preserving the entire existing ATS/portfolio/history/snapshot architecture.

### Architecture

- **Nested portfolio map preserved** (`users/{uid}/portfolio.resume`) — no redesign, no second storage arch.
- **Canonical resume unchanged**: `resumes/{uid}/latest.pdf` (Firebase Storage).
- **Server-side extraction**: the `reviewResume` callable now accepts an optional `storagePath`. When present:
  1. `request.auth.uid` (authoritative) is compared with the owner embedded in the path — exact match `resumes/{uid}/latest.pdf` only.
  2. Admin SDK downloads the PDF (5 MB cap via `getMetadata` size check).
  3. `pdf-parse@^1.1.1` (deep-require `pdf-parse/lib/pdf-parse.js`) extracts text, `\u0000` stripped, trimmed.
  4. Image-only/empty/unextractable PDFs → friendly `invalid-argument` error (no OCR, no content logging).
  5. Extracted text flows through the **EXISTING** AI/ATS pipeline; the response keeps the same `{review, usage}` shape.
- **Client**: `ResumeReviewService.reviewResume` gained an optional `storagePath` (mutually exclusive with pasted text); `ResumeReviewProvider.submitReview` forwards it; the Resume Reviewer UI added **Review Uploaded Resume**, **Open Uploaded Resume**, **Replace Resume**, review count + latest ATS, and a no-resume fallback banner (manual paste preserved).
- **ATS/history/snapshots**: unchanged — the PDF review returns the same shape, so `onResumeReviewCreatedRefreshMatches` still merges `portfolio.resume.{latestATSScore,reviewCount,lastReviewAt,updatedAt}`, reviews still land in `users/{uid}/resumeReviews` via the existing client-side `_saveToHistory`, placement applications keep immutable `resumes/{uid}/snapshots/app_*.pdf` snapshots.

### Subtasks (R1–R10)

| # | Subtask | Status |
|---|---------|--------|
| R1 | Architecture/data-flow audit | ✅ |
| R2 | PDF extraction (server-side) | ✅ `pdf-parse`, verified on Node vs. real Chromium PDF |
| R3 | Callable `reviewResume(storagePath)` + client forwarding | ✅ |
| R4 | Resume Reviewer UI (Review/Open/Replace + fallback) | ✅ |
| R5 | ATS/portfolio synchronization | ✅ (unchanged shape; trigger still merges) |
| R6 | Review history | ✅ (existing `resumeReviews` reuse) |
| R7 | Resume replacement verification | ✅ (reads `latest.pdf` at review time; snapshots untouched) |
| R8 | Error handling (`not-found`,`invalid-argument` mapped; `finally` resets) | ✅ |
| R9 | Security tests + existing suite | ✅ 6 new tests; 71/71 total |
| R10 | Validation/deploy/manual pass | ⏳ deploy + manual matrix pending |

### Files Changed

- `functions/package.json` — added `pdf-parse@^1.1.1`
- `functions/index.js` — `resumeTextFromStorage(uid, storagePath)` + `reviewResume` storagePath branch; unchanged: quota, quota check order, `{review, usage}` shape, analytics event (now includes `source: "uploaded"`)
- `lib/services/ai/resume_review_service.dart` — `storagePath` param, server `not-found` mapping, mutual-exclusion validation
- `lib/providers/resume_review_provider.dart` — `storagePath` passthrough audit (validation matches service)
- `lib/views/resume_review_view.dart` — uploaded-resume card actions (Review/Open/Replace), review count + ATS, no-resume fallback banner
- `test/resume_review_storage_path_test.dart` — NEW, 6 storage-path security contract tests
- `docs/todo.md`, `docs/issues.md`, `docs/v8_workspace_tracker.md`, `pubspec.yaml` (8.4.1+85 → 8.5.0+86)

### Validation

- `flutter analyze` → **0 errors / 0 warnings** (69 pre-existing info lints unchanged)
- `flutter test` → **71/71 passed** (65 existing + 6 new storage-path tests)
- `node --check functions/index.js` → pass
- `pdf-parse` smoke test → extracted expected text from a real Chromium-generated PDF on Node

### Deployment Status

⏳ Not yet deployed — `firebase deploy --only functions` is the pending step (needs Firebase auth/project access; see final report).

### Manual Verification Status

⏳ Pending on-device matrix (`docs/Task.md`): existing resume → review → ATS; dashboard (Resume Uploaded/Latest ATS/Last Review/Resume Age); replace resume; placement snapshot immutability; security cross-UID attempt; bad/image PDF friendly error.

### Known Limitations

1. No OCR — scanned/image-only PDFs return the friendly "image-based" error (task-mandated).
2. `pdf-parse` bundles 2017-era pdf.js; its xref parser rejected a synthetic minimal PDF but parses real Chromium/Word PDFs. If a real upload ever reports `bad XRef entry`, re-render client-side or switch extractor (documented in `docs/issues.md`).
3. `metadata.parserVersion` on `ResumeMetadata` remains a placeholder — PDF text is extracted server-side per review, not cached.

---

## v8.4.1 — Resume Portfolio & Firebase Storage Foundation

> Source: `docs/Task.md` · Executed via `docs/todo.md` (T0–T7) · Gap baseline: `project_info__12.md`

### Objective

Implement the Resume Portfolio system per `docs/Task.md`, making the student's resume the central asset of CampusConnect and the single source of truth for the roadmap (Resume Reviewer v8.5, Resume Intelligence v8.6, AI Recommendations v8.7, Teacher Analytics 2.0, Alumni Mentorship, Placement Snapshot). Non-breaking: existing dashboards, ATS review, role permissions, and Material 3 theming all preserved.

### Architecture Decision (T0)

**Kept the existing nested-map design** (`users/{uid}/portfolio.resume`) instead of the spec's dedicated `users/{uid}/resume/metadata` document. Rationale: backward compatibility with dashboards, read-only views, and F5 per-section saves; avoids the M2 whole-doc-read privacy caveat of a new subcollection. The deviation is documented in `docs/Task.md`. Everything else aligns with the spec:

- Storage file renamed to `resumes/{uid}/latest.pdf` (Phase 1)
- All spec metadata fields added to `ResumeMetadata` (Phase 2)
- Dedicated `ResumeService` orchestration layer (Phase 4)
- Placement resume snapshot at apply time (Phase 8)

### What Shipped

| Task | Deliverable | Spec Phase |
|------|-------------|------------|
| **T1** | `ResumeMetadata` extended: `storagePath`, `fileSize`, `mimeType`, `uploadedAt`/`updatedAt`, `latestATSScore`, `reviewCount`, `lastReviewAt`, `isDemoData`; storage file is now `resumes/{uid}/latest.pdf`; original picked `fileName` preserved; tolerant `fromMap` with legacy-key fallbacks (`uploadDate`/`lastUpdated`/`atsScore`); `ResumeUploadResult` now carries path/size/mime + original name | 1 + 2 |
| **T2** | New `lib/services/firestore/resume_service.dart` — upload/delete orchestration (storage + per-section metadata diff via `PortfolioService`), `downloadResume`/`getResumeUrl`/`checkResumeExists`/`readMetadata`, version-history path helper; `StorageService` gained `downloadUrlFromPath`/`downloadBytes`; `PortfolioProvider` upload/delete now delegate to it (F5/H4 + F6 guards preserved) | 4 |
| **T3** | `CareerPreferences.careerObjective` + `PortfolioModel.languages` (+ edit UI); Resume Status chip, Resume Metadata rows (storage path, size, MIME, version, review count, last review), Latest ATS + Resume Age in student portfolio and read-only views | 3 + 10 |
| **T4** | New `ResumeSummaryCard` (`lib/widgets/resume_summary_card.dart`) on `_StudentDashboardTab` — Resume Uploaded status chip, Latest ATS, Resume Age, Last Review, Open Portfolio, Upload/Replace | 5 |
| **T5** | Placement resume snapshot: `logPlacementApplication` Cloud Function, `Application` model (`studentId` alias + snapshot fields), `applyForPlacementDirect`, `PlacementsProvider.applyForPlacement` persist `resumeVersion`/`resumeStoragePath`/`atsScoreAtApplication` read from the student's portfolio resume at apply time; apply dialog uses the uploaded resume, text fallback only when none exists | 8 |

**Security (Phase 9):** unchanged and satisfied — students write only their own `resumes/{uid}/latest.pdf`; teachers/alumni read via Firestore role lookup; denials for anonymous and everything else.

### Files

**Created:** `lib/services/firestore/resume_service.dart`, `lib/widgets/resume_summary_card.dart`

**Modified:** `lib/models/portfolio/resume_metadata.dart`, `lib/models/portfolio/portfolio_model.dart`, `lib/models/portfolio/career_preferences.dart`, `lib/services/storage/storage_service.dart`, `lib/providers/portfolio_provider.dart`, `lib/views/portfolio/student_portfolio_screen.dart`, `lib/views/portfolio/portfolio_read_only_view.dart`, `lib/views/portfolio/edit_portfolio_screen.dart`, `lib/views/dashboards/student_dashboard_view.dart`, `functions/index.js`, `lib/models/application.dart`, `lib/services/firestore/placements_service.dart`, `lib/providers/placements_provider.dart`, `lib/views/placements/placements_list_view.dart`, `pubspec.yaml`

**Version (T6):** `8.4.0+84` → `8.4.1+85`

### Validation (T7)

- `flutter analyze` → **0 errors / 0 warnings** on every subtask (T1–T5); the 69 pre-existing info-level lints are unchanged from baseline
- Acceptance matrix per `docs/Task.md` Phase 12: upload / replace / download / delete, metadata updates, teacher + alumni read, no cross-student access, existing ATS review functional, dashboards + analytics unaffected

---

## v8.4.9 — Flattened-Shape Portfolio Read Fix + Email Backfill

> Source: `docs/logs.md` device diagnostics (2026-08-07) · Executed via `docs/todo.md` (MB17–MB19).

### Root Cause (proven on-device)

The user's device log fired the MB13 diagnostic:

```
PortfolioService.getPortfolio: doc USERS/SWJLWtNNV7RMnhmcUquXTmW2mfH3 EXISTS but portfolio key is MISSING.
Doc keys present: (isPublicProfile, career, metadata, ..., portfolio.certifications, metadata.updatedAt)
```

The document had **no nested `portfolio` map** — every section was stored as **root-level keys with dots in their names** (`portfolio.resume`, `portfolio.projects`, `portfolio.certifications`, …) — the shape Firebase-console JSON edits / legacy writers produce. The reader looked up `data['portfolio']`, so it returned empty while the console clearly held all the data. That was the **exact mechanism behind Symptom 1** ("console has data, app shows empty") from the v8.4.8 pass: UID mismatch, wiped doc, and parsing were all ruled out — the reader simply looked in the wrong shape.

### The mistake (what went wrong, honestly)

Two compounding mistakes landed here, and both are now fixed:

1. **The read path assumed only the canonical nested shape.** Since v8.4, the writer (`PortfolioService.savePortfolio`) always writes the nested map via `portfolio.<section>` dotted paths, so nothing verified what happens when a document stores the portfolio *flattened* as root-level `portfolio.*` dots (Firebase-console JSON edits / legacy importers). The reader silently returned `PortfolioModel.empty()` for that shape, which is exactly why the app showed "No Resume" + 10% strength while the console had every section. This was not new to this bug — it had been latent since day one of the portfolio feature; nothing surfaced it because all app-authored writes self-consistently used the nested shape.
2. **The v8.4.8 pass drew the wrong conclusion instead of reading the raw document.** After the user's console dump looked complete, the pass concluded "data is fine — probably a stale debug build" (MB16). That was incorrect: the console dump was showing the *flattened* keys, and the app's reader looked for a nested `portfolio` map that didn't exist. The lesson: when "console has data but the app sees empty", the first check must be the **actual storage shape** the reader expects vs. what the document really contains — not caching, not parsing, not the build. The MB13 diagnostic from v8.4.8 is what finally proved it (`portfolio key is MISSING … keys present: …, portfolio.certifications, …`), and MB17 fixed the reader to accept both shapes.

### What Shipped

| Subtask | Fix |
|---------|-----|
| **MB17** | `PortfolioService._extractPortfolioMap` + `_unflattenPaths` — BOTH `getPortfolio` and `portfolioStream` now read the nested `portfolio` map when present, OR rebuild the portfolio from root-level `portfolio.*` dotted keys (deep leaf-flattened keys like `portfolio.resume.downloadUrl` re-nested under their section), else null → empty. The MB13 diagnostic only fires when neither shape carries a portfolio. |
| **MB18** | `personal.email` blank was a data bug, not a feature — the setup screen renders email read-only from that stored field. New `ProfileService.backfillEmail` does a targeted `personal.email` merge (portfolio + everything else untouched) when blank; `ProfileProvider.initWithUser` calls it once per user (`_emailBackfillUid`, cleared on `reset()`), non-fatal, and mirrors the email into memory immediately. |

### Files

**Modified:** `lib/services/firestore/portfolio_service.dart`, `lib/services/firestore/profile_service.dart`, `lib/providers/profile_provider.dart`, `docs/todo.md`, `docs/issues.md`

### Validation (MB19)

- `flutter analyze` → **No issues found** on all 3 changed files
- `flutter test` → **all 65 tests passed**
- Data self-heals to the canonical nested shape on the next app-side portfolio save (the tolerant reader prefers the nested map thereafter)

---

## v8.4.8 — Portfolio Read Failure & Refresh-Wipe Fix

> Source: `project_info__16.md` / `project_info__17.md` (2026-08-07 investigation) · Executed via `docs/todo.md` (MB11–MB16).

### What Shipped

| Subtask | Fix |
|---------|-----|
| **MB11** | `PortfolioProvider.refresh()` applied the v8.4.4 stale-guards (skip during in-flight local write; never let an empty read wipe a non-empty portfolio; never let a read drop the resume while memory has one). A single empty `getPortfolio()` could previously wipe the just-uploaded resume from memory AND poison the SharedPreferences cache — the exact refresh-wipe mechanism. Cache is only re-written when fresh data actually replaces memory. |
| **MB12** | `initWithUser` one-shot-get catch now sets `_error = 'Failed to load portfolio'` when falling back to empty, and the later `_error = null` was removed so the v8.4.7 banner actually fires on failed startup reads. |
| **MB13** | `PortfolioService.getPortfolio` prints a diagnostic (uid + doc key list) when the doc exists without a `portfolio` key — this diagnostic is what proved the v8.4.9 root cause on-device. Also hardened the read against a non-map `portfolio` value. |
| **MB14** | `createProfile` re-checks doc existence itself and uses `SetOptions(merge: true)` on an existing doc, so the race with `initializeProfile`'s `exists` check can never overwrite the whole document (including `portfolio`). |
| **MB15** | `ResumeSummaryCard` takes an `error` param and renders a red banner; the dashboard passes `portfolioProvider.error` through, so a failed load can't silently look like a fresh empty portfolio. |
| **MB16** | Validation: `flutter analyze` clean on all 5 changed files; `flutter test` 65/65 passed. User-side console verification confirmed portfolio data under the logged-in uid (candidates A/B/C ruled out). |

### Files

**Modified:** `lib/providers/portfolio_provider.dart`, `lib/services/firestore/portfolio_service.dart`, `lib/services/firestore/profile_service.dart`, `lib/widgets/resume_summary_card.dart`, `lib/views/dashboards/student_dashboard_view.dart`, `docs/todo.md`, `docs/issues.md`

---

## v8.4.2 — Issues Hardening

> Source: v8.4.1 Final Audit (`docs/confirmation.md` §2) + Explore audit `project_info__13.md` · Executed via `docs/todo.md` (S1–S7) · Issue status mirrored in `docs/issues.md`.
> Status: **DEPLOYED 2026-08-07** — S1a–S7 complete, S1c/P2 ✅ (Storage provisioned in Console by the project owner), full deploy batch released. Only the post-deploy manual pass remains.

### Scope

Every audit item from `docs/issues.md` (C1/H1/H2 + N1, M1–M5, L1–L7, N2–N6, P1, P3) was verified against source (`project_info__13.md`) and fixed in this cycle. The S4b (M4) and S4c (N2) UI call sites and the S6b (P3) client callables (`AIService`, `ResumeReviewService`) were updated in the same batch.

### What Shipped

| Subtask | Fix |
|---------|-----|
| **S1a** | `storage.rules` `allow write` now has the `request.resource == null` branch (owner deletes) and `<=` size boundary (closes C1 + L3) |
| **S1b** | Stale `resume.pdf` comments → `resumes/{uid}/latest.pdf` in `storage.rules` header + `resume_upload_screen.dart` (L2) |
| **S2a** | `logPlacementApplication` copies `latest.pdf` → `resumes/{uid}/snapshots/app_{applicationId}.pdf` and stores the snapshot path + signed URL in both write paths (H1) |
| **S2b** | `firestore.indexes.json` gained `applications` (userId/appliedAt) + 2× `placements` indexes (H2 + N1) |
| **S2c** | Linux platform block in `firebase.json` + `lib/firebase_options.dart` Linux options (L7) |
| **S3a** | Server-side `resumeStoragePath` ownership check + `atsScoreAtApplication` int 0–100 coercion (M2) |
| **S3b** | Application `status: "applied"` unified on both write paths in `logPlacementApplication` (M1) |
| **S3c** | Connectivity `StreamSubscription` kept + cancelled in `reset()`/`dispose()`, `_isDisposed`-guarded callback (M5) |
| **S4a** | F10 `end.isBefore(start)` guard in Experience manager `_formatDuration` (M3) |
| **S4b** | Apply dialog awaits `PortfolioProvider` init, resolves storagePath-only resumes via `ResumeService.getResumeUrl`, shows loading (M4) |
| **S4c** | `resume.downloadUrl!` null-assert crash fixed at both call sites via `ResumeService.getResumeUrl` with SnackBar fallbacks (N2) |
| **S5a** | `firestore.rules` notifications subcollection gained `allow delete: if isOwner(userId);` (L4; N3 verified) |
| **S5b** | `PortfolioTextField` `maxLength` param + caps across all six portfolio edit screens (L5) |
| **S5c** | `seedPortfolios()` phase-15 in `scripts/seed_firestore/seed.js` — full portfolio + resume metadata, `merge: true`, `isDemoData: true` (L6) |
| **S5d** | Dead code removed from `placements_service.dart`: `applyForPlacement`, `applyForPlacementDirect`, `getUserApplicationsWithDetails`, `getUserApplications`, `hasUserApplied` (L1 + N4) |
| **S5e** | T2 bullet restored in `docs/todo.md` (N6); `copyWith` null-clear limitation documented as `NOTE (N5, v8.4.2)` on `CareerPreferences`/`SocialLinks`/`ResumeMetadata` |
| **S6a** | `onResumeReviewCreatedRefreshMatches` now merges `latestATSScore`/`reviewCount`/`lastReviewAt` (+`updatedAt`) into `users/{uid}/portfolio.resume` (P1) |
| **S6b** | `askAI` + `reviewResume` migrated from `onRequest` → `onCall`; identity from `request.auth.uid`; quota → `resource-exhausted`; `AIService`/`ResumeReviewService` clients migrated to `httpsCallable` (P3) |
| **S7** | Validation below |

### Files

**Created:** `test/application_test.dart`, `test/resume_metadata_test.dart`

**Modified:** `storage.rules`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `lib/firebase_options.dart`, `functions/index.js`, `lib/services/firestore/placements_service.dart`, `lib/providers/placements_provider.dart`, `lib/views/placements/placements_list_view.dart`, `lib/views/portfolio/experience_manager_screen.dart`, `lib/views/portfolio/student_portfolio_screen.dart`, `lib/views/portfolio/portfolio_read_only_view.dart`, `lib/views/portfolio/resume_upload_screen.dart`, `lib/views/portfolio/edit_portfolio_screen.dart`, `lib/views/portfolio/widgets/portfolio_text_field.dart`, `lib/views/portfolio/career_preferences.dart`, `lib/models/portfolio/social_links.dart`, `lib/models/portfolio/resume_metadata.dart`, `lib/models/application.dart`, `lib/services/ai/ai_service.dart`, `lib/services/ai/resume_review_service.dart`, `scripts/seed_firestore/seed.js`, `docs/todo.md`, `docs/issues.md`

### Validation (S7)

- `flutter analyze` → **0 errors / 0 warnings** (69 pre-existing info lints unchanged from baseline)
- `flutter test` → **58/58** (45 existing + 13 new: `test/application_test.dart` — Application M1/S3b status + T5 snapshot contract; `test/resume_metadata_test.dart` — T1 field names, legacy-key fallbacks, storagePath-only `hasResume`, N5 copyWith null-clear limitation)
- JS syntax: `node --check` passes for `functions/index.js` and `scripts/seed_firestore/seed.js`
- Manual pass (post-deploy) still open — see `docs/todo.md` S7

### Deploy batch

✅ **EXECUTED 2026-08-07** — `firebase deploy --only "functions,firestore:rules,firestore:indexes,storage" --non-interactive` succeeded after the owner enabled Storage in the Console. All 11 functions updated (askAI, reviewResume, logPlacementApplication, onResumeReviewCreatedRefreshMatches, etc.), storage.rules + firestore.rules released, indexes deployed. Note: the run used `--non-interactive` so the 6 pre-existing remote-only indexes + 2 field overrides were preserved (not deleted).

---

## Previous Versions (condensed)

### v8.4.6 — Final Audit Fixes (F1–F12)
Final audit close-out (`docs/confirmation.md` §9): **F1** role immutability guard (closes student self-elevation), **F2** chat route registration, **F3** notifications `type/createdAt` ASC composite index (system notifications no longer dropped), **F4** mentorship completion UI reachable, **F5** per-section dotted-path portfolio saves (no sibling clobber), **F6** provider uid/disposed lifecycle guards, **F7** notifications create rule → owner-only, **F8** dead code removal, **F9** `getPortfolio` rethrows real errors, **F10** inverted-date guards, **F11** typed params + version bump. Deployed `firestore:rules,firestore:indexes,storage`. Validation: analyze 0 errors; **45/45 tests**; zero unhandled exceptions across 3 logged launches.

### v8.4.5 — Student Resume Portfolio Bugfix (C1/H1–H5/M1–M13/L1–L7)
Fixed v8.4 audit issues: **C1** platform-split upload (web bytes / non-web filePath), **C2** real `educationFilled` completion score, **C3/H2** storage rules — teacher/alumni read via role lookup, PDF-only + 5 MB server-side, **H1** single-seed forms, **H3** `optionalUrl` allowHttp fix, **H4** per-section diff saves, **H5** 16 new tests, **M5/M13** profile gating + dynamic version label, **M10** tolerant `fromMap`. Validation: analyze 0 errors; **41/41 tests**. Deployment note: `firebase deploy --only storage` blocked — Firebase Storage not yet provisioned on `campusconnect-firebase-project`.

### v8.4 — Student Resume Portfolio
Full portfolio subsystem: models (portfolio, skills, projects, certifications, experience, achievements, career preferences, social links, resume metadata), `PortfolioService` (merge-set CRUD under `users/{uid}/portfolio`), `StorageService` (`resumes/{uid}/resume.pdf`, 5 MB + PDF validation), `PortfolioProvider`, validators, 10 portfolio views, 8 routes, `storage.rules`, alumni/teacher read-only Firestore rules. Foundation for v8.4.5 / v8.4.6 / v8.4.1.

### v8.3.1 — First-Login Data Load Retry
Teacher dashboard showed zero data on first login (Firestore gRPC connection not warm). Fix: retry load up to 3× with 2 s delay when zero students returned; `mounted`-guarded.

### v8.3 — Codebase Architecture Documentation + Firestore Demo Data Seeder
- `project_info__8.md`: complete schema analysis — 12 document schemas, security rules audit, index audit, analytics data-flow trace.
- 14-phase seed script (`scripts/seed_firestore/seed.js` + `cleanup.js` + README): 30 students (5 departments, differentiated profiles), 10 alumni, 5 teachers, 120–150 progressive ATS reviews, 30 engagement summaries, 20 placements, 80–120 applications (dual-path), 40 mentorship requests, 15 opportunities, 22 chats, ~200 notifications, 150+ activities, 6 recommendations/student, ~75 AI interactions, 6 public profiles. `isDemoData: true` safe cleanup, Admin SDK (bypasses rules), batched writes in chunks of 490.

### v8.2.2 — Layout Fix & Data Pipeline Investigation
Removed nested Scaffold + AppBar in `_TeacherDashboardTab` and `AIInsightsTab` (fixed vertical purple/blue bar corrupting the AI Insights tab). Investigated zero-metric reports: root cause = **empty Firebase database**, no code bugs; every chart/section shows a proper empty state.

### v8.2.1 — Data Pipeline Fix
Fixed `getEngagementAggregates()` path `engagement` → `engagement_summary` (avg engagement / profile strength were always 0). Renamed misleading metrics: "Placed Students" → "Active Drives", "Overall Placement" → "Active/Student", "Mentorships" → "Alumni". Schema does not track per-student placement outcome, so Shortlisted/Interview/Placed stages show "N/A".

### v8.2 — Teacher Intelligence & Analytics
8 workspace phases: placement pipeline refinement (real data, no hardcoded multipliers), quick statistics, department analytics, FL Chart visual upgrade (pie/bar/line), at-risk detection, student growth analytics, AI-generated teacher summary (dynamic narratives), workspace docs. Edge-case hardening: provider lists copied before sorting; at-risk uses per-student signals only (not teacher-level counts); zero-value chart stubs; single-department and single-trend-point rendering.

### v8.1 — Teacher Dashboard Modernization
Predecessor analytics pass; superseded by v8.2.

---

## Cross-Cutting Notes

### Architecture Decisions (still relevant)
- **Nested portfolio map** (`users/{uid}/portfolio`) over a dedicated subcollection — preserves dashboards, per-section diffs (F5), backward compatibility. Caveat (M2): alumni read = whole student document read; documented inline in `firestore.rules`.
- **Storage naming**: `resumes/{uid}/latest.pdf` since v8.4.1; the wildcard rule `resumes/{uid}/{fileName}` already covers future `history/v1.pdf` paths.
- **ATS score wired (v8.4.2 S6a)**: `onResumeReviewCreatedRefreshMatches` now merges `latestATSScore`/`reviewCount`/`lastReviewAt` (+`updatedAt`) into `users/{uid}/portfolio.resume` — dashboard/portfolio/read-only "Latest ATS", Resume Age and `atsScoreAtApplication` are powered.
- **Dual application paths**: `placements/{pid}/applications/{uid}` + legacy `applications/{appId}` for backward compatibility.
- **Seed data**: `demo_` UID prefix, `isDemoData: true` flag, Admin SDK, batched writes.

### Performance
Parallel analytics loads (`Future.wait`), capped queries (30 students / 400 reviews), `count()` aggregations, one-time fetches (no streams), batched seed writes.

### Known Limitations
1. Per-student placement *outcome* (shortlist/interview/placed) is not tracked — pipeline shows "N/A" for those stages.
2. Engagement aggregates iterate per-student docs — slow at 500+ students; a materialized aggregate (Cloud Function) is the future fix.
3. Analytics are snapshot-based — data appears on dashboard init or pull-to-refresh, not live.
4. At-risk detection limited to ATS/review signals.
5. ~~Firebase Storage provisioning~~ — **RESOLVED 2026-08-07** (v8.4.2 S1c/P2): Storage bucket enabled in Console + `storage.rules` deployed. Resume uploads/deletes are live.
6. **App Check not installed** — `No AppCheckProvider installed` appears as a WARNING on every login/session (placeholder token). Non-blocking: Firestore/Storage rules authenticate via `request.auth` (Firebase Auth), not `app.check()`, so requests are never blocked. Verified harmless on alumni login (2026-08-07). Enabling would be a deliberate future hardening task: add `firebase_app_check`, configure Play Integrity + DeviceCheck, opt-in the rules, redeploy.
7. **Flattened-vs-nested portfolio shape** — legacy/console-edited user docs may store the portfolio as root-level `portfolio.*` dotted keys instead of a nested `portfolio` map. v8.4.9 (MB17) makes both reads (`getPortfolio`/`portfolioStream`) tolerant of both shapes; app writes always produce the canonical nested shape and self-heal the doc on the next save.
