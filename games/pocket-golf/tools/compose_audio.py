#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Original 'A Little Green' score and cues. No sampled music or borrowed melody.

Offline only: Python + numpy + soundfile. The game plays compressed Ogg files.
32 bars at 88 BPM, electric-piano chords, plucked melody, bass and brushed rhythm.
Loop tails wrap into the first bar; three little cadences share its instrumentation.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
import soundfile as sf

RATE = 44100
BEAT = 60 / 88
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(25102026)

def tone(note, seconds, voice='pluck'):
    t = np.arange(round(seconds * RATE)) / RATE
    f = 440 * 2 ** ((note - 69) / 12)
    if voice == 'keys':
        signal = (np.sin(2*np.pi*f*t + .7*np.sin(2*np.pi*f*2*t)*np.exp(-t*6))
                  + .16*np.sin(2*np.pi*f*3*t)*np.exp(-t*3))
        envelope = (1-np.exp(-t*150))*np.exp(-t*1.9)
    elif voice == 'bass':
        signal = np.sin(2*np.pi*f*t) + .24*np.sin(2*np.pi*f*2*t)*np.exp(-t*5)
        envelope = (1-np.exp(-t*100))*np.exp(-t*2.4)
    else:
        # Rounded plucked reed/wood tone, gentle transient and bell-like overtone.
        signal = (np.sin(2*np.pi*f*t) + .28*np.sin(2*np.pi*f*2*t)*np.exp(-t*7)
                  + .12*np.sin(2*np.pi*f*3*t)*np.exp(-t*10))
        envelope = (1-np.exp(-t*400))*np.exp(-t*3.8)
    return signal * envelope * np.minimum((seconds-t)/.06, 1).clip(0, 1)

def add(dst, sample, start, gain=1, pan=0, wrap=False):
    stereo = sample[:,None] * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)]) * gain
    at = round(start*RATE)
    if wrap:
        indices = (np.arange(len(sample))+at) % len(dst)
        np.add.at(dst, indices, stereo)
    elif at < len(dst):
        n = min(len(sample), len(dst)-at)
        dst[at:at+n] += stereo[:n]

def space(data, loop=False):
    dry = data.copy()
    for delay, amount in [(.071,.10),(.113,.08),(.191,.055),(.293,.035)]:
        n=round(delay*RATE)
        if loop: data += np.roll(dry[:,::-1],n,axis=0)*amount
        else: data[n:] += dry[:-n,::-1]*amount
    return data

report={}
def save(name, data, loop=False):
    data=space(data,loop)
    data *= .76 / max(.76, float(np.max(np.abs(data))))
    path=OUT/(name+'.ogg')
    # Bound each encoder call (also avoids large Vorbis stack buffers on Windows).
    with sf.SoundFile(path,'w',samplerate=RATE,channels=2,format='OGG',subtype='VORBIS') as stream:
        for at in range(0,len(data),4096):stream.write(data[at:at+4096])
    decoded,_=sf.read(path)
    report[name]={'seconds':round(len(data)/RATE,3),'peak':round(float(np.max(np.abs(decoded))),5),
                  'rms':round(float(np.sqrt(np.mean(decoded**2))),5),
                  'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

# A freshly authored, spacious call-and-response tune. Section B answers A higher.
chords=[([62,66,69,73],38),([59,62,66,69],35),([60,64,67,71],36),([57,61,64,67],33),
        ([55,59,62,66],31),([64,67,71,74],40),([57,62,64,67],33),([57,61,64,67],33)]
melodies=[[(0,78),(1.5,76),(2.5,73)],[(.5,74),(1.25,73),(2.5,69)],
          [(0,76),(1.5,79),(3,76)],[(.75,73),(2,71),(3,69)],
          [(0,74),(1,71),(2.5,69)],[(.5,71),(1.5,74),(3,76)],
          [(0,74),(1.75,73)],[(.5,71),(2.5,69)]]
music=np.zeros((round(32*4*BEAT*RATE),2))
for bar in range(32):
    chord, root=chords[bar%8]; start=bar*4*BEAT
    for off, level in [(0,.095),(1.5,.06),(2.75,.075)]:
        for i,note in enumerate(chord):
            add(music,tone(note,1.65,'keys'),start+(off+i*.025)*BEAT,level,(-.32+i*.18),True)
    for off,note,level in [(0,root,.23),(1.75,root+12,.11),(2.5,root+7,.16)]:
        add(music,tone(note,.9,'bass'),start+off*BEAT,level,0,True)
    for off,note in melodies[bar%8]:
        if 16<=bar<24: note += 12 if bar%2==0 else 0
        if bar>=24 and off>2: continue  # let the final phrase breathe into the loop
        add(music,tone(note,1.5),start+(off+.02)*BEAT,.20 if bar<16 else .17,.22,True)
    for beat in range(4):
        t=np.arange(round(.09*RATE))/RATE
        noise=rng.normal(0,1,len(t)); noise=np.concatenate(([0],np.diff(noise)))
        sample=noise*np.exp(-t*65)*(1-np.exp(-t*1200))
        add(music,sample,start+(beat+.54)*BEAT,.012,-.45,True)
        if beat in (1,3):
            add(music,tone(42,.12,'bass'),start+beat*BEAT,.075,.35,True)
save('little-green',music,True)

for name,notes in [('cup-jingle',[74,78,81,78]),('ace-jingle',[74,78,81,86,85,86]),
                   ('round-jingle',[69,73,76,78,74])]:
    data=np.zeros((round(3.0*RATE),2))
    for i,n in enumerate(notes):add(data,tone(n,1.2),i*.19,.24,(i%2-.5)*.3)
    for n in [50,62,66,69,73]:add(data,tone(n,1.6,'keys'),len(notes)*.19,.10)
    save(name,data)

# Soft textured rolling bed and a small hollow cup drop; no synthetic speech.
for name,seconds in [('roll',2.0),('sand',.22),('cup',.38),('ui',.09)]:
    t=np.arange(round(seconds*RATE))/RATE
    if name=='roll':
        noise=rng.normal(0,1,len(t))
        sample=np.convolve(noise,np.ones(22)/22,mode='same')*.09
        sample*=.7+.15*np.sin(2*np.pi*3*t)+.15*np.sin(2*np.pi*7*t)
        edge=round(.03*RATE);sample[:edge]*=np.linspace(0,1,edge);sample[-edge:]*=np.linspace(1,0,edge)
    elif name=='sand': sample=rng.normal(0,1,len(t))*.10*np.exp(-t*20)*(1-np.exp(-t*500))
    elif name=='cup': sample=(np.sin(2*np.pi*430*t)+.35*np.sin(2*np.pi*760*t))*np.exp(-t*19)*.35*(1-np.exp(-t*1000))
    else: sample=tone(81,seconds)*.17
    data=np.zeros((len(t),2));add(data,sample,0)
    save(name,data,name=='roll')
(OUT/'original-provenance.json').write_text(json.dumps({'title':'A Little Green','composer':'TrainerOS project',
    'license':'GPL-3.0-or-later','original':True,'source':'../../tools/compose_audio.py',
    'note':'Original melody, arrangement and synthesis; no Animal Crossing audio or melodic transcription.',
    'sample_rate':RATE,'files':report},indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
