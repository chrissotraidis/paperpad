#!/usr/bin/env bash
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"
recut="$PAPERPAD_ROOT/vendor/paper-mario-recut"
if [[ -e "$recut/.git" ]]; then
    [[ -z "$(git -C "$recut" status --porcelain --untracked-files=all)" ]] ||
        die "maintained ReCut checkout is dirty; refusing to update it"
fi
git -C "$PAPERPAD_ROOT" submodule update --init -- vendor/paper-mario-recut
assert_revision "$recut" "$(lock_value paperMarioReCut commit)" "maintained ReCut"
# ReCut's pinned snapshot contains ordinary vendored files, not nested gitlinks.
# Its retained nested .gitmodules files describe historical origins only.
note "Maintained ReCut source initialized."
