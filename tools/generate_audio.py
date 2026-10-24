"""Generate original, dependency-free placeholder ambience and SFX."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050


def save(name, length, sample):
    rng = random.Random(42)
    count = int(length * RATE)
    data = bytearray()
    for i in range(count):
        t = i / RATE
        value = max(-0.95, min(0.95, sample(t, length, rng)))
        data.extend(struct.pack("<h", int(value * 32767)))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, count, "NONE", "not compressed"))
        out.writeframes(data)


def tone(freq, end=None, noise=0.0):
    def sample(t, duration, rng):
        envelope = min(1.0, t / 0.012) * (1 - t / duration) ** 2
        phase = 2 * math.pi * (freq * t + ((end or freq) - freq) * t * t / (2 * duration))
        return envelope * (math.sin(phase) * 0.35 + rng.uniform(-1, 1) * noise)
    return sample


def chord(notes):
    return lambda t, d, rng: min(1, t / 0.03) * (1 - t / d) ** 2 * sum(math.sin(2 * math.pi * f * t) for f in notes) / len(notes) * 0.45


def ambience(t, duration, rng):
    # Integer cycles over 20 seconds keep the drone loop continuous.
    drone = math.sin(2 * math.pi * 55 * t) * 0.14 + math.sin(2 * math.pi * 82.5 * t) * 0.07
    drone += math.sin(2 * math.pi * 110 * t) * 0.035
    breath = 0.65 + math.sin(2 * math.pi * t / 10) * 0.25
    bell_time = t % 4
    bell = math.sin(2 * math.pi * [220, 261.65, 293.65, 329.65, 261.65][int(t / 4)] * bell_time) * math.exp(-bell_time * 2) * min(1, bell_time * 25) * 0.07
    return drone * breath + bell + rng.uniform(-1, 1) * 0.015


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, duration, synth in [
        ("projectile", .12, tone(650, 330)),
        ("hit", .1, tone(160, 65, .1)),
        ("enemy_death", .24, tone(190, 45, .08)),
        ("pickup", .15, tone(880, 1320)),
        ("level_up", .7, chord([440, 554.37, 659.25])),
        ("player_damage", .3, tone(120, 50, .16)),
        ("boss_arrival", 1.6, chord([55, 58.27, 82.5])),
        ("boss_shot", .4, tone(150, 70, .04)),
        ("victory", 2.0, chord([261.63, 329.63, 392, 523.25])),
        ("death", 1.4, chord([110, 130.81, 164.81])),
        ("ui_select", .12, tone(500, 700)),
        ("pulse", .4, tone(420, 80, .04)),
    ]:
        save(name, duration, synth)
    save("winter_ambience", 20, ambience)
    print("Generated 13 original WAV assets in", ROOT)
