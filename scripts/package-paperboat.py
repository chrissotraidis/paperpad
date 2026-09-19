#!/usr/bin/env python3
"""Create a private, unsigned PaperPad Boat candidate. Does not publish anything."""
import hashlib,json,os,plistlib,re,shutil,subprocess,sys,tempfile,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];build=root/'build-paperboat-ios'
output=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'artifacts/PaperPad.ipa'
subprocess.run(['python3',str(root/'scripts/verify-paperboat.py'),'--build-dir',str(build)],check=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((build/'PAPERPAD_BUILD.json').read_text())
if record['dirty'] or subprocess.check_output(['git','-C',str(root),'status','--porcelain'],text=True).strip():
    raise SystemExit('Packaging requires a clean recorded build and checkout.')
if record['applicationCommit']!=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip():
    raise SystemExit('Build commit differs; rebuild this clean commit.')
for p,digest in record['shellInputs'].items():
    if sha(root/p)!=digest:raise SystemExit(f'Built shell input changed: {p}')
if sha(build/'Paperboat.app/Paperboat')!=record['executableSHA256']:raise SystemExit('Built executable changed.')
with tempfile.TemporaryDirectory(prefix='paperpad-boat-package-') as tmp:
    stage=Path(tmp);app=stage/'Payload/PaperPad.app';app.parent.mkdir()
    shutil.copytree(build/'Paperboat.app',app)
    subprocess.run(['codesign','--remove-signature',str(app)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    shutil.rmtree(app/'_CodeSignature',ignore_errors=True)
    (app/'embedded.mobileprovision').unlink(missing_ok=True)
    (app/'BUILD_PROVENANCE.json').write_text(json.dumps(record,indent=2)+'\n')
    shutil.copy(root/'apple/paperboat/ThirdPartyNotices.txt',app/'ThirdPartyNotices.txt')
    roots={p:root/p for p in record['sources']['sources']}
    roots.update({f'fetched/{name}':build/'_deps'/(name+'-src') for name in record['sources']['buildDependencies']})
    for label,source in roots.items():
        files=subprocess.check_output(['git','-C',str(source),'ls-files'],text=True).splitlines()
        for file in files:
            p=source/file
            if p.is_file() and re.match(r'(?i)^(licen[cs]e|copying|notice|copyright|third.party.notices|ofl|unlicense)',p.name):
                dest=app/'Licenses'/label/file;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
    info=plistlib.loads((app/'Info.plist').read_bytes())
    assert info['CFBundleIdentifier']=='com.chrissotraidis.paperpad.boat'
    assert info['CFBundleShortVersionString']=='0.2.0' and info['CFBundleVersion']=='6'
    assert info['CFBundleDisplayName']=='PaperPad' and info['CFBundleName']=='PaperPad'
    assert info['MinimumOSVersion']=='16.3'
    assert info.get('UIDeviceFamily')==[1,2], 'Boat must declare native iPhone and iPad support'
    assert info.get('UIRequiresFullScreen') is True
    assert set(info.get('UISupportedInterfaceOrientations~ipad', []))=={'UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
    assert subprocess.check_output(['lipo','-archs',str(app/'Paperboat')],text=True).strip()=='arm64'
    platform=subprocess.check_output(['xcrun','vtool','-show-build',str(app/'Paperboat')],text=True)
    assert re.search(r'platform\s+IOS\s',platform) and re.search(r'minos\s+16\.3\s',platform)
    dependencies=subprocess.check_output(['otool','-L',str(app/'Paperboat')],text=True).splitlines()[1:]
    assert all(line.strip().startswith(('/System/Library/','/usr/lib/')) for line in dependencies)
    for p in app.rglob('*'):
        assert not p.is_symlink(),f'Unexpected link: {p.name}'
        assert p.name!='pm64.o2r' and p.suffix.lower() not in {'.z64','.v64','.n64','.sav','.fla','.srm','.mobileprovision','.p12','.key'}
    strings=subprocess.check_output(['strings','-a',str(app/'Paperboat')])
    assert b'/Users/' not in strings and b'/private/var/folders/' not in strings,'Private build path in executable'
    assert not (app/'_CodeSignature').exists()
    assert (app/'paperboat.o2r').exists() and (app/'gamecontrollerdb.txt').exists()
    assert len(list((app/'Licenses').rglob('*')))>10
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
        for p in sorted(stage.rglob('*')):
            if p.is_file():
                zi=zipfile.ZipInfo(str(p.relative_to(stage)),(2020,1,1,0,0,0));zi.external_attr=(p.stat().st_mode&0xFFFF)<<16;zi.compress_type=zipfile.ZIP_DEFLATED
                archive.writestr(zi,p.read_bytes())
    with zipfile.ZipFile(output) as archive:assert archive.testzip() is None
    digest=sha(output);output.with_suffix(output.suffix+'.sha256').write_text(digest+'  '+output.name+'\n')
    print(f'Private unsigned candidate audit passed: {output.name}; SHA256 {digest}')
