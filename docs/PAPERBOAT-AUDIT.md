# PaperPad engine decision and PaperBoat source audit

Date: 2026-09-19. Decision: **use PaperBoat as the engine foundation for PaperPad's next major version; preserve the current PaperPad product and qualify the replacement before switching users.** First modernize the existing source maintenance without changing engine versions or gameplay. Engine replacement belongs in a separate change.

This is an architecture, implementation, dependency, release and migration audit, with a bounded iOS compile attempt. It is not a measured performance comparison or a full-game acceptance report. No installed application or user save was changed.

## Exact comparison

| Input | Audited identity |
|---|---|
| PaperPad main and fetched origin/main | `74b6e45830a06c7f274c5ac1ddd7c625bc13a557` |
| PaperPad public iOS/iPadOS release | `v0.1.0-preview.2`, version 0.1.0/build 2, published 2026-08-16 |
| Public unsigned IPA | SHA-256 `ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029`, 11,605,609 bytes |
| Current ReCut base | `SMCGames/Paper-Mario-ReCut@098be0a501eecd5bb894a47964061d05eeedc3a2` |
| Current decomp metadata source | `pmret/papermario@c61db66e3cce7e8fa5b53d3e9ecd01632e7b064a` |
| PaperBoat develop | `2f7d38e07bcb85c216bf37e8a0a1a5cf8731ceef` |
| PaperBoat 1.0.1 | `424c220f0863c29b9fe55cc674baceff88e9e14f`, published 2026-09-17 |
| PaperBoat libultraship | `JeodC/libultraship@7aa03b6c830b059e3ddd6ad20d3f289c5f406161` |
| PaperBoat Torch | `JeodC/Torch-LH@106f4e3056f07fe3a8758bb14a060f8423b6877f` |
| libultraship Prism dependency | `KiritoDv/prism-processor@aa8370981b2cf57c46172e6aa639d720137f9a92` |

PaperBoat develop differs from 1.0.1 in CMake CPU-option handling and CODEOWNERS only at this snapshot; the inspected engine/save issues apply to both. [Release 1.0.1](https://github.com/HarbourMasters/PaperBoat/releases/tag/1.0.1) ships Windows, Linux and macOS ZIPs, not an IPA. Its build workflow covers those desktop platforms. Mobile source support is real but is not equivalent to a qualified mobile release.

## Why the engine decision favors PaperBoat

PaperPad's current path compiles generated MIPS translations to arm64 and runs them against guest memory, overlay lookups and N64ModernRuntime services. It is already native AOT code, not a conventional CPU interpreter. Nevertheless, its generated functions preserve N64 register/memory semantics and its runtime still coordinates guest threads, RSP tasks and VI presentation. PaperBoat instead directly compiles the decompiled C/C++ game, with native pointers and explicit host engine integration. That is a stronger long-term basis for game fixes and enhancements.

PaperBoat's main loop runs `step_game_loop`, builds one combined display list, coordinates an audio worker and submits through libultraship/Fast3D. Its event bytecode uses `intptr_t`; PaperPad's hooks use fixed guest addresses and `recomp_context` registers. These are incompatible integration boundaries. Source availability in both projects does not make whole subsystems interchangeable.

The opportunity is substantial: fewer PaperPad-specific guest scheduler/audio/rendering workarounds, direct game-level fixes, actual widescreen camera/UI changes, interpolation instrumentation, source asset replacements and upstream enhancement work. Performance gains are plausible, especially from the native audio path and avoiding guest translation conventions, but their magnitude and mobile energy impact remain unmeasured. Both use Metal on Apple hardware; merely changing engines is not evidence of lower GPU cost.

Evidence: [PaperBoat game loop](https://github.com/HarbourMasters/PaperBoat/blob/2f7d38e07bcb85c216bf37e8a0a1a5cf8731ceef/src/port/Game.cpp), [frame orchestration](https://github.com/HarbourMasters/PaperBoat/blob/2f7d38e07bcb85c216bf37e8a0a1a5cf8731ceef/src/port/gfx_frame.c), [engine](https://github.com/HarbourMasters/PaperBoat/blob/2f7d38e07bcb85c216bf37e8a0a1a5cf8731ceef/src/port/Engine.cpp), and PaperPad `src/paperpad_main.cpp`, `src/paperpad_game_hooks.cpp`, `CMakeLists.txt`.

## Capability and cost comparison

| Area | Existing PaperPad | PaperBoat | Consequence |
|---|---|---|---|
| Game execution | N64Recomp AOT + N64ModernRuntime | Native decompiled C/C++ | Prefer the new foundation for future development; avoid a mixed game ABI |
| Graphics | RT64 Metal, original projection, optional final-image crop | libultraship/Fast3D Metal, game-aware viewport and effect patches | Widescreen is a substantive feature gain; renderer fidelity needs regression coverage |
| Frame rate | Original RT64 cadence; 60 VI target does not mean 60 unique game frames | 30 Hz game logic plus configurable matrix interpolation | Smooth presentation without claiming faster game simulation; 60/120 presentation costs extra work |
| Audio | Generated game-specific RSP path, queue feedback and synchronous task patches | Native mixer with ARM NEON paths, 32 kHz host audio, sample-debt pacing and bounded refill | Promising simplification; listening, queue and interruption tests still required |
| Assets | Privately imported ROM, runtime ROM reads | Torch extraction to private `pm64.o2r`; separate port-owned `paperboat.o2r` | Keep Nintendo-derived archive private; ROM import must drive extraction and handle partial failures |
| Saves | 128 KiB FlashRAM, four logical slots in six rotating sectors | Per-slot JSON and DX-era native structures | Conversion required; renaming files cannot work |
| Apple interface | Native UIKit setup, settings, share sheet, safe-area layouts | ImGui settings/touch overlay; Files-based ROM staging on mobile | Preserve PaperPad's interface and implement narrow engine adapters |
| Controls | Direct SDL2 mapping/reconciliation and independently persisted phone/tablet layouts | libultraship control deck plus configurable SDL/ImGui touch controls | Choose one hardware-controller owner; prevent duplicate polling and touch overlays |
| Minimum iOS | 15.0 | 16.3 in supplied toolchain | Explicit compatibility change for the later engine migration |
| Source maintenance | 25 production patches over a flattened ReCut vendor tree; five historical patches | Native source plus pinned fork dependencies | PaperBoat is easier to develop at game level, but its dependency forks still need careful pinning |
| Release maturity | Two mobile previews, documented limited physical acceptance | Very recent desktop releases and active bug-fix PRs | Neither establishes full-game iOS acceptance |

PaperPad's open [issue #5](https://github.com/chrissotraidis/paperpad/issues/5) reports framing on iPhone 12 Pro Max/iOS 16.6.1. PaperBoat's widescreen work is relevant, but cannot be claimed to fix that report without testing the same composition and device class. PaperPad's current crop behavior is intentional and does not provide game-aware widescreen.

## Specific upstream findings to carry into qualification

### Apple configuration persistence: source-confirmed, high priority

`GameEngine` passes an already resolved configuration path to `CreateUninitializedInstance`; `Context::InitConfiguration` calls `GetPathRelativeToAppDirectory` again. The helper concatenates strings rather than treating an absolute path specially. The iOS app directory is an absolute `HOME/Documents` path, so the same double-prefix issue reported on macOS applies by source inspection to iOS. This can prevent settings, controls and graphics choices from persisting. This iOS consequence is an inference from the exact call chain, not a device reproduction.

Open [PR #154](https://github.com/HarbourMasters/PaperBoat/pull/154) addresses the constructor argument and the macOS controller-database installation location. [Issue #160](https://github.com/HarbourMasters/PaperBoat/issues/160) reports settings loss in 1.0.1. Qualify or carry a reviewed fix before a PaperPad candidate uses existing preferences.

### Save serialization and durability: source-confirmed, high priority

In `src/port/save/SaveManager.cpp:163-168`, JSON `partnerUsedTime` is assigned into `player.partnerUnlockedTime`; the earlier unlock-time array is overwritten and usage time remains default. The serializer writes two separate arrays at lines 367-377. This is a definite asymmetric field mapping and requires a round-trip regression with distinct nonzero values.

At lines 490-494, the writer opens the destination JSON directly with `std::ofstream`, writes and closes it. There is no temporary-file/atomic-replacement transaction in this path. At lines 506-510, JSON parsing and field conversion have no local recovery for a truncated/malformed file. Unexpected termination or invalid input can therefore become a save-recovery problem. Introduce validated atomic writes and a last-good backup before migration; do not make existing FlashRAM data the test subject.

PaperBoat's [issue #161](https://github.com/HarbourMasters/PaperBoat/issues/161) also reports inability to import raw `.fla`/`.sav`/`.srm` saves. The inspected native loader expects JSON; an external converter is not a verified migration path.

### Battle lifetime and rendering remain active upstream work

Open [PR #157](https://github.com/HarbourMasters/PaperBoat/pull/157) clears damage-popup references after effect destruction to address reported demo/Bowser crashes. Its fix is absent from the audited develop snapshot. [PR #158](https://github.com/HarbourMasters/PaperBoat/pull/158) changes dialogue texture filtering to point sampling; this is a visual preference/fidelity change, not a proven general performance improvement. PaperPad previously rejected a broad crisp-2D experiment, so do not blindly transplant that setting.

Other open reports include landing-zone movement behavior (#150/#152), post-office menu behavior (#156), widescreen off-screen actors (#90), and playthrough rendering notes (#73). These are qualification targets, not proof that the entire port is unusable. Their existence prevents an unconditional claim that upstream is universally more correct.

### iOS support is substantial, but not yet a ready replacement

The source includes an iOS toolchain, unsigned signing option, Metal backend branches, packaged resources, touch controls and scripting/dynamic-loader exclusions. `ENABLE_SCRIPTING=OFF` and `DISABLE_DLL_LOADER=ON` are forced on mobile: CPU JIT is not required. Runtime Metal shader compilation is distinct from CPU JIT.

The mobile extractor currently loads `baserom.us.z64` from the app directory and provides no native document picker. Its plist exposes Documents through Files. PaperPad should retain exact revision validation, byte-order normalization, protected private storage and a native picker; then feed that validated input into Torch. Keep both source ROM and generated game archives out of release packages.

PaperBoat touch controls support simultaneous fingers, editable normalized positions, opacity and clearing while its menu is open. They use a shared layout key rather than PaperPad's independent phone/tablet schemas. Their enabled state is a CVar; the examined implementation does not reproduce PaperPad's hardware-controller overlay handoff. Preserve and adapt PaperPad's accepted behavior instead of replacing it solely because upstream has a touch overlay.

### Reproducibility needs work in either direction

PaperBoat pins its main dependency gitlinks and Prism, but downloads `sse2neon.h` and the controller database from moving `master` URLs. Several dependency declarations use tags and host package discovery. An app release needs immutable fetched-file hashes, exact selected packages and a complete source graph. Switching to PaperBoat does not itself satisfy the modernization checklist.

The dependency is the JeodC libultraship fork, not an arbitrary current Harbour Masters or Kenix3 branch. Substituting another existing libultraship fork without comparing the effective source risks losing PM64 sprite/rendering and platform changes. Preserve the selected source first; reconcile ancestry and shared forks in a separate review.

## Keep, replace and selectively borrow

**Keep and adapt:** PaperPad repository/name/issues/releases, bundle identity for qualified in-place updates, native ROM manager, native settings/diagnostics, privacy boundary, accepted touch geometry, phone/tablet persistence and useful controller regression scenarios. Keep Preview 2 and its complete recovery inputs.

**Replace together in the successor:** generated MIPS game code, N64ModernRuntime guest services, RT64 integration, overlay registration, RSP dispatch and fixed-address game hooks. PaperBoat's native game, resource loaders, frame orchestration, audio and renderer form one coherent replacement. Carrying both full engines indefinitely would double the maintenance surface.

**Adapter seams:** connect `PaperPad_SetTouchButtons/Stick` to `OSContPad` at `GameEngine_ReadController`; use libultraship as the sole hardware-controller owner after its behavior is verified; bridge volume/settings to upstream CVars; obtain renderer-confirmed resolution from the new backend rather than reusing RT64 assumptions. Retain UIKit lifecycle ownership intentionally; do not run two independent SDL/application mains or both overlays.

**Selective work on the old engine:** use upstream bug reports/source as diagnostic references, adopt platform-independent tests, and consider narrowly proven game fixes only when reproduced in PaperPad. Widescreen, interpolation, native mixer and native asset loaders are broad engine integrations, not small cherry-picks. PaperBoat's `intptr_t` script fields and native pointers cannot replace 32-bit guest-memory structures directly.

## Options and selected path

| Option | Judgment |
|---|---|
| Replace PaperPad immediately with upstream desktop packages | Reject: wrong mobile delivery and data/interface contract |
| Keep ReCut forever and port large PaperBoat subsystems piecemeal | Reject as the strategic direction: repeated ABI/resource/renderer adaptation |
| Make PaperPad a maintained Apple product over PaperBoat native source | **Selected long-term direction**, subject to explicit acceptance gates |
| Preserve and modernize Preview 2's current source as the fallback | **Required first step** under the current maintenance scope |

The selected direction is firm; release acceptance is evidence-dependent. If a prototype fails the gates, keep Preview 2 available and resolve the failure before transitioning users. Do not create a permanent dual-engine product merely to avoid a decision.

## Qualification gates for the later engine change

1. Build pinned native macOS, iOS arm64 device and Simulator profiles without CPU JIT; fix the iOS toolchain failure and inspect bundle identity, minimum OS, resources and notices. Use a separate test identity initially; only a qualified migration gets the production identity.
2. Fix Apple path resolution and JSON round-trip/durability defects. Implement one-time, copy-only conversion of all four logical FlashRAM slots, choosing the newest checksum-valid sector. Preserve original 128 KiB image and backups unchanged. Validate story flags, inventory, partners, map/entry, name, play time and reload after save. Do not reinterpret the old binary image as a host `SaveData` struct.
3. Port the existing Apple interface through a small adapter. Exercise Files/cloud import cancellation, all byte orders, corrupt input, extraction failure, replacement/removal, native settings, modal input release, safe areas and rotation.
4. Compare original 4:3 output first, then widescreen/interpolation. Include intro, file select, Goompa return twice, action commands, battle target hand, damage-popups at battle teardown, map transitions, pause/maps, framebuffer effects, later chapters and a representative long session. Distinguish build/startup from owner gameplay acceptance.
5. Measure old/new release builds on the same physical device and route, matched internal pixel count, aspect, MSAA/filtering and 30 Hz presentation first. Record frame-time percentiles, CPU/GPU time, resident/peak memory, audio underruns and thermal state after warmup; use Instruments energy measurements for battery claims. Evaluate 60 Hz interpolation separately and count unique game versus presented frames. Desktop timings cannot establish iPhone performance.
6. Preserve controller-slot ownership, all mappings, disconnect input release, reconnect, background/foreground, audio interruption and touch-overlay handoff. Review the new engine's lifecycle instead of transplanting the old guest-process exit workaround.
7. Deliver pinned source, attribution, per-component notices and reproducible packages; retain the prior signed identity/data recovery route. No new public release is authorized by the current modernization request.

## Checks actually performed in this audit

- Refreshed PaperPad origin; main is unchanged and has no application-level uncommitted changes. Inspected dirty prepared dependency source separately.
- Inspected PaperBoat release/develop source, exact dependency gitlinks, libultraship paths/Metal/build configuration, Torch integration, game/native audio/interpolation/save/touch code, desktop CI and current GitHub issues/PR diffs.
- `scripts/verify-sources.sh` passed on the existing PaperPad tree, but its current implementation checks revisions and does not reject prepared-source drift; modernization must strengthen it.
- Compiled and ran PaperPad's existing controller-slot tests: all scenarios passed.
- Unmodified PaperBoat iOS configure passed with CMake 4.4.2, Ninja 1.13.2, Xcode iPhoneOS 27.0 SDK, arm64 and iOS 16.3 deployment. Build failed at SDL `SDL_rwopsbundlesupport.m`: `invalid argument '-std=gnu++2a' not allowed with 'Objective-C'`. The command line combines Objective-C++ standard flags with an Objective-C source override. This proves a failure of the tested Ninja/toolchain path, not that every iOS generator is broken. No finished PaperBoat app, install, game launch or FPS comparison is claimed.

## Attribution and rights boundaries

PaperBoat's root is CC0, libultraship and Torch carry MIT notices, and nested dependencies retain separate terms. PaperPad's current ReCut integration is MIT, N64ModernRuntime carries GPLv3, RT64 is MIT, and SDL/zstd and build tooling retain their own terms. None of these grants automatically covers Nintendo game material. Preserve the decomp/DX, Harbour Masters and individual dependency credits and audit copied font/artwork/mixer notices before distributing a successor.

The current repository deliberately excludes generated playable game source, while the linked GPL runtime raises exact corresponding-source delivery questions. A reconstruction recipe or ROM-free package does not by itself settle that boundary. Current maintenance can preserve permitted source and improve reproducibility, but must leave unresolved game-source rights/delivery questions explicit rather than assigning a blanket license. This audit is an engineering recommendation, not legal clearance.
