"""Lay a song's onsets out on the 5x5 floor so a chart reads as dancing.

Shared by the score charts (music/chart.py) and the audio charts
(chart-audio.py). Both hand over the same thing: onsets on an eighth-note grid,
each with a strength, the melody pitch where one is known, how long it rings,
and the song's sections with an energy each.

Stage one picks which onsets carry a step, section by section: calm passages
are sparse, choruses and drops are dense, and a section that lifts the energy
is preceded by a short rest so the drop lands. Plain steps are at least a beat
apart; anything faster is a rush, so the whole fast run shows at once.

Stage two moves the dancer one tile at a time in named patterns (zig-zags,
L-turns, boxes, runs across the pad) and orients each one by the melody:
a rising line steps forward or right, a falling one back or left. Every move is
checked against the difficulty's travel budget and step time, the way
Timing.analyzeMap and onBeat judging see it. Easy and normal never step
straight back to the tile just left within a beat; hard and expert do it once at most.

Some notes then become slides, a cyan path of 2-4 tiles to walk, choruses get
gold items off the path and the loudest parts get danger walls that sweep the
pad, with a hole wherever the dancer has to stand. Once the floor events are in,
dress() turns a note now and then into a shape: a few tiles, any of which will do.

Between the two stages some pulse slots become moves: a green hold at
four-bar phrase ends in calm and build passages and where a chorus or drop
winds down, a break of four beats or more (at least 2.5 s) on easy and normal
and three on hard and expert, with a clap or two on its snare hits; and from
normal up a rush, a fast chain of tiles half a beat apart that follows the note
before it a beat later. Claps then fill still moments only, inside a hold or in
the middle of a rest, preferring beats where the music has a snare or clap. A
clap stays on the tile of the note before it, and the note after a clap or a
hold is a single tile away. Last, single danger tiles sit beside the path now
and then.
"""

import bisect
import math
import os
import random
import re

BOARD = 5
CENTRE = (3, 3)
EPS = 1e-4
ENERGIES = ("calm", "build", "chorus", "drop")
RANK = {energy: index for index, energy in enumerate(ENERGIES)}

# maxBeatTravel and stepSeconds are read from Timing.DifficultyProfiles when the
# module loads, so a chart is always checked against the hop time the game uses;
# the values here are only the fallback. A step's press is what onBeat judges,
# so a move of d tiles needs d presses, the last one on the beat, plus margin
# seconds to read the next target. restBars is the longest a section's energy
# may go without a two-beat breath; jumpPairs allows two-tile moves back to back.
# slides is the fewest notes between two slides (0: none), returns how many
# steps straight back to the tile just left may come in a row (None: any), and
# shapeEvery the beats between two shapes per energy, dangerEvery the beats
# between two single danger tiles beside the path, and barSpecials how many
# holds, claps, rushes, slides and danger tiles any four beats may hold.
# phraseHoldBeats is how long the break at a phrase end is held, stretched to
# breakSeconds at least, with up to breakClaps claps on the snares inside it.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIMING_PATH = os.path.join(REPO_ROOT, "src", "ReplicatedStorage", "Shared", "Timing.luau")
RHYTHM_PATH = os.path.join(REPO_ROOT, "src", "ServerScriptService", "Server", "RhythmService.server.luau")
# A steady pulse per section instead of the strongest onsets: one two-bar rhythm
# cell, repeated, so the player can lock into the groove. A slot is only kept
# where the music hits, and off-beat offsets only where it has an off-beat hit; every second cell drops its tail on
# the difficulties with "phraseRest", so each four bars ends with a breath.
PULSE_CELL_BEATS = 8.0
PULSE = {
    "easy": {
        "calm": (0, 2, 4, 6),
        "build": (0, 2, 4, 6),
        "chorus": (0, 1, 2, 4, 5, 6),
        "drop": (0, 1, 2, 4, 5, 6),
    },
    "normal": {
        "calm": (0, 1, 2, 4, 5, 6),
        "build": (0, 1, 2, 3, 4, 5, 6),
        "chorus": (0, 1, 2, 3, 4, 5, 6),
        "drop": (0, 1, 2, 3, 4, 5, 6),
    },
    "hard": {
        "calm": (0, 1, 2, 3, 4, 5, 6),
        "build": (0, 1, 2, 3, 4, 5, 6, 7),
        "chorus": (0, 1, 2, 3, 4, 5, 6, 7),
        "drop": (0, 1, 2, 3, 4, 5, 6, 7),
    },
    "expert": {
        "calm": (0, 1, 2, 3, 4, 5, 6, 7),
        "build": (0, 1, 2, 3, 4, 5, 6, 7),
        "chorus": (0, 1, 2, 3, 4, 5, 6, 7),
        "drop": (0, 1, 2, 3, 4, 5, 6, 7),
    },
}
PHRASE_REST_FROM = 5.5
# A pulse slot only takes a step where the music hits, at least this share of
# the section's strongest beat, so the steps never fall on silence or a lone hat.
PULSE_MIN_SHARE = 0.25
# Where the eighth beside a slot hits this much harder than the slot itself,
# the step moves onto it: the chart follows the song's syncopation.
SYNC_RATIO = 1.2
LAYOUT_ATTEMPTS = 8
# Fewer notes than this of a repeated section is not worth recognising.
ECHO_MIN_NOTES = 4
ECHO_PHRASE_BEATS = 8.0

PROFILES = {
    "easy": {
        "density": {"calm": 0.35, "build": 0.5, "chorus": 0.7, "drop": 0.75},
        "eighths": (),
        "run": 1,
        "maxBeatTravel": 1,
        "maxHop": 1,
        "phraseRest": True,
        "stepSeconds": 0.14,
        "margin": 0.25,
        "jump": 0,
        "jumpPairs": False,
        "walls": 0,
        "holdSpacing": 8,
        "slides": 0,
        "returns": 0,
        "shapeEvery": {"chorus": 12, "drop": 12},
        "dangerEvery": 16,
        "barSpecials": 1,
        "phraseHoldBeats": 4,
        "breakSeconds": 2.45,
        # A beginner holding still is not also asked to clap.
        "breakClaps": 0,
        "rushTiles": (),
        "rushEvery": {},
        "clapEvery": {"chorus": 32, "drop": 32},
        "itemGap": 2.0,
        "restBeats": 2.0,
        "restBars": {"calm": 2, "build": 2, "chorus": 4, "drop": 4},
    },
    "normal": {
        "density": {"calm": 0.5, "build": 0.65, "chorus": 0.8, "drop": 0.9},
        "eighths": (),
        "offbeatShare": 0.2,
        "minEighthSeconds": 0.22,
        "run": 3,
        "maxBeatTravel": 2,
        "maxHop": 1,
        "phraseRest": True,
        "stepSeconds": 0.12,
        "margin": 0.1,
        "jump": 0,
        "jumpPairs": False,
        "walls": 2,
        "holdSpacing": 6,
        "slides": 0,
        "returns": 0,
        "shapeEvery": {"calm": 12, "build": 7, "chorus": 7, "drop": 7},
        "dangerEvery": 16,
        "barSpecials": 1,
        "phraseHoldBeats": 4,
        "breakSeconds": 2.45,
        "breakClaps": 3,
        "rushTiles": (3, 4),
        "rushEvery": {"chorus": 16, "drop": 16},
        "clapEvery": {"calm": 32, "build": 32, "chorus": 32, "drop": 32},
        "itemGap": 1.0,
        "restBeats": 1.5,
        "restBars": {"calm": 2, "build": 2, "chorus": 4, "drop": 4},
    },
    "hard": {
        "density": {"calm": 0.8, "build": 1.0, "chorus": 1.25, "drop": 1.4},
        "eighths": (),
        "run": 1,
        "maxBeatTravel": 2,
        "maxHop": 1,
        "phraseRest": True,
        "stepSeconds": 0.1,
        "margin": 0.1,
        "jump": 0,
        "jumpPairs": False,
        "walls": 2,
        "holdSpacing": 4,
        "slides": 12,
        "returns": 1,
        "shapeEvery": {"calm": 6, "build": 6, "chorus": 6, "drop": 6},
        "dangerEvery": 16,
        "barSpecials": 2,
        "phraseHoldBeats": 3,
        "breakClaps": 1,
        "rushTiles": (3, 4, 5),
        "rushEvery": {"build": 12, "chorus": 12, "drop": 12},
        "clapEvery": {"calm": 16, "build": 16, "chorus": 16, "drop": 16},
        "itemGap": 1.0,
        "restBeats": 1.5,
        "restBars": {"calm": 8, "build": 8, "chorus": 8, "drop": 8},
    },
    "expert": {
        "density": {"calm": 1.0, "build": 1.25, "chorus": 1.6, "drop": 1.8},
        "eighths": (),
        "run": 1,
        "maxBeatTravel": 2,
        "maxHop": 1,
        "phraseRest": True,
        "stepSeconds": 0.09,
        "margin": 0.1,
        "jump": 0,
        "jumpPairs": False,
        "walls": 3,
        "holdSpacing": 3,
        "slides": 10,
        "returns": 1,
        "shapeEvery": {"calm": 6, "build": 6, "chorus": 6, "drop": 6},
        "dangerEvery": 16,
        "barSpecials": 2,
        "phraseHoldBeats": 3,
        "breakClaps": 1,
        "rushTiles": (3, 4, 5),
        "rushEvery": {"build": 8, "chorus": 8, "drop": 8},
        "clapEvery": {"calm": 16, "build": 16, "chorus": 16, "drop": 16},
        "itemGap": 1.0,
        "restBeats": 1.0,
    },
}

# Busier profiles a song can opt into (chart-audio.py --intensity), laid over
# PROFILES. rushFollow puts rushes where the drums fill every eighth and in the
# bars that build into a lift instead of at fixed spots in the phrase; rushGap
# is the fewest beats between two rushes, and rushPhraseEnd lets one run into
# the last bar of a phrase, taking the place of its hold. sustainHolds is the
# fewest beats between two holds on notes that ring two beats or more, and
# wallEvery splits a section so it can take a danger wall per that many beats.
# diagonals lets a note sit a corner away: one hop, two keys pressed together.
# shapeHop is how far a shape's farthest tile may be from the notes either side;
# the player only has to reach the nearest one, so it can pass maxHop.
# diagonalWeight scales how often the diagonal patterns are picked. pulse
# replaces the difficulty's PULSE cells, and syncopate False keeps every step on
# its beat instead of nudging it onto a louder off-beat.
INTENSITY = {
    "high": {
        "normal": {
            "rushFollow": True,
            "rushEvery": {"chorus": 8, "drop": 8},
            "shapeEvery": {"calm": 10, "build": 6, "chorus": 6, "drop": 6},
            "dangerEvery": 12,
            "walls": 3,
        },
        "hard": {
            "rushFollow": True,
            "rushEvery": {"build": 8, "chorus": 8, "drop": 6},
            "rushGap": 5.0,
            "sustainHolds": 8,
            "shapeEvery": {"calm": 5, "build": 4, "chorus": 4, "drop": 4},
            "dangerEvery": 8,
            "walls": 5,
            "holdSpacing": 3,
            "clapEvery": {"calm": 8, "build": 8, "chorus": 8, "drop": 8},
        },
        "expert": {
            "rushFollow": True,
            "rushTiles": (4, 5),
            "rushEvery": {"calm": 8, "build": 6, "chorus": 5, "drop": 5},
            "rushGap": 3.5,
            "rushPhraseEnd": True,
            "sustainHolds": 6,
            "shapeEvery": {"calm": 4, "build": 4, "chorus": 3, "drop": 3},
            "dangerEvery": 6,
            "walls": 5,
            "wallEvery": 32,
            "holdSpacing": 2,
            "clapEvery": {"calm": 8, "build": 8, "chorus": 8, "drop": 8},
        },
    },
    # Fewer kinds of tile and more shape to the path: diagonals, few dangers.
    "flow": {
        "easy": {
            "shapeHop": 2,
            "shapeEvery": {"calm": 12, "build": 8, "chorus": 6, "drop": 6},
            "pulse": {"calm": (0, 4), "build": (0, 2, 4, 6), "chorus": (0, 2, 4, 6), "drop": (0, 2, 4, 6)},
            "syncopate": False,
        },
        "normal": {
            "shapeHop": 2,
            "walls": 0,
            "dangerEvery": 32,
            "rushTiles": (),
            "rushEvery": {},
            "clapEvery": {},
            "breakClaps": 0,
            "shapeEvery": {"calm": 8, "build": 6, "chorus": 5, "drop": 5},
            "pulse": {
                "calm": (0, 2, 4, 6),
                "build": (0, 2, 4, 6),
                "chorus": (0, 1, 2, 4, 5, 6),
                "drop": (0, 1, 2, 4, 5, 6),
            },
            "syncopate": False,
        },
        "hard": {
            "diagonals": True,
            "shapeHop": 2,
            "diagonalWeight": 1.5,
            "walls": 1,
            "dangerEvery": 24,
            "rushEvery": {"chorus": 32, "drop": 32},
            "clapEvery": {"chorus": 32, "drop": 32},
            "shapeEvery": {"calm": 6, "build": 5, "chorus": 4, "drop": 4},
        },
        "expert": {
            "diagonals": True,
            "shapeHop": 2,
            "diagonalWeight": 1.5,
            "walls": 2,
            "dangerEvery": 16,
            "rushEvery": {"chorus": 12, "drop": 8},
            "rushFollow": True,
            "eighths": ("chorus", "drop"),
            "minEighthSeconds": 0.22,
            "clapEvery": {"chorus": 32, "drop": 32},
            "shapeEvery": {"calm": 5, "build": 4, "chorus": 4, "drop": 3},
        },
    },
}


def _load_timing(path=TIMING_PATH):
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return

    for name, profile in PROFILES.items():
        block = re.search(r"\n\t%s = \{(.*?)\n\t\}," % name, text, re.S)

        if block is None:
            continue

        for key, cast in (("stepSeconds", float), ("maxBeatTravel", int)):
            value = re.search(r"\b%s = ([\d.]+)" % key, block.group(1))

            if value is not None:
                profile[key] = cast(float(value.group(1)))


_load_timing()

for _name, _profile in PROFILES.items():
    _profile["name"] = _name


def intensify(level):
    """Lay INTENSITY[level] over every difficulty's profile, for the rest of the run."""
    for name, changes in INTENSITY[level].items():
        PROFILES[name].update(changes)

# The server only follows a slide's path once its telegraph opens, this long
# before the slide's beat, so the path has to start on a tile the dancer is
# still standing on by then. Read from RhythmService like the profiles above.
SLIDE_TRACK_BEATS = 2.0
SLIDE_TRACK_SECONDS = 0.9


def _load_slide_tracking(path=RHYTHM_PATH):
    global SLIDE_TRACK_BEATS, SLIDE_TRACK_SECONDS

    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return

    found = re.search(r"leadSeconds = math\.max\(([\d.]+) \* beatSeconds, ([\d.]+)\)", text)

    if found is not None:
        SLIDE_TRACK_BEATS, SLIDE_TRACK_SECONDS = float(found.group(1)), float(found.group(2))


_load_slide_tracking()

LEAD_IN_BEATS = 2.0
REST_GAP_BEATS = 2.0
EIGHTH_CHAIN_BEATS = 0.75
HOLD_MIN_BEATS = {"calm": 0.75, "build": 1.0, "chorus": 1.0, "drop": 1.5}
HOLD_MIN_GAP_BEATS = 1.5
HOLD_RELEASE_BEATS = 0.75
HOLD_MIN_SECONDS = 0.3
HOLD_MAX_SECONDS = 1.5
BONUS_SPACING = 10
SLIDE_MAX_MOVES = 4
SLIDE_KIND_WEIGHTS = {"straight": 1.0, "L": 3.0, "U": 2.5, "zigzag": 3.0}
SLIDE_KEEP_TILE = 0.5
SLIDE_CORNER_SPACING = 3
RETURN_BEATS = 1.0
RETURN_SPAN_BEATS = 4.0
RETURN_PENALTY = 1.5
SHAPE_MAX_TILES = 4
SHAPE_MIN_GAP_BEATS = 1.0
SHAPE_CLEAR_BEATS = 2.0
ITEM_WINDOW_BEATS = 16
WALL_LINES = 5
WALL_MIN_TILES = 3
MAX_STREAK = 4
PHRASE_BEATS = 16.0
BAR_BEATS = 4.0
STAYS = ("pose", "clap")
MOVES = STAYS + ("rush",)
RUSH_STRIDE = 0.5
DANGER_ENERGIES = ("build", "chorus", "drop")
DANGER_CLEAR_BEATS = 2.0
DANGER_ITEM_BEATS = 4.0
RUSH_CLEAR_BEATS = 1.0
RUSH_AFTER_BEATS = 1.0
RUSH_STRAIGHT_BONUS = 1.0
RUSH_ROOM_PENALTY = 10.0
RUSH_GAP_BEATS = 8.0
FILL_OFFBEAT = 1.5
SUSTAIN_HOLD_BEATS = 2
# A phrase's hold goes on its longest ringing note and lets go in time to step
# onto the tune's next note on its beat: half a beat before, on the "and", or a
# whole beat where stepping off takes longer, so no downbeat is lost to a hold.
RING_HOLD_BEATS = 2
RING_RELEASE_BEATS = 0.5
BREAK_MAX_SECONDS = 5.0
BREAK_SPACING_BEATS = 12.0
# Bar offsets in a phrase a rush may start on, best first: the third bar leaves
# the first bar's clap and the last bar's hold in place.
RUSH_OFFSETS = (8, 0, 4)
# Gold items need a phrase-end rest to detour in, and they only come in choruses
# and drops, so there a phrase ends in a rest unless the section is winding down.
ITEM_REST_ENERGIES = ("chorus", "drop")
POSE_BEATS = (1, 4)
RUSH_SIZES = (3, 5)
CLAP_SNAP = 0.5
FAST_REVERSAL_SECONDS = 0.35

F, B, L, R = (0, -1), (0, 1), (-1, 0), (1, 0)

PATTERNS = {
    "pivot": [R, L, F, B],
    "jacks": [R, L, R, L],
    "box": [R, F, L, B],
    "lturn": [F, F, R, R],
    "stairs": [F, R, F, R],
    "zigzag": [R, F, L, F, R, F],
    "wave": [F, R, B, R],
    "arc": [F, R, R, B],
    "hook": [F, (1, -1), R],
    "bend": [(1, -1), F, F],
    "run": [F, F, F],
    "cross": [F, F, F, F],
    "bigbox": [R, R, F, F, L, L, B, B],
    "jump": [(0, -2)],
    "jumpback": [(0, -2), (0, 2)],
    "diag": [(1, -1), (-1, -1)],
    "widejacks": [(2, 0), (-2, 0), (2, 0)],
    "hopscotch": [(0, -2), R, (0, 2), R],
    "snake": [R, R, F, L, L, F],
    "uturn": [F, F, R, B, B],
    "spiral": [R, F, L, L, B, B],
    "longl": [R, R, R, F, F],
    "weave": [F, R, F, L],
    "notch": [R, F, R],
    "kick": [F, F, R, B],
    "sbend": [F, R, R, F],
    "cane": [F, F, F, R, B],
    "crenel": [F, R, R, B, R],
    "ledge": [R, R, F, R, R],
    "comb": [F, R, B, R, F],
    "peak": [F, R, F, R, B, R, B],
    "figure8": [R, F, L, F, R, B, L, B],
}
# Corner-to-corner moves, only where the profile allows diagonals.
DIAGONAL_PATTERNS = {
    "diamond": [(1, -1), (1, 1), (-1, 1), (-1, -1)],
    "diagzig": [(1, -1), (1, 1), (1, -1), (1, 1)],
    "diagstairs": [(1, -1), (1, -1), (1, -1)],
    "triangle": [(1, -1), (1, 1), L, L],
    "vee": [(1, 1), (1, -1), F],
    "slalom": [(1, -1), F, (-1, -1), F],
    "crown": [(1, -1), R, (1, 1), R],
    "bowtie": [(1, -1), B, (-1, -1), B],
    "lightning": [(1, -1), R, (1, -1)],
    "hourglass": [R, (-1, -1), R, (-1, 1)],
    "chevron": [(1, -1), (1, -1), (1, 1), (1, 1)],
}
PATTERNS.update(DIAGONAL_PATTERNS)
DIAGONAL_WEIGHTS = {
    "calm": {"diagstairs": 1, "vee": 1, "slalom": 1, "lightning": 1},
    "build": {
        "diagstairs": 2, "diamond": 1.5, "triangle": 1.5, "vee": 1.5, "slalom": 1.5, "crown": 1, "lightning": 1.5,
        "hourglass": 1,
    },
    "chorus": {
        "diamond": 3, "diagzig": 2.5, "triangle": 2, "diagstairs": 1.5, "vee": 1.5, "slalom": 2, "crown": 2,
        "bowtie": 2, "hourglass": 1.5, "chevron": 2,
    },
    "drop": {
        "diamond": 2.5, "diagzig": 3, "triangle": 2, "diagstairs": 2, "vee": 1.5, "slalom": 2, "crown": 2.5,
        "bowtie": 2, "lightning": 1.5, "chevron": 2.5,
    },
}
JUMPY = {"jump", "jumpback", "diag", "widejacks", "hopscotch"}
JUMP_PAIRS = {"jumpback", "diag", "widejacks"}
RETURNING = {"pivot", "jacks", "jumpback", "widejacks"}
# A corner cut in one move, which the slide pass walks as an L of cyan tiles.
CORNERS = {"hook", "bend"}

WEIGHTS = {
    "calm": {
        "pivot": 3, "jacks": 2, "box": 2, "lturn": 2, "run": 1, "wave": 1, "stairs": 1, "arc": 1.5, "uturn": 1.5,
        "snake": 1, "weave": 1.5, "notch": 1.5, "kick": 1, "sbend": 1,
    },
    "build": {
        "stairs": 3, "zigzag": 2, "lturn": 2, "run": 2, "wave": 2, "box": 1, "jacks": 1, "jump": 0.5, "arc": 1.5,
        "hook": 2, "bend": 1, "snake": 2, "uturn": 1.5, "spiral": 1.5, "longl": 1.5, "weave": 1.5, "notch": 1.5,
        "kick": 1.5, "sbend": 1.5, "crenel": 1.5, "ledge": 1.5, "cane": 1,
    },
    "chorus": {
        "zigzag": 3, "jacks": 2, "bigbox": 2, "run": 2, "stairs": 2, "box": 2, "wave": 2,
        "jump": 1.5, "diag": 1.5, "jumpback": 1, "cross": 1, "widejacks": 1, "hopscotch": 1, "hook": 2.5, "bend": 1.5,
        "snake": 2, "spiral": 2, "uturn": 1.5, "crenel": 2, "comb": 2, "peak": 2, "figure8": 1.5, "ledge": 1.5,
        "sbend": 1.5, "weave": 1.5,
    },
    "drop": {
        "jacks": 2, "zigzag": 2, "run": 2, "jump": 2, "diag": 2, "bigbox": 2, "cross": 1.5,
        "jumpback": 1.5, "wave": 1, "widejacks": 1.5, "hopscotch": 1.5, "hook": 2, "bend": 1.5,
        "snake": 2, "spiral": 2, "longl": 1.5, "figure8": 2, "peak": 2, "comb": 2, "crenel": 2, "ledge": 1.5,
        "kick": 1.5, "notch": 1,
    },
}

# The eight ways to turn a pattern on the board.
ORIENTATIONS = [
    lambda dx, dy: (dx, dy),
    lambda dx, dy: (-dx, dy),
    lambda dx, dy: (dx, -dy),
    lambda dx, dy: (-dx, -dy),
    lambda dx, dy: (dy, dx),
    lambda dx, dy: (-dy, dx),
    lambda dx, dy: (dy, -dx),
    lambda dx, dy: (-dy, -dx),
]

# Shapes: 2-4 tile zones a note may be landed on anywhere, as offsets.
SHAPES = {
    "pair": [(0, 0), (1, 0)],
    "line": [(0, 0), (1, 0), (2, 0)],
    "corner": [(0, 0), (1, 0), (0, 1)],
    "square": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "tee": [(0, 0), (1, 0), (2, 0), (1, 1)],
    # Only where diagonals are hops: tiles touching at their corners.
    "slash": [(0, 0), (1, 1), (2, 2)],
    "diamond": [(1, 0), (0, 1), (2, 1), (1, 2)],
    "vee": [(0, 0), (1, 1), (2, 0)],
    "zag": [(0, 0), (1, 1), (2, 0), (3, 1)],
    "ell": [(0, 0), (0, 1), (0, 2), (1, 2)],
    "zee": [(0, 0), (1, 0), (1, 1), (2, 1)],
}
CORNER_SHAPES = {"slash", "diamond", "vee", "zag"}
# Where every note is one hop, the only pick that leaves the next note one hop
# from each of its tiles is the two corners an L-turn could cut across.
SPLIT = "split"
SHAPES[SPLIT] = [(0, 0), (1, 1)]
CORNER_SHAPES.add(SPLIT)
# Bigger shapes are the ones worth reading, so a note that can take one is favoured.
SHAPE_SIZE_APPEAL = 1.5
SHAPE_WEIGHTS = {
    "easy": {
        "pair": 1, "line": 2, "corner": 2, "square": 3, "tee": 2, SPLIT: 1, "slash": 1, "diamond": 3, "vee": 2,
        "zag": 1, "ell": 2, "zee": 2,
    },
    "normal": {
        "pair": 1, "line": 2, "corner": 3, "square": 2, "tee": 2, SPLIT: 1, "slash": 2, "diamond": 3, "vee": 2,
        "zag": 2, "ell": 2, "zee": 2,
    },
    "hard": {
        "pair": 2, "line": 2, "corner": 3, "square": 1, "tee": 2, SPLIT: 1, "slash": 2, "diamond": 2, "vee": 2,
        "zag": 2, "ell": 2, "zee": 2,
    },
    "expert": {
        "pair": 3, "line": 2, "corner": 2, "square": 1, "tee": 1, SPLIT: 1, "slash": 2, "diamond": 2, "vee": 2,
        "zag": 2, "ell": 2, "zee": 2,
    },
}
# A pattern used in the last few picks is picked this much less, so the dance keeps changing.
RECENT_PATTERNS = 3
RECENT_PATTERN_WEIGHT = 0.3
# A walk this many notes long or more is tagged as a pattern, so the pad can draw its whole path.
PATTERN_MIN_NOTES = 3


class Onset:
    __slots__ = ("beat", "strength", "pitch", "sustain", "accent", "on_beat", "downbeat", "snap")

    def __init__(self, beat, strength, pitch=None, sustain=0.0, accent=False, on_beat=True, downbeat=False, snap=0.0):
        self.snap = snap
        self.beat = beat
        self.strength = strength
        self.pitch = pitch
        self.sustain = sustain
        self.accent = accent
        self.on_beat = on_beat
        self.downbeat = downbeat


def energy_at(sections, beat):
    energy = sections[0][1]

    for start, value in sections:
        if start > beat + EPS:
            break

        energy = value

    return energy


def _section_bounds(sections, end_beat):
    for index, (start, energy) in enumerate(sections):
        stop = sections[index + 1][0] if index + 1 < len(sections) else end_beat
        yield start, stop, energy


def _eighths_allowed(profile, energy, bpm):
    return energy in profile["eighths"] and 30.0 / bpm >= profile.get("minEighthSeconds", 1.0)


def _chain_length(beats, index):
    first = index

    while first > 0 and beats[first] - beats[first - 1] < EIGHTH_CHAIN_BEATS:
        first -= 1

    last = index

    while last + 1 < len(beats) and beats[last + 1] - beats[last] < EIGHTH_CHAIN_BEATS:
        last += 1

    return last - first + 1


def _fits(beats, beat, min_gap, run):
    index = bisect.bisect_left(beats, beat)

    if index > 0 and beat - beats[index - 1] < min_gap - EPS:
        return False

    if index < len(beats) and beats[index] - beat < min_gap - EPS:
        return False

    trial = beats[:index] + [beat] + beats[index:]

    return _chain_length(trial, index) <= max(run, 1)


def _weight(onset):
    weight = onset.strength * (1.0 if onset.on_beat else 0.75)

    return weight * 1.3 if onset.downbeat else weight


def _pulse(onsets, sections, end_beat, profile, bpm, by_beat, cells):
    """The beats a steady pulse puts a step on, where the music hits, nudged onto its syncopation."""
    beats = []
    on_beats = sorted(onset.beat for onset in onsets if onset.on_beat and onset.strength > 0)
    first_beat = on_beats[0] if on_beats else (onsets[0].beat if onsets else 1.0)
    one_tile = (profile["stepSeconds"] + profile["margin"]) * bpm / 60.0
    timed_gap = math.ceil(one_tile * 2 - EPS) / 2.0

    def strength(beat):
        onset = by_beat.get(round(beat, 4))

        return onset.strength if onset else 0.0

    for start, stop, energy in _section_bounds(sections, end_beat):
        eighths = _eighths_allowed(profile, energy, bpm)
        min_gap = max(0.5 if eighths else 1.0, timed_gap)
        origin = first_beat + math.ceil((start - first_beat) - EPS)
        loudest = max((onset.strength for onset in onsets if start - EPS <= onset.beat < stop - EPS), default=0.0)
        floor_strength = max(loudest * PULSE_MIN_SHARE, EPS)
        cell = 0

        while origin < stop - EPS:
            for offset in cells[energy]:
                beat = round(origin + offset, 4)
                off_beat = abs(offset - round(offset)) > EPS

                if beat >= stop - EPS or beat < first_beat + LEAD_IN_BEATS - EPS:
                    continue

                if profile.get("phraseRest") and cell % 2 == 1 and offset >= PHRASE_REST_FROM - EPS:
                    continue

                if off_beat and not (eighths and strength(beat) > 0):
                    continue

                run = profile["run"] if eighths else 1

                if not off_beat and profile.get("syncopate", True):
                    pushed = max((beat + 0.5, beat - 0.5), key=strength)
                    louder = strength(pushed) >= max(strength(beat) * SYNC_RATIO, floor_strength)
                    inside = max(start, first_beat + LEAD_IN_BEATS) - EPS <= pushed < stop - EPS

                    if louder and inside and _fits(beats, pushed, min_gap, run):
                        bisect.insort(beats, round(pushed, 4))
                        continue

                if strength(beat) < floor_strength or not _fits(beats, beat, min_gap, run):
                    continue

                bisect.insort(beats, beat)

            origin += PULSE_CELL_BEATS
            cell += 1

    return beats, first_beat, timed_gap


def pick(onsets, sections, end_beat, profile, bpm):
    """Stage one: which onsets carry a step."""
    by_beat = {round(onset.beat, 4): onset for onset in onsets}
    beats = []
    first_beat = onsets[0].beat if onsets else 1.0
    one_tile = (profile["stepSeconds"] + profile["margin"]) * bpm / 60.0
    timed_gap = math.ceil(one_tile * 2 - EPS) / 2.0
    cells = profile.get("pulse") or PULSE.get(profile.get("name", ""))

    if cells is not None:
        beats, first_beat, timed_gap = _pulse(onsets, sections, end_beat, profile, bpm, by_beat, cells)

    for start, stop, energy in _section_bounds(sections, end_beat) if cells is None else ():
        eighths = _eighths_allowed(profile, energy, bpm)
        min_gap = max(0.5 if eighths else 1.0, timed_gap)
        pool = [
            onset
            for onset in onsets
            if start - EPS <= onset.beat < stop - EPS
            and onset.beat >= first_beat + LEAD_IN_BEATS - EPS
            and onset.strength > 0
            and (onset.on_beat or eighths)
        ]
        pool.sort(key=lambda onset: -_weight(onset))
        target = int(round((stop - start) * profile["density"][energy]))
        offbeats = int(round(target * profile.get("offbeatShare", 0.0))) if eighths else 0
        run = profile["run"] if eighths else 1
        added = 0

        # Off-beats first, up to their share, so a strong backbeat cannot crowd
        # out every syncopation and leave a chorus of plain quarter notes.
        for onset in [onset for onset in pool if not onset.on_beat] + pool:
            if added >= target or (offbeats <= 0 and not onset.on_beat):
                if added >= target:
                    break

                continue

            if onset.beat in beats or not _fits(beats, onset.beat, min_gap, run):
                continue

            bisect.insort(beats, onset.beat)
            added += 1

            if not onset.on_beat:
                offbeats -= 1

    previous = None

    for start, _stop, energy in _section_bounds(sections, end_beat):
        lifts = previous is not None and RANK[energy] >= RANK["chorus"] and RANK[energy] > RANK[previous]
        previous = energy

        if not lifts:
            continue

        beats = [beat for beat in beats if not (start - profile["restBeats"] - EPS <= beat < start - EPS)]
        landing = [
            onset for onset in onsets
            if onset.on_beat and start - EPS <= onset.beat < start + 1 - EPS and onset.strength > 0
        ]

        if landing and not any(abs(beat - landing[0].beat) < EPS for beat in beats):
            if _fits(beats, landing[0].beat, max(1.0, timed_gap), 1):
                bisect.insort(beats, landing[0].beat)

    beats = _breathe(beats, onsets, sections, profile)

    return [by_beat[round(beat, 4)] for beat in beats]


def _breathe(beats, onsets, sections, profile):
    """Clear the end of a phrase wherever the steps have run too long without a rest."""
    rest_bars = profile.get("restBars")

    if not rest_bars or not beats:
        return beats

    bar_starts = sorted(onset.beat for onset in onsets if onset.downbeat)

    if len(bar_starts) < 2:
        return beats

    bar_beats = bar_starts[1] - bar_starts[0]
    rested = beats[0]

    for bar in bar_starts:
        if bar <= rested + EPS:
            continue

        for index in range(1, len(beats)):
            if beats[index] > bar + EPS:
                break

            if beats[index] - beats[index - 1] >= REST_GAP_BEATS - EPS:
                rested = max(rested, beats[index])

        limit = rest_bars[energy_at(sections, bar - EPS)] * bar_beats

        if bar - rested < limit - EPS:
            continue

        beats = [beat for beat in beats if not (bar - REST_GAP_BEATS + EPS < beat < bar - EPS)]
        rested = bar

    return beats


def _kind(move):
    return move["kind"] if move else None


def rush_fits(profile, bpm):
    """Whether half a beat leaves time for one hop and the margin to read the next tile."""
    return RUSH_STRIDE * 60.0 / float(bpm) >= profile["stepSeconds"] + profile["margin"] - EPS


def _drives(onset, hits=None):
    """Whether a rush tile can land here: on a note of the tune or a snare, not a lone hat.

    hits, when given, is the only beats that count as a hit at all.
    """
    if hits is not None and (onset is None or round(onset.beat, 4) not in hits):
        return False

    return onset is not None and onset.strength > 0 and (onset.sustain > 0 or onset.snap > 0)


def _phrases(onsets, sections, end_beat):
    """(start, stop, energy) per four bars, counted from each section's first pulse cell."""
    on_beats = [onset.beat for onset in onsets if onset.on_beat and onset.strength > 0]
    first = min(on_beats) if on_beats else (onsets[0].beat if onsets else 1.0)

    for start, stop, energy in _section_bounds(sections, end_beat):
        origin = first + math.ceil((start - first) - EPS)

        while origin < stop - EPS:
            yield origin, min(origin + PHRASE_BEATS, stop), energy
            origin += PHRASE_BEATS


def _lifts(sections):
    """Where a section lifts the energy into a chorus or a drop."""
    return [
        start for (start, energy), (_, previous) in zip(sections[1:], sections)
        if RANK[energy] >= RANK["chorus"] and RANK[energy] > RANK[previous]
    ]


def _fills(phrases, sections, end_beat, by_beat, profile, building_only=False, hits=None):
    """(drive, first, size, spacing) for every rush the drums could carry, best first.

    Drive is how hard the eighths under the rush hit, off-beats and snares
    counting extra since a plain step cannot follow them. A rush that ends in the
    bar before a lift is a build into it and goes first. Rushes keep clear of
    the middle of each stretch that gets a danger wall, so the wall has room.
    """
    lifts = _lifts(sections)
    slots = _wall_slots(sections, end_beat, profile)
    longest = max(profile["rushTiles"])
    tail = profile.get("rushPhraseEnd")
    found = []

    for start, stop, energy in phrases:
        spacing = profile["rushEvery"].get(energy)
        lift = any(abs(stop - beat) < EPS for beat in lifts)
        beat = start

        while (spacing or lift) and beat < stop - EPS:
            for size in profile["rushTiles"]:
                end = beat + (size - 1) * RUSH_STRIDE + RUSH_AFTER_BEATS
                building = lift and end > stop - BAR_BEATS + EPS
                tiles = [by_beat.get(round(beat + step * RUSH_STRIDE, 4)) for step in range(size)]

                if end > stop + EPS or (end > stop - BAR_BEATS + EPS and not (lift or tail)) or None in tiles:
                    continue

                if not all(_drives(tile, hits) for tile in tiles):
                    continue

                if not (spacing or building) or (building_only and not building):
                    continue

                if any(beat < high + 1 + EPS and end > low - 2 - EPS for low, high in slots):
                    continue

                drive = sum(
                    tile.strength * (1.0 if tile.on_beat else FILL_OFFBEAT) * (1.0 + tile.snap) for tile in tiles
                )
                found.append((building, drive / longest, round(beat, 4), size, spacing or PHRASE_BEATS))

            beat += 1.0

    return [fill[1:] for fill in sorted(found, key=lambda fill: (not fill[0], -fill[1], fill[2]))]


def place_moves(notes, onsets, sections, end_beat, profile, bpm, rng, hits=None):
    """Stage one and a half: swap pulse slots for rushes, holds and claps.

    Returns the notes and, per note, its move ({"kind": ...}) or None.
    """
    chosen = {round(note.beat, 4): note for note in notes}
    by_beat = {round(onset.beat, 4): onset for onset in onsets}
    moves = {}
    phrases = list(_phrases(onsets, sections, end_beat))

    def inside(low, high):
        return sorted(beat for beat in chosen if low + EPS < beat < high - EPS)

    def before(beat):
        return max((other for other in chosen if other < beat - EPS), default=None)

    def after(beat):
        return min((other for other in chosen if other > beat + EPS), default=None)

    # Long notes are held before rushes are laid, so the drums cannot crowd out the
    # vocal; the bar before a lift stays free for the rush that builds into it.
    spacing = profile.get("sustainHolds")
    lifts = _lifts(sections)
    last_hold = None
    sustained = []

    for beat in sorted(chosen) if spacing else ():
        if beat not in chosen or chosen[beat].sustain < SUSTAIN_HOLD_BEATS:
            continue

        if last_hold is not None and beat - last_hold < spacing - EPS:
            continue

        if any(lift - BAR_BEATS - SUSTAIN_HOLD_BEATS - 1 - EPS <= beat < lift for lift in lifts):
            continue

        previous = before(beat)
        held = inside(beat, beat + SUSTAIN_HOLD_BEATS + 1)

        if previous is None or previous in moves:
            continue

        for other in held:
            del chosen[other]

        moves[beat] = {"kind": "hold", "holdBeats": SUSTAIN_HOLD_BEATS}
        sustained.append(beat)
        last_hold = beat

    starts = []
    spans = []
    rush_gap = profile.get("rushGap", RUSH_GAP_BEATS)
    rushes = profile["rushTiles"] and rush_fits(profile, bpm)
    follow = profile.get("rushFollow")

    def lay(first, size):
        last = first + (size - 1) * RUSH_STRIDE

        if any(first - high < rush_gap - EPS and low - last < rush_gap - EPS for low, high in spans):
            return False

        tiles = [by_beat.get(round(first + step * RUSH_STRIDE, 4)) for step in range(size)]

        if not all(_drives(tile, hits) for tile in tiles):
            return False

        anchor = before(first - RUSH_CLEAR_BEATS + 2 * EPS)
        cleared = inside(first - RUSH_CLEAR_BEATS, first)
        cleared += [beat for beat in chosen if first - EPS <= beat < last + RUSH_AFTER_BEATS - EPS]

        if anchor is None or anchor in moves or any(beat in moves for beat in cleared):
            return False

        # The dancer starts on the centre tile, which a five-tile rush cannot leave from.
        if follow and sum(1 for beat in chosen if beat < anchor - EPS) < 2:
            return False

        for beat in cleared:
            del chosen[beat]

        starts.append(first)
        spans.append((first, last))

        for step in range(size):
            beat = round(first + step * RUSH_STRIDE, 4)
            chosen[beat] = by_beat.get(beat) or Onset(beat, 0.5, chosen[anchor].pitch)
            moves[beat] = {"kind": "rush", "rush": len(starts)}

        return True

    for start, stop, energy in phrases if rushes and not follow else ():
        spacing = profile["rushEvery"].get(energy)

        if not spacing:
            continue

        for offset in RUSH_OFFSETS:
            first = round(start + offset, 4)

            if first not in chosen or any(abs(first - other) < spacing - EPS for other in starts):
                continue

            # The longest run the tune carries: every tile on a note or a snare.
            for size in sorted(profile["rushTiles"], reverse=True):
                last = first + (size - 1) * RUSH_STRIDE

                if last + RUSH_AFTER_BEATS <= stop - BAR_BEATS + EPS and lay(first, size):
                    break

    # A snare roll into a chorus or a drop is run on every difficulty with rushes.
    fills = _fills(phrases, sections, end_beat, by_beat, profile, building_only=not follow, hits=hits) if rushes else ()

    for _drive, first, size, spacing in fills:
        if not follow or not any(abs(first - other) < spacing - EPS for other in starts):
            lay(first, size)

    hold_beats = _break_beats(profile, bpm)
    release_beats = _release_beats(profile, 60.0 / float(bpm))
    specials = list(starts) + sustained
    breaks = []

    def breakable(beat, hold_beats):
        previous = before(beat)
        held = inside(beat, beat + hold_beats + 1)

        if beat in moves or previous is None or previous in moves or any(other in moves for other in held):
            return False

        if breaks and beat - breaks[-1] < BREAK_SPACING_BEATS - EPS:
            return False

        return not _crowded(specials, beat, profile)

    def ringing(start, stop):
        """(beats, beat) for each long note in the phrase, longest and latest first."""
        found = []

        for onset in onsets:
            if not (start - EPS <= onset.beat < stop - EPS and onset.on_beat and onset.strength > 0):
                continue

            beats = min(int(onset.sustain + EPS), hold_beats, int(stop - onset.beat + EPS))

            if beats >= RING_HOLD_BEATS:
                found.append((beats, round(onset.beat, 4)))

        return sorted(found, reverse=True)

    for start, stop, _energy in phrases:
        spot = next(
            (
                (beats, beat)
                for beats, beat in ringing(start, stop)
                if before(beat) is not None and (beat in chosen or beat - before(beat) >= 1 - EPS)
                and breakable(beat, beats)
            ),
            None,
        )

        if spot is None:
            continue

        beats, beat = spot
        held = beats - release_beats
        chosen[beat] = chosen.get(beat) or by_beat[beat]

        for other in inside(beat, beat + beats):
            del chosen[other]

        release = round(beat + beats, 4)

        following = after(release)
        spaced = following is None or following - release >= 1 - EPS

        if release not in chosen and release in by_beat and by_beat[release].strength > 0 and spaced:
            chosen[release] = by_beat[release]

        moves[beat] = {"kind": "hold", "holdBeats": held}
        specials.append(beat)
        breaks.append(beat)

        for clap in _break_claps(beat, beats, by_beat, profile):
            chosen[clap] = by_beat.get(clap) or Onset(clap, 0.5, chosen[beat].pitch)
            moves[clap] = {"kind": "clap"}

    # Choruses and drops keep their rests for gold items, so claps there come only inside holds.
    def still(beat, energy):
        previous, following = before(beat), after(beat)

        if previous is None or following is None:
            return False

        if _kind(moves.get(previous)) != "hold" and (energy in ITEM_REST_ENERGIES or _crowded(specials, beat, profile)):
            return False

        return _still_moment(beat, previous, moves.get(previous), following, moves.get(following))

    last_clap = None

    for start, stop, energy in phrases:
        span = profile["clapEvery"].get(energy)
        window = start

        while span and window < stop - EPS:
            options = []
            beat = window

            while beat < min(window + span, stop) - EPS:
                beat = round(beat, 4)

                spaced = last_clap is None or beat - last_clap >= span - EPS
                broken = any(low < beat < low + moves[low]["holdBeats"] + EPS for low in breaks)

                snap = by_beat[beat].snap if beat in by_beat else 0.0

                if snap > 0 and spaced and not broken and beat not in chosen and still(beat, energy):
                    spot = (beat - start) % BAR_BEATS
                    backbeat = min(abs(spot - 1), abs(spot - 3)) < EPS
                    options.append((snap >= CLAP_SNAP, backbeat, snap, -beat))

                beat += 1.0

            if options:
                beat = -max(options)[3]

                if _kind(moves.get(before(beat))) != "hold":
                    specials.append(beat)

                chosen[beat] = by_beat.get(beat) or Onset(beat, 0.5, chosen[before(beat)].pitch)
                moves[beat] = {"kind": "clap"}
                last_clap = beat

            window += span

    order = sorted(chosen)

    return [chosen[beat] for beat in order], [moves.get(beat) for beat in order]


def _release_beats(profile, beat_seconds):
    """Beats from letting go of a hold to the next note: whole half beats, enough to step one tile."""
    step_off = (profile["stepSeconds"] + profile["margin"]) / beat_seconds

    return max(RING_RELEASE_BEATS, math.ceil(step_off / RING_RELEASE_BEATS - EPS) * RING_RELEASE_BEATS)


def _break_beats(profile, bpm):
    """Whole beats a phrase-end break lasts: phraseHoldBeats, stretched to breakSeconds, capped at BREAK_MAX_SECONDS."""
    beat_seconds = 60.0 / float(bpm)
    beats = max(profile["phraseHoldBeats"], math.ceil(profile.get("breakSeconds", 0.0) / beat_seconds - EPS))

    return max(1, min(beats, int(BREAK_MAX_SECONDS / beat_seconds + EPS)))


def _break_claps(beat, hold_beats, by_beat, profile):
    """The beats inside a break to clap on: snare hits two beats apart, or the strongest snap if none is accented."""
    inner = [round(beat + step, 4) for step in range(1, hold_beats)]
    ranked = sorted(inner, key=lambda spot: (-(by_beat[spot].snap if spot in by_beat else 0.0), spot))
    snares = [spot for spot in ranked if spot in by_beat and by_beat[spot].snap >= CLAP_SNAP] or [
        spot for spot in ranked[:1] if spot in by_beat and by_beat[spot].snap > 0
    ]
    claps = []

    for spot in snares:
        if len(claps) < profile.get("breakClaps", 1) and all(abs(spot - other) >= 2 - EPS for other in claps):
            claps.append(spot)

    return sorted(claps)


def _crowded(specials, beat, profile):
    """Whether one more special on beat would put too many inside some four beats."""
    limit = profile["barSpecials"]
    marks = sorted(list(specials) + [beat])

    return any(
        marks[index] <= beat + EPS <= marks[index + limit] + 2 * EPS and marks[index + limit] - marks[index] < BAR_BEATS - EPS
        for index in range(len(marks) - limit)
    )


def _move_specials(notes, moves):
    """The beats of the specials place_moves laid: rush starts, holds and claps outside a hold."""
    beats = []

    for index, move in enumerate(moves):
        kind = _kind(move)
        before = moves[index - 1] if index > 0 else None

        if kind == "rush" and (before or {}).get("rush") != move["rush"]:
            beats.append(notes[index].beat)
        elif kind == "hold" or (kind == "clap" and _kind(moves[_clap_root(moves, index, _kind)]) != "hold"):
            beats.append(notes[index].beat)

    return beats


def _special_beats(steps):
    """Where the chart's specials fall: a wall counts at its first and last line."""
    notes = notes_of(steps)
    beats = [notes[group[0]]["beat"] for group in _rush_groups(notes)]

    for index, note in enumerate(notes):
        kind = note.get("type")
        in_hold = kind == "clap" and notes[_clap_root(notes, index, _type)].get("type") == "hold"

        if kind in ("hold", "slide", "pose") or (kind == "clap" and not in_hold):
            beats.append(note["beat"])

    tiles = {}

    for step in steps:
        if step.get("type") == "danger":
            tiles[step["beat"]] = tiles.get(step["beat"], 0) + 1

    lines = sorted(beat for beat, count in tiles.items() if count >= WALL_MIN_TILES)
    beats += [beat for beat, count in tiles.items() if count < WALL_MIN_TILES]

    for index, beat in enumerate(lines):
        starts = index == 0 or beat - lines[index - 1] > 1 + EPS
        ends = index + 1 == len(lines) or lines[index + 1] - beat > 1 + EPS

        if starts or ends:
            beats.append(beat)

    return sorted(beats)


def _type(note):
    return note.get("type") if note else None


def _clap_root(notes, index, kind_of):
    """The index of the note before notes[index], past a run of claps (claps inside one hold share it)."""
    root = max(index - 1, 0)

    while root > 0 and kind_of(notes[root]) == "clap":
        root -= 1

    return root


def _in_hold(notes, index, beat_seconds):
    """Whether notes[index] is a clap that falls inside the hold before its run of claps."""
    if index >= len(notes) or notes[index].get("type") != "clap":
        return False

    hold = notes[_clap_root(notes, index, _type)]
    end = hold["beat"] + hold.get("holdSeconds", 0.0) / beat_seconds

    return hold.get("type") == "hold" and notes[index]["beat"] < end - EPS


def _still_moment(beat, previous, previous_move, following, following_move):
    """Whether a clap on beat falls while the dancer stands still: inside a hold, or mid-rest."""
    if _kind(previous_move) == "hold":
        previous += previous_move["holdBeats"]

        if beat < previous - EPS:
            return True
    elif previous_move is not None:
        return False

    if following - previous < REST_GAP_BEATS - EPS:
        return False

    if beat - previous < 1 - EPS or following - beat < 1 - EPS:
        return False

    return _kind(following_move) != "rush" or following - beat > RUSH_AFTER_BEATS + EPS


def _holds(notes, sections, profile, beat_seconds, moves=None):
    """Which notes ring long enough, with room after them, to be held."""
    holds = {}
    last = -profile["holdSpacing"]
    specials = _move_specials(notes, moves) if moves else []

    for index, onset in enumerate(notes):
        if index + 1 >= len(notes) or index - last < profile["holdSpacing"]:
            continue

        if moves and (moves[index] or moves[index + 1]):
            continue

        gap = notes[index + 1].beat - onset.beat
        energy = energy_at(sections, onset.beat)

        if onset.sustain < HOLD_MIN_BEATS[energy] or gap < HOLD_MIN_GAP_BEATS:
            continue

        held = min(onset.sustain - RING_RELEASE_BEATS, gap - _release_beats(profile, beat_seconds))
        held = math.floor(held / RING_RELEASE_BEATS + EPS) * RING_RELEASE_BEATS * beat_seconds
        held = min(held, HOLD_MAX_SECONDS, gap * beat_seconds - profile["stepSeconds"] - profile["margin"])

        if held < HOLD_MIN_SECONDS or _crowded(specials, onset.beat, profile):
            continue

        holds[index] = int(held * 1000) / 1000.0
        specials.append(onset.beat)
        last = index

    return holds


def _in_bounds(tile):
    return 1 <= tile[0] <= BOARD and 1 <= tile[1] <= BOARD


def _diagonal_ok(move, profile):
    """A corner step, one hop where the profile allows diagonals."""
    return bool(profile.get("diagonals")) and abs(move[0]) == 1 and abs(move[1]) == 1


def _hops(move, profile):
    if profile.get("diagonals"):
        return max(abs(move[0]), abs(move[1]))

    return abs(move[0]) + abs(move[1])


def _move_ok(move, gap_beats, beat_seconds, profile, held_seconds):
    hops = _hops(move, profile) if held_seconds <= 0 else abs(move[0]) + abs(move[1])
    return _travel_ok(hops, gap_beats, beat_seconds, profile, held_seconds)


def _travel_ok(distance, gap_beats, beat_seconds, profile, held_seconds, walked=False):
    if distance == 0 or (not walked and distance > profile.get("maxHop", distance)):
        return False

    if distance / gap_beats > profile["maxBeatTravel"] + EPS:
        return False

    free = gap_beats * beat_seconds - held_seconds

    if distance * profile["stepSeconds"] > free - profile["margin"]:
        return False

    return not (held_seconds > 0 and distance > 1)


def _quick_return(beats, index):
    """Whether a step back onto the tile two notes ago would come too soon to read."""
    if index < 2:
        return False

    gap = beats[index] - beats[index - 1]
    span = beats[index - 1] - beats[index - 2]

    return gap <= RETURN_BEATS + EPS and span <= RETURN_SPAN_BEATS + EPS


def _sign(value):
    return (value > 0) - (value < 0)


def _is_jump(move, profile):
    return abs(move[0]) + abs(move[1]) >= 2 and not _diagonal_ok(move, profile)


def _streak(history, move):
    if abs(move[0]) + abs(move[1]) != 1:
        return 0

    count = 1

    for previous in reversed(history):
        if previous != move:
            break

        count += 1

    return count


class _Layout:
    def __init__(self, notes, holds, sections, profile, beat_seconds, rng, moves=None, echoes=None):
        self.moves = moves or [None] * len(notes)
        self.echoes = echoes or {}
        self.dropped = set()
        self.notes = notes
        self.beats = [note.beat for note in notes]
        self.holds = holds
        self.sections = sections
        self.profile = profile
        self.beat_seconds = beat_seconds
        self.rng = rng
        self.visits = {}
        self.history = []
        self.tiles = []
        self.recent_patterns = []
        self.return_run = 0
        self.patterns = {}

    def _visit(self, tile):
        self.visits[tile] = self.visits.get(tile, 0) + 1
        self.tiles.append(tile)

    def _try(self, moves, start, strict=True):
        """Score a run of moves from note `start`, or None if any move is unplayable."""
        tile = self.tiles[-1]
        history = list(self.history)
        trail = self.tiles[-2:]
        run = self.return_run
        limit = self.profile["returns"]
        contour = 0.0
        crowd = 0.0
        streak_penalty = 0.0
        placed = []

        for offset, move in enumerate(moves):
            index = start + offset

            if index >= len(self.notes) or self.moves[index] is not None:
                break

            previous = self.notes[index - 1]
            gap = self.notes[index].beat - previous.beat
            held = self.holds.get(index - 1, 0.0)

            if not _move_ok(move, gap, self.beat_seconds, self.profile, held):
                return None

            if index in self.holds and abs(move[0]) + abs(move[1]) != 1:
                return None

            if _kind(self.moves[index - 1]) in STAYS and abs(move[0]) + abs(move[1]) != 1:
                return None

            tile = (tile[0] + move[0], tile[1] + move[1])

            if not _in_bounds(tile):
                return None

            back = len(trail) >= 2 and tile == trail[-2]
            run = run + 1 if back and _quick_return(self.beats, index) else 0
            trail.append(tile)

            if strict and limit is not None and run > limit:
                return None

            if back and limit is not None:
                streak_penalty += RETURN_PENALTY

            if not self.profile["jumpPairs"] and history and _is_jump(move, self.profile) and _is_jump(history[-1], self.profile):
                return None

            streak = _streak(history, move)

            if streak > MAX_STREAK:
                return None

            if streak > 3:
                streak_penalty += 2.0

            history.append(move)
            pitch, before = self.notes[index].pitch, previous.pitch

            if pitch is not None and before is not None:
                contour += _sign(pitch - before) * (move[0] - move[1])

            crowd += self.visits.get(tile, 0)
            placed.append(tile)

            if index + 1 < len(self.notes) and _kind(self.moves[index + 1]) == "rush":
                shapes = _rush_shapes(tile, self._rush_size(index + 1))

                if not any(len(trail) < 2 or path[0] != trail[-2] for _, path, _ in shapes):
                    streak_penalty += RUSH_ROOM_PENALTY

        if not placed:
            return None

        mean = max(1.0, len(self.tiles) / float(BOARD * BOARD))
        score = contour - 0.35 * crowd / mean - streak_penalty + self.rng.random() * 0.75

        return score, placed, history, run

    def _choose_pattern(self, energy):
        weights = dict(WEIGHTS[energy])

        if self.profile.get("diagonals"):
            for name, weight in DIAGONAL_WEIGHTS[energy].items():
                weights[name] = weight * self.profile.get("diagonalWeight", 1.0)

        for name in JUMPY:
            if name in weights:
                weights[name] *= self.profile["jump"]

        if not self.profile["jumpPairs"]:
            for name in JUMP_PAIRS:
                weights.pop(name, None)

        if self.profile["returns"] == 0:
            for name in RETURNING:
                weights.pop(name, None)

        if not self.profile["slides"] or self.profile.get("maxHop") == 1:
            for name in CORNERS:
                weights.pop(name, None)

        for name in self.recent_patterns:
            if name in weights:
                weights[name] *= RECENT_PATTERN_WEIGHT

        names = sorted(weights)
        total = sum(weights[name] for name in names)
        roll = self.rng.random() * total

        for name in names:
            roll -= weights[name]

            if roll <= 0:
                return name

        return names[-1]

    def run(self):
        self._visit(CENTRE)
        index = 1

        while index < len(self.notes):
            kind = _kind(self.moves[index])
            echoed = self._echo(index)

            if echoed > 0:
                index += echoed
                continue

            if kind in STAYS:
                self._visit(self.tiles[-1])
                index += 1
                continue

            if kind == "rush":
                index += self._rush(index)
                continue

            energy = energy_at(self.sections, self.notes[index].beat)
            best = None

            for _ in range(4):
                name = self._choose_pattern(energy)

                for orient in ORIENTATIONS:
                    moves = [orient(*move) for move in PATTERNS[name]]
                    result = self._try(moves, index)

                    if result is not None and (best is None or result[0] > best[0][0]):
                        best = (result, name)

                if best is not None:
                    break

            if best is None:
                best = (self._single(index), None)

            (_, placed, history, self.return_run), name = best
            self.history = history[-8:]
            if name is not None:
                self.recent_patterns = (self.recent_patterns + [name])[-RECENT_PATTERNS:]

            # A pattern stops where a repeated phrase starts, so the repeat gets its turn.
            for offset in range(1, len(placed)):
                if index + offset in self.echoes:
                    placed = placed[:offset]
                    break

            if name is not None and len(placed) >= PATTERN_MIN_NOTES:
                group = len(set(self.patterns.values())) + 1

                for offset in range(len(placed)):
                    self.patterns[index + offset] = group

            for tile in placed:
                self._visit(tile)

            index += len(placed)

        return self.tiles

    def _echo(self, index):
        """Replays the section this one repeats, turned to fit the pad, or as much of
        it as fits before the floor runs out; returns how many notes it placed."""
        plan = self.echoes.get(index)

        if plan is None or len(self.tiles) != index:
            return 0

        source, count = plan
        steps = [
            (self.tiles[k][0] - self.tiles[k - 1][0], self.tiles[k][1] - self.tiles[k - 1][1])
            for k in source[:count]
        ]

        best = []

        for orient in ORIENTATIONS:
            x, y = self.tiles[-1]
            path = []

            for step in steps:
                dx, dy = orient(*step)
                x, y = x + dx, y + dy

                if not _in_bounds((x, y)):
                    break

                path.append((x, y))

            if len(path) > len(best):
                best = path

        # Stop on a moving note, so the walk that takes over starts from a step
        # and never splits a rush or a clap from the note it belongs to.
        while best and (len(best) < count and _kind(self.moves[index + len(best)]) in MOVES):
            best.pop()

        if len(best) < ECHO_MIN_NOTES:
            return 0

        for tile in best:
            self._visit(tile)

        self.history = []
        return len(best)

    def _rush_size(self, index):
        group = self.moves[index]["rush"]
        size = 1

        while index + size < len(self.notes) and (self.moves[index + size] or {}).get("rush") == group:
            size += 1

        return size

    def _rush_paths(self, size):
        mean = max(1.0, len(self.tiles) / float(BOARD * BOARD))
        options = []

        for straight, path, moves in _rush_shapes(self.tiles[-1], size):
            if len(self.tiles) >= 2 and path[0] == self.tiles[-2]:
                continue

            crowd = sum(self.visits.get(spot, 0) for spot in path)
            bonus = RUSH_STRAIGHT_BONUS if straight else 0.0
            options.append((self.rng.random() * 1.5 + bonus - 0.35 * crowd / mean, path, moves))

        return options

    def _rush(self, index):
        """Lay a rush group along a straight or once-turned path, trimmed if the pad has no room."""
        size = self._rush_size(index)

        shortest = min(self.profile["rushTiles"] or (RUSH_SIZES[0],))
        placed = size
        options = []

        while placed >= shortest:
            options = self._rush_paths(placed)

            if options:
                break

            placed -= 1

        if not options:
            raise ValueError("no room for the rush at beat %.3f" % self.notes[index].beat)

        _, path, moves = max(options, key=lambda option: option[0])

        for tile in path:
            self._visit(tile)

        for offset in range(placed, size):
            self.dropped.add(index + offset)
            self.tiles.append(path[-1])

        self.history = (self.history + moves)[-8:]
        self.return_run = 0

        return size

    def _single(self, index):
        options = []
        moves = (F, B, L, R, (0, -2), (0, 2), (2, 0), (-2, 0), (1, 1), (1, -1), (-1, 1), (-1, -1))

        for strict in (True, False):
            options = [result for result in (self._try([move], index, strict) for move in moves) if result is not None]

            if options:
                break

        if not options:
            raise ValueError("no playable move to the note at beat %.3f" % self.notes[index].beat)

        return max(options, key=lambda option: option[0])


def _rush_shapes(start, size):
    """(straight, path, moves) for every straight or once-turned run of size tiles from start."""
    for ahead in (F, B, L, R):
        for turn in range(1, size + 1):
            for side in ((ahead[1], ahead[0]), (-ahead[1], -ahead[0])) if turn < size else (None,):
                tile, path, moves = start, [], []

                for step in range(size):
                    move = ahead if step < turn else side
                    tile = (tile[0] + move[0], tile[1] + move[1])
                    path.append(tile)
                    moves.append(move)

                if all(_in_bounds(spot) for spot in path):
                    yield turn == size, path, moves


def _box(a, b):
    xs = range(min(a[0], b[0]), max(a[0], b[0]) + 1)
    ys = range(min(a[1], b[1]), max(a[1], b[1]) + 1)

    return {(x, y) for x in xs for y in ys}


def _spots(note):
    """The tiles that satisfy a note: its own, or any of a shape's."""
    if note.get("type") == "shape":
        return [(tile["x"], tile["y"]) for tile in note["zone"]]

    return [(note["x"], note["y"])]


def _between(start, end):
    tiles = set()

    for a in _spots(start):
        for b in _spots(end):
            tiles |= _box(a, b)

    for tile in end.get("path", ()) if end.get("type") == "slide" else ():
        tiles.add((tile["x"], tile["y"]))

    return tiles


def _occupied(notes, beat):
    """Every tile the dancer could fairly be on at this beat."""
    beats = [note["beat"] for note in notes]
    index = bisect.bisect_right(beats, beat + EPS) - 1
    tiles = set()

    if index >= 0:
        here = notes[index]
        tiles |= set(_spots(here))

        if index > 0 and beat - here["beat"] <= 0.3:
            tiles |= _between(notes[index - 1], here)

    if index + 1 < len(notes):
        after = notes[index + 1]
        tiles |= _between(notes[index] if index >= 0 else after, after)

    return tiles


def _holding(notes, beat, beat_seconds):
    for note in notes:
        if note.get("type") != "hold" or note["beat"] > beat:
            continue

        if note["beat"] + note["holdSeconds"] / beat_seconds >= beat - 0.5:
            return True

    return False


def _wall_stretches(sections, end_beat, profile):
    """(start, stop, energy) of each stretch that gets a danger wall."""
    if profile["walls"] <= 0:
        return []

    candidates = [
        (start, stop, energy)
        for start, stop, energy in _section_bounds(sections, end_beat)
        if RANK[energy] >= RANK["chorus"] and stop - start >= WALL_LINES + 4
    ]
    candidates.sort(key=lambda section: (-RANK[section[2]], -section[0]))
    chosen = sorted(candidates[: profile["walls"]], key=lambda section: section[0])
    every = profile.get("wallEvery")

    if not every:
        return chosen

    return [
        (start + part * every, min(start + (part + 1) * every, stop), energy)
        for start, stop, energy in chosen
        for part in range(int(math.ceil((stop - start) / every - EPS)))
    ]


def _wall_slots(sections, end_beat, profile):
    """(low, high) beats in the middle of each wall stretch that rushes leave free for the wall."""
    slots = []

    for start, stop, _energy in _wall_stretches(sections, end_beat, profile):
        if stop - start >= WALL_LINES + 4:
            first = start + math.floor((stop - start - WALL_LINES) / 2.0)
            slots.append((first, first + WALL_LINES))

    return slots


def _walls(notes, sections, end_beat, profile, beat_seconds, grid, rng):
    """Danger lines sweeping the pad, one line a beat, with holes where the dancer stands."""
    chosen = _wall_stretches(sections, end_beat, profile)

    if not chosen:
        return []

    plain = notes_of(notes)
    rushes = [(plain[group[0]]["beat"], plain[group[-1]]["beat"]) for group in _rush_groups(plain)]
    danger = []

    for start, stop, _energy in chosen:
        starts = [beat for beat in grid if start + 2 - EPS <= beat <= stop - WALL_LINES - EPS]
        rng.shuffle(starts)

        for first in starts:
            axis = rng.choice((0, 1))
            lines = list(range(1, BOARD + 1))

            if rng.random() < 0.5:
                lines.reverse()

            wall = []

            for offset, line in enumerate(lines):
                beat = first + offset

                if _holding(notes, beat, beat_seconds) or any(low <= beat <= high for low, high in rushes):
                    wall = None
                    break

                blocked = _occupied(notes, beat)
                tiles = [
                    (line, other) if axis == 0 else (other, line)
                    for other in range(1, BOARD + 1)
                ]
                tiles = [tile for tile in tiles if tile not in blocked]

                if len(tiles) < WALL_MIN_TILES:
                    wall = None
                    break

                wall.extend({"beat": beat, "x": x, "y": y, "type": "danger"} for x, y in tiles)

            specials = _special_beats(notes + danger)

            if wall and not _crowded(specials, first, profile) and not _crowded(specials + [first], first + 4, profile):
                danger.extend(wall)
                break

    return danger


def _items(notes, danger, sections, end_beat, profile, beat_seconds, rng):
    """One gold tile per stretch of chorus, a short detour off the path."""
    items = []
    beats = [note["beat"] for note in notes]

    def near_danger(tile, beat):
        return any(
            (step["x"], step["y"]) == tile and abs(step["beat"] - beat) <= 1.0 + EPS for step in danger
        )

    def leg_ok(distance, gap):
        return gap > EPS and distance / gap <= profile["maxBeatTravel"] + EPS and (
            distance * profile["stepSeconds"] <= gap * beat_seconds - profile["margin"]
        )

    for start, stop, energy in _section_bounds(sections, end_beat):
        if RANK[energy] < RANK["chorus"]:
            continue

        window = start

        while window + ITEM_WINDOW_BEATS / 2.0 <= stop:
            limit = min(window + ITEM_WINDOW_BEATS, stop)
            middle = (window + limit) / 2.0
            pairs = [
                index for index in range(len(notes) - 1)
                if window - EPS <= beats[index] and beats[index + 1] <= limit + EPS
                and beats[index + 1] - beats[index] >= profile["itemGap"] - EPS
                and notes[index].get("type") not in ("hold",) + MOVES
                and notes[index + 1].get("type") not in ("slide", "clap", "pose")
            ]
            pairs.sort(key=lambda index: abs(beats[index] - middle))

            for index in pairs:
                here, there = notes[index], notes[index + 1]
                a, b = (here["x"], here["y"]), (there["x"], there["y"])
                stride = 1.0 if profile["itemGap"] >= 2 else 0.5
                options = []
                beat = here["beat"] + stride

                top = there["beat"] - (RUSH_CLEAR_BEATS - EPS if there.get("type") == "rush" else EPS)

                while beat < top:
                    for x in range(1, BOARD + 1):
                        for y in range(1, BOARD + 1):
                            tile = (x, y)
                            reach = abs(x - a[0]) + abs(y - a[1])
                            onward = abs(x - b[0]) + abs(y - b[1])

                            if reach == 0 or onward == 0 or near_danger(tile, beat):
                                continue

                            if leg_ok(reach, beat - here["beat"]) and leg_ok(onward, there["beat"] - beat):
                                off_path = reach + onward > abs(a[0] - b[0]) + abs(a[1] - b[1])
                                options.append((off_path, -reach, rng.random(), tile, beat))

                    beat += stride

                if options:
                    best = max(options)
                    items.append({"beat": best[4], "x": best[3][0], "y": best[3][1], "type": "item"})
                    break

            window += ITEM_WINDOW_BEATS

    return items


def _rush_groups(notes):
    """Each rush group's note indices, in order."""
    groups = {}

    for index, note in enumerate(notes):
        if note.get("type") == "rush":
            groups.setdefault(note.get("rush"), []).append(index)

    return list(groups.values())


def _rush_windows(steps):
    """(low, high) beats around each rush that nothing else may be placed in."""
    notes = notes_of(steps)

    return [
        (notes[group[0]]["beat"] - RUSH_CLEAR_BEATS, notes[group[-1]]["beat"] + RUSH_AFTER_BEATS)
        for group in _rush_groups(notes)
    ]


def _bonus(steps, notes):
    last_bonus = -BONUS_SPACING

    for index, onset in enumerate(notes):
        step = steps[index]

        if "type" in step or not onset.accent or index - last_bonus < BONUS_SPACING:
            continue

        step["type"] = "bonus"
        last_bonus = index


def _tile(step):
    return (step["x"], step["y"])


def _distance(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def _slide_lead_beats(beat_seconds):
    return max(SLIDE_TRACK_BEATS, SLIDE_TRACK_SECONDS / beat_seconds)


def _walks(start):
    """Every path of 2 to SLIDE_MAX_MOVES single-tile moves away from start, start included."""
    found = []

    def extend(path):
        if len(path) > 2:
            found.append(list(path))

        if len(path) > SLIDE_MAX_MOVES:
            return

        for dx, dy in (F, B, L, R):
            tile = (path[-1][0] + dx, path[-1][1] + dy)

            if _in_bounds(tile) and tile not in path:
                extend(path + [tile])

    extend([start])

    return found


def path_kind(tiles):
    moves = [(b[0] - a[0], b[1] - a[1]) for a, b in zip(tiles, tiles[1:])]
    turns = sum(1 for first, second in zip(moves, moves[1:]) if first != second)

    if turns == 0:
        return "straight"

    if turns == 1:
        return "L"

    if moves[0] == (-moves[-1][0], -moves[-1][1]):
        return "U"

    return "zigzag"


def _rerouted(steps, index, end, beat_seconds, profile):
    """Whether steps[index] may move to end and still lead on to the notes after it."""
    if end == _tile(steps[index]):
        return True

    if index + 1 < len(steps) and steps[index + 1].get("type") in STAYS:
        return False

    if index >= 2 and end == _tile(steps[index - 2]):
        return False

    if index + 1 >= len(steps):
        return True

    after = steps[index + 1]
    gap = after["beat"] - steps[index]["beat"]
    distance = _distance(end, _tile(after))

    if distance > max(1, _distance(_tile(steps[index]), _tile(after))):
        return False

    if not _move_ok((after["x"] - end[0], after["y"] - end[1]), gap, beat_seconds, profile, 0.0):
        return False

    return index + 2 >= len(steps) or _tile(steps[index + 2]) != end


def _slide_options(steps, index, profile, beat_seconds):
    """(kind, walk) for each way to make steps[index] a slide walked from the note before.

    A walk starts on the note before and may end on another tile than the note's,
    which then moves there.
    """
    a = steps[index - 2] if index >= 2 else None
    b, c = steps[index - 1], steps[index]
    after = steps[index + 1] if index + 1 < len(steps) else None
    gap = c["beat"] - b["beat"]
    avoid = {_tile(step) for step in (a, after) if step is not None}
    options = []

    if gap > _slide_lead_beats(beat_seconds) + EPS:
        return options

    for walk in _walks(_tile(b)):
        if avoid & set(walk) or not _travel_ok(len(walk) - 1, gap, beat_seconds, profile, 0.0, True):
            continue

        if _rerouted(steps, index, walk[-1], beat_seconds, profile):
            options.append((path_kind(walk), walk))

    for back in range(2, min(SLIDE_MAX_MOVES, index) + 1):
        run = steps[index - back : index + 1]
        walk = [_tile(step) for step in run]

        if any("type" in step for step in run[:-1]) or len(set(walk)) != len(walk):
            break

        if any(_distance(one, two) != 1 for one, two in zip(walk, walk[1:])):
            break

        if c["beat"] - run[0]["beat"] <= _slide_lead_beats(beat_seconds) + EPS:
            options.append((path_kind(walk), walk))

    return options


def _slides(steps, profile, beat_seconds, rng):
    """Turn a note now and then into a slide: a cyan path walked from the note before.

    The path leaves out the tile walked from: the server follows a path only once
    the slide's telegraph opens, and that may be after the dancer reached it.
    """
    spacing = profile["slides"]

    if not spacing:
        return

    last_slide = -spacing
    last_kind = None

    for index in range(1, len(steps)):
        if "type" in steps[index] or "type" in steps[index - 1]:
            continue

        if index + 1 < len(steps) and steps[index + 1].get("type") in MOVES:
            continue

        if _crowded(_special_beats(steps), steps[index]["beat"], profile):
            continue

        here = _tile(steps[index])
        corner = _distance(_tile(steps[index - 1]), here) == 2 and steps[index - 1]["x"] != here[0]
        options = _slide_options(steps, index, profile, beat_seconds)

        if corner:
            options = [(kind, walk) for kind, walk in options if len(walk) == 3 and walk[-1] == here]

        if not options or index - last_slide < (min(spacing, SLIDE_CORNER_SPACING) if corner else spacing):
            continue

        kinds = sorted({kind for kind, _ in options})
        weights = [SLIDE_KIND_WEIGHTS[kind] * (0.3 if kind == last_kind else 1.0) for kind in kinds]
        kind = rng.choices(kinds, weights)[0]
        walks = [walk for other, walk in options if other == kind]
        kept = [walk for walk in walks if walk[-1] == _tile(steps[index])]
        walk = rng.choice(kept if kept and rng.random() < SLIDE_KEEP_TILE else walks)
        steps[index]["x"], steps[index]["y"] = walk[-1]
        steps[index]["type"] = "slide"
        steps[index]["path"] = [{"x": x, "y": y} for x, y in walk[1:]]
        last_slide = index
        last_kind = kind


def _slide_start(notes, index):
    """How many notes back the slide's walk starts: past the notes its path runs through."""
    path = [(tile["x"], tile["y"]) for tile in notes[index].get("path") or ()]
    back = 1

    while back < len(path) and back < index and _tile(notes[index - back]) == path[-1 - back]:
        back += 1

    return back


def _slide_walk(notes, index):
    """The slide's path with the tile it is walked from in front."""
    path = [(tile["x"], tile["y"]) for tile in notes[index].get("path") or ()]
    back = _slide_start(notes, index)

    return [_tile(notes[index - back])] + path if index >= back else path


def _slide_problem(notes, index, beat_seconds, profile):
    """Why the slide at notes[index] cannot be walked as the server follows it, or None."""
    note = notes[index]
    walk = _slide_walk(notes, index)
    back = _slide_start(notes, index)

    if not 3 <= len(walk) <= SLIDE_MAX_MOVES + 1 or walk[-1] != _tile(note) or len(set(walk)) != len(walk):
        return "a path of 2 to %d tiles to the slide, off the tile it starts from" % SLIDE_MAX_MOVES

    if any(_distance(one, two) != 1 or not _in_bounds(two) for one, two in zip(walk, walk[1:])):
        return "a path of neighbouring tiles"

    run = notes[index - back : index + 1]

    if any(step.get("type") for step in run[:-1]) or note["beat"] - run[0]["beat"] > _slide_lead_beats(beat_seconds) + EPS:
        return "to start from plain notes no more than its telegraph ahead"

    if back == 1 and not _travel_ok(len(walk) - 1, note["beat"] - run[0]["beat"], beat_seconds, profile, 0.0, True):
        return "more time to walk its %d tiles" % (len(walk) - 1)

    return None


SHAPE_VARIANTS = {
    name: sorted({tuple(sorted(orient(*offset) for offset in offsets)) for orient in ORIENTATIONS})
    for name, offsets in SHAPES.items()
}


def _zones(tile, avoid, profile):
    """(name, tiles) for every shape on the pad that covers tile and none of avoid."""
    found = []

    for name, variants in SHAPE_VARIANTS.items():
        if name in CORNER_SHAPES and not profile.get("diagonals"):
            continue

        for offsets in variants:
            for ox, oy in offsets:
                zone = [(tile[0] + dx - ox, tile[1] + dy - oy) for dx, dy in offsets]

                if all(_in_bounds(spot) for spot in zone) and not set(zone) & set(avoid):
                    found.append((name, sorted(zone)))

    return found


def _event_spans(steps):
    spans = {}

    for step in steps:
        if "event" in step:
            low, high = spans.get(step["event"], (step["beat"], step["beat"]))
            spans[step["event"]] = (min(low, step["beat"]), max(high, step["beat"]))

    return list(spans.values())


def _shape_options(notes, index, extras, spans, sections, profile, beat_seconds):
    note, before, after = notes[index], notes[index - 1], notes[index + 1]
    gap = after["beat"] - note["beat"]

    if note.get("type") not in (None, "bonus") or any(key in note for key in ("event", "hidden")):
        return []

    if "event" in before or "event" in after:
        return []

    if before.get("type") in STAYS + ("hold",) or after.get("type") in MOVES + ("hold",):
        return []

    if energy_at(sections, note["beat"]) not in profile["shapeEvery"] or gap < SHAPE_MIN_GAP_BEATS - EPS:
        return []

    if any(low - SHAPE_CLEAR_BEATS <= note["beat"] <= high + SHAPE_CLEAR_BEATS for low, high in spans):
        return []

    if any(before["beat"] - EPS <= extra["beat"] <= after["beat"] + SHAPE_CLEAR_BEATS for extra in extras):
        return []

    for later in range(index + 1, min(index + 1 + SLIDE_MAX_MOVES, len(notes))):
        if notes[later].get("type") == "slide" and later - _slide_start(notes, later) <= index:
            return []

    if profile.get("maxHop") == 1 and not profile.get("diagonals"):
        return [] if before.get("type") == "shape" else _split_zones(before, note, after)

    lead = note["beat"] - before["beat"]
    reach = dict(profile, maxHop=profile.get("shapeHop", profile.get("maxHop")))

    return [
        (name, zone)
        for name, zone in _zones(_tile(note), _spots(before) + [_tile(after)], profile)
        if all(_move_ok((after["x"] - x, after["y"] - y), gap, beat_seconds, reach, 0.0) for x, y in zone)
        and all(_move_ok((x - bx, y - by), lead, beat_seconds, reach, 0.0) for x, y in zone for bx, by in _spots(before))
    ]


def _split_zones(before, note, after):
    b, n, a = _tile(before), _tile(note), _tile(after)

    if _distance(b, n) != 1 or _distance(n, a) != 1 or abs(b[0] - a[0]) != 1 or abs(b[1] - a[1]) != 1:
        return []

    across = (b[0] + a[0] - n[0], b[1] + a[1] - n[1])

    return [(SPLIT, sorted([n, across]))]


def _is_split(zone):
    return len(zone) == 2 and abs(zone[0][0] - zone[1][0]) == 1 and abs(zone[0][1] - zone[1][1]) == 1


def _shape_appeal(notes, index, sections, rng):
    note, before = notes[index], notes[index - 1]
    downbeat, strength = note.get("cue", (False, 0.0))
    lifted = RANK[energy_at(sections, note["beat"])] > RANK[energy_at(sections, before["beat"])]

    return 2.0 * downbeat + 1.5 * lifted + 1.5 * (_distance(_tile(before), _tile(note)) >= 2) + strength + rng.random()


def _pick_zone(options, before, difficulty, last_name, rng):
    weights = SHAPE_WEIGHTS[difficulty]
    names = sorted({name for name, _ in options})
    size = {name: max(len(zone) for kind, zone in options if kind == name) for name in names}
    name = rng.choices(
        names, [weights[name] * (size[name] - 1) * (0.3 if name == last_name else 1.0) for name in names]
    )[0]
    zones = [zone for kind, zone in options if kind == name]
    nearest = min(_distance(_tile(before), spot) for zone in zones for spot in zone)
    short_cuts = [zone for zone in zones if min(_distance(_tile(before), spot) for spot in zone) == nearest]

    return name, rng.choice(short_cuts)


def _repair_slides(steps, beat_seconds, profile):
    notes = notes_of(steps)

    for index, note in enumerate(notes):
        if note.get("type") == "slide" and _slide_problem(notes, index, beat_seconds, profile):
            del note["type"], note["path"]


def dress(steps, sections, bpm, difficulty, seed=0):
    """The finished chart: slides an event cut short undone, then shapes placed.

    Runs after events.place, so a shape never lands in or next to an event.
    """
    profile = PROFILES[difficulty]
    rng = random.Random(seed * 131 + list(PROFILES).index(difficulty) * 17 + 5)
    beat_seconds = 60.0 / float(bpm)
    sections = merge_sections(sections)
    _repair_slides(steps, beat_seconds, profile)
    notes = notes_of(steps)
    extras = [step for step in steps if step.get("type") in ("danger", "item")]
    spans = _event_spans(steps)
    window, last_beat, last_name = 1.0, None, None
    end = notes[-1]["beat"] if notes else 0.0

    while window <= end:
        best = None
        every = profile["shapeEvery"].get(energy_at(sections, window))

        if not every:
            window += BAR_BEATS
            continue

        for index in range(1, len(notes) - 1):
            beat = notes[index]["beat"]

            if not window - EPS <= beat < window + every - EPS:
                continue

            if last_beat is not None and beat - last_beat < every / 2.0 - EPS:
                continue

            options = _shape_options(notes, index, extras, spans, sections, profile, beat_seconds)

            if options:
                widest = max(len(zone) for _, zone in options)
                appeal = _shape_appeal(notes, index, sections, rng) + SHAPE_SIZE_APPEAL * (widest - 2)

                if best is None or appeal > best[0]:
                    best = (appeal, index, options)

        if best is not None:
            _, index, options = best
            last_name, zone = _pick_zone(options, notes[index - 1], difficulty, last_name, rng)
            notes[index]["type"] = "shape"
            notes[index]["zone"] = [{"x": x, "y": y} for x, y in zone]
            last_beat = notes[index]["beat"]

        window += every

    steps = _singles(steps, sections, profile, rng)

    for step in steps:
        step.pop("cue", None)

    return steps


def _single_spots(notes, index, steps, rushes, spans):
    """Free tiles beside notes[index] a lone danger may take on its beat."""
    note, before, after = notes[index], notes[index - 1], notes[index + 1]
    beat = note["beat"]
    plain = ("bonus", "hold")

    if any(key in note for key in ("event", "hidden")) or note.get("type") not in (None,) + plain:
        return []

    if any(step.get("type") in ("shape", "slide") for step in (before, after)):
        return []

    if any(low - EPS <= beat <= high + EPS for low, high in rushes):
        return []

    if any(low - DANGER_CLEAR_BEATS <= beat <= high + DANGER_CLEAR_BEATS for low, high in spans):
        return []

    if any(
        step.get("type") in ("danger", "item") and abs(step["beat"] - beat) <= DANGER_CLEAR_BEATS + EPS
        for step in steps
    ):
        return []

    items = [step for step in steps if step.get("type") == "item"]
    taken = _occupied(notes, beat) | {_tile(item) for item in items if abs(item["beat"] - beat) <= DANGER_ITEM_BEATS}
    here = _tile(note)
    beside = [(here[0] + dx, here[1] + dy) for dx, dy in (F, B, L, R)]

    return [tile for tile in beside if _in_bounds(tile) and tile not in taken]


def _singles(steps, sections, profile, rng):
    """A lone danger tile beside the path now and then, on the beat of a plain note."""
    every = profile.get("dangerEvery", 0)
    notes = notes_of(steps)

    if not every or len(notes) < 3:
        return steps

    rushes = _rush_windows(steps)
    spans = _event_spans(steps)
    added = []
    window, last_beat = 1.0, -every
    end = notes[-1]["beat"]

    while window <= end:
        options = []

        for index in range(1, len(notes) - 1):
            beat = notes[index]["beat"]

            if not window - EPS <= beat < window + every - EPS or beat - last_beat < every / 2.0 - EPS:
                continue

            if energy_at(sections, beat) not in DANGER_ENERGIES or _crowded(_special_beats(steps + added), beat, profile):
                continue

            spots = _single_spots(notes, index, steps + added, rushes, spans)

            if spots:
                options.append((rng.random(), beat, spots))

        if options:
            _, beat, spots = max(options)
            x, y = rng.choice(spots)
            added.append({"beat": beat, "x": x, "y": y, "type": "danger"})
            last_beat = beat

        window += every

    order = {"danger": 1, "item": 2}

    return sorted(steps + added, key=lambda step: (step["beat"], order.get(step.get("type"), 0)))


def merge_sections(sections):
    merged = []

    for beat, energy in sorted(sections):
        if merged and merged[-1][1] == energy:
            continue

        merged.append((beat, energy))

    if merged:
        merged[0] = (1.0, merged[0][1])

    return merged


def _echoes(notes, moves, holds, named_sections, end_beat):
    """{first index of a phrase: the indices of the earlier phrase it repeats}.

    When the music comes back (a second verse, every chorus, the second half of
    a verse) the player should recognise the steps, so a phrase whose notes fall
    on the same beats, with the same moves, as an earlier one dances it again.
    """
    first, plan = {}, {}

    for section_start, section_stop, _energy in _section_bounds(named_sections, end_beat):
        start = section_start

        while start < section_stop - EPS:
            stop = min(start + ECHO_PHRASE_BEATS, section_stop)
            indices = [index for index, note in enumerate(notes) if start - EPS <= note.beat < stop - EPS]
            start = stop

            if len(indices) < ECHO_MIN_NOTES or indices[0] == 0:
                continue

            signature = tuple(
                (round(notes[index].beat - notes[indices[0]].beat, 4), _kind(moves[index]), index in holds)
                for index in indices
            )

            if signature in first:
                plan[indices[0]] = (first[signature], len(indices))
            else:
                first[signature] = indices

    return plan


def build(onsets, sections, end_beat, bpm, difficulty, seed=0, rhythm=None, hits=None):
    """The floor chart: notes, then danger walls and items, sorted by beat.

    rhythm, when given, is the beats the steps go on, in place of pick's choice,
    and hits the beats with a real hit under them, the only ones a rush may use.
    """
    profile = PROFILES[difficulty]
    rng = random.Random(seed * 31 + len(difficulty) * 7919)
    beat_seconds = 60.0 / float(bpm)
    named_sections = sorted(sections)
    sections = merge_sections(sections)
    ordered = sorted(onsets, key=lambda onset: onset.beat)

    if rhythm is None:
        notes = pick(ordered, sections, end_beat, profile, bpm)
    else:
        by_beat = {round(onset.beat, 4): onset for onset in ordered}
        notes = [by_beat[round(beat, 4)] for beat in _breathe(sorted(rhythm), ordered, sections, profile)]

    if len(notes) < 2:
        raise ValueError("too few onsets to chart %r" % difficulty)

    notes, moves = place_moves(notes, ordered, sections, end_beat, profile, bpm, rng, hits)
    holds = _holds(notes, sections, profile, beat_seconds, moves)

    for index, move in enumerate(moves):
        if _kind(move) == "hold":
            holds[index] = round(move["holdBeats"] * beat_seconds, 3)
            moves[index] = None

    # A walk can corner itself before a rush; the next draw of the same rng
    # usually finds room, and keeps the chart reproducible from the seed.
    echoes = _echoes(notes, moves, holds, named_sections, end_beat)

    for attempt in range(LAYOUT_ATTEMPTS):
        layout = _Layout(notes, holds, sections, profile, beat_seconds, rng, moves, echoes)

        try:
            tiles = layout.run()
            break
        except ValueError:
            if attempt + 1 == LAYOUT_ATTEMPTS:
                raise

    strongest = max(max(onset.strength for onset in notes), EPS)
    steps = []
    kept = []

    for index, onset in enumerate(notes):
        if index in layout.dropped:
            continue

        step = {"beat": round(onset.beat, 4), "x": tiles[index][0], "y": tiles[index][1]}
        move = moves[index]

        if move:
            step["type"] = move["kind"]
            step.update({key: value for key, value in move.items() if key != "kind"})
        elif index in holds:
            step["type"] = "hold"
            step["holdSeconds"] = holds[index]

        if index in layout.patterns:
            step["pattern"] = layout.patterns[index]

        step["cue"] = (onset.downbeat, onset.strength / strongest)
        steps.append(step)
        kept.append(onset)

    _bonus(steps, kept)
    _slides(steps, profile, beat_seconds, rng)
    grid = sorted(round(onset.beat, 4) for onset in onsets if onset.on_beat)
    danger = _walls(steps, sections, end_beat, profile, beat_seconds, grid, rng)
    items = _items(steps, danger, sections, end_beat, profile, beat_seconds, rng)
    order = {"danger": 1, "item": 2}
    every = sorted(steps + danger + items, key=lambda step: (step["beat"], order.get(step.get("type"), 0)))

    return every, sections


def notes_of(steps):
    return [step for step in steps if step.get("type") not in ("danger", "item")]


def check(steps, bpm, difficulty):
    """Problems that would make a chart unfair in onBeat, as readable strings."""
    profile = PROFILES[difficulty]
    beat_seconds = 60.0 / float(bpm)
    notes = notes_of(steps)
    problems = []

    for index in range(1, len(steps)):
        if steps[index]["beat"] < steps[index - 1]["beat"] - EPS:
            problems.append("steps out of order at beat %.3f" % steps[index]["beat"])

    problems += _move_problems(steps, notes, bpm, profile, difficulty)

    for index in range(1, len(notes)):
        before, note = notes[_moved_from(notes, index)], notes[index]
        gap = note["beat"] - before["beat"]
        held = before.get("holdSeconds", 0.0) if before.get("type") == "hold" else 0.0
        walked = note.get("type") == "slide" and _slide_start(notes, index) == 1
        reach = profile.get("shapeHop") if before.get("type") == "shape" else None

        if note.get("type") in STAYS and note["beat"] - notes[index - 1]["beat"] > EPS:
            continue

        for spot in _spots(before):
            distance = len(note["path"]) if walked else _hops((note["x"] - spot[0], note["y"] - spot[1]), profile)

            if gap < EPS:
                problems.append("two notes share beat %.3f" % note["beat"])
            elif not _travel_ok(distance, gap, beat_seconds, profile, held, walked or (reach or 0) >= distance):
                problems.append(
                    "note at beat %.3f: %d tile(s) in %.2f beats%s"
                    % (note["beat"], distance, gap, " after a hold" if held else "")
                )
            else:
                continue

            break

        if note.get("type") == "slide":
            reason = _slide_problem(notes, index, beat_seconds, profile)

            if reason:
                problems.append("slide at beat %.3f needs %s" % (note["beat"], reason))

        if note.get("type") == "clap":
            reason = _clap_problem(notes, index, beat_seconds)

            if reason:
                problems.append("clap at beat %.3f %s" % (note["beat"], reason))

        if note.get("type") == "hold":
            reason = _hold_problem(notes, index, beat_seconds, profile)

            if reason:
                problems.append("hold at beat %.3f %s" % (note["beat"], reason))

        if note.get("type") == "shape":
            reason = _shape_problem(notes, index, profile)

            if reason:
                problems.append("shape at beat %.3f %s" % (note["beat"], reason))

    problems += _reversal_problems(notes, beat_seconds)
    specials = _special_beats(steps)
    limit = profile["barSpecials"]

    for index in range(len(specials) - limit):
        if specials[index + limit] - specials[index] < BAR_BEATS - EPS:
            problems.append("more than %d special(s) in the 4 beats from beat %.3f" % (limit, specials[index]))

    groups = _rush_groups(notes)
    rush_gap = profile.get("rushGap", RUSH_GAP_BEATS)

    for earlier, later in zip(groups, groups[1:]):
        if notes[later[0]]["beat"] - notes[earlier[-1]]["beat"] < rush_gap - EPS:
            problems.append("rush at beat %.3f comes too soon after the last" % notes[later[0]]["beat"])
    limit = profile["returns"]

    for index, run in enumerate(_return_runs(notes)):
        if limit is not None and run > limit:
            problems.append("note at beat %.3f steps straight back %d time(s) running" % (notes[index]["beat"], run))

    for step in steps:
        if not _in_bounds((step["x"], step["y"])):
            problems.append("step at beat %.3f is off the pad" % step["beat"])

        if step.get("type") == "danger" and (step["x"], step["y"]) in _occupied(notes, step["beat"]):
            problems.append("danger at beat %.3f sits on the dancer's path" % step["beat"])

        if step.get("type") == "item":
            beats = [note["beat"] for note in notes]
            index = bisect.bisect_left(beats, step["beat"])

            if index < len(beats) and abs(beats[index] - step["beat"]) < EPS:
                problems.append("item at beat %.3f shares a note's beat" % step["beat"])
            elif 0 < index < len(beats):
                legs = [(spot, step["beat"] - beats[index - 1]) for spot in _spots(notes[index - 1])]
                legs.append((_tile(notes[index]), beats[index] - step["beat"]))

                for spot, gap in legs:
                    distance = _distance(spot, _tile(step))

                    if distance == 0 or distance / gap > profile["maxBeatTravel"] + EPS:
                        problems.append("item at beat %.3f is out of reach" % step["beat"])
                        break

    return problems


def _moved_from(notes, index):
    """The note before notes[index] the dancer last stepped to, past any claps."""
    prior = index - 1

    while prior > 0 and notes[prior].get("type") == "clap":
        prior -= 1

    return prior


def _reversal_problems(notes, beat_seconds):
    moving = [note for note in notes if note.get("type") != "clap"]
    problems = []

    for a, b, c in zip(moving, moving[1:], moving[2:]):
        if _tile(a) != _tile(c) or _tile(a) == _tile(b):
            continue

        if (c["beat"] - a["beat"]) * beat_seconds < 2 * FAST_REVERSAL_SECONDS - EPS and max(
            b["beat"] - a["beat"], c["beat"] - b["beat"]
        ) * beat_seconds < FAST_REVERSAL_SECONDS - EPS:
            problems.append("note at beat %.3f steps straight back too fast" % c["beat"])

    return problems


def _clap_problem(notes, index, beat_seconds):
    note = notes[index]
    previous = notes[_clap_root(notes, index, _type)] if index > 0 else None
    following = notes[index + 1] if index + 1 < len(notes) else None

    if previous is None or following is None:
        return "has no note on each side"

    kind = previous.get("type")

    if kind == "hold":
        move = {"kind": "hold", "holdBeats": round(previous["holdSeconds"] / beat_seconds, 2)}
    else:
        move = None if kind in (None, "bonus") else {"kind": kind}

    if not _still_moment(note["beat"], previous["beat"], move, following["beat"], {"kind": following.get("type")}):
        return "is not inside a hold or a rest"

    return None


def _hold_problem(notes, index, beat_seconds, profile):
    note, before = notes[index], notes[index - 1]
    later = [other for other in notes[index + 1 :] if other.get("type") != "clap"]
    after = later[0] if later else None

    if any(_distance(spot, _tile(note)) != 1 for spot in _spots(before)):
        return "is not one tile from the note before it"

    if after is None:
        return None

    release = min(HOLD_RELEASE_BEATS, _release_beats(profile, beat_seconds))

    # holdSeconds is rounded to the millisecond, so it can overshoot its beats by half of one.
    held = max(note.get("holdSeconds", 0.0) - 0.0005, 0.0) / beat_seconds

    if after["beat"] - note["beat"] < held + release - EPS:
        return "is followed too soon"

    if _distance(_tile(after), _tile(note)) != 1:
        return "is not one tile from the note after it"

    return None


def _stay_problems(steps, notes, index, beat_seconds):
    note, kind, beat = notes[index], notes[index].get("type"), notes[index]["beat"]
    before = notes[index - 1] if index > 0 else None
    after = notes[index + 1] if index + 1 < len(notes) else None
    problems = []
    stacked = before is not None and before.get("type") == "clap" and _in_hold(notes, index, beat_seconds)

    if before is None or (before.get("type") in ("shape",) + STAYS and not stacked) or _tile(before) != _tile(note):
        problems.append("%s at beat %.3f is not on the dancer's tile" % (kind, beat))

    if after is not None and not _in_hold(notes, index + 1, beat_seconds) and (
        after.get("type") in ("shape", "slide") + STAYS or _distance(_tile(after), _tile(note)) != 1
    ):
        problems.append("note after the %s at beat %.3f is not one tile away" % (kind, beat))

    length = note.get("poseBeats", 0) if kind == "pose" else 0

    if kind == "pose" and not POSE_BEATS[0] <= length <= POSE_BEATS[1]:
        problems.append("pose at beat %.3f holds %s beats" % (beat, length))

    reach = beat + length + 1 - EPS if kind == "pose" else beat + EPS
    crowd = [
        step for step in steps
        if step is not note and beat - EPS <= step["beat"] < reach
        and not (step.get("type") == "danger" and _tile(step) != _tile(note))
    ]

    if crowd:
        where = "inside its hold" if length else "on its beat"
        problems.append("%s at beat %.3f has another step %s" % (kind, beat, where))

    return problems


def _rush_problems(steps, notes, group, bpm, profile, difficulty):
    rush = [notes[index] for index in group]
    first = rush[0]["beat"]
    where = "rush at beat %.3f" % first
    tiles = [_tile(step) for step in rush]
    sizes = profile["rushTiles"]
    problems = []

    if not sizes:
        problems.append("%s on %s, which has none" % (where, difficulty))
    elif not max(min(sizes), RUSH_SIZES[0]) <= len(rush) <= min(max(sizes), RUSH_SIZES[1]):
        problems.append("%s has %d tiles" % (where, len(rush)))

    if not rush_fits(profile, bpm):
        problems.append("%s is too fast for %g bpm" % (where, bpm))

    if group != list(range(group[0], group[0] + len(group))):
        problems.append("%s is broken up by other notes" % where)

    if any(abs(b["beat"] - a["beat"] - RUSH_STRIDE) > EPS for a, b in zip(rush, rush[1:])):
        problems.append("%s is not half a beat per tile" % where)

    if group[0] == 0 or notes[group[0] - 1].get("type") in ("shape", "slide"):
        problems.append("%s has no single tile to start from" % where)
    elif any(_distance(a, b) != 1 for a, b in zip([_tile(notes[group[0] - 1])] + tiles, tiles)):
        problems.append("%s is not one tile at a time" % where)
    elif path_kind(tiles) not in ("straight", "L"):
        problems.append("%s turns more than once" % where)

    if any(first - RUSH_CLEAR_BEATS + EPS < step["beat"] < first - EPS for step in steps):
        problems.append("%s has something in the %g beats before it" % (where, RUSH_CLEAR_BEATS))

    following = notes[group[-1] + 1] if group[-1] + 1 < len(notes) else None

    if following is not None and following["beat"] - rush[-1]["beat"] < RUSH_AFTER_BEATS - EPS:
        problems.append("%s is followed too soon" % where)

    return problems


def _move_problems(steps, notes, bpm, profile, difficulty):
    """Poses, claps and rushes a player could not fairly do."""
    problems = []

    for index, note in enumerate(notes):
        if note.get("type") == "pose":
            problems.append("pose at beat %.3f: charts use holds now" % note["beat"])

        if note.get("type") in STAYS:
            problems += _stay_problems(steps, notes, index, 60.0 / float(bpm))

    for group in _rush_groups(notes):
        problems += _rush_problems(steps, notes, group, bpm, profile, difficulty)

    if not profile["eighths"]:
        for index in range(1, len(notes)):
            before, note = notes[index - 1], notes[index]
            paired = note.get("type") == before.get("type") == "rush" and before.get("rush") == note.get("rush")

            if note["beat"] - before["beat"] < 1 - EPS and not paired:
                problems.append("note at beat %.3f is off the beat outside a rush" % note["beat"])

    return problems


def _shape_problem(notes, index, profile):
    note = notes[index]
    zone = [(tile["x"], tile["y"]) for tile in note.get("zone") or ()]

    if not 2 <= len(zone) <= SHAPE_MAX_TILES or len(set(zone)) != len(zone) or _tile(note) not in zone:
        return "needs 2 to %d tiles holding its own" % SHAPE_MAX_TILES

    if not all(_in_bounds(spot) for spot in zone):
        return "spills off the pad"

    if not _is_split(zone) and any(
        all(_hops((spot[0] - other[0], spot[1] - other[1]), profile) != 1 for other in zone) for spot in zone
    ):
        return "is not one connected shape"

    for other in notes[index - 1 : index] + notes[index + 1 : index + 2]:
        if _tile(other) in zone:
            return "covers the tile of the note beside it"

    hop = profile.get("shapeHop", profile.get("maxHop"))

    if hop is not None and index > 0:
        if any(
            _hops((spot[0] - other[0], spot[1] - other[1]), profile) > hop
            for spot in zone
            for other in _spots(notes[index - 1])
        ):
            return "has a tile more than %d hop(s) from the note before it" % hop

    return None


def _return_runs(notes):
    """For each note, how many quick steps straight back it ends in a row."""
    beats = [note["beat"] for note in notes]
    runs = []

    for index, note in enumerate(notes):
        back = index >= 2 and _tile(note) == _tile(notes[index - 2]) and _quick_return(beats, index)
        runs.append(runs[-1] + 1 if back and runs else 0)

    return runs


def describe(steps):
    notes = notes_of(steps)
    counts = {}

    for step in steps:
        kind = step.get("type", "tap")
        counts[kind] = counts.get(kind, 0) + 1

    jumps = sum(
        1 for index in range(1, len(notes))
        if _distance(_tile(notes[index]), _tile(notes[index - 1])) >= 2 and notes[index].get("type") != "slide"
    )
    eighths = sum(1 for index in range(1, len(notes)) if notes[index]["beat"] - notes[index - 1]["beat"] < 0.75)
    used = len({(note["x"], note["y"]) for note in notes})
    kinds = {}

    for index, note in enumerate(notes):
        if note.get("type") == "slide":
            kind = path_kind(_slide_walk(notes, index))
            kinds[kind] = kinds.get(kind, 0) + 1

    runs = _return_runs([note for note in notes if "event" not in note])

    return "%s, %d rushes, %d jumps, %d eighths, %d/25 tiles, slide paths %s, %d quick returns (most in a row %d)" % (
        " ".join("%s %d" % (kind, counts[kind]) for kind in sorted(counts)),
        len(_rush_groups(notes)),
        jumps,
        eighths,
        used,
        " ".join("%s %d" % (kind, kinds[kind]) for kind in sorted(kinds)) or "none",
        sum(1 for run in runs if run > 0),
        max(runs or [0]),
    )
