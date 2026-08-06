# PaperPad status

Updated 2026-08-05 21:30 (America/Chicago). Target-by-target status.

| Target | Status | Evidence |
|---|---|---|
| macOS native app | **Launches reliably and plays the intro (logo + star scene + cutscene) at ~60fps for 1-3 minutes, then freezes at a scene transition** | `docs/evidence/macos-opening-scene.png`; cutscene evidence captured 2026-08-05 21:0x |
| iPhone Simulator | **Builds and launches; renders intro; touch overlay works; boot freezes mid-intro (same runtime deadlock as macOS)** | `docs/evidence/ios-iphone-running.png`, `docs/evidence/ios-iphone-touch-overlay.png` |
| iPad Simulator | Pending deadlock fix (same code path) | — |
| iOS device (unsigned IPA) | Not started | — |
| Signed physical device | Blocked externally (no signing identity/device) | — |

## macOS current state

Works:
- Boots through decomp-verified AOT code, main-loop spin hooks, anti-piracy
  wrapper bypass, audio/RSP microcode, and RT64 Metal rendering.
- Renders the game window at 50–60fps and advances the intro scene.
- Keyboard input wired (Z=A, X=B, Enter=Start, arrows=stick, WASD=DPad).
- Logs runtime events to stderr for diagnosis.
- Launches reliably after switching from the Homebrew `sdl2-compat` shim
  (SDL3 underneath, which hung in `SDL_ShowWindow`'s Cocoa restore path) to a
  vendored SDL2 2.32.10 static build (`build-macos-sdl2/`), the same source
  the iOS target uses.
- With local runtime fixes (see `KNOWN-ISSUES.md` macOS #1), the intro now
  plays past the old ~40s freeze: N64 logo, star scene, and the first story
  cutscene ("Ha ha ha! Yeah! I did!") render at ~60fps.

Known issues (see `docs/KNOWN-ISSUES.md`): audio RSP errors slow startup; a
cooperative-scheduler deadlock still freezes the game at a scene transition
1-3 minutes into the intro; process teardown can crash in RT64 worker
autorelease cleanup; no touch controls on macOS (keyboard/gamepad only).

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

Fix the cooperative-scheduler deadlock that freezes the game at the intro's
scene transition (all game threads park in `osRecvMesg`; host-delivered
retraces land in the guest queue but no game thread is resumed). The local
runtime patches (monitor pump + host-side wake + scheduler wait) extend the
intro from ~40s to 1-3 minutes but don't fully resolve it. Once the freeze is
fixed, verify a playthrough on macOS, then repeat on iPhone and iPad
Simulators.
