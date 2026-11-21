# SPDX-License-Identifier: GPL-3.0-or-later
"""Render the original Bazaar score and Foley. Python 3 + ffmpeg, no sample bank."""
from array import array
from functools import lru_cache
from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
import subprocess
import wave

OUT = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000
TAU = 2 * pi
rng = Random(2814)


def pcm(samples):
    values = array("h", (round(32767 * max(-1, min(1, s))) for s in samples))
    import sys
    if sys.byteorder != "little":
        values.byteswap()
    return values.tobytes()


def effect(name, samples):
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", ""))
        f.writeframes(pcm(samples))


@lru_cache(maxsize=512)
def note(instrument, midi, length):
    freq = 440 * 2 ** ((midi - 69) / 12)
    result = array("f")
    for i in range(int(RATE * length)):
        t = i / RATE
        a = TAU * freq * t
        if instrument == "pipe":
            a += .035 * sin(TAU * 5 * t)
            tone = sin(a) + .19 * sin(2*a) + .065 * sin(3*a)
            env = min(1, t/.065) * min(1, (length-t)/.11) * (.85+.09*sin(13*t))
        elif instrument == "bass":
            tone = sin(a) + .26*sin(2*a) + .07*sin(3*a)
            env = min(1, t/.012) * exp(-3.8*t)
        else:
            tone = sin(a)+.42*sin(2*a+.1)+.2*sin(3*a)+.13*exp(-9*t)*sin(6*a)
            env = min(1,t/.005)*exp(-4.5*t)
        result.append(tone * env * min(1, (length-t)/.035))
    return result


def music():
    # A small waltz in D. The reed answers the off-beat mandolin in four phrases.
    beat = .62
    harmony = [(50,57,62,66),(45,57,61,64),(47,54,59,62),(43,55,59,62),
               (50,54,57,62),(40,55,59,64),(45,55,61,64),(50,54,57,62)]
    phrases = [
        [(66,1),(69,.5),(71,1.5)],[(69,1.5),(64,1.5)],[(62,.5),(66,.5),(69,2)],[(67,2),(0,1)],
        [(66,1),(64,.5),(62,1.5)],[(64,1),(67,1),(71,1)],[(69,2),(61,1)],[(62,2),(0,1)],
        [(0,.5),(69,.5),(74,1),(73,1)],[(71,1),(69,2)],[(66,1.5),(62,.5),(66,1)],[(67,2.5),(0,.5)],
        [(69,1),(66,1),(62,1)],[(67,1.5),(64,1.5)],[(61,.5),(64,.5),(69,2)],[(62,3)]]
    frames = round(32*3*beat*RATE)
    left, right = [array("f",[0])*frames for _ in range(2)]

    def mix(start, samples, gain, pan):
        offset = round(start*RATE)
        for i, val in enumerate(samples):
            j = (offset+i) % frames
            left[j] += val*gain*(1-pan)
            right[j] += val*gain*pan

    for bar in range(32):
        root, low, mid, high = harmony[bar%8]
        start = 3*beat*bar
        mix(start, note("bass",root,1.05), .35, .48)
        for tick, pitch in enumerate([low,high,mid,high]):
            onset = [.5,1,1.65,2.5][tick]
            mix(start+beat*onset+rng.uniform(-.008,.008),note("pluck",pitch,.88),
                (.23 if tick%2 else .18)*rng.uniform(.88,1.07),.33)
        cursor = .012
        for pitch, duration in phrases[bar%16]:
            if pitch:
                mix(start+cursor,note("pipe",pitch,max(.14,duration*beat-.075)),.21,.59)
            cursor += duration*beat
        if bar >= 16 and bar%4 in (1,3):
            mix(start+beat*2,note("pluck",high+12,.75),.14,.7)
    # Wrap the stereo room reflection around the loop boundary.
    def stereo():
        for i in range(frames):
            yield .94*tanh(left[i]+.18*right[i-2839])
            yield .94*tanh(right[i]+.16*left[i-3371])
    subprocess.run(["ffmpeg","-loglevel","error","-y","-f","s16le","-ar",str(RATE),
                    "-ac","2","-i","pipe:0","-map_metadata","-1","-c:a","libvorbis","-q:a","4",
                    str(OUT/"awning_waltz.ogg")],input=pcm(stereo()),check=True)


def footsteps():
    # Heel and toe share the same ground, with separate impacts and a scuff.
    for kind, body, grit, decay in [("stone",123,.18,24),("grass",72,.51,14),
                                    ("sand",59,.37,10),("metal",186,.12,22)]:
        for variation in range(3):
            samples = []
            low = phase = 0.
            fundamental = body*rng.uniform(.93,1.07)
            for i in range(int(RATE*.34)):
                t=i/RATE
                noise=rng.uniform(-1,1)
                low += (.19 if kind in ("sand","grass") else .44)*(noise-low)
                heel = exp(-decay*t)
                toe = max(0,t-.061-.004*variation)
                scuff = min(1,toe/.016)*exp(-decay*.8*toe)
                phase += TAU*fundamental*(.83+.52*heel)/RATE
                val = .44*heel*sin(phase)+grit*(heel+scuff)*low
                if kind=="metal":
                    val += .18*exp(-18*t)*sin(phase*3.67)+.09*exp(-23*t)*sin(phase*5.41)
                if kind=="stone":
                    val += .23*(noise-low)*(exp(-180*t)+scuff**7)
                if kind=="grass":
                    val += .2*(noise-low)*scuff*(.5+.5*sin(255*t)**2)
                samples.append(val*min(1,t/.003)*min(1,(.34-t)/.027))
            effect(f"{kind}{variation}",samples)


def fauna():
    # Start, duration, start/end Hz and amplitude of each gesture.
    calls = {"Pigeon":[(0,.28,370,280,.6),(.35,.26,320,275,.45)],
             "Birb":[(0,.12,1300,2100,.45),(.18,.15,1800,1080,.52)],
             "Frog":[(0,.24,160,91,.65),(.31,.17,147,96,.48)],
             "Bunny":[(0,.11,830,1060,.39),(.17,.085,780,900,.3)],
             "Yeti":[(0,.49,141,82,.55)],"Dino":[(0,.23,435,650,.53),(.28,.19,630,320,.44)]}
    for species, gestures in calls.items():
        samples = array("f",[0])*round((gestures[-1][0]+gestures[-1][1]+.02)*RATE)
        for start,duration,first,last,amp in gestures:
            phase = 0.
            for i in range(int(duration*RATE)):
                t=i/RATE
                phase+=TAU*(first+(last-first)*t/duration)*(1+.025*sin(44*t))/RATE
                env=sin(pi*t/duration)**1.4
                tone=sin(phase)+.26*sin(2*phase)+.09*sin(3*phase)
                if species in ("Frog","Yeti"):
                    tone *= .65+.35*sin(TAU*27*t)
                samples[round(start*RATE)+i]+=amp*tone*env
        effect(species.lower(),samples)


def voices():
    # Short voiced syllables. Harmonics pass through two vowel formants.
    for n,(v1,v2) in enumerate([(700,1150),(340,2100),(410,840),(480,1450),(550,1900),(800,1350)]):
        samples=[]
        f0=195+7*n
        for i in range(int(.105*RATE)):
            t=i/RATE
            phase=TAU*f0*(t+.0008*sin(32*t))
            harm=0.
            for h in range(1,16):
                hz=h*f0
                weight=.33*exp(-((hz-v1)/185)**2)+.18*exp(-((hz-v2)/290)**2)
                harm+=sin(h*phase)*(weight+.22/h**1.8)
            samples.append(.62*harm*sin(pi*t/.105)**1.35)
        effect("voice"+str(n),samples)


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    music()
    footsteps()
    fauna()
    voices()
