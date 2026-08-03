# CampusConnect v8.4 — Fix Tracker

> Source: final audit report `docs/confirmation.md` §9 (prioritized fix list from 2026-08-03).
> Workflow: fix one problem → mark it done → move to the next.

## 🔴 Critical

- [x] **F1 — Security: block role self-elevation in `firestore.rules`** — `canWriteRole()` guard added to the owner write rule; role immutable once persisted.
- [x] **F2 — Routing: register `chatDetailRoute`** — `main.dart` `onGenerateRoute` now handles `chatDetailRoute` (same as `chatRoute`); activity-feed taps open the chat instead of crashing.
- [x] **F3 — Indexes: add `notifications` type ASC / createdAt ASC** — added to `firestore.indexes.json` so `maybeCreateNotification`'s `type == … + createdAt >= …` range query works (was DESC, which cannot serve the ascending range).

## 🟠 High

- [x] **F4 — Mentorship completion flow unreachable** — completion block moved outside the `status == pending` branch in `mentorship_request_detail_view.dart`; "Mark as Completed" + completion info now render for accepted/completed requests.
- [x] **F5 — H4 per-section portfolio saves** — `PortfolioService.savePortfolio` now writes per-section dotted-path diffs (with `previous`); provider passes `previous`. No more whole-map clobbering of sibling/remote edits.
- [x] **F6 — Provider guards (L4 + L5)** — `initWithUser` guard is uid-based (`_lastUid`); `refresh`/`uploadResume`/`deleteResume` bail out when `_isDisposed` (no `notifyListeners` after logout).

## 🟡 Medium

- [x] **F7 — Tighten notifications create rule** — `users/{uid}/notifications` create is now `isOwner(userId)`, not any authenticated user. System notifications are written by the Cloud Functions Admin SDK, which bypasses rules — no breakage.
- [x] **F8 — Remove dead code (finish M8)** — removed `PortfolioService.updateResumeMetadata`/`deletePortfolio` and `ResumeUploadResult.version`/`toMetadataMap` (+ unused `cloud_firestore` import).
- [x] **F9 — Read-only view error vs empty** — `PortfolioService.getPortfolio` rethrows real errors (permission/network) so the read-only view shows "Failed to load portfolio." instead of a misleading empty state.

## 🔵 Low

- [x] **F10 — Inverted-date display guard in manager screens** — `projects_manager_screen.dart` + `experience_manager_screen.dart` `_formatDuration` now defend against `end.isBefore(start)` (same guard the read-only view already had).
- [x] **F11 — Typed `dynamic profile` params + pubspec version bump** — `StudentPortfolioScreen` `_buildCompletionHeader`/`_buildEducationSection` now take `StudentProfile?`; version bumped `5.1.2+3` → `8.4.0+84`.

## ✅ Verification

- [x] **F12 — Run `flutter analyze` + `flutter test`** — `flutter analyze`: 0 errors (only pre-existing info-level lints, none in edited files). `flutter test`: all 45 tests pass. (2 verify-email navigation tests flaked on the first run — off-screen tap warning — and passed on re-run.)

---
