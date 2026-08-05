# PaperPad Research

Research snapshot: 2026-08-05. Exact commits are recorded in
`REPOSITORY-INVENTORY.md`; conclusions may change only through a recorded
decision and new runtime evidence.

## Executive conclusion

Use `SMCGames/Paper-Mario-ReCut` as the game-specific foundation: it is the
current static-recompilation port of Paper Mario (US 1.0) built with
N64Recomp + RT64, with gameplay fixes, saves, and a known desktop release.
Use `pmret/papermario` as the decompilation input for asset/ROM validation
(per the working goal). For the Apple architecture, adapt the proven
AnnePad/BearBirdPad pipeline: pinned fetch-only sources, host generation
tools, generated AOT source outside git, source patches with forward/reverse
checks, Metal through RT64, a native UIKit shell, normalized controller/touch
input, private user files, lifecycle handling, and audited packaging.

## Game-core candidates

### SMCGames/Paper-Mario-ReCut — selected provisionally

Strengths:
- Current static-recomp desktop port for Paper Mario (US), the exact game and
  revision in `ref/Paper Mario (U) [!].v64`.
- Built with the N64Recomp toolchain (AOT native code) and RT64 rendering,
  the same family AnnePad proved on Apple targets.
- Does not distribute ROMs or Nintendo assets; requires the user's own ROM.

Risks:
- Windows-oriented build surface; macOS/iOS cross-compile needs verification.
- Runtime/RT64 commits and dependency manifest must be pinned for
  reproducibility.

### pmret/papermario (decomp) — build input

- Full Paper Mario decomp; builds matching ROMs (US/JP/PAL/iQue) via
  `./configure` + `ninja` from a `baserom.z64`.
- Expected US SHA-1: `3837f44cda784b466c9a2d99df70d77c322b97a0`.
- Provides the canonical ROM expectations and asset-split inputs.

## Open questions

- Exact dependency pins for ReCut (N64Recomp, RT64, N64ModernRuntime).
- Whether the ReCut runtime tree can be cross-compiled for iOS arm64 with
  interpreter-only fallback (no JIT/TCC), as AnnePad proved for Stadium.
