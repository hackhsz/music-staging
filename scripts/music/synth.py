"""Chiptune-flavoured renderer: score events in, 16-bit mono WAV out.

Standard library only, so the pipeline runs on a clean checkout with no pip
install. Rendering is seeded, so the same score always produces byte-identical
audio and the wav never needs committing.

Output is 44.1 kHz mono, inside Roblox's limits (48 kHz or lower, under 7
minutes, under 20 MB).
"""

import array
import math
import random
import wave

SAMPLE_RATE = 44100
MASTER_GAIN = 0.82
FADE_OUT_SECONDS = 0.35

LANE_GAIN = {
    "kick": 1.0,
    "snare": 0.7,
    "hat": 0.28,
    "clap": 0.6,
    "bass": 0.55,
    "lead": 0.42,
    "pad": 0.3,
}


def note_to_frequency(note):
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def _square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def _triangle(phase):
    position = phase % 1.0

    return 4.0 * abs(position - 0.5) - 1.0


def _saw(phase):
    return 2.0 * (phase % 1.0) - 1.0


def _render_kick(length, rng):
    samples = []
    phase = 0.0

    for index in range(length):
        progress = index / float(length)
        # Pitch drop is what makes a kick read as a kick rather than a low beep.
        frequency = 45.0 + 85.0 * math.exp(-progress * 14.0)
        phase += frequency / SAMPLE_RATE
        envelope = math.exp(-progress * 7.0)
        samples.append(math.sin(phase * 2.0 * math.pi) * envelope)

    return samples


def _render_snare(length, rng):
    samples = []
    phase = 0.0
    previous = 0.0

    for index in range(length):
        progress = index / float(length)
        envelope = math.exp(-progress * 13.0)
        noise = rng.uniform(-1.0, 1.0)
        bright = noise - previous
        previous = noise
        phase += 185.0 / SAMPLE_RATE
        body = math.sin(phase * 2.0 * math.pi) * 0.45
        samples.append((bright * 0.75 + body) * envelope)

    return samples


def _render_hat(length, rng):
    samples = []
    previous = 0.0

    for index in range(length):
        progress = index / float(length)
        envelope = math.exp(-progress * 38.0)
        noise = rng.uniform(-1.0, 1.0)
        # Crude high pass: differencing kills the low end and leaves the hiss.
        bright = noise - previous
        previous = noise
        samples.append(bright * envelope)

    return samples


def _render_clap(length, rng):
    samples = []
    previous = 0.0

    for index in range(length):
        progress = index / float(length)
        burst = 1.0 if (progress < 0.05 or 0.08 < progress < 0.12) else math.exp(-progress * 16.0)
        noise = rng.uniform(-1.0, 1.0)
        bright = noise - previous
        previous = noise
        samples.append(bright * burst * 0.8)

    return samples


def _render_pitched(length, frequency, shape):
    samples = []
    phase = 0.0

    for index in range(length):
        progress = index / float(length)

        if shape == "bass":
            value = _triangle(phase) * 0.7 + _square(phase, 0.5) * 0.3
            envelope = math.exp(-progress * 3.2)
        elif shape == "lead":
            value = _square(phase, 0.25)
            envelope = math.exp(-progress * 2.6) * min(1.0, progress * 60.0)
        else:
            value = _saw(phase)
            envelope = min(1.0, progress * 8.0) * math.exp(-progress * 1.1)

        phase += frequency / SAMPLE_RATE
        samples.append(value * envelope)

    return samples


def _voice(event, beat_seconds, rng):
    if event.lane == "kick":
        return _render_kick(int(0.28 * SAMPLE_RATE), rng)

    if event.lane == "snare":
        return _render_snare(int(0.20 * SAMPLE_RATE), rng)

    if event.lane == "hat":
        return _render_hat(int(0.06 * SAMPLE_RATE), rng)

    if event.lane == "clap":
        return _render_clap(int(0.22 * SAMPLE_RATE), rng)

    held = max(event.beats * beat_seconds, 0.05)
    length = int(min(held * 1.6, 2.5) * SAMPLE_RATE)

    return _render_pitched(length, note_to_frequency(event.note), event.lane)


def render(score, events, seed=None):
    """Mix every event into a float buffer."""
    if score.get("sound") == "pop":
        from . import studio

        return studio.render(score, events, seed)

    bpm = float(score["bpm"])
    beat_seconds = 60.0 / bpm
    total = sum(section["bars"] for section in score["sections"]) * score.get("beatsPerBar", 4)
    tail = int((total * beat_seconds + 1.5) * SAMPLE_RATE)
    buffer = [0.0] * tail
    rng = random.Random(seed if seed is not None else score.get("seed", 0))

    for event in events:
        start = int((event.beat - 1.0) * beat_seconds * SAMPLE_RATE)

        if start >= tail:
            continue

        gain = LANE_GAIN.get(event.lane, 0.4) * (1.25 if event.accent else 1.0)

        for offset, sample in enumerate(_voice(event, beat_seconds, rng)):
            position = start + offset

            if position >= tail:
                break

            buffer[position] += sample * gain

    fade = int(FADE_OUT_SECONDS * SAMPLE_RATE)

    for index in range(max(0, tail - fade), tail):
        buffer[index] *= (tail - index) / float(fade)

    return buffer


def write_wav(path, buffer):
    pcm = array.array("h")

    # The pop renderer hands back a finished, normalised numpy array.
    if hasattr(buffer, "dtype"):
        pcm.frombytes((buffer.clip(-1.0, 1.0) * 32767).astype("<i2").tobytes())
        buffer = []

    for sample in buffer:
        value = sample * MASTER_GAIN
        # Soft clip so a dense bar distorts gracefully instead of wrapping.
        value = math.tanh(value)
        pcm.append(int(max(-1.0, min(1.0, value)) * 32767))

    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())

    return len(pcm) / float(SAMPLE_RATE)
