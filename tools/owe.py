"""Make SSF's welcome note or its announcement show again for one character.

A dev tool for testing: it edits SSF's saved settings on disk so the next login treats the
note as not yet seen. Run it while that character is logged out; the game writes the file
at logout and would undo the edit.

    python tools/owe.py                              list the characters and their flags
    python tools/owe.py welcome "Name Surname"       the welcome note shows at next login
    python tools/owe.py news "Name Surname"          the announcement shows at next login
    python tools/owe.py both "Name Surname"          both
    python tools/owe.py both "Name Surname" --file <path to SoulShardForever.lua>

Both flags have one shape (Welcome's Owed, News's Owed): a number once the note was
dismissed (the version of the note the character saw), anything else while it is owed. So
"owe" is the same edit for either: the flag's line is set to false.

The saved file is found from where the addon sits:
<game>/Interface/AddOns/SoulShardForever -> <game>/WTF/Account/*/SavedVariables/
SoulShardForever.lua; with more than one account, the file written last is used. No
account or character name lives in this script.

Reads and writes only that one file. Never packaged (.pkgmeta ignores tools/).
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.dirname(os.path.dirname(os.path.dirname(ROOT)))
SAVED_GLOB = os.path.join(GAME, "WTF", "Account", "*", "SavedVariables", "SoulShardForever.lua")

# what to owe -> the profile key that records it was seen
FLAGS = {"welcome": "welcomed", "news": "newsSeen"}
OWED = b"false"

HEADER_RE = re.compile(rb'^\["(.+)"\] = \{\s*$')        # ["Name"] = {
VALUE_RE = re.compile(rb'^\["(\w+)"\] = (.*?),?\s*$')   # ["key"] = value,


def saved_file(explicit):
    if explicit:
        return explicit
    found = sorted(glob.glob(SAVED_GLOB), key=os.path.getmtime)
    if not found:
        sys.exit("no saved file found at " + SAVED_GLOB)
    return found[-1]


def profiles(lines):
    """Each profile's name -> (first line index, last line index, {key: line index}) for
    the keys directly inside it. The file is the game's own writer's: one entry a line, a
    table opens on a line ending in { and closes on a line starting with }."""
    out, depth, inside, current = {}, 0, None, None
    for i, line in enumerate(lines):
        text = line.strip()
        header = HEADER_RE.match(text)
        if header and depth == 1 and header.group(1) == b"profiles":
            inside = depth + 1
        elif header and inside is not None and depth == inside:
            current = header.group(1).decode("utf-8")
            out[current] = [i, None, {}]
        elif current and depth == inside + 1:
            value = VALUE_RE.match(text)
            if value and not text.endswith(b"{"):
                out[current][2][value.group(1).decode()] = i
        if text.endswith(b"{"):
            depth += 1
        elif text.startswith(b"}"):
            depth -= 1
            if current and depth == inside:
                out[current][1] = i
                current = None
            elif inside is not None and depth < inside:
                inside = None
    return out


def value_of(lines, index):
    return VALUE_RE.match(lines[index].strip()).group(2).decode("utf-8")


def game_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow*"], capture_output=True,
                             text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return "wow" in out.lower()


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    explicit = argv[argv.index("--file") + 1] if "--file" in argv else None
    if explicit in args:
        args.remove(explicit)
    path = saved_file(explicit)
    with open(path, "rb") as handle:
        lines = handle.read().splitlines(keepends=True)
    found = profiles(lines)

    if not args:
        print(path)
        for name, (_, _, keys) in found.items():
            shown = ", ".join("%s: %s" % (what, value_of(lines, keys[key]) if key in keys else "owed")
                              for what, key in FLAGS.items())
            print("  %-28s %s" % (name, shown))
        return

    if len(args) != 2 or args[0] not in list(FLAGS) + ["both"]:
        sys.exit(__doc__)
    what, name = args
    if name not in found:
        sys.exit('no character "%s" in %s; run with no arguments for the list' % (name, path))
    keys = found[name][2]
    changed = False
    for flag in (FLAGS if what == "both" else [what]):
        key = FLAGS[flag]
        if key not in keys:
            print("%s: already owed (no %s saved)" % (flag, key))
            continue
        index = keys[key]
        was = value_of(lines, index)
        if was.encode() == OWED:
            print("%s: already owed" % flag)
            continue
        ending = lines[index][len(lines[index].rstrip(b"\r\n")):]
        lines[index] = b'["%s"] = %s,' % (key.encode(), OWED) + ending
        changed = True
        print("%s: %s was %s, now owed" % (flag, key, was))
    if changed:
        with open(path, "wb") as handle:
            handle.writelines(lines)
        print("saved: " + path)
    if game_running():
        print("NOTE: the game is running. The edit only holds if this character is logged out.")


if __name__ == "__main__":
    main(sys.argv[1:])
