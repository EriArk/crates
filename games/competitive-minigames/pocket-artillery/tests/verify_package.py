#!/usr/bin/env python3
"""Install the actual package in disposable Linux storage and exercise its launcher."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import signal
from unittest.mock import patch

p=argparse.ArgumentParser()
p.add_argument('host',type=Path);p.add_argument('record',type=Path);p.add_argument('archive',type=Path)
a=p.parse_args()
helpers=a.host.resolve()/'packaging/crates'
sys.path.insert(0,str(helpers))
from installer import Store, validate_records
record=json.loads(a.record.read_text());validate_records([record])
with tempfile.TemporaryDirectory(prefix='pocket-artillery-package-') as directory:
    home=Path(directory)
    with patch.dict(os.environ,{'HOME':str(home)}):
        store=Store(home/'packages');receipt=store.activate(a.archive,record)
        declaration=json.loads((store.root/"objects"/receipt["object"]/"traineros-activity.json").read_text())
        assert declaration==dict(schema=1,app="art.abysstail."+record["id"],protocol=record["id"]+(".3" if record["id"]=="pocket-artillery" else ".2"),seats=2)
        assert not (home/'.local/share/applications/org.traineros.crates.pocket-artillery.desktop').exists()
        data=store.root/'data/pocket-artillery/owners'/('a'*64);data.mkdir(parents=True)
        (data/'preserved.txt').write_text('personal game data')
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_DATA_HOME=str(home/'host-data'),XDG_RUNTIME_DIR=str(home/'runtime'))
        (home/'runtime').mkdir(mode=0o700)
        process=subprocess.Popen([sys.executable,str(helpers/'launch.py'),str(store.root),record['id'],'a'*64],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        try:
            time.sleep(2)
            assert process.poll() is None,process.communicate()[1].decode()
            try:
                store.remove(record['id'])
                raise AssertionError('Removed a running package')
            except BlockingIOError:pass
        finally:
            if process.poll() is None:process.terminate()
            try:
                _,error=process.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL);process.communicate()
                raise
            assert b'failed to load component' not in error.lower(),error.decode()
        store.remove(record['id'])
        assert (data/'preserved.txt').read_text()=='personal game data'
        store.activate(a.archive,record)
        assert (data/'preserved.txt').read_text()=='personal game data'
        print('Actual package: installation, launch, running lease, removal and data-preserving reinstall passed')
