# iPadOS dependency inventory

## Evidence and reproducibility status

Versions come from `libraries/build-macos-libs.sh:23-52` and the individual
`libraries/source/*/build.sh` files at revision `eae57d9aab66511a22a869192b7ec72feeaedc7a`.
Licenses come from `libraries/LICENSE.txt` where listed; every transitive license must be rechecked
against the actual source archive before distribution.

No iPadOS dependency build command is claimed working. No archive was downloaded in this session,
and the current scripts perform no SHA/checksum verification. Their `.already-built` stamps contain
only a version, so they cannot distinguish macOS from iPhoneOS, device from simulator, compiler, SDK,
or interpreter/JIT mode. `libraries/ios/` reserves isolated, ignored build/output roots.

Status vocabulary:

- **Upstream iOS route**: upstream documents an iOS target, but this exact pin is not built here.
- **Portable candidate**: source is likely targetable, but this repository has no iOS proof.
- **Host only**: omit from the application and run on the Mac during staging/build.
- **Critical proof**: must pass a source audit and physical-device test before integration.

## Runtime and core matrix

| Dependency | Version | Existing build | Runtime/build-time | Simulator status | Device status | Link strategy | Required patch/config | License | Exact source used by current script | Reproducible iPad command |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SDL2 | 2.24.0 | Cocoa configure | Runtime window/input | Upstream route; not built | Upstream route; not built | Static XCFramework/library | UIKit target, lifecycle/main, no shared objects | zlib | [SDL2-2.24.0.tar.gz](https://libsdl.org/release/SDL2-2.24.0.tar.gz) | Not implemented¹ |
| MoltenVK | 1.3.0 | mac-only Xcode/dylib | Runtime Vulkan bridge | Upstream route; not built | Critical GPU proof | Static XCFramework | iOS package, portability extensions, feature probe | Apache-2.0; verify notices | [v1.3.0.tar.gz](https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v1.3.0.tar.gz) | Not implemented¹ |
| SpiderMonkey | 128.13.0+wfg5 | WFG mozbuild/Rust | Runtime JavaScript | Critical; not built | Critical; not built | Static C++/Rust archives | Exact no-JIT/no-exec-memory iOS config and assertion | MPL/GPL/LGPL | [mozjs-128.13.0.tar.xz](https://releases.wildfiregames.com/libs/mozjs-128.13.0.tar.xz) | Not implemented¹ |
| zlib | 1.3.1 | configure | Runtime compression | Portable candidate | Portable candidate | Static | SDK/target-qualified build | zlib | [zlib-1.3.1.tar.gz](https://zlib.net/fossils/zlib-1.3.1.tar.gz) | Not implemented¹ |
| libpng | 1.6.44 | configure | Runtime images | Portable candidate | Portable candidate | Static | no host paths; separate slices | libpng | [libpng-1.6.44.tar.gz](http://download.sourceforge.net/libpng/libpng-1.6.44.tar.gz) | Not implemented¹ |
| FreeType | 2.13.3 | CMake | Runtime fonts | Portable candidate | Portable candidate | Static | iOS target; audit optional deps | FreeType/GPL; verify | [freetype-2.13.3.tar.gz](https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.gz) | Not implemented¹ |
| libxml2 | 2.13.5 | CMake/configure | Runtime XML | Portable candidate | Portable candidate | Static | disable network/modules/dlopen where possible | MIT | [libxml2-2.13.5.tar.xz](https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz) | Not implemented¹ |
| Boost | 1.81.0 | bootstrap/b2 | Runtime headers/libs | Portable candidate | Portable candidate | Headers/static used libs | cross-build only required components | Boost | [boost_1_81_0.tar.bz2](https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.bz2) | Not implemented¹ |
| ICU | 69.1 | host + cross configure | Runtime Unicode/i18n | Complex; not built | Complex; not built | Static data/libs | build host tools then iOS; package data | MIT-X11 | [icu4c-69_1-src.tgz](https://github.com/unicode-org/icu/releases/download/release-69-1/icu4c-69_1-src.tgz) | Not implemented¹ |
| libiconv | 1.17 | configure | Runtime encoding | Decision pending | Decision pending | Prefer system API or static | prove whether Apple iconv suffices | LGPL-2.0+ | [libiconv-1.17.tar.gz](http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz) | Not implemented¹ |
| fmt | 7.1.3 | CMake | Runtime formatting | Portable candidate | Portable candidate | Static/header mode | preserve upstream mode, SDK-qualified | MIT | [7.1.3.tar.gz](https://github.com/fmtlib/fmt/archive/7.1.3.tar.gz) | Not implemented¹ |
| libsodium | 1.0.20 | configure | Runtime crypto | Portable candidate | Portable candidate | Static | iOS configure and symbol audit | ISC | [libsodium-1.0.20.tar.gz](https://download.libsodium.org/libsodium/releases/libsodium-1.0.20.tar.gz) | Not implemented¹ |
| ENet | 1.3.18 | CMake/configure | Runtime network | Deferred/disabled | Deferred/disabled | None initially; static later | offline flag; sockets/IPv6 review later | MIT | [enet-1.3.18.tar.gz](http://enet.bespin.org/download/enet-1.3.18.tar.gz) | Not implemented¹ |
| curl | 7.71.0 | configure | Runtime HTTP | Deferred/disabled | Deferred/disabled | None initially; static if proven needed | offline flag; TLS/IPv6 policy | MIT | [curl-7.71.0.tar.bz2](http://curl.haxx.se/download/curl-7.71.0.tar.bz2) | Not implemented¹ |
| OpenAL Soft | 1.24.2 | CMake | Runtime audio | Not built | Physical audio proof | Static | iOS backend, no modules, `AVAudioSession` | LGPL-2.0+ | [1.24.2.tar.gz](https://github.com/kcat/openal-soft/archive/refs/tags/1.24.2.tar.gz) | Not implemented¹ |
| libogg / libvorbis | 1.3.5 / 1.3.7 | configure | Runtime audio decode | Portable candidates | Portable candidates | Static | cross-build fixed inputs | BSD | [libogg](http://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz), [libvorbis](http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz) | Not implemented¹ |
| miniupnpc | 2.2.8 | CMake/make | Runtime NAT | Deferred/disabled | Deferred/disabled | None initially | preserve behind offline flag | BSD | [miniupnpc-2.2.8.tar.gz](http://miniupnp.free.fr/files/miniupnpc-2.2.8.tar.gz) | Not implemented¹ |
| gloox | 1.0.28 | configure | Runtime lobby/XMPP | Deferred/disabled | Deferred/disabled | None initially | omit lobby initialization | GPLv3 | [gloox-1.0.28.tar.bz2](https://releases.wildfiregames.com/libs/gloox-1.0.28.tar.bz2) | Not implemented¹ |
| GnuTLS / GMP / Nettle | 3.8.4 / 6.3.0 / 3.10 | configure | Runtime lobby/TLS chain | Deferred/disabled | Deferred/disabled | None initially | omit chain unless later required | mixed GPL/LGPL; verify | [GnuTLS](https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.4.tar.xz), [GMP](https://gmplib.org/download/gmp/gmp-6.3.0.tar.bz2), [Nettle](https://ftp.gnu.org/gnu/nettle/nettle-3.10.tar.gz) | Not implemented¹ |

¹ The missing command is an explicit future dependency-build gap, not a successful build claim. It will be added only
after an HTTPS URL/SHA-256 lock entry and target-specific configuration have been reviewed. The
current HTTP links are recorded as audited facts, not approved future download sources.

## Build-time and vendored matrix

| Dependency | Version | Existing build / role | Simulator | Device | iPad strategy | License | Source URL | Reproducible command status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Premake core | `55fc4b2deac045ca06dc23d98426423356c507c1+wfg0` | Host workspace generator | Host-only | Host-only | Keep desktop generator; CMake only for isolated probes | verify source notice | [pinned archive](https://github.com/premake/premake-core/archive/55fc4b2deac045ca06dc23d98426423356c507c1.tar.gz) | Existing host `libraries/source/premake-core/build.sh`; not run |
| CMake | >=3.25 | Host Xcode generator | Host-only | Host-only | Never bundle | CMake upstream | [cmake.org](https://cmake.org/download/) | Installed-host `cmake`; unavailable here |
| CxxTest | 4.4+wfg1 | Host unit-test generation | Tests may run later | Not bundled | Reuse for pure C++ tests | LGPLv3 | [cxxtest-4.4.tar.gz](https://github.com/CxxTest/cxxtest/releases/download/4.4/cxxtest-4.4.tar.gz) | Existing host `libraries/source/cxxtest-4.4/build.sh`; not run |
| FCollada | SVN r28209+wfg1 | Host DAE conversion | Host-only | Omit | Preconvert; never device `dlopen` | MIT | [official WFG SVN pin](https://svn.wildfiregames.com/public/source-libs/trunk/fcollada@28209) | Existing host `libraries/source/fcollada/build.sh`; not run |
| NVTT | SVN r28209+wfg4 | Host texture conversion | Host-only | Omit | Preconvert textures | MIT | [official WFG SVN pin](https://svn.wildfiregames.com/public/source-libs/trunk/nvtt@28209) | Existing host `libraries/source/nvtt/build.sh`; not run |
| cpp-httplib | 0.30.1+wfg0 | Runtime DAP HTTP interface | Omit initially | Omit initially | Disable DAP/offline-unneeded route | MIT | [v0.30.1.tar.gz](https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.30.1.tar.gz) | No iPad command; existing host script not run |
| SPIRV-Reflect | 1.3.290.0 | Optional reflection | Host preferred | Only if proved necessary | Prefer host tool | Apache-2.0 | [vulkan-sdk-1.3.290.0](https://github.com/KhronosGroup/SPIRV-Reflect/archive/refs/tags/vulkan-sdk-1.3.290.0.tar.gz) | No iPad command; existing host script not run |
| glslc | unpinned | Host SPIR-V compiler | Host-only | Omit | **Pin before staging** | not inventoried | URL not recorded by repo | No reproducible command |
| SPIR-V Tools | README asks 2023+ | Host shader validation | Host-only | Omit | Exact version required | not inventoried | URL not recorded by repo | No reproducible command |
| GLAD/Vulkan headers | generator 2.0.8; header 1.4.329 | Vendored API declarations | Not compiled | Not compiled | Compile source; regenerate portability enumeration | Apache-2.0 / WTFPL-or-CC0 | generator source URL not recorded in repo | No separate build command |
| VMA | 3.0.1 | Vendored Vulkan allocator | Not compiled | Not compiled | Header implementation in renderer | MIT upstream; verify notice | exact vendored source URL not recorded | No separate build command |
| wxWidgets | 3.2.8 | Host Atlas editor | Omit | Omit | Atlas excluded from iPad | wxWindows | [wxWidgets-3.2.8.tar.bz2](http://github.com/wxWidgets/wxWidgets/releases/download/v3.2.8/wxWidgets-3.2.8.tar.bz2) | Existing mac host script; not run |
| tinygettext/jsonspirit/mikktspace/ogre preprocessor | revisions not recorded | Vendored helpers | Unknown | Unknown | Audit actual link closure | mixed/verify | exact URLs not recorded | Not reproducible |

## Required deterministic layout

Generated and ignored paths:

```text
libraries/ios/downloads/
libraries/ios/build/device/
libraries/ios/build/simulator/
libraries/ios/output/device/
libraries/ios/output/simulator/
libraries/ios/output/xcframeworks/
```

Before `build-ios-deps.sh` is implemented, create a reviewed lock manifest containing dependency,
exact version/tag, canonical HTTPS URL, SHA-256, license file path, patch hashes, target triple, SDK
version, deployment target, compiler version, configuration, and output hash. Reject HTTP redirects to
unapproved hosts. Stamps must hash that full build identity.

Required targets are `arm64-apple-ios` and, where upstream permits it,
`arm64-apple-ios-simulator`. Intel simulator support is not a first objective. No Homebrew library
path, macOS archive, personal SDK path, dylib copied from a local machine, or unsigned framework may
enter the generated project.

## Reproducible command status

There is currently **no reviewed iPadOS dependency build command**. M2 needs no third-party
dependency and no LFS/runtime data, so do not download the approximately 6.52 GB data set for the
shell. The next safe command is inspection, not dependency compilation:

```sh
sh scripts/ios/verify-mac-environment.sh
```

After official sources and hashes are approved, implement one dependency at a time with a
`--download-only`, `--verify-only`, device, simulator, and XCFramework mode. SpiderMonkey must remain
a separate critical track rather than being hidden in a bulk build script.
