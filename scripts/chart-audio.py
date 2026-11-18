#!/usr/bin/env python3
"""Chart a finished audio track, with no score to read.

For songs we did not render ourselves (Creator Store tracks), this listens to
the audio instead: it finds the tempo and the beat grid, scores every grid
position by how hard a sound starts there, keeps the strongest down to each
difficulty's density, and spreads notes across the lanes by pitch, low on the
left and high on the right, phrase by phrase.

The floor chart is built from the same listening: every eighth becomes an
onset for music/floor.py, and the track's loudness, eight beats at a time,
gives the sections their energy.

    python scripts/chart-audio.py track.ogg --id my-song --title "My Song" --artist "Someone"
    python scripts/chart-audio.py track.ogg --id my-song --title "My Song" --bpm 141 --check
    python scripts/chart-audio.py track.ogg --id my-song --title "My Song" --bpm 130 --offset 0.306 \
        --sections 0:calm,16:build,52:chorus,116:drop --difficulties easy,normal,hard,expert --intensity high

Needs numpy, scipy and soundfile.
"""

import argparse
import os
import sys

import numpy as np
import soundfile
from scipy.ndimage import median_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from music import chart, events as floor_events, floor, library  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CHART_DIR = os.path.join(REPO_ROOT, "src", "ReplicatedStorage", "Shared", "Songs")
SOURCE = "scripts/chart-audio.py"

HOP = 512
FRAME = 2048
LANES = 4
# Where a note may sit (in beats), the closest two may be, and how many notes a
# second to aim for.
DIFFICULTIES = {
    "easy": {"grid": 1.0, "minGap": 1.0, "density": 1.3},
    "normal": {"grid": 0.5, "minGap": 0.5, "density": 2.3},
    "hard": {"grid": 0.25, "minGap": 0.25, "density": 3.4},
    "expert": {"grid": 0.25, "minGap": 0.25, "density": 4.2},
}
DEFAULT_DIFFICULTIES = ("easy", "normal", "hard")
STRENGTH_WINDOW_SECONDS = 0.035
# Quiet passages keep some of their quietness: strength is divided by the
# local loudness raised to this power, so a whispered intro is not charted as
# densely as the chorus.
LOCAL_NORMALISE = 0.6
LOCAL_BEATS = 16
PHRASE_BEATS = 8
MELODY_BAND = (180.0, 1800.0)
# Snares and claps start bright: a strong onset up here is where a clap goes,
# measured against the loudest such onsets nearby.
SNAP_BAND = (1500.0, 8000.0)
SNAP_PERCENTILE = 90
HOLD_MIN_BEATS = 1.0
HOLD_SUSTAIN = 0.65
HOLD_GAP_FRACTION = 0.7
HOLD_EVERY = 6
MAX_REPEAT = 3
SECTION_BEATS = 16
# Loudness percentiles that split calm, build and chorus; the loudest
# stretch that jumps up from what came before is the drop.
CALM_BELOW = 0.3
BUILD_BELOW = 0.55
DROP_ABOVE = 0.8
DROP_JUMP = 1.1
SUSTAIN_LOOKAHEAD_BEATS = 4.0
# --follow snares: a step goes on a snare or clap that stands out from the
# eighths around it. Each difficulty gives the fewest eighths between steps (two
# unless its floor profile allows eighths in those sections, and then never more
# than SNARE_CHAIN quick steps in a row) and
# how far above the local spread a snare must be, first where the song is calm
# and then at its loudest; sections in between are blended by SECTION_LIFT.
# Whatever the threshold, a step needs an audible hit under it, and one between
# beats a clear snare, or it reads as off the beat. Where a difficulty still
# wants more, beatFill sections (by lift) take the loudest plain beats too.
# Where the drums drop back, a sung or played note starting counts as a snare:
# the melody is read from the held part of the sound, so a busy hat or a noise
# wash cannot pass for it. A section is lifted to at least how loud the song is
# there, ranked against the rest, so a loud stretch labelled calm still dances.
SNARE_WINDOW_EIGHTHS = 64
HARMONIC_FRAMES = 17
PERCUSSIVE_BINS = 17
LOUDNESS_BEATS = 8
SNARE_HIT = 0.3
SNARE_OFF_BEAT = 1.0
BEAT_FILL_PERCENTILE = 50
SNARE_CHAIN = 4
SNARE_FOLLOW = {
    "easy": {"gap": (4, 4), "threshold": (0.6, 0.1)},
    "normal": {"gap": (4, 2), "threshold": (0.2, -0.4)},
    "hard": {"gap": (2, 2), "threshold": (0.3, -0.3), "beatFill": 0.45},
    "expert": {"gap": (2, 1), "threshold": (-0.2, -0.8), "beatFill": 0.0, "songWide": True},
}
SECTION_LIFT = {"calm": 0.0, "build": 0.45, "chorus": 0.8, "drop": 1.0}
# A floor layout can corner itself; the next seeds are tried before giving up.
SEED_ATTEMPTS = 8


def load(path):
    data, rate = soundfile.read(path, always_2d=True)
    return data.mean(axis=1), rate


def spectrogram(signal):
    # Frame n is read as the moment n * HOP, so it has to be centred there: an
    # uncentred frame hears a hit half a frame early and charts every step early.
    signal = np.pad(signal, (FRAME // 2, FRAME // 2))
    frames = 1 + (len(signal) - FRAME) // HOP
    index = np.arange(FRAME)[None, :] + HOP * np.arange(frames)[:, None]
    return np.abs(np.fft.rfft(signal[index] * np.hanning(FRAME), axis=1))


def onset_envelope(spec):
    logspec = np.log1p(spec * 10)
    flux = np.concatenate([[0.0], np.maximum(logspec[1:] - logspec[:-1], 0).sum(axis=1)])
    flux -= np.convolve(flux, np.ones(16) / 16, mode="same")
    return np.maximum(flux, 0)


def _comb(env, fps, bpm):
    period = 60 * fps / bpm
    best, best_offset = -1.0, 0.0

    for offset in np.arange(0, period, 0.5):
        positions = np.arange(offset, len(env) - 1, period)
        score = np.interp(positions, np.arange(len(env)), env).mean()

        if score > best:
            best, best_offset = score, offset

    return best, best_offset / fps


def find_tempo(env, fps, bpm=None):
    """The tempo and the time of a beat, preferring the 80-180 range."""
    if bpm is not None:
        return bpm, _comb(env, fps, bpm)[1]

    candidates = []

    for coarse in np.arange(80, 181, 0.5):
        score, _ = _comb(env, fps, coarse)
        candidates.append((score * np.exp(-0.5 * ((coarse - 125) / 45) ** 2), coarse))

    coarse = max(candidates)[1]
    fine = max((_comb(env, fps, value)[0], value) for value in np.arange(coarse - 1, coarse + 1, 0.02))[1]
    rounded = round(fine)

    if _comb(env, fps, rounded)[0] >= 0.95 * _comb(env, fps, fine)[0]:
        fine = float(rounded)

    return fine, _comb(env, fps, fine)[1]


def grid_strengths(env, fps, times):
    window = int(STRENGTH_WINDOW_SECONDS * fps)
    frames = np.clip((times * fps).astype(int), 0, len(env) - 1)
    raw = np.array([env[max(f - window, 0) : f + window + 1].max() for f in frames])
    return raw


def melody_pitch(spec, rate, frame):
    """The pitch of whatever just started: the band's biggest rise, not its loudest bin."""
    frequencies = np.fft.rfftfreq(FRAME, 1.0 / rate)
    band = (frequencies >= MELODY_BAND[0]) & (frequencies <= MELODY_BAND[1])
    after = spec[min(frame + 2, len(spec) - 1), band]
    before = spec[max(frame - 2, 0), band]
    rise = np.log1p(after) - np.log1p(before)
    peak = frequencies[band][np.argmax(rise)]
    return int(round(12 * np.log2(peak / 440.0) + 69))


def snap_strengths(spec, rate, fps, times):
    frequencies = np.fft.rfftfreq(FRAME, 1.0 / rate)
    band = (frequencies >= SNAP_BAND[0]) & (frequencies <= SNAP_BAND[1])
    raw = grid_strengths(onset_envelope(spec[:, band]), fps, times)
    span = 2 * LOCAL_BEATS
    peaks = np.array([
        np.percentile(raw[max(i - span, 0) : i + span + 1], SNAP_PERCENTILE) for i in range(len(raw))
    ])
    return np.clip(raw / np.maximum(peaks, 1e-6), 0.0, 1.0)


def band_energy(spec, rate):
    frequencies = np.fft.rfftfreq(FRAME, 1.0 / rate)
    band = (frequencies >= MELODY_BAND[0]) & (frequencies <= MELODY_BAND[1])
    return spec[:, band].sum(axis=1)


def assign_lanes(notes, beat_seconds):
    """Spread each phrase's pitches across the lanes, then break long runs."""
    phrases = {}

    for note in notes:
        phrases.setdefault(int(note["time"] / (PHRASE_BEATS * beat_seconds)), []).append(note)

    for phrase in phrases.values():
        distinct = sorted({note["pitch"] for note in phrase})

        for note in phrase:
            if len(distinct) == 1:
                note["lane"] = 2
            else:
                rank = distinct.index(note["pitch"])
                note["lane"] = 1 + int(round(rank * (LANES - 1) / (len(distinct) - 1)))

    run = 1

    for index in range(1, len(notes)):
        if notes[index]["lane"] == notes[index - 1]["lane"]:
            run += 1

            if run > MAX_REPEAT:
                lane = notes[index]["lane"]
                notes[index]["lane"] = lane + 1 if lane < LANES else lane - 1
                run = 1
        else:
            run = 1


def build(signal, rate, bpm, offset, difficulty):
    profile = DIFFICULTIES[difficulty]
    spec = spectrogram(signal)
    env = onset_envelope(spec)
    fps = rate / HOP
    beat_seconds = 60.0 / bpm
    duration = len(signal) / rate
    step = profile["grid"] * beat_seconds
    times = np.arange(offset % step, duration - 0.5, step)
    raw = grid_strengths(env, fps, times)

    local_span = max(int(LOCAL_BEATS / profile["grid"]), 1)
    loudness = np.array([
        np.percentile(raw[max(i - local_span, 0) : i + local_span + 1], 75) for i in range(len(raw))
    ])
    strength = raw / np.maximum(loudness, 1e-6) ** LOCAL_NORMALISE

    target = int(profile["density"] * duration)
    min_gap = profile["minGap"] * beat_seconds - 1e-6
    chosen = []

    for index in np.argsort(-strength):
        if len(chosen) >= target or strength[index] <= 0:
            break

        t = times[index]

        if all(abs(t - other) >= min_gap for other in chosen):
            chosen.append(t)

    chosen.sort()
    notes = [{"time": t, "pitch": melody_pitch(spec, rate, int(t * fps))} for t in chosen]
    assign_lanes(notes, beat_seconds)

    energy = band_energy(spec, rate)
    steps = []
    since_hold = HOLD_EVERY

    for index, note in enumerate(notes):
        beat = round(1.0 + note["time"] / beat_seconds, 4)
        entry = {"beat": beat, "x": note["lane"], "y": 1}
        gap = (notes[index + 1]["time"] - note["time"]) if index + 1 < len(notes) else 0.0
        since_hold += 1

        if gap >= HOLD_MIN_BEATS * beat_seconds and since_hold >= HOLD_EVERY:
            start = int(note["time"] * fps)
            span = energy[start : start + int(gap * fps)]
            onset_level = energy[start : start + 3].max() if start + 3 <= len(energy) else 0.0
            held = np.argmax(span < onset_level * HOLD_SUSTAIN) if np.any(span < onset_level * HOLD_SUSTAIN) else len(span)
            seconds = min(held / fps, gap * HOLD_GAP_FRACTION)

            if seconds >= HOLD_MIN_BEATS * beat_seconds * HOLD_GAP_FRACTION:
                entry["type"] = "hold"
                entry["holdSeconds"] = round(seconds, 3)
                since_hold = 0

        steps.append(entry)

    return steps


def sections_from_loudness(signal, rate, env, bpm, offset):
    """Energy per stretch: loudness times how busy the onsets are, ranked."""
    fps = rate / HOP
    beat_seconds = 60.0 / bpm
    span = SECTION_BEATS * beat_seconds
    first = offset % beat_seconds
    starts = np.arange(first, len(signal) / rate - span / 2, span)

    if len(starts) == 0:
        return [(1.0, "calm")]

    levels = np.array([
        np.sqrt(np.mean(signal[int(t * rate) : int((t + span) * rate)] ** 2) + 1e-12)
        * env[int(t * fps) : int((t + span) * fps)].mean()
        for t in starts
    ])
    ranks = levels.argsort().argsort() / max(len(levels) - 1, 1)
    energies = ["calm" if r < CALM_BELOW else "build" if r < BUILD_BELOW else "chorus" for r in ranks]

    for index in range(1, len(energies)):
        jumped = levels[index] >= DROP_JUMP * levels[index - 1] and energies[index - 1] in ("calm", "build")
        carried = energies[index - 1] == "drop" and ranks[index] >= BUILD_BELOW

        if carried or (jumped and ranks[index] >= DROP_ABOVE):
            energies[index] = "drop"

    return [(round(1.0 + t / beat_seconds, 4), energy) for t, energy in zip(starts, energies)]


def given_sections(text, bpm, offset, parser):
    """--sections as (chart beat, energy), the beats counted from the first beat."""
    first = 1.0 + (offset % (60.0 / bpm)) * bpm / 60.0
    sections = []

    for pair in text.split(","):
        beat, _, energy = pair.strip().partition(":")

        if energy not in floor.ENERGIES:
            parser.error("--sections: %r needs an energy of %s" % (pair, ", ".join(floor.ENERGIES)))

        sections.append((round(first + float(beat), 4), energy))

    return sorted(sections)


def eighth_times(signal, rate, bpm, offset):
    eighth = 30.0 / bpm
    return np.arange(offset % eighth, len(signal) / rate - 0.5, eighth)


def snare_scores(signal, rate, bpm, offset, song_wide=False):
    """How far each eighth's snare or clap stands above the eighths around it, in spreads."""
    spec = spectrogram(signal)
    frequencies = np.fft.rfftfreq(FRAME, 1.0 / rate)
    band = (frequencies >= SNAP_BAND[0]) & (frequencies <= SNAP_BAND[1])
    raw = grid_strengths(onset_envelope(spec[:, band]), rate / HOP, eighth_times(signal, rate, bpm, offset))
    half = SNARE_WINDOW_EIGHTHS // 2
    scores = np.zeros(len(raw))
    song = (raw - np.median(raw)) / max(np.std(raw), 1e-9)

    # Against its neighbours alone a snare in a drop, where every eighth is loud,
    # scores like filler; song_wide also scores it against the whole song, so a
    # drop keeps its hits.
    for index, value in enumerate(raw):
        around = raw[max(index - half, 0) : index + half]
        scores[index] = (value - np.median(around)) / max(np.std(around), 1e-9)

        if song_wide:
            scores[index] = max(scores[index], song[index])

    return scores


def melody_scores(signal, rate, bpm, offset):
    """How far each eighth's new note stands above the eighths around it, in spreads, drums left out."""
    spec = spectrogram(signal)
    held = median_filter(spec, size=(HARMONIC_FRAMES, 1))
    struck = median_filter(spec, size=(1, PERCUSSIVE_BINS))
    harmonic = spec * held**2 / (held**2 + struck**2 + 1e-12)
    frequencies = np.fft.rfftfreq(FRAME, 1.0 / rate)
    band = (frequencies >= MELODY_BAND[0]) & (frequencies <= MELODY_BAND[1])
    raw = grid_strengths(onset_envelope(harmonic[:, band]), rate / HOP, eighth_times(signal, rate, bpm, offset))
    half = SNARE_WINDOW_EIGHTHS // 2
    scores = np.zeros(len(raw))

    for index, value in enumerate(raw):
        around = raw[max(index - half, 0) : index + half]
        scores[index] = (value - np.median(around)) / max(np.std(around), 1e-9)

    return scores


def loudness_lifts(signal, rate, bpm, offset):
    """Per eighth, how loud the song is around it, ranked from 0 (quietest) to 1 (loudest)."""
    span = LOUDNESS_BEATS * 60.0 / bpm
    times = eighth_times(signal, rate, bpm, offset)
    levels = np.array([
        np.sqrt(np.mean(signal[max(int((t - span / 2) * rate), 0) : int((t + span / 2) * rate)] ** 2) + 1e-12)
        for t in times
    ])
    return levels.argsort().argsort() / max(len(levels) - 1, 1)


def snare_hits(onsets, scores):
    """The beats with a hit a player can hear: a snare, or a loud plain beat."""
    loud = np.percentile([onset.strength for onset in onsets if onset.on_beat], BEAT_FILL_PERCENTILE)
    return {
        round(onset.beat, 4)
        for onset, score in zip(onsets, scores)
        if score >= SNARE_HIT or (onset.on_beat and onset.strength >= loud)
    }


def follow_snares(onsets, scores, sections, difficulty, loudness):
    """The beats a step goes on: the strongest snares first, kept apart by the difficulty's gap."""
    rule = SNARE_FOLLOW[difficulty]
    first = onsets[0].beat + floor.LEAD_IN_BEATS
    taken = np.zeros(len(onsets), dtype=bool)
    lifts = [
        max(SECTION_LIFT[floor.energy_at(sections, onset.beat)], loud) for onset, loud in zip(onsets, loudness)
    ]

    def chained(index, step):
        count = 0

        while 0 <= index + step * (count + 1) < len(taken) and taken[index + step * (count + 1)]:
            count += 1

        return count

    def free(index):
        gap = rule["gap"][0 if lifts[index] < 0.5 else 1]

        if onsets[index].beat < first - floor.EPS or taken[max(index - gap + 1, 0) : index + gap].any():
            return False

        return chained(index, -1) + chained(index, 1) + 1 <= SNARE_CHAIN

    for index in np.argsort(-scores):
        low, high = rule["threshold"]
        least = SNARE_HIT if onsets[index].on_beat else SNARE_OFF_BEAT

        if scores[index] >= max(low + (high - low) * lifts[index], least) and free(index):
            taken[index] = True

    if "beatFill" in rule:
        beats = [index for index, onset in enumerate(onsets) if onset.on_beat]
        loud = np.percentile([onsets[index].strength for index in beats], BEAT_FILL_PERCENTILE)

        for index in sorted(beats, key=lambda index: -onsets[index].strength):
            if onsets[index].strength >= loud and lifts[index] >= rule["beatFill"] and free(index):
                taken[index] = True

    return [onset.beat for onset, keep in zip(onsets, taken) if keep]


def floor_chart(onsets, sections, end_beat, bpm, difficulty, seed, rhythm, hits, generator="library"):
    if generator == "library":
        steps, floor_sections = library.build(onsets, sections, end_beat, bpm, difficulty, seed=seed, rhythm=rhythm)
        return steps, floor_sections, [], library.check(steps, bpm, difficulty)

    steps, floor_sections = floor.build(
        onsets, sections, end_beat, bpm, difficulty, seed=seed, rhythm=rhythm, hits=hits
    )
    steps, event_list = floor_events.place(steps, floor_sections, end_beat, bpm, difficulty, seed=seed)
    steps = floor.dress(steps, floor_sections, bpm, difficulty, seed=seed)
    problems = floor.check(floor_events.plain(steps), bpm, difficulty)
    problems += floor_events.check(steps, event_list, bpm, difficulty)
    return steps, floor_sections, event_list, problems


def floor_onsets(signal, rate, bpm, offset):
    spec = spectrogram(signal)
    env = onset_envelope(spec)
    energy = band_energy(spec, rate)
    fps = rate / HOP
    beat_seconds = 60.0 / bpm
    eighth = beat_seconds / 2
    times = eighth_times(signal, rate, bpm, offset)
    raw = grid_strengths(env, fps, times)
    local_span = 2 * LOCAL_BEATS
    loudness = np.array([
        np.percentile(raw[max(i - local_span, 0) : i + local_span + 1], 75) for i in range(len(raw))
    ])
    strength = raw / np.maximum(loudness, 1e-6) ** LOCAL_NORMALISE
    snaps = snap_strengths(spec, rate, fps, times)
    lookahead = int(SUSTAIN_LOOKAHEAD_BEATS * beat_seconds * fps)
    onsets = []

    for t, value, snap in zip(times, strength, snaps):
        slot = int(round((t - offset) / eighth))
        frame = int(t * fps)
        level = energy[frame : frame + 3].max() if frame + 3 <= len(energy) else 0.0
        span = energy[frame : frame + lookahead]
        quiet = span < level * HOLD_SUSTAIN
        held = (np.argmax(quiet) if np.any(quiet) else len(span)) / fps

        onsets.append(
            floor.Onset(
                round(1.0 + t / beat_seconds, 4),
                float(value),
                pitch=melody_pitch(spec, rate, frame),
                sustain=held / beat_seconds,
                on_beat=slot % 2 == 0,
                downbeat=slot % 8 == 0,
                snap=float(snap),
            )
        )

    return onsets


def luau_step(step):
    parts = ["beat = %s" % ("%.4f" % step["beat"]).rstrip("0").rstrip("."), "x = %d" % step["x"], "y = 1"]

    if step.get("type") == "hold":
        parts.append('type = "hold"')
        parts.append("holdSeconds = %s" % ("%.3f" % step["holdSeconds"]).rstrip("0").rstrip("."))

    return "{ %s }," % ", ".join(parts)


def to_luau(args, bpm, duration, charts, highway, module_name, events_by_difficulty):
    lines = [
        "--!nonstrict",
        "-- Generated by %s from %s. Do not edit by hand." % (SOURCE, os.path.basename(args.audio)),
        "",
        "local %s = {" % module_name,
    ]

    for difficulty, (steps, sections) in charts.items():
        lines += [
            "\t{",
            '\t\tid = "%s-%s",' % (args.id, difficulty),
            '\t\ttitle = "%s",' % args.title.replace('"', '\\"'),
            '\t\tartist = "%s",' % args.artist.replace('"', '\\"'),
            '\t\tdifficulty = "%s",' % difficulty,
            "\t\tbpm = %s," % ("%.2f" % bpm).rstrip("0").rstrip("."),
            "\t\tdurationSeconds = %.2f," % duration,
            "\t\tpreviewBeats = 1,",
            "\t\tperformanceGoal = {",
            '\t\t\tlabel = "%s GOAL",' % difficulty.upper(),
            "\t\t\ttargetScore = %d," % chart.target_score(steps),
            "\t\t},",
            "\t\tsteps = {",
        ]
        lines += ["\t" + floor_events.luau_step(step) for step in steps]
        lines += ["\t\t},"]
        lines += chart.luau_sections(sections, "\t")
        lines += floor_events.luau_events(events_by_difficulty[difficulty], "\t")
        lines += ["\t\thighwaySteps = {"]
        lines += ["\t\t\t" + luau_step(step) for step in highway[difficulty]]
        lines += ["\t\t},", "\t},"]

    lines += ["}", "", "return %s" % module_name, ""]

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("audio")
    parser.add_argument("--id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--artist", default="Unknown")
    parser.add_argument("--bpm", type=float, help="skip tempo detection")
    parser.add_argument("--offset", type=float, help="seconds to the first beat, skipping phase detection")
    parser.add_argument(
        "--sections",
        help="the song's sections instead of reading them from its loudness, as BEAT:ENERGY pairs "
        "counted in beats from the first beat, e.g. 0:calm,16:build,52:chorus,116:drop",
    )
    parser.add_argument("--difficulties", default=",".join(DEFAULT_DIFFICULTIES), help="comma-separated")
    parser.add_argument("--intensity", choices=sorted(floor.INTENSITY), help="a busier floor profile")
    parser.add_argument(
        "--follow",
        choices=("snares",),
        help="put the floor's steps on the song's snares and claps, more of them where the song is bigger",
    )
    parser.add_argument(
        "--generator",
        choices=("library", "walk"),
        default="library",
        help="library: authored patterns with generated bars between; walk: the older all-generated floor",
    )
    parser.add_argument("--chart-dir", default=DEFAULT_CHART_DIR)
    parser.add_argument("--check", action="store_true", help="report, write nothing")
    args = parser.parse_args()
    difficulties = [name.strip() for name in args.difficulties.split(",") if name.strip()]

    for name in difficulties:
        if name not in DIFFICULTIES:
            parser.error("unknown difficulty %r" % name)

    if args.intensity:
        floor.intensify(args.intensity)

    signal, rate = load(args.audio)
    env = onset_envelope(spectrogram(signal))
    bpm, offset = find_tempo(env, rate / HOP, args.bpm)

    if args.offset is not None:
        offset = args.offset

    duration = len(signal) / rate
    print("%s: %.1fs, %.2f bpm, a beat at %.3fs" % (args.id, duration, bpm, offset))

    charts = {}
    highway = {}
    events_by_difficulty = {}
    onsets = floor_onsets(signal, rate, bpm, offset)
    snares = loudness = None

    if args.follow:
        melody = melody_scores(signal, rate, bpm, offset)
        snares = {wide: np.maximum(snare_scores(signal, rate, bpm, offset, wide), melody) for wide in (False, True)}
        loudness = loudness_lifts(signal, rate, bpm, offset)
    sections = (
        given_sections(args.sections, bpm, offset, parser)
        if args.sections
        else sections_from_loudness(signal, rate, env, bpm, offset)
    )
    end_beat = 1.0 + duration * bpm / 60.0
    failures = 0
    print("  sections %s" % " ".join("%g:%s" % (beat, energy) for beat, energy in floor.merge_sections(sections)))

    for difficulty in difficulties:
        steps = build(signal, rate, bpm, offset, difficulty)
        highway[difficulty] = steps
        lanes = [sum(1 for s in steps if s["x"] == lane) for lane in range(1, LANES + 1)]
        holds = sum(1 for s in steps if s.get("type") == "hold")
        print("  %-7s %3d notes (%.2f/s)  lanes %s  holds %d" % (difficulty, len(steps), len(steps) / duration, lanes, holds))

        rhythm = hits = None

        if args.follow:
            scores = snares[SNARE_FOLLOW[difficulty].get("songWide", False)]
            rhythm = follow_snares(onsets, scores, sections, difficulty, loudness)
            hits = snare_hits(onsets, scores)

        for seed in range(len(args.id), len(args.id) + SEED_ATTEMPTS):
            floor_steps, floor_sections, floor_event_list, problems = floor_chart(
                onsets, sections, end_beat, bpm, difficulty, seed, rhythm, hits, args.generator
            )

            if not problems:
                break

        charts[difficulty] = (floor_steps, floor_sections)
        events_by_difficulty[difficulty] = floor_event_list
        print("          floor: %s%s" % (floor.describe(floor_steps), "  UNFAIR" if problems else ""))

        if args.generator == "library":
            print("          mix: %s" % library.describe(floor_steps, end_beat))
        print("          events: %s" % (" ".join("%s@%g" % (e["kind"], e["beat"]) for e in floor_event_list) or "none"))

        for problem in problems:
            print("            %s" % problem)

        failures += len(problems)

    if failures:
        raise SystemExit("\n%d floor chart problem(s); nothing written." % failures)

    if args.check:
        return

    module_name = "Generated" + "".join(part.capitalize() for part in args.id.split("-"))
    path = os.path.join(args.chart_dir, module_name + ".luau")
    os.makedirs(args.chart_dir, exist_ok=True)

    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(to_luau(args, bpm, duration, charts, highway, module_name, events_by_difficulty))

    print("  chart -> %s" % os.path.relpath(path, REPO_ROOT).replace(os.sep, "/"))


if __name__ == "__main__":
    sys.exit(main())
