#!/usr/bin/env bash
# Normalize the user Paper Mario ROM into generated/rom/baserom.z64.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

usage() {
    printf 'usage: %s --rom /absolute/path/to/user-rom\n' "$(basename "$0")" >&2
    exit 64
}

rom_path=
while (($#)); do
    case "$1" in
        --rom) (($# >= 2)) || usage; rom_path=$2; shift 2 ;;
        *) usage ;;
    esac
done
[[ -n "$rom_path" ]] || usage
[[ "$rom_path" = /* ]] || die "ROM path must be absolute"
[[ -f "$rom_path" ]] || die "ROM file not found: $rom_path"

require_command python3
require_command shasum

expected_size=$(jq -er '.rom.size' "$PAPERPAD_LOCK")
expected_sha=$(jq -er '.rom.sha1' "$PAPERPAD_LOCK")
rom_work="$PAPERPAD_GENERATED/rom"
normalized="$rom_work/baserom.z64"
mkdir -p "$rom_work"
temporary=$(mktemp "$rom_work/.baserom.XXXXXX")
trap 'rm -f "$temporary"' EXIT

python3 - "$rom_path" "$temporary" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
with source.open("rb") as incoming:
    magic = incoming.read(4)
if magic == bytes.fromhex("80371240"):
    order = "z64"
elif magic == bytes.fromhex("37804012"):
    order = "v64"
elif magic == bytes.fromhex("40123780"):
    order = "n64"
else:
    raise SystemExit("error: unrecognized N64 ROM byte order")

with source.open("rb") as incoming, destination.open("wb") as outgoing:
    while chunk := incoming.read(1024 * 1024):
        if order == "v64":
            if len(chunk) % 2:
                raise SystemExit("error: odd-length v64 input")
            data = bytearray(chunk)
            data[0::2], data[1::2] = chunk[1::2], chunk[0::2]
            chunk = data
        elif order == "n64":
            if len(chunk) % 4:
                raise SystemExit("error: non-word-aligned n64 input")
            data = bytearray(chunk)
            for offset in range(0, len(data), 4):
                data[offset:offset + 4] = data[offset:offset + 4][::-1]
            chunk = data
        outgoing.write(chunk)
print(order)
PY

actual_size=$(stat -f '%z' "$temporary")
actual_sha=$(shasum -a 1 "$temporary" | awk '{print $1}')
[[ "$actual_size" == "$expected_size" ]] || \
    die "unsupported ROM size: expected $expected_size, found $actual_size"
[[ "$actual_sha" == "$expected_sha" ]] || \
    die "unsupported ROM revision: normalized sha1 $actual_sha (expected $expected_sha)"

mv -f "$temporary" "$normalized"
trap - EXIT
chmod 600 "$normalized"
note "Normalized ROM ready at ${normalized#"$PAPERPAD_ROOT/"} (z64 sha1 $actual_sha)."
