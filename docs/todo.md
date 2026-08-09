# CampusConnect v8.7 — Alumni Experience Simplification & Alumni Group Chat

> Portfolio is a Student career-development feature. Alumni use a lightweight profile + optional text-based Resume Review + Alumni Community Chat.

## Task Status

- [x] **Phase 0: Audit & Planning**
  - [x] Inspect routing, providers, services, Firestore schema/rules, Cloud Functions, and user role model
  - [x] Document current v8.6 architecture and decide integration points (see `project_info__19.md`)

- [x] **Phase 1: Role Separation (UI/access)**
  - [x] Hide/remove Portfolio navigation & workflow from all Alumni surfaces (Dashboard, Profile, nav, quick actions, resume cards)
  - [x] Guard portfolio routes for Alumni (safe redirect / blocked message)
  - [x] Confirm Student Portfolio remains fully intact

- [x] **Phase 2: Alumni Text-Based Resume Reviewer**
  - [x] Alumni Resume Review screen shows text-input only (hide uploaded-resume card / upload CTA for Alumni)
  - [x] Wire Alumni text reviews into the existing Resume Review pipeline (no second AI/ATS engine)
  - [x] Store Alumni review history under their own UID; reuse existing quota
  - [x] Keep Student uploaded-PDF reviewer unchanged

- [x] **Phase 3: Alumni Group Chat**
  - [x] Create AlumniGroupChatService (Firestore `alumni_group_messages/{messageId}`)
  - [x] Create AlumniGroupChatProvider (real-time stream, send, loading/error states)
  - [x] Create AlumniGroupChatView (Material 3 chat UI: message list, timestamps, sender name, input bar, empty/loading/error states, auto-scroll)
  - [x] Add route (`alumniGroupChatRoute`) and navigation entry point on Alumni Dashboard
  - [x] Update Firestore rules (read/create Alumni-only, sender UID = request.auth.uid, update/delete own messages only)
  - [x] Add Firestore index only if required for chat query — **not required** (single-field `orderBy('createdAt')`, no composite)

- [x] **Phase 4: Alumni Dashboard / Profile updates**
  - [x] Update Alumni Dashboard primary actions (Alumni Community, Resume Review, Profile)
  - [x] Keep Alumni Profile lightweight; no portfolio requirements

- [ ] **Phase 5: Docs, Version & Validation**
  - [x] Update pubspec version to v8.7 per convention (`8.6.0+89` → `8.7.0+90`)
  - [x] Update `docs/todo.md`, `docs/issues.md`
  - [x] Add tests for Alumni behavior (portfolio access, text review, group chat security/state)
  - [x] Update `docs/v8_workspace_tracker.md`, `docs/confirmation.md`
  - [x] Run `flutter analyze`, `flutter test`, `node --check functions/index.js`, `dart format` on changed files
  - [ ] Manual testing matrix verification (Student, Alumni, Security) — requires on-device verification, pending

## Detailed Rollout Log

### Phase 1 — Role Separation (UI/access)

- **Alumni Dashboard** (`lib/views/dashboards/alumni_dashboard_view.dart`): removed the v8.5.2 `ResumeSummaryCard` + `PortfolioProvider` watch/refresh. Replaced with an **Alumni Community** primary card (→ `alumniGroupChatRoute`) and a "Community" quick action. Dashboard no longer implies Alumni must build a portfolio (Task §10).
- **Alumni Profile** (`lib/views/profile/profile_view.dart`): removed the v8.5.2 (A3) Alumni "My Portfolio" tile. Only Edit Profile remains (Task §11). The Student/Teacher branch keeps its student-only "My Portfolio" tile unchanged.
- **Resume Review UI** (`lib/views/resume_review_view.dart`): Alumni see only **Target Role (Optional)** + **Resume Text**; the uploaded-resume card (Review/Open/Replace + upload CTA) is gated `if (!isAlumni)` (Task §2/§5). Students keep the full uploaded-PDF integration.
- **Portfolio route guards** (`lib/main.dart`): `_guardStudentPortfolio` wraps the 7 editing routes (`studentPortfolioRoute`, `editPortfolioRoute`, managers, `resumeUploadRoute`). Alumni get a safe blocked view ("Portfolios are for Students" + CTA to Alumni Community). `portfolioReadOnlyRoute` remains open for read-only Alumni → Student viewing (Task §13).

### Phase 2 — Alumni Text Resume Reviewer

- Alumni paste resume text (≥100, ≤5000 chars — existing `ResumeReviewService` validation) → `submitReview(resumeText:)` → the SAME `reviewResume` callable (Task §3). **No second AI/ATS engine, no second storage system.**
- Quota (`resume_usage/{uid}`, atomic `consumeResumeQuota`) and history (`users/{uid}/resumeReviews`) are UID-scoped and reused unchanged (Task §4/§18).
- Cloud Function analytics already tags text reviews `source: "pasted"` vs uploaded `"uploaded"` (Task §19) — no function change needed.

### Phase 3 — Alumni Group Chat

- `lib/models/alumni_group_message.dart` — message model (`senderId`, `senderName`, `senderPhotoUrl?`, `message`, `createdAt`, `editedAt?`, `isDeleted?`).
- `lib/services/firestore/alumni_group_chat_service.dart` — real-time stream `orderBy('createdAt')` (client-side soft-delete filter avoids a composite index — Task §16), `sendMessage` with `FieldValue.serverTimestamp()`, `deleteMessage`.
- `lib/providers/alumni_group_chat_provider.dart` — ChatProvider lifecycle discipline: `initWithUser` / `reset` / `_isDisposed` guards, stream subscription cancelled on reset/dispose, `isSending`/`error`/`clearError`.
- `lib/views/chats/alumni_group_chat_view.dart` — Material 3 chat: sender name + timestamp, own-message bubbles right-aligned, date separators, empty/loading/error/sending states, **auto-scroll only when the message count grows** (not on keystrokes).
- `lib/constants/routes.dart` — `alumniGroupChatRoute`.
- `lib/main.dart` — provider registered in `MultiProvider`, initialized in AuthGuard post-frame, **reset at all 5 logout sites** (AuthGuard fallback, Alumni dashboard, Profile view, Student dashboard, Teacher dashboard), route wired with `_guardAlumniGroupChat` (non-Alumni → denied view).
- `firestore.rules` — `alumni_group_messages` block: read Alumni-only; create Alumni-only with `senderId == request.auth.uid`; update/delete own messages only. Students/Teachers/unauthenticated denied (Task §8).
- No Firestore index added — the single-field `orderBy('createdAt')` query is served by the automatic single-field index (Task §16).

### Phase 4 — Alumni Dashboard / Profile

- Dashboard primary actions: **Alumni Community**, **Resume Review**, Mentorship, Directory (quick actions) + Alumni Community card at the top.
- Profile stays lightweight — no Portfolio editing requirements (Task §11).

### Phase 5 — Docs, Version & Validation

- `pubspec.yaml`: `8.6.0+89` → `8.7.0+90`.
- `docs/issues.md`: v8.7 section added (role separation, text reviewer, group chat, security, deployment status).
- Tests added: `test/alumni_group_chat_test.dart` (17), `test/alumni_resume_text_review_test.dart` (13), `test/alumni_portfolio_access_test.dart` (8).
- Validation: `flutter analyze` **0 errors / 0 warnings** (68 pre-existing info lints); `flutter test` **121/121 passed** (83 pre-existing + 38 new); `node --check functions/index.js` pass; `dart format` clean on all changed files.
- Pending: manual matrix (on-device) + `firebase deploy --only firestore:rules` to release the `alumni_group_messages` rules.
