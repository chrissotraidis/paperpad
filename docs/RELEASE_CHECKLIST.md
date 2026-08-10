# Release checklist

Use this checklist for a public source update and again before any macOS or iPhone/iPad binary. A successful compile or short playtest is not, by itself, a release pass.

## Source release

1. Confirm intended paths with `git status -sb`, review the complete diff, and run `git diff --check`.
2. Run `scripts/check-repo-safety.sh`. Resolve every game-data, generated-output, package, signing, credential, size, syntax, or Git-integrity failure.
3. Run `scripts/clone-sources.sh`, `scripts/verify-sources.sh`, and `scripts/apply-patches.sh` from a clean local source-input state.
4. Confirm the README, rights boundary, dependency inventory, build instructions, status, and screenshots state only evidence actually reproduced.
5. Confirm no personal paths, user names, private device identifiers, or sensitive logs are in tracked text or images.
6. Stage only reviewed paths. Verify the final published commit separately from the working directory used for private ROM-backed testing.

## macOS binary

1. Build with `scripts/build-macos-app.sh` from already generated local source, or pass `--rom` for a clean private generation.
2. Verify `build-macos-release/PaperPad.app` is arm64, ad-hoc signed as intended, and contains no ROM, generated AOT tree, save, personal path, credential, profile, certificate, or private key.
3. Launch the exact final artifact and exercise: startup, title input, file creation/load, early gameplay movement, menu/dialogue input, audio, controller hot-plug if claimed, and clean quit.
4. Run at least a 60-minute soak and inspect crash reports and runtime logs.
5. Before public distribution, define and verify signing, hardened runtime, notarization, update channel, privacy disclosure, and complete third-party notices.
6. Record version, commit, SHA-256, signing/notarization state, tested hardware/OS, playtest duration, and remaining limitations in release notes.

## iPhone and iPad Simulator

1. Build with `scripts/build-ios-simulator.sh`; verify `build-ios-simulator/Release/PaperPad.app` contains no ROM.
2. Run one Simulator/app at a time. Fully terminate and shut down a target before starting a comparison app or macOS runner.
3. On both an iPhone and iPad Simulator, exercise first-run import, invalid-file rejection, title/file flow, early gameplay, every touch control, simultaneous touches, settings persistence, touch editor/reset, ROM manager, portrait/landscape recovery, background/foreground, and clean terminate.
4. Select Auto, 1x, 2x, 3x, and 4x separately; confirm the renderer scale, live framebuffer rebuild, and relaunch persistence rather than recording UI selection alone.
5. Verify menu/settings presentation clears held input and suppresses gameplay touch targets, then restores them according to the saved Touch Controls switch. Generate `PaperPad-Diagnostics.txt`, inspect its metadata/log boundary and path replacement, and cancel the system share sheet without sending it.
6. Inspect accessibility labels/values for setup, persistent menu, settings, switches, sliders, alerts, and ROM flow. Record gameplay-overlay limitations honestly.
7. Run a long soak and inspect console and crash reports.

## Physical iPhone and iPad

No physical-device build or package is currently published. Before changing that status:

1. Add and review a generic device build that does not embed signing identities or provisioning material.
2. Audit the unsigned app before adding a local signature outside the repository.
3. Install on every intended device class and OS; verify live launch, Metal features, Retina sizing, touch feel, controller behavior, audible audio, interruptions, background/foreground, thermal behavior, memory pressure, saves, reinstall/update behavior, and long gameplay.
4. Validate privacy manifests, entitlements, encryption declarations, accessibility, complete notices, package contents, and distribution rights.
5. Record artifact SHA-256, signing method, device/OS coverage, playtest duration, and known limits. Do not describe local signing, TestFlight, App Store, or a prebuilt download as available until that exact path is reproduced.
