# PaperPad handoff

Current as of 2026-08-09. The maintained source-build paths are `scripts/build-macos-app.sh` and `scripts/build-ios-simulator.sh`; older `build-macos2`, `build-ios-deps`, and manual `ref/mstan-*` instructions are obsolete.

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

Neither app may contain a ROM.

## Verified behavior

- macOS launches and reaches early gameplay with keyboard input.
- iPhone/iPad Simulator first-run import, gameplay, touch controls, accessible menu, settings persistence, touch layout, and ROM management work.
- iPad Retina rendering and original-aspect framing are fixed in portrait and landscape.
- Empty save-card reads, HLE audio task handling, and RT64 Metal worker teardown have maintained fixes.

## Highest-priority next acceptance

1. Rebuild both final artifacts and rerun repository/package checks.
2. Run longer chapter-spanning and soak tests with crash/log inspection.
3. Add a reviewed ROM-free physical-device build and perform on-device audio, lifecycle, thermal, controller, touch, and accessibility acceptance.
4. Resolve or explicitly disposition the remaining non-blocking runtime diagnostics listed in `docs/STATUS.md`.
5. Complete notices, rights, signing/notarization, privacy, and package audits before any public binary.

Always test one simulation or game process at a time. Terminate PaperPad and shut down Simulator before launching a comparison app or macOS runner.
