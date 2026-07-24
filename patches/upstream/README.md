# Upstream patches

This directory contains deterministic unified diff patches applied to the pinned upstream 0 A.D.
source during CI.

Patch application is driven by `scripts/ios/apply-upstream-patches.sh`, which validates the pinned
upstream HEAD and then applies each `*.patch` file with `git apply --check` followed by `git apply`.
The process is intentionally fail-fast: if a patch does not apply cleanly, CI stops immediately.

The current M3-B patch is `0001-sysdep-detect-ios-platform.patch`.
