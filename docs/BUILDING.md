# Building PaperPad

These instructions describe the maintained Apple Silicon source-build paths verified on 2026-08-09. PaperPad does not distribute a ROM or ROM-derived playable output.

## Host requirements

- Apple Silicon macOS with Xcode and the iOS Simulator SDK
- CMake, Ninja, Git, jq, Python 3.11+, Rust/Cargo, Homebrew, curl, make, and standard Apple command-line tools
- GNU `cpp-16`; `scripts/setup-decomp-tools.sh` installs Homebrew GCC when missing
- Several gigabytes of free disk space
- A legally obtained, unmodified Paper Mario (US) 1.0 ROM

Accepted input byte orders are `.z64`, `.v64`, and `.n64`. The input must normalize to 40 MiB with SHA-1 `3837f44cda784b466c9a2d99df70d77c322b97a0`.

## Clean private generation

The top-level build scripts perform the complete pipeline when passed `--rom`:

```sh
scripts/build-macos-app.sh --rom /absolute/path/to/your/rom
# or
scripts/build-ios-simulator.sh --rom /absolute/path/to/your/rom
```

That pipeline:

1. clones exact pins from `dependencies.lock.json` into ignored `ref/`;
2. initializes required submodules and disables source-checkout push URLs;
3. applies the ordered maintained patch series;
4. creates the pmret Python environment and host toolchain;
5. normalizes and validates the private ROM under ignored `generated/rom/`;
6. builds the matching pmret decompilation ELF and verifies its rebuilt ROM hash;
7. builds N64Recomp/RSPRecomp host tools and generates ignored AOT source;
8. builds the chosen ROM-free app.

The first clean generation can take significant time. Set `PAPERPAD_BUILD_JOBS` to a positive integer to limit build parallelism.

## Incremental builds

Once `generated/aot/paper_mario_recomp_out/lookup.cpp` exists, omit `--rom`:

```sh
scripts/build-macos-app.sh
scripts/build-ios-simulator.sh
```

The scripts still verify/fetch pins and apply maintained patches. They refuse to continue if the generated source is absent.

## Outputs

| Target | Output | Notes |
|---|---|---|
| macOS | `build-macos-release/PaperPad.app` | Apple Silicon; ad-hoc signed and verified by the script |
| iOS Simulator | `build-ios-simulator/Release/PaperPad.app` | arm64 Simulator app; code signing disabled; iPhone+iPad; minimum iOS 15.0 |

Both app artifacts must remain ROM-free.

## iOS Simulator install and first run

Boot one device, install, and launch:

```sh
xcrun simctl list devices available
xcrun simctl boot "iPad Pro 11-inch (M4)"
open -a Simulator
xcrun simctl install booted build-ios-simulator/Release/PaperPad.app
xcrun simctl launch booted com.chrissotraidis.paperpad
```

Choose your own ROM from the first-run screen. The app validates, normalizes, and stores it privately in that Simulator's Application Support container. Use PaperPad Menu > Manage Game ROM to replace or remove it.

End the session before testing another target:

```sh
xcrun simctl terminate booted com.chrissotraidis.paperpad || true
xcrun simctl shutdown booted
```

Never run PaperPad and a comparison game simultaneously; it makes screenshots, input, audio, CPU, crash, and stability evidence ambiguous.

## Source and patch verification

```sh
scripts/clone-sources.sh
scripts/verify-sources.sh
scripts/apply-patches.sh
```

`apply-patches.sh` is idempotent: each patch must either apply cleanly or already be present. The historical `patches/mstan-*` files document earlier provenance; the maintained applied series is under `patches/n64recomp/`, `patches/n64modernruntime/`, and `patches/rt64/`.

## Release checks

```sh
scripts/check-repo-safety.sh
git diff --check
bash -n scripts/*.sh
python3 -m py_compile scripts/generate-n64recomp-config.py
```

Then follow [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). A Simulator result does not establish physical-device readiness.

## Troubleshooting

- **Generated game sources are missing**: rerun the selected build with `--rom /absolute/path/...`.
- **Unsupported ROM size or SHA-1**: confirm the game, region, revision, and that the dump is unmodified. Byte order is normalized automatically.
- **Pinned checkout is modified**: inspect `ref/` changes. The fetch script intentionally refuses to change revisions over unknown edits. Maintained patches should be applied only through `scripts/apply-patches.sh`.
- **Missing MIPS assembler**: run `scripts/build-mips-binutils.sh` or rerun the clean build; it creates a local ignored toolchain.
- **Simulator shows stale code**: terminate the app, reinstall the exact new `.app`, then relaunch. Shut down unused devices.
- **Crash**: run `scripts/capture-crashes.sh`, remove sensitive/user-specific content from the report, and include exact reproduction steps.
