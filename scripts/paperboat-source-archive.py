#!/usr/bin/env python3
"""Export the exact Boat sources, prepared dependencies and pinned downloads."""
import argparse, gzip, hashlib, json, os, shutil, subprocess, tarfile, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def git(root, *args, **kwargs):
    return subprocess.check_output(['git', '-C', str(root), *args], **kwargs)

def identity(path):
    if path.is_symlink(): return {'link': os.readlink(path)}
    return {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'mode': path.stat().st_mode & 0o777}

def verify(root):
    manifest = json.loads((root/'SOURCE_MANIFEST.json').read_text())
    for rel, expected in manifest['files'].items():
        path = root/rel
        if not path.is_relative_to(root) or '..' in Path(rel).parts:
            raise SystemExit('Unsafe manifest path')
        if not path.exists() and not path.is_symlink(): raise SystemExit('Missing source: '+rel)
        if identity(path) != expected: raise SystemExit('Changed source: '+rel)
    print(f"Verified {len(manifest['files'])} source/metadata files and {len(manifest['repositories'])} exact Git snapshots.")

def snapshot(source, commit, destination):
    # Copy only this public commit and its tree, never unrelated local history,
    # remotes, working files, hooks, credentials or ignored private inputs.
    objects = git(source, 'rev-list', '--objects', '--no-object-names', commit+'^{tree}')
    packed = git(source, 'pack-objects', '--stdout', input=commit.encode()+b'\n'+objects)
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run(['git','init','-q',str(destination)],check=True)
    subprocess.run(['git','-C',str(destination),'index-pack','--stdin'],input=packed,check=True,stdout=subprocess.DEVNULL)
    (destination/'.git/shallow').write_text(commit+'\n')
    branch = git(source, 'rev-parse', '--abbrev-ref', 'HEAD', text=True).strip()
    if branch == 'HEAD':
        (destination/'.git/HEAD').write_text(commit+'\n')
    else:
        git(destination, 'symbolic-ref', 'HEAD', 'refs/heads/'+branch)
        git(destination, 'update-ref', 'HEAD', commit)
    git(destination, 'read-tree', '--reset', '-u', commit)

def create(output):
    build = ROOT/'build-paperboat-ios'
    subprocess.run(['python3',str(ROOT/'scripts/verify-paperboat.py'),'--build-dir',str(build)],check=True)
    if git(ROOT,'status','--porcelain').strip(): raise SystemExit('Commit source before export')
    lock = json.loads((ROOT/'paperboat.lock.json').read_text())
    commit = git(ROOT,'rev-parse','HEAD',text=True).strip()
    repos = {'': {'commit':commit}}
    repos.update(lock['sources'])
    repos.update({'build-paperboat-ios/_deps/'+name+'-src': spec for name,spec in lock['buildDependencies'].items()})
    with tempfile.TemporaryDirectory(prefix='paperpad-source-') as tmp:
        stage = Path(tmp)/'PaperPad-source'
        for rel,spec in repos.items():
            snapshot(ROOT/rel,spec['commit'],stage/rel)
            for file,expected in spec.get('preparedFiles',{}).items():
                target = stage/rel/file
                if expected.get('absent'): target.unlink()
                else: shutil.copy2(ROOT/rel/file,target)
        for rel in lock['fetchedFiles']:
            dest = stage/'build-paperboat-ios'/rel
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(build/rel,dest)
        with (stage/'.git/info/exclude').open('a') as f: f.write('\n/SOURCE_MANIFEST.json\n')
        files = {str(p.relative_to(stage)):identity(p) for p in sorted(stage.rglob('*')) if p.is_file() or p.is_symlink()}
        manifest = {'applicationCommit':commit,'repositories':repos,'files':files,
                    'scope':'PaperBoat target only; Original nested runtime is not included. No ROM, game archive, saves, signing inputs, SDK or build products.'}
        (stage/'SOURCE_MANIFEST.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n')
        verify(stage)
        output.parent.mkdir(parents=True,exist_ok=True)
        with output.open('wb') as raw, gzip.GzipFile(fileobj=raw,mode='wb',filename='',mtime=0) as compressed:
            with tarfile.open(fileobj=compressed,mode='w') as archive:
                for p in [stage,*sorted(stage.rglob('*'))]:
                    info = archive.gettarinfo(str(p),arcname=str(p.relative_to(stage.parent)))
                    info.uid=info.gid=info.mtime=0;info.uname=info.gname=''
                    if info.isfile():
                        with p.open('rb') as stream: archive.addfile(info,stream)
                    else: archive.addfile(info)
        print('Source archive:',output)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--output',type=Path);group.add_argument('--verify',type=Path)
    args=parser.parse_args()
    if args.verify: verify(args.verify.resolve())
    else: create(args.output.resolve())
