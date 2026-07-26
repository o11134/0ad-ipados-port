# M3 Thread Bootstrap (M3-C2)

## Overview

M3-C2 (`PyrogenesisThreadProbe`) is an isolated low-level runtime probe for upstream Pyrogenesis
main-thread registration, thread identity semantics, Apple thread naming, and debug filtering. It
reuses the accepted M3-C1 core library and adds only `source/ps/Threading.cpp` from pinned upstream.

## Scope

- Preserve the existing `PyrogenesisCoreProbe` target, markers, and workflow as the M3-C1 regression
  baseline.
- Compile and link an unsigned `iphoneos` arm64 product.
- Compile, link, install, launch, validate, and terminate an `iphonesimulator` arm64 product.
- Exclude Profiler2, GameSetup, EarlyInit, VFS, SDL, SpiderMonkey, renderer, audio, and networking.

## Current Status

- **M3-C2: IN PROGRESS / NOT VERIFIED.** Local implementation is pending static validation and the
  dedicated `iPadOS M3 Thread Bootstrap` GitHub Actions result.
- **M3-D / Full Engine Runtime: NOT STARTED.** Physical iPad execution is **NOT TESTED**.
