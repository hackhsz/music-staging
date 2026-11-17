#!/usr/bin/env python3
"""Emit a Luau script that repoints StarterGui image ids onto the re-imported ones.

Reads the old-id -> new-id map written by reimport-assets.py and prints Luau to
paste into Studio (or run through the Studio MCP). The emitted script reports
what it would change, and only writes when RUN is true, so the first pass is a
preview rather than an edit you cannot see.

    python tools/scripts/emit-repoint-luau.py > repoint.luau
    python tools/scripts/emit-repoint-luau.py --apply > repoint.luau

Standard library only.
"""

import argparse
import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_MAP = os.path.join(REPO_ROOT, "assets", "asset-reimport-map.json")

TEMPLATE = '''local RUN = %(run)s

local StarterGui = game:GetService("StarterGui")

local REMAP = {
%(pairs)s}

local PROPS = { "Image", "Texture" }

local changed, skipped = 0, 0
local lines = {}

for _, inst in StarterGui:GetDescendants() do
\tfor _, prop in PROPS do
\t\tlocal ok, value = pcall(function()
\t\t\treturn (inst :: any)[prop]
\t\tend)

\t\tif ok and typeof(value) == "string" and value ~= "" then
\t\t\tlocal old = string.match(value, "(%%d+)")
\t\t\tlocal new = if old ~= nil then REMAP[old] else nil

\t\t\tif new ~= nil then
\t\t\t\tif RUN then
\t\t\t\t\t(inst :: any)[prop] = "rbxassetid://" .. new
\t\t\t\tend

\t\t\t\tchanged += 1

\t\t\t\tif #lines < 12 then
\t\t\t\t\ttable.insert(lines, string.format("  %%s.%%s  %%s -> %%s", inst:GetFullName(), prop, old, new))
\t\t\t\tend
\t\t\telseif old ~= nil then
\t\t\t\tskipped += 1
\t\t\tend
\t\tend
\tend
end

local out = {}
table.insert(out, if RUN then "APPLIED" else "PREVIEW (nothing written)")
table.insert(out, string.format("remap entries: %%d", %(count)d))
table.insert(out, string.format("references %%s: %%d", if RUN then "rewritten" else "that would change", changed))
table.insert(out, string.format("references left on other ids: %%d", skipped))
table.insert(out, "")
for _, line in lines do
\ttable.insert(out, line)
end
if changed > #lines then
\ttable.insert(out, string.format("  ... and %%d more", changed - #lines))
end

return table.concat(out, "\\n")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--map", default=DEFAULT_MAP)
    parser.add_argument(
        "--rebase-from",
        help="a previous map whose values the place already holds; emit thosevalues -> --map's values, joined on the original id",
    )
    parser.add_argument("--apply", action="store_true", help="emit a script that writes, not one that previews")
    args = parser.parse_args()

    if not os.path.isfile(args.map):
        raise SystemExit("no map at %s; run reimport-assets.py first" % args.map)

    with open(args.map, "r", encoding="utf-8") as handle:
        mapping = json.load(handle)

    # After a bad import the place holds the wrong ids, not the originals, so
    # the remap has to start from what is actually in there.
    if args.rebase_from:
        if not os.path.isfile(args.rebase_from):
            raise SystemExit("no map at %s" % args.rebase_from)

        with open(args.rebase_from, "r", encoding="utf-8") as handle:
            previous = json.load(handle)

        rebased, orphans = {}, 0

        for original, current in previous.items():
            replacement = mapping.get(original)

            if replacement is None:
                orphans += 1
                continue

            rebased[current] = replacement

        if orphans:
            sys.stderr.write("warning: %d ids in the previous map have no entry in the new one\n" % orphans)

        mapping = rebased

    if not mapping:
        raise SystemExit("the map is empty")

    pairs = "".join('\t["%s"] = "%s",\n' % (old, new) for old, new in sorted(mapping.items()))

    sys.stdout.write(
        TEMPLATE % {"run": "true" if args.apply else "false", "pairs": pairs, "count": len(mapping)}
    )


if __name__ == "__main__":
    main()
