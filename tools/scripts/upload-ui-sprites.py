#!/usr/bin/env python3
"""Pack a folder of named UI sprites into 1024 px atlases and upload them.

Every Name.png may have a grey Name_Tint.png twin (for ImageColor3); the twins
are packed into a second atlas with the identical layout, so one offset serves
both. Sprites are grouped by the prefix before the first underscore (Neon_,
Pastel_, Comic_), one set of pages per style.

    python tools/scripts/upload-ui-sprites.py path/to/sprites --dry-run
    python tools/scripts/upload-ui-sprites.py path/to/sprites

Writes assets/ui-sprites.json (atlas ids and every sprite's rect) and
Client/UI/UiSprites.luau. Re-running skips atlas pages already uploaded with
the same layout. Needs Pillow; the keys come from .env as in reimport-assets.py.
"""

import argparse
import hashlib
import importlib.util
import io
import json
import os
import sys
import time

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("reimport", os.path.join(HERE, "reimport-assets.py"))
reimport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reimport)

MAP_PATH = os.path.join(reimport.REPO_ROOT, "assets", "ui-sprites.json")
LUAU_PATH = os.path.join(reimport.REPO_ROOT, "src", "StarterPlayerScripts", "Client", "UI", "UiSprites.luau")
PAGE = 1024
PAD = 4
# A sprite much bigger than it is drawn costs atlas space and buys no
# sharpness; backdrops cover whole windows, so they keep a full page.
MAX_SIDE = 508
BACKDROP_SIDE = 1024


def collect(folder):
    styles = {}

    for file in sorted(os.listdir(folder)):
        if not file.lower().endswith(".png") or file.endswith("_Tint.png"):
            continue

        name = file[:-4]
        image = Image.open(os.path.join(folder, file))
        limit = BACKDROP_SIDE if "Backdrop" in name else MAX_SIDE
        scale = min(1.0, limit / max(image.size))
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        styles.setdefault(name.split("_", 1)[0], []).append((name, size))

    return styles


def shelf_pack(items):
    pages, rects = [], {}

    for name, (w, h) in sorted(items, key=lambda item: (-item[1][1], -item[1][0])):
        placed = False

        for index, shelves in enumerate(pages):
            for shelf in shelves:
                if h <= shelf["height"] and shelf["x"] + w <= PAGE:
                    rects[name] = (index, shelf["x"], shelf["y"], w, h)
                    shelf["x"] += w + PAD
                    placed = True
                    break

            if placed:
                break

            top = shelves[-1]["y"] + shelves[-1]["height"] + PAD

            if top + h <= PAGE:
                shelves.append({"y": top, "height": h, "x": w + PAD})
                rects[name] = (index, 0, top, w, h)
                placed = True
                break

        if not placed:
            pages.append([{"y": 0, "height": h, "x": w + PAD}])
            rects[name] = (len(pages) - 1, 0, 0, w, h)

    return len(pages), rects


def render(folder, rects, page, suffix):
    canvas = Image.new("RGBA", (PAGE, PAGE), (0, 0, 0, 0))

    for name, (index, x, y, w, h) in rects.items():
        if index != page:
            continue

        path = os.path.join(folder, name + suffix + ".png")

        if not os.path.isfile(path):
            path = os.path.join(folder, name + ".png")

        sprite = Image.open(path).convert("RGBA").resize((w, h), Image.LANCZOS)
        canvas.paste(sprite, (x, y))

    out = io.BytesIO()
    canvas.save(out, format="PNG", optimize=True)
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder")
    parser.add_argument("--dry-run", action="store_true", help="pack and save the pages next to the map, upload nothing")
    parser.add_argument("--upload-key-var", default="ROBLOX_API_KEY_ME")
    args = parser.parse_args()

    previous = {}

    if os.path.isfile(MAP_PATH):
        with open(MAP_PATH, "r", encoding="utf-8") as handle:
            previous = json.load(handle).get("atlases", {})

    env = reimport.load_env()
    key = env.get(args.upload_key_var, "")
    group = int(env.get("ROBLOX_GROUP_ID", "0"))

    if not args.dry_run and (not key or not group):
        raise SystemExit("%s or ROBLOX_GROUP_ID is empty in .env" % args.upload_key_var)

    atlases, sprites, failures = {}, {}, 0

    for style, items in collect(args.folder).items():
        count, rects = shelf_pack(items)

        for page in range(count):
            for suffix in ("", "_Tint"):
                atlas = "%s_Atlas%d%s" % (style, page + 1, suffix)
                png = render(args.folder, rects, page, suffix)
                digest = hashlib.sha1(png).hexdigest()
                known = previous.get(atlas)

                if known and known.get("sha1") == digest:
                    atlases[atlas] = known
                    continue

                if args.dry_run:
                    with open(os.path.join(os.path.dirname(MAP_PATH), atlas + ".png"), "wb") as handle:
                        handle.write(png)
                    print("%s  packed, not uploaded" % atlas)
                    continue

                try:
                    asset_id = reimport.upload(png, atlas, group, key)
                except reimport.ReimportError as error:
                    print("%s  FAILED: %s" % (atlas, error))
                    failures += 1
                    continue

                atlases[atlas] = {"id": asset_id, "sha1": digest}
                print("%s -> %s" % (atlas, asset_id))
                time.sleep(reimport.RATE_PAUSE)

        for name, (page, x, y, w, h) in rects.items():
            sprites[name] = {"atlas": "%s_Atlas%d" % (style, page + 1), "offset": [x, y], "size": [w, h]}

    if args.dry_run:
        return 0

    with open(MAP_PATH, "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"atlases": atlases, "sprites": sprites}, handle, indent=1, sort_keys=True)

    if failures:
        print("%d pages failed; rerun to retry them" % failures)
        return 1

    write_luau(atlases, sprites)
    return 0


def write_luau(atlases, sprites):
    lines = [
        "--!strict",
        "-- Written by tools/scripts/upload-ui-sprites.py from assets/ui-sprites.json; rerun it rather than editing.",
        "export type Sprite = { Image: string, Tint: string, Offset: Vector2, Size: Vector2 }",
        "",
        "local UiSprites: { [string]: Sprite } = {",
    ]

    for name in sorted(sprites):
        sprite = sprites[name]
        atlas = sprite["atlas"]
        lines.append(
            '\t%s = { Image = "rbxassetid://%s", Tint = "rbxassetid://%s", Offset = Vector2.new(%d, %d), Size = Vector2.new(%d, %d) },'
            % (
                name,
                atlases[atlas]["id"],
                atlases[atlas + "_Tint"]["id"],
                sprite["offset"][0],
                sprite["offset"][1],
                sprite["size"][0],
                sprite["size"][1],
            )
        )

    lines += ["}", "", "return UiSprites", ""]

    with open(LUAU_PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))

    print("wrote %s" % os.path.relpath(LUAU_PATH, reimport.REPO_ROOT).replace(os.sep, "/"))


if __name__ == "__main__":
    sys.exit(main())
