"""Score model.

A score is the single source of truth for one song: the audio and every chart
difficulty are rendered from it, so they can never drift apart.

Lanes are step grids, one character per grid step (16 per bar by default):

    drums (kick, snare, hat, clap, crash)     x = hit, X = accent, . = rest
    pitched (bass, lead, pad, vox, riser)     1-9 = scale degree, - = sustain, . = rest

A pitched lane given as an object may set "chord": true, which plays the triad
built on each degree instead of the single note. A riser ignores its degree and
sweeps noise upward for as long as it is held.

Standard library only.
"""

import json
import os

DRUM_LANES = ("kick", "snare", "hat", "clap", "crash")
PITCHED_LANES = ("bass", "lead", "pad", "vox", "riser")
KNOWN_LANES = DRUM_LANES + PITCHED_LANES

SCALES = {
    "major": (0, 2, 4, 5, 7, 9, 11),
    "minor": (0, 2, 3, 5, 7, 8, 10),
    "pentatonic_major": (0, 2, 4, 7, 9),
    "pentatonic_minor": (0, 3, 5, 7, 10),
}

DEFAULT_STEPS_PER_BAR = 16

# What each lane contributes to a step's claim on being charted. The kick and
# snare carry the backbone a player's ear follows, so they outrank the hats.
LANE_SALIENCE = {
    "kick": 3.0,
    "snare": 2.5,
    "clap": 2.0,
    "bass": 1.5,
    "lead": 1.0,
    "vox": 1.2,
    "crash": 1.0,
    "hat": 0.4,
    "pad": 0.2,
    "riser": 0.0,
}

ACCENT_BONUS = 2.0


class ScoreError(Exception):
    pass


class Event:
    __slots__ = ("beat", "lane", "note", "accent", "beats")

    def __init__(self, beat, lane, note=None, accent=False, beats=0.25):
        self.beat = beat
        self.lane = lane
        self.note = note
        self.accent = accent
        self.beats = beats

    def __repr__(self):
        return "Event(beat=%.3f, lane=%s, note=%s, accent=%s)" % (
            self.beat,
            self.lane,
            self.note,
            self.accent,
        )


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        score = json.load(handle)

    problems = validate(score)

    if problems:
        raise ScoreError("%s:\n  %s" % (os.path.basename(path), "\n  ".join(problems)))

    return score


def _lane_config(value):
    if isinstance(value, str):
        return {"pattern": value}

    if isinstance(value, dict) and isinstance(value.get("pattern"), str):
        return value

    return None


def validate(score):
    problems = []

    for key in ("id", "title", "bpm", "sections"):
        if key not in score:
            problems.append("missing required key %r" % key)

    if problems:
        return problems

    if not isinstance(score["id"], str) or not score["id"]:
        problems.append("id must be a non-empty string")

    bpm = score.get("bpm")

    if not isinstance(bpm, (int, float)) or bpm <= 0:
        problems.append("bpm must be a positive number")

    scale = score.get("scale", "major")

    if scale not in SCALES:
        problems.append("unknown scale %r (have %s)" % (scale, ", ".join(sorted(SCALES))))

    steps_per_bar = score.get("stepsPerBar", DEFAULT_STEPS_PER_BAR)

    if not isinstance(steps_per_bar, int) or steps_per_bar <= 0:
        problems.append("stepsPerBar must be a positive integer")
        return problems

    sections = score.get("sections")

    if not isinstance(sections, list) or not sections:
        problems.append("sections must be a non-empty list")
        return problems

    for index, section in enumerate(sections):
        where = "section %d (%s)" % (index + 1, section.get("name", "unnamed"))

        if not isinstance(section.get("bars"), int) or section["bars"] <= 0:
            problems.append("%s: bars must be a positive integer" % where)

        lanes = section.get("lanes")

        if not isinstance(lanes, dict) or not lanes:
            problems.append("%s: lanes must be a non-empty object" % where)
            continue

        for lane, value in lanes.items():
            if lane not in KNOWN_LANES:
                problems.append("%s: unknown lane %r (have %s)" % (where, lane, ", ".join(KNOWN_LANES)))
                continue

            config = _lane_config(value)

            if config is None:
                problems.append("%s: lane %r must be a pattern string or an object with one" % (where, lane))
                continue

            pattern = config["pattern"]

            if len(pattern) % steps_per_bar != 0:
                problems.append(
                    "%s: lane %r pattern is %d chars, not a multiple of stepsPerBar (%d)"
                    % (where, lane, len(pattern), steps_per_bar)
                )

            if lane in PITCHED_LANES and not isinstance(config.get("root", 60), int):
                problems.append("%s: lane %r root must be an integer MIDI note" % (where, lane))

    return problems


def degree_to_note(degree, root, scale_name):
    scale = SCALES[scale_name]
    index = degree - 1
    octave, position = divmod(index, len(scale))

    return root + octave * 12 + scale[position]


def expand(score):
    """Flatten the sections into a flat, beat-ordered list of Events.

    Beat positions are 1-indexed to match Timing.beatToSeconds in the game,
    where beat 1 is time zero.
    """
    steps_per_bar = score.get("stepsPerBar", DEFAULT_STEPS_PER_BAR)
    beats_per_bar = score.get("beatsPerBar", 4)
    scale_name = score.get("scale", "major")
    beats_per_step = beats_per_bar / float(steps_per_bar)

    events = []
    bar_cursor = 0

    for section in score["sections"]:
        bars = section["bars"]

        for lane, value in section["lanes"].items():
            config = _lane_config(value)
            pattern = config["pattern"]
            root = config.get("root", 36 if lane == "bass" else 60)
            pattern_bars = len(pattern) // steps_per_bar

            for bar in range(bars):
                source_bar = bar % pattern_bars

                for step in range(steps_per_bar):
                    symbol = pattern[source_bar * steps_per_bar + step]

                    if symbol == ".":
                        continue

                    absolute_step = (bar_cursor + bar) * steps_per_bar + step
                    beat = 1.0 + absolute_step * beats_per_step

                    if lane in DRUM_LANES:
                        if symbol not in ("x", "X"):
                            continue

                        events.append(Event(beat, lane, accent=(symbol == "X"), beats=beats_per_step))
                        continue

                    if symbol == "-":
                        # A chord is several events on one beat; all of them hold.
                        if events and events[-1].lane == lane:
                            held_beat = events[-1].beat

                            for event in reversed(events):
                                if event.lane != lane or event.beat != held_beat:
                                    break

                                event.beats += beats_per_step
                        continue

                    if not symbol.isdigit() or symbol == "0":
                        continue

                    degree = int(symbol)
                    degrees = (degree, degree + 2, degree + 4) if config.get("chord") else (degree,)

                    for chord_degree in degrees:
                        note = degree_to_note(chord_degree, root, scale_name)
                        events.append(Event(beat, lane, note=note, beats=beats_per_step))

        bar_cursor += bars

    events.sort(key=lambda event: (event.beat, event.lane))

    return events


def total_beats(score):
    beats_per_bar = score.get("beatsPerBar", 4)

    return sum(section["bars"] for section in score["sections"]) * beats_per_bar


def duration_seconds(score):
    return total_beats(score) * 60.0 / score["bpm"]


def salience_by_beat(events):
    """How strongly each beat position asks to be charted."""
    weights = {}

    for event in events:
        weight = LANE_SALIENCE.get(event.lane, 0.5)

        if event.accent:
            weight += ACCENT_BONUS

        weights[event.beat] = weights.get(event.beat, 0.0) + weight

    return weights
