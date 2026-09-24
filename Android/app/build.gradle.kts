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

    // The catalogue, the flavour wheel and the tequila registry come from
    // shared/data/ at build time rather than being checked in again here.
    //
    // iOS has to keep its own copy under IOS/App/Resources/Data because Xcode
    // bundles only what lives under the target directory, and
    // scripts/check_bundled_data.py exists to catch that copy going stale.
    // Gradle can read outside the module, so Android takes the canonical file
    // directly: there is no second copy, so there is nothing to drift.
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("sharedData"))

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

    // SF Symbols have no Android equivalent, and the core icon set is about
    // forty glyphs. This is the set the iOS screens actually name -- a
    // wineglass, a viewfinder, a barrel -- so the two platforms can show the
    // same thing rather than the nearest of four.
    implementation("androidx.compose.material:material-icons-extended")

    implementation("androidx.activity:activity-compose:1.9.2")

    // A phone held upright writes a sideways JPEG and an orientation tag.
    // Reading that tag is the difference between a bottle photo and a bottle
    // photo lying down; the framework ExifInterface reads paths only, and a
    // photo picked from the library arrives as a content URI.
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")

    // One back stack, so a bottle opened from the collection, from the search
    // index or from a widget lands on the same screen with the same way back.
    implementation("androidx.navigation:navigation-compose:2.8.2")
}

/**
 * Stages shared/data/ into a generated assets directory.
 *
 * Fails the build when the directory is missing rather than shipping an app
 * with no catalogue: a shelf check that answers "never had it" because the
 * catalogue did not load is the one wrong answer this app must not give.
 */
val stageSharedData by tasks.registering(Copy::class) {
    val canonical = rootProject.layout.projectDirectory.dir("../shared/data")
    from(canonical) {
        include("spirits.v1.json", "flavor-wheel.v1.json", "tequila-nom.v1.json")
    }
    into(layout.buildDirectory.dir("sharedData"))
    doFirst {
        require(canonical.asFile.isDirectory) {
            "shared/data is missing at " + canonical.asFile.absolutePath
        }
    }
}

tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Assets") }
    .configureEach { dependsOn(stageSharedData) }
tasks.matching { it.name.startsWith("generate") && it.name.endsWith("Assets") }
    .configureEach { dependsOn(stageSharedData) }
