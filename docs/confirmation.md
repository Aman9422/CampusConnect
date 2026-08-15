# CampusConnect — Version Confirmation

## ✅ v8.8.0+91 — AI Provider Migration, Response Quality & Chat Lifecycle Hardening (2026-08-15)

Status: **IMPLEMENTATION COMPLETE + AUTOMATED VALIDATION PASSED + ✅ DEPLOYED (2026-08-15)**

### What shipped

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Full AI architecture audit (`project_info__20.md`) | ✅ |
| 1 | Primary provider migration: **Groq `openai/gpt-oss-20b`** (env-configurable `GROQ_MODEL`) | ✅ |
| 2 | Fallback migration: **HuggingFace Inference Providers `openai/gpt-oss-20b`** (env-configurable `HF_MODEL`) | ✅ |
| 3 | Environment/secret audit; `functions/.env.example`; no keys committed/rotated | ✅ |
| 4 | Chat response normalization (`normalizeChatText`) + `CHAT_SYSTEM_PROMPT` constraints; resume JSON untouched; legitimate `*` preserved | ✅ |
| 5 | AI chat deletion: `deleteAIHistory` callable (auth-uid owner-scoped), `AIChatProvider.deleteHistory()`, `AIChatView` delete + confirmation; rules `allow delete: if isOwner(userId)` | ✅ |
| 6 | Retention: `cleanupExpiredAIConversations` daily schedule, `AI_RETENTION_DAYS` (default 90), batched/idempotent, only expired AI docs, aggregate-only logs | ✅ |
| 7 | Security audit: owner-scoped reads/deletes; unauth denied; quota write:false intact; Admin SDK cleanup | ✅ |
| 8 | Quota architecture preserved (`consumeResumeQuota`/`rollbackResumeUsage`/`getResumeUsage`); no double-charge on fallback | ✅ |
| 9 | Fallback chain primary → HF → normalized response; no second pipeline; friendly client errors | ✅ |
| 10 | 43 new tests (provider/fallback, formatting, deletion, retention, security) | ✅ |
| 11 | `flutter analyze` 0 errors/0 warnings · `flutter test` 167/167 · `node --check` pass · `dart format` clean | ✅ |
| 12 | Manual on-device matrix | ⏳ pending (Phase 12 in `docs/todo.md`) |
| 13 | Docs + version `8.8.0+91` | ✅ |

### Primary AI provider/model

**Groq — `openai/gpt-oss-20b`** (was `llama-3.1-8b-instant`)

### Fallback provider/model

**HuggingFace Inference Providers — `openai/gpt-oss-20b`** via `https://router.huggingface.co/v1/chat/completions` (was `meta-llama/Llama-3.1-8B-Instruct`)

### Environment variables

| Variable | Role |
|----------|------|
| `AI_PROVIDER` | `groq` (default, dual-provider with fallback) or `huggingface` (single-provider) |
| `GROQ_API_KEY` | Primary provider key (server-side only) |
| `HUGGINGFACE_API_KEY` | Fallback provider key (server-side only) |
| `GROQ_MODEL` | Default `openai/gpt-oss-20b` |
| `HF_MODEL` | Default `openai/gpt-oss-20b` |
| `AI_RETENTION_DAYS` | Default `90` — retention window for automatic cleanup |

### Validation results

- `flutter analyze` → **0 errors / 0 warnings** (68 pre-existing info lints, none in v8.8 files)
- `flutter test` → **167/167 passed** (124 existing + 43 new v8.8)
- `node --check functions/index.js` (+ `functions/ai/*.js`) → **pass**
- `dart format` → clean on all changed files
- No API keys committed; no obsolete model references (`llama-3.1-8b-instant`, `meta-llama/Llama-3.1-8B-Instruct`) remain

### Deployment status

✅ **DEPLOYED 2026-08-15** — `firebase deploy --only "functions,firestore:rules" --non-interactive` **SUCCESS**. All 17 functions updated (incl. **created**: `deleteAIHistory`, `cleanupExpiredAIConversations`); `firestore.rules` compiled + released (owner delete on `users/{uid}/ai_interactions`). `functions/.env` keys verified present before deploy; env vars loaded into deployed functions. Remaining: on-device manual matrix (Phase 12, `docs/todo.md`).

---
