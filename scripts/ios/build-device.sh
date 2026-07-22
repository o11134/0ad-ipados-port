#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
BUILD_DIRECTORY=${IPADOS_DEVICE_BUILD_DIR:-"$REPOSITORY_ROOT/build/ios/out/iphoneos"}
CONFIGURATION=${CONFIGURATION:-Debug}

if [ "$(uname -s 2>/dev/null || printf 'unknown')" != "Darwin" ]; then
	echo "error: a signed device build requires an Apple Silicon Mac with Xcode." >&2
	echo "error: follow docs/ipados/MAC_HANDOFF.md; no build was attempted." >&2
	exit 1
fi

if [ -z "${IPADOS_DEVELOPMENT_TEAM:-}" ]; then
	echo "error: set IPADOS_DEVELOPMENT_TEAM in the local shell for a signed command-line device build." >&2
	echo "error: alternatively, generate the project and select a Team locally in Xcode." >&2
	exit 2
fi

if [ "${IPADOS_BUNDLE_IDENTIFIER:-org.example.pyrogenesis.ipadshell}" = "org.example.pyrogenesis.ipadshell" ]; then
	echo "error: set a unique local IPADOS_BUNDLE_IDENTIFIER for device signing." >&2
	exit 2
fi

sh "$SCRIPT_DIR/generate-xcode-project.sh" iphoneos "$BUILD_DIRECTORY"
if [ "${IPADOS_ALLOW_PROVISIONING_UPDATES:-0}" = "1" ]; then
	cmake --build "$BUILD_DIRECTORY" --config "$CONFIGURATION" \
		--target PyrogenesisIPadShell -- -allowProvisioningUpdates
else
	cmake --build "$BUILD_DIRECTORY" --config "$CONFIGURATION" --target PyrogenesisIPadShell
fi

echo "device-target app output is under: $BUILD_DIRECTORY/$CONFIGURATION-iphoneos/"
echo "this build output is not proof of installation or execution on a physical iPad."
