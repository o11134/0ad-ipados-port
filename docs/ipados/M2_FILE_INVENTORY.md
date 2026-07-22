# M0/M2 file inventory

This began as the reviewed Windows-host inventory for the 41-file source scaffold committed in
`27c6c602019a3744581ea71d119b62a379b12e10`. It now records the standalone export's CI workflow
additions in `.github/workflows`, `docs/ipados`, and `scripts/ios`. “Referenced” includes GitHub Actions,
Git/CMake/UIKit implicit use, and explicit documentation links. Apple compilation, simulator launch,
signing, and physical-device behavior remain unverified unless a later run record says otherwise.

| Relative path | Type and purpose | Referenced by | Generated content or placeholder | Syntax/buildability on this host | Secrets, personal paths, private API |
| --- | --- | --- | --- | --- | --- |
| `.github/workflows/ipados-m2.yml` | ARM64 macOS compile/simulator workflow | GitHub Actions and CI docs | Handwritten; runner paths are ephemeral | Windows structural validation passed; run evidence pending | Read-only permissions; pinned official actions; no secrets/signing/LFS |
| `build/ios/.gitignore` | Git ignore policy for project/build/user output | Git and both static checkers | Handwritten; no placeholder | Ignore probes checked on Windows | None found |
| `build/ios/CMakeLists.txt` | Isolated CMake/Xcode iPad app target | `generate-xcode-project.sh` | Cache defaults; Team is empty; revision may be detected | Manual review only; CMake/Xcode unavailable | No Team value or host path found |
| `build/ios/IOSBuildConfig.h.in` | Generated build-configuration header template | CMake; AppDelegate/ViewController | `@...@` revision/deployment substitutions; build-type fallback | C/C++ preprocessor reviewed; generated header not compiled | None found |
| `build/ios/Info.plist.in` | iPad app/scene/orientation plist template | CMake target and static checkers | Xcode `$(...)` build-setting substitutions | XML accepted by .NET; Apple `plutil` skipped | No permissions, network, background mode, or secret found |
| `docs/ipados/AUDIO.md` | Audio gap and future `AVAudioSession` plan | docs README/feasibility | Future bridge/build milestones are explicit | Markdown/static text reviewed | Public references only; none sensitive |
| `docs/ipados/BASELINE_BUILD.md` | M1 host inventory and failed baseline record | README/plan/status | Recorded result plus future Mac fields | Markdown reviewed; M1 remains incomplete | None found |
| `docs/ipados/DATA_LAYOUT.md` | Proposed bundle/sandbox/VFS mapping | README/feasibility | Mapping and staging steps are proposals | Markdown reviewed; no implementation claim | None found |
| `docs/ipados/DEPENDENCIES.md` | Pinned dependency/status matrix | README/feasibility/baseline | iPad commands and hashes explicitly not implemented | Markdown reviewed; no dependency built | Public upstream URLs only; no downloader or secret |
| `docs/ipados/DEVICE_TEST_LOG.md` | Sanitized simulator/device record and checklist | Xcode/test/plan/status docs | Blank result template/check boxes | Markdown reviewed; all physical boxes remain unchecked | Explicitly excludes identifiers and signing data |
| `docs/ipados/FEASIBILITY.md` | Evidence-backed M0 decision | docs README | Estimates/proposals labeled; M0 decision is conditional | Markdown reviewed | Public source references only |
| `docs/ipados/GRAPHICS.md` | Renderer/MoltenVK gap and G0–G5 proof ledger | README/plan/feasibility | Graphics targets and results explicitly not implemented | Markdown reviewed; no graphics build claim | Public URLs only; none sensitive |
| `docs/ipados/GITHUB_ACTIONS.md` | CI operation, evidence, artifact, and proof-boundary guide | README/status/test/Xcode docs | Pending statuses are intentional until a run exists | Markdown reviewed on Windows; commands not run on GitHub | No credentials, Team ID, device ID, or signing data |
| `docs/ipados/LEGAL_AND_ATTRIBUTION.md` | Unofficial identity, license, trademark boundary | README | Future About/BOM items explicit | Markdown reviewed | No signing identity or personal namespace |
| `docs/ipados/MAC_HANDOFF.md` | Deferred future physical-device handoff | README/generator/build scripts | Selected GitHub URL and later reviewed commit are explicit future inputs | Markdown reviewed; not the current CI route | Personal/signing values forbidden |
| `docs/ipados/M2_FILE_INVENTORY.md` | This per-file audit ledger | docs README and final handoff | Handwritten snapshot; update when file set changes | Markdown reviewed | No secrets expected; included in final scans |
| `docs/ipados/NETWORKING_FUTURE.md` | Post-MVP networking scope | feasibility | Multiplayer work deferred | Markdown reviewed; no M2 networking | Public concepts only |
| `docs/ipados/PERFORMANCE.md` | Future measurement protocol/empty ledger | README/status | `NOT TESTED` result fields | Markdown reviewed; no measurements claimed | None found |
| `docs/ipados/PORTING_PLAN.md` | M0–M10 gates and rollback boundaries | docs README/status | M3+ actions are future work | Markdown reviewed | No credentials or personal paths |
| `docs/ipados/README.md` | Primary status/setup/index | feasibility and operators | Local signing/product values are examples | Markdown reviewed | Placeholder bundle only; no Team value |
| `docs/ipados/SPIDERMONKEY.md` | Separate interpreter-only proof track | README/feasibility/plan | Configure/results templates unfilled | Markdown reviewed; no JS product built | Public source URL only |
| `docs/ipados/STATUS.md` | Current factual host/commands/results snapshot | docs README and handoff | Updated after verification; no generated data | Markdown reviewed | Sanitized command/result record |
| `docs/ipados/TEST_PLAN.md` | Truth labels, test matrix, future cases | README/Xcode/plan | Later subsystem cases are not implemented | Markdown reviewed | Security checklist only; no secret value |
| `docs/ipados/TOUCH_CONTROLS.md` | Touch audit and proposed RTS state machine | README/plan | Gestures/thresholds are design proposals | Markdown reviewed; no touch integration | None found |
| `docs/ipados/XCODE_SETUP.md` | M2 signing/simulator/device instructions | README/Mac handoff | Operator supplies local Team and unique bundle | Markdown reviewed; commands not run on Apple host | No personal signing value |
| `libraries/ios/.gitignore` | Dependency download/build/output isolation | Git/static checkers | Handwritten patterns | Ignore probes checked on Windows | None found |
| `libraries/ios/README.md` | Reserved future dependency workspace | dependency/status docs | `build-ios-deps.sh` intentionally absent | Markdown reviewed; no build command | No downloads, hashes, or secret values |
| `scripts/ios/bootstrap-ios.sh` | Compatibility entry that delegates to verifier | older/operator command references | No generated content | POSIX `sh -n` checked; not run on macOS | Local exec only; no network/secret |
| `scripts/ios/build-device.sh` | Signed command-line device-target build | README/Xcode/test docs | Team/bundle/config/output from environment | POSIX `sh -n`; Windows guard tested; no build | No committed Team; provisioning update is opt-in |
| `scripts/ios/build-simulator.sh` | ARM64 iPad simulator build wrapper | README/Xcode/test docs | Config/output from environment | POSIX `sh -n`; no simulator build | No signing value or network command |
| `scripts/ios/generate-xcode-project.sh` | macOS-only Xcode project generator | build wrappers and setup docs | SDK/output/deployment/bundle/product/Team inputs | POSIX `sh -n`; Windows handoff guard tested | Team remains optional environment input |
| `scripts/ios/run-ci-simulator-smoke.sh` | Dynamic iPad Simulator build/install/marker smoke test | GitHub Actions workflow and CI docs | Uses installed runtimes only; CI artifact/DerivedData paths are inputs | POSIX `sh -n`; Apple commands not run on Windows | Signing disabled; raw UUID data excluded from artifacts; no network/download |
| `scripts/ios/run-static-checks.ps1` | Native Windows M0/M2 static checker | README/test/Mac inventory | Counters only; no generated source | PowerShell parser and execution checked | Self excluded from literal-pattern scans; manually reviewed |
| `scripts/ios/run-static-checks.sh` | Cross-platform static and Mac configure checker | README/Xcode/test/Mac handoff | Ignored CMake static-check output on Mac only | POSIX `sh -n` and Windows execution checked | Self excluded from literal-pattern scans; manually reviewed |
| `scripts/ios/verify-mac-environment.sh` | Inspection-only Mac readiness report | bootstrap/generator/docs | Reads environment; writes nothing | POSIX `sh -n`; Windows failure/skip behavior checked | Reports paths to console only; no download/credential |
| `source/platform/ios/IOSAppDelegate.h` | Minimal `UIApplicationDelegate` interface | CMake and `main.mm` | Handwritten; no placeholder | Objective-C manual review; not Apple-compiled | Public UIKit only |
| `source/platform/ios/IOSAppDelegate.mm` | Launch marker, memory-warning, termination, orientation bridge | CMake/UIKit/CI smoke | Engine integration intentionally absent | Objective-C++ manual review; not Apple-compiled | Public UIKit/Foundation; no sensitive log |
| `source/platform/ios/IOSPlatformBridge.h` | Small diagnostics/lifecycle C++ boundary | app/scene/view controllers | Handwritten snapshot/notification API | C++/Objective-C header manual review; not compiled | No engine/network/private API |
| `source/platform/ios/IOSPlatformBridge.mm` | Main-thread diagnostic state and sanitized logs | delegates/ViewController | Engine callbacks intentionally absent | Objective-C++ manual review; not Apple-compiled | Public APIs; compile guard; no personal data |
| `source/platform/ios/IOSSceneDelegate.h` | `UIWindowSceneDelegate` and window ownership | plist/CMake/UIKit | Handwritten; no placeholder | Objective-C manual review; not Apple-compiled | Public UIKit only |
| `source/platform/ios/IOSSceneDelegate.mm` | Root window/controller and distinct scene events | plist/CMake/UIKit bridge | Future engine pause comment only | Objective-C++ manual review; not Apple-compiled | No network or secret |
| `source/platform/ios/IOSViewController.h` | Root diagnostic view-controller interface | SceneDelegate/CMake | Handwritten; no placeholder | Objective-C manual review; not Apple-compiled | Public UIKit only |
| `source/platform/ios/IOSViewController.mm` | Safe-area UI, diagnostics, manual and explicit CI sandbox probe | SceneDelegate/CMake/bridge/CI smoke | Initial `NOT RUN` UI state remains normal; CI mode is opt-in | Objective-C++ manual review; not Apple-compiled | Public APIs; failure markers contain domain/code, never a sandbox path |
| `source/platform/ios/main.mm` | `UIApplicationMain` entry point | CMake/app bundle | Handwritten; no placeholder | Objective-C++ manual review; not Apple-compiled | Public UIKit only |

Final local static results, the scaffold commit, and Apple-only skips are recorded in `STATUS.md`.
This inventory is not evidence of GitHub execution, simulator launch, or physical-device testing.
