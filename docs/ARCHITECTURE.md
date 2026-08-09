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

The iPhone/iPad overlay tracks independent fingers for simultaneous input. It exposes a fixed visible analog stick with a wider floating pickup region, a D-pad, A/B/Z, C-buttons, L/R, and Start. Settings persist touch visibility/opacity and edited normalized positions separately from the game save.

macOS uses SDL keyboard and standard game-controller mappings. Controller hot-plug is supported by the input loop; controller-driven touch auto-hide is not implemented.

## Rendering and window sizing

RT64 renders through Metal. On iOS, the UIKit window bridge reports physical pixel dimensions using the screen scale so the swapchain and Retina drawable agree. The default uses automatic integer scaling and original 4:3 aspect framing. Users can select fixed 2x resolution or expanded aspect in the native settings sheet.

## ROM setup and saves

The iOS first launch presents a native document picker. A selected 40 MiB ROM is copied only after `.z64`/`.v64`/`.n64` normalization and exact SHA-1 verification. The normalized private copy lives under the app's Application Support directory, uses data protection, and is excluded from backup. The ROM manager can replace or remove it.

Flash/save operations remain within the platform's private writable path. The maintained runtime handles empty flash-card page numbers safely so a new file-select state fails checksum validation normally rather than accessing memory out of bounds.

## Apple shutdown boundary

RT64 worker threads are stopped before render-device teardown, with explicit
Apple autorelease-pool scopes and balanced Metal-cpp ownership. N64 guest
threads are scheduler fibers backed by host threads, and the pinned upstream
runtime does not own every parked guest thread at shutdown. After the renderer,
event threads, thread cleaner, and save writer are joined, PaperPad ends its
single-session Apple process without unmapping RDRAM underneath those remaining
threads. The OS reclaims process memory atomically; this avoids both teardown
crash classes while preserving save completion.
