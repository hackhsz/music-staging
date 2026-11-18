"""Chart the floor from a library of authored patterns, with generated bars between.

A pattern is one or two bars of steps timed in beats, in the dancer's frame
(offsets from the tile they stand on, forward is -y) or the board's (fixed
cells). Each step asks for one tile, any tile of a set, or a hold. The song is
walked bar by bar: most bars take a library pattern the difficulty and the
section's energy allow, turned to fit the pad; the rest are generated, the
walk's move shapes laid on the song's own onsets. Either way a step is kept
only if every tile the dancer might be standing on can reach it in time:
d * m <= gap * 60000 / bpm - s, with m and s measured per difficulty.
"""

import math
import random

from . import floor

CENTRE = floor.CENTRE
BOARD = floor.BOARD
# The pad's largest "any of these tiles" set, as SongSchema.MaxZoneTiles.
ZONE_MAX_TILES = 10
BAR_BEATS = 4
LIBRARY_SHARE = 0.8
NO_REPEAT_BARS = 8
EASY_START_BEATS = 8
FIRST_STEP_BEATS = 4
FIRST_STEP_SECONDS = 2.0
TRIES_PER_BAR = 24
ENERGY_LEVEL = {"calm": "low", "build": "mid", "chorus": "high", "drop": "high"}

# m: ms one tile move costs a player, input included; s: ms to settle before the
# beat. rest is (phrase beats, empty beats at its end); stretch 2 halves density.
# grid is the beats between a generated bar's steps per energy; offbeats lets
# the song's picked half-beat hits in between.
RULES = {
    "easy": {"m": 400, "s": 100, "gap": 2.0, "perBeat": 1.0, "rest": (16, 4), "grid": {}, "offbeats": False},
    "normal": {"m": 300, "s": 100, "gap": 1.0, "perBeat": 1.0, "rest": (16, 2), "grid": {"calm": 2.0}, "offbeats": False},
    "hard": {"m": 220, "s": 60, "gap": 0.5, "perBeat": 1.5, "rest": (32, 2), "grid": {}, "offbeats": True},
    "expert": {"m": 200, "s": 50, "gap": 0.5, "perBeat": 1.5, "rest": (32, 2), "grid": {"drop": 0.5}, "offbeats": True},
}
TAGS = {"easy": "easy", "normal": "normal", "hard": "hard", "expert": "hard"}

ONE, ANY, HOLD = "one", "any", "hold"
ALL_LEVELS = ("low", "mid", "high")


def _pattern(pid, frame, beats, steps, diff, energy=ALL_LEVELS, stretch=(1,)):
    return {"id": pid, "frame": frame, "beats": beats, "steps": steps, "diff": diff, "energy": energy, "stretch": stretch}


def _cols(*columns):
    return [(x, y) for x in columns for y in range(1, BOARD + 1)]


def _rows(*rows):
    return [(x, y) for y in rows for x in range(1, BOARD + 1)]


def _block(x, y):
    return [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]


RING = [(x, y) for x in (2, 3, 4) for y in (2, 3, 4) if (x, y) != CENTRE]
SIDES = [(-1, 0), (1, 0)]

LIBRARY = [
    _pattern("RT-SHUTTLE", "player", 4, [(0, ONE, [(1, 0)]), (1, ONE, [(0, 0)]), (2, ONE, [(1, 0)]), (3, ONE, [(0, 0)])],
             ("easy", "normal", "hard"), ("low", "mid"), (1, 2)),
    _pattern("RT-OUTBACK", "player", 4, [(0, ONE, [(0, -1)]), (1, ONE, [(0, 0)]), (2, ONE, [(0, 1)]), (3, ONE, [(0, 0)])],
             ("easy", "normal"), ("low", "mid"), (1, 2)),
    _pattern("RT-LINE3", "player", 4, [(0, ONE, [(1, 0)]), (1, ONE, [(2, 0)]), (2, ONE, [(1, 0)]), (3, ONE, [(0, 0)])],
             ("normal", "hard"), ("mid", "high"), (1, 2)),
    _pattern("RT-BOX", "player", 4, [(0, ONE, [(1, 0)]), (1, ONE, [(1, -1)]), (2, ONE, [(0, -1)]), (3, ONE, [(0, 0)])],
             ("normal", "hard"), ("mid", "high"), (1, 2)),
    _pattern("RT-STAIRS", "player", 4, [(0, ONE, [(0, -1)]), (1, ONE, [(0, -2)]), (2, ONE, [(1, -2)]), (3, ONE, [(1, -3)])],
             ("hard",), ("mid", "high")),
    _pattern("RT-HALFPAIR", "player", 4, [(0, ONE, [(1, 0)]), (0.5, ONE, [(0, 0)]), (1, ONE, [(-1, 0)])],
             ("hard",), ("high",)),
    _pattern("CH-SIDE", "player", 4, [(0, ANY, SIDES), (2, ONE, [(0, 0)])],
             ("easy", "normal"), ("mid", "high"), (1, 2)),
    _pattern("CH-FOUR", "player", 4, [(0, ANY, SIDES + [(0, -1), (0, 1)]), (2, ONE, [(0, 0)])],
             ("easy",), ("low", "mid"), (1, 2)),
    _pattern("CH-WIDE", "player", 4, [(0, ANY, [(-2, 0), (2, 0)]), (2, ONE, [(0, 0)])],
             ("easy", "normal"), ("mid", "high"), (1, 2)),
    _pattern("CH-FORK", "player", 4, [
        (0, ANY, SIDES), (1, ANY, [(-1, -1), (1, -1)]), (2, ANY, [(-1, -2), (1, -2)]), (3, ONE, [(0, -2)]),
    ], ("normal", "hard"), ("high",), (1, 2)),
    _pattern("CH-CORNERS", "player", 4, [(0, ANY, [(-1, -1), (1, 1)]), (2, ONE, [(0, 0)])],
             ("normal",), ("mid", "high"), (1, 2)),
    _pattern("ZN-HALVES", "board", 8, [(0, ANY, _cols(1, 2)), (2, ANY, _cols(4, 5)), (4, ANY, _cols(1, 2)), (6, ANY, _cols(4, 5))],
             ("easy",)),
    _pattern("ZN-ROWS", "board", 8, [(0, ANY, _rows(2)), (2, ANY, _rows(4)), (4, ANY, _rows(2)), (6, ANY, _rows(4))],
             ("easy",)),
    _pattern("ZN-BLOCKS", "board", 8, [(0, ANY, _block(1, 1)), (2, ANY, _block(4, 1)), (4, ANY, _block(4, 4)), (6, ANY, _block(1, 4))],
             ("easy", "normal"), ("mid", "high")),
    _pattern("ZN-RING", "board", 4, [(0, ANY, RING), (2, ONE, [CENTRE])],
             ("easy",), ("low", "mid"), (1, 2)),
    _pattern("ZN-COLUMN", "board", 8, [(0, ANY, _cols(1)), (4, ANY, _cols(5))],
             ("easy", "normal")),
    _pattern("HD-TWO", "player", 4, [(0, HOLD, [(1, 0)], 2), (3, ONE, [(0, 0)])],
             ("easy", "normal", "hard"), ("low", "mid")),
]

# The walk's moves, one tile at a time and never on a diagonal, for generated bars.
GENERATED = {
    name: moves
    for name, moves in floor.PATTERNS.items()
    if all(abs(dx) + abs(dy) == 1 for dx, dy in moves)
}


def _tightest(pattern):
    beats = [entry[0] for entry in pattern["steps"]]
    return min((b - a for a, b in zip(beats, beats[1:])), default=pattern["beats"])


def _distance(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def _in_bounds(tile):
    return 1 <= tile[0] <= BOARD and 1 <= tile[1] <= BOARD


class _Reach:
    def __init__(self, difficulty, bpm):
        self.rules = RULES[difficulty]
        self.beat_ms = 60000.0 / bpm
        self.travel = min(self.rules["perBeat"], floor.PROFILES[difficulty]["maxBeatTravel"])

    def ok(self, distance, gap_beats):
        if distance == 0 or gap_beats < self.rules["gap"] - floor.EPS:
            return False

        # One tile is the reach rule's call alone: a half-beat hop passes it only at slow tempos.
        if distance > max(1, math.floor(self.travel * gap_beats + floor.EPS)):
            return False

        return distance * self.rules["m"] <= gap_beats * self.beat_ms - self.rules["s"] + floor.EPS


class _State:
    """Where the dancer may stand and from when, after the steps so far."""

    def __init__(self):
        self.possible = {CENTRE}
        self.free_at = None

    def copy(self):
        state = _State()
        state.possible = set(self.possible)
        state.free_at = self.free_at
        return state

    def take(self, reach, beat, rule, tiles, hold_beats):
        """Moves the dancer onto a step, or returns False if it cannot be played from here."""
        if not tiles or not all(_in_bounds(tile) for tile in tiles) or len(tiles) > ZONE_MAX_TILES:
            return False

        if self.possible & set(tiles):
            return False

        if self.free_at is None:
            if not any(_distance(tile, CENTRE) <= 1 for tile in tiles):
                return False
            reachable = list(tiles)
        else:
            gap = beat - self.free_at
            reachable = [tile for tile in tiles if any(reach.ok(_distance(spot, tile), gap) for spot in self.possible)]

            if not all(any(reach.ok(_distance(spot, tile), gap) for tile in tiles) for spot in self.possible):
                return False

        self.possible = set(reachable if rule == ANY else tiles[:1])
        self.free_at = beat + (hold_beats if rule == HOLD else 0.0)
        return True


def _orient_board(orient, tile):
    dx, dy = orient(tile[0] - CENTRE[0], tile[1] - CENTRE[1])
    return (CENTRE[0] + dx, CENTRE[1] + dy)


class _Library:
    def __init__(self, notes, sections, end_beat, bpm, difficulty, rng, first_downbeat):
        self.notes = sorted(note.beat for note in notes)
        self.sections = sections
        self.end_beat = end_beat
        self.bpm = bpm
        self.difficulty = difficulty
        self.tag = TAGS[difficulty]
        self.rules = RULES[difficulty]
        self.reach = _Reach(difficulty, bpm)
        self.rng = rng
        self.start = first_downbeat
        self.state = _State()
        self.steps = []
        self.recent = []
        self.instances = 0

    def _resting(self, beat):
        phrase, empty = self.rules["rest"]
        into = round(beat - self.start, 4) % phrase
        return into >= phrase - empty - floor.EPS

    def _options(self, bar, energy, early):
        level = ENERGY_LEVEL[energy]
        allowed = [
            pattern for pattern in LIBRARY
            if self.tag in pattern["diff"] and level in pattern["energy"]
            and (not early or 2 in pattern["stretch"] or pattern["frame"] == "board")
        ]
        barred = {pid for at, pid in self.recent if bar - at < NO_REPEAT_BARS * BAR_BEATS}
        fresh = [pattern for pattern in allowed if pattern["id"] not in barred]

        if fresh:
            return fresh

        # A small set at this difficulty and energy runs out inside the window;
        # then only the pattern just played stays out.
        last = self.recent[-1][1] if self.recent else None
        return [pattern for pattern in allowed if pattern["id"] != last]

    def _place(self, candidate):
        """Takes a list of (beat, rule, tiles, hold beats) if every step fits, from a copy of the state."""
        state = self.state.copy()

        for beat, rule, tiles, hold in candidate:
            if not state.take(self.reach, beat, rule, tiles, hold):
                return None

        return state

    def _library_bar(self, bar, energy, early):
        options = self._options(bar, energy, early)
        self.rng.shuffle(options)
        beat_seconds = 60.0 / self.bpm

        for pattern in options[:TRIES_PER_BAR]:
            stretch = 2 if (early or _tightest(pattern) < self.rules["gap"] - floor.EPS) and 2 in pattern["stretch"] else 1

            if _tightest(pattern) * stretch < self.rules["gap"] - floor.EPS:
                continue

            span = pattern["beats"] * stretch

            if bar + span > self.end_beat - BAR_BEATS:
                continue

            origins = sorted(self.state.possible) if pattern["frame"] == "player" else [None]
            orients = list(floor.ORIENTATIONS)
            self.rng.shuffle(orients)

            for origin in origins:
                for orient in orients:
                    candidate = []

                    for entry in pattern["steps"]:
                        beat = bar + entry[0] * stretch

                        if self._resting(beat):
                            continue

                        if origin is None:
                            tiles = [_orient_board(orient, tile) for tile in entry[2]]
                        else:
                            tiles = [(origin[0] + dx, origin[1] + dy) for dx, dy in (orient(*tile) for tile in entry[2])]

                        hold = entry[3] * stretch if entry[1] == HOLD else 0.0
                        candidate.append((round(beat, 4), entry[1], tiles, hold))

                    state = self._place(candidate) if candidate else None

                    if state is not None:
                        self._commit(candidate, state, pattern["id"], beat_seconds)
                        self.recent.append((bar, pattern["id"]))
                        return span

        return None

    def _generated_bar(self, bar, energy):
        last = self.state.free_at
        beats = []
        grid = self.rules["grid"].get(energy, self.rules["gap"] if self.rules["gap"] >= 1 else 1.0)
        slots = {round(bar + k * grid, 4) for k in range(int(BAR_BEATS / grid))}

        if self.rules["offbeats"]:
            slots |= {round(beat, 4) for beat in self.notes if bar - floor.EPS <= beat < bar + BAR_BEATS - floor.EPS}

        for beat in sorted(slots):
            if self._resting(beat):
                continue

            previous = beats[-1] if beats else last

            if previous is None or beat - previous >= self.rules["gap"] - floor.EPS:
                beats.append(round(beat, 4))

        if not beats:
            return None

        names = sorted(GENERATED)
        self.rng.shuffle(names)

        for name in names[:TRIES_PER_BAR]:
            for orient in floor.ORIENTATIONS:
                moves = [orient(*move) for move in GENERATED[name]]

                for origin in sorted(self.state.possible):
                    tile, candidate = origin, []

                    for index, beat in enumerate(beats):
                        dx, dy = moves[index % len(moves)]
                        tile = (tile[0] + dx, tile[1] + dy)
                        candidate.append((beat, ONE, [tile], 0.0))

                    state = self._place(candidate)

                    if state is not None:
                        self._commit(candidate, state, "GEN-" + name.upper(), 60.0 / self.bpm)
                        return BAR_BEATS

        return None

    def _commit(self, candidate, state, pid, beat_seconds):
        self.instances += 1
        self.state = state

        for beat, rule, tiles, hold in candidate:
            step = {"beat": beat, "x": tiles[0][0], "y": tiles[0][1], "pid": pid, "pattern": self.instances}

            if rule == ANY and len(tiles) > 1:
                step["type"] = "shape"
                step["zone"] = [{"x": x, "y": y} for x, y in tiles]
            elif rule == HOLD:
                step["type"] = "hold"
                step["holdSeconds"] = round(hold * beat_seconds, 3)

            self.steps.append(step)

    def run(self):
        bar = self.start

        while bar + BAR_BEATS <= self.end_beat - BAR_BEATS:
            if self.rules["rest"][1] >= BAR_BEATS and self._resting(bar):
                bar += BAR_BEATS
                continue

            energy = floor.energy_at(self.sections, bar)
            early = bar - self.start < EASY_START_BEATS
            span = None

            if early or self.rng.random() < LIBRARY_SHARE:
                span = self._library_bar(bar, energy, early)

            if span is None and not early:
                span = self._generated_bar(bar, energy)

            if span is None and not early:
                span = self._library_bar(bar, energy, early)

            bar += span or BAR_BEATS

        return self.steps


def _first_downbeat(onsets, bpm):
    earliest = max(1.0 + FIRST_STEP_BEATS - 1, 1.0 + FIRST_STEP_SECONDS * bpm / 60.0)

    for onset in sorted(onsets, key=lambda onset: onset.beat):
        if onset.downbeat and onset.beat >= earliest - floor.EPS:
            return round(onset.beat, 4)

    return math.ceil(earliest)


def build(onsets, sections, end_beat, bpm, difficulty, seed=0, rhythm=None):
    """The floor chart from the library: steps sorted by beat, and the merged sections."""
    profile = floor.PROFILES[difficulty]
    rng = random.Random(seed * 31 + len(difficulty) * 7919)
    sections = floor.merge_sections(sections)
    ordered = sorted(onsets, key=lambda onset: onset.beat)

    if rhythm is None:
        notes = floor.pick(ordered, sections, end_beat, profile, bpm)
    else:
        by_beat = {round(onset.beat, 4): onset for onset in ordered}
        notes = [by_beat[round(beat, 4)] for beat in sorted(rhythm) if round(beat, 4) in by_beat]

    layout = _Library(notes, sections, end_beat, bpm, difficulty, rng, _first_downbeat(ordered, bpm))
    return layout.run(), sections


def check(steps, bpm, difficulty):
    """Replays a chart against the reach rule; problems as readable strings."""
    reach = _Reach(difficulty, bpm)
    state = _State()
    beat_seconds = 60.0 / bpm
    problems = []

    for step in steps:
        zone = step.get("zone")
        tiles = [(tile["x"], tile["y"]) for tile in zone] if zone else [(step["x"], step["y"])]
        rule = ANY if zone else HOLD if step.get("type") == "hold" else ONE
        hold = step.get("holdSeconds", 0.0) / beat_seconds if rule == HOLD else 0.0

        if not state.take(reach, step["beat"], rule, tiles, hold):
            problems.append("%s step at beat %.3f cannot be reached from every tile the dancer may be on" % (rule, step["beat"]))
            state = _State()
            state.possible = set(tiles)
            state.free_at = step["beat"] + hold

    return problems


def describe(steps, end_beat):
    """The mix numbers the spec asks for, so a chart can be judged without playing it."""
    if not steps:
        return "no steps"

    span = max(end_beat - steps[0]["beat"], 1.0)
    library = sum(1 for step in steps if not step["pid"].startswith("GEN-"))
    zones = sum(1 for step in steps if step.get("zone"))
    holds = sum(1 for step in steps if step.get("type") == "hold")
    kinds = len({step["pid"] for step in steps})

    return "%.2f steps/beat, library %d%%, any-tile %d%%, holds %d, %d kinds of pattern" % (
        len(steps) / span, 100 * library // len(steps), 100 * zones // len(steps), holds, kinds,
    )
