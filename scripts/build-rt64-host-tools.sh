#!/usr/bin/env bash
# Build the native shader helper executables required by iOS cross-compilation.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

require_command cmake
require_command ninja

"$script_dir/build-sdl2.sh"

rt64="$PAPERPAD_REF/paper-mario-recut/lib/rt64"
build_dir="$PAPERPAD_ROOT/build-rt64-host-tools"
cmake -S "$rt64" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="$build_dir" \
    -DRT64_STATIC=ON -DRT64_BUILD_TOOLS=ON \
    -DPAPERPAD_ZSTD_SOURCE_DIR="$PAPERPAD_REF/zstd" \
    -DSDL2_INCLUDE_DIRS="$PAPERPAD_REF/SDL2/include" \
    -DSDL2_LIBRARIES="$PAPERPAD_ROOT/build-macos-sdl2/libSDL2.a"

build_jobs=$(configured_build_jobs)
if [[ -n "$build_jobs" ]]; then
    cmake --build "$build_dir" --parallel "$build_jobs" --target file_to_c spirv_cross_msl
else
    cmake --build "$build_dir" --parallel --target file_to_c spirv_cross_msl
fi

spirv_cross_output="$rt64/build/bin/spirv_cross_msl"
[[ -x "$spirv_cross_output" ]] || die "spirv_cross_msl host tool was not produced"
cmake -E copy_if_different "$spirv_cross_output" "$build_dir/spirv_cross_msl"
[[ -x "$build_dir/file_to_c" ]] || die "file_to_c host tool was not produced"
[[ -x "$build_dir/spirv_cross_msl" ]] || die "spirv_cross_msl host tool was not produced"
note "RT64 host tools ready: $build_dir"
