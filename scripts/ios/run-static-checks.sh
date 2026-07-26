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

if [ -f "$REPOSITORY_ROOT/patches/upstream/0001-sysdep-detect-ios-platform.patch" ] &&
	[ -f "$REPOSITORY_ROOT/patches/upstream/0002-timer-include-sys-time.patch" ] &&
	[ -f "$REPOSITORY_ROOT/patches/upstream/0003-unix-ios-portability.patch" ] &&
	[ -f "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch" ] &&
	grep -F 'sys/time.h' "$REPOSITORY_ROOT/patches/upstream/0002-timer-include-sys-time.patch" >/dev/null &&
	grep -F 'OS_IOS' "$REPOSITORY_ROOT/patches/upstream/0003-unix-ios-portability.patch" >/dev/null &&
	[ "$(grep -F -c 'diff --git a/source/lib/sysdep/os/ios/ios.cpp b/source/lib/sysdep/os/ios/ios.cpp' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch")" -eq 1 ] &&
	[ "$(grep -F -c 'new file mode 100644' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch")" -eq 1 ] &&
	[ "$(grep -F -c -- '--- /dev/null' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch")" -eq 1 ] &&
	[ "$(grep -F -c '+++ b/source/lib/sysdep/os/ios/ios.cpp' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch")" -eq 1 ] &&
	[ "$(grep -F -c '+OsPath sys_ExecutablePathname()' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch")" -eq 1 ] &&
	grep -F '_NSGetExecutablePath' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch" >/dev/null &&
	grep -F 'realpath' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch" >/dev/null &&
	! grep -F 'PATH_MAX' "$REPOSITORY_ROOT/patches/upstream/0004-ios-executable-path.patch" >/dev/null &&
	grep -F 'apply --check' "$REPOSITORY_ROOT/scripts/ios/apply-upstream-patches.sh" > /dev/null &&
	grep -F '/*.patch' "$REPOSITORY_ROOT/scripts/ios/apply-upstream-patches.sh" >/dev/null &&
	! grep -F -- '--3way' "$REPOSITORY_ROOT/scripts/ios/apply-upstream-patches.sh" >/dev/null &&
	! grep -F 'fuzzy' "$REPOSITORY_ROOT/scripts/ios/apply-upstream-patches.sh" >/dev/null &&
	! grep -F 'patch -F' "$REPOSITORY_ROOT/scripts/ios/apply-upstream-patches.sh" >/dev/null; then
	pass "upstream patching is deterministic and unified-diff based"
else
	fail "deterministic unified patching checks failed"
fi

CORE_CMAKE="$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt"
CORE_PROBE="$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm"
CORE_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml"
CORE_LIBRARY_BLOCK=$(sed -n '/add_library(PyrogenesisCoreIOS STATIC/,/source\/lib\/sysdep\/os\/ios\/ios.cpp")/p' "$CORE_CMAKE" 2>/dev/null || true)
CORE_PROBE_LINK_BLOCK=$(sed -n '/target_link_libraries(PyrogenesisCoreProbe PRIVATE/,/"-framework UIKit")/p' "$CORE_CMAKE" 2>/dev/null || true)
CORE_PROBE_LINK_ENTRIES=$(printf '%s\n' "$CORE_PROBE_LINK_BLOCK" | sed '1d; s/)[[:space:]]*$//; /^[[:space:]]*$/d')

if [ -f "$CORE_CMAKE" ] &&
	[ -f "$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm" ] &&
	[ -f "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" ] &&
	grep -F 'timer.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	grep -F 'module_init.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	[ "$(grep -F -c 'source/lib/wsecure_crt.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt")" -eq 1 ] &&
	[ "$(grep -F -c 'source/lib/fnv_hash.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt")" -eq 1 ] &&
	[ "$(grep -F -c 'source/lib/sysdep/os/osx/odbg.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt")" -eq 1 ] &&
	[ "$(grep -F -c 'source/lib/sysdep/os/ios/ios.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt")" -eq 1 ] &&
	! grep -F 'source/lib/sysdep/os/osx/osx.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	! grep -F 'source/lib/sysdep/os/osx/osx_bundle.mm' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	! grep -F 'source/lib/sysdep/os/linux/ldbg.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	! grep -F 'source/lib/sysdep/os/bsd/bdbg.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	[ "$(grep -F -c 'target_compile_definitions(PyrogenesisCoreIOS PRIVATE CONFIG_ENABLE_PCH=0)' "$CORE_CMAKE")" -eq 1 ] &&
	! grep -F 'target_link_libraries(PyrogenesisCoreIOS' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	! grep -i -E 'fmt|boost|sdl|mozjs|spidermonkey|moltenvk|vulkan|openal|enet|vfs|renderer|network' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null &&
	[ "$(printf '%s\n' "$CORE_PROBE_LINK_ENTRIES" | grep -c .)" -eq 3 ] &&
	[ "$(printf '%s\n' "$CORE_PROBE_LINK_ENTRIES" | grep -F -c 'PyrogenesisCoreIOS')" -eq 1 ] &&
	[ "$(printf '%s\n' "$CORE_PROBE_LINK_BLOCK" | grep -F -c '"-framework ')" -eq 2 ] &&
	[ "$(printf '%s\n' "$CORE_PROBE_LINK_BLOCK" | grep -F -c '"-framework Foundation"')" -eq 1 ] &&
	[ "$(printf '%s\n' "$CORE_PROBE_LINK_BLOCK" | grep -F -c '"-framework UIKit"')" -eq 1 ] &&
	[ "$(grep -F -c 'timer_Init();' "$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm")" -eq 1 ] &&
	grep -F 'M3_TIMER_INIT_PASS' "$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm" >/dev/null &&
	grep -F 'M3_CORE_BOOTSTRAP_PASS' "$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm" >/dev/null &&
	! grep -E 'Threading|M3_C2_' "$REPOSITORY_ROOT/source/platform/probe/CoreProbe.mm" >/dev/null &&
	grep -F 'otool -L' "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" >/dev/null &&
	grep -F 'nm -u' "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" >/dev/null &&
	grep -F 'M3_TIMER_INIT_PASS' "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" >/dev/null &&
	grep -F 'M3_CORE_BOOTSTRAP_PASS' "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" >/dev/null &&
	! grep -E 'PyrogenesisThreadProbe|M3_C2_' "$REPOSITORY_ROOT/.github/workflows/ipados-m3-core.yml" >/dev/null &&
	! grep -F 'GameSetup.cpp' "$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt" >/dev/null; then
	pass "M3-C1 core probe CMake, probe source, and workflow configuration are valid"
else
	fail "M3-C1 core probe static checks failed"
fi

THREAD_CMAKE="$REPOSITORY_ROOT/build/ios/core/CMakeLists.txt"
THREAD_PROBE="$REPOSITORY_ROOT/source/platform/probe/ThreadProbe.mm"
THREAD_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/ipados-m3-thread.yml"
THREAD_DOCUMENTATION="$REPOSITORY_ROOT/docs/ipados/M3_THREAD_BOOTSTRAP.md"
M3_C2_STATIC_OK=1

for required_file in "$THREAD_CMAKE" "$THREAD_PROBE" "$THREAD_WORKFLOW" "$THREAD_DOCUMENTATION"; do
	if [ ! -f "$required_file" ]; then
		M3_C2_STATIC_OK=0
	fi
done

EXPECTED_UPSTREAM_SOURCES='
source/lib/timer.cpp
source/lib/module_init.cpp
source/lib/debug.cpp
source/lib/fnv_hash.cpp
source/lib/status.cpp
source/lib/utf8.cpp
source/lib/path.cpp
source/lib/app_hooks.cpp
source/lib/secure_crt.cpp
source/lib/wsecure_crt.cpp
source/lib/sysdep/os/unix/unix.cpp
source/lib/sysdep/os/unix/udbg.cpp
source/lib/sysdep/os/osx/odbg.cpp
source/lib/sysdep/os/ios/ios.cpp'
for expected_source in $EXPECTED_UPSTREAM_SOURCES; do
	if [ "$(printf '%s\n' "$CORE_LIBRARY_BLOCK" | grep -F -c "$expected_source" || true)" -ne 1 ]; then
		M3_C2_STATIC_OK=0
	fi
done
THREAD_TARGET_BLOCK=$(sed -n '/add_executable(PyrogenesisThreadProbe/,/source\/ps\/Threading.cpp")/p' "$THREAD_CMAKE" 2>/dev/null || true)
THREAD_LINK_BLOCK=$(sed -n '/target_link_libraries(PyrogenesisThreadProbe PRIVATE/,/"-framework UIKit")/p' "$THREAD_CMAKE" 2>/dev/null || true)
THREAD_LINK_ENTRIES=$(printf '%s\n' "$THREAD_LINK_BLOCK" | sed '1d; s/)[[:space:]]*$//; /^[[:space:]]*$/d')
if [ "$(printf '%s\n' "$CORE_LIBRARY_BLOCK" | grep -E -c '^[[:space:]]*"\$\{IPADOS_UPSTREAM_SOURCE\}/source/.*\.cpp"' || true)" -ne 14 ] ||
	[ "$(printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -E -c '^[[:space:]]*"\$\{IPADOS_UPSTREAM_SOURCE\}/source/.*\.cpp"' || true)" -ne 1 ] ||
	[ "$(printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -F -c 'source/ps/Threading.cpp' || true)" -ne 1 ] ||
	[ "$(grep -E -c '^[[:space:]]*"\$\{IPADOS_UPSTREAM_SOURCE\}/source/.*\.cpp"' "$THREAD_CMAKE" || true)" -ne 15 ]; then
	M3_C2_STATIC_OK=0
fi
if printf '%s\n' "$CORE_LIBRARY_BLOCK" | grep -F 'Threading.cpp' >/dev/null; then
	M3_C2_STATIC_OK=0
fi
if ! printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -F 'EXCLUDE_FROM_ALL' >/dev/null ||
	[ "$(printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -E -c '\.(mm|cpp)"' || true)" -ne 2 ] ||
	[ "$(printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -F -c 'source/platform/probe/ThreadProbe.mm' || true)" -ne 1 ] ||
	[ "$(printf '%s\n' "$THREAD_TARGET_BLOCK" | grep -F -c 'source/ps/Threading.cpp' || true)" -ne 1 ]; then
	M3_C2_STATIC_OK=0
fi

REQUIRED_THREAD_MARKERS='
M3_C2_CORE_REGRESSION_STARTED
M3_C2_CORE_REGRESSION_PASS
M3_THREAD_BOOTSTRAP_STARTED
M3_MAIN_THREAD_PASS
M3_WORKER_THREAD_PASS
M3_MAIN_THREAD_POST_JOIN_PASS
M3_DEBUG_THREAD_NAME_PASS
M3_DEBUG_FILTER_PASS
M3_C2_BOOTSTRAP_PASS'
for required_marker in $REQUIRED_THREAD_MARKERS; do
	if [ "$(grep -F -c "$required_marker" "$THREAD_PROBE" || true)" -ne 1 ] ||
		[ "$(grep -F -c "$required_marker" "$THREAD_WORKFLOW" || true)" -ne 1 ]; then
		M3_C2_STATIC_OK=0
	fi
done

if [ "$(grep -F -c 'target_compile_definitions(PyrogenesisThreadProbe PRIVATE CONFIG_ENABLE_PCH=0)' "$THREAD_CMAKE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'target_link_libraries(PyrogenesisThreadProbe PRIVATE' "$THREAD_CMAKE" || true)" -ne 1 ] ||
	[ "$(printf '%s\n' "$THREAD_LINK_ENTRIES" | grep -c . || true)" -ne 3 ] ||
	[ "$(printf '%s\n' "$THREAD_LINK_BLOCK" | grep -F -c 'PyrogenesisCoreIOS' || true)" -ne 1 ] ||
	[ "$(printf '%s\n' "$THREAD_LINK_BLOCK" | grep -F -c '"-framework Foundation"' || true)" -ne 1 ] ||
	[ "$(printf '%s\n' "$THREAD_LINK_BLOCK" | grep -F -c '"-framework UIKit"' || true)" -ne 1 ] ||
	[ "$(grep -F -c 'org.example.pyrogenesis.thread-probe' "$THREAD_CMAKE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'Threading::SetMainThread();' "$THREAD_PROBE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'Threading::IsMainThread()' "$THREAD_PROBE" || true)" -ne 3 ] ||
	[ "$(grep -F -c 'std::thread worker' "$THREAD_PROBE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'worker.join();' "$THREAD_PROBE" || true)" -ne 1 ] ||
	grep -F '.detach(' "$THREAD_PROBE" >/dev/null ||
	[ "$(grep -F -c 'debug_SetThreadName("main");' "$THREAD_PROBE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'pthread_getname_np(' "$THREAD_PROBE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'debug_filter_allows("FILES|M3-C2")' "$THREAD_PROBE" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'debug_filter_add("FILES");' "$THREAD_PROBE" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_DEBUG_FILTER_BEFORE=%d' "$THREAD_PROBE" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'M3_DEBUG_FILTER_AFTER=%d' "$THREAD_PROBE" || true)" -ne 2 ] ||
	grep -E '(^|[^[:alnum:]_])(exit|_exit|abort)[[:space:]]*\(' "$THREAD_PROBE" >/dev/null; then
	M3_C2_STATIC_OK=0
fi

if [ "$(grep -F -c 'name: iPadOS M3 Thread Bootstrap' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c -- '-scheme PyrogenesisThreadProbe' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c -- '-sdk iphoneos' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c -- '-sdk iphonesimulator' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'sh scripts/ios/apply-upstream-patches.sh' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'cmake -S build/ios/core' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'CODE_SIGNING_ALLOWED=NO' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'CODE_SIGNING_REQUIRED=NO' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'CompileC .*Threading\.o .*source/ps/Threading\.cpp' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c '** BUILD SUCCEEDED **' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'otool -L' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'nm -u' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'error: prohibited dynamic dependency' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'error: prohibited symbol leakage' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c '_al[A-Z][A-Za-z0-9_]*' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'simctl install' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'simctl launch' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'simulator-selection.txt' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	[ "$(grep -F -c 'simulator_name=%s' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'simulator_runtime=%s' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'simulator_udid=%s' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_MAIN_IS_MAIN=1' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_WORKER_IS_MAIN=0' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_WORKER_JOINED=1' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_MAIN_POST_JOIN_IS_MAIN=1' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_PTHREAD_GETNAME_RESULT=0' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_DEBUG_THREAD_NAME_VALUE=main' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_DEBUG_FILTER_BEFORE=0' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_DEBUG_FILTER_AFTER=1' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'M3_C2_BOOTSTRAP_FAIL' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'if count != 1:' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'if positions != sorted(positions):' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'if marker in text:' "$THREAD_WORKFLOW" || true)" -ne 1 ] ||
	[ "$(grep -F -c 'simctl terminate' "$THREAD_WORKFLOW" || true)" -ne 2 ] ||
	grep -F 'simctl terminate "$SIMULATOR_UDID" "$THREAD_BUNDLE_ID" || true' "$THREAD_WORKFLOW" >/dev/null ||
	grep -E 'secrets\.|DEVELOPMENT_TEAM|PROVISIONING_PROFILE|CODE_SIGN_IDENTITY|CODE_SIGNING_ALLOWED[[:space:]]*=[[:space:]]*YES|git[[:space:]]+lfs|build-ios-deps|devicectl|ios-deploy|(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(reset[[:space:]]+--hard|clean|stash|rebase|push[[:space:]]+--force)' "$THREAD_WORKFLOW" >/dev/null; then
	M3_C2_STATIC_OK=0
fi

if grep -i -E 'Profiler2|Paths|CreateVfs|(^|[^[:alnum:]_])VFS([^[:alnum:]_]|$)|GameSetup|EarlyInit|Script::Engine|CXeromyces|(^|[^[:alnum:]_])SDL2?([^[:alnum:]_]|$)|SpiderMonkey|mozjs|Renderer|SoundManager|(^|[^[:alnum:]_])Audio([^[:alnum:]_]|$)|NetClient|NetServer|Networking|MoltenVK|Vulkan|OpenAL|(^|[^[:alnum:]_])ENet([^[:alnum:]_]|$)|fmt|Boost' "$THREAD_CMAKE" "$THREAD_PROBE" >/dev/null ||
	[ "$(grep -F -c 'M3-C2: IN PROGRESS / NOT VERIFIED' "$THREAD_DOCUMENTATION" || true)" -ne 1 ] ||
	grep -F 'M3-C2: PASS' "$THREAD_DOCUMENTATION" >/dev/null; then
	M3_C2_STATIC_OK=0
fi

if [ "$M3_C2_STATIC_OK" -eq 1 ]; then
	pass "M3-C2 thread probe, isolated source closure, workflow, and pre-CI status are valid"
else
	fail "M3-C2 thread bootstrap static checks failed"
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
