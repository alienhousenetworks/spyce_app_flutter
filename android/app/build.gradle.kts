plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.spycenow.spyce"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.spycenow.spyce"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Lighter sideload APK: modern phones only (drops 32-bit + x86 emulator libs).
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            // Compress .so files inside the APK (smaller sideload). They unpack on install.
            useLegacyPackaging = true
            // Force-drop non-arm64 natives from plugins (WebRTC, etc.)
            excludes += listOf(
                "**/armeabi/**",
                "**/armeabi-v7a/**",
                "**/x86/**",
                "**/x86_64/**",
            )
        }
        resources {
            // Amplify workers ship source maps; they are unused at runtime.
            excludes += listOf(
                "**/*.map",
                "**/*.js.map",
                "**/*.wasm.map",
            )
        }
    }

    buildTypes {
        release {
            // Smaller install: R8 minify + resource shrink (lite APK).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Debug keys for sideload installs until a release keystore is configured.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

// Drop Amplify worker source maps after Flutter copies package assets.
tasks.configureEach {
    if (name == "compileFlutterBuildRelease") {
        doLast {
            val candidates =
                listOf(
                    layout.buildDirectory.get().asFile.resolve(
                        "intermediates/flutter/release/flutter_assets",
                    ),
                    file("../../build/app/intermediates/flutter/release/flutter_assets"),
                )
            candidates.filter { it.exists() }.forEach { dir ->
                dir.walkTopDown()
                    .filter { it.isFile && it.name.endsWith(".map") }
                    .forEach { file ->
                        logger.lifecycle("Stripping source map ${file.relativeTo(dir)}")
                        file.delete()
                    }
            }
        }
    }
}

