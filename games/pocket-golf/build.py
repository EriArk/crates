#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build in an isolated copy using pinned Godot 4.7.2 official export templates."""
import argparse, hashlib, json, pathlib, shutil, subprocess, tempfile
p=argparse.ArgumentParser()
p.add_argument('--godot',type=pathlib.Path,required=True)
p.add_argument('--templates',type=pathlib.Path,required=True,help='Extracted export_templates.tpz templates directory')
p.add_argument('--output',type=pathlib.Path,required=True)
a=p.parse_args();root=pathlib.Path(__file__).resolve().parent
godot=a.godot.resolve();templates=a.templates.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
version=subprocess.check_output([str(godot),'--version'],text=True).strip()
if not version.startswith('4.7.2.stable.'):p.error('Use pinned Godot 4.7.2 stable')
def run(args):
    result=subprocess.run([str(godot),*args],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    if result.returncode or 'SCRIPT ERROR:' in result.stdout or 'ERROR:' in result.stdout:
        raise RuntimeError(result.stdout)
    return result.stdout
with tempfile.TemporaryDirectory(prefix='golf-build-',dir=out.parent) as tmp:
    stage=pathlib.Path(tmp).resolve()
    if stage.parent!=out.parent:raise RuntimeError('Unexpected staging path')
    # TemporaryDirectory cleanup is restricted to this verified disposable staging directory.
    project=stage/'pocket-golf'
    shutil.copytree(root,project,ignore=shutil.ignore_patterns('.godot','build','dist','__pycache__'))
    preset=project/'export_presets.cfg'
    preset.write_text(preset.read_text().replace('../../build/godot/templates/',templates.as_posix()+'/'))
    run(['--headless','--path',str(project),'--editor','--import','--quit'])
    for target,filename in [('Linux x86_64','pocket-golf.x86_64'),('Linux ARM64','pocket-golf.arm64'),('Windows','pocket-golf.exe')]:
        (out/(filename+'.build.txt')).write_text(run(['--headless','--path',str(project),'--export-release',target,str(out/filename)]),encoding='utf-8')
        print('Exported',filename,flush=True)
digest=lambda file:hashlib.sha256(file.read_bytes()).hexdigest()
runtime=[f for f in root.rglob('*') if f.is_file() and '.godot' not in f.parts and (f.suffix in ['.gd','.tscn','.uid','.gdshader'] or 'assets' in f.relative_to(root).parts or f.name in ['project.godot','icon.svg']) and 'tests' not in f.relative_to(root).parts]
(out/'build-manifest.json').write_text(json.dumps(dict(engine=version,editor_sha256=digest(godot),source_sha256={f.relative_to(root).as_posix():digest(f) for f in runtime},binary_sha256={f.name:digest(f) for f in [out/'pocket-golf.x86_64',out/'pocket-golf.arm64',out/'pocket-golf.exe']}),indent=2)+'\n')
