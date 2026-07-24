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

## What M3-B currently shows

- The pinned upstream revision's `os.h` does not match the old Python regex-based patcher.
- The real upstream context captured in run `30057265615` shows:
  - `64:#if (defined(__APPLE__) && defined(__MACH__))`
  - `65:# define OS_MACOSX 1`
  - `67:# define OS_MACOSX 0`
  - `110:#if OS_LINUX || OS_MACOSX || OS_BSD || OS_SOLARIS`
  - `111:# undef OS_UNIX`
  - `112:# define OS_UNIX 1`
- The earlier Python patcher failed with `error: could not locate the __APPLE__ / OS_MACOSX block`.
- No iPhoneOS compile, simulator compile, or simulator launch evidence exists yet for the unified patch.

## What M3-B did not prove

- Engine runtime initialization.
- SpiderMonkey, SDL, MoltenVK, or renderer integration.
- Physical device behavior.
- Full engine compilation.
- M2-Device validation.
