plugins {
    kotlin("jvm")
}

// 17 is what the Android Gradle Plugin wants and what the CI runner has.
kotlin {
    jvmToolchain(17)
}

dependencies {
    testImplementation(kotlin("test"))
    // Tests only. The engine's own code stays dependency-free; this is here
    // so the golden vectors in shared/vectors can be read as the JSON they
    // are, rather than transcribed into Kotlin where they could drift from
    // the file the Swift engine reads.
    testImplementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}

tasks.test {
    useJUnitPlatform()
    // The vectors live at the repository root, which is the parent of the
    // Gradle root. Passed in rather than walked up to, so the tests do not
    // depend on where they happen to be run from.
    systemProperty("repoRoot", rootProject.projectDir.parentFile.absolutePath)
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
