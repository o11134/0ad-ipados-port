# iPadOS audio integration

## Current state

Audio is enabled by default through `CONFIG2_AUDIO` (`source/lib/config2.h:73-76`) and can be omitted
with `--without-audio` (`build/premake/premake5.lua:57,279-281`). The mac dependency script pins
OpenAL Soft 1.24.2 and builds it statically with examples/utilities/tests disabled
(`libraries/build-macos-libs.sh:52,1127-1137`). Vorbis/Ogg are pinned to 1.3.7/1.3.5.

`source/soundmanager/SoundManager.cpp:55-170` owns a worker thread; `:196-210` opens the default ALC
device and starts work, and `:319-377` creates the context and source pool. No `AVAudioSession`, route
change, interruption, silent-mode, or iOS background bridge exists in the audited source.

The safe route is to build M2 through early engine/bootstrap work without audio, then add it as a
separate physical-device gate. A macOS OpenAL archive is not an iOS artifact.

## Proposed narrow bridge

`IOSAudioSession` should remain Objective-C++ and expose C++ events/policy only:

- configure an intentional category/mode and document silent-switch behavior;
- activate only when engine audio is ready;
- on interruption begin, synchronously pause new engine sound work and acknowledge the session;
- on interruption end, reactivate only when permitted, rebuild/reopen OpenAL if required, then resume
  according to game/lifecycle state;
- handle headphone/Bluetooth route changes and lost device/context;
- observe platform/output volume changes without attempting to override the system volume;
- deactivate and stop worker activity before background suspension;
- never treat a route change as permission to autoplay when the game is paused;
- log category, sample rate, channel count, buffer duration, interruption reason/options, route class,
  and recovery result without personal device information.

Policy question to resolve with a physical prototype: whether game audio should respect silent mode
using an ambient-style session or behave as intentional media. Do not force playback until the choice
is documented and tested.

## Dependency and license gate

Build OpenAL Soft and Ogg/Vorbis from official pinned archives into device and ARM64 simulator static
outputs with SHA-256 manifests. Disable dynamic backend/module loading. Inspect the exact OpenAL iOS
backend and required Apple frameworks before integrating it. `libraries/LICENSE.txt:73-75` lists
OpenAL as LGPL-2.0-or-later; static distribution requires a separate compliance/relinking review.
This document is not a legal conclusion.

## First audio milestone

After M6 menu rendering:

1. main-menu music;
2. one interface sound;
3. one in-game sound;
4. headphones unplug/replug;
5. Bluetooth route change if available;
6. interruption begin/end;
7. lock/background and foreground;
8. clean shutdown with worker/context/device released.

Record on a physical iPad: OpenAL device string, negotiated sample rate/channels/buffer duration,
silent-mode policy/result, route transitions, underrun/error logs, and whether resume was automatic or
user-driven. Simulator audio is only a logic smoke test. No audio build or test has occurred.
