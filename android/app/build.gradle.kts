import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ===============================================================
// v9.2.4 (C-1) - RELEASE SIGNING
// ===============================================================
//
// Before v9.2.4 the `release` build type was wired to
// `signingConfigs.getByName("debug")`, so `flutter build apk --release` and
// `flutter build appbundle --release` produced artifacts signed with the
// publicly known Android debug key. The Play Console rejects such a bundle,
// and any artifact distributed from this tree had no provable provenance.
//
// Release builds are now signed with a real upload key whose credentials live
// in `android/app/key.properties` - a file that is git-ignored (see
// `android/.gitignore`) and must NEVER be committed. See
// `docs/release_signing.md` for the keystore creation / rotation procedure and
// `android/app/key.properties.template` for the expected format.
//
// The properties file is read (but not required) at configuration time so a
// clean checkout without secrets can still run `flutter build apk --debug`,
// `flutter analyze` and `flutter test`. A RELEASE build without it fails
// loudly instead of silently falling back to the debug key.
val signingPropertyKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// A complete configuration = the file exists AND every required key is set.
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    signingPropertyKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

// Driven by the requested task names (`assembleRelease` / `bundleRelease`), not
// by the registered variants, so debug/test/profile invocations are untouched
// even when no keystore is present on the machine.
val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "io.campusconnect.campusconnect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.campusconnect.campusconnect"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only created when a complete credential set is present, so a partial
        // or absent key.properties cannot produce a half-configured config.
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // The debug keystore is kept for the debug build type ONLY.
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            // Never the debug key. When the release signing config is absent
            // this stays unset and the guard below aborts the build.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// v9.2.4 (C-1): fail a release build loudly rather than emit an unsigned or
// debug-signed artifact. This is a plain top-level check evaluated at
// configuration time and guarded by `releaseSigningRequested`, so it can never
// affect `flutter build apk --debug`, `flutter test` or `flutter analyze`.
//
// It tests `hasReleaseKeystore` rather than reading `signingConfigs` again:
// the release signing config is created if and only if that flag is true, so
// the two can never disagree, and this avoids depending on the generated
// accessor scope of the `android` extension.
if (releaseSigningRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is not configured. Expected android/app/key.properties " +
            "with the keys ${signingPropertyKeys.joinToString(", ")}. " +
            "Generate a keystore and the properties file as described in " +
            "docs/release_signing.md. Refusing to sign a release artifact with " +
            "the debug keystore (the v9.2.4 C-1 defect)."
    )
}

flutter {
    source = "../.."
}
