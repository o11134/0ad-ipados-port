#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
DEPLOYMENT_TARGET=${IPADOS_DEPLOYMENT_TARGET:-17.0}
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass()
{
	PASS_COUNT=$((PASS_COUNT + 1))
	printf 'PASS: %s\n' "$1"
}

warn()
{
	WARN_COUNT=$((WARN_COUNT + 1))
	printf 'WARN: %s\n' "$1"
}

fail()
{
	FAIL_COUNT=$((FAIL_COUNT + 1))
	printf 'FAIL: %s\n' "$1" >&2
}

skip()
{
	SKIP_COUNT=$((SKIP_COUNT + 1))
	printf 'SKIP: %s\n' "$1"
}

version_at_least()
{
	awk -v actual="$1" -v required="$2" 'BEGIN {
		split(actual, a, ".");
		split(required, r, ".");
		for (i = 1; i <= 4; ++i) {
			av = a[i] + 0;
			rv = r[i] + 0;
			if (av > rv) exit 0;
			if (av < rv) exit 1;
		}
		exit 0;
	}'
}

HOST_SYSTEM=$(uname -s 2>/dev/null || printf 'unknown')
if [ "$HOST_SYSTEM" = "Darwin" ]; then
	MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || printf 'unknown')
	pass "host is macOS $MACOS_VERSION"

	HOST_ARCHITECTURE=$(uname -m 2>/dev/null || printf 'unknown')
	if [ "$HOST_ARCHITECTURE" = "arm64" ]; then
		pass "host architecture is Apple Silicon arm64"
	else
		fail "Apple Silicon arm64 is required; found $HOST_ARCHITECTURE"
	fi

	if command -v xcode-select >/dev/null 2>&1; then
		if DEVELOPER_DIRECTORY=$(xcode-select -p 2>/dev/null); then
			pass "xcode-select points to $DEVELOPER_DIRECTORY"
		else
			fail "xcode-select has no active developer directory"
		fi
	else
		fail "xcode-select is missing"
	fi

	if command -v xcodebuild >/dev/null 2>&1; then
		if XCODE_VERSION=$(xcodebuild -version 2>&1); then
			pass "xcodebuild is available: $(printf '%s' "$XCODE_VERSION" | awk 'NR == 1')"
		else
			fail "xcodebuild could not report its version"
		fi
		if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
			pass "Xcode license and first-launch components report ready"
		else
			warn "Xcode license or first-launch components need operator review"
		fi
	else
		fail "xcodebuild is missing"
	fi

	if command -v xcrun >/dev/null 2>&1; then
		pass "xcrun is available"
		if IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null); then
			if version_at_least "$IPHONEOS_SDK" "$DEPLOYMENT_TARGET"; then
				pass "iPhoneOS SDK $IPHONEOS_SDK satisfies deployment target $DEPLOYMENT_TARGET"
			else
				fail "iPhoneOS SDK $IPHONEOS_SDK is older than deployment target $DEPLOYMENT_TARGET"
			fi
		else
			fail "iPhoneOS SDK is unavailable"
		fi
		if SIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null); then
			if version_at_least "$SIMULATOR_SDK" "$DEPLOYMENT_TARGET"; then
				pass "iPhoneSimulator SDK $SIMULATOR_SDK satisfies deployment target $DEPLOYMENT_TARGET"
			else
				fail "iPhoneSimulator SDK $SIMULATOR_SDK is older than deployment target $DEPLOYMENT_TARGET"
			fi
		else
			fail "iPhoneSimulator SDK is unavailable"
		fi
	else
		fail "xcrun is missing"
	fi
else
	fail "host is $HOST_SYSTEM; iPadOS generation/build requires an Apple Silicon Mac"
	skip "Apple Silicon architecture check is Apple-host-only"
	skip "xcode-select, xcodebuild, xcrun, and Apple SDK checks are Apple-host-only"
fi

if command -v git >/dev/null 2>&1; then
	GIT_VERSION=$(git --version 2>&1)
	pass "$GIT_VERSION"
	if REVISION=$(git -C "$REPOSITORY_ROOT" rev-parse HEAD 2>/dev/null); then
		pass "repository revision is $REVISION"
	else
		fail "repository root is not a readable Git worktree: $REPOSITORY_ROOT"
	fi
else
	fail "Git is missing"
fi

if command -v cmake >/dev/null 2>&1; then
	CMAKE_VERSION=$(cmake --version | awk 'NR == 1 { print $3 }')
	if version_at_least "$CMAKE_VERSION" 3.25; then
		pass "CMake $CMAKE_VERSION satisfies minimum 3.25"
	else
		fail "CMake 3.25 or newer is required; found $CMAKE_VERSION"
	fi
else
	fail "CMake 3.25 or newer is missing"
fi

PYTHON_COMMAND=
if command -v python3 >/dev/null 2>&1 &&
	python3 -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
	PYTHON_COMMAND=python3
elif command -v python >/dev/null 2>&1 &&
	python -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
	PYTHON_COMMAND=python
fi
if [ -n "$PYTHON_COMMAND" ]; then
	PYTHON_VERSION=$($PYTHON_COMMAND --version 2>&1)
	PYTHON_MAJOR=$($PYTHON_COMMAND -c 'import sys; print(sys.version_info[0])' 2>/dev/null || printf 'unknown')
	if [ "$PYTHON_MAJOR" = "3" ]; then
		pass "$PYTHON_VERSION"
	else
		fail "Python 3 is required; found $PYTHON_VERSION"
	fi
else
	fail "Python 3 is missing"
fi

FREE_KB=$(df -Pk "$REPOSITORY_ROOT" 2>/dev/null | awk 'END { print $4 }')
case "$FREE_KB" in
	''|*[!0-9]*)
		warn "free disk space could not be determined"
		;;
	*)
		FREE_GB=$((FREE_KB / 1024 / 1024))
		if [ "$FREE_KB" -ge 10485760 ]; then
			pass "repository volume has approximately ${FREE_GB} GiB free"
		else
			warn "repository volume has only approximately ${FREE_GB} GiB free"
		fi
		;;
esac

MISSING_PROJECT_FILES=
for relative_path in \
	build/ios/CMakeLists.txt \
	build/ios/Info.plist.in \
	source/platform/ios/main.mm \
	source/platform/ios/IOSAppDelegate.mm \
	source/platform/ios/IOSSceneDelegate.mm \
	source/platform/ios/IOSViewController.mm \
	source/platform/ios/IOSPlatformBridge.mm
do
	if [ ! -f "$REPOSITORY_ROOT/$relative_path" ]; then
		MISSING_PROJECT_FILES="$MISSING_PROJECT_FILES $relative_path"
	fi
done
if [ -z "$MISSING_PROJECT_FILES" ]; then
	pass "all required M2 project files are present"
else
	fail "required M2 project files are missing:$MISSING_PROJECT_FILES"
fi

if [ -d "$REPOSITORY_ROOT/binaries/data" ]; then
	pass "runtime data directory is present but is not inspected or required for M2"
else
	skip "runtime/LFS data is absent; M2 intentionally requires no Git LFS hydration"
fi

printf 'SUMMARY: PASS=%s WARN=%s FAIL=%s SKIP=%s\n' \
	"$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
	exit 1
fi
