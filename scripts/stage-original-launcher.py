#!/usr/bin/env python3
"""Stage the accepted Original binary with launch-link metadata; never publish or sign."""
import hashlib,json,plistlib,sys,zipfile
from pathlib import Path
source,destination=map(Path,sys.argv[1:])
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
expected='ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029'
if sha(source)!=expected:raise SystemExit('Expected the accepted public Preview 2 IPA; input differs.')
if destination.exists():raise SystemExit('Use a fresh destination; existing artifacts are preserved.')
destination.mkdir(parents=True)
with zipfile.ZipFile(source) as archive:
    for info in archive.infolist():
        path=Path(info.filename)
        if path.is_absolute() or '..' in path.parts:raise SystemExit('Unsafe archive path')
    archive.extractall(destination)
apps=list((destination/'Payload').glob('*.app'))
assert len(apps)==1
app=apps[0];plist=app/'Info.plist';info=plistlib.loads(plist.read_bytes())
assert info['CFBundleIdentifier']=='com.chrissotraidis.paperpad'
executable=app/info['CFBundleExecutable'];executable.chmod(0o755);binary_sha=sha(executable)
info['CFBundleDisplayName']='PaperPad Original'
info['CFBundleVersion']='3'
info['CFBundleURLTypes']=[{'CFBundleURLName':'paperpad-original','CFBundleURLSchemes':['paperpad-original']}]
plist.write_bytes(plistlib.dumps(info))
assert sha(executable)==binary_sha
record={'purpose':'Private Original companion: unchanged Preview 2 executable; launch-link, display-name and build metadata only',
        'sourceIPA_SHA256':expected,'executableSHA256':binary_sha,'bundleIdentifier':info['CFBundleIdentifier'],'build':'3'}
(destination/'ORIGINAL_PROVENANCE.json').write_text(json.dumps(record,indent=2)+'\n')
print('Original executable preserved; companion staged at '+str(app))
