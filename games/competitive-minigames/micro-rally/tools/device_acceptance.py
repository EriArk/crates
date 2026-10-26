#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicitly authorized device delivery: public catalogue, installer and menu.
Run on a handheld with a selected Trainer; never replaces the shell or helpers.
"""
from pathlib import Path
import argparse,hashlib,json,os,socket,subprocess,sys,time
p=argparse.ArgumentParser();p.add_argument('stage',type=Path);p.add_argument('--settle',type=int,default=18);p.add_argument('--skip-install',action='store_true');a=p.parse_args()
assert 5<=a.settle<=55
stage=a.stage.resolve();stage.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,'/var/opt/traineros/crates')
import catalogue
root=Path.home()/'.local/share/TrainerOS/TrainerOS/crates'
before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'active').glob('*.json') if p.stem!='micro-rally'}
old_objects={p.name for p in (root/'objects').iterdir()}
old_data={str(p.relative_to(root/'data')) for p in (root/'data').rglob('*') if p.is_file()}
envelope,kind=catalogue.sync(root/'catalogue')
record=next(r for r in envelope['signed']['packages'] if r['id']=='micro-rally' and r['version']=='0.1.0' and r['architecture']=='aarch64')
assert record['title']=='Micro Rally (альфа)'
if not a.skip_install:
 with (stage/'install.log').open('wb') as log:
  subprocess.run(['/usr/bin/python3','/var/opt/traineros/crates/installer.py',str(root/'catalogue/current.json'),str(root),'install','micro-rally','0.1.0'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
receipt=json.loads((root/'active/micro-rally.json').read_text());assert receipt['sha256']==record['sha256']
assert all((root/'active'/name).exists() and hashlib.sha256((root/'active'/name).read_bytes()).hexdigest()==digest for name,digest in before.items())
assert old_objects<={p.name for p in (root/'objects').iterdir()}
assert old_data<={str(p.relative_to(root/'data')) for p in (root/'data').rglob('*') if p.is_file()}
report={'title':record['title'],'version':record['version'],'catalogue_revision':envelope['signed']['revision'],'download_url':record['url'],'sha256':record['sha256'],'installed':True,'other_receipts_unchanged':True,'old_objects_retained':True,'old_data_files_retained':True}
(stage/'installation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('PUBLIC DOWNLOAD AND INSTALL PASS',flush=True)
pid=subprocess.check_output(['pgrep','-xo','traineros'],text=True).strip()
raw=dict(s.split('=',1) for s in Path('/proc',pid,'environ').read_text().split('\0') if '=' in s)
env=dict(os.environ)
for key in ['DISPLAY','XAUTHORITY','XDG_RUNTIME_DIR','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS']:
 if key in raw:env[key]=raw[key]
info=json.loads((Path.home()/'.local/share/traineros/platform-v1/endpoint.json').read_text())
with socket.create_connection((info['host'],info['port']),timeout=5) as peer:
 packet={'id':'check','method':'hello','params':{'protocol':1,'token':info['token'],'app':'org.traineros.rally-delivery-check'}}
 peer.sendall((json.dumps(packet)+'\n').encode());context=json.loads(peer.makefile().readline())['result']['context']
assert context.get('profile'),'Select/unlock a Trainer before launch acceptance'
owner=hashlib.sha256(context['profile'].encode()).hexdigest()
with (stage/'launch.log').open('wb') as log:
 proc=subprocess.Popen(['/usr/bin/python3','/var/opt/traineros/crates/launch.py',str(root),'micro-rally',owner],env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 try:
  time.sleep(a.settle)
  assert proc.poll() is None,'Game exited before menu capture'
  capture_env=dict(env,WAYLAND_DISPLAY=raw.get('GAMESCOPE_WAYLAND_DISPLAY',raw.get('WAYLAND_DISPLAY','')))
  subprocess.run(['gamescopectl','screenshot',str(stage/'menu.png'),'4'],env=capture_env,capture_output=True,check=True,timeout=10)
  time.sleep(1)
 finally:
  if proc.poll() is None:proc.terminate()
  proc.wait(timeout=15)
text=(stage/'launch.log').read_text(errors='replace')
assert not any(s in text for s in ['SCRIPT ERROR:','Parse Error:','error while loading shared libraries','VK_ERROR_DEVICE_LOST','Failed to create Vulkan']),text
assert Path('/proc',pid).exists(),'Shell stopped during launch check'
report.update(menu_process_live=True,managed_stop=True,shell_retained=True,renderer='Compatibility' if 'Compatibility' in text else 'Mobile' if 'Mobile' in text else 'unknown')
(stage/'acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('MANAGED MENU/STOP PASS',report['renderer'],flush=True)
