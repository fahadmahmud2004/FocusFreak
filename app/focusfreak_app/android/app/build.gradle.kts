import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * The upload key, kept out of the repository.
 *
 * `android/key.properties` is gitignored and holds the store password, so it is
 * never committed and never printed. Create it with the `keytool` command in
 * `docs/RELEASE.md`; without it the release build falls back to debug signing,
 * which still runs on a phone but **Play will refuse it**.
 */
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "com.freakingwaves.focusfreak_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // Required by flutter_local_notifications, which uses java.time on
        // minSdk levels that predate it. Without this the build fails at
        // checkDebugAarMetadata rather than at compile, which is why the
        // error does not look like a dependency problem.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Locked once the first build reaches Play: an applicationId cannot be
        // changed afterwards without shipping a different app and losing every
        // install.
        applicationId = "com.freakingwaves.focusfreak_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing so a release build still runs on a
            // phone during development. Play rejects debug-signed uploads, so
            // an actual upload needs android/key.properties — docs/RELEASE.md.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }

            // Off deliberately. R8 strips the Kotlin plugin classes that are
            // only ever reached from Dart across a MethodChannel — nothing in
            // Java calls them, so shrinking reads them as dead and the app
            // loses Bluetooth and every phone-side factor at runtime, in
            // release only. Turning this on needs keep rules and a pass over
            // the §7.7 checklist on a release build first.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ContextCompat / ActivityCompat, used by BtClassicPlugin for the runtime
    // Bluetooth permissions. Declared rather than relied on transitively from
    // the Flutter embedding, so an embedding upgrade cannot silently remove it.
    implementation("androidx.core:core-ktx:1.13.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
