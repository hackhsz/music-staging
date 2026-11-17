#!/usr/bin/env python3
"""Re-import Roblox image assets into the group that owns the experience.

Images owned by another account fail to load with "The experience doesn't have
access permission to use asset id ...". This downloads each one and re-uploads
it under the group, then writes an old-id -> new-id map so the references can
be repointed.

    python tools/scripts/reimport-assets.py --ids-file ids.txt --limit 2
    python tools/scripts/reimport-assets.py --ids-file ids.txt
    python tools/scripts/reimport-assets.py --ids-file ids.txt --dry-run

The API key is read from .env at the repo root and is never printed, logged or
written to the map. Re-running skips ids already in the map, so an interrupted
run resumes where it stopped.

Standard library only.
"""

import argparse
import gzip
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV_PATH = os.path.join(REPO_ROOT, ".env")
DELIVERY = "https://apis.roblox.com/asset-delivery-api/v1/assetId/%s"
CREATE = "https://apis.roblox.com/assets/v1/assets"
OPERATION = "https://apis.roblox.com/assets/v1/operations/%s"
POLL_ATTEMPTS = 20
POLL_SECONDS = 2
RATE_PAUSE = 0.6


class ReimportError(Exception):
    pass


def load_env(path=ENV_PATH):
    values = {}

    if not os.path.isfile(path):
        raise ReimportError("no .env at %s" % path)

    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            values[key.strip()] = value.strip()

    return values


def request(url, key, method="GET", body=None, content_type=None, timeout=90):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)

    if content_type is not None:
        req.add_header("Content-Type", content_type)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def download(asset_id, key):
    status, payload = request(DELIVERY % asset_id, key)

    if status != 200:
        raise ReimportError("delivery lookup failed (HTTP %d): %s" % (status, payload[:160]))

    data = json.loads(payload)

    # This endpoint answers 200 with the failure in the body, so a status check
    # alone reports "no location" instead of the actual reason.
    errors = data.get("errors")

    if errors:
        first = errors[0] if isinstance(errors, list) and errors else {}
        raise ReimportError("not downloadable: %s" % first.get("message", json.dumps(errors)[:120]))

    location = data.get("location")

    if not location:
        raise ReimportError("delivery response had no location")

    with urllib.request.urlopen(location, timeout=90) as response:
        raw = response.read()

    # The CDN serves these gzipped regardless of Accept-Encoding.
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)

    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ReimportError("downloaded bytes are not a PNG (got %r)" % raw[:8])

    return raw


def multipart(fields, filename, file_bytes, file_field="fileContent"):
    boundary = "----ddstep%s" % uuid.uuid4().hex
    parts = []

    for name, (value, ctype) in fields.items():
        parts.append(("--%s\r\n" % boundary).encode())
        parts.append(('Content-Disposition: form-data; name="%s"\r\n' % name).encode())
        parts.append(("Content-Type: %s\r\n\r\n" % ctype).encode())
        parts.append(value.encode() if isinstance(value, str) else value)
        parts.append(b"\r\n")

    parts.append(("--%s\r\n" % boundary).encode())
    parts.append(
        ('Content-Disposition: form-data; name="%s"; filename="%s"\r\n' % (file_field, filename)).encode()
    )
    parts.append(b"Content-Type: image/png\r\n\r\n")
    parts.append(file_bytes)
    parts.append(("\r\n--%s--\r\n" % boundary).encode())

    return b"".join(parts), "multipart/form-data; boundary=%s" % boundary


def upload(png, name, group_id, key, asset_type="Image"):
    # Must be "Image". Uploading as "Decal" succeeds and returns a Decal id,
    # which ImageLabel.Image will not render, so every reference silently
    # draws nothing.
    spec = {
        "assetType": asset_type,
        "displayName": name,
        "description": "Re-imported for group ownership.",
        "creationContext": {"creator": {"groupId": str(group_id)}},
    }
    body, content_type = multipart(
        {"request": (json.dumps(spec), "application/json")}, name + ".png", png
    )
    status, payload = request(CREATE, key, method="POST", body=body, content_type=content_type)

    if status == 429:
        raise ReimportError("rate limited")

    if status != 200:
        raise ReimportError("create failed (HTTP %d): %s" % (status, payload[:200]))

    operation = json.loads(payload).get("operationId")

    if not operation:
        raise ReimportError("create returned no operationId")

    for _ in range(POLL_ATTEMPTS):
        time.sleep(POLL_SECONDS)
        status, payload = request(OPERATION % operation, key)

        if status != 200:
            continue

        data = json.loads(payload)

        if data.get("done"):
            asset_id = (data.get("response") or {}).get("assetId")

            if not asset_id:
                raise ReimportError("operation finished without an assetId: %s" % payload[:200])

            return str(asset_id)

    raise ReimportError("operation %s did not finish in time" % operation)


def read_ids(path):
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()

    ids, seen = [], set()

    for token in text.replace(",", " ").split():
        if token.isdigit() and token not in seen:
            seen.add(token)
            ids.append(token)

    return ids


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ids-file", required=True, help="file containing the asset ids to re-import")
    parser.add_argument("--map", default=os.path.join(REPO_ROOT, "assets", "asset-reimport-map.json"))
    parser.add_argument("--group", type=int, help="override the group id from .env")
    parser.add_argument("--limit", type=int, help="only process this many (use 2 for a first run)")
    parser.add_argument("--dry-run", action="store_true", help="download and verify, upload nothing")
    # Each key does one half: only the asset owner's key can read the source,
    # and only a user key is accepted by the Assets API for the upload.
    parser.add_argument("--asset-type", default="Image", choices=["Image", "Decal"])
    parser.add_argument("--download-key-var", default="ROBLOX_API_KEY")
    parser.add_argument("--upload-key-var", default="ROBLOX_API_KEY_ME")
    args = parser.parse_args()

    env = load_env()
    read_key = env.get(args.download_key_var, "")
    write_key = env.get(args.upload_key_var, "")

    if not read_key:
        raise SystemExit("%s is empty in .env" % args.download_key_var)

    if not write_key and not args.dry_run:
        raise SystemExit("%s is empty in .env" % args.upload_key_var)

    group = args.group or int(env.get("ROBLOX_GROUP_ID", "0"))

    if not group:
        raise SystemExit("no group id; set ROBLOX_GROUP_ID in .env or pass --group")

    ids = read_ids(args.ids_file)
    mapping = {}

    if os.path.isfile(args.map):
        with open(args.map, "r", encoding="utf-8") as handle:
            mapping = json.load(handle)

    todo = [i for i in ids if i not in mapping]

    if args.limit:
        todo = todo[: args.limit]

    print("%d ids, %d already done, %d to process%s" % (len(ids), len(mapping), len(todo), "  (dry run)" if args.dry_run else ""))
    os.makedirs(os.path.dirname(args.map), exist_ok=True)
    failures = 0

    for index, asset_id in enumerate(todo, 1):
        prefix = "[%d/%d] %s" % (index, len(todo), asset_id)

        try:
            png = download(asset_id, read_key)
        except ReimportError as error:
            print("%s  DOWNLOAD FAILED: %s" % (prefix, error))
            failures += 1
            continue

        if args.dry_run:
            print("%s  downloaded %d bytes, upload skipped" % (prefix, len(png)))
            continue

        try:
            new_id = upload(png, "ddstep-%s" % asset_id, group, write_key, args.asset_type)
        except ReimportError as error:
            print("%s  UPLOAD FAILED: %s" % (prefix, error))
            failures += 1
            continue

        mapping[asset_id] = new_id
        print("%s  %d bytes -> %s" % (prefix, len(png), new_id))

        with open(args.map, "w", encoding="utf-8") as handle:
            json.dump(mapping, handle, indent=2, sort_keys=True)

        time.sleep(RATE_PAUSE)

    print("")
    print("mapped: %d / %d   failures this run: %d" % (len(mapping), len(ids), failures))

    if not args.dry_run:
        print("map: %s" % os.path.relpath(args.map, REPO_ROOT).replace(os.sep, "/"))

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
