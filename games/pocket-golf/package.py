#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare immutable Crates records and packages; never publishes or updates a catalogue."""
import argparse,hashlib,io,json,pathlib,subprocess,tarfile,zipfile
root=pathlib.Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('build',type=pathlib.Path);p.add_argument('output',type=pathlib.Path);a=p.parse_args()
version='0.1.3'
if 'config/version="'+version+'"' not in (root/'project.godot').read_text():p.error('Version mismatch')
if a.output.exists():p.error('Choose a fresh output directory')
manifest=json.loads((a.build/'build-manifest.json').read_text())
for name,expected in manifest['source_sha256'].items():
    if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:p.error('Build is stale: '+name)
for name,expected in manifest['binary_sha256'].items():
    if hashlib.sha256((a.build/name).read_bytes()).hexdigest()!=expected:p.error('Binary mismatch: '+name)
a.output.mkdir(parents=True)
revision=None
try:
    if not subprocess.check_output(['git','-C',str(root),'status','--porcelain','--','.'],text=True,stderr=subprocess.DEVNULL).strip():
        revision=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
except (OSError,subprocess.CalledProcessError):
    pass # A distributed source archive is a valid build/package input without Git.
common={name:(root/name).read_bytes() for name in ['LICENSE','README.md','icon.svg']}
common['build-manifest.json']=(a.build/'build-manifest.json').read_bytes()
for pack in ['nature','pirate','golf']:
    common['licenses/kenney-'+pack+'.txt']=(root/'assets/kenney'/pack/'LICENSE.txt').read_bytes()
common['licenses/kenney-provenance.json']=(root/'assets/kenney/provenance.json').read_bytes()
for folder in ['licenses','docs']:
    for file in sorted((root/folder).rglob('*')):
        if file.is_file():common[file.relative_to(root).as_posix()]=file.read_bytes()
archives=[]
for suffix,arch,machine in [('x86_64','x86_64',62),('arm64','aarch64',183)]:
    binary=(a.build/('pocket-golf.'+suffix)).read_bytes()
    if binary[:6]!=b'\x7fELF\x02\x01' or int.from_bytes(binary[18:20],'little')!=machine:p.error('Wrong ELF architecture')
    files={'bin/pocket-golf':binary,**common}
    name=f'pocket-golf-{version}-{arch}.tar.gz';archive=a.output/name
    with tarfile.open(archive,'w:gz') as t:
        for path,data in files.items():
            member=tarfile.TarInfo(path);member.size=len(data);member.mode=0o755 if path.startswith('bin/') else 0o644;t.addfile(member,io.BytesIO(data))
    record=dict(id='pocket-golf',title='Pocket Golf',kind='game',version=version,architecture=arch,entry='bin/pocket-golf',icon='icon.svg',license='GPL-3.0-or-later',repository='https://github.com/EriArk/crates.git',size=archive.stat().st_size,unpackedSize=sum(map(len,files.values()))+1048576,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),channel='Experimental',compatibility='untested',compatibilityNote='Godot preparation; avatar integration and handheld acceptance pending.',notes='Three-hole minigolf: solo, local pass-controller and optional SDK Lobby. Vulkan Mobile; OpenGL fallback.',url=f'https://github.com/EriArk/crates/releases/download/pocket-golf-v{version}/{name}')
    if revision:record['revision']=revision
    (a.output/f'pocket-golf-{arch}-record.json').write_text(json.dumps(record,indent=2)+'\n')
    archives.append(archive)
windows=a.output/f'pocket-golf-{version}-windows-preview.zip'
with zipfile.ZipFile(windows,'w',zipfile.ZIP_DEFLATED) as z:
    z.write(a.build/'pocket-golf.exe','pocket-golf.exe')
    for path,data in common.items():z.writestr(path,data)
archives.append(windows)
source=a.output/f'pocket-golf-{version}-source.tar.gz'
with tarfile.open(source,'w:gz') as t:
    for path in sorted(root.rglob('*')):
        if path.is_file() and not any(part in ['.godot','__pycache__','build','dist'] for part in path.relative_to(root).parts):
            t.add(path,arcname=pathlib.Path('pocket-golf')/path.relative_to(root))
archives.append(source)
(a.output/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in archives))
print('Prepared',a.output,'revision',revision)
