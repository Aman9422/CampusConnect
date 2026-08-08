# CampusConnect — Workspace Tracker

## Status: IMPLEMENTATION COMPLETE — deployment pending
## Version: CampusConnect v8.5 — Resume Reviewer Integration & PDF Intelligence (2026-08-08)

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
