# M3 Core Bootstrap (M3-C1)

## Overview

M3-C1 (`PyrogenesisCoreProbe`) is the minimal Pyrogenesis core bootstrap target. It verifies that a real, low-level C++ subsystem from upstream 0 A.D. (`source/lib/timer.cpp` and `source/lib/module_init.cpp`) compiles, links, installs, launches, and executes on the iPad Simulator without importing desktop frameworks, SDL, SpiderMonkey, or renderer dependencies.

## Architecture

- **Static Library Target**: `PyrogenesisCoreIOS` (`build/ios/core/CMakeLists.txt`)
- **Upstream Sources**:
  - `source/lib/timer.cpp`
  - `source/lib/module_init.cpp`
- **Probe Executable Target**: `PyrogenesisCoreProbe` (`source/platform/probe/CoreProbe.mm`)
- **Bundle Identifier**: `org.example.pyrogenesis.core-probe`

## Executed Upstream Functions

- `timer_Init()`
- `timer_Time()`
- `timer_Resolution()`

## Current Status

- **M3-C1: PASS.** GitHub Actions run
  [`30184571646`](https://github.com/o11134/0ad-ipados-port/actions/runs/30184571646) verified
  implementation commit `bc9c1ec53b5fa2fac7bbbfa67bd32e8c9cecd992` against pinned upstream
  `eae57d9aab66511a22a869192b7ec72feeaedc7a`.
- Unsigned `iphoneos` arm64 and `iphonesimulator` arm64 both compiled and linked successfully with
  Xcode 16.4 / SDK 18.5. The final app load commands and undefined-symbol reports were clean: only
  Foundation, UIKit, and Apple system runtimes were linked, with no SDL, SpiderMonkey, renderer,
  audio, networking, or other later-stage dependency leakage.
- The probe installed and launched on an iPad Pro 11-inch (M4), iOS 18.5 simulator. It reported
  `M3_CORE_BOOTSTRAP_STARTED`, `M3_TIMER_TIME_0=0.000002`, `M3_TIMER_TIME_1=0.012023`,
  `M3_TIMER_RESOLUTION=0.000001000`, `M3_TIMER_INIT_PASS`, and `M3_CORE_BOOTSTRAP_PASS`.
- **Scope boundary:** M3-C2, M3-D, and the Full Engine are **NOT STARTED**. Physical iPad execution
  is **NOT TESTED**; the `iphoneos` result is an unsigned device-SDK compile/link result only.
