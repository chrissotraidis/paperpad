# PaperPad status

Updated 2026-08-05 23:55 (America/Chicago). Target-by-target status.

| Target | Status | Evidence |
|---|---|---|
| macOS native app | **Playable: intro, story narration, and Toad Town gameplay reached; runs 20+ minutes at ~60fps with HLE audio** | `docs/evidence/macos-gameplay-opening.jpg`, `docs/evidence/macos-gameplay-star-haven.jpg`, `docs/evidence/macos-gameplay-star-haven.jpg`; health log `t=1348` stable |
| iPhone Simulator | **Intro + story + Toad Town gameplay reached; touch overlay visible; 7.5+ minutes stable** | `docs/evidence/ios-iphone-intro-hle.jpg`; health log `t=450` stable |
| iPad Simulator | **Runs natively fullscreen, renders crisply at 7x (2240x1680), plays the intro/story; settings sheet + touch overlay work** | `docs/evidence/ipad-title-full.jpg`; fixes `eca833c`, `0ab64ce`, `557d376` |
| iOS device (unsigned IPA) | Not started | — |
| Signed physical device | Blocked externally (no signing identity/device) | — |

## macOS current state (2026-08-05 23:55)

Works:
- Full intro → story narration → Toad Town gameplay reached on the current
  build (`build-macos2`, commit `5226a15` + HLE audio patch). The N64 logo,
  star scene, storybook cutscene, opening narration ("Today..." →
  "In the sanctuary of Star Haven" → "Oh dear... What the...?" → Bowser
  scenes), and the gameplay-map load (`tik_03`/`trd_09` = Toad Town) all
  render at ~60fps. Ran 22+ minutes with healthy health-log counters
  (gfx/audio/sp/dp all +120 per 2 s tick, ext_pending=0).
- Keyboard input works and advances story text (Z=A, X=B, Enter=Start,
  arrows=stick, WASD=DPad). A-press advanced the opening narration, proving
  the input path end-to-end.
- **Audio now processes through mupen64plus-rsp-hle** (NAUDIO interpreter)
  instead of the broken recompiled aspMain ucode: the "RSP ucode 2 exited
  unexpectedly" flood is gone and audio tasks complete every frame. Audible
  verification on speakers/device is still pending (see KNOWN-ISSUES.md).
- Launches reliably with the vendored SDL2 2.32.10 static build
  (`build-macos-sdl2/`); logs runtime events to stderr for diagnosis.
- Freeze diagnostic: the health logger now dumps the guest startup state
  (`startupState`/`introPart`/`mainScriptID`/pressed buttons) plus the
  message-log tail when task submission stalls (`[freeze]` lines in
  `~/Library/Application Support/health.log`).

Known issues (see `docs/KNOWN-ISSUES.md`): process teardown can crash in RT64
worker autorelease cleanup; no touch controls on macOS (keyboard/gamepad
only); audio output not yet confirmed audible.

## iPhone Simulator current state (2026-08-05 23:55)

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
- **Intro + gameplay**: with the HLE audio fix the intro completes
  (`[intro]` step count 7,141+), the story narration plays, and Toad Town
  gameplay assets load (`tik_03`/`trd_09`). Health log stable to `t=450`
  (7.5+ minutes) at full speed with no RSP flood. The earlier permanent
  mid-intro boot stall (iOS #1) did not reproduce on the HLE build; treat the
  one t≈256 stall (2026-08-05 23:31) as an intermittent issue until it
  reproduces on a clean run.
- **Render note**: drawable is sized in points (874×402 @ contentsScale 1.0)
  rather than native pixels (2622×1206); functional but soft. simctl
  screenshots capture the portrait framebuffer, so landscape app content
  appears bottom/right-anchored in PNGs.

## iPad Simulator current state (2026-08-06)

- The app previously ran in iPhone-compatibility mode on iPad
  (`UIDeviceFamily=[1]`): an iPhone-sized 667×375 window in the middle of the
  iPad screen, game content zoomed/cropped (user-reported 2026-08-06).
  Diagnosed via window diagnostics: `screen=667x375 mode=750x1334
  native=750x1334` (iPhone-8-sized canvas) while the sim framebuffer was the
  full 1668×2420. Fixed by removing `LSRequiresIPhoneOS` and setting the
  target device family to `1,2` (commit `eca833c`).
- Native mode confirmed: window 1210×834, swapchain 2420×1668, drawable
  2420×1668 @ contentsScale 2.00.
- A second rendering bug was found and fixed: the CAMetalLayer was left at
  `contentsScale 1.0`, so the drawable (1210×834) was half the swapchain's
  pixel size (2420×1668) and the present clipped the frame — the
  "zoomed/cropped" look. Fixed by aligning the layer's scale/drawableSize
  with the swapchain (commit `0ab64ce`). The PAPER MARIO title screen now
  renders in full (`docs/evidence/ipad-title-full.jpg`), and the storybook
  plays with correct framing.
- A third rendering issue was fixed: the internal resolution defaulted to 1x
  (native 320×240 upscaled ~7.5x), which looked soft and shimmered in motion
  (the "screen flashing" reported on the live Simulator). The default is now
  `Resolution::Auto` (WindowIntegerScale, 7x = 2240×1680 on the iPad) with
  steady 60fps (commit `557d376`).
- Settings sheet added to the "..." menu: master volume, resolution (Auto/2x),
  aspect (Original/Expand), edit/reset touch layout, ROM management.
  Persisted and applied at launch.

## Next milestone

The primary intro freeze is fixed on all three targets; the iPad now renders
natively and correctly. Remaining:
1. Drive the iPad through a full playthrough (title screen needs a button
   press; no simctl touch injection — use the title-screen demo mode or
   XCUITest) to confirm gameplay on iPad.
2. Confirm audible audio output (host AI buffer / speaker check) — the HLE
   backend processes tasks, but an audible proof on speakers or a device is
   still open.
3. Drive a longer agent playthrough (walk Mario, enter Toad Town, trigger a
   text box / battle) to catch gameplay-era stalls.
4. Optionally fix the recompiled `n_aspMain` ucode itself (regenerate with
   `extra_indirect_branch_targets` 0x1C84/0x02B0) so the audio ucode could
   replace HLE later — not needed for playability.
