# PaperPad handoff

Current as of 2026-08-14. The maintained source-build paths are `scripts/build-macos-app.sh` and `scripts/build-ios-simulator.sh`; older `build-macos2`, `build-ios-deps`, and manual `ref/mstan-*` instructions are obsolete.

The complete hands-on issue queue and acceptance criteria are tracked in
[TECH-DEBT.md](TECH-DEBT.md). This handoff records what the 2026-08-11 working
tree changed, what was reproduced, and which release gates remain open.

## 2026-08-14 Preview 1 package

- The first public package is the ROM-free, unsigned, self-signable
  `PaperPad-v0.1.0-preview.1-unsigned.ipa` for arm64 iOS/iPadOS 15 or newer.
- `scripts/package-unsigned-ipa.sh` builds a deterministic archive and
  `scripts/audit-ios-package.sh` rejects ROM/save/log/signing/private-path
  contamination, unexpected runtime dependencies, or missing notices.
- Two independent package runs matched SHA-256
  `80721e9a726e3131b86f7186ee150fdbec8a6e53ce327a11baa2a5d85fc7e8ee`.
- Preview publication does not close the stable-release gameplay, controller,
  accessibility, physical-iPhone, or chapter-spanning acceptance gates below.
- Before final packaging, the complete saved `iphone.v8` preference dictionary
  was exported from the attached iPhone 14 through a temporary startup console
  line. Its 15 positions, A/B sizes, opacity/visibility, and unlinked group
  state now define the fresh-install phone defaults; the temporary exporter was
  removed and the iPad defaults were not changed.
- The clean final signed device executable is
  `ea1453bc17d209ffd4b38a99a2f7299438f444e6d334122de1b96aaada3b6541`;
  it installed in place and launched on the attached iPhone 14.

## 2026-08-13–14 device handoff

- A 16m41s physical-iPad Kishi V2 run reached 30,000 frames without a crash,
  fatal/assert, or game-loop-stall line. Analog and A/B/Z/L/R/Start were
  observed; D-pad/C directions and reconnect remain targeted checks.
- After physical-iPhone rejection of the first grouped layout, D-pad and C
  directions move individually by default. Link/Unlink optionally binds only
  the selected cluster for movement. `iphone.v8` corrects the phone geometry;
  accepted `ipad.v4` tablet defaults remain independent.
- A clean ROM/save-free app is installed and running on the physical iPhone 14.
  The private iPad test ROM/save were copied before the clean in-place install.
  Runtime initialization passed; direct File Select/save and compact-touch
  acceptance are the next user checks.

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

## 2026-08-11 defect work

- Audio now uses one persistent `SDL_AudioStream`; the destructive queue
  catch-up/downsampling path and per-block converter were removed. Simulator
  PCM analysis shows the added high-frequency energy eliminated and no queue
  or conversion errors. The installed physical build subsequently logged 190
  structural windows with the expected 32→48 kHz frame ratio, a 60.75 ms
  maximum queue, zero queue/conversion/over-100 ms events, and no boundary
  peak above its within-block peak. Subsequent physical-iPad listening still
  heard smaller crackle. The host-resampler defect is fixed; the remaining
  release blocker is in the HLE N64 synthesis seam, not proven to
  be a queue size, cache size, or full-scale clipping problem.
- The three-dot menu exposes `Share Diagnostics & Logs…`. Private current and
  previous logs are capped at 4 MiB each; a session marker identifies a
  possible unclean prior exit, and the share report reads at most 512 KiB from
  each log. It never includes ROM/save contents or raw PCM.
- Settings shows the renderer-confirmed effective scale and internal
  dimensions. Auto reported 9.00x/2880×2160 on the current 13-inch iPad
  Simulator and now explicitly explains why it may exceed the manual 4x cap.
- The analog-stick knob and N64 vector now use the same fixed origin and clamp.
  Released flick retention was reduced to one runtime poll to address
  name-entry overshoot. After fresh physical feedback, touch output gained a
  quadratic inner precision curve and cardinal-axis bias while preserving full
  rim speed and deliberate diagonals. The rebuilt Simulator app passes compile
  and launch; fresh name-entry/gameplay acceptance remains open.
- A disposable blank-save iPad Simulator route then verified touch-only name
  entry: `A → B` and `B → o` each took one deliberate gesture, and three far
  diagonal drags produced one adjacent step each. The saved level-27 fixture
  was restored with its original hash. Computer automation releases drags
  between rendered frames, so the physical held-knob visual check remains open.
- The sequential iPhone 17 Pro Simulator route repeated `A → B → o` with one
  horizontal and one vertical touch gesture, preserved its ROM/preferences
  hashes, created no save, and logged no audio queue/conversion or fatal error.
- A later visible iPhone capture exposed a real default-layout collision: R/L
  touched and C-up intruded into L. The `iphone.v6` defaults separate the full
  right-hand stack; the rebuilt ROM-free app preserved private data and passed
  a gameplay-frame visual check. This intentionally stops loading obsolete v5
  phone customization while leaving the iPad layout and other settings intact.
- The iOS SDL window is borderless. The iPad drawable fills the screen while
  Original preserves the largest centered 4:3 image. The user's physical test
  showed that the old projection-only Expand was effectively a no-op on the
  near-4:3 iPad and later detached a battle pointer from its selected actor.
  Fill Screen now keeps RT64 projection at Original and center-crops only the
  completed VI frame, keeping actors and 2D HUD under one final transform.
- Settings action links were replaced with consistent 50-point native UIKit
  rows with SF Symbols, visible backgrounds, rounded corners, accessibility
  button traits, and full-width targets. Done is a filled primary button.
- The user's physical test rejected Crisp 2D as visibly worse. Its UI,
  persistence field, and renderer behavior are removed; Smooth is fixed.
  Original low-resolution texture/text detail remains a known limitation.
- The README visual section now shows two representative captures, including
  a current Auto/status settings image.
- A private CC BY-NC-ND 4.0 GameBanana `.fla` was archive-hash checked,
  converted from Project64 word order, and validated across all save/global
  sectors. In disposable iPad Simulator `8EAB77D1-A8CB-4ADC-A806-7281DB381FF1`,
  Files 1 and 2 appeared at level 27 and File 2 loaded into Toad Town; touch
  movement worked, the save hash remained
  `e9881da4ae8873aed319697e8a63ec0ee9bcec46663642a9a18381bfa227a175`,
  and runtime telemetry remained error-free. The converted private file and a
  provenance note now live under ignored `ref/demo-saves/` for local demo use.
  Keep it private; do not commit/package it or replace a live save wholesale.
- The private fixture was subsequently merged into physical File 2 without
  replacing the save wholesale. Active File 1 remained in its original sector
  and its complete sector SHA-256 stayed
  `c5d67e80cc104b13622c63e9271d0451b5f0af6892f375a05714486ba1797ad5`.
  Exact device read-back and post-update read-back matched merged save SHA-256
  `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398`.
  Visible File 2 load and later-game acceptance remain open.
- iOS now advertises controller user interaction. SDL mappings cover left
  stick/D-pad, A/B/Start, L/R/Z, and right-stick C buttons; connection clears
  and hides gameplay touch controls while leaving the utility menu available,
  and disconnect restores the overlay according to the saved setting.
  Physical pairing/mapping/reconnect acceptance remains open.
- A sustained Toad Town run found a second, smaller Metal leak that the earlier
  255-region check could not see: RT64 retained every acquired
  `CAMetalDrawable` when reusing a swap-chain slot. At failure, heap showed
  42,354 drawables and 757,314 FramePacing command buffers. The new maintained
  `metal-drawable-slot-lifetime.patch` releases the previous slot owner; full
  patch replay and rebuild passed, and post-fix counts stayed exactly 3
  drawables, 3 lifetimes, and 72 command buffers across thousands of frames.
  Physical footprint ended at 130.1 MiB below a 145.3 MiB peak. The rebuilt
  Simulator executable is
  `c7169064de1fee098c6703cccec8b1e38f148e1ea9cb6071b5284a8045fb5500`.
- The user-supplied 12:22 iPhone report and a fresh 12:32 iPad reproduction
  showed shutdown aborting when RT64 released SDL/UIKit's unowned
  `CAMetalLayer` on the Gfx Thread. `ios-metal-view-lifetime.patch` preserves
  macOS release behavior but leaves the iOS layer to UIKit. Fixed iPhone and
  iPad active-rendering shutdowns created no newer report.

The current 2026-08-11 iPhone follow-up passed preserved-data installation,
corrected non-overlapping compact controls, landscape framing, live Auto 6x/1920×1440 status, a 22 KiB diagnostics
share/dismissal, modal restoration, and error-free bounded audio telemetry. The
earlier 2026-08-10 routes still provide first-run, file-flow, all-resolution,
and File 1A/Mario's House evidence. No Simulator result proves physical audio.

The 2026-08-11 physical-iPad iteration executable was
`4705532b2b5ebca7752ed0fd78bcc6ae1ac7f19d29a3b7f7c831a857e34d6b33`.
It passed strict signing and ROM/save bundle scans, installed in place on the
attached iPad14,5 without container reset, launched, and remained live as PID
761. It preserved the exact merged File 1/File 2 save and the complete vendor
patch stack replayed cleanly from a fresh local clone. It is intentionally left
running for direct evaluation. This proves
deployment, not that the remaining synthesis crackle or new touch/visual
behavior has passed human acceptance.

## Remaining release gates

1. Reproduce the Goomba Village gate-unlock freeze from a preserved pre-scene
   save. Capture current/previous diagnostics and the guest wait state without
   overwriting File 1. Close only after three runs complete the sequence and
   restore Start, movement, and NPC interaction.
2. On the installed current iteration, repeat human listening at title, file
   selection, File 1A, Mario's House, sustained
   music, and representative effects. The remaining synthesis crackle must be
   fixed or explicitly held as a release blocker.
3. Repeat extreme stick drag, cardinal name entry, normal movement, Auto
   status, fixed Smooth filtering, native settings actions, diagnostics, Original/Fill Screen,
   File 2 load, battle-pointer alignment, background/foreground, and a longer
   session.
4. Extend the fixed heap-count regression into a full 60-minute and
   chapter-spanning Simulator route, then validate a current signed physical
   iPhone.
5. Extend the installed private File 2 into named middle/late
   checkpoints, battles/transitions, saving, lifecycle recovery, and a
   chapter-spanning or 60-minute regression route.
6. Physically verify controller pairing, mappings, hot-plug/reconnect, overlay
   handoff, and menu availability; resolve or disposition the remaining
   reference/accessibility gaps, warnings, notices, rights, privacy, and packaging gates in
   [STATUS.md](STATUS.md).

Always test one simulation or game process at a time. Terminate PaperPad and shut down Simulator before launching a comparison app or macOS runner.

Earlier on 2026-08-11, CoreDevice acquired the paired-iPad wired tunnel but
timed out or interrupted every app-container request. The Mac-side
`CoreDeviceService` worker was stalled; after terminating that worker and
running `devicectl` outside the Codex sandbox, the same no-recurse `Documents`
request completed in 0.6 seconds. No backup or container replacement was
performed. The clean ROM-free signed arm64 bundle (executable SHA-256
`9e7954471ec43465d01031ba2799a6f2110d6e56bb9f2d04acc511518c5a753e`, team
`VKDH2T9UTF`, wildcard profile `8b78a5eb-d835-41a7-9578-fbc74823f7e6`) then
passed strict verification, installed in place, launched, and remained listed
as PID 631. This is host-observable deployment evidence, not hands-on gameplay,
audio, touch, visual, or lifecycle acceptance.
