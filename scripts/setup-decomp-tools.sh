#!/usr/bin/env bash
# One-time host toolchain setup for the pmret decomp build.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

decomp="$PAPERPAD_REF/papermario"
[[ -d "$decomp/.git" ]] || die "papermario checkout missing at $decomp"

decomp_python=${PAPERPAD_PYTHON:-}
if [[ -z "$decomp_python" && -x /opt/homebrew/bin/python3.11 ]]; then
    decomp_python=/opt/homebrew/bin/python3.11
elif [[ -z "$decomp_python" ]]; then
    decomp_python=$(command -v python3 || true)
fi
[[ -n "$decomp_python" ]] || die "Python 3.11 or newer is required"
"$decomp_python" -c 'import sys; raise SystemExit(sys.version_info < (3, 11))' || \
    die "Python 3.11 or newer is required (found $($decomp_python --version))"

if [[ ! -d "$decomp/.venv" ]]; then
    "$decomp_python" -m venv "$decomp/.venv"
    "$decomp/.venv/bin/pip" install -q --upgrade pip
    "$decomp/.venv/bin/pip" install -r "$decomp/tools/configure/requirements.txt"
fi

export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v pigment64 >/dev/null || ! command -v crunch64 >/dev/null; then
    rust_version=$(rustc --version | awk '{print $2}')
    if [[ "$(printf '%s\n' 1.85.0 "$rust_version" | sort -V | head -1)" != "1.85.0" ]]; then
        if command -v rustup >/dev/null; then
            rustup update stable
        else
            die "Rust 1.85 or newer is required; update Rust before continuing"
        fi
    fi
    cargo install pigment64 crunch64-cli --locked
fi

if [[ ! -x /opt/homebrew/bin/cpp-16 ]]; then
    brew install gcc
fi
local_binutils="$PAPERPAD_ROOT/build-tools/mips-binutils-2.46.1/bin"
if ! command -v mips-linux-gnu-as >/dev/null && [[ ! -x "$local_binutils/mips-linux-gnu-as" ]]; then
    "$script_dir/build-mips-binutils.sh"
fi
if [[ -d "$local_binutils" ]]; then
    export PATH="$local_binutils:$PATH"
fi
require_command mips-linux-gnu-as

if [[ ! -x "$decomp/tools/build/cc/gcc/gcc" ]]; then
    (cd "$decomp" && ./install_compilers.sh)
fi

note "Decomp host tools ready."
