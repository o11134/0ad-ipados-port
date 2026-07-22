# Touch-first RTS controls

## Existing implementation is not safe to enable on iOS

`source/ps/TouchInput.cpp:43-44` calls the current handler a basic prototype. It is enabled only for
Android or mouse emulation (`:60-66`), has states `INACTIVE`, `FIRST_TOUCH`, `PANNING`, and `ZOOMING`,
turns a short tap into a left mouse click, and a long hold into a right click.

The critical defect is identity handling: `source/ps/TouchInput.h:62-70` stores two-element arrays,
while `TouchInput.cpp:268-285` narrows arbitrary 64-bit `SDL_FingerID` values to `int` and uses them
as direct array indexes in `OnFingerDown/Up/Motion`. SDL does not promise IDs 0 and 1. Enabling this
code on iPadOS could corrupt memory.

The input pipeline itself is reusable. `source/ps/Input.h:47-75` places touch before GUI and game view,
and `source/ps/Input.cpp:46-53` stops at the first handled reaction. `source/gui/GUIManager.cpp:369-408`
has pre/post native GUI hooks. Keep existing hardware mouse and keyboard events on their desktop SDL
paths.

## Architecture

Implement a pure C++ `TouchGestureRecognizer` independent of UIKit, renderer, and wall-clock globals.
It consumes normalized events containing stable contact ID, input kind (finger/Pencil), position in
safe-area-aware points, monotonic timestamp, force/altitude when available, and cancellation. It emits
semantic gestures; an iOS adapter translates UIKit-only Pencil/palm details, while SDL may supply
ordinary touch/mouse/keyboard.

First fix the compatibility layer with a map from external `SDL_FingerID` to bounded internal slots,
explicit overflow policy, zero-initialized synthetic `SDL_Event`, and `CancelAllTouches()` on
interruption/background/focus loss. Do not use external IDs as indexes.

Proposed recognizer states:

```text
Idle
PotentialTap
OneFingerPan
LongPressArmed
SelectionRectangle
TwoFingerCandidate
TwoFingerPan
Pinch
CommandRadialMenu
Cancelled
```

Transitions are driven by injected timestamps/distances, not frame rate. A third finger, palm-like
contact, app interruption, ownership transfer, or platform cancellation must resolve explicitly and
must never issue a command accidentally.

## Initial semantic mapping

| Gesture/context | Action |
| --- | --- |
| Tap selectable object | Select it |
| Tap empty terrain | Clear selection unless command mode is active |
| One-finger drag beginning on empty terrain | Pan camera after threshold |
| Long-press then drag | Selection rectangle |
| Double tap unit | Select nearby visible same-type units |
| Two-finger drag | Pan regardless of object below |
| Pinch | Zoom |
| Two-finger rotation | Ignore safely until camera support is proven |
| Long press terrain with selected units | Open radial command menu |
| Tap enemy | Attack only in explicit/unambiguous command state |
| Pencil | Precise selection/placement/selection rectangle; optional |
| Mouse/trackpad/keyboard | Preserve desktop behavior and hotkeys where supported |

Radial actions are Move, Attack, Attack-move, Patrol, Gather, Repair, Garrison, context-valid Build,
and Cancel. Disable irrelevant actions rather than issuing a fallback command.

## Configurable thresholds

Store thresholds in logical points and seconds, then tune on device. Initial values are proposals for
experiments—not shipped defaults:

- maximum tap duration;
- long-press duration and progress feedback interval;
- drag hysteresis/distance;
- double-tap interval and spatial radius;
- pinch scale dead zone;
- two-finger pan/rotation disambiguation;
- palm size/velocity rejection policy;
- Pencil preference and finger coexistence policy.

Expose UI scale, sensitivity, pan speed, pinch speed, long-press duration, handedness, Pencil
preference, haptics, performance preset, and FPS cap in an eventual iPad settings group. Keep all
threshold values injectable in tests.

## Feedback requirements

Render selection, touch-down location, drag threshold, selection rectangle, long-press progress,
active command mode, valid/invalid target, placement validity, radial choice, and cancellation. Safe
areas constrain control placement. Do not permanently cover the battlefield with desktop-sized
panels, and do not issue gameplay commands at touch-down before intent is resolved.

## Independent unit-test matrix

Add CxxTest or another existing-compatible pure C++ target for:

- arbitrary large/negative-bit-pattern external IDs and slot reuse;
- one, two, three, and more simultaneous contacts;
- exact time/distance threshold boundaries;
- tap vs drag vs long press; double-tap spatial/time rejection;
- two-finger pan vs pinch; ignored rotation;
- cancellation from every state, including lifecycle background;
- palm ignored without canceling a Pencil stroke incorrectly;
- Pencil + finger coexistence and Pencil absence;
- safe-area/scale coordinate transformation;
- mouse/trackpad events not consumed by the touch recognizer;
- no semantic command after ambiguous/overflow/canceled input;
- deterministic replay of an event trace at different frame rates.

No touch source or tests have been changed yet; physical touch latency and gesture ergonomics remain
unmeasured.
