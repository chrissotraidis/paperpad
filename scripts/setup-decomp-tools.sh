#!/usr/bin/env bash
# One-time host toolchain setup for the pmret decomp build.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

decomp="$PAPERPAD_REF/papermario"
[[ -d "$decomp/.git" ]] || die "papermario checkout missing at $decomp"

if [[ ! -d "$decomp/.venv" ]]; then
    python3 -m venv "$decomp/.venv"
    "$decomp/.venv/bin/pip" install -q --upgrade pip
    "$decomp/.venv/bin/pip" install -r "$decomp/tools/configure/requirements.txt"
fi

export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v pigment64 >/dev/null || ! command -v crunch64 >/dev/null; then
    cargo install pigment64 crunch64-cli --locked
fi

if [[ ! -x /opt/homebrew/bin/cpp-16 ]]; then
    brew install gcc
fi
command -v mips-linux-gnu-as >/dev/null || brew install bates64/brew/mips-linux-gnu-binutils

if [[ ! -x "$decomp/tools/build/cc/gcc/gcc" ]]; then
    (cd "$decomp" && ./install_compilers.sh)
fi

note "Decomp host tools ready."
