#!/usr/bin/env python3
"""Pack the verified Godot exports for the OctoFox Crates catalogue."""
# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('build', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
version = re.search(r'^config/version="([^"]+)"$', (root/'project.godot').read_text(), re.M)[1]
revision = subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip()
if subprocess.check_output(['git','status','--porcelain','--','.'],cwd=root):
    parser.error('Package from a clean source tree')
manifest = json.loads((args.build/'build-manifest.json').read_text())
args.output.mkdir(parents=True, exist_ok=False)
for suffix, arch, machine in [('arm64','aarch64',183),('x86_64','x86_64',62)]:
    binary = args.build/('bazaar.'+suffix)
    with binary.open('rb') as stream:
        header = stream.read(20)
        stream.seek(0)
        digest = hashlib.file_digest(stream,'sha256').hexdigest()
    if digest != manifest['binaries'][binary.name] or header[:6]!=b'\x7fELF\x02\x01' or int.from_bytes(header[18:20],'little') != machine:
        parser.error('Unexpected export '+binary.name)
    archive = args.output/f'bazaar-{version}-{arch}.tar.gz'
    files = {'bin/bazaar':binary,'LICENSE':root/'LICENSE','park.png':root/'assets/market/park.png',
             'README.md':root/'README.md','build-manifest.json':args.build/'build-manifest.json'}
    files.update({p.relative_to(root).as_posix():p for p in (root/'licenses').glob('*') if p.is_file()})
    with tarfile.open(archive,'w:gz') as output:
        for name,path in files.items():
            info=output.gettarinfo(str(path),arcname=name)
            info.mode=0o755 if name=='bin/bazaar' else 0o644
            with path.open('rb') as stream:output.addfile(info,stream)
    with archive.open('rb') as stream:checksum=hashlib.file_digest(stream,'sha256').hexdigest()
    record=dict(id='bazaar',version=version,architecture=arch,kind='game',title='Bazaar (Alpha Preview)',
                license='GPL-3.0-or-later',entry='bin/bazaar',icon='park.png',repository='https://github.com/EriArk/crates.git',
                channel='Experimental',compatibility='untested',notes='Steer into Festival Park, visit the island counter and play the Toy Gallery or Wanage.',
                revision=revision,size=archive.stat().st_size,unpackedSize=sum(p.stat().st_size for p in files.values())+1048576,
                sha256=checksum,url=f'https://github.com/EriArk/crates/releases/download/bazaar-v{version}/{archive.name}')
    (args.output/f'bazaar-{arch}-record.json').write_text(json.dumps(record,indent=2)+'\n')
source=args.output/f'bazaar-{version}-source.tar.gz'
subprocess.run(['git','archive','--format=tar.gz','--prefix=bazaar/','--output',str(source.resolve()),'HEAD:games/bazaar'],cwd=root.parents[1],check=True)
with (args.output/'SHA256SUMS').open('w') as out:
    for path in sorted(args.output.glob('*.tar.gz')):
        with path.open('rb') as stream:out.write(hashlib.file_digest(stream,'sha256').hexdigest()+'  '+path.name+'\n')
