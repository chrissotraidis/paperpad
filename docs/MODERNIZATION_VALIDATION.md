# Source-maintenance validation — 2026-09-19

Baseline: application `74b6e45830a06c7f274c5ac1ddd7c625bc13a557`, public `v0.1.0-preview.2`, ReCut upstream `098be0a501eecd5bb894a47964061d05eeedc3a2`. Public IPA SHA-256: `ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029`.

## Verified source and preservation

- Complete private backup of the primary checkout and its Git history, nested working sources, ignored inputs, builds and packages; restored separately. All **142,176 entries** matched by content SHA-256, mode and symlink target. Same physical disk. Primary application tree was clean before work and remains on its original main branch.
- Genuine fork parent verified through GitHub: `chrissotraidis/Paper-Mario-ReCut` → `SMCGames/Paper-Mario-ReCut`.
- Ordinary source import `40351e667c599ef7bdf18841d5fd2213d1252307` matched **11,219 prepared files and modes**. The next selected source commit adds only the explicit HLE build-path override documented in the exception manifest. No upstream version update.
- All **247 generated C/C++/header files**, including game and audio-RSP outputs, regenerated with the rebuilt host tools and compared byte-for-byte with the baseline: zero differences. ROM and generated outputs stayed private.
- Existing controller-slot test compiled and passed all scenarios.
- Repository safety checks and shell syntax passed. Python source/archive/provenance scripts compile.
- Exact five source pins and source manifest verification passed. The original verifier did not reject prepared-source drift; the replacement does.

## Build and package qualification

Current host: Xcode 27.0 (`27A266a`), iPhoneOS 27.0 SDK, CMake 4.4.2 and Ninja 1.13.2. Apple's matching optional Metal Toolchain was absent and installed for this audit. This changes the build environment relative to historical artifacts; source equality does not imply binary hash equality.

N64Recomp/RSPRecomp and RT64 shader host tools rebuilt successfully. Device/Simulator/macOS application builds, restored-source rebuild, archive hash and candidate package audits are recorded below as results become available; none is implied by successful host-tool compilation.

No physical device is used, no app is installed, and no new gameplay acceptance or public binary publication is claimed. Current Preview 2 stays intact. Current source delivery/game-source rights questions remain open as specified in `RIGHTS_AND_LICENSES.md`.
