"""Pop renderer: a fuller, produced sound for scores that set "sound": "pop".

Where synth.py is a chiptune box, this aims at modern dance-pop: layered drums,
an 808 bass, detuned supersaw leads and chords, a formant "voice" that sings the
melody, noise risers, a kick-keyed sidechain pump and a reverb bus.

Needs numpy, which the chiptune renderer does not. Filters work in the
frequency domain over each note, since numpy cannot run a recursive filter
quickly, and the reverb is a convolution with a synthetic decaying impulse.
Seeded, so a score always renders the same audio.
"""

import numpy as np

SAMPLE_RATE = 44100
MASTER_PEAK = 0.89
FADE_OUT_SECONDS = 1.5

GAIN = {
    "kick": 0.7,
    "snare": 0.6,
    "clap": 0.6,
    "hat": 0.28,
    "crash": 0.3,
    "bass": 0.3,
    "lead": 0.5,
    "pad": 0.24,
    "vox": 1.0,
    "riser": 0.3,
}

# How much of each lane goes to the reverb, and how hard the kick ducks it.
REVERB_SEND = {"snare": 0.25, "clap": 0.35, "lead": 0.3, "pad": 0.35, "vox": 0.3, "crash": 0.3, "riser": 0.4}
SIDECHAIN = {"pad": 0.75, "bass": 0.35, "lead": 0.4, "vox": 0.25, "riser": 0.3}
SIDECHAIN_SECONDS = 0.16
REVERB_SECONDS = 2.2
REVERB_MIX = 0.5

# Vowel formants of an open "ah" (Hz, bandwidth Hz, gain), for the vox lane.
AH_FORMANTS = ((800, 90, 1.0), (1150, 110, 0.6), (2900, 170, 0.25), (3900, 250, 0.12))


def note_to_frequency(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def _time(length):
    return np.arange(length) / SAMPLE_RATE


def _spectral(signal, response):
    """Filter a whole signal at once by shaping its spectrum."""
    spectrum = np.fft.rfft(signal)
    frequencies = np.fft.rfftfreq(len(signal), 1.0 / SAMPLE_RATE)

    return np.fft.irfft(spectrum * response(frequencies), len(signal))


def _lowpass(signal, cutoff, slope=2):
    return _spectral(signal, lambda f: 1.0 / (1.0 + (f / cutoff) ** (2 * slope)) ** 0.5)


def _highpass(signal, cutoff, slope=2):
    return _spectral(signal, lambda f: 1.0 / (1.0 + (cutoff / np.maximum(f, 1.0)) ** (2 * slope)) ** 0.5)


def _bandpass(signal, centre, width):
    return _spectral(signal, lambda f: 1.0 / (1.0 + ((f - centre) / (width / 2.0)) ** 2))


def _saw(frequency, length, rng, voices=1, detune_cents=0.0):
    t = _time(length)
    out = np.zeros(length)

    for index in range(voices):
        spread = 0.0 if voices == 1 else (index / (voices - 1) - 0.5) * 2.0
        f = frequency * 2.0 ** (spread * detune_cents / 1200.0)
        phase = (rng.random() + f * t) % 1.0
        out += 2.0 * phase - 1.0

    return out / voices


def _adsr(length, attack, decay, sustain, release, held):
    t = _time(length)
    env = np.where(t < attack, t / max(attack, 1e-4), 1.0)
    decaying = (t >= attack) & (t < attack + decay)
    env = np.where(decaying, 1.0 - (1.0 - sustain) * (t - attack) / max(decay, 1e-4), env)
    env = np.where(t >= attack + decay, sustain, env)
    releasing = t >= held
    env = np.where(releasing, env * np.exp(-(t - held) / max(release, 1e-4)), env)

    return env


def _kick(rng):
    length = int(0.42 * SAMPLE_RATE)
    t = _time(length)
    frequency = 48.0 + 110.0 * np.exp(-t * 32.0)
    phase = np.cumsum(frequency) / SAMPLE_RATE
    body = np.sin(2 * np.pi * phase) * np.exp(-t * 6.5)
    click = _highpass(rng.uniform(-1, 1, length), 3000) * np.exp(-t * 180.0) * 0.6

    return np.tanh((body + click) * 1.6)


def _snare(rng):
    length = int(0.32 * SAMPLE_RATE)
    t = _time(length)
    noise = _bandpass(rng.uniform(-1, 1, length), 4200, 6000) * np.exp(-t * 14.0)
    body = np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 28.0) * 0.8

    return noise + body


def _clap(rng):
    length = int(0.36 * SAMPLE_RATE)
    t = _time(length)
    bursts = sum(np.exp(-np.maximum(t - offset, 0) * 90.0) * (t >= offset) for offset in (0.0, 0.011, 0.022))
    tail = np.exp(-t * 11.0) * (t >= 0.03)

    return _bandpass(rng.uniform(-1, 1, length), 1500, 1800) * (bursts * 0.8 + tail * 0.5)


def _hat(rng, accent):
    length = int((0.22 if accent else 0.07) * SAMPLE_RATE)
    t = _time(length)

    return _highpass(rng.uniform(-1, 1, length), 8000) * np.exp(-t * (14.0 if accent else 60.0))


def _crash(rng):
    length = int(2.2 * SAMPLE_RATE)
    t = _time(length)

    return _highpass(rng.uniform(-1, 1, length), 5000) * np.exp(-t * 1.6)


def _bass(frequency, held, rng):
    length = int((held + 0.12) * SAMPLE_RATE)
    t = _time(length)
    glide = frequency * (1.0 + 0.5 * np.exp(-t * 40.0))
    phase = np.cumsum(glide) / SAMPLE_RATE
    tone = np.sin(2 * np.pi * phase) + 0.25 * np.sin(4 * np.pi * phase)
    env = _adsr(length, 0.004, 0.25, 0.75, 0.06, held)

    return np.tanh(tone * 1.8) * env


def _lead(frequency, held, rng):
    length = int((held + 0.3) * SAMPLE_RATE)
    t = _time(length)
    raw = _saw(frequency, length, rng, voices=7, detune_cents=24.0)
    bright = _lowpass(raw, 7000)
    dark = _lowpass(raw, 1400)
    sweep = np.exp(-t * 7.0)
    env = _adsr(length, 0.005, 0.18, 0.55, 0.12, held)

    return (dark + (bright - dark) * sweep) * env


def _pad(frequency, held, rng):
    length = int((held + 0.6) * SAMPLE_RATE)
    raw = _saw(frequency, length, rng, voices=5, detune_cents=18.0)
    env = _adsr(length, 0.08, 0.4, 0.8, 0.35, held)

    return _lowpass(raw, 2600) * env


def _vox(frequency, held, rng):
    """A sung "ah": a buzzy source through vowel formants, with late vibrato."""
    length = int((held + 0.18) * SAMPLE_RATE)
    t = _time(length)
    vibrato = 1.0 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.25, 0.0, 1.0)
    scoop = 1.0 - 0.03 * np.exp(-t * 30.0)
    phase = np.cumsum(frequency * vibrato * scoop) / SAMPLE_RATE
    source = 2.0 * (phase % 1.0) - 1.0
    source = source + 0.04 * rng.uniform(-1, 1, length)
    voiced = sum(gain * _bandpass(source, centre, width) for centre, width, gain in AH_FORMANTS)
    env = _adsr(length, 0.025, 0.1, 0.85, 0.08, held)

    return voiced * env * 3.0


def _riser(held, rng):
    length = int(held * SAMPLE_RATE)
    t = _time(length)
    progress = t / max(held, 1e-3)
    noise = rng.uniform(-1, 1, length)
    low = _highpass(noise, 300)
    high = _highpass(noise, 4000)

    return (low + (high - low) * progress) * progress ** 2


def _voice(event, beat_seconds, rng):
    lane = event.lane
    held = max(event.beats * beat_seconds, 0.06)

    if lane == "kick":
        return _kick(rng)
    if lane == "snare":
        return _snare(rng)
    if lane == "clap":
        return _clap(rng)
    if lane == "hat":
        return _hat(rng, event.accent)
    if lane == "crash":
        return _crash(rng)
    if lane == "riser":
        return _riser(held, rng)

    frequency = note_to_frequency(event.note)

    if lane == "bass":
        return _bass(frequency, held, rng)
    if lane == "lead":
        return _lead(frequency, held, rng)
    if lane == "vox":
        return _vox(frequency, held, rng)

    return _pad(frequency, held, rng)


def _sidechain(kicks, length, depth):
    gain = np.ones(length)
    window = int(SIDECHAIN_SECONDS * 3 * SAMPLE_RATE)
    curve = 1.0 - depth * np.exp(-_time(window) / SIDECHAIN_SECONDS)

    for start in kicks:
        end = min(start + window, length)

        if start < length:
            gain[start:end] = np.minimum(gain[start:end], curve[: end - start])

    return gain


def _reverb(signal, rng):
    length = int(REVERB_SECONDS * SAMPLE_RATE)
    t = _time(length)
    impulse = rng.uniform(-1, 1, length) * np.exp(-t * 6.9 / REVERB_SECONDS)
    impulse = _lowpass(impulse, 6000)
    impulse /= np.sqrt(np.sum(impulse ** 2))
    size = 1 << int(np.ceil(np.log2(len(signal) + length)))
    wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)[: len(signal)]

    return _highpass(wet, 250)


def render(score, events, seed=None):
    bpm = float(score["bpm"])
    beat_seconds = 60.0 / bpm
    total = sum(section["bars"] for section in score["sections"]) * score.get("beatsPerBar", 4)
    length = int((total * beat_seconds + REVERB_SECONDS) * SAMPLE_RATE)
    rng = np.random.default_rng(seed if seed is not None else score.get("seed", 0))
    buses = {}

    def start_of(event):
        return int((event.beat - 1.0) * beat_seconds * SAMPLE_RATE)

    for event in events:
        start = start_of(event)

        if start >= length:
            continue

        sound = _voice(event, beat_seconds, rng) * GAIN.get(event.lane, 0.3) * (1.2 if event.accent else 1.0)
        bus = buses.setdefault(event.lane, np.zeros(length))
        end = min(start + len(sound), length)
        bus[start:end] += sound[: end - start]

    kicks = [start_of(event) for event in events if event.lane == "kick"]
    dry = np.zeros(length)
    send = np.zeros(length)

    for lane, bus in buses.items():
        if lane in SIDECHAIN:
            bus = bus * _sidechain(kicks, length, SIDECHAIN[lane])

        dry += bus
        send += bus * REVERB_SEND.get(lane, 0.0)

    mix = dry + _reverb(send, rng) * REVERB_MIX
    mix = np.tanh(mix * 1.1)
    mix *= MASTER_PEAK / max(np.max(np.abs(mix)), 1e-9)

    fade = int(FADE_OUT_SECONDS * SAMPLE_RATE)
    mix[-fade:] *= np.linspace(1.0, 0.0, fade)

    return mix
