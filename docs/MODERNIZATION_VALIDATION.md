# Source-maintenance validation — 2026-09-19

Baseline: application `74b6e45830a06c7f274c5ac1ddd7c625bc13a557`, public `v0.1.0-preview.2`, ReCut upstream `098be0a501eecd5bb894a47964061d05eeedc3a2`. Public IPA SHA-256: `ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029`.

## Verified source and preservation

- Complete private backup of the primary checkout and its Git history, nested working sources, ignored inputs, builds and packages; restored separately. All **142,176 entries** matched by content SHA-256, mode and symlink target. Same physical disk. Primary application tree was clean before work and remains on its original main branch.
- Genuine fork parent verified through GitHub: `chrissotraidis/Paper-Mario-ReCut` → `SMCGames/Paper-Mario-ReCut`.
- Ordinary source import `40351e667c599ef7bdf18841d5fd2213d1252307` matched **11,219 prepared files and modes**. Selected source `9d6eda9eec3b170c65d452ca2e2f7ba64c074632` adds only the explicit HLE build-path override and the iOS deployment-target guard documented in the exception manifest. No upstream version update.
- All **247 generated C/C++/header files**, including game and audio-RSP outputs, regenerated with the rebuilt host tools and compared byte-for-byte with the baseline: zero differences. ROM and generated outputs stayed private.
- Existing controller-slot test compiled and passed all scenarios.
- Repository safety checks and shell syntax passed. Python source/archive/provenance scripts compile.
- Exact five source pins and source manifest verification passed. The original verifier did not reject prepared-source drift; the replacement does.

## Build and package qualification

Current host: Xcode 27.0 (`27A266a`), iPhoneOS 27.0 SDK, CMake 4.4.2 and Ninja 1.13.2. Apple's matching optional Metal Toolchain was absent and installed for this audit. This changes the build environment relative to historical artifacts; source equality does not imply binary hash equality.

N64Recomp/RSPRecomp and RT64 shader host tools rebuilt successfully. The following qualification uses application source **`5088e13960c6933d7ba4f2e90ab3171419b8263d`**; subsequent validation-documentation commits do not change the build inputs.

- iOS arm64 Release device build passed with signing disabled. Unsigned IPA audit passed: original bundle `com.chrissotraidis.paperpad`, version **0.1.0/build 2**, minimum iOS **15.0**, privacy declaration, required notices, system-only dynamic dependencies, no embedded provisioning/signature, no loose ROM/save/log/generated-source payload, and no detected personal build paths in the executable.
- Local validation IPA: **11,605,168 bytes**, SHA-256 **`4a7b1ea95b661f99862432f284d506108d5a12f2595e6c2efd3b1faab9122cca`**. This is a private validation candidate, not a replacement public Preview 2 asset. Its `BUILD_PROVENANCE.json` names the above app source and all dependency pins; it records the packaging source snapshot, not an independently embedded compiler attestation.
- macOS arm64 Release build passed; ad-hoc signature passed `codesign --verify --deep --strict`. No macOS binary was published. Simulator was not rebuilt in this qualification; it is not a separately shipped product.
- The public Preview 2 IPA was downloaded anonymously, matched the recorded hash, and passed the original baseline package audit. Candidate/public plist differences were confined to SDK/Xcode/host build metadata. Version, bundle identity, minimum OS and app data settings remain equal. The compiled executable and asset catalog differ under the newer toolchain, so binary equality is not claimed. Notices/rights/provenance are intentionally updated. The public IPA's embedded installation guide still named Preview 1; the existing main source already corrected it to Preview 2.

## Delivered source and recovery rehearsal

- Explicit archive from `5088e13960c6933d7ba4f2e90ab3171419b8263d`: **`PaperPad-restorable-source.tar.gz`**, SHA-256 **`4c45075e3d9282b1faf1f8a214c2536dbeb01eb10d5155c743335003df6efc52`**. Two independent exports are byte-identical. All **20,278 files** and five full dependency trees verified after extraction, without Git metadata. Altering an archived source file was correctly rejected; restoring it restored verification.
- A fresh macOS build from that restored archive passed under `sandbox-exec -p '(version 1)(allow default)(deny network*)'`, including SDL2, renderer/shader compilation and the app. Private generated game inputs were supplied separately; system compiler/SDK tools were preinstalled. No original checkout dependency or build cache was supplied. This proves a disconnected app rebuild from the maintained sources plus those prerequisites, **not** a self-contained offline ROM-to-binary toolchain. Source manifest verification still passed after the build.
- The archive rehearsal found and fixed Git-metadata assumptions in SDL/decomp setup and the submodule entry point. Source export also normalizes Git executable intent to portable 644/755 modes and works with the tested Python 3.11.2.
- A deliberately changed maintained source file was rejected by the clean-source verifier; exact restoration passed. Existing controller tests pass all scenarios. Hosted source-integrity/controller checks passed on `5088e13` ([push run](https://github.com/chrissotraidis/paperpad/actions/runs/35411060760), [PR run](https://github.com/chrissotraidis/paperpad/actions/runs/35411063402)). These are source checks, not hosted Apple builds.
- Complete app and ReCut history bundles additionally passed `git bundle verify`. The original full private archive/restore remains preserved. In a disposable migrated checkout, restoring the baseline app commit reproduced exact root tree **`2c734e693ff2e1e08bd9f444ecda208d09b58400`**. The disposable rollback checkout was then removed using `git worktree remove`; main and user data were never reset. The already verified full restore contains the original prepared dependencies and private inputs.

No physical device is used, no app is installed, and no new gameplay acceptance or public binary publication is claimed. Current Preview 2 stays intact. Current source delivery/game-source rights questions remain open as specified in `RIGHTS_AND_LICENSES.md`.
