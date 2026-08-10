# PaperPad handoff

Current as of 2026-08-10. The maintained source-build paths are `scripts/build-macos-app.sh` and `scripts/build-ios-simulator.sh`; older `build-macos2`, `build-ios-deps`, and manual `ref/mstan-*` instructions are obsolete.

## Reproduce the current build

For a clean private generation, pass an absolute legal ROM path to either top-level build script. For an incremental build, omit `--rom` after `generated/aot/paper_mario_recomp_out/lookup.cpp` exists.

```sh
scripts/build-macos-app.sh --rom /absolute/path/to/rom
# or
scripts/build-ios-simulator.sh --rom /absolute/path/to/rom
```

Expected outputs:

- `build-macos-release/PaperPad.app`
- `build-ios-simulator/Release/PaperPad.app`
- `build-ios-device/Release/PaperPad.app` after a locally signed Xcode device build

Neither app may contain a ROM.

## Verified behavior

- macOS launches and reaches early gameplay with keyboard input.
- A ROM-free signed arm64 development build installed on a physical iPad Pro 12.9-inch (6th generation), iPadOS 26.5.2, and launched against a separately stored validated private ROM. Native 2732×2048 Metal setup, recomp-heap initialization, and the game-loop hook passed. This was not a hands-on physical gameplay or visual pass.
- The 2026-08-10 iPhone/iPad Simulator artifact passed clean first-run UI, touch-driven title/file flow, Auto plus 1x–4x renderer confirmation, diagnostics sharing, modal touch suppression/restoration, and clean terminate. iPad 4x persistence passed a terminate/relaunch check.
- Native document-picker import, invalid-file handling, rotation, layout editing/reset, and ROM management retain the earlier audit evidence; they were not re-run on the final 2026-08-10 artifact.
- iPad Retina rendering and original-aspect framing are fixed in portrait and landscape.
- Empty save-card reads, HLE audio task handling, and RT64 Metal worker teardown have maintained fixes.
- The iPad-only File 1A follow-up fixed runaway Metal serializer retention,
  a half-frame PCM overlap offset, and off-main `CAMetalLayer` display-sync
  access. The retained 4x build reached Mario's House and held 255 VM
  allocation regions through the measured idle/transition window.

## Highest-priority next acceptance

1. Re-run macOS and both Simulator routes on the final RT64 data-path change. The final source compiled for physical iOS and Simulator and passed physical iPad engine startup, but the hands-on Simulator routes predate that last path-only change.
2. Re-run the final iPad stability changes on iPhone Simulator, then run longer chapter-spanning and soak tests with crash/log inspection on both device classes.
3. Extend the physical iPad startup evidence through native document-picker import, visuals, gameplay, audio, lifecycle, thermal, controller, touch, and accessibility acceptance; repeat the signed build/install flow on physical iPhone.
4. Resolve or explicitly disposition the remaining non-blocking runtime diagnostics listed in `docs/STATUS.md`.
5. Complete notices, rights, signing/notarization, privacy, and package audits before any public binary.

Always test one simulation or game process at a time. Terminate PaperPad and shut down Simulator before launching a comparison app or macOS runner.
