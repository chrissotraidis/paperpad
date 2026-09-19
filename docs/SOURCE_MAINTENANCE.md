# Maintained source, archives and rollback

PaperPad's application repository and Preview 2 product remain intact. This change preserves the existing engine; the separate [PaperBoat decision](PAPERBOAT-AUDIT.md) is the direction for a later major-version implementation.

## Source ownership

`vendor/paper-mario-recut` is a submodule of the genuine [chrissotraidis/Paper-Mario-ReCut](https://github.com/chrissotraidis/Paper-Mario-ReCut) fork, whose GitHub parent is [SMCGames/Paper-Mario-ReCut](https://github.com/SMCGames/Paper-Mario-ReCut). The per-project branch is `codex/paperpad-preview2-source`. Neither the fork's default branch nor another application's selected source is changed.

The upstream base stays `098be0a501eecd5bb894a47964061d05eeedc3a2`. The imported source commit `40351e667c599ef7bdf18841d5fd2213d1252307` matches all **11,219** files and modes in the prepared Preview 2 checkout. [Patch map](source-maintenance/patch-map.json) identifies the source commit replacing each of 25 production patches. Five `mstan-*` patch records were historical already. All 30 remain available as non-production history.

The selected gitlink adds two build-only exceptions: librecomp accepts an explicit `MUPEN_RSP_HLE_DIR` cache path, and the app points it to its unchanged pinned `ref/mupen64plus-rsp-hle`. This is necessary because ReCut moved from ignored `ref/` into `vendor/`. RT64 also retains the iOS deployment target during dependency checks instead of assigning the macOS 10.15 default, which Xcode 27 rejects as an iOS version. Desktop targeting is unchanged. No runtime algorithm or upstream version changes. [The exception manifest](source-maintenance/path-exceptions.json) records its exact hash and commit; [the original prepared manifest](source-maintenance/prepared-recut.json) remains unchanged.

ReCut's runtime/compiler/renderer were flattened into ordinary tracked source upstream. Keeping them together preserves that actual ancestry and exact effective contents. The retained nested `.gitmodules` files describe historical projects but there are no nested gitlinks in this ReCut snapshot. Do not replace them with arbitrary current upstream submodule tips.

Unmodified pmret, SDL2, zstd and Mupen RSP HLE inputs retain their existing exact upstream pins in `dependencies.lock.json`. The decomp provides private ROM-derived ELF metadata; it is not a new engine upgrade. HLE is a fallback; current PaperPad prefers its generated game-specific audio RSP.

## Normal builds and new fixes

Run `scripts/clone-sources.sh`, then the existing build entry point. Bootstrap initializes the exact ReCut gitlink and unchanged upstream inputs. `scripts/verify-sources.sh` checks commits, clean worktrees, gitlink/lock agreement, every preserved ReCut file hash and mode, and the two permitted build changes. CMake also runs that check, including direct device builds. Dirty sources fail with a useful message; they are not reset. `scripts/apply-patches.sh` remains a compatibility verifier and applies nothing.

For a new runtime fix, create a topic branch from the selected maintained source, edit the actual file, test it, commit and push to the maintained fork. Update the app gitlink, dependency lock, expected-source evidence and documentation together. Keep the historical prepared manifest as the baseline and record reviewed exceptions explicitly. Compare against the frozen ReCut base and use an app PR to review the delta. An upstream upgrade needs separate qualification; never move a shared default branch as an app update mechanism.

The source-integrity CI checks source preparation and controller ownership without requiring a ROM. It is not an iOS build or gameplay test.

## Source delivery and offline verification

From a clean committed app tree with initialized dependencies:

```sh
python3 scripts/source-archive.py --output /absolute/private/output/PaperPad-source.tar.gz
mkdir /absolute/private/restore
 tar -xzf /absolute/private/output/PaperPad-source.tar.gz -C /absolute/private/restore
python3 /absolute/private/restore/PaperPad-source/scripts/source-archive.py --verify /absolute/private/restore/PaperPad-source
```

The exporter uses Git's selected trees, not working-directory copies. It includes all five dependency trees, notices, build scripts, and a manifest with file hashes/modes and immutable source identities. It excludes ignored ROMs, generated game output, saves, logs, signing material and caches. The app's ordinary GitHub-generated ZIP does **not** include the ReCut submodule; use the explicit source workflow instead.

Restored archives bypass Git/network bootstrap and verify `SOURCE_MANIFEST.json`. They still need the documented compiler/SDK tools, Python/Rust/decomp prerequisites and the user's supported ROM for fresh AOT generation. An offline app rebuild can be qualified with separately provisioned private generated inputs; that must not be mislabeled a completely self-contained offline ROM-to-binary build.

The export is an engineering source bundle, **not a declaration that GPL corresponding-source and game-source redistribution questions are resolved**. Keep it private until the distribution boundary is qualified. Source provenance in candidate packages names the selected app/dependencies without embedding private paths, identifiers or signing data.

## Backup and rollback

Before changes, a complete private checkout archive was restored separately and checked against **142,176 entries**, including content SHA-256, file modes and symlink targets. It contains the complete original Git data, prepared dependency trees, ignored private inputs, build trees and app packages. It is outside the repository on the same physical disk; it is recovery protection against edits, not an independent-disk backup. The exact local location is retained in the task handoff rather than public source.

The production baseline is `74b6e45830a06c7f274c5ac1ddd7c625bc13a557`. To inspect/rebuild it without modifying an existing checkout:

```sh
git worktree add --detach /absolute/disposable/paperpad-baseline 74b6e45830a06c7f274c5ac1ddd7c625bc13a557
```

Restore the backed-up prepared `ref/` and private generated inputs into that disposable tree; do not rely on the old patch replay to reconstruct it. The known mixed worker-lifetime patch prevents an unconditional clean-bootstrap claim for the old workflow. Restore the archive into an empty directory, verify its private manifest, and use the baseline commands there. Never overwrite a dirty working checkout or its source dependencies to rehearse rollback.

No device installation is part of this source migration. For any later in-place reinstall, verify the same bundle ID, signing team/profile and permitted device first, back up the full relevant app container, and compare durable data after installation. Preserve the public Preview 2 IPA and its exact hash. Never uninstall to work around identity mismatches.

## Acceptance boundary

See [modernization validation](MODERNIZATION_VALIDATION.md) for actual build, source-output, archive and rollback checks. Public `v0.1.0-preview.2` remains unchanged. This work does not include publication, merge authorization, new hardware/gameplay acceptance or PaperBoat adoption in the shipping binary.
