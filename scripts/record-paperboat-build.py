#!/usr/bin/env python3
import hashlib,json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];build=Path(sys.argv[1])
def git(*args):return subprocess.check_output(['git','-C',str(root),*args],text=True).strip()
inputs=['apple/app/ios_main.mm','apple/app/rom_setup.mm','apple/app/diagnostics.mm','apple/app/touch_tap_latch.h','src/paperpad_input.h','src/controller_slots.h','src/controller_slots.cpp']
inputs += [str(p.relative_to(root)) for p in sorted((root/'apple/paperboat').glob('*')) if p.is_file()]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
doc={'applicationCommit':git('rev-parse','HEAD'),'dirty':bool(git('status','--porcelain')),
     'engine':'PaperBoat','sources':json.loads((root/'paperboat.lock.json').read_text()),
     'shellInputs':{p:sha(root/p) for p in inputs},'executableSHA256':sha(build/'Paperboat.app/Paperboat')}
(build/'PAPERPAD_BUILD.json').write_text(json.dumps(doc,indent=2)+'\n')
print('Recorded exact PaperBoat build inputs and executable hash.')
