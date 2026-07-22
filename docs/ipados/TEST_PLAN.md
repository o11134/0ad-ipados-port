# iPadOS test plan

## Test truth labels

Every result is labeled one of: `Host-Windows`, `CI-macOS-ARM64`, `Simulator-iPad-ARM64`, or
`Physical-iPad-ARM64`. A cloud compile, simulator result, and physical-device result are separate
gates. `PASS` requires the exact command/build revision, environment, expected result, actual result,
and retained log. A missing target is `NOT IMPLEMENTED`, not `PASS`; a skipped check is not a pass.

## Required categories

| Category | Existing evidence/command | New coverage needed | Required environment |
| --- | --- | --- | --- |
| Upstream regression | mac Jenkins builds and runs `./binaries/system/test[_dbg] --format junit --output cxxtest.xml` | Repeat unchanged before/after iOS guards | Apple Silicon macOS |
| Build system | Premake target generation; new CMake shell | configure/build device and simulator; no desktop source-list drift | macOS/Xcode |
| Paths/VFS | existing archive/VFS tests; `test_path_util` has validation TODO | sandbox mapping, bundle read-only, traversal rejection, UTF-8/Arabic | host + simulator + device |
| Touch | `test_Input.h` covers dispatch only | deterministic state machine/IDs/cancellation/thresholds | host + simulator; ergonomics on device |
| Lifecycle | unbuilt M2 scene/app diagnostics bridge | verify M2 events/size; later add engine pause, timer reset, GPU/audio stop/recovery | simulator + device |
| Save/load | no focused atomic/fault tests found | create/overwrite/interruption/corruption/storage/Unicode | host + device |
| JavaScript | upstream script tests use normal runtime | isolated interpreter-only init/evaluate/shutdown/assertion | physical iPad required |
| Graphics | renderer tests do not prove Apple surface | G0–G5 and capability/fallback/resume | physical iPad required |
| Assets | CI reference/LFS checks | signed manifest, required menu/map files, no native payload | macOS + device mount |
| Audio | desktop sound path | session interruption/routes/silent/background | physical iPad required |
| Offline policy | existing flags are incomplete | binary/runtime assertion that ENet/curl/lobby/reporter HTTP do not initialize | host + device |

## Current commands

Implemented shell-only commands; the PowerShell/static portions run on Windows, while generation and
build remain macOS/Xcode-only and have not run:

```sh
sh scripts/ios/verify-mac-environment.sh
sh scripts/ios/run-static-checks.sh
sh scripts/ios/generate-xcode-project.sh iphoneos
sh scripts/ios/generate-xcode-project.sh iphonesimulator
sh scripts/ios/build-device.sh
sh scripts/ios/build-simulator.sh
sh scripts/ios/run-ci-simulator-smoke.sh \
  "<actual project>" "<discovered scheme>" "<artifact directory>" "<DerivedData directory>"
```

Windows uses `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/ios/run-static-checks.ps1`; Apple-only checks are explicitly `SKIP`, not `PASS`.

Upstream macOS baseline commands are recorded, not executed here:

```sh
libraries/build-macos-libs.sh -j$(sysctl -n hw.ncpu)
build/workspaces/update-workspaces.sh
make -C build/workspaces/gcc -j$(sysctl -n hw.ncpu) config=debug
./binaries/system/test_dbg --format junit --output cxxtest.xml
```

The M2 UI contains an Application Support write/read-back sandbox probe and an explicit CI-only
one-shot launch mode for the same operation. The markers `M2_SHELL_LAUNCHED`,
`M2_SANDBOX_PROBE_PASS`, and `M2_SANDBOX_PROBE_FAIL` exist in source but remain unobserved until a
GitHub run retains launched-process logs. This is not an engine/VFS/save test. No commands exist yet
for SpiderMonkey, graphics, touch, engine/VFS, or data staging validation.

## M2 track acceptance

### M2-CI

Acceptance requires a successful standard ARM64 macOS job, environment and static checks with no
`FAIL`, both generated Xcode projects and discovered schemes, validated product/family/architecture/
Team metadata, an unsigned `iphoneos` build using `CODE_SIGNING_ALLOWED=NO`, generated plist and link
reports, and retained logs/artifacts. It proves compile/link compatibility only.

### M2-Simulator

Acceptance additionally requires dynamic selection or creation from an installed iPad runtime,
successful `iphonesimulator` build/install/launch, numeric PID, ten-second liveness, both launch and
sandbox PASS markers for that PID, no FAIL marker, and clean termination. A build without launch
evidence is not a pass. Screenshot capture is supporting evidence requiring human inspection; logs do
not by themselves prove the visual layout. Background/foreground remains `SKIP` when no documented
`simctl` transition command is available.

### M2-Device

Acceptance requires a legitimately signed install and launch on a physical iPad plus visible
diagnostics, manual sandbox PASS, lifecycle evidence, landscape/safe-area checks, and responsive
background/foreground cycles. This track is **BLOCKED (validation pending)**. Neither M2-CI nor
M2-Simulator completes M2-Device or overall M2.

## Build/platform cases

- clean CMake configure for `iphoneos` and `iphonesimulator` ARM64;
- unique output roots and no local absolute path or Team ID in tracked/generated-source inputs;
- Debug and Release compile with warnings captured;
- unsigned device-SDK CI build, unsigned simulator build, and a separately deferred signed device
  build;
- desktop Premake generation/build before and after platform macros;
- minimum iPadOS 17 deployment and current SDK;
- missing CMake/Xcode produces an actionable CI failure; Team/profile failures apply only to the
  deferred M2-Device route;
- bundle contains only expected public frameworks/static libraries and no macOS entitlements/dylibs.

## Path/save fault cases

Fresh/existing/missing directories; read-only bundle; cache purge; insufficient storage; destination
permission failure; unique-temp creation, write, flush, sync, rename faults; corrupt/truncated ZIP;
missing/corrupt version; overwrite preserving old valid save; resume during save; concurrent save
rejection; absolute path, separators, `.`, `..`, NUL/control; Unicode and Arabic display/physical file
names; update preservation; delete/reinstall semantics. Verify no arbitrary traversal and no silent
deletion.

## Touch cases

Arbitrary 64-bit contact IDs, ID reuse, more contacts than capacity, every state cancellation,
background mid-gesture, tap/drag/long-press/double-tap boundaries, two-finger pan/pinch ambiguity,
ignored rotation, Pencil/no-Pencil, palm contacts, safe-area transforms, hardware mouse/keyboard not
consumed, and deterministic event replay at different frame rates.

## Lifecycle cases

Cold launch, scene connect/disconnect, active/inactive, interruption, lock, background/foreground,
memory warning in each safe state, rotation/resize, external display if encountered, background during
load/save, termination without a guaranteed callback, GPU drawable recreation, audio interruption,
touch cancellation, and reset of frame delta. Assert no simulation/network/render loop continues in
background.

## Physical-device smoke checklist

Record each line individually in `DEVICE_TEST_LOG.md`:

- install a fresh signed build;
- launch and see main menu;
- start the selected small official offline map;
- select one unit;
- pan and pinch zoom;
- select multiple units;
- move units and attack one target;
- construct one building;
- pause, background, wait, and return;
- save, load, and verify state;
- play 20 minutes while recording memory/frame/thermal state;
- exit normally;
- relaunch and verify settings;
- uninstall and explicitly confirm whether local data deletion was intended.

For M2, only install/launch, visible diagnostics, landscape/size, lifecycle, safe area, memory warning,
logs, and the visible sandbox write/read-back result are applicable. Do not mark later checklist
items failed against an empty shell; mark them `NOT IMPLEMENTED`.

## Security/compliance checks

Search the final link closure and bundle for JIT/executable-memory entitlements, unexpected dynamic
libraries, runtime download/update paths, private frameworks/selectors, embedded certificates,
profiles, Team IDs, secrets, device IDs, user paths, executable data, non-official assets, and missing
license/credit files. This supports—but does not replace—source review and actual runtime tests.
