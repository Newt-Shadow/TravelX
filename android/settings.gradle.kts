// settings.gradle.kts

pluginManagement {
    // Get Flutter SDK path from local.properties
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    // Include Flutter Gradle build
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Flutter engine artifacts
        maven {
            url = uri("$flutterSdkPath/bin/cache/artifacts/engine/android")
        }
    }
}

dependencyResolutionManagement {
    // Force using repositories defined here, ignore project repositories
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)

    repositories {
        google()
        mavenCentral()
        // Flutter engine artifacts
        val flutterSdkPath = run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val path = properties.getProperty("flutter.sdk")
            require(path != null) { "flutter.sdk not set in local.properties" }
            path
        }
        maven {
            url = uri("$flutterSdkPath/bin/cache/artifacts/engine/android")
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}

include(":app")
