#!/usr/bin/env python3
"""Build a restored PaperPad-source archive using installed Xcode/CMake/Ninja."""
import json, os, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['python3',str(root/'scripts/paperboat-source-archive.py'),'--verify',str(root)],check=True)
lock=json.loads((root/'paperboat.lock.json').read_text());build=root/'build-paperboat-ios'
args=['cmake','-S',str(root/'vendor/paperboat'),'-B',str(build),'-G','Ninja',
      '-DCMAKE_TOOLCHAIN_FILE=cmake/ios.paperboat.toolchain.cmake','-DPLATFORM=OS64',
      '-DIOS_SIGNING=OFF','-DCMAKE_BUILD_TYPE=Release','-DPAPERPAD_APP_ROOT='+str(root),
      '-DSDL_SHARED=OFF','-DSDL_STATIC=ON','-DFETCHCONTENT_FULLY_DISCONNECTED=ON',
      '-DCMAKE_PROJECT_INCLUDE_BEFORE='+str(root/'scripts/paperboat-offline-downloads.cmake')]
for name in lock['buildDependencies']:
    args.append('-DFETCHCONTENT_SOURCE_DIR_'+name.upper()+'='+str(build/'_deps'/(name+'-src')))
subprocess.run(args,check=True)
subprocess.run(['python3',str(root/'scripts/verify-paperboat.py'),'--build-dir',str(build)],check=True)
subprocess.run(['cmake','--build',str(build),'--parallel',os.environ.get('PAPERPAD_BUILD_JOBS','8')],check=True)
subprocess.run(['python3',str(root/'scripts/record-paperboat-build.py'),str(build)],check=True)
