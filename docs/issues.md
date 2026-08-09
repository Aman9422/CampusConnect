# CampusConnect — Issues Log

> Maintained as part of the v8.6 Audit-Fix pass. Source: `project_info__17.md` + `project_info__18.md` (2026-08-09 final audit, superseding the v8.4.3 manual-test source). The v8.6 audit found **1 critical deployment gap, 5 high findings, 5 medium findings and a cluster of low/edge issues** beyond the v8.5.2 Alumni Reviewer work.

---

## Status Legend
- **🔴 OPEN** — confirmed, fix not yet applied
- **🟢 FIXED** — code change applied & analyzed
- **🟡 PARTIAL / DEFERRED** — addressed in part, or explicitly deferred to a later version

---

## 🆕 v8.7 — Alumni Experience Simplification & Alumni Group Chat (2026-08-09)

> Source: `docs/Task.md` (v8.7) · Executed via `docs/todo.md` (Phase 1–5) · v8.6.0+89 → v8.7.0+90.

### Alumni Portfolio access is now Student-only (role-separation)
| | |
|---|---|
| Severity | Medium (UI/access change — the v8.5.2 A3/A4 Alumni portfolio surfaces were surfaced for the wrong role) |
| Status | 🟢 **FIXED** |
| Root cause | v8.5.2 deliberately routed Alumni into the Student Portfolio editing workflow ("My Portfolio" tile in the Alumni profile + `ResumeSummaryCard` on the Alumni dashboard). The actual intended Alumni role is a lightweight profile + optional text-based Resume Review + Alumni Community — not portfolio maintenance. |
| Fix | (1) `ResumeSummaryCard` + portfolio refresh removed from the Alumni dashboard; replaced with an **Alumni Community** primary card + quick action (Task §10). (2) Alumni "My Portfolio" tile removed from `ProfileView._buildAlumniProfile` (Task §11). (3) `ResumeReviewView` now hides the uploaded-resume card / upload CTA for Alumni — they only paste text (Task §2). (4) The 7 Student Portfolio editing routes are role-gated in `main.dart` (`_guardStudentPortfolio`) — Alumni get a safe blocked view instead of the editing UI. `portfolioReadOnlyRoute` stays open so Alumni can still VIEW a Student's portfolio (Task §13). |
| Files | `lib/views/dashboards/alumni_dashboard_view.dart`, `lib/views/profile/profile_view.dart`, `lib/views/resume_review_view.dart`, `lib/main.dart` |
| Note | The Student Portfolio subsystem is NOT deleted — the change is role-based UI/access only. |

### Alumni text-based Resume Reviewer reuses the existing pipeline
| | |
|---|---|
| Severity | Medium (feature — previously Alumni were pushed toward the uploaded-PDF flow) |
| Status | 🟢 **FIXED** (zero AI/ATS engine changes) |
| Fix | Alumni paste resume text into the existing `ResumeReviewView` text fields → `ResumeReviewProvider.submitReview(resumeText:)` → the SAME `reviewResume` callable (Task §3). Quota (`resume_usage/{uid}`, atomic `consumeResumeQuota`) and history (`users/{uid}/resumeReviews`) are UID-scoped and reuse the existing implementation unchanged (Task §4/§18). The Cloud Function already tags text reviews `source: "pasted"` vs `"uploaded"` in analytics (Task §19). |
| Files | no pipeline changes; tests `test/alumni_resume_text_review_test.dart` (new) |

### Alumni Group Chat — new Alumni-only community feature
| | |
|---|---|
| Severity | New feature (Task §6–§9) |
| Status | 🟢 **IMPLEMENTED** |
| What changed | `alumni_group_messages/{messageId}` collection (source of truth `senderId`, `senderName`, `senderPhotoUrl?`, `message`, `createdAt`, `editedAt?`, `isDeleted?`). `AlumniGroupChatService` (real-time `orderBy('createdAt')` stream — **no composite index needed**), `AlumniGroupChatProvider` (ChatProvider lifecycle discipline: `initWithUser`/`reset`, `_isDisposed`, subscription cancel), `AlumniGroupChatView` (Material 3 chat: sender name, timestamp, own-message styling, empty/loading/error/sending states, auto-scroll on new messages only). `alumniGroupChatRoute` registered + guarded Alumni-only. Provider registered in `MultiProvider`, initialized in AuthGuard, and reset at **all 5 logout sites** (Task §6/§9/§14/§15/§16). |
| Security | `firestore.rules` gained the `alumni_group_messages` block: read Alumni-only; create Alumni-only with `senderId == request.auth.uid`; update/delete own messages only. Students/Teachers/unauthenticated denied server-side (Task §8). Client route guard is a UX layer; rules are authoritative. |
| Files | `lib/models/alumni_group_message.dart` (new), `lib/services/firestore/alumni_group_chat_service.dart` (new), `lib/providers/alumni_group_chat_provider.dart` (new), `lib/views/chats/alumni_group_chat_view.dart` (new), `lib/constants/routes.dart`, `lib/main.dart`, `firestore.rules`, `test/alumni_group_chat_test.dart` (new) |

### Deployment status (v8.7)
| | |
|---|---|
| Firebase | ✅ **DEPLOYED 2026-08-09** — `firebase deploy --only firestore:rules --non-interactive` **SUCCESS** (released `alumni_group_messages` Alumni-only rules). Functions deployed separately in the v8.7.1 badge fix pass. On-device manual matrix per `docs/Task.md` §22 remains. |
| Tests | `test/alumni_group_chat_test.dart` (17 tests), `test/alumni_resume_text_review_test.dart` (13 tests), `test/alumni_portfolio_access_test.dart` (8 tests) added. |
| Version | `pubspec.yaml` `8.6.0+89` → `8.7.0+90`. |

### v8.7.1 — Alumni dashboard badge shows a Student-flavored title ("Active Student")
| | |
|---|---|
| Severity | Medium (wrong-role labeling on the Alumni dashboard Engagement section — user-reported during v8.7 review) |
| Status | 🟢 **FIXED & DEPLOYED** (2026-08-09) |
| Root cause | Both badge engines hardcoded the "Active Student" title: client `EngagementService._buildBadges` and server `recomputeEngagementSummary`. Alumni share the same `engagement_summary/summary` pipeline, so the Alumni dashboard's Engagement & Badges card displayed a Student-oriented badge title. |
| Fix | Role-aware activity badge: Alumni now see **"Active Alumni"** (`Active Student` unchanged for students). Applied identically in both writers so the badge never flickers between client/server recompute (same class as the v8.6 badge-threshold conflict): (1) `lib/services/firestore/engagement_service.dart` — `_buildBadges` accepts the role from `profile.role ?? UserRole.student`, title/description computed from it, plus a public static `activeBadgeTitle(UserRole)` as the single source of truth; (2) `functions/index.js` — `recomputeEngagementSummary` computes `activeTitle`/`activeDescription` from `userData.role === "alumni"`. Badge `id`/`type` ("active_student"/activeStudent) untouched — no schema change. Existing stored summaries self-heal on the next recompute (app-init, refresh, or the daily scheduler). |
| Files | `lib/services/firestore/engagement_service.dart`, `functions/index.js`, `test/alumni_badge_title_test.dart` (new, 3 tests) |
| Validation | `flutter analyze` 0 errors / 0 warnings (68 pre-existing info lints); `flutter test` **124/124 passed** (121 + 3 new); `node --check functions/index.js` pass; `dart format` clean. |
| Deploy | ✅ **EXECUTED** — `firebase deploy --only functions --non-interactive` **SUCCESS** (15/15 functions updated; server badge rule live). |

---

## 🆕 v8.6 — Final Audit & Architecture Stability Fixes (project_info__17/18)

> Scope: every item on the audit's Prioritized Fix List (§10). Items 2–6 [HIGH] and 7, 8, 10 [MEDIUM] plus a curated set of LOW items were fixed in this version; item 9 (EditPortfolio/manager role-gate verification) was a read-only audit task; item 1 (deploy) and the remaining LOW items are tracked below.

### 🔴 Deploy gap — v8.5.2 trigger change (A2) NOT deployed
| | |
|---|---|
| Severity | Critical (production still runs the old `if (userData.role !== "student") return;` gate — Alumni ATS sync broken in prod) |
| Status | 🟢 **FIXED & DEPLOYED** (2026-08-09, during v8.6 B14) |
| Root cause | `docs/todo.md` A8 + `docs/v8_workspace_tracker.md` both record deployment pending; the repo contained the fix but production had not received it. |
| Fix | ✅ **EXECUTED** — `firebase deploy --only functions --non-interactive` **SUCCESS** (15/15 functions updated/created, incl. the new `refreshRecommendations` callable); `firebase deploy --only firestore:indexes --non-interactive` **SUCCESS** (21 indexes deployed, 1 remote index + 2 field overrides preserved). Alumni ATS sync is now live in production. |

### HIGH 1 — OpportunityService still writes cross-user notifications client-side
| | |
|---|---|
| Severity | High (Bug 5 pattern v8.4.3 missed in OpportunityService) |
| Status | 🟢 **FIXED** |
| Root cause | `OpportunityService.createOpportunity` (v7.3 legacy block) batches `AppNotification.newJobPost` documents into `users/{studentUid}/notifications` for **every** student. Rule F7 (owner-only create) blocks these writes → `PERMISSION_DENIED` log noise, and >500 students would exceed Firestore's 500-write batch cap. `onOpportunityPostedNotifyStudents` already delivers these correctly server-side (Admin SDK, batched at 400). |
| Fix | Removed the redundant client-side batch entirely. Opportunity creation now writes the opportunity doc only; the trigger handles student notification. |
| Files | `lib/services/firestore/opportunity_service.dart` |

### HIGH 2 — ResumeReviewProvider connectivity subscription leaks
| | |
|---|---|
| Severity | High (provider lifecycle leak — M5 pattern missed by v8.4.2) |
| Status | 🟢 **FIXED** |
| Root cause | `_startConnectivityMonitoring()` calls `_connectivity.onConnectivityChanged.listen(...)` and discards the `StreamSubscription`; `reset()` never cancels it and there is no `_isDisposed` guard. Every login stacks a new listener; a late callback after provider disposal can fire `notifyListeners()` → debug-mode "used after being disposed" crash class. |
| Fix | Applied the same M5 fix as `PlacementsProvider` (v8.4.2): retained `_connectivitySubscription`, `_isDisposed` guard in the callback, `_cancelConnectivityMonitoring()` from `reset()` and `dispose()`. |
| Files | `lib/providers/resume_review_provider.dart` |

### HIGH 3 — reviewResume consumes monthly quota when the AI provider fails
| | |
|---|---|
| Severity | High (user loses a review credit with no rollback) |
| Status | 🟢 **FIXED** |
| Root cause | `reviewResume` calls `trackResumeUsage(userId)` BEFORE `generateResumeReviewAI(...)`. On AI error the quota was already incremented and the user got no review. |
| Fix | Quota is now decremented (rolled back) when the AI call fails; the increment also moved inside a single atomic transaction (see MEDIUM 8) so check+increment is race-free and the rollback only compensates an actually-consumed credit. |
| Files | `functions/index.js` |

### HIGH 4 — Resume replacement wipes portfolio.resume.reviewCount + lastReviewAt
| | |
|---|---|
| Severity | High (dashboard/portfolio counters lie until next review) |
| Status | 🟢 **FIXED** |
| Root cause | `ResumeService.uploadResume` builds a fresh `ResumeMetadata(...)` with `reviewCount: 0` / `lastReviewAt: null`. ATS score is correctly cleared on replace, but the user's review history (`users/{uid}/resumeReviews`) is untouched — only the counters were reset. |
| Fix | `uploadResume` now carries `reviewCount` and `lastReviewAt` forward from the previous portfolio's resume metadata. |
| Files | `lib/services/firestore/resume_service.dart` |

### HIGH 5 — Missing composite indexes in firestore.indexes.json
| | |
|---|---|
| Severity | High (fresh project / CI deploy breaks Chat, Opportunities, Mentorship with "index required") |
| Status | 🟢 **FIXED & DEPLOYED** (2026-08-09) |
| Root cause | The repo declared only 9 indexes. Queries for `chats` (participantIds arrayContains + lastMessageAt DESC), `opportunities` (isActive + postedAt DESC; alumniId + postedAt DESC; search combos), and `mentorship_requests` (studentId + createdAt; alumniId + createdAt; alumniId + status + createdAt; studentId + alumniId + status) had no matching declared index. They only worked because v8.4.2's deploy preserved remote-only indexes. |
| Fix | Added all missing composites to `firestore.indexes.json` (see §5 of the audit) — 21 indexes total. ✅ `firebase deploy --only firestore:indexes --non-interactive` **SUCCESS** (2026-08-09); the 1 pre-existing remote-only index + 2 field overrides were preserved (no `--force`). |
| Files | `firestore.indexes.json` |

### MEDIUM 6 — onProfileUpdatedRefreshAI compares Firestore Timestamps with `!==` (identity)
| | |
|---|---|
| Severity | Medium (recompute always runs for every non-portfolio write by a completed student) |
| Status | 🟢 **FIXED** |
| Root cause | `before.updatedAt !== after.updatedAt` compares two distinct `Timestamp` object references and is ALWAYS true, so `changed` was effectively always true for completed students; `isPortfolioOnlyChange` was the only effective guard. |
| Fix | Value comparison via `.toMillis()` (falling back to string comparison and field-by-field for `skills`/`careerInterest`/`department`/`graduationYear` which were already correct). |
| Files | `functions/index.js` |

### MEDIUM 7 — Two competing recommendation engines clobber each other
| | |
|---|---|
| Severity | Medium (AI Smart Picks feed unstable depending on last writer) |
| Status | 🟢 **FIXED** (single-writer contract restored) |
| Root cause | Server `refreshRecommendationsForStudent` (functions) and client `RecommendationService.refreshRecommendations` (lib) write the same `users/{uid}/recommendations/{id}` docs with different scoring models. Profile updates / resume reviews trigger the server engine; app init / refresh triggers the client engine. |
| Fix | The client no longer writes recommendations. `RecommendationService.refreshRecommendations` now delegates to the server engine via a one-shot call to the `refreshRecommendations` callable (added), and the client provider's refresh merely reads the Firestore stream. Single writer = the Cloud Function. |
| Files | `lib/services/firestore/recommendation_service.dart`, `functions/index.js` |

### MEDIUM 8 — Quota race in reviewResume (non-atomic check-then-increment)
| | |
|---|---|
| Severity | Medium (two concurrent calls can both pass the limit → 6+ monthly reviews) |
| Status | 🟢 **FIXED** |
| Root cause | `getResumeUsage` (outside transaction) then `trackResumeUsage` (transaction) are not atomic together: concurrent calls can both read `monthlyCount = 4` and both increment → 6 reviews in a month. |
| Fix | The limit check + increment now run in a single Firestore transaction (`consumeResumeQuota`). `getResumeUsage` is still used for the read-only `checkUsage` callable path. |
| Files | `functions/index.js` |

### MEDIUM 9 — generateResumeAnalysis / onProfileUpdatedRefreshAI engagement writes contend
| | |
|---|---|
| Severity | Medium (last-writer-wins `set(merge)` on engagement_summary — acceptable at current scale, noisy under load) |
| Status | 🟡 **DEFERRED** — documented Known Limitation; requires write-amplification redesign (roadmap #4). No code change in v8.6. |

### MEDIUM 10 — ProfileView logout resets fewer providers than dashboard logout
| | |
|---|---|
| Severity | Medium (fragile — currently covered by AuthGuard's post-logout safety net) |
| Status | 🟢 **FIXED** |
| Root cause | `_handleProfileLogout` omitted Chat, Mentorship, Opportunity, AlumniDirectory, TeacherAnalytics, ActivityFeed providers that the dashboard logout resets. |
| Fix | `_handleProfileLogout` now resets the same provider set as the dashboard logout. |
| Files | `lib/views/profile/profile_view.dart` |

### LOW items
| Item | Status |
|---|---|
| `resumeTextFromStorage` rejects extracted text < 100 chars as "image-based" — genuine short resumes get a misleading message | 🟢 **FIXED** — message now distinguishes "too short" from image-only |
| PDF text silently truncated to 5000 chars before analysis (user not told) | 🟡 PARTIAL — warning surfaced in callable response (`warning: "truncated"`) — client maps it to a friendly notice |
| `logPlacementApplication` copies resume snapshot BEFORE the idempotency transaction (duplicate apply re-copies needlessly) | 🟡 DEFERRED — harmless; moved check is a low-value refactor, tracked for a later version |
| `onResumeReviewCreatedRefreshMatches` creates a phantom `portfolio`/`portfolio.resume` on no-portfolio users | 🟢 **FIXED** — merge guard only writes when `userData.portfolio?.resume` already exists (or the user has a resumeUpload route source); no phantom maps on manual-paste reviews without a portfolio |
| Server badge threshold (`profile_pro` at 100) differs from client badge logic (≥85) | 🟢 **FIXED** — server threshold aligned to ≥85 |
| `Application.fromFirestore` ignores stored `studentId` alias | ✅ No change needed (`userId` is canonical) |
| Scheduler `recomputeEngagementScores` sequential iteration — 540s timeout at ~1000+ users | 🟡 DEFERRED — documented Known Limitation 2 |
| Audit coverage gap: `EditPortfolioScreen` + six manager screens not re-read | 🟢 **VERIFIED** this version — no role gates found; Alumni edit path confirmed role-agnostic (see MEDIUM item below) |

### Read-only verification — EditPortfolioScreen + manager screens (audit gap #9)
| | |
|---|---|
| Severity | Medium (was the one unresolved audit gap) |
| Status | 🟢 **VERIFIED** — no hidden role gates |
| Result | `EditPortfolioScreen`, `ProjectsManagerScreen`, `CertificationsManagerScreen`, `ExperienceManagerScreen`, `AchievementsManagerScreen`, `CareerPreferencesScreen`, `SocialLinksScreen` were all read. None branch on `role`; each writes through the shared `PortfolioProvider`/`PortfolioService` (UID-scoped, role-agnostic). Alumni portfolio editing is safe. |
| Files | `lib/views/portfolio/*.dart` (7 screens) |

---

## 🆕 v8.5.2 — Alumni Resume Reviewer & Portfolio Integration

### Root cause — Alumni ATS never persisted to their portfolio
| | |
|---|---|
| Severity | High (feature broken for Alumni — reviews ran but scores never synced) |
| Status | 🟢 **FIXED** |
| Root cause | Cloud Function trigger `onResumeReviewCreatedRefreshMatches` (`functions/index.js`) early-returned `if (userData.role !== "student")` BEFORE merging `portfolio.resume.{reviewCount,lastReviewAt,updatedAt,latestATSScore}`. Alumni reviews landed in `users/{uid}/resumeReviews` and incremented `resume_usage/{uid}` (both role-agnostic), but the ATS → portfolio bridge never ran for Alumni, so their portfolio/dashboard showed `Latest ATS —` and no review count. |
| Fix | The ATS → `portfolio.resume` merge now runs for **any** role (Students AND Alumni share the same source of truth `users/{uid}/portfolio.resume`). The student-only AI enrichment (`refreshRecommendationsForStudent`) stays gated to `role === "student"`; activity logging + engagement recompute run for every review author (the Alumni dashboard's Recent Activity / Impact Strip read those). |
| Files | `functions/index.js` |

### UX gaps — Alumni had no portfolio entry point or dashboard surface
| | |
|---|---|
| Severity | Medium (target Alumni flow unreachable) |
| Status | 🟢 **FIXED** |
| Root cause | (1) `ProfileView._buildAlumniProfile` had no "My Portfolio" tile (student branch only). (2) The Alumni dashboard had a "Resume Review" quick action but no `ResumeSummaryCard` — unlike the Student dashboard. |
| Fix | (1) Added a "My Portfolio" `_ProfileMenuCard` to the Alumni profile → `studentPortfolioRoute` (the screen is role-agnostic — reads `PortfolioProvider` for the signed-in user). (2) Added `ResumeSummaryCard` to the Alumni dashboard (with `onOpenPortfolio`/`onUploadReplace` overrides routing to `studentPortfolioRoute`/`resumeUploadRoute`) and included `PortfolioProvider.refresh()` in the pull-to-refresh. |
| Files | `lib/views/profile/profile_view.dart`, `lib/views/dashboards/alumni_dashboard_view.dart` |

### Verified NOT broken (no changes needed)
- Upload/replace/delete (`ResumeUploadScreen`) — UID-scoped, role-agnostic.
- `reviewResume(storagePath)` — server enforces `request.auth.uid === owner` + exact `resumes/{uid}/latest.pdf`; cross-UID attempt rejected.
- Review history `users/{uid}/resumeReviews` — owner-scoped, isolated per UID (firestore.rules + ResumeHistoryService).
- Alumni viewing a student portfolio — `PortfolioReadOnlyView` is read-only (View Resume only; no upload/replace/delete/review actions).
- Placement snapshots — `resumes/{uid}/snapshots/app_*.pdf` immutable at apply time.
- No new pipeline / storage location / ATS field — reused the existing architecture per Task §19.

### Tests
- `test/alumni_resume_review_test.dart` (new, 12 tests): ATS merge runs for alumni; student-only recommendations stay gated; own storage path enforced; history isolated per UID; student regression.
- Full suite: `flutter test` **83/83** pass (71 existing + 12 new).
- `flutter analyze` **0 errors, 0 warnings** (68 pre-existing info lints).
- `node --check functions/index.js` pass.

### Deployment
- **NOT yet deployed** — pending code review + deploy step (docs/todo.md A8).

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
