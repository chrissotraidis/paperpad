# Repository inventory and pinned sources

Updated 2026-08-05. Exact pins are authoritative for reproducible builds.
Upstream inputs are local build inputs only; push URLs are disabled on all
upstream checkouts.

## Local reference and build inputs (`ref/`, gitignored)

| Path | Source | Pin | Purpose |
|---|---|---|---|
| `ref/Paper Mario (U) [!].v64` | user-supplied | sha1 (v64) `77693a00…`; z64 `3837f44cda784b466c9a2d99df70d77c322b97a0` | Required Paper Mario US ROM; never committed/distributed |
| `ref/spaghettipad` | github.com/chrissotraidis/spaghettipad | `4f6bb0c` (plus worktree state) | Primary Apple-port reference (build scripts, iOS shell, touch patterns, docs) |
| `ref/papermario` | github.com/pmret/papermario | `c61db66e3cce7e8fa5b53d3e9ecd01632e7b064a` | Paper Mario decomp; ELF + ROM verification for AOT generation |
| `ref/paper-mario-recut` | github.com/SMCGames/Paper-Mario-ReCut | `098be0a501eecd5bb894a47964061d05eeedc3a2` | Game-specific N64Recomp foundation (runtime + RT64 vendored, RSP config, generated-output interface) |
| `ref/mstan-n64modernruntime` | mstan N64ModernRuntime fork (AnnePad) | local checkout | Runtime used by PaperPad (N64Recomp/RSPRecomp/librecomp/ultramodern); patched for HLE audio (`patches/mstan-n64modernruntime/hle-audio-rsp.patch`) |
| `ref/mstan-rt64` | mstan RT64 fork with Apple Metal RHI | local checkout | Renderer |
| `ref/mupen64plus-rsp-hle` | github.com/mupen64plus/mupen64plus-rsp-hle | local checkout (GPL-2.0) | HLE NAUDIO audio backend for `M_AUDTASK` — replaces the broken recompiled aspMain ucode (see `KNOWN-ISSUES.md` macOS #1) |
| `ref/spaghettipad` | github.com/chrissotraidis/spaghettipad | `4f6bb0c` (plus worktree state) | Primary Apple-port reference (build scripts, iOS shell, touch patterns, docs) |

## Upstream dependency graph

- N64ModernRuntime (N64Recomp, RSPRecomp, librecomp, ultramodern, thirdparty
  miniz/o1heap/xxHash/concurrentqueue) — `ref/mstan-n64modernruntime`
  (mstan fork used by AnnePad; PaperPad patches applied).
- RT64 (renderer; direct Metal RHI included) — `ref/mstan-rt64`.
- mupen64plus-rsp-hle — `ref/mupen64plus-rsp-hle`; sources `alist.c`,
  `alist_naudio.c`, `audio.c`, `memory.c` compiled into `librecomp` for
  audio task processing.
- N64Recomp dependencies: rabbitizer, ELFIO, toml11, fmt, sljit (submodules
  of the N64Recomp checkout, initialized on fetch).
- SDL2 2.30.x is used by ReCut's desktop launcher; Apple targets may replace
  it with a static SDL2 build or a UIKit-only shell (AnnePad used static
  SDL2 2.32.10 for input/audio inside the UIKit shell).

## Decomp toolchain (host)

- mips-linux-gnu binutils + gcc (Homebrew `bates64/brew` tap) for the decomp
  ELF build.
- Prebuilt decomp compilers downloaded by `install_compilers.sh`:
  pmret/gcc-papermario, decompals mips-gcc-2.7.2, decompals
  ido-static-recomp 5.3 (macOS builds).
- pigment64 (cargo) for image processing; Python splat64 toolchain from
  `tools/configure/requirements.txt`.

## Verification

Each checkout is fetched detached at its exact commit; submodules are
initialized to the gitlinks of that commit. Source changes are only made via
maintained patches under `patches/` with forward/reverse checks.
