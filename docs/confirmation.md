# CampusConnect v8.4.1 — Final Audit & Architecture Stability Review

> Audit date: 2026-08-07 · Scope: `docs/Task.md` (v8.4.1), `docs/todo.md` (T0–T7), `docs/v8_workspace_tracker.md`, `project_info__12.md`, and full source review of the v8.4.1 changes — `ResumeMetadata`, `StorageService`, `ResumeService`, `PortfolioProvider`, `PortfolioService`, portfolio views, `ResumeSummaryCard`, placement snapshot chain (`functions/index.js`, `Application`, `PlacementsService`, `PlacementsProvider`, `placements_list_view.dart`), routes, `main.dart`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
> Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low
> Previous audit (v8.4.6 era) preserved at `project_info__11.md`.

---

## Summary

v8.4.1 has been **verified against the code, the static-analysis claim, and the test suite**, and it is genuinely complete per `docs/Todo.md` T0–T7:

- **`flutter analyze` → 0 errors / 0 warnings.** Only 69 pre-existing `info`-level lints (deprecated `withOpacity`/`value`, `use_build_context_synchronously`, legacy archived files). None introduced by v8.4.1 files.
- **`flutter test` → 45/45 pass** (auth regression 14, auth 24, portfolio read-only view 1, verify-email navigation 2, portfolio model/validators included in prior 45 baseline).
- **T0–T7 confirmed in source**: nested-map architecture decision documented; `latest.pdf` storage path; all Phase 2 metadata fields on `ResumeMetadata` with legacy-key fallbacks; `ResumeService` façade delegating Storage + per-section Firestore diffs; `careerObjective`/`languages` + Resume Status chip + metadata rows in both portfolio views; `ResumeSummaryCard` on the student dashboard; placement resume snapshot end-to-end (callable → model → provider → dialog); version `8.4.1+85`.

**However, the audit found real issues that would surface in production.** The most severe is a **Storage-rules bug that will deny owner deletes once Firebase Storage is provisioned** (`storage.rules` write rule references `request.resource.contentType` which is null on delete). The Phase 8 "resume snapshot" is also **metadata-only** — it stores a path that later uploads overwrite, so the preserved-resume guarantee is not actually met at the byte level. Several smaller correctness gaps (F10 incomplete in the experience manager, status inconsistency between the two application write paths, a possibly-missing composite index, provider subscription leak) are detailed below.

---

## 1. Verified-Fixed (code matches the docs)

| Task | Evidence in source |
|------|--------------------|
| **T0** Architecture decision | `docs/v8_workspace_tracker.md` + `ResumeMetadata` doc comment: nested map `users/{uid}/portfolio.resume` retained; deviation from `users/{uid}/resume/metadata` documented. |
| **T1** Metadata + path | `resume_metadata.dart` — `storagePath`, `fileSize`, `mimeType`, `uploadedAt`/`updatedAt`, `latestATSScore`, `reviewCount`, `lastReviewAt`, `isDemoData`, tolerant `fromMap` (legacy `uploadDate`/`lastUpdated`/`atsScore`), back-compat getters, `hasResume`, `resumeAgeInDays`. `storage_service.dart` — `resumes/{uid}/latest.pdf`, `resumeHistoryPath`, 5 MB + PDF validation, original `fileName` in `ResumeUploadResult`. |
| **T2** ResumeService | `resume_service.dart` exists; upload/delete orchestrate Storage + `PortfolioService.savePortfolio(..., previous)` per-section diffs; `downloadResume`/`getResumeUrl`/`checkResumeExists`/`readMetadata`/`historyPath`. `PortfolioProvider.uploadResume/deleteResume` delegate to it; F5/H4 + F6 guards preserved (`_isDisposed`, `_lastUid`). |
| **T3** Portfolio fields + UI | `career_preferences.dart` (`careerObjective`), `portfolio_model.dart` (`languages`, `isEmpty` includes them), edit UI for both; Resume Status chip, size/type/storage-path/version/review-count rows, Latest ATS + Resume Age in `student_portfolio_screen.dart` and `portfolio_read_only_view.dart`. |
| **T4** Dashboard summary | `resume_summary_card.dart` wired into `_StudentDashboardTab` via `Consumer<PortfolioProvider>`; Uploaded/no-resume chip, Latest ATS, Resume Age, Last Review, Open Portfolio + Upload/Replace. |
| **T5** Placement snapshot | `functions/index.js` `logPlacementApplication` persists `resumeVersion`/`resumeStoragePath`/`atsScoreAtApplication` (both write paths); `Application` model + `studentId` alias; `PlacementsService.applyForPlacement/Direct` forward them; `_ApplyDialogWidget` uses the uploaded resume URL with text fallback. |
| **T6** Version | `pubspec.yaml` = `8.4.1+85`. |
| **T7** Validation | `flutter analyze` 0/0 (verified); `flutter test` 45/45 (verified). |

---

## 2. 🆕 Bugs & Issues Found (v8.4.1 audit)

### 2.1 🔴 CRITICAL — `storage.rules` write rule denies owner **delete**
- **File**: `storage.rules`.
- **Code**:
  ```
  allow write: if request.auth != null &&
    request.auth.uid == userId &&
    request.resource.contentType.matches('application/pdf') &&
    request.resource.size < 5 * 1024 * 1024;
  ```
- **Problem**: on a Storage **delete** operation, `request.resource` is **null**. Referencing `request.resource.contentType` in the rule makes the evaluation fail → the request is **denied**. `StorageService.deleteResume` (`ref.delete()`) will therefore get `permission-denied` for the owner once Storage is provisioned — the "Delete Resume" feature silently breaks.
- **Fix**: allow deletes explicitly:
  ```
  allow write: if request.auth != null && request.auth.uid == userId &&
    (request.resource == null ||   // delete
       (request.resource.contentType.matches('application/pdf') &&
        request.resource.size < 5 * 1024 * 1024));
  ```
  (or `request.method == 'delete'` branch). This must be deployed together with `firebase deploy --only storage` when Storage is enabled.

### 2.2 🟠 HIGH — Phase 8 "resume snapshot" is metadata-only; the bytes are not preserved
- **Files**: `functions/index.js` `logPlacementApplication`, `Application.resumeStoragePath`, `StorageService.resumePath`.
- **Problem**: the application stores `resumeStoragePath = resumes/{uid}/latest.pdf` (or the live download URL). `latest.pdf` is **overwritten in place** on every re-upload (`uploadResume` → same path). So the snapshot promise — "This preserves the resume used when applying even after future uploads" (`docs/Task.md` Phase 8) — holds for the metadata fields but **not for the actual resume content**. A recruiter/analyst opening the application's resume after the student re-uploads sees the new file.
- **Fix (recommended)**: in `logPlacementApplication`, copy the object to an immutable path at apply time, e.g. `resumes/{uid}/snapshots/app_{placementId}.pdf` (Storage `copyTo` in Node Admin SDK), and store **that** path + URL. Metadata-only is acceptable only if the product explicitly accepts "latest resume" semantics.
- **Note**: `resumeVersion` gives a version number but there is no version *history* (out of scope per Task.md), so the number alone cannot recover the old file either.

### 2.3 🟠 HIGH — Composite index for `applications` is not declared in `firestore.indexes.json` (verify + add)
- **Queries** needing it: `getUserApplicationsOnce` and stream `getUserApplicationsWithDetails` — `applications where userId == … orderBy appliedAt desc`.
- **Problem**: composite index `applications: userId ASC / appliedAt DESC` is required. It is **not present** in `firestore.indexes.json`. The v8.4.6 deployment note says 8 pre-existing *remote* indexes were left undeclared, so the index may exist in the deployed project — but it is missing from the repo, so a fresh project / CI deploy will hit "index required" and the student dashboard placements section (and apply-states) will silently fail. Same risk class as F3.
- **Fix**: add the index to `firestore.indexes.json`:
  ```json
  { "collectionGroup": "applications", "queryScope": "COLLECTION",
    "fields": [ {"fieldPath":"userId","order":"ASCENDING"},
                {"fieldPath":"appliedAt","order":"DESCENDING"} ] }
  ```
  and deploy. Verify the remote project already has it.

### 2.4 🟡 MEDIUM — Application `status` is inconsistent between the two write paths
- **File**: `functions/index.js` (`logPlacementApplication`).
- **Code**: global `applications/{appId}` is written `status: "applied"`; the mirror `placements/{placementId}/applications/{uid}` is written `status: "pending"`. `applyForPlacementDirect` writes `"applied"` to both; the `Application` model defaults to `"applied"`.
- **Problem**: the same application reads `pending` through one path and `applied` through the other. Any future teacher pipeline (or an admin tool reading the subcollection) will disagree with the student's "Applied" state.
- **Fix**: write `status: "applied"` in both places in the callable (or clearly define "pending" as a deliberate pre-approval state and mirror it everywhere).

### 2.5 🟡 MEDIUM — Cloud Function accepts a client-supplied `resumeStoragePath` without ownership validation
- **File**: `functions/index.js` `logPlacementApplication`.
- **Problem**: `resumeStoragePath` comes from `request.data` and is stored as-is. A malicious student can pass **another student's** storage path (`resumes/otherUid/latest.pdf`) into their own application record. Impact is limited (metadata only; reads are still rule-gated), but the record would misattribute a resume.
- **Fix**: server-side check — `if (!resumeStoragePath?.startsWith(\`resumes/${uid}/\`)) resumeStoragePath = null;` (and validate `atsScoreAtApplication` is an int 0–100).

### 2.6 🟡 MEDIUM — F10 (inverted-date guard) was applied to Projects but **not** Experience
- **File**: `lib/views/portfolio/experience_manager_screen.dart` `_formatDuration`.
- **Problem**: Projects manager has `if (end.isBefore(start)) return startStr;` (F10), and so do the preview/read-only views (M9), but the Experience manager returns `'$startStr — ${DateFormat('MMM yyyy').format(end)}'` unconditionally. Legacy/inverted data renders "Dec 2024 — Aug 2024" in the Experience manager.
- **Fix**: add the same guard to `experience_manager_screen.dart`.

### 2.7 🟡 MEDIUM — Apply dialog can silently drop the resume snapshot
- **File**: `lib/views/placements/placements_list_view.dart` `_ApplyDialogWidget.didChangeDependencies`.
- **Problem**: it reads `context.read<PortfolioProvider>().portfolio` once (seed-once). If the dialog is opened before `PortfolioProvider.initWithUser` completes (AuthGuard initializes it in a post-frame callback), the portfolio is null → the dialog falls back to the text-paste field even though the student has an uploaded resume; the snapshot fields (`resumeVersion` etc.) are never attached.
- **Also**: when `resume.hasResume` is true via `storagePath` only (legacy doc with no `downloadUrl`), `_resumeUrl = resume!.downloadUrl ?? ''` → `hasUploadedResume` is false → same silent fallback.
- **Fix**: (a) await provider init or show a loading state in the dialog; (b) when `downloadUrl` is missing, resolve via `ResumeService.getResumeUrl`/`downloadUrlFromPath`.

### 2.8 🟡 MEDIUM — `PlacementsProvider` connectivity subscription leaks and can notify after reset
- **File**: `lib/providers/placements_provider.dart`.
- **Problem**: `_startConnectivityMonitoring()` subscribes to `Connectivity.onConnectivityChanged` but the stream-subscription is never cancelled (`dispose()` is empty; `reset()` doesn't cancel it). After logout, a connectivity change calls `notifyListeners()` on a provider whose listeners may be gone, and the subscription leaks across logins (stacking listeners on re-init → duplicate `notifyListeners`).
- **Fix**: keep the `StreamSubscription`, cancel it in `reset()`/`dispose()`, and guard the callback with `_isDisposed`.

### 2.9 🔵 LOW — `applyForPlacementDirect` is dead code
- `PlacementsService.applyForPlacementDirect` exists as a "fallback if Cloud Function unavailable" but **nothing calls it** — `PlacementsProvider.applyForPlacement` only uses the callable. Either wire an offline/secondary path or remove the dead method (matches the M8 dead-code cleanup goal).

### 2.10 🔵 LOW — Stale doc comments reference `resume.pdf`
- `storage_service.dart` class-level doc and `resume_upload_screen.dart` doc say `resumes/{uid}/resume.pdf`; the actual path is `latest.pdf`. `storage.rules` header comment says `resumes/{uid}/resume.pdf` too. Cosmetic, but confusing for the next engineer (and the rules comment is now wrong).

### 2.11 🔵 LOW — No length caps on career objective / languages / many portfolio fields
- `careerObjective` is a free-form 3-line field with no `maxLength`; languages are free-form strings. A student can persist a huge objective; Firestore 1 MiB doc limit is the only backstop. Add `maxLength` (e.g. 500) to `PortfolioTextField` usages.

### 2.12 🔵 LOW — Users cannot delete their own notifications (rules)
- `firestore.rules` notifications: `allow read, update: if isOwner(userId); allow create: if isOwner(userId);` — **no `delete`**. Clients can mark-read/update but never delete a notification. Add `allow delete: if isOwner(userId);` if the UI offers deletion (or document the decision).

### 2.13 🔵 LOW — Seed script has no portfolio/resume data
- `scripts/seed_firestore/seed.js` (v8.3) predates the portfolio — demo students have empty portfolios, so Teacher "View Portfolio" and the new Resume Summary card show empty states for all demo data. Extend the seeder (phase 15) with portfolio sections + `resume` metadata + `languages` + `careerObjective`, tagged `isDemoData: true`.

### 2.14 🔵 LOW — Linux not registered in `firebase.json` FlutterFire platforms
- `linux/` exists in the repo but `firebase.json` → `flutter.platforms` lists only android/ios/macos/web/windows. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` will throw on Linux builds. Pre-existing; fix by adding the linux config block.

---

## 3. Role-Based Access / Rules / Indexes Audit

| Area | Verdict |
|------|---------|
| `firestore.rules` — `canWriteRole` (F1) | ✅ Role self-elevation closed; short-circuit order is safe for first-time create and role-less documents. |
| `firestore.rules` — owner read/write + teacher read + alumni whole-doc read (M2) | ✅ Intent correct. M2 caveat (alumni read whole student doc) remains a documented trade-off of the nested-map design. |
| `firestore.rules` — notifications create owner-only (F7) | ✅ Fixed. `delete` missing (see §2.12). |
| `storage.rules` — owner write PDF/5 MB (C3/H2) | 🟠 **Owner delete broken** (§2.1). |
| `storage.rules` — teacher/alumni read via Firestore role lookup | ✅ Correct `exists()` guard. |
| `storage.rules` — `request.resource.size < 5 * 1024 * 1024` | ⚠️ Strictly *less than* 5 MB; a file of exactly 5 MB (5,242,880 bytes) is rejected while the client allows `<=`. Align the two (use `<= 5*1024*1024`). |
| `firestore.indexes.json` — notifications ASC (F3) | ✅ Now present (both ASC and DESC). |
| `firestore.indexes.json` — applications composite | 🟠 **Missing from repo** (§2.3). |
| Cloud Function `logPlacementApplication` — auth from callable context | ✅ `request.auth?.uid` — cannot be spoofed. |
| Cloud Function — snapshot path ownership | 🟡 Client-supplied path not validated (§2.5). |
| `askAI` HTTP body `userId` | ⚠️ Pre-existing: no auth binding on HTTP `userId`; App Check + callable migration recommended (long-standing item). |
| `onProfileUpdatedRefreshAI` trigger | ✅ Portfolio diffs excluded — portfolio saves correctly do not retrigger AI recompute. |

---

## 4. Edge Cases & Boundary Handling

- **Zero-resume path**: upload screen, resume card, portfolio views, read-only view, apply dialog — all branch on `hasResume`; empty states are intentional (verified).
- **Legacy documents**: `ResumeMetadata.fromMap` tolerates `uploadDate`/`lastUpdated`/`atsScore`; but a legacy storagePath-only resume loses the apply-dialog snapshot (§2.7).
- **Date inversion**: guarded in preview, read-only, projects manager (M9/F10); **missing in experience manager (§2.6)**.
- **Upload size boundary**: client accepts `<= 5 MB`, storage rule rejects `>= 5 MB` — boundary mismatch (§3).
- **Version increment**: `(current.resume?.version ?? 0) + 1` — correct, starts at 1 on first upload, keeps incrementing on replace.
- **Delete idempotency**: `StorageService.deleteResume` tolerates `object-not-found` client-side; rules must still permit the delete (§2.1).
- **`_isDisposed`/`_lastUid` guards** in `PortfolioProvider.uploadResume/deleteResume/refresh` — present and correct; `PlacementsProvider` connectivity callback is the remaining unprotected surface (§2.8).

---

## 5. Prioritized Fix List

| # | Sev | Area | Fix |
|---|-----|------|-----|
| 1 | 🔴 | Storage rules | Allow deletes: `request.resource == null ||` branch in the write rule (§2.1). Deploy with Storage enablement. |
| 2 | 🟠 | Phase 8 | Copy resume to an immutable snapshot path in `logPlacementApplication` (`resumes/{uid}/snapshots/app_{pid}.pdf`) and store that path/URL (§2.2). |
| 3 | 🟠 | Indexes | Add `applications userId ASC / appliedAt DESC` to `firestore.indexes.json`; verify remote; deploy (§2.3). |
| 4 | 🟡 | Function | Validate `resumeStoragePath` ownership + `atsScoreAtApplication` range server-side (§2.5). |
| 5 | 🟡 | Function | Unify application `status` (`"applied"` in both write paths) (§2.4). |
| 6 | 🟡 | UI | Apply F10 guard to `experience_manager_screen.dart` `_formatDuration` (§2.6). |
| 7 | 🟡 | UI | Apply-dialog: await portfolio init / resolve `downloadUrl` from `storagePath` before falling back to text (§2.7). |
| 8 | 🟡 | Provider | Cancel the connectivity `StreamSubscription` on reset/dispose + `_isDisposed` guard (§2.8). |
| 9 | 🔵 | Hygiene | Remove or wire `applyForPlacementDirect`; fix `resume.pdf` doc comments; size-boundary alignment; notifications delete rule; maxLength caps; seed portfolio data; linux in `firebase.json`. |

---

## 6. Improvements for the Project (roadmap)

**Correctness / safety first**
1. **Enable Firebase Storage & deploy rules** — the single deployment blocker (console → `firebase deploy --only storage`). Without it, uploads/delete are untestable in production and §2.1 cannot be proven either way.
2. **Wire ATS score into portfolio metadata (true Phase 2 completion)** — extend `onResumeReviewCreatedRefreshMatches` (Cloud Function) to write `latestATSScore`, `reviewCount`, `lastReviewAt` into `users/{uid}/portfolio.resume` (merge). This instantly powers Latest ATS on the dashboard, portfolio, read-only view, and `atsScoreAtApplication` snapshots. Currently those UI hooks always show "—". This is the v8.5 bridge.
3. **App Check** — closes the forged-`userId` AI-spend hole and raises the bar on all rule bypasses.
4. **Materialized analytics** — replace the per-student N+1 reads (`getStudentResumeData`, `getEngagementAggregates`) with a Cloud Function-maintained `teacher_analytics/summary` doc; scale past the free tier.
5. **Dead-code + lint cleanup** — remove archived legacy views (`lib/views/archived/notes_view_legacy.dart`, the source of ~33 of 69 info lints), migrate deprecated `withOpacity`/`value:` to `withValues`/`initialValue`, and finish M8 (dead services).
6. **Documentation accuracy** — keep `docs/confirmation.md`, `docs/confirmation.md` issues, and the workspace tracker in lockstep with source (the H4/L4/L5 claim mismatch in v8.4.5-era docs was a real hazard the tracker has since corrected).

**Product next**
7. **Resume version history UI (v8.5 path is pre-wired)** — `resumes/{uid}/history/v{n}.pdf` + `historyPath` already exist; add copy-to-history on replace and a picker.
8. **Placement snapshot bytes (see §2.2)** — makes the apply record fully auditable and enables "resume at application time" reviews.
9. **Demo data** — extend the seeder so every dashboard (Teacher portfolio drill-down, Resume card, ATS hooks) has realistic data after seeding.
10. **Offline-first portfolio** — `PortfolioService.portfolioStream` exists but the app uses one-shot `get()`; switching the provider to a stream would make edits instant and conflict-safe once per-section diff saves are in.
