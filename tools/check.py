#!/usr/bin/env python
"""tools/check.py: the pre-commit check for Soul Shards Forever.

Job:    run luacheck, run the headless tests (tests/run.lua, when present), check that
        every locale carries every key enUS has, lint every file header against the
        template in CLAUDE.md, apply the rules luacheck cannot see (no raw hooks, every
        widget type used, the shard id only in Core), regenerate ARCHITECTURE.md from the
        code and the file headers, and report (never fail on) how far the committed Libs/
        are behind their upstreams. Exit 1 on any failure, 0 when all pass.
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

# the header template (CLAUDE.md), in order
FIELDS = ["Public", "Listens", "Hooks", "Sends", "Lib internals", "Reads", "Saves", "Exceptions"]
CLOSING = "Touches nothing else."


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


def read(rel):
    return open(os.path.join(ROOT, rel), encoding="utf-8").read()


def lua_files():
    """Core, every module and widget, the locale registrar, and the tests: the files that
    carry a header contract."""
    out = ["Core.lua", "Locales/Register.lua"]
    for folder in ("Modules", "Widgets", "tests"):
        for fn in sorted(os.listdir(os.path.join(ROOT, folder))):
            if fn.endswith(".lua"):
                out.append(f"{folder}/{fn}")
    return out


# ---------------------------------------------------------------- luacheck, libs, tests

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
    for l in (proc.stdout + proc.stderr).splitlines():
        if "DRIFT" in l or "not fetched" in l or "NOT EMBEDDED" in l or l.startswith("libs:"):
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
        text = read(f"Locales/{name}")
        tables[name] = (set(KEY_RE.findall(text)), CODE_RE.findall(text))
        if name == "enUS.lua":
            ref = tables[name][0]
    if ref is None:
        print("   FAILED: Locales/enUS.lua not found")
        return False
    ok = True
    toc = read("SoulShardForever.toc")
    for name, (keys, codes) in tables.items():
        for k in sorted(ref - keys):
            print(f"   {name}: missing {k!r}")
            ok = False
        for k in sorted(keys - ref):
            print(f"   {name}: extra {k!r} (not in enUS)")
            ok = False
        for code in codes:
            if code != "enUS" and f"## Notes-{code}:" not in toc:
                print(f"   toc: no Notes-{code} line for {name}")
                ok = False
    print(f"   {len(ref)} keys in enUS, {len(tables) - 1} translations" + ("" if ok else ", FAILED"))
    return ok


# ---------------------------------------------------------------- headers

def header_lines(rel):
    """The leading comment block, without the '-- ' prefixes."""
    out = []
    for line in read(rel).splitlines():
        if not line.startswith("--"):
            break
        out.append(line[2:].strip())
    return out


def paragraphs(lines):
    paras, cur = [], []
    for body in lines:
        if body == "":
            if cur:
                paras.append(" ".join(cur))
                cur = []
        else:
            cur.append(body)
    if cur:
        paras.append(" ".join(cur))
    return paras


def check_headers():
    """Every header: a paragraph that starts with '<Name>:', the template fields in template
    order, and the closing line last."""
    print("== headers")
    ok = True
    field_re = re.compile(r"^(" + "|".join(re.escape(f) for f in FIELDS) + r"):")
    for rel in lua_files():
        stem = os.path.splitext(os.path.basename(rel))[0]
        lines = header_lines(rel)
        problems = []
        if not any(p.startswith(stem + ":") for p in paragraphs(lines)):
            problems.append(f"no paragraph starts with '{stem}:'")
        seen = -1
        for body in lines:
            m = field_re.match(body)
            if m:
                idx = FIELDS.index(m.group(1))
                if idx < seen:
                    problems.append(f"field '{m.group(1)}' out of template order")
                seen = max(seen, idx)
        if not lines or not lines[-1].endswith(CLOSING):
            problems.append(f"last header line is not '{CLOSING}'")
        for p in problems:
            print(f"   {rel}: {p}")
            ok = False
    print("   ok" if ok else "   FAILED")
    return ok


# ---------------------------------------------------------------- rules luacheck cannot see

def check_rules():
    print("== rules")
    ok = True
    code_files = [f for f in lua_files() if not f.startswith("tests/")]
    texts = {rel: read(rel) for rel in code_files}
    # raw hooks: AceHook or nothing, unless the header names the raw call as an exception
    for rel, text in texts.items():
        header = "\n".join(header_lines(rel))
        for m in re.finditer(r"hooksecurefunc\(|:HookScript\(", text):
            if m.group(0)[:-1] not in header:
                line = text[: m.start()].count("\n") + 1
                print(f"   {rel}:{line}: raw hook {m.group(0)[:-1]} (use AceHook, or name it under Exceptions)")
                ok = False
    # every widget type registered is used somewhere
    used = "\n".join(texts.values())
    for rel, text in texts.items():
        for name in re.findall(r'RegisterWidgetType\(\s*"(\w+)"', text):
            if not re.search(r'dialogControl\s*=\s*"' + name + r'"|Create\(\s*"' + name + r'"', used):
                print(f"   {rel}: widget type {name} is registered but nothing uses it")
                ok = False
    # the shard item id lives in Core (the stub knows it too, before Core loads)
    for rel, text in texts.items():
        if rel != "Core.lua" and re.search(r"\b6265\b", text):
            print(f"   {rel}: the shard id is typed here; read SSF.SHARD_ITEM_ID")
            ok = False
    print("   ok" if ok else "   FAILED")
    return ok


# ---------------------------------------------------------------- architecture map

SEND_RE = re.compile(r'SendMessage\(\s*"(SSF_\w+)"\s*(?:,\s*(.*?))?\)')
LISTEN_RE = re.compile(r'RegisterMessage\(\s*"(SSF_\w+)"')
EVENT_RE = re.compile(r'RegisterEvent\(\s*"(\w+)"')
BUCKET_RE = re.compile(r'RegisterBucketEvent\(\s*(\{[^}]*\}|"\w+")\s*,\s*([\d.]+)')

STATIC_TAIL = """## Shared state and exceptions

See CLAUDE.md: the AceDB profile is the one shared state (any module may read it, only
its owner derives a rule from it), NS is the addon-private namespace, and the three raw
frames and the library-internals rule are listed there with their reasons.
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


def header_job(rel):
    """The job sentence from the header: the paragraph that starts with '<Stem>:'."""
    stem = os.path.splitext(os.path.basename(rel))[0]
    paras = paragraphs(header_lines(rel))
    pick = next((p for p in paras if p.startswith(stem + ":")), "")
    pick = pick[len(stem) + 1:].strip()
    m = re.search(r"\.(\s|$)", pick)
    return pick[: m.start() + 1] if m else pick


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
        text = code_lines(read(rel))
        for msg, args in SEND_RE.findall(text):
            senders.setdefault(msg, set()).add(name)
            args = args.strip()
            if args.count(",") >= payload.get(msg, "").count(",") and args:
                payload[msg] = args  # the send with the most arguments describes the payload
        for msg in LISTEN_RE.findall(text):
            listeners.setdefault(msg, set()).add(name)
        evs = list(EVENT_RE.findall(text))
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
    out.append("Widgets (custom AceGUI widgets, used from the options table through dialogControl, or")
    out.append("created by Window and by each other):\n")
    for rel in widgets:
        out.append(f"- {rel.replace('/', chr(92))}: {header_job(rel)}")
    out.append("\nCore and modules:\n")
    for rel in core_mods:
        out.append(f"- {rel.replace('/', chr(92))}: {header_job(rel)}")
    out.append("\nLocales:\n")
    for rel in locales:
        if rel.endswith("Register.lua"):
            out.append(f"- {rel.replace('/', chr(92))}: {header_job(rel)}")
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
    results = [check_luacheck(), check_tests(), check_locales(), check_headers(), check_rules(),
               check_map(), check_libs()]
    ok = all(results)
    print("\nALL PASS" if ok else "\nCHECK FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
