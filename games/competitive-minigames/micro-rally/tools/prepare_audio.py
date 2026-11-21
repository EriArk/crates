#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run on the build server with ffmpeg; download only from authors' asset pages."""
import hashlib,json,pathlib,subprocess,urllib.request,zipfile
ROOT=pathlib.Path('/audio'); OUT=ROOT/'prepared'; OUT.mkdir(exist_ok=True)
SOURCES={
 'race.wav':('Umplix','https://opengameart.org/content/super-wreck-roadway','https://opengameart.org/sites/default/files/super_wreck_roadway_loop.wav'),
 'menu.wav':('Umplix','https://opengameart.org/content/rock-theme-3','https://opengameart.org/sites/default/files/rock_theme_3_loop_.wav'),
 'impact.zip':('Kenney','https://kenney.nl/assets/impact-sounds','https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip'),
 'scifi.zip':('Kenney','https://kenney.nl/assets/sci-fi-sounds','https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip'),
 'jingles.zip':('MintoDog','https://opengameart.org/content/racing-game-finish-jingle','https://opengameart.org/sites/default/files/ogg_racing_game_finish_jingle.zip')}
manifest={'license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','sources':{},'files':{}}
for name,(author,page,url) in SOURCES.items():
 p=ROOT/name
 if not p.exists(): urllib.request.urlretrieve(url,p)
 manifest['sources'][name]={'author':author,'page':page,'download':url,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
for name in ['race','menu']:
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(ROOT/(name+'.wav')),'-af','loudnorm=I=-18:TP=-3:LRA=9','-ar','44100','-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],check=True)
 manifest['files'][name+'.ogg']={'source':name+'.wav','processing':'ffmpeg loudnorm I=-18 TP=-3 LRA=9; Vorbis q4 44100 Hz'}
choices={'impact0.ogg':('impact.zip','Audio/impactMetal_medium_000.ogg'),
 'impact1.ogg':('impact.zip','Audio/impactMetal_medium_002.ogg'),
 'wreck.ogg':('scifi.zip','Audio/explosionCrunch_000.ogg'),
 'shield.ogg':('scifi.zip','Audio/forceField_000.ogg'),
 'win.ogg':('jingles.zip','ogg_Racing Game Finish & Jingle/Race Finish Best/Race Finish Best (Jingle).ogg'),
 'finish.ogg':('jingles.zip','ogg_Racing Game Finish & Jingle/Race Finish Good/Race Finish Good (Jingle).ogg'),
 'dnf.ogg':('jingles.zip','ogg_Racing Game Finish & Jingle/Race Finish Bad/Race Finish Bad (Jingle).ogg'),
 'final_lap.ogg':('jingles.zip','ogg_Racing Game Finish & Jingle/Final Lap (Jingle).ogg')}
for name,(archive,member) in choices.items():
 with zipfile.ZipFile(ROOT/archive) as z:
  (OUT/name).write_bytes(z.read(member))
 manifest['files'][name]={'source':archive,'member':member,'processing':'unmodified Ogg file'}
for archive in ['impact','scifi']:
 with zipfile.ZipFile(ROOT/(archive+'.zip')) as z: (OUT/(archive+'-LICENSE.txt')).write_bytes(z.read('License.txt'))
for name,entry in manifest['files'].items():
 p=OUT/name; entry['sha256']=hashlib.sha256(p.read_bytes()).hexdigest(); entry['bytes']=p.stat().st_size
 info=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(p)],capture_output=True,text=True,check=True)
 entry['seconds']=float(json.loads(info.stdout)['format']['duration'])
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:round(v['seconds'],2) for k,v in manifest['files'].items()}))
