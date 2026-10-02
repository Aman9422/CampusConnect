# CampusConnect — v9.2.4 Confirmation (Definition of Done)

| | |
|---|---|
| **Release confirmed** | `9.2.4+101` (`pubspec.yaml`) |
| **Baseline** | `9.2.2+100` |
| **Confirmation date** | 2026-10-02 |
| **Scope confirmed** | `docs/Task.md` — *v9.2.4 Critical Security, Correctness & Production Hardening* |
| **Full report** | `docs/v9_2_4_hardening_report.md` |
| **Deployment scope** | **Direct APK installation — NOT Google Play publication** |

This document answers one question: **is the v9.2.4 Definition of Done met?**
Every status below is backed by a command that was run or a test that exists in the
tree. Nothing requiring a physical device, the Firebase Console or a real release
keystore is claimed as done — those are listed as operator actions.

---

## 1. Deployment scope (re-scoped during v9.2.4)

`docs/Task.md` §0 is authoritative: this is a final-year academic project and is
**not** published on Google Play.

```
Firebase backend (Auth · Firestore · Storage · Cloud Functions)
        |
        v
properly signed Flutter *release* APK
        |
        v
direct installation on a phone / emulator (adb install / USB / file transfer)
        |
        v
final-year project demonstration
```

Consequences that are *deliberately* not done, and are **not** v9.2.4 defects:

* No Google Play publication, no testing track, no Play Console account, no $25 fee.
* No App Bundle as a delivery artefact (it is built only to prove the signing config applies).
* **App Check enforcement is OFF by design** — a sideloaded release APK cannot obtain a
  valid Play Integrity token here (the provider's API link requires a Play Console account).
  See §4.

---

## 2. Definition of Done

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Release builds use a real release signing configuration, never the debug key | **MET** | `android/app/build.gradle.kts` builds a `release` signing config from `key.properties` with **no** debug fallback and an explicit abort when credentials are missing. Pinned by `functions/test/hardening_source_contracts.test.js` (C-1 group). |
| 2 | The signed release APK installs and launches on the demo device/emulator | **OPERATOR ACTION** | The APK is built and release-signed; installing it on the physical device is a human step (`adb install -r build/app/outputs/flutter-apk/app-release.apk`). Not performed here — no device attached to this environment. |
| 3 | App Check posture documented and deliberate; no insecure bypass | **MET** | `docs/app_check_status.md`; provider selection pinned by `test/app_check_config_test.dart` + the C-2 source contract. Enforcement deliberately off, reason recorded (§4 below). No debug provider on any release path, no custom attestation backend. |
| 4 | Resume Review no longer triggers duplicate recommendation regeneration | **MET** | `isResumeReviewMetadataOnlyChange()` guard in `functions/helpers/shared.js`, used by `functions/triggers/index.js`. `functions/test/resume_review_single_refresh.test.js`: metadata-only write → **0** refreshes; genuine change → exactly **1**; no engagement points on the metadata write. |
| 5 | Recommendation fingerprints converge correctly | **MET** | Same suite — three convergence tests (options-agnostic derivation, new review still invalidates, `portfolio.metadata`-only flutter ignored). Second half of the fix in `functions/recommendations/engine.js` (`extractUserSignals()` reads the persisted `portfolio.resume.latestMissingKeywords`). |
| 6 | Placement apply/update timeout contracts are aligned | **MET** | `lib/providers/placements_provider.dart` — 120 s (server: 120 s) and 60 s (server: 60 s). `test/placement_timeout_reconciliation_test.dart`. |
| 7 | Placement timeout no longer falsely rolls back successful applications | **MET** | Pending/reconciliation state replaces the rollback; single read reconciles. Same suite. |
| 8 | Client/server eligibility semantics are identical | **MET** | `lib/services/eligibility_engine.dart` treats `programs`/`branches` as alternatives, matching `checkMandatoryEligibility`. Table-driven `test/eligibility_parity_test.dart`. |
| 9 | Only authorized alumni can create opportunities | **MET** | `firestore.rules` — create requires `userRole() == 'alumni'`. **Executed** against the Firestore emulator by `functions/test-rules/firestore_rules.test.js` (alumni allowed; student/teacher/anon denied; owner update/delete allowed; non-owner denied), plus the text contract `functions/test/security_rules_contract.test.js`. |
| 10 | Opportunity schema validation is enforced | **MET** | `isValidOpportunityData()` applied on create **and** update. Malformed writes — missing field, empty `title`, wrong types, non-timestamp `postedAt`, a foreign `alumniId` — are **denied in the executed emulator suite**; the field set is reconciled against `lib/models/opportunity.dart::toFirestore`. |
| 11 | `profileCompleted` / `isVerified` gap is addressed | **MET** | `firestore.rules` — `profileCompleted` only as a validated absent/false → true transition with the required sections present; `isVerified` client-immutable. Both tampering writes are **denied in the executed emulator suite**, the genuine completion flow is allowed, and `role` self-elevation is denied in both directions. `role` behaviour unchanged. |
| 12 | AI chat has one writer and one schema | **MET** | Server is the sole writer of `users/{uid}/ai_interactions`; client write removed from `lib/providers/ai_chat_provider.dart` and `lib/models/ai_interaction.dart`; reader, retention sweep and history loading all use `timestamp`. `test/ai_chat_single_writer_test.dart` (+ existing `test/ai_chat_deletion_test.dart`). |
| 13 | `autoExpireOpportunities` safely handles large batches | **MET** | `functions/schedulers/index.js` chunks at 400/batch. `functions/test/schedulers_expiry.test.js` — empty / small / multi-batch. |
| 14 | `deepAnalysis.js` error handling is consistent | **MET** | `instanceof admin.functions.https.HttpsError` replaces the duck-typed check. `functions/test/hardening_source_contracts.test.js` (E-18 group). |
| 15 | Regression tests cover every critical fix | **MET** | 4 new Flutter suites + 4 new Functions suites + 1 **emulator-executed rules suite** (37 assertions) (§3). No existing test removed or weakened. |
| 16 | Flutter tests pass | **MET** | `flutter test` → **All tests passed! (540)**, exit 0. |
| 17 | Functions tests pass | **MET** | `npm --prefix functions test` → **97 tests / 97 pass / 0 fail / 0 skipped**. Separately, `npm --prefix functions run test:rules` → **37 tests / 37 pass / 0 fail** against the Firestore emulator. |
| 18 | `flutter analyze` passes | **MET** | `flutter analyze` → **No issues found! (ran in 13.5s)**, exit 0. |
| 19 | Release APK builds and is signed with the release key | **MET** | `app-release.apk` (56.7 MB) and `app-release.aab` (46.8 MB) both present; `apksigner verify --print-certs` reported a signer **different from the Android debug key** in both DN and SHA-256 (§3). The App Bundle build is optional per §0. |
| 20 | No secrets are committed | **MET** | `git ls-files` filtered for `key.properties` / `*.jks` / `*.keystore` → **no matches**. Debug App Check tokens are not committed (C-2 contract). |
| 21 | v9.2.4 documentation/report is complete | **MET** | `docs/v9_2_4_hardening_report.md` (§1–§20), `docs/release_signing.md`, `docs/app_check_status.md`, `docs/eligibility_rules.md`, `docs/Task.md` §0 + re-scope notes, `docs/todo.md`, this confirmation. |
| 22 | No unrelated UI, architecture or dependency changes | **MET** | No UI/UX redesign; no provider architecture change; `firebase-functions`/`firebase-admin`/`pdf-parse`/Flutter/Android toolchain versions untouched. `pubspec.yaml` changed only its version string. |

**Verdict: 20 of 22 criteria met in this environment. Criterion 2 (install on the
demo device) is the only substantive operator action; criterion 19's *final*
key identity likewise belongs to the operator, because the build here used a
throwaway validation keystore.**

---

## 3. Verification commands and observed results

Run on 2026-10-02 on this machine, after the last source change.

| Command | Observed |
|---|---|
| `flutter analyze` | `No issues found! (ran in 13.5s)` — exit `0` |
| `flutter test` | `All tests passed!` — **540** tests, exit `0` |
| `npm --prefix functions test` | `# tests 97` · `# pass 97` · `# fail 0` · `# skipped 0` |
| `npm --prefix functions run test:rules` | Firestore emulator + `node --test functions/test-rules/firestore_rules.test.js` → `# tests 37` · `# pass 37` · `# fail 0` · `# skipped 0`; emulator shut down cleanly — exit `0` |
| `node --check` (shared.js, triggers/index.js, schedulers/index.js, ai/deepAnalysis.js, recommendations/refresh.js, recommendations/engine.js) | exit `0` on every file — no syntax error |
| `git ls-files` filtered for key material | no `key.properties`, no `*.jks`, no `*.keystore` tracked |
| `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` — **56.7 MB** |
| `flutter build appbundle --release` *(optional)* | `build/app/outputs/bundle/release/app-release.aab` — **46.8 MB** |
| `apksigner verify --print-certs` (APK) | `CN=CampusConnect Validation, OU=Local, O=CampusConnect, L=NA, ST=NA, C=IN`, SHA-256 `03:B7:0D:79:…:A8:DA` — **not** the debug key |
| `apksigner verify --print-certs` (AAB) | same validation signer; **not** the debug key |
| debug key for comparison | `CN=Android Debug, O=Android, C=US`, SHA-256 `13:65:4F:0D:…:41:A3` — different DN **and** digest |

> **The APK currently in `build/` was signed with a throwaway validation keystore,
> which was deleted immediately after the check** (the C-1 contract test fails if a
> keystore or a real `key.properties` is present in the tree). It proves the signing
> *mechanism*; the operator must rebuild with their own release key before the demo —
> see `docs/release_signing.md` §6.

**New test suites**

| Suite | Count relevance |
|---|---|
| `test/app_check_config_test.dart` | C-2 provider selection |
| `test/eligibility_parity_test.dart` | D-3 table-driven parity |
| `test/placement_timeout_reconciliation_test.dart` | D-2 timeout + pending/reconciliation |
| `test/ai_chat_single_writer_test.dart` | D-7 single writer + schema |
| `functions/test/hardening_source_contracts.test.js` | C-1, C-2, E-18 source contracts |
| `functions/test/resume_review_single_refresh.test.js` | D-1 guard + fingerprint convergence |
| `functions/test/security_rules_contract.test.js` | D-9, D-10, D-11 — source contract on the rule text |
| `functions/test/schedulers_expiry.test.js` | E-3 empty / small / multi-batch |
| `functions/test-rules/firestore_rules.test.js` | D-9, D-10, D-11, SEC-1, SEC-2, D-7 — **executed against the Firestore emulator**, 37 allow/deny assertions |

**Emulator-executed rules tests.** `functions/test-rules/firestore_rules.test.js`
loads `firestore.rules` into the Firestore emulator through
`@firebase/rules-unit-testing`, signs in as alumni / student / teacher / anonymous,
and asserts what the rules **actually allow and deny** (37 cases: D-9 authorization,
D-10 schema validation, SEC-1 role immutability, D-11 profile flags, SEC-2
server-owned collections, D-7 append-only `ai_interactions`, catch-all removal, and
the placement regressions). Run it with:

```
npm --prefix functions run test:rules
```

The script is new in `functions/package.json`, which also adds
`@firebase/rules-unit-testing` and `firebase` as **devDependencies** — the only
dependency-manifest change in v9.2.4, dev-only and not deployed. The emulator needs
a JVM: `JAVA_HOME` on this machine pointed at a non-existent JDK, so the Android
Studio JBR was used. Observed: `# tests 37` · `# pass 37` · `# fail 0`, exit `0`.

---

## 4. App Check — the deliberate non-enforcement decision

Full detail: `docs/app_check_status.md`. Summary:

| Aspect | State |
|---|---|
| Provider selection | correct; debug/profile → debug providers, release → Play Integrity / DeviceCheck, Web → reCAPTCHA v3 (opt-in) |
| Release build receiving a debug provider | **impossible** — forbidden in code and asserted by tests |
| Debug token committed | **no** |
| Enforcement (Firestore / Functions / Storage) | **OFF — by design, documented** |
| Insecure bypass / custom attestation backend | **none introduced** |

Why off: the Play Integrity provider *does* support non-Play distribution, but
linking the Play Integrity API requires a Play Console developer account (out of
scope per §0), and App Check demands the `PLAY_RECOGNIZED` label by default, which
apps not published on Play are not eligible for. A sideloaded release APK therefore
cannot obtain a valid token, and enforcement would deny 100 % of demo traffic.
Authentication, Firestore rules, Storage rules, callable auth/role re-checks,
quota/rate limits and server-owned collections all stay enforced regardless.

---

## 5. Outstanding operator actions

These need a device, the Firebase Console, or a private key — none of them is a
code defect, and each is documented where it is performed.

1. **Generate the release keystore and build the demo APK** with the operator's own
   key (`docs/release_signing.md` §2–§6), then `apksigner verify --print-certs` and
   confirm the digest is not the debug key.
2. **Install and launch the release APK on the demo device/emulator**
   (`adb install -r build/app/outputs/flutter-apk/app-release.apk`) and run the
   manual pass in `docs/Task.md` §15 (auth, resume review, placements,
   opportunities, AI chat, one end-to-end pass per role).
3. **Allow-list the development App Check debug token** (App Check → Manage debug
   tokens) so `flutter run` sessions attest cleanly. This does **not** change the
   release posture.
4. **Leave App Check enforcement OFF.** Only revisit if a Play Console account is
   created, then follow `docs/app_check_status.md` §7.
5. **Deploy the hardened rules and Functions** when ready
   (`firebase deploy --only firestore:rules,storage,functions`) — deploying is a
   production action and was not performed here. The Firestore rules themselves are
   already **behaviour-verified against the emulator** (37/37); an equivalent
   executed suite for `storage.rules` is a follow-up, not a blocker.

---

## 6. Corrections and marked updates made during v9.2.4

Per `docs/Task.md` §16, corrections are marked rather than silently applied:

* `docs/v9_2_3_audit_report.md` — §AD addendum: report date (2026-10-02), the
  v9.2.3 = audit-only vs v9.2.4 = implementation distinction, and a reconciliation
  of inconsistent test-count wording. No historical result was changed.
* `docs/v9_2_2_investigation_report.md` — a **HISTORICAL DOCUMENT** banner was added
  (audit finding E-17): its `9.1.2+99` header is a record of the version under
  investigation, not current status. Content below the banner is unedited.
* This file previously held the V9.2 whole-app audit report. It is preserved
  verbatim below the archive boundary, and remains in git history.
* **Rules verification upgraded (same release, no historical result changed).**
  v9.2.4 originally validated `firestore.rules` by **source contract only**. It now
  also **executes** the rules against the Firestore emulator
  (`functions/test-rules/firestore_rules.test.js`, 37 allow/deny assertions,
  `npm --prefix functions run test:rules`) — the follow-up the original report
  listed as its first item of remaining work. `docs/v9_2_4_hardening_report.md`
  §14/§15.2/§17.1/§18 and this document were updated to reflect that; nothing was
  recorded as passing before it was actually run.

---

> ---
> ## ARCHIVE — superseded document, preserved verbatim
>
> Everything below this line is the **V9.2** confirmation content as it stood
> before v9.2.4 (`docs/todo.md` §0 records that workstream as complete). It is kept
> in-tree so the tree stays self-describing rather than relying on git history.
> It described a **Play-bound** release plan, which `docs/Task.md` §0 re-scoped
> during v9.2.4; read it as a historical record, not current status.
>
> Current status lives in `docs/v9_2_4_hardening_report.md`.

---

# CampusConnect — V9.2 Whole-App Audit Report

**Audit date:** 2026-09-27
**Build audited:** `9.1.2+99` (`pubspec.yaml`) with the **V9.2 optimization workstream** applied (`docs/Task.md`, `docs/v9_2_audit_report.md`)
**Scope:** every layer — Flutter `lib/`, Cloud Functions `functions/`, Firestore rules, Storage rules, indexes, quotas, schedulers, recommendation engine, AI providers, engagement, placement pipeline, resume review, portfolio, teacher analytics, alumni chat, role/routing, App Check, secrets, tests.
**Method:** full source read of every file cited, plus authoritative Firebase docs for rule semantics. Every finding below names the file and symbol that proves it.

> **Verdict up front: NOT production-safe.** Two **Firestore rules** defects (SEC-1, SEC-2) are exploitable by any signed-in user and were *not* caught by the V9.2 pass (which modified no rules). SEC-1 allows **privilege self-elevation to teacher/alumni** via a single client write — granting access to every user's PII, all resume reviews, all analytics, and all applications. Two HIGH functional defects (BUG-1, BUG-2) silently break the AI retention policy and make engagement points/badges flicker. All are small, surgical fixes.

---

## Severity Matrix

| ID | Sev | Area | Finding | Verified in |
|----|-----|------|---------|-------------|
| **SEC-1** | **CRITICAL** | Rules | `match /{subcollection=**}` (v2 ⇒ matches **zero** segments) grants `isOwner(userId)` write on the `users/{uid}` **document itself**, overriding `canWriteRole` → any user can set `role:'teacher'`/`'alumni'` | `firestore.rules` |
| **SEC-2** | **HIGH** | Rules | Same catch-all overrides `allow write: if false` on `recommendations`, `recommendations_meta`, `engagement_summary`, `ai_insights`, `career_coach` **and** the MED-5 `activities` points restriction / `ai_interactions` `update:false` — the "single-writer", "CF-only" and "can't self-award points" contracts are not rule-enforced | `firestore.rules`, `engagement_service.dart`, `recommendation_service.dart` |
| **BUG-1** | **HIGH** | Functions | `cleanupExpiredAIConversations` filters `ai_interactions` by `createdAt`; `askAI` writes `timestamp` → retention **never deletes anything** (unbounded growth + privacy retention failure) | `functions/ai/chatDelete.js`, `functions/ai/chat.js` |
| **BUG-2** | **HIGH** | Client+Fn | Engagement has **two live writers** (`EngagementService.recomputeEngagement` on every login vs server `logUserActivity`/`recomputeEngagementSummary`) with divergent point/streak algorithms → score & badge flicker, double-counted client recompute, 200 reads + 1 write per login | `engagement_service.dart`, `engagement_provider.dart`, `functions/helpers/shared.js`, `functions/helpers/engagement.js` |
| **BUG-3** | MED | Functions | `logPlacementApplication` copies the immutable resume snapshot **before** the idempotency check → a duplicate apply re-copies the *current* resume over `snapshots/app_{applicationId}.pdf` | `functions/placements.js` |
| **BUG-4** | MED | Functions | Placement callables omit `timeoutSeconds`; snapshot copy + signed-URL generation run on the default 60 s ceiling and on every duplicate call | `functions/placements.js` |
| **BUG-5** | MED | UI/Logic | Teacher `StudentAnalyticsView` renders "Resume Reviews / Avg Score" from the **teacher's own** `ResumeReviewProvider.history` — contradicting the real cross-student numbers shown lower on the same screen | `lib/views/teacher/student_analytics_view.dart` |
| **BUG-6** | MED | Functions | `updateApplicationStatus` re-creates a missing mirror as a **partial** doc (no `resume`/`resumeStoragePath`/`appliedAt`) and re-reads the placement after the transaction (redundant read) | `functions/placements.js` |
| **BUG-11** | MED | Recommendation | "Career match: X" role cards are still emitted for roles the student never chose, even when the student has **declared** a career interest (e.g. "Web Developer · 26%" to an App-Development student). **Fixed in code** this pass (engine now suppresses all role cards once a role is declared). | `functions/recommendations/engine.js` |
| **PERF-1** | MED | Cost | Teacher analytics still does **N+1 reads of `engagement_summary`** per student + an **unbounded** roster scan + an up-to-800-doc recommendations read per load | `lib/services/firestore/teacher_analytics_service.dart` |
| **BUG-7** | LOW | Functions | `generateResumeAnalysis` destructures `request.data` unguarded (every sibling callable now uses `request.data || {}`) | `functions/ai/deepAnalysis.js` |
| **BUG-8** | LOW | Utility | `LoadDedupe.begin` discards the future returned by `whenComplete`, an unhandled-error surface | `lib/utilities/load_dedupe.dart` |
| **BUG-9** | LOW | State | `AuthGuard._profileSynced` is one-shot per session → `PlacementsProvider` eligibility is stale after an in-session profile edit | `lib/main.dart` |
| **BUG-10** | LOW | Dead code | `EngagementProvider.trackActivity` has **no callers**; if used with any event other than `resumeReviewed`/5 the `activities` rule rejects it silently | `engagement_provider.dart`, `firestore.rules` |
| **INT-1** | LOW | Storage | Placement **snapshot** objects (`resumes/{uid}/snapshots/app_*.pdf`) are not matched by `resumes/{userId}/{fileName}` → reachable only via the long-lived signed URL | `storage.rules`, `functions/placements.js` |
| **TEST-1** | LOW | Tests | `functions` test script runs only `quota.test.js` + `schedulers.test.js`; placements/chat/resume/careerCoach/triggers/deepAnalysis have no tests (Task §20 asks for them) | `functions/package.json` |

**Resolved since the V9.1 report (do not re-open):** SEC-1…SEC-5 (v9.1 set), BUG-A, BUG-B, BUG-E, BUG-H — and **BUG-D is now fixed**: `teacher_dashboard_sections.dart` derives the placement rate from `analytics.pipelinePlaced` (lines 234/438/696). `placementApplicantsRoute` is now role-gated (`_guardPlacementApplicants` in `main.dart`), closing SEC-6.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Critical & High Findings](#2-critical--high-findings)
3. [Bugs & Logical Errors](#3-bugs--logical-errors)
4. [Firebase Rules, Functions & Indexes](#4-firebase-rules-functions--indexes)
5. [Routing & Integration](#5-routing--integration)
6. [Edge Cases & Boundary Problems](#6-edge-cases--boundary-problems)
7. [Performance, Scale & Cost](#7-performance-scale--cost)
8. [Security: App Check, Secrets, Input Validation](#8-security-app-check-secrets-input-validation)
9. [Improvements (priority-ordered)](#9-improvements-priority-ordered)
10. [Carried-Over Open Items](#10-carried-over-open-items)
11. [Verdict & Version History](#11-verdict--version-history)

---

## 1. Executive Summary

The V9.2 workstream itself is sound and its housekeeping landed well: lazy dashboard tabs, `LoadDedupe`, the listener-lifecycle fixes, the teacher-analytics N+1 removal, the scheduler consolidation (7→5 jobs) and the unified `user_ai_quotas` store are all present and internally consistent, and `flutter analyze` is clean.

But V9.2 **touched no rules**, and the rules contain a latent structural defect that predates it and was never exercised by a test: a recursive catch-all that (under `rules_version = '2'`) also matches the **parent** document. The consequences are the two most important findings in this report:

- **SEC-1 — privilege self-elevation.** `canWriteRole` (the "F1 fix" from v8.4.6 that was supposed to make `role` immutable) is **completely bypassed**, because the later catch-all grants the owner an unconditional `write`. A one-line client write (`users/{uid}.update({role:'teacher'})`) turns any student into a teacher, unlocking `isTeacher()`-gated reads of every user document, all resume reviews, all analytics, all engagement summaries and all applications. This is the exact hole the rules claim to have closed (see the `F1 (security)` comment in `firestore.rules`).
- **SEC-2 — contract bypass + a false "single writer" claim.** The same catch-all defeats `allow write: if false` on five subcollections. Worse, the client *already* relies on it: `EngagementService.recomputeEngagement` writes `engagement_summary/summary` and `RecommendationService.createRecommendation`/`markRecommendationInteracted` write `recommendations/*`. So the documented "Cloud Functions are the only writer" contract is not enforced by rules at all — and **BUG-2** shows the engagement dual-writer is not merely theoretical: it produces wrong numbers.

Two HIGH functional defects sit alongside: the AI retention job never deletes a single document (**BUG-1**), and engagement points are double-counted in one writer and streaked in two different time zones (**BUG-2**).

Items 1–4 in [§9](#9-improvements-priority-ordered) are small, local, and should ship before anything else.

---

## 2. Critical & High Findings

### SEC-1 [CRITICAL] — Rules catch-all bypasses role immutability → user self-elevates to teacher/alumni

**File:** `firestore.rules`

```rules
match /users/{userId} {
  allow read, write: if isOwner(userId) && canWriteRole(userId);   // (A) tries to freeze `role`
  ...
  // All other subcollections under users/{uid}
  match /{subcollection=**} {                                       // (B) ← catch-all
    allow read, write: if isOwner(userId);
  }
}
```

The rules file begins with `rules_version = '2';`. Per the Firebase documentation (*Structuring Cloud Firestore Security Rules → “Version 2”*):

> “In version 2 … recursive wildcards match **zero or more** path items. `match /cities/{city}/{document=**}` matches documents in any subcollections **as well as documents in the `cities` collection**.”

Nested under `match /users/{userId}`, rule (B) therefore applies to the path `/users/{userId}/{subcollection=**}` — and with **zero** captured segments that is `/users/{userId}` **itself**, i.e. the user document.

Firestore rules are **additive**: “if multiple `allow` expressions match a request, the access is allowed if **any** of the conditions is `true`” (same doc, “Overlapping match statements”). There is no deny precedence. Therefore, for a write to `users/{uid}`:

- (A) grants only when `canWriteRole(userId)` is true, **and**
- (B) grants whenever `isOwner(userId)` is true — **which it always is for your own doc.**

Because (B) grants, the write is allowed **regardless of `canWriteRole`**. The `role`-immutability guard never runs.

**Exploit (any authenticated user, incl. web DevTools against the deployed project):**

```js
await db.collection('users').doc(myUid).update({ role: 'teacher' }); // allowed by (B)
```

Immediately `userRole()` → `'teacher'`, so `isTeacher()` is true and the actor can read:

- **every** `users/*` doc via `allow read: if isTeacher();` (phone, email, academic records — the v8.4.2 M2 privacy caveat becomes a full-roster PII dump),
- every `resumeReviews/*` (ATS scores, strengths, weaknesses, missing keywords) via `/{path=**}/resumeReviews/{reviewId}`,
- every `recommendations/*` and `engagement_summary/*` via their teacher collectionGroup rules,
- every `applications/*` via `/{path=**}/applications/{appId} { allow read: if isTeacher() … }`.

Setting `role: 'alumni'` unlocks `isAlumni()` reads of all placement applications and student portfolios. `canManagePlacements()` then permits creating placements. This is a full cross-role data-exfiltration primitive from an ordinary account.

**Fix (one of):**
1. Delete the catch-all and enumerate the genuinely owner-writable subcollections (`notifications`, `resumeReviews`, and the two engagement/recommendation paths that must remain owner-writable — see SEC-2), or
2. Keep the catch-all but restrict it to creation of owner data only, e.g. `match /{subcollection=**} { allow read: if isOwner(userId); allow create: if isOwner(userId); }` — never `write`, and never covering the parent path, or
3. Re-add the role guard explicitly inside the catch-all and stop relying on `canWriteRole` from the parent rule.

Whichever is chosen, add a regression test (firestore rules unit test or a documented manual check) that a client write of `role` is **denied**.

### SEC-2 [HIGH] — Same catch-all defeats `write:if false` on five subcollections; the client already writes two of them

**Files:** `firestore.rules`; `lib/services/firestore/engagement_service.dart`; `lib/services/firestore/recommendation_service.dart`

The catch-all (SEC-1) also matches any **deeper** path, so the following hardening is inert for the document's owner:

| Subcollection | Declared | Actually effective (owner) |
|---|---|---|
| `recommendations/{id}` | `allow write: if false` | **writable** |
| `recommendations_meta/{id}` | `allow write: if false` | **writable** |
| `engagement_summary/{id}` | `allow write: if false` | **writable** |
| `ai_insights/{id}` | `allow write: if false` | **writable** |
| `career_coach/{id}` | `allow write: if false` | **writable** |
| `activities/{id}` | `allow create: if … eventType=='resumeReviewed' && points==5` (MED-5) | **any `eventType`/`points` writable** |
| `ai_interactions/{id}` | `allow update: if false` | **updatable** (append-only intent void) |

This is not hypothetical. Two live client code paths depend on the hole:

- `EngagementService.recomputeEngagement` → `_summaryRef(userId).set(summary, merge:true)` writes `users/{uid}/engagement_summary/summary` **from the client** (called on every login by `EngagementProvider.initWithUser`).
- `RecommendationService.createRecommendation` and `markRecommendationInteracted` write `users/{uid}/recommendations/*` from the client.

So the in-code claims — e.g. the `career_coach` rule comment *“Prevents clients from bypassing the AI + quota system by writing directly to the summary doc”* and the recommendation `“single-writer contract”* — are **false as written**. A user can:

- write `career_coach/summary` directly, bypassing the AI call and the 3/month quota entirely (and read the crafted doc back as if the coach produced it);
- forge `recommendations/*` (arbitrary `score`, `opportunityId`, `reason`) so the dashboard shows fabricated “Recommended for You” items;
- write `engagement_summary/summary` with `engagementScore:100` and pre-earned badges (see BUG-2 for the organic version of the same corruption);
- write `ai_insights/*` and read them back as server-generated.

There is no cross-user impact (each write is scoped to the writer), so this is data-integrity / contract-bypass rather than exfiltration — but it silently invalidates the quota and single-writer designs that several docs assert are in force.

**Fix:** Decide, per subcollection, who the writer is, and make the rules match reality:
- If engagement is genuinely client-computed, the rule must say so explicitly (`allow create, update: if isOwner(userId) && validEngagementShape()`) **and** the server must stop being a second writer (BUG-2).
- If recommendations/career_coach/ai_insights remain CF-only, the catch-all must not grant them (see SEC-1 fix).

Because a `write:false` rule and the catch-all can never coexist safely, fix SEC-1 first; SEC-2 then falls out automatically once the catch-all is narrowed.
---

## 3. Bugs & Logical Errors

### BUG-1 [HIGH] — AI-chat retention never deletes `ai_interactions` (field-name mismatch)

**Files:** `functions/ai/chatDelete.js` (`cleanupExpiredAIConversations`), `functions/ai/chat.js` (`askAI`)

`askAI` writes both chat turns to `users/{uid}/ai_interactions` with the field **`timestamp`**:

```js
// askAI (user turn) and (assistant turn)
.add({ role, message, timestamp: admin.firestore.FieldValue.serverTimestamp(), ... })
```

`cleanupExpiredAIConversations` (daily) queries the same collection by **`createdAt`**:

```js
.collectionGroup("ai_interactions")
.where("createdAt", "<", cutoff)   // ← no document has `createdAt`
.limit(5000).get();
```

No `ai_interactions` document carries `createdAt`, so the query always returns empty and **the retention window (default 90 days) is never enforced** — chat history grows without bound, and the documented “delete ONLY expired ai_interactions” behaviour does not happen. The v8.8.3 HIGH-4 note (“both exactly match the fields askAI writes”) is therefore **incorrect**: the legacy `ai_conversations` branch does use `timestamp` (matching), but that collection is no longer written — IMP-11 removed the `ai_conversations` writes — so **neither** branch deletes anything in practice.

**Fix:** change the `ai_interactions` filter to `where("timestamp", "<", cutoff)` (and either drop the dead `ai_conversations` branch or keep it purely for the transition window). Add a Functions test that seeds an old `timestamp` doc and asserts deletion.

### BUG-2 [HIGH] — Engagement has two writers with divergent algorithms (flicker + double-count + per-login cost)

**Files:** `lib/services/firestore/engagement_service.dart` (`recomputeEngagement`), `lib/providers/engagement_provider.dart` (`initWithUser`), `functions/helpers/shared.js` (`logUserActivity`), `functions/helpers/engagement.js` (`recomputeEngagementSummary`), `functions/triggers/index.js`

`users/{uid}/engagement_summary/summary` is written by **both** the client and the server:

- **Server** — `logUserActivity` maintains the materialized aggregate (`activityPoints`/`dailyStreak`/`streakLastActiveKey`/`lastActiveAt`) atomically, and `recomputeEngagementSummary` (daily scheduler + the `onProfileUpdatedRefreshAI` / `onResumeReviewCreatedRefreshMatches` triggers) rewrites the score/badges from those aggregates.
- **Client** — `EngagementService.recomputeEngagement` runs on **every login** (`EngagementProvider.initWithUser` → `await _service.recomputeEngagement(...)`) and, in a `try/catch` that swallows failures, `.set()`s a freshly computed summary (via the SEC-2 rule hole).

The two computations **disagree**:

1. **Points double-count (client side).** A resume review writes **two** `activities` docs (client `logActivity` at 5 pts + the server trigger’s `logUserActivity` at 5 pts — see the note in §4). The server keeps a running aggregate and only increments once per `logUserActivity`, so the *server* summary stays consistent. But the client recomputes `activityPoints` by **summing the newest 200 activity docs**, which now includes both docs → the client-computed score is ~2× the server’s for that event. The displayed score therefore changes depending on **who wrote last**, and the `active_student`/`networking_pro` badges (thresholds 50/100) can flip earned↔locked between a login and the next daily recompute.
2. **Streak uses different clocks.** The client builds “consecutive days” from **local** calendar days (`DateTime.now()` bucketing) and requires the streak to include today, otherwise it breaks to 0; the server uses **UTC** day keys with a materialized pointer (`dayKey`/`previousDayKey`). In IST (UTC+5:30) the two disagree for ~5.5 h of every day, so `dailyStreak` can differ by one and the “Consistency Champion” progress wobbles.
3. The client recompute also **overwrites the server’s materialized aggregate** with a scan-derived value (`activityPoints`/`dailyStreak` are written, `streakLastActiveKey` is not), defeating the IMP-9 optimisation that was supposed to stop scanning activity docs — the next `logUserActivity` then increments from the client-clobbered base.

**Cost:** on every login the client reads up to 200 activity docs and writes the summary — a pure waste given the server already owns the value.

**Fix:** pick **one** writer. Recommended: the server is the single writer (it already maintains the aggregate and badges atomically); delete/retire `EngagementService.recomputeEngagement` from the login path and have the client only *read* `engagement_summary` (the stream already exists: `engagementSummaryStream`). Also remove the redundant client `resumeReviewed` activity write so the points are logged once. If the client must stay a writer, then (a) the rules must explicitly permit it (SEC-2) and (b) both engines must share one algorithm (same clock, same aggregation source).

### BUG-3 [MEDIUM] — Duplicate apply overwrites the “immutable” resume snapshot

**File:** `functions/placements.js` (`logPlacementApplication`)

The snapshot copy runs **before** the idempotency transaction:

```js
// copies latest.pdf → snapshots/app_{applicationId}.pdf  ← runs unconditionally
if (resumeStoragePath) { await bucket.file(resumeStoragePath).copy(bucket.file(snapshotPath)); ... }

await admin.firestore().runTransaction(async (tx) => {
  const existingApp = await tx.get(existingAppRef);
  if (existingApp.exists) { isNewApplication = false; return; }   // ← idempotent no-op, no writes
  ...
});
```

`logPlacementApplication` is idempotent by design (“safe to call multiple times”), but the snapshot copy is **not** gated by the idempotency check. A second call for the same `applicationId` re-copies the **current** `resumes/{uid}/latest.pdf` over the existing snapshot. If the student replaced their resume between the two calls, the snapshot the teacher later reviews is the **new** resume, not the one submitted at apply time — silently defeating the v8.4.2 S2a/H1 “immutable snapshot so bytes survive re-uploads” contract. It also costs a Storage copy + a `getSignedUrl` on every duplicate attempt.

**Fix:** move the snapshot copy **inside** the transaction path, immediately before `isNewApplication = true`, or short-circuit the copy with a pre-check `bucket.file(snapshotPath).exists()` and reuse the existing snapshot/URL when it already exists.
### BUG-4 [MEDIUM] — Placement callables have no `timeoutSeconds`; snapshot work runs on the default 60 s ceiling

**File:** `functions/placements.js`

`logPlacementApplication` is declared `onCall({cors: false, maxInstances: 100})` and `updateApplicationStatus` `onCall({cors: false, maxInstances: 20})` — neither sets `timeoutSeconds`. The default callable timeout is 60 s, and `logPlacementApplication` performs a Storage `copy` **plus** a `getSignedUrl` (both network round-trips to GCS) before it even opens the Firestore transaction. Under load or a slow bucket, the copy + signed-URL path can exceed the default budget, failing the apply with an `internal` error even though nothing is wrong with the data. Every sibling callable in the codebase (`askAI`, `reviewResume`, `deleteAIHistory`, `generateResumeAnalysis`, `refreshRecommendations`) sets an explicit timeout; these two do not.

**Fix:** add an explicit `timeoutSeconds` (e.g. 60 for `updateApplicationStatus`, 120 for `logPlacementApplication` given the Storage work) and cap `maxInstances` sensibly. (Folded into BUG-3's fix, which also removes the duplicate-call copy.)

### BUG-5 [MEDIUM] — Teacher “Resume Review Insights” are the teacher’s own reviews, not the students’

**File:** `lib/views/teacher/student_analytics_view.dart` (`_buildOverviewMetrics`, `_buildResumeInsights`)

```dart
final reviews = resumeProvider.history;                  // ResumeReviewProvider.history
final totalReviews = reviews.length;
final avgReviewScore = reviews.isNotEmpty ? ... : 0.0;   // "Avg Review Score"
```

`ResumeReviewProvider.history` is loaded by `ResumeHistoryService.fetchHistory(userId)` from the **signed-in user's own** `users/{uid}/resumeReviews`. On the **teacher** analytics screen this is the teacher's personal review history (almost always empty), yet it is rendered as “Resume Reviews”, “Avg Review Score” (Overview Metrics) and “Resume Review Insights → Total Reviews / Avg Score”.

The same screen, lower down, renders the **correct** cross-student values from `TeacherAnalyticsProvider` (`_buildResumeAggregates` → `provider.totalReviews` / `provider.averageScore`, sourced from the `resumeReviews` collectionGroup scan). So the screen shows two contradictory sets of numbers with the same labels — e.g. “Resume Reviews: 0 / Avg: N/A” directly above “Total Reviews: 312 / Avg: 74”. This is the teacher equivalent of the BUG-D (v9.1) “wrong source for a dashboard metric” class, and it survives V9.2.

**Fix:** drive both sections from `TeacherAnalyticsProvider` (`totalReviews`, `averageScore`), or remove the duplicate “Resume Review Insights” section entirely (it already exists as `Resume Review Analytics`).

### BUG-6 [MEDIUM] — `updateApplicationStatus` re-creates a partial mirror + does a redundant placement read

**File:** `functions/placements.js` (`updateApplicationStatus`)

When the mirror is missing, the transaction re-creates it as a **partial** document:

```js
transaction.set(mirrorRef, {
  userId: studentId, studentId, placementId, status,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  // ← no resume / resumeStoragePath / appliedAt / resumeVersion / atsScoreAtApplication
});
```

So a recovered mirror is missing `resume`/`appliedAt` that the canonical doc (and the applicants UI) rely on — the mirror exists but is not equivalent to a canonical write. Separately, after the transaction the function re-reads the placement to build the notification:

```js
const placementDoc = await db.collection("placements").doc(placementId).get();   // already read inside the txn
```

That is one redundant document read per status update (and a read that could race a concurrent edit).

**Fix:** (a) copy the resume fields from the canonical doc (`canonicalData`) into the re-created mirror so the two stay equivalent; (b) capture `placementData` (already fetched in the transaction) and pass it to `_notifyStatusChange` instead of re-reading.

### BUG-7 [LOW] — `generateResumeAnalysis` destructures `request.data` unguarded

**File:** `functions/ai/deepAnalysis.js`

```js
const { reviewId, resumeText, targetRole } = request.data;   // throws if request.data is undefined
```

Every other callable in the tree now null-guards (`const { … } = request.data || {}` — see `askAI`, `logPlacementApplication`, `updateApplicationStatus`, `logPlacementView`). A callable invoked with no body here throws a raw `TypeError`, surfaced to the client as `internal` instead of a friendly `invalid-argument`.

**Fix:** `= request.data || {}`.

### BUG-8 [LOW] — `LoadDedupe.begin` leaves an error future unhandled

**File:** `lib/utilities/load_dedupe.dart`

```dart
void begin(Future<void> future) {
  _active = future;
  future.whenComplete(() { if (identical(_active, future)) _active = null; });
}
```

`whenComplete` returns a **new** future carrying the same error; that future is discarded. If the guarded load ever completes with an error, this becomes an unhandled async error (a zone-level crash in tests / red screen in debug). In practice `_runLoad` catches everything, so it is latent — but `LoadDedupe` is documented as a general-purpose reusable gate, so it should not have an unhandled-error path.

**Fix:** `future.whenComplete(...).catchError((_) {});` or store/await the returned future.

### BUG-9 [LOW] — One-shot profile sync leaves `PlacementsProvider` eligibility stale mid-session

**File:** `lib/main.dart` (`AuthGuard.build`)

`_profileSynced` makes `placementsProvider.updateUserProfile(profile)` run **once per session**. If the user later edits their profile (skills/CGPA/department) during the same session, `PlacementsProvider` keeps the old snapshot for eligibility checks until the next login. Low impact (eligibility is re-checked server-side at apply time), but the client-side pre-filter can disagree with the server.

**Fix:** re-run `updateUserProfile` when `ProfileProvider` signals a profile change (e.g. watch a `profileVersion`/`updatedAt`), or drop the client-side pre-filter and rely on the server.

### BUG-10 [LOW] — `EngagementProvider.trackActivity` is dead and would be rule-denied

**Files:** `lib/providers/engagement_provider.dart`, `firestore.rules`

`EngagementProvider.trackActivity` (→ `EngagementService.logActivity`) has **no callers** in `lib/` (verified by search). Were it used with any event type other than `resumeReviewed`/`points == 5`, the `activities` create rule would reject it (`allow create: if isOwner(userId) && eventType == 'resumeReviewed' && points == 5`), and `EngagementService.logActivity` swallows the error with a `debugPrint`. The only active client activity write is the `resumeReviewed`/5 one in `ResumeReviewProvider` — which is itself redundant with the server trigger (BUG-2).

**Fix:** delete `trackActivity` (and the client `logActivity` call in `ResumeReviewProvider`) so all activity/points flow through the server's `logUserActivity`.

### INT-1 [LOW] — Placement snapshot objects are unreachable via Storage rules

**Files:** `storage.rules`, `functions/placements.js`

`storage.rules` grants access via `match /resumes/{userId}/{fileName}` — a **single**-segment wildcard. The snapshot the apply flow writes lives at `resumes/{uid}/snapshots/app_{applicationId}.pdf` (two segments after `uid`), so it does **not** match and falls through to the deny-all. It happens to work today only because the apply flow stores a **signed URL** (`getSignedUrl({expires: "01-01-2035"})`) in the application doc and the UI opens that URL (signed URLs bypass Storage rules). So the snapshot is readable **only** through that long-lived URL; any code path that tries to read it by path (or if the URL is rotated/removed) gets `permission-denied`.

**Fix:** either add `match /resumes/{userId}/snapshots/{fileName}` with the same read rule, or keep the signed-URL design and document that snapshots are URL-only. (Signed URLs valid to 2035 are also a long-lived capability that should be reviewed — see §8.)

### TEST-1 [LOW] — Functions test coverage is thin

**File:** `functions/package.json`

```json
"test": "node --test test/quota.test.js test/schedulers.test.js"
```

Only the unified-quota and scheduler tests run (13 tests). `placements.js`, `ai/chat.js`, `ai/resumeReview.js`, `ai/deepAnalysis.js`, `careerCoach.js` and `triggers/index.js` have **no** tests — which is precisely why BUG-1 (the `createdAt`/`timestamp` mismatch) and BUG-3 (snapshot overwrite) went unnoticed: both are cheap to assert. Task §20 explicitly asks for placement/resume/AI-quota/Career-Coach trigger coverage.

**Fix:** add focused `node --test` files (shared fakes already exist in `functions/test/firestore_fake.js` / `setup.js`) for: retention deletion (BUG-1), duplicate-apply snapshot immutability (BUG-3), status transition state machine, and `logUserActivity` aggregate idempotency.

### BUG-11 [MEDIUM] — "Career match" cards are offered for roles the student did not choose

**File:** `functions/recommendations/engine.js` (`buildRoleRecommendations`, `isDeclaredRole`)

The student dashboard's "Recommended for You" section renders server-authored `type: 'role'` recommendations titled **"Career match: {role}"**. The v8.9.1 portfolio-first gate and the v9.1.1 "declared-role" de-dupe were meant to keep these relevant, but the de-dupe only suppressed the **exact** role the student declared:

```js
const declaredRoleIds = new Set(
  CAREER_ROLES.filter((role) => isDeclaredRole(role, u)).map((role) => role.id),
);
const matches = CAREER_ROLES
  .map((role) => matchRole(role, {...}))
  .filter((match) => match.score >= ROLE_MATCH_THRESHOLD)   // 20
  .filter((match) => !declaredRoleIds.has(match.roleId))    // ← only the declared role
  .sort((a, b) => b.score - a.score)
  .slice(0, 2);
```

So a student who has already told the app their goal — e.g. `careerInterest: "App Development"` (which claims `mobile_developer`) — still receives the **next-best non-declared** role as a "Career match" card. Reproduced against the engine with the user's own profile shape:

```
A declared "App Development" + web skills: roleCards: 0      ← after fix
```

Before the fix it emitted `Career match: Web Developer (26% role fit)` — a role the student never chose, at a weak score, contradicting the goal they explicitly declared. `isDeclaredRole` matches the declared phrase only when the phrase is a *superset* of the role keyword's tokens (`"web"` is not in `{"app","development"}`), which is why `web_developer` survived the de-dupe while `mobile_developer` was correctly hidden. This is product-noise: once a student has committed to a path, "here is a different career you barely match" is not a recommendation.

**Fix (shipped this pass):** when the student has declared **any** career interest that maps to a known role (`declaredRoleIds.size > 0`), `buildRoleRecommendations` returns `[]`. Role discovery cards are preserved for students who have **not** declared an interest, so the discovery use case still works. Verified: declared-goal profiles → 0 role cards; same skills with no declared goal → still 2 discovery cards (`Web Developer 53%`, `Software Developer 21%`). The client already tolerates an empty role list (the section simply shows its other types / empty state), so no client change is required — but the Dashboards "Recommended for You" empty state should be re-checked once this deploys.

**Deploy note:** this is a Cloud Functions change (`functions/recommendations/engine.js`) — it takes effect only after `firebase deploy --only functions` and the next recommendation refresh (`onResumeReviewCreatedRefreshMatches` / `refreshRecommendations`), since existing `recommendations/*` docs are already materialized. Consider a one-off re-refresh of active students, or filtering stale role cards client-side until they age out. The Dart mirror `test/career_role_matching_test.dart` tests scoring only (not the de-dupe), so it is unaffected — but it also means **no test guards the suppression** (add one: declared interest ⇒ zero role cards).

---

## 4. Firebase Rules, Functions & Indexes

### 4.1 Firestore rules — per-collection verdict

`firestore.rules` is `rules_version = '2'`. The recursive catch-all under `users/{userId}` (`match /{subcollection=**}`) is the defect behind SEC-1/SEC-2 and is analysed there; the table below records the effective state of every other path.

| Path | Declared | Effective | Notes |
|---|---|---|---|
| `users/{uid}` (doc) | `isOwner && canWriteRole` | owner (role **unchecked**) + teacher/alumni read | **SEC-1**: catch-all overrides `canWriteRole`. |
| `users/{uid}/notifications/*` | owner read/create/update/delete | owner | OK (system writes via Admin SDK). |
| `users/{uid}/ai_insights/*` | owner read; `write:false` | **owner write** | SEC-2. |
| `users/{uid}/ai_interactions/*` | owner read/create/delete; `update:false` | **owner update** | SEC-2 (append-only intent void). |
| `users/{uid}/recommendations{,_meta}/*` | owner read; `write:false` | **owner write** | SEC-2. |
| `users/{uid}/engagement_summary/*` | owner/teacher read; `write:false` | **owner write** | SEC-2; the client writes it (BUG-2). |
| `users/{uid}/activities/*` | owner read; create only `resumeReviewed`+5 pts; no update/delete | **any payload** | SEC-2: the MED-5 points guard is void. |
| `users/{uid}/resumeReviews/*` | owner read/create/update/delete; teacher read | owner | **Tamper risk — see below.** |
| `users/{uid}/career_coach/*` | owner read; `write:false` | **owner write** | SEC-2; AI + quota bypass. |
| `placements/*` | auth read; manager create/update/delete **with schema + `createdBy` binding** | managers (authored only) | Good (v9.1 SEC-1). |
| `placements/*/applications/*` | read owner/alumni/teacher; `create/update/delete:false` | client read-only | Good (v9.1 SEC-2). Mirror doc-id = `studentId`, so the owner branch is valid. |
| `applications/*` | read owner; all writes `false` | owner read only | Good (v9.1 SEC-2). |
| `notes/*` | auth read; teacher CRUD | as declared | OK. |
| `{path=**}/resumeReviews`, `{path=**}/recommendations` | teacher read | teacher | OK. |
| `{path=**}/applications` | teacher/alumni read; owner via `resource.data.userId` | as declared | Good (v9.1 SEC-5 — the old doc-id `isOwner` was always false). |
| `mentorship_requests/*` | participant read; student create; participant diff-limited update | as declared | OK. |
| `opportunities/*` | auth read; author write | OK. | |
| `public_profiles/*` | public read; author write | OK. | |
| `chats/*` → `messages/*` | participant read/write | see below | **Any participant may delete any message.** |
| `alumni_group_messages/*` | alumni read; sender-bound create/update/delete | OK. | |
| `user_ai_quotas`,`ai_usage`,`resume_usage`,`career_coach_usage`,`ai_analysis_usage`,`ai_rate_limits`,`ai_spam_check`,`ai_conversations`,`announcements`,`analytics_events` | owner read (where applicable); `write:false` | owner read | Good. |

**Two further rules observations (same root cause family as SEC-2 — “who owns each field”):**

- **`resumeReviews` is fully owner-writable.** A student can `create`/`update` their own `users/{uid}/resumeReviews/{id}` with a hand-written `atsScore`, `aiAnalysis`, `strengths`/`weaknesses`, etc. Teachers read these docs directly **and** roll them up via the `{path=**}/resumeReviews` collectionGroup, so a forged review pollutes the teacher analytics and the student’s own insights. Fix by making the server the writer of the AI/score fields (or shape-validating owner writes), exactly as for the SEC-2 subcollections.
- **Chat messages are deletable by any participant.** `match /messages/{messageId} { allow read, write: if <participant> }` grants `delete` to every chat participant, so one participant can delete another’s message — there is no `senderId == request.auth.uid` binding (unlike `alumni_group_messages`). Low impact, but an ownership/moderation gap.

### 4.2 Storage rules

`storage.rules` is `rules_version = '2'`. Access is granted via `match /resumes/{userId}/{fileName}` — a **single**-segment wildcard — plus teacher/alumni/owner read branches.

- **INT-1:** the immutable snapshot written by `logPlacementApplication` lives at `resumes/{uid}/snapshots/app_{applicationId}.pdf` (two segments after `uid`) and therefore **does not match** that rule; it falls through to the deny-all `match /{allPaths=**}`. It works today only because the apply flow stores a `getSignedUrl({expires:"01-01-2035"})` URL in the application doc and the UI opens that URL (signed URLs bypass rules). Any path-based read — or a rotated/removed URL — is `permission-denied`.
- A signed URL valid until **2035** is itself a long-lived bearer capability: anyone who obtains the URL can read the resume for a decade. Prefer short expiries plus on-demand signing by an authenticated teacher/alumni callable.

### 4.3 Cloud Functions inventory & contracts

`functions/index.js` is a thin re-exporter (v9.0 ARCH-2). Deployed surface:

- **Callables (9):** `generateCareerCoachAnalysis`, `askAI`, `reviewResume`, `generateResumeAnalysis`, `deleteAIHistory`, `refreshRecommendations`, `logPlacementView`, `logPlacementApplication`, `updateApplicationStatus`.
- **Triggers (6):** `onProfileUpdatedRefreshAI`, `onResumeReviewCreatedRefreshMatches`, `onOpportunityPostedNotifyStudents`, `onMentorshipRequestCreated`, `onMentorshipRequestResponseNotifyStudent`, `onChatMessageCreated`.
- **Scheduled (5):** `cleanupExpiredAIConversations` (retention — BUG-1), `autoExpireOpportunities` (60 min), `sendInactivityReminders` (daily 09:00), `recomputeEngagementScores` (daily 01:00; cursor-paginated 50 users/page), `compensateStaleAIQuotas` (daily 04:00; v9.2 3→1 consolidation). All `us-central1`, `timeZone: UTC`.

Observations:

- **Duplicate engagement write (feeds BUG-2):** `onResumeReviewCreatedRefreshMatches` calls `logUserActivity(userId, "resumeReviewed", 5, …)` **and** `ResumeReviewProvider.submitReview` writes its own 5-pt `activities` doc — two docs, one aggregate increment, two point-paths. Keep one.
- **BUG-4:** `updateApplicationStatus`, `logPlacementApplication` and `logPlacementView` set `maxInstances` but **no `timeoutSeconds`** (default 60 s). `logPlacementApplication` performs a Storage `copy` + `getSignedUrl` *before* opening the Firestore transaction — all on the default ceiling. Every other callable (`askAI`, `reviewResume`, `generateResumeAnalysis`, `refreshRecommendations`) sets an explicit timeout.
- **Placement pipeline is otherwise solid:** `updateApplicationStatus` verifies actor role, actor-authorship of the placement, a server-side transition state machine (`applied→[shortlisted,rejected]`; terminal `placed`/`rejected`), and per-actor rate limiting; `logPlacementApplication` validates placement existence/active/deadline inside the create transaction. BUG-3 and BUG-6 are the remaining gaps.

### 4.4 Indexes

`firestore.indexes.json` declares no `fieldOverrides` and **no `ai_interactions` entry**. Verified against the queries in the tree:

- **Covered:** `opportunities` (`isActive+applicationDeadline` for `autoExpireOpportunities`; `isActive+postedAt`, `company/jobType/location+isActive+postedAt`, `alumniId+postedAt`), `mentorship_requests` (`status+createdAt` asc/desc for the reminder sweep; `studentId/alumniId+createdAt`; `studentId+alumniId+status`), `chats` (`participantIds CONTAINS + lastMessageAt DESC`), `applications` (`userId+appliedAt`, COLLECTION scope, for the student feed), `placements` (`isActive+postedAt`, `company+isActive+postedAt`), `notifications` (`type+createdAt` asc/desc), `notes` (`uploadedBy+uploadedAt`).
- **Gap (ties to BUG-1):** the retention query is `collectionGroup("ai_interactions").where("createdAt","<",cutoff)`. A **collection-group** range query needs a collection-group-scoped single-field index; none is declared. The job therefore either returns empty (the field is never written — BUG-1’s root cause) or fails `FAILED_PRECONDITION`. Fixing BUG-1 requires the field-name change **and** this index.
- **Confirm-on-deploy:** `recomputeEngagementScores` runs `users.where("profileCompleted","==",true).orderBy(FieldPath.documentId())`. Equality + `__name__` ordering is usually served without a composite index, but verify against the deployed project.

### 4.5 Functions tests

`functions/package.json` → `"test": "node --test test/quota.test.js test/schedulers.test.js"` (13 tests). Covered: the unified-quota reserve/refund logic and the scheduler envelope. **Not covered:** `placements.js`, `ai/chat.js`, `ai/resumeReview.js`, `ai/deepAnalysis.js`, `careerCoach.js`, `triggers/index.js`. BUG-1 (retention) and BUG-3 (snapshot overwrite) are precisely the kind of pure-logic defect a small `node --test` file would catch — and the fakes already exist (`test/firestore_fake.js`, `test/setup.js`). This is **TEST-1**.
---

## 5. Routing & Integration

### 5.1 Route registry

All route names are constants in `lib/constants/routes.dart`; the router is `MaterialApp` in `lib/main.dart` (`home: AuthGuard`, a `routes:` map plus an `onGenerateRoute` for argument-carrying routes). Registration is complete — every constant has a builder, and `flutter analyze` is clean, so no unresolved route names.

- **Dynamic (`onGenerateRoute`):** `resumeReviewDetailRoute`, `chatRoute`/`chatDetailRoute`, `completeMentorshipRoute`. Each falls back to a safe list view when its argument is missing.
- **Guarded (`routes:` wrappers):** `placementApplicantsRoute` → `_guardPlacementApplicants` (teacher/alumni), `alumniGroupChatRoute` → `_guardAlumniGroupChat` (alumni), the six portfolio editing routes → `_guardStudentPortfolio` (non-alumni), `profileRoute` → `_RoleAwareProfileView` (teacher vs student/alumni).
- **Argument via `ModalRoute`:** `placements_list_view.dart` navigates to `placementApplicantsRoute` with a `String` `placementId`; `PlacementApplicantsView` reads it with `ModalRoute.of(context)?.settings.arguments` (not a constructor arg), so the plain `routes:` builder is correct. Same pattern for `portfolioReadOnlyRoute`.

### 5.2 Auth & role dispatch

`AuthGuard` (v6.3/V6.6/V7.1) drives the tree: unauthenticated → `LoginView`; authenticated-but-unverified → `VerifyEmailView`; verified but `!isProfileCompleted` → `ProfileSetupView`; otherwise `_buildDashboardForRole` (alumni / teacher / student). Providers are (re)initialised in `addPostFrameCallback`s guarded by `_providerInitScheduled` / `_profileSynced` / `_ecosystemInitScheduled` (v9.2 P1 — each runs at most once per session, reset on logout/re-login), and every provider is reset on logout. The only state gap is BUG-9 (one-shot profile sync).

### 5.3 Integration completeness (is the new code reachable?)

| Feature | Entry point(s) | Verdict |
|---|---|---|
| Placement list | student dashboard (×3), alumni dashboard (quick action), teacher dashboard sections, activity feed | **Reachable** |
| Applicant review (`placementApplicantsRoute`) | `placements_list_view.dart` (managers) | **Reachable**; role-gated (v9.1 SEC-6) |
| Portfolio read-only (from applicants) | `PlacementApplicantsView._openPortfolio` | **Reachable** |
| Alumni Community (group chat) | alumni dashboard → guarded route | **Reachable**; alumni-only |
| AI Career Coach | `careerCoachRoute` (dashboard + coach screen) | **Reachable** |
| All 9 callables / 6 triggers / 5 schedulers | registered in `functions/index.js` | **Wired** |

**Resolved v9.1 carry-overs confirmed in the tree:**
- **INT-1 (v9.1, “alumni dashboard has no placements entry”):** now resolved — `alumni_dashboard_view.dart:602` adds a fifth quick action to `placementsListRoute`.
- **BUG-D (fake dashboard metric):** resolved — placement rate from `analytics.pipelinePlaced` (`teacher_dashboard_sections.dart` 234/438/696).
- **BUG-F (stale applicant counts):** resolved — `PlacementApplicantsView._updateStatus` calls `loadApplicantCounts()` after a status change.
- **BUG-G (dead text-resume button):** resolved — `isTextResume` opens a text dialog instead of `launchUrl`.
- **SEC-6 (unguarded applicants route):** resolved — `_guardPlacementApplicants`.

### 5.4 Remaining integration gaps

- **INT-1 (this report, storage):** the placement snapshot path is not covered by `storage.rules`; the app depends on the 2035 signed URL. Integration works by accident, not by rule (see §4.2).
- **SEC-2 integration coupling:** because the *client* legitimately writes `engagement_summary` and `recommendations`, tightening the catch-all (SEC-1 fix) without moving those writes server-side (BUG-2 fix) will break the app. These must ship together — this is the one non-local fix in the report.
- **`notesRoute`** maps to `StudentDashboardView` (legacy compat shim); it is intentional but misleading — worth deleting once nothing links to it.

---

## 6. Edge Cases & Boundary Problems

- **Duplicate apply (BUG-3):** the immutable snapshot is re-copied on a repeat `logPlacementApplication` call because the copy precedes the idempotency check. Two rapid taps on Apply can also race two copies before either transaction commits.
- **Unguarded body (BUG-7):** `generateResumeAnalysis` throws `TypeError` on an empty payload (→ `internal`); every sibling callable null-guards.
- **Canonical/mirror drift (BUG-6):** a mirror re-created by `updateApplicationStatus` omits `resume`/`resumeStoragePath`/`appliedAt`/`resumeVersion`/`atsScoreAtApplication`, so the mirror and canonical doc are no longer equivalent, and the applicants UI (which reads the mirror) shows a resume-less applicant.
- **Legacy status default:** `updateApplicationStatus` reads `canonicalData.status || "applied"`, so any legacy application doc without a `status` starts from `applied` — correct, but it means a doc that is *actually* terminal but missing `status` could be advanced. Low risk (all new docs set `status`).
- **Snapshot copy is non-fatal:** if the Storage copy fails, `logPlacementApplication` keeps the original `resumeStoragePath`/`resumeUrl` and still creates the application — so the teacher may later open a resume that has since been re-uploaded (the immutability guarantee silently degrades). Consider failing the apply, or flagging the application as “no snapshot”.
- **`atsScoreAtApplication` coercion:** non-numbers and out-of-range values are nulled; non-integers are rounded. Good, but the clamp range (0–100) is duplicated from `deepAnalysis.js` — a shared constant would prevent drift.
- **Text-resume detection:** `Application.isTextResume` (client heuristic) must stay in sync with how `logPlacementApplication` stores text vs URL vs storage path; a mismatched heuristic re-introduces BUG-G (dead link button).
- **Timezone streak (BUG-2):** client local-day bucketing vs server UTC day keys disagree for ~5.5 h/day in IST; the streak can differ by one and the badge progress wobbles.
- **Applicants N+1:** `PlacementApplicantsView._load` sequentially `await`s `ProfileService.getProfile(app.userId)` per applicant — a placement with 200 applicants issues 200 serial reads. `Future.wait` (bounded) would remove the serial latency.
- **No-placement guard:** `PlacementApplicantsView` shows a safe “No placement selected.” error when the argument is absent — good.
- **Notification failure is non-fatal:** `updateApplicationStatus` logs and continues if the student notification write fails — correct, but the student silently misses the status update; a retry/queue would be more robust.
- **`activities` rule fields:** the MED-5 create rule requires `userId == request.auth.uid` *and* `eventType == 'resumeReviewed'` *and* `points == 5`. If the client `logActivity` ever omits `userId`, the write is denied and swallowed — a latent fragility once SEC-2 is fixed (the catch-all no longer masks it).
- **Alumni group-chat stream:** activated only after the role resolves (`setRoleForStream`), so non-alumni never subscribe — this correctly avoids a guaranteed `permission-denied` stream per session (v8.8.2 B).
- **One-shot profile sync (BUG-9):** in-session profile edits leave `PlacementsProvider`’s eligibility snapshot stale.
---

## 7. Performance, Scale & Cost

The V9.2 workstream removed a large amount of duplicate work (the `TeacherAnalyticsService` load-scoped cache and the scheduler consolidation are real wins), but several **unbounded** reads and one remaining N+1 survive. Numbers below are per load cycle unless stated.

### 7.1 Teacher analytics load (PERF-1) — the dominant cost

`TeacherAnalyticsProvider.loadAnalytics()` drives `TeacherAnalyticsService`, which for a roster of **N** students issues:

| Read | Volume | Bounded? | Note |
|---|---|---|---|
| `users.where(role=='student').get()` (`_studentDocs`) | **N** docs | ❌ unbounded | Shared once per cycle (was 4× before v9.2). Entire roster, no `limit`. |
| `collectionGroup('resumeReviews').get()` (`_resumeReviewDocs`) | **R** docs (all reviews, all students) | ❌ **deliberately unbounded** | Comment says capping would under-count; correctness > reads. |
| `collectionGroup('applications').get()` (`_applicationDocs`) | **A** docs | ❌ unbounded | Pipeline counts. |
| **Per-student** `users/{uid}/engagement_summary/summary` `get()` (`getEngagementAggregates`) | **N** reads | ❌ | **N+1**: one dedicated document read **per student**, in a serial `for` loop. This is the N+1 the v9.2 notes did **not** remove — they removed the *latest-review* and *review-count* N+1s (now derived in memory from the shared review scan), but the engagement aggregate still fans out per student. |
| `collectionGroup('recommendations').limit(800).get()` (`getRecommendationAggregates`) | ≤800 docs | ✅ (800) | Hard cap, but reads up to 800 docs/load. |
| `users.where(role=='alumni').count()` | 1 aggregation | ✅ | Cheap; cached per cycle. |

So a single teacher dashboard load ≈ **N (roster) + R (reviews) + A (applications) + N (engagement) + min(800, recs)** document reads. Concretely, for 500 students / 1 500 reviews / 800 applications / 500 recommendation docs that is **~3 800 reads per load** — and `loadAnalytics` is not throttled, so a teacher tapping Refresh repeatedly multiplies it. On a department-wide basis (every teacher loading concurrently) this is the app's largest Firestore cost line.

**Fixes:**
- **Kill the engagement N+1.** Either (a) `getAll()` the `engagement_summary/summary` refs in one batched round trip (chunked to ≤500), or (b) maintain a teacher-scoped materialized aggregate (e.g. written by `recomputeEngagementScores` into a single `analytics/teacher` doc) and read that one doc. Option (b) also removes the need to read the full roster for engagement.
- **Bound the scans.** `_resumeReviewDocs` / `_applicationDocs` should be paginated + date-windowed (the trend query already applies a `pastMonths` window client-side — push it server-side as a `where('createdAt','>=',start)` so the scan ships fewer docs). The roster scan should page.
- Cache/aggregate: the whole screen is a candidate for a scheduled `analytics/teacher_snapshot` document so the read is O(1) per load instead of O(N + R + A + 800).

### 7.2 Engagement dual-writer on every login (BUG-2)

Each login runs `EngagementService.recomputeEngagement`, which reads up to the newest **200 `activities`** docs and writes `engagement_summary/summary`. For a cohort that logs in daily this is **200 reads + 1 write per user per day**, all to produce a value the server already maintains (and then clobbers it). Removing the client recompute (the BUG-2 fix) eliminates both the reads and the write.

### 7.3 Applicant review N+1

`PlacementApplicantsView._load` `await`s `ProfileService.getProfile(app.userId)` **sequentially** per applicant. A placement with 200 applicants = **200 serial round-trips** (plus the applicant list). Wrap in a bounded `Future.wait` (chunks of ~20–30) to collapse serial latency into a few concurrent waves; better, have `logPlacementApplication` persist the denormalized applicant snapshot the UI already needs so the list is one read.

### 7.4 Unbounded collectionGroup scans elsewhere

`getApplicationPipelineCounts` (student) and the pipeline mirror read are unbounded collectionGroup scans of `applications`. Combined with §7.1 the `applications` collectionGroup is scanned twice per teacher load path and once per student dashboard. Consider a maintained counter (`analytics/pipeline`) updated by `updateApplicationStatus`, or a scheduled aggregate.

### 7.5 AI chat growth (BUG-1) compounds cost

Because `cleanupExpiredAIConversations` deletes nothing (BUG-1), every student's `ai_interactions` grows forever. Each `askAI` call reads the recent transcript for context, so an unbounded history slowly raises the per-call read cost and the storage bill, and makes the (intended) 90-day retention unenforceable. Fixing the field name + adding the collection-group index removes a permanent, compounding cost.

### 7.6 What is already right

- **Schedulers are paginated.** `recomputeEngagementScores` walks `users.where(profileCompleted==true)` in cursor pages of 50; `sendInactivityReminders` / `autoExpireOpportunities` use bounded `where` + `limit`. No full-collection scheduled scan.
- **Load-scoped cache (v9.2 P1)** genuinely removes the four roster scans / three review scans / per-student count reads of the pre-V9.2 code — the remaining cost is the unbounded *volume*, not duplication.
- **`LoadDedupe`** collapses concurrent identical loads client-side (subject to BUG-8).
- **Recommendations** are materialized server-side and read once; the client does not recompute engine output.
---

## 8. Security: App Check, Secrets, Input Validation

### 8.1 App Check

`lib/main.dart` activates App Check before `runApp`:

- **Android release** → `AndroidPlayIntegrityProvider`; **iOS/macOS release** → `AppleDeviceCheckProvider` (or App Attest).
- **Debug/profile** → `AndroidDebugProvider` / `AppleDebugProvider` (correct — release attestation is unavailable in a debug build).
- **Web** → `ReCaptchaV3Provider` with `webSiteKey` injected at build time via `--dart-define`.

This is the **right** client setup. The caveat that matters: **App Check only protects anything once it is _enforced_ in the Firebase console** for Firestore, Cloud Storage, and Cloud Functions (App Check → APIs → Enforce). The code cannot self-enforce. Until enforcement is switched on, a scripted client (or the DevTools exploit in SEC-1) talks to the backend with no attestation. Also note App Check is **unsupported on Windows/Linux/desktop** targets, so desktop builds send no token — if those are ever shipped, they need an explicit decision (block, or accept un-attested).

### 8.2 Secrets & config

- The AI provider key lives **only** in Cloud Functions (`functions/` reads it from the environment / secret manager); it is never shipped to the client. Good.
- `webSiteKey` (App Check) is passed via `--dart-define`, not hardcoded. Good.
- `lib/firebase_options.dart` and `android/app/google-services.json` are committed — standard for Flutter and **not** secret material (the Firebase API key is a public project identifier). What matters is that the key is **restricted in Google Cloud** (HTTP-referrer / app restrictions) so it cannot be abused outside the app; verify that restriction exists in the project console.
- No service-account JSON, private key, or Admin SDK credential is present in `lib/` or the repo root (checked) — the Admin SDK is used only inside `functions/`.

### 8.3 Rules-level exposure (see §2)

- **SEC-1 (CRITICAL)** and **SEC-2 (HIGH)** are the dominant security findings — both are Firestore-rules defects exploitable by any authenticated user. SEC-1 turns a normal account into a teacher/alumni (full PII + analytics + applications read). §2 has the exploit and fixes.
- **`resumeReviews` owner-write tamper** and **chat-message delete by any participant** are the two smaller rules issues (§4.1).
- **INT-1 / long-lived signed URL:** the placement snapshot is served via a signed URL valid to **2035**. That URL is a bearer capability — whoever holds it (logs, analytics, a shared device, a screenshot of the network tab) can fetch the resume for a decade, and it bypasses Storage rules entirely. Prefer short-lived URLs minted on demand by an authenticated teacher/alumni callable, or a path covered by Storage rules.

### 8.4 Rate limiting & quotas

- **AI quotas** are enforced server-side in the unified `user_ai_quotas` store (monthly per feature) with a `compensateStaleAIQuotas` reconciliation job — solid. The **daily** AI-chat limit is **soft** (advisory; it does not hard-block), which the code documents; acceptable, but note it is not a security control.
- **Status updates** are rate-limited per actor in `updateApplicationStatus`. Good.
- **Placement apply** validates existence/active/deadline inside the create transaction. Good.
- **Client-side-only throttles** (e.g. resume retry throttle) are UX, not security — the server must be (and is) the authority.

### 8.5 Input validation & authorization inside callables

The callables are the trust boundary and are generally well-guarded:

- `generateResumeAnalysis` / `reviewResume` verify the `reviewId` **belongs to the caller** (`users/{uid}/resumeReviews/{reviewId}`) before analyzing — no IDOR. (BUG-7 is only about an unguarded empty body, not authorization.)
- `sanitizeAIInput` + length caps bound the AI prompt surface (defense against prompt-injection and cost abuse).
- `logPlacementApplication` checks the `resumeStoragePath` is under the caller's own prefix before snapshotting.
- `updateApplicationStatus` checks actor role, actor-authorship, and a transition state machine.
- `isValidPlacementData` + `createdBy` binding gate placement writes.

The gaps are the ones already listed: **BUG-4** (missing `timeoutSeconds`), **BUG-3/BUG-6** (snapshot/mirror correctness), and the rules defects (SEC-1/SEC-2).

### 8.6 Summary

The **application-layer** security (callable guards, quotas, validation, App Check wiring, secret handling) is in good shape. The **data-layer** security (Firestore/Storage rules) is where the serious defects are, and the single most important action in this entire report is to fix the `users/{userId}` catch-all (SEC-1) — one `role` write is currently a full privilege-escalation primitive.
---

## 9. Improvements (priority-ordered)

Ordered by risk-reduction-per-hour. P0 is a security emergency; P1–P2 are correctness/cost; P3 is hygiene.

### P0 — Security (ship immediately)

**1. Fix SEC-1: remove the `users/{userId}` catch-all.** The one-line change that closes the privilege-escalation primitive:

```rules
match /users/{userId} {
  // The user document itself — `canWriteRole` now actually governs it.
  allow read: if isOwner(userId) || isTeacher() || isAlumni();
  allow write: if isOwner(userId) && canWriteRole(userId);

  // Enumerate the genuinely client-writable subcollections EXPLICITLY…
  match /notifications/{notificationId} { allow read, write: if isOwner(userId); }
  match /resumeReviews/{reviewId}       { allow read, write: if isOwner(userId); allow read: if isTeacher(); }
  match /activities/{activityId}        { allow read: if isOwner(userId); allow create: if isOwner(userId) && request.resource.data.eventType == 'resumeReviewed' && request.resource.data.points == 5; }
  // …and grant NOTHING else to the client (ai_insights, career_coach,
  // ai_interactions, recommendations, recommendations_meta,
  // engagement_summary stay server-only).

  // DELETE:  match /{subcollection=**} { allow read, write: if isOwner(userId); }
}
```

Then add the rules-unit-test (or a documented manual check) that `update({role:'teacher'})` is **denied**.

**2. Fix SEC-2 by making the rules state the real writer per collection.** Once the catch-all is gone, decide explicitly:
- `engagement_summary` & `recommendations`: if the client must keep writing them (today it does), grant `isOwner` **and** write a shape validator; if not, keep `write:false` and do step 3.
- `career_coach`, `ai_insights`, `recommendations_meta`: server-only (no client grant) — this restores the AI+quota contract the rules claim.

**3. Fix BUG-2: make the server the sole engagement writer.** Remove `EngagementService.recomputeEngagement` from `EngagementProvider.initWithUser`, have the client **read** `engagementSummaryStream`, and drop the redundant client `resumeReviewed` activity write. This is the change that lets the SEC-2 rules stay strict — SEC-2 and BUG-2 must ship together.

### P1 — High-severity correctness

**4. Fix BUG-1: retention field name + index.** `functions/ai/chatDelete.js`: query `ai_interactions` by `timestamp` (what `askAI` writes), drop or transition-window the dead `ai_conversations` branch, and add a **collection-group** single-field index for `timestamp` to `firestore.indexes.json`. Add the unit test.

**5. Deploy + test BUG-11 (already coded).** `firebase deploy --only functions`, then re-refresh active students' recommendations (or client-filter stale role cards). Add a test asserting a declared interest yields zero role cards.

### P2 — Medium correctness, integrity & cost

**6. Fix BUG-3: gate the snapshot copy behind the idempotency check** — move it inside the transaction path (or `exists()`-short-circuit), so a duplicate apply never overwrites the submitted resume.
**7. Fix BUG-4: add `timeoutSeconds`** to `logPlacementApplication` (120) and `updateApplicationStatus` (60).
**8. Fix BUG-5: source the teacher "Resume Review" metrics from `TeacherAnalyticsProvider`**, not the teacher's own `ResumeReviewProvider.history` (delete the duplicate section).
**9. Fix BUG-6: copy `resume`/`resumeStoragePath`/`appliedAt` into the re-created mirror** and pass the already-read `placementData` to the notifier (drop the redundant read).
**10. Fix PERF-1 (cost):** batch the per-student `engagement_summary` reads with a chunked `getAll()`, or (better) publish a single `analytics/teacher_snapshot` from `recomputeEngagementScores` and read one document per load. Bound the roster/resume-review/application scans with pagination + date windows.
**11. Fix the `resumeReviews` field-ownership tamper (§4.1):** make the server the writer of `atsScore`/`aiAnalysis` (or shape-validate owner writes so a student cannot forge their own score into the teacher analytics).

### P3 — Low-severity hygiene

**12.** BUG-7: `request.data || {}` in `deepAnalysis.js`.
**13.** BUG-8: `.catchError((_) {})` (or store the future) in `LoadDedupe.begin`.
**14.** BUG-9: re-sync `PlacementsProvider.updateUserProfile` on profile change, or drop the client pre-filter.
**15.** BUG-10: delete `EngagementProvider.trackActivity` (and the client `logActivity` call).
**16.** INT-1: add `match /resumes/{userId}/snapshots/{fileName}` to `storage.rules` **or** document the signed-URL-only design, and shorten the signed-URL expiry (2035 → minutes/hours, minted on demand).
**17.** Chat messages: bind `delete` to `resource.data.senderId == request.auth.uid` (parity with `alumni_group_messages`).
**18.** TEST-1: add the four `node --test` files (retention, snapshot immutability, status transitions, `logUserActivity` idempotency) — the fakes already exist.

### Architecture bets (bigger, do after P0–P2)

- **Materialize the teacher dashboard.** One scheduled `analytics/teacher_snapshot` doc turns a ~N+R+A+800-read load into a single read and removes the N+1 and the unbounded scans at once.
- **Bound every collectionGroup scan** (`resumeReviews`, `applications`, `recommendations`) with pagination + date windows; push `pastMonths` server-side.
- **One writer per document, everywhere.** SEC-2/BUG-2 are the same root cause; a short "who owns each collection" table (like §4.1) should live next to `firestore.rules` and be enforced by tests.
- **Retire the legacy quota/collection shims** (`ai_usage`, `resume_usage`, `career_coach_usage`, `ai_analysis_usage`, `ai_conversations`) once the unified store has run clean for a release, so retention/cost reasoning stays simple.

---

## 10. Carried-Over Open Items

**Resolved this cycle (confirmed in the tree — do not re-open):**

| Item | Where it came from | Status |
|---|---|---|
| BUG-D — fake dashboard metric (hard-coded placement rate) | v9.1 report | **Fixed** — `analytics.pipelinePlaced` (`teacher_dashboard_sections.dart` 234/438/696) |
| BUG-F — stale applicant counts after status change | v9.1 report | **Fixed** — `loadApplicantCounts()` re-run on status change |
| BUG-G — dead “view text resume” button | v9.1 report | **Fixed** — `isTextResume` opens the text dialog |
| SEC-6 — unguarded applicants route | v9.1 report | **Fixed** — `_guardPlacementApplicants` |
| INT-1 (v9.1) — no placements entry on alumni dashboard | v9.1 report | **Fixed** — quick action at `alumni_dashboard_view.dart:602` |
| v9.1 SEC-1…SEC-5, BUG-A/B/E/H | v9.1 report | **Resolved** |

**Still open (carried forward):**

- **App Check enforcement** must be switched on in the Firebase console for Firestore/Storage/Functions — the client code is correct but cannot self-enforce (§8.1).
- **Signed-URL expiry** for placement snapshots is 2035 — a decade-long bearer token (§4.2, §8.3).
- **Bounded reads / pagination** across teacher analytics and the pipeline scans (PERF-1, §7.4).
- **Legacy collection retirement** (the old per-feature quota stores and `ai_conversations`).
- **Functions test coverage** for placements/AI/triggers (TEST-1).
- **`notesRoute`** legacy shim → `StudentDashboardView` (§5.4).

---

## 11. Verdict & Version History

### Overall

The **V9.2 optimization workstream is well done** — its client-side wins (lazy tabs, `LoadDedupe`, listener lifecycle, scheduler consolidation 7→5, unified quota store) are real and internally consistent, and `flutter analyze` is clean. **But V9.2 changed no security rules, and the rules contain a CRITICAL, exploitable defect** (SEC-1) that lets any signed-in user self-elevate to teacher/alumni and read the entire user base's PII, every resume review, every engagement summary, and every application. A second rules defect (SEC-2) silently voids five `write:false` guards and the points/append-only contracts. Two HIGH functional bugs (BUG-1 retention, BUG-2 dual engagement writer) produce wrong/expanding data.

None of these is large. **Every finding in this report is a small, local fix.** The only non-local one is the SEC-2↔BUG-2 coupling (tightening the rule requires moving the engagement write server-side in the same change).

### Ship order (one line each)

1. **SEC-1** — delete the `users/{userId}` catch-all, enumerate the writable subcollections. *(emergency)*
2. **BUG-2 + SEC-2 together** — server becomes the sole engagement writer; rules state the real writer per collection.
3. **BUG-1** — retention field name + collection-group index.
4. **BUG-11** — deploy the shipped engine fix (+ re-refresh, + test).
5. **BUG-3 / BUG-4 / BUG-5 / BUG-6** — snapshot idempotency, timeouts, teacher-metric source, mirror fields.
6. **PERF-1** — batch/materialize the teacher analytics reads.
7. **BUG-7…BUG-10, INT-1, chat-delete, TEST-1** — hygiene.

### Severity tally

**1 CRITICAL · 3 HIGH · 6 MEDIUM · 7 LOW** (SEC-1; SEC-2, BUG-1, BUG-2; BUG-3, BUG-4, BUG-5, BUG-6, BUG-11, PERF-1; BUG-7, BUG-8, BUG-9, BUG-10, INT-1, TEST-1, chat-delete).

### Version history

| Version | Report | Highlights |
|---|---|---|
| V9.0 | `docs/v8_workspace_tracker.md` | Architecture pass: function re-export layout (ARCH-2), unified quota work begins. |
| V9.1 | prior `docs/confirmation.md` | Closed SEC-1…SEC-5 (v9.1), BUG-A/B/E/H; left BUG-D/F/G + SEC-6 + INT-1 open. |
| V9.2 | this report | Optimization workstream verified; **BUG-D/F/G, SEC-6, INT-1 confirmed fixed**. New: SEC-1, SEC-2, BUG-1, BUG-2, BUG-3, BUG-4, BUG-5, BUG-6, PERF-1, INT-1(storage), TEST-1, plus **BUG-11 (fixed in code this pass)**. |

*Method note:* rule semantics were verified against the Firebase documentation (*Structuring Cloud Firestore Security Rules*, “Version 2” recursive wildcards and “Overlapping match statements”), and the BUG-11 fix was executed and observed (`node` harness: declared-goal profile → 0 role cards; undeclared profile → 2 discovery cards). Where a claim depends on the deployed project rather than source (App Check enforcement, the `profileCompleted` index), it is marked “confirm-on-deploy” rather than asserted.
