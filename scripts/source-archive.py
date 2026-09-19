#!/usr/bin/env python3
"""Create or verify a source-only archive; never collect ignored/private working files."""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {'papermario': 'ref/papermario', 'paperMarioReCut': 'vendor/paper-mario-recut',
           'mupen64plusRspHle': 'ref/mupen64plus-rsp-hle', 'sdl2': 'ref/SDL2', 'zstd': 'ref/zstd'}

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args]).decode().strip()

def entry(path):
    if path.is_symlink():
        return {'type': 'symlink', 'target': os.readlink(path)}
    return {'type': 'file', 'mode': stat.S_IMODE(path.stat().st_mode),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def verify(root):
    doc = json.loads((root / 'SOURCE_MANIFEST.json').read_text())
    for name, value in doc['files'].items():
        p = root / name
        if not p.exists() and not p.is_symlink():
            raise SystemExit(f'Missing archive source: {name}')
        if entry(p) != value:
            raise SystemExit(f'Changed archive source: {name}')
    lock = json.loads((root / 'dependencies.lock.json').read_text())
    for key, sha in doc['sources'].items():
        if lock['sources'][key]['commit'] != sha:
            raise SystemExit(f'Archive source pin mismatch: {key}')
    print(f"Source archive verified: {len(doc['files'])} files; all five dependency trees present.")

def create(output):
    subprocess.run([str(ROOT / 'scripts/verify-sources.sh')], check=True)
    if git(ROOT, 'status', '--porcelain', '--untracked-files=all'):
        raise SystemExit('Commit intended application changes before exporting source.')
    lock = json.loads((ROOT / 'dependencies.lock.json').read_text())
    with tempfile.TemporaryDirectory(prefix='paperpad-source-') as tmp:
        stage = Path(tmp) / 'PaperPad-source'
        stage.mkdir()
        for path, commit, prefix in [(ROOT, 'HEAD', '')] + [
                (ROOT / rel, lock['sources'][key]['commit'], rel) for key, rel in SOURCES.items()]:
            data = subprocess.check_output(['git', '-C', str(path), 'archive', commit])
            destination = stage / prefix
            destination.mkdir(parents=True, exist_ok=True)
            with tarfile.open(fileobj=io.BytesIO(data)) as archive:
                # Git-created archives only; validate paths and links for Python
                # versions predating tarfile's data_filter API.
                boundary = destination.resolve()
                for member in archive.getmembers():
                    target = (destination / member.name).resolve()
                    if not target.is_relative_to(boundary):
                        raise SystemExit(f'Unsafe source archive path: {member.name}')
                    if member.issym() and not (target.parent / member.linkname).resolve().is_relative_to(boundary):
                        raise SystemExit(f'Unsafe source symlink: {member.name}')
                    if not (member.isfile() or member.isdir() or member.issym()):
                        raise SystemExit(f'Unexpected source entry: {member.name}')
                    archive.extract(member, destination)
                    if member.isfile():
                        # Git stores executable intent, not group-write umask.
                        target.chmod(0o755 if member.mode & 0o111 else 0o644)
        files = {str(p.relative_to(stage)): entry(p) for p in sorted(stage.rglob('*'))
                 if p.is_file() or p.is_symlink()}
        doc = {'schemaVersion': 1, 'applicationCommit': git(ROOT, 'rev-parse', 'HEAD'),
               'sources': {key: lock['sources'][key]['commit'] for key in SOURCES},
               'boundary': 'Source-only. No ROM, generated game code, saves, signing material or Apple SDK. '
                           'Not a claim that game-source rights or complete corresponding-source delivery is resolved.',
               'files': files}
        (stage / 'SOURCE_MANIFEST.json').write_text(json.dumps(doc, sort_keys=True, indent=2) + '\n')
        verify(stage)
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode='w') as archive:
                for p in [stage, *sorted(stage.rglob('*'))]:
                    info = archive.gettarinfo(str(p), arcname=str(p.relative_to(stage.parent)))
                    info.uid = info.gid = info.mtime = 0
                    info.uname = info.gname = ''
                    if info.isfile():
                        with p.open('rb') as stream:
                            archive.addfile(info, stream)
                    else:
                        archive.addfile(info)
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        output.with_name(output.name + '.sha256').write_text(f'{digest}  {output.name}\n')
        print(f'{digest}  {output}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if bool(args.verify) == bool(args.output):
        parser.error('choose --verify ROOT or --output ARCHIVE.tar.gz')
    if args.verify:
        verify(args.verify.resolve())
    else:
        create(args.output.resolve())
