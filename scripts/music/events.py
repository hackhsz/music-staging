"""Floor events: a few beats mid-song where the whole pad turns into something.

lava       the pad is lava but for 1-3 safe tiles that jump every 1-2 beats
spotlight  a 1-4 tile spotlight slides across the dark pad, a tile a beat
memory     the pad shows 3-6 tiles one a beat, then the player steps them back
           with their telegraphs hidden
freeze     on the way into a drop the player must not take a step for 4 beats

Each event is compiled into ordinary steps that name it (`event`, its index in
map.events), so the server judges them like any other note; SongSchema.luau
documents the fields. place() clears the chart around each event and drops the
notes after it that the player could no longer reach.
"""

import random

from . import chart, floor

KINDS = ("lava", "memory", "spotlight", "freeze")
# Off while the plain notes are tuned; the old counts were easy 1, normal 2, hard and expert 3.
EVENT_COUNT = {"easy": 0, "normal": 0, "hard": 0, "expert": 0}
NO_MEMORY = ("easy",)
LAVA_BEATS = 8
SPOTLIGHT_BEATS = 8
FREEZE_BEATS = 4
LAVA_SAFE_TILES = {"easy": 3, "normal": 2, "hard": 2, "expert": 1}
LAVA_INTERVAL = {"easy": 2, "normal": 2, "hard": 1, "expert": 1}
SPOTLIGHT_INTERVAL = {"easy": 2, "normal": 1, "hard": 1, "expert": 1}
SPOTLIGHT_SHAPES = {
    "easy": ((0, 0), (1, 0), (0, 1), (1, 1)),
    "normal": ((0, 0), (1, 0), (0, 1)),
    "hard": ((0, 0), (1, 0)),
    "expert": ((0, 0),),
}
MEMORY_LENGTH = {"normal": 4, "hard": 5, "expert": 6}
MEMORY_FAST_BPM = 150
MEMORY_FAST_LENGTH = 3
MAX_EVENT_BEATS = 16
SONG_EDGE_BEATS = 8
EVENT_SPACING_BEATS = 16
CLEAR_AFTER_BEATS = 1.0
EXTRAS_CLEAR_BEATS = 2.0
PREFERRED = {
    "lava": ("chorus", "drop"),
    "spotlight": ("build", "chorus"),
    "memory": ("calm", "build"),
    "freeze": ("drop", "chorus"),
}
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def plain(steps):
    """The steps that belong to no event, as the rest of the pipeline knows them."""
    return [step for step in steps if "event" not in step]


def _tile(step):
    return (step["x"], step["y"])


def _distance(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def _in_bounds(tile):
    return 1 <= tile[0] <= floor.BOARD and 1 <= tile[1] <= floor.BOARD


def _reach(a, b, gap_beats, beat_seconds, profile):
    move = (b[0] - a[0], b[1] - a[1])

    if move == (0, 0):
        return True

    return floor._move_ok(move, gap_beats, beat_seconds, profile, 0.0)


def _zone_follows(old, new, gap_beats, beat_seconds, profile):
    return all(any(_reach(a, b, gap_beats, beat_seconds, profile) for b in new) for a in old)


def _neighbours(tile, rng):
    options = [(tile[0] + dx, tile[1] + dy) for dx, dy in NEIGHBOURS]
    options = [option for option in options if _in_bounds(option)]
    rng.shuffle(options)
    return options


class _Placer:
    def __init__(self, difficulty, bpm, rng):
        self.difficulty = difficulty
        self.profile = floor.PROFILES[difficulty]
        self.beat_seconds = 60.0 / float(bpm)
        self.bpm = float(bpm)
        self.rng = rng

    def lava(self, start, beat):
        size = LAVA_SAFE_TILES[self.difficulty]
        interval = LAVA_INTERVAL[self.difficulty]
        path = _neighbours(start, self.rng)[0]
        zone = self._lava_zone(path, None, size)
        beats = []

        for k in range(LAVA_BEATS):
            if k > 0 and k % interval == 0:
                path = _neighbours(path, self.rng)[0]
                zone = self._lava_zone(path, zone, size)

                if zone is None:
                    return None

            beats.append((beat + k, path, zone))

        return self._zoned("lava", beat, LAVA_BEATS, beats)

    def _lava_zone(self, path, old, size):
        every = [(x, y) for x in range(1, floor.BOARD + 1) for y in range(1, floor.BOARD + 1) if (x, y) != path]

        for _ in range(60):
            zone = [path] + self.rng.sample(every, size - 1)

            if old is None or (
                set(zone) != set(old) and _zone_follows(old, zone, 1, self.beat_seconds, self.profile)
            ):
                return zone

        if old is not None:
            shift = (path[0] - old[0][0], path[1] - old[0][1])
            moved = [(x + shift[0], y + shift[1]) for x, y in old]

            if all(_in_bounds(tile) for tile in moved):
                return moved

        return None

    def spotlight(self, start, beat):
        shape = SPOTLIGHT_SHAPES[self.difficulty]
        interval = SPOTLIGHT_INTERVAL[self.difficulty]
        width = 1 + max(dx for dx, _ in shape)
        height = 1 + max(dy for _, dy in shape)
        first = _neighbours(start, self.rng)[0]
        anchor = (min(max(first[0], 1), floor.BOARD - width + 1), min(max(first[1], 1), floor.BOARD - height + 1))
        heading = self.rng.choice(NEIGHBOURS)
        cell = min(shape, key=lambda offset: _distance((anchor[0] + offset[0], anchor[1] + offset[1]), first))
        beats = []

        for k in range(SPOTLIGHT_BEATS):
            if k > 0 and k % interval == 0:
                anchor, heading = self._slide(anchor, heading, width, height)

            zone = [(anchor[0] + dx, anchor[1] + dy) for dx, dy in shape]
            beats.append((beat + k, (anchor[0] + cell[0], anchor[1] + cell[1]), zone))

        if _distance(start, beats[0][1]) == 0:
            return None

        return self._zoned("spotlight", beat, SPOTLIGHT_BEATS, beats)

    def _slide(self, anchor, heading, width, height):
        options = [heading] + [turn for turn in NEIGHBOURS if turn != heading]

        if self.rng.random() < 0.3:
            self.rng.shuffle(options)

        for dx, dy in options:
            moved = (anchor[0] + dx, anchor[1] + dy)

            if 1 <= moved[0] <= floor.BOARD - width + 1 and 1 <= moved[1] <= floor.BOARD - height + 1:
                return moved, (dx, dy)

        return anchor, heading

    def _zoned(self, kind, beat, length, beats):
        steps = [
            {
                "beat": float(at),
                "x": path[0],
                "y": path[1],
                "zone": [{"x": x, "y": y} for x, y in zone],
            }
            for at, path, zone in beats
        ]

        return {"beat": beat, "beats": length, "kind": kind}, steps, beats[-1][2]

    def memory(self, start, beat):
        interval = 2 if self.bpm > MEMORY_FAST_BPM else 1
        length = MEMORY_LENGTH[self.difficulty] if interval == 1 else MEMORY_FAST_LENGTH
        sequence = []
        here = start
        recent = [start]

        for _ in range(length):
            options = [tile for tile in _neighbours(here, self.rng) if tile not in recent[-2:]]

            if not options:
                return None

            here = options[0]
            sequence.append(here)
            recent.append(here)

        play_beat = beat + (length + 1) * interval
        span = play_beat + (length - 1) * interval - beat + 1

        if span > MAX_EVENT_BEATS:
            return None

        event = {
            "beat": beat,
            "beats": span,
            "kind": "memory",
            "interval": interval,
            "playBeat": play_beat,
            "sequence": [{"x": x, "y": y} for x, y in sequence],
        }
        steps = [
            {"beat": float(play_beat + index * interval), "x": x, "y": y, "hidden": True}
            for index, (x, y) in enumerate(sequence)
        ]

        return event, steps, [sequence[-1]]

    def freeze(self, start, beat):
        steps = [
            {"beat": float(beat + k), "x": start[0], "y": start[1], "type": "freeze"} for k in range(FREEZE_BEATS)
        ]

        return {"beat": beat, "beats": FREEZE_BEATS, "kind": "freeze"}, steps, [start]


def _candidates(kind, sections, end_beat, rng):
    """Start beats for an event of this kind, the fitting sections first."""
    bounds = [
        (beat, sections[index + 1][0] if index + 1 < len(sections) else end_beat, energy)
        for index, (beat, energy) in enumerate(sections)
    ]
    preferred, rest = [], []

    for index, (start, stop, energy) in enumerate(bounds):
        if kind == "freeze":
            lifts = index > 0 and floor.RANK[energy] > floor.RANK[bounds[index - 1][2]]
            starts = [start - FREEZE_BEATS] if lifts else []
        else:
            starts = list(range(int(start) + 4, int(stop) - MAX_EVENT_BEATS, 8))

        (preferred if energy in PREFERRED[kind] else rest).extend(starts)

    fallback = list(range(1 + SONG_EDGE_BEATS * 2, int(end_beat) - MAX_EVENT_BEATS - SONG_EDGE_BEATS, 8))
    rng.shuffle(preferred)
    rng.shuffle(rest)
    rng.shuffle(fallback)

    return [int(round(beat)) for beat in preferred + rest + fallback]


def _hold_end(step, beat_seconds):
    return step["beat"] + (step.get("holdSeconds", 0.0) / beat_seconds if step.get("type") == "hold" else 0.0)


def _compile(steps, kind, beat, placer, index):
    """steps with one event put in at beat, or None when it does not fit there."""
    beat_seconds = placer.beat_seconds
    before = [note for note in floor.notes_of(plain(steps)) if note["beat"] <= beat - 1 + floor.EPS]

    if not before:
        return None

    previous = before[-1]

    if _hold_end(previous, beat_seconds) > beat - 0.5:
        return None

    built = getattr(placer, kind)(_tile(previous), beat)

    if built is None:
        return None

    event, event_steps, exits = built
    end = event["beat"] + event["beats"]

    for step in event_steps:
        step["event"] = index

    first = event_steps[0]

    if not _reach(_tile(previous), _tile(first), first["beat"] - previous["beat"], beat_seconds, placer.profile):
        return None

    kept = []

    for step in steps:
        extra = step.get("type") in ("danger", "item")
        low = beat - (EXTRAS_CLEAR_BEATS if extra else 1.0)

        if "event" not in step and low + floor.EPS < step["beat"] < end + (CLEAR_AFTER_BEATS if extra else 0.0):
            continue

        kept.append(step)

    kept = _clear_exit(kept, exits, end - 1, _tile(previous), placer)
    order = {"danger": 1, "item": 2}

    # The note before an event is played as a plain step, so a slide there
    # never has the server tracking a path across the event's start.
    if previous.get("type") == "slide":
        del previous["type"], previous["path"]
    result = sorted(kept + event_steps, key=lambda step: (step["beat"], order.get(step.get("type"), 0)))

    return event, result


def _clear_exit(steps, exits, last_beat, entry, placer):
    """Drops what follows an event until the player can reach it from anywhere they may stand."""
    steps = list(steps)

    while True:
        notes = floor.notes_of([step for step in steps if step["beat"] > last_beat + floor.EPS and "event" not in step])

        if not notes:
            return steps

        note = notes[0]
        gap = note["beat"] - last_beat
        here = _tile(note)
        reachable = all(_reach(tile, here, gap, placer.beat_seconds, placer.profile) for tile in exits)
        moves = here != entry and (len(exits) > 1 or here != exits[0])
        held = note.get("type") in ("hold", "slide") and gap < 2

        if reachable and moves and not held:
            break

        steps.remove(note)

    first_note = notes[0]["beat"]

    return [
        step
        for step in steps
        if not (step.get("type") in ("danger", "item") and last_beat < step["beat"] <= first_note + EXTRAS_CLEAR_BEATS)
    ]


def place(steps, sections, end_beat, bpm, difficulty, seed=0):
    """The chart with its floor events compiled in, and the events, in order."""
    rng = random.Random(seed * 7919 + list(floor.PROFILES).index(difficulty) * 131 + 17)
    placer = _Placer(difficulty, bpm, rng)
    sections = floor.merge_sections(sections)
    kinds = [kind for kind in KINDS if difficulty not in NO_MEMORY or kind != "memory"]
    rng.shuffle(kinds)
    walls = [step["beat"] for step in steps if step.get("type") == "danger"]
    chosen = []

    def clears_wall(beat):
        return any(beat - EXTRAS_CLEAR_BEATS <= wall <= beat + MAX_EVENT_BEATS + CLEAR_AFTER_BEATS for wall in walls)

    for kind in kinds:
        if len(chosen) >= EVENT_COUNT[difficulty]:
            break

        candidates = _candidates(kind, sections, end_beat, rng)

        for beat in [beat for beat in candidates if not clears_wall(beat)] + [b for b in candidates if clears_wall(b)]:
            if beat < 1 + SONG_EDGE_BEATS * 2 or beat + MAX_EVENT_BEATS > end_beat - SONG_EDGE_BEATS:
                continue

            if any(abs(beat - other) < EVENT_SPACING_BEATS + MAX_EVENT_BEATS for other, _ in chosen):
                continue

            chosen.append((beat, kind))
            break

    chosen.sort()
    events = []

    for beat, kind in chosen:
        compiled = _compile(steps, kind, beat, placer, len(events) + 1)

        if compiled is None:
            continue

        event, steps = compiled
        events.append(event)

    return steps, events


def check(steps, events, bpm, difficulty):
    """Problems with the events of a chart, as readable strings."""
    profile = floor.PROFILES[difficulty]
    beat_seconds = 60.0 / float(bpm)
    problems = []

    for index, event in enumerate(events, start=1):
        start, end = event["beat"], event["beat"] + event["beats"]
        own = [step for step in steps if step.get("event") == index]
        intruders = [step for step in steps if start - floor.EPS <= step["beat"] < end - floor.EPS and step not in own]

        if intruders:
            problems.append("%s at beat %g has %d foreign step(s) inside it" % (event["kind"], start, len(intruders)))

        if not 2 <= event["beats"] <= MAX_EVENT_BEATS:
            problems.append("%s at beat %g lasts %d beats" % (event["kind"], start, event["beats"]))

        if event["kind"] == "memory" and difficulty in NO_MEMORY:
            problems.append("memory on %s" % difficulty)

        zoned = [step for step in own if "zone" in step]

        for before, after in zip(zoned, zoned[1:]):
            old = [_tile(tile) for tile in before["zone"]]
            new = [_tile(tile) for tile in after["zone"]]

            if not _zone_follows(old, new, after["beat"] - before["beat"], beat_seconds, profile):
                problems.append("%s zone at beat %g cannot be reached in time" % (event["kind"], after["beat"]))

        if event["kind"] == "freeze":
            others = floor.notes_of(plain(steps))
            near = [note for note in others if start - 1 + floor.EPS < note["beat"] < end - floor.EPS]

            if near:
                problems.append("freeze at beat %g has a note too close before it" % start)

    return problems


def luau_step(step):
    line = chart.luau_step(step)
    extras = []

    if "event" in step:
        extras.append("event = %d" % step["event"])

    if "zone" in step:
        extras.append("zone = { %s }" % ", ".join("{ x = %d, y = %d }" % (t["x"], t["y"]) for t in step["zone"]))

    if step.get("hidden"):
        extras.append("hidden = true")

    if not extras:
        return line

    return line[: -len(" },")] + ", " + ", ".join(extras) + " },"


def luau_events(events, pad):
    if not events:
        return []

    lines = ["%s\tevents = {" % pad]

    for event in events:
        parts = ["beat = %d" % event["beat"], "beats = %d" % event["beats"], 'kind = "%s"' % event["kind"]]

        if event["kind"] == "memory":
            parts.append("interval = %d" % event["interval"])
            parts.append("playBeat = %d" % event["playBeat"])
            tiles = ", ".join("{ x = %d, y = %d }" % (t["x"], t["y"]) for t in event["sequence"])
            parts.append("sequence = { %s }" % tiles)

        lines.append("%s\t\t{ %s }," % (pad, ", ".join(parts)))

    lines.append("%s\t}," % pad)

    return lines


def decorate(text, maps):
    """Puts each map's event fields and events into a module chart.to_luau wrote.

    maps is (steps, events) per map, in the order the module lists them.
    """
    lines = text.split("\n")
    out = []
    index = -1
    pending = 0
    position = 0
    in_sections = False

    for line in lines:
        stripped = line.strip()

        if stripped == "steps = {":
            index += 1
            pending = len(maps[index][0])
            position = 0
            out.append(line)
            continue

        if pending > 0:
            pad = line[: len(line) - len(line.lstrip("\t"))]
            out.append(pad[:-2] + luau_step(maps[index][0][position]))
            position += 1
            pending -= 1
            continue

        out.append(line)

        if stripped == "sections = {":
            in_sections = True
        elif in_sections and stripped == "},":
            in_sections = False
            out.extend(luau_events(maps[index][1], line[: len(line) - len(line.lstrip("\t")) - 1]))

    return "\n".join(out)
