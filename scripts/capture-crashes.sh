#!/usr/bin/env bash
# PaperPad crash-log capture.
#
# macOS and iOS Simulator crashes are written by the OS to
# ~/Library/Logs/DiagnosticReports/PaperPad-*.ips (unified .ips format).
# This script archives any reports newer than the last capture into
# logs/crashes/ (gitignored) and prints a compact summary so failures can be
# diagnosed from evidence. Run after any launch/playtest that crashed.
#
# Usage: scripts/capture-crashes.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$HOME/Library/Logs/DiagnosticReports"
DEST_DIR="$REPO_ROOT/logs/crashes"
MARKER="$DEST_DIR/.last-capture"

mkdir -p "$DEST_DIR"

# On first run there is no marker, so every existing report is new.
LAST=""
[[ -f "$MARKER" ]] && LAST="$(cat "$MARKER")"
COPIED=0

while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    base="$(basename "$f")"
    ts="$(stat -f '%Sm' -t '%Y%m%dT%H%M%SZ' "$f")"
    # Archive any report newer than the marker (lexicographic ISO sort works);
    # with no marker everything qualifies.
    if [[ -z "$LAST" || "$ts" > "$LAST" ]]; then
        cp -p "$f" "$DEST_DIR/$base"
        echo "captured: $base"
        # Compact one-line summary: exception type + crashed thread from the .ips JSON.
        python3 - "$f" <<'PY'
import json, sys
try:
    # .ips files are JSONL: a metadata header line, then the crash payload.
    with open(sys.argv[1]) as fh:
        lines = [ln for ln in fh if ln.strip()]
    data = json.loads("\n".join(lines[1:]))
    body = data.get("body", data)  # payload fields are top-level (or nested under "body")
    exc = body.get("exception", {}) or {}
    faults = body.get("faultingThread", 0) or 0
    term = body.get("termination", {}) or {}
    # Include the crashed thread's first frames for quick triage.
    stack = ""
    threads = body.get("threads") or []
    for t in threads:
        if t.get("triggered") or t.get("id") == faults:
            imgs = body.get("usedImages") or []
            frames = [f for f in (t.get("frames") or []) if f.get("symbol")]
            names = []
            for fr in frames[:6]:
                img = fr.get("imageIndex")
                iname = imgs[img].get("name", "?") if isinstance(img, int) and img < len(imgs) else "?"
                names.append(f"{iname}:{fr.get('symbol')}")
            stack = "  stack=" + " <- ".join(names)
            break
    print(f"  exception={exc.get('type','?')} signal={exc.get('signal','?')} faultingThread={faults} termination={term.get('indicator','')} ({data.get('bundleID','?')} {data.get('appVersion','?')})")
    if stack:
        print(stack)
except Exception as e:
    print(f"  (could not parse .ips: {e})")
PY
        COPIED=$((COPIED + 1))
    fi
done < <(find "$SRC_DIR" -maxdepth 1 -name 'PaperPad-*.ips' -print 2>/dev/null)

date -u +%Y%m%dT%H%M%SZ > "$MARKER"

if [[ "$COPIED" -eq 0 ]]; then
    echo "No new PaperPad crash reports since last capture."
else
    echo "Archived $COPIED crash report(s) into logs/crashes/"
fi
