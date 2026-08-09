#!/usr/bin/env bash
# Build a current local MIPS binutils when the old Homebrew tap cannot build.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib/common.sh"

require_command curl
require_command make
require_command shasum
require_command tar

version=2.46.1
tools_root="$PAPERPAD_ROOT/build-tools"
prefix="$tools_root/mips-binutils-$version"
archive="$tools_root/downloads/binutils-$version.tar.xz"
checksums="$tools_root/downloads/binutils-sha512.sum"
source_dir="$tools_root/binutils-$version"
build_dir="$tools_root/mips-binutils-$version-build"

if [[ -x "$prefix/bin/mips-linux-gnu-as" ]]; then
    note "Local MIPS binutils already ready: $prefix"
    exit 0
fi

mkdir -p "$tools_root/downloads" "$build_dir"
curl -L --fail --retry 3 -o "$archive" \
    "https://sourceware.org/pub/binutils/releases/binutils-$version.tar.xz"
curl -L --fail --retry 3 -o "$checksums" \
    "https://sourceware.org/pub/binutils/releases/sha512.sum"

expected=$(awk -v file="binutils-$version.tar.xz" '$2 == file { print $1 }' "$checksums")
actual=$(shasum -a 512 "$archive" | awk '{ print $1 }')
[[ -n "$expected" && "$actual" == "$expected" ]] || die "GNU binutils checksum mismatch"

if [[ ! -x "$source_dir/configure" ]]; then
    tar -xf "$archive" -C "$tools_root"
fi
if [[ ! -f "$build_dir/Makefile" ]]; then
    (cd "$build_dir" && "$source_dir/configure" \
        --prefix="$prefix" --target=mips-linux-gnu \
        --disable-gdb --disable-gprof --disable-nls --disable-werror \
        --without-zstd --without-debuginfod)
fi

build_jobs=$(configured_build_jobs)
make -C "$build_dir" ${build_jobs:+-j"$build_jobs"}
make -C "$build_dir" install
[[ -x "$prefix/bin/mips-linux-gnu-as" ]] || die "local MIPS assembler was not produced"
note "Local MIPS binutils ready: $prefix"
