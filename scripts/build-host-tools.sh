#!/usr/bin/env bash
# Build N64Recomp and RSPRecomp host tools from the vendored N64Recomp checkout.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

require_command cmake
require_command ninja

recut="$PAPERPAD_REF/paper-mario-recut"
n64recomp="$recut/lib/N64ModernRuntime/N64Recomp"
build_dir="$PAPERPAD_ROOT/build-host-tools"

[[ -d "$n64recomp/lib/rabbitizer" ]] || die "N64Recomp submodules missing; run scripts/init-submodules.sh"

cmake -S "$n64recomp" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-DFMT_USE_CONSTEVAL=0"
build_jobs=$(configured_build_jobs)
if [[ -n "$build_jobs" ]]; then
    cmake --build "$build_dir" --parallel "$build_jobs" --target N64Recomp RSPRecomp
else
    cmake --build "$build_dir" --parallel --target N64Recomp RSPRecomp
fi

for tool in N64Recomp RSPRecomp; do
    [[ -x "$build_dir/$tool" ]] || die "host tool was not produced: $tool"
done
note "Host tools ready: $build_dir/N64Recomp, $build_dir/RSPRecomp"
