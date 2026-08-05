#!/usr/bin/env bash
# Verify host tools required for PaperPad builds.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

for command in git jq cmake ninja python3 cargo xcrun shasum md5; do
    require_command "$command"
done

[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon is required"
command -v mips-linux-gnu-as >/dev/null || die "mips-linux-gnu-binutils is missing (brew install bates64/brew/mips-linux-gnu-binutils)"
[[ -x /opt/homebrew/bin/cpp-16 ]] || die "GNU cpp is missing (brew install gcc)"
[[ -d "$PAPERPAD_REF/papermario/.venv" ]] || die "decomp venv missing; run scripts/setup-decomp-tools.sh"

note "Host prerequisites OK (Apple Silicon, Xcode $(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}'))."
