#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build only on the existing server, in immutable source snapshots. No publishing."""
import argparse, hashlib, io, json, pathlib, shlex, subprocess, tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
REMOTE = '/home/abysscloud/traineros-micro-rally'
IMAGE = 'traineros-golf-backend-ci:20261025'
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=pathlib.Path, required=True)
parser.add_argument('--tests', action='store_true')
TESTS=['county_navigation_test.gd','county_route_test.gd','royale_storm_test.gd','royale_test.gd','royale_battle_test.gd','royale_network_test.gd','arena_test.gd','arena_battle_test.gd','arena_network_test.gd','tire_test.gd','menu_test.gd','nord_test.gd','nord_race_test.gd','haptics_test.gd','pass_test.gd','pass_race_test.gd','transmission_test.gd','driver_feedback_test.gd','difficulty_race_test.gd','difficulty_test.gd','difficulty_behavior_test.gd','scenery_test.gd','quarry_test.gd','quarry_race_test.gd','physics_test.gd','weapon_test.gd','surface_test.gd','drive_test.gd','journey_test.gd','weather_test.gd','timeline_test.gd','bot_test.gd','recovery_test.gd','race_test.gd','network_test.gd','cup_test.gd','cup_journey_test.gd','cup_race_test.gd','audio_feedback_test.gd','audio_mix_test.gd']
parser.add_argument('--test', action='append', choices=TESTS)
parser.add_argument('--export', action='store_true')
parser.add_argument('--bake-county', action='store_true', help='Regenerate navigation with Godot on server and download only the data asset')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
files = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in sorted(ROOT.rglob('*'))
         if p.is_file() and not any(x in p.relative_to(ROOT).parts for x in ('.godot','__pycache__','evidence','build','dist'))
         and p.suffix != '.png'}  # PNG assets are added explicitly below.
for p in (ROOT/'assets').rglob('*.png'): files[p.relative_to(ROOT).as_posix()] = p.read_bytes()
digest = {name: hashlib.sha256(data).hexdigest() for name,data in files.items()}
identity = hashlib.sha256(json.dumps(digest, sort_keys=True).encode()).hexdigest()[:16]
project = f'{REMOTE}/snapshots/{identity}'
exports = f'{REMOTE}/exports/{identity}'
archive = args.output/'source.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
    for name,data in files.items():
        entry=tarfile.TarInfo(name); entry.size=len(data); entry.mode=0o644; tar.addfile(entry,io.BytesIO(data))

def remote(argv, log):
    command=' '.join(shlex.quote(str(x)) for x in argv)
    result=subprocess.run(['ssh','books-server',command],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=1800 if log=='nord_race_test.gd.log' else 600 if log in ['pass_race_test.gd.log','nord_test.gd.log','royale_storm_test.gd.log','royale_battle_test.gd.log','royale_test.gd.log','royale_network_test.gd.log'] else 300)
    (args.output/log).write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR:' in result.stdout+result.stderr or 'ERROR:' in result.stdout+result.stderr:
        raise RuntimeError(f'{log}: '+(result.stdout+result.stderr)[-5000:])
    return result.stdout

remote(['mkdir','-p',project,exports],'prepare.log')
subprocess.run(['scp',str(archive),'books-server:'+REMOTE+'/source-upload.tar.gz'],check=True)
remote(['tar','-xzf',REMOTE+'/source-upload.tar.gz','-C',project],'extract.log')
base=['docker','run','--rm','--network','none','--user','1000:1000','-e','HOME=/tmp',
      '-v',REMOTE+':/work','-v','/home/abysscloud/traineros-golf-backend-20261025/templates:/templates:ro',
      IMAGE,'/work/engine/godot','--headless','--path','/work/snapshots/'+identity]
remote(base+['--editor','--import','--quit'],'import.log')
if args.bake_county:
    remote(base+['--script','res://tests/county_navigation_test.gd','--','--navigation-output=/work/exports/'+identity+'/navigation.json'],'county_navigation_test.gd.log')
    subprocess.run(['scp','books-server:'+exports+'/navigation.json',str(ROOT/'assets/deadwater/navigation.json')],check=True)
if args.tests or args.test:
    for test in (TESTS if args.tests else args.test):
        if (ROOT/'tests'/test).exists():
            extra=['--','--mix-output=/work/exports/'+identity+'/audio-preview.wav'] if test=='audio_mix_test.gd' else []
            test_base=base
            if test=='scenery_test.gd':
                # Dummy headless rendering does not retain MultiMesh transforms.
                test_base=['docker','run','--init','--rm','--network','none','--user','1000:1000',
                    '-e','HOME=/tmp','-e','LIBGL_ALWAYS_SOFTWARE=1','-e','XDG_RUNTIME_DIR=/tmp',
                    '-v',REMOTE+':/work','traineros-rally-render-ci:20261028','xvfb-run','-a',
                    '/work/engine/godot','--path','/work/snapshots/'+identity,'--audio-driver','Dummy',
                    '--rendering-method','gl_compatibility']
            print(remote(test_base+['--fixed-fps','60','--script','res://tests/'+test]+extra,test+'.log')[-1000:],flush=True)
if args.export:
    for preset,name in [('Windows','micro-rally.exe'),('Linux ARM64','micro-rally.arm64'),('Linux x86_64','micro-rally.x86_64')]:
        remote(base+['--export-release',preset,'/work/exports/'+identity+'/'+name],'export-'+name+'.log')
        print('EXPORTED',name,flush=True)
manifest={'engine':'4.7.2.stable.official.ed1daf0bf','source_snapshot':identity,'source_sha256':digest}
(args.output/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('SOURCE',identity,flush=True)
