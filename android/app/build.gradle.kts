plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from the environment (CI secrets, see docs/releasing.md).
// Without it, release builds are signed with the debug key so they still install
// for testing.
val releaseKeystore: String? = System.getenv("SPEAKAGAIN_KEYSTORE_FILE")?.takeIf { it.isNotBlank() }

android {
    namespace = "io.github.lobojoel2003.speakagain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.lobojoel2003.speakagain"
        // Android 7.0+: covers older and low-cost devices many stroke survivors use.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml: version 1.2.3+10203 -> versionName 1.2.3, versionCode 10203.
        // Release builds pass -Pforce-version-code-ignoring-abi=true so every APK of a
        // release (per processor and universal) shares one versionCode.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = System.getenv("SPEAKAGAIN_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SPEAKAGAIN_KEY_ALIAS")
                keyPassword = System.getenv("SPEAKAGAIN_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystore != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs {
            // Store native libraries uncompressed and page-aligned (Android 15+ 16 KB pages).
            useLegacyPackaging = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
