# M2 CI, simulator, and physical-device test log

## Test record policy

Append one record per build/environment. Do not overwrite failures. Do not include UDID, serial number,
Apple account, Team ID, provisioning profile, certificate, personal path, or token. A device class
such as `M1 iPad Pro` is sufficient. Attach screenshots/logs outside Git if they contain personal
metadata and record only a neutral file name/hash here.

## Historical port-source session 2026-07-22

| Field | Value |
| --- | --- |
| Audited upstream base | `eae57d9aab66511a22a869192b7ec72feeaedc7a` |
| Scaffold commit | `27c6c602019a3744581ea71d119b62a379b12e10` |
| Branch | `feature/ipados-native-port` |
| Host | Windows x64 `10.0.26200.0` |
| Xcode / SDK | unavailable |
| Target | none |
| Configuration | none |
| Simulator | **NOT RUN** |
| Physical iPad | **NOT RUN** |
| Build | **NOT RUN** for iPadOS |
| Signing/install/launch | **NOT RUN** |
| GitHub workflow | Prepared before standalone export; **NOT RUN IN THIS RECORD** |
| GitHub run URL / ID | none |
| M2-CI | **PENDING** |
| M2-Simulator | **PENDING** |
| M2-Device | **BLOCKED (validation pending)** |
| Result | Scaffold and CI source exported; no run evidence in this record; overall M2 incomplete |

No screenshot, device log, performance sample, rendering result, JavaScript result, audio result, or
touch result exists.

## Record template

```text
Date/time and timezone:
Audited upstream base / tested commit / dirty status:
Workflow name / run ID / run URL:
Host macOS / architecture:
Runner label / runner image:
Xcode / Apple Clang / iPadOS SDK:
Target: CI-macOS-ARM64, Simulator-iPad-ARM64, or Physical-iPad-ARM64
Simulator name/runtime or physical device class/chip/iPadOS (no identifier):
Configuration / deployment target:
Bundle identifier (redact personal namespace if needed):
Actual project / discovered scheme:
Exact configure/build/launch commands and exit codes:
Signing result:
Install/launch result:
M2_SHELL_LAUNCHED evidence:
M2_SANDBOX_PROBE_PASS/FAIL evidence:
Process-liveness interval:
Expected visible result:
Actual visible result:
Visible app/build/arch/OS/screen/scale/insets/scene/lifecycle fields:
Sandbox read/write visible result:
Lifecycle sequence and logs:
Safe-area / drawable size:
Memory-warning result:
First exact warning/error:
Screenshot/log neutral name and SHA-256:
Artifact name / retention / digest when available:
Tests passed:
Tests failed:
Not implemented/not run:
Performance measurements (if applicable):
Next exact action:
```

## M2 device checklist

- [ ] Signed application installed on a physical iPad.
- [ ] Landscape `Pyrogenesis iPad Shell` title and safe-area content visible.
- [ ] App, build type, revision, `arm64`, OS, screen/view points, native scale, and insets visible.
- [ ] Scene state, lifecycle state/event, and memory-warning count visibly update.
- [ ] Scene connect, active, inactive, background, foreground, and disconnect logged.
- [ ] View-size changes logged in both landscape orientations.
- [ ] Safe-area values logged in both landscape orientations.
- [ ] Memory warning handled/logged.
- [ ] Sandbox button writes, reads back, and visibly reports `PASS`.
- [ ] No engine/SDL/MoltenVK/SpiderMonkey/audio/network initialization.
- [ ] App remains responsive after three background/foreground cycles.
- [ ] App removal/data behavior recorded.

All boxes remain unchecked until a physical-device log proves them.
