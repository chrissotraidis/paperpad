# PaperPad status

Updated 2026-08-09 (America/Chicago). This file distinguishes reproduced acceptance from planned work.

## Current acceptance

| Target | Status | Reproduced evidence |
|---|---|---|
| Apple Silicon macOS | **Verified local source build** | ROM-free app build/signature check; launch through intro, name/file creation, and early gameplay; keyboard input; clean test quit |
| iPhone Simulator | **Verified local source build** | First-run UI, ROM import path, native launch/rendering, touch overlay, persistent menu/settings, and clean terminate |
| iPad Simulator | **Verified local source build** | Retina 4:3 rendering in both orientations, title/file flow, touch-driven castle entry, settings/touch visibility/opacity/layout/ROM controls, and clean terminate |
| Physical iPhone/iPad | **Not verified** | No device build, signing, install, audible-device-audio, interruption, thermal, or long-play evidence |
| Signed/notarized/TestFlight/App Store | **Not available** | Packaging, rights clearance, signing, and distribution acceptance remain open |

The tested build identifies as version 0.1.0 (build 1), profile `release`, bundle ID `com.chrissotraidis.paperpad` on iOS.

## Fixes verified in the 2026-08-09 release audit

- iOS Metal initialization and Simulator shader-tool selection work.
- The iOS path avoids unsupported 18-sampler native fast paths and the optional 52-buffer ray-tracing debug pipeline.
- UIKit window dimensions are reported in physical pixels, fixing the quarter-size Retina viewport. iPad now shows a centered original 4:3 frame at full height in landscape and full width in portrait.
- Flash page reads wrap safely, preventing the empty-file-select crash.
- HLE NAUDIO replaces the broken recompiled Paper Mario audio microcode path and removes its RSP error flood.
- RT64 Metal worker ownership/teardown fixes eliminated the reproduced autorelease crash.
- The 2026-08-09 final macOS regression caught two teardown paths that the
  historical patch provenance did not actually apply to the current ReCut
  vendor layout. `metal-worker-lifetime.patch` now stops renderer workers in
  dependency order, drains Apple autorelease pools, and corrects unowned Metal
  object releases. `apple-clean-process-exit.patch` completes renderer, event,
  thread-cleaner, and save shutdown before ending the single-session Apple
  process without unmapping RDRAM beneath parked guest threads. Three
  launch/render/input/quit cycles then exited with no new crash report.
- A persistent accessible PaperPad Menu exposes native settings. Touch visibility and opacity now persist alongside volume, resolution, aspect, and edited layout.
- The visible analog stick has a fixed center, while a broad left-side pickup region remains available. Touch flick retention was lengthened so short gestures reach the game poll reliably.

## Playtest boundary

The current hands-on route covered launch, title, file creation, the opening narrative, early map movement, dialogue, and entry into Peach's Castle. Touch A, Start, D-pad, and analog movement were exercised, including menu/settings interactions and a controls-off/on cycle. The final macOS artifact also passed three clean-quit cycles after a teardown regression was found and fixed. This is meaningful early-game acceptance, not a full-game playthrough.

Visual comparisons against original Paper Mario references found matching theater structure, original 4:3 composition, saturated palette, checkerboard/curtain staging, dialogue styling, and layered paper-character presentation. See `docs/release-audit/` and the README.

## Known open release gates

1. Run a complete-game or chapter-spanning regression and a 60+ minute soak on the final macOS and Simulator artifacts.
2. Confirm audible audio and interruption/background recovery on real Apple hardware.
3. Add and audit a generic physical-device build before making any iPhone/iPad device claim.
4. Verify controller hot-plug and decide whether touch controls should auto-hide while a hardware controller is active.
5. Clean up the non-blocking iOS launch warnings: unbalanced UIKit appearance transition and duplicate Simulator accessibility class.
6. Investigate the RT64 `RenderPool in Metal is not implemented currently` diagnostic and document whether the feature is unused or needs an implementation.
7. Complete binary packaging, required third-party notices, signing/notarization, privacy, accessibility, and rights review before any public binary.

Historical failures and detailed investigations remain in [TESTING.md](TESTING.md) and [KNOWN-ISSUES.md](KNOWN-ISSUES.md). They are not evidence that the current build still fails.
