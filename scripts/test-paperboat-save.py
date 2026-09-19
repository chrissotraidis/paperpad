#!/usr/bin/env python3
"""Run the real native save codec on the host, using includes from a configured build."""
import subprocess, shlex, tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
commands = subprocess.check_output(['ninja', '-C', str(root/'build-paperboat-ios'), '-t', 'commands'], text=True)
command = shlex.split(next(line for line in commands.splitlines() if '/SaveManager.cpp.o ' in line and ' -c ' in line))
flags = [arg for arg in command if arg.startswith(('-I', '-D')) and arg not in
         ('-DNDEBUG', '-DPLATFORM_IOS=1', '-D__IOS__', '-DPAPERPAD_APP=1')]
with tempfile.TemporaryDirectory(prefix='paperpad-save-test-') as tmp:
    executable = str(Path(tmp)/'save-test')
    subprocess.run(['clang++', '-std=c++20', '-w', '-ffunction-sections', '-fdata-sections', '-Wl,-dead_strip',
                    *flags, str(root/'tests/paperboat_save_test.cpp'),
                    str(root/'vendor/paperboat/src/port/save/SaveManager.cpp'), '-o', executable], check=True)
    subprocess.run([executable], check=True)
