#!/usr/bin/env bash
# Verify host tools required for PaperPad builds.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

for command in git jq cmake ninja python3 cargo xcrun shasum md5; do
    require_command "$command"
done

[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon is required"
local_binutils="$PAPERPAD_ROOT/build-tools/mips-binutils-2.46.1/bin"
if [[ -d "$local_binutils" ]]; then
    export PATH="$local_binutils:$PATH"
fi
command -v mips-linux-gnu-as >/dev/null || \
    die "MIPS binutils is missing (run scripts/build-mips-binutils.sh)"
[[ -x /opt/homebrew/bin/cpp-16 ]] || die "GNU cpp is missing (brew install gcc)"
[[ -d "$PAPERPAD_REF/papermario/.venv" ]] || die "decomp venv missing; run scripts/setup-decomp-tools.sh"
"$PAPERPAD_REF/papermario/.venv/bin/python" -c \
    'import sys; raise SystemExit(sys.version_info < (3, 11))' || \
    die "decomp venv must use Python 3.11 or newer; recreate it with scripts/setup-decomp-tools.sh"

note "Host prerequisites OK (Apple Silicon, Xcode $(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}'))."
