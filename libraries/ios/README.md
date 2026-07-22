# iPadOS dependency workspace

This directory is reserved for deterministic iPadOS dependency builds. No binary dependency,
downloaded archive, Apple signing material, or locally generated output belongs in Git.

Planned generated roots are:

- `downloads/` for verified source archives;
- `build/device/` for `arm64-apple-ios` intermediates;
- `build/simulator/` for `arm64-apple-ios-simulator` intermediates;
- `output/device/`, `output/simulator/`, and `output/xcframeworks/` for products.

`build-ios-deps.sh` has intentionally not been added yet. Exact iPadOS configurations and archive
hashes must first be derived from each pinned upstream source, especially SpiderMonkey 128.13.0.
The existing macOS dependency outputs and `.already-built` stamps are not safe to reuse because
they are not keyed by SDK, architecture, compiler, or configuration.
