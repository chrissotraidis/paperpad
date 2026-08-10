# PaperPad iOS validation — 2026-08-10

This record documents the release-candidate iOS Simulator build and hands-on
acceptance performed in Europe/Budapest. It is evidence for the exercised
routes plus a later physical-iPad install/launch check. It is not complete-game
or long-soak certification, and the physical check is not a gameplay pass.

## Physical iPad startup addendum

- Target: iPad Pro 12.9-inch (6th generation), iPadOS 26.5.2, wired/paired, Developer Mode enabled.
- Every Simulator was shut down first. No keyboard or automated gameplay input was sent.
- Final output: ROM-free `build-ios-device/Release/PaperPad.app`, version 0.1.0 (1), arm64, iPhone+iPad families, executable SHA-256 `44607a39552c12692296dbcf1f54c98d1166216b1e8b466df4b19665d978ae52`.
- Xcode automatic development signing embedded matching application/team entitlements and an iPad-inclusive provisioning profile. The host's strict trust-chain check returned `CSSMERR_TP_NOT_TRUSTED`; iPadOS nevertheless validated and installed the signed app successfully.
- The source `.v64` normalized to the supported SHA-1 `3837f44cda784b466c9a2d99df70d77c322b97a0`. CoreDevice app-container copy attempts timed out, so a temporary private seed build called PaperPad's normal validator/importer. PaperPad logged the accepted US 1.0 revision; the seed code and ROM resource were then removed, and the clean ROM-free app was rebuilt and installed over the preserved data container.
- The first ROM-backed physical launch exposed a device-only permission failure: RT64 tried to create `.rt64` at the read-only app-container root. PaperPad now supplies `Application Support/PaperPad/RT64` as RT64's data path.
- The clean final app launched against the private ROM, created a native 2732×2048 drawable, initialized RT64, initialized the recomp heap, installed the game-loop hook, and remained alive through the observation window. Detaching the console requested SDL quit and exited cleanly.
- PaperPad was not previously installed, so there was no existing PaperPad data container to back up or restore.

The native document-picker route, screenshot/visual review, touch gameplay,
audible audio, lifecycle, controller, thermal, and long-session acceptance were
not performed on hardware.

## Artifact and private input

- Source base: `main` at `30a28a9e160ffbebee7a191f2ade5da632528900`, plus the reviewed working-tree changes described in this update.
- Build output: `build-ios-simulator/Release/PaperPad.app`.
- Initial iPhone/iPad audit executable SHA-256: `e2f90aa4c236665e53355dd42c5b181c7c5b78d7183becd0d6414148ea1e4db7`.
- Current iPad stability-follow-up executable SHA-256: `fef7f0188caa4ce448a7d4aaa7b84c6dce94c02e47c46b693b69c1923caf924a`.
- Post-device-path-fix Simulator compile SHA-256: `98f103252fbce85a61fcc39d2a0c5d990f0eb03bb24ee5704e947409745555e6`; build passed, but this artifact was not relaunched in Simulator.
- Bundle: `com.chrissotraidis.paperpad`, version 0.1.0 (1), release profile, arm64 Simulator, iPhone+iPad families.
- The app artifact passed the repository ROM/package audit. The user-owned ROM remained ignored under `ref/` and private Simulator containers; the normalized test input matched SHA-1 `3837f44cda784b466c9a2d99df70d77c322b97a0`.

The first setup attempt exposed an incomplete existing pmret virtual environment:
the directory existed but `ninja_syntax` was absent. `scripts/setup-decomp-tools.sh`
was corrected to install the pinned requirements on every setup run, then the
full source generation and release build completed.

## Sequential procedure

1. Confirm every Simulator was shut down.
2. Boot only iPad Pro 11-inch (M5), iPadOS 26.5.
3. Install and launch the exact release app; inspect the clean first-run ROM UI.
4. Stop the app, seed the ignored normalized ROM into its private Application Support directory, verify the SHA-1, and relaunch.
5. Exercise rendering, settings, diagnostics, modal controls, title/file flow, save creation, and the Mario's House prologue. Start/A used the on-screen controls; Simulator keyboard direction was used only to navigate the file-name grid. Terminate PaperPad and shut down the iPad.
6. Confirm no Simulator was booted, then boot only iPhone 17 Pro, iOS 26.5.
7. Repeat the clean first-run inspection, private ROM seed/hash check, rendering/settings/diagnostics checks, and touch-driven title/file-entry route.
8. Terminate PaperPad, shut down the iPhone, and confirm `simctl list devices` reported no booted device.

No two Simulators or game processes were run at the same time. A reinstall on
the clean iPad Simulator replaced its data-container identity, so the test ROM
was re-seeded and re-hashed before final launch. This is recorded rather than
treated as evidence that a Simulator reinstall preserves app data.

## Acceptance results

| Area | iPad Pro 11-inch (M5) | iPhone 17 Pro |
|---|---|---|
| Runtime | iPadOS 26.5, 1210×834 points @2x | iOS 26.5, 874×402 points @3x |
| Route | Clean first-run UI; logos/story/title; on-screen Start/A plus Simulator directional input for file creation/load; Mario's House prologue | Clean first-run UI; logos/title; file entry using only on-screen Start and A |
| Visual result | Original 4:3 frame centered at native Retina size; no crop, quarter-size viewport, flashing, missing layer, or obvious control collision observed | Original 4:3 frame centered; top-centered menu and compact touch layout stayed within safe areas; no crop, flashing, or missing layer observed |
| Rendering controls | Auto, 1x, 2x, 3x, 4x selected; each matching log line recorded; 4x persisted through relaunch | Auto, 1x, 2x, 3x, 4x selected; each matching log line recorded |
| Diagnostics | System share sheet and report inspected; controls/menu hidden behind share and restored on dismissal | Same |
| Termination | Clean; Simulator shut down before iPhone boot | Clean; all Simulators shut down afterward |

The renderer log distinguishes selectable UI from effective runtime state:
1x reported Original with multiplier 1.00; 2x/3x/4x reported Manual with
multipliers 2.00/3.00/4.00; Auto reported WindowIntegerScale. Every live change
reported `discard=1`, including manual multiplier-only changes.

The shared report contained app/build/system/device/screen/settings metadata,
only `ROM installed: yes`, a review-before-sharing privacy notice, and at most
the last 512 KiB of the current-session stderr log. The local log is private,
mode 0600, data-protected, backup-excluded, replaced per launch, and rotated at
4 MiB. Known Application Support, home, and temporary prefixes are replaced,
but the report is not described as fully anonymized.

## Runtime review and remaining gates

No new `PaperPad*` macOS DiagnosticReport appeared during these sessions and no
fatal, assertion, or crash line appeared in either current-session log. The
following non-blocking diagnostics were reproduced and remain tracked:

- unbalanced UIKit appearance transitions around the SDL view controller;
- duplicate Simulator WebCore/WebKit accessibility-class warning;
- RT64 `RenderPool in Metal is not implemented currently`;
- intermittent `IOSurfaceClientSetSurfaceNotify failed e00002c7`.

Not re-run on this final artifact: native document-picker import after file
selection, invalid-file rejection, every individual N64 button, simultaneous
multi-touch, touch-editor/reset, ROM-manager replacement/removal, rotation,
background/foreground recovery, controller hot-plug, audible audio, or a long
soak. Prior audit evidence covers several of these, but they remain explicit
future final-artifact checklist items. Physical-device signing, installation,
audio, lifecycle, thermal, and long-play acceptance are still open.

## File 1A stability follow-up

The user subsequently reported severe music clipping, visible shudder during
the File 1A transition, and a crash. The report was reproduced and investigated
only on the same iPad Pro 11-inch (M5), iPadOS 26.5 Simulator, with no second
Simulator booted and no keyboard input.

- Before the retained fix, 4x RSS grew from about 744 MiB at 32 seconds to
  1.61 GiB at 79 seconds, 7.67 GiB at 6:58, and 8.77 GiB at 8:14. A 1x run
  showed a similar slope, excluding resolution size as the primary cause.
- The original crash and reproduced resource pressure terminated PaperPad in
  Metal namespace 102 after SimMetalHost disappeared. The launch log also
  caught `CAMetalLayer` display-sync access off the main thread, and the 4x
  run caught a CoreAudio overload.
- The PCM overlap code removed four frames from the byte count but advanced the
  float pointer by only two frames. Advancing by the full channel × frame count
  removes that block-boundary discontinuity.
- Long-lived RT64 Apple threads retained autoreleased Metal-cpp serializer
  wrappers. Per-display-list, per-screen-update, per-present, fence-safe idle,
  and fully synchronized texture-upload-batch pools now drain completed work.
  A broader per-workload pool was tested, produced a SimMetalHost resource-map
  crash, and was removed rather than shipped.
- The retained build entered File 1A, displayed “Mail call!”, crossed into
  Mario's House, and remained alive at 4x. Across a 45-second idle comparison,
  physical footprint moved only 124.0→124.6 MiB and VM allocation regions
  remained exactly 255. At 3:19 after the house transition, footprint was
  127.1 MiB with the same 255 regions.
- Sampled black/fade/exterior/interior transitions showed no stale or
  half-built framebuffer. The final current-session log contained no CoreAudio
  overload, off-main-layer warning, SimMetalHost error, fatal line, or crash.

The Simulator confirms that audio reaches the runtime without the measured
overload and that the identified PCM discontinuity is fixed; it cannot replace
the user's audible listening acceptance. The final stability build was not
re-run on iPhone Simulator in this follow-up.

## Captures

- `15-paperpad-ios-resolution-diagnostics-settings.png`: current five-mode iPad settings.
- `16-paperpad-ipad-final-title-controls.png`: final iPad animated intro and touch layout.
- `17-paperpad-ipad-final-diagnostics-share.png`: iPad system share sheet with all gameplay targets suppressed.
- `18-paperpad-ipad-final-prologue.png`: final iPad Mario's House prologue.
- `19-paperpad-iphone-final-diagnostics-share.png`: iPhone system share sheet with gameplay targets suppressed.
- `20-paperpad-iphone-final-touch-file-entry.png`: iPhone file entry after on-screen Start/A input.
