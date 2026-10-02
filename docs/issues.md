# CampusConnect — Issue Log

---

## ISSUE-2026-1002-02 — The AI resume reviewer fails with an opaque "Server error", and the real cause was invisible in production

**Reported (student → AI Resume Review):**

> "the resume reviewer is not working" — and, separately, "it was working like
> 2 or 3 days ago".

The Flutter log showed only:

```
I/flutter: ResumeReviewProvider: Submitting review...
I/flutter: ResumeReviewService: Sending review request...
I/flutter: ResumeReviewService: function error internal - INTERNAL
```

The user also asked whether the in-app banner **"⚠ AI trial expires tomorrow!"**
was the cause. It is not — see *Ruled out* below.

---

### Symptom summary

| Layer | What was observed |
| --- | --- |
| Client | `function error internal - INTERNAL` — the callable rejected with no message |
| Function log | `Unhandled error TypeError: Cannot read properties of undefined (reading 'https')` at `/workspace/ai/resumeReview.js:216:46` |
| Function log | **No handler output at all** for the failing request — not even the entry log line |
| Last success | 2026-09-29, `Resume review from provider: huggingface` |
| Deployed revision | `reviewresume-00026-lez` (stamped at the deploy of 2026-10-02 13:33 UTC) |

---

### Root cause — three independent defects

#### Defect 1 — `admin.functions.https.HttpsError` does not exist, so every error was destroyed on the way out

**Proven by the deployed log**, not inferred:

```
E reviewresume: Unhandled error TypeError: Cannot read properties of undefined (reading 'https')
    at /workspace/ai/resumeReview.js:216:46
    at async /workspace/node_modules/firebase-functions/lib/common/providers/https.js:467:26
```

`firebase-admin` 12.7.0 (the version in `functions/node_modules`) exposes
`auth`, `firestore`, `storage`, `messaging`, … but **no `functions` provider**,
and requiring `firebase-functions` does not add one. Every module in this tree
signals a failure with:

```js
throw new admin.functions.https.HttpsError("invalid-argument", "...");
// and, in every catch block:
if (error instanceof admin.functions.https.HttpsError) throw error;
```

Both forms were therefore `undefined.https` → **TypeError, thrown at the exact
moment the code tried to report a failure**. `firebase-functions`' `onCall`
wrapper turns any non-`HttpsError` into `HttpsError("internal", "INTERNAL")`.

The observable consequences were:

* a quota rejection (`resource-exhausted` plus its `usage` details), a missing
  resume PDF (`not-found`), a malformed argument (`invalid-argument`) and a dead
  AI provider all arrived at the client as the same bare `internal` / `INTERNAL`
  — which is why the app could only say "Server error";
* the *original* error was never logged: `console.error("Error in reviewResume
  function:", error)` sits **after** the crashing `instanceof` line, so the
  function log for a failing request contains no cause and no handler output;
* because the classification of an error could itself throw, a mislabelled
  failure could be re-wrapped on the way out.

This defect alone makes **every** specific failure in `askAI`,
`reviewResume`, `generateResumeAnalysis`, `generateCareerCoachAnalysis` and
every other callable undiagnosable. It is the reason the reported symptom was
"it doesn't work" rather than any actionable message.

**Fix.** `functions/helpers/https_error.js` attaches the real `HttpsError`
class (the same one `firebase-functions/v2/https` exports, so the codebase's
`instanceof` checks keep working) to `admin.functions.https`.
`functions/index.js` calls it **before requiring any feature module**:

```js
require("./helpers/https_error").installHttpsError();
```

It is idempotent and never clobbers an existing value, so the deployed runtime
gets the real class once and the unit-test shim keeps its own stand-in.

#### Defect 2 — the 2048-token completion budget truncates the review JSON (the failure the user hit)

Proven by the last **successful** review, 2026-09-29 — the day the user
remembers it working:

```
resumeTextFromStorage: extracted 1785 characters from resumes/ynleASY3m0dJ0dVkQ6D9K1xMVKv2/latest.pdf
Resume review request from user: ynleASY3m0dJ0dVkQ6D9K1xMVKv2 (uploaded)
AI Provider: Using "groq" (jsonMode: true)
Groq: Calling openai/gpt-oss-20b (max_tokens: 2048)
Groq API error (400): {"error":{"message":"Failed to generate JSON. Please adjust your prompt. See 'failed_generation' for more details.","type":"invalid_request_error","code":"json_validate_failed","failed_generation":"max completion tokens reached before generating a valid document"}}
AI Provider: Groq failed — falling back to HuggingFace. Reason: ... status 400 ...
HuggingFace: Calling openai/gpt-oss-20b via Inference Providers (max_tokens: 2048)
HuggingFace: Response received (2555 chars)
Resume review from provider: huggingface
```

`openai/gpt-oss-20b` is a **reasoning model**: `max_tokens` bounds the reasoning
trace **and** the answer together. At 2048 the trace consumed the whole budget
and the JSON document was never closed. Groq validates
`response_format: {type: "json_object"}` server-side and rejects the incomplete
document with `400 json_validate_failed`; its own `failed_generation` field says
exactly what happened — *"max completion tokens reached before generating a
valid document"*.

**Why it "worked 2 or 3 days ago".** The primary provider was **already
failing**; the feature was being *rescued* by the fallback. On 2026-09-29
HuggingFace happened to fit the same request into the same 2048 tokens (2555
chars back), so the review completed. The HF router selects a partner provider
per request and reasoning length varies, so the same code succeeded or failed
depending on routing. A flaky dependency silently carrying a feature is exactly
what "it worked a few days ago" looks like.

A latent crash sat in the same path: for a reasoning model that spends its whole
budget on the trace, `choices[0].message.content` is `null`, and the provider
read `content.length` — a TypeError reported as "Failed to parse Groq response",
which hid the truncation.

**Fix.** `functions/ai/tokenBudget.js`:

* JSON calls (resume review, deep analysis, recommendation explanations) now
  request **4096** tokens instead of 2048. Plain-text chat keeps its original
  2048, so no existing caller silently changes behaviour;
* `escalateMaxTokens` supplies a doubled budget for one retry.

Both providers now retry **once** with the escalated budget when a completion was
genuinely cut off — Groq on the `json_validate_failed` 400, HuggingFace on an
empty or `finish_reason: "length"` answer (the router does not validate JSON, so
a truncation arrives there as an incomplete document) — and both read the answer
defensively. If the retry is *still* cut off, the rejection names the budget
instead of surfacing as a TypeError. A non-budget failure is never retried.

#### Defect 3 — the resume object was read from an implicitly resolved bucket (hardening, **not** the reported cause)

`reviewResume` read the PDF with `admin.storage().bucket().file(storagePath)` —
no bucket name — so Firebase Admin resolves `app.options.storageBucket`, and the
deployed `functions/.env` sets **no** `STORAGE_BUCKET`. Measured locally:

* `storageBucket` set to the project's current default
  (`…firebasestorage.app`) → the read works;
* `storageBucket` **absent** → `admin.storage().bucket()` does **not** fall
  back, it throws `Bucket name not specified or invalid`;
* `storageBucket` set to the **legacy** `…appspot.com` while the client uploaded
  to `…firebasestorage.app` → the read 404s.

The 2026-09-29 log shows the read **succeeding** ("extracted 1785 characters"),
so this is **not** what broke the reviewer. It is a latent fragility: whichever
`storageBucket` a deploy happens to carry silently decides which bucket is read,
and a misread lands in the same catch block that Defect 1 had already broken.

**Fix.** `functions/ai/resumeStorage.js` probes every plausible bucket name
(env override → the admin-configured name → `<project>.firebasestorage.app` →
`<project>.appspot.com`, deduped) and returns a **typed** outcome —
`not-found`, `unreadable` or `too-large` — logging the names it tried. A 404
moves to the next candidate; a non-404 failure stops and reports, so a genuine
permission problem is never masked as "file missing".

### Also fixed — failures that could not be named in the log

`resumeTextFromStorage` threw in two places **without logging anything**: the
resume-path check and the "extracted text is too short / image-based" branch.
Because the first log line sat *after* the Storage read, either throw produced a
request with **no handler output at all** — precisely the log signature of the
failing requests on 2026-10-02 (a ~700 ms gap between "verification passed" and
the crash, with nothing in between). Both branches, and the missing-input
branch, now log before throwing, so the next failure names its stage
(`resumeTextFromStorage: extracted only N characters … — the PDF is image-based
or unscannable`).

### Ruled out — the "⚠ AI trial expires tomorrow!" banner

`manageUserTrial` (`functions/ai/chat.js`) is **soft enforcement only**, as its
own documentation states:

> "Creates trial on first AI usage and tracks expiration. Returns trial status
> but does NOT block access."

It is called **only** by `askAI`; `reviewResume` never reads trial state. The
banner is informational metadata returned by `askAI` and rendered by the chat
UI — it could not cause the reviewer to fail, and the trial had not even expired.

### Separately observed (not part of this fix)

Every callable request logs:

```
Failed to validate AppCheck token. FirebaseAppCheckError: Decoding App Check token failed.
{"verifications":{"app":"INVALID","auth":"VALID"},"message":"Callable request verification failed: AppCheck token was rejected."}
Allowing request with invalid AppCheck token because enforcement is disabled
```

Enforcement is disabled, so this is **not** blocking — but the device's debug
App Check token is not registered, and every request pays for a failed
verification. Worth fixing separately; see `docs/app_check_status.md`.

---

### Files changed

| File | Change |
| --- | --- |
| `functions/helpers/https_error.js` | **new** — attaches the real `HttpsError` to `admin.functions.https`; idempotent, never clobbers |
| `functions/index.js` | calls `installHttpsError()` before requiring any feature module |
| `functions/ai/tokenBudget.js` | **new** — JSON calls get 4096 tokens (chat keeps 2048); `escalateMaxTokens` for the single retry |
| `functions/ai/groqProvider.js` | sends the resolved budget; reads `message.content` defensively; logs `finish_reason`; one retry on `json_validate_failed` / empty completion |
| `functions/ai/huggingfaceProvider.js` | sends the resolved budget; reads `message.content` defensively; one retry on an empty or truncated JSON answer |
| `functions/ai/resumeStorage.js` | **new** — bucket-probing reader with a typed outcome and the buckets tried |
| `functions/ai/resumeReview.js` | reads through the reader and maps `not-found` / `too-large` / `unreadable` to distinct `HttpsError`s; logs at every previously-silent throw site |
| `functions/test/ai_error_reporting.test.js` | **new** — 21 tests |
| `functions/test/ai_provider_budget_retry.test.js` | **new** — 10 tests |
| `functions/test/setup.js` | corrected a comment that claimed the deployed runtime provides `admin.functions` (it does not) |
| `functions/test/hardening_source_contracts.test.js` | the C-1 signing-secret guard now asserts "not **tracked by Git**" instead of "not present on disk" — see *Unrelated test defect found and fixed* below |

### Tests

| Test | What it pins |
| --- | --- |
| `functions/test/ai_provider_budget_retry.test.js` (10) | a `json_validate_failed` 400 ⇒ exactly **one** retry at the doubled budget, then success; an empty completion retries the same way; a 401 is **not** retried; still-truncated ⇒ a rejection that names the budget and is not a `TypeError`; a truncated **JSON** document is retried while truncated **plain text** is returned as-is; an explicit `maxTokens` is doubled, not replaced. `node:https` is stubbed, so the exact production 400 is replayed offline. |
| `functions/test/ai_error_reporting.test.js` (21) | the shim installs a working `HttpsError` when the runtime has none, is idempotent, and never clobbers it; `index.js` installs it before **every** feature module; the reader finds a file in the **current** default bucket while configured for the legacy one; absent everywhere ⇒ `not-found` **with the buckets tried**; no resolvable bucket ⇒ `not-found` and no bucket contacted; oversized ⇒ `too-large`; empty ⇒ `unreadable`; a non-404 failure ⇒ `unreadable` and probing stops; a missing `size` is not read as oversized |

### Verification

| Check | Result |
| --- | --- |
| `npm --prefix functions test` | **133 passed, 0 failed** |
| `functions/test/hardening_source_contracts.test.js` | **14/14 passed** (was 13/14 — the guard itself was wrong; see below) |
| `flutter analyze` | **No issues found!** |
| `flutter test` | **all tests passed** |
| production-like boot (`FIREBASE_CONFIG` set, then `require("functions/index.js")`) | **all 20 functions register**; `admin.functions.https.HttpsError` **is** the real `firebase-functions` class and constructs a working error (`code`, `message`, `details`) — the end-to-end proof that the shim runs before any module loads |
| **production**, after deploy (`curl` the deployed `reviewResume` with no credentials) | `401` + `{"status":"UNAUTHENTICATED","message":"You must be logged in to review your resume."}` — the handler's **own** code and message, live; this returned `INTERNAL` before the fix |

#### Unrelated test defect found and fixed while verifying

Running the suite surfaced one failure, and it turned out to be a **bug in the
test**, not in the code under test:

```
✖ C-1: a committed keystore or key.properties would fail this test
  AssertionError: no real key.properties may be committed
```

The assertion read `fs.existsSync("android/app/key.properties")` — it tested
**working-tree presence**. But its own name and message say *committed*, and the
two are not the same thing: a machine that can assemble a release build **must**
carry a local, Git-ignored `key.properties`. So the guard could never pass on a
developer machine, and a permanently-red suite hides real regressions — the very
failure mode these contract tests exist to prevent.

The predicate now asks Git's index (`git ls-files --error-unmatch -- <path>`),
which is what "committed" actually means. Verified in both directions:

| Check | Result |
| --- | --- |
| `git ls-files --error-unmatch -- android/app/key.properties` | exit **1** → untracked → the guard **passes** |
| `git ls-files --error-unmatch -- android/app/key.properties.template` | exit **0** → tracked → the predicate returns `true` |
| `node --test functions/test/hardening_source_contracts.test.js` (real index) | **14/14 pass** |
| the same test with `key.properties` staged into a **throwaway** `GIT_INDEX_FILE` | **13/14 — the C-1 guard fails, exactly as intended** |

The throwaway index was used precisely so that a real signing secret never
entered the real Git index. `git status`, re-read after clearing the variable
(below), confirms nothing keystore-related was staged.

> Caveat if you reproduce this: `GIT_INDEX_FILE` must be **scoped to the
> individual `git` invocation**. In a long-lived shell an exported
> `GIT_INDEX_FILE` persists, and once the temporary index file is deleted every
> later `git status` reads an *empty* index and reports the whole repository as
> 436 staged deletions. That is display-only — `.git/index` is never written and
> nothing is lost — but it looks alarming. Note also that the C-1 assertion then
> passes *vacuously*, because a path in no index is reported as untracked. Set it
> per command (`$env:GIT_INDEX_FILE=…; git …; Remove-Item Env:GIT_INDEX_FILE`).

### Deployment — deployed and verified in production

**Deployed 2026-10-02 ~15:30 UTC** to `campusconnect-firebase-project`:

```
firebase deploy --only functions
…
+  functions[reviewResume(us-central1)] Successful update operation.
+  Deploy complete!
```

All **20 functions updated, none deleted**. The change is **server-side only**;
the Flutter client needs no rebuild.

**Live end-to-end proof of Defect 1's fix.** Calling the deployed function
without credentials exercises exactly the code path that used to crash — the
handler's own `new admin.functions.https.HttpsError("unauthenticated", …)`:

```
$ curl -i -X POST \
    https://us-central1-campusconnect-firebase-project.cloudfunctions.net/reviewResume \
    -H 'Content-Type: application/json' -d '{"data":{}}'

HTTP/1.1 401 Unauthorized
{"error":{"message":"You must be logged in to review your resume.",
          "status":"UNAUTHENTICATED"}}
```

Before the fix that same line returned `{"status":"INTERNAL"}`: the
`HttpsError` construction threw `TypeError: … reading 'https'` and `onCall`
re-wrapped it. The handler's **own message** now arrives with its **own code**,
in production, on the first try — which is the entire point of Defect 1.

Two things are now observable on a real failure:

1. **A failure now names itself.** Instead of a bare "Server error" the app
   receives the real code and message — `not-found` ("Your uploaded resume could
   not be found in storage. Please upload it again from your portfolio, then
   retry."), `invalid-argument` ("This resume appears to be image-based…"), or
   `resource-exhausted` with its `usage` details.
2. **The function log always names the stage**:
   `reviewResume: received request`, `resumeStorage: read N bytes from
   <bucket>/<path>`, `resumeTextFromStorage: extracted N characters`,
   `Groq: … finish_reason: length`,
   `HuggingFace: the JSON document was cut off … retrying with 8192 tokens`.

If a review still fails after this deploy, the log states the cause, and the
retry line shows whether the token budget was the reason.

> Version note: the code comments in these files stamp the fix `v9.2.5`, while
> ISSUE-2026-1002-01 below is stamped `v9.2.7`. The two are independent fixes;
> reconcile the release numbering before shipping.

---

## ISSUE-2026-1002-01 — Resume upload / remove reports success but nothing changes, and "Open Resume" returns **403 Permission denied** (v9.2.7)

**Reported (student dashboard → My Portfolio):**

> "whenever I try to upload a new resume inside my portfolio the message down that it is changes shows in green but the resume does not show that its updated, nothing changes. And when I try to view it I get error 403 message permission denied. And when I try remove it, similarly it shows the green pop saying its deleted but nothing happened, it's as it is."

**Symptom summary**

| Action | Snackbar | Actual result |
| --- | --- | --- |
| Replace Resume | "Resume uploaded successfully!" (green) | Card still shows the OLD file name / size / date / version |
| Open Resume | — | Browser: `403 Permission denied` |
| Remove Resume | "Resume removed." (green) | Resume stays exactly as it was |

Also visible on the same card: no **Reviews** count and no **Latest ATS** row, even though the user had 3 resume reviews in their history.

---

### Root cause

**One defect explains all three symptoms: every portfolio writer used DOT-NOTATION keys inside a `set(…, {merge: true})` payload.**

```dart
// BEFORE (broken) — lib/services/firestore/portfolio_service.dart
update['portfolio.$key'] = value;      // 'portfolio.resume', 'portfolio.skills', …
```

```js
// BEFORE (broken) — functions/triggers/index.js
"portfolio.resume.reviewCount": admin.firestore.FieldValue.increment(1),
"portfolio.resume.latestATSScore": atsScore,
```

Dot notation is a feature of **`update()`** (and `SetOptions(mergeFields:)`). In a
`set(…, merge: true)` payload a key that *contains* a dot is stored as a
**literal root-level field name**. So all of these writes landed as flat fields
next to the real data:

```
users/{uid}
  portfolio: { resume: {…old metadata…} }     ← what every reader reads
  "portfolio.resume":     {…}                 ← what the broken client wrote
  "portfolio.resume.reviewCount": 3           ← what the broken trigger wrote
  "metadata.updatedAt":   …                   ← the "nested" stamp, also literal
```

**Why the snackbar was honest and still wrong.** The Storage side of both
operations really succeeded — the PDF *was* overwritten at
`resumes/{uid}/latest.pdf`, and it *was* deleted on remove. Only the Firestore
metadata write was invisible to readers, so:
* the in-memory `_portfolio` did change for a moment, but the document never
  carried the new metadata, so every later read (stream replay, refresh,
  re-login) restored the old section;
* the reader (`PortfolioService._extractPortfolioMap`) prefers the canonical
  nested `portfolio` map (written by the v9.2.2 migration), so it never looked
  at the flat `portfolio.resume` field again.

**Why 403.** A Firebase Storage download URL carries a `token`, and that token
is **rotated whenever the object at the same path is overwritten** — which is
exactly what every resume replace does (same path, no versioning). The stored
`downloadUrl` was therefore a *dead token from the previous upload*. Opening it
in a browser returns `403 Permission denied` even though the current file
exists and is readable. This is the same root cause: the fresh URL from the new
upload never made it into the document.

**Why the review counters were also missing.** `onResumeReviewCreatedRefreshMatches`
wrote `portfolio.resume.reviewCount` / `…latestATSScore` with the same dotted
form, so those values sat beside the nested map. The helpers that decide
"is this only the review-counter write?" (`isResumeReviewMetadataOnlyChange`,
`portfolioContentChanged` in `functions/helpers/shared.js`) all read the
**nested** paths — proof that the nested shape is, and always was, the intended
one.

---

### Fix

**1. The write is now the canonical nested map (client).**
`PortfolioService.savePortfolio` builds its payload through the new pure,
unit-testable helper `PortfolioService.buildPortfolioWritePayload`, which emits
`{'portfolio': changedSections, 'metadata': {'updatedAt': …}}`. Per-section
diffing (H4/F5) is preserved, so sibling sections and remote edits are still not
clobbered. A cleared resume arrives as `resume: null` **inside** the nested map,
which replaces the section under merge semantics — that is what finally lets
"Remove Resume" stick.

**2. The write is now the canonical nested map (server).**
`onResumeReviewCreatedRefreshMatches` writes
`{portfolio: {resume: resumeMerge}}` with `merge: true`. `FieldValue.increment(1)`
still applies atomically, and `latestMissingKeywords` is still always written so
a review with no keywords clears the previous list. This makes the review
counter / ATS score visible to the app, the recommendation engine and the
fingerprint for the first time since the document was migrated to the nested
shape.

**3. The migration stamp is nested too.**
`migrateFlattenedPortfolio` wrote `'metadata.portfolioMigratedAt'` (another
literal root field). It now writes a nested `metadata` map. The legacy flat-key
DELETES are deliberately kept verbatim — those keys are literal field names, so
naming them exactly is correct.

**4. "Open Resume" resolves a FRESH URL (the 403).**
`ResumeService.getResumeUrl` now prefers a URL resolved live from `storagePath`
and only falls back to the cached `downloadUrl` when the live resolve fails
(offline). Every open path funnels through it; the two screens that bypassed it
(`resume_upload_screen.dart`, `resume_review_view.dart`) now call it and show a
clear "resume file is missing — upload it again" message instead of opening a
broken browser tab.

**5. Snapshot cache-replay rule (stops the "old resume comes back" race).**
The Firestore SDK replays its locally cached document as a normal event, which
is how a pre-write snapshot could revert a fresh upload. `PortfolioSnapshot`
(new model) carries Firestore's own `isFromCache` / `hasPendingWrites` flags
through `PortfolioService.portfolioSnapshotStream`, and the provider applies one
pure rule (`shouldApplyPortfolioSnapshot`): a **server-confirmed** snapshot
always applies — including one that removes the resume — while a **cache**
snapshot may bootstrap empty state but never overwrite data this session already
holds. The old "never let an event drop the resume while memory has one" guard is
**removed**: it was there to fend off stale replays, and its side effect was that
a removed resume could never leave the UI. `refresh()` now reads the server
explicitly (`Source.server`, cache fallback) so a pull-to-refresh cannot adopt a
stale cached document.

---

### Files changed

| File | Change |
| --- | --- |
| `lib/services/firestore/portfolio_service.dart` | nested write payload helper; `portfolioSnapshotStream`; `readPortfolioSnapshot` (server-preferred); nested migration stamp |
| `lib/models/portfolio/portfolio_snapshot.dart` | **new** — portfolio value + `isFromCache` / `hasPendingWrites` |
| `lib/providers/portfolio_provider.dart` | subscribes to the flagged stream; `shouldApplyPortfolioSnapshot`; removed the resume-drop guard; server-preferring `refresh()` |
| `lib/services/firestore/resume_service.dart` | `getResumeUrl` resolves a fresh URL first |
| `lib/views/portfolio/resume_upload_screen.dart` | "Open Resume" resolves + clear error message |
| `lib/views/resume_review_view.dart` | "Open Uploaded Resume" resolves + clear error message |
| `functions/triggers/index.js` | review counter/ATS merge written as a nested map |

### Tests

| Test | What it pins |
| --- | --- |
| `test/portfolio_write_payload_test.dart` | no dotted key anywhere in the payload; nested `metadata.updatedAt`; a cleared resume is `resume: null` inside the map; a no-op save omits `portfolio` entirely |
| `test/portfolio_snapshot_apply_test.dart` | the cache-replay rule for all four flag combinations; `PortfolioSnapshot` flags |
| `functions/test/portfolio_nested_write_contract.test.js` | source contract: the trigger writes the nested map and no writer reintroduces a literal dotted portfolio key |

Verification run: `flutter analyze` → no issues · `flutter test` → **552 passed**
(12 new) · `npm --prefix functions test` → 101 passed, 1 pre-existing unrelated
failure (`C-1` key.properties probe, which fails on any machine that has a local
release keystore — **since fixed**, because the probe itself was wrong; see
ISSUE-2026-1002-02) · the new functions contract test → 5/5 passed.

---

### Deployment note

The trigger half only takes effect after `firebase deploy --only functions`.
The client half works immediately. Legacy flat `portfolio.*` fields are still
tolerated by the reader, and the existing one-time
`migrateFlattenedPortfolio` login path deletes them, so no manual data cleanup
is required. Nothing needs to be re-uploaded for the 403 to stop: the URL is now
resolved live from the storage path on every open.

### Residual / follow-up

* If a resume PDF is genuinely absent from Storage while the document still
  claims one (a delete that ran while offline, for example), the open action now
  reports "Your resume file is missing. Upload it again." rather than opening a
  URL the browser will reject.
* The reader still accepts the legacy flattened shape. Once the flattened fields
  have been cleaned up for all accounts, `_extractPortfolioMap`'s
  un-flattening branch and `portfolio_migration.dart` can be removed.
