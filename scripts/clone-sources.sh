#!/usr/bin/env bash
# Fetch the exact ROM-free source inputs recorded in dependencies.lock.json.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

# An exported source tree already contains every locked dependency; do not fetch.
if [[ -f "$PAPERPAD_ROOT/SOURCE_MANIFEST.json" ]]; then
    python3 "$script_dir/source-archive.py" --verify "$PAPERPAD_ROOT"
    python3 "$script_dir/verify-prepared-source.py"
    exit 0
fi

require_command git
require_command jq

clone_locked_source() {
    local key=$1
    local destination=$2
    local label=$3
    local url commit actual
    url=$(lock_value "$key" url)
    commit=$(lock_value "$key" commit)

    if [[ ! -d "$destination/.git" ]]; then
        git clone --filter=blob:none "$url" "$destination"
    fi

    [[ -z "$(git -C "$destination" status --porcelain --untracked-files=all)" ]] ||
        die "$label checkout is dirty at $destination; preserve its changes before preparing sources"
    actual=$(git -C "$destination" rev-parse HEAD)
    if [[ "$actual" != "$commit" ]]; then
        if ! git -C "$destination" diff --quiet ||
           ! git -C "$destination" diff --cached --quiet; then
            die "$label checkout is modified at $destination; refusing to change revisions"
        fi
        git -C "$destination" fetch --depth=1 origin "$commit"
        git -C "$destination" checkout --detach "$commit"
    fi

    assert_revision "$destination" "$commit" "$label"
    disable_push "$destination"
}

mkdir -p "$PAPERPAD_REF"
clone_locked_source papermario "$PAPERPAD_REF/papermario" "papermario decomp"
clone_locked_source mupen64plusRspHle "$PAPERPAD_REF/mupen64plus-rsp-hle" "mupen64plus-rsp-hle"
clone_locked_source sdl2 "$PAPERPAD_REF/SDL2" "SDL2"
clone_locked_source zstd "$PAPERPAD_REF/zstd" "zstd"

"$script_dir/init-submodules.sh"

"$script_dir/verify-sources.sh"
note "Pinned PaperPad source inputs are ready."
