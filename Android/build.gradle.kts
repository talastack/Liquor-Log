plugins {
    kotlin("jvm") version "2.0.21" apply false
    kotlin("android") version "2.0.21" apply false
    // Kotlin 2.0 moved the Compose compiler out of the AGP and into its own
    // plugin, versioned with Kotlin rather than with Compose.
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.android.application") version "8.7.3" apply false
    // Generates the database API from the .sq schema. Applied by :data only;
    // :engine stays dependency-free.
    id("app.cash.sqldelight") version "2.0.2" apply false
}
