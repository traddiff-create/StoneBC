// Root build file for StoneBC Android (standalone Compose app — no KMP).

plugins {
    id("com.android.application") version "8.3.0" apply false
    kotlin("android") version "1.9.21" apply false
    kotlin("plugin.serialization") version "1.9.21" apply false
}
