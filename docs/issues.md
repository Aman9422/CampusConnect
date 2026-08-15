# CampusConnect — Issues Log

## v8.8.1 — AI Chat Callable Cast Regression Fix (2026-08-15)

### Resolved in this version

- **BUG: every AI chat message failed with "I could not process that right now."** Root cause (`docs/logs.md`):
  `AIChatProvider.sendMessage error: Exception: Failed to connect to AI service: type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>' in type cast`.
  The `cloud_functions` callable SDK decodes nested JSON objects as `Map<Object?, Object?>`; `AIService.sendMessage` called `.call<Map<String, dynamic>>(...)` and `AIResponse.fromJson(result.data)` cast the nested `trial`/`usage` maps directly, which threw — so the provider always fell back to the friendly error. `askAI` returns nested `trial`/`usage`; `reviewResume` returns a nested `review`; both hit the same cast hazard.
  Fix: `AIService.sendMessage` now calls the callable WITHOUT the generic type parameter and deep-converts the whole payload with `jsonDecode(jsonEncode(result.data))` before handing it to `AIResponse.fromJson` — the exact pattern `ResumeReviewService` already used (which is why resume review worked while chat was broken). After the deep-convert, the `trial`/`usage` sub-maps are genuine `Map<String, dynamic>` so `fromJson`'s existing casts succeed; no model changes were needed.
- **BUG: `AIChatProvider.deleteHistory()` threw the same cast on success.** The v8.8 `deleteAIHistory` callable returns `{deleted: n}`; `.call<Map<String, dynamic>>({})` applies the same unsafe downcast. Fixed by calling without the generic (the body is intentionally ignored).
- **Regression test added:** `test/ai_callable_response_cast_test.dart` reproduces the `Map<Object?, Object?>` SDK shape, proves the deep-convert succeeds on the full `askAI`/`deleteAIHistory` shapes, and documents that the old direct cast throws the exact TypeError from the log.

### Verification

- `flutter analyze`: 0 errors / 0 warnings (only pre-existing info-level lints, none in the touched files).
- `flutter test`: 172/172 pass, including the 5 new cast-regression tests.
- No server changes required — the `askAI`/`deleteAIHistory` callables already return correct JSON; this is purely a client-side decode fix. No Cloud Function redeploy needed.

---

## v8.8 — AI Provider Migration, Response Quality & Chat Lifecycle Hardening (2026-08-15)

### Resolved in this version

- **BUG: `*`, `**`, `###`, raw Markdown artifacts in AI chat responses.** Root cause: the chat system prompt allowed Markdown and the chat bubble rendered raw text. Fixed server-side at the single normalization layer (`normalizeChatText` in `functions/ai/aiProvider.js`, applied in `generateChatResponse`) + tightened `CHAT_SYSTEM_PROMPT` formatting constraints. Resume-review/deep-analysis JSON parsing untouched. Legitimate `*` (e.g. `C++`, `a*b`, `5 * 4`) preserved by conservative emphasis stripping.
- **BUG: AI conversations accumulated indefinitely; no user deletion.** Added `deleteAIHistory` callable (owner-scoped via `request.auth.uid`; deletes both `users/{uid}/ai_interactions` and legacy `ai_conversations`), `AIChatProvider.deleteHistory()`, `AIChatView` AppBar delete action + confirmation dialog. `firestore.rules` now allows owner deletes on `users/{uid}/ai_interactions` (`update` stays false).
- **BUG: no automatic cleanup of old AI conversations → unbounded Firestore growth.** Added `cleanupExpiredAIConversations` daily scheduled function honoring `AI_RETENTION_DAYS` (env-configurable, conservative default 90; validated positive integer). Batched deletes (≤400/batch), idempotent, only expired `ai_interactions`/`ai_conversations`; aggregate-only logs (no prompts/responses).
- **Migration: primary model `llama-3.1-8b-instant` → `openai/gpt-oss-20b` (Groq).** Model is env-configurable via `GROQ_MODEL`. JSON mode (`response_format`) preserved. 30 s timeout, 429/5xx/malformed-response handling preserved, error surface is a deployment error (never a key leak).
- **Migration: HF fallback `meta-llama/Llama-3.1-8B-Instruct` → `openai/gpt-oss-20b` via Inference Providers (`router.huggingface.co`).** Env-configurable via `HF_MODEL`. Bearer auth, 60 s timeout, 429/503 handling, response parsing preserved. JSON mode added for resume-review/analysis parity.
- **Failure: no AUTOMATIC provider fallback existed.** Added the primary → HuggingFace fallback chain in `callAIProvider` (chat + resume review + deep analysis). Single-provider `AI_PROVIDER=huggingface` mode preserved. No second pipeline.
- **Compile blocker fixed:** `AIChatProvider` used `FirebaseFunctions` without importing `cloud_functions` — added the import.

### Known limitations (tracked from prior versions, unchanged)

1. No OCR — scanned/image-only PDFs return the friendly "image-based" error.
2. `pdf-parse` xref parser may reject synthetic minimal PDFs (real Chromium/Word PDFs parse).
3. Per-student placement outcome stages remain "N/A" (schema does not track outcomes).
4. Engagement aggregates iterate per-student docs — slow at 500+ students.
5. **App Check not installed** — `No AppCheckProvider installed` WARNING on login (non-blocking; rules authenticate via `request.auth`).
6. Flattened-vs-nested portfolio shape — both read shapes tolerated since v8.4.9; app writes produce the canonical nested shape.
7. Manual on-device matrix for v8.8 pending (Phase 12, `docs/todo.md`).
8. **v8.8 deployed 2026-08-15** (`functions` + `firestore:rules`, 17/17 functions) — resolved.

## Final Audit — v8.8 (2026-08-15, post-deploy)

### Verified OK

- **Provider/model live check**: real keys from `functions/.env` exercised against BOTH endpoints — Groq and HuggingFace Inference Providers both returned HTTP 200 with `openai/gpt-oss-20b` echoed as the serving model. Phases 1/2 config is production-verified.
- **No key leak**: `functions/.env` is untracked by git (`git ls-files --error-unmatch` → not tracked; `functions/.gitignore` covers `.env`), and the live-check printed no key material.
- **No obsolete model references in active code**: full repo sweep found old model names only in historical changelogs/audit reports (`V6.95_AI_DEEP_ANALYSIS.md`, `project_info__20/21.md`, v8.8 migration notes) — all describe the pre-migration state and are preserved as version history.
- **Rules semantics**: the `ai_interactions` delete rule corrects a real gap — the old specific rule `delete: if false` would have overridden the `users/{uid}` catch-all write for owner deletes; owner deletes are now properly allowed while `update` stays denied. No weakening.
- **Quota**: consumption happens once per logical request in `askAI`/`reviewResume`; the fallback chain is internal to `generateChatResponse`/`generateResumeReviewAI`/`generateAIResponse`, so an HF failover cannot double-charge. Verified by tests.
- **Cleanup scheduler**: `collectionGroup("ai_interactions")` + `ai_conversations` single-field queries only — no composite index required; batching ≤400 is safe.

### Action items discovered

1. **[HIGH — upcoming] Node 20 runtime deprecation**: the deploy banner warns Node.js 20 is deprecated (2026-04-30) and will be decommissioned **2026-10-30**, after which functions cannot be redeployed without upgrading. Recommendation: bump `functions/package.json` `engines.node` to `22`, run syntax checks/tests, then `firebase deploy --only functions` — before October 2026.
2. **[LOW] `askAI` logs the first 50 chars of each user message** (`console.log("Message: …")`) — pre-existing truncated soft-abuse log, predates v8.8. Left unchanged to honor the preserve-existing-architecture constraint; a future pass could remove it.
3. **[LOW] `firebase-functions` outdated**: deploy warns `^5.0.0` is outdated with breaking changes in newer majors. Not blocking; schedule an upgrade in a dedicated pass.
4. **[INFO] `.env` values are readable in the Firebase console** (non-secret env vars). Matches the existing project pattern; keys can be moved to `firebase functions:secrets` later if desired.

---
