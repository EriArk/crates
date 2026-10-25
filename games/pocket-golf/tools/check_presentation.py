#!/usr/bin/env python3
"""Bounded software-rendered server UI check; no handheld or audio acceptance."""
import os
from pathlib import Path
import select
import subprocess
import sys

read,write=os.pipe()
display=subprocess.Popen(['Xvfb','-displayfd',str(write),'-screen','0','960x540x24','-nolisten','tcp'],pass_fds=(write,),stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
os.close(write)
try:
    if not select.select([read],[],[],15)[0]:raise RuntimeError('Display startup timed out')
    with os.fdopen(read) as pipe:number=pipe.readline().strip()
    if not number:raise RuntimeError('Display failed')
    command=[os.environ['GOLF_UI_RUNNER'],'boardPortraits'] if os.environ.get('GOLF_UI_RUNNER') else ['/godot','--path','/work/source','--audio-driver','Dummy','--rendering-method','gl_compatibility','--script','tests/scorecards_ui_test.gd']
    result=subprocess.run(command,
        env=dict(os.environ,DISPLAY=':'+number,LIBGL_ALWAYS_SOFTWARE='1',GOLF_SCORE_CAPTURE='/work/evidence/captures'),
        capture_output=True,text=True,timeout=180)
    print(result.stdout+result.stderr)
    if result.returncode or 'SCRIPT ERROR' in result.stderr:raise SystemExit(1)
finally:
    display.terminate();display.communicate(timeout=10)
