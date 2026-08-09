#!/usr/bin/env bash
set -euo pipefail

PAPERPAD_AUDIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAPERPAD_AUDIT_ROOT"

fail() {
    echo "Repository safety check failed: $*" >&2
    exit 1
}

current_files="$(git ls-files --cached --others --exclude-standard | sort -u)"

tracked_ref_files="$(printf '%s\n' "$current_files" | grep '^ref/' || true)"
if [[ -n "$tracked_ref_files" ]]; then
    printf '%s\n' "$tracked_ref_files" >&2
    fail "ref/ contains publishable files"
fi

forbidden='(^|/)(generated|build-tools)(/|$)|\.(z64|n64|v64|rom|elf|ipa|xcarchive|mobileprovision|provisionprofile|p12|p8|pem|key)(/|$)|(^|/)[^/]+\.app/'
forbidden_files="$(printf '%s\n' "$current_files" | grep -Ei "$forbidden" || true)"
if [[ -n "$forbidden_files" ]]; then
    printf '%s\n' "$forbidden_files" >&2
    fail "game data, generated output, package, or signing material is publishable"
fi

if git rev-parse --verify HEAD >/dev/null 2>&1; then
    # Only refs Git can publish are audited. Local editor/Codex snapshots are
    # not remote branches, tags, or remotes and may record ignored research.
    history_paths="$(git rev-list --objects --branches --tags --remotes |
        awk 'NF > 1 { sub(/^[^ ]+ /, ""); print }')"
    forbidden_history="$(printf '%s\n' "$history_paths" | grep -Ei "$forbidden" || true)"
    history_ref="$(printf '%s\n' "$history_paths" | grep '^ref/' || true)"
    if [[ -n "$forbidden_history" || -n "$history_ref" ]]; then
        printf '%s\n%s\n' "$forbidden_history" "$history_ref" >&2
        fail "prohibited material exists in publishable Git history"
    fi
fi

while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    size="$(wc -c < "$file")"
    if [[ "$size" -gt 5242880 ]]; then
        echo "$file ($size bytes)" >&2
        fail "publishable file exceeds the 5 MiB review limit"
    fi
done < <(printf '%s\n' "$current_files")

credential_pattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})'
while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    if grep -nEI "$credential_pattern" "$file" >/dev/null 2>&1; then
        echo "$file" >&2
        fail "a likely credential or private key exists in the publishable tree"
    fi
done < <(printf '%s\n' "$current_files")

bash -n scripts/*.sh
for script in scripts/*.sh; do
    [[ -x "$script" ]] || fail "$script is not executable"
done

git fsck --full --strict --no-dangling
echo "Repository safety checks passed."
