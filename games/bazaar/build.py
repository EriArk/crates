#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Export an isolated source copy; never modifies a live installation or catalogue."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--templates', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent
engine = args.godot.resolve()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
version = subprocess.check_output([str(engine), '--version'], text=True).strip()
if not version.startswith('4.7.2.stable.'):
    parser.error('Use the pinned Godot 4.7.2 stable engine/templates')
with tempfile.TemporaryDirectory(prefix='bazaar-export-', dir=output.parent) as temporary:
    project = Path(temporary) / 'source'
    shutil.copytree(root, project, ignore=shutil.ignore_patterns('.godot', 'build', '__pycache__'))
    preset = project / 'export_presets.cfg'
    preset.write_text(preset.read_text().replace('@TEMPLATES@', args.templates.resolve().as_posix()))
    def run(*command):
        result = subprocess.run([str(engine), '--headless', '--path', str(project), *command],
                                capture_output=True, text=True, timeout=240)
        log = result.stdout + result.stderr
        if result.returncode or 'ERROR:' in log:
            raise RuntimeError(log)
        return log
    (output / 'import.log').write_text(run('--editor', '--import', '--quit'))
    for target, name in [('Linux x86_64', 'bazaar.x86_64'), ('Linux ARM64', 'bazaar.arm64'), ('Windows', 'bazaar.exe')]:
        (output / (name+'.log')).write_text(run('--export-release', target, str(output/name)))
        print('Exported', name, flush=True)
shutil.copytree(root/'licenses', output/'licenses', dirs_exist_ok=True)
shutil.copyfile(root/'LICENSE', output/'LICENSE')
hash_file = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = {'engine': version, 'editor_sha256': hash_file(engine),
            'binaries': {n: hash_file(output/n) for n in ['bazaar.x86_64', 'bazaar.arm64', 'bazaar.exe']}}
(output/'build-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
