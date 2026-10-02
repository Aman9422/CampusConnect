# CampusConnect — Release Signing

**Applies to:** v9.2.4+101 and later
**Audit finding closed:** C-1 — "The release APK/AAB is signed with the debug keystore"
**Files:** `android/app/build.gradle.kts`, `android/app/key.properties.template`, `android/.gitignore`
**Deployment scope:** direct APK installation, **not** Google Play distribution
(see `docs/Task.md` §0). The key described here is a **direct-distribution release
key** — it signs the APK installed on the demo device. If Play distribution ever
enters scope, the same key would serve as the Play upload key.

---

## 1. What was wrong (v9.2.3 audit, finding C-1)

Before v9.2.4, `android/app/build.gradle.kts` declared:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Consequences:

* `flutter build apk --release` and `flutter build appbundle --release` produced
  artifacts signed with the **publicly known Android debug key**
  (`~/.android/debug.keystore`, alias `androiddebugkey`, password `android`).
* Any build distributed from this tree had no provable provenance — because the
  debug key is public, **anyone can sign an APK that Android treats as the same
  app**, so a tampered build is indistinguishable from a genuine one. This is the
  consequence that matters for a directly installed APK.
* *(Play-specific, recorded for accuracy: the Play Console also rejects a bundle
  signed with the debug key. Play publication is out of scope for this project —
  see `docs/Task.md` §0 — but the provenance problem above applies regardless.)*

`docs/v9_2_2_optimization_report.md` §11 records a release APK being built in
v9.2.2; it built successfully, but it was debug-signed and therefore not
shippable.

---

## 2. What v9.2.4 does

The `debug` build type keeps the debug signing config. The `release` build type
resolves a **`release` signing config built from `android/app/key.properties`**,
and there is **no fallback to the debug key**:

* If `android/app/key.properties` exists **and** all four keys are non-blank, a
  `release` signing config is created and used.
* If it does not exist (or is partial) **and** a release build was requested,
  the build **aborts** with a clear `GradleException` naming the missing file
  and the expected keys.
* Debug / profile / `flutter test` / `flutter analyze` runs are untouched: the
  abort is gated on `releaseSigningRequested`, which is derived from the
  requested Gradle task names, and the signing config block is only evaluated
  when the credentials are complete.

This shape was chosen so a clean checkout **without** secrets can still run
`flutter build apk --debug`, `flutter test` and `flutter analyze`, while a
release build can never silently emit a debug-signed artifact again.

---

## 3. Create the release keystore (one time)

Run from the repository root (or any directory; only `storeFile` matters
afterwards):

```bash
keytool -genkeypair -v \
  -keystore C:/keys/campusconnect-upload.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

`keytool` will ask for:

| Prompt | Value to supply |
|---|---|
| Enter keystore password | a strong store password (**store this safely**) |
| Re-enter new password | the same |
| What is your first and last name? | your name or organisation |
| What is the name of your organisational unit? | team / department |
| What is the name of your organisation? | `CampusConnect` |
| What is the name of your City or Locality? | your city |
| What is the name of your State or Province? | your state |
| What is the two-letter country code for this unit? | e.g. `IN` |
| Is CN=… correct? | `yes` |
| Enter key password for \<upload\> | press **Enter** to reuse the store password, or set a distinct key password |

> **Java 9+ note.** `-storetype JKS` is explicit above to match the historical
> default. On modern JDKs `PKCS12` is the default and also works — either is
> accepted by `keytool` and by the Android Gradle plugin; keep the file's
> contents out of Git either way.

### Where to keep it

Keep the `.jks` **outside the repository** (e.g. `C:/keys/`) and back it up in
a password manager or a private vault. **Leaking it** means someone else can
sign an APK that your device will accept as an update.

**Losing it** is not fatal for an academic deployment, but it is not silent
either: the APK is installed directly, so there is no "upload key reset" escape
hatch. If the key is lost you must

1. generate a new keystore,
2. **uninstall** the app from the device — Android refuses to update an installed
   app with an APK signed by a different key, and
3. reinstall the newly signed APK.

Record which key signed the submitted build in your project report.

---

## 4. Create `key.properties`

Copy the template and fill it in:

```bash
copy android\app\key.properties.template android\app\key.properties
```

Then edit `android/app/key.properties`:

```properties
storeFile=C:/keys/campusconnect-upload.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

* `storeFile` may be absolute (`C:/keys/…`) or **relative to `android/app/`**
  (`storeFile=upload-keystore.jks` for a keystore stored next to the app module).
* Use **forward slashes** in the path on Windows — a backslash is an escape
  character in a `.properties` file.

---

## 5. Secrets are Git-ignored (verify before every commit)

`android/.gitignore` already excludes the credentials and the keystore:

```gitignore
key.properties
**/*.keystore
**/*.jks
```

Confirm nothing sensitive is staged:

```bash
git status --short
git check-ignore -v android/app/key.properties
```

`android/app/key.properties.template` **is** committed on purpose — it documents
the expected format and contains only placeholder values.

`functions/test/hardening_source_contracts.test.js` (C-1 group) fails the
Functions test suite if a real `android/app/key.properties` or a keystore
(`upload-keystore.jks`, `release.keystore`, `key.jks`) ever appears in the
working tree, so a committed secret is caught by `npm --prefix functions test`
as well as by review.

---

## 6. Build, verify and install (direct distribution)

The **delivery artifact is the APK** — an `.aab` cannot be installed directly on a
device, so it is only ever an extra check of the same signing configuration:

```bash
flutter build apk --release

# optional — signing-configuration check only, not a delivery artifact
flutter build appbundle --release
```

Expected outputs:

* `build/app/outputs/flutter-apk/app-release.apk`
* `build/app/outputs/bundle/release/app-release.aab` (optional build)

### Confirm the artifact is signed with the release key, not the debug key

Use **`apksigner`**, which ships with the Android SDK build-tools. Do **not** use
`keytool -printcert -jarfile` for this: current Android Gradle Plugin versions
sign with the v2/v3 APK Signature Scheme and emit **no** v1 JAR signature, so
`keytool` fails with `Not a signed jar file` even on a correctly signed release
APK (verified during v9.2.4).

```bash
"$LOCALAPPDATA/Android/Sdk/build-tools/<version>/apksigner" \
  verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Compare the printed digest with your keystore's certificate:

```bash
keytool -list -v -keystore C:/keys/campusconnect-upload.jks -alias upload
```

The `Signer #1 certificate SHA-256 digest` from `apksigner` must equal the
`SHA256:` line from `keytool`.

The debug key always reports `CN=Android Debug, O=Android, C=US` with the
well-known debug digest. **If you see that DN, the build was debug-signed** and
the signing configuration did not apply — treat it as a failure.

### Install it directly on the device (the delivery path)

```bash
adb devices                                                   # confirm the target is attached
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or let Flutter drive the install:

```bash
flutter install --release
```

If Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, the device already has
the app installed under a different signing key (typically an earlier debug
build). Uninstall it first:

```bash
adb uninstall io.campusconnect.campusconnect
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### App Check note

Installing the APK this way does **not** by itself let it attest through Play
Integrity, because this project is not Play-distributed. That is expected and is
exactly why App Check enforcement stays off for this deployment — see
`docs/app_check_status.md`. It does not block the install or the running app.

### Negative test (proves the guard works)

Temporarily rename `android/app/key.properties`, then run
`flutter build apk --release`. The build must **fail** with the
`GradleException` from `build.gradle.kts` — it must never produce an APK. Rename
the file back afterwards.

---

## 7. Rotation

If the release key is compromised or lost:

1. Generate a new keystore (§3) and a new `key.properties` (§4).
2. **Uninstall** the app from the demo device (Android will not update an app
   signed by a different key).
3. Rebuild, re-verify and reinstall the APK (§6).
4. Destroy the old keystore and its passwords.

*(Play-specific, out of scope here: if the app were ever on Play with Play App
Signing enabled, you would instead request an upload key reset in the Play
Console — App integrity → App signing → Request upload key reset — and upload
the new certificate.)*

Never commit the new credentials — the same `.gitignore` rules and the same
contract test (`hardening_source_contracts.test.js`) apply.

---

## 8. Housekeeping

* `android/local.properties` (flutter SDK path) is already ignored.
* Do not add `key.properties` or a keystore to `git` even temporarily
  (`git add -f` bypasses `.gitignore` — never use it for these files).
* If a secret is ever committed, treat the key as compromised: rotate it (§7)
  and scrub the history; do not merely delete the file in a later commit.

---

## 9. Status

| Item | Status |
|---|---|
| `release` build type wired to a real key | **Fixed** (`android/app/build.gradle.kts`) |
| Credentials loaded from `key.properties` | **Fixed** |
| Debug config kept for debug builds only | **Fixed** |
| `key.properties` + keystores Git-ignored | **Verified** (`android/.gitignore`) |
| Template committed | **Fixed** (`android/app/key.properties.template`) |
| Source-contract regression test | **Fixed** (`functions/test/hardening_source_contracts.test.js`, C-1 group) |
| `flutter build apk --release` with a keystore present | **Runtime-verified** — built during v9.2.4 (`build/app/outputs/flutter-apk/app-release.apk`, 56.7 MB) |
| `flutter build appbundle --release` (optional) | **Runtime-verified** — `build/app/outputs/bundle/release/app-release.aab`, 46.8 MB |
| The APK/AAB is **not** debug-signed | **Runtime-verified** — `apksigner verify --print-certs` reported `CN=CampusConnect Validation, OU=Local, O=CampusConnect, L=NA, ST=NA, C=IN`, SHA-256 `03:B7:0D:79:…:A8:DA`, whereas the debug key reports `C=US, O=Android, CN=Android Debug`, SHA-256 `13:65:4F:0D:…:41:A3`. Different DN **and** different digest ⇒ release-signed |
| Release build with no `key.properties` aborts instead of falling back | **Verified in source** — the `GradleException` guard, pinned by the C-1 contract test (the abort path was not re-executed against Gradle in this version) |
| Build + signature check with the **operator's own keystore** | **Operator action** — repeat §6 with your real keystore and record its digest |
| Direct install on the demo device | **Operator action** — `adb install -r …` (§6) |

> **Note on the runtime evidence above.** The v9.2.4 verification used a
> **throwaway validation keystore**, which was removed immediately afterwards —
> the C-1 contract test fails the suite if any keystore or real `key.properties`
> is present in the working tree. Those digests therefore prove the *mechanism*
> (release signing applies and it is not the debug key), **not** the identity of
> your final key. Reproduce §6 once with your own keystore and record that
> digest in your project report.

---

*End of `docs/release_signing.md` — v9.2.4+101.*
