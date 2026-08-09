# Repository inventory and pinned sources

Updated 2026-08-09. `dependencies.lock.json` is authoritative for fetched revisions. All upstream checkouts, generated game code, ROM inputs, build trees, and artifacts are local ignored inputs unless explicitly documented otherwise.

## Fetched source inputs

| Local path | Lock key | Purpose |
|---|---|---|
| `ref/papermario` | `papermario` | pmret decompilation, ROM verification, and ELF metadata |
| `ref/paper-mario-recut` | `paperMarioReCut` | ReCut game integration; vendors N64ModernRuntime, N64Recomp, and RT64 |
| `ref/mupen64plus-rsp-hle` | `mupen64plusRspHle` | HLE NAUDIO implementation |
| `ref/SDL2` | `sdl2` | Native window, input, controller, and audio library |
| `ref/zstd` | `zstd` | Compression source/CMake input required by the flattened ReCut tree |

`scripts/clone-sources.sh` checks out exact commits, initializes required nested inputs, and disables push URLs. `scripts/verify-sources.sh` checks the pins. `scripts/apply-patches.sh` applies the maintained N64Recomp, N64ModernRuntime, and RT64 patch series from this repository.

The files under `patches/mstan-*` are historical provenance only and are intentionally not applied by the maintained script.

## Private/generated local inputs

| Path | Contents | Publication rule |
|---|---|---|
| `generated/rom/` | normalized private ROM | Never commit or package |
| `generated/aot/` | ROM-derived statically recompiled source | Never commit or package |
| `ref/papermario/ver/us/baserom.z64` | private decomp build input | Never commit or package |
| `ref/papermario/ver/us/build/` | decomp outputs, including a rebuilt ROM/ELF | Never commit or package |
| `build-*` | host tools, libraries, Xcode/CMake trees, and app artifacts | Never commit; audit any selected external release artifact |
| `logs/` | local build/runtime/crash evidence | Never publish without sensitive-data review |

## Tracked project-owned inputs

- `apple/app/`: Apple application shell, touch/settings/ROM flow, metadata, privacy manifest, and notice seed.
- `src/`: native runner, input, renderer/runtime bridge, paths, stubs, and hooks.
- `config/`: generated N64Recomp configuration template.
- `patches/`: reviewable changes to exact upstream source pins.
- `scripts/`: reproducible fetch, generation, build, and audit automation.
- `docs/`: build, architecture, evidence, status, dependency, and release records.

Run `scripts/check-repo-safety.sh` before source publication. See [DEPENDENCIES.md](DEPENDENCIES.md) for exact revisions and license notes.
