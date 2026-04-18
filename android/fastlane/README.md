fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android bump_version_code

```sh
[bundle exec] fastlane android bump_version_code
```

Auto-increment versionCode in build.gradle.kts

### android set_version_name

```sh
[bundle exec] fastlane android set_version_name
```

Set versionName in build.gradle.kts

### android test

```sh
[bundle exec] fastlane android test
```

Run unit tests

### android build_debug

```sh
[bundle exec] fastlane android build_debug
```

Build debug APK

### android build_release

```sh
[bundle exec] fastlane android build_release
```

Build release AAB

### android deploy_internal

```sh
[bundle exec] fastlane android deploy_internal
```

Build and deploy to Google Play internal testing track

### android deploy_production

```sh
[bundle exec] fastlane android deploy_production
```

Build and deploy to Google Play production track

### android promote_to_production

```sh
[bundle exec] fastlane android promote_to_production
```

Promote internal testing release to production (no rebuild)

### android upload_metadata

```sh
[bundle exec] fastlane android upload_metadata
```

Upload store listing metadata and screenshots (no build)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
