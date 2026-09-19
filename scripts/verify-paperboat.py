#!/usr/bin/env python3
"""Verify the PaperBoat product's immutable engine and recursive source pins."""
import json, os, subprocess, argparse, hashlib, stat
from pathlib import Path
root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'paperboat.lock.json').read_text())
def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()
for path, source in lock['sources'].items():
    folder = root / path
    if git(folder, 'rev-parse', 'HEAD') != source['commit']:
        raise SystemExit(f'Source pin mismatch: {path}')
    if not os.environ.get('PAPERPAD_ALLOW_DIRTY') and git(folder, 'status', '--porcelain', '--untracked-files=all'):
        raise SystemExit(f'Dirty source: {path}; commit it, or explicitly use PAPERPAD_ALLOW_DIRTY=1 for development.')
selected = git(root, 'ls-files', '--stage', 'vendor/paperboat').split()[1]
if selected != lock['sources']['vendor/paperboat']['commit']:
    raise SystemExit('PaperBoat gitlink and lock disagree')
print('PaperBoat engine and recursive source pins verified.')

parser = argparse.ArgumentParser()
parser.add_argument('--build-dir', type=Path)
args = parser.parse_args()
if args.build_dir:
    for name, source in lock['buildDependencies'].items():
        folder = args.build_dir / '_deps' / (name + '-src')
        if git(folder, 'rev-parse', 'HEAD') != source['commit']:
            raise SystemExit(f'Fetched dependency pin mismatch: {name}')
        prepared = source.get('preparedFiles', {})
        changed = git(folder, 'diff', '--name-only', 'HEAD').splitlines()
        if set(changed) != set(prepared) or git(folder, 'ls-files', '--others', '--exclude-standard'):
            raise SystemExit(f'Unexpected fetched-source changes: {name}')
        for file, expected in prepared.items():
            path = folder / file
            actual = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'mode': stat.S_IMODE(path.stat().st_mode)} if path.exists() else {'absent': True}
            if actual != expected:
                raise SystemExit(f'Prepared dependency differs: {name}/{file}')
    for path, digest in lock['fetchedFiles'].items():
        if hashlib.sha256((args.build_dir / path).read_bytes()).hexdigest() != digest:
            raise SystemExit(f'Fetched file hash mismatch: {path}')
    print(f"All {len(lock['buildDependencies'])} fetched dependency commits and {len(lock['fetchedFiles'])} downloaded file hashes verified.")
