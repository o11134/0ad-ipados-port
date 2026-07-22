# iPadOS feasibility audit

## Decision

**CONDITIONAL GO** for a native ARM64 iPadOS proof of concept. The engine already has AArch64 code,
an SDL abstraction, and a Vulkan backend whose minimum extension set is narrow. SDL 2 and MoltenVK
have maintained iOS routes. None of that proves this revision works on iPadOS: four hard gates remain
before engine integration can be called feasible.

1. Build the exact Wildfire Games SpiderMonkey 128.13.0+wfg5 source for `arm64-apple-ios` with JIT,
   executable-memory allocation, and runtime native-code generation disabled at build time.
2. Link SDL and MoltenVK in an Apple-compliant static form and pass a physical-device clear/present
   probe.
3. Introduce a distinct iOS platform identity instead of inheriting `OS_MACOSX`, then exclude
   desktop frameworks, `fork`/`exec`, unrestricted `dlopen`, and unsupported asynchronous I/O.
4. Stage official data, precompiled SPIR-V, DAE conversions, and texture conversions offline without
   writing to the app bundle or downloading executable components at runtime.

Failure of gate 1 is a valid **NO-GO for the current engine/runtime combination**, not permission to
silently replace SpiderMonkey or use JIT. Failure of the Vulkan probe moves evaluation to a narrow
Metal backend only after the MoltenVK incompatibility is recorded.

## Required audit conclusion index

| # | Required conclusion | Evidence-backed result |
| --- | --- | --- |
| 1 | Repository revision | Official Gitea revision `eae57d9aab66511a22a869192b7ec72feeaedc7a`; details below. |
| 2 | Build system | Premake 5 pin/generators/output are cited under **Current build system**. |
| 3 | Relevant directories | Concrete entry/platform/renderer/script/data/input/audio/network/test paths are mapped below. |
| 4 | Dependency inventory | Exact repo pins and roles are in `DEPENDENCIES.md` and `libraries/build-macos-libs.sh:23-52`. |
| 5 | Platform assumptions | `OS_MACOSX`, framework, AIO, fork/exec, dlopen, dylib, and path evidence is tabulated below. |
| 6 | Existing iOS-capable dependencies | SDL 2.24.0 and MoltenVK 1.3.0 have pinned upstream iOS documentation linked below; no local product exists. |
| 7 | Configuration changes | Separate UIKit SDL, static MoltenVK, iOS target triples, offline/audio/Atlas flags, and target-keyed outputs are required. |
| 8 | Required patches | Apple OS identity, Vulkan portability extensions, lifecycle pause, safe paths, and touch-ID mapping are identified with symbols below. |
| 9 | Suspected blockers | The four hard gates at the start of this document are the ranked blockers. |
| 10 | SpiderMonkey/JIT | Version, current mozconfig, unconditional runtime enables, and missing-source proof gap are cited below. |
| 11 | Graphics backend | Vulkan 1.1, SDL surface, extensions, queues, formats, features, swapchain, and SPIR-V evidence is cited below and expanded in `GRAPHICS.md`. |
| 12 | File-system sandbox | Current `Paths`/VFS/save behavior and proposed bundle/Application Support/Documents/Caches split are cited below. |
| 13 | Application lifecycle | Desktop event/focus loop and missing iOS app events are cited below; M2 bridge remains unverified. |
| 14 | Porting stages | M1–M10 estimates, proofs, and rollback boundaries are tabulated below. |
| 15 | First rendering strategy | Existing Vulkan through static MoltenVK, starting with a shader-free G0 probe. |
| 16 | First build strategy | Isolated CMake/Xcode shell and probes, retaining desktop Premake unchanged initially. |
| 17 | Exact evidence | Conclusions use audited repository paths/lines/symbols; external capability claims link the matching upstream pin. |
| 18 | Decision | **CONDITIONAL GO**, subject to the four hard gates; no build/device success is claimed. |

## Audited repository

- Path: repository root of this checkout. The absolute session path is reported to the operator but
  intentionally not persisted in tracked project files.
- Official remote: `https://gitea.wildfiregames.com/0ad/0ad.git`.
- Revision: `eae57d9aab66511a22a869192b7ec72feeaedc7a`.
- Upstream branch: `main`; work branch: `feature/ipados-native-port`.
- Audit date: 2026-07-22.
- Checkout: shallow, blob-filtered, sparse checkout of `.gitea`, `build`, `docs`, `libraries`, and
  `source`. Git reports 28,297 tracked paths under `binaries`; 15,718 are LFS entries. Those objects
  are not hydrated and were not treated as tested data.

`README.md` points build documentation to the official Gitea wiki. `LICENSE.md` identifies the
source as GPL-2.0-or-later, binary data as GPL-2-or-later, and art/audio as principally CC BY-SA 3.0
with per-file/per-map exceptions. `libraries/LICENSE.txt` records third-party license families.

## Current build system and entry path

Premake 5 is the engine workspace generator. `libraries/source/premake-core/build.sh` pins commit
`55fc4b2deac045ca06dc23d98426423356c507c1+wfg0`; `build/premake/premake5.lua:1-8` requires
Premake 5.0.0-beta5 or newer. `build/workspaces/update-workspaces.sh:43-53` generates GNU Make and,
on macOS, an Xcode 4 workspace. Output is placed in `binaries/system` by
`build/premake/premake5.lua:179-217`.

The desktop executable begins at `source/main.cpp:790-795`. `RunGameOrAtlas` calls `InitVfs`, `Init`,
and `InitGraphics`, then owns the frame loop at `source/main.cpp:517-775`. The relevant initialization
definitions are in `source/ps/GameSetup/GameSetup.cpp:191-223` (`InitVfs`), `:283-306` (`InitSDL`),
and `:593-657` (`InitGraphics`). The existing macOS project is deliberately a `ConsoleApp` because
the generated Xcode bundle lacks the required resources and plist
(`build/premake/premake5.lua:519-530`). That is why the first iPad target is an isolated CMake/Xcode
application shell instead of a broad Premake rewrite.

## Relevant source map

| Area | Evidence and role |
| --- | --- |
| Entry/lifecycle | `source/main.cpp`; desktop event loop and engine bootstrap |
| Platform detection | `source/lib/sysdep/os.h`, `arch.h`, `config2.h` |
| OS implementations | `source/lib/sysdep/os/{unix,osx}`, `source/lib/sysdep/arch/aarch64` |
| Window/SDL | `source/ps/VideoMode.cpp`, `source/ps/GameSetup/GameSetup.cpp` |
| Rendering | `source/renderer/backend/{vulkan,gl,dummy}` |
| JavaScript | `source/scriptinterface/{Engine,Context,Interface}.*` |
| Data and paths | `source/ps/GameSetup/Paths.cpp`, `source/lib/file/vfs`, `source/ps/Filesystem.*` |
| Mods/archives | `source/ps/Mod.*`, `source/ps/ArchiveBuilder.*`, `source/graphics/ColladaManager.cpp` |
| Input | `source/ps/TouchInput.*`, `source/ps/Input.*`, `source/graphics/GameView.cpp` |
| Audio | `source/soundmanager`, OpenAL/Vorbis declarations in Premake |
| Networking | `source/network`, ENet/gloox/curl/miniupnpc declarations in Premake |
| Tests | `source/*/tests`, CxxTest target in `build/premake/premake5.lua:1495-1669` |

## Dependency conclusions

Exact versions and classifications are in `DEPENDENCIES.md`. Key evidence:

- `libraries/build-macos-libs.sh:23-52` pins SDL 2.24.0, MoltenVK 1.3.0, OpenAL Soft 1.24.2,
  ICU 69.1, Boost 1.81.0, and the remaining macOS libraries.
- The existing SDL recipe is Cocoa/macOS-specific (`libraries/build-macos-libs.sh:379-423`). The
  matching upstream pin documents a UIKit/iOS target in
  [SDL 2.24.0 README-iOS](https://github.com/libsdl-org/SDL/blob/release-2.24.0/docs/README-ios.md),
  but it still requires a separate local proof build.
- The MoltenVK recipe explicitly builds `MoltenVK Package (macOS only)` and installs a dylib
  (`libraries/build-macos-libs.sh:1186-1229`). The matching
  [MoltenVK v1.3.0 source/tag](https://github.com/KhronosGroup/MoltenVK/tree/v1.3.0) contains the
  Apple multi-platform package; iPadOS requires its pinned static XCFramework/library and device proof.
- SpiderMonkey uses a macOS `aarch64-apple-darwin` host and existing output stamps are not keyed by
  target SDK, architecture, compiler, or JIT mode.
- FCollada and NVTT are runtime conversion dependencies on desktop. The first iPad data package
  should perform those conversions on the Mac build host and omit Atlas/NVTT/Collada runtime code.
- `download_lib` only calls `curl` without a hash check (`libraries/build-macos-libs.sh:140-146`), and
  HTTP sources include curl/iconv/libpng/Ogg/Vorbis/ENet/miniupnpc at
  `libraries/build-macos-libs.sh:236,300,545,632,670,994,1035`. A new iOS source manifest must pin
  official HTTPS URLs and SHA-256 hashes before dependency downloading is automated.

Dependencies with a documented upstream iOS route: SDL 2.24.0 and MoltenVK 1.3.0. Portable C/C++
libraries such as zlib, libpng, FreeType, fmt, libxml2, Boost, ICU, libsodium, and ENet are plausible
static builds, but this repository contains no iOS configuration proving them. OpenAL Soft,
SpiderMonkey/Rust, curl/TLS, iconv, and any lobby stack require target-specific configuration and
device validation. wxWidgets/Atlas, NVTT, FCollada tools, CxxTest, Premake, and shader compilers are
host-only for the first app.

## Desktop-only and unsafe assumptions

| Evidence | Finding | Required action |
| --- | --- | --- |
| `source/lib/sysdep/os.h:63-68` | Every Apple Mach target becomes `OS_MACOSX`; no `OS_IOS` exists. | Detect iOS first with public Apple target macros and keep macOS behavior unchanged. |
| `build/premake/premake5.lua:1035-1045` | sysdep directories have Linux, Windows, macOS, BSD, but no iOS entry. | Add iOS source groups only to the isolated target initially. |
| `build/premake/premake5.lua:1228-1239` | Main target links Cocoa, ApplicationServices, CoreFoundation. | Use UIKit/Foundation/QuartzCore and only required public frameworks. |
| `source/lib/sysdep/os/unix/unix.cpp:354-381` | URL launching uses `fork` and `execlp`. | Bridge to an approved UIKit URL API later or report unsupported. |
| `source/ps/DllLoader.cpp:117-197` | Native plugins use `dlopen`, `dlsym`, and `dlclose`. | Exclude runtime Collada/Atlas; link approved components statically. |
| `source/ps/VideoMode.cpp:427-445` | macOS loads `libMoltenVK.dylib` through SDL. | Link MoltenVK statically and pass no dynamic library path on iOS. |
| `source/lib/config2.h:55-63` | AIO is enabled on non-Linux/OpenBSD targets. | Disable it until the iOS implementation is audited. |
| `source/ps/GameSetup/Paths.cpp:107-225` | Only desktop mac bundle/support/cache logic exists. | Map bundle, Application Support, Documents, Caches, and tmp explicitly. |
| `source/main.cpp:117-119` | `OS_MACOSX` selects desktop Atlas helpers. | Ensure iOS never takes the macOS branch. |

## SpiderMonkey and JIT risk

`libraries/source/spidermonkey/build.sh:8-13` pins `128.13.0+wfg5`; `source/scriptinterface/Engine.h:27-32`
rejects another major version. The current `libraries/source/spidermonkey/mozconfig` enables a shared
JS build but contains no JIT-disable option. More importantly, `source/scriptinterface/Context.cpp:141`
enables off-thread Ion and `:148-149` enables Ion and Baseline at runtime.

The Mozilla source archive is not present. Therefore the exact supported configure symbols for this
specific WFG source, and the resulting `ExecutableAllocator`/`mmap`/`mprotect` behavior, cannot be
proven from this checkout. A runtime `JSJITCOMPILER_* = 0` change alone is insufficient: the build
must exclude native code generation and executable memory, then an isolated test must run on a
physical iPad and the linked image must be inspected. `SPIDERMONKEY.md` defines the proof protocol.

## Graphics assessment

The renderer already has Vulkan, OpenGL, and dummy backends under `source/renderer/backend`.
`source/ps/VideoMode.cpp:336-340` tries Vulkan, then GL, then dummy. The Vulkan device requests API
1.1 (`source/renderer/backend/vulkan/Device.cpp:226-234`), obtains instance extensions and its surface
from SDL (`:82-94`, `:339-340`), and requires only `VK_KHR_swapchain` at the device level (`:342-345`).

Device selection requires a graphics/present queue, at least four bound descriptor sets, a surface,
and an RGBA8/BGRA8 UNORM sRGB-nonlinear format
(`source/renderer/backend/vulkan/DeviceSelection.cpp:300-335`). Optional feature detection already
exists, and descriptor indexing is disabled on Apple/macOS due a MoltenVK combined-sampler issue
(`source/renderer/backend/vulkan/Device.cpp:440-460`). Swapchain code intersects its desired usage
with surface capabilities and defaults to FIFO (`source/renderer/backend/vulkan/SwapChain.cpp:112-170`).

The engine format list includes BC1/2/3 (`source/renderer/backend/Format.h:27-70`). Unsupported S3TC
can fall back to software DDS decompression in `source/graphics/TextureManager.cpp:63-97`; this is a
memory/performance risk rather than an immediate correctness blocker. Compute shaders and GPU
skinning exist, so the first preset must disable GPU skinning and expensive effects. Precompiled
SPIR-V is not tracked; `source/tools/spirv/compile.py:127-158` compiles Vulkan 1.1/GLSL 450 stages and
`source/tools/spirv/get-nightly-shaders.sh` fetches official nightly output. Runtime downloading is
not acceptable, so the build must stage verified output.

Recommendation: existing Vulkan through a statically linked MoltenVK is strategy A. Prove G0
clear/present and G1 diagnostic geometry before loading engine assets. Do not begin a Metal renderer
rewrite unless the exact failed Vulkan feature/surface/shader operation is recorded.

## File-system and game-data assessment

`source/ps/GameSetup/Paths.cpp:67-225` has Android, Windows, macOS, and Unix path policies but no iOS
sandbox mapping. `source/ps/GameSetup/GameSetup.cpp:209-223` mounts cache/config/screenshots/saves and
localization. iPadOS must treat bundle resources as read-only, Application Support as internal
persistent state, Documents as user saves/replays, Library/Caches as discardable, and `tmp` as
short-lived.

Runtime conversion currently uses `DllLoader("Collada")` in
`source/graphics/ColladaManager.cpp:68-218`; `source/ps/ArchiveBuilder.cpp:123+` provides a host archive
conversion route. Use host-side conversion. The checked-out data is incomplete: no map, menu, font,
texture, sound, shader, or localization load has been tested.

Two pre-existing correctness/security risks need tests before writable user data is exposed:

- non-Windows `Path` conversion rejects wide characters outside its narrow range
  (`source/lib/path.cpp:102-110`, `source/lib/path.h:169-190`), so Arabic file names are unproven;
- save names reach VFS operations without a demonstrated `..` rejection
  (`source/ps/SavedGame.cpp:81-87,233-238,333-349`; `source/lib/file/vfs/vfs_lookup.cpp:90-131`).

Current saves use a fixed `cache/temp.0adsave` and a truncate/create destination path rather than an
audited atomic replace (`source/ps/SavedGame.cpp:81-164`). These are post-bootstrap gates, not reasons
to weaken sandbox restrictions.

## Application lifecycle and input

The desktop handler at `source/main.cpp:191-239` handles quit/drop/hotkeys, not SDL iOS app lifecycle
events. Frame update suppression uses focus and the configurable pause flag
(`source/main.cpp:389-453`); iPadOS background suspension must be unconditional and synchronously
pause simulation/audio before returning from the lifecycle callback. `source/ps/Globals.cpp:53-75`
tracks ordinary window focus/minimize only.

The existing touch implementation is an Android mouse/camera prototype
(`source/ps/TouchInput.cpp:43-67`). It casts an arbitrary 64-bit `SDL_FingerID` to an index for
two-element arrays (`TouchInput.cpp:266-286`, `TouchInput.h:62-70`), which is an out-of-bounds risk.
It is disabled on iOS and does not model Pencil, palm rejection, cancellation, double-tap, selection
drag, or command modes. It must not simply be enabled for `OS_IOS`.

The reviewed shell source establishes a narrow `IOSPlatformBridge`, displays app/build/CPU/OS,
screen/view, scale, safe-area, scene/lifecycle, and memory diagnostics, and includes a small
Application Support write/read-back probe. It logs UIKit lifecycle/safe-area/size events, but it has
not been built or run and is not connected to the engine. It intentionally performs no background
or network work.

## Audio and networking scope

The desktop audio route uses OpenAL Soft and Vorbis; no `AVAudioSession` or iOS interruption/route
bridge exists. The initial dependency-free shell has no audio. Offline MVP builds should disable
lobby, miniupnpc, and DAP targets using existing Premake concepts and preserve network source rather
than delete it. `NETWORKING_FUTURE.md` records the deferred review.

## Estimated stages and rollback boundaries

| Stage | Proof | Estimate after a prepared Mac exists | Rollback boundary |
| --- | --- | --- | --- |
| M1 | Clean supported macOS engine/test baseline | 1–3 engineer days plus dependency build | Documentation only |
| M2 | Unsigned CI compile and simulator smoke; signed physical-iPad validation remains separate | 0.5–1 day after CI access, plus the later device route | Isolated `build/ios`, `scripts/ios`, `source/platform/ios` |
| M4 probe | JITless SpiderMonkey test on device | 3–10 days; highest uncertainty | Separate dependency output and validation target |
| M5 | SDL + MoltenVK clear/present | 2–5 days | Graphics probe target |
| M3 core | OS identity, paths, logging, clean shutdown | 3–7 days | iOS platform source group |
| M6 | Menu with bundled fonts/textures/scripts | 1–3 weeks | Data manifest and engine link set |
| M7–M8 | Small map and basic touch gameplay | 3–8 weeks | Feature flags and touch state machine |
| M9–M10 | Persistence and 20-minute device proof | 2–6 weeks | Save format unchanged; iOS path layer isolated |

These are engineering estimates, not delivery claims. Shader/data size, SpiderMonkey patches, and
MoltenVK feature gaps can change them materially.

## Recommended first build and render strategy

Keep upstream Premake untouched while the app shell and probes stabilize. For the current M2-CI and
M2-Simulator route, use CMake's Xcode generator only for the isolated iPad targets with `arm64`,
`CMAKE_SYSTEM_NAME=iOS`, deployment target 17.0, `CODE_SIGNING_ALLOWED=NO`, and no Development Team.
Automatic signing and a locally selected team are deferred to a separately authorized M2-Device run.
Build every target library into SDK-specific roots; never reuse macOS outputs or unqualified stamps.
Once source group requirements are known, either teach Premake about a real iOS platform or generate
a reviewed source manifest for CMake—do not maintain two untracked hand-written engine file lists.

The immediate rendering route is SDL UIKit window/surface plus Vulkan 1.1 through static MoltenVK.
The sequence is window/view, clear/present, triangle, texture/font, menu, terrain, then units. Each
step must be proven on a physical iPad and retain the previous diagnostic target as its rollback point.
