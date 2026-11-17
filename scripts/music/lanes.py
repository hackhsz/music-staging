"""Chart the four-lane highway from the melody, the way lane games do.

The floor charts land on the drum backbone, which on a highway reads as a
metronome. Here notes follow the melody instead (the voice, or the lead synth
where it carries the tune), so pressing plays the tune:
each melodic phrase spreads its pitches across the lanes from low (left) to high
(right), sustained notes become holds, and where the lead rests the drums fill
in so the lanes never go quiet for long.
"""

from . import score as score_model

LANES = 4
BEAT_EPSILON = 1e-6

# grid: the finest beat subdivision a note may sit on. minGap: the closest two
# notes may be. fillStride and fillAfter: where the lead rests for at least
# fillAfter beats, drum hits on fillStride beats take over.
DIFFICULTIES = {
    "easy": {"grid": 1.0, "minGap": 1.0, "fillStride": 2.0, "fillAfter": 4.0},
    "normal": {"grid": 0.5, "minGap": 0.5, "fillStride": 1.0, "fillAfter": 2.0},
    "hard": {"grid": 0.5, "minGap": 0.5, "fillStride": 0.5, "fillAfter": 1.0},
    "expert": {"grid": 0.25, "minGap": 0.25, "fillStride": 0.25, "fillAfter": 0.75},
}

# A phrase is at most this many beats, and a rest at least PHRASE_BREAK_BEATS
# long ends one early. Each phrase spreads its own pitches over the lanes, so a
# melody that wanders keeps using all four.
PHRASE_BEATS = 8.0
PHRASE_BREAK_BEATS = 2.0
HOLD_MIN_BEATS = 0.75
HOLD_GAP_FRACTION = 0.7
HOLD_MAX_SECONDS = 2.0
# Ties go to the first, so a sung line wins over a lead doubling it.
MELODIC_LANES = ("vox", "lead")
FILL_LANES = {"kick": (1, 2), "snare": (3, 4), "clap": (4, 3)}
FILL_MIN_SALIENCE = 2.0


def _on_grid(beat, grid):
    offset = (beat - 1.0) / grid
    return abs(offset - round(offset)) < BEAT_EPSILON


def _phrases(notes):
    phrases = []
    current = []

    for event in notes:
        rested = current and event.beat - (current[-1].beat + current[-1].beats) >= PHRASE_BREAK_BEATS
        crossed = current and (event.beat - 1.0) // PHRASE_BEATS != (current[0].beat - 1.0) // PHRASE_BEATS

        if rested or crossed:
            phrases.append(current)
            current = []

        current.append(event)

    if current:
        phrases.append(current)

    return phrases


def _lane_for_pitch(pitches):
    """Spread a phrase's distinct pitches evenly from lane 1 to lane 4."""
    distinct = sorted(set(pitches))

    if len(distinct) == 1:
        return {distinct[0]: 2}

    return {pitch: 1 + int(round(index * (LANES - 1) / (len(distinct) - 1))) for index, pitch in enumerate(distinct)}


def _melodic_line(events):
    """The tune a player hears: per phrase, the voice, or the lead where it is busier."""
    by_window = {}

    for event in events:
        if event.lane in MELODIC_LANES:
            window = int((event.beat - 1.0) // PHRASE_BEATS)
            by_window.setdefault(window, {}).setdefault(event.lane, []).append(event)

    line = []

    for lanes_in_window in by_window.values():
        busiest = max(MELODIC_LANES, key=lambda lane: len(lanes_in_window.get(lane, [])))
        line.extend(lanes_in_window.get(busiest, []))

    return sorted(line, key=lambda event: event.beat)


def _melody(events, profile):
    kept = []

    for event in _melodic_line(events):
        if not _on_grid(event.beat, profile["grid"]):
            continue

        if kept and event.beat - kept[-1].beat < profile["minGap"] - BEAT_EPSILON:
            continue

        kept.append(event)

    notes = []

    for phrase in _phrases(kept):
        lanes = _lane_for_pitch([event.note for event in phrase])

        for event in phrase:
            notes.append({"beat": event.beat, "x": lanes[event.note], "y": 1, "_beats": event.beats})

    return notes


def _fills(events, notes, total, profile):
    """Drum hits in the gaps the melody leaves."""
    stride = profile["fillStride"]
    weights = score_model.salience_by_beat(events)
    hits = {}

    for event in events:
        if event.lane in FILL_LANES and _on_grid(event.beat, stride):
            hits.setdefault(round(event.beat, 4), event.lane)

    taken = sorted(note["beat"] for note in notes)
    fills = []
    turn = 0

    def gap_around(beat):
        before = max((b for b in taken if b <= beat), default=-1e9)
        after = min((b for b in taken if b > beat), default=1e9)
        return before, after

    for beat in sorted(hits):
        if beat > total:
            continue

        before, after = gap_around(beat)

        if after - before < profile["fillAfter"]:
            continue

        if beat - before < profile["minGap"] or after - beat < profile["minGap"]:
            continue

        if weights.get(beat, 0.0) < FILL_MIN_SALIENCE:
            continue

        if fills and beat - fills[-1]["beat"] < stride - BEAT_EPSILON:
            continue

        lane = FILL_LANES[hits[beat]][turn % 2]
        turn += 1
        fills.append({"beat": beat, "x": lane, "y": 1, "_beats": 0.0})

    return fills


def build(score, events, difficulty):
    profile = DIFFICULTIES[difficulty]
    total = score_model.total_beats(score)
    beat_seconds = 60.0 / float(score["bpm"])
    notes = _melody(events, profile)
    notes = sorted(notes + _fills(events, notes, total, profile), key=lambda note: note["beat"])

    steps = []

    for index, note in enumerate(notes):
        step = {"beat": note["beat"], "x": note["x"], "y": 1}
        following = notes[index + 1]["beat"] if index + 1 < len(notes) else None

        if note["_beats"] >= HOLD_MIN_BEATS:
            seconds = min(note["_beats"] * beat_seconds, HOLD_MAX_SECONDS)

            if following is not None:
                seconds = min(seconds, (following - note["beat"]) * beat_seconds * HOLD_GAP_FRACTION)

            if seconds >= HOLD_MIN_BEATS * beat_seconds * HOLD_GAP_FRACTION:
                step["type"] = "hold"
                step["holdSeconds"] = round(seconds, 3)

        steps.append(step)

    return steps
