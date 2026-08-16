# PaperPad status

Updated 2026-08-16 (Europe/Budapest). This file distinguishes reproduced acceptance from planned work.

## Current acceptance

| Target | Status | Reproduced evidence |
|---|---|---|
| Apple Silicon macOS | **Verified local source build** | ROM-free app build/signature check; launch through intro, name/file creation, and early gameplay; keyboard input; clean test quit |
| iPhone Simulator | **Current development build verified** | 2026-08-11 in-place update preserved private data; current audio telemetry, live Auto 6x/1920×1440 status, 22 KiB diagnostics share/dismissal, modal touch restoration, touch-only name-entry `A → B → o`, and the corrected non-overlapping compact layout passed |
| iPad Simulator | **Current development build verified** | Stateful audio PCM comparison, crash-log rotation, live Auto 7x/2240×1680 status, first-level diagnostics, modal touch restoration, borderless maximum-size 4:3 framing, private level-27 Toad Town loading/movement, a direct drawable/frame-pacing leak regression, and a no-input unattended-battle cursor-alignment route passed; earlier evidence covers File 1A/Mario's House at 4x |
| Physical iPad | **Preview 2 release candidate installed in place and booted; physical reconnect open** | The signed build installed under the existing bundle ID without uninstalling or replacing the data container, launched into active gameplay, and remained live. Exact pre/post read-back comparisons preserved the existing ROM files, save and backup, ROM selection, and controller/touch preferences. Earlier Kishi V2 play verified analog and A/B/Z/L/R/Start; Bluetooth, wired, and natural-sleep reconnect were not exercised |
| Physical iPhone | **Clean build installed and runtime verified; hands-on open** | The current ROM/save-free app was installed on an iPhone 14 after privately seeding the exact iPad test ROM and 128 KiB save. A clean in-place reinstall then initialized the recomp heap, renderer, project audio RSP, and game loop through an opening scene at the 2532×1170 native drawable. File-select/save visibility, touch ergonomics, controller behavior, audio, and lifecycle still require hands-on acceptance |
| Public iOS preview | **ROM-free unsigned Preview 2 packaged** | `PaperPad-v0.1.0-preview.2-unsigned.ipa`; arm64 iPhoneOS 15.0; version 0.1.0 build 2; no ROM/save/log/profile/signature/personal path; bundled privacy manifest, notices, install guide, rights statement, and dependency licenses; deterministic SHA-256 `ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029` |
| Signed/notarized/TestFlight/App Store | **Not available** | Preview 2 requires user self-signing. Maintainer-signed, notarized, TestFlight, and App Store distribution remain open |

The tested build identifies as version 0.1.0 (build 2), profile `release`, bundle ID `com.chrissotraidis.paperpad` on iOS.

## Controller reconnect repair verified on 2026-08-16

- PaperPad uses direct SDL2 `SDL_GameController` ownership. It does not use SDL3, own Apple's GameController framework directly, or delegate controller slots to the recompiled engine.
- Reconciliation uses SDL2's supported attached-state check, current-device enumeration, and instance IDs. It runs for controller events, foreground resume, and a bounded active poll without restarting the controller subsystem.
- Deterministic tests simulate a missed removal while a button and axis are held, then verify stale-slot removal, neutral input, and player-1 reclamation. Separate cases preserve player 1 when a second controller arrives or reconnects and cover foreground reconciliation.
- Instance ID, player slot, device index, reason, and controller name are logged for assignment/release diagnosis.
- The complete macOS build/test target, ROM-free iOS Simulator build, signed physical-device build, strict signature verification, repository audits, and exact in-place iPad boot passed. These are automated and host-observable proofs; no claim is made that physical Bluetooth, wired, or natural-sleep reconnect was exercised.

## Fixes verified in the 2026-08-11 iPad Simulator defect pass

- A bounded source/output capture isolated one audio defect to the stateless per-block sample-rate converter. A continuous `SDL_AudioStream` removed that measured contamination. Pre-submit instrumentation later exposed repeated device-queue drains hidden by the old post-submit counter; host-queue feedback and measured 2.5-VI headroom eliminated post-startup drains in the instrumented run.
- Paper Mario's audio task enters its game-specific microcode at IMEM `0x1080`, not the generic `0x1000` entry previously generated. PaperPad now generates the exact project audio RSP function at `0x1080`, selects it for `M_AUDTASK`, and preserves synchronous SP completion order. Runtime diagnostics confirmed the exact backend on the physical iPad, and the user's next listening route reported that audio sounded fixed. This is one hands-on pass, not chapter-spanning proof; recurrence remains a reopen condition.
- The destructive queue catch-up path was removed. It had shortened already rendered PCM by retaining every second/fourth/etc. frame and could create unavoidable cadence/pitch discontinuities even though the observed Simulator queue never reached its 100 ms trigger.
- Diagnostics now rotate bounded 4 MiB current/previous logs, mark an active session with private 0600 files, prioritize the previous log after a suspected unclean exit, and share no more than the last 512 KiB of each. Forced terminate/relaunch and report generation passed.
- `Share Diagnostics & Logs…` is visible directly in the three-dot menu. The generated report includes renderer-confirmed state and continues to exclude ROM/save contents while requiring user review of runtime text.
- Settings shows live renderer-confirmed scale and internal dimensions. iPad Auto reported 7.00x/2240×1680 and the diagnostic report matched it.
- The broad left-side stick pickup targets the visible fixed origin, so its knob and N64 vector share one radius clamp. Released flick retention was narrowed from six runtime polls to one. After physical feedback still found name entry too eager, touch analog output gained a quadratic inner precision curve plus conservative cardinal-axis bias; full rim speed and deliberate diagonals remain available. Fresh hands-on name-entry/gameplay acceptance is open.
- Touch-only name-entry routes on both Simulator device classes moved `A → B` with one horizontal gesture and `B → o` with one vertical gesture, then held position. iPad extreme diagonal gestures also stayed to one adjacent step; its late-game fixture was restored with the original hash. Physical held-knob visuals and human feel remain open.
- The original compact-phone defaults were not actually collision-free: R/L touched and C-up overlapped L. The `iphone.v6` defaults create visible gaps through the shoulder, C, Z, and face-button stack; the rebuilt iPhone 17 Pro Simulator route passed visual review. The iPad layout was not changed.
- The iOS SDL window is borderless. Original preserves the largest centered 4:3 image. Fill Screen now center-crops only the completed 4:3 VI presentation instead of widening RT64's 3D projection. That keeps Paper Mario's game-projected 2D battle hand and target actor under the same final transform; physical confirmation is open.
- Settings explains that Auto may exceed manual 4x, presents Edit/Reset/Diagnostics/ROM as native action rows, and uses a filled Done button. Crisp 2D was removed after physical testing found it visibly worse; the stable smooth path is fixed and low-resolution source text remains a known limitation.
- The README keeps only two primary verification images. A private level-27 fixture was merged into File 2 on the physical iPad using checksum-valid sector rotation. Active File 1's complete sector remained byte-for-byte unchanged, and exact pre/post-update read-back matched merged save SHA-256 `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398`. The donor remains excluded from source and packages; visible File 2 load acceptance is open.
- SDL controller mappings cover hot-plug, left stick/D-pad, A/B/Start, L/R/Z, and right-stick C buttons. A Kishi V2 session exercised analog and A/B/Z/L/R/Start for 16m41s. Automated stale-handle, reconnect, held-input release, two-controller, and foreground-resume cases now pass. Targeted D-pad/C-direction plus physical Bluetooth, wired, and natural-sleep reconnect acceptance remains open.
- In the touch-layout editor, D-pad and C buttons move individually by default. A persisted Link/Unlink action optionally binds only the selected four-button cluster for movement. `iphone.v8` corrects the physically rejected phone spacing; the accepted iPad arrangement remains independent in `ipad.v4`.
- The final Preview 1 phone defaults reproduce the complete `iphone.v8` layout exported from the attached physical iPhone 14 on 2026-08-14. All 15 saved positions, A/B sizes, opacity/visibility, and the unlinked D-pad/C-button state were captured directly; iPad defaults remain unchanged.
- A longer level-27 run exposed a distinct RT64 swap-chain leak despite stable VM-region counts: 42,354 drawables and 757,314 FramePacing command buffers remained live because each slot replacement lost its previous retained owner. The maintained fix replayed cleanly; the rebuilt ROM-free app held exactly 3 drawables, 3 lifetimes, and 72 command buffers across thousands of frames, while physical footprint ended at 130.1 MiB below a 145.3 MiB peak.
- The supplied 12:22 iPhone crash report and an independent 12:32 iPad reproduction exposed RT64 releasing SDL/UIKit's `CAMetalLayer` from the Gfx Thread during shutdown. `ios-metal-view-lifetime.patch` leaves that unowned layer to UIKit on iOS; active-rendering shutdown regressions on both Simulator classes produced no newer report.
- The final Preview 1 source compiles and signs as arm64 iPhoneOS. Strict verification passed for executable SHA-256 `ea1453bc17d209ffd4b38a99a2f7299438f444e6d334122de1b96aaada3b6541`, team `VKDH2T9UTF`, and the existing Xcode-managed wildcard profile. The ROM/save-free app installed in place on the attached iPhone 14 and launched without a container reset. Exact post-install private-file read-back remains unavailable because CoreDevice's app-container file service timed out; the in-app saved layout had already survived the preceding in-place capture build.

## Fixes verified in the 2026-08-10 Simulator audit

- The settings sheet exposes Auto, 1x, 2x, 3x, and 4x. Both device-class logs confirmed the intended RT64 mode/multiplier and framebuffer invalidation for every live change; iPad 4x also survived terminate/relaunch.
- `Share Diagnostics…` produced a system share sheet on iPhone and iPad with app/build/system/screen/settings metadata, only a ROM-present boolean, a privacy review notice, and the bounded current-session stderr tail.
- The private current-session log was protected, excluded from backup, capped at 4 MiB, and read from the end rather than loaded wholesale for sharing. The 2026-08-11 pass supersedes its old replace-at-launch behavior with current/previous rotation.
- Menu, settings, and share presentation suppress gameplay input and every touch target; dismissal restores the saved Touch Controls state.
- The phone menu is top-centered, global touch opacity includes the menu, and the layout editor preserves the finger grab offset instead of snapping a control center on selection.
- The clean setup script now repairs an existing but incomplete pmret virtual environment by rerunning its pinned requirements install.
- The reported File 1A crash was traced to runaway autoreleased Metal serializer wrappers across long-lived graphics/present/idle/texture threads. The retained pools drain only completed or fenced work. A broad workload pool that caused a SimMetalHost resource-map crash was rejected and removed.
- The retained 4x iPad build held exactly 255 VM allocation regions across a 45-second idle comparison and remained at 255 after the Mario's House transition; physical footprint was about 124–127 MiB instead of multi-gigabyte growth.
- The PCM overlap pointer advanced by the full discarded channel × frame count in this historical build. The 2026-08-11 pass supersedes that workaround with a stateful stream after PCM evidence showed residual per-block contamination.
- iOS Metal-layer display-sync access now runs on the main thread; the final log no longer reports off-main `CAMetalLayer` mutation.
- The physical iPad exposed RT64's default attempt to create `.rt64` at the now read-only app-container root. PaperPad now gives RT64 an explicit private path under Application Support; the clean device build then completed renderer and recompiled-game initialization.
- The initial one-iPad-then-one-iPhone audit created no PaperPad crash report. One later rejected experimental build did; the retained final build created no newer report. The known non-blocking Simulator/runtime diagnostics listed below remain visible.

## Fixes verified in the 2026-08-09 release audit

- iOS Metal initialization and Simulator shader-tool selection work.
- The iOS path avoids unsupported 18-sampler native fast paths and the optional 52-buffer ray-tracing debug pipeline.
- UIKit window dimensions are reported in physical pixels, fixing the quarter-size Retina viewport. iPad now shows a centered original 4:3 frame at full height in landscape and full width in portrait.
- Flash page reads wrap safely, preventing the empty-file-select crash.
- HLE NAUDIO replaces the broken recompiled Paper Mario audio microcode path and removes its RSP error flood.
- RT64 Metal worker ownership/teardown fixes eliminated the reproduced autorelease crash.
- The 2026-08-09 final macOS regression caught two teardown paths that the
  historical patch provenance did not actually apply to the current ReCut
  vendor layout. `metal-worker-lifetime.patch` now stops renderer workers in
  dependency order, drains Apple autorelease pools, and corrects unowned Metal
  object releases. `apple-clean-process-exit.patch` completes renderer, event,
  thread-cleaner, and save shutdown before ending the single-session Apple
  process without unmapping RDRAM beneath parked guest threads. Three
  launch/render/input/quit cycles then exited with no new crash report.
- A persistent accessible PaperPad Menu exposes native settings. Touch visibility and opacity now persist alongside volume, resolution, aspect, and edited layout.
- The visible analog stick has a fixed center and a broad left-side pickup region. The 2026-08-11 pass corrected that pickup region to use the same fixed origin and reduced overlong flick replay.

## Playtest boundary

The combined hands-on evidence covers launch, title, file creation, opening narrative, early map movement, dialogue, and entry into Peach's Castle. The 2026-08-10 final iPad route reached the Mario's House prologue after creating/loading a save; the final iPhone route reached file entry with touch Start/A. On 2026-08-11 a private, checksum-validated level-27 fixture loaded File 2 into Toad Town and accepted touch movement without changing its save hash. The final macOS artifact passed three clean-quit cycles on 2026-08-09. This is meaningful route acceptance, not a full-game or chapter-spanning playthrough.

Visual comparisons against original Paper Mario references found matching theater structure, original 4:3 composition, saturated palette, checkerboard/curtain staging, dialogue styling, and layered paper-character presentation. See `docs/release-audit/` and the README.

## Known open release gates

1. Replay the Goompa return route twice more on the diagnostic build. Each sequence must complete, Start must respond promptly, and dialogue, movement, and NPC interaction must restore. Mark and capture any failure live; do not add a timeout or scene-specific bypass.
2. On the physical iPhone, confirm the copied File 1/File 2 save appears, inspect the independent compact touch defaults, exercise grouped D/C layout movement, and run title/file/gameplay/audio plus background/foreground acceptance.
3. Target-test physical-controller D-pad, all C directions, Bluetooth and wired disconnect/reconnect, natural sleep/wake, overlay restoration, and menu availability. Separately decide whether to add the reference hold-to-latch Z gesture and per-control VoiceOver elements.
4. Run a complete-game or chapter-spanning regression and a 60+ minute soak on both device classes. Reopen audio immediately if flutter/static recurs.
5. Use the private File 2 to document named middle/late checkpoints, battles, transitions, music, saving, and lifecycle recovery without changing File 1 or redistributing the fixture.
6. Clean up the non-blocking iOS launch warnings: unbalanced UIKit appearance transition and duplicate Simulator accessibility class.
7. Investigate the RT64 `RenderPool in Metal is not implemented currently` diagnostic and document whether the feature is unused or needs an implementation.
8. Before any stable or maintainer-signed distribution, complete physical accessibility acceptance and the appropriate signing/notarization, TestFlight, or App Store review. Preview 2 is deliberately unsigned and includes the audited notices, privacy manifest, and license bundle.

Historical failures and detailed investigations remain in [TESTING.md](TESTING.md) and [KNOWN-ISSUES.md](KNOWN-ISSUES.md). They are not evidence that the current build still fails.
