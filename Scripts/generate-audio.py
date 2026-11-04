"""Original Glintwake audio. No recordings, samples, models or third-party assets.

Reproduce from the repository root: python3 Scripts/generate-audio.py
Effects use soft sine partials and seeded filtered noise. The 48-second stereo
ambient composition uses periodic envelopes and integer-period oscillators so
that AVAudioPlayer can loop it without a discontinuity.
"""
from pathlib import Path
import array
import math
import random
import wave

RATE = 22050
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "Resources" / "Audio"
OUT.mkdir(parents=True, exist_ok=True)


def write(name, samples, channels=1):
    peak = max(abs(v) for v in samples)
    assert peak < 0.95, (name, peak)
    pcm = array.array("h", (round(v * 32767) for v in samples))
    import sys
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / (name + ".wav")), "wb") as output:
        output.setparams((channels, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())
    print(f"{name}: {len(samples) / channels / RATE:.2f}s; peak {peak:.3f}")


def bell(t, start, frequency, amplitude, decay=7):
    t -= start
    if t < 0:
        return 0
    return amplitude * (1 - math.exp(-t * 90)) * math.exp(-t * decay) * (
        math.sin(TAU * frequency * t) + 0.18 * math.sin(TAU * frequency * 2 * t)
    )


specs = {
    "crystal": (0.7, [(0, 784, 0.22), (0.10, 1174.66, 0.12)]),
    "undo": (0.4, [(0, 523.25, 0.13), (0.09, 392, 0.12)]),
    "failure": (0.65, [(0, 164.81, 0.18), (0.12, 146.83, 0.16)]),
    "win": (1.3, [(0, 392, 0.18), (0.14, 493.88, 0.18), (0.28, 587.33, 0.18), (0.42, 784, 0.17)]),
}
for name, (duration, notes) in specs.items():
    result = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        fade = min(1, (duration - t) / 0.05)
        result.append(fade * sum(bell(t, start, hz, gain) for start, hz, gain in notes))
    write(name, result)

rng = random.Random(7341)
filtered = 0
slide = []
for i in range(round(0.24 * RATE)):
    t = i / RATE
    filtered = 0.85 * filtered + 0.15 * rng.uniform(-1, 1)
    envelope = math.sin(math.pi * t / 0.24) ** 2
    slide.append(envelope * (0.06 * filtered + 0.055 * math.sin(TAU * (180 * t + 180 * t * t))))
write("slide", slide)

duration = 48
# Four overlapping, airy chord voicings, one every twelve seconds.
chords = [[164.81, 246.94, 369.99], [146.83, 220, 329.63],
          [130.81, 196, 293.66], [146.83, 246.94, 369.99]]
result = array.array("f")
for i in range(duration * RATE):
    t = i / RATE
    left = right = 0
    for chord_index, chord in enumerate(chords):
        distance = ((t - chord_index * 12 + 24) % duration) - 24
        if abs(distance) >= 12:
            continue
        envelope = (0.5 + 0.5 * math.cos(math.pi * distance / 12)) ** 2
        for j, hz in enumerate(chord):
            frequency = round(hz * duration) / duration
            tone = math.sin(TAU * frequency * t + j * 0.7)
            tone += 0.12 * math.sin(TAU * frequency * 2 * t + j * 0.2)
            pan = 0.5 + 0.25 * math.sin(TAU * t / duration + chord_index + j)
            amplitude = 0.07 * envelope * tone
            left += amplitude * math.sqrt(1 - pan)
            right += amplitude * math.sqrt(pan)
    result.extend([left, right])
write("ambience", result, channels=2)
