#!/usr/bin/env bash
# Build the pmret decomp ELF from the normalized ROM.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

decomp="$PAPERPAD_REF/papermario"
baserom="$PAPERPAD_GENERATED/rom/baserom.z64"
elf="$decomp/ver/us/build/papermario.elf"
rebuilt="$decomp/ver/us/build/papermario.z64"

[[ -f "$baserom" ]] || die "normalized ROM missing; run scripts/prepare-rom.sh --rom ..."
[[ -d "$decomp/.venv" ]] || die "decomp venv missing; run scripts/setup-decomp-tools.sh"

mkdir -p "$PAPERPAD_LOGS"
log="$PAPERPAD_LOGS/decomp-build.log"

if [[ ! -f "$decomp/ver/us/baserom.z64" ]]; then
    cp "$baserom" "$decomp/ver/us/baserom.z64"
    chmod 600 "$decomp/ver/us/baserom.z64"
fi

if [[ ! -f "$decomp/build.ninja" ]]; then
    (cd "$decomp" && PATH="$decomp/.venv/bin:$HOME/.cargo/bin:$PATH" ./configure --cpp cpp-16) 2>&1 | tee "$log"
fi

if [[ -f "$elf" && -f "$rebuilt" ]]; then
    note "Reusing built decomp ELF: ${elf#"$PAPERPAD_ROOT/"}"
    exit 0
fi

(cd "$decomp" && PATH="$decomp/.venv/bin:$HOME/.cargo/bin:$PATH" ninja) 2>&1 | tee -a "$log"
[[ -f "$elf" ]] || die "decomp build did not produce $elf"
[[ -f "$rebuilt" ]] || die "decomp build did not produce $rebuilt"

expected_sha=$(jq -er '.rom.sha1' "$PAPERPAD_LOCK")
actual_sha=$(shasum -a 1 "$rebuilt" | awk '{print $1}')
[[ "$actual_sha" == "$expected_sha" ]] || \
    die "rebuilt ROM mismatch: expected $expected_sha, found $actual_sha"

note "Decomp ELF ready: ${elf#"$PAPERPAD_ROOT/"} (matching ROM sha1 verified)"
