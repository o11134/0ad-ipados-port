#!/bin/sh

set -eu

if [ "$#" -ne 4 ]; then
	echo "usage: $0 <project-path> <scheme> <artifact-directory> <derived-data-directory>" >&2
	exit 2
fi

PROJECT_PATH=$1
SCHEME=$2
ARTIFACT_DIRECTORY=$3
DERIVED_DATA_DIRECTORY=$4
SIMULATOR_ARTIFACT_DIRECTORY="$ARTIFACT_DIRECTORY/simulator"
SIMULATOR_UDID=
SIMULATOR_NAME=
SIMULATOR_OS_VERSION=
SIMULATOR_STATE=
SIMULATOR_CREATED=0
SIMULATOR_BOOTED_BY_SCRIPT=0
APP_BUNDLE_IDENTIFIER=
APP_INSTALLED=0

if [ "$(uname -s 2>/dev/null || printf 'unknown')" != "Darwin" ]; then
	echo "error: the CI simulator smoke test requires macOS with Xcode." >&2
	exit 1
fi

if [ "$(uname -m 2>/dev/null || printf 'unknown')" != "arm64" ]; then
	echo "error: the CI simulator smoke test requires an arm64 macOS runner." >&2
	exit 1
fi

for required_command in xcodebuild xcrun python3 plutil otool tar sed grep kill find
do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		echo "error: required command is unavailable: $required_command" >&2
		exit 1
	fi
done

if [ ! -d "$PROJECT_PATH" ]; then
	echo "error: Xcode project does not exist: $PROJECT_PATH" >&2
	exit 1
fi

mkdir -p "$SIMULATOR_ARTIFACT_DIRECTORY" "$DERIVED_DATA_DIRECTORY"
SMOKE_SUMMARY="$SIMULATOR_ARTIFACT_DIRECTORY/smoke-summary.txt"
printf 'result=RUNNING\n' > "$SMOKE_SUMMARY"

sanitize_output()
{
	if [ -n "$SIMULATOR_UDID" ]; then
		sed "s/$SIMULATOR_UDID/<SIMULATOR_UDID>/g"
	else
		cat
	fi
}

run_simctl()
{
	if SIMCTL_OUTPUT=$(xcrun simctl "$@" 2>&1); then
		SIMCTL_STATUS=0
	else
		SIMCTL_STATUS=$?
	fi
	if [ -n "$SIMCTL_OUTPUT" ]; then
		printf '%s\n' "$SIMCTL_OUTPUT" | sanitize_output
	fi
	return "$SIMCTL_STATUS"
}

cleanup()
{
	CLEANUP_STATUS=$1
	trap - EXIT HUP INT TERM
	set +e
	if [ -n "$APP_BUNDLE_IDENTIFIER" ] && [ -n "$SIMULATOR_UDID" ]; then
		xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_IDENTIFIER" >/dev/null 2>&1
	fi
	if [ "$APP_INSTALLED" -eq 1 ] && [ -n "$APP_BUNDLE_IDENTIFIER" ] && [ -n "$SIMULATOR_UDID" ]; then
		xcrun simctl uninstall "$SIMULATOR_UDID" "$APP_BUNDLE_IDENTIFIER" >/dev/null 2>&1
	fi
	if [ "$SIMULATOR_BOOTED_BY_SCRIPT" -eq 1 ] && [ -n "$SIMULATOR_UDID" ]; then
		xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1
	fi
	if [ "$SIMULATOR_CREATED" -eq 1 ] && [ -n "$SIMULATOR_UDID" ]; then
		xcrun simctl delete "$SIMULATOR_UDID" >/dev/null 2>&1
	fi
	if [ "$CLEANUP_STATUS" -ne 0 ]; then
		printf 'result=FAIL\nexit_code=%s\n' "$CLEANUP_STATUS" >> "$SMOKE_SUMMARY"
	fi
	exit "$CLEANUP_STATUS"
}

trap 'cleanup $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

RAW_DEVICES="$DERIVED_DATA_DIRECTORY/simctl-devices.json"
RAW_RUNTIMES="$DERIVED_DATA_DIRECTORY/simctl-runtimes.json"
RAW_DEVICE_TYPES="$DERIVED_DATA_DIRECTORY/simctl-device-types.json"
SELECTION_FILE="$DERIVED_DATA_DIRECTORY/simulator-selection.txt"
CREATION_FILE="$DERIVED_DATA_DIRECTORY/simulator-creation.txt"

xcrun simctl list devices available -j > "$RAW_DEVICES"
xcrun simctl list devices available |
	sed -E 's/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/<SIMULATOR_UDID>/g' \
	> "$SIMULATOR_ARTIFACT_DIRECTORY/devices-available.txt"
cat "$SIMULATOR_ARTIFACT_DIRECTORY/devices-available.txt"

if python3 - "$RAW_DEVICES" > "$SELECTION_FILE" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

def runtime_version(identifier):
    match = re.search(r"\.iOS-([0-9-]+)$", identifier)
    if not match:
        return ()
    return tuple(int(part) for part in match.group(1).split("-"))

candidates = []
for runtime, devices in payload.get("devices", {}).items():
    version = runtime_version(runtime)
    if not version:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        name = device.get("name", "")
        udid = device.get("udid", "")
        state = device.get("state", "Shutdown")
        if name.startswith("iPad") and udid:
            candidates.append((state == "Booted", version, name.casefold(), runtime, name, udid, state))

if not candidates:
    raise SystemExit(3)

selected = sorted(candidates, reverse=True)[0]
print(selected[3])
print(".".join(str(part) for part in selected[1]))
print(selected[4])
print(selected[5])
print(selected[6])
PY
then
	SIMULATOR_RUNTIME_ID=$(sed -n '1p' "$SELECTION_FILE")
	SIMULATOR_OS_VERSION=$(sed -n '2p' "$SELECTION_FILE")
	SIMULATOR_NAME=$(sed -n '3p' "$SELECTION_FILE")
	SIMULATOR_UDID=$(sed -n '4p' "$SELECTION_FILE")
	SIMULATOR_STATE=$(sed -n '5p' "$SELECTION_FILE")
	SIMULATOR_SOURCE=preinstalled-device
else
	SELECTION_STATUS=$?
	if [ "$SELECTION_STATUS" -ne 3 ]; then
		echo "error: failed to parse available simulator devices." >&2
		exit "$SELECTION_STATUS"
	fi

	xcrun simctl list runtimes available -j > "$RAW_RUNTIMES"
	xcrun simctl list devicetypes -j > "$RAW_DEVICE_TYPES"
	if ! python3 - "$RAW_RUNTIMES" "$RAW_DEVICE_TYPES" > "$CREATION_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    runtimes = json.load(handle).get("runtimes", [])
with open(sys.argv[2], encoding="utf-8") as handle:
    device_types = json.load(handle).get("devicetypes", [])

available_runtimes = []
for runtime in runtimes:
    if runtime.get("platform") != "iOS" and ".iOS-" not in runtime.get("identifier", ""):
        continue
    if not runtime.get("isAvailable", "unavailable" not in runtime.get("availability", "").lower()):
        continue
    version = tuple(int(part) for part in runtime.get("version", "0").split("."))
    available_runtimes.append((version, runtime.get("identifier", ""), runtime.get("version", "")))

ipad_types = []
for device_type in device_types:
    name = device_type.get("name", "")
    identifier = device_type.get("identifier", "")
    if not name.startswith("iPad") or not identifier:
        continue
    priority = ("iPad Pro (13-inch)" in name, "iPad Pro" in name, "iPad Air" in name, name.casefold())
    ipad_types.append((priority, identifier, name))

if not available_runtimes or not ipad_types:
    raise SystemExit("no installed iOS runtime and iPad device type are available")

runtime = sorted(available_runtimes, reverse=True)[0]
device_type = sorted(ipad_types, reverse=True)[0]
print(runtime[1])
print(runtime[2])
print(device_type[1])
print(device_type[2])
PY
	then
		echo "error: no suitable installed iPad simulator runtime/device type is available." >&2
		exit 1
	fi

	SIMULATOR_RUNTIME_ID=$(sed -n '1p' "$CREATION_FILE")
	SIMULATOR_OS_VERSION=$(sed -n '2p' "$CREATION_FILE")
	SIMULATOR_DEVICE_TYPE=$(sed -n '3p' "$CREATION_FILE")
	SIMULATOR_NAME="Pyrogenesis M2 CI iPad"
	if SIMULATOR_CREATE_OUTPUT=$(xcrun simctl create "$SIMULATOR_NAME" \
		"$SIMULATOR_DEVICE_TYPE" "$SIMULATOR_RUNTIME_ID" 2>&1); then
		SIMULATOR_UDID=$(printf '%s\n' "$SIMULATOR_CREATE_OUTPUT" | sed -n '$p')
		SIMULATOR_CREATED=1
	else
		printf '%s\n' "$SIMULATOR_CREATE_OUTPUT" >&2
		exit 1
	fi
	if ! printf '%s\n' "$SIMULATOR_UDID" |
		grep -E '^[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}$' >/dev/null; then
		echo "error: simctl create did not return a simulator UUID." >&2
		exit 1
	fi
	SIMULATOR_STATE=Shutdown
	SIMULATOR_SOURCE=created-from-installed-runtime
fi

printf 'simulator_name=%s\nruntime=iOS %s\nsource=%s\n' \
	"$SIMULATOR_NAME" "$SIMULATOR_OS_VERSION" "$SIMULATOR_SOURCE" \
	> "$SIMULATOR_ARTIFACT_DIRECTORY/selection.txt"
cat "$SIMULATOR_ARTIFACT_DIRECTORY/selection.txt"

if [ "$SIMULATOR_STATE" != "Booted" ]; then
	run_simctl boot "$SIMULATOR_UDID"
	SIMULATOR_BOOTED_BY_SCRIPT=1
fi
run_simctl bootstatus "$SIMULATOR_UDID" -b

DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
DISPLAY_DESTINATION='platform=iOS Simulator,id=<SIMULATOR_UDID>'
SIMULATOR_BUILD_LOG="$SIMULATOR_ARTIFACT_DIRECTORY/xcodebuild.log"
RAW_SIMULATOR_BUILD_LOG="$DERIVED_DATA_DIRECTORY/simulator-xcodebuild.raw.log"
printf 'xcodebuild -project "%s" -scheme "%s" -configuration Debug -sdk iphonesimulator -destination "%s" -derivedDataPath "%s" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build\n' \
	"$PROJECT_PATH" "$SCHEME" "$DISPLAY_DESTINATION" "$DERIVED_DATA_DIRECTORY" \
	> "$SIMULATOR_ARTIFACT_DIRECTORY/build-command.txt"
cat "$SIMULATOR_ARTIFACT_DIRECTORY/build-command.txt"

if xcodebuild \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration Debug \
	-sdk iphonesimulator \
	-destination "$DESTINATION" \
	-derivedDataPath "$DERIVED_DATA_DIRECTORY" \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	build > "$RAW_SIMULATOR_BUILD_LOG" 2>&1
then
	SIMULATOR_BUILD_STATUS=0
else
	SIMULATOR_BUILD_STATUS=$?
fi
sed -E 's/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/<SIMULATOR_UDID>/g' \
	"$RAW_SIMULATOR_BUILD_LOG" > "$SIMULATOR_BUILD_LOG"
cat "$SIMULATOR_BUILD_LOG"
if [ "$SIMULATOR_BUILD_STATUS" -ne 0 ]; then
	exit "$SIMULATOR_BUILD_STATUS"
fi

APP_PATH=$(python3 - "$DERIVED_DATA_DIRECTORY" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]) / "Build" / "Products" / "Debug-iphonesimulator"
apps = sorted(path for path in root.glob("*.app") if path.is_dir())
if len(apps) != 1:
    raise SystemExit(f"expected one simulator app under {root}, found {len(apps)}")
print(apps[0])
PY
)
INFO_PLIST="$APP_PATH/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
	echo "error: generated simulator Info.plist is missing." >&2
	exit 1
fi
SIGNING_MATERIAL=$(find "$APP_PATH" -type f \
	\( -name '*.mobileprovision' -o -name '*.p12' -o -name '*.cer' \))
if [ -n "$SIGNING_MATERIAL" ]; then
	printf '%s\n' "$SIGNING_MATERIAL" >&2
	echo "error: signing or certificate material exists in the unsigned simulator product." >&2
	exit 1
fi

APP_BUNDLE_IDENTIFIER=$(plutil -extract CFBundleIdentifier raw -o - "$INFO_PLIST")
APP_EXECUTABLE=$(plutil -extract CFBundleExecutable raw -o - "$INFO_PLIST")
if [ -z "$APP_BUNDLE_IDENTIFIER" ] || [ -z "$APP_EXECUTABLE" ]; then
	echo "error: generated simulator app metadata is incomplete." >&2
	exit 1
fi

cp "$INFO_PLIST" "$SIMULATOR_ARTIFACT_DIRECTORY/Info.plist"
plutil -p "$INFO_PLIST" > "$SIMULATOR_ARTIFACT_DIRECTORY/info-plist.txt"
otool -L "$APP_PATH/$APP_EXECUTABLE" > "$SIMULATOR_ARTIFACT_DIRECTORY/linked-frameworks.txt"
if grep -E -i 'SDL|SpiderMonkey|mozjs|MoltenVK|OpenAL|binaries/data' \
	"$SIMULATOR_ARTIFACT_DIRECTORY/linked-frameworks.txt" >/dev/null; then
	echo "error: prohibited engine or third-party linkage found in simulator product." >&2
	exit 1
fi

printf 'product=%s\n' "$APP_PATH" > "$SIMULATOR_ARTIFACT_DIRECTORY/product-path.txt"
tar -czf "$SIMULATOR_ARTIFACT_DIRECTORY/unsigned-simulator-app.tar.gz" \
	-C "$(dirname -- "$APP_PATH")" "$(basename -- "$APP_PATH")"

run_simctl install "$SIMULATOR_UDID" "$APP_PATH"
APP_INSTALLED=1
if LAUNCH_OUTPUT=$(SIMCTL_CHILD_M2_AUTOMATIC_SANDBOX_PROBE=1 \
	xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" \
	"$APP_BUNDLE_IDENTIFIER" --m2-sandbox-probe 2>&1); then
	LAUNCH_STATUS=0
else
	LAUNCH_STATUS=$?
fi
printf '%s\n' "$LAUNCH_OUTPUT" | sanitize_output \
	> "$SIMULATOR_ARTIFACT_DIRECTORY/launch.txt"
cat "$SIMULATOR_ARTIFACT_DIRECTORY/launch.txt"
if [ "$LAUNCH_STATUS" -ne 0 ]; then
	exit "$LAUNCH_STATUS"
fi

APP_PID=$(printf '%s\n' "$LAUNCH_OUTPUT" |
	sed -n 's/^.*: \([0-9][0-9]*\)$/\1/p' | sed -n '$p')
if [ -z "$APP_PID" ]; then
	echo "error: simctl launch did not return an application PID." >&2
	exit 1
fi

sleep 10
if ! kill -0 "$APP_PID" 2>/dev/null; then
	echo "error: simulator application process exited during the smoke-test interval." >&2
	exit 1
fi

LOG_PREDICATE="processID == $APP_PID AND eventMessage CONTAINS \"M2_\""
if MARKER_LOG=$(xcrun simctl spawn "$SIMULATOR_UDID" log show \
	--last 2m --style compact --info --debug --predicate "$LOG_PREDICATE" 2>&1); then
	MARKER_LOG_STATUS=0
else
	MARKER_LOG_STATUS=$?
fi
printf '%s\n' "$MARKER_LOG" | sanitize_output \
	> "$SIMULATOR_ARTIFACT_DIRECTORY/marker-log.txt"
cat "$SIMULATOR_ARTIFACT_DIRECTORY/marker-log.txt"
if [ "$MARKER_LOG_STATUS" -ne 0 ]; then
	exit "$MARKER_LOG_STATUS"
fi

if grep -F 'M2_SANDBOX_PROBE_FAIL' "$SIMULATOR_ARTIFACT_DIRECTORY/marker-log.txt" >/dev/null; then
	echo "error: the automatic sandbox probe reported failure." >&2
	exit 1
fi
if ! grep -F 'M2_SHELL_LAUNCHED' "$SIMULATOR_ARTIFACT_DIRECTORY/marker-log.txt" >/dev/null; then
	echo "error: M2_SHELL_LAUNCHED was not observed for the launched process." >&2
	exit 1
fi
if ! grep -F 'M2_SANDBOX_PROBE_PASS' "$SIMULATOR_ARTIFACT_DIRECTORY/marker-log.txt" >/dev/null; then
	echo "error: M2_SANDBOX_PROBE_PASS was not observed for the launched process." >&2
	exit 1
fi

if SCREENSHOT_OUTPUT=$(xcrun simctl io "$SIMULATOR_UDID" screenshot \
	"$SIMULATOR_ARTIFACT_DIRECTORY/screenshot.png" 2>&1); then
	printf 'PASS: simulator screenshot captured for manual artifact inspection.\n'
else
	printf '%s\n' "$SCREENSHOT_OUTPUT" | sanitize_output >&2
	printf 'WARN: simulator screenshot was unavailable; marker-based smoke checks continue.\n' >&2
fi

printf '%s\n' \
	'result=PASS' \
	'process_alive_after_seconds=10' \
	'launch_marker=M2_SHELL_LAUNCHED' \
	'sandbox_marker=M2_SANDBOX_PROBE_PASS' \
	'background_foreground=SKIP (no documented simctl transition command is assumed)' \
	'visual_result=UNVERIFIED (screenshot, when present, requires human inspection)' \
	> "$SMOKE_SUMMARY"

run_simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_IDENTIFIER"
cat "$SMOKE_SUMMARY"
