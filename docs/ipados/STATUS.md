# Export-time milestone status

This file was exported from port-source commit
`5c60bd3f06727e0ee92e0a9968f069bc186097d1`. Source-repository commit and host observations remain
historical provenance; live publication and run state belongs to the standalone GitHub repository.

- **M0: complete with CONDITIONAL GO.** The audit is documented and cross-reviewed; Apple-only
  validation remains unavailable on this host.
- **M1: incomplete and blocked on this host.** No supported desktop baseline or CxxTest run exists.
- **M2-CI: PASS.** GitHub Actions run 30053407913 compiled and linked the unsigned iphoneos product
  successfully on a macos-15 ARM64 runner (Xcode 16.4, SDK 18.5, CMake 4.4.0).
- **M2-Simulator: PASS.** The same run built, installed, launched, and observed `M2_SHELL_LAUNCHED`
  and `M2_SANDBOX_PROBE_PASS` markers on an iPad Pro 13-inch (M5) simulator with iOS 26.2.
- **M2-Device: NOT TESTED (DEFERRED).** No physical Mac/device Xcode connection or authorized
  signed distribution route exists. Must be completed before any release or public device claim.
- **Overall M2: INCOMPLETE.** M2-Device remains unvalidated.
- **M3-A: PASS.** Upstream source bootstrap (run 30055025293): clone, sparse checkout, exact HEAD
  verification, 16/16 required files, no LFS objects, 61 MB workspace.
- **M3-B: FAIL / FIX IN PROGRESS.** The Python-based patcher failed on the real upstream `os.h` and is being replaced by a deterministic unified diff.
- **M3 engine runtime: NOT STARTED.** No engine, SpiderMonkey, graphics, data, audio, touch, or
  networking integration was added.

# Repository identity

| Field | Verified value |
| --- | --- |
| Branch | `feature/ipados-native-port` |
| Audited upstream base | `eae57d9aab66511a22a869192b7ec72feeaedc7a` |
| Audited scaffold commit | `27c6c602019a3744581ea71d119b62a379b12e10` |
| Historical source remote | `https://gitea.wildfiregames.com/0ad/0ad.git` |
| Standalone export destination | `https://github.com/o11134/0ad-ipados-port.git` |
| Upstream identity | official Wildfire Games repository |
| Port identity | unofficial experimental work; no endorsement claim |

# Host capability

| Field | Observed value |
| --- | --- |
| Host | Microsoft Windows 11 Pro `10.0.26200`, x64 |
| CPU | AMD Ryzen 7 3800X, 8 cores / 16 logical processors |
| Shell | Windows PowerShell `5.1.26100.8875` Desktop, x64 process |
| Git | `2.53.0.windows.1` |
| Python | `3.11.15` |
| CMake | unavailable |
| Clang / MSBuild | unavailable in `PATH` |
| Xcode tools | `xcode-select`, `xcodebuild`, and `xcrun` unavailable on Windows |
| Apple SDKs | unavailable; Apple SDK discovery skipped, not passed |

This Windows host can author and statically validate the workflow but cannot perform an Apple build.
The intended M2-CI/M2-Simulator execution route is the standard GitHub-hosted ARM64 `macos-15`
runner. M2-Device remains a separate future physical-device route.

# Initial pre-edit state

The required commands were run before modification:

```text
git status --short --branch
git branch --show-current
git rev-parse HEAD
git remote -v
git diff --stat
git diff
git ls-files --others --exclude-standard
```

Initial `git status --short --branch`:

```text
## feature/ipados-native-port
?? build/ios/
?? docs/ipados/
?? libraries/ios/
?? scripts/
?? source/platform/
```

Both tracked diff commands were empty. There were exactly **37 untracked files**, all confined to
`build/ios`, `docs/ipados`, `libraries/ios`, `scripts/ios`, and `source/platform/ios`. Filtering the
broad `scripts/` and `source/platform/` entries found only `scripts/ios` and `source/platform/ios`;
there was no unrelated file that required a stop.

# Pre-change review findings

Every initial file was read and classified before editing. `M2_FILE_INVENTORY.md` contains the final
per-file type, purpose, reference, generated/placeholder, syntax/buildability, and security ledger.
The prior scaffold problems were:

1. Product and bundle defaults were `0 A.D. Touch Experimental` and
   `org.example.pyrogenesis.ipad`, not the reviewed temporary values.
2. Product name was not configurable and build configuration was not available to the visible UI.
3. The generator reached a raw missing-CMake error on Windows; device build checked signing before
   checking the host.
4. No inspection-only full Mac verifier or exact clean Mac handoff existed.
5. Static checks only ran `sh -n` and optionally `plutil`; there was no structured summary, CMake
   check, required-file check, security/path/private-API scan, ignore probe, or Windows checker.
6. `build/ios/.gitignore` omitted `generated`, `DerivedData`, `xcuserdata`, and `*.xcuserstate`.
7. The screen showed a title and revision only. It omitted build/CPU/OS/screen/scale/insets/scene/
   lifecycle diagnostics, did not expose memory count, and did not update when lifecycle changed.
8. Lifecycle logs collapsed connect/resign/foreground into the same `inactive` text and had no view
   size log.
9. No sandbox write/read-back control or visible `PASS/FAIL` existed.
10. Several documents used weaker or stale M0/M1/M2 wording, implied Git LFS was a prerequisite for
    M2, retained the old bundle default, or lacked the expanded acceptance criteria.

No initial file contained a personal Team ID, signing asset, secret, user-specific path, private API,
network API, runtime downloader, remote script execution, or Git LFS command in the M2 scripts.

# Stabilization changes

Relative to the 37-file prior scaffold, these existing files were modified:

```text
build/ios/.gitignore
build/ios/CMakeLists.txt
build/ios/IOSBuildConfig.h.in
build/ios/Info.plist.in
docs/ipados/BASELINE_BUILD.md
docs/ipados/DEPENDENCIES.md
docs/ipados/DEVICE_TEST_LOG.md
docs/ipados/FEASIBILITY.md
docs/ipados/LEGAL_AND_ATTRIBUTION.md
docs/ipados/PORTING_PLAN.md
docs/ipados/README.md
docs/ipados/STATUS.md
docs/ipados/TEST_PLAN.md
docs/ipados/XCODE_SETUP.md
scripts/ios/bootstrap-ios.sh
scripts/ios/build-device.sh
scripts/ios/build-simulator.sh
scripts/ios/generate-xcode-project.sh
scripts/ios/run-static-checks.sh
source/platform/ios/IOSAppDelegate.mm
source/platform/ios/IOSPlatformBridge.h
source/platform/ios/IOSPlatformBridge.mm
source/platform/ios/IOSSceneDelegate.mm
source/platform/ios/IOSViewController.mm
```

Exactly four files were added:

```text
docs/ipados/MAC_HANDOFF.md
docs/ipados/M2_FILE_INVENTORY.md
scripts/ios/run-static-checks.ps1
scripts/ios/verify-mac-environment.sh
```

The final shell remains standalone UIKit/Foundation code. It links no engine source, SDL,
SpiderMonkey, MoltenVK, OpenAL, game data, third-party library, network API, telemetry, ads, or
background mode. Default product name is `Pyrogenesis iPad Shell`; default bundle identifier is
`org.example.pyrogenesis.ipadshell`; both are configurable. No Team ID is stored.

# Commands executed in this stabilization session

Repository and host inspection used the exact Git commands listed above plus:

```text
Get-CimInstance Win32_OperatingSystem
Get-CimInstance Win32_Processor
git --version
cmake --version (availability guarded; not found)
python --version
xcode-select --version (availability guarded; not found)
xcodebuild --version (availability guarded; not found)
xcrun --version (availability guarded; not found)
rg -n --hidden "^" build/ios libraries/ios scripts/ios source/platform/ios
rg -n -i "complete|ready|verified|works|supported|M0|M1|M2|LFS|multiplayer" docs/ipados
git ls-files --others --exclude-standard -- scripts source/platform
```

Static and guard validation commands used:

```text
sh -n scripts/ios/*.sh (executed as a loop through Git's POSIX sh)
PowerShell parser API on scripts/ios/run-static-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ios/run-static-checks.ps1
sh scripts/ios/run-static-checks.sh
sh scripts/ios/verify-mac-environment.sh
sh scripts/ios/generate-xcode-project.sh invalid-sdk
sh scripts/ios/generate-xcode-project.sh iphoneos
sh scripts/ios/build-device.sh
sh scripts/ios/build-simulator.sh
.NET XML parsing of build/ios/Info.plist.in
git check-ignore -v --no-index for out/generated/DerivedData/xcuserdata/xcuserstate and dependency roots
rg security, absolute-path, signing, private-API, network/background, and download/LFS patterns
git diff --check --no-index against the new text files where applicable
git status --short --branch
git diff --stat
git diff
git ls-files --others --exclude-standard
```

Several diagnostic harness errors occurred and were corrected without changing build output: an
initial PowerShell interpolation typo, an unsupported .NET relative-path helper, a shell-loop PATH
wrapper typo, an over-broad CMake source-reference parser that counted an include directory, and two
quoting/subshell attempts around `git diff --no-index --check`. The first execution of the new checker
also exposed its own unmatched quote, stale absolute Git-Bash paths in the old status document, a
broken `python3` alias, and false positives for Team variables and the phrase “Git LFS”. The corrected
commands/checkers all passed before handoff.

# Static result

Final checker results:

| Check | Result |
| --- | --- |
| PowerShell checker | exit 0 with `FAIL=0`; includes workflow YAML-subset structure and all inline shell blocks |
| POSIX shell checker through Git sh | exit 0 with `FAIL=0`; full Ruby YAML parse remains Apple-runner-only |
| `Info.plist.in` | .NET XML and Python `plistlib` structure checks passed |
| Shell syntax | all seven `scripts/ios/*.sh` files passed `sh -n` |
| PowerShell syntax | parser reported zero errors |
| GitHub workflow | triggers/permissions/pinned actions/runner/timeout/concurrency/artifact/security fields passed local checks |
| Workflow shell | all ten inline `run` blocks passed extracted POSIX-shell syntax checks |
| Mac handoff | rewritten as a deferred M2-Device guide; obsolete untracked-archive flow removed |
| Inventory | the 41 reviewed scaffold files were committed exactly in the audited scaffold commit |
| M2 source requirements | all required app/delegate/scene/UI/diagnostic/lifecycle/size/sandbox markers present |
| Isolation | CMake references exactly the nine `source/platform/ios` files and public Apple frameworks |
| Source structural check | balanced delimiters, preprocessor blocks, and Objective-C blocks in nine files |
| Guard behavior | invalid SDK exit 2; Windows generator/device/simulator guards exit 1; no `out` created |

The skips are Apple `plutil` and CMake/Xcode configuration because those tools do not exist on this
Windows host. A fallback XML check passed, but it was not mislabeled as Apple plist validation.

Apple Objective-C++ compile, signing, simulator, and device tests remain not run. The host guard is
intentionally evaluated after the first `project()` call because the
[official CMake 3.25 documentation](https://cmake.org/cmake/help/v3.25/command/project.html) records
that call as establishing host and target platform variables. The guard still awaits an actual
Apple-host configure.

The 41-file scaffold is no longer untracked: it was committed as
`27c6c602019a3744581ea71d119b62a379b12e10`. The workflow changes are excluded from that commit and
are reviewed as an independent follow-up changeset.

# Build and runtime result

| Result | Status |
| --- | --- |
| GitHub workflow | Included in standalone export; **NO SUCCESSFUL RUN EVIDENCE AT EXPORT TIME** |
| CMake configure / Xcode generation | **PENDING CI; NOT RUN** |
| Unsigned Objective-C++ device-SDK compile/link | **PENDING CI; NOT RUN** |
| Code signing | **NOT RUN** |
| ARM64 iPad simulator build/install/launch | **PENDING; NOT RUN** |
| Physical iPad build/install/launch | **NOT RUN** |
| CI launch/sandbox markers | Implemented in source; **NOT OBSERVED** |
| Visible diagnostics/manual sandbox | Implemented in source; **NOT RUN** |
| M2-CI | **PENDING** |
| M2-Simulator | **PENDING** |
| M2-Device | **BLOCKED (validation pending)** |
| M2 acceptance | **NOT MET; M2 INCOMPLETE** |

M2-CI/M2-Simulator remain pending until the standalone repository records a successful workflow and
the required retained evidence. M2-Device is separately blocked by the lack of a legitimate
Mac/device Xcode or signed distribution route. Git LFS and the approximately 6.52 GB runtime source
data are not required for M2 and were not included in this export.

# Export boundary and next gate

In the source repository, the scaffold and CI work were reviewed as separate commits. This standalone
export publishes their current files as one independent root commit without upstream history or game
data. The next gate is the first real `iPadOS M2 Scaffold` result and retained evidence. Do not begin
M3.
