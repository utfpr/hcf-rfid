plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.beontag_utfpr_agro_mobile"
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
        applicationId = "br.edu.utfpr.hcf.rfid"
        minSdk = 27  // Chainway C72 minimum (Android 8.1+)
        targetSdk = 33  // Chainway DeviceAPI requires targetSdk 33 for UART access
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(files("libs/DeviceAPI_ver20230301_release.aar"))
    implementation(files("libs/Rfid.AsciiProtocol-3.1.0-release.aar"))
    // Urovo UHF SDK (DT50P and other Urovo devices with integrated UHF). The android.device.*
    // classes it uses are provided by the Urovo ROM at runtime.
    implementation(files("libs/URFIDLibrary-v2.6.0609.aar"))
}

flutter {
    source = "../.."
}
