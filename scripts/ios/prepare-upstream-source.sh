#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
UPSTREAM_REVISION_FILE="$REPOSITORY_ROOT/UPSTREAM_REVISION"

if [ ! -f "$UPSTREAM_REVISION_FILE" ]; then
	echo "error: UPSTREAM_REVISION file is missing." >&2
	exit 1
fi

UPSTREAM_REPOSITORY=$(sed -n 's/^repository=//p' "$UPSTREAM_REVISION_FILE")
UPSTREAM_COMMIT=$(sed -n 's/^commit=//p' "$UPSTREAM_REVISION_FILE")

if [ -z "$UPSTREAM_REPOSITORY" ] || [ -z "$UPSTREAM_COMMIT" ]; then
	echo "error: UPSTREAM_REVISION must contain repository= and commit= lines." >&2
	exit 1
fi

WORKSPACE_ROOT=${IPADOS_UPSTREAM_WORKSPACE:-"${RUNNER_TEMP:-/tmp}/ipados-upstream-source"}

printf 'upstream_repository=%s\n' "$UPSTREAM_REPOSITORY"
printf 'upstream_commit=%s\n' "$UPSTREAM_COMMIT"
printf 'workspace_root=%s\n' "$WORKSPACE_ROOT"

rm -rf "$WORKSPACE_ROOT"
mkdir -p "$WORKSPACE_ROOT"

git clone \
	--filter=blob:none \
	--no-checkout \
	--no-tags \
	--single-branch \
	"$UPSTREAM_REPOSITORY" "$WORKSPACE_ROOT" 2>&1

cd "$WORKSPACE_ROOT"

git sparse-checkout init --cone
git sparse-checkout set \
	source \
	build \
	libraries \
	docs

git checkout --detach "$UPSTREAM_COMMIT" 2>&1

ACTUAL_HEAD=$(git rev-parse HEAD)
printf 'actual_head=%s\n' "$ACTUAL_HEAD"

if [ "$ACTUAL_HEAD" != "$UPSTREAM_COMMIT" ]; then
	echo "error: upstream HEAD mismatch." >&2
	printf 'expected=%s\n' "$UPSTREAM_COMMIT" >&2
	printf 'actual=%s\n' "$ACTUAL_HEAD" >&2
	exit 1
fi
printf 'PASS: upstream HEAD matches pinned commit\n'

if [ -d "$WORKSPACE_ROOT/binaries/data" ]; then
	echo "error: binaries/data is materialized; LFS or full checkout detected." >&2
	exit 1
fi
if [ -d "$WORKSPACE_ROOT/binaries" ]; then
	echo "error: binaries/ directory exists; sparse checkout is too broad." >&2
	exit 1
fi
printf 'PASS: binaries/data is not materialized\n'

LFS_STATUS="not-installed"
if command -v git-lfs >/dev/null 2>&1; then
	LFS_STATUS="installed-but-not-fetched"
	if [ -d "$WORKSPACE_ROOT/.git/lfs/objects" ] && [ -n "$(ls -A "$WORKSPACE_ROOT/.git/lfs/objects" 2>/dev/null)" ]; then
		echo "error: Git LFS objects were downloaded unexpectedly." >&2
		exit 1
	fi
fi
printf 'lfs_status=%s\n' "$LFS_STATUS"
printf 'PASS: no LFS objects downloaded\n'

FAIL_COUNT=0
for required_path in \
	source/lib/sysdep/os.h \
	source/lib/sysdep/arch.h \
	source/lib/config2.h \
	source/scriptinterface/Engine.h \
	source/scriptinterface/Context.cpp \
	source/renderer/backend/vulkan/Device.cpp \
	source/ps/GameSetup/GameSetup.cpp \
	source/ps/GameSetup/Paths.cpp \
	source/ps/VideoMode.cpp \
	source/ps/DllLoader.cpp \
	source/main.cpp \
	source/lib/sysdep/os/unix/unix.cpp \
	build/premake/premake5.lua \
	build/workspaces/update-workspaces.sh \
	libraries/build-macos-libs.sh \
	libraries/source/spidermonkey/build.sh
do
	if [ -f "$WORKSPACE_ROOT/$required_path" ]; then
		printf 'PASS: %s\n' "$required_path"
	else
		printf 'FAIL: %s is missing\n' "$required_path" >&2
		FAIL_COUNT=$((FAIL_COUNT + 1))
	fi
done

if [ "$FAIL_COUNT" -ne 0 ]; then
	echo "error: $FAIL_COUNT required upstream files are missing." >&2
	exit 1
fi
printf 'PASS: all required upstream source files are present\n'

FILE_COUNT=$(git ls-files | wc -l | tr -d ' ')
WORKSPACE_SIZE=$(du -sh "$WORKSPACE_ROOT" 2>/dev/null | awk '{print $1}')
printf 'file_count=%s\n' "$FILE_COUNT"
printf 'workspace_size=%s\n' "$WORKSPACE_SIZE"

printf 'PASS: upstream source workspace is ready for M3-B\n'
