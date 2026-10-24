#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package a native Linux build for the existing TrainerOS Crates installer."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('executable', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--version', default='0.1.3')
args = parser.parse_args()
import re
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9.-]+)?', args.version):
    parser.error('Use an explicit numeric app version')
binary = args.executable.read_bytes()
match = re.search(r'project\(PocketArtillery VERSION ([0-9.]+)', (root / 'CMakeLists.txt').read_text())
if not match or args.version != match.group(1):
    parser.error('Package version must match the CMake project version')
if binary[:4] != b'\x7fELF' or binary[4:6] != b'\x02\x01':
    parser.error('Expected a 64-bit little-endian Linux ELF executable')
arch = {62: 'x86_64', 183: 'aarch64'}.get(int.from_bytes(binary[18:20], 'little'))
if arch is None:
    parser.error('Unsupported ELF architecture')
args.output.mkdir(parents=True, exist_ok=True)
name = f'pocket-artillery-{args.version}-{arch}.tar.gz'
archive = args.output / name
files = {'traineros-activity.json': (root / 'traineros-activity.json').read_bytes(), 'bin/pocket-artillery': binary, 'LICENSE': (root / 'LICENSE').read_bytes(),
         'README.md': (root / 'README.md').read_bytes(), 'icon.svg': (root / 'icon.svg').read_bytes(),
         'docs/duel.png': (root / 'docs/duel.png').read_bytes(),
         'docs/idea.md': (root / 'docs/idea.md').read_bytes()}
for document in ('presentation-pass.md', 'flight.png', 'impact.png'):
    files['docs/'+document] = (root/'docs'/document).read_bytes()
for evidence in sorted((root/'docs/evidence').glob('*.txt')):
    files['docs/evidence/'+evidence.name] = evidence.read_bytes()
if archive.exists():
    parser.error('Choose a fresh output directory; published packages are immutable')
with tarfile.open(archive, 'w:gz') as tar:
    for path, content in files.items():
        info = tarfile.TarInfo(path)
        info.size = len(content)
        info.mode = 0o755 if path.startswith('bin/') else 0o644
        tar.addfile(info, io.BytesIO(content))
record = dict(id='pocket-artillery', title='Pocket Artillery', kind='game', version=args.version,
              architecture=arch, entry='bin/pocket-artillery', icon='icon.svg',
              license='GPL-3.0-or-later', repository='https://github.com/EriArk/crates.git',
              size=archive.stat().st_size, unpackedSize=sum(map(len, files.values())) + 1048576,
              sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), channel='Experimental',
              compatibility='untested', compatibilityNote='Linux x86_64/ARM64 UI checks and paired SDK match/rematch checks passed. Physical controls and separate-network acceptance remain open.',
              notes='Two-player artillery, Lobby-first matches and shared avatar portraits. Optional Qt Quick 3D for portraits; Qt Quick, Network and SDL2 for play.',
              url=f'https://github.com/EriArk/crates/releases/download/pocket-artillery-v{args.version}/{name}')
try:
    if not subprocess.check_output(['git','-C',str(root),'status','--porcelain','--','.', '../avatar-sdk', '../arcade-common/ControllerInput.h', '../arcade-common/tests/VirtualPad.h'], text=True).strip():
        record['revision']=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'], text=True).strip()
except (OSError,subprocess.CalledProcessError):
    pass  # A distributed source archive is also a valid build input.
(args.output / f'pocket-artillery-{arch}-record.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
source = args.output / f'pocket-artillery-{args.version}-source.tar.gz'
with tarfile.open(source, 'w:gz') as tar:
    tar.add(root.parent/'avatar-sdk', arcname='avatar-sdk')
    tar.add(root.parent/'arcade-common/ControllerInput.h', arcname='arcade-common/ControllerInput.h')
    tar.add(root.parent/'arcade-common/tests/VirtualPad.h', arcname='arcade-common/tests/VirtualPad.h')
    for path in sorted(root.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts:
            tar.add(path, arcname=Path('pocket-artillery') / path.relative_to(root))
(args.output / 'SHA256SUMS').write_text(''.join(
    f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in (archive, source)), encoding='utf-8')
print(archive)
