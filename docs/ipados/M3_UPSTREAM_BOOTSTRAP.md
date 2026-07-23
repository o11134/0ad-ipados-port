# M3 Upstream Bootstrap

## Why the port repository is lightweight

`0ad-ipados-port` contains only the iPadOS port code, integration scripts, CI workflows, patches,
and documentation. It does not contain the 0 A.D. engine source, game data, or third-party
dependency source. This keeps the repository small, auditable, and free of upstream licensing
complexity until engine integration begins.

## Why upstream is not copied into this repository

The official 0 A.D. source is approximately 28,000 tracked paths with over 15,000 Git LFS
objects. Copying it into this repository would create an unmaintainable fork, duplicate
licensing obligations, and make rebasing on future upstream revisions impractical. Instead,
CI fetches the exact pinned upstream revision into a temporary workspace at run time.

## Pinned upstream revision

| Field | Value |
| --- | --- |
| Repository | `https://gitea.wildfiregames.com/0ad/0ad.git` |
| Commit | `eae57d9aab66511a22a869192b7ec72feeaedc7a` |
| Source of truth | `UPSTREAM_REVISION` at the repository root |

## Clone strategy

`scripts/ios/prepare-upstream-source.sh` performs:

1. `git clone --filter=blob:none --no-checkout --no-tags --single-branch` — downloads only
   commit/tree metadata, no file content and no tags.
2. `git sparse-checkout set source build libraries docs` — materializes only the paths
   needed for engine source review and future M3-B integration.
3. `git checkout --detach <exact-commit>` — checks out the pinned revision.
4. Verifies `git rev-parse HEAD` matches the pinned commit exactly.

## What is excluded

- `binaries/` — game data, LFS objects, compiled outputs.
- `art/`, `audio/` — asset directories.
- Git LFS objects — never fetched. The script verifies no LFS objects were downloaded.
- Full Git history — blob-filtered clone downloads only the required tree.

## Temporary CI workspace

The upstream workspace is created under `$RUNNER_TEMP/ipados-upstream-source` (or
`$IPADOS_UPSTREAM_WORKSPACE` if overridden). It is ephemeral: GitHub Actions destroys it
when the job completes. No upstream source is committed to this repository.

## How M3-B will use this workspace

M3-B (engine bootstrap) will:

1. Run `prepare-upstream-source.sh` to stage the upstream source.
2. Overlay iPadOS port files from this repository (`source/platform/ios/`, `build/ios/`).
3. Apply patches from `patches/upstream/` if any exist.
4. Configure and build the engine for iOS.
5. Discard the workspace after CI.

## Patches directory

Future upstream patches will be placed in `patches/upstream/`. No patches exist yet.
The directory is reserved but intentionally empty.

## What M3-A proved

- The pinned upstream revision is fetchable from Gitea on a GitHub Actions macOS runner.
- Sparse checkout of `source`, `build`, `libraries`, `docs` works without LFS.
- All M0-identified critical source files are present in the sparse workspace.
- `binaries/data` is not materialized.
- No LFS objects are downloaded.

## What M3-A did not prove

- Engine compilation for iOS.
- SpiderMonkey interpreter-only build.
- SDL or MoltenVK integration.
- Any runtime behavior on simulator or device.
- M2-Device physical validation.
