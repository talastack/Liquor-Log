pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

// The Android side of Liquor-Log.
//
// `engine` is plain Kotlin with no Android dependency, mirroring
// LiquorEngine's zero-dependency rule on the Swift side: the domain logic
// is the part worth testing hardest, and keeping it off the Android
// toolchain means its tests run in seconds on a free Linux runner rather
// than in an emulator.
// Declared here rather than per-module: with PREFER_SETTINGS a module that
// forgets its own repositories cannot silently resolve from somewhere else.
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        mavenCentral()
        google()
    }
}

rootProject.name = "liquorlog"

include(":engine")

// The local database, sync and auth. A plain JVM module, not an Android
// library: SQLDelight's generated code is platform-agnostic and the driver is
// injected, so the whole thing is testable on the free Linux runner and only
// the driver differs on a device.
include(":data")

// The Android app itself: the only module that needs the Android SDK, and the
// only one an emulator ever sees. Everything it shows is computed in :engine
// and stored by :data, both of which are tested without it.
include(":app")
