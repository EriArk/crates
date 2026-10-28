#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render an existing Linux export on the server's isolated virtual display."""
import argparse, json, pathlib, re, shlex, subprocess, uuid

p=argparse.ArgumentParser()
p.add_argument('--manifest',type=pathlib.Path,required=True)
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--track',choices=['dirty-valley.4','quarry.1','forest-pass.1','nordschleife.1'],default='quarry.1')
p.add_argument('--screen',choices=['race','quick','bots','cup','controls','credits'],default='race')
p.add_argument('--renderer',choices=['mobile','gl_compatibility'],default='mobile')
p.add_argument('--at',type=int)
p.add_argument('--time',choices=['day','dawn','sunset','night'],default='sunset')
p.add_argument('--weather',choices=['clear','overcast','rain'],default='clear')
a=p.parse_args()
snapshot=json.loads(a.manifest.read_text())['source_snapshot']
if not re.fullmatch('[a-f0-9]{16}',snapshot): p.error('Invalid snapshot')
a.output.mkdir(parents=True,exist_ok=True)
remote='/home/abysscloud/traineros-micro-rally'
name='rally-capture-'+uuid.uuid4().hex
filename='capture-'+a.track+'-'+a.renderer+('-at'+str(a.at) if a.at is not None else '')+('-'+a.screen if a.screen!='race' else '')+'.png'
target='/work/exports/'+snapshot+'/'+filename
argv=['docker','run','--init','--rm','--name',name,'--network','none','--user','1000:1000',
      '-e','HOME=/tmp','-e','LIBGL_ALWAYS_SOFTWARE=1','-e','XDG_RUNTIME_DIR=/tmp',
      '-v',remote+':/work','traineros-rally-render-ci:20261028',
      'xvfb-run','-a','-s','-screen 0 1280x720x24',
      '/work/exports/'+snapshot+'/micro-rally.x86_64','--audio-driver','Dummy',
      '--rendering-method',a.renderer,'--',('--autodrive' if a.screen=='race' else '--screen='+a.screen),'--track='+a.track,
      '--time='+a.time,'--weather='+a.weather,'--capture='+target]+(['--capture-at='+str(a.at)] if a.at is not None else [])
try:
    result=subprocess.run(['ssh','books-server',shlex.join(argv)],capture_output=True,timeout=180)
    log=result.stdout+result.stderr
    (a.output/(filename+'.log')).write_bytes(log)
    if result.returncode or any(x in log for x in [b'SCRIPT ERROR:',b'SHADER ERROR:',b'Parse Error:']):
        raise RuntimeError(log.decode(errors='replace')[-3000:])
    subprocess.run(['scp','books-server:'+remote+'/exports/'+snapshot+'/'+filename,str(a.output/filename)],check=True)
    if not (a.output/filename).read_bytes().startswith(b'\x89PNG\r\n\x1a\n'): raise RuntimeError('Missing PNG')
    print(json.dumps({'snapshot':snapshot,'track':a.track,'renderer':a.renderer,'image':str(a.output/filename),'software_render':True,'static_route_index':a.at,'time':a.time,'weather':a.weather}))
except subprocess.TimeoutExpired as error:
    (a.output/(filename+'.log')).write_bytes((error.stdout or b'')+(error.stderr or b'')+b'\nCAPTURE TIMEOUT\n')
    raise
finally:
    subprocess.run(['ssh','books-server',shlex.join(['docker','rm','-f',name])],capture_output=True,timeout=20)
