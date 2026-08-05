# Building PaperPad

Work in progress; each phase is filled in as it is proven on this machine.
`STATUS.md` is authoritative about which phases pass.

## Prerequisites

- Apple Silicon Mac, macOS 26.x (this checkout: 26.5.2).
- Xcode 26.6 (17F113) with iOS 26.5 SDK and iOS 18.5/26.5 Simulators.
- CMake 4.4.0, Ninja, Git, Python 3.14, Homebrew.
- A legally obtained Paper Mario (US) 1.0 ROM (`.z64`/`.v64`/`.n64` accepted;
  normalized z64 sha1 `3837f44cda784b466c9a2d99df70d77c322b97a0`).
- Enough free storage for the decomp build, generated AOT source, and build
  trees (several GB).

## Phase 0: reference inputs

SpaghettiPad, the pmret decomp, and Paper-Mario-ReCut live in `ref/`
(gitignored). See `REPOSITORY-INVENTORY.md` for exact pins.

## Phase 1: decomp ELF build (host)

```sh
cd ref/papermario
python3 -m pip install -r tools/configure/requirements.txt
brew install md5sha1sum bates64/brew/mips-linux-gnu-gcc
./install_compilers.sh          # downloads pmret gcc + IDO toolchains
cargo install pigment64
# normalize the user ROM:
python3 - <<'PY'   # byte-swap .v64 -> .z64
...
PY
./configure
ninja                            # expect "papermario.z64: OK"
```

Produces `ver/us/build/papermario.elf` (AOT metadata) and the matching ROM.

## Phase 2: AOT generation (host)

```sh
# build N64Recomp + RSPRecomp host tools from vendored N64ModernRuntime
# run N64Recomp with the Paper Mario config -> generated/paper_mario_recomp_out/
# run RSPRecomp with the n_aspMain config -> generated RSP source
```

## Phase 3: macOS app

## Phase 4: iOS Simulator core + app

## Phase 5: iOS device (unsigned) + packaging
