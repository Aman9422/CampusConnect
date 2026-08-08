# CampusConnect — Task Tracker

> Current cycle: **v8.5 — Resume Reviewer Integration & PDF Intelligence** (docs/Task.md)
> Status: **R1–R9 COMPLETE** · R10 in flight (docs/, version bump, deploy, manual pass)

---

## v8.5 — Resume Reviewer Integration & PDF Intelligence

> Goal: make `resumes/{uid}/latest.pdf` the actual source for the existing Resume Reviewer.
> Primary success flow: Upload → Review Uploaded PDF → ATS/AI review → Portfolio updates → Dashboard updates → Apply to placement with immutable snapshot.

| # | Subtask | Status |
|---|---------|--------|
| R1 | Architecture/data-flow audit | ✅ DONE — `project_info__15_v8.5_R1_Resume_Review_Integration_Audit.md` |
| R2 | PDF text extraction (server-side, functions/) | ✅ DONE — `pdf-parse@1.1.1` deep-require (`pdf-parse/lib/pdf-parse.js`), verified on Node against a real Chromium-generated PDF |
| R3 | Callable integration: `reviewResume(storagePath)` + client path forwarding | ✅ DONE |
| R4 | Resume Reviewer UI: Review Uploaded Resume / Replace Resume / review count | ✅ DONE |
| R5 | ATS/portfolio synchronization verification | ✅ DONE — unchanged `{review, usage}` shape → `onResumeReviewCreatedRefreshMatches` keeps merging `portfolio.resume.{latestATSScore,reviewCount,lastReviewAt,updatedAt}` |
| R6 | Review history verification | ✅ DONE — PDF reviews reuse the existing client-side `_saveToHistory` → `users/{uid}/resumeReviews` |
| R7 | Resume replacement verification | ✅ DONE — server reads `resumes/{uid}/latest.pdf` at review time; history + placement snapshots untouched |
| R8 | Error handling (new codes + friendly messages) | ✅ DONE — `not-found` / `invalid-argument` mapped in `ResumeReviewService`; loading flags reset in `finally` |
| R9 | Security tests (storage-path validation) + existing suite | ✅ DONE — `test/resume_review_storage_path_test.dart` (6 tests); `flutter analyze` 0 errors; `flutter test` 71/71 |
| R10 | Validation/deployment/manual pass + docs (issues, tracker, version) | ⏳ IN PROGRESS — docs/version done below; deploy + manual matrix pending |

---

## v8.5.1 — Resume Storage → Resume Reviewer (detailed checklist)

- [x] R1 — Trace complete Resume Review data flow (view → service → provider → callable → AI pipeline → ATS persistence → history → snapshots)
- [x] R2 — Add server-side PDF text extractor (functions/) compatible with Node 20 / firebase-functions v5
- [x] R2 — Graceful handling of empty / image-only / unextractable PDFs (friendly user message, no OCR, no content logging)
- [x] R3 — `reviewResume` accepts `storagePath`; enforces `request.auth.uid === owner` and exact `resumes/{uid}/latest.pdf`
- [x] R3 — Admin SDK downloads the PDF; extracted text flows through the EXISTING AI/ATS pipeline; returns the same `{review, usage}` shape
- [x] R3 — Client: `ResumeReviewService.reviewResume(storagePath)`, provider passthrough
- [x] R4 — Resume Reviewer UI uses the uploaded resume automatically (Review Uploaded Resume / Open / Replace) with manual-paste fallback
- [x] R5 — Confirm `onResumeReviewCreatedRefreshMatches` keeps updating `portfolio.resume.{latestATSScore,reviewCount,lastReviewAt,updatedAt}` for PDF reviews
- [x] R6 — Confirm PDF reviews land in `users/{uid}/resumeReviews` (existing history)
- [x] R7 — Confirm resume replacement (A→B) updates current resume/ATS, preserves history + placement snapshots
- [x] R8 — Map `not-found` / image-only / invalid-path / oversized errors to friendly messages; loading flags reset in `finally`
- [x] R9 — `test/resume_review_storage_path_test.dart` (valid + invalid cases per docs/Task.md) + existing suite green
- [x] R10 — Validate: `flutter analyze` (0 errors), `flutter test` (71/71), `node --check functions/index.js` (pass)
- [x] R10 — Docs: `docs/todo.md`, `docs/issues.md`, `docs/v8_workspace_tracker.md` updated; pubspec `8.4.1+85` → `8.5.0+86`
- [x] R10 — Deploy `--only functions` **SUCCESS** (2026-08-08 — all 14 functions updated, incl. `reviewResume` + triggers)
- [ ] R10 — Manual test matrix (device) — pending: upload → review PDF → ATS → dashboard → replace resume → placement snapshot → cross-UID security attempt → bad/image PDF

---

## Archive — Previous Cycles

*(Previous cycles tracked in `docs/v8_workspace_tracker.md` — v8.4 … v8.4.9 all complete + deployed.)*
