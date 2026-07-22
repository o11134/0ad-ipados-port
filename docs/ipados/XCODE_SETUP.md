# Xcode setup for the empty iPad shell

This is the **deferred manual M2-Device path** for the isolated UIKit shell. It does not build the
engine, SDL, SpiderMonkey, MoltenVK, audio, or game data. Do not perform its signing/account/device
steps during the present unsigned CI task.

## Current CI path

`.github/workflows/ipados-m2.yml` is the current route for M2-CI and M2-Simulator; see
`GITHUB_ACTIONS.md`. It runs on the standard ARM64 `macos-15` runner, discovers generated schemes,
uses `CODE_SIGNING_ALLOWED=NO`, dynamically selects an installed iPad simulator, and evaluates
launch/sandbox markers. Both tracks remain pending until a successful retained run proves them.
Signing, Apple Accounts, certificates, profiles, and Team IDs are unnecessary and prohibited in that
workflow.

## 1. Verify a future physical-device Mac

Use an Apple Silicon Mac with the current stable Xcode and iPadOS SDK. Select Xcode's command-line
tools in Xcode settings if needed, then run from the repository root:

```sh
sh scripts/ios/verify-mac-environment.sh
sh scripts/ios/run-static-checks.sh
```

The first script performs inspection-only host, Apple Silicon, Xcode/license, SDK, Git, CMake,
Python, disk, project-file, and data-presence checks. It never installs software or changes global
configuration. Record its `PASS/WARN/FAIL/SKIP` summary. Git LFS data is not required for M2; do not
hydrate the approximately 6.52 GB source data set.

## 2. Generate and open the project

```sh
bash scripts/ios/generate-xcode-project.sh iphoneos
open build/ios/out/iphoneos/PyrogenesisIPadShell.xcodeproj
```

Generated files live under ignored `build/ios/out/`. Regenerate them instead of committing them.
The default product name is `Pyrogenesis iPad Shell`, bundle identifier is
`org.example.pyrogenesis.ipadshell`, deployment target is iPadOS 17.0, device family is iPad,
architecture is ARM64, and Mac Catalyst is disabled. These are configured values, not build proof.

To use a unique local identifier or a newer minimum version:

```sh
IPADOS_BUNDLE_IDENTIFIER=org.example.pyrogenesis.ipadshell \
IPADOS_PRODUCT_NAME="Pyrogenesis iPad Shell" \
IPADOS_DEPLOYMENT_TARGET=17.0 \
bash scripts/ios/generate-xcode-project.sh iphoneos
```

Use an identifier under a namespace you control for device signing. Do not commit that identifier if
it identifies a person or organization. Never write a Development Team ID into a tracked file.

## 3. Select signing locally only for an authorized M2-Device session

1. In Xcode, select the `PyrogenesisIPadShell` project and application target.
2. Open **Signing & Capabilities**.
3. Leave **Automatically manage signing** enabled.
4. Select a local Apple Development Team. Xcode may use a personal Apple Account or a Developer
   Program team.
5. Resolve bundle-identifier conflicts locally; do not change upstream branding or imply endorsement.

Xcode's current documented flow is to sign in under **Xcode > Settings > Apple Accounts**, select a
team, and let automatic signing register the device/profile. See
[Running your app on simulated or physical devices](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices).

## 4. Connect and prepare an iPad only for M2-Device

1. Connect the unlocked iPad to the Mac by cable and accept **Trust This Computer** if shown.
2. Select the iPad in Xcode's Device Hub/run-destination menu and allow pairing to complete.
3. If requested, open **Settings > Privacy & Security > Developer Mode** on the iPad, enable it,
   restart, confirm **Enable**, and enter the device passcode.
4. Reconnect/unlock the device and wait for Xcode to finish preparing symbols/support files.

Developer Mode appears after pairing has begun. Apple's current steps are documented in
[Enabling Developer Mode on a device](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

## 5. Build, install, and exercise M2-Device

Select the `PyrogenesisIPadShell` scheme and physical iPad, then choose **Product > Run**. A valid M2
test must capture all of the following, not just a successful compile:

- the dark landscape shell and `Pyrogenesis iPad Shell` title are visible;
- app name, build type, source revision, ARM64, target environment, OS version, screen/view points,
  native scale, safe-area insets, scene state, lifecycle state/event, and memory count are visible;
- both landscape orientations obey the policy and safe-area content remains visible;
- logs contain `launch revision=... architecture=arm64 environment=iPadOS device`;
- distinct connect, active, inactive, background, foreground, size, and scene-disconnect events are
  observed in logs and the visible lifecycle fields update;
- a memory-warning event, if Xcode can simulate one for the selected destination, is logged;
- **Run Sandbox Read/Write Test** visibly returns `PASS` after an atomic Application Support
  write/read-back; `FAIL` is an M2 failure and its non-sensitive domain/code must be recorded;
- the app performs no engine, network, audio, or graphics-backend initialization.

The command-line convenience build is:

```sh
bash scripts/ios/build-device.sh
```

It deliberately fails before generation unless the local shell already contains
`IPADOS_DEVELOPMENT_TEAM` and a non-default `IPADOS_BUNDLE_IDENTIFIER`. This avoids pretending the
placeholder identifier is signable and avoids losing a Team selected manually when CMake regenerates
the project. If signing needs Xcode to update profiles, the operator may explicitly set
`IPADOS_ALLOW_PROVISIONING_UPDATES=1`; the default does not grant that behavior. Preserve the exact
failure in `DEVICE_TEST_LOG.md`; do not disable signing to claim M2-Device. Disabling signing is
separately correct and required for the unsigned M2-CI compile.

## Simulator

The automated M2-Simulator route is `scripts/ios/run-ci-simulator-smoke.sh`, invoked by GitHub
Actions. It discovers an available iPad from `simctl` JSON, creates one only from an installed runtime
when necessary, launches with the explicit sandbox diagnostic mode, and requires
`M2_SHELL_LAUNCHED` plus `M2_SANDBOX_PROBE_PASS` for the launched PID. It does not assume a supported
background/foreground `simctl` command and never converts that skip into a pass.

For a future interactive simulator session:

```sh
bash scripts/ios/build-simulator.sh
open build/ios/out/iphonesimulator/PyrogenesisIPadShell.xcodeproj
```

Select an ARM64 iPad simulator and use **Product > Run**. Label all results `Simulator`; they do not
satisfy physical-device acceptance for rendering, JavaScript, audio, touch latency, memory, thermal,
or performance behavior. A CI screenshot is an artifact for human review and is not automatic visual
proof.

## Logs and failure capture

When launched from Xcode, copy the debug-console lines beginning `[Pyrogenesis iPadOS]`. For an
installed app, use **Window > Devices and Simulators** (or Device Hub in newer Xcode), select the iPad,
open its console, and filter by that prefix. Record:

- `sw_vers`, `uname -m`, `xcodebuild -version`, and `xcrun --sdk iphoneos --show-sdk-version`;
- source revision, configuration, bundle identifier with personal portions redacted, and device class;
- the first compiler/link/signing error exactly;
- whether the result is host-only, simulator, or physical device;
- screenshot file name without committing device identifiers or personal metadata.

## Change the deployment target

Regenerate rather than hand-editing generated project settings:

```sh
IPADOS_DEPLOYMENT_TARGET=17.0 bash scripts/ios/generate-xcode-project.sh iphoneos
```

Do not lower it until every linked dependency's deployment target and required API are verified.

## Remove the app and data

Long-press the app on the iPad, choose **Remove App**, then **Delete App**. This deletes the entire app
sandbox, including future saves/configuration. Xcode's device management UI can also uninstall the
app. Deleting DerivedData or `build/ios/out` removes Mac-side build output only and must never be
confused with preserving on-device user data.
