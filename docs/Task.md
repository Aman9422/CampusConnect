# CampusConnect v8.8 — AI Provider Migration, Response Quality & Chat Lifecycle Hardening

## Objective

Continue from the completed **v8.7 — Alumni Experience Simplification & Alumni Group Chat** release.

v8.8 focuses on hardening the AI layer and improving the user experience around AI conversations.

The goal is to:

1. Migrate the primary AI model/provider to the new approved model configuration.
2. Update Hugging Face as the fallback provider/model.
3. Audit and update all AI-related environment variables and API keys.
4. Fix AI responses containing unwanted Markdown artifacts such as `*`, `**`, excessive headings, raw JSON, or formatting that looks unnatural inside the Flutter chat UI.
5. Add user-controlled AI chat deletion.
6. Add an appropriate automatic cleanup/retention mechanism so old conversations do not grow the Firestore database indefinitely.
7. Preserve the existing AI architecture, quota system, security model, and existing student/alumni functionality.
8. Do not introduce a second AI pipeline.

---

# Phase 0 — Full AI Architecture Audit

Before modifying code, inspect the complete AI flow.

Audit:

* `functions/index.js`
* AI provider modules
* Groq integration
* Hugging Face integration
* `AIService`
* `ResumeReviewService`
* `ResumeReviewProvider`
* AI usage/quota provider
* AI chat views
* Firestore conversation schema
* Firestore rules
* Cloud Functions
* `functions/.env`
* Firebase configuration
* `functions/package.json`
* any AI-related environment variable references
* any hardcoded model names
* any provider fallback logic

Search the entire repository for:

* `GROQ_API_KEY`
* `HUGGINGFACE_API_KEY`
* `GROQ_MODEL`
* `HF_MODEL`
* `router.huggingface.co`
* `api.groq.com`
* `askAI`
* `reviewResume`
* `AIService`
* `ai`
* `conversation`
* `chat`
* `messages`

Do not assume an environment variable is unused simply because it is not present in one file.

Produce a short audit of:

* primary provider
* fallback provider
* models
* environment variables
* secrets
* AI callable functions
* chat storage structure
* quota handling
* current retention behavior

---

# Phase 1 — AI Model / Provider Migration

## Primary provider

Update the primary provider to the new model/provider selected for v8.8.

Do NOT blindly replace model names.

Verify:

* model identifier
* API endpoint
* authentication method
* supported request format
* JSON response support
* maximum context/output limits
* timeout requirements
* rate-limit behavior
* error response format

Preserve the existing application-level AI interface so callers do not need unnecessary changes.

The provider should continue accepting:

* `systemPrompt`
* `userPrompt`
* optional JSON mode/options

and return the same normalized response expected by the existing AI pipeline.

---

# Phase 2 — Hugging Face Fallback Migration

The current Hugging Face implementation uses:

`https://router.huggingface.co/v1/chat/completions`

Current model:

`meta-llama/Llama-3.1-8B-Instruct`

Update this fallback to the approved v8.8 Hugging Face model.

Before changing it, verify that the selected model is actually available through Hugging Face Inference Providers and supports the OpenAI-compatible chat completion interface.

Preserve:

* `HUGGINGFACE_API_KEY`
* Bearer authentication
* timeout handling
* 429 handling
* 503/provider-unavailable handling
* response parsing
* existing provider abstraction

Do not expose API keys to Flutter/client code.

---

# Phase 3 — Environment & Secret Audit

Audit every AI environment variable.

Expected categories include:

* primary provider API key
* Hugging Face API key
* model identifiers
* optional provider configuration
* AI timeout/token configuration

Check:

* `functions/.env`
* `.env.example` if present
* Firebase Functions configuration
* deployment configuration
* GitHub/Git configuration if applicable
* any hardcoded secrets
* documentation mentioning obsolete keys/models

IMPORTANT:

Do NOT print actual API keys into logs, documentation, test output, or source code.

If the API key itself is still valid, do not unnecessarily rotate it.

Only request a new key if:

* the provider requires it,
* the current key is invalid/expired,
* permissions changed,
* or the migration requires a different credential.

Update documentation so future model migrations are clear.

---

# Phase 4 — AI Response Formatting Cleanup

There is an existing UX issue where AI responses sometimes contain formatting such as:

`* text`

`**text**`

`### Heading`

raw JSON blocks

escaped characters

or other Markdown artifacts that look ugly in the application's chat UI.

Audit how AI responses are currently rendered.

Determine whether the correct solution is:

1. proper Markdown rendering in Flutter,
2. controlled Markdown sanitization,
3. prompt-level formatting constraints,
4. or a combination.

Do NOT blindly remove all `*` characters because legitimate content may contain them.

The final chat UI should display:

* readable paragraphs
* clean bullet points
* readable headings
* code when appropriate
* no accidental Markdown artifacts
* no raw JSON unless JSON is intentionally requested/displayed
* no escaped formatting such as unnecessary `\n`

Resume-review JSON parsing must remain unaffected.

AI responses should be normalized at the appropriate layer rather than duplicating formatting logic across multiple UI widgets.

---

# Phase 5 — AI Chat Deletion

Currently AI conversations can accumulate indefinitely.

Implement user-controlled deletion.

The user should be able to:

* delete an individual AI conversation, OR
* delete their AI chat history

depending on the existing conversation model.

Requirements:

* user can only delete their own conversations
* deletion must be enforced server-side/rules-side
* UI must include confirmation before destructive deletion
* deleted conversation should disappear immediately from the UI
* provider state/cache must be updated correctly
* no other user's conversation can be deleted

Do not allow arbitrary client-supplied user IDs to determine ownership.

Use:

`request.auth.uid`

as the authoritative identity wherever applicable.

---

# Phase 6 — Automatic AI Conversation Cleanup

Design a retention policy to prevent unlimited Firestore growth.

Do NOT automatically delete recent conversations.

Implement a conservative retention mechanism, for example:

* retain recent conversations
* automatically remove conversations older than the configured retention period

The retention period must be configurable rather than hardcoded throughout the codebase.

Prefer a scheduled Cloud Function for cleanup.

Requirements:

* delete only expired AI conversation data
* never delete unrelated Firestore documents
* use batched/chunked deletes
* avoid exceeding Firestore batch limits
* handle large datasets safely
* log only aggregate cleanup information
* do not log conversation contents
* do not log personal AI prompts/responses
* make cleanup idempotent
* handle partial failures safely

If the existing conversation schema uses parent documents/subcollections, respect that schema rather than creating a new storage system.

---

# Phase 7 — Firestore Security Audit

Review the AI conversation Firestore rules.

Confirm:

* authenticated users can access only their own conversations
* unauthenticated users cannot access conversations
* users cannot read another user's AI history
* users cannot delete another user's conversations
* users cannot manipulate another user's quota
* server-side cleanup can operate securely through Admin SDK

Do not weaken existing security rules merely to make deletion work.

---

# Phase 8 — AI Quota Preservation

The v8.6 quota architecture must remain intact.

Do NOT break:

* `consumeResumeQuota`
* `rollbackResumeUsage`
* `getResumeUsage`
* existing quota limits
* AI failure rollback behavior

Verify that:

* successful AI calls consume usage correctly
* failed AI calls do not permanently consume quota where rollback is expected
* provider fallback does not double-charge usage
* provider failure does not create duplicate usage records

If the provider changes, the quota should remain application-level rather than provider-specific.

---

# Phase 9 — Provider Fallback Behavior

Review the provider fallback architecture.

Expected behavior:

Primary provider
→ failure / temporary unavailability
→ Hugging Face fallback
→ normalized response
→ existing application pipeline

Do not create duplicate AI pipelines.

Provider-specific errors should not leak raw API responses to the user.

Return friendly application-level errors such as:

* AI temporarily unavailable
* Please try again
* AI service is busy

Log technical diagnostics server-side without exposing API keys or sensitive prompt content.

---

# Phase 10 — Tests

Add/update automated tests for:

### Provider

* primary provider configuration
* Hugging Face fallback
* missing API key
* provider failure
* timeout
* rate limit
* malformed response
* normalized response

### Formatting

* Markdown cleanup
* bullets
* headings
* accidental formatting
* raw JSON handling
* legitimate `*` characters are not incorrectly destroyed

### Chat deletion

* user can delete own conversation
* user cannot delete another user's conversation
* unauthenticated deletion rejected
* deleted conversation disappears from provider state

### Retention

* expired conversations are eligible for deletion
* recent conversations are preserved
* unrelated documents are untouched
* cleanup handles batches safely

### Security

* UID ownership enforced
* quota cannot be modified by another user
* conversation reads remain owner-scoped

---

# Phase 11 — Validation

Run:

```text
flutter analyze
flutter test
node --check functions/index.js
dart format
```

Also run any provider-specific/unit tests.

Verify:

* 0 analyzer errors
* 0 analyzer warnings
* all existing tests pass
* all new tests pass
* Cloud Functions syntax passes
* no API keys are committed
* no obsolete model references remain

Search again for old model names and deprecated environment variables after implementation.

---

# Phase 12 — Manual Testing

Test at minimum:

### Student

* AI chat opens
* normal question works
* formatted response displays cleanly
* long response works
* AI failure shows friendly error
* quota still works
* conversation is saved
* conversation can be deleted
* deleted conversation disappears
* old conversation cleanup does not affect recent chats

### Alumni

* AI functionality that remains available works
* text-based Resume Reviewer remains functional
* ATS pipeline remains unchanged
* no Alumni Portfolio functionality is accidentally reintroduced

### Resume Reviewer

* Student uploaded PDF review still works
* ATS parsing still works
* review history still works
* quota still works
* provider migration does not break structured output

### Security

* Student A cannot read Student B's AI history
* Student A cannot delete Student B's history
* Alumni cannot access another user's AI history
* client cannot manipulate quota
* API keys never appear in client code/logs

---

# Phase 13 — Documentation & Version

Update:

* `pubspec.yaml`
* `docs/todo.md`
* `docs/issues.md`
* `docs/v8_workspace_tracker.md`
* `docs/confirmation.md`
* AI/provider documentation
* `.env.example` if present

Record:

* new primary model
* new Hugging Face fallback model
* provider architecture
* environment variables
* chat retention policy
* deletion behavior
* formatting strategy
* security decisions
* validation results

Version:

**v8.8.0**

Do not modify unrelated version history.

---

# Important Constraints

1. Do NOT redesign the entire AI architecture.
2. Do NOT create a second AI/ATS pipeline.
3. Do NOT expose API keys to Flutter.
4. Do NOT log API keys.
5. Do NOT log user prompts/responses unnecessarily.
6. Do NOT weaken Firestore security rules.
7. Do NOT break the existing v8.6 quota/rollback architecture.
8. Do NOT break Student uploaded-PDF Resume Reviewer.
9. Do NOT reintroduce the removed Alumni Portfolio workflow from v8.7.
10. Do NOT delete recent AI conversations automatically.
11. Do NOT delete unrelated Firestore data.
12. Do NOT blindly strip `*` from AI responses; fix Markdown rendering/normalization correctly.
13. Preserve backward compatibility with the existing Firestore conversation structure wherever practical.
14. Avoid unnecessary UI redesign.

---

# Final Deliverable

At completion provide:

1. Exact files changed
2. Primary AI provider/model
3. Hugging Face fallback provider/model
4. Environment variables added/removed/renamed
5. Chat deletion implementation
6. Automatic retention policy
7. AI formatting solution
8. Security changes
9. Tests added/updated
10. `flutter analyze` result
11. `flutter test` result
12. `node --check` result
13. Manual test results
14. Deployment status
15. Any remaining limitations

Mark the version complete only after implementation, automated validation, and deployment are confirmed.
