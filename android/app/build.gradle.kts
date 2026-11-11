import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 로그인 SDK 설정값. 커밋하지 않는 파일에서 읽는다. 없으면 빈 값으로 빌드되고 그 로그인만 실패한다.
fun loadProperties(path: String) = Properties().apply {
    rootProject.file(path).takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
// 네이버 Client ID·Secret·이름. Dart(.env)로 가지 않게 여기에만 둔다.
val localProperties = loadProperties("local.properties")
// 카카오 네이티브 앱 키. 앱 코드도 같은 값을 --dart-define-from-file=.env로 읽는다.
val dartEnv = loadProperties("../.env")

android {
    namespace = "com.mandagolab.mapmarker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mandagolab.mapmarker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["kakaoScheme"] =
            "kakao" + dartEnv.getProperty("KAKAO_NATIVE_APP_KEY", "")
        manifestPlaceholders["naverClientId"] =
            localProperties.getProperty("naver.client_id", "")
        manifestPlaceholders["naverClientName"] =
            localProperties.getProperty("naver.client_name", "")
        resValue(
            "string",
            "naver_client_secret",
            localProperties.getProperty("naver.client_secret", ""),
        )
    }

    buildFeatures {
        resValues = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
