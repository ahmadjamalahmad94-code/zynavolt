pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // v101 — Google Services plugin for Firebase. `apply false` here so
    // each module that actually needs it (only `:app` for now) opts in
    // via its own build.gradle.kts. 4.4.4 is what the Firebase Console
    // setup wizard recommends as of the project creation date.
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
