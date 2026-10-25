#!/usr/bin/env python3
"""Server-only real Golf/SDK/TLS/HTTP/worker check, isolated from live accounts/DB."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

p=argparse.ArgumentParser()
p.add_argument('golf',type=Path);p.add_argument('native',type=Path)
p.add_argument('backend',type=Path);p.add_argument('godot',type=Path)
p.add_argument('--players',type=int,nargs='+',default=[2,4,5,8])
p.add_argument('--casual',action='store_true',help='Last peer has no Backend account/capability')
a=p.parse_args();golf=a.golf.resolve();native=a.native.resolve();backend=a.backend.resolve()
evidence=golf/'evidence';evidence.mkdir(exist_ok=True)
image='traineros-backend-test:play-20261025';native_image='traineros-golf-backend-ci:20261025'
def run(cmd,**kwargs):return subprocess.run(cmd,stdin=subprocess.DEVNULL,**kwargs)
for count in a.players:
    if count not in [2,4,5,8]:p.error('Use supported fixture counts')
    live=Path(tempfile.mkdtemp(prefix='golf-fixture-',dir=evidence));name='golf-play-'+uuid.uuid4().hex[:12]
    def private(program):
        run(['docker','run','--rm','--network','none','--user','0','-v',str(live)+':/fixture',image,'python','-c',program],check=True)
    started=False
    try:
        private(f'import os;os.chown("/fixture",10001,{os.getgid()});os.chmod("/fixture",0o750)')
        run(['docker','run','-d','--rm','--name',name,'--network','none','--cpus','1','--memory','768m','--pids-limit','128',
             '-e','PLAY_FIXTURE_DIR=/fixture','-e',f'PLAY_FIXTURE_PLAYERS={count}','-e','PLAY_FIXTURE_RULESET=/registry/golf.json',
             '-v',str(live)+':/fixture','-v',str(backend/'registry/pocket-golf-island-v1.json')+':/registry/golf.json:ro',
             '-v',str(backend/'tests/play_http_fixture.py')+':/workspace/services/backend/tests/play_http_fixture.py:ro',
             image,'python','tests/play_http_fixture.py'],check=True,stdout=subprocess.DEVNULL)
        started=True
        for _ in range(50):
            result=run(['docker','exec',name,'python','-c',"import urllib.request;urllib.request.urlopen('http://127.0.0.1:19091/health/ready',timeout=1)"],capture_output=True)
            if result.returncode==0:break
            time.sleep(.2)
        else:raise RuntimeError('Isolated API failed to start')
        suffix='-casual' if a.casual else ''
        with (evidence/f'backend-group-{count}{suffix}.txt').open('w') as log:
            result=run(['docker','run','--rm','--network','container:'+name,'--cpus','3','--memory','4g','--pids-limit','512',
                '-e','QT_QPA_PLATFORM=offscreen','-e','QT_QUICK_BACKEND=software',
                '-e','TRAINEROS_TEST_RECORD_PYTHON=/usr/bin/python3','-e','GOLF_TEST_GODOT=/godot',
                '-e','GOLF_TEST_PROJECT=/golf/source','-e','GOLF_TEST_BACKEND_FIXTURES=/fixtures',
                *(['-e','GOLF_TEST_CASUAL=1'] if a.casual else []),
                '-v',str(native)+':/work:ro','-v',str(golf)+':/golf','-v',str(live)+':/fixtures:ro',
                '-v',str(a.godot.resolve())+':/godot:ro',native_image,
                '/golf/host-build/golf-host-tests',f'groupGolf:{count}'],stdout=log,stderr=subprocess.STDOUT,timeout=300)
        if result.returncode:raise RuntimeError(f'Golf {count} failed; see evidence/backend-group-{count}.txt')
        print(f'PASS Golf {count}: '+('casual fallback, full round, rematch, owner revocation' if a.casual else 'actual game, SDK, TLS, HTTP, PostgreSQL, worker, shared board, rematch, owner revocation'),flush=True)
    finally:
        if started:run(['docker','stop','--time','15',name],stdout=subprocess.DEVNULL)
        private('from pathlib import Path;import os\n'
            'for p in Path("/fixture").glob("player-*.json"):p.unlink()\n'
            f'os.chown("/fixture",{os.getuid()},{os.getgid()});os.chmod("/fixture",0o700)')
        live.rmdir()
