#!/usr/bin/env bash
# Generate Paper Mario AOT sources from the user's validated local ROM.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

host_tools="$PAPERPAD_ROOT/build-host-tools"
rom="$PAPERPAD_GENERATED/rom/baserom.z64"
elf="$PAPERPAD_REF/papermario/ver/us/build/papermario.elf"
recomp_config="$PAPERPAD_GENERATED/aot/paper-mario-us.toml"
audio_rsp_config="$PAPERPAD_ROOT/config/paper-mario-audio-rsp.toml"

[[ -f "$rom" ]] || die "normalized ROM missing; run scripts/prepare-rom.sh --rom ..."
[[ -f "$elf" ]] || die "decomp ELF missing; run scripts/build-decomp.sh"
[[ -x "$host_tools/N64Recomp" ]] || die "N64Recomp is missing; run scripts/build-host-tools.sh"
[[ -x "$host_tools/RSPRecomp" ]] || die "RSPRecomp is missing; run scripts/build-host-tools.sh"

local_binutils="$PAPERPAD_ROOT/build-tools/mips-binutils-2.46.1/bin"
if [[ -d "$local_binutils" ]]; then
    export PATH="$local_binutils:$PATH"
fi

"$PAPERPAD_ROOT/ref/papermario/.venv/bin/python" \
    "$script_dir/generate-n64recomp-config.py"
"$host_tools/N64Recomp" "$recomp_config"
mkdir -p "$PAPERPAD_GENERATED/aot/rsp"
"$host_tools/RSPRecomp" "$audio_rsp_config"

[[ -f "$PAPERPAD_GENERATED/aot/paper_mario_recomp_out/lookup.cpp" ]] || \
    die "N64Recomp did not produce lookup.cpp"
[[ -f "$PAPERPAD_GENERATED/aot/rsp/n_aspMain.cpp" ]] || \
    die "RSPRecomp did not produce n_aspMain.cpp"
note "Paper Mario game and audio-RSP sources are ready under generated/aot/."
