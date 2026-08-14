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
4. Select Auto, 1x, 2x, 3x, and 4x separately; confirm the renderer scale/internal dimensions, live framebuffer rebuild, and relaunch persistence rather than recording UI selection alone. Record that Auto may exceed manual 4x.
5. Confirm the rejected Crisp 2D selector is absent, diagnostics reports `Smooth (fixed)`, and no setting migration re-enables it. Exercise Original/Fill Screen on iPad and wider iPhone, verify the presentation-only crop, and confirm battle pointers remain attached to their targets. Verify each native action row plus Done has clear affordance and a reliable 44-point-or-larger target.
6. Verify menu, settings, ROM, and share-sheet presentation clears held input and suppresses every gameplay touch target, including the utility button, then restores controls according to the saved Touch Controls switch.
7. Force one disposable unclean termination, relaunch, and generate `PaperPad-Diagnostics.txt`. Confirm the bounded current and possible-unclean previous tails, 4 MiB private-file caps, metadata, ROM-present-only boundary, and path replacement. Review the report and cancel the system share sheet without sending it.
8. Inspect accessibility labels/values for setup, persistent menu, settings, switches, sliders, alerts, and ROM flow. Record gameplay-overlay limitations honestly.
9. Run a long soak and inspect console and crash reports.

## Physical iPhone and iPad

Preview 1 is a public ROM-free **unsigned** IPA for self-signing. Its package audit passed for arm64 iPhoneOS 15.0, version 0.1.0 build 1, bundled notices/privacy/licenses, and the absence of ROMs, saves, logs, profiles, signatures, personal paths, and non-system runtime dependencies. Its deterministic SHA-256 is `03a4b1006dbfc91ec8abb849df5c59b49145a5feb215b179ff1da10001848045`.

Before a stable or maintainer-signed release:

1. Add and review a generic device build that does not embed signing identities or provisioning material.
2. Audit the unsigned app before adding a local signature outside the repository.
3. Use the same bundle identifier and install in place without removing or replacing the existing data container. Do not copy whole app-data folders unless the device owner explicitly requests it; limit any read-back to exact, approved files. Install on every intended device class and OS; verify live launch, Metal features, Retina sizing, touch feel, controller behavior, audible audio, interruptions, background/foreground, thermal behavior, memory pressure, saves, reinstall/update behavior, and long gameplay.
4. On physical hardware, listen through the title, file selection, File 1A transition, Mario's House, sustained music, and representative effects. Confirm no clipping, growing latency, queue fault, or regression across background/foreground and a longer session.
5. Pair a supported controller and verify the complete mapping, hot-plug/reconnect, automatic touch-overlay hiding, utility-menu access, disconnect restoration, and a sustained gameplay route.
6. If a private later-game File 2 is used, verify File 1 remains byte-for-byte unchanged, load File 2, exercise a battle/transition/save/relaunch route, and keep every donor and merged save out of source and packages.
7. Validate privacy manifests, entitlements, encryption declarations, accessibility, complete notices, package contents, and distribution rights.
8. Record artifact SHA-256, signing method, device/OS coverage, playtest duration, and known limits. Do not describe TestFlight, App Store, or a maintainer-signed download as available until that exact path is reproduced.
