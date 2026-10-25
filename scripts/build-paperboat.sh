#!/usr/bin/env bash
# Build the separate PaperBoat product without preparing or modifying Original.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "${1:-device}" in
 device) platform=OS64; profile=ios ;;
 simulator) platform=SIMULATORARM64; profile=simulator ;;
 *) echo 'usage: scripts/build-paperboat.sh [device|simulator]' >&2; exit 2 ;;
esac
build_jobs="${PAPERPAD_BUILD_JOBS:-${CMAKE_BUILD_PARALLEL_LEVEL:-8}}"
if [[ ! "$build_jobs" =~ ^[1-9][0-9]*$ ]]; then
 echo 'PaperBoat build jobs must be a positive whole number (1, 2, ...)' >&2
 exit 2
fi
if [[ ! -e "$root/vendor/paperboat/.git" ]]; then
 git -C "$root" submodule update --init --recursive -- vendor/paperboat
fi
python3 "$root/scripts/verify-paperboat.py"
# PaperBoat must use the same scene-capable SDL as PaperPad Original.
sdl_source="$root/ref/SDL2"
sdl_commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sources"]["sdl2"]["commit"])' "$root/dependencies.lock.json")
sdl_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sources"]["sdl2"]["url"])' "$root/dependencies.lock.json")
if [[ ! -d "$sdl_source" ]]; then
 mkdir -p "$root/ref"
 git clone --filter=blob:none --no-checkout "$sdl_url" "$sdl_source"
 git -C "$sdl_source" checkout --detach "$sdl_commit"
fi
if [[ "$(git -C "$sdl_source" rev-parse HEAD)" != "$sdl_commit" || -n "$(git -C "$sdl_source" status --porcelain)" ]]; then
 echo "SDL2 must be clean at the locked revision: $sdl_source" >&2
 exit 1
fi
python3 "$root/scripts/prepare-paperboat-downloads.py" --build-dir "$root/build-paperboat-$profile"
cmake -S "$root/vendor/paperboat" -B "$root/build-paperboat-$profile" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE=cmake/ios.paperboat.toolchain.cmake -DPLATFORM="$platform" \
 -DIOS_SIGNING=OFF -DCMAKE_BUILD_TYPE=Release -DPAPERPAD_APP_ROOT="$root" \
 -DFETCHCONTENT_SOURCE_DIR_SDL2="$sdl_source" \
 -DSDL_SHARED=OFF -DSDL_STATIC=ON \
 -DCMAKE_PROJECT_INCLUDE_BEFORE="$root/scripts/paperboat-offline-downloads.cmake"
python3 "$root/scripts/verify-paperboat.py" --build-dir "$root/build-paperboat-$profile"
cmake --build "$root/build-paperboat-$profile" --parallel "$build_jobs"
python3 "$root/scripts/record-paperboat-build.py" "$root/build-paperboat-$profile"
