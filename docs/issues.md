# CampusConnect — Issues Log

> Maintained as part of the v8.4.3 Manual-Test Bug Fix pass. Source: `project_info__14.md` (2026-08-07 investigation). Across all six reported bugs, **5 had confirmed code-level root causes + 1 was a security-rule mismatch (Bug 5)**.

---

## Status Legend
- **🔴 OPEN** — confirmed, fix not yet applied
- **🟢 FIXED** — code change applied & analyzed
- **🟡 PARTIAL / DEFERRED** — addressed in part, or explicitly deferred to a later version

---

## 🆕 v8.4.10 — "Replace Resume" stuck in an endless loop (upload spinner never ends)

### Bug 7 — Replace Resume: spinner spins forever, upload "not going anywhere" (then v2 appears after leaving/revisiting)
| | |
|---|---|
| Severity | High (UI deadlock — reported by the user on-device) |
| Status | 🟢 **FIXED** |
| Root cause | Firebase Storage Android SDK race: the `UploadTask` reached `INTERNAL_STATE_SUCCESS` (the file physically landed at `resumes/{uid}/latest.pdf`) but a cancel signal — emitted when the app resumed from the document picker / activity lifecycle — arrived AFTER success (`StorageTask: unable to change internal state to: INTERNAL_STATE_CANCELED ... from state:INTERNAL_STATE_SUCCESS`). The Dart `putFile(...)` future then never completed promptly. `PortfolioProvider.uploadResume` → `ResumeService.uploadResume` → `StorageService.uploadResume` were all **unbounded awaits** (unlike `savePortfolio`, which has `saveTimeout`), so `_isUploadingResume` stayed `true` forever → "Replace Resume" showed the infinite spinner/"endless loop". The chain only completed after the user navigated away (lifecycle nudges), which is why the new v2 resume appeared on revisit. |
| Fix | Every network hop in the resume-upload chain is now bounded so a hung future always surfaces a clean error and the spinner always resets: (1) `StorageService` — `putFile`/`putData` under `uploadTimeout` (60 s), `getDownloadURL`/`delete`/`downloadBytes` under `quickTimeout` (15 s), with `TimeoutException` mapped to a "Upload timed out. Check your connection and try again." message; (2) `ResumeService` — the Firestore metadata write in both `uploadResume` and `deleteResume` runs under `PortfolioService.saveTimeout` (20 s); (3) `PortfolioProvider._friendlyError` passes "timed out" messages through verbatim; (4) `ResumeUploadScreen` — `_isPicking` re-entrancy guard (double-tap can't stack pickers/uploads; button shows busy state during the document-picker window) and a **failure snackbar** (previously failures were silently only visible via the banner, making a timeout look like a hang). |
| Files | `lib/services/storage/storage_service.dart`, `lib/services/firestore/resume_service.dart`, `lib/services/firestore/portfolio_service.dart`, `lib/providers/portfolio_provider.dart`, `lib/views/portfolio/resume_upload_screen.dart` |
| Verification | `flutter analyze` 0 issues on all 5 changed files. Manual pass needed on-device: replace resume → success snackbar; simulate offline/hang → "Upload timed out" snackbar + banner + spinner clears; remove resume → spinner clears on failure. |

---

## 🆕 v8.5 — Resume Reviewer Integration & PDF Intelligence (2026-08-08)

### Bug 4 (REOPEN) — Resume Review still asks for resume in text form; can't access the uploaded resume directly
| | |
|---|---|
| Severity | Medium (feature/UX gap) |
| Status | 🟢 **FIXED — v8.5 (MB7 delivered)** |
| What changed | The unfinished v8.4.3 item **MB7 — PDF → text for Resume Review** is now implemented server-side: `reviewResume` accepts `storagePath` (`resumes/{uid}/latest.pdf`), validates `request.auth.uid === owner` + exact path match, downloads the PDF via Admin SDK, extracts text with `pdf-parse@1.1.1` (deep-require `pdf-parse/lib/pdf-parse.js` to avoid the package's test-data `main` side effect), and feeds the extracted text through the EXISTING AI/ATS pipeline, returning the same `{review, usage}` shape. The Resume Reviewer UI now has **Review Uploaded Resume**, **Open Uploaded Resume**, **Replace Resume**, review count + latest ATS, with the manual-paste flow kept as a fallback. |
| Verification | `flutter analyze` 0 errors; `flutter test` **71/71** (65 existing + 6 new storage-path security tests); `node --check functions/index.js` pass; `pdf-parse` smoke-tested on Node against a real Chromium-generated text PDF (extracted all expected text). On-device manual matrix (Upload → Review → ATS → Dashboard → Placement snapshot) still pending — see `docs/todo.md` R10. |
| Files (this pass) | `functions/package.json` (added `pdf-parse@^1.1.1`), `functions/index.js` (`resumeTextFromStorage` + `reviewResume` storagePath branch), `lib/services/ai/resume_review_service.dart`, `lib/providers/resume_review_provider.dart`, `lib/views/resume_review_view.dart`, `test/resume_review_storage_path_test.dart` (new), `docs/todo.md`, `docs/issues.md`, `docs/v8_workspace_tracker.md`, `pubspec.yaml` |

### New finding — pdf-parse bundled pdf.js (v1.10.100) xref strictness
| | |
|---|---|
| Severity | Low (note — not an app bug) |
| Status | 🟢 Documented |
| Details | The `pdf-parse@1.1.1` bundle ships 2017-era pdf.js builds. Its xref parser rejects some hand-crafted *minimal* PDFs (`bad XRef entry`) even when byte-correct by the PDF spec, but successfully parses real PDFs produced by Chromium/Edge. Resumes uploaded to CampusConnect are user-generated PDFs (Chromium/Word/etc.), so this is not reachable in practice. If a future report shows `bad XRef entry` on a real upload, the fix is to render the PDF pages first (client-side) or switch the extractor (e.g., `pdfjs-dist` modern build) — deferred. |
| Verification | Reproduced with a synthetic minimal PDF on Node; real Chromium-generated PDF extracted text correctly. |

---

## 🆕 v8.4.4 — On-Device Re-Verification Fix (post-deploy manual pass)

### Bug 1R — Resume upload says "success" but the dashboard placeholder still shows "No Resume"
| | |
|---|---|
| Severity | High (data-loss appearance — reported by the user during the post-deploy manual pass) |
| Status | 🟢 **FIXED** (MB2 revisit — stale-stream guard) |
| Root cause | `PortfolioService.portfolioStream` maps any snapshot without a `portfolio` key to `PortfolioModel.empty()`. The Firestore SDK replays such a snapshot from the **local cache** (taken BEFORE the upload's `metadata.updatedAt` + `portfolio.resume` write landed) when the app returns from the document picker or after a network flap — the exact conditions in `docs/logs.md` (`Application backgrounded`, `INTERNAL_STATE_SUCCESS`→`INTERNAL_STATE_CANCELED`, `ENETUNREACH`). MB2's listener assigned that stale `empty` value **unconditionally**, overwriting the resume that `uploadResume` had already committed to memory (`_portfolio = updated`). Result: snackbar says "Resume uploaded successfully!", Firestore has the resume, but the dashboard's `ResumeSummaryCard` (a `Consumer<PortfolioProvider>` reading `portfolio?.resume`) shows the "No Resume" placeholder. MB1/MB2/MB3 fixed the persistence paths but not this read-side race. |
| Fix | `PortfolioProvider._listenToPortfolio` now applies a stream event ONLY when it is at least as new as the in-memory state: (1) events while `_isUploadingResume`/`_isSaving` are ignored (the write's in-memory result is authoritative until the server-confirmed event arrives); (2) an `empty` event never overwrites a non-empty portfolio; (3) an event that drops the resume while memory still has one (`current.resume.hasResume == true && fresh.resume.hasResume != true`) is ignored. Deletes are unaffected because `deleteResume`/`reset` set `_portfolio` themselves before the confirmation event arrives. |
| Files | `lib/providers/portfolio_provider.dart` |
| Verification | `flutter analyze` 0 issues on the file; `flutter test` **58/58 passed**. Manual pass needed on-device: upload → snackbar success → dashboard card shows "Resume Uploaded" immediately and after pull-to-refresh → logout → login → resume still present. |

---

## 🆕 v8.4.3 Manual-Test Bug Fixes

### Bug 1 — Resume disappears after pull-to-refresh on the Student Dashboard portfolio
| | |
|---|---|
| Severity | High (data-loss appearance) |
| Status | 🟢 **FIXED** (MB1 + MB2 + MB3; resurrected as Bug 1R, see above) |
| Root cause | Dashboard `RefreshIndicator.onRefresh` was a no-op `Future.delayed(500ms)`; portfolio used a one-shot `get()` with no local cache; a flaky Firestore read/write race (logs: `UNAVAILABLE keepalive failed`, `ENETUNREACH`, Storage upload `INTERNAL_STATE_CANCELED` after `SUCCESS`) made the resume appear deleted after a refresh. |
| Fix | Dashboard refresh now calls `PortfolioProvider.refresh()`; provider subscribes to `PortfolioService.portfolioStream`, keeps last-known-good on error, and snapshots to SharedPreferences (`PortfolioCacheService`); `refresh()`/save never clears `_portfolio` on failure. |
| Files | `lib/views/dashboards/student_dashboard_view.dart`, `lib/providers/portfolio_provider.dart`, `lib/services/portfolio_cache_service.dart` (new) |
| Verification | `flutter analyze` clean (pending run completion); manual: upload → pull-to-refresh → resume persists |

### Bug 2 — Editing a project → Save gets stuck in an endless loop
| | |
|---|---|
| Severity | High (UI deadlock) |
| Status | 🟢 **FIXED** (MB4) |
| Root cause | Manager list pull-to-refresh swapped the in-memory portfolio while the project form was open (save built from a stale/different list and looped); `_save()` had no `try/finally` and no timeout — a hung Firestore write left the button in a permanent spinner. |
| Fix | `_save()` wrapped in `try/finally` (resets `_isSaving` unconditionally); refresh removed from manager list (stream already converges); save reads the **latest** provider state at save time; `savePortfolio` runs under a bounded 20 s timeout. |
| Files | `lib/views/portfolio/projects_manager_screen.dart`, `lib/providers/portfolio_provider.dart` |
| Verification | Manual: edit project → save → returns to list with updated project, spinner always clears |

### Bug 3 — Logging out of the Student Dashboard wipes the entire portfolio (incl. resume)
| | |
|---|---|
| Severity | Critical (data-loss) |
| Status | 🟢 **FIXED** (MB2 + MB3 + MB5) |
| Root cause | No code deletes the portfolio/resume on logout — the "wipe" was memory-only state + a write/read race + `reset()` discarding in-memory data; `uploadResume` also dropped the in-memory update when `_isDisposed` was true mid-flight, and portfolio saves co-triggered the `onProfileUpdatedRefreshAI` recompute. |
| Fix | Offline-first: stream convergence + SharedPreferences snapshot restores on re-login; `reset()` keeps the per-user local cache; `uploadResume`/`deleteResume`/`savePortfolio` commit to memory before the dispose check; `metadata.updatedAt`-driven trigger amplification stopped by `isPortfolioOnlyChange` guard. |
| Files | `lib/providers/portfolio_provider.dart`, `lib/services/portfolio_cache_service.dart`, `functions/index.js` |
| Verification | Manual: upload → logout → login → resume present; `isPortfolioOnlyChange` guard added (call existed without a definition — fixed `ReferenceError`) |

### Bug 4 — Resume Review still asks for resume in text form; can't access the uploaded resume directly
| | |
|---|---|
| Severity | Medium (feature/UX gap) |
| Status | 🟡 **PARTIAL** (MB6 UX bridge done; **MB7 PDF→text deferred**) |
| Root cause | `ResumeReviewView` is text-only; nothing reads `PortfolioProvider.portfolio.resume`; no PDF text-extraction exists client- or server-side; `ResumeMetadata.parserVersion` is an explicit placeholder. |
| Fix (this pass) | MB6: "Using your uploaded resume" card on the review screen — file name, version, ATS chip, Open Uploaded Resume (download URL), and a clear note that review uses pasted text. |
| Deferred (MB7 → v8.5) | PDF→text: server-side `reviewResume(storagePath)` path (Admin SDK reads PDF bytes → extract text → existing AI pipeline) or a client-side Dart package. **Reclassified 2026-08-07: this is the first feature of v8.5, not a bug fix.** A `pdf-parse` dependency was trialled and reverted — no dependency added in this pass. |
| Files | `lib/views/resume_review_view.dart` |
| Verification | Manual: with an uploaded resume, the review screen shows the card + Open action |

### Bug 5 — No notification came to the alumni about the mentorship request
| | |
|---|---|
| Severity | High (broken feature) |
| Status | 🟢 **FIXED** (MB8) |
| Root cause | Definitive + confirmed in logs: `Write failed at users/.../notifications/...: PERMISSION_DENIED` + `Error creating mentorship request notification`. Client-side `NotificationsService.createNotification(alumniId, ...)` writes to a **different user's** notifications subcollection; Firestore rule F7 (`create: if isOwner(userId)`) blocks it. Same bug affected respond-to-request (alumni→student) and chat messages (sender→recipient). Placement notifications work (owner write). |
| Fix | Three Admin-SDK Firestore triggers added: `onMentorshipRequestCreated` (→ alumni), `onMentorshipRequestResponseNotifyStudent` (→ student accepted/rejected, idempotent doc id), `onChatMessageCreated` (→ recipient, 30-day backfill guard); client-side best-effort cross-user writes **removed** from `MentorshipService.createRequest`, `respondToRequest`, and `ChatService.sendMessage` so permission-denied log noise disappears. |
| Files | `functions/index.js`, `lib/services/firestore/mentorship_service.dart`, `lib/services/firestore/chat_service.dart` |
| Verification | `node --check functions/index.js` passed; **deployed** to `campusconnect-firebase-project` (all 3 triggers created successfully, all existing functions updated); manual: student requests → alumni gets notification |

### Bug 6 — Mentorship request tab has no way to view the student's portfolio
| | |
|---|---|
| Severity | Medium (dead feature) |
| Status | 🟢 **FIXED** (MB9) |
| Root cause | Request cards were plain `Container`s with **no tap target** — `MentorshipRequestDetailView` (which holds the alumni "View Student Portfolio" button) was unreachable from the list. |
| Fix | Cards wrapped in `Material` + `InkWell` → `mentorshipRequestDetailRoute` with `arguments: request.id` (detail view already handles String args); **alumni cards also get a compact "View Student Portfolio" button** → `portfolioReadOnlyRoute` with `request.studentId`. |
| Files | `lib/views/mentorship/mentorship_requests_view.dart` |
| Verification | Manual: alumni taps card → detail; taps View Portfolio → read-only portfolio |

---

## Additional Findings From the Logs (confirmed, not user-reported)
| Log evidence | Meaning | Status |
|---|---|---|
| `Write failed at users/.../notifications/...: PERMISSION_DENIED` | Bug 5 hard blocker | 🟢 Fixed (MB8 triggers) |
| `StorageTask unable to change internal state to INTERNAL_STATE_CANCELED ... from INTERNAL_STATE_SUCCESS` | Upload success then cancel — Bug 1/3 metadata race | 🟢 Fixed (MB1/2/3 + v8.4.4 Bug 1R stale-stream guard) |
| `StorageException Object does not exist at location. 404` | Idempotent delete path / cancelled-upload artifact | No change needed (delete is idempotent) |
| `Firestore ... UNAVAILABLE Keepalive failed / ENETUNREACH` | Flaky network during test — exposed Bugs 1/2/3 | 🟢 Mitigated (offline-first + cache + timeouts) |
| `ResumeReviewProvider: Loaded 0 history items` | Per-account state, not a bug | No action |
| `App Check ... No AppCheckProvider installed` | Pre-existing, non-blocking placeholder | No action |

---

## 🆕 Additional Findings From the v8.4.3 Log Audit (project_info__15.md, 2026-08-07)

> Source: full audit of `docs/logs.md` cross-referenced against the current source. **No unknown app-code bugs were found** — the log is the pre-fix session that produced Bugs 1–6. The 27 log signatures reduce to the fixes above, documented non-issues, emulator/GMS artifacts, and the six entries below.

| # | Log evidence | Meaning | Disposition |
|---|---|---|---|
| N1 | `W/System: A resource failed to call close.` (4×, always right after `FilePickerUtils: Caching from URI ... resume.pdf`) | A stream/PFD was opened and not closed during the file-picker cache step. App-side verified: `StorageService.uploadResume` uses `ref.putFile` / `getData` (self-contained) — the app opens no stream in this flow. | **No app fix** — plugin-internal; warning, not a crash. Re-check only if it appears without a file-pick |
| N2 | `I/FilePickerUtils: Caching from URI ...` → `cache/file_picker/{timestamp}/resume.pdf` (5 picks = 5 copies) | `file_picker` writes each pick to its own timestamped dir under the OS cache; nothing removes old ones. Cache dir is OS-managed and evicted under storage pressure; files are small PDFs. | **No app fix** — optional hygiene only |
| N3 | `E/IPCThreadState: Binder transaction failure ... -28` + `DeadObjectException` + `E/FA: Failed to get app instance id` (run 2) | GMS measurement binder buffer exhaustion on the x86_64 emulator (calls originate in `com.google.android.gms.dynamite_measurementdynamite`). | Emulator/GMS artifact — monitor only; act only if seen on a physical device |
| N4 | `D/FilePickerDelegate: Selected type */*` | Plugin logs the raw intent MIME; the `Allowed file extensions mimes: [application/pdf]` line directly above proves the allowlist is active. | Info — filter is **not** broken |
| N5 | `W/Firestore: WatchStream ... Target id not found: 10 / 72` | Client tears down watch targets on logout/provider reset. | Info — expected |
| N6 | `I/Choreographer: Skipped 47/140 frames` | Cold-start JIT + GMS boot on a debug emulator. | Info — re-check in profile mode on a real device if UI smoothness matters |
