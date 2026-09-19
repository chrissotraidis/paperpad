#!/usr/bin/env bash
# Compatibility entry point. Production sources are already maintained; never rewrite them.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/verify-sources.sh"
echo "No patches applied: PaperPad consumes pinned maintained source."
