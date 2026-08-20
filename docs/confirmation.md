# CampusConnect v9.1 — Final Comprehensive Audit Report

**Date:** 2026-08-20
**Version audited:** `9.1.0+97` (pubspec.yaml) · **Feature:** Teacher Applicant Review / Placement Pipeline
**Source report(s):** `project_info__30.md` + `project_info__31.md` (identical V9.1 Final Audit Report)
**Reference:** `project_info__29.md` (V9.1 spec), `docs/todo.md` (V9.1 checklist)
**Scope:** placement applications (canonical + mirror), applicant view, status pipeline, Cloud Functions (`placements.js`), `firestore.rules`, `firestore.indexes.json`, `storage.rules`, teacher dashboard integration, role-based access, routing.

> This report consolidates the V9.1 audit with the open (unmarked) items carried over from the v9.0 confirmation audit. All completed/marked tasks have been removed from the tracker; see [§8](#8-carried-over-open-items-v90-audit) for carried-over open items and [§10](#10-severity-matrix-combined) for the combined severity matrix.
>
> **Resolution status (2026-08-20):** the V9.1 audit-fix sprint is in progress — **9 items are RESOLVED** (SEC-1, SEC-2, SEC-3, SEC-4, SEC-5, BUG-A, BUG-B, BUG-E, BUG-H — see [§12](#12-resolution-status-2026-08-20) and `docs/todo.md` Phases 1–3) and **5 items remain OPEN** (BUG-D, BUG-F, BUG-G, SEC-6, INT-1 — `docs/todo.md` Phase 4). SEC-7/IMP-6 and IMP-8/9/11/12/15/16 remain carried over (see §8).

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Bugs & Logical Errors](#2-bugs--logical-errors)
3. [Security Findings](#3-security-findings)
4. [Firebase Rules, Functions & Indexes](#4-firebase-rules-functions--indexes)
5. [Routing & Integration Audit](#5-routing--integration-audit)
6. [Edge Cases & Boundary Problems](#6-edge-cases--boundary-problems)
7. [Performance / Scale Concerns](#7-performance--scale-concerns)
8. [Carried-Over Open Items (v9.0 audit)](#8-carried-over-open-items-v90-audit)
9. [Improvements (priority-ordered)](#9-improvements-priority-ordered)
10. [Severity Matrix (combined)](#10-severity-matrix-combined)
11. [Verdict](#11-verdict)

---

## 1. Executive Summary

V9.1 is an architecturally sound feature that mostly integrates well: the dual-mirror write is transactional, the collectionGroup dedupe is correct, the `updateApplicationStatus` callable is the right single-writer pattern, and the pipeline widget now shows real status-bucketed counts.

**However, the version has 3 HIGH-severity security holes and 2 HIGH-severity robustness bugs** that must be fixed before this can be considered production-safe:

| # | Severity | Area | Summary |
|---|----------|------|---------|
| SEC-1 | **HIGH** | Rules | Any teacher/alumni can create/update/**delete any placement doc** with arbitrary fields (no `createdBy` check, no schema validation) → global DoS + data destruction |
| SEC-2 | **HIGH** | Rules | Students can **forge application docs directly** (`applications/{uid}_{pid}` and mirror) with arbitrary `status`/`placementId`/`resumeUrl` — the v9.1 "update:false" threat model forgot **create** is open |
| SEC-3 | **HIGH** | Functions | `updateApplicationStatus` has **no placement-ownership check** (any teacher/alumni can mutate any placement's applicants) and **no transition state machine** (applied → placed in one jump; placed → rejected allowed) |
| SEC-4 | **HIGH** | Functions | `logPlacementApplication` never verifies the placement **exists, is active, or has a valid deadline** — closed/fake placements can be applied to, polluting teacher analytics |
| BUG-A | **HIGH** | Functions | `updateApplicationStatus` blindly `transaction.update`s the mirror doc — **throws if the mirror is missing** (legacy/partial writes) and rolls back the canonical update |
| BUG-B | **MEDIUM** | Service | `Application.fromFirestore` hard-casts `data['userId'] as String` — a mirror-only legacy doc (**no userId**) crashes the whole applicants query |
| BUG-D | **MEDIUM** | UI | `QuickStatistics` "Placement Rate" = activeDrives/students (can exceed 100%, is semantically wrong) while the real `pipelinePlaced` count sits unused — **stale v8.2 logic survived V9.1** |
| INT-1 | **MEDIUM** | Integration | Alumni are granted placement-manager powers (rules + callable + UI logic) but **the Alumni dashboard has no placements entry point** — feature half-wired for half its authors |

---

## 2. Bugs & Logical Errors

### BUG-A [HIGH] — `updateApplicationStatus` crashes when the mirror doc is missing
**File:** `functions/placements.js` (transaction inside `updateApplicationStatus`)

```js
const canonicalDoc = await transaction.get(canonicalRef);
if (!canonicalDoc.exists) { throw ... "Application not found."; }
...
transaction.update(canonicalRef, {status});
transaction.update(mirrorRef, {status});   // ← NOT guarded
```

The canonical doc is existence-checked; the mirror is **not**. `transaction.update` on a non-existent doc throws (`no document to update`), aborting the whole transaction — so the canonical status write also fails with an `internal` error. Scenarios where the mirror is missing:

- Canonical-only applications created before the mirror (V5) was introduced, or by a direct SDK write (see SEC-2).
- A mirror manually/accidentally deleted.

**Fix:** inside the transaction, `transaction.get(mirrorRef)`; if missing, `transaction.set(mirrorRef, {status, ...})` (or skip the mirror write — the canonical is the source of truth).

### BUG-B [MEDIUM] — Hard cast on `userId` crashes `getApplicationsForPlacement` for legacy mirror docs
**Files:** `lib/services/firestore/placements_service.dart` + `lib/models/application.dart`

The dedupe loop tolerantly reads `data['userId'] as String? ?? data['studentId'] as String?`, but then calls `Application.fromFirestore(doc)` whose constructor does **`data['userId'] as String`** — a null-unsafe cast. Any mirror doc that predates the `userId` field (or comes from a forged create that only sets `studentId`) throws a `TypeError` that propagates out of `getApplicationsForPlacement` → the **entire applicants screen fails**, not just one applicant.

**Fix:** `userId: data['userId'] as String? ?? data['studentId'] as String? ?? ''`.

### BUG-D [MEDIUM] — "Placement Rate" and "Active/Student" still use fake metrics
**File:** `lib/views/dashboards/widgets/teacher_dashboard_sections.dart` (`QuickStatistics`, `DepartmentOverview`)

```dart
final placedCount = placements.placements.where((p) => p.isActive).length;
final placementRate = totalStudents > 0 ? ((placedCount / totalStudents) * 100).round() : 0;
```

`placementRate` is **active-drives ÷ students** — it can exceed 100%, and it is not a placement rate at all. V9.1 wired *real* placed counts into the `PlacementPipeline` widget (`analytics.pipelinePlaced`) but **left `QuickStatistics` and `DepartmentOverview` on the old fake metric**. This is the clearest example of V9.1 not fully propagating through the whole app.

**Fix:** use `analytics.pipelinePlaced` for the rate numerator (and `DepartmentOverview` similarly), falling back gracefully.

### BUG-E [LOW] — `logPlacementApplication` destructures `request.data` before null-check
**File:** `functions/placements.js`

```js
const {placementId, resumeUrl, company} = request.data;   // throws on null
```

If a client calls with no payload, a raw `TypeError` is wrapped as `internal` rather than a friendly `invalid-argument`. Robustness nit — the Flutter provider always sends an object.

### BUG-F [LOW] — Stale applicant counts after status change
`PlacementApplicantsView` does not call `loadApplicantCounts()` after a successful `updateApplicationStatus`. The **count** itself is distinct-students (unchanged by status), so no visible number is wrong today — but the badge won't reflect a new application that arrives while the user sits on the applicants screen.

### BUG-G [LOW] — Text-paste applications produce a broken "Resume" button for teachers
When a student has no uploaded resume, the fallback path stores the **pasted text** in `resumeUrl`. `_openResume` then calls `launchUrl(Uri.parse(text))`, which throws `FormatException` → caught → "Could not open resume". Not a crash, but a dead-feeling button. Consider storing `appliedWithTextResume: true` and showing the text, or a "No PDF resume" label.

### BUG-H [LOW] — `Application` model doc comment is stale
`lib/models/application.dart` still documents `status: applied | shortlisted | rejected` — missing `interviewed | placed` added by V9.1.

---

## 3. Security Findings

### SEC-1 [HIGH] — Unrestricted placement write access (DoS + malformed-data crash vector)
**File:** `firestore.rules`

```
match /placements/{placementId} {
  allow read: if isAuthenticated();
  allow create, update, delete: if canManagePlacements();   // no ownership, no schema
}
```

`canManagePlacements()` = `role == teacher || role == alumni`. There is **no `createdBy == request.auth.uid` check** on `update`/`delete`, and **no validation of the written document**. Consequences:

- Any teacher/alumni can **delete every placement** (`collection('placements').doc(id).delete()` — no rule blocks it).
- Any teacher/alumni can **write a malformed placement** (e.g. `deadline` as a String, `postedAt` missing). `Placement.fromFirestore` does `(data['deadline'] as Timestamp).toDate()` — a hard cast — which **throws for every user rendering the placements list**. This is a one-line remote crash for the whole placements feature (client-side DoS).

**Fix:** `allow create: if canManagePlacements() && request.resource.data.createdBy == request.auth.uid;` `allow update: if canManagePlacements() && resource.data.createdBy == request.auth.uid;` `allow delete: if canManagePlacements() && resource.data.createdBy == request.auth.uid;` — plus a schema validation helper (deadline is Timestamp, required string fields non-empty, etc.). Also make `Placement.fromFirestore` null/tolerant.

### SEC-2 [HIGH] — Students can forge application documents (the v9.1 threat-model gap)
**File:** `firestore.rules`

```
match /applications/{applicationId} {
  allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
  ...
}
match /placements/{placementId}/applications/{appUserId} {
  allow create: if isOwner(appUserId);
  ...
}
```

The V9.1 design comment says *"application docs are locked client-side (`update: false` on both paths)"* — but **`create` is NOT locked on either path**, and `create` payloads are unvalidated. A student can directly write:

- `applications/{uid}_{placementId}` with **`status: 'placed'`**, arbitrary `placementId`, arbitrary `appliedAt`, arbitrary `resumeUrl` (e.g. a phishing URL).
- The mirror `placements/{placementId}/applications/{uid}` with the same.

Effects:

1. A student can **self-promote to 'placed' / 'shortlisted'** — appears in the teacher applicants list, pipeline counts, and any future placement reports.
2. A student can **forge applications to placements they never applied to** (pollutes `getApplicationsForPlacement`, `getApplicantCounts`, `getApplicationPipelineCounts`).
3. **Exploit chain:** a forged `resumeUrl` = `http://evil.example` → teacher taps "Resume" → `launchUrl` opens the attacker's site. Social-engineering/phishing vector.

**Fix:** set `allow create: if false;` on **both** application paths — `logPlacementApplication` uses the Admin SDK and bypasses rules, so clients never need direct create. This closes the whole hole and matches the stated single-writer contract.

### SEC-3 [HIGH] — `updateApplicationStatus`: no authorship check + no transition validation
**File:** `functions/placements.js`

```js
const actorRole = await _getUserRole(uid);
if (actorRole !== "teacher" && actorRole !== "alumni") { throw ... }
```

- **No check that the actor created the placement** (`placements/{placementId}.createdBy == uid`) or belongs to the same college/department. Any teacher in the system can shortlist/place/reject applicants on any placement.
- **No transition state machine.** `APPLICATION_STATUSES.includes(status)` accepts any of the four values, so a direct call can move `applied → placed` in one step, or `placed → rejected`, *or* `rejected → shortlisted`. The UI's `_StatusActions._availableActions` state machine is **client-side only** — the server is callable directly.
- No per-actor rate limit on the callable.

**Fix:** (a) verify the actor authored the placement (or is otherwise authorized); (b) enforce a transition map server-side — e.g. `applied→[shortlisted,rejected]`, `shortlisted→[interviewed,rejected]`, `interviewed→[placed,rejected]`, terminal states `[]`; (c) consider a per-min rate limit like the Career Coach pattern (`checkCareerCoachRateLimit`).

### SEC-4 [HIGH] — `logPlacementApplication` accepts applications to non-existent/closed placements
**File:** `functions/placements.js`

The function validates `placementId` is a non-empty string but **never reads the placement document** to check `exists`, `isActive == true`, or `deadline > now`. Combined with the open `create` rules, students can (via the callable) create application docs for arbitrary or expired placement IDs. Teachers' collectionGroup queries and pipeline counts then include garbage.

**Fix:** inside (or before) the transaction, `transaction.get(placementRef)`; reject when missing/inactive/past-deadline with `failed-precondition`/`invalid-argument`.

### SEC-5 [MEDIUM] — `isOwner(appId)` on the collectionGroup rule never matches canonical docs
**File:** `firestore.rules` (`match /{path=**}/applications/{appId} { allow read: if isTeacher() || isAlumni() || isOwner(appId); }`)

Canonical doc IDs are `{uid}_{placementId}`, so `appId != request.auth.uid` and `isOwner(appId)` is always false for them. The intended "owner can read own canonical doc via collectionGroup" path silently never grants. It does not break anything today (the global `applications/{applicationId}` rule covers owner reads of canonical docs; teachers/alumni read via role), but it is a latent correctness trap — e.g. a future `collectionGroup` query a student runs on their own docs would fail. Use `resource.data.userId == request.auth.uid` instead.

### SEC-6 [LOW] — `placementApplicantsRoute` is not role-gated
**File:** `lib/main.dart` — `placementApplicantsRoute: (context) => const PlacementApplicantsView()`.

Any signed-in user can deep-link `/placements/applicants`. Data itself is protected (the collectionGroup rule denies students), so the student sees a generic "Failed to load applicants" error instead of a proper denied state. **UX security smell** — follow the existing `_guardStudentPortfolio` / `_guardAlumniGroupChat` pattern.

### SEC-7 [LOW — pre-existing] — No App Check (still open)
`docs/todo.md` SEC-3 / IMP-6 remains open. Given SEC-1/SEC-2 above, App Check (Play Integrity / DeviceCheck / reCAPTCHA) would materially reduce the "modified client writes directly to Firestore" attack class.

---

## 4. Firebase Rules, Functions & Indexes

### Rules (beyond SEC-1/SEC-2)
- **`userRole()`/`canManagePlacements()` fail closed** when the actor's doc is missing — ✅ correct.
- **Activities rule** restricts client writes to `resumeReviewed`/`points == 5` — ✅ still correct.
- **Chat rules** — update limited to messaging metadata; create allows any authenticated user who includes their uid in `participantIds` (pre-existing spam vector, documented in earlier audits; unchanged in V9.1). ✅ no regression.
- **`public_profiles` create/update** — key/uid binding verified. ✅
- **Notifications** — owner-only create/update/delete; Admin SDK writes bypass rules so `updateApplicationStatus` notifications still work. ✅
- **Global `applications` vs the `/{path=**}/applications/{appId}` wildcard** — overlap is benign because Firestore ORs matching `allow` statements; owner reads of canonical docs succeed via the global rule. ✅ (note: see SEC-5).

### Functions
- **`updateApplicationStatus`** — transactional dual-mirror write ✅ (except BUG-A mirror-missing), notification + analytics after commit ✅, friendly HttpsErrors ✅, role gate ✅ (except SEC-3 authorship). **Missing:** placement ownership, transition state machine, per-actor rate limit.
- **`logPlacementApplication`** — transactional idempotent create ✅, resume snapshot copy with ownership/range validation (`resumes/{uid}/` prefix ✅, ATS range ✅), non-fatal snapshot failure ✅. **Missing:** placement-existence validation (SEC-4), `null`-data guard (BUG-E). Note: **no `maxInstances`** on this callable.
- **Registration/re-export in `index.js`** ✅ (`exports.updateApplicationStatus = placements.updateApplicationStatus`).
- **`logPlacementView`** — onCall (SEC-1 fix from v9.0) ✅; only validates `placementId` presence.

### Indexes
- `firestore.indexes.json` has the needed **collectionGroup `applications` (userId ASC, appliedAt DESC)** composite index — ✅ covers `getUserApplicationsOnce` (a root `applications` query is covered by the collectionGroup composite) and `getApplicationsForPlacement` single-field `placementId` filters use auto single-field indexes (**no missing composite for V9.1**).
- Unused/legacy index entries (e.g. `notifications type+createdAt` both directions, multiple `opportunities` combos) add deploy weight but are harmless.
- **Deployment dependency:** V9.1 requires deploying `firestore.indexes.json` + updated rules + the new function together; a partial deploy silently breaks `getUserApplicationsOnce` or the rules' alumni reads.

---

## 5. Routing & Integration Audit

| Check | Verdict |
|-------|---------|
| `placementApplicantsRoute` registered in `main.dart` routes map; `_placementId` reads `ModalRoute..settings.arguments` — works with `pushNamed(route, arguments: placementId)` | ✅ |
| `_ApplicantSummaryButton` → `Navigator.pushNamed(placementApplicantsRoute, arguments: placementId)` | ✅ |
| `portfolioReadOnlyRoute` from applicants view passes `userId` String — matches `PortfolioReadOnlyView` arg contract | ✅ |
| `onGenerateRoute` fallbacks (`chatRoute`/`chatDetailRoute`/`completeMentorshipRoute`) untouched by V9.1 | ✅ |
| Provider wiring in `main.dart` (`PlacementsProvider`) ✅; `AuthGuard` logout resets PlacementsProvider (safety net) ✅ | ✅ |
| **INT-1 [GAP]** Alumni granted `canManagePlacements` everywhere (rules, callable, `PlacementsListView` add-button) but **the Alumni dashboard (`AlumniDashboardView`) has no placements tab, quick action, or card** — alumni cannot reach the placements list/applicants view except by deep link. Teacher quick-action ("Placement Reports") and student dashboard are the only entries. **Half-integrated role.** | ⚠️ |
| **INT-2 [OK]** `PlacementsListView.build` triggers one-time `loadApplicantCounts` only when `canManagePlacements`; role is immutable so mid-session role change is impossible; widget state is recreated on re-login. | ✅ |
| **INT-3 [OK]** Teacher dashboard `PlacementPipeline` shows real status counts via `pipelineShortlisted/Interviewed/Placed` | ✅ |
| **INT-4 [BUG]** `QuickStatistics`/`DepartmentOverview` still use drives÷students (BUG-D) | ⚠️ |
| INT-5 [NOTE] `docs/todo.md` V9.1 checklist was all `- [ ]` while pubspec is `9.1.0+97` — checklist/version drift; corrected in this consolidation. | ⚠️ |
| INT-6 [NOTE] Notifications from `updateApplicationStatus` use the `statusChange` shape (`data: {placementId, company, role, status}`) matching `NotificationsService.notifyStatusChange`/`AppNotification.statusChange` — render path consistent. | ✅ (verify 1 line) |

---

## 6. Edge Cases & Boundary Problems

| Case | Assessment |
|------|------------|
| Mirror doc missing in `updateApplicationStatus` | **BUG-A** — transaction aborts. |
| Legacy mirror doc without `userId` | **BUG-B** — hard cast crash. |
| Application to a closed/expired/non-existent placement | SEC-4 — no server check; UI hides the button but the callable is open. |
| Forged `status` value (e.g. `"hacked"`) | Renders as "Applied" chip; not counted in shortlisted/interviewed/placed, but **counts in `appliedStudents`** (`studentStatuses.length`) — pollution persists. |
| 2 (two) status values on one student across placements | Correctly bucketed at the highest stage (`contains('placed')` → placed+interviewed+shortlisted). ✅ |
| Rejected-only student | Counts in `appliedStudents` — semantically correct (they did apply). ✅ |
| Multiple children apply with same uid to same placement | Dedupe by `userId` prefers canonical (`resumeUrl`) — ✅ matches test `application_applicants_test.dart`. |
| `getApplicantCounts` with >10 placements | Batched `whereIn` chunks of 10 — ✅. |
| Teacher taps "Resume" on text-pasted application | Broken (BUG-G). |
| Counts load failure | `loadApplicantCounts` non-fatal; cards show 0 applied — graceful. ✅ |
| Empty applicants list | `EmptyState` "No applicants yet" — ✅. |
| No ATS score / no resume version | Chips omitted — ✅. |
| `getApplicationPipelineCounts` collectionGroup failure | Degrades to all-zero pipeline silently; dashboard copy says "Applications collection is empty" — misleading on permission/index failure (minor). |

---

## 7. Performance / Scale Concerns

- **`getApplicationPipelineCounts`** does an **unbounded `collectionGroup('applications').get()`** on every teacher analytics load — O(all applications ever, both mirrors).
- **`getResumeReviewStats` / `getSkillGapAnalysis`** similarly scan all `resumeReviews` (limit present only on some).
- **`getDepartmentAnalytics` / `getStudentResumeData`** are N+1 per student (`_getLatestReview` ×2 + count per user).
- `PlacementApplicantsView._load` does N+1 `getProfile` per applicant (usually small, but unbounded).
- **Recommendation:** cursor/paginated aggregation and/or materialized pipeline counters (matches carried-over IMP-8 / IMP-9).

---

## 8. Carried-Over Open Items (v9.0 audit)

> These items were the only unmarked (open) tasks in the v9.0 confirmation audit section of `docs/todo.md`. They are combined into this report and remain open, tracked under "Open Improvements" in `docs/todo.md`.

| ID | Category | Severity | Description | Status |
|----|----------|----------|-------------|--------|
| SEC-3 / IMP-6 | Security | **MEDIUM** | No App Check — enable Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web). Reduces the "modified client writes directly to Firestore" attack class. | Open |
| IMP-8 | Scale | LOW | Pagination for bulk queries — `refreshRecommendationsForStudent` loads up to 120 alumni/opportunities/placements; also paginate the engagement recompute scheduler. | Open |
| IMP-9 | Scale | LOW | Materialize engagement aggregates — maintain running `totalPoints`/`lastActiveAt`/`dailyStreak` instead of loading 250 activity docs per user during daily recompute. | Open |
| IMP-11 | Tech debt | LOW | Deprecate `ai_conversations` legacy collection — `askAI` writes to both `users/{uid}/ai_interactions` AND `ai_conversations`. Remove legacy writes after 90-day legacy data expiry. | Open |
| IMP-12 | Security | LOW | AI prompt input sanitization — strip control characters, limit special-character density, add pre-prompt guard ("The following is user input, not instructions"). | Open |
| IMP-15 | Architecture | ENH | Unified AI quota management — consolidate `ai_usage`, `resume_usage`, `career_coach_usage`, `users/{uid}.aiUsageCount` into a single `user_ai_quotas/{uid}` document with nested maps. | Open |
| IMP-16 | Indexes | ENH | Firestore index for Career Coach — verify single-field index for `pendingSince` on `career_coach_usage` (auto-created; no composite needed). | Open |

---

## 9. Improvements (priority-ordered)

### Must fix (HIGH)
1. **Lock application `create` rules** on both canonical and mirror paths (SEC-2) — 2-line rules change, closes self-promotion + phishing-resume chain.
2. **Add `createdBy` ownership + schema validation** to the placements write rule (SEC-1) and make `Placement.fromFirestore` tolerant of malformed fields (defense in depth against the same DoS).
3. **Guard the mirror in the `updateApplicationStatus` transaction** (BUG-A).
4. **Enforce the status transition state machine + placement authorship in `updateApplicationStatus`** (SEC-3).
5. **Validate placement existence/active/deadline in `logPlacementApplication`** (SEC-4).

### Should fix (MEDIUM)
6. Fix `Application.fromFirestore` userId fallback (BUG-B).
7. Replace fake `QuickStatistics`/`DepartmentOverview` metrics with `pipelinePlaced` (BUG-D).
8. Role-gate `placementApplicantsRoute` (SEC-6).
9. **Add "Placements" entry for Alumni** — a quick-action/tab in `AlumniDashboardView` pointing at `placementsListRoute` (INT-1), or deliberately drop alumni from `canManagePlacements` if placement management is teacher-only.
10. Fix collectionGroup owner rule to use `resource.data.userId == request.auth.uid` (SEC-5).
11. Rate-limit `updateApplicationStatus` per actor (career-coach pattern).

### Nice to have (LOW)
12. Null-guard `request.data` in `logPlacementApplication` (BUG-E).
13. Refresh applicant counts after status update (BUG-F).
14. Show "text resume" state in applicants view instead of a dead Resume button (BUG-G).
15. Fix stale comments (`Application` status doc, `pipelineTotalPlacements` dead getter, `_pipelineStep` N/A branch) (BUG-H).
16. Implement App Check (SEC-7 / carried-over IMP-6).
17. Paginate/aggregate the teacher-analytics collectionGroup scans (carried-over IMP-8/9).

---

## 10. Severity Matrix (combined)

> Status updated 2026-08-20 — the V9.1 audit-fix sprint has RESOLVED the first 9 items (Phases 1–3, see [§12](#12-resolution-status-2026-08-20)); the rest remain OPEN. V9.1 findings are targeted in the `docs/todo.md` "v9.1 — Audit Fixes" section; carried-over items are in the "Open Improvements" section.

| ID | Category | Severity | Description | Status |
|----|----------|----------|-------------|--------|
| SEC-1 | Security | **HIGH** | Unrestricted placement write access (no createdBy, no schema) | ✅ **RESOLVED** |
| SEC-2 | Security | **HIGH** | Students can forge application docs (create open on both paths) | ✅ **RESOLVED** |
| SEC-3 | Security | **HIGH** | No placement authorship + no transition state machine in updateApplicationStatus | ✅ **RESOLVED** |
| SEC-4 | Security | **HIGH** | Applications accepted for non-existent/closed/exceeded-deadline placements | ✅ **RESOLVED** |
| BUG-A | Bug | **HIGH** | Mirror-missing crash rolls back canonical update | ✅ **RESOLVED** |
| BUG-B | Bug | MEDIUM | Hard cast on userId crashes whole applicants query | ✅ **RESOLVED** |
| BUG-D | Bug | MEDIUM | Fake Placement Rate / Active-per-Student metrics on teacher dashboard | ⏳ Open (Phase 4) |
| SEC-5 | Security | MEDIUM | isOwner(appId) never matches canonical docs | ✅ **RESOLVED** |
| SEC-6 | Security | LOW | placementApplicantsRoute not role-gated | ⏳ Open (Phase 4) |
| SEC-7 | Security | LOW | No App Check (pre-existing) | ⏳ Open (IMP-6) |
| INT-1 | Integration | MEDIUM | Alumni placements entry point missing | ⏳ Open (Phase 4) |
| BUG-E | Bug | LOW | logPlacementApplication null-data guard | ✅ **RESOLVED** |
| BUG-F | Bug | LOW | Stale applicant counts after status change | ⏳ Open (Phase 4) |
| BUG-G | Bug | LOW | Broken "Resume" button for text-paste applications | ⏳ Open (Phase 4) |
| BUG-H | Bug | LOW | Stale Application model doc comment | ✅ **RESOLVED** |
| IMP-6 / SEC-3 (v9.0) | Security | MEDIUM | App Check (Play Integrity / DeviceCheck / reCAPTCHA) | Carried over |
| IMP-8 | Scale | LOW | Pagination for bulk queries | Carried over |
| IMP-9 | Scale | LOW | Materialize engagement aggregates | Carried over |
| IMP-11 | Tech debt | LOW | Deprecate ai_conversations legacy collection | Carried over |
| IMP-12 | Security | LOW | AI prompt input sanitization | Carried over |
| IMP-15 | Architecture | ENH | Unified AI quota management | Carried over |
| IMP-16 | Indexes | ENH | Firestore index for career_coach_usage pendingSince | Carried over |

---

## 11. Verdict

**V9.1 as shipped (`9.1.0+97`) is NOT production-safe** because of SEC-1/SEC-2 (rules) and SEC-3/SEC-4 (functions) — all four are cheaply fixable in a sprint (items 1–5 in §9). The data model, dedupe algorithm, transactional mirroring, and UI flow are otherwise correct and well-tested. The main whole-app integration gaps are: alumni placement-management UI missing (INT-1) and the leftover fake teacher-dashboard metrics (BUG-D).

Once items 1–11 in §9 are applied, V9.1 can be re-audited and closed out. The carried-over items (§8) remain tracked for future scale/security sprints.

> **Post-audit update (2026-08-20):** items 1–6, 10, 12 and 15 in §9 are now applied on disk (SEC-1..SEC-4, SEC-5, BUG-A, BUG-B, BUG-E, BUG-H). Remaining: items 7–9, 11, 13, 14 (BUG-D, SEC-6, INT-1, BUG-F, BUG-G) — see §12.

---

## 12. Resolution Status (2026-08-20)

> Status of every V9.1 audit finding after the audit-fix sprint so far. Phases 1–3 of `docs/todo.md` are complete — the changes were verified on disk in `firestore.rules`, `functions/placements.js`, `functions/index.js`, `lib/models/application.dart` and `lib/models/placement.dart`. Phase 4 (UI/Integration), Phase 5 (tests) and Phase 6 (validate) remain.

| ID | Status | Resolution |
|----|--------|------------|
| SEC-1 | ✅ **RESOLVED** | `firestore.rules` — placements `create/update/delete` now require `createdBy == request.auth.uid`; new `isValidPlacementData()` schema helper (deadline/postedAt are Timestamps, isActive is bool, company/role/description/eligibility/salary non-empty strings) applied to create + update. `Placement.fromFirestore` made tolerant of malformed `deadline`/`postedAt` (defense in depth). |
| SEC-2 | ✅ **RESOLVED** | `firestore.rules` — application `create: if false` locked on BOTH canonical `applications/{applicationId}` and mirror `placements/{placementId}/applications/{appUserId}` paths; `logPlacementApplication` (Admin SDK) is the only writer. Closes self-promotion + phishing-resume chain. |
| SEC-3 | ✅ **RESOLVED** | `functions/placements.js` — `updateApplicationStatus` verifies the actor authored the placement (`placements/{id}.createdBy == uid`), enforces the server-side `STATUS_TRANSITIONS` state machine (applied→[shortlisted,rejected], shortlisted→[interviewed,rejected], interviewed→[placed,rejected], terminal states []), and rate-limits per actor (`_checkStatusRateLimit`, 20/min, career-coach pattern). |
| SEC-4 | ✅ **RESOLVED** | `functions/placements.js` — `logPlacementApplication` reads the placement doc inside the create transaction and rejects missing (`not-found`) / inactive / past-deadline (`failed-precondition`) placements. |
| SEC-5 | ✅ **RESOLVED** | `firestore.rules` — collectionGroup owner rule changed from `isOwner(appId)` to `resource.data.userId == request.auth.uid` (works for canonical `{uid}_{placementId}` doc IDs). |
| BUG-A | ✅ **RESOLVED** | `functions/placements.js` — mirror doc is `transaction.get`-checked inside `updateApplicationStatus`; a missing mirror is re-created via `transaction.set` so the canonical update no longer rolls back. |
| BUG-B | ✅ **RESOLVED** | `lib/models/application.dart` — `userId: data['userId'] as String? ?? data['studentId'] as String? ?? ''` (no null-unsafe cast crash on legacy mirror docs). |
| BUG-E | ✅ **RESOLVED** | `functions/placements.js` — `logPlacementApplication` null-guards `request.data` before destructuring (friendly `invalid-argument` instead of a wrapped TypeError). |
| BUG-H | ✅ **RESOLVED** | `lib/models/application.dart` — status doc comment updated to `applied \| shortlisted \| interviewed \| placed \| rejected`. |
| BUG-D | ⏳ OPEN | `lib/views/dashboards/widgets/teacher_dashboard_sections.dart` — `QuickStatistics`/`DepartmentOverview` still use activeDrives÷students; use `analytics.pipelinePlaced`. (todo.md Phase 4) |
| BUG-F | ⏳ OPEN | `lib/views/placements/placement_applicants_view.dart` — refresh applicant counts after a successful status update. (todo.md Phase 4) |
| BUG-G | ⏳ OPEN | `lib/views/placements/placement_applicants_view.dart` — show a "text resume" state instead of a dead Resume button for text-paste applications. (todo.md Phase 4) |
| SEC-6 | ⏳ OPEN | `lib/main.dart` — role-gate `placementApplicantsRoute` (teacher/alumni-only guard, `_guardStudentPortfolio`/`_guardAlumniGroupChat` pattern). (todo.md Phase 4) |
| INT-1 | ⏳ OPEN | `lib/views/dashboards/alumni_dashboard_view.dart` — add a "Placements" entry (quick action/tab) pointing at `placementsListRoute`. (todo.md Phase 4) |
| SEC-7 / IMP-6 | ⏳ OPEN | App Check (Play Integrity / DeviceCheck / reCAPTCHA) — carried over to the security sprint. |
| IMP-8/9/11/12/15/16 | ⏳ OPEN | Carried-over improvements — see §8 and `docs/todo.md` "Open Improvements". |

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v9.1.1+98 | 2026-08-20 (in progress) | V9.1 audit fixes — Phases 1–3 complete (rules/functions/models: SEC-1..SEC-5, BUG-A/B/E/H); Phases 4–6 pending (UI, tests, validate) |
| v9.1.0+97 | 2026-08-20 | Teacher Applicant Review / Placement Pipeline (this audit) |
| v9.0.0+96 | 2026-08-18 | AI Career Coach + audits (see `docs/todo.md` History) |
| v8.9.3+95 | 2026-08-18 | Recommendations fixes, portfolio-first gate |
| v8.9.0+92 | 2026-08-16 | Recommendation engine, career roles |
| v8.8.x | 2026-08-15 | AI chat, resume review, crash-safe quotas |
| v8.4–8.7 | 2026-08-07..09 | Resume portfolio system, single-writer restoration, AI migration |
