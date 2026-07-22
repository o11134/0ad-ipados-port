#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
BUILD_DIRECTORY=${IPADOS_SIMULATOR_BUILD_DIR:-"$REPOSITORY_ROOT/build/ios/out/iphonesimulator"}
CONFIGURATION=${CONFIGURATION:-Debug}

sh "$SCRIPT_DIR/generate-xcode-project.sh" iphonesimulator "$BUILD_DIRECTORY"
cmake --build "$BUILD_DIRECTORY" --config "$CONFIGURATION" --target PyrogenesisIPadShell

echo "simulator app output is under: $BUILD_DIRECTORY/$CONFIGURATION-iphonesimulator/"
echo "this is simulator-only output and does not satisfy physical-device acceptance."
