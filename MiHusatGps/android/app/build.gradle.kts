import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Cargar propiedades del keystore desde key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.husat.gps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.husat.gps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Asumiendo que el .jks está en la misma carpeta que este build.gradle.kts (android/app/)
            storeFile = file("husat365_key.jks")
            storePassword = "Husat\$Gps_2026#Secure!"
            keyAlias = "husat_alias"
            keyPassword = "Husat\$Gps_2026#Secure!"
        }
    }

    buildTypes {
        getByName("release") {
            // Usar la configuración de firma desde key.properties
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    // Configurar nombre del APK de salida
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val outputFileName = when (variant.buildType.name) {
                "release" -> "Husat365.apk"
                "debug" -> "Husat365-debug.apk"
                else -> "Husat365-${variant.buildType.name}.apk"
            }
            output.outputFileName = outputFileName
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
