"""Make the scripts in the open Studio place match src/ on disk, through Argon.

    python scripts/push-to-studio.py

For when Argon's file watcher stops syncing edits while the plugin is still
connected. It writes one Luau script that only rewrites sources that differ,
creates missing folders and scripts, and removes scripts under the managed
folders that no longer exist on disk, then runs it with `argon exec`. Studio's
Output prints what changed; one undo reverts it.
"""

import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(tempfile.gettempdir(), "dance-dance-step-push.luau")
SRC = os.path.join(REPO, "src")

# Disk folder -> instance path, and whether unknown scripts under it are removed.
ROOTS = [
    ("ReplicatedStorage/Shared", "ReplicatedStorage.Shared", True),
    ("ServerScriptService/Server", "ServerScriptService.Server", True),
    ("StarterPlayerScripts/Client", "StarterPlayer.StarterPlayerScripts.Client", True),
    ("ServerStorage/Tests", "ServerStorage.Tests", True),
    ("ServerStorage/ArchivedSongs", "ServerStorage.ArchivedSongs", True),
]


def class_and_name(filename):
    for suffix, class_name in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return class_name, filename[: -len(suffix)]
    return None, None


def long_string(text):
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


entries = []
for disk, instance, _ in ROOTS:
    base = os.path.join(SRC, *disk.split("/"))
    if not os.path.isdir(base):
        continue
    for root, _dirs, files in os.walk(base):
        for filename in sorted(files):
            class_name, name = class_and_name(filename)
            if class_name is None:
                continue
            rel = os.path.relpath(os.path.join(root, filename), base).replace("\\", "/")
            parts = rel.split("/")[:-1] + [name]
            with open(os.path.join(root, filename), "rb") as handle:
                source = handle.read().decode("utf-8").replace("\r\n", "\n")
            entries.append((instance, parts, class_name, source))

lines = [
    "local ChangeHistoryService = game:GetService('ChangeHistoryService')",
    "local recording = ChangeHistoryService:TryBeginRecording('Sync src from disk')",
    "local written, created, removed = 0, 0, 0",
    "local keep = {}",
    "local function resolve(path)",
    "\tlocal node = game",
    "\tfor part in string.gmatch(path, '[^%.]+') do",
    "\t\tlocal child = node:FindFirstChild(part)",
    "\t\tif child == nil then",
    "\t\t\tchild = Instance.new('Folder')",
    "\t\t\tchild.Name = part",
    "\t\t\tchild.Parent = node",
    "\t\tend",
    "\t\tnode = child",
    "\tend",
    "\treturn node",
    "end",
    "local function put(rootPath, parts, className, source)",
    "\tlocal node = resolve(rootPath)",
    "\tfor index = 1, #parts - 1 do",
    "\t\tlocal child = node:FindFirstChild(parts[index])",
    "\t\tif child == nil then",
    "\t\t\tchild = Instance.new('Folder')",
    "\t\t\tchild.Name = parts[index]",
    "\t\t\tchild.Parent = node",
    "\t\tend",
    "\t\tnode = child",
    "\tend",
    "\tlocal name = parts[#parts]",
    "\tlocal script = node:FindFirstChild(name)",
    "\tif script ~= nil and script.ClassName ~= className then",
    "\t\tlocal replacement = Instance.new(className)",
    "\t\treplacement.Name = name",
    "\t\tfor _, inner in script:GetChildren() do inner.Parent = replacement end",
    "\t\tscript:Destroy()",
    "\t\treplacement.Parent = node",
    "\t\tscript = replacement",
    "\t\tcreated += 1",
    "\telseif script == nil then",
    "\t\tscript = Instance.new(className)",
    "\t\tscript.Name = name",
    "\t\tscript.Parent = node",
    "\t\tcreated += 1",
    "\tend",
    "\tif script.Source:gsub('\\r', '') ~= source then",
    "\t\tscript.Source = source",
    "\t\twritten += 1",
    "\tend",
    "\tkeep[script] = true",
    "end",
]

for instance, parts, class_name, source in entries:
    lines.append(
        "put(%r, {%s}, %r, %s)" % (instance, ", ".join(repr(p) for p in parts), class_name, long_string(source))
    )

lines += [
    "local function prune(root)",
    "\tfor _, item in root:GetDescendants() do",
    "\t\tif item:IsA('LuaSourceContainer') and not keep[item] and item.Parent ~= nil then",
    "\t\t\titem:Destroy()",
    "\t\t\tremoved += 1",
    "\t\tend",
    "\tend",
    "\tlocal changed = true",
    "\twhile changed do",
    "\t\tchanged = false",
    "\t\tfor _, item in root:GetDescendants() do",
    "\t\t\tif item:IsA('Folder') and #item:GetChildren() == 0 then",
    "\t\t\t\titem:Destroy()",
    "\t\t\t\tchanged = true",
    "\t\t\tend",
    "\t\tend",
    "\tend",
    "end",
]
for _, instance, prune in ROOTS:
    if prune:
        lines.append("prune(resolve(%r))" % instance)

lines += [
    "if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end",
    "print(('[DanceDanceStep] Synced src: %d written, %d created, %d removed'):format(written, created, removed))",
]

with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
    handle.write("\n".join(lines) + "\n")

print("%d scripts, %d bytes; running argon exec" % (len(entries), os.path.getsize(OUT)))
sys.exit(subprocess.run(["argon", "exec", OUT]).returncode)
