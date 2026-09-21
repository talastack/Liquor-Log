plugins {
    id("com.android.application")
    kotlin("android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.talastack.liquorlog"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.talastack.liquorlog"
        // 26 is where the java.time the engine uses is available without
        // desugaring. The engine is shared with iOS and uses it throughout.
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.1"
    }

    buildFeatures { compose = true }

    // AGP looks in src/main/java by default. The rest of this repository
    // keeps Kotlin in src/main/kotlin and there is no reason for the app to
    // be the exception.
    sourceSets["main"].kotlin.srcDir("src/main/kotlin")

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":engine"))
    implementation(project(":data"))

    // The device's driver. :data does not know which driver it is given,
    // which is what lets the whole data layer be tested on a JVM.
    implementation("app.cash.sqldelight:android-driver:2.0.2")

    implementation(platform("androidx.compose:compose-bom:2024.09.03"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
}
