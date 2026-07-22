# iPadOS data and sandbox layout

## Current engine behavior

`source/ps/GameSetup/Paths.h:42-88` exposes root data, game data, user data, config, cache, and logs.
`source/ps/GameSetup/Paths.cpp:107-146` maps desktop macOS support/cache roots, while `:210-220`
recognizes a mac app's `Resources/data`. `source/ps/GameSetup/GameSetup.cpp:211-222` mounts config,
cache, screenshots, saves, and localization. There is no iOS sandbox policy.

The development `-writableRoot` route at `Paths.cpp:54-62` collapses paths under `root/data`; it must
be rejected/ignored on iOS because the installed app bundle is read-only.

## Proposed mapping

| Engine purpose | iPadOS root | Policy |
| --- | --- | --- |
| `RData`, engine/base/public built-ins | `<App>.app/Resources/data/` | Read-only, signed bundle |
| Internal `GameData` and indexes | `Library/Application Support/0ad/data/` | Persistent, not user-facing |
| Config/settings | `Library/Application Support/0ad/config/` | Persistent; atomic writes |
| Saves | `Documents/0 A.D. Touch/Saves/` | User-visible/persistent |
| Replays | `Documents/0 A.D. Touch/Replays/` | Separate from saves |
| Exports/screenshots | `Documents/0 A.D. Touch/Exports/` | User-visible; Files integration later |
| Derived shaders/thumbnails/cache | `Library/Caches/0ad/` | Rebuildable; safe to purge |
| Temporary extraction/write | `NSTemporaryDirectory()` | Unique, short-lived, never executable |
| Logs | Apple unified log; optional diagnostics in Caches | No secrets/device identifiers |
| User mods | Disabled in MVP | Separate review; data/JS only, no native code |

Do not simply set all `UserData` to Documents: that would expose config, internal indexes, and future
mods unnecessarily. Extend the path abstraction with explicit save/replay/export/temp purposes or a
narrow iOS mapping without duplicating the rest of VFS.

## Official data state

The Git tree contains 28,292 paths under `binaries/data`, including 27,556 under `mods/public`.
`git lfs ls-files --json` reports 15,718 LFS objects totaling about 6.52 GB of source object sizes;
`public` accounts for about 6.45 GB and `mod` about 65 MB. These are source/LFS sizes, not a packaged
app size.

The current sparse checkout excludes `binaries`, so none of the menu, map, font, texture, audio,
localization, shader-source, or model data is locally verified. The tree has official `mod` and
`public` mods, but generated Vulkan SPIR-V is not tracked. Do not claim a map/menu works until data is
hydrated and a VFS manifest test passes.

## Packaging route

Reusable evidence:

- `GameSetup.cpp:159-189` mounts built-in and user mods; built-in wins over an identically named user
  mod.
- `source/ps/Mod.cpp:157-182` always adds `mod` and optionally `public`.
- `source/lib/file/vfs/vfs_populate.cpp:120-136` mounts ZIP contents.
- `source/tools/dist/build-archives.sh:40-48` uses desktop Pyrogenesis to produce a mod ZIP and copies
  `mod.json` beside it.
- `source/ps/ArchiveBuilder.cpp:67-176` performs texture/font/model/XMB conversion during packaging.
- `source/graphics/ColladaManager.cpp:68-218` dynamically loads Collada for runtime conversion; this
  must not occur on iPad.

The first deterministic staging process, not yet implemented, must:

1. require an exact official source revision and hydrate only its official LFS objects;
2. record every input object hash and license/credit file;
3. run FCollada/NVTT/XMB and shader compilation as signed Mac host tools, never on the iPad;
4. pin `glslc`, SPIR-V Tools, scripts, options, and output hashes;
5. place `mod.json` sidecars outside ZIPs so runtime never attempts to write them into the bundle
   (`source/ps/Mod.cpp:67-104`);
6. generate a sorted bundle manifest with size and SHA-256;
7. reject absolute paths, `..`, case-collisions, symlinks escaping staging, native binaries, and
   unexpected extensions;
8. copy only verified results to the read-only resource bundle;
9. run menu and selected-map dependency checks on the staged tree;
10. keep all large/generated output ignored by Git.

No staging script is provided yet because the LFS data and exact shader toolchain were not available.
The first complete build should package official `mod` + `public` and measure it. A reduced POC subset
is acceptable only after an automated dependency manifest proves the menu and chosen official map
closure.

## Path safety and Unicode blockers

`VfsPath` is only a `Path` typedef (`source/lib/file/vfs/vfs_path.h:31-43`). VFS lookup constructs
components literally and has no demonstrated `..` rejection
(`source/lib/file/vfs/vfs_lookup.cpp:90-131`). Save/load/delete names flow from JavaScript without
central validation (`source/ps/SavedGame.cpp:81-87,233-238,333-349`). Before any import or user mod,
reject absolute paths, separators, empty/`.`/`..` components, NUL/control characters, and confirm the
canonical final path remains below its sandbox root.

On non-Windows, `OsPath` narrows wide characters to bytes and enforces an 8-bit range
(`source/lib/os_path.h:34-57`, `source/lib/path.cpp:102-110`). An Arabic physical file name is not
currently safe. A temporary design may use an ASCII/UUID disk identifier plus a UTF-8 Arabic display
name in metadata, but that does **not** pass the required Arabic-filename test. The long-term fix must
represent Darwin/Unix native paths as UTF-8 bytes or a proven filesystem abstraction without lossy
wide-to-byte conversion.

## Atomic writes

`SavedGames::Save` uses fixed `cache/temp.0adsave`, loads the ZIP into memory, then calls VFS create
(`source/ps/SavedGame.cpp:96-164`). File writes use create/truncate
(`source/lib/file/file.cpp:47-51`), so an overwrite can destroy the previous save. Config writes have
a similar direct path (`source/ps/ConfigDB.cpp:483-516`).

Required helper semantics:

- validate the destination and create a unique temporary file in the same directory;
- write, flush, sync, close, then atomically replace; sync the directory where supported;
- never delete the old valid file before replacement;
- return structured errors for out-of-space, permissions, corruption, and interruption;
- clean stale temporary files conservatively on a later launch;
- use fault injection tests before and after write/flush/rename.

## Required path/data tests

Fresh install, existing directories, missing directory, read-only bundle, insufficient storage,
corrupt save, absolute/traversal names, Unicode and Arabic names, case collisions, update preserving
Documents/Application Support, deletion/reinstall removing the sandbox, manifest mismatch, missing
sidecar, corrupt ZIP, cache purge, and attempted bundle write. Run pure mapping tests on desktop and
simulator; run actual container/update/storage behavior on a physical iPad.
