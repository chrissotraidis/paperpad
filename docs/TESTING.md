# PaperPad test evidence

Dates use America/Chicago local time. Each entry records target, commands,
logs, screenshots, gameplay checks, and outcome.

| Date | Target | Command/check | Result |
|---|---|---|---|
| 2026-08-05 | host | verified ROM byte order and hashes | v64 sha1 `77693a00418a9d8971b7a005f2001d997e359bff`; normalized z64 sha1 `3837f44cda784b466c9a2d99df70d77c322b97a0` matches pmret US baserom |
| 2026-08-05 17:38 | iPhone 16 Pro Sim | `xcodebuild ... build` (build-ios-sim) | first link fail: `_UTTypeData` + C++-mangled `paperpad_recomp_main`; fixed via `-framework UniformTypeIdentifiers` + `extern "C"` (both sides) |
| 2026-08-05 17:47 | iPhone 16 Pro Sim | iOS build after fixes | **BUILD SUCCEEDED** (`/tmp/iosbuild10.log`) |
| 2026-08-05 17:48 | iPhone 16 Pro Sim | install + `simctl launch` | PID 69104; Metal shaders compiled; game rendered intro (starfield/curtains) — `docs/evidence/ios-iphone-running.png` |
| 2026-08-05 17:48–18:05 | iPhone 16 Pro Sim | repeated plain + `--console-pty` launches | boot stalls permanently mid-intro on landscape runs (4 reproductions); console: `logs/ios-console3.log` (gfx send_dl stops at 1201, RSP flood 1344+); sample: `logs/crashes/` + `/tmp/pp-sample.txt` |
| 2026-08-05 18:1x | macOS (fresh rebuild) | `cmake --build build-macos2` + run with `logs/macos-current.log` | same RSP flood (1677 errors) but game keeps advancing (gfx send_dl 1201→1501); process later exited with known teardown autorelease crash (`logs/crashes/PaperPad-2026-08-05-181521.ips`) |
| 2026-08-05 18:2x | iPhone 16 Pro Sim | touch attach added; relaunch | touch overlay visible: stick, D-pad, A/B/Z, C-buttons, L/R, START — `docs/evidence/ios-iphone-touch-overlay.png` |
| 2026-08-05 20:0x | macOS | runtime instrumented (VI posts, external queue, guest queue) | VI posts retraces at 60/s to `mq=0x800DA4B4` (`~vi_retrace`), but the guest retraceMQ stays empty and `ext_pending` sticks at 1: the delivery depends on a game thread running `dequeue_external_messages`, and all game threads park in `osRecvMesg`. |
| 2026-08-05 20:4x | macOS | vendored SDL2 2.32.10 static linked | launch hang in `SDL_ShowWindow → SDL_RestoreWindow` (Homebrew sdl2-compat/SDL3) eliminated; window created, renderer init OK. |
| 2026-08-05 21:0x | macOS | monitor pump + host-side wake + scheduler wait applied | game plays past the old ~40s freeze: N64 logo, star scene, first cutscene ("Ha ha ha! Yeah! I did!") at ~60fps; `[sgl]` reached 7441 calls (vs 1231 before), `[sched] broadcast` 14900 (vs 2491). Still freezes at a scene transition 1-3 min in (log: `logs/macos-clean-run.log`, `logs/macos-fix2.log`). |
| 2026-08-05 22:39 | macOS | run with `[asset]`/`[script]` hooks | crash in `load_asset_by_name` +84: `fprintf` strlen over a bad rdram pointer during `state_step_intro` map load (`logs/crashes/PaperPad-2026-08-05-223939.ips`). Diagnosed as a stale `build-macos` binary with an older hook; the current `build-macos2` hook copies the asset name to a stack buffer first. |
| 2026-08-05 23:0x | macOS | AOT hook analysis + ROM ucode disassembly | root-caused the audio ucode failure: the recompiled `n_aspMain` never sets `$29` (command pointer = 0x2B0 lives in a DMA subroutine at RSP offset 0x10A0 that RSPRecomp emits as dead code). The ucode reads its own DMEM dispatch table as commands → "Unhandled jump target" flood; dispatch slots 12/14 (`0x1C84`/`0x02B0`) are also missing from the generated switch. Verified with `mips-linux-gnu-objdump` on `generated/rom/baserom.z64` text at `0x4E5A0`. |
| 2026-08-05 23:18 | macOS | HLE audio patch + launch (logs/run-hle1.log) | **No RSP flood; game passes the old t≈68 freeze.** Intro storybook plays; at t≈226 the game loads Toad Town assets (`tik_03`, `trd_09`); opening narration "Today..." advances with A-presses (Z key) through "In the sanctuary of Star Haven"/"Oh dear... What the...?"; health log stable to t=1348 (22+ min). Evidence: `docs/evidence/macos-intro-storybook.jpg`, `macos-gameplay-opening.jpg`, `macos-gameplay-star-haven.jpg`. |
| 2026-08-05 23:26 | iPhone 16 Pro Sim | HLE build install + `simctl launch --console-pty` (logs/run-hle1.log was macOS; iOS log `/tmp/ios-run1.log`) | no RSP flood; intro runs; one stall at t≈256 (health log) with all PM threads parked but SP Task Thread idle — did NOT reproduce on later runs. |
| 2026-08-05 23:45 | iPhone 16 Pro Sim | clean boot + `simctl launch --console-pty` (session log) | **intro completes** (`[intro]` steps 7,141+), story narration plays, Toad Town assets load (`tik_03`/`trd_09`); health log stable to t=450+ (7.5+ min); touch overlay visible (`docs/evidence/ios-iphone-intro-hle.jpg`, `ios-iphone-gameplay.jpg`). |
| 2026-08-05 23:49 | iPhone 16 Pro Sim | freeze diagnostic build (health-log `[freeze]` dump + `ultramodern_get_rdram`) | diagnostic added and verified building on both targets; no stall in the run (dump not triggered). |
| 2026-08-06 00:01 | iPad Pro 11" (M4) Sim | install + `simctl launch --console-pty` | renders intro at full speed (health t=270+, 9 min), touch overlay visible; **window is 667×375 = iPhone-compatibility mode** (`diag: screen=667x375 mode=750x1334 native=750x1334` while the sim framebuffer is 1668×2420). Evidence: `docs/evidence/ipad-intro-hle.png` |
| 2026-08-06 00:1x | iPad Pro 11" (M4) Sim | diagnostics expanded (screen/currentMode/nativeBounds) + `SDL_SetWindowFullscreen` experiment | confirmed the canvas is iPhone-8-sized regardless of fullscreen request; `UIDeviceFamily=[1]` found in the built plist (iPhone-only) — the compatibility-mode cause |
| 2026-08-06 00:2x | build | fix: remove `LSRequiresIPhoneOS`, set `XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"` | rebuilt plist has `UIDeviceFamily=[1,2]`; commit `eca833c` (verification pending a fresh boot) |
| 2026-08-06 01:0x | iPad Pro 11" (M4) Sim | native build + render-state probe (`[render]` lines in health log) | **drawable/swapchain mismatch found**: `swapchain=2420x1668` but `drawable=1210x834 @ contentsScale 1.00` — the present clips the frame to the smaller surface (the zoom/crop). VI `width=320 fbSize=320x240` confirmed the game is 320×240 |
| 2026-08-06 01:1x | iPad Pro 11" (M4) Sim | fix: set CAMetalLayer `contentsScale=nativeScale`, `drawableSize=bounds×nativeScale` (commit `0ab64ce`) | diag now `drawable=2420x1668 @ contentsScale 2.00`; **PAPER MARIO title screen renders in full** (`docs/evidence/ipad-title-full.jpg`); storybook text ("Far, far away, beyond the sky.") fully visible |
| 2026-08-06 01:4x | iPad Pro 11" (M4) Sim | video capture + frame analysis (AVFoundation, 0.1-0.5s sampling) | no sustained full-frame flicker in boot/storybook captures; the perceived "flashing" traced to the 1x internal resolution upscaled 7.5x (soft + shimmer in motion), not a frame-timing bug |
| 2026-08-06 01:5x | iPad Pro 11" (M4) Sim | render probe shows `userConfig.resolution=0 resolutionScale=1.000` | confirmed the render was RT64 Resolution::Original (1x); default changed to Auto → `resolutionScale=7.000` (2240×1680), steady 60fps, crisp output (commit `557d376`) |
| 2026-08-06 02:0x | iPad Pro 11" (M4) Sim | settings sheet build (volume/resolution/aspect/layout) | builds and launches clean; the C bridge (PaperPad_SetAudioVolume/SetGraphicsConfig) applies saved settings at startup |
| 2026-08-06 02:0x | iPad Pro 11" (M4) Sim | agent-driven playthrough via Simulator hardware-keyboard forwarding (osascript key codes; Return=START, Z=A) | **full flow verified**: title screen -> storybook -> name entry (File 1 "First Play" created) -> file select -> "Start Game with File 1?" -> **Mario's House gameplay** ("Mail call!" dialogue advancing; health t=690+ at 60fps). Evidence: `docs/evidence/ipad-fileselect.jpg`, `docs/evidence/ipad-gameplay-marios-house.jpg` |
| 2026-08-06 02:1x | iPad Pro 11" (M4) Sim | audio output probe (SDL queue size added to health log) | `queued=2240..4704` bytes every tick — HLE audio mix reaches the SDL device queue (end-to-end audio path confirmed) |
| 2026-08-06 04:0x | iPad Pro 11" (M4) Sim | video capture + frame analysis (brightness at 30fps sampling) | **screen flashing reproduced and root-caused**: 253 full/partial alternations per 32s during the storybook. The present created between Paper Mario's two gfx tasks (background + main) drew the half-built starfield. |
| 2026-08-06 04:5x | iPad Pro 11" (M4) Sim | fix: present waits for the frame's main task (odd workload id + early notify + 16ms bound); runtime presents at the game's frame cadence | **flashing eliminated**: 4 changes/55s (all intended storybook page transitions), gfx steady 60fps, no pipeline stall. |

## Crash-log capture

macOS and iOS Simulator crashes are archived with
`scripts/capture-crashes.sh` (copies `~/Library/Logs/DiagnosticReports/PaperPad-*.ips`
into `logs/crashes/` and prints a one-line summary: exception, signal,
faulting thread, top frames). Run it after any launch/playtest that crashes.
22+ reports archived 2026-08-05:

- ~18: teardown `objc_autoreleasePoolPop` → `objc_release` in RT64 worker
  threads (process exit; game already ran).
- 2026-08-05 22:39: `SIGSEGV` in `load_asset_by_name` (stale pre-hardening
  binary hook; see table entry above).
- 1: `SIGBUS` in `create_audio_system_obfuscated` → `boot_main` (16:50, macOS
  era before the playable milestone; not reproduced since).
- 2: black-screen-era crashes (15:27 `CocoaWindow::updateRefreshRateInternal`
  on the main thread; 15:40 abort) — predate the `SDL_ShowWindow` fix.
