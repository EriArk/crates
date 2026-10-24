#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Isolated Linux build/Qt+SDL checks. No production services or device writes."""
from pathlib import Path
import argparse,subprocess,tarfile,shlex
p=argparse.ArgumentParser();p.add_argument('--host',required=True);p.add_argument('--remote',required=True);p.add_argument('--installer-source',type=Path,required=True);a=p.parse_args()
if not a.remote.startswith('/tmp/crates-') or any(c not in '/-_.0123456789abcdefghijklmnopqrstuvwxyz' for c in a.remote):p.error('Use a dedicated /tmp/crates-* directory')
base=Path(__file__).resolve().parents[2];root=base.parents[1];out=root/'build/polish-linux';out.mkdir(parents=True,exist_ok=True)
games=('pong','snake-arena','light-cycles','falling-blocks','minesweeper-race','chain-reaction','mini-racing','tanks')
def ssh(command):subprocess.run(['ssh','-o','BatchMode=yes',a.host,command],check=True)
archive=out/'source.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
    for name in ('CMakeLists.txt','arcade-common','avatar-sdk','pocket-artillery',*games):tar.add(base/name,arcname='source/'+name)
    tar.add(a.installer_source,arcname='host/packaging/crates')
ssh('mkdir -p '+shlex.quote(a.remote));subprocess.run(['scp',str(archive),a.host+':'+a.remote+'/source.tar.gz'],check=True)
ssh('tar -xzf '+a.remote+'/source.tar.gz -C '+a.remote)
commands=[]
for source,build in [('/work/source','/work/build'),('/work/source/pocket-artillery','/work/artillery')]:
    commands += [f'cmake -S {source} -B {build} -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON',f'cmake --build {build} --parallel 3',f'ctest --test-dir {build} --output-on-failure']
ssh('docker run --rm --network=none -v '+a.remote+':/work traineros-ci:20260911 sh -c '+shlex.quote(' && '.join(commands)))
for build,names in [('build',(*games,'arcade-results.txt')),('artillery',('pocket-artillery','game-results.txt'))]:
    for name in names:subprocess.run(['scp',a.host+':'+a.remote+'/'+build+'/'+name,str(out/name)],check=True)
    subprocess.run(['scp',a.host+':'+a.remote+'/'+build+'/*.png',str(out)],check=True)
