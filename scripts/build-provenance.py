#!/usr/bin/env python3
"""Record public source identities without user paths, ROMs or signing identity."""
import json
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'dependencies.lock.json').read_text())
if (root / 'SOURCE_MANIFEST.json').exists():
    commit = json.loads((root / 'SOURCE_MANIFEST.json').read_text())['applicationCommit']
else:
    commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    if subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain'], text=True).strip():
        raise SystemExit('Package provenance requires a clean committed application tree.')
doc = {'schemaVersion': 1, 'applicationCommit': commit, 'dependencies': lock['sources'],
       'profile': 'PaperPad 0.1.0 build 2 source-maintenance validation; no engine upgrade',
       'sourceBoundary': 'Private ROM and generated game output excluded. See RIGHTS_AND_LICENSES.md.'}
Path(sys.argv[1]).write_text(json.dumps(doc, indent=2) + '\n')
