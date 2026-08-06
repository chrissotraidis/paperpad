# PaperPad handoff

Latest: 2026-08-05 21:30 (America/Chicago). See `STATUS.md` for the
authoritative status table, `TESTING.md` for evidence, and `KNOWN-ISSUES.md`
for the full issue list.

## What works

- **macOS app launches reliably and plays Paper Mario's intro** (logo, star
  scene, first cutscene, ~60fps for 1-3 minutes): decomp
  (`ref/papermario` pmret @ `c61db66`) -> AOT
  (`generated/aot/paper_mario_recomp_out/`) -> mstan N64ModernRuntime + RT64
  (both pinned + AnnePad patches in `ref/mstan-*`) -> SDL2/Metal runner
  (`src/paperpad_main.cpp`) with vendored static SDL2 2.32.10 and three local
  runtime patches (see `KNOWN-ISSUES.md` macOS #5 and `BUILDING.md`).
  Evidence: `docs/evidence/macos-opening-scene.png` and 2026-08-05 21:0x
  cutscene captures.
- **iPhone Simulator app builds, installs, launches, and renders** the intro
  under Metal with the Paper Mario touch overlay (stick, D-pad, A/B/Z,
  C-buttons, L/R, START). Evidence: `docs/evidence/ios-iphone-running.png`,
  `docs/evidence/ios-iphone-touch-overlay.png`.
- Crash-log capture: `scripts/capture-crashes.sh` archives
  `~/Library/Logs/DiagnosticReports/PaperPad-*.ips` into `logs/crashes/` with
  one-line summaries (exception, signal, faulting thread, top frames).
  22 reports archived 2026-08-05.
- ROM present via `generated/rom/baserom.z64`, verified z64 sha1
  `3837f44cda784b466c9a2d99df70d77c322b97a0`; never committed.

## What does not work

- **Game freezes at a scene transition 1-3 minutes into the intro (primary
  blocker, both platforms)**: the mstan cooperative scheduler deadlocks when
  every game thread parks in `osRecvMesg`. Host-delivered retraces land in the
  guest queue but no game thread is resumed, so `step_game_loop` stops being
  called. The audio RSP ucode grind (`n_aspMain` UnhandledJumpTarget /
  crawl) is a downstream symptom. Full analysis in `KNOWN-ISSUES.md` macOS
  #5.
- Audio is unverified everywhere (RSP flood on both platforms; macOS reaches
  gameplay anyway).
- macOS teardown crashes in RT64 worker autorelease cleanup
  (`objc_autoreleasePoolPop`); gameplay unaffected.
- iPad Simulator untested (same code path as iPhone; blocked by the stall).
- Touch input beyond overlay visibility is untested (no playthrough reached
  yet on iOS).

## Next highest-priority task

Fix the cooperative-scheduler deadlock at the intro's scene transition so the
game reaches the title screen and gameplay, then verify an agent-driven
playthrough on macOS, iPhone Simulator, and iPad Simulator (one Simulator at a
time). The local runtime patches (monitor pump, host-side wake, scheduler
wait) extend the intro from ~40s to 1-3 minutes but don't fully resolve it;
the next hypothesis to test is a secondary stall at the scene-transition
asset DMA load (the `dma_copy`/PI path) or the audio ucode grind starving the
pump's wake. See `KNOWN-ISSUES.md` macOS #5.

## How to reproduce each issue

- **Intro freeze (macOS)**: `build-macos2/PaperPad.app/Contents/MacOS/PaperPad
  generated/rom/baserom.z64` (or `open build-macos2/PaperPad.app` with the ROM
  at `~/Library/Application Support/pm.n64.us.z64`), wait 1-3 min - the intro
  plays then freezes on a black/transition screen; `[sgl]` stops advancing and
  the health log shows `gfx=+0`.
- **Intro freeze (iOS)**: boot "iPhone 16 Pro", install
  `build-ios-sim/Release/PaperPad.app`, ensure
  `<data>/Library/Application Support/PaperPad/baserom.z64` exists (copy from
  `generated/rom/`), `xcrun simctl launch <udid> com.chrissotraidis.paperpad`,
  wait 1-3 min - intro freezes at a scene transition.
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
