#!/usr/bin/env bash
# Fetch the exact ROM-free source inputs recorded in dependencies.lock.json.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

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
clone_locked_source paperMarioReCut "$PAPERPAD_REF/paper-mario-recut" "Paper-Mario-ReCut"
clone_locked_source mupen64plusRspHle "$PAPERPAD_REF/mupen64plus-rsp-hle" "mupen64plus-rsp-hle"
clone_locked_source sdl2 "$PAPERPAD_REF/SDL2" "SDL2"
clone_locked_source zstd "$PAPERPAD_REF/zstd" "zstd"

"$script_dir/init-submodules.sh"

# ReCut vendors prebuilt DXC binaries as ordinary files, so its flattened
# source archive loses the executable bit that the shader build requires.
for dxc in "$PAPERPAD_REF/paper-mario-recut/lib/rt64/src/contrib/dxc/bin/"*/dxc-macos; do
    [[ -f "$dxc" ]] && chmod +x "$dxc"
done
note "Pinned PaperPad source inputs are ready."
