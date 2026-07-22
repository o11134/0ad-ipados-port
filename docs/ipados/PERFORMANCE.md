# iPadOS performance and thermal plan

## Status

No executable engine target exists and no simulator or physical iPad was tested. There are **zero
performance measurements**. The values below are proof-of-concept targets, not results.

Initial target on a modern Apple Silicon iPad: stable 30 FPS on one small official offline map, no
unbounded memory growth, no repeated thermal shutdown behavior, responsive touch, correct pause/resume,
and no crash during a 20-minute session. Do not default to 120 FPS.

## Presets

| Preset | Intent | Initial policy to validate |
| --- | --- | --- |
| Low | thermal/memory recovery | 30 FPS cap, low textures/distance/particles, minimal shadows/water/postprocessing, no MSAA/GPU skinning |
| Balanced | default | 30 FPS cap, medium texture/UI quality, conservative shadows/water/distance, optional features capability-gated |
| High | opt-in on proven devices | higher effects/distance only after sustained device measurement |
| Custom | explicit user control | preserve each setting and show costly options clearly |

The audited default config has anti-aliasing disabled and GPU skinning enabled when capabilities allow.
The iPad port must initially force GPU skinning off and keep descriptor indexing/MSAA/expensive water,
shadows, post-processing, PBR, particles, and draw distance conservative. Raise them one at a time with
runtime feature checks and comparative measurements.

## Measurement protocol

Use a fixed source revision, signed Release-with-debug-symbols build, exact official staged-data
manifest, same map/seed/faction/camera script, charged device disconnected from debugger for final
numbers, fixed brightness/audio/network state, and recorded ambient conditions. Run a cold start and
at least three steady-state repetitions. Preserve raw samples rather than only averages.

Measure:

- cold launch to first shell, menu, and interactive map;
- resident/dirty/peak memory at shell, menu, map load, 5 and 20 minutes;
- CPU utilization by thread and pathfinding/script spikes;
- GPU utilization/counters when Instruments supports the device;
- FPS plus 50th/90th/95th/99th percentile frame time and worst hitch;
- thermal state transitions and elapsed time to each;
- battery percentage/energy diagnostics over a controlled interval;
- map load, save, and load-save duration;
- interpreter-only JavaScript frame/update cost compared with the same desktop scenario;
- input-to-visible-response samples for tap, pan, and pinch;
- audio callback stability/underruns;
- background/foreground pause duration and first resumed frame time.

Do not collect analytics or telemetry from users. Development measurements stay local and contain no
personal device identifier.

## Instrumentation

Prefer existing engine profiler/timing hooks and local Xcode Instruments: Time Profiler, Metal System
Trace/GPU tools where compatible, Allocations/Leaks, Energy Log, and signposts added through a narrow
iOS diagnostics bridge. User reporter/profiler HTTP must remain disabled in the offline build; export
results manually.

Frame pacing should use the platform display cadence without busy-waiting. Start at a 30 FPS cap,
record actual present intervals under FIFO, and reset accumulated frame time after suspension to avoid
a huge simulation delta.

## Result table

Populate only after a physical-device run.

| Revision/build | Device class/iPadOS | Scenario | Launch | Menu memory | Map memory | FPS / p95 / p99 | Thermal | 20 min | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Not run | Not run | Not run | — | — | — | — | — | — | NOT TESTED |

If a target is missed, record the actual value and profile evidence before changing quality. Never
remove diagnostics, disable safety checks, or label the run passed merely because the app did not
crash immediately.
