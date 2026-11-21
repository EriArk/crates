#!/usr/bin/env python3
"""Bounded real-device launch checks after explicit owner authorization.

Menus only: no synthetic competition result, saved round or account mutation.
Uses the existing selected Trainer and installed managed package launcher.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import signal
import socket
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('stage', type=Path)
parser.add_argument('--only')
parser.add_argument('--settle', type=int, default=5)
args = parser.parse_args()
assert 5 <= args.settle <= 45
stage = args.stage.resolve()
pid = subprocess.check_output(['pgrep', '-xo', 'traineros'], text=True).strip()
raw = dict(x.split('=',1) for x in Path('/proc',pid,'environ').read_text().split('\0') if '=' in x)
env = dict(os.environ)
for key in ['DISPLAY','XAUTHORITY','XDG_RUNTIME_DIR','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS']:
    if key in raw:
        env[key] = raw[key]
endpoint = Path.home()/'.local/share/traineros/platform-v1/endpoint.json'
info = json.loads(endpoint.read_text())
with socket.create_connection((info['host'],info['port']),timeout=5) as peer:
    packet = {'id':'check','method':'hello','params':{'protocol':1,'token':info['token'],'app':'org.traineros.game-launch-check'}}
    peer.sendall((json.dumps(packet)+'\n').encode())
    context = json.loads(peer.makefile().readline())['result']['context']
assert context.get('profile'), 'Unlock/select your Trainer before game launch checks'
owner = hashlib.sha256(context['profile'].encode()).hexdigest()
root = Path.home()/'.local/share/TrainerOS/TrainerOS/crates'
entries = json.loads((stage/'manifest.json').read_text())
report = []
for entry in entries:
    record = json.loads((stage/entry['record']).read_text())
    game = record['id']
    if args.only and game != args.only:
        continue
    output = stage/(game+'-launch.txt')
    with output.open('wb') as log:
        proc = subprocess.Popen(['/usr/bin/python3','/var/opt/traineros/crates/launch.py',str(root),game,owner],
                                env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            time.sleep(max(8 if game=='pocket-golf' else 5, args.settle))
            assert proc.poll() is None, 'Game exited: '+game
            if game in ['pocket-golf','mini-racing','tanks']:
                capture_env = dict(env,WAYLAND_DISPLAY=raw.get('GAMESCOPE_WAYLAND_DISPLAY',raw.get('WAYLAND_DISPLAY','')))
                subprocess.run(['gamescopectl','screenshot',str(stage/(game+'.png')),'4'],env=capture_env,
                               stdin=subprocess.DEVNULL,capture_output=True,timeout=10,check=True)
                time.sleep(.5)
        finally:
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid,signal.SIGKILL)
                proc.wait()
                raise RuntimeError('Managed game did not stop: '+game)
    text = output.read_text(errors='replace')
    assert not any(error in text for error in ['SCRIPT ERROR:','Parse Error:','QQmlApplicationEngine failed to load','error while loading shared libraries']), text
    report.append({'game':game,'version':record['version'],'menu_process_live':True,'managed_stop':True})
    print('LAUNCH PASS',game,flush=True)
    time.sleep(.5)
assert report, 'No matching installed game'
report_name = 'launch-checks.json' if not args.only else args.only+'-followup.json'
(stage/report_name).write_text(json.dumps(report,indent=2))
assert Path('/proc',pid).exists(), 'Shell exited during game checks'
print('All installed games opened and exited; shell retained')
