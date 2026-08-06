# PaperPad handoff

Latest: 2026-08-05 23:55 (America/Chicago). See `STATUS.md` for the
authoritative status table, `TESTING.md` for evidence, and `KNOWN-ISSUES.md`
for the full issue list.

## What works

- **macOS app is playable through the intro into Toad Town**: N64 logo, star
  scene, storybook cutscene, opening narration (advanced with A presses),
  and the gameplay-map load all run at ~60fps; the app stayed healthy for
  22+ minutes (`health.log` t=1348, all counters +120/2 s). Pipeline: decomp
  (`ref/papermario` pmret @ `c61db66`) -> AOT
  (`generated/aot/paper_mario_recomp_out/`) -> mstan N64ModernRuntime + RT64
  (pinned + AnnePad patches in `ref/mstan-*`) -> SDL2/Metal runner
  (`src/paperpad_main.cpp`) with vendored static SDL2 2.32.10.
  Evidence: `docs/evidence/macos-gameplay-*.png`.
- **Audio fixed**: audio tasks now run through mupen64plus-rsp-hle's NAUDIO
  interpreter instead of the recompiled `n_aspMain` ucode. The recompiled
  ucode is broken for Paper Mario (the audio command pointer `$29 = 0x2B0` is
  only set by the RSP boot-ucode handoff this runtime skips, so the ucode
  reads its own DMEM dispatch table as commands, floods "Unhandled jump
  target", and eventually spins forever — freezing the game). HLE processes
  the same OSTask reliably. Patch: `patches/mstan-n64modernruntime/
  hle-audio-rsp.patch`; dependency vendored at `ref/mupen64plus-rsp-hle`.
- **Screen flashing fully fixed (2026-08-06, final)**: the full/partial
  frame alternation during 30fps cutscenes (the storybook flashing between
  the complete scene and the bare star sanctuary, which persisted through
  the earlier wait-for-main-task fix) is gone. Final root cause: the VI
  retrace present could still land between Paper Mario's two per-frame gfx
  tasks (background + main swap task) and time out its 16ms wait for the
  main task, drawing the half-built background. Final fix: REMOVED the
  VI-thread retrace present entirely; the only present now fires at the
  swap-task boundary (`flags & 0x4`, after `dp_complete`), which is exactly
  the frame-complete moment — a present can never land mid-frame again.
  `RT64_PRESENT_LOG` shows exactly one present per frame, and 45-frame
  screenshot bursts through the logos → intro → storybook show zero
  repeated/identical frames (previously 6/40 were the identical 0.1818
  stale frame); the storybook's dark pages are real content, each unique.
  Patches: `patches/mstan-rt64/present-wait-workload.patch` (defensive),
  `patches/mstan-n64modernruntime/vi-screen-update-cadence.patch`.
- **File-select crash on an empty flash card fixed (2026-08-06)**: a fresh
  install crashed with SIGBUS in `save_read` every time the game reached
  the file-select screen with no saved games (macOS crash
  `PaperPad-2026-08-06-073051.ips`, stack `filemenu_init ->
  fio_load_game -> fio_read_flash -> osFlashReadArray_recomp ->
  save_read`). The game reads empty slots with `page_num = -1`; the real
  flash chip wraps the resulting byte offset, but the host recomp indexed
  the flat save buffer out of bounds. Fix
  (`patches/mstan-n64modernruntime/flash-page-wrap.patch`): mask the page
  number to the chip's page count so out-of-range reads wrap into erased
  (0xFF) flash and the checksum check fails gracefully. Verified: macOS
  boots → title → file select → new-game creation → Mario's House gameplay.
- **Teardown autorelease crash fixed (2026-08-06)**: the
  `objc_autoreleasePoolPop` → `objc_release` crash on the RT64 Workload thread
  at exit is gone. Root cause: four Metal-cpp objects were over-released
  (blit encoder, resolve compute encoder, a buffer-formatted-view texture
  descriptor, and `MetalShader::functionName`) — created by autoreleased class
  factories but explicitly released, so their memory was freed while the
  caller's autorelease pool still held a pending release. Identified with
  `NSZombieEnabled` (`-[AGXG13GFamilyBlitContext release]: message sent to
  deallocated instance`). Fixes: `retain()` on the blit/resolve encoders
  (matching the render/compute encoders), no release for the autoreleased
  descriptor/string, no release for the unowned
  `commandBufferWithUnretainedReferences()` buffer in `commit()`, thread-wide
  autorelease pool markers on every RT64 worker thread, and
  `Application::~Application` stops/joins the workload + present queues before
  any render objects are destroyed. Patch:
  `patches/mstan-rt64/metal-worker-autorelease-and-overrelease-fixes.patch`.
  Verified: 8 consecutive macOS SIGTERM cycles and a 110s run exit cleanly
  (zero crash reports), iPad Simulator terminate is clean, and the game
  renders normally.
- **iPhone Simulator app builds, installs, launches, and reaches Toad Town
  gameplay** under Metal with the Paper Mario touch overlay (stick, D-pad,
  A/B/Z, C-buttons, L/R, START). Health log stable to t=450 (7.5+ minutes),
  no RSP flood, intro story completed. Evidence:
  `docs/evidence/ios-iphone-intro-hle.jpg`,
  `docs/evidence/ios-iphone-touch-overlay.png`.
- **iPad Simulator app builds, installs, launches, and renders correctly**:
  native fullscreen (window 1210×834, drawable 2420×1668 @ contentsScale
  2.00), crisp 7x internal rendering (2240×1680), the PAPER MARIO title
  screen and storybook render in full, and the touch overlay works. Fixes:
  device family 1,2 (`eca833c`), CAMetalLayer scale (`0ab64ce`), and
  scale-to-window resolution default (`557d376`). Evidence:
  `docs/evidence/ipad-title-full.jpg`.
- **Settings sheet** added to the "..." menu (volume, resolution Auto/2x,
  aspect Original/Expand, edit/reset touch layout, ROM management);
  persisted and applied at launch.
- **All three targets verified playable (2026-08-06)**: macOS reaches Toad
  Town gameplay; iPhone Simulator reaches Toad Town; iPad Simulator was
  driven through the entire boot flow (title -> storybook -> name entry ->
  file select -> Mario's House gameplay) using the Simulator's hardware-
  keyboard forwarding. Audio output flows end-to-end (health log `queued=`
  bytes from the SDL queue).
- Freeze diagnostic in the health logger: when task submission stalls, it
  dumps `gGameStatusPtr` state (`startupState`/`introPart`/`mainScriptID`/
  pressed) plus the last message-log events (`[freeze]` lines in
  `~/Library/Application Support/health.log`).
- Crash-log capture: `scripts/capture-crashes.sh` archives
  `~/Library/Logs/DiagnosticReports/PaperPad-*.ips` into `logs/crashes/` with
  one-line summaries (exception, signal, faulting thread, top frames).
  22+ reports archived 2026-08-05.
- ROM present via `generated/rom/baserom.z64`, verified z64 sha1
  `3837f44cda784b466c9a2d99df70d77c322b97a0`; never committed.

## What does not work

- **Audible audio unverified**: the HLE backend completes every audio task and
  writes mixed output, but no speaker/device proof yet (host SDL audio path
  needs a listen check or AI-buffer sample verification).
- Audible proof on real speakers/device still pending (the SDL queue
  demonstrably carries audio, but no listen test on hardware speakers yet).
- Touch input beyond overlay visibility is untested on iOS (no simctl touch
  injection; the input path is shared with the verified macOS keyboard path).
- The recompiled `n_aspMain` ucode remains broken (HLE bypasses it); fixing
  it would remove the need for the HLE dependency but is not required for
  playability.
- One iOS stall at t≈256 on 2026-08-05 23:31 did not reproduce on the next
  two runs; treat as intermittent until reproduced on a clean boot.

## Next highest-priority task

Re-verify the iPhone Simulator with the final present fix (only one
Simulator at a time — currently verified on iPad and macOS), then drive a
longer agent playthrough on each target (walk Mario, enter a building,
trigger a text box and a battle) to catch gameplay-era stalls, and confirm
audible audio on real speakers. See `STATUS.md` → Next milestone.

## How to reproduce each issue

- **Intermittent iOS stall**: boot "iPhone 16 Pro", install
  `build-ios-sim/Release/PaperPad.app`, ensure
  `<data>/Documents/baserom.z64` exists (copy from `generated/rom/`),
  `xcrun simctl launch --console-pty <udid> com.chrissotraidis.paperpad`,
  watch the health log (`<data>/Library/Application Support/health.log`) for
  `gfx=+0` followed by a `[freeze]` dump (game state + message tail).
- **macOS teardown crash**: run the app, quit; capture with
  `scripts/capture-crashes.sh`.
- **HLE audio in action**: run with stderr captured; expect NO "RSP ucode 2
  exited unexpectedly" lines, `[health]` audio counters +120 per tick, and
  the SP Task Thread idle between tasks (not spinning in `n_aspMain_impl`).
- **macOS teardown crash**: run the app, quit; capture with
  `scripts/capture-crashes.sh`.
- **macOS audio RSP flood**: run the app with stderr captured; the
  "RSP ucode 2 exited unexpectedly" dumps appear during audio boot.

## Build/launch commands (iOS Simulator)

```
cmake -S . -B build-ios-sim -G Xcode -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DSDL2_DIR="$PWD/build-ios-deps/simulator/sdl2/lib/cmake/SDL2" \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
  -DSPIRV_CROSS_MSL_PATH="$PWD/build/bin/spirv_cross_msl"
xcodebuild -project build-ios-sim/PaperPad.xcodeproj -scheme PaperPad \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl install <udid> build-ios-sim/Release/PaperPad.app
xcrun simctl launch <udid> com.chrissotraidis.paperpad
```

macOS: `cmake --build build-macos2 --target PaperPad -j 8`, run
`build-macos2/PaperPad.app/Contents/MacOS/PaperPad generated/rom/baserom.z64`.
