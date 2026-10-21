#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package one arcade executable, plus all sources needed to rebuild it."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

base = Path(__file__).resolve().parent.parent
titles = {'pong': 'Pong', 'snake-arena': 'Snake Arena', 'light-cycles': 'Light Cycles',
          'falling-blocks': 'Falling Blocks', 'minesweeper-race': 'Minesweeper Race', 'chain-reaction': 'Chain Reaction',
          'mini-racing': 'Brick Racing', 'tanks': 'Brick Tanks'}
p = argparse.ArgumentParser()
p.add_argument('game', choices=titles)
p.add_argument('executable', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--version', default='0.1.1')
a = p.parse_args()
match = re.search(r'project\(CratesArcade VERSION ([0-9.]+)', (base/'CMakeLists.txt').read_text())
if not match or a.version != match.group(1):
    p.error('Version must match CMakeLists.txt')
binary = a.executable.read_bytes()
if len(binary) < 20 or binary[:6] != b'\x7fELF\x02\x01':
    p.error('Expected a 64-bit little-endian Linux ELF')
arch = {62: 'x86_64', 183: 'aarch64'}.get(int.from_bytes(binary[18:20], 'little'))
if not arch:
    p.error('Unsupported ELF architecture')
root = base/a.game
files = {f'bin/{a.game}': binary}
for name in ('LICENSE', 'README.md', 'icon.svg', 'docs/play.png'):
    files[name] = (root/name).read_bytes()
a.output.mkdir(parents=True, exist_ok=True)
name = f'{a.game}-{a.version}-{arch}.tar.gz'
archive = a.output/name
if archive.exists():
    p.error('Choose a fresh output directory; package artifacts are immutable')
with tarfile.open(archive, 'w:gz') as tar:
    for path, content in files.items():
        info = tarfile.TarInfo(path)
        info.size = len(content)
        info.mode = 0o755 if path.startswith('bin/') else 0o644
        tar.addfile(info, io.BytesIO(content))
record = dict(id=a.game, title=titles[a.game], kind='game', version=a.version,
              architecture=arch, entry=f'bin/{a.game}', icon='icon.svg',
              license='GPL-3.0-or-later', repository='https://github.com/EriArk/crates.git',
              size=archive.stat().st_size, unpackedSize=sum(map(len, files.values()))+1048576,
              sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), channel='Experimental',
              compatibility='untested',
              compatibilityNote='Desktop checks only; ARM, physical controls and live internet acceptance pending.',
              notes='Bot practice, two local players and optional TrainerOS SDK Lobby. Requires Qt Quick, Qt Network and SDL2.',
              url=f'https://github.com/EriArk/crates/releases/download/{a.game}-v{a.version}/{name}')
try:
    if not subprocess.check_output(['git','-C',str(base),'status','--porcelain','--','.'], text=True).strip():
        record['revision'] = subprocess.check_output(['git','-C',str(base),'rev-parse','HEAD'], text=True).strip()
except (OSError, subprocess.CalledProcessError):
    pass
(a.output/f'{a.game}-{arch}-record.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
source = a.output/f'{a.game}-{a.version}-source.tar.gz'
with tarfile.open(source, 'w:gz') as tar:
    tar.add(base/'CMakeLists.txt', arcname='arcade/CMakeLists.txt')
    tar.add(base/'README.md', arcname='arcade/README.md')
    for directory in ('docs', 'arcade-common', *titles):
        for path in sorted((base/directory).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                tar.add(path, arcname=Path('arcade')/path.relative_to(base))
(a.output/'SHA256SUMS').write_text(''.join(
    f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in (archive, source)), encoding='utf-8')
print(archive)
