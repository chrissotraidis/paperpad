# PaperPad Original and PaperPad Boat

The owner's 2026-09-19 decision is to keep **two builds**. Original remains the existing ReCut/RT64 product. PaperPad Boat is a separate native PaperBoat product with PaperPad's Apple controls and setup. Boat is the default entry point. Its three-dot menu offers **Launch Original**, opening the separately installed companion through `paperpad-original://launch`. Neither app replaces or migrates the other's container. Both can coexist. No shared-save or automatic save conversion is implemented.

| Product | Identity | Current delivery |
|---|---|---|
| PaperPad Original | `com.chrissotraidis.paperpad` | Existing public `v0.1.0-preview.2`, unchanged |
| PaperPad Boat | `com.chrissotraidis.paperpad.boat` | Private iPad test, 0.2.0/build 4; iOS/iPadOS 16.3+ |

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

Native UI interaction through the available computer-use tool was unavailable for Simulator. Consequently actual touch presses, settings/share-sheet interaction, save/reload gameplay, physical controller handoff and audio/lifecycle acceptance remain explicit follow-up checks. At this initial build 1 checkpoint, no hardware installation or binary release had occurred; the later build 2 device test is recorded below. File formats and saves remain isolated. Upstream/current-source licenses and game-derived-content rights still need distribution qualification; notices and a fork relationship do not resolve that boundary.

## Recovery

Original main and public Preview 2 are unchanged. The verified private backup from the original audit remains at the location recorded in the task recovery handoff; it includes the accepted artifact and complete prior working inputs. Boat uses its own bundle/container, so removing or abandoning its development branch does not require rolling back Original. Never install Boat over Original's identity or convert a user's only save copy. Keep development builds and locally extracted data private.

## iPad test — build 2

At app commit `fba0d03`, Boat 0.2.0/build 2 was built, signature-verified, installed and launched on the owner's physical iPad. Its private unsigned IPA SHA-256 is `3fe4920fc6b622a05622c09208c4ecdd0ecbbae47140777baffcab87bef6a602`. Device and Simulator builds, source/package checks, input/save tests and hosted CI passed. Physical logs show completed ROM extraction, initialized SDL audio, advancing frames and map transitions; no visual, listening or full-game acceptance is inferred from those logs.

Original's private companion is Preview 2 with only the registered launch scheme, display name and build metadata changed (0.1.0/build 3). `scripts/stage-original-launcher.py` requires the exact accepted public IPA and proves its unsigned executable is unchanged before signing. It stages a fresh copy and never edits an existing artifact. Future source builds also register the scheme. Both installs used the existing signing team; Original retained its exact application entitlements.

Before updating Original, all 11 Documents/Library files were backed up, archived, restored separately and hash-verified. All 11 remained byte-identical after the in-place update; save files were checked again after launching Original and still matched. Boat received a verified copy of the existing ROM in its own container, with no Original saves imported. A missing Original companion produces a native message and releases modal input suspension.

The installed pair's URL registrations and versions were read back. Original launched with its URL payload; the Boat URL opened the Simulator build. Physically tapping the three-dot action, controller/touch behavior, audio quality and save/reload gameplay remain owner acceptance checks. The device screenshot service was unavailable; no on-device screenshot or visual acceptance is claimed. Existing extraction asset-clash diagnostics remain recorded. No public binary release was published.

### Build 3: native iPad window correction

The owner reported that build 2 opened in a compatibility window. The Boat Ninja bundle omitted `UIDeviceFamily`, unlike Original's Xcode-produced `[1, 2]` declaration. The initial iPhone Simulator test did not cover this packaging boundary. Commit `6a5446f` adds explicit iPhone/iPad family metadata, the matching Xcode target property, package assertions for native iPad/full-screen/landscape support and startup window diagnostics.

Build 3 was audited, signed and installed in place on the same iPad. Its live log reports `idiom=1 bounds=1366x1024 screen=1366x1024 scale=2.0`, establishing native iPad mode and a window matching the full screen. The private unsigned IPA SHA-256 is `a98526d7cb2d1d0af9d380b0883646fa4e965335e770d41c9c409252a1b0cf2d`. Boat's 20 pre-update files were backed up; ROM/archive bytes and existing configuration values were preserved (upstream added missing controller defaults). Original was untouched during this correction. Physical gameplay and interaction acceptance remains separate from the window-size proof.

### Build 4: menu, floating stick, reporting and Auto

At app source `07ac459`, the three-dot button uses a native grouped UIMenu, following SunPad's navigation pattern: Settings, Controls, Game Data & Saves, Support and Launch Original. Diagnostics/ROM actions are removed from the settings sheet. Support offers a reviewable GitHub issue draft and the bounded diagnostics share; reports name this repository, its issues URL, the actual engine/upstream, source commit when packaged, and optional reporter context. No issue is posted automatically.

The analog stick is invisible at rest, anchors at the first left-side touch, keeps that finger's ownership across movement, rejects a second stick owner and disappears on release. Buttons retain hit-test priority. Layout editing still displays the editable resting control. This follows KartPad/MeleePad floating-stick behavior; existing N64 response mapping remains intact.

Boat Auto previously used a fractional window-sized render target while its UI claimed whole-number scaling. Auto now uses the Metal drawable size to choose a whole-number scale from 1x through 4x, with fixed-scale modes unchanged. The real iPad reports a 2732×2048 drawable, Auto=4x and sustained 1280×960 internal rendering in 4:3 mode. Tests cover iPad/phone, smaller viewports, Fill Screen and unavailable-drawable fallback. This is deterministic resolution selection, not adaptive frame-rate scaling.

Clean device/Simulator builds, real save-codec/input/Auto tests, repository checks, package audit and hosted CI passed. Private unsigned IPA SHA-256: `d4c1de6c26530c8a0e156ce01f4aa8b0189e365e0b5a972abff131bab5a74dda`. Build 4 was signed with the established identity and installed in place. QuickTime's existing physical iPad mirror showed full-screen startup with the stick hidden at rest. Runtime logs show native iPad bounds and the expected render size. Actual menu/submenu/share interactions and the moving thumb gesture remain owner acceptance unless separately recorded.

The owner's apparent missing save was investigated before edits: both Original FlashRAM files still matched the pre-deployment backup byte-for-byte, and the latest records for two logical save slots passed checksums. Boat had no save files in its separate container. No save was deleted or converted. Original remains the way to continue that existing progress; a verified endian-aware native-format import is separate work. The menu now explains this distinction. Boat's complete relevant container was backed up/restored/hash-verified before update; ROM/archive hashes and existing native preferences matched after update. Original was untouched.


## Menu refinement — private iPad build 5

Source `87c24db543dec2545804bd6c8d986edda4705c64` applies SunPad's fixed capsule UIButton configuration, disabling automatic configuration and selection changes so menu dismissal does not synthesize a rectangular selected background. **Display & Audio** contains volume, resolution and aspect ratio. **Controls → Touch Settings** contains the touch-enable switch and opacity; Edit Touch Layout and Reset Touch Layout stay alongside it under Controls. Game Data & Saves, Support and Launch Original remain available. Each sheet updates only its own preference fields.

Clean device and Simulator builds, save-codec/input tests, repository checks and the exact-source package audit passed. Unsigned build 5 SHA-256: `9e4caba6bbe71a30c5e11f1dc53494fd0989257c45c4e23f0d9f34c576610350`. Installed and launched in place on the authorized iPad with matching application/team/keychain entitlements. Logs show continued frame progression at 1280×960. Direct dismissal-animation and settings-sheet interaction acceptance remains pending; startup is not proof of those gestures.

A fresh complete Documents/Library backup was restored separately and hash-verified immediately before installation. Unlike the earlier build 4 checkpoint, Boat now contains the owner's new save. Post-install readback before launch confirms that save, ROM data and preferences are byte-for-byte unchanged; only system launch snapshots changed. Original was untouched. Private backup/recovery instructions and signed build 4 rollback artifact remain preserved on the same physical disk. No public release or merge occurred.


## Compact settings and product naming — private build 6

The app and candidate IPA are named **PaperPad** (`PaperPad.app` / `PaperPad.ipa`). The existing Boat bundle identifier remains unchanged to preserve installed data. Source `d92bfe1d7d2875d762513085d48f46b34e4abc14` replaces the older custom settings panels with one native grouped controller, presented as a compact anchored popover on iPad. Both panels size to their actual content; Touch Settings has two controls. Display & Audio retains volume, resolution/aspect selection and live effective-renderer status. Each setting updates its own preference without overwriting the others.

Launch Original now explains that the older PaperPad remains supported but has been superseded, and that older saves remain there while current progress stays separate. Cancel keeps the current app open; Open Original launches the companion. The redundant About Original Saves action was removed. Missing-companion feedback is retained.

Device and Simulator builds, save-codec/input tests, repository checks and package audit passed. Unsigned `PaperPad.ipa` SHA-256: `ba8013689a57b584848b645af540e70384f29cba0fbd5fd760aa3f4ea8018bb2`. Signed build 6 installed and launched in place with matching identity/entitlements. Fresh complete Documents/Library backup restored and hash-verified; post-install readback confirms the current Boat save, ROM and preferences unchanged, with only system launch snapshots changing. Original untouched. Direct physical panel/prompt interaction remains owner acceptance. Same-disk private recovery instructions and the signed build 5 rollback remain preserved. Public Preview 2 is unchanged; this is not a public binary release or completion of the remaining source-delivery/rights qualification.


## Version 0.2.0 source delivery

The PaperPad source asset includes the application and all three pinned engine/nested repositories, all fourteen prepared CMake dependencies, and the three pinned downloaded headers/data files. Minimal Git snapshots contain only each selected commit and its tree, preserving exact IDs without unrelated history or local configuration. Original's separate runtime is outside this Boat-specific archive. Hashes and modes are recorded in `SOURCE_MANIFEST.json`.

Create with `python3 scripts/paperboat-source-archive.py --output /absolute/path/PaperPad-source.tar.gz`. Extract into a new directory, verify with `python3 scripts/paperboat-source-archive.py --verify .`, and build with `python3 scripts/build-paperboat-offline.py`. Installed Xcode/iOS SDK, CMake, Ninja and Python remain required. The offline build redirects FetchContent to included exact sources and rejects missing or mismatched pinned downloads; it never fetches replacements. This source asset contains no ROM, extracted game archive, saves, signing inputs or proprietary SDK. Per-component terms and the documented rights limitations remain applicable; delivery is not a blanket rights grant.


### Build 7 release qualification (2026-09-20)

The source-archive rehearsal restored 18 exact Git snapshots and all three downloaded inputs, then built and packaged the iOS target with `sandbox-exec` denying network access. The resulting IPA passed the same bundle, pin, license, private-path and restricted-data audit. All 68 uncompressed entries of the generated port-resource archive matched the normal build; controller database and bundle metadata matched. Raw resource ZIP and executable bytes differed between build trees, so this is an offline source-reproduction result, not a claim of bit-for-bit reproducible binaries. Missing offline inputs and a modified source file were rejected by the verification checks.

Build 7 adds the previously omitted stb/sse2neon header notices, pins stb's exact bytes, and records toolchain versions. It changes no game/control implementation or engine source pin. The owner explicitly requests public preview publication while third-party rights limitations remain documented; no blanket clearance or new hardware/gameplay acceptance is asserted. The title-menu stutter remains known. Original is unchanged, and no device container is modified during release preparation.
