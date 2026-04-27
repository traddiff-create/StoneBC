# StoneBC Android — Build, Fastlane, CI Setup

## Local build

```bash
# Debug build
./gradlew assembleDebug

# Signed release (AAB)
./gradlew bundleRelease
```

The signing config reads from `keystore.properties` (gitignored) at the `android/` root. Regenerate from env vars if needed:

```properties
storeFile=keystore/stonebc-upload.jks
storePassword=...
keyAlias=stonebc-upload
keyPassword=...
```

The keystore itself lives at `app/keystore/stonebc-upload.jks`. **Back this up** — without it you cannot ship updates.

## Fastlane lanes

All run from `android/` directory:

```bash
fastlane test           # ./gradlew test
fastlane build_debug    # assembleDebug
fastlane build_release  # signed bundleRelease (uses env-var signing injection)
fastlane internal       # upload AAB to Play internal track
fastlane beta           # promote internal → closed beta
fastlane production     # promote beta → production, 10% rollout
```

All upload lanes require `fastlane/service-account.json` (a Play Developer API service-account key).

## Google Play Console setup (one-time, manual)

1. **Create app in Play Console** — go to [play.google.com/console](https://play.google.com/console), create app with package `com.stonebicyclecoalition.stonebc`
2. **Complete store listing** — name, description, screenshots, privacy policy URL
3. **Upload first AAB manually via Play Console web UI** — needed to register the package. After that, Fastlane can upload subsequent builds
4. **Opt into Play App Signing** — when uploading first AAB, Google offers to manage the signing key. Accept. Your upload keystore stays with you; Google holds the final signing key

### Service account (for Fastlane uploads)

1. In Play Console → Setup → API access, link a Google Cloud project
2. Create a service account with role **Release Manager**
3. Download JSON key → save as `android/fastlane/service-account.json` (gitignored)
4. For GitHub Actions, base64-encode the JSON and add as `PLAY_SERVICE_ACCOUNT_JSON` secret

## GitHub Actions secrets

Go to **Settings → Secrets and variables → Actions** on the repo. Add:

| Secret | What it is | How to generate |
|---|---|---|
| `STONEBC_KEYSTORE_BASE64` | Base64 of `app/keystore/stonebc-upload.jks` | `base64 -i app/keystore/stonebc-upload.jks \| pbcopy` |
| `STONEBC_STORE_PASSWORD` | Keystore password | From `keystore.properties` |
| `STONEBC_KEY_ALIAS` | Key alias | `stonebc-upload` |
| `STONEBC_KEY_PASSWORD` | Key password | From `keystore.properties` |
| `PLAY_SERVICE_ACCOUNT_JSON` | Base64 of Play service-account key | `base64 -i fastlane/service-account.json \| pbcopy` |

These secrets are required by the release workflow (once the Play listing exists). The `android-ci.yml` and `android-maestro.yml` workflows run without any secrets.

## Workflows

| File | Trigger | What |
|---|---|---|
| `.github/workflows/android-ci.yml` | Push to main (android/ path) | Lint, unit tests, debug APK |
| `.github/workflows/android-maestro.yml` | Push to main (android/ path) | Debug APK + Maestro suite on emulator |

## Local Maestro testing

```bash
cd android
/test-android        # skill: build + install + run all flows
# or directly:
maestro test .maestro/
```

## What's *not* wired up yet

- **Play Console listing** — manual step, needs human to sign up
- **Service account JSON** — created after listing exists
- **Release workflow** — will be added after first manual upload to Play Console

These are documented so when you're ready to ship, the only missing piece is the Play Console human setup.
