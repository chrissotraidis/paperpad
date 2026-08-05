#!/usr/bin/env bash

set -euo pipefail

PAPERPAD_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
PAPERPAD_LOCK="$PAPERPAD_ROOT/dependencies.lock.json"
PAPERPAD_REF="$PAPERPAD_ROOT/ref"
PAPERPAD_GENERATED="$PAPERPAD_ROOT/generated"
PAPERPAD_LOGS="$PAPERPAD_ROOT/logs"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '%s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

configured_build_jobs() {
    local build_jobs=${PAPERPAD_BUILD_JOBS:-}
    if [[ -n "$build_jobs" ]]; then
        [[ "$build_jobs" =~ ^[1-9][0-9]*$ ]] || \
            die "PAPERPAD_BUILD_JOBS must be a positive integer"
    fi
    printf '%s\n' "$build_jobs"
}

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

lock_value() {
    local source_name=$1
    local field=$2
    jq -er --arg name "$source_name" --arg field "$field" \
        '.sources[$name][$field]' "$PAPERPAD_LOCK"
}

assert_revision() {
    local checkout=$1
    local expected=$2
    local label=$3
    [[ -d "$checkout/.git" || -f "$checkout/.git" ]] || die "missing checkout for $label: $checkout"
    local actual
    actual=$(git -C "$checkout" rev-parse HEAD)
    [[ "$actual" == "$expected" ]] || die "$label revision mismatch: expected $expected, found $actual"
}

disable_push() {
    local checkout=$1
    if git -C "$checkout" remote get-url origin >/dev/null 2>&1; then
        git -C "$checkout" remote set-url --push origin DISABLED
    fi
}

mkdir_p_dirs() {
    mkdir -p "$PAPERPAD_GENERATED" "$PAPERPAD_LOGS"
}
