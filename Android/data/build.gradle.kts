plugins {
    kotlin("jvm")
    id("app.cash.sqldelight")
}

// 17, as the engine. What the Android Gradle Plugin wants and what CI has.
kotlin {
    jvmToolchain(17)
}

sqldelight {
    databases {
        create("LiquorDatabase") {
            // The schema is a paired edit with Postgres and GRDB; nothing
            // here may change it independently. See Schema.sq, and
            // scripts/check_schema_mirror.py, which compares all three.
            packageName.set("com.talastack.liquorlog.data")
        }
    }
}

dependencies {
    implementation(project(":engine"))
    implementation("app.cash.sqldelight:runtime:2.0.2")

    // JDBC SQLite, so the whole data layer runs in a JVM test on a free Linux
    // runner. The Android app supplies AndroidSqliteDriver instead; the
    // generated code does not care which.
    testImplementation("app.cash.sqldelight:sqlite-driver:2.0.2")
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
