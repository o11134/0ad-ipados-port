#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
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

MISSING_FILES=
for relative_path in \
	.github/workflows/ipados-m2.yml \
	build/ios/CMakeLists.txt \
	build/ios/IOSBuildConfig.h.in \
	build/ios/Info.plist.in \
	docs/ipados/GITHUB_ACTIONS.md \
	docs/ipados/MAC_HANDOFF.md \
	docs/ipados/M2_FILE_INVENTORY.md \
	scripts/ios/run-ci-simulator-smoke.sh \
	scripts/ios/run-static-checks.ps1 \
	scripts/ios/verify-mac-environment.sh \
	source/platform/ios/main.mm \
	source/platform/ios/IOSAppDelegate.mm \
	source/platform/ios/IOSSceneDelegate.mm \
	source/platform/ios/IOSViewController.mm \
	source/platform/ios/IOSPlatformBridge.mm
do
	if [ ! -f "$REPOSITORY_ROOT/$relative_path" ]; then
		MISSING_FILES="$MISSING_FILES $relative_path"
	fi
done
if [ -z "$MISSING_FILES" ]; then
	pass "required M2 source, build, CI, script, and documentation files are present"
else
	fail "required files are missing:$MISSING_FILES"
fi

SHELL_SYNTAX_FAILED=0
for script in "$SCRIPT_DIR"/*.sh; do
	if ! sh -n "$script"; then
		SHELL_SYNTAX_FAILED=1
	fi
done
if [ "$SHELL_SYNTAX_FAILED" -eq 0 ]; then
	pass "shell syntax is valid for every scripts/ios/*.sh file"
else
	fail "one or more scripts/ios shell files have invalid syntax"
fi

WORKFLOW_FILE="$REPOSITORY_ROOT/.github/workflows/ipados-m2.yml"
if command -v ruby >/dev/null 2>&1; then
	if ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0))' "$WORKFLOW_FILE"; then
		pass "Ruby YAML parser accepts the GitHub Actions workflow"
	else
		fail "Ruby YAML parser rejects the GitHub Actions workflow"
	fi
else
	skip "full YAML parser is unavailable; Windows structural workflow checks remain required"
fi

if grep -n "$(printf '\t')" "$WORKFLOW_FILE"; then
	fail "GitHub Actions workflow contains tab indentation"
else
	pass "GitHub Actions workflow uses space-only indentation"
fi

WORKFLOW_STRUCTURE_FAILED=0
for required_fragment in \
	'name: iPadOS M2 Scaffold' \
	'workflow_dispatch:' \
	'push:' \
	'pull_request:' \
	'contents: read' \
	'cancel-in-progress: true' \
	'runs-on: macos-15' \
	'timeout-minutes: 45' \
	'CODE_SIGNING_ALLOWED=NO' \
	'if: ${{ always() }}' \
	'retention-days: 14'
do
	if ! grep -F "$required_fragment" "$WORKFLOW_FILE" >/dev/null; then
		printf 'missing workflow fragment: %s\n' "$required_fragment" >&2
		WORKFLOW_STRUCTURE_FAILED=1
	fi
done
if [ "$WORKFLOW_STRUCTURE_FAILED" -eq 0 ]; then
	pass "workflow triggers, permissions, runner, timeout, signing-off, always-upload, and retention fields are present"
else
	fail "GitHub Actions workflow structure is incomplete"
fi

ACTION_REFERENCE_COUNT=$(grep -c -E '^[[:space:]]+uses: actions/(checkout|upload-artifact)@[0-9a-f]{40}([[:space:]]+#.*)?$' "$WORKFLOW_FILE" || true)
ALL_USES_COUNT=$(grep -c -E '^[[:space:]]+uses:' "$WORKFLOW_FILE" || true)
if [ "$ACTION_REFERENCE_COUNT" -eq 2 ] && [ "$ALL_USES_COUNT" -eq 2 ]; then
	pass "workflow uses only two official GitHub actions pinned to immutable commit SHAs"
else
	fail "workflow action references are not the expected pinned official actions"
fi

if grep -n -E 'secrets\.|DEVELOPMENT_TEAM[^[:space:]]*[=:][[:space:]]*[A-Z0-9]{10}([^A-Z0-9]|$)|PROVISIONING_PROFILE|CODE_SIGN_IDENTITY|git[[:space:]]+lfs[[:space:]]+(pull|fetch)|(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(reset[[:space:]]+--hard|clean|stash|rebase|push[[:space:]]+--force)' "$WORKFLOW_FILE"; then
	fail "workflow contains a secret, signing value, download, LFS hydration, or destructive Git command"
else
	pass "workflow contains no secret reference, signing identity, downloader, LFS hydration, or destructive Git command"
fi

if grep -F 'set(CMAKE_XCODE_GENERATE_SCHEME ON)' "$REPOSITORY_ROOT/build/ios/CMakeLists.txt" >/dev/null &&
	grep -F 'M2_SHELL_LAUNCHED' "$REPOSITORY_ROOT/source/platform/ios/IOSAppDelegate.mm" >/dev/null &&
	grep -F 'M2_SANDBOX_PROBE_PASS' "$REPOSITORY_ROOT/source/platform/ios/IOSViewController.mm" >/dev/null &&
	grep -F 'M2_SANDBOX_PROBE_FAIL' "$REPOSITORY_ROOT/source/platform/ios/IOSViewController.mm" >/dev/null &&
	grep -F 'processID == $APP_PID' "$REPOSITORY_ROOT/scripts/ios/run-ci-simulator-smoke.sh" >/dev/null; then
	pass "deterministic Xcode scheme and launched-process simulator smoke markers are wired"
else
	fail "Xcode scheme or simulator smoke marker wiring is incomplete"
fi

if command -v plutil >/dev/null 2>&1; then
	if plutil -lint "$REPOSITORY_ROOT/build/ios/Info.plist.in" >/dev/null; then
		pass "Apple plutil accepts Info.plist.in"
	else
		fail "Apple plutil rejects Info.plist.in"
	fi
else
	skip "Apple plutil is unavailable; fallback XML parsing is not Apple plist validation"
	PYTHON_COMMAND=
	if command -v python3 >/dev/null 2>&1 &&
		python3 -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
		PYTHON_COMMAND=python3
	elif command -v python >/dev/null 2>&1 &&
		python -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
		PYTHON_COMMAND=python
	fi
	if [ -n "$PYTHON_COMMAND" ]; then
		if "$PYTHON_COMMAND" -c \
			'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' \
			"$REPOSITORY_ROOT/build/ios/Info.plist.in"; then
			pass "fallback XML parser accepts Info.plist.in"
		else
			fail "fallback XML parser rejects Info.plist.in"
		fi
	else
		skip "plist XML validation unavailable because neither plutil nor Python is installed"
	fi
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'(^|[^[:alnum:]])[A-Za-z]:\\|/(Users|home)/|/opt/homebrew/|/usr/local/' \
	"$REPOSITORY_ROOT/build/ios" "$REPOSITORY_ROOT/docs/ipados" \
	"$REPOSITORY_ROOT/libraries/ios" "$REPOSITORY_ROOT/scripts/ios" \
	"$REPOSITORY_ROOT/source/platform/ios"; then
	fail "hard-coded host-specific absolute path found in M0/M2 files"
else
	pass "no hard-coded user-specific or dependency-prefix absolute paths found"
fi

if grep -F '/Applications/Xcode.app/Contents/Developer' \
	"$REPOSITORY_ROOT/docs/ipados/MAC_HANDOFF.md" >/dev/null; then
	warn "MAC_HANDOFF.md intentionally names the standard Xcode.app developer directory; verify it locally"
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'BEGIN ([A-Z ]+ )?PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[[:alnum:]]{20,}|sk-[[:alnum:]]{20,}' \
	"$REPOSITORY_ROOT/build/ios" "$REPOSITORY_ROOT/docs/ipados" \
	"$REPOSITORY_ROOT/libraries/ios" "$REPOSITORY_ROOT/scripts/ios" \
	"$REPOSITORY_ROOT/source/platform/ios"; then
	fail "private key or credential-shaped value found"
else
	pass "no private key or common credential pattern found"
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'DEVELOPMENT_TEAM([[:space:]]+|[[:space:]]*=[[:space:]]*)"?[A-Z0-9]{10}("?|[^A-Z0-9]|$)' \
	"$REPOSITORY_ROOT/build/ios" "$REPOSITORY_ROOT/docs/ipados" \
	"$REPOSITORY_ROOT/scripts/ios"; then
	fail "hard-coded Apple Development Team value found"
else
	pass "no hard-coded Apple Development Team value found"
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'performSelector|NSClassFromString|(^|[^[:alnum:]_])(dlopen|dlsym|fork|popen|system)[[:space:]]*\(|allow-unsigned-executable-memory' \
	"$REPOSITORY_ROOT/build/ios" "$REPOSITORY_ROOT/libraries/ios" \
	"$REPOSITORY_ROOT/scripts/ios" "$REPOSITORY_ROOT/source/platform/ios"; then
	fail "private or prohibited runtime primitive found in the M2 build scope"
else
	pass "no scanned private or prohibited runtime primitive found in the M2 build scope"
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'NSURLSession|NWConnection|CFNetwork|UIWebView|WKWebView|NSAllowsArbitraryLoads|UIBackgroundModes|com\.apple\.developer\.networking' \
	"$REPOSITORY_ROOT/build/ios" "$REPOSITORY_ROOT/source/platform/ios"; then
	fail "network, web-view, or background-mode API/configuration found in M2"
else
	pass "M2 build and source contain no scanned network, web-view, or background-mode API/configuration"
fi

if grep -R -n -E --exclude=run-static-checks.sh --exclude=run-static-checks.ps1 \
	--exclude-dir=out --exclude-dir=generated --exclude-dir=DerivedData --exclude-dir=xcuserdata \
	--exclude-dir=downloads --exclude-dir=output \
	'(^|[[:space:]])(curl|wget|git[[:space:]]+lfs)([[:space:]]|$)|Invoke-WebRequest|https?://' \
	"$REPOSITORY_ROOT/scripts/ios"; then
	fail "download, remote script, or Git LFS command found in scripts/ios"
else
	pass "scripts/ios contain no download, remote script, or Git LFS command"
fi

if grep -F 'set(IPADOS_BUNDLE_IDENTIFIER "org.example.pyrogenesis.ipadshell"' \
	"$REPOSITORY_ROOT/build/ios/CMakeLists.txt" >/dev/null &&
	grep -F 'set(IPADOS_PRODUCT_NAME "Pyrogenesis iPad Shell"' \
	"$REPOSITORY_ROOT/build/ios/CMakeLists.txt" >/dev/null; then
	pass "temporary bundle identifier and product-name defaults are exact"
else
	fail "temporary bundle identifier or product-name default differs from the reviewed value"
fi

if command -v git >/dev/null 2>&1 && git -C "$REPOSITORY_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
	IGNORE_FAILED=0
	for ignored_path in \
		build/ios/out/probe \
		build/ios/generated/probe.h \
		build/ios/DerivedData/probe \
		build/ios/Probe.xcodeproj/xcuserdata/probe \
		build/ios/Probe.xcodeproj/project.xcworkspace/xcuserdata/probe.xcuserstate \
		libraries/ios/downloads/probe \
		libraries/ios/build/device/probe \
		libraries/ios/output/device/probe
	do
		if ! git -C "$REPOSITORY_ROOT" check-ignore -q --no-index -- "$ignored_path"; then
			printf 'not ignored: %s\n' "$ignored_path" >&2
			IGNORE_FAILED=1
		fi
	done
	if [ "$IGNORE_FAILED" -eq 0 ]; then
		pass "generated project, user state, DerivedData, download, build, and output probes are ignored"
	else
		fail "one or more generated/output probes are not ignored"
	fi
else
	skip "Git ignore behavior could not be checked"
fi

if command -v cmake >/dev/null 2>&1; then
	if [ "$(uname -s 2>/dev/null || printf 'unknown')" = "Darwin" ] &&
		command -v xcodebuild >/dev/null 2>&1 && command -v xcrun >/dev/null 2>&1; then
		CMAKE_CHECK_DIRECTORY="$REPOSITORY_ROOT/build/ios/out/static-check-iphonesimulator"
		if CMAKE_OUTPUT=$(cmake \
			-S "$REPOSITORY_ROOT/build/ios" \
			-B "$CMAKE_CHECK_DIRECTORY" \
			-G Xcode \
			-DCMAKE_SYSTEM_NAME=iOS \
			-DCMAKE_OSX_SYSROOT=iphonesimulator \
			-DIPADOS_SOURCE_REVISION=static-check 2>&1); then
			pass "CMake configured the isolated ARM64 simulator project; no compile was performed"
		else
			printf '%s\n' "$CMAKE_OUTPUT" >&2
			fail "CMake could not configure the isolated simulator project"
		fi
	else
		skip "CMake configure requires macOS with Xcode and Apple SDKs"
	fi
else
	skip "CMake syntax/configure check unavailable because CMake is not installed"
fi

printf 'SUMMARY: PASS=%s WARN=%s FAIL=%s SKIP=%s\n' \
	"$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
printf 'NOTE: static checks do not prove Objective-C++ compilation, signing, simulator launch, or device launch.\n'

if [ "$FAIL_COUNT" -ne 0 ]; then
	exit 1
fi
