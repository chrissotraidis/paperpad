# PaperPad handoff

Latest: 2026-08-05 18:30 (America/Chicago). See `STATUS.md` for the
authoritative status table, `TESTING.md` for evidence, and `KNOWN-ISSUES.md`
for the full issue list.

## What works

- **macOS app plays Paper Mario's intro** (50-60fps): decomp
  (`ref/papermario` pmret @ `c61db66`) -> AOT
  (`generated/aot/paper_mario_recomp_out/`) -> mstan N64ModernRuntime + RT64
  (both pinned + AnnePad patches in `ref/mstan-*`) -> SDL2/Metal runner
  (`src/paperpad_main.cpp`). Evidence: `docs/evidence/macos-opening-scene.png`.
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

- **iOS boot freezes mid-intro (blocking)**: audio RSP task flood
  (`n_aspMain` UnhandledJumpTarget, exit_reason 3) never clears on iOS - the
  ucode never returns, so ultramodern's graceful drop path never runs. macOS
  survives the same flood; the behavioral difference is unresolved. Full
  analysis in `KNOWN-ISSUES.md` iOS #1.
- Audio is unverified everywhere (RSP flood on both platforms; macOS reaches
  gameplay anyway).
- macOS teardown crashes in RT64 worker autorelease cleanup
  (`objc_autoreleasePoolPop`); gameplay unaffected.
- iPad Simulator untested (same code path as iPhone; blocked by the stall).
- Touch input beyond overlay visibility is untested (no playthrough reached
  yet on iOS).

## Next highest-priority task

Fix the iOS audio RSP stall so boot completes, then verify an agent-driven
playthrough on iPhone Simulator and repeat on iPad Simulator (one Simulator at
a time). Candidate fixes are in `KNOWN-ISSUES.md` iOS #1; start by confirming
whether `n_aspMain_impl` is stuck in the PC 0x10EC loop (watchdog path never
trips) or simply not returning from command dispatch, then test the drop-path
mitigation (treat repeated UnhandledJumpTarget as task completion) to confirm
the game is otherwise playable on iOS.

## How to reproduce each issue

- **iOS boot freeze**: boot "iPhone 16 Pro", install
  `build-ios-sim/Release/PaperPad.app`, ensure
  `<data>/Library/Application Support/PaperPad/baserom.z64` exists (copy from
  `generated/rom/`), `xcrun simctl launch <udid> com.chrissotraidis.paperpad`,
  wait 60 s - intro freezes at the gold/red star-spawn frame; `[gfx] send_dl`
  stops at 1201 while the RSP flood continues.
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
