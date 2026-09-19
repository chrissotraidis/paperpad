# PaperPad Original and PaperPad Boat

The owner's 2026-09-19 decision is to keep **two builds**. Original remains the existing ReCut/RT64 product. PaperPad Boat is a separate native PaperBoat product with PaperPad's Apple controls and setup. Neither app replaces or migrates the other's container. Both can coexist. No shared-save or automatic save conversion is implemented.

| Product | Identity | Current delivery |
|---|---|---|
| PaperPad Original | `com.chrissotraidis.paperpad` | Existing public `v0.1.0-preview.2`, unchanged |
| PaperPad Boat | `com.chrissotraidis.paperpad.boat` | Private development candidate, 0.2.0/build 1; iOS/iPadOS 16.3+ |

The original app's source-maintenance PR #6 remains separate. This branch builds on that source/docs work but does not change Original's runtime pin or build entry points. The same UIKit files provide touch layouts, independent phone/tablet preferences, ROM validation, settings and bounded diagnostics. Boat-specific hooks compile only for its own target. The earlier audit's single-successor recommendation is superseded by the owner's two-build instruction.

## Source and fixes

[paperboat.lock.json](../paperboat.lock.json) records the exact maintained PaperBoat, libultraship, Torch and 14 fetched Git dependency commits, plus hashes for two downloaded files. PaperBoat's upstream base remains `2f7d38e07bcb85c216bf37e8a0a1a5cf8731ceef`. The maintained PaperBoat fork is connected to HarbourMasters/PaperBoat. The existing libultraship fork is connected to Kenix3/libultraship; its project branch starts from the exact audited JeodC commit `7aa03b6c830b059e3ddd6ad20d3f289c5f406161`. Its default branch and other apps' pins are unchanged.

- Enable Objective-C as a distinct CMake language so SDL `.m` files do not receive Objective-C++ standard flags.
- Resolve the configuration filename once; honor the private Application Support path on iOS.
- Reuse PaperPad's accepted controls and controller-slot reconciliation. Match Original's button/keyboard defaults, 8,000-unit SDL deadzone, additive input composition and 127-unit N64 stick range. UIKit remains the only game touch overlay; PaperPad supplies game input.
- Preserve native volume, original/expanded aspect and automatic/1x–4x resolution controls through a narrow engine adapter. The resolution readout uses renderer-reported dimensions.
- Extract the validated ROM through Torch with a native progress screen into a private temporary directory; commit the finished archive only after ZIP consistency validation. Preserve invalid prior archives for diagnosis. ROM removal also removes Boat's derived game archive, keeping saves and settings.
- Correct `partnerUsedTime` loading, initialize save memory and release temporary allocations on parse failures. Save via a flushed temporary file and atomic replacement; keep a valid previous backup, recover from it when necessary, protect unreadable slots from overwriting, and show native errors instead of silently claiming success. No Original FlashRAM image is consumed.
- Carry [upstream PR #157](https://github.com/HarbourMasters/PaperBoat/pull/157), original commit `52680665aa0f45740df31ee164a1c51c670db35b`, with Jeod's authorship: clear stale battle damage-popup effect references after effect removal. Source integration is verified; battle regression gameplay remains untested.
- Capture upstream stdout/spdlog in the existing bounded PaperPad log instead of opening a second rotating log. Include engine identity, input changes, controller changes, map transitions, settings, renderer dimensions, periodic frame progression and a stall watchdog. Sharing retains the original bounded report and path sanitization. Private compiler paths are remapped out of executable strings.

The fetched ImGui package has libultraship's pre-existing four-file configuration/backend patch; zlib relocates its tracked configuration header during CMake preparation. These are recorded, upstream-owned package exceptions, verified by exact prepared hashes/deletion state. They are not PaperPad gameplay patches. Bootstrap/build scripts never reset an existing engine working tree.

## Build and validate

```sh
scripts/build-paperboat.sh device
scripts/build-paperboat.sh simulator
python3 scripts/test-paperboat-save.py
clang++ -std=c++20 -Iapple/paperboat -Ibuild-paperboat-ios/_deps/sdl2-src/include tests/paperboat_input_test.cpp -o /tmp/paperboat-input-test
/tmp/paperboat-input-test
```

Requires Xcode/iOS SDK, CMake, Ninja, Python and network access for initial CMake dependency downloads. Builds produce `build-paperboat-ios/Paperboat.app` and `build-paperboat-simulator/Paperboat.app`. The default is unsigned. For deliberate source development, `PAPERPAD_ALLOW_DIRTY=1` permits source edits; a dirty build is never eligible for packaging. Source pins must still agree. Commit the app and engine before qualifying artifacts.

```sh
python3 scripts/package-paperboat.py /absolute/private/output/PaperPad-Boat-0.2.0-dev.ipa
```

Packaging verifies the recorded clean build commit, source inputs, executable hash, pins, prepared dependency hashes, bundle/version/platform, system dynamic dependencies, absence of private build paths and loose game/save/signing data. It bundles source provenance and per-component notices. It does not publish. The existing `source-archive.py` workflow qualifies **Original only**; a complete restored/offline Boat source-delivery rehearsal is still pending. Do not call the new source graph fully release-qualified on the strength of the earlier Original archive test.

## Evidence and remaining acceptance

Clean device and Simulator Release builds passed at application commit `fd476fd`. The unsigned device candidate (0.2.0/build 1) passed the package audit: SHA-256 `a4f47808b586580097e5a4487a8d49a134f145f87c3bfb26341ed60452b5b74d`. Hosted source-integrity CI also passed. A fresh dedicated Simulator showed the native missing-ROM screen, then extracted a private copy of the supported ROM and rendered the animated intro with the PaperPad overlay. Frame-progress logs continued through the intro. Existing saves in the original app were never opened or modified. These are Simulator startup/rendering observations, not physical-device or full-game acceptance.

The real native save codec passed distinct partner-time-array values, complete JSON round trip, malformed-field rejection, atomic file replacement and backup retention tests. Input tests cover the Original mapping contract; existing controller-slot tests cover disconnect/reconnect ownership. Simulator emitted audio-underrun warnings during concurrent compilation; no physical listening/latency claim is made. Extraction also emitted an upstream asset-clash diagnostic while still completing and rendering; broader visual/gameplay qualification must include it.

A persisted-settings test on the dedicated Simulator verified 2x resolution at 640×480 in Original aspect and 1043×480 in Fill Screen, with corresponding frame logs and screenshots. This exercised the settings-to-renderer path by seeding preferences, not by pressing the settings UI. [Original issue #5](https://github.com/chrissotraidis/paperpad/issues/5) stays open because this separate product does not establish a fix in the released Original build.

Native UI interaction through the available computer-use tool was unavailable for Simulator. Consequently actual touch presses, settings/share-sheet interaction, save/reload gameplay, physical controller handoff and audio/lifecycle acceptance remain explicit follow-up checks. No hardware installation or binary release occurred. File formats and saves remain isolated. Upstream/current-source licenses and game-derived-content rights still need distribution qualification; notices and a fork relationship do not resolve that boundary.

## Recovery

Original main and public Preview 2 are unchanged. The verified private backup from the original audit remains at the location recorded in the task recovery handoff; it includes the accepted artifact and complete prior working inputs. Boat uses its own bundle/container, so removing or abandoning its development branch does not require rolling back Original. Never install Boat over Original's identity or convert a user's only save copy. Keep development builds and locally extracted data private.
