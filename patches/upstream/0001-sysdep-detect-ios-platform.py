#!/usr/bin/env python3
"""Patch upstream source/lib/sysdep/os.h to detect iOS/iPadOS as a distinct platform.

The unpatched 0 A.D. os.h classifies every Apple Mach target (__APPLE__) as
OS_MACOSX.  This is incorrect for iOS/iPadOS builds, where TARGET_OS_IPHONE
is 1.  The patch inserts a TargetConditionals.h check so that:

  - iOS device and iOS Simulator  ->  OS_IOS = 1,  OS_MACOSX = 0
  - macOS                         ->  OS_MACOSX = 1,  OS_IOS = 0

OS_UNIX is extended to include OS_IOS so that POSIX code paths remain
available on iOS.

Usage:
    python3 0001-sysdep-detect-ios-platform.py <upstream-workspace-root>

The script is idempotent: running it on an already-patched file is a no-op
that prints a diagnostic and exits 0.
"""

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <upstream-workspace-root>", file=sys.stderr)
        return 2

    workspace = Path(sys.argv[1])
    os_h = workspace / "source" / "lib" / "sysdep" / "os.h"
    if not os_h.is_file():
        print(f"error: {os_h} not found", file=sys.stderr)
        return 1

    text = os_h.read_text(encoding="utf-8")

    if "OS_IOS" in text:
        print(f"SKIP: {os_h} already contains OS_IOS; patch appears applied")
        return 0

    apple_pattern = re.compile(
        r"(#\s*elif\s+defined\s*\(\s*__APPLE__\s*\)\s*\n)"
        r"((?:[ \t]*#[ \t]*define[ \t]+OS_MACOSX[ \t]+1[ \t]*\n))",
        re.MULTILINE,
    )
    match = apple_pattern.search(text)
    if not match:
        apple_pattern_alt = re.compile(
            r"(#\s*if\s+defined\s*\(\s*__APPLE__\s*\)\s*\n)"
            r"((?:[ \t]*#[ \t]*define[ \t]+OS_MACOSX[ \t]+1[ \t]*\n))",
            re.MULTILINE,
        )
        match = apple_pattern_alt.search(text)

    if not match:
        print(f"error: could not locate the __APPLE__ / OS_MACOSX block in {os_h}",
              file=sys.stderr)
        return 1

    indent = re.match(r"[ \t]*", match.group(2)).group(0)
    replacement = (
        match.group(1)
        + f"{indent}#include <TargetConditionals.h>\n"
        + f"{indent}#if TARGET_OS_IPHONE\n"
        + f"{indent}#define OS_IOS 1\n"
        + f"{indent}#else\n"
        + f"{indent}#define OS_MACOSX 1\n"
        + f"{indent}#endif\n"
    )
    text = text[:match.start()] + replacement + text[match.end():]

    unix_pattern = re.compile(
        r"(#\s*if\s+(?:defined\s*\(\s*OS_LINUX\s*\)\s*\|\|\s*)?"
        r"(?:defined\s*\(\s*OS_MACOSX\s*\)|OS_MACOSX)"
        r"(?:\s*\|\|\s*(?:defined\s*\(\s*OS_BSD\s*\)|OS_BSD))?)"
        r"(\s*\n[ \t]*#[ \t]*define[ \t]+OS_UNIX[ \t]+1)",
        re.MULTILINE,
    )
    unix_match = unix_pattern.search(text)
    if unix_match:
        condition = unix_match.group(1)
        if "OS_IOS" not in condition:
            new_condition = condition.rstrip() + " || defined(OS_IOS)"
            text = (text[:unix_match.start(1)]
                    + new_condition
                    + text[unix_match.end(1):])
            print("PASS: added OS_IOS to OS_UNIX condition")
        else:
            print("SKIP: OS_UNIX already includes OS_IOS")
    else:
        print("WARN: could not locate OS_UNIX condition; manual review needed",
              file=sys.stderr)

    os_h.write_text(text, encoding="utf-8")
    print(f"PASS: patched {os_h}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
