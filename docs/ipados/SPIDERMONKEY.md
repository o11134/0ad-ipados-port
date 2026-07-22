# SpiderMonkey 128 interpreter-only proof track

## Status: critical, unproven

The audited engine requires SpiderMonkey major version 128
(`source/scriptinterface/Engine.h:27-32`). `libraries/source/spidermonkey/build.sh:8-13` pins the WFG
source to `128.13.0+wfg5` and library name `mozjs128`. No iPadOS build has been attempted, the Mozilla
source archive is absent, and no physical-device JavaScript test exists.

No configure flag is proposed as fact in this document. The exact WFG source must be inspected first;
flags remembered from another Firefox/SpiderMonkey release are not acceptable evidence.

## Current configuration and engine assumptions

`libraries/source/spidermonkey/mozconfig` currently selects:

```text
--enable-project=js
--enable-shared-js
--disable-jemalloc
--without-intl-api
--disable-js-shell
--disable-tests
```

It contains no documented no-JIT setting. Debug adds debug/GC zeal and disables optimization; Release
enables optimization in `libraries/source/spidermonkey/build.sh:158-176`. The macOS branch targets
`aarch64-apple-darwin`, not `arm64-apple-ios`, at `:124-144`.

The engine then explicitly enables JIT facilities:

- `JS_SetOffthreadIonCompilationEnabled(..., true)` in
  `source/scriptinterface/Context.cpp:141`;
- `JSJITCOMPILER_ION_ENABLE = 1` at `Context.cpp:148`;
- `JSJITCOMPILER_BASELINE_ENABLE = 1` at `Context.cpp:149`.

JavaScript is compiled/evaluated from readable source through SpiderMonkey APIs in
`source/scriptinterface/Interface.cpp:658-767`; no engine-side dependency on a native bytecode cache
was found. That makes an interpreter route plausible, but does not prove the runtime compiles or
performs acceptably without JIT.

## What must be determined from the exact source

After downloading the canonical WFG archive to ignored `libraries/ios/downloads/`, record its
SHA-256, archive URL/redirect chain, and applied WFG patches. Inspect that source's own `mach configure
--help`, `js/moz.configure`, platform definitions, Rust targets, and executable allocator code to
answer:

1. Which exact build options disable Ion, Baseline, native code generation, and WebAssembly if
   WebAssembly can allocate executable code?
2. Do those options compile the relevant JIT directories out or only change defaults?
3. Which allocator/source paths can request `PROT_EXEC`, `MAP_JIT`, `mprotect`, or writable/executable
   memory, and are they absent/unreachable in the product?
4. Which exact target/host triples and Rust standard-library target are accepted for device and ARM64
   simulator?
5. Which signal handling, process spawning, profiler, crash reporter, shared-library, and ICU hooks
   remain on iOS?
6. Does `--enable-shared-js` need replacement with a static-only supported mode, and what exported
   archive set results?

Useful source-audit commands on the extracted exact archive (these inspect; they do not assert flags):

```sh
./mach configure --help
rg -n "ExecutableAllocator|PROT_EXEC|MAP_JIT|mprotect|mmap|Ion|Baseline|Wasm|dlopen|fork|posix_spawn" .
rg -n "disable.*jit|enable.*jit|jit.*configure|wasm.*configure" js python build moz.configure
```

Preserve the complete help output and relevant configure source in the build log. Do not copy a
configuration from current Firefox documentation without matching the pinned tree.

## Required build identity

The future output/stamp key must include at least:

- source SHA-256 and WFG patch hashes;
- device or simulator target triple;
- Xcode, Apple Clang, SDK, deployment target, CMake/mozbuild, Python, Rust, Cargo, and cbindgen versions;
- Debug/Release and all interpreter/JIT/Wasm/intl/jemalloc/shared/static settings;
- final archive/header hashes.

Store results separately under `libraries/ios/output/device/` and
`libraries/ios/output/simulator/`. Never reuse `libraries/macos` or the existing version-only
`.already-built` stamp. Link only static products or a properly constructed static XCFramework; no
`dlopen` runtime component is allowed.

## Engine integration policy

Add a compile-time capability such as `CONFIG2_JS_JIT` only after the library exposes a proven build
state. Desktop defaults remain unchanged. For iPadOS:

- do not call the current off-thread Ion enable function;
- set any still-present runtime JIT options off as defense in depth;
- assert a build-derived interpreter-only macro/capability before evaluating game code;
- abort startup with an explicit diagnostic if the linked library can enable JIT;
- bundle game JavaScript read-only and never fetch or update it remotely.

Runtime options alone are not proof because executable allocators/native compilers may still be in
the binary.

## Isolated validation target acceptance

Before linking the engine, a small signed physical-iPad target must:

1. call `JS_Init`;
2. create the runtime/context using the same API family as `ScriptInterface`;
3. evaluate a bundled expression such as `21 * 2` and log `42`;
4. log the build-derived fact that Ion, Baseline, Wasm native compilation, and executable memory are
   disabled;
5. force garbage collection and destroy all contexts;
6. call `JS_ShutDown` and exit/return to the shell cleanly;
7. repeat after background/foreground and under a memory warning.

The target and build command do not exist yet. Add them only after the exact source configuration is
known; until then M4 is `NOT RUN`.

## Binary and device audit

For the produced app/archive, retain outputs from commands available on the Mac such as:

```sh
file path/to/product
lipo -info path/to/product
otool -L path/to/app-executable
nm -m path/to/app-executable
codesign -d --entitlements :- path/to/app.app
```

Search symbols/source for JIT and executable allocators, inspect load commands for unexpected dylibs,
and ensure entitlements do not include macOS's
`com.apple.security.cs.allow-unsigned-executable-memory`. A symbol search is supporting evidence, not
a mathematical proof; combine it with configuration/source audit and physical-device execution.

## Failure record template

For the first failure, capture exact source revision/hash, configure command, target triple, compiler,
first error, source file/line, smallest patch, whether desktop behavior changes, and upstreamability.
If exact 128.13.0+wfg5 cannot build without executable native generation, record a NO-GO for this
runtime and request explicit approval before evaluating a replacement such as JavaScriptCore.
