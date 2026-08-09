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

Any future binary workflow must prove that the package excludes ROMs, extracted assets, generated AOT source, saves, credentials, signing material, personal paths, and private device data. It must also collect the license texts and notices required by the exact shipped dependency revisions.

No physical-device, signed, notarized, TestFlight, App Store, or prebuilt public package is promised by the current repository. Use [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) before publishing source or a binary.
