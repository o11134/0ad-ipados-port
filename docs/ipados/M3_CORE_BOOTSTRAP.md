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

- **M3-C1**: IN PROGRESS / NOT VERIFIED (scaffold authoring complete; awaiting GitHub Actions CI verification).
