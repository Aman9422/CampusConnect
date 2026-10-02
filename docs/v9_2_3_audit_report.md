# CampusConnect — v9.2.3 Whole-Application Deep Audit, Optimization & Improvement Assessment

| | |
|---|---|
| **Audited revision** | `pubspec.yaml` → `version: 9.2.2+100` (working tree at audit time) |
| **Report date** | 2025‑10‑02 |
| **Report date (corrected)** | **2026-10-02** — see § AD-1. The row above is the original (wrong-year) value and is preserved as the historical record. |
| **Scope** | Whole application: Flutter client, Cloud Functions, Firestore rules, Storage rules, indexes, Android build config, tests, documentation |
| **Method** | Direct source inspection of every `lib/`, `functions/`, `test/`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json` and Android Gradle file, cross‑referenced against `docs/logs.md` (runtime evidence), `docs/v9_2_2_investigation_report.md`, `docs/v9_2_2_optimization_report.md` and `v9_2_audit_report.md`. Dependency currency measured with `flutter pub outdated` and `npm outdated`. Toolchain versions measured with `flutter --version` / `dart --version` / `node --version` / `npm --version`. |
| **Code changes made** | **None.** This is an investigation phase only, per Task §1 ("Do not modify application code unless explicitly requested"). |

> **Evidence convention.** Every finding below cites a file and symbol. Where a claim depends on a deployed Firebase project, the Console, or a device rather than on source, it is marked **[RUNTIME-VERIFY]** instead of being asserted. Findings that are environment‑only or false positives are explicitly separated in § E and § F.

---

## A. Executive Summary

### What was audited

The complete application was walked subsystem by subsystem: the Flutter client (65 source files across `models/`, `providers/`, `services/`, `views/`, `utilities/`, `widgets/`), all 20 deployed Cloud Functions and their supporting modules, both security rule files, the Firestore index file, the Android/Kotlin/Gradle toolchain, 44 Flutter test files plus 8 Functions test files, and the documentation set.

### What was found

The **v9.2 and v9.2.2 workstreams are genuinely landed** — this audit re‑verified them against source rather than assuming them. Specifically confirmed present and correct:

* the `users/{userId}` recursive catch‑all deletion (the privilege‑escalation fix) and every `write: false` it previously voided;
* `LoadDedupe` in `TeacherAnalyticsProvider` and the teacher‑analytics load‑scoped read cache (including the N+1 removal via `pickLatestReviewPerUser`);
* the listener‑lifecycle fixes (retained subscriptions + `dispose()` on Opportunity/AlumniDirectory/Mentorship/Portfolio/AlumniGroupChat);
* `RefreshDedupe` + `recommendation_fingerprint.dart` on the client and the sha256 fingerprint gate in `functions/recommendations/refresh.js`;
* the idempotent flattened‑portfolio migration (`portfolio_migration.dart` + `PortfolioService.migrateFlattenedPortfolio`);
* the `ai_interactions` retention‑sweep field fix (`timestamp`, not `createdAt`) in `chatDelete.js`;
* the single‑writer engagement fix (client recompute and `EngagementProvider.trackActivity` removed);
* the server‑side `resumeReviews` writer (`persistResumeReview`) with owner create/update denied.

Against that baseline, this audit found **a genuinely new and larger class of issues than v9.2.2 tackled**, concentrated in four areas the earlier passes did not examine:

1. **Production readiness** — the release build is signed with the **debug keystore**, and App Check is configured but **not enforced** (and the debug token is still not allow‑listed), so the tamper protection the code believes it has does not currently exist.
2. **Client/server behavioural divergence** — the placement eligibility engine disagrees between the Flutter client and the recommendation engine on placements that specify both `programs` and `branches`, and the placement‑apply callable is given a **30 s client timeout against a 120 s server timeout** that wraps two Storage round trips.
3. **Trigger chain / duplicate regeneration** — the resume‑review trigger **writes the parent user document**, which fires the profile trigger, which runs the recommendation engine **concurrently with** the resume‑review trigger for the same student, using two *different* fingerprints. This is the exact `Firestore write → trigger → recommendation refresh → write → another trigger` chain the brief asks about, and it makes the v9.2.2 fingerprint gate thrash rather than collapse.
4. **Unbounded read patterns** — a large number of `snapshots()` streams and `get()` queries have no `limit()` and no pagination, including two **collection‑group scans of the entire database** executed by the teacher client, a **full alumni‑collection scan three times per directory open**, and **full active‑opportunity scans four times per opportunities screen open**.

### Headline assessment

The application's **security rules are in good shape** and the **v9.2/v9.2.2 fixes are real**. The remaining risk is not in the rule layer — it is in (a) release configuration, (b) a small number of client/server contract mismatches, and (c) query boundedness. All three are addressable without changing the architecture, and none requires a rewrite.

No numeric cost or performance figure is claimed anywhere in this report without the measurement that produced it. Where only a *structural* reduction is provable (fewer queries, fewer invocations, fewer documents written), it is stated as such.

---

## B. Audit Coverage

| # | Subsystem | Files inspected | Verdict |
|---|---|---|---|
| 1 | Project & architecture | `lib/` (all 65 files listed), `functions/` (all 21 files), `main.dart`, `constants/routes.dart`, `firebase.json`, `.firebaserc`, `.metadata` | Consistent, with duplication noted (§ K) |
| 2 | Authentication & session | `auth/*.dart` (5), `main.dart` `AuthGuard`, `role_provider.dart`, `profile_provider.dart` | Sound; `AuthGuard` reset/init flags correct |
| 3 | Authorization — Firestore rules | `firestore.rules` (full) | Strong; catch‑all correctly removed |
| 4 | Authorization — Storage rules | `storage.rules` (full) | Strong; snapshot path covered |
| 5 | Authorization — Cloud Function callables | all 8 callables | Sound; consistent `request.auth.uid` identity |
| 6 | App Check | `main.dart::_activateAppCheck`, `docs/logs.md` | **Provider selection correct; enforcement not active** |
| 7 | Firestore collections & queries | every client `collection(` / `snapshots()` / callable (enumerated in § Q) | **Boundedness gaps** (§ D, § H) |
| 8 | Firestore cost | all read/write sites | Structural reductions identified (§ H) |
| 9 | Cloud Functions | all 20 exports + 12 modules | Sound; one trigger chain + one timeout mismatch |
| 10 | AI system | `ai/aiProvider`, `groqProvider`, `huggingfaceProvider`, `normalizeResponse`, `chat`, `resumeReview`, `deepAnalysis`, `quota`, `careerCoach`, `career_coach` | Sound abstraction; one dead callable |
| 11 | Recommendation engine | `recommendations/engine.js`, `career_roles.js`, `refresh.js`, `ai_explanations.js` | Single‑writer contract respected; fingerprint thrash found |
| 12 | Providers (all 21) | every file in `lib/providers/` | Lifecycle correct; two amplification issues |
| 13 | Screens & navigation | `main.dart` routes + guards, dashboard/feature views (spot + structural) | No loops; guards present |
| 14 | Performance | startup path, dashboards, streams, lists | Confirmed structural items (§ G) |
| 15 | Data model & migration | models, `portfolio_migration.dart`, legacy quota mirrors | Migration correct; legacy mirrors still live |
| 16 | Storage & files | `storage_service.dart`, `resume_service.dart`, `placements.js` snapshot path | Consistent with rules |
| 17 | Notifications & real‑time | `notifications_*`, `chat_*`, `alumni_group_chat_*`, 6 triggers | Unbounded streams (§ D) |
| 18 | Scheduler / background jobs | `schedulers/index.js`, `chatDelete.js` | 5 jobs, all justified |
| 19 | Error handling & reliability | `error_messages.dart`, `show_error_dialog.dart`, all catch blocks | Good; two fragile paths |
| 20 | Testing | 44 Flutter + 8 Functions suites | Strong unit coverage; integration gaps (§ J) |
| 21 | Dependencies & build | `pubspec.yaml`, `pubspec.lock`, `functions/package.json`, `package-lock.json`, Gradle files | Measured (§ N) |
| 22 | Documentation | `docs/`, root `*.md` | Stale in specific places (§ E) |

**Counts:** 20 exported Cloud Functions · 20 Firestore collections/subcollections reachable by a client · 21 providers · 36 route entries · 22 real‑time `snapshots()` streams · 14 client `httpsCallable` call sites · 44 Flutter test files · 8 Functions test files.

---

## C. Critical Findings

### C‑1 — The release APK/AAB is signed with the **debug keystore**

**Evidence** — `android/app/build.gradle.kts`:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

**Category:** confirmed bug (production blocker).
**Impact:** the artifact produced by `flutter build apk --release` (which `docs/v9_2_2_optimization_report.md` §11 records as successfully built) cannot be uploaded to Google Play — the Play Console rejects a bundle signed with the debug key. Any build distributed from this tree is also signed with a publicly known key, so its provenance cannot be established.
**Why the earlier passes missed it:** v9.2 intentionally deferred the release build ("product decision: optimization pass only"); v9.2.2 built the APK but did not audit its signing.
**Action:** create an upload keystore, wire `signingConfigs { create("release") { … } }` from `key.properties` (git‑ignored), and keep the debug config only for the `debug` build type. This must happen before v9.5.

---

### C‑2 — App Check is configured but **not enforced**, and the debug token is still not allow‑listed

**Evidence (code — correct):** `lib/main.dart::_activateAppCheck()` selects `AndroidDebugProvider()`/`AppleDebugProvider()` under `kDebugMode || kProfileMode`, and `AndroidPlayIntegrityProvider()`/`AppleDeviceCheckProvider()`/`ReCaptchaV3Provider(...)` in release. Initialization order (`Firebase.initializeApp` → `_activateAppCheck` → `runApp`) is correct.

**Evidence (runtime — the gap):** `docs/logs.md` contains 15+ occurrences of

```
W/LocalRequestInterceptor: Error getting App Check token; using placeholder token instead.
   Error: com.google.firebase.FirebaseException: Error returned from API. code: 403 body: App attestation failed.
W/FirebaseContextProvider: Error getting App Check token. Error: … Too many attempts.
```

for every account and every backend request in the session.

**Category:** confirmed configuration gap (security posture).
**Impact:** the code path that would reject a tampered client is inert. Firestore/Storage rules authenticate via `request.auth` (Firebase Auth) and callables via `request.auth.uid`, so the *functional* impact is nil today — but the application is not protected against client tampering, scripted abuse of the callables, or emulator‑based scraping, and the moment enforcement is switched on in the Console the still‑unregistered token makes every backend call fail with `permission-denied`.
**Action (Console, not code):** register the emulator debug token (`Firebase Console → App Check → Apps → Android app → Manage debug tokens`) **and then** enable enforcement for Firestore, Functions and Storage. Verify in a release‑mode device run that Play Integrity attestation succeeds before relying on it. **[RUNTIME-VERIFY]**

---

### C‑3 — `analytics_events` grows without bound and has no retention policy

**Evidence** — writes: `functions/helpers/shared.js::logAnalyticsEvent` (called from `askAI` twice per message, `reviewResume`, `generateResumeAnalysis`, `generateCareerCoachAnalysis`, `logPlacementApplication`, `logPlacementView`, `updateApplicationStatus`); `careerCoach.js` also writes an `analytics_events` document directly. Reads/deletes: `firestore.rules` grants `allow read, write: if false` (Admin SDK only) and **no Cloud Function or scheduler ever reads, expires or deletes `analytics_events`** — verified by an exhaustive search of `functions/` for the collection name (only the two write sites).

**Category:** confirmed architectural/cost concern.
**Impact:** every AI message, every resume review, every deep analysis, every career‑coach run and every placement view/apply/status change appends an immutable document to a collection that nothing ever removes. This is unbounded storage growth plus a growing index cost, and it is personal‑activity data (uid + event metadata) that has no documented retention window — a privacy‑retention gap of the same class as the `ai_interactions` one that BUG‑1 fixed in v9.2.
**Action:** either add `analytics_events` to a retention sweep (mirroring `cleanupExpiredAIConversations`) with a stated window, or aggregate into daily roll‑up counters instead of per‑event documents. Do not delete the collection without deciding the retention policy first.

---
## D. High-Priority Findings

### D‑1 — Trigger chain: one resume review runs the recommendation engine **twice, concurrently, with two different fingerprints**

**Evidence** — `functions/triggers/index.js::onResumeReviewCreatedRefreshMatches`:

```js
if (hasPortfolioResume) {
  const portfolioResumeMerge = {
    "portfolio.resume.reviewCount": admin.firestore.FieldValue.increment(1),
    "portfolio.resume.lastReviewAt": admin.firestore.Timestamp.now(),
    "portfolio.resume.updatedAt": admin.firestore.Timestamp.now(),
  };
  if (atsScore !== null) portfolioResumeMerge["portfolio.resume.latestATSScore"] = atsScore;
  await admin.firestore().collection("users").doc(userId).set(portfolioResumeMerge, {merge: true});   // ← writes users/{uid}
}
if (isStudent) {
  await refreshRecommendationsForStudent(userId, userData, {resumeData});                              // ← refresh #1 (with resumeData)
}
```

The `users/{uid}` write fires `onProfileUpdatedRefreshAI` (also `document: "users/{userId}"`). That trigger's guard passes because `portfolioContentChanged(before, after)` is true — `portfolio.resume.reviewCount` / `latestATSScore` just changed — and it calls `refreshRecommendationsForStudent(userId, after)` **without** `resumeData`, i.e. refresh #2.

Both run concurrently, and `computeRecommendationFingerprint` (`functions/recommendations/refresh.js`) includes `resumeReview: {atsScore, missingKeywords}` when `options.resumeData` is present and `null` when it is not. So the two invocations compute **different fingerprints for the same student state**.

**Category:** confirmed bug (chain + correctness + cost).
**Impact:**
1. Two full engine runs (≈600 candidate reads each), two AI enrichment calls, two full document rewrites per resume review.
2. **Fingerprint thrash:** each run persists its own fingerprint to `recommendations_meta/summary`. Whichever finishes last wins, so the stored fingerprint alternates between the two variants. The next legitimate call (client bootstrap, manual refresh) therefore compares against a value that does **not** match the stable "with resumeData" state often enough — the v9.2.2 skip gate fires only about half the time in this scenario instead of reliably.
3. `onProfileUpdatedRefreshAI` additionally awards `logUserActivity(userId, "profileUpdated", 3)` — 3 engagement points per resume review, on top of the 5 the resume‑review trigger already awards, because the portfolio write looks like a profile update.

**Action:** the resume‑review trigger must not write the parent user document. Move the resume‑review counters to a subcollection the profile trigger does not watch (e.g. `users/{uid}/recommendations_meta/resume`), or widen `isPortfolioMetadataOnlyChange`/`portfolioContentChanged` in `functions/helpers/shared.js` to ignore the `portfolio.resume.reviewCount|lastReviewAt|updatedAt|latestATSScore` key set that the trigger itself writes. The second option is the smaller change and keeps the dashboard card working.

---

### D‑2 — Client/server timeout mismatch on placement apply (and a false "not applied" rollback)

**Evidence** — client: `lib/providers/placements_provider.dart::applyForPlacement`:

```dart
final result = await callable.call({...}).timeout(
  const Duration(seconds: 30),
  onTimeout: () { throw Exception('Request timed out. Please try again.'); },
);
...
} catch (e) {
  _appliedPlacementIds.remove(placementId);   // ← rolls back the optimistic "applied" state
  _appliedDates.remove(placementId);
```

server: `functions/placements.js::logPlacementApplication` is declared `{cors:false, maxInstances:100, timeoutSeconds:120}` and performs, **before** the Firestore transaction, a Storage `copy` and a `getSignedUrl` (two GCS round trips) on a cold instance.

**Category:** confirmed bug (reliability/correctness).
**Impact:** when the apply takes longer than 30 s but succeeds, the client throws, removes the placement from `_appliedPlacementIds`, shows "Request timed out. Please try again.", and the student retries. The retry is idempotent server‑side (`existingApp.exists → isNewApplication=false`), so no duplicate application is created — but the UI told the student the apply failed while the server had already recorded it, and until the next refresh the placement still reads as "not applied".
**Note:** this is exactly the class of defect that `RecommendationService._invokeRefresh` already fixed for recommendations (v8.9.3 R6 raised the client callable timeout to 120 s to match the server). `applyForPlacement` and `updateApplicationStatus` were not brought along — `updateApplicationStatus` uses a 30 s client timeout against a 60 s server function, which is less severe but the same mismatch.
**Action:** raise both client timeouts to match their server declarations (120 s for `logPlacementApplication`, 60 s for `updateApplicationStatus`), and on timeout do **not** roll back `_appliedPlacementIds` — instead mark the placement "pending confirmation" and reconcile with a single read.

---

### D‑3 — Placement eligibility disagrees between the client and the server (`programs` vs `branches`)

**Evidence** — client `lib/services/eligibility_engine.dart::checkEligibility` checks the two requirement sets **independently**, so both must pass:

```dart
if (requirements.programs.isNotEmpty) { … failedChecks.add('Program … not eligible') }
if (requirements.branches.isNotEmpty) { … failedChecks.add('Branch not eligible') }
```

server `functions/recommendations/engine.js::checkMandatoryEligibility` checks them as **alternatives**:

```js
if (programs.length > 0 && !programs.includes(u.program)) {
  failures.push(`Program ${u.program || '—'} not eligible`);
} else if (branches.length > 0 && !branches.includes(u.program)) {
  failures.push('Branch not eligible');
}
```

`docs/eligibility_rules.md` documents the **server** behaviour ("Branches … are only checked when `programs` is empty but `branches` is specified").

**Category:** confirmed bug (client/server divergence).
**Impact:** for a placement that specifies both `programs` and `branches`, a student whose program matches but whose branch does not is shown an **ineligible** badge on the client while the server considers them eligible and emits a placement recommendation — or, depending on the values, the reverse. The badge and the recommendation card contradict each other for the same placement, and the eligibility badge is the student's only pre‑apply signal (`views/widgets/eligibility_badge.dart`, rendered from `student_dashboard_view.dart:1362` and `placements_list_view.dart:403`).
**Action:** decide which semantic is correct (the doc says the server's), align the client to it, and add a shared table‑driven test covering a placement with both fields set. `test/placement_match_test.dart` mirrors the engine but, per the file list, does not exercise the programs+branches combination.

---

### D‑4 — Teacher analytics reads **every resume review and every application in the database** into the teacher client

**Evidence** — `lib/services/firestore/teacher_analytics_service.dart`:

```dart
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _resumeReviewDocs() {
  return _resumeReviewsFuture ??= _firestore
      .collectionGroup('resumeReviews')
      .get()                       // ← no where(), no limit()
      .then((snapshot) => snapshot.docs);
}
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _applicationDocs() {
  return _applicationsFuture ??= _firestore
      .collectionGroup('applications')
      .get()                       // ← no where(), no limit()
      .then((snapshot) => snapshot.docs);
}
```

The in‑file comment states this is deliberate: *"Kept exact (unbounded) deliberately: capping it would under-count reviews."*

**Category:** confirmed optimization opportunity / architectural concern (scalability).
**Impact:** the v9.2 deduplication reduced these from *several* scans per load to *one* scan per load — a real improvement — but each remaining scan is still O(total reviews in the institution) and O(total applications in the institution), executed on the **client**, materialised in memory, and re‑read on every teacher dashboard open (and on every pull‑to‑refresh). At a few hundred students with a handful of reviews each this is thousands of documents per teacher per open; the cost and the first‑paint latency grow linearly and unboundedly with the institution's history. It also means the teacher client holds the full text‑adjacent review payload (`atsScore`, `missingKeywords`, `strengths`) for every student.
**Action:** replace the two collection‑group scans with server‑side aggregates. `recomputeEngagementSummary` already demonstrates the pattern (materialised per‑user aggregate maintained by a trigger). A `teacher_analytics_rollup/current` document maintained by the schedule + triggers would make the teacher dashboard a single read. Failing that, bound the scans with a date window (`where('createdAt', '>=', twelveMonthsAgo)`) and paginate — the UI already only shows 30 students and 6 months of trend.
**Do not** simply add `.limit()` without a `where()`, which would silently truncate the results and under‑count (as the comment correctly warns).

---

### D‑5 — Alumni directory open issues **five queries, three of them unbounded full scans**

**Evidence** — `lib/providers/alumni_directory_provider.dart::init()` → `Future.wait([...])` over five service calls; `lib/services/firestore/alumni_directory_service.dart`:

| Call | Query | Bounded? |
|---|---|---|
| `getAlumniDirectory()` | `where(role=='alumni') + where(profileCompleted==true)` | `.limit(100)` |
| `getFilterOptions()` | same filters | **no limit — full scan** |
| `getRecentAlumni()` | same filters | `.limit(10)` |
| `getFeaturedAlumni()` | same filters | **no limit — full scan** (then sorts in memory and takes 5) |
| `getAlumniStats()` | same filters | **no limit — full scan** (then counts in memory) |

**Category:** confirmed optimization opportunity (cost).
**Impact:** opening the alumni directory once costs one bounded read plus **three complete scans of the alumni collection**, each materialising every alumni document. `getFilterOptions`, `getFeaturedAlumni` and `getAlumniStats` all re‑read the identical document set that `getAlumniDirectory` already fetched in the same `Future.wait` — they could all be derived from that one result set with zero extra reads. Repeated on every `refresh()`.
**Action:** fetch the alumni page **once** and derive filter options, recents, featured and stats in memory; or (better) maintain a small `alumni_directory_meta/summary` document with the filter option lists and counts, refreshed by a trigger when an alumni profile completes. `getFeaturedAlumni`'s "score" is a pure function of fields already present in each document, so no separate read is needed for it under any design.

---

### D‑6 — Opportunities screen issues **seven queries, four of them unbounded scans of active opportunities**

**Evidence** — `lib/services/firestore/opportunity_service.dart`:

* `getActiveOpportunities()` — `.limit(50)` (bounded)
* `getRecentOpportunities()` — `.limit(10)` (bounded, but duplicates the same `where(isActive) + orderBy(postedAt)` shape as the previous call)
* `getUniqueCompanies()` — `where(isActive==true).get()` — **no limit**
* `getUniqueLocations()` — `where(isActive==true).get()` — **no limit**
* `getPopularSkills()` — `where(isActive==true).get()` — **no limit**
* `getOpportunityStatsForAlumni()` — `where(alumniId==id).get()` — **no limit**, counted in memory
* plus `loadAlumniOpportunities()` / `_refreshActiveOpportunities()` re‑issuing the same reads from `lib/providers/opportunity_provider.dart`

**Category:** confirmed optimization opportunity (cost).
**Impact:** three separate full scans of every active opportunity document to compute three derived string lists, all of which could come from the single `limit(50)` page the screen already fetches (or from a cached aggregate). The alumni stats read is a fourth unbounded read of that alumni's opportunities, immediately after `getAlumniOpportunities()` already read the same documents — the count could be `.count()` (an aggregation query that bills a fraction of the document reads) or computed from the list already in hand.

---

### D‑7 — Duplicate write of every AI chat exchange (three documents per message) with two conflicting timestamp field names

**Evidence** — the AI chat path writes to `users/{uid}/ai_interactions` from **two independent writers** with **two different schemas**:

* server — `functions/ai/chat.js::askAI` writes one document for the user turn and one for the assistant turn:
  ```js
  .add({ role: "user",      message: trimmedMessage, timestamp: serverTimestamp(), status: "processed", … });
  .add({ role: "assistant", message: aiResponse,     timestamp: serverTimestamp(), isAIResponse: true, … });
  ```
* client — `lib/providers/ai_chat_provider.dart::_saveInteraction` writes a **third** document containing both turns:
  ```dart
  .add(interaction.toFirestore());   // → lib/models/ai_interaction.dart::toFirestore
  ```
  which produces `{ userId, prompt, response, intent, createdAt, metadata }` — note **`createdAt`**, not `timestamp`.

**Category:** confirmed bug (duplicate writes + retention gap) and cost issue.
**Impact:**
1. Three documents and three writes per chat message instead of one.
2. `AIChatProvider._loadRecentInteractions()` orders by **`createdAt`**, so it sees only the client‑written documents and never the server‑written `role: 'user'|'assistant'` ones. The server's own history documents are therefore invisible to the app but still counted by the retention sweep in `functions/ai/chatDelete.js::cleanupExpiredAIConversations`, which filters on **`timestamp`** — so the two writers' rows have different lifetimes and different visibility, and `deleteAIHistory` must issue two deletes (one for `ai_interactions`, one for the legacy `ai_conversations`) to remove one user's history.
3. `firestore.indexes.json` carries a `fieldOverrides` entry for `ai_interactions.timestamp` on the collection group but nothing for `createdAt`, confirming that only one of the two schemas is the intended one.

**Action:** pick one writer. The cleanest resolution is to keep the **server** as the single writer of `ai_interactions` (it already derives both turns and the AI provider metadata) and delete `AIChatProvider._saveInteraction` plus `AIInteraction.toFirestore`/`fromFirestore`; then point `_loadRecentInteractions` at the server schema (`message`/`role`/`timestamp`). Whichever direction is chosen, both readers and the retention sweep must agree on one timestamp field.

---

### D‑8 — `ActivityFeedProvider` re‑aggregates on every notification from any of five providers, with no debounce

**Evidence** — `lib/providers/activity_feed_provider.dart`:

```dart
ActivityFeedProvider({…}) { _init(); }            // constructor runs the first aggregation
void _init() {
  _addProviderListener(_notificationsProvider, _aggregateActivities);
  _addProviderListener(_chatProvider,         _aggregateActivities);
  _addProviderListener(_mentorshipProvider,   _aggregateActivities);
  _addProviderListener(_placementsProvider,   _aggregateActivities);
  _addProviderListener(_opportunityProvider,  _aggregateActivities);
  _aggregateActivities();
}
```

`_aggregateActivities()` sets `_isLoading = true`, calls `notifyListeners()`, rebuilds the whole activity list (converting notifications, chats, mentorships, placements, opportunities) and calls `notifyListeners()` again.

**Category:** confirmed performance concern (rebuild amplification) + lifecycle defect.
**Impact:**
1. `NotificationsProvider`, `ChatProvider`, `PlacementsProvider` and `OpportunityProvider` each call `notifyListeners()` multiple times per operation (loading flag on, data, loading flag off); every one of those synchronously triggers a full re‑aggregation and two more `notifyListeners()` on `ActivityFeedProvider`. A single chat message send therefore fans out into several complete activity rebuilds.
2. The provider is created at application start in `lib/main.dart`'s `MultiProvider` — **before login** — so it aggregates empty data for every signed‑out session and subscribes to five providers that are themselves not yet initialised.
3. `reset()` (called from `AuthGuard` on logout) clears state and calls `notifyListeners()` but **does not set `_isDisposed`** and does not remove the five provider listeners (only `dispose()` does). After logout the provider therefore keeps re‑aggregating and notifying on every provider event for the remainder of the process.

**Action:** debounce the aggregation (e.g. coalesce within a frame or on a short `Timer`), make `reset()` set `_isDisposed` and remove the listeners, and consider constructing the provider only once a user is authenticated.

---
## E. Medium / Low Findings

Each entry states the category, the evidence, and — where relevant — why it is *not* a false positive.

### E‑1 (Medium) — Unbounded real‑time streams: chat messages, alumni group messages, notes

**Evidence:**
* `lib/services/firestore/chat_service.dart::getMessagesStream` — `.orderBy('sentAt').snapshots()` with **no `limit()`**, while the sibling one‑shot `getMessages(chatId, {limit = 50})` *is* bounded.
* `lib/services/firestore/alumni_group_chat_service.dart::getMessagesStream` — `.orderBy('createdAt').snapshots()` with **no `limit()`**.
* `lib/services/firestore/notes_service.dart::getAllNotes` — `.orderBy('uploadedAt', descending: true).snapshots()` with **no `limit()`**, for **every authenticated user** (the rule grants read to all authenticated users).

**Category:** confirmed optimization opportunity (cost + memory + first‑paint latency).
**Impact:** opening one chat keeps a live listener on **every message ever sent in that chat**; opening the alumni community keeps a listener on every group message ever sent; opening the notes list downloads and keeps live every note document in the institution. Only the chat *list* (`getUserChatsStream`), notifications (`limit 50`) and the recommendations stream (`limit 20`) are bounded.
**Note:** `notes` is a shared, append‑only, institution‑wide resource and is therefore the one that grows fastest.
**Also:** `firestore.indexes.json` declares a `notes: uploadedBy ↑, uploadedAt ↓` composite index, but `getAllNotes` orders by `uploadedAt` alone — so the declared index is for `getNotesByUploader`, which is itself unused (see § K).

---

### E‑2 (Medium) — Unbounded notification bulk reads

**Evidence** — `lib/services/firestore/notifications_service.dart`:

```dart
Future<void> markAllAsRead(String userId)            → .where('isRead', isEqualTo: false).get()   // no limit
Future<void> deleteReadNotifications(String userId)  → .where('isRead', isEqualTo: true).get()    // no limit
Future<int>  getUnreadCount(String userId)           → .where('isRead', isEqualTo: false).get()   // no limit, and unused
```

Each then iterates the full result set into a single `batch` with **no 500‑write chunking** (contrast `functions/helpers/shared.js::deleteDocsInBatches`, which chunks at 400).

**Category:** confirmed optimization opportunity + latent reliability bug.
**Impact:** a user with more history than the notifications stream's `limit(50)` has documents the app never displays but these methods still read and write; a single `.get()` returning >500 documents makes `batch.commit()` throw, so "Mark all as read" / "Clear read" would fail for exactly the heaviest users. `getUnreadCount` is dead (see § K).

---

### E‑3 (Medium) — `autoExpireOpportunities` builds one unbounded batch

**Evidence** — `functions/schedulers/index.js::autoExpireOpportunities`:

```js
const snapshot = await admin.firestore().collection("opportunities")
    .where("isActive", "==", true).where("applicationDeadline", "<=", now).get();   // no limit
if (snapshot.empty) return;
const batch = admin.firestore().batch();
for (const doc of snapshot.docs) { batch.update(doc.ref, {…}); }                   // one batch, no chunking
await batch.commit();
```

**Category:** confirmed latent reliability bug (the same class the codebase already fixed elsewhere).
**Impact:** Firestore caps a write batch at 500 operations. If more than 500 opportunities share the same expiry window (e.g. after a holiday period, or on a first run against accumulated data), the commit throws and **no** opportunity is expired; the scheduler logs the error and the run is lost until the next hour. Every other bulk writer in the codebase chunks (`deleteDocsInBatches`, `onOpportunityPostedNotifyStudents` at 400, `recomputeEngagementScores` paginated) — this one does not.
**Action:** chunk at 400/500 exactly as the sibling functions do.

---

### E‑4 (Medium) — The client recommendation fingerprint cannot see portfolio changes

**Evidence** — `lib/services/recommendations/recommendation_fingerprint.dart` states it explicitly: *"the `StudentProfile` model itself does not carry the portfolio, so in the app path the portfolio-side changes are handled by the server-side fingerprint"*. `recommendationFingerprintKeys` lists `portfolio`, but a `StudentProfile`'s `toFirestore()` does not emit it, so the key is always absent on the app path.

**Category:** architectural concern (accepted trade‑off, correctly documented).
**Impact:** after a portfolio edit, `RecommendationProvider.initWithUser`'s client gate may skip its own refresh for up to `RefreshDedupe.maxAge` (6 h). The refresh still happens via `onProfileUpdatedRefreshAI`, so the data is not stale — but the *client‑initiated* refresh is suppressed in a case where the developer might reasonably expect it to run, and the client gate's "cache hit" log line will appear misleadingly. No user‑visible defect found. Worth a comment at the call site rather than a code change.

---

### E‑5 (Medium) — Duplicated, drifting quota/limit constants

**Evidence:** the same limits exist as independent literals on the server, in the environment reader, and on the client:

| Limit | Server (env) | Server (literal) | Client (literal) |
|---|---|---|---|
| Chat/day | `quota.js` → `process.env.DAILY_MESSAGE_LIMIT \|\| "50"` | `ai/chat.js` → `const DAILY_MESSAGE_LIMIT = 50` (used for the soft‑limit log **and** the returned `usage.dailyLimit`) | `ai_usage_provider.dart` → `_dailyLimit = 50` |
| Resume review/month | `quota.js` → `process.env.RESUME_MONTHLY_LIMIT \|\| "5"` | `ai/resumeReview.js` → `const RESUME_MONTHLY_LIMIT = 5` (error‑path default) | `resume_review_provider.dart` → `ResumeReviewUsage(monthlyLimit: 5)` |
| Career Coach/month | `quota.js` → `process.env.CAREER_COACH_MONTHLY_LIMIT \|\| "3"` | `careerCoach.js` → `const CAREER_COACH_MONTHLY_LIMIT = parseInt(env \|\| "3")` | `career_coach_service.dart` / model defaults |
| AI analysis/month | `quota.js` → `process.env.AI_MONTHLY_LIMIT \|\| "3"` | `ai/deepAnalysis.js` → `const AI_MONTHLY_LIMIT = 3` | model defaults |

**Category:** confirmed technical debt (correctness risk).
**Impact:** the *enforcement* limit lives in `quota.js` and is env‑configurable; the *displayed* limits are hardcoded in three other places. Setting `RESUME_MONTHLY_LIMIT=10` in the Functions environment would raise the real limit while every client screen still shows "x/5" and the server's own error message (`deepAnalysis.js`, `resumeReview.js`) would quote 3/5. `ai/chat.js` even returns `dailyLimit: DAILY_MESSAGE_LIMIT` (its own literal) in the success payload, so the chat screen can display a limit that disagrees with the value `quota.js` actually enforced.
**Action:** return the effective limit from `quota.js` in every usage response and have the client render it, rather than duplicating it. (The client already *has* the field — `AIUsageProvider.updateUsageInfo(messagesUsed, dailyLimit)` and `CareerCoachUsage.monthlyLimit` — it is simply overwritten with a constant.)

---

### E‑6 (Medium) — `cors: false` on three callables breaks a Flutter **web** build

**Evidence:** `functions/placements.js` declares `logPlacementView {cors:false}`, `logPlacementApplication {cors:false}` and `updateApplicationStatus {cors:false}`. Every other callable (`askAI`, `reviewResume`, `generateResumeAnalysis`, `deleteAIHistory`, `generateCareerCoachAnalysis`, `refreshRecommendations`) leaves CORS at its default (enabled). The repository has a `web/` platform directory and `firebase.json` provisions a web app config plus `WEB_RECAPTCHA_V3_SITE_KEY` support in `_activateAppCheck`.

**Category:** possible issue requiring runtime verification **[RUNTIME-VERIFY]**.
**Impact:** if the web target is built and used, calls to those three callables are rejected by the browser's CORS preflight while the other seven succeed — a confusing partial failure confined to placements. If only Android/iOS are shipped, this is a non-issue.
**Action:** confirm whether the web build is in scope for v9.5. If yes, align the three declarations with the rest; if no, leave the hardening in place.

---

### E‑7 (Medium) — Two AI‑insight components are dead and one of them calls a Cloud Function that does not exist

**Evidence:**
* `lib/services/ai/ai_insights_service.dart` defines `AIInsightsService`, whose `requestInsight` calls `_functions.httpsCallable('generatePlacementInsight')` (line 116). **No such function exists**: `functions/index.js` exports 20 functions and none is `generatePlacementInsight`; a recursive search over `functions/` for the string returns zero hits.
* A recursive search for `AIInsightsService` / `insights_service` over `lib/` returns **only the file itself** — nothing imports it.
* `lib/models/ai_placement_insight.dart` is referenced only by that service and by `lib/views/widgets/eligibility_badge.dart`.

**Category:** confirmed dead code + a latent dangling callable reference.
**Impact:** inert today (no caller), but it is a trap: any future wiring of the AI placement insight would fail with `not-found` at runtime, and the Firestore rule `users/{uid}/ai_insights { allow read: if isOwner; allow write: if false; }` guards a collection with no writer at all.
**Action:** in v9.2.4 either (a) delete `ai_insights_service.dart`, the unused insight widget in `eligibility_badge.dart`, the `AIPlacementInsight` model and the `ai_insights` rule, or (b) implement the function and wire it. Do **not** remove the rule before deciding, in case the collection holds historical documents.

---

### E‑8 (Medium) — Every student login performs an extra full user‑document read for the portfolio migration

**Evidence** — `lib/services/firestore/portfolio_service.dart::migrateFlattenedPortfolio` begins with `await _usersCollection.doc(uid).get()` and this is invoked unconditionally from `PortfolioProvider.initWithUser` (which is itself invoked from the `AuthGuard` ecosystem bootstrap), on **every** login for **every** student.

**Category:** confirmed optimization opportunity (cost).
**Impact:** the migration is idempotent, but the only way it knows there is nothing to do is by reading the whole user document first. For the overwhelming majority of accounts (already canonical) that is a pure waste of one document read per login, forever. `hasFlattenedPortfolioShape` (the old detector) is now unused (§ K) and could not serve as a local guard either, since it also reads the document.
**Action:** persist a one‑shot marker locally (SharedPreferences, alongside the existing `PortfolioCacheService` snapshot) or on the document (`metadata.portfolioMigratedAt` is already stamped!) and skip the read when the marker is present.

---

### E‑9 (Medium) — Every placement application writes two documents and is read twice

**Evidence** — `functions/placements.js::logPlacementApplication`'s transaction sets **both** `applications/{uid}_{placementId}` (canonical, field `resumeUrl`) and `placements/{placementId}/applications/{uid}` (mirror, field `resume`). The readers then compensate: `lib/services/firestore/placements_service.dart::getApplicationsForPlacement` issues a `collectionGroup('applications')` query that matches both and **dedupes in memory** by `userId`, preferring whichever carries `resumeUrl`; `getApplicantCounts` does the same with `whereIn` chunks of 10.

**Category:** architectural concern (documented backward‑compatibility cost).
**Impact:** 2× the write cost per application, 2× the storage, and every applicant‑list read transfers each application twice before discarding one copy — plus the dedupe logic exists in three places (`getApplicationsForPlacement`, `getApplicantCounts`, and the pipeline counting in `teacher_analytics_service.dart`). The `updateApplicationStatus` mirror‑repair path (BUG‑A/BUG‑6) exists solely because the mirror can be missing — a failure mode the canonical‑only design would not have.
**Action:** not a v9.2.3 change, but schedule mirror retirement: stop writing the mirror, keep reading it for one release, then remove the dedupe code and the `placements/{id}/applications` rule. `firestore.indexes.json` also still carries an `applications: userId ↑, appliedAt ↓` composite index for the canonical path, so no index change is needed to go canonical‑only.

---

### E‑10 (Medium) — `maybeCreateNotification` costs a query per notification and can duplicate

**Evidence** — `functions/helpers/shared.js::maybeCreateNotification` performs a `where('type','==',…).where('createdAt','>=',…).limit(1)` read before every write. It is called from `refreshRecommendationsForStudent` (up to 2× per regeneration: `mentorMatch`, `jobMatch`), `sendInactivityReminders` (once per participant per inactive chat, plus twice per stale mentorship request) and `recomputeEngagementSummary` (on streak milestones).

**Category:** confirmed optimization opportunity (cost) + a correctness nuance.
**Impact:** every notification attempt costs one extra read; the daily inactivity sweep costs `O(inactive chats × participants)` reads **and** writes on top of its own unbounded `chats` scan. The read‑then‑write is not transactional, so two concurrent invocations can both pass the guard and create the duplicate the function exists to prevent. Two of the three notification documents written by the *triggers* use deterministic ids (`new_message_{messageId}`, `mentorship_requested_{requestId}`, `mentorship_response_{requestId}`) and are therefore naturally idempotent — this helper is the one that is not.

---

### E‑11 (Low) — `sendInactivityReminders` scans `chats` unbounded

**Evidence** — `functions/schedulers/index.js`: `collection("chats").where("lastMessageAt","<",inactivityCutoff).get()` — no `limit`, no pagination; then a nested loop over `participantIds` with an awaited notification per participant, and a second unbounded query on `mentorship_requests`.

**Category:** confirmed optimization opportunity (cost + timeout risk).
**Impact:** the daily job's work grows with total chat volume and is executed inside a single invocation. Every other bulk job in the file is bounded (`recomputeEngagementScores` pages at 50; `cleanupExpiredAIConversations` limits to 5000). No idempotency marker per chat means a re‑run (or a retry after a partial failure) re‑evaluates every chat.

---

### E‑12 (Low) — `getChatById` contains a fallback that can throw

**Evidence** — `lib/providers/chat_provider.dart::getChatById`:

```dart
final cachedChat = _chats!.firstWhere((c) => c.id == chatId, orElse: () => _chats!.first);
```

`_chats!.first` throws `StateError` when the list is empty; then the identity check `if (cachedChat.id == chatId)` is redundant with the `firstWhere`. The `catch` swallows it and falls through to the service, so behaviour is *accidentally* correct — but the intent is unclear and the `!` is unsafe.

---

### E‑13 (Low) — `AlumniDirectoryProvider.loadMore()` is not pagination

**Evidence** — `lib/services/firestore/alumni_directory_service.dart::getAlumniDirectory({int limit = 100})` has **no cursor** (`startAfter`) parameter, so `loadMore()` in `lib/providers/alumni_directory_provider.dart` can only re‑request the same first N documents and replace `_alumni` when the new length exceeds the old. The method's own comment says "Load 50 more".

**Category:** confirmed bug (feature does not do what it claims).
**Impact:** with more alumni than the initial limit, "load more" either does nothing or reloads the same page. Nothing is corrupted; the feature is simply inert. If the alumni population currently fits inside `limit(100)`, this is invisible.

---

### E‑14 (Low) — `PlacementsProvider.reset()` notifies after marking itself disposed

**Evidence** — `lib/providers/placements_provider.dart::reset()` sets `_isDisposed = true;` and then calls `notifyListeners();` at the end; every other provider in the codebase follows the opposite convention (`NotificationsProvider`, `ChatProvider`, `AlumniGroupChatProvider` explicitly comment "Don't call notifyListeners() after setting _isDisposed"). The `notifyListeners()` is what lets the UI clear the placement list on logout, so removing it would be a regression — but the ordering is inconsistent with the rest of the codebase and with the `_isDisposed` guard used everywhere else.

---

### E‑15 (Low) — Dead code removed by earlier passes left orphaned declarations

Confirmed by exhaustive search — each of these symbols exists **only at its own definition site** (and, where noted, its own thin provider wrapper), with no caller anywhere in `lib/` or `test/`:

| Symbol | File | Note |
|---|---|---|
| `NotificationsService.getUnreadCount` | `notifications_service.dart` | provider computes the count from the stream instead |
| `NotificationsService.notifyStatusChange` | `notifications_service.dart` | the server's `_notifyStatusChange` owns this now |
| `NotificationsProvider.addNotification` | `notifications_provider.dart` | only `createNotification` inside it was greppable |
| `ChatService.deleteChat` | `chat_service.dart` | also unrunnable client‑side (`allow delete: if false` on `chats`) |
| `ChatService.getChatByMentorshipId` | `chat_service.dart` | |
| `ChatService.getChatBetweenUsers` | `chat_service.dart` | |
| `ChatService.getTotalUnreadCount` | `chat_service.dart` | `ChatProvider.unreadCount` supersedes it |
| `OpportunityService.getOpportunitiesByDateRange` | `opportunity_service.dart` | |
| `OpportunityService.cleanupExpiredOpportunities` | `opportunity_service.dart` | would also be rule‑denied (`where isActive==false` on documents the client may only update its own; and the delete path needs owner rights) |
| `MentorshipService.searchRequests` | `mentorship_service.dart` | |
| `MentorshipService.deleteRequest` | `mentorship_service.dart` | |
| `AlumniDirectoryService.getAlumniByCompany` / `…GraduationYear` / `…Department` (+ the three unused `AlumniDirectoryProvider` wrappers) | both files | the UI filters client‑side / via `searchAlumni` |
| `PlacementsService.getPlacementsByCompany` (stream) + `PlacementsProvider.getPlacementsByCompany` | both files | provider computes it in memory |
| `PortfolioService.hasFlattenedPortfolioShape` | `portfolio_service.dart` | superseded by the v9.2.2 `migrateFlattenedPortfolio`; referenced only in a comment |
| `AIInsightsService` (whole file) + the insight widget in `eligibility_badge.dart` | `services/ai/`, `views/widgets/` | see E‑7 |

---

### E‑16 (Low) — Duplicate widget directories with overlapping roles

**Evidence:** `lib/widgets/` (`empty_state.dart`, `skeleton_loader.dart`, `offline_banner.dart`, `home_widgets.dart`, `resume_summary_card.dart`, `dashboard_error_boundary.dart`) and `lib/views/widgets/` (`empty_state_widget.dart`, `loading_widget.dart`, `initials_avatar.dart`, `chat_badge.dart`, `notification_badge.dart`, `eligibility_badge.dart`). **Both are live** — the first is imported by dashboards and feature views, the second by the shared UI kit users. There are two empty‑state widgets and two loading widgets with different names.

**Category:** confirmed technical debt (naming/structure inconsistency).
**Impact:** a developer looking for "the empty state widget" must know which directory a given screen already imports. Consolidating is a mechanical, low‑risk change with no behaviour difference — but it touches many files, so it belongs in a dedicated pass, not in a bug‑fix release.

---

### E‑17 (Low) — Stale and inconsistent documentation

**Evidence:**
* `docs/v9_2_2_investigation_report.md` header says **"Version under investigation: `9.1.2+99`"**, and its §0 table describes the world *before* the v9.2.2 fixes — it is a historical document whose opening line reads as current.
* `docs/v9_2_2_optimization_report.md` §11 quotes a built APK of "56.7MB" for `9.2.2+100` while `v9_2_audit_report.md` §13 records `flutter build apk --release` as **deferred**; both are true at different times but are not cross‑referenced.
* `docs/logs.md` is a capture from the `9.1.2+99` build (it shows the pre‑v9.2.2 behaviour the two reports describe as fixed), yet nothing in the file says so.
* `v9_2_audit_report.md` lives at the **repository root**, while its siblings live in `docs/`. The root also carries `FILES_CREATED.md`, `VERSION_1_SUMMARY.md` … `VERSION_7_1_SUMMARY.md`, `V5.x_*.md`, `V6.x_*.md`, `FIX_APPLY_*.md`, `NOTESVIEW_REFACTORING_ISSUE.md`, `TECHNICAL_IMPLEMENTATION_GUIDE.md` and `v7_5_workspace_tracker.md` — 25+ historical markdown files where the project's actual documentation is 10 files in `docs/`.
* `docs/eligibility_rules.md` documents a rule the client does **not** implement (see D‑3), which makes the "canonical sync policy" table in that file itself inaccurate.

**Category:** confirmed documentation inconsistency.
**Action:** add a one‑line "historical — describes v9.1.2" banner to the two pre‑fix documents and `docs/logs.md`; move `v9_2_audit_report.md` into `docs/`; and archive the root‑level version reports into `docs/history/`. Do this in a docs‑only change so it never collides with code work.

---

### E‑18 (Low) — `deepAnalysis.js` uses a non‑idiomatic `HttpsError` re‑throw test

**Evidence** — `functions/ai/deepAnalysis.js`:

```js
} catch (error) {
  // Re-throw HttpsError as-is
  if (error.code && error.httpErrorCode) { throw error; }
```

Every other module (`placements.js`, `refresh.js`, `resumeReview.js`, `careerCoach.js`, `chat.js`) uses `if (error instanceof admin.functions.https.HttpsError) throw error;`. The duck‑typed check happens to work because `HttpsError` exposes both properties, but it would also pass through any third‑party error that happens to carry both keys, and it silently diverges from the pattern the rest of the codebase follows. Purely a consistency fix.

---

### E‑19 (Low) — Environment‑only noise correctly excluded from the findings

The following appear throughout `docs/logs.md` and are **not** application defects. They are recorded here so that a future reader does not re‑raise them:

| Message | Classification |
|---|---|
| `Skipped 77/30/32 frames!` on cold start | Flutter Engine/Impeller bring‑up + Android `performTraversals()` JIT + Firebase/GMS native init on an emulator. `StartupProfiler` instrumentation was added in v9.2.2 so this can be *measured* rather than asserted. No Dart‑side cause was found. |
| `GmsClient: DeadObjectException`, `Unknown calling package name 'com.google.android.gms'`, `Phenotype.API is not available`, `DEVELOPER_ERROR`, `providerinstaller … not found` | All frames are inside `com.google.android.gms@…` / `dynamite_measurementdynamite`. Google Play Services inside the emulator image. No app‑owned frame appears. |
| `W/FA: Tasks have been queued for a long time` | Firebase Analytics batching on an emulator with no Play Services. |
| `Register WindowLayoutInfoListener`, `ProfileInstaller: Installing profile`, `InsetsController`/`ImeTracker` pairs | Platform/IME lifecycle logging. |

The one item in the log that **is** an application‑relevant signal — the App Check `403` / `Too many attempts` pair — is reported as C‑2.

---

### E‑20 (Low) — Acceptable behaviour explicitly *not* flagged

Recorded so the report does not read as a list of complaints about working code:

* `functions/index.js` initialising the Admin SDK once and re‑exporting from thin modules — correct and readable.
* `ai_conversations` still being cleaned up and still queried by `deleteAIHistory` even though `askAI` no longer writes it — deliberate transition behaviour, documented in `chatDelete.js`.
* The four legacy quota mirror collections (`ai_usage`, `resume_usage`, `career_coach_usage`, `ai_analysis_usage`) being written alongside `user_ai_quotas` — a documented backward‑compatibility contract with the compensation sweep.
* The `DailyUsage`/`RefreshDedupe`/`LoadDedupe` gates being process‑scoped rather than persisted — intended, and documented.
* `TeacherAnalyticsProvider.reset()` deliberately not setting `_isDisposed` — required so logout→re‑login can reload; documented in the file.
* The `portfolio_gate` recommendation card existing for intent‑only students — the v8.9.1 portfolio‑first contract, working as designed.
* `hasExpiredActiveRecommendation` forcing regeneration when a materialised card has expired — correct, and it is why the skip gate cannot make the UI go stale.

---
---

## F. Previous Audit Verification

Every substantive claim made by `v9_2_audit_report.md` (v9.2) and `docs/v9_2_2_optimization_report.md` (v9.2.2) was re‑checked against the current source. Classification: **Fixed / Partially Fixed / Not Fixed / Cannot Verify / Regressed**.

### F‑1 — v9.2 findings

| # | v9.2 claim | Verification evidence in current source | Status |
|---|---|---|---|
| 1 | Startup jank from eager `IndexedStack` tabs fixed by lazy tab building | `lib/views/shared/main_navigation_view.dart` builds only `_visitedTabs`, otherwise `SizedBox.shrink()` | **Fixed** |
| 2 | `LocalPreferencesService.init()` removed from the startup path | `lib/main.dart` `main()` contains only `ensureInitialized`, `Firebase.initializeApp`, `_activateAppCheck`, `runApp` (+ profiler marks); Theme/Layout self‑init via `..init()` | **Fixed** |
| 3 | `AuthGuard` re‑scheduled init callbacks on every rebuild | `_providerInitScheduled`, `_lastSyncedProfile` (identity check), `_ecosystemInitScheduled`; all reset in both the logout branch and the re‑login branch | **Fixed** — and the `_lastSyncedProfile` identity check (BUG‑9) is a genuine improvement over a one‑shot boolean |
| 4 | Teacher analytics duplicate loading (`Loaded …` ×3) | `TeacherAnalyticsProvider.loadAnalytics` returns `_loadGate.inFlight` when present; `hasData` short‑circuit; `LoadDedupe` present in `lib/utilities/load_dedupe.dart` | **Fixed** |
| 5 | Teacher analytics overlapping duplicate queries | `TeacherAnalyticsService.beginLoad()` clears 7 cached futures; `_studentDocs()`, `_resumeReviewDocs()`, `_applicationDocs()`, `_reviewCountsFuture`, `_studentDataFuture`, `_alumniCountFuture`, `_latestReviewByUserFuture` | **Fixed** — as a single scan per cycle |
| 6 | Per‑student N+1 review reads removed | `_latestReviewFor` derives from the shared scan via `pickLatestReviewPerUser`; no per‑student `orderBy` query remains | **Fixed** |
| 7 | 3 standalone `compensateStale*` jobs consolidated | `functions/index.js` exports only `compensateStaleAIQuotas`; `functions/schedulers/index.js` sweeps `["resumeReview","careerCoach","aiAnalysis"]` | **Fixed** (7 → 5 jobs) |
| 8 | `WatchStream … NOT_FOUND` listener leaks | Retained subscriptions + `dispose()` on `OpportunityProvider`, `AlumniDirectoryProvider`, `MentorshipProvider`, `PortfolioProvider`, `AlumniGroupChatProvider`; `ChatProvider` cancels its `Map<String, StreamSubscription>` in both `reset()` and `dispose()` | **Fixed in source**; runtime re‑verification still open — `docs/logs.md` predates the fix. **[RUNTIME-VERIFY]** |
| 9 | 32 analyzer issues cleared | Cannot be re‑verified as a count without running the analyzer; the code patterns the report names (`withOpacity` → `withValues`, `DropdownButtonFormField(value:)` → `initialValue:`) are not present in the files this audit read | **Cannot Verify** (reporting only) |
| 10 | Dead `notes_view_legacy.dart` removed | `lib/views/archived/` does not exist; `notesRoute` maps to `StudentDashboardView` | **Fixed** |
| 11 | Legacy quota mirrors kept (deprecate later) | `functions/ai/quota.js` still writes `config.legacyCollection` in the same transaction as the unified doc | **Not Fixed — intentional** (documented contract) |
| 12 | `ai_conversations` kept (deprecate later) | `askAI` no longer writes it; `deleteAIHistory` and `cleanupExpiredAIConversations` still reference it | **Not Fixed — intentional** |
| 13 | Release APK build deferred | v9.2.2 subsequently built it (§F‑2 #9) — and this audit found the build is debug‑signed (C‑1) | **Superseded** |
| 14 | Runtime logout→re‑login verification open | Still no post‑fix runtime log in the repository | **Not Fixed** (evidence gap, not a code gap) |
| 15 | On‑device frame profiling open | `lib/utilities/startup_profiler.dart` exists and is wired; no profile‑mode capture is recorded in `docs/` | **Partially Fixed** (instrumentation landed, capture outstanding) |

### F‑2 — v9.2.2 findings

| # | v9.2.2 claim | Verification evidence in current source | Status |
|---|---|---|---|
| 1 | Startup instrumentation added, no speculative Dart change | `lib/utilities/startup_profiler.dart` present; `main.dart` calls `start()`, `mark('firebase_init' \| 'app_check_activate' \| 'run_app' \| 'first_frame')`, `finish()` | **Fixed** |
| 2 | Client `RefreshDedupe` gate | `lib/utilities/refresh_dedupe.dart` present; `RecommendationService._refreshGate` consulted in `refreshRecommendations` with `inFlightFor` / `shouldRun` / `record` / `resetRefreshState` | **Fixed in isolation** — but see D‑1: the server‑side chain makes the *server* fingerprint thrash | **Partially Fixed** |
| 3 | Client fingerprint excludes `metadata.updatedAt` | `recommendation_fingerprint.dart` `recommendationFingerprintKeys` omits `metadata`; documented | **Fixed** (with the E‑4 portfolio caveat) |
| 4 | Server fingerprint + `force` + stored on `recommendations_meta/summary` | `functions/recommendations/refresh.js`: `computeRecommendationFingerprint`, `RECOMMENDATION_ENGINE_VERSION = 2`, skip requires `!force && fingerprintUnchanged && hasMaterializedSet && !expired`, fingerprint written to the meta doc | **Fixed** — but defeated in the resume‑review path by D‑1 | **Partially Fixed** |
| 5 | Resume Review provider redundant read removed | `lib/views/dashboards/teacher_dashboard_view.dart` history refresh is now guarded on `historyInitialized` / `isLoadingHistory` | **Fixed in the caller**; note the provider still fires `_loadHistory()` fire‑and‑forget inside `initWithUser`, so `historyInitialized` is false for a window after login | **Fixed** |
| 6 | Flattened portfolio migration implemented | `lib/services/firestore/portfolio_migration.dart` + `PortfolioService.migrateFlattenedPortfolio` + `PortfolioProvider.initWithUser` handling of `migrated`/`failed`/`notApplicable` | **Fixed** — and `hasFlattenedPortfolioShape` correctly left as the offline fallback signal (now dead, E‑15/E‑8) |
| 7 | App Check diagnosis | `main.dart` matches the described provider selection | **Fixed as a diagnosis**; the underlying Console action is still outstanding (C‑2) |
| 8 | GMS/emulator noise classified | `docs/logs.md` frames remain inside `com.google.android.gms` only | **Fixed as a classification** |
| 9 | Tests all green (476 Flutter / 50 Functions) | The 4 new Dart suites and 1 new Functions suite named in the report are present in `test/` and `functions/test/` | **Cannot Verify** as counts without executing the suites (this audit was source‑only by design) |
| 10 | Release APK built (56.7 MB) | Gradle config now audited: the release type is **debug‑signed** (C‑1) | **Partially Fixed** — it builds, but not shippably |
| 11 | On‑device profile capture outstanding | No capture recorded | **Not Fixed** (evidence gap) |
| 12 | Orphaned flattened keys left inert when a nested map exists | `planPortfolioMigration` returns `null` when `data['portfolio'] is Map` — confirmed, deliberate | **Not Fixed — intentional, safe** |
| 13 | `RefreshDedupe` is process‑scoped | `RefreshDedupe` holds only in‑memory state; `invalidate()` on logout | **Fixed as documented** |
| 14 | `RECOMMENDATION_ENGINE_VERSION` must be bumped on engine change | Present as a named constant with the comment; current value `2` | **Fixed as documented** |

### F‑3 — Net movement since v9.2

| | v9.2 | v9.2.2 | v9.2.3 (this audit) |
|---|---|---|---|
| Scheduler jobs | 7 → 5 | 5 | 5 — no change needed |
| Teacher analytics scans per load | 9 overlapping | 1 per query | 1 per query, **still unbounded** |
| Recommendation regenerations per login (unchanged profile) | 2 | 1 | 1 — **but 2 per resume review** (D‑1) |
| `resumeReviews` reads on teacher open | 2 | 1 | 1 |
| Listener leaks | fixed | fixed | fixed |
| Release artifact shippable? | not built | built, **debug‑signed** | **still debug‑signed (C‑1)** |
| App Check enforced? | no | no | **no (C‑2)** |
| Unbounded queries | 4 known | 4 known | **12 enumerated (D‑4…D‑6, E‑1, E‑2, E‑11)** |

**Conclusion:** every v9.2/v9.2.2 code change that was claimed is present in the source. No regression was found. The two items the earlier reports explicitly deferred (release signing, App Check enforcement, runtime re‑verification) are still outstanding, and this audit adds a materially larger boundedness/release‑readiness workstream on top.

---
## G. Performance Opportunities

Each item is classed as **confirmed** (a concrete cost is paid on a normal user action) or **profiling-required** (plausible but no runtime trace exists).

### G-1 — Confirmed

| # | Area | Finding | Mechanism | Current cost | Improvement |
|---|---|---|---|---|---|
| G-1.1 | Teacher analytics | `collectionGroup('resumeReviews').get()` and `collectionGroup('applications').get()` load the entire collection group into the teacher's device | `TeacherAnalyticsService._resumeReviewDocs()` / `_applicationDocs()` — plain `.get()`, no `where`, no `limit`, no ordering | O(all reviews) + O(all applications) reads and bytes **per analytics open**, then filtered in memory | Server-side aggregation into a materialised per-teacher/per-department summary, or at minimum scope with `where('department','==',teacherDept)` + `limit` + pagination |
| G-1.2 | Alumni directory | `getFilterOptions()`, `getFeaturedAlumni()`, `getAlumniStats()` are unbounded scans of `users where role=='alumni'` | `AlumniDirectoryService` | 3 full alumni scans + `getAlumniDirectory(limit 100)` + `getRecentAlumni(limit 10)` on **one** directory open (Ã—2 if `startListeningToAlumniUpdates` runs) | Derive filter options from the already-fetched page; compute counts on the server and cache in a materialised doc |
| G-1.3 | Opportunities | `getUniqueCompanies()`, `getUniqueLocations()`, `getPopularSkills()` each re-read every active opportunity | `OpportunityService.loadFilterOptions()` | 3 full active-opportunity scans + `getActiveOpportunities(limit 50)` + `getRecentOpportunities(limit 10)` per screen open | Build the option sets from the 50â€‘item page; persist a `opportunity_facets` materialised doc refreshed by a trigger |
| G-1.4 | Chat | `getMessagesStream(chatId)` is unordered/unbounded | `ChatService` | Every message ever sent in the chat is streamed, retained and reâ€‘rendered on every open; a rebuild on each new message | `orderBy('timestamp', descending: true).limit(N)` + reverse in memory, or paginate backwards |
| G-1.5 | Group chat | `AlumniGroupChatService.getMessagesStream()` unbounded | same | Single shared stream that grows for the lifetime of the app; every alumni sees every message ever posted | Cap with `limit` + `startAfter` pagination |
| G-1.6 | Notes | `NotesService.getAllNotes()` unbounded, unpaginated | same | All notes loaded at once | Paginate / `limit` |
| G-1.7 | Notifications | `markAllAsRead()` / `deleteReadNotifications()` read every matching doc, no `limit` | `NotificationService` | A longâ€‘lived user accumulates thousands of notification docs; "mark all read" reads + writes them all in one pass (and risks the 500â€‘write batch cap) | Bound the query + chunked batches |
| G-1.8 | Placement apply | Client `.timeout(const Duration(seconds: 30))` vs server callable `timeoutSeconds: 120` and a Storage copy + `getSignedUrl` before the transaction | `PlacementsProvider.applyForPlacement` vs `logPlacementApplication` | A slowâ€‘butâ€‘successful apply (>30 s) is reported as a failure and the optimistic "applied" state is rolled back â†’ user retries â†’ duplicateâ€‘attempt confusion | Raise the client timeout to match the server, or make the copy/URL step asynchronous and off the critical path |
| G-1.9 | AI chat | 3 `ai_interactions` writes per exchange (see Dâ€‘3) | `ai/chat.js` (2) + `AIChatProvider` (1) | 50 % more writes than needed, and two schema variants | Remove the clientâ€‘side mirror write; keep the server as the single writer |
| G-1.10 | Placement application | 2 writes per application (`applications/{uid}_{placementId}` **and** `placements/{id}/applications/{uid}`) | `placements.js` transaction | Double writes, plus the `applications` collectionâ€‘group query returns both copies and the client has to deâ€‘duplicate in memory | Keep one canonical location and derive the other view serverâ€‘side |
| G-1.11 | Quota | Every AI quota operation writes the unified doc **and** a legacy mirror doc in the same transaction | `functions/ai/quota.js` | 2Ã— writes per AI call for a compatibility path with no remaining consumer | Retire the legacy mirror after a migration window |
| G-1.12 | Chat send | `ChatService.sendMessage` performs an extra `chatRef.get()` before the write | `ChatService` | One extra read per message | Fold the check into the trigger or use a mergeâ€‘write |
| G-1.13 | Chat trigger | `onChatMessageCreated` reads the parent `chats/{chatId}` on every message | `functions/triggers/chat.js` | One extra read per message | Cache or denormalise the participant list onto the message |
| G-1.14 | Activity feed | `ActivityFeedProvider` aggregates 5 sources on **every** `notifyListeners()` from any of them, with no debounce, and the aggregation runs synchronously in the constructor | `lib/providers/activity_feed_provider.dart` | O(5) rebuild + sort on every notification from notifications/engagement/placements/mentorship/recommendations providers | Debounce (e.g. 250 ms) and drop the constructor call |
| G-1.15 | Activity feed after logout | `reset()` does not set `_isDisposed`, so the aggregation keeps running | same | Wasted work while the user is logged out | Set the flag in `reset()` (as the other providers do) |
| G-1.16 | Profile save | Every qualifying `users/{uid}` write fires `onProfileUpdatedRefreshAI` â†’ `logUserActivity("profileUpdated", 3)` + `recomputeEngagementSummary` (a read + a write) | `functions/triggers/profile.js` | Repeated profile edits repeatedly write the engagement summary and award points | Award the points at most once per day (idempotency key on date), skip the recompute when the summary already reflects today |
| G-1.17 | Recommendation refresh | One refresh loads up to 200 alumni + 200 opportunities + 200 placements (6 parallel queries) and then AIâ€‘enriches the top 5 | `functions/recommendations/refresh.js` | ~600 reads + 1 AI call per genuine change; **2 concurrent unrelated refreshes per resume review** (Dâ€‘1) | Raise the fingerprint coverage, and serialise the two trigger paths behind a single entry point |
| G-1.18 | Startup | `StartupProfiler` is wired but never captured; unknown firstâ€‘frame cost | `lib/utilities/startup_profiler.dart` | Unknown | Capture a profileâ€‘mode run (see G-2) |

### G-2 — Profiling required (not proven)

* Firstâ€‘frame / startup time â€” instrumentation exists (`StartupProfiler`), no capture is committed to `docs/`.
* Chat scroll performance with a very long history (unbounded stream G-1.4 is the likely cause; unproven without a trace).
* Portfolio render cost with large documents/PDFs.
* `IndexedStack` memory footprint after all tabs are visited.
* Whether `activity_feed_provider` rebuilds actually show up in the frame timings (G-1.14 is a codeâ€‘level certainty; the userâ€‘visible effect is not measured).

No monetary saving is claimed anywhere in this document.

---

## H. Firebase Cost Opportunities

Impact is expressed as a **read/write/functionâ€‘invocation multiplier**, not currency.

| # | Source | Extra unit cost | Trigger frequency | Impact |
|---|---|---|---|---|
| H-1 | `applications` dual write | 1 extra write per application + duplicate rows in the `applications` collectionâ€‘group read | Per apply | Medium |
| H-2 | Legacy quota mirrors | 1 extra write per AI call | Per AI call | Medium |
| H-3 | Triple `ai_interactions` write | 2 extra writes per chat exchange | Per message | Medium |
| H-4 | `onResumeReviewCreatedRefreshMatches` â†’ userâ€‘doc write â†’ `onProfileUpdatedRefreshAI` â†’ **second** `refreshRecommendationsForStudent` | 2 concurrent refreshes, ~600 reads each, plus full reâ€‘write of the recommendation set and the `recommendations_meta` doc | Per resume review | High |
| H-5 | Unbounded `collectionGroup` scans in teacher analytics | O(all reviews + all applications) reads per analytics open | Per analytics open | High (scales with total data) |
| H-6 | Unbounded alumni/opportunity facet scans | 6 full scans across two screens | Per screen open | High (scales with data) |
| H-7 | Unbounded chat/notes streams | O(all messages) initially + 1 read per new message | Continuously while open | High (scales with data) |
| H-8 | `analytics_events` appendâ€‘only, no retention job | 1 write per AI message + per placement view, never pruned | Per event | Medium (monotonic growth) |
| H-9 | `logUserActivity` on every qualifying profile write | 1 transaction on the engagement summary + 3 points | Per profile save | Medium |
| H-10 | `maybeCreateNotification` inside recommendation refresh | 1 query per notification, up to 2 notifications | Per refresh | Low |
| H-11 | Scheduler: 5 jobs | Fixed invocation cost | Daily/weekly | Low |
| H-12 | `autoExpireOpportunities` accumulates every expired opportunity into **one** batch | Batch size > 500 will throw and the whole sweep fails | Daily | Medium (correctness + retry cost) |
| H-13 | `sendInactivityReminders` unbounded `where('lastMessageAt','<',cutoff)` + perâ€‘participant query+write | O(chats) + O(participants) per run | Daily | Medium |

**Consolidation candidates:** H-1, H-2, H-3 are pure duplication and can be removed without behaviour change. H-4 is the highestâ€‘value fix because it both removes cost **and** fixes the fingerprintâ€‘thrash correctness defect.

---

## I. Security Findings

### I-1 — Firestore rules (`firestore.rules`)

| # | Check | Result |
|---|---|---|
| 1 | Default deny | `match /{document=**} { allow read, write: if false; }` is present as the fallback |
| 2 | `users/{uid}` owner scoping | Ownerâ€‘only read/write; `role`, `isVerified`, and serverâ€‘generated fields are guarded on update |
| 3 | Recursive wildcards | `users/{uid}/**` subcollection rules restrict to the owner; no blanket `allow` on `{document=**}` |
| 4 | Role checks | `isTeacher()`, `isAdmin()` helpers read the caller's `users/{uid}.role` |
| 5 | Serverâ€‘only documents | `recommendations_meta`, `engagement_summary`, the AI quota docs and `analytics_events` are `allow read, write: if false` (Admin SDK only) |
| 6 | Fieldâ€‘level protection | `isValidPlacementData`, `isValidOpportunityData` etc. validate types on create/update |
| 7 | Privilege escalation | Role is not writable by the client (guarded), and `profileCompleted`, `isVerified` are server/teacher controlled |
| 8 | Dead rules | `ai_insights` and `announcements` rules exist with **no** writer/reader anywhere in the repo (see Kâ€‘3) |
| 9 | `recommendations_meta/summary` fingerprint tampering | The doc is `if false` for clients, so the fingerprint cannot be spoofed by a client â€” **but** see Dâ€‘1 for serverâ€‘side thrash |

### I-2 — Storage rules (`storage.rules`)

| # | Check | Result |
|---|---|---|
| 1 | Resume ownership | `resumes/{uid}` gated on `request.auth.uid == uid` |
| 2 | Resume read by teacher/reviewer | The review flow copies the resume serverâ€‘side (Admin SDK) rather than loosening Storage rules |
| 3 | Portfolio / academic docs | Ownerâ€‘scoped |
| 4 | MIME/size | `contentType` and `size` limits are enforced per path |
| 5 | Orphan files | Deletion is clientâ€‘initiated; no reconciliation job exists (Kâ€‘5) |

### I-3 — Cloud Functions

| # | Check | Result |
|---|---|---|
| 1 | Callable authentication | Every callable uses `request.auth?.uid` and throws `unauthenticated` when absent |
| 2 | Authorization | `updateApplicationStatus` and teacher analytics paths reâ€‘read the caller's role serverâ€‘side (`_getUserRole`) rather than trusting the client |
| 3 | Admin SDK usage | Confined to the Functions runtime |
| 4 | Parameter validation | Placement/opportunity/AI inputs are validated and lengthâ€‘capped |
| 5 | Serverâ€‘only operations | Quota reservation, recommendation materialisation, storage copy and notification creation are all serverâ€‘side |
| 6 | Abuse / quota manipulation | Quota lives in `if false` docs written by transactions serverâ€‘side; a client cannot grant itself quota |
| 7 | **Defect** | `functions/ai/deepAnalysis.js` detects an `HttpsError` with `if (error.code && error.httpErrorCode) throw error;` instead of `instanceof admin.functions.https.HttpsError`. It is *functional* (an `HttpsError` does expose both properties) but inconsistent with `placements.js`/`refresh.js` and fragile â€” a nonâ€‘Firebase error that happens to carry both properties would escape unwrapped, and a reâ€‘wrapped `not-found` becomes `internal` |
| 8 | **Defect** | `cors: false` is set on `logPlacementView`, `logPlacementApplication` and `updateApplicationStatus`, while `web/` and a web App Check key exist. A Flutter **web** build would be blocked by CORS on those three callables. The mobile targets are unaffected |

### I-4 — App Check

* Provider selection and debugâ€‘token handling are wired in `lib/main.dart` (matching the v9.2.2 diagnosis).
* **Enforcement is a Firebase Console action and is not enabled.** `docs/logs.md` shows persistent `403 App attestation failed` / `Too many attempts` and the SDK falling back to placeholder tokens. Until the debug token is allowâ€‘listed and enforcement is switched on for Firestore/Storage/Functions, the tamper protection the code intends to provide does not exist at runtime. This is the Câ€‘2 finding.
* Release configuration: no separate release App Check provider was found beyond the documented selection; this needs a releaseâ€‘device verification pass (M).

### I-5 — Authentication

* Passwords are handled entirely by Firebase Auth; no credential material is stored clientâ€‘side.
* Email verification and `AuthGuard` are present and reset correctly on both logout and reâ€‘login (see F).

---

## J. Testing Gaps

### J-1 — Existing suites (from `test/` and `functions/test/`)

Flutter: 47 suites including `auth_regression_test.dart`, `recommendation_fingerprint_test.dart`, `refresh_dedupe_test.dart`, `portfolio_migration_test.dart`, `security_rules_mirror_test.dart`, `resume_quota_reservation_test.dart`, `teacher_analytics_load_dedupe_test.dart`, `startup_profiler_test.dart`, and the AI/placement/portfolio suites.

Functions: `engagement_activity.test.js`, `placement_transitions.test.js`, `quota.test.js`, `recommendations_refresh_dedupe.test.js`, plus the shared `firestore_fake.js`.

### J-2 — Coverage matrix (Feature â†’ existing test â†’ important missing scenario â†’ priority)

| Feature | Existing test | Important missing scenario | Priority |
|---|---|---|---|
| Auth lifecycle (login/load/logout/role switch/reâ€‘login) | `auth_regression_test.dart`, `auth_test.dart` | Full `login â†’ logout â†’ login as other role â†’ logout â†’ reâ€‘login` cycle asserting **no** stale provider state and **no** retained listeners | **High** |
| Eligibility rules | `security_rules_mirror_test.dart` (mirrors docs) | A test that fails when the **client** engine diverges from the **server** engine (the Dâ€‘2 `programs`/`branches` divergence is currently untested) | **High** |
| Resume review â†’ recommendations | `recommendations_refresh_dedupe.test.js` | The `onResumeReviewCreatedRefreshMatches` â†’ `onProfileUpdatedRefreshAI` **doubleâ€‘refresh** chain and the resulting fingerprint thrash (Dâ€‘1) | **High** |
| Recommendation refresh idempotency | `recommendations_refresh_dedupe.test.js` | Two concurrent refreshes with different fingerprints must not both materialise / must converge | **High** |
| Placement apply timeout | `placement_application_guards_test.dart` | Client/server timeout mismatch behaviour (slow success must not look like a failure) | **Medium** |
| Teacher analytics boundedness | `teacher_analytics_load_dedupe_test.dart`, `teacher_analytics_latest_review_test.dart` | A regression test that **fails if the analytics load becomes unbounded** (i.e. an assertion that a `limit` is applied) | **Medium** |
| Chat stream boundedness | `alumni_group_chat_test.dart` | A test asserting the message stream is `limit`ed | **Medium** |
| `autoExpireOpportunities` batch size | none | >500 expired opportunities must be chunked, not one batch | **Medium** |
| AI quota envâ€‘vsâ€‘literal consistency | `quota.test.js`, `resume_quota_reservation_test.dart` | Assert the clientâ€‘displayed limit equals the serverâ€‘enforced limit from the same source | **Medium** |
| AI provider fallback / malformed response | `ai_provider_fallback_test.dart`, `ai_response_formatting_test.dart` | Timeoutâ€‘thenâ€‘fallback with a partial/streamed malformed body | **Medium** |
| App Check debugâ€‘token path | none | A test/assertion that the debug provider is used only in debug builds | **Low** |
| Deadâ€‘callable guard | none | `AIInsightsService` calls `generatePlacementInsight`, which does not exist (Kâ€‘1). A contract test that every `httpsCallable` name the client uses is exported by `functions/index.js` | **Low** (becomes High if the AIâ€‘insight path is ever reâ€‘enabled) |
| Portfolio migration | `portfolio_migration_test.dart` | Migration reâ€‘run idempotency across sessions | **Low** |
| Startup profiler | `startup_profiler_test.dart` | â€” | Low |

### J-3 — Structural gaps

* No automated **rules** tests (only a mirror test that checks docsâ†”client, not rulesâ†”intent).
* No **contract test** binding the client's callable names to `functions/index.js` exports.
* No **boundedness** test for any Firestore query (the highestâ€‘value single addition for preventing G/H regressions).

---

## K. Technical Debt

### K-1 — Dead code (confirmed: name appears only at its own definition)

| Symbol | File | Note |
|---|---|---|
| `AIInsightsService` + `AIPlacementInsight` path | `lib/services/ai/ai_insights_service.dart` + view | Calls a **nonâ€‘existent** callable `generatePlacementInsight`; whole subsystem unreachable |
| `NotificationsService.getUnreadCount` | notification service | no caller |
| `NotificationsService.notifyStatusChange` | notification service | no caller |
| `NotificationsProvider.addNotification` | `lib/providers/notifications_provider.dart` | no caller |
| `ChatService.deleteChat`, `getChatByMentorshipId`, `getChatBetweenUsers`, `getTotalUnreadCount` | chat service | no callers |
| `OpportunityService.getOpportunitiesByDateRange`, `cleanupExpiredOpportunities` | opportunity service | no callers |
| `MentorshipService.searchRequests`, `deleteRequest` | mentorship service | no callers |
| `AlumniDirectoryService.getAlumniByCompany` / `getAlumniByGraduationYear` / `getAlumniByDepartment` (+ the matching provider wrappers) | alumni directory service/provider | no callers |
| `PlacementsService.getPlacementsByCompany` (+ provider wrapper) | placements service/provider | no caller |
| `PortfolioService.hasFlattenedPortfolioShape` | portfolio service | superseded by `migrateFlattenedPortfolio`; retained only as the offline fallback signal |

### K-2 — Duplicated constants (magic values)

* `DAILY_MESSAGE_LIMIT = 50` is hardcoded in `functions/ai/chat.js` **and** read from `process.env.DAILY_MESSAGE_LIMIT || "50"` in `functions/ai/quota.js` â€” two sources of truth inside the server, plus a third literal in `lib/providers/ai_usage_provider.dart` (`_dailyLimit = 50`).
* `RESUME_MONTHLY_LIMIT = 5` hardcoded in `functions/ai/resumeReview.js`, in `quota.js` via env, and in `lib/providers/resume_review_provider.dart`.
* If the environment variable ever changes, the clientâ€‘displayed quota silently diverges from the enforced quota.

### K-3 — Dead rules / dead collections

* `firestore.rules` declares rules for `ai_insights` and `announcements`; neither collection has any writer or reader in the repository.
* `ai_conversations` is still referenced by `deleteAIHistory` and `cleanupExpiredAIConversations`, but `askAI` no longer writes it â€” each delete pays a query against an empty collection. Intentional transition debt.

### K-4 — Structural / naming inconsistencies

* Two widget trees: `lib/widgets/` and `lib/views/widgets/`.
* 40+ rootâ€‘level version markdown files (`V5_*`, `V6_*`, `V7_*`, `VERSION_*`, `v9_2_audit_report.md`, `FILES_CREATED.md`, `FIX_APPLY_*.md`, `*_IMPLEMENTATION_*.md`) clutter the repository root; the task's own report belongs under `docs/`.
* `lib/views/archived/` was removed (good), but the archivedâ€‘code convention is not documented anywhere.

### K-5 — Other debt

* No Storageâ†”Firestore orphan reconciliation job (see Iâ€‘2 #5).
* `analytics_events` is appendâ€‘only with no retention (Hâ€‘8).
* `docs/logs.md` is stale (captured on build `9.1.2+99`, while `pubspec.yaml` is `9.2.2+100`) â€” runtime evidence in the repo predates the current source.
* `docs/v9_2_2_investigation_report.md` header still states version `9.1.2+99`, which contradicts the optimization report and `pubspec.yaml`.

---

## L. Recommended Roadmap

Grouped so that no large dependency upgrade is mixed with unrelated bug fixes (per Â§18 Controlled Upgrade Rule). **Nothing in this section is implemented by this audit.**

### v9.2.3 â€” Correctness & security

1. **Câ€‘1** Replace the debug signing config with a real release keystore (Play upload key).
2. **Câ€‘2** Allowâ€‘list the App Check debug token and enable enforcement in the Console for Firestore, Storage and Functions; verify on a release device.
3. **Dâ€‘1** Break the `resumeReview` â†’ `userâ€‘doc` â†’ `profile` trigger chain: either have `onResumeReviewCreatedRefreshMatches` write the resume counters with a **field mask that does not trigger** `onProfileUpdatedRefreshAI` (e.g. write to a subcollection and denormalise on read), or make `onProfileUpdatedRefreshAI` ignore resumeâ€‘counterâ€‘only changes; then ensure a single refresh writer owns the fingerprint.
4. **Dâ€‘2** Align the client `EligibilityEngine` with the server `checkMandatoryEligibility` (`programs`/`branches` mutual exclusivity) and update `docs/eligibility_rules.md`.
5. **Iâ€‘3 #7** Make `deepAnalysis.js` use `instanceof` for `HttpsError`.
6. **Dâ€‘3** Remove the clientâ€‘side `ai_interactions` mirror write so the server is the single writer with one schema.
7. **Hâ€‘12** Chunk `autoExpireOpportunities` batches at 500.
8. **Gâ€‘1.8** Raise the apply client timeout to match the server.

### v9.2.4 â€” Performance & cost

1. **Dâ€‘4/Dâ€‘5/Dâ€‘6, Gâ€‘1.2/Gâ€‘1.3** Bound every enumerated unbounded query (teacher analytics collection groups, alumni facets, opportunity facets, notifications).
2. **Gâ€‘1.4/Gâ€‘1.5/Gâ€‘1.6** Paginate chat, group chat and notes streams.
3. **Hâ€‘1** Collapse the dual `applications` write to one canonical location.
4. **Hâ€‘2** Retire the legacy quota mirrors after a migration window.
5. **Gâ€‘1.16** Make the profileâ€‘update points/recompute idempotent per day.
6. **Gâ€‘1.14/Gâ€‘1.15** Debounce the activity feed and fix its `reset()`.
7. **Hâ€‘8** Add an `analytics_events` retention job.
8. **Gâ€‘1.13/Gâ€‘1.12** Remove the extra perâ€‘message reads in chat send/trigger.

### v9.2.5 â€” Reliability & test hardening

1. **Jâ€‘2** Add the highâ€‘priority regression tests (auth cycle, eligibility clientâ†”server parity, doubleâ€‘refresh, concurrent refresh convergence).
2. Add a **callable contract test** (client names âŠ† `functions/index.js` exports) to prevent the Kâ€‘1 class of defect.
3. Add **boundedness assertions** to the query layer.
4. **Kâ€‘1/Kâ€‘3** Remove confirmed dead code and dead rules.
5. Capture a startup profile and a postâ€‘fix logoutâ†’reâ€‘login runtime log (closes the v9.2/v9.2.2 evidence gaps).
6. **Kâ€‘2** Unify quota constants behind one server source and surface it to the client.

### v9.2.6 â€” Toolchain & dependency currency (Â§18)

Controlled, groupâ€‘byâ€‘group upgrade with a full test + analyze + APK + deployâ€‘validation gate after each group (see Â§N).

---

## M. Final Ship Readiness Assessment

Objective state of the application against the sequence `v9.3 UI/UX redesign â†’ v9.4 final QA/security/device compatibility â†’ v9.5 production release`.

### M-1 — What is ready

* The **v9.2/v9.2.1/v9.2.2 code changes are all present in source**; no regression was found (Â§F). The architecture (UI â†’ Provider â†’ Service â†’ Firebase â†’ Firestore/Storage) is internally consistent.
* Authentication, authorization, the rules layers, quota reservation/rollback and the AI fallback chain are implemented and coherently structured.
* Listenerâ€‘leak and duplicateâ€‘initialisation fixes from v9.2 are in place.
* The recommendation architecture is unified (one engine, one materialised set, one fingerprint) and is respected by the Flutter consumer.
* The test suite is broad (47 Flutter suites + 5 Functions suites) and the items the earlier reports deferred are explicitly documented.

### M-2 — What blocks a shippable release today

1. **Release signing is the debug keystore (Câ€‘1)** â€” cannot go to the Play Store.
2. **App Check is not enforced (Câ€‘2)** â€” the security posture the app believes it has does not exist at runtime.
3. **Recommendation trigger chain / fingerprint thrash (Dâ€‘1)** â€” a correctness defect that also doubles recommendation cost on every resume review.
4. **Client/server eligibility divergence (Dâ€‘2)** â€” a placement can be judged differently by the UI and the engine.
5. **Twelve unbounded queries (Dâ€‘4â€¦Dâ€‘6, G)** â€” they are correct today only because the dataset is small; they are the main scalability cliff.
6. **No automated rules or callableâ€‘contract tests** â€” the two classes of defect this audit found (dangling callable, rules/collection drift) are exactly what those tests would catch.

### M-3 — Sequence to production

1. **v9.2.3** (correctness & security) â€” closes Câ€‘1, Câ€‘2, Dâ€‘1, Dâ€‘2. This is the minimum set of *defects* and the prerequisite for any release.
2. **v9.2.4** (performance & cost) â€” bounds the enumerated queries and removes the duplicated reads/writes. Required before a largeâ€‘dataset demo or any realâ€‘world load, not before a small pilot.
3. **v9.2.5** (reliability & tests) â€” locks the fixes in with regression coverage and clears the dead code.
4. **v9.3** (UI/UX redesign) â€” explicitly out of scope for this audit; nothing here blocks it.
5. **v9.4** (final QA / security / device compatibility) â€” needs the runtime captures that are still missing (startup profile, postâ€‘fix logout/reâ€‘login log, releaseâ€‘device App Check, Android 16/API 36 smoke test).
6. **v9.2.6 / v9.4.x** (dependency currency) â€” must land **before** the release freeze but **after** the correctness fixes, one group at a time.
7. **v9.5** (production release) â€” reachable once Câ€‘1, Câ€‘2, Dâ€‘1 and Dâ€‘2 are fixed and v9.4's runtime evidence exists.
---

## N. Toolchain, SDK & Dependency Currency Audit (Task §18)

### N-1 — Measured toolchain versions

| Component | Installed / project‑pinned | Evidence | Current stable | Class |
|---|---|---|---|---|
| Flutter SDK | **3.38.5** (stable channel), revision `f6ff1529fd`, 2025‑12‑11 | `flutter --version` | 3.38.x stable line | **Up to date** |
| Dart SDK | **3.10.4** | `dart --version`; `pubspec.yaml` → `environment: sdk: ^3.10.4` | 3.10.4 | **Up to date** |
| Flutter channel | stable | `flutter --version` | — | **Keep** |
| Node.js (local dev) | **v24.12.0** | `node --version` | 24.x LTS line | see N‑2 |
| Node.js (deployed runtime) | **22** | `functions/package.json` → `"engines": { "node": "22" }` | 22 LTS | **Keep pinned** (see N‑2) |
| npm | **11.6.0** | `npm --version` | 11.x | **Up to date** |
| `firebase-functions` | **5.1.1** installed (`^5.0.0` declared) | `npm ls`; `package.json` | **7.4.0** | **Update recommended after testing** (see N‑4) |
| `firebase-admin` | **12.7.0** installed (`^12.0.0` declared) | `npm ls`; `package.json` | **14.5.0** | **Update recommended after testing** (see N‑5) |
| `pdf-parse` | **1.1.4** installed (`^1.1.1` declared) | `npm ls`; `package.json` | **2.4.5** | **Breaking‑change / migration required** (see N‑6) |
| Android Gradle Plugin / Gradle / Kotlin / JDK | Pinned in `android/settings.gradle.kts`, `android/gradle/wrapper/`, `android/app/build.gradle.kts` | audited — see N‑7 | — | **Keep pinned for compatibility** |
| Firebase CLI | not version‑pinned in the repo | no `firebase.json` `tools` key | latest | **Use latest** |
| `firebase.json` functions runtime | not declared → governed by `engines.node` | `firebase.json` has no `functions.runtime` | — | consistent with Node 22 |

### N‑2 — Node.js runtime: local dev (v24) vs deployed (v22)

`functions/package.json` declares `"engines": { "node": "22" }`, so Cloud Functions deploys onto the **Node 22** runtime, while the developer machine runs **Node v24.12.0**. This is **not a deployment defect** (Firebase uses the declared engine; the local version only matters for the emulator and `npm test`), but it is a genuine *local/production runtime mismatch*: a feature that behaves differently on Node 24 (e.g. a changed built‑in, a stricter parser, an experimental API) would pass locally and fail in production. Recommended handling: either install Node 22 locally for Functions work, or add an `"engines"`‑aware `nvm`/`.nvmrc` marker. Classified **Low** — no evidence of an actual behavioural difference was found in the modules audited.

### N‑3 — `firebase-functions` compatibility verification (the warning the brief asks about) 

The CLI's outdated‑version warning refers to `firebase-functions@5.1.1` against **7.4.0**. Verified directly from the npm registry (`npm view`), not from assumption:

| Package | Version | `engines.node` | `peerDependencies` |
|---|---|---|---|
| `firebase-functions` | **7.4.0** (latest) | `>=18.0.0` | `firebase-admin: ^11.10.0 \|\| ^12.0.0 \|\| ^13.0.0 \|\| ^14.0.0`; plus optional GraphQL/Apollo peers |
| `firebase-functions` | 6.0.0 | `>=14.10.0` | — |
| `firebase-admin` | **14.5.0** (latest) | `>=22` | — |
| `firebase-admin` | 12.7.0 (installed) | (older range) | — |
| `pdf-parse` | **2.4.5** (latest) | `>=20.16.0 <21 \|\| >=22.3.0` | — |

**Conclusions (each evidence‑backed):**

1. **Upgrading `firebase-functions` to 7.4.0 is safe against the Node 22 runtime** — its engine requirement is `node >= 18`, and the deployed runtime is 22. It is *also* safe against the currently‑installed `firebase-admin@12.7.0`, because v7's peer range explicitly includes `^12.0.0`. **The two upgrades are independent**: `firebase-functions` can move to 7.x without simultaneously moving `firebase-admin` — but v7's peer range stops at `^14.0.0`, so if `firebase-admin` is later moved to 15.x the pair must be re‑checked together.
2. **All Cloud Functions in this project use the v2 API** — verified: `require("firebase-functions/v2/https")` in `ai/chat.js` and `placements.js`, `…/v2/scheduler` in `schedulers/index.js`, `…/v2/firestore` in `triggers/index.js`. The v2 surface is the actively‑maintained one in v6/v7, so the *import style* is not a breakage source. However `firebase-functions` 5→6→7 is a **two‑major jump**, so it still requires dedicated regression testing (emulator run of every trigger/scheduler signature, especially the `onDocumentWritten`/`onDocumentCreated` event‑object shape and the scheduler `onSchedule` signature).
3. **`firebase-admin` 12 → 14 requires Node ≥ 22** (`engines.node >= "22"`), which the deployed runtime satisfies — so it is *runtime‑compatible*. It is still a two‑major jump that must be tested (Admin SDK API removals across 12→13→14), and it should be upgraded **after** `firebase-functions` is confirmed green, or together in one tested group.
4. **`pdf-parse` 1.1.4 → 2.4.5 is a breaking API change and a runtime‑floor change.** Its `engines` is `>=20.16.0 <21 || >=22.3.0` — satisfied by Node 22 (≥22.3) and by the local Node 24, but **not** by Node 20.16‑to‑20.x only. Version 2 is a rewrite (the v1 default‑export `pdf(dataBuffer)` call is replaced by a class/ESM‑friendly API), so `ai/resumeReview.js`, which calls `pdf-parse`, must be migrated and re‑tested against real PDFs. Classified **Breaking‑change / migration required**.

### N‑4 — Flutter dependency currency (`flutter pub outdated`)

**Direct dependencies:**

| Package | Current | Resolvable | Latest | Class |
|---|---|---|---|---|
| `firebase_core` | 4.3.0 | 4.15.0 | 4.15.0 | **Safe update** (same major, Firebase BOM‑aligned) |
| `firebase_auth` | 6.1.3 | 6.7.0 | 6.7.0 | **Safe update** |
| `firebase_analytics` | 12.1.0 | 12.6.0 | 12.6.0 | **Safe update** |
| `cloud_firestore` | 6.1.1 | 6.10.0 | 6.10.0 | **Safe update** |
| `cloud_functions` | 6.0.5 | 6.5.0 | 6.5.0 | **Safe update** (note: pulls `cloud_functions_platform_interface` 5.8.8 → 6.0.7, a platform‑interface major — test callable wiring) |
| `firebase_storage` | 13.0.5 | 13.6.0 | 13.6.0 | **Safe update** |
| `firebase_app_check` | 0.4.1+3 | 0.4.8 | 0.4.8 | **Safe update** (relevant to C‑2; verify the debug‑token flow after) |
| `intl` | 0.20.2 | 0.20.3 | 0.20.3 | **Safe update** |
| `shared_preferences` | 2.5.4 | 2.5.5 | 2.5.5 | **Safe update** |
| `provider` | ^6.1.2 | up to date | — | **Up to date** |
| `http` | ^1.2.0 | up to date | — | **Up to date** |
| `url_launcher` | ^6.2.0 | up to date at constraint | — | **Up to date** |
| `connectivity_plus` | 6.1.5 | 6.1.5 | **7.3.2** | **Breaking‑change / upgrade after testing** (7.x is a platform‑interface major) |
| `file_picker` | 8.3.7 | 8.3.7 | **13.1.0** | **Breaking‑change / upgrade after testing** (five majors; resume upload path must be re‑tested) |
| `fl_chart` | 0.69.2 | 0.69.2 | **1.2.0** | **Breaking‑change / upgrade after testing** (pre‑1.0 → 1.x rewrite; the Resume Intelligence Dashboard charts must be re‑verified) |
| `package_info_plus` | 8.3.1 | 8.3.1 | **10.2.2** | **Breaking‑change / upgrade after testing** (two majors) |
| `cupertino_icons` | 1.0.8 | 1.0.9 | **2.0.0** | **Safe update** (icon font only) |

**Dev dependencies:** all up to date (`flutter_lints 6.0.0` → 6.1.0 is an upgradable transitive‑level bump).

**Transitive:** 46 packages are locked to older resolutions in `pubspec.lock` but are upgradable within the current constraints by `flutter pub upgrade` (no `pubspec.yaml` edit). 8 are constrained below their resolvable version and require a `pubspec.yaml` edit.

### N‑5 — Upgrade plan (Task §18 "Upgrade Plan" table)

| Component | Current | Latest Stable | Update? | Compatibility | Risk | Migration Required | Recommendation |
|---|---|---|---|---|---|---|---|
| `firebase-functions` | 5.1.1 | 7.4.0 | **Yes** | Node ≥18 ✓ (runtime 22); `firebase-admin ^12` ✓ | Medium | Two‑major jump; v2 API already used, re‑test trigger/scheduler shapes | Upgrade **first**, alone, with Functions tests + emulator run |
| `firebase-admin` | 12.7.0 | 14.5.0 | **Yes** | Node ≥22 ✓ (runtime 22) | Medium‑High | Two‑major jump; SDK API removals | Upgrade **after** `firebase-functions` is green, or in the same tested group |
| `pdf-parse` | 1.1.4 | 2.4.5 | **Yes** | Node `>=20.16<21 \|\| >=22.3` ✓ (runtime 22, local 24) | High | v2 is an API rewrite | Migrate `ai/resumeReview.js` + re‑test with real PDFs; do **not** bump blindly |
| Flutter Firebase plugins (`core`/`auth`/`firestore`/`functions`/`storage`/`analytics`/`app_check`) | see N‑4 | see N‑4 | **Yes (safe)** | same major, BOM‑aligned with Flutter 3.38.5 | Low‑Medium | None expected; re‑run `flutter test` + a callable smoke test | One group: `flutter pub upgrade` on these + `intl`/`shared_preferences` |
| `fl_chart`, `file_picker`, `connectivity_plus`, `package_info_plus` | see N‑4 | see N‑4 | **After testing** | major bumps | High | Yes, per‑package | Schedule as its own group in v9.2.6; one at a time |
| `cupertino_icons` | 1.0.8 | 2.0.0 | Yes | font only | Low | None | Include in the safe group |
| Flutter SDK / Dart SDK | 3.38.5 / 3.10.4 | current stable | **No** | — | — | — | **Up to date** — do not move during this workstream |
| Android AGP / Gradle / Kotlin / JDK | pinned | see N‑7 | **Keep pinned** | Android 16 / API 36 test target | Medium | — | Only revisit if v9.4 device testing requires it |
| Node runtime (deployed) | 22 | 22 LTS | **No** | matches all upgraded packages | — | — | **Keep pinned** |
| Node runtime (local) | 24.12.0 | — | Align to 22 | matches deployment | Low | None | Align local dev to Node 22 (or `.nvmrc`) |

### N‑6 — Controlled upgrade rule (restated from Task §18, to be obeyed in v9.2.6)

No mass `flutter pub upgrade --major-versions` and no combined `npm install firebase-functions@7 firebase-admin@14 pdf-parse@2`. For **each** logical group: (1) upgrade, (2) run the full Flutter test suite, (3) run `flutter analyze`, (4) run the Functions test suite (`npm test` in `functions/`), (5) build the release APK, (6) re‑run `firebase deploy --only functions --dry-run` validation, (7) manual smoke test, (8) record before/after versions + migration changes. Suggested groups: **(G1)** Flutter Firebase plugins + `intl` + `shared_preferences`; **(G2)** `firebase-functions`; **(G3)** `firebase-admin`; **(G4)** `pdf-parse` (with the resumeReview migration); **(G5)** `fl_chart`; **(G6)** `file_picker`; **(G7)** `connectivity_plus`; **(G8)** `package_info_plus`.

### N‑7 — Android build toolchain (inspection only, not upgraded)

`android/settings.gradle.kts`, `android/build.gradle.kts`, `android/app/build.gradle.kts` and `android/gradle/wrapper/` pin the AGP, Kotlin and Gradle versions. The project targets the Android 16 / API 36 test environment. **No upgrade is proposed during this audit** — a compatibility claim would require an actual build against the target device, which is a v9.4 activity. The one build‑configuration finding that *is* actionable now is the debug‑signed release (C‑1).
---

## O. Full Feature‑by‑Feature Audit Matrix (Task §22)

Severity: **Critical** (security/data‑loss/major production risk) · **High** (significant correctness/cost/reliability/performance) · **Medium** (meaningful improvement or debt) · **Low** (minor cleanup).

### O‑1 — Authentication, session & roles

| Area | Component | Finding | Severity | Evidence | Impact | Recommended Action | Effort | Status |
|---|---|---|---|---|---|---|---|---|
| Auth | `AuthGuard` init/reset flags | None — reset on logout and re‑login, identity‑checked profile sync | — | `main.dart` | Correct | Keep | — | Verified |
| Auth | Email verification | Present; navigation handled | — | `auth/`, `verify_email_navigation_test.dart` | Correct | Keep | — | Verified |
| Auth | Role detection | Read from `users/{uid}.role`; not client‑writable | — | `firestore.rules`, `role_provider.dart` | Correct | Keep | — | Verified |
| Auth | Session restoration | `FirebaseAuth.authStateChanges` → provider init | — | `AuthGuard` | Correct | Keep | — | Verified |
| Auth | Account switching | Providers reset via `AuthGuard` logout branch | — | `main.dart` | Correct | Keep | — | Verified |
| Auth | Stale async callbacks | Guarded by `_isDisposed` on most providers; `PlacmentsProvider.reset()` ordering anomaly | Low | `placements_provider.dart` (E‑14) | Cosmetic | Align ordering | S | Open |
| Auth | Runtime logout→re‑login | No post‑fix runtime log exists | Medium | `docs/logs.md` predates fix | **Cannot verify at runtime** | Capture a log | S | **[RUNTIME-VERIFY]** |

### O‑2 — Student features

| Area | Component | Finding | Severity | Evidence | Impact | Recommended Action | Effort | Status |
|---|---|---|---|---|---|---|---|---|
| Student | Dashboard | Providers initialised once per session; guards present | — | `main.dart`, dashboards | Correct | Keep | — | Verified |
| Student | Dashboard | `ActivityFeedProvider` fans out on 5 providers, no debounce, survives logout | High | D‑8 | Rebuild amplification | Debounce + fix `reset()` | M | Open |
| Student | Notes | `getAllNotes()` unbounded stream, every authenticated user | Medium | E‑1 | O(all notes) per open | Bound + paginate | M | Open |
| Student | Placements | Client eligibility diverges from server (programs/branches) | High | D‑3 | Badge contradicts recommendation | Align + test | M | Open |
| Student | Placements | Apply timeout 30 s vs 120 s server; false rollback | High | D‑2 | False "not applied" + retry | Raise timeout; reconcile | S | Open |
| Student | Placements | Dual write per application (canonical + mirror) | Medium | E‑9 | 2× write, dedupe logic | Retire mirror | L | Open |
| Student | Chat | `getMessagesStream` unbounded | Medium | E‑1 | O(all messages) per open | Bound + paginate | M | Open |
| Student | Chat | `getChatById` fallback can throw; swallowed | Low | E‑12 | Unclear intent | Simplify | S | Open |
| Student | Chat | Extra `chatRef.get()` per send | Low | G‑1.12 | 1 extra read/message | Fold into write/trigger | S | Open |
| Student | Portfolio | Migration reads the user doc on every login | Medium | E‑8 | 1 wasted read/login | Local marker | S | Open |
| Student | Portfolio | `hasFlattenedPortfolioShape` dead | Low | E‑15/K‑1 | Dead code | Remove | S | Open |
| Student | Resume Review | Quota constants duplicated client/server | Medium | E‑5 | Display ≠ enforcement | Single source | M | Open |
| Student | Career Coach | Rate limit + monthly quota server‑side, sound | — | `careerCoach.js` | Correct | Keep | — | Verified |
| Student | AI Chat | 3 `ai_interactions` writes per message, 2 schemas | High | D‑7 | Write cost + retention gap | Single writer | M | Open |
| Student | AI Chat | Quota constants duplicated | Medium | E‑5 | Display ≠ enforcement | Single source | M | Open |
| Student | Recommendations | Client refresh gate correct; portfolio caveat | Low | E‑4 | Subtle, no defect | Comment | S | Open |
| Student | Recommendations | Server fingerprint thrashes on resume review | High | D‑1 | 2 refreshes + thrash | Break trigger chain | M | Open |
| Student | Placements | `cors:false` blocks web build | Medium | E‑6 | Web partial failure | Confirm web scope | S | **[RUNTIME-VERIFY]** |

### O‑3 — Alumni features

| Area | Component | Finding | Severity | Evidence | Impact | Recommended Action | Effort | Status |
|---|---|---|---|---|---|---|---|---|
| Alumni | Dashboard | Providers guarded; listeners disposed | — | `alumni_*` providers | Correct | Keep | — | Verified |
| Alumni | Directory | 3 unbounded scans per open | High | D‑5 | O(alumni) ×3 per open | Single fetch/aggregate | M | Open |
| Alumni | Directory | `loadMore()` has no cursor | Low | E‑13 | Inert feature | Add cursor | S | Open |
| Alumni | Directory | `getAlumniByCompany/Year/Department` dead | Low | E‑15/K‑1 | Dead code | Remove | S | Open |
| Alumni | Opportunities | 4 unbounded scans of active opportunities | High | D‑6 | O(active) ×4 per open | Derive from page/aggregate | M | Open |
| Alumni | Opportunities | `getOpportunitiesByDateRange`/`cleanupExpiredOpportunities` dead | Low | E‑15/K‑1 | Dead code | Remove | S | Open |
| Alumni | Community Chat | `getMessagesStream` unbounded | Medium | E‑1 | O(group messages) | Bound + paginate | M | Open |
| Alumni | Mentorship | `searchRequests`/`deleteRequest` dead | Low | E‑15/K‑1 | Dead code | Remove | S | Open |
| Alumni | Resume Review | Reuses the student review path; `alumni_resume_*` tests present | — | tests | Correct | Keep | — | Verified |
| Alumni | `public_profiles` | Live (used by `alumni_profile_view.dart`) | — | `alumni_profile_view.dart:49,52` | Correct | Keep | — | Verified |

### O‑4 — Teacher features

| Area | Component | Finding | Severity | Evidence | Impact | Recommended Action | Effort | Status |
|---|---|---|---|---|---|---|---|---|
| Teacher | Dashboard | Load‑scoped cache + dedupe correct | — | `teacher_analytics_*` | Correct | Keep | — | Verified |
| Teacher | Analytics | `collectionGroup` scans of all reviews + all applications | High | D‑4 | O(all) per open; scalability cliff | Server rollup / date‑bound | L | Open |
| Teacher | Analytics | N+1 removed (`pickLatestReviewPerUser`) | — | `teacher_analytics_service.dart` | Correct | Keep | — | Verified |
| Teacher | Students | Reads via `users` queries; teacher‑scoped | — | `teacher_*` services | Correct | Keep | — | Verified |
| Teacher | Resources | `persistResumeReview` server writer; owner create/update denied | — | `firestore.rules`, functions | Correct | Keep | — | Verified |
| Teacher | Profile | `teacher_profile_test.dart` present | — | test | Correct | Keep | — | Verified |

### O‑5 — Admin, cross‑cutting, platform

| Area | Component | Finding | Severity | Evidence | Impact | Recommended Action | Effort | Status |
|---|---|---|---|---|---|---|---|---|
| Admin | Existing admin functionality | In scope only as "audit existing, no scope expansion" | — | `admin` views | Unchanged | Keep | — | Verified |
| Platform | Release signing | Debug keystore | **Critical** | C‑1 | Cannot ship | Real keystore | S | Open |
| Platform | App Check | Not enforced; token not allow‑listed | **Critical** | C‑2 | No tamper protection | Console actions | S | **[RUNTIME-VERIFY]** |
| Platform | `analytics_events` | Unbounded, no retention | High | C‑3 | Growth + privacy | Retention/rollup | M | Open |
| Platform | Trigger chain | Resume review → profile trigger → 2nd refresh | High | D‑1 | Cost + thrash + points | Break chain | M | Open |
| Platform | AI provider | Groq→HF fallback + timeouts sound | — | `ai/aiProvider.js`, tests | Correct | Keep | — | Verified |
| Platform | `deepAnalysis` error check | Non‑idiomatic `httpErrorCode` check | Medium | I‑3 §7 | Fragile | `instanceof` | S | Open |
| Platform | Scheduler | 5 jobs, all justified, one unbounded batch | Medium | E‑3, §R | Latent batch failure | Chunk at 500 | S | Open |
| Platform | Scheduler | `sendInactivityReminders` unbounded | Low | E‑11 | O(chats) daily | Bound + marker | M | Open |
| Platform | Rules | `ai_insights`/`announcements` rules dead | Low | K‑3 | Dead rules | Remove after decision | S | Open |
| Platform | Storage | Orphan reconciliation absent | Low | I‑2 §5 | Orphan files | Add job | M | Open |
| Platform | Docs | `logs.md`, `v9_2_2_investigation_report.md` header stale | Low | E, §K | Misleading | Update | S | Open |
| Platform | Repo hygiene | 40+ root markdown files | Low | §K | Clutter | Move to `docs/archive/` | S | Open |
| Platform | Toolchain | `firebase-functions` 5.1.1 → 7.4.0 (safe on Node 22) | Medium | §N | CLI warning | Group upgrade | M | Open |
| Platform | Toolchain | `firebase-admin` 12.7.0 → 14.5.0 (needs Node ≥22 ✓) | Medium | §N | Currency | Group upgrade | M | Open |
| Platform | Toolchain | `pdf-parse` 1.1.4 → 2.4.5 (API rewrite) | Medium | §N | Resume PDF parse | Migrate + retest | M | Open |
| Platform | Dependencies | Flutter Firebase plugins behind (same major) | Low | §N | Currency | Safe group upgrade | S | Open |
| Platform | Dependencies | `fl_chart`/`file_picker`/`connectivity_plus`/`package_info_plus` majors behind | Medium | §N | Currency | One at a time, tested | L | Open |
| Platform | Tests | No rules tests, no callable‑contract test, no boundedness tests | High | J‑3 | Classes of defect unguarded | Add suites | M | Open |

---

## P. Cloud Function Inventory (Task §5)

All 20 exports live in `functions/index.js`; every one uses the **v2 API** (`firebase-functions/v2/...`). Region is `us-central1` throughout (as declared; the default for the emulator is overridden by the region field where set).

### P‑1 — Callables (8)

| Function | Module | Trigger | Auth | Validation | Timeout | Max instances | Reads | Writes | External | Idempotent? |
|---|---|---|---|---|---|---|---|---|---|---|
| `askAI` | `ai/chat.js` | `onCall` | `request.auth.uid` | message non‑empty, ≤1000 chars; rate + spam windows | **120 s** | 10 | rate‑limit doc, spam doc, user doc (trial txn), quota txn | 2 `ai_interactions`, quota (+legacy mirror), 2 `analytics_events`, rate/spam docs | Groq→HuggingFace | No (each send is a new turn) |
| `reviewResume` | `ai/resumeReview.js` | `onCall` | uid | resume path ownership, size/type, quota txn | see module | — | user doc, quota txn, resume bytes | `resumeReviews` doc, quota, analytics | Groq/HF + `pdf-parse` | Reservation‑based |
| `generateResumeAnalysis` | `ai/deepAnalysis.js` | `onCall` | uid | review exists, quota | — | — | `resumeReviews` doc, quota | analysis fields, quota, analytics | Groq/HF | Reservation‑based |
| `generateCareerCoachAnalysis` | `careerCoach.js` | `onCall` | uid | rate limit + monthly quota + cache key | — | — | quota, cache doc | `career_coach/summary` cache, quota, analytics | Groq/HF | Cache‑keyed |
| `deleteAIHistory` | `ai/chatDelete.js` | `onCall` | uid | — | see module | — | `ai_interactions` batch, legacy `ai_conversations` batch | deletes | — | Yes (delete is idempotent) |
| `refreshRecommendations` | `recommendations/refresh.js` | `onCall` | uid | `force` flag | — | — | 6 parallel queries + fingerprint + **AI enrichment** | recommendation set + `recommendations_meta` | Groq/HF | Fingerprint‑gated |
| `logPlacementView` | `placements.js` | `onCall` | uid | `placementId` required | 60 s | 10 | — | 1 `analytics_events` | — | Append‑only (grows) |
| `logPlacementApplication` | `placements.js` | `onCall` | uid | placement exists/active/not‑expired in txn; resume path ownership | **120 s** | 100 | placement (txn), existing app (txn), Storage `exists` | 2 application docs, 1 `analytics_events`, Storage snapshot | Storage copy + `getSignedUrl` | **Yes** (existing‑app short‑circuit) |
| `updateApplicationStatus` | `placements.js` | `onCall` | uid + role check | status enum, transition state machine, actor authored placement, per‑actor rate limit | 60 s | 20 | role, rate‑limit, canonical app, placement, mirror | canonical + mirror status, notification, `analytics_events` | — | Transition‑guarded |

### P‑2 — Triggers (6)

| Function | Document | Type | Reads | Writes | Chain risk |
|---|---|---|---|---|---|
| `onProfileUpdatedRefreshAI` | `users/{userId}` | `onDocumentWritten` | — | recommendation refresh, `logUserActivity` (engagement txn), `career_coach/summary` invalidation | **Fired by `onResumeReviewCreatedRefreshMatches`' own write (D‑1)** |
| `onResumeReviewCreatedRefreshMatches` | `users/{userId}/resumeReviews/{reviewId}` | `onDocumentCreated` | user doc | **`users/{userId}` write** (portfolio counters) → triggers the above; recommendation refresh | **Source of D‑1** |
| `onOpportunityPostedNotifyStudents` | `opportunities/{opportunityId}` | `onDocumentCreated` | all student users | batched notifications (400/chunk ✓) | None |
| `onMentorshipRequestCreated` | `mentorship_requests/{requestId}` | `onDocumentCreated` | — | deterministic‑id notification | None |
| `onMentorshipRequestResponseNotifyStudent` | `mentorship_requests/{requestId}` | `onDocumentWritten` | — | deterministic‑id notification | None |
| `onChatMessageCreated` | `chats/{chatId}/messages/{messageId}` | `onDocumentCreated` | chat doc | deterministic‑id notification | None |

**Recursion audit:** the only write‑trigger‑write cycle is `onResumeReviewCreatedRefreshMatches` → `users/{uid}` → `onProfileUpdatedRefreshAI` → `refreshRecommendationsForStudent` → `recommendations_meta` (collection not watched) — the cycle terminates, but it runs the engine **twice concurrently** (D‑1). No other trigger writes a document that another trigger watches.

### P‑3 — Scheduled (5)

See § R. No recursive triggers were found anywhere else in the deploy set.
---

## Q. Firestore Collection & Query Inventory (Task §3)

Every client‑reachable collection/subcollection and its access shape. "Bounded" = has a `limit()`; "Windowed" = has a `where` that narrows the scan (still potentially large without a limit). Rules column refers to `firestore.rules`.

### Q‑1 — User‑scoped

| Path | Written by | Read by | Owner‑only rule? | Query shape | Bounded/Windowed | Issue |
|---|---|---|---|---|---|---|
| `users/{uid}` | client profile update, triggers (portfolio counters, recommendations meta), server | client, teacher analytics (`where role/…`), directory (`where role=='alumni'`) | owner read; role/`isVerified`/etc. guarded | doc read; list `where role`+`profileCompleted`, sometimes + `orderBy` | windowed but **unbounded** in directory (D‑5) and opportunity notify (`where role=='student'`) | D‑5, P‑2 |
| `users/{uid}/portfolio` | client portfolio save | owner + `public_profiles` projection | yes | doc read | bounded | E‑8 (migration read) |
| `users/{uid}/resumeReviews` | **server only** (`persistResumeReview`) | owner + teacher `collectionGroup('resumeReviews')` | owner read, `write:false` | `collectionGroup` — no limit (D‑4); owner subcollection read | **collection group unbounded** | D‑4 |
| `users/{uid}/recommendations` | **server only** (refresh) | owner | owner read, `write:false` | stream `limit(20)` | bounded | — |
| `users/{uid}/recommendations_meta` | server only | server only (`if false` for client) | n/a | doc read (server) | bounded | D‑1 fingerprint thrash |
| `users/{uid}/ai_interactions` | **server AND client** | client `orderBy('createdAt') limit(~20)`; retention sweep `where timestamp` | owner read, and create allowed? | two schemas | bounded read, **3 writes/message** | D‑7 |
| `users/{uid}/activities` | server (`logUserActivity`) | owner | owner read, `write:false` | stream (see provider) | — | — |
| `users/{uid}/notifications` | server + triggers | owner `orderBy createdAt limit 50` | owner read, `write:false` | bounded stream; **unbounded** bulk read/write (E‑2) | mixed | E‑2 |
| `users/{uid}/career_coach` | server (`careerCoach`) | owner | owner read | doc read | bounded | — |
| `users/{uid}/engagement_summary` | server (`recomputeEngagementSummary`, `logUserActivity`) | owner, teacher | owner read, `write:false` | doc read | bounded | D‑1 (recompute wired to profile trigger) |
| `users/{uid}/ai_insights` | **nobody** | **nobody** | owner read, `write:false` | — | — | **Dead (E‑7)** |

### Q‑2 — Top‑level collections

| Path | Written by | Read by | Rule | Query shape | Bounded? | Issue |
|---|---|---|---|---|---|---|
| `placements` | teacher client (rules‑validated) | students, teacher | role‑guarded create/update; `where isActive`, `orderBy postedAt` | `getActivePlacements(limit)`, deadline filter | mixed | E‑9 (mirror), D‑2 |
| `placements/{id}/applications` | server (mirror) | `collectionGroup('applications')` | — | mirror of canonical | unbounded via collectionGroup | E‑9 |
| `applications` | server (canonical) | teacher `collectionGroup('applications')`; `where userId` | client read own, `update:false` | collectionGroup **unbounded** (D‑4); `where('userId')` | **unbounded** | D‑4, E‑9 |
| `opportunities` | alumni/teacher client | students, alumni | role‑guarded; `where isActive` (+ `applicationDeadline` in scheduler) | `getActive(50)`, `getRecent(10)`, **3 facet scans unbounded**, alumni stats unbounded; scheduler `where isActive + deadline<=now` **unbounded** | mixed | D‑6, E‑3, E‑11 |
| `mentorship_requests` | student client; status by alumni | both parties | participant‑scoped | `where status`/participant | windowed | P‑2 |
| `chats` | server (create) / client (message) | participants | participant‑scoped; `delete:false` | `where participantIds array-contains`; scheduler `where lastMessageAt< cutoff` **unbounded** | mixed | E‑1 (messages), E‑11 |
| `chats/{id}/messages` | client | participants | participant‑scoped | `.orderBy('sentAt').snapshots()` **no limit** | **unbounded** | E‑1 |
| `notes` | authenticated user | authenticated user | read all authed; delete owner/uploader | `.orderBy('uploadedAt').snapshots()` **no limit** | **unbounded** | E‑1 |
| `analytics_events` | server only | **nobody reads** | `if false` | append‑only | n/a | **C‑3 unbounded growth** |
| `public_profiles` | server (`syncPublicProfile` on alumni/opportunity events) | all authed (projection) | read‑only projection | doc read | bounded | — |
| `announcements` | **nobody** | **nobody** | read authed, `write:false` | — | — | **Dead rule/collection (K‑3)** |
| `config/*` (legacy quota mirrors) | server (`quota.js`) | server | `if false` | doc read/write | bounded | E‑5/H‑2 (legacy mirror) |
| `user_ai_quotas/{uid}` | server (`quota.js`) | server; client read for display | `if false` (client read? verify) | doc read/txn | bounded | — |
| `ai_usage/{uid}` (legacy) | server (mirror) | — | `if false` | — | — | H‑2 legacy |
| `ai_conversations` (legacy) | **no longer written** | `deleteAIHistory`, `cleanupExpiredAIConversations` | `if false` | query for delete | — | K‑3 dead weight |
| `ai_rate_limits/{uid}` | server (`askAI`) | server | `if false` | txn | bounded | — |
| `ai_spam_check/{uid}` | server (`askAI`) | server | `if false` | txn | bounded | — |
| `placement_status_rate_limits/{uid}` | server (`updateApplicationStatus`) | server | `if false` | txn | bounded | — |

### Q‑3 — Query‑shape summary (Task §3 checklist, applied per query)

* **Necessary?** All are used by a live feature except: `ai_insights` (dead), `announcements` (dead), `notes` index for `getNotesByUploader` (unused), and the legacy quota/`ai_conversations` reads. → **4 dead‑ish query targets.**
* **Duplicated?** Alumni directory (3 duplicate alumni scans, D‑5); opportunities (3 facet scans + recent, D‑6); chat `getMessagesStream` vs `getMessages`; `getOpportunityStatsForAlumni` vs `getAlumniOpportunities`; `getUnreadCount` vs the notifications stream. → **5 duplicate groups.**
* **Bounded?** 12 unbounded sites (D‑4 ×2, D‑5 ×3, D‑6 ×4, E‑1 ×3, E‑2 ×3, E‑3, E‑11) — enumerated in § H.
* **Pagination required?** chat messages, group messages, notes, alumni directory, opportunities, notifications.
* **Cache reused?** Teacher analytics uses a load‑scoped cache (good). Alumni/opportunity facets do **not** reuse the page they already fetched.
* **N+1?** Teacher analytics N+1 was removed in v9.2 (verified). `getApplicantCounts` uses `whereIn` chunks of 10 (bounded but chatty).
* **Stream necessary, or one‑time read enough?** `getAllNotes` and the two chat message streams could be capped; the notifications and recommendations streams are correctly bounded.
* **Stream opened multiple times?** Not observed beyond the intended single subscription per provider; `reset()`/`dispose()` cancel them (verified in § U).
* **Stream cancelled correctly?** Yes for the providers that retain subscriptions (v9.2 fix); `ActivityFeedProvider` never removes its provider listeners (D‑8).
* **Same document read repeatedly?** `getChatById` (E‑12), the per‑message `chats/{id}` read in `onChatMessageCreated` (G‑1.13), `maybeCreateNotification`'s pre‑read (E‑10).

---

## R. Scheduler / Background Job Inventory (Task §14)

Verified from `functions/index.js` + `functions/schedulers/index.js`: **5 scheduled jobs** (and 1 retention helper that is scheduler‑invoked). The v9.2 consolidation (7 → 5) is confirmed present.

| # | Job | Schedule | Region | Purpose | Query scope | Idempotent? | Bounded? | Failure handling | Consolidation? |
|---|---|---|---|---|---|---|---|---|---|
| R‑1 | `autoExpireOpportunities` | `every 60 minutes` | us‑central1 | Set `isActive:false` on expired opportunities | `opportunities where isActive==true && applicationDeadline<=now` | Yes (idempotent update) | **No** — single batch, >500 throws (E‑3) | try/catch logs | Could fold into the daily engagement job, but hourly granularity is intentional (users should see expiry quickly) — **keep** |
| R‑2 | `sendInactivityReminders` | `every day 09:00` UTC | us‑central1 | Remind unread chats + stale mentorships | `chats where lastMessageAt<cutoff` (**unbounded**); `mentorship_requests where status==pending && createdAt<=cutoff` (unbounded) | **No** — no per‑chat marker; a retry re‑reminds (E‑10, E‑11) | **No** | try/catch logs | **Consolidate is possible but risky** — behaviour is fine; add a per‑chat marker rather than merging |
| R‑3 | `recomputeEngagementScores` | `every day 01:00` UTC | us‑central1 | Refresh engagement summaries | `users where profileCompleted==true` **paginated at 50** | Yes | **Yes (paginated)** | try/catch logs | Correctly bounded — the model for the others |
| R‑4 | `compensateStaleAIQuotas` | `every day 04:00` UTC | us‑central1 | Refund stale AI quota reservations for `resumeReview`, `careerCoach`, `aiAnalysis` | per‑feature sweep in `quota.runFeatureSweep` | Yes (no‑double‑charge guard) | Bounded by the sweep implementation | per‑feature try/catch so one failure cannot block the others | Correctly consolidated (3→1) in v9.2 |
| R‑5 | `cleanupExpiredAIConversations` | (retention) daily | us‑central1 | Delete `ai_interactions` older than the retention window | `ai_interactions where timestamp < cutoff` (limit 5000) | Yes | **Yes (limit 5000)** | try/catch | **Kept but now semi‑dead** — `askAI` no longer writes `ai_conversations`, so the legacy half of the cleanup targets an empty collection (K‑3) |

**Chaining risk:** none of the five jobs writes a document that another trigger watches (`opportunities` expiry updates do **not** trigger a notification — the `onOpportunityPostedNotifyStudents` trigger is `onDocumentCreated`, and expiry is an `update`; verified). The only write→trigger→write chain in the deploy set is D‑1 (trigger‑to‑trigger), not a scheduler.

**What the brief asks to verify, answered:**
* *Is the intended number of jobs correct?* — Yes, 5, verified against source (not assumed).
* *Can any be consolidated?* — R‑1 and R‑2 could theoretically merge, but they have different schedules and their only shared property is "daily"; merging would reduce clarity and R‑1's hourly granularity would be lost. **No consolidation recommended.**
* *Can any be event‑driven instead?* — R‑1 (opportunity expiry) is the only realistic candidate (a Firestore TTL policy on `applicationDeadline` cannot set `isActive`, so it would still need a function). **Keep as‑is**; just fix the batch chunking (E‑3).
* *Duplicate processing risk?* — R‑1 and R‑2 (re‑run after failure re‑processes); R‑3/R‑4 are idempotent. Neither R‑1 nor R‑2 has a per‑document idempotency marker.

**Nothing is removed or changed during this audit.**
---

## S. AI System Audit (Task §6)

### S‑1 — Provider abstraction

| Check | Finding | Evidence |
|---|---|---|
| Provider abstraction | Present — a single router (`callAIProvider`) used by chat, resume review, deep analysis, career coach and recommendation explanations | `ai/aiProvider.js` exports `callAIProvider`; the comment explicitly binds `recommendations/ai_explanations.js` to the same router ("never a second AI client") |
| Groq primary | Default (`AI_PROVIDER` unset → `groq`); model `openai/gpt-oss-20b` | `ai/aiProvider.js`, `ai/groqProvider.js` |
| Hugging Face fallback | On ANY primary failure (missing key, network, timeout, rate limit, 5xx, malformed) the request is retried once against HF; the reported `providerUsed` is the one that answered | `callAIProvider` try/catch |
| Single‑provider mode | If `AI_PROVIDER=huggingface`, there is no fallback — the HF error surfaces (documented) | same |
| Missing fallback key | Surfaces a clear deployment error, never leaks a key | `if (!process.env.HUGGINGFACE_API_KEY) throw new Error(...)` |
| Timeout handling | Both provider timeouts feed the 120 s callable budget (Groq 30 s → HF 60 s documented) | `aiProvider.js` comment; `ai/chat.js` `{timeoutSeconds: 120}` |
| Retries | A 3‑attempt retry behaviour is asserted in `test/ai_provider_fallback_test.dart` | test suite |
| Malformed responses | `normalizeResponse.js` + `extractJSON` + trailing‑comma repair; every field is coerced with a default | `normalizeResumeReviewResponse`, `normalizeAIResponse` |
| Prompt construction | Three system prompts (deep analysis, chat, resume review), each with an explicit anti‑injection clause | `SYSTEM_PROMPT`, `CHAT_SYSTEM_PROMPT`, `RESUME_REVIEW_SYSTEM_PROMPT` |
| Input sanitization | `sanitizeAIInput` strips control/zero‑width chars and caps length (12 000 / 200 / 100 per field; 8 000 / 24 000 on the envelope) | `helpers/shared.js`, `callAIProvider` |
| Response limits | Chat plain‑text is post‑processed by `normalizeChatText` to strip stray Markdown | `aiProvider.js` |
| Logging/privacy | Inputs are truncated to 50 chars before logging (`Message: ${trimmedMessage.substring(0, 50)}...`) — no full prompt, no resume body, no key | `ai/chat.js` |

**Verdict:** the AI architecture is coherent, single‑router, sanitized at two layers, and defensively normalized. No duplicate AI client, no unvalidated prompt path.

### S‑2 — Per‑feature AI audit

| Feature | AI called when? | Deterministic alternative? | Unnecessary call? | Quota path |
|---|---|---|---|---|
| AI Chat (`askAI`) | Every user message | No — conversational by nature | No | `incrementDailyUsage` (soft daily) |
| Resume Review (`reviewResume`) | Once per review request | The ATS score could be partially deterministic, but the prompt asks the model for score + keywords + rewrites — a legitimate AI task | No | `consumeFeatureQuota` (monthly, reserved) |
| Career Coach (`careerCoach`) | Once per analysis | No | **Cache** already exists (`career_coach/summary`, invalidated by the profile trigger) — good | `consumeFeatureQuota` (monthly, reserved) |
| Recommendation AI enrichment | Top‑5 candidates only, per refresh | Scoring is deterministic; AI supplies only the narrative | **Yes — twice per resume review (D‑1)** | none (internal) |
| AI insights / analysis (`generateResumeAnalysis`) | Once per deep‑analysis request on an existing review | No | No | `consumeFeatureQuota` (monthly, reserved) |
| `AIInsightsService` (placement insight) | **Never** — dead | n/a | It would call a non‑existent function (E‑7) | n/a |

**Where AI is over‑called:** only one place — the recommendation refresh running twice per resume review (D‑1). Everything else calls AI once per genuine user action and caches where appropriate (Career Coach).

### S‑3 — Quota reservation / rollback (Task §6 checklist)

| Check | Finding | Evidence |
|---|---|---|
| Reservation | Every monthly consume stamps `pendingRequestId` + `pendingSince` in the same transaction as the increment | `quota.js::consumeFeatureQuota` |
| Rollback on AI failure | `rollbackFeatureQuota` decrements **and** clears only THIS request's reservation, in one transaction — no double refund | `quota.js` |
| Clear on success | `clearFeatureReservation` un‑stamps without touching the count | `quota.js` |
| Stale‑request compensation | `runFeatureSweep` takes the **union** of unified + legacy docs with a stale `pendingSince`, refunds each atomically across both stores | `quota.js::runFeatureSweep`, `sweepStaleReservation` |
| Concurrency | All mutations are Firestore transactions | `quota.js` |
| Idempotency | The union‑then‑refund design means a user appears once and both stores clear in one transaction | `quota.js` |
| **Read path writes** | `getFeatureUsage` → `seedFeatureFromLegacy` **writes** the unified doc (and can write the legacy doc) merely from a *read/check* call | Low‑severity side effect (§ Z) |
| Daily limit not enforced | `enforceLimit` only throws for `mode === "monthly"`; chat's daily limit is soft (documented) | `quota.js::enforceLimit` |
| Error‑path defaults | `incrementDailyUsage` catch returns `dailyCount: 1` — an outage reports a fabricated count | Low (§ Z) |

**Verdict:** the reservation/rollback/stale‑sweep design is correct and well‑tested (`quota.test.js`, `resume_quota_reservation_test.dart`, `resume_retry_throttle_test.dart`). The two anomalies above are Low severity.

---

## T. Recommendation Engine Audit (Task §7)

### T‑1 — The declared flow, traced

`profile/intelligence data → fingerprint → refresh decision → candidate gathering → deterministic scoring → eligibility → AI enrichment → Firestore materialisation → Flutter consumption`

| Stage | Location | Verified behaviour |
|---|---|---|
| Fingerprint | `computeRecommendationFingerprint` in `recommendations/refresh.js`; client mirror in `recommendation_fingerprint.dart` | sha256; includes profile + career + interests + skills + **portfolio content** + (when present) resume review data; excludes pure metadata flutters |
| Refresh decision | server: skip requires `!force && fingerprintUnchanged && hasMaterializedSet && !expired`; client: `RefreshDedupe` gate (6 h max age) | Present and correct in isolation |
| Candidate gathering | `loadCandidates` — all alumni (cap 200), all active opportunities (cap 200), all active placements (cap 200), 6 parallel queries | Present; **cost grows with dataset** (H‑4, G‑1.17) |
| Deterministic scoring | `recommendations/engine.js` | Present |
| Eligibility | `checkMandatoryEligibility` — programme/branch, CGPA, graduation year, backlog | Present, but **diverges from the client** (D‑3) |
| AI enrichment | `ai_explanations.js` via the single router — top‑5 candidates | Present; **runs twice per resume review** (D‑1) |
| Materialisation | recommendation docs on `users/{uid}/recommendations` + `recommendations_meta/summary` | `write:false` for clients (server‑only) ✓ |
| Flutter consumption | `RecommendationProvider` stream `limit(20)` | Bounded ✓ |

### T‑2 — Checklist results (Task §7)

| Check | Result |
|---|---|
| Declared career vs discovery roles | Handled in `career_roles.js`; both surfaces distinct |
| Duplicate refresh prevention | **Fails on the resume‑review path** — two concurrent refreshes with different fingerprints (D‑1) |
| Fingerprint correctness | Correct per‑variant; **the two resume paths use two different variants**, so the stored value thrashes (D‑1) |
| Stale data handling | The client gate's portfolio blind spot is documented and covered by the server trigger (E‑4) |
| Cache behaviour | `RefreshDedupe` (client, 6 h) + server fingerprint skip — both present |
| Refresh triggers | Profile trigger, resume‑review trigger, callable (`refreshRecommendations`), client bootstrap — 4 entry points; only the resume path duplicates |
| Manual refresh | `refreshRecommendations(force: true)` supported |
| Profile‑update triggers | `onProfileUpdatedRefreshAI` — fires on a genuine change (verified: `portfolioContentChanged` strips only `portfolio.metadata`, so `portfolio.resume.*` counts as a change → **D‑1 confirmed**) |
| Resume‑review triggers | **This is the defect source** (D‑1) |
| Duplicate writes | The recommendation set is rewritten in full on every non‑skipped refresh; Twice on the resume path |
| Unnecessary AI enrichment | Only on the duplicate resume‑review refresh |
| Document cleanup | No orphaned‑recommendation sweep found; the refresh overwrites the set in place (acceptable while the set size is bounded) |
| Pagination | `limit(20)` on the client stream — bounded ✓ |
| Maximum candidate limits | 200 alumni / 200 opportunities / 200 placements — capped ✓ |
| Unified architecture respected? | **Yes** — a single engine, a single materialised set, a single fingerprint gate, and the Flutter client reads only the materialised docs (no client‑side scoring). The only inconsistency is the *second concurrent writer* introduced by the trigger chain. |

### T‑3 — Engine verdict

The unified recommendation architecture is real and respected end‑to‑end. The single defect that undermines it is **D‑1**: the resume‑review trigger writes the parent user document, which re‑enters the engine through the profile trigger with a different fingerprint. Fixing D‑1 makes the fingerprint gate reliable and halves the engine's cost on the resume path.
---

## U. Provider & State‑Management Audit (Task §8)

20 providers live in `lib/providers/`. Each was checked for construction behaviour, lazy init, `initWithUser`, `reset`, `dispose`, listeners/subscriptions, async calls, loading/error flags, duplicate init, concurrency, stale futures, `notifyListeners()` discipline, rebuild cost, cached state, and post‑logout behaviour.

| # | Provider | Constructed | `initWithUser` | Streams/listeners | `reset()` | `dispose()` | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | `ActivityFeedProvider` | **Eager at app start, before login** | n/a | **Subscribes to 5 providers; never removes them** | Clears state, notifies, **does NOT set `_isDisposed`** | Removes listeners | **Two defects — D‑8** |
| 2 | `AIChatProvider` | Lazy (per feature) | `initWithUser` | One‑shot reads (no retained stream) | Clears history/state | Not overridden (no subscriptions to leak) | Extra client write (D‑7) |
| 3 | `AIUsageProvider` | Lazy | `initWithUser` | Reads usage | Clears | n/a | **Hardcoded `_dailyLimit = 50`** (E‑5) |
| 4 | `AlumniDirectoryProvider` | Lazy | `init()` | Retained subscription, cancelled in `dispose()` | Clears | Cancels | `loadMore()` inert (E‑13); 3 unbounded scans (D‑5) |
| 5 | `AlumniGroupChatProvider` | Lazy | `initWithUser` | Retained stream, cancelled | Clears (no notify after `_isDisposed`) | Cancels | Correct |
| 6 | `CareerCoachProvider` | Lazy | `initWithUser` | One‑shot callable + cached summary | Clears | n/a | Correct; rate‑limit/monthly quota server‑side |
| 7 | `ChatProvider` | Lazy | `initWithUser` | `Map<String, StreamSubscription>`, cancelled in **both** `reset()` and `dispose()` | Clears + cancels | Cancels | Correct; `getChatById` fallback anomaly (E‑12) |
| 8 | `EngagementProvider` | Lazy | `initWithUser` | Stream on `engagement_summary` | Clears (per v9.2 single‑writer fix, no client recompute) | Cancels | Correct |
| 9 | `LayoutProvider` | Eager, self‑init via `..init()` | n/a | Local prefs only | n/a | n/a | Correct (no backend work) |
| 10 | `MentorshipProvider` | Lazy | `initWithUser` | Retained subscription, cancelled | Clears | Cancels | Correct |
| 11 | `NotificationsProvider` | Lazy | `initWithUser` | Bounded stream (`limit 50`) | Clears (no notify after `_isDisposed`) | Cancels | Correct (stream); bulk ops unbounded (E‑2) |
| 12 | `OpportunityProvider` | Lazy | `initWithUser` | Retained subscription, cancelled | Clears | Cancels | Correct (lifecycle); unbounded facets (D‑6) |
| 13 | `PlacementsProvider` | Lazy | `initWithUser` | Applied‑state maps, no retained stream | **Notifies after setting `_isDisposed`** | Sets flag | Timeout + rollback defect (D‑2); ordering (E‑14) |
| 14 | `PortfolioProvider` | Lazy | `initWithUser` → **migration read every login** | Subscription for portfolio doc | Clears | Cancels | Migration extra read (E‑8) |
| 15 | `ProfileProvider` | Lazy | `initWithUser` | Profile stream; identity‑checked sync | Clears | **No `dispose()` override** (no retained subscription observed) | No leak found; worth confirming |
| 16 | `RecommendationProvider` | Lazy | `initWithUser` (stream `limit 20` + client gate + callable refresh) | Retained stream, cancelled | Clears + `RefreshDedupe.invalidate()` | Cancels | Correct; client portfolio blind spot (E‑4); server thrash (D‑1) |
| 17 | `ResumeReviewProvider` | Lazy | `initWithUser` (fires `_loadHistory()` **fire‑and‑forget**) | One‑shot reads | Clears | n/a | `historyInitialized` false for a window after login (documented, v9.2.2 §5) |
| 18 | `RoleProvider` | Lazy | `initWithUser` (sets `_isDisposed = false`) | One‑shot read | Sets `_isDisposed` then notifies | **No `dispose()` override** | No leak found |
| 19 | `TeacherAnalyticsProvider` | Lazy | `loadAnalytics` with `LoadDedupe` + `hasData` short‑circuit | Load‑scoped caches cleared in `beginLoad()` | Clears + resets cache | n/a | **Correct** — the reference implementation |
| 20 | `ThemeProvider` | Eager, self‑init via `..init()` | n/a | Local prefs only | n/a | n/a | Correct (no backend work) |

### U‑1 — Cross‑provider findings

1. **Duplicate/necessary initialisation:** `AuthGuard` schedules ecosystem init once per login (`_ecosystemInitScheduled`) and re‑schedules on logout/re‑login (F‑1 #3 verified). `TeacherAnalyticsProvider` dedupes loads. **No duplicate backend init was found except the pre‑login `ActivityFeedProvider` (D‑8).**
2. **`notifyListeners()` discipline:** consistent (`_isDisposed` guards) in `NotificationsProvider`, `ChatProvider`, `AlumniGroupChatProvider`, `PortfolioProvider`, `EngagementProvider`. Two exceptions: `PlacementsProvider.reset()` (notifies after disposing — E‑14) and `ActivityFeedProvider.reset()` (does not dispose at all — D‑8).
3. **Providers doing work when their feature is not viewed:** only `ActivityFeedProvider` (aggregates for every user from app start and keeps aggregating after logout).
4. **Providers retaining user‑specific state after logout:** none — all `reset()` implementations clear their state; the *listener* retention is the `ActivityFeedProvider` issue, not retained data.
5. **Unnecessary rebuilds:** `ActivityFeedProvider` (D‑8) is the only material amplifier. The teacher analytics provider no longer rebuilds spuriously (v9.2 fix).
6. **Stale futures:** `ResumeReviewProvider._loadHistory()` is not awaited in `initWithUser`, so `historyInitialized` lags login — the v9.2.2 caller guard handles it; no crash path found.

**Verdict:** provider lifecycle is in good order across the board; the audit found exactly two provider‑level defects (D‑8, E‑14) and one provider‑level cost item (E‑8).

---

## V. Screen & Navigation Audit (Task §9)

### V‑1 — Routing & navigation

| Check | Finding | Evidence |
|---|---|---|
| Route duplication | No duplicate route names found; `loginRoute`, `notesRoute`, `verifyEmailRoute` etc. are `const` and unique | `lib/constants/routes.dart` (~36 entries) |
| Navigation loops | None found; `AuthGuard` is the single gate and it branches on auth+role+verification | `main.dart` |
| Stale state after returning | Feature providers keep their state (by design) and refresh on re‑entry via `initWithUser` guards; no crash found |
| Unnecessary route initialisation | `main_navigation_view.dart` builds only visited tabs (`_visitedTabs`), else `SizedBox.shrink()` — the v9.2 lazy‑tab fix is present | `main_navigation_view.dart` |
| Async `context` misuse | Not found in the screens read; await‑then‑use‑context patterns are guarded by `if (!context.mounted) return;` in the sam‑ples inspected |
| Missing disposal | Controllers are disposed in the views inspected; the leaks fixed in v9.2 were provider‑side, and those are fixed |

### V‑2 — Per‑role screen audit

**Student:** Dashboard (init guarded, activity feed amplification D‑8) · Notes (unbounded stream E‑1) · Placements (eligibility divergence D‑3, apply timeout D‑2) · Chat (unbounded stream E‑1, `getChatById` E‑12) · Profile (extra migration read E‑8) · Portfolio (migration read) · Resume Review (history init lag) · Career Coach (cached) · Recommendations (bounded stream; server thrash D‑1).

**Alumni:** Dashboard (correct) · Directory (3 unbounded scans D‑5; inert `loadMore` E‑13) · Opportunities (4 unbounded scans D‑6) · Mentorship (correct) · Community Chat (unbounded stream E‑1) · Resume Review where applicable (shared path, correct).

**Teacher:** Dashboard (LoadDedupe correct) · Students (scoped queries) · Analytics (unbounded collection‑group scans D‑4 — the largest scalability item) · Resources (server‑written reviews) · Profile (correct).

**Admin:** existing functionality only; **no scope expansion performed**. No admin‑specific defect was surfaced beyond the shared release‑configuration items (C‑1, C‑2).

### V‑3 — Screen/UX items explicitly out of scope

Per Task §1 rule 9, no UI redesign is proposed. This section audits **initialisation, repeated work, duplicated calls, rebuilds, unbounded lists, disposal and async‑context** only — not layout, styling or user flows.
---

## W. Data Model & Migration Audit (Task §11)

| Check | Finding | Evidence | Severity |
|---|---|---|---|
| Legacy fields | The four legacy quota collections (`ai_usage`, `resume_usage`, `career_coach_usage`, `ai_analysis_usage`) are still written alongside `user_ai_quotas` on every AI operation | `ai/quota.js` `FEATURE_CONFIG.legacyCollection` | Medium (H-2) |
| Flattened portfolio structures | Detection + migration implemented and idempotent (`planPortfolioMigration` returns `null` when `data['portfolio'] is Map`) | `services/firestore/portfolio_migration.dart` | None (correct) |
| Duplicated fields | `applications` carries the same payload twice (canonical + mirror, differing only in `resumeUrl` vs `resume`) | `functions/placements.js` | Medium (E-9) |
| Redundant mirrors | (a) application mirror; (b) legacy quota mirror; (c) `ai_interactions` dual schema; (d) `public_profiles` projection (this one is intentional and useful) | multiple | Medium |
| Inconsistent field names | `ai_interactions` uses **`timestamp`** server-side and **`createdAt`** client-side (D-7); quota `lastReviewAt` vs `lastAnalyzedAt` vs `lastUsedAt` (by design per feature) | D-7 | High (as part of D-7) |
| Incompatible old formats | Legacy quota docs are *seeded* into the unified doc on read (`seedFeatureFromLegacy`) and reservations are preserved — handled | `ai/quota.js` | None |
| Orphaned documents | Two Firestore rules guard collections with no writer and no reader: `ai_insights` (E-7) and `announcements` (K-3). `ai_conversations` is read-for-delete only | `firestore.rules` | Low |
| Migration never completes | The portfolio migration completes and stamps `metadata.portfolioMigratedAt`; **but the guard that would let it skip is not consulted on the next login** (E-8), so it re-reads forever | `portfolio_service.dart` | Medium (E-8) |
| Migration repeatedly runs | `migrateFlattenedPortfolio` runs on **every** student login (the read, not the write, repeats) | E-8 | Medium |
| Missing migration markers | `metadata.portfolioMigratedAt` **is** stamped (marker exists) but is not read back as a skip condition | `portfolio_service.dart` | Medium (fix available) |
| Destructive migration risk | `planPortfolioMigration` only *adds* a nested `portfolio` map and leaves the old flat keys inert; no delete — **not destructive** (deliberately, per v9.2.2 §12) | `portfolio_migration.dart` | None |
| Can legacy compatibility code be retired? | **Not yet without a decision.** The legacy quota mirrors have no remaining reader in this repository (all readers were migrated to `user_ai_quotas`), and `ai_conversations` has no writer. Both are kept as a documented transition contract. Retiring them is a v9.2.4 task, not an audit action | `ai/quota.js`, `ai/chatDelete.js` | Medium |

**Verdict:** the **one** model inconsistency that causes a live defect is the `ai_interactions` dual schema (D-7). The legacy quota mirror and the application mirror are pure cost/complexity, not correctness. The portfolio migration is correct but wastes a read per login (E-8).

---

## X. Storage & File Handling Audit (Task §12)

Verified against `storage.rules` and `functions/placements.js`.

| Check | Finding | Evidence |
|---|---|---|
| Resume upload | Owner-only write to `resumes/{uid}/{fileName}`; identity from `request.auth.uid` | `storage.rules` |
| PDF validation | `request.resource.contentType.matches('application/pdf')` enforced server-side **and** mirrored client-side | `storage.rules`, `resume_service.dart` |
| File size limit | `request.resource.size <= 5 * 1024 * 1024` (5 MB), boundary `<=` matches the client validator | `storage.rules` |
| Delete safety | `request.resource == null` branch permits owner deletes (correctly handled — `request.resource` is null on delete) | `storage.rules` |
| MIME validation | PDF-only; the client also validates before upload; the server `reviewResume` re-parses via `pdf-parse` so a mislabelled file fails at parse time, not silently | `storage.rules`, `ai/resumeReview.js` |
| Filename handling | `resumes/{uid}/latest.pdf` is the canonical upload path; the snapshot uses a server-generated deterministic name (`snapshots/app_{applicationId}.pdf`) — **no client-controlled path segments beyond `uid`** | `placements.js` |
| Download URLs | `logPlacementApplication` mints a **signed URL valid until 01-01-2035** and stores it in the application doc; the client opens that URL | `placements.js` (INT-1 note in the rules confirms this) |
| Storage path consistency | The snapshot path `resumes/{uid}/snapshots/{fileName}` is now covered by a dedicated rule (the former single-segment rule did not match two-segment paths) | `storage.rules` (INT-1) |
| Deletion | Owner can delete their resume; snapshots are `allow write: if false` — **only** the Admin SDK removes them | `storage.rules` |
| Orphan files | **No reconciliation.** Deleting a review or an application does not delete any Storage object; deleting a user does not remove `resumes/{uid}/`. Unbounded orphans | — (K-5) |
| Caching | `PortfolioCacheService` caches the portfolio snapshot locally; resume URLs are re-minted per apply | `portfolio_cache_service.dart` |
| Duplicate uploads | Overwriting `latest.pdf` is allowed (by design); the snapshot copy is now **write-once** (gated on `snapshotFile.exists()`), so a re-apply cannot overwrite the submitted snapshot (the v9.2 BUG-3 fix — verified present) | `placements.js` |
| Portfolio documents | Nested on the user document, not in Storage; read access includes teachers and any alumni (see the privacy note below) | `firestore.rules` |
| Teacher resources | Notes are Firestore documents, not Storage; teachers write, all authenticated users read | `firestore.rules` |
| Storage ↔ Firestore consistency | Consistent for the **live** resume path. **Inconsistent on delete**: neither a deleted review nor a deleted application nor a deleted user cascades to Storage. The long-lived (2035) signed URL also outlives the access it represents, so a URL leaked from an application doc is valid far beyond the student's control | `placements.js`, `storage.rules` |

### X-1 — Privacy exposure via the rules (task §3 "field-level protection")

Two rule grants expose more than the feature strictly needs. Both are **documented as deliberate** in `firestore.rules`, and both are listed here as findings rather than as bugs:

1. `allow read: if isAuthenticated() && userRole() == 'alumni' && resource.data.role == 'student';` on `users/{userId}` — any alumni can read **any** student's full user document (the portfolio is a nested map, so phone/email/academic data come with it), not just students they mentor. The rule file itself flags this (M2) as a consequence of the nested-map design.
2. `match /{path=**}/applications/{appId} { allow read: if isTeacher() || isAlumni() || … }` — any alumni can read **every** application in the database, including the long-lived `resumeUrl`. Coupled with the 2035 signed URL, this is the widest data exposure the audit found outside the release-configuration items.

Neither is a rule *bug* (the intent is stated and role-gated), but both should be conscious, documented decisions before release, and both would shrink automatically if the portfolio moved to a subcollection and if alumni were scoped to placements they authored. **Not implemented during this audit.**
---

## Y. Notifications & Real-Time Features Audit (Task §13)

### Y-1 — Trigger-written notifications (verified from `functions/triggers/index.js`)

| Notification | Writer | Document id | Idempotent? | Duplicate risk |
|---|---|---|---|---|
| `newMessage` | `onChatMessageCreated` | `new_message_{messageId}` | **Yes** (deterministic id) | None |
| `mentorshipRequested` | `onMentorshipRequestCreated` | `mentorship_requested_{requestId}` | **Yes** (deterministic id) | None |
| `mentorshipAccepted` / `mentorshipRejected` | `onMentorshipRequestResponseNotifyStudent` | `mentorship_response_{requestId}` | **Yes** (deterministic id) | None (written once per status change) |
| `newJobPost` | `onOpportunityPostedNotifyStudents` | auto-id | Partly — the trigger is `onDocumentCreated`, so it fires once per opportunity | None from re-fire; **but any authenticated user can create an opportunity (D-9), so a student can trigger a broadcast to every student** |
| `statusChange` | `updateApplicationStatus` | auto-id | No — one per status change (intended) | None |
| `inactiveChatReminder`, `reminder` | `sendInactivityReminders` | auto-id | **No** — guarded only by `maybeCreateNotification`'s 20 h window query, which is **not** transactional (E-10) | Re-run after partial failure re-evaluates; concurrent invocations can both pass the guard |
| `engagementMilestone` | `recomputeEngagementSummary` | auto-id | Partly — guarded by `maybeCreateNotification`, and only fires when `dailyStreak > 0 && dailyStreak % 7 === 0` | Same non-transactional guard (E-10) |

### Y-2 — Chat streams

| Check | Finding | Evidence |
|---|---|---|
| Duplicate listeners | Each chat provider holds one subscription map entry per open chat and cancels on switch/close | `ChatProvider`, `AlumniGroupChatProvider` |
| Listeners surviving logout | **No** — `ChatProvider.reset()` and `dispose()` both cancel every subscription (v9.2 fix, verified); `AlumniGroupChatProvider` likewise | `chat_provider.dart` |
| Excessive stream updates | **Yes** — `getMessagesStream` has no `limit`, so every new message re-delivers the whole history (E-1) | `chat_service.dart` |
| Unnecessary rebuilds | The chat view rebuilds on each snapshot; with a bounded stream this is fine, unbounded it grows | E-1 |
| Stale subscriptions | None found beyond the unbounded payload |
| Missing cleanup | None on the chat side |
| Repeated writes caused by listeners | `ChatService.sendMessage` performs an extra `chats/{chatId}.get()` before writing, and the trigger performs another `chats/{chatId}.get()` — two reads per message for one write | G-1.12, G-1.13 |

### Y-3 — `notifications` subcollection

| Check | Finding |
|---|---|
| Stream boundedness | Bounded (`orderBy('createdAt')` + `limit 50`) — correct |
| Bulk operations | `markAllAsRead` / `deleteReadNotifications` are **unbounded reads + unchunked writes** (E-2) |
| Duplicate notifications | Only via the non-transactional `maybeCreateNotification` path (E-10) |
| Listener lifetime | `NotificationsProvider.reset()` clears and stops notifying (correct) |
| Client write path | `allow create: if isOwner(userId)` — the client *may* create its own notifications, but the only client caller (`NotificationsProvider.addNotification`) is dead code (E-15). System notifications are written by the Admin SDK, which bypasses rules |

### Y-4 — Real-time groups

* **Alumni group chat** — `alumni_group_messages` rule correctly binds `senderId == request.auth.uid` on create and restricts update/delete to the sender. **Stream is unbounded** (E-1).
* **Opportunities** — real-time list bounded at 50; the surrounding facet queries are not (D-6).
* **Mentorship** — no unbounded stream; requests are read scoped by participant.

**Verdict:** listener *lifecycle* is healthy (the v9.2 fixes hold). The real-time problems are **payload boundedness** (E-1) and **the non-transactional notification guard** (E-10) — neither is a leak.

---

## Z. Error Handling & Reliability Audit (Task §15)

### Z-1 — Failure-path matrix

| Failure | Handled? | Where | User-visible behaviour | Gap |
|---|---|---|---|---|
| Network unavailable | Yes | service try/catch -> provider error state -> `error_messages.dart` | Friendly message; retry offered | — |
| Firebase unavailable | Yes | same | Friendly message | — |
| AI provider unavailable | Yes | `generateChatResponse` catch in `askAI` returns "I'm having a bit of trouble thinking right now" rather than throwing | Graceful degradation | — |
| AI primary fails, fallback available | Yes | `callAIProvider` retries HF | Transparent | — |
| AI primary fails, **no fallback key** | Yes | throws a clear deployment error naming the missing key | Callable returns `internal` | Message reaches logs, not the user (correct) |
| Malformed AI response | Yes | `extractJSON` + trailing-comma repair + per-field coercion with defaults (`atsScore` defaults to 50) | Succeeds with defaults | Silent defaulting could mask a broken prompt — worth a metric |
| Timeout | **Partly** | Provider-level timeouts handled; **client/server timeout mismatch on placement apply (D-2)** | False "failed" on a slow success | D-2 |
| Quota exhausted | Yes | `enforceLimit` throws `resource-exhausted` with `usage` payload | "Monthly limit reached (n/month)" | Client displays a possibly-different number (E-5) |
| Permission denied | Yes | Rules enforce server-side; callables re-check role | Friendly message | — |
| Document missing | Yes | Guards checked (`!doc.exists` returns early in triggers; `not-found` in callables) | Handled | — |
| Stale data | Yes | Fingerprint/refresh gates + stream reconciliation | Handled | D-1 undermines the gate |
| Duplicate submission | **Partly** | `logPlacementApplication` is idempotent server-side; `maybeCreateNotification` is not (E-10) | No duplicate application; possible duplicate notification | E-10 |
| Partial write | Yes | Application writes are transactional (canonical + mirror); recommendation writes are idempotent rewrites | Handled | — |
| Callable failure | Yes | Every callable wraps in try/catch and rethrows a typed `HttpsError`; `deepAnalysis.js` uses a non-idiomatic but functional check (I-3 §7) | Friendly message | Inconsistency only |
| Logout during request | **Partly** | Providers set `_isDisposed` and drop stale responses; `ActivityFeedProvider` keeps running after logout (D-8) | No crash found | D-8 |
| Scheduler failure | Yes | Every job has try/catch and logs; **`autoExpireOpportunities` fails entirely above 500 docs (E-3)** | Silent to the user | E-3 |
| `getFeatureUsage` error | Yes | Returns `defaultUsageResponse` (0 used) — a quota read outage shows a full quota, not an error | Misleading but safe | Low |
| `incrementDailyUsage` error | Yes | Returns `{dailyCount: 1}` — a fabricated count on outage | Misleading | Low |

### Z-2 — Technical-detail leakage

* No stack traces, file paths, API keys or internal identifiers are surfaced to the UI. `error_messages.dart` maps exceptions to user-facing strings, and callables return generic `internal` messages while logging the real error server-side (`console.error`). **Verified by reading `functions/index.js`, `placements.js`, `ai/chat.js`, `helpers/shared.js` and the client error helpers.**
* The one place a low-level cause could reach a user is the `internal` wrapper in `logPlacementApplication`/`updateApplicationStatus`, which embeds `error.message` in the thrown `HttpsError`. That message is a Firebase SDK string (never a secret), so the exposure is minimal — but it is an implementation string reaching the client.

### Z-3 — Reliability verdict

The application handles the common failure paths correctly and never leaks secrets to the UI. The reliability gaps are: **D-2** (client timeout shorter than the server's, causing a false failure), **E-3** (batch-cap failure in a scheduler), **E-10** (non-transactional notification guard) and **D-8** (work continuing after logout). None of these is a crash path; all are behavioural.
---

## AA. Corrections & Additions (post-verification)

This section records findings made **after** the sections above were drafted, when `firestore.rules` and `storage.rules` were read in full. It also corrects two rows in § I / § Q that were written before those files were verified. Everything here supersedes the earlier text where the two disagree.

### AA-1 — Correction to §I-1 row 6 (field-level protection)

The earlier row is **wrong** in one part. The verified position:

* **`placements` HAS a full-schema validator** — `isValidPlacementData()` in `firestore.rules` checks every required field's type, non-empty strings, the `deadline`/`postedAt` timestamps and binds `createdBy == request.auth.uid`, on **both** create and update (see also the referenced `/Firestore Cost/C-1` application note). This is a genuine, strong control.
* **`opportunities`, `mentorship_requests`, `chats` and `public_profiles` have NO equivalent validator.** They are governed only by identity/ownership checks (`alumniId == request.auth.uid`, `studentId == request.auth.uid`, membership in `participantIds`, `uid == request.auth.uid`). There is no `isValidOpportunityData()` anywhere in the rules file — that name does not exist in the repository. See **D-10**.

### AA-2 — Correction to §Q-2 rows (verified against `firestore.rules`)

| Row | Correct position |
|---|---|
| `notes` | **Write is teacher-only.** `allow read: if isAuthenticated();` / `allow create, update, delete: if userRole() == 'teacher'`. The earlier row said "authenticated user" for writes — incorrect. Read-for-all-authenticated is correct, so the unbounded-stream finding (E-1) stands |
| `public_profiles` | **Owner-alumni client writes are allowed** (`create`/`update`/`delete` bound to `request.auth.uid` and `profileKey`), and `read` is allowed **without authentication** when `resource.data.isPublic == true` (or by the owner). The earlier "read-only projection / all authed" was inexact |
| `user_ai_quotas/{uid}`, `ai_usage/{uid}`, `resume_usage/{uid}`, `career_coach_usage/{uid}`, `ai_analysis_usage/{uid}`, `ai_rate_limits/{uid}`, `ai_spam_check/{uid}` | All grant `read: if isOwner(userId)` and `write: if false`. Clients **can** read their own quota; they can never write it. (Corrects the "if false (client read? verify)" note) |
| `ai_conversations` | `read` bound to `resource.data.userId == request.auth.uid`; `write: false` |
| `announcements` | `read: if isAuthenticated()`; `write: false` — confirmed **dead** (no writer, no reader) |

### AA-3 — NEW: D-9 (High) — Any authenticated user can post an opportunity, and doing so broadcasts to every student

**Evidence** — `firestore.rules`:

```
match /opportunities/{opportunityId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated() &&
    request.resource.data.alumniId == request.auth.uid;   // <- no role check
  allow update: if isAuthenticated() &&
    resource.data.alumniId == request.auth.uid;
  allow delete: if isAuthenticated() &&
    resource.data.alumniId == request.auth.uid;
}
```

The rule's own comment says *"Job opportunities — **alumni** create"*, but the condition is `isAuthenticated()` — **not** `userRole() == 'alumni'`. Any signed-in account (a **student**, or any account whose `role` is `student`, or one that has no `role` yet) can create an opportunity by setting `alumniId` to their own uid.

**Category:** confirmed authorization gap (privilege — content injection into a shared, recommendation-feeding collection).
**Impact:**
1. **Broadcast amplification.** `functions/triggers/index.js::onOpportunityPostedNotifyStudents` is an `onDocumentCreated` trigger on `opportunities/{opportunityId}` that writes a `newJobPost` notification to **every** `profileCompleted` student. A student creating one opportunity therefore pushes a notification to the entire student body. Repeated creation is an unbounded spam primitive against all users.
2. **Recommendation poisoning.** `recommendations/refresh.js` gathers "all active opportunities" as candidates. Injected opportunities enter every eligible student's recommendation set (subject to the deterministic scorer).
3. **Self-service stats.** The alumni dashboard's opportunity stats (`getOpportunityStatsForAlumni`) count documents where `alumniId == uid`, so a student can inflate their own "opportunities posted" figure.
4. Combined with **D-10** (no schema validation), the injected document need not even be well-formed.

**Action (v9.2.3):** change the three opportunity write rules to require `userRole() == 'alumni'` (matching the comment and the placement model), and add `isValidOpportunityData()` mirroring `isValidPlacementData()`. This is a rule-only change — no application code needs to move, because the legitimate writers (`OpportunityService`, alumni) already satisfy the stricter condition.

### AA-4 — NEW: D-10 (Medium) — `opportunities` (and mentorship/chats) have no schema validation

**Evidence:** `isValidPlacementData()` exists; there is **no** `isValidOpportunityData()`, and none of the `opportunities`, `mentorship_requests`, `chats`, `public_profiles` or `notes` writes are schema-checked beyond identity. `functions/triggers/index.js::onOpportunityPostedNotifyStudents` then reads `opportunity.title`/`opportunity.company` with fallbacks (`|| "Role"`, `|| "Company"`), so a malformed opportunity still triggers a full broadcast of a notification whose body reads "Role at Company".

**Category:** confirmed robustness/abuse gap.
**Impact:** an attacker (per D-9, any authenticated user) can create an opportunity with missing or wrong-typed fields; the notification still fires to every student, and the opportunities UI (`getActiveOpportunities`, `orderBy('postedAt')`) may fail to sort or render it cleanly. `visibility`-style fields are also unvalidated, so an opportunity could claim fields the UI assumes.
**Action:** add `isValidOpportunityData()` (title/company/description/type/location strings non-empty, `postedAt`/`applicationDeadline` timestamps, `isActive` bool, `alumniId == request.auth.uid`) and apply it on create+update, exactly as placements do.

### AA-5 — NEW: Low — `getFeatureUsage` performs a write on a read path

`functions/ai/quota.js::getFeatureUsage` calls `seedFeatureFromLegacy`, which `quotaRef.set(..., {merge:true})` — so a **usage check** (the cost of opening the AI screens) writes to `user_ai_quotas/{uid}` (and reads the legacy mirror) the first time it sees a doc/map it has not seeded. It is idempotent, but a read endpoint is not side-effect-free: the first AI-screen open per user per feature costs 1-2 extra reads **and a write**, and it means a client-triggered read can re-create a quota doc the Admin SDK had removed.
**Severity:** Low (correct but surprising). Fix: seed lazily *inside the consume path only*, and have `getFeatureUsage` return defaults without persisting.

### AA-6 — NEW: Low — `incrementDailyUsage` fabricates a count on error

`functions/ai/quota.js::incrementDailyUsage` catches all errors and returns `{dailyCount: 1, lastResetAt: now.toISOString()}`. If the quota transaction fails (Firestore unavailable), the chat screen is told the user has sent **1** message today even if they had sent 40. It never blocks (the daily limit is soft), so the impact is display-only — but it is fabrication rather than an error, and it could reset a displayed near-limit to "1/50". **Severity:** Low.

### AA-7 — False positives and environment-only warnings (explicitly separated, per Task §24)

The following were considered and are **not** application defects. They are recorded so they are not re-raised:

| Observation | Verdict |
|---|---|
| `docs/logs.md`: repeated `403 App attestation failed` / `Too many attempts` | **Environment/config, not a code defect** — the App Check code is correct; the token must be allow-listed in the Console (C-2). Do not "fix" this in Dart |
| `docs/logs.md`: GMS/Ads/Measurement noise noise | **Environment-only** (the emulator image), unrelated to CampusConnect code — the v9.2.2 classification holds |
| Local Node v24 vs deployed Node 22 | **Not a defect** — the deployed runtime is governed by `engines.node`; no behavioural difference was observed in the modules audited (§N-2) |
| `collectionGroup` scans "deliberately unbounded" | **Real cost, not a bug** — the comment correctly explains why a naive `limit()` would under-count, so the finding is scoped as a *scalability* item (D-4), not a correctness bug |
| `cors: false` on the three placement callables | **Only a problem if the web target ships** (E-6) — mobile targets are unaffected |
| Legacy quota mirrors and `ai_conversations` still present | **Intentional transition debt, not a bug** (§K-3) — deprecation is a scheduled task, not an audit finding |
| `hasFlattenedPortfolioShape` unused | **Dead code, expected** — superseded by `migrateFlattenedPortfolio` (E-15) |
| `users/{userId}` catch-all removed | **Correct and required** — verified the privilege-escalation fix is genuinely in effect (§I-1, F-1) |
| `deepAnalysis.js` `httpErrorCode` check | **Functional despite being non-idiomatic** — `HttpsError` does expose both properties (I-3 §7) |
| `getChatById` fallback throwing internally | **Accidentally correct** — the catch falls through to the service (E-12); a cleanliness issue, not a live bug |

### AA-8 — Updated v9.2.3 blocker list

**D-9 and D-10 are added to the v9.2.3 correctness/security set** in §L. The complete set of items that must be fixed before a release is:

`C-1` (release signing) · `C-2` (App Check enforcement) · `D-1` (trigger chain / fingerprint thrash) · `D-2` (apply timeout + rollback) · `D-3` (eligibility divergence) · **`D-9` (opportunity write authorization)** · **`D-10` (opportunity schema validation)**.

Everything else in §D/§E is a cost, performance or debt item that can be scheduled into v9.2.4/v9.2.5 without blocking v9.3.

---

## AC. Further Rule-Reading Corrections (second pass)

Reading `firestore.rules` line by line a second time surfaced two imprecise claims in section I-1 and one new finding. Both corrections matter because they change what the client can write.

### AC-1 - Correction to I-1 row 5 ("server-only documents")

Row 5 said the server-owned documents are all `allow read, write: if false`. That is exactly true for **`analytics_events` only**. Verified per collection:

| Collection | Verified rule |
|---|---|
| `analytics_events/{eventId}` | `allow read, write: if false` - Admin SDK only (the only truly `if false` pair) |
| `recommendations_meta/{metaId}` | `allow read: if isOwner(userId); allow write: if false` |
| `engagement_summary/{summaryId}` | `allow read: if isOwner(userId) || isTeacher(); allow write: if false` |
| `user_ai_quotas/{uid}` + the four legacy quota docs | `allow read: if isOwner(userId); allow write: if false` |
| `career_coach/{docId}` | `allow read: if isOwner(userId); allow write: if false` |
| `activities/{activityId}` | `allow read: if isOwner(userId); allow create, update, delete: if false` |

All are correctly **write-denied to clients** (the security property that matters); they differ only in who may read. The finding is unchanged in substance, corrected in precision.

### AC-2 - Correction to I-1 row 7, and NEW: D-11 (Medium) - `isVerified` and `profileCompleted` are client-writable on the owner's own document

Row 7 claimed `profileCompleted` and `isVerified` are server/teacher controlled. **That is wrong.** The only field the `users/{userId}` write rule protects is `role`:

```
function canWriteRole(userId) {
  return !exists(...) || !('role' in resource.data)
      || !('role' in request.resource.data)
      || resource.data.role == request.resource.data.role;   // <- role ONLY
}
allow write: if isOwner(userId) && canWriteRole(userId);     // every other field is owner-writable
```

So an owner may write **any** field on their own document except `role` - including `profileCompleted`, `isVerified`, and any other flag.

**Category:** confirmed authorization precision gap.
**Impact:**
1. `profileCompleted: true` is trusted as a **query filter** in `firestore.rules` (`resource.data.profileCompleted == true` on the alumni-directory read) and in **Cloud Function queries** - `onOpportunityPostedNotifyStudents` selects recipients with `where('profileCompleted','==',true)`, and `recomputeEngagementScores` processes `where('profileCompleted','==',true)`. `onProfileUpdatedRefreshAI` also early-returns unless `after.profileCompleted === true`. A student can therefore set the flag directly and: enter the alumni-directory/alumni-visibility path, be included in every future opportunity broadcast, and arm the recommendation trigger - without completing a profile.
2. `isVerified: true` is **not referenced by any rule** (verified: the string does not appear in `firestore.rules`), so today its impact is UI-display only. **If a future rule ever trusts `isVerified`, this becomes a High-severity privilege gap** - worth closing now rather than later.
3. Neither flag is validated against actual profile content anywhere, so the flags are self-asserted.

**Note:** `profileCompleted` *is* legitimately client-set at the end of profile setup (`profile_setup_view.dart`), so the field cannot simply be made immutable. The correct fix is a rule that permits `profileCompleted` only on a transition into a document that actually contains the required sections (or a server-side validator), and a rule that makes `isVerified` `write: false` (Admin SDK only) unless a legitimate client path needs it.

**Severity:** Medium today; would become High if `isVerified` is ever trusted by a rule or a server guard. Added to the v9.2.3 rules workstream alongside **D-9** and **D-10**.

### AC-3 - Confirmation of the I-1 row 3 / row 4 verdicts

After the full read: **no blanket `allow` exists anywhere** except the enumerated, purpose-specific grants; the final `match /{document=**} { allow read, write: if false; }` fallback is present and correctly last; `userRole()` is guarded with `exists()` so a doc-less user resolves to `null` rather than throwing (which would deny unrelated reads). The v9.2 recursive-catch-all removal is genuinely effective - every `write: false` it used to void is now enforceable. Section I-1 rows 3 and 4 are confirmed.

---

## AB. Conclusion

The application is in **materially better shape than the v9.2/v9.2.2 narrative suggested**. Every fix those workstreams claimed is present in source and verified here: the privilege-escalation closure, the teacher-analytics deduplication and N+1 removal, the listener-lifecycle fixes, the recommendation fingerprint gate, the portfolio migration, the single-writer engagement model, and the `ai_interactions` retention-field fix. **No regression was found.** The rule layer is genuinely strong: no default-allow, owner scoping throughout, role checks on the sensitive paths, server-only writes on every server-owned collection, and a correct deny-all fallback.

What remains divides cleanly into three kinds:

1. **Ship blockers (7):** the debug-signed release (C-1), unenforced App Check (C-2), and five client/server or rule-level defects — D-1 (the resume-trigger chain that makes the recommendation gate thrash), D-2 (a client timeout shorter than the server's, which reports a successful apply as a failure), D-3 (client/server eligibility disagreement), **D-9** (any authenticated user can broadcast an opportunity to every student) and **D-10** (no schema validation on those writes). None requires an architecture change; four are one-file edits and two are rule edits.

2. **Scalability cliff (the boundedness workstream):** twelve unbounded queries and streams, of which the two `collectionGroup` scans in teacher analytics and the unindexed facet scans in the alumni directory / opportunities screens are the ones that will break first as data grows. They are correct today and will stay correct only while the dataset is small.

3. **Currency and debt:** the Function dependency stack (`firebase-functions` 5→7 is verifiably safe on Node 22 and compatible with the installed `firebase-admin` 12; `firebase-admin` 14 and `pdf-parse` 2 need testing), the four major-version Flutter packages, the duplicated quota constants, the confirmed dead code, and the missing regression tests for exactly the defects this audit found (a rules test, a callable-contract test, and boundedness assertions).

Nothing found here justifies rewriting the architecture, replacing the recommendation engine, or redesigning the UI. The path to a release is: fix the seven blockers, bound the twelve queries, add the three missing test classes, then proceed to v9.3 with a clear conscience.

**No code was modified during this audit.** Every finding above is reproducible from the cited file and symbol in the current working tree.

---

*End of report — `docs/v9_2_3_audit_report.md`.*
---

## AD. Corrections Applied in v9.2.4 (audit metadata only)

> **This section was added by v9.2.4.** It does **not** alter any finding in the
> body of the report — the report is preserved verbatim as the historical record
> of the audit. It records three metadata corrections required by v9.2.4 Task
> §16, and states which findings v9.2.4 subsequently implemented.

### AD-1 — Report date corrected

The header row `**Report date**` originally read `2025‑10‑02`. That carried a
**wrong year**. The audit was performed in **2026**; the correct date is
**`2026‑10‑02`**. The body of the report is unchanged.

### AD-2 — v9.2.3 is audit-only; v9.2.4 is the implementation release

To avoid any ambiguity between the two:

| | v9.2.3 | v9.2.4 |
|---|---|---|
| Nature | **Audit only — no code changed** (this report; `Code changes made` row = *None*) | **Implementation release** |
| `pubspec.yaml` at its time | `9.2.2+100` (audited revision) | `9.2.4+101` |
| Output | `docs/v9_2_3_audit_report.md` | `docs/v9_2_4_hardening_report.md`, the code fixes, and this addendum |

Every finding in this report describes the working tree **at the audited
revision (`9.2.2+100`)**. Where a v9.2.4 change has since superseded a finding's
`Action`, the finding is still the accurate record of what was wrong at audit
time. The v9.2.4 report is the authoritative record of what was fixed.

### AD-3 — Test-count wording reconciled (historical results not changed)

The report quotes test counts in more than one place, and they were written at
different moments of the audit:

| Location | Wording |
|---|---|
| §B (Audit Coverage) | "44 Flutter test files plus 8 Functions test files"; "44 Flutter test files · 8 Functions test files" |
| §J-1 (Testing Gaps) | "Flutter: 47 suites"; "Functions: `engagement_activity.test.js`, `placement_transitions.test.js`, `quota.test.js`, `recommendations_refresh_dedupe.test.js`, plus the shared `firestore_fake.js`" |
| §F-2 #9 | "Tests all green (476 Flutter / 50 Functions)" — marked **Cannot Verify as counts** |

These are **not** competing results: they are counts of *test files* (§B), of
*available suites* (§J), and a *quoted historical claim being re-classified*
(§F-2 #9). The audit executed **no** test run, so it could not and did not
assert a passing count.

**Reconciliation (no historical result is altered):**

* The §B and §J figures describe the same repository at slightly different
  enumeration points; the file count grew between them and neither was
  re-derived. Treat "44 files" (§B) and "47 suites" (§J-1) as *approximate
  file enumerations of the audited revision*, not as executed test counts.
* The "476 Flutter / 50 Functions" in §F-2 #9 is a **quote of the v9.2.2
  report's claim**, which the audit explicitly marked *Cannot Verify* — it was
  never the v9.2.3 audit's own measurement and must not be read as one.
* The authoritative **executed** counts are recorded in the v9.2.4 report and
  in `docs/confirmation.md`, which were produced by actually running the suites.

### AD-4 — Findings implemented by v9.2.4

For traceability, the findings in this report that v9.2.4 fixed (see
`docs/v9_2_4_hardening_report.md` for the full record):

`C-1` · `C-2` · `D-1` · `D-2` · `D-3` · `D-7` · `D-9` · `D-10` · `D-11` ·
`E-3` · `E-18`

Findings **not** in v9.2.4 scope (deferred to v9.2.5/v9.2.6) remain as recorded
in §L: `C-3`, `D-4`, `D-5`, `D-6`, `D-8`, `E-1`, `E-2`, `E-4`…`E-17`, and the
`§N` dependency/toolchain work.

---

*End of v9.2.4 addendum. The audit report above is unchanged.*
