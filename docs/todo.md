# CampusConnect v8.8 — Todo List

## Phase 0 — AI Architecture Audit (read-only)
- [x] Audit complete — `project_info__20.md`: primary Groq `llama-3.1-8b-instant`; no automatic fallback; active store `users/{uid}/ai_interactions` + legacy `ai_conversations`; no retention; no deletion

## Phase 1 — Primary AI Model / Provider Migration
- [x] Approved v8.8 config confirmed: **Groq `gpt-oss-20b`** primary
- [x] Verify endpoint, auth, request format, JSON mode, limits, timeout, rate-limit, error shape
- [x] Update model constant/env config; keep `callAIProvider` signatures unchanged

## Phase 2 — Hugging Face Fallback Migration
- [x] Approved v8.8 fallback confirmed: **Hugging Face Inference Providers `gpt-oss-20b`** (router.huggingface.co OpenAI-compatible)
- [x] Update `HF_MODEL`; preserve Bearer auth, timeouts, 429/503, response parsing
- [x] Add REAL fallback chain in `callAIProvider` (primary → HF) for chat + resume review + deep analysis

## Phase 3 — Environment & Secret Audit
- [x] `.env.example` created documenting `AI_PROVIDER`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, model env vars, retention config
- [x] Model identifiers env-configurable (`GROQ_MODEL` / `HF_MODEL`) with current values as defaults
- [x] No API keys in logs/source/docs; valid keys not rotated
- [x] AI/provider documentation updated

## Phase 4 — AI Response Formatting Cleanup
- [x] Server-side chat response normalization (`generateChatResponse`) — single layer; resume JSON unaffected
- [x] `CHAT_SYSTEM_PROMPT` formatting constraints updated
- [x] Client rendering decision: plain-sanitized-text (no new markdown dependency) — implemented
- [x] Legitimate `*` preserved; no raw JSON unless intended

## Phase 5 — AI Chat Deletion
- [x] `firestore.rules`: `users/{uid}/ai_interactions` add `allow delete: if isOwner(userId)`
- [x] `deleteAIHistory` callable (`request.auth.uid` only)
- [x] `AIChatProvider.deleteHistory()` — clear memory + reload
- [x] `AIChatView` delete action + confirmation dialog; immediate UI removal

## Phase 6 — Automatic AI Conversation Cleanup
- [x] New `onSchedule` cleanup function (daily), configurable retention (`AI_RETENTION_DAYS`, conservative default 90)
- [x] Batched/chunked deletes (≤490/batch), idempotent, only expired `ai_interactions` + `ai_conversations`
- [x] Aggregate logs only (no prompt/response content); handle partial failures

## Phase 7 — Firestore Security Audit
- [x] Owner-scoped reads/deletes; no cross-user access; unauthenticated denied; quota `write:false` intact

## Phase 8 — AI Quota Preservation
- [x] `consumeResumeQuota` / `rollbackResumeUsage` / `getResumeUsage` unchanged; tests pass
- [x] Fallback does not double-charge quota (consume once, application-level)

## Phase 9 — Provider Fallback Behavior
- [x] Fallback chain: primary → failure → HF → normalized response (no duplicate pipeline)
- [x] Friendly app-level errors; technical diagnostics server-side only
- [x] `askAI` error path returns friendly message (existing behavior preserved)

## Phase 10 — Tests
- [x] Provider: config, HF fallback, missing key, failure, timeout, rate limit, malformed/normalized response
- [x] Formatting: markdown cleanup, bullets, headings, raw JSON, legitimate `*` preserved
- [x] Deletion: own-only, cross-user denied, unauthenticated denied, provider state cleared
- [x] Retention: expired eligible, recent preserved, unrelated untouched, batching safe
- [x] Security: UID ownership, quota immutability, owner-scoped reads

## Phase 11 — Validation
- [x] `flutter analyze` → 0 errors / 0 warnings (68 pre-existing info lints, none in changed files)
- [x] `flutter test` → all 167 pass (124 existing + 43 new)
- [x] `node --check functions/index.js` (+ all AI modules → pass)
- [x] `dart format` → clean on all changed files
- [x] No API keys committed; no obsolete model references

## Phase 12 — Manual Testing
- [x] Deployment confirmed (2026-08-15: functions + firestore:rules, 17/17)
- [ ] Alumni: text resume review, ATS unchanged, no portfolio reintroduced
- [ ] Resume Reviewer: PDF + ATS + history + quota + structured output
- [ ] Security: cross-user isolation, no client quota manipulation, no keys in client/logs

## Phase 13 — Documentation & Version
- [x] `pubspec.yaml` → 8.8.0+91
- [x] `docs/todo.md`, `docs/issues.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md`, `.env.example`, provider docs
- [x] Record: models, providers, env vars, retention policy, deletion, formatting strategy, security, validation

## Post-Release Audit (user-requested, 2026-08-15)
- [x] Live provider check: both keys + `openai/gpt-oss-20b` verified against Groq + HF (HTTP 200, model echoed)
- [x] Key-leak audit: `functions/.env` untracked by git; `.env` gitignored; no key material in logs/scripts
- [x] Obsolete-model sweep: old names only in historical docs (changelogs/audits); zero in active code
- [x] Rules/quota/cleanup review: no weakening, no double-charge, no composite indexes needed
- [x] Audit findings recorded in `docs/issues.md` (incl. HIGH: Node 20 decommission 2026-10-30)

## v8.8.2 — Log Audit Fixes (project_info__22 / project_info__23 — pid 24538 session, 2026-08-15)

### A. HIGH — Quota-leak guard for `reviewResume` (crash-safe reservation)
- [x] `consumeResumeQuota` records a per-request reservation (`pendingRequestId` / `pendingSince`)
- [x] Success path clears the reservation; AI-failure rollback also clears it
- [x] Daily compensation sweep returns credits for stale (>24h) un-cleared reservations
- [x] Node syntax check + quota reservation contract tests

### B. MEDIUM — Gate Alumni Group Chat stream on the alumni role
- [x] `AlumniGroupChatProvider` no longer subscribes for students/teachers (role-gated init + `setRoleForStream`; `initWithUser` stores the user only)
- [x] `AuthGuard` activates the stream only once the role is known (`setRoleForStream(roleProvider.role)`)
- [x] Role-gate mirror tests (alumni subscribes; student/teacher/null do not)

### C. MEDIUM — Startup jank reduction
- [x] Remove blocking `LocalPreferencesService.init()` from `main()` pre-`runApp` (Theme/Layout providers resolve async, defaults render first)
- [x] `flutter analyze` clean on changed files (verified 2026-08-15: 0 errors / 0 warnings)
- [x] Note: full `flutter run --profile` profiling remains a documented follow-up

### D. LOW — Storage upload state warning (benign artifact)
- [x] Investigated: upload completed (`INTERNAL_STATE_SUCCESS`); the cancel is a post-success navigation/retry artifact — no data loss, no code change

### E. LOW/MEDIUM — Retry-storm throttling for quota-burning calls
- [x] Distinct typed exceptions for server-unavailable / network failures in `ResumeReviewService` (`ResumeReviewUnavailableException` / `ResumeReviewNetworkException`)
- [x] Consecutive-failure cooldown in `ResumeReviewProvider.submitReview` (blocks repeat calls, clears on success / connectivity restore, surfaces blocked reason via `isRetryBlocked` / `submitBlockedReason`)
- [x] Throttle logic mirrored in contract tests (`test/resume_retry_throttle_test.dart`)

### v8.8.2 Validation
- [x] `flutter analyze` → 0 errors / 0 warnings (68 pre-existing info lints, none in changed files)
- [x] `flutter test` → full suite green — 213 pass (verified 2026-08-15)
- [x] `node --check functions/index.js` → pass (all AI modules included)
- [x] `dart format` → clean on all changed files (resume_review_provider.dart formatted)
- [x] `docs/todo.md` updated after every sub-task (this run)

## v8.8.3 — project_info__23 Follow-up (audit addendum, 2026-08-15)

> `project_info__23.md` retracts HIGH-2 (`.env.example` is by design — a one-time setup
> template; the live `functions/.env` is the source of truth) and carries over the
> remaining HIGH + MED findings from `project_info__22.md`. This section tracks their
> resolution. The plan section is written FIRST; each sub-task is checked off as it is
> implemented, followed by the final validation block.

### Plan (updated as sub-tasks complete — 2026-08-15)
- [x] HIGH-1 — `askAI` callable: add `timeoutSeconds: 120` (Groq 30 s → HF 60 s fallback chain needs up to 90 s; default 60 s kills the chat fallback mid-flight)
- [x] HIGH-3 — `functions/package.json` `engines.node` → `"22"` (Node 20 decommissioned 2026-10-30; must redeploy before then)
- [x] HIGH-4 — VERIFIED (no code change): `deleteAIHistory` queries legacy `ai_conversations` by `userId` (owner-scoped); `cleanupExpiredAIConversations` by `timestamp` — both exactly match the fields `askAI` writes
- [x] HIGH-2 — RETRACTED (by design): `.env.example` intentionally not retained; optional note added to `docs/confirmation.md` Phase 3
- [x] MED-1 — `AIUsageProvider` connectivity subscription leak: retain subscription, cancel on `reset()`/`dispose()` (M5 pattern)
- [x] MED-2 — `AIUsageProvider.init()` hardcoded stub → read real trial/usage (Firestore `users/{uid}` + `ai_usage/{uid}`)
- [x] MED-3 — `AIChatProvider.sendMessage` surfaces the mapped friendly error text (bubble + `_error`) instead of the canned message
- [x] MED-4 — Firestore `chats` rule: participants may read/create; update limited to last-message/unread metadata; delete/rewrite denied (admin-only)
- [x] MED-5 — Firestore `users/{uid}/activities` create restricted to the sole legit client write (resumeReviewed / 5 pts / own UID); arbitrary points/events denied
- [x] MED-8 — `AIChatProvider.deleteHistory()` callable call gains `.timeout(...)`; `deleteAIHistory` server gains `timeoutSeconds: 120`
- [x] MED-6 — Duplicate profile routes: deprecate `/profile-view`; point `/profile/` at the extracted `ProfileView`; update dashboard navigators; remove legacy shim
- [x] Security mirror tests for MED-4/MED-5 (rules contract, `AlumniGroupChat`-style — `test/security_rules_mirror_test.dart`)

### v8.8.3 Validation
- [x] `flutter analyze` → 0 errors / 0 warnings (68 pre-existing info lints, none in changed files)
- [x] `flutter test` → full suite green — 213 pass (verified 2026-08-15; exceeds the 191 expected by MED-7)
- [x] `node --check functions/index.js` → pass (all AI modules included)
- [x] `dart format` → clean on all changed files (verified 2026-08-15)
- [x] `docs/todo.md` updated after every sub-task (this run)

### v8.8.3 Deployment (manual — requires Firebase credentials)
- [ ] `firebase deploy --only "functions,firestore:rules" --non-interactive` (HIGH-1 + HIGH-3 + rules fixes; MUST complete before 2026-10-30)

## Final Deliverable

- [x] Report: files changed, providers/models, env changes, deletion impl, retention, formatting, security, tests, analyze/test/check results, manual tests (pending device), deployment (confirmed 2026-08-15), limitations

**v8.8.0+91 status: IMPLEMENTED + VALIDATED + DEPLOYED**
**v8.8.2 status: IMPLEMENTED + VALIDATED (2026-08-15 — 213 tests, analyze clean, format clean)**
**v8.8.3 status: IMPLEMENTED + VALIDATED (2026-08-15) — deployment pending (MUST complete before 2026-10-30)**
