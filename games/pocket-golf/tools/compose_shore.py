#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Original Pocket Golf score Harbour Steps, shore break and gallery applause."""
from array import array
from functools import lru_cache
from math import exp, sin, tau
from pathlib import Path
import random
import subprocess

RATE = 24000
BEAT = 0.625
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
rng = random.Random(936)

def write(name, channels):
    pcm = array('h')
    for frame in zip(*channels):
        pcm.extend(int(max(-1, min(1, value)) * 32767) for value in frame)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(RATE),
                    '-ac', str(len(channels)), '-i', '-', '-c:a', 'libvorbis', '-q:a', '4',
                    str(OUT / (name + '.ogg'))], input=pcm.tobytes(), check=True)

@lru_cache(None)
def note(pitch, voice):
    hz = 440 * 2 ** ((pitch - 69) / 12)
    duration, decay = {'pan': (1.18, 3.8), 'strings': (.56, 6.3), 'bass': (.83, 3.4)}[voice]
    out = array('f')
    for i in range(round(RATE * duration)):
        t = i / RATE
        p = tau * hz * t
        overtone = sin(2.01*p)*.26 + sin(3.98*p)*.13*exp(-11*t)
        if voice == 'pan':
            overtone += .34*sin(2.42*p)*exp(-8*t)
        out.append((sin(p)+overtone)*(1-exp(-130*t))*exp(-decay*t)*min(1,(duration-t)/.08))
    return out

def music():
    size = round(16 * 4 * BEAT * RATE)
    left, right = (array('f', [0])*size for _ in range(2))
    def play(bar, beat, pitch, voice, gain, pan):
        start = round((bar*4+beat)*BEAT*RATE)
        for i, v in enumerate(note(pitch,voice)):
            at = (start+i) % size
            left[at] += gain*(1-pan)*v
            right[at] += gain*(1+pan)*v
    chords = [(50,57,61,66),(47,54,57,62),(43,55,59,62),(45,55,61,64),
              (42,54,57,61),(47,54,62,66),(43,55,59,64),(45,57,61,64)]
    tune = [(73,69,66),(69,71,74),(71,67,69),(73,71,64),
            (69,73,76),(74,71,66),(67,69,71),(73,69,62)]
    for bar in range(16):
        root, *chord = chords[bar%8]
        for beat, bass in [(0,root-12),(2.5,root-5)]:
            play(bar,beat,bass,'bass',.105,0)
        for off in (.75,1.5,3.25):
            for j, n in enumerate(chord):
                play(bar,off+j*.026,n,'strings',.042,-.24)
        for j, n in enumerate(tune[bar%8]):
            off = (.25,1.75,2.5)[j] if bar%2==0 else (.5,1.25,3)[j]
            play(bar,off,n+(12 if 8<=bar<12 and j==2 else 0),'pan',.105,.16)
    write('harbour-steps', [left,right])

def surf():
    channels = []
    for side in range(2):
        sound = array('f')
        slow = fast = 0.0
        for i in range(RATE*18):
            t = i/RATE
            white = rng.uniform(-1,1)
            slow += .048*(white-slow)
            fast += .32*(white-fast)
            swell = (.5-.5*sin(tau*t/6+side*.21+.62*sin(tau*t/18)))**2
            sound.append((slow*.8+fast*.20)*(.20+.72*swell))
        # Crossfade the end into the start with independent noise on each shore.
        n=RATE//2
        for i in range(n):
            sound[i]=sound[-n+i]*(1-i/n)+sound[i]*(i/n)
        channels.append(sound[:-n])
    write('shore-break',channels)

def applause():
    channels=[array('f',[0])*(RATE*2) for _ in range(2)]
    for fan in range(5):
        at = rng.uniform(.02,.28)
        pan = rng.uniform(-.6,.6)
        for clap in range(4):
            start = int(at*RATE)
            low = 0.0
            for i in range(int(.11*RATE)):
                t=i/RATE
                white=rng.uniform(-1,1)
                low+=.28*(white-low)
                snap=(white*.21+low)*exp(-47*t)*min(1,t*1100)*.23
                channels[0][start+i]+=snap*(1-pan)
                channels[1][start+i]+=snap*(1+pan)
            at += rng.uniform(.22,.33)
    write('gallery-claps',channels)

if __name__ == '__main__':
    music()
    surf()
    applause()
