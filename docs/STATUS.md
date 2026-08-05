# PaperPad status

Updated 2026-08-05 18:30 (America/Chicago). Target-by-target status.

| Target | Status | Evidence |
|---|---|---|
| macOS native app | **Playable — boots and runs Paper Mario's intro** | Renders at 50–60fps; `docs/evidence/macos-opening-scene.png`; fresh rebuild verified 2026-08-05 18:1x |
| iPhone Simulator | **Builds and launches; renders intro; touch overlay works; boot stalls mid-intro (audio RSP flood)** | `docs/evidence/ios-iphone-running.png`, `docs/evidence/ios-iphone-touch-overlay.png` |
| iPad Simulator | Pending boot-stall fix (same code path as iPhone) | — |
| iOS device (unsigned IPA) | Not started | — |
| Signed physical device | Blocked externally (no signing identity/device) | — |

## macOS current state

Works:
- Boots through decomp-verified AOT code, main-loop spin hooks, anti-piracy
  wrapper bypass, audio/RSP microcode, and RT64 Metal rendering.
- Renders the game window at 50–60fps and advances the intro scene.
- Keyboard input wired (Z=A, X=B, Enter=Start, arrows=stick, WASD=DPad).
- Logs runtime events to stderr for diagnosis.

Known issues (see `docs/KNOWN-ISSUES.md`): audio RSP errors slow startup;
process teardown can crash in RT64 worker autorelease cleanup; no touch
controls on macOS (keyboard/gamepad only).

## iPhone Simulator current state (2026-08-05)

- **Build**: `build-ios-sim/PaperPad.xcodeproj` (CMake iOS toolchain, Release,
  arm64, code signing off) builds cleanly. Link fixes landed: `-framework
  UniformTypeIdentifiers` for `UTTypeData` and `extern "C"` linkage for
  `paperpad_recomp_main` on both sides of the shell boundary.
- **Launch + render**: installs on iPhone 16 Pro Simulator; Paper Mario's intro
  renders (starfield, curtains, star spawn) under Metal; ~38% CPU while
  running.
- **Touch overlay**: `paperpad_touch_attach` now called after window creation;
  overlay visible with stick, D-pad, A/B/Z, C-buttons, L/R, START
  (`docs/evidence/ios-iphone-touch-overlay.png`).
- **Blocking bug**: boot freezes mid-intro (permanent, reproduced 4×). Root
  cause: audio RSP task flood ("RSP ucode 2 exited unexpectedly.
  exit_reason: 3" = UnhandledJumpTarget in `n_aspMain`); the ucode never
  returns on iOS, so ultramodern's graceful drop path never triggers. See
  `docs/KNOWN-ISSUES.md` iOS #1 for the full analysis.
- **Render note**: drawable is sized in points (874×402 @ contentsScale 1.0)
  rather than native pixels (2622×1206); functional but soft. simctl
  screenshots capture the portrait framebuffer, so landscape app content
  appears bottom/right-anchored in PNGs.

## Next milestone

Fix the iOS audio RSP stall so the boot completes (macOS reaches gameplay by
the same graceful path), then repeat launch/playtest on iPad Simulator.
