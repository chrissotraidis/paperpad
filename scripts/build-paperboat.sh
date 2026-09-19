#!/usr/bin/env bash
# Build the separate PaperBoat product without preparing or modifying Original.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "${1:-device}" in
 device) platform=OS64; profile=ios ;;
 simulator) platform=SIMULATORARM64; profile=simulator ;;
 *) echo 'usage: scripts/build-paperboat.sh [device|simulator]' >&2; exit 2 ;;
esac
if [[ ! -e "$root/vendor/paperboat/.git" ]]; then
 git -C "$root" submodule update --init --recursive -- vendor/paperboat
fi
python3 "$root/scripts/verify-paperboat.py"
cmake -S "$root/vendor/paperboat" -B "$root/build-paperboat-$profile" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE=cmake/ios.paperboat.toolchain.cmake -DPLATFORM="$platform" \
 -DIOS_SIGNING=OFF -DCMAKE_BUILD_TYPE=Release -DPAPERPAD_APP_ROOT="$root" \
 -DSDL_SHARED=OFF -DSDL_STATIC=ON
python3 "$root/scripts/verify-paperboat.py" --build-dir "$root/build-paperboat-$profile"
cmake --build "$root/build-paperboat-$profile" --parallel "${PAPERPAD_BUILD_JOBS:-8}"
python3 "$root/scripts/record-paperboat-build.py" "$root/build-paperboat-$profile"
