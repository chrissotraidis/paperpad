#!/usr/bin/env bash
# Build the pinned native SDL2 static library used by the macOS app.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

source_dir="$PAPERPAD_REF/SDL2"
build_dir="$PAPERPAD_ROOT/build-macos-sdl2"
[[ -f "$source_dir/CMakeLists.txt" ]] || die "SDL2 is missing; run scripts/clone-sources.sh"

cmake -S "$source_dir" -B "$build_dir" -G Ninja \
    -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF -DSDL_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release
build_jobs=$(configured_build_jobs)
if [[ -n "$build_jobs" ]]; then
    cmake --build "$build_dir" --parallel "$build_jobs" --target SDL2-static
else
    cmake --build "$build_dir" --parallel --target SDL2-static
fi
[[ -f "$build_dir/libSDL2.a" ]] || die "SDL2 static library was not produced"
note "Native SDL2 ready: $build_dir/libSDL2.a"
