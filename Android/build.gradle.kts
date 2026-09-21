plugins {
    kotlin("jvm") version "2.0.21" apply false
    // Generates the database API from the .sq schema. Applied by :data only;
    // :engine stays dependency-free.
    id("app.cash.sqldelight") version "2.0.2" apply false
}
