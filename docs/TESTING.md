# PaperPad test evidence

This is a chronological engineering record. Older failure rows describe the
binary and source state at their timestamp; they are not current release
claims. `docs/STATUS.md` is authoritative for the latest acceptance boundary.
Dates use America/Chicago local time.

## 2026-08-09 release audit

| Target | Exercise | Result |
|---|---|---|
| Apple Silicon macOS | Current ROM-backed app launch; intro, name/file flow, early gameplay, keyboard input, clean quit | Passed the exercised route; screenshots `docs/release-audit/03-paperpad-macos-prologue.png` through `06-paperpad-macos-gameplay.png` |
| iPad Pro 11-inch Simulator | ROM-free app install plus private first-run input; touch Start/A/D-pad/analog; title, file creation, early movement, Peach's Castle entry | Passed; no crash during the exercised route |
| iPad Pro 11-inch Simulator | Retina/window correction in portrait and landscape with original 4:3 aspect | Passed; corrected landscape capture `docs/release-audit/10-paperpad-ios-retina-landscape.png`; earlier quarter-size `09-paperpad-ios-first-play.png` retained as before evidence |
| iPad Pro 11-inch Simulator | Persistent PaperPad Menu; volume, resolution, aspect, touch visibility, opacity, layout edit/reset, ROM manager | Controls present and operable; touch visibility toggled off and restored; settings capture `docs/release-audit/11-paperpad-ios-settings.png` |
| Original-game visual comparison | PaperPad opening, file select, and early gameplay compared against Nintendo archive/secondary capture in one review input | Matching 4:3 composition, theater geometry, palette, curtain/checkerboard staging, dialogue styling, and layered cutout presentation; sources recorded in README |
| Apple Silicon macOS final teardown | Final app was launched, rendered, accepted keyboard input, and quit repeatedly; fresh crash reports initially exposed an RT64 workload autorelease fault and then a parked guest-thread/RDRAM race | Both root causes converted into maintained patches; three subsequent launch/render/input/quit cycles produced no new crash reports |
| iPad Pro 11-inch Simulator final shared-runtime rebuild | Rebuilt after the Metal lifetime and Apple process-exit patches; installed the ROM-free app and launched the existing private test container | Build, install, native 2420x1668 drawable, rendering, touch overlay, and accessible PaperPad Menu passed; app terminated and Simulator shut down before any other target |

Remaining release acceptance is listed in `docs/STATUS.md` and
`docs/RELEASE_CHECKLIST.md`; this audit is not a complete-game or physical-device
certification.

## Historical engineering log

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
| 2026-08-06 07:30 | macOS | clean launch to verify the frame-boundary present; process crashed 37s in | **NEW crash root-caused**: `SIGBUS` in `save_read` at file select on an empty flash card — `filemenu_init -> fio_load_game -> fio_read_flash -> osFlashReadArray_recomp -> save_read`, fault addr `0x9db4c4000` = `save_buffer.data() + 0xFFFFC000` (slot `-1` read wraps to a huge offset). Crash log: `~/Library/Logs/DiagnosticReports/PaperPad-2026-08-06-073051.ips` (procLaunch 07:30:07). |
| 2026-08-06 07:44 | macOS | fix applied: `flash_page_offset` masks page_num to the chip's page count (patch `patches/mstan-n64modernruntime/flash-page-wrap.patch`); rebuild + launch with stderr log | **empty-slot flash read no longer crashes**: game booted, START at title, storybook played, new game created, and reached Mario's House gameplay (screenshots `/tmp/pp-fs1..3.png`); no crash logs after 07:30. |
| 2026-08-06 07:5x | iPad Pro 11" (M4) Sim | screenshot burst (40 shots, ~1s apart) during the intro cutscene on the previous build | **flashing reproduced despite the earlier fix**: 6/40 frames were the identical stale sanctuary frame (mean brightness exactly 0.1818 every time) interleaved with the progressing cutscene — the retrace present still landed mid-frame and timed out its 16ms wait. |
| 2026-08-06 08:0x | iPad Pro 11" (M4) Sim | final fix: REMOVED the VI-thread retrace present; only the swap-task present remains (`RT64_PRESENT_LOG`, `RT64_FLAG_LOG` console) | **exactly one present per frame, always after the swap task** (`[task] flags=0x4` -> one `[present]`, workload ids even, fb cycling 0x38F800/0x3B5000/0x3DA800); no odd-id or double presents. |
| 2026-08-06 08:0x | iPad Pro 11" (M4) Sim | screenshot bursts (45+45 frames) through logos -> intro -> storybook on the fixed build | **no repeated/identical frames** (previous build had 6/40 identical 0.1818 frames); dark frames are the storybook's own pages, each unique; brightness changes smoothly (0.17-0.57) with the cutscene; health log steady (gfx +104-120/2s). |
| 2026-08-06 08:1x | macOS | same fixed build, `RT64_PRESENT_LOG=1` launch | identical clean pattern: one present per frame at the swap boundary, no mid-frame presents. |
| 2026-08-06 08:1x | iPhone 16 Pro Sim | fixed build install + `simctl launch --console-pty` (`RT64_PRESENT_LOG`/`RT64_FLAG_LOG`) + 40-shot screenshot burst through the intro storybook | same clean pattern (one present per frame at the swap task, even workload ids); burst brightness drifts smoothly between scene plateaus (0.182-0.199-0.267) with no oscillation or identical repeat frames; dark frames are the storybook's own pages (`docs/evidence/iphone-flash-fixed-storybook.jpg`); health log steady (gfx +81-115/2s during the cutscene, audio +120). |
| 2026-08-06 09:1x | macOS | NSZombieEnabled run to identify the teardown crash object | **root cause found**: `-[AGXG13GFamilyBlitContext release]: message sent to deallocated instance` — the blit encoder (and later the resolve compute encoder, a texture descriptor in `MetalBufferFormattedView`, and `MetalShader::functionName`) were over-released: created via autoreleased class factories but explicitly released, leaving dangling pointers in the autorelease pool that crashed the next pool pop. |
| 2026-08-06 09:2x | macOS | fixes applied: retain() on blit/resolve encoders, drop releases of autoreleased descriptors/strings, unowned command buffer no longer released, thread-wide autorelease pool markers on all RT64 worker threads, `Application::~Application` stops/joins workers before member teardown | **teardown crash eliminated**: 8 consecutive SIGTERM cycles exit cleanly, a 110s run is stable and exits cleanly, zero crash reports; title screen renders correctly (`/tmp/ppdiag/fix7-render5.png`). |
| 2026-08-06 09:4x | iPad Pro 11" (M4) Sim | fixed build install + launch 25s + screenshot + terminate | renders the storybook opening ("Far, far away, beyond the sky") with the touch overlay; terminate produces no crash report. |

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
