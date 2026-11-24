import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin harus setelah plugin Android & Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: dibaca dari android/key.properties (TIDAK ikut repo). Jika tidak ada,
// release TIDAK ditandatangani dengan key palsu — build release akan gagal dengan pesan jelas.
val keystoreProps = Properties()
val keystoreFile = rootProject.file("key.properties")
val hasReleaseSigning = keystoreFile.exists().also { exists ->
    if (exists) keystoreFile.inputStream().use { keystoreProps.load(it) }
}

android {
    namespace = "com.aismartpanel.app"
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
        applicationId = "com.aismartpanel.app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    if (!hasReleaseSigning && allTasks.any { it.name == "assembleRelease" }) {
        throw GradleException(
            "Release signing belum dikonfigurasi: buat android/key.properties + keystore Anda sendiri " +
                "(lihat README §5). Gunakan 'flutter build apk --debug' untuk APK uji."
        )
    }
}
