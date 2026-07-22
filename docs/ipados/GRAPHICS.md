# iPadOS graphics assessment

## Decision

**CONDITIONAL GO** for the existing Vulkan renderer through a statically linked MoltenVK. There is no
Metal backend, and the Premake GLES option is explicitly described as non-working
(`build/premake/premake5.lua:42-45`). A Metal rewrite is not justified before a focused MoltenVK
probe records an actual incompatibility.

No graphics target has been built or run. The M2 UIKit shell deliberately links neither SDL nor
MoltenVK.

Strategy order assessment:

1. **A — Vulkan through MoltenVK:** selected for the first probe because both the renderer and pinned
   translation dependency already exist in this revision.
2. **B — another maintained Apple translation layer:** no second layer, version pin, build recipe, or
   surface integration is present under `build`, `libraries`, or `source`. Adding an external layer
   would create a new dependency/link/shader compatibility track; evaluate one only after recording a
   MoltenVK-specific blocker and obtaining approval for the exact candidate.
3. **C — narrow native Metal backend:** technically possible but no current `Backend::METAL` exists;
   it is larger than the G0 proof and remains contingency C.
4. **D — OpenGL ES diagnostic:** the existing option is marked non-working and requests an old ES2
   path, so it is not a reliable fallback.

## Existing backend contract

- Backends are GL, Vulkan, and Dummy (`source/renderer/backend/Backend.h:27-32`).
- `source/ps/VideoMode.cpp:334-340` selects Vulkan only for `rendererbackend=vulkan`; failure falls
  through Vulkan, GL, then Dummy at `:86-102`.
- SDL 2.24.0 is pinned at `libraries/build-macos-libs.sh:27`; Vulkan code requires SDL 2.0.6 or newer
  (`source/renderer/backend/vulkan/Device.cpp:182-190`). The current recipe is static Cocoa/macOS,
  not UIKit (`libraries/build-macos-libs.sh:379-423`).
- MoltenVK 1.3.0 is pinned, but `libraries/build-macos-libs.sh:1185-1229` builds the macOS-only scheme
  and installs `libMoltenVK.dylib`. iPadOS needs a verified static device/simulator product.

The matching SDL pin documents UIKit, lifecycle events, high-DPI drawable sizing, indirect mouse
input, sandbox behavior, and static/XCFramework linkage in
[SDL 2.24.0 README-iOS](https://github.com/libsdl-org/SDL/blob/release-2.24.0/docs/README-ios.md).
The matching [MoltenVK v1.3.0 source/tag](https://github.com/KhronosGroup/MoltenVK/tree/v1.3.0)
contains its Apple package and runtime documentation. Those upstream capabilities do not substitute
for building and testing these exact pins locally.

## Vulkan requirements found

| Contract | Evidence | iPad/MoltenVK implication |
| --- | --- | --- |
| API version | Vulkan 1.1 at `Device.cpp:226-234` | Plausible; prove against pinned MoltenVK/device. |
| Instance extensions | Supplied by `SDL_Vulkan_GetInstanceExtensions`, `Device.cpp:82-95` | Must include the SDL UIKit metal-surface route. |
| Surface | `SDL_Vulkan_CreateSurface`, `Device.cpp:339-340` | Requires real UIKit SDL window and drawable-resize tests. |
| Required device extension | Only `VK_KHR_swapchain`, `Device.cpp:342-345` | Add portability subset conditionally when advertised. |
| Debug features | validation/debug utils optional, `Device.cpp:247-296` | Keep optional; do not require layers on device. |
| Queues | One queue family must support graphics and present, `DeviceSelection.cpp:229-270` | Probe actual Apple GPU result. |
| Descriptor sets | At least four bound sets, `DeviceSelection.cpp:300-315` | Log limit before accepting device. |
| Surface formats | RGBA8/BGRA8 UNORM + sRGB nonlinear, `DeviceSelection.cpp:329-335` | Verify exact surface list. |
| Frames in flight | Three, `source/renderer/backend/vulkan/Device.h:64` | Start unchanged, measure latency/memory. |
| Present mode | FIFO default; optional immediate without vsync, `SwapChain.cpp:112-129` | Force FIFO for initial proof. |
| Swapchain usage | Intersects color/transfer/storage with supported flags, `SwapChain.cpp:147-170` | Existing feature detection is useful. |
| Depth | D24S8 or D32S8, `SwapChain.cpp:228-236` | Confirm chosen format on device. |
| Acquire | Infinite wait, `SwapChain.cpp:410-431` | Never acquire while backgrounded; stop frame callback first. |
| Resize/result | OUT_OF_DATE invalidates; SUBOPTIMAL continues, `SwapChain.cpp:420-431,484-498` | Explicit drawable/foreground recreation tests required. |

### Synchronization and render-pass usage

The renderer uses ordinary binary semaphores and fences; no timeline-semaphore requirement was found.
`source/renderer/backend/vulkan/SubmitScheduler.cpp:46-58` creates one fence per frame in flight,
`:82-98` waits/resets with an infinite timeout, and `:114-131` submits command buffers with queued
wait/signal semaphores. `source/renderer/backend/vulkan/SwapChain.cpp:253-281` creates acquire and
submit semaphores, `:341-365` waits for reusable frame work and queues the acquire semaphore at
`COLOR_ATTACHMENT_OUTPUT`, and `:368-385` signals before `vkQueuePresentKHR`. This synchronization
model is plausible on MoltenVK but makes lifecycle fencing mandatory; background entry cannot race an
infinite acquire/fence wait.

Render passes are cached from color/depth formats, sample count, and load/store operations
(`source/renderer/backend/vulkan/RenderPassManager.cpp:69-130`). Color and depth/stencil attachments
use explicit attachment-optimal layouts and mapped load/store ops at `:137-172`. G0 needs only the
existing backbuffer clear/store pass; G1 adds fixed pipeline/shader state. No Apple-specific render
pass extension is required by the audited code.

### Portability extensions

The current engine does not conditionally enable `VK_KHR_portability_subset`, although applications
must enable it when a device advertises it. `Device.cpp:342-345,462-520` only requests swapchain and
feature extensions. GLAD lists portability subset but the generator input lacks
`VK_KHR_portability_enumeration` (`source/third_party/glad/extensions/vulkan.txt:9`), while instance
creation leaves flags zero (`Device.cpp:275-298`).

Smallest compatibility patch for the later graphics probe:

1. regenerate GLAD with `VK_KHR_portability_enumeration` declarations;
2. enable that instance extension and `VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR` when
   advertised/needed by the loader;
3. enable `VK_KHR_portability_subset` when the selected device advertises it;
4. leave non-Apple behavior and required-extension failures unchanged.

Direct-linked MoltenVK may enumerate without the loader flag, so log both direct and loader behavior
instead of assuming. The device extension is still a conformance requirement when advertised.

## Features and formats

`Device.cpp:485-520` enables BC compression, anisotropy, and non-solid fill only when supported.
Descriptor indexing is optional and deliberately disabled on macOS because of MoltenVK combined
samplers (`Device.cpp:440-460`); extend that conservative Apple policy to iOS initially. Compute is
reported available, while large storage buffers require `maxStorageBufferRange >= 1 GiB`
(`Device.cpp:586-617`). GPU skinning requires compute and storage
(`source/renderer/RenderingOptions.cpp:214-229`) and must start disabled.

Formats in `source/renderer/backend/Format.h:27-70` include R/RG/RGBA normalized/integer/float,
depth/stencil, and BC1/2/3. Vulkan does not directly support the engine's RGB8 path
(`Device.cpp:839-875`). If BC/S3TC is absent, `source/graphics/TextureManager.cpp:62-105,375-393`
can decompress DXT to an uncompressed format. That avoids a hard feature requirement but can expand
memory and upload cost substantially; measure actual staged textures.

## Shaders and render passes

The backend loads ready-made SPIR-V from VFS and calls `vkCreateShaderModule`
(`source/renderer/backend/vulkan/ShaderProgram.cpp:75-101`). Engine runtime stages are vertex,
fragment, and compute (`ShaderProgram.cpp:387-528`); geometry/tessellation are not in that creation
path. `source/tools/spirv/compile.py:127-180,327-344` uses `glslc`, Vulkan 1.1, GLSL 450, and
`spirv-opt`. Its tool versions are not fully pinned.

No generated `.spv` assets are tracked in the sparse data tree. `get-nightly-shaders.sh` asks for the
latest nightly, which is not reproducible. Normal Vulkan startup rejects missing `spirv/canvas2d` in
`source/ps/VideoMode.cpp:679-714`. Therefore G0 must exercise device/swapchain clear and present
directly; it needs no shader or VFS. G1 should bundle fixed, hash-recorded diagnostic SPIR-V. G2+
must stage the complete shader manifest from pinned tools or a source-revision-matched official build.

The renderer uses explicit framebuffer pass begin/end and load/store operations. The G0 path should
use the existing current-backbuffer clear/store flow once the minimal link closure is known, then
`Flush` and `Present`. Do not enter the full GUI render pass until G1 is stable.

## Lifecycle and surface rules

The current blocking loop handles focus/minimize, not iOS scenes. Before background entry:

1. stop the display-link/frame producer;
2. prevent new acquire/present calls;
3. pause simulation and audio;
4. finish or safely abandon submitted work, using device-idle only at the lifecycle boundary;
5. mark swapchain/drawable state invalid.

On foreground/size change, query the drawable pixel size—not only UIKit points/SDL window size—then
recreate the swapchain and depth target before resuming. Test safe-area changes separately from the
renderable surface; the safe area constrains GUI layout, not the full drawable extent.

## Conservative first preset

- FIFO/vsync, 30 FPS cap, Balanced default;
- GPU skinning and descriptor indexing off;
- no MSAA initially; anti-aliasing disabled;
- low/medium texture and particle budgets;
- reduced shadows, water, post-processing, PBR options, and draw distance;
- software BC fallback only with memory logging;
- runtime capability report and graceful optional-feature disable, never an assertion/crash.

## Milestone ledger

No G0–G5 build target exists yet. Inventing a command would violate the reproducibility rules. Each
`Build` entry below must be replaced by the exact implemented command before its test can run.

| Milestone | Visible success | Build | Device test | Screenshot/log | Rollback |
| --- | --- | --- | --- | --- | --- |
| G0 | Stable clear color presents | Not implemented; standalone `IPadGraphicsProbe` target required | rotate, background 10 s, foreground, repeat 1000 frames | Xcode GPU/device log + physical screenshot | Empty UIKit M2 shell |
| G1 | Fixed engine-owned triangle | Not implemented; fixed hashed SPIR-V target required | same lifecycle test plus resize | screenshot with revision; shader hashes in log | G0 clear path |
| G2 | One official texture and font | Not implemented; deterministic asset mini-bundle required | validate sampling/text and memory | screenshot + VFS/format capability log | G1 probe |
| G3 | Existing main menu | Not implemented; full minimal menu closure required | activate one item by touch | screenshot + missing-resource-free log | G2 mini-bundle |
| G4 | Small official-map terrain | Not implemented; selected-map manifest required | load/reload/background | terrain screenshot + load/memory timings | G3 menu revision |
| G5 | Buildings and units | Not implemented; model/animation closure required | move camera and resume | unit screenshot + frame-time log | G4 terrain revision |

For every physical run record model class (not personal device ID), chip family, iPadOS version,
Xcode/SDK, configuration, renderer/device/driver strings, extensions/features/formats, present mode,
drawable size, safe area, memory, first validation error, and exact source revision.

Suggested matrix once targets exist: Apple Silicon iPad (M1 or newer) first; then one A12-class device
if available; current ARM64 iPad simulator only for lifecycle/surface smoke, never GPU performance or
compatibility claims.
