#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package an exact server snapshot; no publishing, signing or device access."""
import argparse,hashlib,io,json,pathlib,re,tarfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--build',type=pathlib.Path,required=True)
p.add_argument('--manifest',type=pathlib.Path,required=True); p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--revision',required=True); a=p.parse_args()
if not re.fullmatch('[0-9a-f]{40}',a.revision): p.error('Full source revision required')
if a.output.exists(): p.error('Use a fresh immutable output directory')
manifest=json.loads(a.manifest.read_text())
match=re.search(r'^config/version="(\d+\.\d+\.\d+)"$',(ROOT/'project.godot').read_text(),re.M)
if not match: p.error('Missing package version')
version=match.group(1)
for name,digest in manifest['source_sha256'].items():
 if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest: p.error('Stale snapshot: '+name)
def archive(path,files):
 with tarfile.open(path,'w:gz') as tar:
  for name,data in sorted(files.items()):
   item=tarfile.TarInfo(name); item.size=len(data); item.mode=0o755 if name.startswith(('bin/','libexec/')) else 0o644
   tar.addfile(item,io.BytesIO(data))
common={n:(ROOT/n).read_bytes() for n in ['LICENSE','README.md','icon.svg','traineros-activity.json']}
for path in sorted(ROOT.rglob('*')):
 if path.is_file() and (path.parts[len(ROOT.parts)]=='licenses' or (path.parts[len(ROOT.parts)]=='assets' and path.suffix in ['.txt','.json','.md'])):
  common['licenses/'+path.relative_to(ROOT).as_posix()]=path.read_bytes()
manifest['revision']=a.revision; manifest['binary_sha256']={}
for suffix in ['arm64','x86_64']:
 name='micro-rally.'+suffix; manifest['binary_sha256'][name]=hashlib.sha256((a.build/name).read_bytes()).hexdigest()
common['build-manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
a.output.mkdir(parents=True); archives=[]
for suffix,arch,machine in [('arm64','aarch64',183),('x86_64','x86_64',62)]:
 binary=(a.build/('micro-rally.'+suffix)).read_bytes()
 if binary[:6]!=b'\x7fELF\x02\x01' or int.from_bytes(binary[18:20],'little')!=machine:p.error('Wrong architecture')
 files={'bin/micro-rally':(ROOT/'launch.sh').read_bytes(),'libexec/micro-rally':binary,**common}
 name=f'micro-rally-{version}-{arch}.tar.gz'; target=a.output/name; archive(target,files); archives.append(target)
 record=dict(id='micro-rally',title='Micro Rally (альфа)',kind='game',version=version,architecture=arch,
  entry='bin/micro-rally',icon='icon.svg',license='GPL-3.0-or-later',repository='https://github.com/EriArk/crates.git',revision=a.revision,
  size=target.stat().st_size,unpackedSize=sum(map(len,files.values()))+1048576,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
  channel='Experimental',compatibility='untested',compatibilityNote='Alpha: handheld controls, audio and sustained performance await player feedback.',
  notes='Four-stage solo Woodland Challenge with the full Nordschleife final; Rust Pit arena and 900x700 m Deadwater Battle Royale. Up to 16 cars, adjustable bots, independent suspension, five tire surfaces, heat-limited unlimited base gun, manual gears and haptics. Five camera views including windshield; shared SDK profile driver with updated outfits and expressions. English interface. Multiplayer uses TrainerOS Lobby; protocol micro-rally.9 requires matching updates. Faster cars, spatial aiming in low cameras, rebalanced gun heat and damage, three lives in every mode, death explosions and protected respawns. Routine hits no longer detach wheels. Incremental Nord scenery streaming and cached surface queries. Network racing remains in Valley; network cup is not included. Handheld performance and full gameplay acceptance remain pending. Flip2 uses OpenGL.',
  url=f'https://github.com/EriArk/crates/releases/download/micro-rally-v{version}/{name}')
 (a.output/f'micro-rally-{arch}-record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
source=a.output/f'micro-rally-{version}-source.tar.gz'
archive(source,{'micro-rally/'+name:(ROOT/name).read_bytes() for name in manifest['source_sha256']}); archives.append(source)
(a.output/'build-manifest.json').write_bytes(common['build-manifest.json'])
(a.output/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in archives))
print(json.dumps({'version':version,'revision':a.revision,'files':{f.name:f.stat().st_size for f in archives}}))
