# Rights and licensing boundary

PaperPad is an independent, unofficial source-port project. It is not affiliated with or endorsed by Nintendo, pmret, SMCGames, N64Recomp/N64ModernRuntime, RT64, mupen64plus, SDL, or their contributors.

## Game data and screenshots

This repository does not distribute a Nintendo ROM, extracted original game asset, audio, model, texture, save, generated playable game source, or playable ROM-derived archive. Users must supply their own legally obtained supported game data locally. Do not commit, bundle, upload, attach to CI, link to, or request those files.

Documentation screenshots were captured from a locally supplied game copy or downloaded as visual references from the sources identified in the README. They document compatibility and visual behavior; they are not playable game data. Game names, characters, copyrights, and trademarks remain the property of their respective owners. PaperPad branding must remain original and must not imply official status.

## Source and dependency rights

The Paper Mario decompilation, Paper-Mario-ReCut, N64ModernRuntime, N64Recomp, RT64, mupen64plus-rsp-hle, SDL, zstd, and every transitive dependency retain their own license and rights boundaries. Do not describe the complete combined tree as having one license.

The pinned pmret Paper Mario tree does not present a general grant for Nintendo-owned game content. A decompilation's source availability does not grant permission to redistribute the original game or generated playable output. Confirm the actual license and notice files of every pinned dependency before publishing a binary or making commercial or store-distribution claims.

PaperPad's integration source, scripts, documentation, and original artwork do not relicense third-party source or game material. [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) is an engineering inventory, not legal advice or a substitute for the underlying licenses.

## Release packages

The audited `v0.1.0-preview.2` package confirms that the unsigned IPA excludes ROMs, extracted assets, generated AOT source, saves, credentials, signing material, personal paths, and private device data. The package includes PaperPad's notices and the license/rights files collected for the exact shipped dependency revisions. The matching release tag identifies its source snapshot.

Preview 2 is a ROM-free, unsigned public package for users to sign with their own Apple credentials. It is not a maintainer-signed, notarized, TestFlight, or App Store release. Use [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) before publishing another source or binary release.

## Source-maintenance qualification (2026-09-19)

The maintained ReCut fork preserves the existing component licenses and upstream
history. It does not relicense the app or game. Normal builds consume an exact
source gitlink instead of applying local patches; [source delivery and
rollback](docs/SOURCE_MAINTENANCE.md) describe the explicit dependency archive.
The automatic application source ZIP alone does not include that submodule.

The linked N64ModernRuntime carries GPLv3, and the compiled Mupen RSP HLE files
(`alist.c`, `alist_naudio.c`, `audio.c`, `memory.c`) carry GPL-2.0-or-later
headers. The previous dependency inventory's BSD-style description of HLE was
incorrect. The existing bundled HLE notice already identified GPL-2.0-or-later;
it is preserved. Runtime/game-source delivery must be assessed against the
actual linked executable and the [GPL corresponding-source requirements](https://www.gnu.org/licenses/gpl.en.html),
not merely whether the IPA omits the ROM.

Unresolved release qualification is specific: the current binary includes
private ROM-derived game code while this repository excludes that generated
source; the scope and permitted delivery of all source needed to rebuild the
combined executable have not been reconciled here. The app also has no root
blanket license grant; this task does not invent one. These questions require
resolution before calling a new binary/source distribution fully qualified.
The local engineering source archive is not asserted to be complete legal
Corresponding Source. No new binary release is part of this task.

ReCut's upstream `COMPLIANCE.md` also retains a provenance question for its
built-in texture replacements. PaperPad's `src/builtin_texture_pack.cpp` is a
no-op, and its target does not package or enable that upstream texture pack.
Preserving upstream source history does not establish rights in those assets;
do not add them to a PaperPad package or treat the fork relationship as clearance.


## PaperBoat candidate qualification

The new PaperPad target does **not** link Original's ReCut, N64ModernRuntime or RT64. The Original-specific GPL/generated-private-source issue above must not be automatically attributed to this different executable. PaperBoat's pinned root notice is CC0, libultraship and Torch carry MIT notices, and nested components retain their own terms in the packaged license collection.

The narrower unresolved question is the scope of the rights in compiled game-derived code inherited through PaperBoat's decompilation/DX sources. [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en) grants or waives only rights held by its affirmer; it does not clear third-party rights. This work records those notices without inventing a Nintendo rights grant. The 0.2.0 release supplies a separate Boat source archive with exact nested sources, prepared dependency inputs and notices. Publication is explicitly requested by the project owner; it does not resolve or conceal the recorded third-party rights question, invent a Nintendo rights grant, or certify blanket redistribution clearance. See the release evidence in `docs/PAPERBOAT_DEVELOPMENT.md` for technical reproduction and acceptance scope.
