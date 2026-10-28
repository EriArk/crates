#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""External resolved SDK fixture + server render. Never includes GLB in game export."""
import argparse,json,pathlib,hashlib,re,shlex,subprocess,uuid
p=argparse.ArgumentParser()
p.add_argument('--manifest',type=pathlib.Path,required=True)
p.add_argument('--descriptor',type=pathlib.Path,required=True,help='Existing official SDK resolved test profile')
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--renderer',choices=['mobile','gl_compatibility'],default='gl_compatibility')
a=p.parse_args(); a.output.mkdir(parents=True,exist_ok=True)
snapshot=json.loads(a.manifest.read_text())['source_snapshot']
assert re.fullmatch('[a-f0-9]{16}',snapshot)
d=json.loads(a.descriptor.read_text()); asset=pathlib.Path(d['glb'])
assert hashlib.sha256(asset.read_bytes()).hexdigest()==d['sha256']
remote='/home/abysscloud/traineros-micro-rally'
fixture='fixtures/'+d['sha256']
def ssh(argv,**kw): return subprocess.run(['ssh','books-server',shlex.join(argv)],check=True,**kw)
ssh(['mkdir','-p',remote+'/'+fixture])
subprocess.run(['scp',str(asset),'books-server:'+remote+'/'+fixture+'/avatar.glb'],check=True)
d['glb']='/work/'+fixture+'/avatar.glb';d['profile']='rally-test-profile';d.pop('preview',None)
ssh(['tee',remote+'/'+fixture+'/descriptor.json'],input=json.dumps(d).encode(),stdout=subprocess.DEVNULL)
folder='exports/'+snapshot+'/driver-'+a.renderer
ssh(['mkdir','-p',remote+'/'+folder])
name='rally-driver-'+uuid.uuid4().hex
argv=['docker','run','--init','--rm','--name',name,'--network','none','--user','1000:1000','-e','HOME=/tmp',
 '-e','LIBGL_ALWAYS_SOFTWARE=1','-e','XDG_RUNTIME_DIR=/tmp','-v',remote+':/work',
 'traineros-rally-render-ci:20261028','xvfb-run','-a','-s','-screen 0 1280x720x24',
 '/work/engine/godot','--path','/work/snapshots/'+snapshot,'--audio-driver','Dummy',
 '--rendering-method',a.renderer,'--fixed-fps','60','--script','res://tests/avatar_driver_test.gd',
 '--','--descriptor=/work/'+fixture+'/descriptor.json','--output=/work/'+folder]
try:
 result=subprocess.run(['ssh','books-server',shlex.join(argv)],capture_output=True,timeout=240)
 log=result.stdout+result.stderr; (a.output/'render.log').write_bytes(log)
 print(log.decode(errors='replace'),flush=True)
 if result.returncode or b'ERROR:' in log or b'AVATAR_DRIVER_TEST PASS' not in log: raise RuntimeError('Avatar check failed')
 for image_name in ['neutral','happy','sad','right-lock','left-lock','game-hud']:
  subprocess.run(['scp','books-server:'+remote+'/'+folder+'/'+image_name+'.png',str(a.output/(image_name+'.png'))],check=True)
 (a.output/'evidence.json').write_text(json.dumps({'snapshot':snapshot,'sdk_fixture_sha256':d['sha256'],
  'renderer':a.renderer,'software_render':True,'test_profile':True},indent=2)+'\n')
finally:
 subprocess.run(['ssh','books-server',shlex.join(['docker','rm','-f',name])],capture_output=True,timeout=20)
