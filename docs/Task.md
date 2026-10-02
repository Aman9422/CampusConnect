# v9.2.4 — Critical Security, Correctness & Production Hardening

## Objective

Implement the critical and high-priority security, correctness, reliability, and production-readiness fixes identified by the complete **v9.2.3 Whole-Application Deep Audit**.

Do **not** redesign the UI, replace the architecture, rewrite the recommendation engine, or perform broad dependency upgrades in this version.

The goal is to remove the current release blockers and harden the affected flows before moving to the performance/cost optimization phase.

---

## 0. Deployment Scope — v9.2.4 re-scope (authoritative)

> **Added during v9.2.4.** This project is a final-year academic submission. It is
> **not** a Play Store release, and v9.2.4 does not prepare it to be one. Where
> §1, §2, §13, §14, §15, §16 or the Definition of Done below still read as
> Play-centric, they carry an inline **`v9.2.4 re-scope`** note rather than being
> silently rewritten — the Play-centric wording is preserved as the original
> intent, and the note states the scope that actually applies.

**CampusConnect is only a final-year academic project and will NOT be published on Google Play.**

Deployment target for v9.2.4:

```
Firebase backend (Auth · Firestore · Storage · Cloud Functions)
        |
        v
properly signed Flutter *release* APK
        |
        v
direct installation on a phone / emulator (adb install, USB or file transfer)
        |
        v
final-year project demonstration
```

### Required

* A real (non-debug) release signing configuration, with credentials never committed.
* A release APK that installs and runs on the demo device.
* A Firebase backend reachable from that APK (Auth, Firestore, Storage, Functions).
* An App Check posture that is **documented and deliberate** for a direct-APK, non-Play distribution.

### Explicitly out of scope

* Google Play Store publication — draft, internal, closed or open testing tracks, staged rollout.
* A Google Play Console developer account and the one-time **$25** registration fee.
* Play Store upload, review, Play App Signing, upload-key reset flows.
* Distributing via an App Bundle (`.aab`) / `bundletool` (buildable for validation only).
* Paid or commercial distribution infrastructure of any kind.

### Resulting constraints

* "Upload key" / "upload keystore" anywhere in this document means the
  **direct-distribution release key** — the key that signs the APK handed to the
  examiner or installed on the demo device.
* `flutter build appbundle --release` remains available as an *optional extra
  check* of the signing configuration. It is **not** a delivery artifact and is
  **not** required for v9.2.4 to be complete.
* **No insecure App Check bypass** may be introduced to work around the non-Play
  attestation constraint (see §2). In particular: no release build may be
  downgraded to the App Check debug provider, and no custom attestation backend
  may be introduced.

---

## 1. Release Signing — C-1

> **v9.2.4 re-scope.** `upload keystore` here means the **direct-distribution
> release key** that signs the APK installed on the demo device. Google Play
> upload is out of scope (see §0). The App Bundle build is kept only as an
> optional extra verification of the signing configuration.

Replace the debug signing configuration in `android/app/build.gradle.kts`.

Requirements:

* Create/configure a proper release signing keystore for direct APK distribution.
* Load credentials through `key.properties`.
* Ensure `key.properties` and keystore files are Git-ignored.
* Keep the debug signing configuration only for debug builds.
* Configure the release build to use the real release signing configuration.
* Do not commit secrets or keystore credentials.

Validation:

* `flutter build apk --release`
* Verify the APK is signed with the release configuration rather than the debug key
  (`apksigner verify --print-certs <apk>`, and/or compare the signing certificate
  SHA-256 against the keystore's `keytool -list -v` digest).
* Install that APK directly on the demo device/emulator and launch it
  (`adb install -r build/app/outputs/flutter-apk/app-release.apk`).
* `flutter build appbundle --release` — **optional**, used only to confirm the
  signing configuration applies to the bundle variant as well.

---

## 2. App Check — C-2 (re-scoped for direct-APK distribution)

> **v9.2.4 re-scope.** The original Play-centric requirements for this section
> (verify release-mode attestation, then enable enforcement for Firestore /
> Functions / Storage) describe a **Play-distributed** posture. This project is
> not Play-distributed (§0), so those steps are out of scope for v9.2.4 and are
> replaced by the non-Play posture below. They are kept in this document because
> they are exactly the steps to follow if Play distribution ever enters scope.

Finalize App Check without changing the existing provider architecture.

Current state:

* Debug App Check provider is already implemented.
* The current emulator debug token has already been allow-listed during manual testing.
* Provider selection is correct and pinned by tests: debug/profile → debug
  providers, release → Play Integrity / DeviceCheck, Web → reCAPTCHA v3.
* Enforcement is **not** enabled — and for a direct-APK distribution it must stay that way.

Requirements:

* Keep debug/profile providers for development.
* Keep Android release provider as Play Integrity. (Do **not** downgrade a release
  build to the debug provider — that would be an insecure bypass.)
* Keep iOS release provider as DeviceCheck.
* Keep Web release provider as reCAPTCHA v3 where applicable.
* Keep the debug-token allow-listing step for development, so emulator/device
  `flutter run` sessions attest cleanly and logcat is free of `403 App Attestation failed`.
* Do not commit debug tokens.
* Do **not** enable App Check enforcement for this deployment (see below).
* Introduce no insecure App Check bypass and no custom attestation backend.
* Document the final App Check state, including the reason enforcement is off.

### Why enforcement stays off for a direct-APK build

Firebase's Play Integrity provider does support apps distributed outside Google
Play, but the provider's setup requires the Play Integrity API to be **linked
from the Google Play Console**, and by default App Check requires the
`PLAY_RECOGNIZED` label — which *"apps not published on Google Play are not
eligible to receive"*. Relaxing that is an App Check **advanced setting**
("Exclusively outside Google Play": `PLAY_RECOGNIZED` not required, `LICENSED`
not required, minimum device integrity = *Device integrity*). The API link itself
still requires a Play Console developer account, which §0 puts out of scope.

Consequence: a sideloaded release APK cannot obtain a valid Play Integrity token
in this deployment. Turning enforcement on would deny **100 %** of the demo app's
Firestore / Cloud Functions / Storage traffic with `permission-denied`.

The correct choice is therefore to leave enforcement **off** and rely on the
layers that are enforced regardless of App Check:

| Layer | Enforced in v9.2.4? |
|---|---|
| Firebase Authentication (identity) | Yes |
| Firestore rules — including the D-9 / D-10 / D-11 hardening | Yes |
| Storage rules — resume ownership, MIME type, 5 MB size cap | Yes |
| Callable auth + server-side role re-checks | Yes |
| AI quota, rate-limit and spam windows | Yes |
| Server-owned writes (`allow write: if false` collections) | Yes |
| **App Check attestation** | **No — configured, deliberately not enforced, documented** |

### Enforcement verification (out of scope — Play-only)

Retained as the runbook for a future Play-linked build; **not** performed or
claimed for v9.2.4:

* Firestore
* Cloud Functions
* Storage

Document the final App Check state.

---

## 3. Resume Review Trigger Chain — D-1

Break the duplicate recommendation regeneration chain:

`resumeReview → users/{uid} write → onProfileUpdatedRefreshAI → second recommendation refresh`

Requirements:

* A resume review must result in **one effective recommendation refresh**.
* Prevent resume-review metadata writes from being interpreted as normal profile-content changes.
* Preserve:

  * `reviewCount`
  * `lastReviewAt`
  * `latestATSScore`
  * portfolio resume data
  * existing dashboard behaviour
* Preserve the unified recommendation writer.
* Preserve the server fingerprint mechanism.
* Ensure the same resume-review event cannot cause fingerprint thrashing.
* Ensure engagement points are awarded only once for the intended activity.

Preferred implementation:

* Update the profile-trigger change detection so resume-review metadata-only changes are ignored by `onProfileUpdatedRefreshAI`, while legitimate profile changes continue to trigger recommendations.

Validation:

* Unit tests for the trigger guard.
* Test one resume review → exactly one recommendation refresh path.
* Verify the stored fingerprint converges to one stable value.
* Verify no duplicate recommendation rewrite occurs.

---

## 4. Placement Apply Reliability — D-2

Fix the client/server timeout mismatch.

Current contract:

* `logPlacementApplication`: server timeout 120 s.
* Flutter client currently uses 30 s.
* `updateApplicationStatus`: server timeout 60 s.

Requirements:

* Raise the client timeout for placement apply to match the server.
* Raise application-status update timeout to match its server contract.
* Do not treat a client timeout as proof that the server failed.
* Do not immediately remove `_appliedPlacementIds` after timeout.
* Introduce a pending/reconciliation state when necessary.
* Reconcile server state with one read rather than blindly retrying.

Preserve server-side idempotency and duplicate prevention.

Validation:

* Normal apply.
* Slow/timeout simulation where possible.
* Apply succeeds on server but client response is delayed.
* Confirm the UI eventually shows the correct applied state.
* Confirm retries do not create duplicate applications.

---

## 5. Placement Eligibility Parity — D-3

Make the Flutter eligibility engine match the server's canonical semantics.

Requirements:

* Align `lib/services/eligibility_engine.dart` with `checkMandatoryEligibility` in `functions/recommendations/engine.js`.
* For `programs` and `branches`, use the same semantics everywhere.
* Update `docs/eligibility_rules.md` so it matches the actual implementation.
* Do not create a second eligibility engine.

Testing:
Create a table-driven test covering:

* programs only
* branches only
* both programs + branches
* matching program
* matching branch
* non-matching program
* non-matching branch
* missing student program

The client badge, recommendation engine, and documented rule must agree.

---

## 6. Opportunity Authorization — D-9

Harden `opportunities` Firestore writes.

Current audit finding:
Any authenticated user can currently create an opportunity while setting `alumniId` to their own UID, allowing unwanted broadcast/recommendation injection.

Requirements:

* Require `userRole() == 'alumni'` for legitimate opportunity creation.
* Preserve ownership checks for update/delete.
* Ensure students/teachers cannot create opportunities directly.
* Preserve legitimate alumni opportunity functionality.
* Do not weaken existing placement authorization.

Add/update security-rule tests for:

* alumni create → allowed
* student create → denied
* teacher create → denied
* unauthenticated create → denied
* owner update/delete → allowed
* non-owner update/delete → denied

---

## 7. Opportunity Schema Validation — D-10

Add proper Firestore validation for opportunities.

Create a validator equivalent in strength to `isValidPlacementData()`.

Validate at minimum:

* `title` → non-empty string
* `company` → non-empty string
* `description` → valid string
* `type` → valid string
* `location` → valid string
* `postedAt` → timestamp
* `applicationDeadline` → timestamp
* `isActive` → boolean
* `alumniId` → equals `request.auth.uid`

Apply validation to both create and update.

Reject malformed or wrong-typed opportunity documents before they can trigger notifications or enter recommendation generation.

---

## 8. Users Profile Flag Hardening — D-11

Review and harden the owner-writable profile flags identified by the second rules pass.

Focus on:

* `profileCompleted`
* `isVerified`

Requirements:

* Do not allow users to arbitrarily assert security-sensitive state.
* Preserve the legitimate profile-completion workflow.
* Validate `profileCompleted` against the required profile fields/state, either in rules or through a trusted server-side transition.
* Prevent unauthorized client manipulation of `isVerified` unless a legitimate application flow explicitly requires it.
* Verify that no existing feature breaks because of the stricter validation.

Do not change `role` behaviour; the current role protection must remain intact.

---

## 9. AI Chat Single-Writer Fix

Remove the duplicate client-side `ai_interactions` write identified as D-7.

Requirements:

* Server becomes the single writer for `users/{uid}/ai_interactions`.
* Use one consistent schema.
* Use one timestamp field: `timestamp`.
* Update the Flutter reader to consume the server schema.
* Remove obsolete client serialization/writer logic only after checking all callers.
* Ensure retention cleanup and history loading use the same schema.
* Preserve `deleteAIHistory`.
* Do not restore `ai_conversations` writes.

Validation:

* Send AI message.
* Verify exactly the intended server-side records are created.
* Reload chat history.
* Verify ordering.
* Delete AI history and verify it disappears.
* Verify retention cleanup remains compatible.

---

## 10. Scheduler Bulk Safety

Fix `autoExpireOpportunities`.

Requirements:

* Do not build one Firestore batch containing an unbounded number of writes.
* Process expired opportunities in safe chunks consistent with the existing bulk-delete/write patterns.
* Preserve scheduler behaviour and idempotency.
* Do not change the current scheduler count or consolidate jobs in this version.

Validation:

* Empty result.
* Small result.
* Multi-batch result.
* Verify all eligible opportunities become inactive.

---

## 11. Error Handling Consistency

Fix the non-idiomatic `HttpsError` detection in:

`functions/ai/deepAnalysis.js`

Use the same `HttpsError` handling pattern already used by the other Functions modules.

Do not alter unrelated error behaviour.

---

## 12. Regression Tests

Add focused tests for every fixed blocker.

Minimum coverage:

* release/signing configuration validation where practical
* App Check configuration/provider selection
* resume-review single-refresh behaviour
* recommendation fingerprint convergence
* placement timeout behaviour
* placement pending/reconciliation behaviour
* client/server eligibility parity
* opportunity authorization rules
* opportunity schema validation rules
* `profileCompleted` / `isVerified` write restrictions
* AI chat single-writer behaviour
* scheduler multi-batch expiry
* `HttpsError` handling

Do not remove existing tests.

---

## 13. Constraints

* No UI/UX redesign.
* No new product features.
* No architecture rewrite.
* No replacement of the recommendation engine.
* No mass dependency upgrade.
* Do not upgrade `firebase-functions`, `firebase-admin`, `pdf-parse`, Flutter packages, or Android tooling as part of this version unless a fix above absolutely requires it.
* Do not remove legacy quota mirrors or `ai_conversations` in this release.
* Do not remove the placement application mirror yet.
* Preserve backward compatibility with existing production data.
* Do not delete Firestore data as part of these fixes.
* Do not commit secrets, keystores, App Check debug tokens, or credentials.
* No Google Play publication, no Play Console account, and no Play-only tooling or step (see §0).
* No insecure App Check bypass to work around the non-Play attestation constraint (see §2).

---

## 14. Automated Validation

Run after implementation:

```bash
flutter pub get
flutter analyze
flutter test
cd functions
npm test
cd ..
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk   # direct-install target (see §0)
flutter build appbundle --release                              # optional — signing-configuration check only
firebase deploy --only functions --dry-run
```

Verify the release APK's signature before installing it:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Also validate Firestore/Storage rules using the project's existing rule-test setup.

All failures must be investigated; do not hide failures by weakening tests.

---

## 15. Manual Testing

Use the existing Google Pixel 9 / Android 16 test environment where applicable.

Test at minimum:

### Authentication

* logout
* login
* account switching
* logout → login again
* verify provider state resets correctly

### Resume Review

* submit resume review
* verify ATS data
* verify recommendation refresh happens once
* verify no duplicate recommendation regeneration
* verify dashboard recommendation state

### Placements

* open placement
* check eligibility badge
* apply
* simulate/observe delayed response where possible
* verify applied state
* update application status
* verify no duplicate application

### Opportunities

* alumni creates opportunity
* student attempts to create opportunity → denied
* teacher attempts to create opportunity → denied
* malformed opportunity write → denied
* valid alumni opportunity → notification/recommendation pipeline works

### AI Chat

* send several messages
* close/reopen chat
* verify history
* verify one consistent history schema
* delete AI history

### Release APK — direct install (the v9.2.4 delivery path)

* install the signed release APK directly on the phone
  (`adb install -r build/app/outputs/flutter-apk/app-release.apk`)
* launch it and complete one end-to-end pass per role (student / alumni / teacher)
* confirm it reaches the Firebase backend (login, dashboard, placements, AI chat)
* confirm the app is not blocked by App Check (enforcement is off by design — see §2)

### Security

* verify App Check debug mode still works (debug/profile providers, allow-listed token)
* verify the release build selects the Play Integrity provider (unit-tested; not enforced)
* verify the enforced layers still hold from the release APK: Auth identity, Firestore
  rules, Storage rules, callable auth/role checks, quota and rate limits
* confirm App Check enforcement is **off** in the Console for Firestore / Functions /
  Storage — the intended state for a direct-APK distribution (§2)

---

## 16. Documentation & Versioning

Update:

* `pubspec.yaml` version to `9.2.4+101`
* implementation/change report for v9.2.4
* security/rules documentation
* eligibility documentation
* relevant architecture documentation
* App Check status documentation — **re-scoped to the direct-APK, non-Play posture**
* release signing documentation — **re-scoped to a direct-distribution release key**
* deployment-scope documentation (this file §0: direct APK, no Play publication)

Also correct the v9.2.3 audit metadata where appropriate:

* report date should reflect the actual 2026 audit date
* distinguish the audit-only v9.2.3 baseline from this implementation release
* reconcile inconsistent test-count wording rather than silently changing historical results

Do not rewrite historical reports; clearly mark corrections/updates.

---

## 17. Final Report

Create:

`docs/v9_2_4_hardening_report.md`

Include:

* objective
* deployment scope (direct APK, **no Google Play publication**) and the App Check
  posture that follows from it
* implemented changes
* files changed
* security-rule changes
* App Check status — including why enforcement is deliberately off for a direct-APK build
* release signing status — direct-distribution release key, not a Play upload key
* recommendation trigger behaviour before/after
* placement timeout behaviour
* eligibility parity
* opportunity authorization/validation
* AI chat schema/writer change
* tests added
* automated validation results
* manual test results
* known limitations
* remaining v9.2.5/v9.2.6 work

Clearly separate:

* Fixed
* Verified
* Runtime-verified
* Still outstanding

Do not claim runtime success without actual runtime evidence.

---

# Definition of Done

v9.2.4 is complete only when:

* [ ] Release builds use a real release signing configuration — a **direct-distribution**
      release key, never the debug key (see §0, §1).
* [ ] The signed release APK installs and launches on the demo device/emulator.
* [ ] App Check posture for a **direct-APK / non-Play** distribution is documented and
      deliberate: provider selection preserved, enforcement **not** enabled, and the
      reason recorded. **No insecure App Check bypass** was introduced (§2).
* [ ] Resume Review no longer triggers duplicate recommendation regeneration.
* [ ] Recommendation fingerprints converge correctly.
* [ ] Placement apply/update timeout contracts are aligned.
* [ ] Placement timeout no longer falsely rolls back successful applications.
* [ ] Client/server eligibility semantics are identical.
* [ ] Only authorized alumni can create opportunities.
* [ ] Opportunity schema validation is enforced.
* [ ] `profileCompleted` / `isVerified` security gap is addressed.
* [ ] AI chat has one writer and one schema.
* [ ] `autoExpireOpportunities` safely handles large batches.
* [ ] `deepAnalysis.js` error handling is consistent.
* [ ] Regression tests cover every critical fix.
* [ ] Flutter tests pass.
* [ ] Functions tests pass.
* [ ] `flutter analyze` passes.
* [ ] Release APK builds successfully and is signed with the release key.
      (The App Bundle build is **optional** — see §0.)
* [ ] No secrets are committed.
* [ ] v9.2.4 documentation/report is complete.
* [ ] No unrelated UI, architecture, or dependency changes were introduced.

### Out of scope — not required for v9.2.4 to be complete

* **Google Play publication is explicitly out of scope.** No Play Store upload, no
  Play testing track, no Play Console developer account, no $25 registration fee, and
  no Play-only step or tooling is required by any item above.
* App Check **enforcement** is out of scope for this deployment (the non-Play
  attestation constraint; see §2). Enabling it is a Play-linked future task, not a
  v9.2.4 criterion.

**Next phase after successful completion: v9.2.5 — Performance, Cost & Scalability Optimization.**
