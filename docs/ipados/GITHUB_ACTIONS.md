# GitHub Actions validation for the M2 shell

## Export-time status

The workflow is stored at `.github/workflows/ipados-m2.yml` and is named `iPadOS M2 Scaffold`.
It was authored and structurally checked on Windows, then included in the standalone export. No
successful GitHub Actions evidence existed when the export commit was prepared. Until an actual run
finishes successfully:

- **M2-CI: PENDING** — macOS cloud compilation is unproven.
- **M2-Simulator: PENDING** — simulator install, launch, markers, and retained logs are unproven.
- **M2-Device: BLOCKED (validation pending)** — no physical-device signing or connection route is
  available.
- **Overall M2: INCOMPLETE.**

GitHub Actions replaces the unavailable developer-owned Mac for unsigned compile and simulator
validation only. It does not replace a signed physical-iPad test.

## Triggers and runner

The workflow supports `workflow_dispatch`, pushes to `feature/ipados-native-port`, and pull requests
that change the iPadOS scaffold, documentation, or workflow. It uses the standard ARM64
`macos-15` GitHub-hosted runner, not a larger or self-hosted runner. The runner label is explicit so a
future `macos-latest` migration cannot silently change the operating-system generation. The job has
`contents: read`, a 45-minute timeout, and concurrency cancellation for older runs of the same ref.

For public repositories, GitHub documents standard hosted runners as free and unlimited. Private
repositories consume the account's included minutes and may incur charges after that allowance; do
not enable this workflow in a paid configuration without separate approval. Runner availability is
documented in the
[GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

The two official actions are pinned to immutable release commit SHAs. Checkout disables credential
persistence, global safe-directory changes, destructive workspace cleaning, submodules, and Git LFS.
It materializes only the reviewed iPadOS paths.

## What the workflow records

The environment step prints and retains:

```sh
uname -a
uname -m
sw_vers
xcode-select -p
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphonesimulator --show-sdk-version
cmake --version
python3 --version
git --version
```

The workflow also records Ruby because the runner's standard YAML parser checks the workflow file.
It then runs:

```sh
sh scripts/ios/verify-mac-environment.sh
sh scripts/ios/run-static-checks.sh
sh scripts/ios/generate-xcode-project.sh iphoneos
sh scripts/ios/generate-xcode-project.sh iphonesimulator
```

Both generated projects are inspected with `xcodebuild -list`; the application scheme is parsed from
the JSON form of that command instead of being guessed. `xcodebuild -showBuildSettings` and its JSON
form must prove product `Pyrogenesis iPad Shell`, iPad device family `2`, `arm64`, an empty
`DEVELOPMENT_TEAM`, and no entitlements file. Generated project text and linked products are scanned
for SDL, SpiderMonkey/mozjs, MoltenVK, OpenAL, engine data, and embedded Team IDs.

## Unsigned device-SDK compilation

The effective compile command uses the discovered project and scheme:

```sh
xcodebuild \
  -project "<actual iphoneos project>" \
  -scheme "<discovered application scheme>" \
  -configuration Debug \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "<runner temporary device directory>" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

This proves compiler, linker, UIKit, CMake, and device-SDK compatibility only. The resulting bundle is
unsigned, not installable as a normal physical-device build, and not M2-Device evidence. No
certificate, profile, Apple Account, Team ID, or provisioning update is required or permitted.

## Simulator selection, build, and smoke test

`scripts/ios/run-ci-simulator-smoke.sh` reads `simctl` JSON and selects an available iPad
deterministically, preferring an already booted device and then the newest installed iOS runtime. If
no available iPad exists, it creates one from an already installed iOS runtime and iPad device type.
It never downloads a runtime. A simulator created by the script is the only simulator the script may
delete during cleanup; an existing simulator is never deleted.

The simulator build uses the selected device name and OS version, the discovered scheme,
`iphonesimulator`, a temporary DerivedData directory, and signing disabled. The script then boots,
installs, and launches the app with `--m2-sandbox-probe`. The production UI and manual sandbox button
remain unchanged; that explicit diagnostic argument runs the same sandbox write/read-back operation
once automatically.

The smoke test succeeds only when all of the following are true:

- `simctl launch` returns a numeric process ID;
- the process remains alive for ten seconds;
- the launched process's unified log contains `M2_SHELL_LAUNCHED`;
- the same process log contains `M2_SANDBOX_PROBE_PASS`;
- it does not contain `M2_SANDBOX_PROBE_FAIL`;
- the application terminates cleanly through `simctl` after evidence collection.

Log filtering uses the launched process ID, so marker literals in source or workflow logs cannot create
a false pass. A screenshot is attempted and uploaded for human inspection, but its existence is not
reported as visual success. There is no documented, stable `simctl` command assumed for Home-button
background/foreground transitions; that subtest is recorded as `SKIP`, not `PASS`.

## Artifacts

One artifact named `ipados-m2-<run-id>-<attempt>` is uploaded with `if: always()` and retained for 14
days. Where execution reached the relevant stage, it contains:

- environment and macOS verifier reports;
- workflow-YAML and repository static-check reports;
- both CMake configure logs;
- `xcodebuild -list`, discovered schemes, build settings, and metadata validation;
- exact unsigned device and simulator build commands and full build logs;
- generated `Info.plist` files and human-readable plist dumps;
- linked-framework reports and product-path records;
- tar-compressed unsigned device-SDK and simulator `.app` bundles;
- sanitized simulator selection, launch, marker, liveness, and smoke-summary reports;
- a simulator screenshot when capture succeeds;
- the final M2-CI/M2-Simulator/M2-Device outcome summary.

The `.app` products are wrapped in `tar.gz` before upload so executable modes are preserved. Full
DerivedData, raw `simctl` JSON, simulator UUIDs, signing material, credentials, personal paths, Git
LFS objects, and game data are excluded.

## Reading results

Open **Actions > iPadOS M2 Scaffold**, select the run, then inspect the first failed step and download
the artifact from the run summary. Interpret checker lines literally:

- `PASS`: the named check actually completed and met its criterion.
- `WARN`: evidence exists but needs attention or human review.
- `FAIL`: a required criterion failed; the job must fail.
- `SKIP`: the check did not run and is never equivalent to `PASS`.

Use **Run workflow** to trigger `workflow_dispatch` after the branch exists on the selected GitHub
repository. Do not record M2-CI or M2-Simulator as passed until the run and retained evidence prove
their separate gates.

## Proof boundary

M2-CI can prove unsigned device-SDK compilation and isolated link metadata. M2-Simulator can prove an
iPad Simulator build, install, process launch, bounded liveness, and sandbox marker on the runner. It
does not prove signing, physical installation, real safe areas, touch ergonomics, thermal/memory
behavior, audio, graphics, engine startup, or distribution. Only a later legitimate physical-iPad
route can advance M2-Device. Git LFS game data remains unnecessary for all three M2 tracks.
