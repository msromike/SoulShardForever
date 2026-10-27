#!/usr/bin/env python
"""tools/check.py: the pre-commit check for Soul Shards Forever.

Job:    run luacheck, run the headless tests (tests/run.lua, when present), check that
        every locale carries every key enUS has and keeps its placeholders, check that
        every literal L[...] the code looks up is a key enUS has, check that
        every color is typed in Colors.lua only (code, locales, tests and the shipped
        docs read it by name), lint every file header that carries the
        contract (Core, the modules, the widgets, the locale registrar, the tests) against
        the template in CLAUDE.md, check every header claim code can verify (Listens, Sends,
        Hooks, the modules called, the profile keys touched and Saves) against the code,
        apply the rules luacheck cannot see (no raw hooks, every widget type used, the
        shard id only in Core, every message listened for is sent, no constant typed in
        two files), regenerate ARCHITECTURE.md from the
        code and the file headers, and report (never fail on) how far the committed Libs/
        are behind their upstreams. Exit 1 on any failure, 0 when all pass.
Takes:  nothing; paths resolve from this file. LUACHECK and LUA env vars override the
        tool locations (the GitHub workflow sets them; locally they are found on PATH or
        at the fallback paths below). The tests run on Lua 5.1, the game's own: locally
        `lua51` on PATH, never a plain `lua`, which may be a later version.
Writes: ARCHITECTURE.md, only when its content changed. Through tools/sync_libs.py (the
        libs report) it also makes and removes the scratch folder tools/.sync/ and fetches
        each upstream over the network.
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
FALLBACK_LUA = r"C:\bin\PortableTools\lua51\lua5.1.exe"

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
    exe = os.environ.get("LUA") or shutil.which("lua51") or FALLBACK_LUA
    return run([exe, "tests/run.lua"], "tests")


# ---------------------------------------------------------------- locales

# one L[...] = ... line: the key in either quote style, then its value (a string in either
# quote style, or `true`: the key is the string)
LINE_RE = re.compile(
    r'^L\[(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\]\s*=\s*'
    r'(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'|(true))', re.M)
CODE_RE = re.compile(r'NS\.RegisterLocale\(\s*"(\w+)"')
PLACEHOLDER_RE = re.compile(r"%(?:(\d+)\$)?([sd])")


def locale_files():
    """Locales/<code>.lua, every string table (not the registrar)."""
    return [f"Locales/{fn}" for fn in sorted(os.listdir(os.path.join(ROOT, "Locales")))
            if fn.endswith(".lua") and fn != "Register.lua"]


def locale_table(rel):
    """key -> value string (the key itself for `true`), from one Locales/*.lua."""
    out = {}
    for k1, k2, v1, v2, is_true in LINE_RE.findall(read(rel)):
        key = k1 or k2
        out[key] = key if is_true else (v1 or v2)
    return out


def placeholders(text):
    """(positional, [(index, type)]): the %s / %d / %1$s arguments a string takes, in
    order; positional is True when every one carries an index, False when none does, None
    when they are mixed (Lua's format rejects that)."""
    found = PLACEHOLDER_RE.findall(text)
    indexed = [i for i, _ in found if i]
    if indexed and len(indexed) != len(found):
        return None, []
    if indexed:
        return True, [(int(i), t) for i, t in found]
    return False, [(n + 1, t) for n, (_, t) in enumerate(found)]


def placeholder_problems(key, value):
    """Why a translation's placeholders do not fit the key's: it may use more than the key
    (the two Bane lines are handed both spell names and English uses one), never fewer,
    never another type in a position, and never a mix of plain and positional."""
    _, want = placeholders(key)
    positional, got = placeholders(value)
    if positional is None:
        return ["mixes plain and positional placeholders"]
    out = []
    by_index = {}
    for i, t in got:
        by_index.setdefault(i, t)
    for i, t in want:
        if i not in by_index:
            out.append(f"drops argument {i} (%{t})")
        elif by_index[i] != t:
            out.append(f"argument {i} is %{by_index[i]}, the key has %{t}")
    if positional and got:
        top = max(i for i, _ in got)
        for i in range(1, top + 1):
            if i not in by_index:
                out.append(f"skips argument {i}: positions must run 1 to {top}")
    return out


def check_locales():
    """Every translation carries every key enUS has and no other, every translation's
    placeholders fit its key's (placeholder_problems), and the toc has a Notes line for
    every locale code registered."""
    print("== locales")
    ref = None
    tables = {}
    for rel in locale_files():
        name = os.path.basename(rel)
        tables[name] = (locale_table(rel), CODE_RE.findall(read(rel)))
        if name == "enUS.lua":
            ref = tables[name][0]
    if ref is None:
        print("   FAILED: Locales/enUS.lua not found")
        return False
    ok = True
    toc = read("SoulShardForever.toc")
    for name, (strings, codes) in tables.items():
        keys = set(strings)
        for k in sorted(set(ref) - keys):
            print(f"   {name}: missing {k!r}")
            ok = False
        for k in sorted(keys - set(ref)):
            print(f"   {name}: extra {k!r} (not in enUS)")
            ok = False
        for k in sorted(keys & set(ref)):
            for p in placeholder_problems(k, strings[k]):
                print(f"   {name}: {k[:40]!r}: {p}")
                ok = False
        for code in codes:
            if code != "enUS" and f"## Notes-{code}:" not in toc:
                print(f"   toc: no Notes-{code} line for {name}")
                ok = False
    print(f"   {len(ref)} keys in enUS, {len(tables) - 1} translations" + ("" if ok else ", FAILED"))
    return ok


# L["..."] or L['...'] typed in code: the key as written, either quote style
CODE_KEY_RE = re.compile(r'\bL\[\s*(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\s*\]')


def unescape(key):
    r"""A key as Lua reads it, for \" \' and \\: so a key typed in one quote style matches
    the same key typed in the other."""
    return re.sub(r"\\([\"'\\])", r"\1", key)


def check_code_keys():
    """Every key Core, the modules and the widgets look up as a literal L[...] is a key enUS
    has. AceLocale answers a missing key with an error once per session and the key itself
    as the text, and check_locales only compares the locale files with each other, so a
    key renamed in the locales but not in the code passes everything else. A key built at
    runtime (L[name]) is not a literal and is not checked."""
    print("== code keys")
    ref = {unescape(k) for k in locale_table("Locales/enUS.lua")}
    ok = True
    count = 0
    for rel in [f for f in lua_files() if not f.startswith("tests/") and f != "Locales/Register.lua"]:
        for n, line in enumerate(read(rel).splitlines(), 1):
            if line.lstrip().startswith("--"):
                continue
            for k1, k2 in CODE_KEY_RE.findall(line):
                count += 1
                key = unescape(k1 or k2)
                if key not in ref:
                    print(f"   {rel}:{n}: L[{key[:50]!r}] is not a key in enUS")
                    ok = False
    print(f"   {count} lookups, " + ("ok" if ok else "FAILED"))
    return ok


# ---------------------------------------------------------------- colors

COLORS = "Modules/Colors.lua"
COLOR_DEF_RE = re.compile(r"\bColor\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)")
ESCAPE_RE = re.compile(r"\|c[0-9a-fA-F]{8}")
HEX_RE = re.compile(r"(?<![0-9a-zA-Z])[0-9a-fA-F]{6}(?![0-9a-zA-Z])")
NUM = r"\d+(?:\.\d+)?"
TRIPLE_RE = re.compile(rf"(?<![\w.])({NUM})\s*,\s*({NUM})\s*,\s*({NUM})(?![\w.])")
COLOR_CALL_RE = re.compile(rf"(?:Color|ColorTexture|VertexColor|TextColor|BackdropColor|BackdropBorderColor)\(\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}")
COLOR_TABLE_RE = re.compile(rf"\{{\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}\s*(?:,\s*{NUM}\s*)?\}}")


def known_colors():
    """The colors Colors.lua defines, as (r, g, b) tuples and as the hex Colors derives."""
    triples = {tuple(float(x) for x in m) for m in COLOR_DEF_RE.findall(read(COLORS))}
    hexes = {"%02x%02x%02x" % tuple(int(v * 255 + 0.5) for v in t) for t in triples}
    return triples, hexes


def color_files():
    """Every file a color could be typed into: the Lua that carries a header, every locale,
    and the shipped docs (README, CHANGELOG, media/*.md; .docs/ is local work and not
    walked). Colors.lua itself is the home and is left out."""
    out = [f for f in lua_files() if f != COLORS] + locale_files()
    out += [fn for fn in ("README.md", "CHANGELOG.md") if os.path.exists(os.path.join(ROOT, fn))]
    out += [f"media/{fn}" for fn in sorted(os.listdir(os.path.join(ROOT, "media"))) if fn.endswith(".md")]
    return out


def check_colors():
    """Every color lives in Colors.lua and is read by name. Outside it, in code, locales,
    tests and the shipped docs: no |cRRGGBBAA escape code (Colors:Paint makes them), no hex
    of a color Colors defines; in code lines, no r, g, b that equals one Colors defines, no
    color-setting call with its r, g, b typed as numbers, and no bare table of three or
    four numbers (a color's shape). An alpha stays the caller's own."""
    print("== colors")
    if not os.path.exists(os.path.join(ROOT, COLORS)):
        print(f"   FAILED: {COLORS} not found")
        return False
    triples, hexes = known_colors()
    if not triples:
        print(f"   FAILED: no Color(r, g, b) definitions found in {COLORS}")
        return False
    ok = True

    def report(rel, line_no, what):
        nonlocal ok
        print(f"   {rel}:{line_no}: {what}")
        ok = False

    for rel in color_files():
        lua = rel.endswith(".lua")
        for n, line in enumerate(read(rel).splitlines(), 1):
            if ESCAPE_RE.search(line):
                report(rel, n, "a color escape code is typed here; paint the text through Colors")
            for h in HEX_RE.findall(line):
                if h.lower() in hexes:
                    report(rel, n, f"the hex {h} is a Colors value typed here; read it by name")
            if not lua or line.lstrip().startswith("--"):
                continue
            for m in TRIPLE_RE.findall(line):
                if tuple(float(x) for x in m) in triples:
                    report(rel, n, f"{', '.join(m)} is a Colors value typed as numbers; read it by name")
            if COLOR_CALL_RE.search(line):
                report(rel, n, "a color is typed as numbers in a color call; read it from Colors")
            if COLOR_TABLE_RE.search(line):
                report(rel, n, "a table of three or four numbers: a color belongs in Colors")
    print("   ok" if ok else "   FAILED")
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


# ---------------------------------------------------------------- header truth

MSG_RE = re.compile(r"\bSSF_[A-Z_]+\b")
GAME_EVENT_RE = re.compile(r"\b(?!SSF_)[A-Z]+(?:_[A-Z]+)+\b")
GETMODULE_RE = re.compile(r'GetModule\(\s*"(\w+)"\s*\)')
PROFILE_ALIAS_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*(?:SSF|self)\.db\.profile\s*(?:--.*)?$", re.M)
PROFILE_SUB_ALIAS_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*(?:SSF|self)\.db\.profile\.(\w+)\s*(?:--.*)?$", re.M)
HOOK_RE = re.compile(r':(?:Secure|Raw)?Hook(?:Script)?\(\s*[^,()]+,\s*"(\w+)"')
PROFILE_KEY_IN_HEADER_RE = re.compile(r"\bprofile\.(\w+)")


def header_fields(rel):
    """Field name -> its text: the field's own line plus the continuation lines up to the
    next field or the end of the header."""
    field_re = re.compile(r"^(" + "|".join(re.escape(f) for f in FIELDS) + r"):\s*")
    fields, cur = {}, None
    for body in header_lines(rel):
        m = field_re.match(body)
        if m:
            cur = m.group(1)
            fields[cur] = body[m.end():]
        elif cur and body:
            fields[cur] += " " + body
    return fields


def profile_refs(text):
    """(reads, writes): the profile keys the code touches, through SSF.db.profile or a
    local alias of it. A write is `<profile>.<key>... =` (not ==)."""
    aliases = set(PROFILE_ALIAS_RE.findall(text)) | {"SSF.db.profile", "self.db.profile"}
    # `Migrate(self.db.profile)` with `local function Migrate(p)`: the parameter is an alias
    for fn in re.findall(r"\b(\w+)\(\s*(?:SSF|self)\.db\.profile\s*\)", text):
        m = re.search(r"function\s+" + re.escape(fn) + r"\(\s*(\w+)\s*\)", text)
        if m:
            aliases.add(m.group(1))
    base = "(?:" + "|".join(re.escape(a) for a in sorted(aliases, key=len, reverse=True)) + r")"
    reads = set(re.findall(r"\b" + base + r"\.(\w+)", text))
    writes = set(re.findall(r"\b" + base + r"\.(\w+)(?:\.\w+|\[[^\]]*\])*\s*=(?!=)", text))
    # `local window = SSF.db.profile.window` then `window.top, window.left = ...`: a line that
    # assigns through such a sub-table alias writes that key
    for var, key in PROFILE_SUB_ALIAS_RE.findall(text):
        for line in text.splitlines():
            if re.match(r"\s*" + re.escape(var) + r"\.", line) and re.search(r"=(?!=)", line):
                writes.add(key)
    return reads, writes


def check_header_truth():
    """Every claim a header makes that code can verify: Listens names exactly the messages
    and events the file registers; Sends names exactly the messages it sends; every method
    hooked on an object (HOOK_RE: a target, then the quoted name) is named under Hooks; every
    module it calls and every profile key it touches is named somewhere in the header; every
    profile key it writes is named under Saves, and no `profile.<key>` written in Saves is
    one the code does not write (a bare key name there is not checked)."""
    print("== header truth")
    ok = True
    code_files = [f for f in lua_files() if not f.startswith("tests/")]
    for rel in code_files:
        raw = read(rel)
        text = code_lines(raw)
        header = " ".join(header_lines(rel))
        fields = header_fields(rel)
        stem = module_name(rel)
        problems = []

        def word_in(name, where):
            return re.search(r"\b" + re.escape(name) + r"\b", where) is not None

        # Listens: messages and game events
        listens = fields.get("Listens", "")
        hdr_msgs = set(MSG_RE.findall(listens))
        code_msgs = set(LISTEN_RE.findall(text))
        hdr_events = set(GAME_EVENT_RE.findall(listens))
        code_events = set(EVENT_RE.findall(text))
        for group, _ in BUCKET_RE.findall(text):
            code_events |= set(re.findall(r'"(\w+)"', group))
        for m in sorted(hdr_msgs - code_msgs):
            problems.append(f"Listens names {m}, the code never registers it")
        for m in sorted(code_msgs - hdr_msgs):
            problems.append(f"the code registers {m}, Listens does not name it")
        for e in sorted(hdr_events - code_events):
            problems.append(f"Listens names {e}, the code never registers it")
        for e in sorted(code_events - hdr_events):
            problems.append(f"the code registers {e}, Listens does not name it")

        # Sends
        hdr_sends = set(MSG_RE.findall(fields.get("Sends", "")))
        code_sends = {m for m, _ in SEND_RE.findall(text)}
        for m in sorted(hdr_sends - code_sends):
            problems.append(f"Sends names {m}, the code never sends it")
        for m in sorted(code_sends - hdr_sends):
            problems.append(f"the code sends {m}, Sends does not name it")

        # Hooks: every method hooked on an object, named under Hooks
        hooks = fields.get("Hooks", "")
        for name in sorted(set(HOOK_RE.findall(text))):
            if not word_in(name, hooks):
                problems.append(f"the code hooks {name}, Hooks does not name it")

        # modules it calls: named somewhere in the header
        for name in sorted(set(GETMODULE_RE.findall(text))):
            if name != stem and not word_in(name, header):
                problems.append(f"the code calls GetModule(\"{name}\"), the header never names {name}")

        # profile keys: touched -> named in the header; written -> named under Saves; Saves -> written
        reads, writes = profile_refs(text)
        for key in sorted(reads | writes):
            if not word_in(key, header):
                problems.append(f"the code touches profile.{key}, the header never names it")
        saves = fields.get("Saves", "")
        for key in sorted(writes):
            if not word_in(key, saves):
                problems.append(f"the code writes profile.{key}, Saves does not name it")
        for key in sorted(set(PROFILE_KEY_IN_HEADER_RE.findall(saves)) - writes):
            problems.append(f"Saves names profile.{key}, the code never writes it")

        for p in problems:
            print(f"   {rel}: {p}")
            ok = False
    print("   ok" if ok else "   FAILED")
    return ok


# ---------------------------------------------------------------- rules luacheck cannot see

# `local NAME = <literal>`: a number, a string or a table on one line
CONST_RE = re.compile(r'^local\s+([A-Z][A-Z0-9_]*)\s*=\s*(-?\d[\d.]*|"[^"]*"|\{[^}]*\})\s*(?:--.*)?$', re.M)


def check_rules():
    """No raw hooks (AceHook, or named under Exceptions); every widget type registered is
    used; the shard id is typed in Core only (the locale files' comments included); every
    message a module listens for is sent by some module; and the same ALL_CAPS local with
    the same literal in two files is one value with two homes (or two things that need two
    names)."""
    print("== rules")
    ok = True
    code_files = [f for f in lua_files() if not f.startswith("tests/")]
    texts = {rel: read(rel) for rel in code_files}
    # raw hooks: AceHook or nothing, unless the header names the raw call (anywhere in it)
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
    # the shard item id lives in Core (the stub knows it too, before Core loads); the locale
    # files are walked as well, comments included
    for rel, text in list(texts.items()) + [(rel, read(rel)) for rel in locale_files()]:
        if rel != "Core.lua" and re.search(r"\b6265\b", text):
            print(f"   {rel}: the shard id is typed here; read SSF.SHARD_ITEM_ID")
            ok = False
    # a message a module listens for is sent by some module: a misspelt name never arrives
    sent = {m for text in texts.values() for m, _ in SEND_RE.findall(code_lines(text))}
    for rel, text in texts.items():
        for m in sorted(set(LISTEN_RE.findall(code_lines(text))) - sent):
            print(f"   {rel}: listens for {m}, nothing sends it")
            ok = False
    # one value, one home: the same ALL_CAPS local with the same literal in two files
    homes = {}
    for rel, text in texts.items():
        for name, value in CONST_RE.findall(code_lines(text)):
            homes.setdefault((name, re.sub(r"\s+", "", value)), []).append(rel)
    for (name, _), files in sorted(homes.items()):
        if len(files) > 1:
            print(f"   {name} is typed in {' and '.join(files)}: one home, or two names if they are two things")
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
its owner derives a rule from it), and the documented exceptions (a raw named frame, a
raw FontString, a raw title strip) and the library-internals rule are listed there with
their reasons. NS is the addon-private table Core and the locale registrar share.
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
    out.append("code of Core and the modules (every SendMessage, RegisterMessage, RegisterEvent and")
    out.append("RegisterBucketEvent there; the widgets send and register none). Do not")
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
    results = [check_luacheck(), check_tests(), check_locales(), check_code_keys(), check_colors(), check_headers(),
               check_header_truth(), check_rules(), check_map(), check_libs()]
    ok = all(results)
    print("\nALL PASS" if ok else "\nCHECK FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
