#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SDK=${1:-iphoneos}
BUILD_DIRECTORY=${2:-"$REPOSITORY_ROOT/build/ios/out/$SDK"}
DEPLOYMENT_TARGET=${IPADOS_DEPLOYMENT_TARGET:-17.0}
BUNDLE_IDENTIFIER=${IPADOS_BUNDLE_IDENTIFIER:-org.example.pyrogenesis.ipadshell}
PRODUCT_NAME=${IPADOS_PRODUCT_NAME:-Pyrogenesis iPad Shell}

case "$SDK" in
	iphoneos|iphonesimulator)
		;;
	*)
		echo "error: SDK must be iphoneos or iphonesimulator" >&2
		exit 2
		;;
esac

if [ "$(uname -s 2>/dev/null || printf 'unknown')" != "Darwin" ]; then
	echo "error: Xcode project generation requires an Apple Silicon Mac." >&2
	echo "error: follow docs/ipados/MAC_HANDOFF.md; no iPadOS build was attempted." >&2
	exit 1
fi

if ! sh "$SCRIPT_DIR/verify-mac-environment.sh"; then
	echo "error: Mac environment verification failed; generation was not attempted." >&2
	exit 1
fi

set -- cmake -S "$REPOSITORY_ROOT/build/ios" -B "$BUILD_DIRECTORY" -G Xcode \
	-DCMAKE_SYSTEM_NAME=iOS \
	-DCMAKE_OSX_SYSROOT="$SDK" \
	-DIPADOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
	-DIPADOS_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
	-DIPADOS_PRODUCT_NAME="$PRODUCT_NAME"

if [ -n "${IPADOS_DEVELOPMENT_TEAM:-}" ]; then
	set -- "$@" -DIPADOS_DEVELOPMENT_TEAM="$IPADOS_DEVELOPMENT_TEAM"
fi

"$@"
echo "generated: $BUILD_DIRECTORY/PyrogenesisIPadShell.xcodeproj"
