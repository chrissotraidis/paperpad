#!/usr/bin/env bash
# Build and ad-hoc sign the ROM-free Apple Silicon PaperPad application.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

rom_path=
while (($#)); do
    case "$1" in
        --rom) (($# >= 2)) || die "--rom requires an absolute path"; rom_path=$2; shift 2 ;;
        *) die "usage: scripts/build-macos-app.sh [--rom /absolute/path/to/rom]" ;;
    esac
done

"$script_dir/clone-sources.sh"
"$script_dir/apply-patches.sh"

if [[ -n "$rom_path" ]]; then
    "$script_dir/setup-decomp-tools.sh"
    "$script_dir/prepare-rom.sh" --rom "$rom_path"
    local_binutils="$PAPERPAD_ROOT/build-tools/mips-binutils-2.46.1/bin"
    PATH="$local_binutils:$PATH" "$script_dir/build-decomp.sh"
    "$script_dir/build-host-tools.sh"
    "$script_dir/generate-game.sh"
fi

[[ -f "$PAPERPAD_GENERATED/aot/paper_mario_recomp_out/lookup.cpp" ]] || \
    die "generated game sources are missing; rerun with --rom /absolute/path/to/your/ROM"

"$script_dir/build-sdl2.sh"
build_dir="$PAPERPAD_ROOT/build-macos-release"
cmake -S "$PAPERPAD_ROOT" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release
build_jobs=$(configured_build_jobs)
if [[ -n "$build_jobs" ]]; then
    cmake --build "$build_dir" --parallel "$build_jobs" --target PaperPad
else
    cmake --build "$build_dir" --parallel --target PaperPad
fi

app="$build_dir/PaperPad.app"
[[ -x "$app/Contents/MacOS/PaperPad" ]] || die "PaperPad.app was not produced"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"
note "PaperPad macOS app ready: $app"
