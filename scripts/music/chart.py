"""Turn a score into one playable chart per difficulty, then emit Luau.

The score knows its sections and every hit, so it hands music/floor.py an onset
on each eighth with the drums' salience, the melody's pitch and how long the
tune rings there; floor.py picks the steps by section energy and dances them
across the pad. The travel budget is checked here with the rule
Timing.analyzeMap applies.
"""

from . import floor
from . import score as score_model

DIFFICULTIES = floor.PROFILES
BEAT_EPSILON = 1e-6
MELODY_LANES = ("vox", "lead", "bass")
SUSTAIN_LANES = ("vox", "lead")
# A hit in these lanes is what a clap is placed on.
SNAP_LANES = ("snare", "clap")
SNAP_ACCENT, SNAP_PLAIN = 1.0, 0.7
# Where the tune starts a note the step follows it, not only the drums.
MELODY_ACCENT = 1.0
# A plucked note followed by a rest is heard as a long note, so a note rings
# until the tune's next note or its section's end, up to this many beats.
RING_MAX_BEATS = 4.0
ENERGY_BY_NAME = (
    ("final chorus", "drop"),
    ("dance break", "drop"),
    ("drop", "drop"),
    ("post chorus", "chorus"),
    ("chorus", "chorus"),
    ("hook", "chorus"),
    ("pre", "build"),
    ("bridge", "build"),
    ("build", "build"),
)


def section_energy(section):
    if section.get("energy") in floor.ENERGIES:
        return section["energy"]

    name = section.get("name", "").lower()

    for keyword, energy in ENERGY_BY_NAME:
        if keyword in name:
            return energy

    return "calm"


def sections(score):
    beats_per_bar = score.get("beatsPerBar", 4)
    beat = 1.0
    result = []

    for section in score["sections"]:
        result.append((beat, section_energy(section)))
        beat += section["bars"] * beats_per_bar

    return result


def onsets(score, events):
    """One onset per eighth: drum salience, the melody pitch and how long it rings."""
    weights = {}

    for position, weight in score_model.salience_by_beat(events).items():
        key = round(position, 4)
        weights[key] = weights.get(key, 0.0) + weight

    pitches, sustains, accents, snaps = {}, {}, set(), {}

    for event in events:
        key = round(event.beat, 4)

        if event.accent:
            accents.add(key)

        if event.lane in SNAP_LANES:
            snaps[key] = max(snaps.get(key, 0.0), SNAP_ACCENT if event.accent else SNAP_PLAIN)

        if event.note is not None and event.lane in MELODY_LANES:
            rank = MELODY_LANES.index(event.lane)

            if key not in pitches or rank < pitches[key][0]:
                pitches[key] = (rank, event.note)

        if event.note is not None and event.lane in SUSTAIN_LANES:
            sustains[key] = max(sustains.get(key, 0.0), event.beats)
            weights[key] = weights.get(key, 0.0) + MELODY_ACCENT

    beats_per_bar = score.get("beatsPerBar", 4)
    total = score_model.total_beats(score)
    starts = sorted(sustains)
    ends = [beat for beat, _energy in sections(score)][1:] + [total + 1.0]

    for index, key in enumerate(starts):
        following = starts[index + 1] if index + 1 < len(starts) else total + 1.0
        section_end = min(end for end in ends if end > key + BEAT_EPSILON)
        ring = min(following, section_end) - key
        sustains[key] = max(sustains[key], min(ring, RING_MAX_BEATS))

    result = []
    melody = None
    index = 0

    while 1.0 + index * 0.5 < total + 1.0 - BEAT_EPSILON:
        beat = 1.0 + index * 0.5
        key = round(beat, 4)

        if key in pitches:
            melody = pitches[key][1]

        result.append(
            floor.Onset(
                beat,
                weights.get(key, 0.0),
                pitch=melody,
                sustain=sustains.get(key, 0.0),
                accent=key in accents,
                on_beat=index % 2 == 0,
                downbeat=index % (2 * beats_per_bar) == 0,
                snap=snaps.get(key, 0.0),
            )
        )
        index += 1

    return result


def build(score, events, difficulty, seed=None):
    """The floor chart and its sections for one difficulty."""
    seed = seed if seed is not None else score.get("seed", 0)
    end_beat = score_model.total_beats(score) + 1.0

    return floor.build(onsets(score, events), sections(score), end_beat, score["bpm"], difficulty, seed)


def analyze(steps, difficulty):
    """The travel-budget check Timing.analyzeMap runs in game, over the notes."""
    profile = DIFFICULTIES[difficulty]
    warnings = []
    worst = 0.0
    previous = None
    notes = floor.notes_of(steps)

    for index, step in enumerate(notes):
        if previous is not None:
            gap = max(step["beat"] - previous["beat"], 0.001)
            travel = abs(step["x"] - previous["x"]) + abs(step["y"] - previous["y"])
            per_beat = travel / gap
            worst = max(worst, per_beat)

            if per_beat > profile["maxBeatTravel"]:
                warnings.append(
                    "note %d at beat %.2f needs %.2f tiles/beat, budget is %d"
                    % (index + 1, step["beat"], per_beat, profile["maxBeatTravel"])
                )

        previous = step

    return {"ok": not warnings, "warnings": warnings, "maxObservedTravel": worst, "stepCount": len(notes)}


def reachability(steps, bpm, difficulty="normal", tile_seconds=None):
    """Can the avatar cross every move in time, and is there slack to spare?"""
    beat_seconds = 60.0 / float(bpm)
    walk_seconds = tile_seconds if tile_seconds is not None else DIFFICULTIES[difficulty]["stepSeconds"]
    notes = floor.notes_of(steps)
    tightest = None

    for index in range(1, len(notes)):
        previous, step = notes[index - 1], notes[index]
        gap = (step["beat"] - previous["beat"]) * beat_seconds
        travel = abs(step["x"] - previous["x"]) + abs(step["y"] - previous["y"])

        if travel == 0:
            continue

        needed = travel * walk_seconds

        if tightest is None or gap - needed < tightest[0]:
            tightest = (gap - needed, gap, needed, travel)

    if tightest is None:
        return {"walkable": True, "slackSeconds": None}

    slack, gap, needed, travel = tightest

    return {
        "walkable": slack >= 0,
        "slackSeconds": slack,
        "tightestGap": gap,
        "tightestWalk": needed,
        "tightestTiles": travel,
    }


def target_score(steps):
    """A goal a competent clear should pass, not a perfect run.

    Derived from Shared/Scoring.luau rather than guessed: every step landing
    at Good with the combo never breaking. Perfects and step-type bonuses then
    carry the player comfortably past it.
    """
    count = sum(1 for step in steps if step.get("type") != "item")
    good_points = count * 500
    combo_bonus = 10 * count * (count + 1) // 2

    return int(round((good_points + combo_bonus) / 100.0) * 100)


def _luau_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"

    if isinstance(value, str):
        return '"%s"' % value.replace('"', '\\"')

    if isinstance(value, float):
        if abs(value - round(value)) < BEAT_EPSILON:
            return str(int(round(value)))

        return ("%.4f" % value).rstrip("0").rstrip(".")

    return str(value)


def luau_sections(sections, pad):
    lines = ["%s\tsections = {" % pad]

    for beat, energy in sections:
        lines.append('%s\t\t{ beat = %s, energy = "%s" },' % (pad, _luau_value(float(beat)), energy))

    lines.append("%s\t}," % pad)

    return lines


def luau_step(step):
    parts = ["beat = %s" % _luau_value(step["beat"]), "x = %d" % step["x"], "y = %d" % step["y"]]

    if "type" in step:
        parts.append('type = "%s"' % step["type"])

    if "holdSeconds" in step:
        parts.append("holdSeconds = %s" % _luau_value(step["holdSeconds"]))

    if "poseBeats" in step:
        parts.append("poseBeats = %s" % _luau_value(step["poseBeats"]))

    if "rush" in step:
        parts.append("rush = %s" % _luau_value(step["rush"]))

    if "path" in step:
        tiles = ", ".join("{ x = %d, y = %d }" % (tile["x"], tile["y"]) for tile in step["path"])
        parts.append("path = { %s }" % tiles)

    return "\t\t{ %s }," % ", ".join(parts)


def _luau_map(score, chart, difficulty, indent, highway=None):
    steps, sections = chart
    pad = "\t" * indent
    theme = score.get("visualTheme", {})
    duration = score_model.duration_seconds(score)

    lines = [
        "%s{" % pad,
        '%s\tid = "%s-%s",' % (pad, score["id"], difficulty),
        '%s\ttitle = "%s",' % (pad, score["title"]),
        '%s\tartist = "%s",' % (pad, score.get("artist", "Generated")),
        '%s\tdifficulty = "%s",' % (pad, difficulty),
        "%s\tbpm = %s," % (pad, _luau_value(float(score["bpm"]))),
        "%s\tdurationSeconds = %s," % (pad, _luau_value(round(duration, 2))),
        "%s\tpreviewBeats = 1," % pad,
    ]

    if theme:
        lines.append("%s\tvisualTheme = {" % pad)

        for key in ("name", "primary", "accent", "mood"):
            if key in theme:
                lines.append('%s\t\t%s = "%s",' % (pad, key, theme[key]))

        lines.append("%s\t}," % pad)

    lines.append("%s\tperformanceGoal = {" % pad)
    lines.append('%s\t\tlabel = "%s GOAL",' % (pad, difficulty.upper()))
    lines.append("%s\t\ttargetScore = %d," % (pad, target_score(steps)))
    lines.append("%s\t}," % pad)
    lines.append("%s\tsteps = {" % pad)

    for step in steps:
        lines.append(pad + luau_step(step))

    lines.append("%s\t}," % pad)
    lines.extend(luau_sections(sections, pad))

    if highway:
        lines.append("%s\thighwaySteps = {" % pad)

        for step in highway:
            lines.append(pad + luau_step(step))

        lines.append("%s\t}," % pad)

    lines.append("%s}," % pad)

    return lines


def to_luau(score, charts, module_name, source, score_path, highway=None):
    """One module holding every difficulty, shaped like GeneratedSongs.List."""
    lines = [
        # Data, not logic: steps mix taps, holds, slides, items and dangers, and strict
        # mode infers a step list's type from its first entry and rejects the rest.
        "--!nonstrict",
        "-- Generated by %s from %s. Do not edit by hand." % (source, score_path),
        "",
        "local %s = {" % module_name,
    ]

    for difficulty in sorted(charts, key=lambda name: list(DIFFICULTIES).index(name)):
        lines.extend(_luau_map(score, charts[difficulty], difficulty, 1, (highway or {}).get(difficulty)))

    lines.append("}")
    lines.append("")
    lines.append("return %s" % module_name)
    lines.append("")

    return "\n".join(lines)
