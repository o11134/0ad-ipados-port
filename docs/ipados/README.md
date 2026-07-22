# 0 A.D. Touch — Unofficial Experimental iPad Port

This directory tracks an experimental, unofficial, native ARM64 iPadOS port of 0 A.D. It is not
endorsed by Wildfire Games and contains no Age of Empires code or assets.

## Current status

The audited upstream base is `eae57d9aab66511a22a869192b7ec72feeaedc7a`. The standalone export was
prepared from branch `feature/ipados-native-port` at source commit
`5c60bd3f06727e0ee92e0a9968f069bc186097d1`; the reviewed source scaffold commit is
`27c6c602019a3744581ea71d119b62a379b12e10`. M0 is complete with a **CONDITIONAL GO** decision. A
dependency-free UIKit shell, Xcode/CMake generator, and GitHub Actions workflow source exist. No
successful CI, simulator, or physical-device result existed when the export was prepared.

Milestone status:

- M0 audit: **complete with CONDITIONAL GO**; Apple `plutil`/Xcode validation remains unavailable.
- M1 desktop baseline: **incomplete and blocked on this host** by missing upstream
  dependency outputs, compiler/MSBuild, generated Premake, runtime data, and tests.
- M2-CI: **PENDING** until an actual GitHub-hosted macOS compile succeeds with retained evidence.
- M2-Simulator: **PENDING** until an actual simulator install/launch and marker-based smoke test
  succeeds.
- M2-Device: **BLOCKED (validation pending)** because no local Mac/device Xcode connection or
  authorized signed distribution route is available.
- Overall M2: **INCOMPLETE**; the reviewed standalone shell is not physical-device proof.
- M3 and later: not started.

The configured first target is an ARM64 iPad running iPadOS 17 or later; support has not been proven.
A standard GitHub-hosted ARM64 macOS runner can exercise M2-CI and M2-Simulator without a
developer-owned Mac. A legitimate signed launch on a physical iPad remains the M2-Device source of
truth.

## Known limitations and proof gates

- The current SpiderMonkey 128.13.0 configuration does not disable JIT, and engine startup explicitly
  requests Baseline and Ion. No SpiderMonkey product was built in this session; the exact
  interpreter-only configuration for the pinned source has not been proven.
- No iOS dependency archives have been downloaded, hashed, compiled, or linked.
- The renderer, SDL, audio, VFS, game data, touch input, saves, and engine entry point are not linked
  into the shell.
- The sparse checkout does not hydrate `binaries/data`; no data staging command exists yet.
- The shell has no development icon or launch artwork. It does not use the official 0 A.D. logo.
- Multiplayer is intentionally outside the proof-of-concept scope.

## Current GitHub Actions route

The current route is `.github/workflows/ipados-m2.yml`, documented in `GITHUB_ACTIONS.md`. It uses the
standard ARM64 `macos-15` runner, prints the actual Xcode/SDK/CMake/Python/Git environment, and runs:

```sh
sh scripts/ios/verify-mac-environment.sh
sh scripts/ios/run-static-checks.sh
```

The environment verifier is inspection-only and reports `PASS/WARN/FAIL/SKIP`; the static checker
never labels skipped checks as passed. CI then generates both projects, compiles against the device SDK
with signing disabled, and attempts a dynamic iPad Simulator smoke test. This is authored behavior,
not a successful result. Git LFS and runtime game data are **not required for M2**.

On Windows, the equivalent non-Apple static entry point is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ios/run-static-checks.ps1
```

## Generate and build the shell

The workflow automates these commands on GitHub-hosted macOS. Until a successful retained run is
recorded, the following local commands remain only a future manual-Mac path:

```sh
bash scripts/ios/generate-xcode-project.sh iphoneos
open build/ios/out/iphoneos/PyrogenesisIPadShell.xcodeproj
```

For a future signed command-line device build, first set `IPADOS_DEVELOPMENT_TEAM` and a unique
`IPADOS_BUNDLE_IDENTIFIER` in the local shell, then run:

```sh
bash scripts/ios/build-device.sh
```

For the Apple Silicon simulator:

```sh
bash scripts/ios/build-simulator.sh
```

Device and simulator output roots are separate. Override them locally with
`IPADOS_DEVICE_BUILD_DIR` and `IPADOS_SIMULATOR_BUILD_DIR`; generated content must remain ignored and
must never replace a source directory.

The temporary defaults are product name `Pyrogenesis iPad Shell` and bundle identifier
`org.example.pyrogenesis.ipadshell`. To change them for the current shell invocation without
committing personal data:

```sh
IPADOS_BUNDLE_IDENTIFIER=org.example.pyrogenesis.ipadshell \
IPADOS_PRODUCT_NAME="Pyrogenesis iPad Shell" \
IPADOS_DEPLOYMENT_TARGET=17.0 \
sh scripts/ios/generate-xcode-project.sh iphoneos
```

For interactive **Product > Run**, set the Development Team in the generated Xcode project.
`build-device.sh` regenerates that project, so its repeatable command-line path intentionally requires
`IPADOS_DEVELOPMENT_TEAM` as a local environment value. It must never be written into a tracked
script or document. Set `IPADOS_ALLOW_PROVISIONING_UPDATES=1` only when explicitly allowing Xcode's
command-line build to update signing assets.

## Deferred signing and installation

This section applies only to a future M2-Device session and is not part of current CI. Open the
generated project, select `PyrogenesisIPadShell`, choose the connected iPad as the run
destination, and select an Apple Development Team under **Signing & Capabilities**. Keep automatic
signing enabled. Enable Developer Mode on the iPad if iPadOS requests it, then use **Product > Run**.
Detailed steps are in `XCODE_SETUP.md`.

## Data staging

There is deliberately no data staging command yet, and none is needed for M2. The current checkout
omits more than 28,000 tracked `binaries/data` paths, including Git LFS objects. Work after M2 must
hydrate only approved official upstream/LFS inputs and transform them into a read-only bundle plus
writable sandbox roots. SPIR-V output and host-side DAE/texture conversions must be deterministic.
See `DATA_LAYOUT.md`.

## Logs

The shell visibly reports app/build/architecture/OS, screen and view points, native scale, safe-area
insets, scene/lifecycle state, last event, and memory-warning count. Its button atomically writes and
reads a small Application Support probe and displays `PASS` or `FAIL`. Launch, lifecycle, size,
safe-area, memory, and sandbox events also use Apple unified logging with the prefix
`[Pyrogenesis iPadOS]`. Read them in Xcode's debug console or the connected-device console.
CI diagnostic mode additionally emits `M2_SHELL_LAUNCHED`, `M2_SANDBOX_PROBE_PASS`, or a sanitized
`M2_SANDBOX_PROBE_FAIL`; it activates only through an explicit launch argument/environment value and
does not remove the manual button.

## Common failures

- GitHub workflow unavailable: verify Actions is enabled and the export branch exists on GitHub; no
  CI result exists before a completed run provides the required evidence.
- `Xcode project generation requires an Apple Silicon Mac`: use the GitHub Actions route or the
  deferred `MAC_HANDOFF.md` physical-device route; no build ran on Windows.
- `required tool is missing`: install the named prerequisite explicitly; the scripts do not install
  anything.
- `Signing for ... requires a development team`: select a local team in Xcode; never commit it.
- `No profiles for ... were found`: connect/unlock the device, verify the bundle identifier is
  unique, and allow Xcode to manage signing.
- `This scaffold must be configured with -DCMAKE_SYSTEM_NAME=iOS`: use the provided generator.
- Missing game data, SDL, MoltenVK, or SpiderMonkey errors cannot be fixed by the shell scripts yet;
  those integrations have not been implemented.

## Uninstall and local data

Long-press the development app on the iPad and choose **Remove App > Delete App**. This deletes its
sandboxed documents, saves, settings, and caches. Xcode's **Devices and Simulators** window may also
uninstall the app. Do not delete development data unless it is no longer needed.

## License

Upstream source remains under GPL-2.0-or-later and bundled data/art has its existing licenses; see
the repository `LICENSE.md`, `license_gpl-2.0.txt`, `libraries/LICENSE.txt`, and
`LEGAL_AND_ATTRIBUTION.md`. Public distribution requires separate GPL, trademark, dependency,
asset-attribution, and Apple policy review.

## Document index

- `FEASIBILITY.md`: evidence-based Phase 0 decision.
- `BASELINE_BUILD.md`: host inventory and exact baseline failure.
- `DEPENDENCIES.md`: version and port-status matrix.
- `PORTING_PLAN.md`: ordered gates and rollback boundaries.
- `GITHUB_ACTIONS.md`: current unsigned macOS CI and simulator workflow, artifacts, and proof limits.
- `XCODE_SETUP.md`: deferred manual signing and physical-device workflow.
- `MAC_HANDOFF.md`: deferred clean-Mac M2-Device handoff; not the current CI route.
- `M2_FILE_INVENTORY.md`: per-file purpose, reference, placeholder, and verification inventory.
- `SPIDERMONKEY.md`, `GRAPHICS.md`, `DATA_LAYOUT.md`, `TOUCH_CONTROLS.md`, `AUDIO.md`: subsystem
  audits.
- `PERFORMANCE.md`, `TEST_PLAN.md`, `DEVICE_TEST_LOG.md`: measurement and verification records.
- `STATUS.md`: current factual state and command log.
