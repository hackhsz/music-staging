#!/usr/bin/env python3
"""Render a song score into audio and into one chart per difficulty.

    python scripts/generate-rhythm-map.py assets/scores/candy-pop-warmup.json
    python scripts/generate-rhythm-map.py assets/scores/*.json --check
    python scripts/generate-rhythm-map.py assets/scores/x.json --no-audio

The score is the single source of truth, so the wav and the charts are always
in sync and the wav never needs committing. Standard library only, except
scores with "sound": "pop", which render through numpy (scripts/music/studio.py).
"""

import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from music import chart, events as floor_events, floor, lanes, score as score_model, synth  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_AUDIO_DIR = os.path.join(REPO_ROOT, "assets", "audio")
DEFAULT_CHART_DIR = os.path.join(REPO_ROOT, "src", "ReplicatedStorage", "Shared", "Songs")
SOURCE = "scripts/generate-rhythm-map.py"


def pascal_case(identifier):
    return "".join(part.capitalize() for part in identifier.replace("_", "-").split("-") if part)


def relative(path):
    return os.path.relpath(path, REPO_ROOT).replace(os.sep, "/")


def process(path, args):
    score = score_model.load(path)
    events = score_model.expand(score)

    if not events:
        raise score_model.ScoreError("%s: the score produced no events" % relative(path))

    difficulties = args.difficulties or list(chart.DIFFICULTIES)
    charts = {}
    highway = {}
    events_by_difficulty = {}
    failures = []

    for difficulty in difficulties:
        if difficulty not in chart.DIFFICULTIES:
            raise SystemExit("unknown difficulty %r (have %s)" % (difficulty, ", ".join(chart.DIFFICULTIES)))

        steps, sections = chart.build(score, events, difficulty, seed=args.seed)
        end_beat = score_model.total_beats(score) + 1.0
        seed = args.seed if args.seed is not None else score.get("seed", 0)
        steps, floor_event_list = floor_events.place(steps, sections, end_beat, score["bpm"], difficulty, seed)
        steps = floor.dress(steps, sections, score["bpm"], difficulty, seed)
        plain = floor_events.plain(steps)
        report = chart.analyze(plain, difficulty)
        charts[difficulty] = (steps, sections)
        events_by_difficulty[difficulty] = floor_event_list
        highway[difficulty] = lanes.build(score, events, difficulty)

        walk = chart.reachability(plain, score["bpm"], difficulty)
        problems = floor.check(plain, score["bpm"], difficulty)
        problems += floor_events.check(steps, floor_event_list, score["bpm"], difficulty)

        if not report["ok"]:
            status = "TRAVEL BUDGET EXCEEDED"
        elif not walk["walkable"]:
            status = "NOT WALKABLE"
        elif problems:
            status = "UNFAIR"
        else:
            status = "ok"

        print(
            "  %-7s %3d notes  max %.2f tiles/beat  %s  (highway %d notes)"
            % (difficulty, report["stepCount"], report["maxObservedTravel"], status, len(highway[difficulty]))
        )
        print("            %s" % floor.describe(steps))
        print("            events: %s" % (" ".join("%s@%g" % (e["kind"], e["beat"]) for e in floor_event_list) or "none"))

        if not walk["walkable"]:
            failures.append("%s/%s: not physically walkable at %s bpm" % (score["id"], difficulty, score["bpm"]))

        for warning in report["warnings"] + problems:
            print("            %s" % warning)
            failures.append("%s/%s: %s" % (score["id"], difficulty, warning))

    if failures:
        raise SystemExit("\n%d chart problem(s); nothing written." % len(failures))

    if args.check:
        return

    module_name = "Generated" + pascal_case(score["id"])
    chart_path = os.path.join(args.chart_dir, module_name + ".luau")
    os.makedirs(args.chart_dir, exist_ok=True)

    with open(chart_path, "w", encoding="utf-8", newline="\n") as handle:
        text = chart.to_luau(score, charts, module_name, SOURCE, relative(path), highway)
        order = sorted(charts, key=lambda name: list(chart.DIFFICULTIES).index(name))
        handle.write(floor_events.decorate(text, [(charts[name][0], events_by_difficulty[name]) for name in order]))

    print("  chart -> %s" % relative(chart_path))

    if args.no_audio:
        return

    os.makedirs(args.audio_dir, exist_ok=True)
    audio_path = os.path.join(args.audio_dir, score["id"] + ".wav")
    buffer = synth.render(score, events, seed=args.seed)
    seconds = synth.write_wav(audio_path, buffer)
    size_mb = os.path.getsize(audio_path) / (1024.0 * 1024.0)

    print("  audio -> %s  (%.1fs, %.1f MB)" % (relative(audio_path), seconds, size_mb))

    if seconds > 7 * 60:
        print("  WARNING: over Roblox's 7 minute limit")

    if size_mb > 20:
        print("  WARNING: over Roblox's 20 MB limit")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scores", nargs="+", help="score JSON files (globs allowed)")
    parser.add_argument("--chart-dir", default=DEFAULT_CHART_DIR)
    parser.add_argument("--audio-dir", default=DEFAULT_AUDIO_DIR)
    parser.add_argument("--difficulties", nargs="*", help="default: every difficulty")
    parser.add_argument("--no-audio", action="store_true", help="charts only")
    parser.add_argument("--check", action="store_true", help="validate and report, write nothing")
    parser.add_argument("--seed", type=int, help="override the score's seed")
    args = parser.parse_args()

    paths = []

    for pattern in args.scores:
        matches = sorted(glob.glob(pattern))
        paths.extend(matches if matches else [pattern])

    if not paths:
        raise SystemExit("no score files matched")

    for path in paths:
        if not os.path.isfile(path):
            raise SystemExit("no such score file: %s" % path)

        print(relative(path))

        try:
            process(path, args)
        except score_model.ScoreError as error:
            raise SystemExit("invalid score %s" % error)


if __name__ == "__main__":
    main()
