# Native iPadOS porting plan

## Rules of execution

Every milestone has one new assumption, a visible or logged acceptance test, and an isolated rollback
boundary. Desktop builds remain the regression reference. Simulator results are labeled as such;
rendering, JavaScript behavior, audio, touch latency, memory, and thermals require a physical iPad.
No remote executable/script loading, JIT, private API, arbitrary dylib loading, or network dependency
is permitted.

## Ordered milestones

### M0 — audit

Acceptance: revision/build/dependency/platform evidence exists and decision is explicit.

Current result: **M0 is complete with a CONDITIONAL GO**; local cross-review, shell syntax, XML
well-formedness, required-file, whitespace, path, and secret scans passed. Apple `plutil`,
CMake/Xcode compilation, and physical-device evidence remain unavailable. No personal path is
permitted in tracked documentation or build inputs.

Rollback: documentation-only changes.

### M1 — supported desktop baseline

On an Apple Silicon Mac, build unchanged upstream Debug, run CxxTest, record warnings/durations and
then build Release. Hydrate only official test/LFS data required by upstream CI first.

Acceptance: engine and tests pass, or an exact external/upstream failure is preserved.

Current result: **M1 is incomplete and blocked on this host**. There is no macOS/Xcode host,
generated dependency bundle, compiler, or hydrated test data in this session. See
`BASELINE_BUILD.md`.

Rollback: no engine changes.

### M2 — standalone UIKit shell

The isolated files in `build/ios`, `scripts/ios`, and `source/platform/ios` generate a dependency-free
UIKit app target. Validation is split into non-interchangeable tracks:

- **M2-CI:** generate both Xcode projects, discover their schemes, inspect settings, and compile an
  unsigned `iphoneos` product on the standard ARM64 `macos-15` runner. Acceptance requires a real
  successful workflow and retained compiler/link/plist/framework evidence.
- **M2-Simulator:** dynamically select an installed iPad simulator, or create one only from installed
  runtime/device-type data, then build/install/launch. Acceptance requires PID liveness and launched-
  process `M2_SHELL_LAUNCHED` plus `M2_SANDBOX_PROBE_PASS` evidence with no FAIL marker.
- **M2-Device:** use a legitimate local signing route, install on a physical iPad, inspect the visible
  landscape diagnostics and safe areas, exercise the manual sandbox button and lifecycle transitions,
  and retain logs. CI never attempts this track.

Current result: **M2-CI PENDING**, **M2-Simulator PENDING**, and **M2-Device BLOCKED (validation
pending)**. The workflow is included in the standalone export, but no successful run evidence was
available when the export was prepared. Overall M2 remains incomplete, and M3 must not begin.

Rollback: revert the dedicated scaffold and CI commits; do not delete unrelated upstream paths.

### M3 — core engine bootstrap

Add `OS_IOS` without changing macOS classification; add iOS source selection and a narrow platform
bridge. Link the smallest core closure with audio, Atlas, lobby, DAP, miniupnpc, NVTT, and Collada
runtime conversion disabled. Implement bundle/sandbox roots, logging, unconditional background pause,
and clean shutdown. Explicitly guard `fork`/`exec`, AIO, desktop frameworks, and `dlopen` paths.

Acceptance: core initializes paths and logging then exits cleanly on device; desktop baseline remains
unchanged.

Rollback: compile-time iOS guards and isolated source group.

### M4 — engine JavaScript

1. Obtain the exact WFG 128.13.0+wfg5 source over HTTPS and record SHA-256.
2. Inspect its own configure help/source; document exact no-JIT/no-Wasm/executable-memory options.
3. Cross-build static C++ and Rust products into a target-qualified output root.
4. First link a standalone app target that calls `JS_Init`, evaluates a bundled trivial expression,
   checks the interpreter-only diagnostic, returns the result, and shuts down on a physical iPad.
5. Inspect linked symbols/load commands, then integrate that proven product with the M3 core.
6. Replace unconditional engine JIT enabling with a compile-time policy that leaves desktop defaults
   unchanged and asserts interpreter-only mode on iOS; repeat through the real `ScriptInterface`.

Acceptance: standalone and engine-context device logs contain the correct result, clean shutdown, and
a build-derived JIT-off diagnostic; no JIT/executable-memory claim is based solely on runtime flags.

Rollback: standalone target and target-qualified dependency output remain isolated; the engine link
excludes JS and returns to M3.

### M5 — renderer integration

Build pinned SDL2 UIKit and pinned static MoltenVK slices. In a standalone probe, create an SDL Vulkan
window/surface, request Vulkan 1.1, clear/present under FIFO (G0), then draw fixed diagnostic geometry
(G1). Exercise resize, background/foreground, and memory warning on device. Only then connect the
existing Vulkan backend to the engine, add feature reporting/conservative defaults, and advance to G2
texture/font, G3 existing menu, G4 terrain, and G5 units.

Acceptance: each graphics stage has its own build log, device result, screenshot instruction, and
known-good source revision as defined in `GRAPHICS.md`.

Rollback: retain the standalone G0/G1 probe and UIKit shell; disable the engine graphics capability.

### M6 — menu and read-only data

Generate a deterministic official data manifest. Precompile SPIR-V and preconvert DAE/textures on the
Mac. Bundle the minimum base/public mod closure and mount it read-only. Open `page_pregame.xml` and
activate one menu item using a temporary compatibility input path.

Acceptance: no bundle write attempt, network download, missing asset, or unlicensed content; fonts,
textures, localization, and scripts load on device.

### M7/M8 — small map and touch gameplay

Load one measured small official offline scenario. Implement a pure C++ gesture state machine with
stable touch-ID mapping, cancellation, configurable thresholds, Pencil discrimination, and independent
unit tests. Keep hardware mouse/keyboard paths intact. Add native touch command modes incrementally.

Acceptance: terrain/buildings/units/audio appear; select, pan, pinch, multiple select, move, attack,
and building placement pass the device checklist without ambiguous commands.

### M9 — persistence and lifecycle safety

Implement validated sandbox-relative names, UTF-8 path tests, atomic unique-temp save replacement,
corruption handling, settings, and replay separation. Save or clearly pause before suspension; do not
claim guaranteed background time.

Acceptance: fresh/existing/corrupt/low-storage/interrupted/Arabic-name tests and background/resume
tests pass without silent deletion.

### M10 — stable proof of concept

Run a 20-minute physical-device small-map session. Record cold launch, load/save, memory, FPS/frame
times, CPU/GPU observations, thermal state, input latency observations, and interpreter overhead.
Verify clean rebuild instructions from a fresh official checkout. Multiplayer remains disabled.

## Immediate next gate

Publish the reviewed standalone export branch and evaluate its first real `iPadOS M2 Scaffold` run.
Do not configure signing, hydrate LFS/runtime data, or begin M3 while all M2 tracks lack their required
evidence.
