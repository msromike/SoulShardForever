#!/usr/bin/env python
"""tools/check.py: the pre-commit check for Soul Shards Forever.

Job:    run luacheck, run the headless tests (tests/run.lua, when present), check that
        every locale carries every key enUS has, regenerate ARCHITECTURE.md from the
        code and the file headers, and report (never fail on) how far the committed
        Libs/ are behind their upstreams. Exit 1 on any failure, 0 when all pass.
Takes:  nothing; paths resolve from this file. LUACHECK and LUA env vars override the
        tool locations (the GitHub workflow sets them; locally they are found on PATH or
        at the fallback paths below).
Writes: ARCHITECTURE.md, only when its content changed.
Touches nothing else.
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(ROOT, "SoulShardForever.toc")
MAP = os.path.join(ROOT, "ARCHITECTURE.md")

FALLBACK_LUACHECK = r"C:\bin\PortableTools\luacheck\luacheck.exe"
FALLBACK_LUA = r"C:\Users\mike\AppData\Local\Programs\Lua\bin\lua.exe"


def tool(name, fallback):
    return os.environ.get(name.upper()) or shutil.which(name) or fallback


def run(cmd, label):
    print(f"== {label}")
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    out = (proc.stdout + proc.stderr).strip()
    if out:
        print(out)
    ok = proc.returncode == 0
    print("   ok" if ok else f"   FAILED (exit {proc.returncode})")
    return ok


# ---------------------------------------------------------------- luacheck and tests

def check_luacheck():
    exe = tool("luacheck", FALLBACK_LUACHECK)
    if not os.path.exists(exe) and not shutil.which(exe):
        print(f"== luacheck\n   FAILED: luacheck not found ({exe})")
        return False
    return run([exe, ".", "--no-color", "-q"], "luacheck")


def check_libs():
    """Information only: how far the committed Libs/ are behind their upstreams. Never fails
    the check; a bump is a deliberate step (tools/sync_libs.py --apply, in-game pass, own
    commit). Offline, it says so and passes."""
    print("== libs vs upstream (information)")
    proc = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "sync_libs.py"), "--quiet"],
                          cwd=ROOT, text=True, capture_output=True)
    lines = [l for l in (proc.stdout + proc.stderr).splitlines() if "DRIFT" in l or "not fetched" in l or "NOT EMBEDDED" in l or l.startswith("libs:")]
    for l in lines:
        print("   " + l)
    return True


def check_tests():
    runner = os.path.join(ROOT, "tests", "run.lua")
    if not os.path.exists(runner):
        print("== tests\n   none yet (tests/run.lua absent)")
        return True
    exe = tool("lua", FALLBACK_LUA)
    return run([exe, "tests/run.lua"], "tests")


# ---------------------------------------------------------------- locales

KEY_RE = re.compile(r'^L\["((?:[^"\\]|\\.)*)"\]\s*=', re.M)
CODE_RE = re.compile(r'NS\.RegisterLocale\(\s*"(\w+)"')


def check_locales():
    print("== locales")
    folder = os.path.join(ROOT, "Locales")
    ref = None
    tables = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".lua") or name == "Register.lua":
            continue
        text = open(os.path.join(folder, name), encoding="utf-8").read()
        keys = set(KEY_RE.findall(text))
        codes = CODE_RE.findall(text)
        tables[name] = (keys, codes)
        if name == "enUS.lua":
            ref = keys
    ok = True
    if ref is None:
        print("   FAILED: Locales/enUS.lua not found")
        return False
    toc = open(TOC, encoding="utf-8").read()
    for name, (keys, codes) in tables.items():
        missing = sorted(ref - keys)
        extra = sorted(keys - ref)
        for k in missing:
            print(f"   {name}: missing {k!r}")
        for k in extra:
            print(f"   {name}: extra {k!r} (not in enUS)")
        if missing or extra:
            ok = False
        for code in codes:
            if code != "enUS" and f"## Notes-{code}:" not in toc:
                print(f"   toc: no Notes-{code} line for {name}")
                ok = False
    print(f"   {len(ref)} keys in enUS, {len(tables) - 1} translations" + ("" if ok else ", FAILED"))
    return ok


# ---------------------------------------------------------------- architecture map

SEND_RE = re.compile(r'SendMessage\(\s*"(SSF_\w+)"\s*(?:,\s*(.*?))?\)')
LISTEN_RE = re.compile(r'RegisterMessage\(\s*"(SSF_\w+)"')
EVENT_RE = re.compile(r'RegisterEvent\(\s*"(\w+)"')
BUCKET_RE = re.compile(r'RegisterBucketEvent\(\s*(\{[^}]*\}|"\w+")\s*,\s*([\d.]+)')

STATIC_TAIL = """## Shared state

- The AceDB profile (SSF.db.profile) is the one shared state. Any module may read it.
  Only the module that owns a rule derives it: the low mark in use is Cap:LowMark(),
  not min(profile.lowMark, cap) written again.
- NS, the addon-private namespace every file receives, carries the locale tables and
  the shared constants Core sets (SSF.SHARD_ITEM_ID, SSF.ICON on the addon object).

## Raw-frame exceptions (the only three)

- DeleteButton: a named CreateFrame, because /click resolves a global name.
- Counter: a FontString on a Blizzard bag button, because nothing in Ace draws there.
- Window: the title strip behind each option group, because AceConfigDialog hardcodes
  the InlineGroup widget.
"""


def toc_files():
    files = []
    for line in open(TOC, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        files.append(line.replace("\\", "/"))
    return files


def code_lines(text):
    """Source lines with comment-only lines dropped, so a commented-out call does not count."""
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("--"))


def header_job(path):
    """The job sentence from the header: the paragraph that starts with '<Stem>:', else the
    first paragraph after the license line."""
    stem = os.path.splitext(os.path.basename(path))[0]
    paras, cur = [], []
    for line in open(path, encoding="utf-8"):
        if not line.startswith("--"):
            break
        body = line[2:].strip()
        if body == "":
            if cur:
                paras.append(" ".join(cur))
                cur = []
        else:
            cur.append(body)
    if cur:
        paras.append(" ".join(cur))
    pick = next((p for p in paras if p.startswith(stem + ":")), None)
    if pick is None:
        pick = next((p for p in paras if not p.startswith("Soul Shards Forever (SSF)")), paras[0] if paras else "")
    if pick.startswith(stem + ":"):
        pick = pick[len(stem) + 1:].strip()
    m = re.search(r"\.(\s|$)", pick)
    if m:
        pick = pick[: m.start() + 1]
    return pick


def module_name(rel):
    return os.path.splitext(os.path.basename(rel))[0]


def build_map():
    files = toc_files()
    lua = [f for f in files if f.endswith(".lua")]
    widgets = [f for f in lua if f.startswith("Widgets/")]
    core_mods = [f for f in lua if f == "Core.lua" or f.startswith("Modules/")]
    locales = [f for f in lua if f.startswith("Locales/")]

    senders, listeners, payload, events = {}, {}, {}, {}
    for rel in core_mods:
        name = module_name(rel)
        text = code_lines(open(os.path.join(ROOT, rel), encoding="utf-8").read())
        for msg, args in SEND_RE.findall(text):
            senders.setdefault(msg, set()).add(name)
            if args and msg not in payload:
                payload[msg] = args.strip()
        for msg in LISTEN_RE.findall(text):
            listeners.setdefault(msg, set()).add(name)
        evs = []
        for ev in EVENT_RE.findall(text):
            evs.append(ev)
        for group, delay in BUCKET_RE.findall(text):
            names = re.findall(r'"(\w+)"', group)
            evs.append("bucket " + ", ".join(names) + f" ({delay}s)")
        if evs:
            events[name] = evs

    out = []
    out.append("# Soul Shards Forever: architecture map\n")
    out.append("Generated by tools/check.py from the toc order, the file headers (the job line) and the")
    out.append("code (every SendMessage, RegisterMessage, RegisterEvent and RegisterBucketEvent). Do not")
    out.append("edit by hand: fix the header or the code and rerun the check. A file or message missing")
    out.append("here is missing from the headers or the code, not from this file.\n")

    out.append("## Files, in load order\n")
    out.append("Widgets (custom AceGUI widgets, used from the options table through dialogControl):\n")
    for rel in widgets:
        out.append(f"- {rel.replace('/', chr(92))}: {header_job(os.path.join(ROOT, rel))}")
    out.append("\nCore and modules:\n")
    for rel in core_mods:
        out.append(f"- {rel.replace('/', chr(92))}: {header_job(os.path.join(ROOT, rel))}")
    out.append("\nLocales:\n")
    for rel in locales:
        if rel.endswith("Register.lua"):
            out.append(f"- {rel.replace('/', chr(92))}: {header_job(os.path.join(ROOT, rel))}")
    others = [module_name(r) for r in locales if not r.endswith("Register.lua")]
    out.append(f"- Locales\\<code>.lua: the string tables, one per locale: {', '.join(others)}.")

    out.append("\n## Messages (AceEvent, prefix SSF_)\n")
    out.append("| Message | Sender | Listeners | Payload |")
    out.append("|---|---|---|---|")
    for msg in sorted(set(senders) | set(listeners)):
        s = ", ".join(sorted(senders.get(msg, []))) or "NO SENDER"
        l = ", ".join(sorted(listeners.get(msg, []))) or "none"
        out.append(f"| {msg} | {s} | {l} | {payload.get(msg, '')} |")

    out.append("\n## Game events, by module\n")
    out.append("| Module | Events |")
    out.append("|---|---|")
    for rel in core_mods:
        name = module_name(rel)
        if name in events:
            out.append(f"| {name} | {'; '.join(events[name])} |")

    out.append("")
    out.append(STATIC_TAIL)
    return "\n".join(out)


def check_map():
    print("== architecture map")
    new = build_map()
    old = open(MAP, encoding="utf-8").read() if os.path.exists(MAP) else ""
    if new == old:
        print("   ARCHITECTURE.md unchanged")
    else:
        with open(MAP, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
        print("   ARCHITECTURE.md regenerated: CHANGED, read the diff before committing")
    return True


def main():
    results = [check_luacheck(), check_tests(), check_locales(), check_map(), check_libs()]
    ok = all(results)
    print("\nALL PASS" if ok else "\nCHECK FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
