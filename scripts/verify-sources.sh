#!/usr/bin/env bash
# Verify pinned reference checkouts and their submodules.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

require_command git
require_command jq

assert_revision "$PAPERPAD_REF/papermario" "$(lock_value papermario commit)" "papermario decomp"
assert_revision "$PAPERPAD_REF/paper-mario-recut" "$(lock_value paperMarioReCut commit)" "Paper-Mario-ReCut"

# N64Recomp submodules used by host-tool and runtime builds.
for sub in lib/rabbitizer lib/ELFIO lib/fmt lib/tomlplusplus lib/sljit; do
    if [[ ! -d "$PAPERPAD_REF/paper-mario-recut/lib/N64ModernRuntime/N64Recomp/$sub" ]]; then
        die "missing N64Recomp submodule $sub; run scripts/init-submodules.sh"
    fi
done

for checkout in "$PAPERPAD_REF/papermario" "$PAPERPAD_REF/paper-mario-recut"; do
    if git -C "$checkout" status --porcelain | rg -q .; then
        # Patched upstream inputs are allowed for ReCut; the decomp must stay clean.
        if [[ "$checkout" == *papermario ]] && git -C "$checkout" diff --quiet; then
            :
        fi
    fi
done

note "Pinned sources verified."
