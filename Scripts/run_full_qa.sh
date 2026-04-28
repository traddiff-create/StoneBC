#!/usr/bin/env bash

set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT="app.xcodeproj"
IOS_SCHEME="StoneBC"
WATCH_SCHEME="StoneBCWatch"
IOS_DEVICE_NAME="${IOS_DEVICE_NAME:-StoneBC QA iPhone 17 Pro Max}"
IOS_DEVICE_TYPE="${IOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
IOS_RUNTIME="${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-4}"
WATCH_DEVICE_NAME="${WATCH_DEVICE_NAME:-StoneBC QA Apple Watch Ultra 3 (49mm)}"
WATCH_DEVICE_TYPE="${WATCH_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm}"
WATCH_RUNTIME="${WATCH_RUNTIME:-com.apple.CoreSimulator.SimRuntime.watchOS-26-4}"
RESULT_ROOT="${QA_RESULTS_DIR:-${ROOT_DIR}/qa-results}"
if [[ "$RESULT_ROOT" != /* ]]; then
    RESULT_ROOT="${ROOT_DIR}/${RESULT_ROOT}"
fi
RESULT_DIR="${RESULT_ROOT}/$(date +%Y%m%d-%H%M%S)"
DERIVED_DATA="${RESULT_DIR}/DerivedData"
SUMMARY_FILE="${RESULT_DIR}/summary.md"
RUN_LONG_RIDE=1
FAILURES=0
IOS_UDID=""
WATCH_UDID=""
IOS_DESTINATION=""
WATCH_DESTINATION=""
DEFAULT_STEP_TIMEOUT="${DEFAULT_STEP_TIMEOUT:-1800}"

for arg in "$@"; do
    case "$arg" in
        --skip-long-ride)
            RUN_LONG_RIDE=0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

slugify() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//'
}

find_device_udid() {
    local device_name="$1"
    xcrun simctl list devices available \
        | grep -F "${device_name} (" \
        | head -n 1 \
        | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/'
}

find_or_create_device_udid() {
    local device_name="$1"
    local device_type="$2"
    local runtime="$3"
    local udid

    udid="$(find_device_udid "$device_name")"
    if [ -n "$udid" ]; then
        printf "%s" "$udid"
        return 0
    fi

    xcrun simctl create "$device_name" "$device_type" "$runtime"
}

run_command_with_timeout() {
    local timeout_seconds="$1"
    shift
    local started_at="$SECONDS"
    local pid

    "$@" &
    pid=$!

    while kill -0 "$pid" >/dev/null 2>&1; do
        if [ $((SECONDS - started_at)) -ge "$timeout_seconds" ]; then
            echo "Timed out after ${timeout_seconds}s: $*" >&2
            kill "$pid" >/dev/null 2>&1 || true
            sleep 5
            kill -9 "$pid" >/dev/null 2>&1 || true
            wait "$pid" >/dev/null 2>&1 || true
            return 124
        fi
        sleep 2
    done

    wait "$pid"
}

run_step() {
    local name="$1"
    shift
    local timeout_seconds="$DEFAULT_STEP_TIMEOUT"
    if [ "${1:-}" = "--timeout" ]; then
        timeout_seconds="$2"
        shift 2
    fi
    local slug
    slug="$(slugify "$name")"
    local log_file="${RESULT_DIR}/${slug}.log"

    echo "==> ${name}"
    echo "## ${name}" >> "$SUMMARY_FILE"
    echo '```text' >> "$SUMMARY_FILE"
    printf '$' >> "$SUMMARY_FILE"
    printf ' %q' "$@" >> "$SUMMARY_FILE"
    echo >> "$SUMMARY_FILE"

    run_command_with_timeout "$timeout_seconds" "$@" > "$log_file" 2>&1
    local status=$?

    if [ "$status" -eq 0 ]; then
        echo "PASS ${name}"
        echo "PASS" >> "$SUMMARY_FILE"
    else
        echo "FAIL ${name} (${status})"
        echo "FAIL (${status})" >> "$SUMMARY_FILE"
        FAILURES=$((FAILURES + 1))
    fi

    echo '```' >> "$SUMMARY_FILE"
    echo "- Log: ${log_file}" >> "$SUMMARY_FILE"
    echo >> "$SUMMARY_FILE"
    tail -n 40 "$log_file" || true
    echo
}

boot_device() {
    local udid="$1"
    local erase="${2:-0}"

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    sleep 2

    if [ "$erase" -eq 1 ]; then
        local erased=0
        for _ in {1..30}; do
            if xcrun simctl erase "$udid" >/dev/null 2>&1; then
                erased=1
                break
            fi
            sleep 2
        done
        if [ "$erased" -ne 1 ]; then
            echo "Unable to erase simulator ${udid}" >&2
            return 1
        fi
    fi

    local booted=0
    for _ in {1..30}; do
        if xcrun simctl boot "$udid" >/dev/null 2>&1; then
            booted=1
            break
        fi
        if xcrun simctl list devices | grep -F "$udid" | grep -F "(Booted)" >/dev/null 2>&1; then
            booted=1
            break
        fi
        sleep 2
    done
    if [ "$booted" -ne 1 ]; then
        echo "Unable to boot simulator ${udid}" >&2
        return 1
    fi

    run_command_with_timeout 600 xcrun simctl bootstatus "$udid" -b
}

seed_ios_route() {
    xcrun simctl privacy "$IOS_UDID" grant location com.traddiff.StoneBC
    xcrun simctl location "$IOS_UDID" clear || true
    xcrun simctl location "$IOS_UDID" start \
        --speed=4 \
        --interval=5 \
        44.0805,-103.2310 \
        44.0850,-103.2260 \
        44.0915,-103.2200 \
        44.0980,-103.2140 \
        44.1060,-103.2070 \
        44.1130,-103.1980
}

prepare_ios_simulator() {
    if [ -z "$IOS_UDID" ]; then
        IOS_UDID="$(find_device_udid "$IOS_DEVICE_NAME")"
    fi
    if [ -z "$IOS_UDID" ]; then
        echo "Could not find iOS simulator: ${IOS_DEVICE_NAME}" >&2
        return 1
    fi

    boot_device "$IOS_UDID" 1

    local app_path="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/StoneBC.app"
    if [ -d "$app_path" ]; then
        xcrun simctl install "$IOS_UDID" "$app_path"
    fi
    xcrun simctl terminate "$IOS_UDID" com.traddiff.StoneBC >/dev/null 2>&1 || true
    xcrun simctl terminate "$IOS_UDID" com.traddiff.StoneBCUITests.xctrunner >/dev/null 2>&1 || true

    seed_ios_route
}

restart_ios_route() {
    if [ -z "$IOS_UDID" ]; then
        IOS_UDID="$(find_device_udid "$IOS_DEVICE_NAME")"
    fi
    if [ -z "$IOS_UDID" ]; then
        echo "Could not find iOS simulator: ${IOS_DEVICE_NAME}" >&2
        return 1
    fi

    xcrun simctl terminate "$IOS_UDID" com.traddiff.StoneBC >/dev/null 2>&1 || true
    xcrun simctl terminate "$IOS_UDID" com.traddiff.StoneBCUITests.xctrunner >/dev/null 2>&1 || true
    seed_ios_route
}

clear_ios_location() {
    if [ -n "${IOS_UDID:-}" ]; then
        xcrun simctl location "$IOS_UDID" clear >/dev/null 2>&1 || true
    fi
}

launch_watch_smoke() {
    if [ -z "$WATCH_UDID" ]; then
        WATCH_UDID="$(find_device_udid "$WATCH_DEVICE_NAME")"
    fi
    if [ -z "$WATCH_UDID" ]; then
        echo "Could not find watchOS simulator: ${WATCH_DEVICE_NAME}" >&2
        return 1
    fi

    boot_device "$WATCH_UDID"

    local app_path="${DERIVED_DATA}/Build/Products/Debug-watchsimulator/StoneBCWatch.app"
    if [ ! -d "$app_path" ]; then
        echo "Missing watch app at ${app_path}" >&2
        return 1
    fi

    xcrun simctl install "$WATCH_UDID" "$app_path"
    xcrun simctl launch --terminate-running-process "$WATCH_UDID" com.traddiff.StoneBC.watchkitapp -stonebc-watch-ui-stale-pulse
    sleep 5
    xcrun simctl io "$WATCH_UDID" screenshot "${RESULT_DIR}/watch-stale-pulse.png"
    xcrun simctl terminate "$WATCH_UDID" com.traddiff.StoneBC.watchkitapp || true

    xcrun simctl launch "$WATCH_UDID" com.traddiff.StoneBC.watchkitapp
    sleep 5
    xcrun simctl io "$WATCH_UDID" screenshot "${RESULT_DIR}/watch-no-phone.png"
}

trap clear_ios_location EXIT

if ! IOS_UDID="$(find_or_create_device_udid "$IOS_DEVICE_NAME" "$IOS_DEVICE_TYPE" "$IOS_RUNTIME")" || [ -z "$IOS_UDID" ]; then
    echo "Unable to create or find iOS simulator: ${IOS_DEVICE_NAME}" >&2
    exit 1
fi
if ! WATCH_UDID="$(find_or_create_device_udid "$WATCH_DEVICE_NAME" "$WATCH_DEVICE_TYPE" "$WATCH_RUNTIME")" || [ -z "$WATCH_UDID" ]; then
    echo "Unable to create or find watchOS simulator: ${WATCH_DEVICE_NAME}" >&2
    exit 1
fi
IOS_DESTINATION="id=${IOS_UDID}"
WATCH_DESTINATION="id=${WATCH_UDID}"

mkdir -p "$RESULT_DIR"
{
    echo "# StoneBC Full QA"
    echo
    echo "- Started: $(date)"
    echo "- iOS simulator: ${IOS_DEVICE_NAME} (${IOS_UDID})"
    echo "- watchOS simulator: ${WATCH_DEVICE_NAME} (${WATCH_UDID})"
    echo "- Long ride: ${RUN_LONG_RIDE}"
    echo
} > "$SUMMARY_FILE"

run_step "Git status" --timeout 120 git status --short
run_step "Project and plist lint" --timeout 120 plutil -lint \
    app.xcodeproj/project.pbxproj \
    StoneBC/Info.plist \
    StoneBCWatch/Info.plist \
    StoneBCWatchWidgets/Info.plist \
    StoneBCWatch/StoneBCWatch.entitlements \
    StoneBCWatchWidgets/StoneBCWatchWidgets.entitlements
run_step "Diff whitespace check" --timeout 120 git diff --check
run_step "SwiftLint" --timeout 300 bash -lc 'if command -v swiftlint >/dev/null 2>&1; then swiftlint lint --config .swiftlint.yml; else echo "swiftlint not installed"; fi'

run_step "iOS build" --timeout 1800 xcodebuild build \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -destination "$IOS_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA"

run_step "watchOS build" --timeout 1800 xcodebuild build \
    -project "$PROJECT" \
    -scheme "$WATCH_SCHEME" \
    -destination "$WATCH_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA"

run_step "StoneBC tests" --timeout 1800 xcodebuild test \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -destination "$IOS_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -skip-testing:StoneBCUITests/RideRecordingUITests/testShortSimulatedRideRecordingFlow \
    -skip-testing:StoneBCUITests/RideRecordingUITests/testFifteenMinuteSimulatedRideRecording

run_step "Prepare iOS simulator route" --timeout 900 prepare_ios_simulator

run_step "Prepared UI ride smoke" --timeout 900 xcodebuild test \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -destination "$IOS_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -only-testing:StoneBCUITests/RideRecordingUITests/testShortSimulatedRideRecordingFlow

if [ "$RUN_LONG_RIDE" -eq 1 ]; then
    run_step "Restart iOS route for long ride" --timeout 300 restart_ios_route

    run_step "Fifteen-minute ride UI test" --timeout 1800 xcodebuild test \
        -project "$PROJECT" \
        -scheme "$IOS_SCHEME" \
        -destination "$IOS_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -parallel-testing-enabled NO \
        -only-testing:StoneBCUITests/RideRecordingUITests/testFifteenMinuteSimulatedRideRecording
else
    echo "Skipping 15-minute ride test by request." | tee -a "$SUMMARY_FILE"
fi

run_step "watchOS launch smoke" --timeout 900 launch_watch_smoke

clear_ios_location

{
    echo
    echo "## Result"
    if [ "$FAILURES" -eq 0 ]; then
        echo "PASS: all collected checks passed."
    else
        echo "FAIL: ${FAILURES} collected check(s) failed."
    fi
    echo
    echo "Finished: $(date)"
} >> "$SUMMARY_FILE"

echo "QA summary: ${SUMMARY_FILE}"

if [ "$FAILURES" -ne 0 ]; then
    exit 1
fi
