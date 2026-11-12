plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sales_mien_tay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Package ID used by existing Field Work debug installs; do not change.
        applicationId = "com.example.sales_mien_tay"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("fieldWorkRelease") {
            // These env vars exist only during the signed-release job.
            val storePath = System.getenv("FIELD_WORK_ANDROID_KEYSTORE_PATH")
            val storeSecret = System.getenv("FIELD_WORK_ANDROID_STORE_PASSWORD")
            val alias = System.getenv("FIELD_WORK_ANDROID_KEY_ALIAS")
            val keySecret = System.getenv("FIELD_WORK_ANDROID_KEY_PASSWORD")
            if (!storePath.isNullOrBlank() && !storeSecret.isNullOrBlank() &&
                !alias.isNullOrBlank() && !keySecret.isNullOrBlank()) {
                storeFile = file(storePath)
                storePassword = storeSecret
                keyAlias = alias
                keyPassword = keySecret
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Fail closed if signing secrets are not supplied.
            // NEVER fall back to debug keys for an upgrade release.
            signingConfig = signingConfigs.getByName("fieldWorkRelease")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core:1.16.0")
}

flutter {
    source = "../.."
}
