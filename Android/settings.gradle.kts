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
