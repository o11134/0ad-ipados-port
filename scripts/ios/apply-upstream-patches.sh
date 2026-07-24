#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
PATCHES_DIR="$REPOSITORY_ROOT/patches/upstream"

if [ "$#" -ne 1 ]; then
	echo "usage: $0 <upstream-workspace-root>" >&2
	exit 2
fi

WORKSPACE_ROOT=$1

if [ ! -d "$WORKSPACE_ROOT/.git" ]; then
	echo "error: $WORKSPACE_ROOT is not a Git workspace." >&2
	exit 1
fi

UPSTREAM_REVISION_FILE="$REPOSITORY_ROOT/UPSTREAM_REVISION"
EXPECTED_COMMIT=$(sed -n 's/^commit=//p' "$UPSTREAM_REVISION_FILE")
ACTUAL_HEAD=$(git -C "$WORKSPACE_ROOT" rev-parse HEAD)

if [ "$ACTUAL_HEAD" != "$EXPECTED_COMMIT" ]; then
	echo "error: upstream HEAD mismatch; refusing to patch." >&2
	printf 'expected=%s\n' "$EXPECTED_COMMIT" >&2
	printf 'actual=%s\n' "$ACTUAL_HEAD" >&2
	exit 1
fi
printf 'PASS: upstream HEAD matches pinned commit %s\n' "$EXPECTED_COMMIT"

APPLIED_COUNT=0
for patch_file in "$PATCHES_DIR"/*.patch; do
	[ -f "$patch_file" ] || continue
	patch_name=$(basename -- "$patch_file")
	printf 'applying: %s\n' "$patch_name"
	if ! git -C "$WORKSPACE_ROOT" apply --check "$patch_file"; then
		echo "error: patch does not apply cleanly: $patch_name" >&2
		exit 1
	fi
	if ! git -C "$WORKSPACE_ROOT" apply "$patch_file"; then
		echo "error: patch application failed: $patch_name" >&2
		exit 1
	fi
	APPLIED_COUNT=$((APPLIED_COUNT + 1))
done

if [ "$APPLIED_COUNT" -eq 0 ]; then
	printf 'NOTE: no patches found in %s\n' "$PATCHES_DIR"
else
	printf 'PASS: applied %s patch(es) successfully\n' "$APPLIED_COUNT"
fi
