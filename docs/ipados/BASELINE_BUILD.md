# Desktop baseline

## Result

No supported desktop baseline was possible in this session. 0 A.D. has a Windows/Visual Studio path,
but this Windows x64 host lacks its compiler/MSBuild, SVN-fetched upstream dependency bundle,
generated Premake executable/workspace, hydrated runtime data, and test binary. iPad work separately
requires macOS/Xcode. This is an **environment failure**, not an upstream compile failure and not a
port regression.

## Historical port-source repository baseline

- Revision: `eae57d9aab66511a22a869192b7ec72feeaedc7a`.
- Branch before work: `main`; isolated branch: `feature/ipados-native-port`.
- Historical source remote: `origin https://gitea.wildfiregames.com/0ad/0ad.git`.
- Initial workspace contained no repository. The requested initial Git commands each returned
  `fatal: not a git repository` before the official repository was cloned.
- After sparse checkout materialization and before edits, `git status --porcelain=v1 --branch`
  reported `## main...origin/main`.

## Available host inventory

| Item | Observed value |
| --- | --- |
| OS | Microsoft Windows 11 Pro 10.0.26200, x64 |
| Git | `git version 2.53.0.windows.1` |
| Git LFS | `git-lfs/3.7.1` |
| Node | `v24.14.0` |
| PowerShell | `5.1.26100.8875` Desktop |
| Xcode / iPadOS SDK | unavailable: non-macOS host |
| Apple Clang | not found |
| Visual C++ `cl` | not found in `PATH` |
| MSBuild / Visual Studio | not found in `PATH` or standard VS 2022 locations |
| CMake | not found |
| Premake | source script present; generated `build/bin/premake5.exe` absent |
| Python | `3.11.15` |
| GNU Make / Ninja | not found |

Pinned dependency versions were inventoried from `libraries/build-macos-libs.sh:23-52`; the complete
list is in `DEPENDENCIES.md`. None is installed in a repository output root on this host. Resulting
executable path: **none**. Compiler/linker warnings: **none**, because compilation never began.

`npm` is present, but PowerShell execution policy blocks `npm.ps1`; no Node dependency was installed
and linting was not attempted. This does not affect the recorded engine build failure.

## Exact attempted upstream command

From the repository root on 2026-07-22:

```powershell
cmd /c build\workspaces\update-workspaces.bat
```

Duration: approximately 0.049 seconds. Exit code: `1`.

Exact relevant output:

```text
The system cannot find the path specified.
'premake5.exe' is not recognized as an internal or external command,
operable program or batch file.
```

Cause: the normal Windows dependency bundle/build step that provides Premake has not run and the host
also lacks a compiler/MSBuild. A full build or CxxTest invocation would produce no additional engine
signal, so it was not attempted.

The next repository-provided Windows acquisition command would be:

```powershell
cmd /c libraries\get-windows-libs.bat --amd64
```

It requires `svn`, downloads official revision 28278, and writes dependency binaries/tools; it was
not run because SVN is absent and dependency installation/download requires an explicit host choice.
There is no pinned repository command to install Visual Studio, SVN, or CMake globally, so this audit
does not invent one. Reproducing the full M1 engine baseline still requires the upstream macOS flow
recorded in `Upstream supported macOS commands to reproduce later` and `Next baseline action` below.
The current isolated M2-CI/M2-Simulator continuation instead uses the standard GitHub-hosted macOS
route in `GITHUB_ACTIONS.md` and does not fetch the full LFS/runtime payload.

## Upstream supported macOS commands to reproduce later

The following are recorded directly from `build/jenkins/pipelines/macOS.Jenkinsfile:50-120`; they
have **not** been run in this session:

```sh
git lfs pull -I binaries/data/tests
git lfs pull -I "binaries/data/mods/_test.*"
libraries/build-macos-libs.sh -j$(sysctl -n hw.ncpu)
build/workspaces/update-workspaces.sh
make -C build/workspaces/gcc -j$(sysctl -n hw.ncpu) config=debug
./binaries/system/test_dbg --format junit --output cxxtest.xml
```

Release uses `config=release` and `./binaries/system/test`. Before running these on the port host,
record `sw_vers`, `uname -m`, `xcodebuild -version`, `xcrun clang++ --version`, `cmake --version`,
`python3 --version`, Premake version, exact duration, executable path, warnings, and test output.

## Next baseline action

On an Apple Silicon Mac with sufficient storage and official LFS access, clone/hydrate the required
data, run the upstream dependency and workspace commands unchanged, then record both Debug and test
results before linking any iOS engine code. The current workspace path contains a space; validate
each upstream dependency script's quoting before using it, and choose a no-space clone if a script
explicitly rejects whitespace.
