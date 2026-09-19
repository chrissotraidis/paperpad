# Dependency inventory

Verified source-maintenance snapshot: 2026-09-19. `dependencies.lock.json` is the machine-readable authority. ReCut is a pinned maintained submodule under `vendor/`; unmodified inputs remain in ignored `ref/`.

| Component | Exact revision | Purpose | License / rights note |
|---|---|---|---|
| [pmret/papermario](https://github.com/pmret/papermario) | `c61db66e3cce7e8fa5b53d3e9ecd01632e7b064a` | Paper Mario US decompilation, ROM verification, ELF metadata | Source-available decompilation; Nintendo material remains excluded; inspect pinned notices before redistribution |
| [maintained Paper-Mario-ReCut](https://github.com/chrissotraidis/Paper-Mario-ReCut/tree/codex/paperpad-preview2-source) | `43f61ea373e02372ca9e0330beccf97ec4c72e44` | Game-specific N64Recomp integration; vendors N64ModernRuntime and RT64 | Multiple nested components and licenses; inspect the pinned tree |
| [mupen64plus-rsp-hle](https://github.com/mupen64plus/mupen64plus-rsp-hle) | `8a7a472a7172eb2c8725b305eae26818ed7b51a2` | HLE NAUDIO backend | Compiled HLE files carry GPL-2.0-or-later headers; preserve LICENSES and file notices |
| [SDL 2.32.10](https://github.com/libsdl-org/SDL) | `5d249570393f7a37e037abf22cd6012a4cc56a71` | Window, input, controllers, and audio | zlib license in pinned source |
| [zstd 1.5.6](https://github.com/facebook/zstd) | `794ea1b0afca0f020f4e57b6732332231fb23c70` | Compression source/CMake files needed by the flattened ReCut vendor tree | BSD/GPL dual layout; shipped library portions and notices must be audited |
| [SpaghettiPad](https://github.com/chrissotraidis/spaghettipad) | `4f6bb0c` | Apple-platform research reference only | Reference-only; not fetched or linked into PaperPad by the current build |

## Transitive build inputs

ReCut vendors N64ModernRuntime, N64Recomp, RT64, shader compilers, and nested source as ordinary tracked files. Retained nested `.gitmodules` files do not correspond to nested gitlinks in this snapshot. The maintained branch preserves the exact prepared source from upstream base `098be0a501eecd5bb894a47964061d05eeedc3a2`, with one explicit build-path exception; see [source maintenance](SOURCE_MAINTENANCE.md). The build also uses Apple SDK frameworks and host tools including CMake, Ninja, Python, Rust/Cargo, GNU cpp, and GNU binutils. The table above is not a complete binary-notice manifest.

Before distributing a binary:

1. enumerate the exact linked libraries and bundled resources from the final artifact;
2. copy applicable license and notice texts from the exact pinned/fetched revisions;
3. verify that `apple/app/ThirdPartyNotices.txt` matches that artifact rather than relying on this inventory; and
4. repeat the rights and package audit in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

The Preview 1 packager collects the exact license and notice files into
`PaperPad.app/Licenses/`, bundles `ThirdPartyNotices.txt`, and rejects a package
that omits the required top-level dependency documents. This does not collapse
those components into a single PaperPad license; every included license remains
authoritative for its own component.

See [RIGHTS_AND_LICENSES.md](../RIGHTS_AND_LICENSES.md). This inventory is engineering documentation, not legal advice.
