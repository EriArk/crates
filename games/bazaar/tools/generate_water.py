#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Original, deterministic four-second fountain bed; no third-party recordings."""
from pathlib import Path
import math, random, struct, wave
rng = random.Random(71403)
rate, count = 22050, 22050 * 4
samples, low, slow = [], 0.0, 0.0
for i in range(count):
    white = rng.uniform(-1.0, 1.0)
    low += 0.19 * (white - low)
    slow += 0.012 * (white - slow)
    ripple = 0.022 * math.sin(2 * math.pi * 730 * i / rate + math.sin(2 * math.pi * 6 * i / rate))
    samples.append((low - slow) * 0.8 + ripple)
# Linear overlap creates a continuous seam without a silent gap.
fade = 2048
for i in range(fade):
    weight = i / (fade - 1)
    samples[i] = samples[count-fade+i] * (1-weight) + samples[i] * weight
samples = samples[:count-fade]
path = Path(__file__).resolve().parents[1] / 'assets/audio/fountain.wav'
with wave.open(str(path), 'wb') as out:
    out.setnchannels(1); out.setsampwidth(2); out.setframerate(rate)
    out.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, s)) * 32767)) for s in samples))
print(path.name, len(samples), 'samples')
