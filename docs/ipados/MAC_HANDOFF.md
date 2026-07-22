# Clean Apple Silicon Mac handoff for M2

This is a **deferred future M2-Device guide**, not the current validation route. Current unsigned
compile and simulator work belongs to `.github/workflows/ipados-m2.yml`; see `GITHUB_ACTIONS.md`.
Do not perform signing or physical-device setup during the present CI task.

The old archive transfer of 41 untracked files is obsolete: the reviewed scaffold is committed as
`27c6c602019a3744581ea71d119b62a379b12e10`. A later device session must start from the reviewed
GitHub branch after the workflow commit has been pushed, not by overlaying an untracked archive.

When a legitimate physical Mac becomes available and M2-Device work is separately authorized:

1. Record the selected GitHub repository URL, branch, and exact reviewed commit from the successful
   CI record. Do not substitute an unofficial binary or signing service.
2. Clone the selected GitHub repository without LFS hydration:

   ```sh
   GIT_LFS_SKIP_SMUDGE=1 git clone --filter=blob:none \
     --branch feature/ipados-native-port "<selected GitHub repository URL>" 0ad-ipados
   cd 0ad-ipados
   ```

   The angle-bracket URL is an explicit placeholder, not a command to run before a repository is
   selected.
3. Run `git status --short --branch`, `git rev-parse HEAD`, and `git remote -v`. Require a clean tree
   and the reviewed workflow commit recorded by CI; stop on any difference.
4. Install and launch a stable Xcode through an approved Apple channel as the logged-in user, accept
   its license through the normal UI, install requested components, and select Command Line Tools in
   **Xcode > Settings > Locations**. Do not use `sudo` or modify global shell/Git configuration.
5. Verify `xcode-select -p`, `xcodebuild -version`, both SDKs, CMake 3.25+, Git, and Python 3 with
   `sh scripts/ios/verify-mac-environment.sh`; stop at any `FAIL`.
6. Run `sh scripts/ios/run-static-checks.sh`. Do not run `git lfs pull`, hydrate `binaries/data`, or
   fetch the approximately 6.52 GB runtime data set; M2 does not need it.
7. Generate the physical project with `sh scripts/ios/generate-xcode-project.sh iphoneos` and open
   `build/ios/out/iphoneos/PyrogenesisIPadShell.xcodeproj`.
8. Only in this authorized device session, select a local Development Team and unique local bundle
   identifier in Xcode. Never commit an Apple Account, Team ID, certificate, profile, device
   identifier, or personal namespace.
9. Connect and unlock the iPad, complete normal trust/pairing, and enable Developer Mode only through
   the iPad UI if requested. Select the physical device in Xcode.
10. Use **Product > Build** and **Product > Run**. A compile or simulator result is not M2-Device
    evidence; require a signed install and actual launch.
11. Verify the landscape diagnostics, both orientations, safe areas, manual sandbox `PASS`, three
    background/foreground cycles, memory warning where supported, and sanitized lifecycle/size logs.
12. Append the exact sanitized result to `DEVICE_TEST_LOG.md`. A pass advances **M2-Device only**;
    overall M2 remains incomplete until every required project gate is explicitly satisfied. Do not
    begin M3 on the strength of CI or simulator evidence alone.
