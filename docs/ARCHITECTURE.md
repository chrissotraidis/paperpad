# PaperPad architecture

PaperPad is a native Apple Silicon port of Paper Mario (N64, US 1.0) built from statically recompiled game code. The build separates public integration source from private game input and generated output.

## Build and data boundary

```text
User-owned ROM (.z64 / .v64 / .n64)
                 |
                 v
   normalize + verify exact SHA-1
                 |
                 v
 ignored generated/rom/baserom.z64
                 |
                 +--> ignored pmret build --> Paper Mario ELF metadata
                 |
                 +--> N64Recomp/RSPRecomp host tools
                              |
                              v
                   ignored generated/aot source
                              |
                 +------------+------------+
                 v                         v
       ROM-free macOS app       ROM-free Simulator app
       (SDL + Metal/RT64)        (UIKit + SDL + Metal/RT64)
```

No ROM, rebuilt ROM, generated AOT source, save, or private app-container data belongs in Git or in a published package. `scripts/check-repo-safety.sh` enforces the source-tree boundary; a separate artifact audit is still required before binary distribution.

On Apple platforms, PaperPad gives RT64 an explicit data directory at `Application Support/PaperPad/RT64`. This avoids RT64's desktop default of creating `.rt64` at the home/container root, which is read-only on current physical iPadOS.

## Pinned game/runtime stack

- `ref/papermario` provides the US 1.0 decompilation build, exact ROM validation, and ELF metadata used for AOT generation.
- `ref/paper-mario-recut` provides the game-specific N64Recomp integration and vendors N64ModernRuntime, N64Recomp, and RT64.
- N64ModernRuntime supplies N64-shaped memory, scheduler, audio, input, save/flash, and overlay services.
- RT64 supplies the renderer and direct Metal RHI.
- `ref/mupen64plus-rsp-hle` supplies the HLE NAUDIO path used instead of the broken recompiled Paper Mario audio microcode.
- `ref/SDL2` supplies window/input/controller/audio integration; `ref/zstd` supplies the compression build input needed by the vendor tree.

Exact commits live in `dependencies.lock.json` and [DEPENDENCIES.md](DEPENDENCIES.md).

All game code used by the app is ahead-of-time compiled for arm64. The Apple targets exclude JIT, TCC, LiveRecomp, dynamic code download, and emulator-core packaging.

## Project integration

- `apple/app/ios_main.mm`: UIKit lifecycle, Metal-capable SDL window handoff, settings, accessible menu, touch overlay, safe areas, layout editing, and lifecycle callbacks.
- `apple/app/diagnostics.mm`: bounded private stderr tee, diagnostic report generation, path replacement, and system share sheet.
- `apple/app/rom_setup.mm`: first-run picker, byte-order normalization, SHA-1 validation, protected private storage, and ROM replacement/removal.
- `src/paperpad_main.cpp`: runtime startup, SDL event pump, keyboard/controller mappings, touch snapshot merge, graphics settings, and shutdown.
- `src/paper_rt64_context.cpp`: RT64 configuration, Metal rendering bridge, framebuffer/present cadence, and diagnostics.
- `patches/`: maintained changes to the exact fetched vendor source.
- `scripts/`: pinned fetch, toolchain/decomp generation, app builds, and source-safety checks.

## Input paths

All sources normalize into controller 0:

```text
UIKit multi-touch ----+
SDL keyboard ---------+--> PaperPad input snapshot --> N64 buttons/stick
SDL game controller --+
```

The iPhone/iPad overlay tracks independent fingers for simultaneous input. It exposes a fixed visible analog stick with a wider pickup region, a D-pad, A/B/Z, C-buttons, L/R, and Start. The stick clamps its drawn knob and N64 vector from one fixed origin, applies a quadratic inner precision response, and zeros the minor axis when one axis dominates by 1.45×; the outer rim still reaches full magnitude and near-equal axes remain diagonal. Settings persist touch visibility/opacity and edited normalized positions separately from the game save. Phone and tablet layouts use independent schema keys so a compact-layout correction does not reset iPad customization; `iphone.v6` spaces the wider shoulder targets and the C/Z/face cluster without intersection. The normalized layouts and modal input lifecycle adapt HarkinianPad's accepted interaction pattern to PaperPad's direct N64 input bridge. Selecting an editor control preserves its grab offset; menu/settings transitions clear held input and suppress the gameplay targets.

macOS and iOS use SDL's standard game-controller mappings. The input loop reports controller connect/disconnect to UIKit; gameplay touch controls are cleared and hidden while a controller is connected, the utility menu remains available, and the overlay restores on disconnect according to the saved Touch Controls setting. HarkinianPad's hold-to-latch Z gesture and per-control VoiceOver elements for the custom-drawn gameplay overlay are not implemented.

## Rendering and window sizing

RT64 renders through Metal. On iOS, the borderless SDL window and UIKit bridge report physical pixel dimensions using the screen scale so the swapchain and Retina drawable agree. Each of the three Metal swap-chain slots owns one retained drawable; acquiring a replacement retains it before releasing the slot's previous owner, while presentation uses a separate temporary retain through command-buffer completion. The default uses automatic integer scaling and original 4:3 aspect framing. Settings map `Auto` to RT64 window-integer scaling, `1x` to `Original`, `2x` to `Original2x`, and `3x`/`4x` to `Manual` with the selected multiplier. Auto can therefore exceed 4x when the screen fits a larger whole-number scale. Smooth is the fixed image path: RT64 anti-aliased pixel scaling, scaled-only 2D upscaling, and N64 three-point filtering. The physically rejected Crisp 2D experiment was removed. Original keeps the largest centered 4:3 frame. Fill Screen keeps both regular and extended GBI projection at Original, then center-covers only the completed VI presentation. This deliberately crops rather than performing game-unaware widescreen projection, because Paper Mario positions battle HUD elements with its own 4:3 screen-coordinate math. Settings and diagnostics display the scale and internal dimensions confirmed by the renderer rather than inferring them from the selected segment.

## Diagnostics boundary

On iPhone and iPad, stderr continues to the development console and is also captured privately under `Application Support/PaperPad/Logs/`. The current session is `paperpad-latest.log`; at the next launch it becomes `paperpad-previous.log`. Each file is capped at 4 MiB, uses mode `0600`, data protection, and backup exclusion. A private active-session marker lets the next launch label the previous log as a possible unclean exit; it does not claim that every unclean exit was an application crash.

`Share Diagnostics & Logs…` reads at most the last 512 KiB from each available current and previous log and adds app/build/system/screen/settings metadata, renderer-confirmed scale, and a ROM-present boolean. It never reads ROM/save contents or attaches PCM audio. Known app-support, home, and temporary path prefixes are replaced, but arbitrary runtime text can still contain private material. The report is not promised to be fully anonymized and must be reviewed before sharing.

## ROM setup and saves

The iOS first launch presents a native document picker. A selected 40 MiB ROM is copied only after `.z64`/`.v64`/`.n64` normalization and exact SHA-1 verification. The normalized private copy lives under the app's Application Support directory, uses data protection, and is excluded from backup. The ROM manager can replace or remove it.

Flash/save operations remain within the platform's private writable path. The maintained runtime handles empty flash-card page numbers safely so a new file-select state fails checksum validation normally rather than accessing memory out of bounds.

## Apple shutdown boundary

RT64 worker threads are stopped before render-device teardown, with explicit
Apple autorelease-pool scopes and balanced Metal-cpp ownership. On iOS, the
`CAMetalLayer` passed into RT64 remains owned by SDL/UIKit; the swap chain does
not release that unowned layer from its graphics-thread destructor. N64 guest
threads are scheduler fibers backed by host threads, and the pinned upstream
runtime does not own every parked guest thread at shutdown. After the renderer,
event threads, thread cleaner, and save writer are joined, PaperPad ends its
single-session Apple process without unmapping RDRAM underneath those remaining
threads. The OS reclaims process memory atomically; this avoids both teardown
crash classes while preserving save completion.
