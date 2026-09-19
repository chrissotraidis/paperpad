#!/usr/bin/env bash
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
for key in papermario paperMarioReCut mupen64plusRspHle sdl2 zstd; do
    case "$key" in
        paperMarioReCut) checkout="$PAPERPAD_ROOT/vendor/paper-mario-recut" ;;
        mupen64plusRspHle) checkout="$PAPERPAD_REF/mupen64plus-rsp-hle" ;;
        sdl2) checkout="$PAPERPAD_REF/SDL2" ;;
        *) checkout="$PAPERPAD_REF/$key" ;;
    esac
    assert_revision "$checkout" "$(lock_value "$key" commit)" "$key"
    [[ -z "$(git -C "$checkout" status --porcelain --untracked-files=all)" ]] ||
        die "$key source is dirty: $checkout"
done
expected=$(lock_value paperMarioReCut commit)
gitlink=$(git -C "$PAPERPAD_ROOT" ls-files --stage vendor/paper-mario-recut | awk '{print $2}')
[[ "$gitlink" == "$expected" ]] || die "ReCut gitlink and dependency lock disagree"
python3 "$script_dir/verify-prepared-source.py"
note "Pinned clean sources and prepared-source identity verified."
