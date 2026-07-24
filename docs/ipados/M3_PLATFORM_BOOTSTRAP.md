# M3 Platform Bootstrap

## The problem

The upstream 0 A.D. engine at revision `eae57d9aab66511a22a869192b7ec72feeaedc7a` classifies
every Apple Mach target (`__APPLE__`) as `OS_MACOSX` in `source/lib/sysdep/os.h:63-68`. There
is no `OS_IOS` definition. This means an iPadOS build would inherit macOS platform assumptions:
desktop frameworks (Cocoa, ApplicationServices), `fork`/`exec` code paths, `dlopen` plugin
loading, and desktop path logic — none of which are valid on iOS.

## Evidence from upstream source

| File | Lines | Finding |
| --- | --- | --- |
| `source/lib/sysdep/os.h` | 63-68 | `#elif defined(__APPLE__)` → `#define OS_MACOSX 1`; no iOS check |
| `source/main.cpp` | 117-119 | `OS_MACOSX` selects desktop Atlas helpers |
| `source/lib/sysdep/os/unix/unix.cpp` | 354-381 | `fork`/`execlp` for URL launching under Unix |
| `source/ps/DllLoader.cpp` | 117-197 | `dlopen`/`dlsym` plugin loading |
| `build/premake/premake5.lua` | 1228-1239 | Links Cocoa, ApplicationServices, CoreFoundation |

## Why macOS and iPadOS must not share a platform macro

| Concern | macOS | iPadOS |
| --- | --- | --- |
| UI framework | Cocoa/AppKit | UIKit |
| Process model | fork/exec allowed | No fork/exec; sandboxed |
| Dynamic loading | dlopen permitted | Prohibited by App Store policy |
| File system | User home directory | Sandboxed (bundle, App Support, Documents) |
| Audio | CoreAudio desktop | AVAudioSession with interruptions |
| Networking | Unrestricted | Requires entitlements; no background by default |
| GPU | MoltenVK dylib | Static MoltenVK only |

## The patch

`patches/upstream/0001-sysdep-detect-ios-platform.patch` will modify `source/lib/sysdep/os.h` to:

1. Include `<TargetConditionals.h>` inside the Apple Mach block.
2. Check `TARGET_OS_IPHONE` (which is 1 for both iOS device and iOS Simulator).
3. Define `OS_IOS 1` when `TARGET_OS_IPHONE` is true, `OS_MACOSX 1` otherwise.
4. Add `OS_IOS` to the `OS_UNIX` condition so POSIX code paths remain available.

The patch is intended to be deterministic: `git apply --check` must succeed before application,
and a second `git apply --check` after application must fail because the patch is already applied.

## TargetConditionals behavior

| Compiler target | `TARGET_OS_IPHONE` | `TARGET_OS_SIMULATOR` | `TARGET_OS_MAC` |
| --- | --- | --- | --- |
| macOS arm64 | 0 | 0 | 1 |
| iOS device arm64 | 1 | 0 | 0 |
| iOS Simulator arm64 | 1 | 1 | 0 |

`TARGET_OS_IPHONE` historically covers the entire iPhone-family platform, including iPadOS.
The simulator runs on a Mac host but compiles for the iOS target; host != target.

## Expected macro matrix after patch

| Platform | OS_IOS | OS_MACOSX | OS_UNIX | ARCH_ARM64 |
| --- | --- | --- | --- | --- |
| macOS arm64 | 0 | 1 | 1 | 1 |
| iPadOS device arm64 | 1 | 0 | 1 | 1 |
| iPad Simulator arm64 | 1 | 0 | 1 | 1 |

## Platform probe

`source/platform/probe/PlatformProbe.mm` is a minimal UIKit app that includes the upstream
`os.h` and `arch.h` headers and prints all platform macros to stdout and the unified log.
It is built by `build/ios/probe/CMakeLists.txt` against the patched upstream workspace.

## What M3-B shows

### Troubleshooting history
- The initial Python-based patcher (`0001-sysdep-detect-ios-platform.py`) failed because it searched for a synthetic fixture layout.
- The real upstream `os.h` at pinned commit `eae57d9aab66511a22a869192b7ec72feeaedc7a` contains a 63-line preamble (MIT copyright header, include guard, Windows/Linux/Android platform blocks) before line 64: `#if (defined(__APPLE__) && defined(__MACH__))`.
- The initial unified patch hunk `@@ -1,11 +1,16 @@` failed because `git apply` checked line 1 context.
- In run `30128482594`, diagnostic context capture extracted the exact real upstream `os.h` file structure.
- In run `30129740773`, the unified patch was regenerated against real upstream `os.h`, but the probe CMakeLists had an extra `build/` directory level resolution.

### Verified execution evidence (GitHub Actions Run `30129970396`)
- **Upstream preparation**: Cloned and checked out pinned commit `eae57d9aab66511a22a869192b7ec72feeaedc7a`.
- **Patch application**: `git apply --check` and `git apply` passed cleanly for `patches/upstream/0001-sysdep-detect-ios-platform.patch`.
- **Idempotency**: Double application check rejected second `git apply --check` as expected.
- **macOS classification**: Host test validated `OS_MACOSX=1`, `OS_IOS=0`, `OS_UNIX=1`.
- **`iphoneos` device probe**: CMake generated Xcode project; `xcodebuild` compiled and linked unsigned `arm64` binary cleanly.
- **iPad Simulator probe**: CMake generated Xcode project; `xcodebuild` built `arm64` bundle; `simctl install` and `simctl launch` succeeded on iPad Simulator (`E1283D47-9830-4DDE-B6D3-C216A12ACAC2`).
- **Runtime macro values**: Simulator unified log verified:
  - `OS_IOS=1`
  - `OS_MACOSX=0`
  - `OS_UNIX=1`
  - `ARCH_ARM64=1`

## What M3-B did not prove

- Physical iPad device execution (remains `NOT TESTED / DEFERRED`).
- Core engine runtime initialization (M3-C).
- SpiderMonkey, SDL, MoltenVK, or renderer integration.
- Full engine compilation.
- M2-Device validation.
