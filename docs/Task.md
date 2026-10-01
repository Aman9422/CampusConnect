# v9.2.2 — Runtime Performance & Recommendation Refresh Optimization

## Objective

Perform a targeted optimization pass on CampusConnect based on the latest runtime log from the Google Pixel 9 Android 16 emulator.

The goal is to reduce startup jank, eliminate unnecessary recommendation regeneration, remove avoidable compatibility/refresh work, and keep the existing architecture, functionality, security model, and UI unchanged.

## 1. Startup Performance — P0/P1

Investigate the remaining startup jank shown by:

* `Skipped 77 frames`
* `Skipped 30 frames`
* `Skipped 32 frames`

Do **not** guess the root cause.

### Requirements

1. Profile the application in **Flutter Profile mode** using DevTools.
2. Identify the actual startup functions/widgets/providers consuming the frame budget.
3. Inspect:

   * `main.dart`
   * Firebase initialization
   * App Check initialization
   * `AuthGuard`
   * `MultiProvider`
   * provider constructors and `init/load` methods
   * first dashboard construction
   * profile loading
   * recommendation initialization
   * resume-history initialization
   * teacher analytics initialization
   * SharedPreferences/local storage
   * image/font loading
   * navigation initialization
4. Move non-critical work out of the first-frame path where safe.
5. Preserve Firebase/App Check correctness and authentication behaviour.
6. Avoid introducing unnecessary delays solely to hide the jank.
7. Add lightweight timing/debug instrumentation where useful, but never log secrets, tokens, or personal data.

### Acceptance

Document the actual startup bottleneck identified from profiling and the exact optimization applied.

---

## 2. Recommendation Refresh Deduplication — P1

The runtime log shows repeated:

`RecommendationService: server regenerated recommendations`

for the same authenticated session.

### Requirements

1. Trace every caller of recommendation regeneration.
2. Identify whether duplicate calls originate from:

   * `AuthGuard`
   * Dashboard initialization
   * providers
   * Career Coach
   * profile synchronization
   * login/session lifecycle
   * recommendation freshness checks
3. Implement end-to-end refresh deduplication.
4. Multiple concurrent callers for the same user/state must share one in-flight refresh instead of creating multiple server calls.
5. A fresh recommendation set must not be regenerated simply because a widget/provider rebuilds.
6. Preserve the existing recommendation fingerprint/cache architecture.
7. Regeneration should still occur when relevant intelligence inputs actually change.
8. Preserve:

   * unified recommendation writer
   * deterministic eligibility/security logic
   * recommendation metadata
   * cache behaviour
   * existing recommendation document structure
9. Do not solve this by simply disabling recommendation refresh.

### Acceptance

For one login/session, the same recommendation refresh request must result in **one effective server regeneration**, unless a legitimate fingerprint/state change explicitly requires another refresh.

Add regression tests for:

* concurrent refresh requests
* repeated initialization
* stale recommendations
* changed intelligence fingerprint
* logout/login lifecycle

---

## 3. Resume Review Provider Refresh Deduplication — P2

The log shows:

`Loaded 0 history items`

followed immediately by:

`Refreshed 0 history items`

### Requirements

1. Trace the initialization path for `ResumeReviewProvider`.
2. Determine whether `loadHistory()` and `refreshHistory()` are redundantly executed.
3. Avoid duplicate Firestore reads when the existing data is already current.
4. Preserve explicit user-triggered refresh functionality.
5. Ensure the provider does not accidentally suppress legitimate updates after a new review.

### Acceptance

Normal page initialization should perform only the minimum required history read(s), while an explicit refresh still reloads data.

---

## 4. Portfolio Compatibility Cleanup — P2

The log repeatedly reports:

`detected flattened portfolio shape ... next save will use full (non-diff) write to reconstitute nested map`

### Requirements

1. Inspect the current portfolio schema and compatibility handling.
2. Identify existing flattened portfolio documents.
3. Confirm the canonical structure remains:

`users/{uid}/portfolio`

with the intended nested fields.
4. Implement a **safe, controlled migration** for legacy flattened portfolio data where appropriate.
5. Do not delete valid portfolio information.
6. Preserve backward compatibility during migration.
7. After migration, normal portfolio updates should use the optimized nested/diff-write path.
8. Migration must be idempotent and safe to rerun.

### Acceptance

After migration, previously affected accounts no longer require the flattened-shape compatibility path during normal login/save operations.

---

## 5. App Check Debug Configuration — P0 Validation

The runtime log repeatedly shows:

* `403 App attestation failed`
* `Too many attempts`
* `using placeholder token`

### Requirements

1. Verify the emulator is using the intended Firebase project.
2. Verify the current App Check debug token is allowlisted for that exact project.
3. Confirm debug App Check works correctly on the development emulator.
4. Do not weaken production App Check enforcement.
5. Do not hard-code or commit debug tokens.
6. Verify release configuration still uses the intended production attestation provider.
7. Avoid unnecessary repeated App Check requests/retries during a session where possible.

### Acceptance

A debug emulator session should obtain a valid App Check token without repeated `403`/`Too many attempts` errors.

---

## 6. Google Play Services / Emulator Diagnostics — P3

The log contains repeated:

* `DeadObjectException`
* `Phenotype.API is not available`
* `Unknown calling package name 'com.google.android.gms'`
* `DEVELOPER_ERROR`

### Requirements

1. Determine whether these errors originate from CampusConnect or the Android Emulator/Google Play Services environment.
2. Do not modify application logic merely to suppress external emulator noise.
3. If the errors are environment-specific, document them separately.
4. Verify Firebase Authentication and core Firebase operations still work normally.

### Acceptance

Clearly classify these messages as:

* application issue,
* configuration issue, or
* emulator/Google Play Services issue.

No unnecessary application-code changes should be made for emulator-only noise.

---

## 7. Teacher Analytics Regression Check

The latest log shows one Teacher Analytics load for the tested session:

`Loaded 3 reviews, 1 students, 1 depts, 1 pipeline eligible, 1 engagement summaries`

### Requirements

1. Confirm the previous load-deduplication fix remains active.
2. Ensure no new duplicate loads are introduced by this optimization pass.
3. Preserve the existing load-scoped cache and in-flight deduplication.
4. Re-test tab navigation, retry, logout, and re-login.

---

## 8. Listener Lifecycle Regression Check

The latest log contains multiple logout/login cycles and does not reproduce the previous Firestore `NOT_FOUND Target id not found` symptom.

### Requirements

Verify that:

* Opportunity listeners are cancelled correctly.
* Alumni directory listeners are cancelled correctly.
* Portfolio listeners are cancelled correctly.
* Chat/notification/group-chat listeners remain lifecycle-safe.
* Re-login does not create duplicate subscriptions.

Do not rewrite working listener architecture without evidence.

---

## 9. Logging Improvements

Keep useful diagnostics for optimization:

* startup phase timings
* provider initialization timing
* recommendation refresh reason
* recommendation refresh deduplication
* cache hit/miss
* expensive Firestore operations

Do **not** log:

* passwords
* API keys
* App Check debug tokens
* Firebase ID tokens
* private resume text
* private user data

Prefer structured/debug-only diagnostics where appropriate.

---

## 10. Testing

Add or update automated tests for:

### Flutter

* startup/provider initialization
* recommendation refresh deduplication
* Resume Review initialization/refresh
* portfolio migration handling

### Firebase Functions

* recommendation refresh behaviour where testable
* idempotent recommendation writes
* any affected callable/service logic

### Existing validation

Run:

```bash
flutter analyze
flutter test
cd functions
node --test
```

For every changed JavaScript file:

```bash
node --check <file>
```

Also build:

```bash
flutter build apk --release
```

---

## 11. Manual Validation

Test on the **Google Pixel 9 Android 16.0 emulator**.

### Startup

* cold launch
* first frame
* login
* dashboard opening
* navigation to other tabs

### Recommendation

* login
* observe recommendation generation
* navigate between Dashboard/Career Coach/Profile
* verify no unnecessary duplicate regeneration
* change a recommendation-driving profile field
* verify legitimate regeneration occurs

### Resume Review

* open history
* refresh manually
* submit a review
* reopen history

### Portfolio

* load an affected legacy portfolio
* edit/save
* reload
* verify canonical nested structure

### Lifecycle

* login
* navigate through listener-heavy screens
* logout
* login with another account
* repeat
* verify no duplicate listeners or stale callbacks

### App Check

* verify valid debug token acquisition
* verify repeated attestation failures no longer occur in a correctly configured emulator

---

## 12. Performance Measurement

Do not claim optimization success based only on the absence of log warnings.

Capture before/after measurements where possible using Flutter DevTools Profile mode:

* first-frame timing
* frame build/raster time
* startup duration
* number of recommendation refresh calls
* unnecessary Firestore reads
* provider initialization duration

Document what was actually measured.

---

## 13. Constraints

Do **not**:

* redesign the UI
* introduce new features
* replace the existing Firebase architecture
* replace Provider
* replace the recommendation engine
* disable recommendation generation
* weaken App Check/security
* remove required lifecycle listeners
* change quota limits
* expose API keys client-side
* make speculative performance changes without profiling evidence

The purpose of v9.2.2 is **targeted runtime optimization only**.

## 14. Documentation

Update the optimization/audit documentation with:

* problems discovered from the runtime log
* root causes
* files/components changed
* before/after measurements
* recommendation deduplication behaviour
* portfolio migration result
* App Check configuration result
* emulator-only warnings
* test results
* remaining known issues

## Definition of Done

v9.2.2 is complete when:

* startup bottlenecks have been profiled and the confirmed expensive work has been optimized
* recommendation regeneration is deduplicated
* Resume Review redundant initialization is resolved where confirmed
* legacy portfolio compatibility is reduced through safe migration
* App Check debug configuration is working correctly
* Teacher Analytics and listener lifecycle fixes remain stable
* all automated tests pass
* release APK builds successfully
* before/after performance evidence is documented
* no existing functionality, security controls, or architecture is unnecessarily changed.
