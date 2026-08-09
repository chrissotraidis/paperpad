#!/usr/bin/env bash
# Apply every maintained PaperPad patch to the pinned ignored source tree.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

recut="$PAPERPAD_REF/paper-mario-recut"
[[ -d "$recut/.git" ]] || die "Paper-Mario-ReCut is missing; run scripts/clone-sources.sh"

apply_one() {
    local checkout=$1
    local patch=$2
    # Every maintained patch is rooted at the ReCut checkout. Keeping one
    # repository root avoids git-apply silently skipping paths when a vendored
    # library is not an independent Git worktree.
    if git -C "$checkout" apply --check "$patch" >/dev/null 2>&1; then
        git -C "$checkout" apply "$patch"
        note "Applied: ${patch#"$PAPERPAD_ROOT/"}"
    elif git -C "$checkout" apply --reverse --check "$patch" >/dev/null 2>&1; then
        note "Already applied: ${patch#"$PAPERPAD_ROOT/"}"
    else
        die "patch is neither cleanly applicable nor already applied: $patch"
    fi
}

# patches/mstan-* document fixes already incorporated by the pinned ReCut
# snapshot or superseded by the maintained RT64 patches below. They are kept
# as provenance and intentionally are not re-applied.
for patch in "$PAPERPAD_ROOT"/patches/n64recomp/*.patch \
             "$PAPERPAD_ROOT"/patches/n64modernruntime/*.patch \
             "$PAPERPAD_ROOT"/patches/rt64/*.patch; do
    apply_one "$recut" "$patch"
done

note "PaperPad runtime and renderer patches are ready."
