# CampusConnect — App Check Status & Posture

**Applies to:** v9.2.4+101 and later
**Audit finding addressed:** C-2 — "App Check is configured but not enforced, and the debug token is still not allow-listed"
**Files:** `lib/main.dart`, `lib/services/app_check/app_check_config.dart`, `test/app_check_config_test.dart`, `functions/test/hardening_source_contracts.test.js`
**Deployment scope:** direct APK installation — **not** Google Play distribution (see `docs/Task.md` §0)

---

## 1. Summary

| Aspect | State at v9.2.4 |
|---|---|
| Provider selection (debug / profile) | **Correct** — `AndroidDebugProvider` / `AppleDebugProvider` |
| Provider selection (release) | **Correct** — `AndroidPlayIntegrityProvider` / `AppleDeviceCheckProvider` |
| Provider selection (web) | **Correct** — `ReCaptchaV3Provider`, only when a Site Key was supplied at build time |
| Initialisation order | **Correct** — `Firebase.initializeApp` → `activate` → `runApp` |
| Debug token committed to the repo | **No** — verified by the C-2 contract test |
| Debug token allow-listed in the Console | **Operator action** — see §6 (development convenience) |
| **Enforcement for Firestore / Functions / Storage** | **OFF — deliberate, documented, and correct for this deployment** (§4) |
| Insecure App Check bypass introduced | **No** — no release build is downgraded to a debug provider (§3, §5) |

The provider code was already correct before v9.2.4 (the v9.2.2 diagnosis
established this). v9.2.4 changes **no** provider behaviour: it extracts the
selection into a pure, testable function
(`lib/services/app_check/app_check_config.dart`) and pins the contract with
tests.

What v9.2.4 *does* change is the **scope framing**. The v9.2.3 audit treated
"enforcement not enabled" as a gap to close. For a project that is **not
distributed through Google Play**, closing it the Play way is impossible without
a Play Console developer account, and enabling it anyway would break the app.
This document records the deliberate non-Play posture instead.

---

## 2. Provider matrix (as implemented — unchanged by this deployment scope)

`resolveAppCheckConfig()` in `lib/services/app_check/app_check_config.dart`:

| Build mode | Android | Apple (iOS / macOS) | Web |
|---|---|---|---|
| `debug` (`kDebugMode`) | `AndroidDebugProvider` | `AppleDebugProvider` | `ReCaptchaV3Provider(siteKey)` if a Site Key was supplied, else none |
| `profile` (`kProfileMode`) | `AndroidDebugProvider` | `AppleDebugProvider` | as above |
| `release` | `AndroidPlayIntegrityProvider` | `AppleDeviceCheckProvider` | as above |

Rules the code enforces:

* **Release never falls back to a debug provider.** The release return
  constructs `AndroidPlayIntegrityProvider` / `AppleDeviceCheckProvider`
  unconditionally; it never builds a debug provider, so a release binary that
  cannot attest fails attestation rather than silently presenting a placeholder
  token. This is a deliberate anti-bypass property and is pinned by
  `test/app_check_config_test.dart` and by the C-2 group of
  `functions/test/hardening_source_contracts.test.js`.
* **Profile is treated as debug** so `flutter run --profile` (used for the
  v9.2.2 startup profiling) keeps working on an emulator. Hence the tier
  function `(isDebugMode || isProfileMode) ? debug : release`.
* **Desktop is skipped.** `isAppCheckSupportedPlatform` covers Android, iOS and
  Web only; Windows/Linux/macOS return `false` so startup does not throw on a
  platform with no provider.
* **Web is opt-in.** The reCAPTCHA v3 Site Key comes from a build-time
  `--dart-define=WEB_RECAPTCHA_V3_SITE_KEY=<key>`; an empty value means "no Web
  App Check" and the Web provider is `null`, so a mobile-only build still runs.
  No Site Key is committed.

Build commands:

```bash
# Android — the delivery path for this project (see docs/Task.md §0)
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

# iOS — not part of the v9.2.4 delivery path, kept for completeness
flutter build ios --release

# Web — supply the reCAPTCHA v3 Site Key at build time
flutter build web --dart-define=WEB_RECAPTCHA_V3_SITE_KEY=<your-site-key>
```

---

## 3. The non-Play constraint (why this section is not "enable enforcement")

Verified against Google's and Firebase's own documentation
(`firebase.google.com/docs/app-check/android/play-integrity-provider`, page last
updated 2026-10-01):

* Firebase's Play Integrity provider **does** support apps distributed outside
  Google Play: *"The Play Integrity provider supports Android apps that are
  published on Google Play, outside Google Play, or both."*
* **But** the setup instructions require the Play Integrity API to be enabled
  from the Google Play Console — *"In the Google Play Console, select your app,
  or add it if you haven't already done so… click Link Cloud project"* — and app
  registration in the Firebase Console needs the **SHA-256 fingerprint** of the
  app's signing certificate.
* And by default App Check requires the `PLAY_RECOGNIZED` app recognition label:
  *"By default, App Check requires the `PLAY_RECOGNIZED` app recognition label.
  Apps not published on Google Play are not eligible to receive this label."*
* Relaxing that requirement is an App Check **advanced setting**. The documented
  configuration for a non-Play app is:

  | Your app's distribution channel | `PLAY_RECOGNIZED` | `LICENSED` | Minimum acceptable device integrity |
  |---|---|---|---|
  | Exclusively on Google Play | Required | Required | Don't explicitly check device integrity level |
  | **Exclusively outside Google Play** | **Not required** | **Not required** | **Device integrity** |
  | On Google Play and outside Google Play | Required | Not required | Don't explicitly check device integrity level |

So a supported non-Play path does exist, and it costs no Play **publication**.
It does, however, still require a **Google Play Console developer account** to
create the app entry and link the Play Integrity API — and that account carries
the one-time **$25** registration fee that `docs/Task.md` §0 explicitly puts out
of scope for this final-year project.

**Consequence for v9.2.4:** a sideloaded, locally built release APK cannot obtain
a valid Play Integrity token in this deployment. Enabling enforcement would deny
**100 %** of the demo app's Firestore / Cloud Functions / Cloud Storage traffic
with `permission-denied` — including entirely legitimate traffic from the
student's own phone.

---

## 4. Decision: enforcement stays OFF (deliberate)

For v9.2.4 the App Check posture is:

> **Configured, correct, and deliberately not enforced for Firestore / Cloud
> Functions / Cloud Storage — because this build is distributed by direct
> install, not through Google Play.**

This is a scoped engineering decision, not an oversight, and it introduces **no
insecure bypass**:

* No release build is downgraded to the App Check debug provider (that would be a
  bypass, and the code and tests forbid it).
* No custom App Check provider / attestation backend was introduced (explicitly
  out of scope — no unnecessary commercial infrastructure).
* Nothing was added to the client that lets it skip attestation.
* The debug-token mechanism is used **only** for development convenience (§6),
  never as the release attestation story.

The protection that this project actually relies on is unaffected by the
decision, and is enforced today:

| Layer | Enforced in v9.2.4? | Notes |
|---|---|---|
| Firebase Authentication (identity) | **Yes** | Every request carries `request.auth`; callables require `request.auth.uid` |
| Firestore rules | **Yes** | Owner scoping, role checks, server-only writes; includes the new D-9 / D-10 / D-11 hardening |
| Storage rules | **Yes** | `resumes/{uid}` ownership, `application/pdf` MIME, 5 MB cap |
| Cloud Functions callable auth + server-side role re-checks | **Yes** | e.g. `updateApplicationStatus` re-reads the caller's role server-side |
| AI quota, rate-limit and spam windows | **Yes** | Server-side transactions; a client cannot grant itself quota |
| Server-owned collections (`allow write: if false`) | **Yes** | `recommendations_meta`, `engagement_summary`, quota docs, `analytics_events` |
| **App Check attestation** | **No — off by design** | The only layer disabled, for the reason in §3 |

Put plainly: App Check is an additional abuse barrier, not an authorisation
mechanism. Removing it does not remove any authorisation check — every rule,
role check and quota listed above still applies to a sideloaded APK.

---

## 5. What the runtime symptom looks like when the token is not allow-listed

`docs/logs.md` (captured on the `9.1.2+99` build) contains the signature of an
**unregistered debug token**:

```
W/LocalRequestInterceptor: Error getting App Check token; using placeholder token instead.
   Error: com.google.firebase.FirebaseException: Error returned from API.
   code: 403 body: App attestation failed.
W/FirebaseContextProvider: Error getting App Check token. Error: … Too many attempts.
```

This is **configuration, not a code defect**: the SDK is correctly attempting to
attest, the emulator's debug token has simply not been registered for the
project, so the backend rejects it and the SDK falls back to a placeholder.

With enforcement **off** (the v9.2.4 posture) the functional impact is exactly
nil — the backend never checks the token, and Firestore/Storage rules
authenticate via `request.auth`. Registering the token (§6) removes the logcat
noise and is what would make the debug path usable **if** enforcement were ever
turned on for a Play-linked build.

**Critical:** do **not** enable enforcement before either (a) the Play-linked
configuration in §7 is complete, or (b) everything you intend to demo is a
debug/profile build with an allow-listed token. Enforcement with a client that
cannot attest denies **every** backend request with `permission-denied`.

---

## 6. Allow-list the debug token (Console — operator action, development only)

This step is a **development convenience** (it silences the `403 App attestation
failed` loop in logcat) and is *not* the release attestation story. It does not
change the enforcement decision in §4.

1. Run the app on the Android emulator or device in **debug** mode (`flutter run`).
2. In Logcat, find the App Check debug token line:
   ```
   D/FirebaseAppCheck: Enter this debug secret into the allow list
   in the Firebase Console for your project: <DEBUG_TOKEN_UUID>
   ```
   (The SDK prints it; the app never writes or stores it.)
3. Open **Firebase Console → App Check → Apps → Android app → ⋮ → Manage debug
   tokens**.
4. **Add debug token**, give it a recognisable name (e.g. `Pixel-9-emulator-API36`),
   paste the token, save.
5. Re-run and confirm Logcat no longer shows `403 App attestation failed` /
   `Too many attempts`.
6. Repeat for an iOS simulator token if iOS debug testing is required (DeviceCheck
   on a simulator uses the same debug-token mechanism).

> **Do not commit the token.** It is secret material. The C-2 group of
> `functions/test/hardening_source_contracts.test.js` scans
> `app_check_config.dart`, `firebase_options.dart` and
> `AndroidManifest.xml` for a UUID and fails if one is found.

---

## 7. If enforcement is ever wanted (Play-linked path — OUT OF SCOPE for v9.2.4)

This is the *only* supported way to make Play Integrity attest for this app, and
it is not required for the final-year project. It is recorded so the reasoning in
§3/§4 can be re-checked rather than re-derived.

1. Create a **Google Play Console developer account** and add the app (it does
   **not** have to be published — an app entry is enough). This is the one-time
   **$25** registration that `docs/Task.md` §0 excludes.
2. In the Play Console: **Release → App integrity → Play Integrity API → Link
   Cloud project** and select the `campusconnect` Firebase/GCP project.
3. Register the Android app under **Firebase Console → App Check → Apps**, using
   the **SHA-256 fingerprint of the release signing certificate**:
   ```bash
   keytool -list -v -keystore C:/keys/campusconnect-upload.jks -alias upload   # copy the SHA256 line
   ```
4. For each registered Android app, open the App Check **advanced settings** and
   set the row for **"Exclusively outside Google Play"**: `PLAY_RECOGNIZED` **not
   required**, `LICENSED` **not required**, minimum device integrity =
   **Device integrity**.
5. Optionally set a token TTL (default **1 hour**; allowed 30 minutes – 7 days).
6. Rebuild the release APK, install it directly, and while enforcement is still
   **off** confirm in **App Check → Metrics** that requests appear as **verified**
   (not `unverified`).
7. Only then enable enforcement, one service at a time, watching the metrics
   (§8).

**Until step 7 is reached, keep enforcement off.** A half-applied Play link does
not make an existing sideloaded APK attest.

---

## 8. Enforcement runbook (reference — not applied in v9.2.4)

Do this **only** after §7 succeeds. Enable per service, one at a time, watching
metrics:

**Firebase Console → App Check → APIs:**

| Service | Setting |
|---|---|
| Cloud Firestore | Enforce |
| Cloud Functions | Enforce |
| Cloud Storage | Enforce |

Recommended order and cadence:

1. Enforce **Cloud Functions** first (the callables) and watch **App Check →
   Metrics** for `unverified` / `invalid` request volume for 24 h.
2. Then enforce **Cloud Firestore** and watch for `permission-denied` in Logcat.
3. Then enforce **Cloud Storage** (resume uploads / snapshot reads).
4. If legitimate traffic is denied, **un-enforce** that service, register the
   missing client, and retry — do **not** weaken Firestore/Storage rules to
   compensate for a misconfigured App Check.

> **Android release note.** Play Integrity attestation requires the app to be
> recognised as installed by Play, or the advanced settings in §7 step 4 to be
> applied. A locally built release APK will not attest until then — which is the
> whole subject of §3/§4.

### Verification checklist (only relevant once enforcement is on)

- [ ] **Firestore** — authenticated app traffic reads/writes normally; an
      App-Check-less client is denied.
- [ ] **Cloud Functions** — every callable (`askAI`, `reviewResume`,
      `generateResumeAnalysis`, `generateCareerCoachAnalysis`, `deleteAIHistory`,
      `refreshRecommendations`, `logPlacementView`, `logPlacementApplication`,
      `updateApplicationStatus`) succeeds from the app and fails without
      attestation.
- [ ] **Cloud Storage** — resume upload and snapshot read succeed from the app.
- [ ] Debug mode still works with the allow-listed token (§6).
- [ ] Release mode attests via Play Integrity / DeviceCheck (§7).
- [ ] App Check metrics show no unexpected `invalid` traffic after 24 h.
- [ ] No App Check debug token appears in `git status` / the repository.

---

## 9. Status summary

| Item | Status |
|---|---|
| Provider selection extracted + unit-testable | **Fixed** (`lib/services/app_check/app_check_config.dart`) |
| Debug/profile → debug providers | **Verified** (`test/app_check_config_test.dart`, C-2 contract test) |
| Release → Play Integrity / DeviceCheck | **Verified** (tests; not runtime-attested — see §3) |
| Release never falls back to a debug provider | **Verified** (`test/app_check_config_test.dart`, C-2 contract test) |
| Web → reCAPTCHA v3, opt-in via `--dart-define` | **Verified** (tests) |
| No debug token committed | **Verified** (`hardening_source_contracts.test.js`, C-2 group) |
| Non-Play attestation constraint analysed and documented | **Done** (this document §3) |
| Enforcement decision recorded for the direct-APK deployment | **Done** — enforcement **OFF by design** (§4) |
| No insecure bypass / no custom-provider infrastructure introduced | **Verified** (code unchanged; C-2 contract test enforces the release-never-debug property) |
| Debug token allow-listed in the Console | **Operator action** — development only, §6 |
| Enforcement enabled for Firestore / Functions / Storage | **NOT APPLICABLE** for this deployment. Would require the Play Console link in §7, which is out of scope |

---

*End of `docs/app_check_status.md` — v9.2.4+101. Supersedes the Play-centric
enforcement runbook that was drafted earlier in v9.2.4; that runbook is retained
in §7/§8 as the future Play-linked path.*
