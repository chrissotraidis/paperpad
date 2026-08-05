#!/usr/bin/env bash
# Initialize the vendored N64Recomp submodules inside ReCut.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

require_command git
recut="$PAPERPAD_REF/paper-mario-recut"
n64recomp="$recut/lib/N64ModernRuntime/N64Recomp"

required_n64recomp_submodules=(lib/ELFIO lib/fmt lib/rabbitizer lib/sljit lib/tomlplusplus)
git -C "$n64recomp" submodule sync -- "${required_n64recomp_submodules[@]}"
git -C "$n64recomp" submodule update --init --depth=1 "${required_n64recomp_submodules[@]}"

disable_push "$n64recomp"
git -C "$n64recomp" submodule foreach --quiet --recursive \
    'if git remote get-url origin >/dev/null 2>&1; then git remote set-url --push origin DISABLED; fi'

note "N64Recomp submodules ready."
