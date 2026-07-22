# 0 A.D. iPadOS Port

This is an experimental, unofficial iPadOS porting project. It is not affiliated with, endorsed by,
or sponsored by Wildfire Games.

The official 0 A.D. repository is:

https://gitea.wildfiregames.com/0ad/0ad

## Current scope

This repository does not contain the complete 0 A.D. engine or game data. It currently contains only
the standalone UIKit M2 application scaffold, its platform-isolation documentation, local static
checks, and the `iPadOS M2 Scaffold` GitHub Actions workflow.

Current validation status:

- M2-CI: PENDING until a GitHub Actions macOS compile succeeds.
- M2-Simulator: PENDING until the workflow builds, launches, and observes the required smoke markers.
- M2-Device: NOT TESTED; no physical iPad installation or launch has been verified.
- Overall M2: INCOMPLETE.

No result from the simulator should be interpreted as physical-device verification.

## Export provenance

- Source branch: `feature/ipados-native-port`
- Source port commit: `5c60bd3f06727e0ee92e0a9968f069bc186097d1`
- Audited upstream revision: `eae57d9aab66511a22a869192b7ec72feeaedc7a`

The export was created from locally available working-tree files. It contains neither the complete
upstream Git history nor Git LFS game assets.

## Future engine integration and licensing

Any later engine integration will be sourced from the official upstream repository and handled under
the original upstream licenses and attribution requirements. See
`docs/ipados/LEGAL_AND_ATTRIBUTION.md` for the current project boundary and attribution notes.
