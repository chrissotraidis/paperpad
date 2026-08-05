# PaperPad Architecture

Target architecture for PaperPad, a native macOS / iPhone / iPad port of
Paper Mario (N64, US 1.0) built by static recompilation.

## System boundary

```text
User ROM (ref/Paper Mario (U) [!].v64)
        |
        v  normalize to z64 + verify sha1 3837f44c...
ref/papermario (pmret decomp) -> build/us/papermario.elf + matching z64
        |
        v  N64Recomp (host tool) reads ROM + ELF metadata
generated/paper_mario_recomp_out/  (ignored AOT C/C++ source)
        |
        v  RSPRecomp -> generated RSP microcode (n_aspMain.cpp)
+-------------------+-------------------+
v                   v                   v
macOS app        iOS Simulator       iOS device
(arm64 native,   (UIKit shell,       (same, unsigned or
 Metal/RT64)      Metal/RT64)         signed builds)
```

No ROM, extracted asset, generated AOT source, or save travels through git or
release packaging. `ref/` is gitignored and local-only.

## Game core

- `ref/papermario` (pmret decomp) provides the canonical US ROM verification
  and the ELF metadata used for AOT generation.
- `ref/paper-mario-recut` (SMCGames) is the game-specific foundation: the
  Paper Mario N64Recomp workflow, `generated/paper_mario_recomp_out/`
  interfaces (`recomp_entrypoint`, `get_function`, overlays), RSP microcode
  setup (`n_aspMain`), and RT64 rendering glue.
- N64ModernRuntime (vendored inside ReCut) supplies the runtime: memory,
  scheduler, audio, input, saves, and overlay bookkeeping.
- RT64 (vendored inside ReCut) provides the renderer with a direct Metal RHI.

All game code executes as ahead-of-time compiled arm64 native code. No JIT,
TCC, LiveRecomp, dynamic code download, or emulator core is part of Apple
targets (N64MODERN_NO_DYNAMIC_CODE-style compile-time exclusions).

## Apple integration

The proven AnnePad/BearBirdPad pipeline is adapted:

- `apple/app/` — Objective-C++ UIKit shell: UIApplication lifecycle, ROM
  setup view (Files picker + hash validation), CAMetalLayer view, safe-area
  handling, touch overlay, lifecycle pause/resume, fatal-error presentation.
- `apple/core/` — static library core: generated AOT + N64ModernRuntime +
  RT64, cross-compiled for iOS Simulator/device.
- `scripts/` — reproducible pinned build: check-prerequisites, fetch/verify
  sources, prepare ROM, build host tools (N64Recomp/RSPRecomp), generate AOT,
  build macOS / iOS core / iOS app, run, test, package, audit.

## Input and touch

All input sources normalize to N64 controller state:

```text
UIKit multitouch ----+
GameController ------+-> normalized stick/buttons -> runtime input snapshot
keyboard (macOS) ----+
```

The touch overlay tracks fingers independently with stick recentering,
C-button intent, simultaneous inputs, cancellation, and safe-area layout.
Paper Mario-specific layout: left thumb on the analog stick, D-pad left of
the stick for menus, right cluster with A (confirm/action), B (jump), C
buttons (menu/partner), Z, Start, and L/R triggers. iPhone and iPad profiles
store normalized positions/sizes and default per device idiom.

## ROM and setup flow

First launch shows a native setup screen with the supported revision and a
Files picker. The ROM is copied into Application Support, normalized to z64,
hashed against `3837f44cda784b466c9a2d99df70d77c322b97a0`, and committed only
on success. The installed ROM is a private user-owned input, never exported
by the app.
