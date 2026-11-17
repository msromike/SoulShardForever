#!/usr/bin/env python
"""tools/check.py: the pre-commit check for Soul Shards Forever.

Job:    run luacheck, run the headless tests (tests/run.lua, when present), open the real
        options window outside the game (tests/window.lua) and compare its controls with
        tests/window_controls.txt (--accept-window rewrites that file), check that
        every locale carries every key enUS has and keeps its placeholders, check that
        every literal L[...] the code looks up is a key enUS has, check that
        every color is typed in Colors.lua only (code, locales, tests and the shipped
        docs read it by name), lint every file header that carries the
        contract (Core, the modules, the widgets, the locale registrar, the tests) against
        the template in CLAUDE.md, check every header claim code can verify (Listens, Sends,
        the modules called, the profile keys touched and Saves) against the code,
        hold Hooks to the hooks the code makes, both ways, allow a raw hook only one at a
        time under Exceptions, and flag a script set on a frame the file did not create,
        compare the toc with the files on disk both ways, spelling and case included,
        hold Bindings.xml to the frames, methods and labels it uses,
        count the documented exceptions and the Lib internals fields in the headers against
        the two lists in CLAUDE.md, both ways,
        check that every header's "Acts on" names what the file does to the game (the ACTS
        list: items moved or deleted, macros made, sounds, Blizzard frames, globals),
        check that Public is the truth (every use of another module names something that
        module defines and lists under Public, every name under Public is defined, the
        tests' stand-in modules included),
        apply the rules luacheck cannot see (every widget type used, the
        shard id only in Core, every message listened for is sent, no constant typed in
        two files), check every Blizzard name the code uses against the client's own UI
        source (no deprecated shim, every C_ call in the API docs), regenerate
        ARCHITECTURE.md from the code and the file headers, and report (never fail on) how
        far the committed Libs/ are behind their upstreams. Exit 1 on any failure, 0 when
        all pass.
Takes:  nothing; paths resolve from this file. LUACHECK and LUA env vars override the
        tool locations (the GitHub workflow sets them; locally they are found on PATH or
        at the fallback paths below). The tests run on Lua 5.1, the game's own: locally
        `lua51` on PATH, never a plain `lua`, which may be a later version.
Writes: ARCHITECTURE.md, only when its content changed. tests/window_controls.txt, only
        with --accept-window. tools/.wowui/ (gitignored): a
        shallow clone of the wow-ui-source mirror's forever branch, made on the first run
        and pulled on every run after. Through tools/sync_libs.py (the libs report) it also
        keeps a copy of each library's upstream in tools/.sync/ (gitignored), downloaded
        again only when the upstream's version changed.
Touches nothing else.
"""
import bisect
import os
import re
import shutil
import subprocess
import sys
from xml.etree import ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(ROOT, "SoulShardForever.toc")
MAP = os.path.join(ROOT, "ARCHITECTURE.md")

FALLBACK_LUACHECK = r"C:\bin\PortableTools\luacheck\luacheck.exe"
FALLBACK_LUA = r"C:\bin\PortableTools\lua51\lua5.1.exe"

# the header template (CLAUDE.md), in order
FIELDS = ["Public", "Listens", "Hooks", "Sends", "Lib internals", "Game internals", "Reads", "Saves", "Acts on",
          "Exceptions"]
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
    """Core, every module and widget, the locale registrar, the announcement (News/News.lua)
    and the tests: the files that carry a header contract."""
    out = ["Core.lua", "Locales/Register.lua", "News/News.lua"]
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


# ---------------------------------------------------------------- Blizzard API

WOWUI_REPO = "https://github.com/Gethe/wow-ui-source.git"
WOWUI_BRANCH = "forever"
WOWUI = os.path.join(ROOT, "tools", ".wowui")
WOWUI_ADDONS = os.path.join(WOWUI, "Interface", "AddOns")
WOWUI_DOCS = os.path.join(WOWUI_ADDONS, "Blizzard_APIDocumentationGenerated")
NS_CALL_RE = re.compile(r"\b(C_\w+)\.(\w+)\s*\(")
LUACHECKRC_GLOBALS_RE = re.compile(r"read_globals\s*=\s*\{(.*?)\n\}", re.S)
LUA_STRING_RE = re.compile(r'"(\w+)"')
NOT_BLIZZARD = {"LibStub"}
OFFLINE = "--offline"  # pass the Blizzard API step when there is no UI source to check against


def wowui_build():
    """Bring tools/.wowui to the mirror's current forever build and say which it is: a
    shallow clone of the branch if absent, a pull if present. Offline, the copy on disk is
    used and the message says so; with no copy at all, None."""
    git = shutil.which("git")
    if not git:
        return None, "git not found"
    if not os.path.isdir(os.path.join(WOWUI, ".git")):
        proc = subprocess.run([git, "clone", "--quiet", "--depth", "1", "--single-branch", "--branch",
                               WOWUI_BRANCH, WOWUI_REPO, WOWUI], text=True, capture_output=True)
        if proc.returncode != 0:
            return None, "clone failed: " + (proc.stderr.strip().splitlines() or ["?"])[-1]
        note = "cloned"
    else:
        proc = subprocess.run([git, "-C", WOWUI, "pull", "--quiet", "--ff-only"], text=True, capture_output=True)
        note = "current" if proc.returncode == 0 else "offline, using the copy on disk"
    build = subprocess.run([git, "-C", WOWUI, "log", "-1", "--format=%s"], text=True, capture_output=True).stdout.strip()
    return build, note


def blizzard_names():
    """(globals, namespaced): every Blizzard global the code may read (.luacheckrc's
    read_globals, the libraries left out) and every C_<namespace>.<function> call in Core,
    the modules and the widgets, as {(namespace, function): [file:line, ...]}."""
    m = LUACHECKRC_GLOBALS_RE.search(read(".luacheckrc"))
    globs = [n for n in LUA_STRING_RE.findall(m.group(1)) if n not in NOT_BLIZZARD] if m else []
    namespaced = {}
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        for n, line in enumerate(code_lines(read(rel)).splitlines(), 1):
            for ns, fn in NS_CALL_RE.findall(line):
                namespaced.setdefault((ns, fn), []).append(f"{rel}:{n}")
    return globs, namespaced


# Globals the code calls that this client has and its published UI source never mentions:
# functions built into the client that Blizzard's own Lua does not happen to use and its
# API docs leave out. Each needs a proof from the game, since no file can give one.
KNOWN_GLOBALS = {
    "GetMacroIndexByName": "type() printed 'function' in game on build 1.60.1",
    "PlaySoundFile": "type() printed 'function' in game on build 1.60.1",
    "MuteSoundFile": "type() printed 'function' in game on build 1.60.1",
    "UnmuteSoundFile": "type() printed 'function' in game on build 1.60.1",
}
REACHES = "tools/blizzard_reaches.txt"
WOWUI_FOUND = os.path.join(ROOT, "tools", ".wowui_found.txt")
NOT_FRAMES = {"bit", "LibStub"}  # globals whose members are Lua's or a library's, not Blizzard's UI
GAME_INTERNALS = "Game internals"
DOC_ENTRY_RE = re.compile(r'\bName\s*=\s*"(\w+)",\s*\n\s*Type\s*=\s*"(\w+)"')
DOC_GLOBAL_KINDS = {"Enum": "Enumeration", "Constants": "Constants"}  # their members, by doc entry kind
CREATE_FRAME_RE = re.compile(r'(?<![\w.:])CreateFrame\s*\(')


def call_args(text, start):
    """The top-level arguments of the call whose "(" is at text[start - 1], as source
    strings, and the index just past its ")"; None when the call is not closed."""
    args, depth, quote, i, begin = [], 0, None, start, start
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                args.append(text[begin:i].strip())
                return args, i + 1
            depth -= 1
        elif c == "," and depth == 0:
            args.append(text[begin:i].strip())
            begin = i + 1
        i += 1
    return None


def frame_templates(lines):
    """[(line, templates or None)] for every CreateFrame call in the code lines: the
    template names of its fourth argument, [] with none, None when the fourth argument is
    not a quoted string (a template the check cannot read)."""
    text = "\n".join(code for _, code in lines)
    starts = [0]
    for _, code in lines:
        starts.append(starts[-1] + len(code) + 1)
    out = []
    for m in CREATE_FRAME_RE.finditer(text):
        parsed = call_args(text, m.end())
        n = lines[bisect.bisect_right(starts, m.start()) - 1][0]
        if not parsed:
            continue
        args = parsed[0]
        if len(args) < 4 or args[3] in ("", "nil"):
            out.append((n, []))
        else:
            s = re.fullmatch(r'"([^"]*)"|\'([^\']*)\'', args[3])
            out.append((n, re.findall(r"\w+", s.group(1) or s.group(2) or "") if s else None))
    return out


def ui_source_has(words, build):
    """word -> True when it appears as a whole word anywhere in the client's UI source.
    One `git grep` over tools/.wowui for the words not yet known, remembered in
    tools/.wowui_found.txt (gitignored) for as long as the build stays the same."""
    known = {}
    if os.path.exists(WOWUI_FOUND):
        lines = open(WOWUI_FOUND, encoding="utf-8").read().splitlines()
        if lines and lines[0] == build:
            known = {w: flag == "1" for w, flag in (l.split() for l in lines[1:] if l.strip())}
    ask = sorted(set(words) - set(known))
    if ask:
        cmd = ["git", "-C", WOWUI, "grep", "-I", "-w", "-o", "-h", "-F"]
        for w in ask:
            cmd += ["-e", w]
        proc = subprocess.run(cmd + ["--", "Interface"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        seen = set(proc.stdout.split())
        for w in ask:
            known[w] = w in seen
        with open(WOWUI_FOUND, "w", encoding="utf-8", newline="\n") as f:
            f.write(build + "\n" + "".join(f"{w} {int(v)}\n" for w, v in sorted(known.items())))
    return known


WOWUI_FILES = os.path.join(ROOT, "tools", ".wowui_files.txt")


def ui_source_files(words, build):
    """word -> the set of UI source files it appears in as a whole word. One `git grep`
    for the words not yet known, remembered in tools/.wowui_files.txt (gitignored) for as
    long as the build stays the same."""
    known = {}
    if os.path.exists(WOWUI_FILES):
        lines = open(WOWUI_FILES, encoding="utf-8").read().splitlines()
        if lines and lines[0] == build:
            for l in lines[1:]:
                w, _, paths = l.partition(" ")
                known[w] = set(paths.split()) if paths else set()
    ask = sorted(set(words) - set(known))
    if ask:
        cmd = ["git", "-C", WOWUI, "grep", "-I", "-w", "-o", "-F"]
        for w in ask:
            cmd += ["-e", w]
        proc = subprocess.run(cmd + ["--", "Interface"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        for w in ask:
            known[w] = set()
        for line in proc.stdout.splitlines():
            path, _, word = line.rpartition(":")
            if word in known:
                known[word].add(path)
        with open(WOWUI_FILES, "w", encoding="utf-8", newline="\n") as f:
            f.write(build + "\n" + "".join(f"{w} {' '.join(sorted(v))}\n" for w, v in sorted(known.items())))
    return known


def reach_parts(name):
    """MacroFrame.MacroSelector -> ["MacroFrame", "MacroSelector"]"""
    return re.split(r"[:.]", name)


def read_reaches():
    """([(name, last segment, file, built)], problems) from tools/blizzard_reaches.txt: one
    reach per line, `Name  File  [built]`. built: the code makes the name at run time (a
    bag button's name from its number), so the name is not looked for in the code."""
    rows, problems = [], []
    for n, raw in enumerate(read(REACHES).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 2)
        if len(parts) < 2:
            problems.append(f"{REACHES}:{n}: a reach needs a name and a file")
            continue
        flag = parts[2].strip() if len(parts) > 2 else ""
        if flag not in ("", "built") and not parts[1].startswith("Libs/"):
            problems.append(f"{REACHES}:{n}: \"{flag}\" after the file: only \"built\" means something there")
        rows.append((parts[0], re.split(r"[:.]", parts[0])[-1], parts[1], flag == "built"))
    return rows, problems


def reach_truth(reaches, where, documented, globals_read, documented_as):
    """Blizzard's frames are read past the documented API only where it is written down,
    the way library internals are. Every reach in tools/blizzard_reaches.txt is still in
    the client's UI source by its whole name: every part of it, together in one file
    (MacroFrame and MacroSelector both in the file that makes them), so a new build that
    renames or moves either part fails here. It is still in the file it names (its last
    part, and its first part too where that is a global the code reads), and is named in
    that file's header under "Game internals". And back:
    every member the code reads off a Blizzard global (MacroFrame.MacroSelector,
    GameTooltip:SetOwner), directly or through a local that is the global under another
    name, is either in Blizzard's own API docs as an entry of its kind (a function; for
    Enum an enumeration, for Constants a constants table) or a reach listed for that file.
    Every CreateFrame names its templates as a quoted string, each listed for that file.
    A field read off a local (button.Count) cannot be found this way and is listed by
    hand."""
    problems = []
    by_file = {}
    for name, last, rel, built in reaches:
        by_file.setdefault(rel, set()).add(last)
        parts = reach_parts(name)
        gone = [p for p in parts if not where.get(p)]
        if gone:
            problems.append(f"{REACHES}: {name}: {' and '.join(gone)} is nowhere in this client's UI source: "
                            f"Blizzard renamed or removed it")
        elif not set.intersection(*[where[p] for p in parts]):
            problems.append(f"{REACHES}: {name}: no file of this client's UI source has all of "
                            f"{', '.join(parts)}: Blizzard moved or renamed a part")
        if rel.startswith("Libs/"):
            continue  # a library's own reach: listed so a new build is searched for it, nothing more
        if not exact_path(rel):
            problems.append(f"{REACHES}: {name} names {rel}, and there is no such file")
            continue
        word = r"(?<![\w])" + re.escape(last) + r"(?![\w])"
        code = code_lines(read(rel))
        if not built and not re.search(word, code):
            problems.append(f"{REACHES}: {name} is listed for {rel}, whose code no longer uses it: drop the line")
        owner = parts[0]
        if not built and len(parts) > 1 and owner in globals_read and \
                not re.search(r"(?<![\w.:])" + re.escape(owner) + r"(?![\w])", code):
            problems.append(f"{REACHES}: {name} is listed for {rel}, whose code does not read {owner}: "
                            f"name the owner the code really reads")
        if not re.search(word, header_fields(rel).get(GAME_INTERNALS, "")):
            problems.append(f"{rel}: reaches {name}, and its header's \"{GAME_INTERNALS}\" does not name {last}")
    frames = [g for g in globals_read if g not in NOT_FRAMES]
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        lines = bare_code(read(rel))
        text = "\n".join(code for _, code in lines)
        for g in frames:
            if re.search(r"\blocal\s+(?:function\s+)?" + re.escape(g) + r"\b", text):
                continue  # the file has a local of that name (SSF's own Settings module): not Blizzard's
            # the global under another name: `local tip = GameTooltip` (or `tip = GameTooltip`)
            names = [g] + re.findall(r"(?:^|\n)\s*(?:local\s+)?(\w+)\s*=\s*" + re.escape(g) + r"\s*(?:\n|$)", text)
            known = documented_as.get(DOC_GLOBAL_KINDS[g], set()) if g in DOC_GLOBAL_KINDS else documented
            told = set()
            for n, code in lines:
                code = blank_strings(code)
                for name in names:
                    for member in re.findall(r"(?<![\w.:])" + re.escape(name) + r"\s*[.:]\s*(\w+)", code):
                        if member not in known and member not in by_file.get(rel, ()) and member not in told:
                            told.add(member)
                            seen = g if name == g else f"{g} (as {name})"
                            problems.append(f"{rel}:{n}: reads {seen}.{member}, which is not in Blizzard's API docs "
                                            f"and not a reach listed for this file in {REACHES}")
        # a frame made from a Blizzard template: CreateFrame(type, name, parent, "A, B")
        for n, templates in frame_templates(lines):
            if templates is None:
                problems.append(f"{rel}:{n}: CreateFrame's template is not a quoted string; write the "
                                f"template names out so the check can hold them to {REACHES}")
                continue
            for template in templates:
                if template not in by_file.get(rel, ()):
                    problems.append(f"{rel}:{n}: creates a frame from the template {template}, which is not a "
                                    f"reach listed for this file in {REACHES}")
    return problems


# ---------------------------------------------------------------- frame methods, for the fake game

FRAME_METHODS = os.path.join(ROOT, "tests", "frame_methods.lua")
# each frame kind the code, its libraries or the fake game makes, as the client documents
# it: the API tables it is made of, in the game's own widget tree
_OBJECT = ["SimpleObjectAPI", "SimpleFrameScriptObjectAPI"]
_SCRIPT_REGION = _OBJECT + ["SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleAnimatableObjectAPI"]
_REGION = _SCRIPT_REGION + ["SimpleRegionAPI"]
_FRAME = _SCRIPT_REGION + ["SimpleFrameAPI"]
_FONT = ["SimpleFontAPI"]  # the font instance methods FontString and EditBox share
FRAME_KINDS = {
    "Frame": _FRAME,
    "Button": _FRAME + ["SimpleButtonAPI"],
    "CheckButton": _FRAME + ["SimpleButtonAPI", "SimpleCheckboxAPI"],
    "EditBox": _FRAME + ["SimpleEditBoxAPI"] + _FONT,
    "Slider": _FRAME + ["SimpleSliderAPI"],
    "ScrollFrame": _FRAME + ["SimpleScrollFrameAPI"],
    "StatusBar": _FRAME + ["SimpleStatusBarAPI"],
    "Cooldown": _FRAME + ["FrameAPICooldown"],
    "GameTooltip": _FRAME + ["FrameAPITooltip"],
    "Minimap": _FRAME,
    "MessageFrame": _FRAME + ["SimpleMessageFrameAPI"] + _FONT,
    "FontString": _REGION + ["SimpleFontStringAPI"] + _FONT,
    "Texture": _REGION + ["SimpleTextureBaseAPI", "SimpleTextureAPI"],
    "MaskTexture": _REGION + ["SimpleTextureBaseAPI", "SimpleMaskTextureAPI"],
    "Line": _REGION + ["SimpleTextureBaseAPI", "SimpleLineAPI"],
    "Font": _OBJECT + _FONT,
    "AnimationGroup": _OBJECT + ["SimpleAnimGroupAPI"],
    "Animation": _OBJECT + ["SimpleAnimAPI"],
    # CreateAnimation(type) makes one of these; each adds its own methods to Animation's
    "Alpha": _OBJECT + ["SimpleAnimAPI", "SimpleAnimAlphaAPI"],
    "Translation": _OBJECT + ["SimpleAnimAPI", "SimpleAnimTranslationAPI"],
    "Scale": _OBJECT + ["SimpleAnimAPI", "SimpleAnimScaleAPI"],
    "Rotation": _OBJECT + ["SimpleAnimAPI", "SimpleAnimRotationAPI"],
    "Path": _OBJECT + ["SimpleAnimAPI", "SimpleAnimPathAPI"],
    "FlipBook": _OBJECT + ["SimpleAnimAPI", "SimpleAnimFlipBookAPI"],
    "VertexColor": _OBJECT + ["SimpleAnimAPI", "SimpleAnimVertexColorAPI"],
    "TextureCoordTranslation": _OBJECT + ["SimpleAnimAPI", "SimpleAnimTextureCoordTranslationAPI"],
}
# the templates the code makes frames from: their mixins add Lua methods to the frame
FRAME_TEMPLATES = ["BackdropTemplate", "DialogBorderOpaqueTemplate", "GameTooltipTemplate", "InputBoxTemplate",
                   "UIDropDownMenuTemplate", "UIPanelButtonTemplate", "SecureActionButtonTemplate",
                   "UIPanelCloseButton", "OptionsSliderTemplate", "UIPanelScrollFrameTemplate",
                   "UIPanelScrollBarTemplate"]


def frame_methods():
    """{kind: sorted method names} and {template: sorted method names}, read from the
    client's own API docs and UI source (tools/.wowui). The fake game refuses any other."""
    tables = {}
    for fn in os.listdir(WOWUI_DOCS):
        if not fn.endswith(".lua"):
            continue
        text = open(os.path.join(WOWUI_DOCS, fn), encoding="utf-8", errors="replace").read()
        m = re.search(r'^\s*Name\s*=\s*"(\w+)",\s*\n\s*Type\s*=\s*"ScriptObject"', text, re.M)
        if not m:
            continue
        body = text.split("Functions =", 1)[1].split("Events =", 1)[0] if "Functions =" in text else ""
        tables[m.group(1)] = set(re.findall(r'Name\s*=\s*"(\w+)",\s*\n\s*Type\s*=\s*"Function"', body))
    kinds = {}
    for kind, parts in FRAME_KINDS.items():
        names = set()
        for part in parts:
            if part not in tables:
                raise SystemExit(f"tools/check.py: the client's API docs have no {part} (FRAME_KINDS, {kind})")
            names |= tables[part]
        kinds[kind] = names

    # the docs leave out the GameTooltip's oldest methods (AddLine, SetOwner, NumLines...):
    # every method Blizzard's own UI calls on GameTooltip is one the game has
    called = set()
    for folder, _, files in os.walk(WOWUI_ADDONS):
        for fn in files:
            if fn.endswith(".lua"):
                text = open(os.path.join(folder, fn), encoding="utf-8", errors="replace").read()
                called.update(re.findall(r"\bGameTooltip:(\w+)\(", text))
    kinds["GameTooltip"] |= called
    kinds = {kind: sorted(names) for kind, names in kinds.items()}

    # templates: the XML that defines each, its mixins and what it inherits, then each
    # mixin's functions in the Lua (CreateFromMixins chains followed)
    defs, lua = {}, []
    for folder, _, files in os.walk(WOWUI_ADDONS):
        for fn in files:
            path = os.path.join(folder, fn)
            if fn.endswith(".xml"):
                text = open(path, encoding="utf-8", errors="replace").read()
                for m in re.finditer(r'<\w+\s+([^>]*\bname="(\w+)"[^>]*\bvirtual="true"[^>]*)>', text):
                    attrs = m.group(1)
                    mix = re.search(r'\bmixin="([^"]*)"', attrs)
                    inh = re.search(r'\binherits="([^"]*)"', attrs)
                    defs.setdefault(m.group(2), (
                        [x.strip() for x in mix.group(1).split(",")] if mix else [],
                        [x.strip() for x in inh.group(1).split(",")] if inh else []))
            elif fn.endswith(".lua"):
                lua.append(path)
    methods, chains = {}, {}
    for path in lua:
        text = open(path, encoding="utf-8", errors="replace").read()
        for mixin, name in re.findall(r"^function\s+(\w+Mixin)[:.](\w+)\s*\(", text, re.M):
            methods.setdefault(mixin, set()).add(name)
        for mixin, args in re.findall(r"^(\w+Mixin)\s*=\s*CreateFromMixins\(([^)]*)\)", text, re.M):
            chains.setdefault(mixin, []).extend(re.findall(r"\w+Mixin", args))

    def mixin_names(mixin, seen):
        if mixin in seen:
            return set()
        seen.add(mixin)
        out = set(methods.get(mixin, set()))
        for parent in chains.get(mixin, []):
            out |= mixin_names(parent, seen)
        return out

    def template_names(template, seen):
        if template in seen or template not in defs:
            return set()
        seen.add(template)
        mixins, inherits = defs[template]
        out = set()
        for mixin in mixins:
            out |= mixin_names(mixin, set())
        for parent in inherits:
            out |= template_names(parent, seen)
        return out

    templates = {t: sorted(template_names(t, set())) for t in FRAME_TEMPLATES}
    return kinds, templates


def write_frame_methods():
    """Write tests/frame_methods.lua from the client's docs; True when it changed."""
    kinds, templates = frame_methods()
    out = ["-- Soul Shards Forever (SSF). MIT, see LICENSE.",
           "--",
           "-- frame_methods: every method each frame kind has in this client, and what each template",
           "-- the code makes frames from adds, read from the client's own API docs and UI source by",
           "-- tools/check.py. Written by the check, never by hand. The fake game (tests/wow_stub.lua)",
           "-- refuses any method a frame of that kind does not have.",
           "-- Touches nothing else.",
           "",
           "return {"]
    for label, table in (("kinds", kinds), ("templates", templates)):
        out.append(f"    {label} = {{")
        for key in sorted(table):
            words = ", ".join(f"{n} = true" for n in table[key])
            out.append(f"        {key} = {{ {words} }},")
        out.append("    },")
    out.append("}")
    text = "\n".join(out) + "\n"
    old = open(FRAME_METHODS, encoding="utf-8").read() if os.path.exists(FRAME_METHODS) else ""
    if text == old:
        return False
    with open(FRAME_METHODS, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return True


def check_blizzard_api():
    """Every Blizzard name the code uses, against the client's own UI source (tools/.wowui,
    the wow-ui-source mirror's forever branch, the build the live client runs): no global
    SSF reads is defined in a Deprecated file (those are shims Blizzard removes a patch or
    two later: IsPlayerSpell and GetActionText were both found there); every
    C_<namespace>.<function> it calls is in Blizzard_APIDocumentationGenerated (so a
    namespaced call is one this client has, not one borrowed from retail); every other
    global in .luacheckrc appears in that source or is on KNOWN_GLOBALS with its proof from
    the game; and every reach past the documented API is written down (reach_truth)."""
    print("== blizzard api")
    build, note = wowui_build()
    if build is None:
        # no copy of the UI source at all: nothing was checked. That passes only when asked
        # for by name; a check that silently skips is a check nobody runs.
        if OFFLINE in sys.argv:
            print(f"   SKIPPED on {OFFLINE}: no UI source ({note})")
            return True
        print(f"   FAILED: no UI source ({note}), so no Blizzard name was checked. Offline with no\n"
              f"   copy on disk? Run again with {OFFLINE} to pass without this step.")
        return False
    print(f"   {WOWUI_BRANCH} build {build} ({note})")
    if write_frame_methods():
        print("   tests/frame_methods.lua rewritten from this client's API docs: CHANGED, run the check again "
              "and commit it")
        ok_methods = False
    else:
        ok_methods = True
    globs, namespaced = blizzard_names()
    ok = True
    deprecated = []
    for folder, _, files in os.walk(WOWUI_ADDONS):
        if "Deprecated" not in folder:
            continue
        for fn in files:
            if fn.endswith(".lua"):
                deprecated.append(os.path.join(folder, fn))
    def_re = re.compile(r"^\s*(?:function\s+(\w+)\s*\(|(\w+)\s*=)")
    shimmed = {}
    for path in deprecated:
        for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            m = def_re.match(line)
            name = m and (m.group(1) or m.group(2))
            if name in globs:
                shimmed.setdefault(name, []).append(f"{os.path.relpath(path, WOWUI_ADDONS)}:{n}")
    for name in sorted(shimmed):
        print(f"   {name} is a deprecated shim ({shimmed[name][0]}); move to its C_ replacement")
        ok = False
    docs, documented, documented_as = {}, set(), {}
    for fn in os.listdir(WOWUI_DOCS):
        if not fn.endswith(".lua"):
            continue
        text = open(os.path.join(WOWUI_DOCS, fn), encoding="utf-8", errors="replace").read()
        # a member is documented by an entry of its own kind: a function for a frame or a
        # namespace, an enumeration for Enum, a constants table for Constants. An argument,
        # field or event that happens to share the name documents nothing.
        names = [n for n, kind in DOC_ENTRY_RE.findall(text) if kind == "Function"]
        documented.update(names)
        for n, kind in DOC_ENTRY_RE.findall(text):
            if kind in DOC_GLOBAL_KINDS.values():
                documented_as.setdefault(kind, set()).add(n)
        ns = re.search(r'Namespace\s*=\s*"(C_\w+)"', text)
        if ns:
            docs.setdefault(ns.group(1), set()).update(names)
    for (ns, fn), where in sorted(namespaced.items()):
        if fn not in docs.get(ns, ()):
            print(f"   {ns}.{fn} is not in this client's API docs ({where[0]})")
            ok = False

    # every other global the code may read is one this client has: its name appears in the
    # client's own UI source, or it is on the short list of ones proven in the game
    plain = [g for g in globs if not g.startswith("C_")]
    reaches, reach_problems = read_reaches()
    has = ui_source_has(plain, build)
    where = ui_source_files([p for name, _, _, _ in reaches for p in reach_parts(name)], build)
    for name in plain:
        if not has[name] and name not in KNOWN_GLOBALS:
            print(f"   {name} is in .luacheckrc and nowhere in this client's UI source: prove the game has it "
                  f"(KNOWN_GLOBALS in tools/check.py, with the proof) or stop using it")
            ok = False
    for name in sorted(KNOWN_GLOBALS):
        if name not in plain:
            print(f"   KNOWN_GLOBALS lists {name}, which .luacheckrc no longer names: drop it from the list")
            ok = False
        elif has[name]:
            print(f"   KNOWN_GLOBALS lists {name}, which this client's UI source now has: drop it from the list")
            ok = False

    # reaches into Blizzard's frames past the documented API
    for p in reach_problems + reach_truth(reaches, where, documented, plain, documented_as):
        print("   " + p)
        ok = False
    ok = ok and ok_methods
    print(f"   {len(globs)} globals ({len(KNOWN_GLOBALS)} proven in game only), {len(namespaced)} namespaced calls, "
          f"{len(reaches)} reaches, " + ("ok" if ok else "FAILED"))
    return ok


def check_tests():
    runner = os.path.join(ROOT, "tests", "run.lua")
    if not os.path.exists(runner):
        print("== tests\n   FAILED: tests/run.lua is missing, so nothing was tested")
        return False
    exe = os.environ.get("LUA") or shutil.which("lua51") or FALLBACK_LUA
    return run([exe, "tests/run.lua"], "tests")  # the runner itself fails when it finds no test file


# ---------------------------------------------------------------- the window's controls

WINDOW_RUNNER = "tests/window.lua"
WINDOW_LIST = "tests/window_controls.txt"
WINDOW_SCENES = ["settled", "first"]
ACCEPT_WINDOW = "--accept-window"
WINDOW_HEAD = """# tests/window_controls.txt: every control in SSF's options window that carries a text,
# and every button on the window's own frame that has none, as tests/window.lua finds them
# when it opens the real window outside the game. Columns: kind, shown or hidden, enabled
# or greyed, the text. One block per scene (see tests/window.lua for what a scene is).
# Written by `python tools/check.py --accept-window`, never by hand. The check fails when
# the window no longer matches this file. A test card names only controls listed here as
# shown. It says what is in the window, not where it sits or how it looks.
"""


def window_list():
    """(text, error): what tests/window.lua prints for every scene, one block each, under
    the file's heading; or the runner's own output when a scene fails to open."""
    exe = os.environ.get("LUA") or shutil.which("lua51") or FALLBACK_LUA
    blocks = []
    for scene in WINDOW_SCENES:
        proc = subprocess.run([exe, WINDOW_RUNNER, scene], cwd=ROOT, text=True, capture_output=True,
                              encoding="utf-8", errors="replace")
        if proc.returncode != 0:
            return None, f"scene {scene}: " + (proc.stdout + proc.stderr).strip()
        blocks.append(proc.stdout.strip())
    return WINDOW_HEAD + "\n" + "\n\n".join(blocks) + "\n", None


def check_window():
    """The options window, opened for real outside the game (tests/window.lua), still holds
    exactly the controls tests/window_controls.txt lists. A control added, removed,
    renamed, hidden or greyed fails here until the list is accepted on purpose
    (--accept-window), so the list is always what a player has, and nobody describes the
    window from reading code."""
    print("== window controls")
    new, error = window_list()
    if error:
        print("   FAILED: the window did not open\n   " + error.replace("\n", "\n   "))
        return False
    path = os.path.join(ROOT, WINDOW_LIST)
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    count = sum(1 for l in new.splitlines() if l and not l.startswith(("#", "scene:")))
    if new == old:
        print(f"   {count} controls in {len(WINDOW_SCENES)} scenes, ok")
        return True
    if ACCEPT_WINDOW in sys.argv:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
        print(f"   {WINDOW_LIST} rewritten ({count} controls): ACCEPTED, read the diff before committing")
        return True
    import difflib
    for line in difflib.unified_diff(old.splitlines(), new.splitlines(), "listed", "the window now", lineterm="", n=0):
        if not line.startswith(("---", "+++", "@@")):
            print("   " + line)
    print(f"   FAILED: the window no longer matches {WINDOW_LIST}. If the change is meant, run\n"
          f"   python tools/check.py {ACCEPT_WINDOW}")
    return False


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


NEWS_PREFIX = "News_"  # News/News_deDE.lua adds its lines to the locale Locales/deDE.lua registers


def news_files():
    """News/News_<code>.lua, the current announcement's lines, one per locale (not
    News.lua, the announcement itself)."""
    folder = os.path.join(ROOT, "News")
    if not os.path.isdir(folder):
        return []
    return [f"News/{fn}" for fn in sorted(os.listdir(folder))
            if fn.startswith(NEWS_PREFIX) and fn.endswith(".lua")]


def locale_strings(name):
    """One locale's whole table, as the game has it after load: Locales/<name> plus the
    announcement's lines in News/News_<name>, which Register merges into the same locale."""
    out = locale_table(f"Locales/{name}")
    if f"News/{NEWS_PREFIX}{name}" in news_files():
        out.update(locale_table(f"News/{NEWS_PREFIX}{name}"))
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


# The two keys whose code hands the translation more arguments than English uses: both
# spell names, where English names only one. Each by the start of its key, with the most
# arguments the code passes. Any other translation uses exactly its key's arguments.
MORE_ARGUMENTS = {
    "The Bane macro lets you delete on the move": 2,
    "Make sure you're not targeting an enemy with the Bane macro": 2,
}


def placeholder_problems(key, value):
    """Why a translation's placeholders do not fit the key's: never fewer than the key,
    never more (except the keys on MORE_ARGUMENTS, up to the count named there), never
    another type in a position, and never a mix of plain and positional."""
    _, want = placeholders(key)
    positional, got = placeholders(value)
    if positional is None:
        return ["mixes plain and positional placeholders"]
    out = []
    allowed = next((n for start, n in MORE_ARGUMENTS.items() if key.startswith(start)), len({i for i, _ in want}))
    used = {i for i, _ in got}
    if used and max(used) > allowed:
        out.append(f"uses argument {max(used)}, and the code hands it only {allowed}")
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
    every locale code registered. A locale is its Locales file plus its News file
    (locale_strings), so an announcement missing in one language fails here too; a News
    file with no Locales file beside it is a locale nobody registered."""
    print("== locales")
    ref = None
    tables = {}
    for rel in locale_files():
        name = os.path.basename(rel)
        tables[name] = (locale_strings(name), CODE_RE.findall(read(rel)))
        if name == "enUS.lua":
            ref = tables[name][0]
    if ref is None:
        print("   FAILED: Locales/enUS.lua not found")
        return False
    ok = True
    for start in MORE_ARGUMENTS:
        hits = [k for k in ref if k.startswith(start)]
        if len(hits) != 1:
            print(f"   tools/check.py MORE_ARGUMENTS: {start!r} starts {len(hits)} enUS keys, not one: "
                  f"follow the key's new wording or drop the line")
            ok = False
    toc = read("SoulShardForever.toc")
    for rel in news_files():
        name = os.path.basename(rel)[len(NEWS_PREFIX):]
        if name not in tables:
            print(f"   {rel}: no Locales/{name} to add its lines to")
            ok = False
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
    ref = {unescape(k) for k in locale_strings("enUS.lua")}
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


FAKE_GAME = "tests/wow_stub.lua"
# a color typed as a keyed table, on one line or over several: { r = 1, g = 0.5, b = 0 }
COLOR_KEYED_RE = re.compile(rf"\{{[^{{}}]*\br\s*=\s*{NUM}[^{{}}]*\bg\s*=\s*{NUM}[^{{}}]*\bb\s*=\s*{NUM}")
# a color call whose r, g, b are names or numbers (which names are numbers: number_names)
COLOR_NAMES_RE = re.compile(r"(?:Color|ColorTexture|VertexColor|TextColor|BackdropColor|BackdropBorderColor)"
                            r"\(\s*([\w.]+)\s*,\s*([\w.]+)\s*,\s*([\w.]+)")


def number_names(code):
    """The names a file sets to a typed number: `local R = 0.2`, `R = 0.2`, and each name of
    `local r, g, b = 1, 0.5, 0` whose own value is a number."""
    names = set()
    for m in re.finditer(r"^\s*(?:local\s+)?(\w+(?:\s*,\s*\w+)*)\s*=(?!=)\s*(.+?)\s*$", code, re.M):
        left = [s.strip() for s in m.group(1).split(",")]
        right = [s.strip() for s in m.group(2).split(",")]
        for name, value in zip(left, right):
            if re.fullmatch(NUM, value):
                names.add(name)
    return names


def known_colors():
    """The colors Colors.lua defines, as (r, g, b) tuples and as the hex Colors derives."""
    triples = {tuple(float(x) for x in m) for m in COLOR_DEF_RE.findall(read(COLORS))}
    hexes = {"%02x%02x%02x" % tuple(int(v * 255 + 0.5) for v in t) for t in triples}
    return triples, hexes


def color_files():
    """Every file a color could be typed into: the Lua that carries a header, every locale,
    and the shipped docs (README, CHANGELOG, media/*.md; .docs/ is local work and not
    walked). Colors.lua itself is the home and is left out."""
    out = [f for f in lua_files() if f != COLORS] + locale_files() + news_files()
    out += [fn for fn in ("README.md", "CHANGELOG.md") if os.path.exists(os.path.join(ROOT, fn))]
    out += [f"media/{fn}" for fn in sorted(os.listdir(os.path.join(ROOT, "media"))) if fn.endswith(".md")]
    return out


def check_colors():
    """Every color lives in Colors.lua and is read by name. Outside it, in code, locales,
    tests and the shipped docs: no |cRRGGBBAA escape code (Colors:Paint makes them), no hex
    of a color Colors defines; in code lines, no r, g, b that equals one Colors defines, no
    color-setting call with its r, g, b typed as numbers, and no bare table of three or
    four numbers (a color's shape); nor the same in other clothes: a table with r, g and b
    keys typed as numbers, or a color call fed names the file itself sets to numbers. An
    alpha stays the caller's own."""
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
        if not lua:
            continue
        # the same color in other clothes, looked for over the whole file's code
        code = code_text(rel)
        # (not in the fake game: it states Blizzard's own RAID_CLASS_COLORS, which is keyed so)
        for m in COLOR_KEYED_RE.finditer(code if rel != FAKE_GAME else ""):
            report(rel, code[: m.start()].count("\n") + 1, "a table with r, g and b typed as numbers: a color belongs in Colors")
        numbers = number_names(code)
        for m in COLOR_NAMES_RE.finditer(code):
            parts = [m.group(1), m.group(2), m.group(3)]
            if any(p in numbers for p in parts) and all(p in numbers or re.fullmatch(NUM, p) for p in parts):
                report(rel, code[: m.start()].count("\n") + 1,
                       f"a color call takes {', '.join(parts)}, names this file sets to numbers: a color belongs in Colors")
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
# a module asked for by its name, with or without AceAddon's "silent" second argument
GM_CALL = r'GetModule\(\s*"(\w+)"\s*(?:,\s*true\s*)?\)'
GM_ANY = GM_CALL.replace(r'"(\w+)"', r'"\w+"')
GETMODULE_RE = re.compile(GM_CALL)
PROFILE_ALIAS_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*(?:SSF|self)\.db\.profile\s*(?:--.*)?$", re.M)
PROFILE_KEY_IN_HEADER_RE = re.compile(r"\bprofile\.(\w+)")


def header_fields(rel):
    """Field name -> its text: the field's own line plus the continuation lines up to the
    next field or the end of the header."""
    field_re = re.compile(r"^(" + "|".join(re.escape(f) for f in FIELDS) + r"):\s*")
    fields, cur = {}, None
    for body in header_lines(rel):
        if body.endswith(CLOSING):  # the closing line is no part of the field above it
            body = body[: -len(CLOSING)].rstrip()
        m = field_re.match(body)
        if m:
            cur = m.group(1)
            fields[cur] = body[m.end():]
        elif cur and body:
            fields[cur] += " " + body
    return fields


PROFILE_RE = r"(?:SSF|self)\.db\.profile"
PROFILE_KEY = r"(?:\.(\w+)|\[\s*[\"'](\w+)[\"']\s*\])"  # .key or ["key"]


def profile_refs(text):
    """(reads, writes, problems): the profile keys the code touches, through SSF.db.profile,
    a local alias of it, or the parameter of a local function the profile is handed to.
    A key is written .key or ["key"]; a write is `<profile><key>... =` (not ==), and a
    line that assigns through a local holding one key's table (`local window =
    SSF.db.profile.window`, also in a multi-name local) writes that key. A key the check
    cannot name (profile[name]) or the whole profile handed to a function outside the
    file is a problem: nothing would hold those writes to Saves."""
    aliases = set(PROFILE_ALIAS_RE.findall(text)) | {"SSF.db.profile", "self.db.profile"}
    problems = []
    # `Migrate(self.db.profile)` with `local function Migrate(p)`: the parameter is an
    # alias, whichever argument the profile is
    for m in re.finditer(r"([\w.:]+)\(([^()\n]*)\)", text):
        args = [a.strip() for a in m.group(2).split(",")]
        for i, arg in enumerate(args):
            if not re.fullmatch(PROFILE_RE, arg):
                continue
            fn = m.group(1)
            fm = re.search(r"\bfunction\s+" + re.escape(fn) + r"\s*\(([^)]*)\)", text)
            params = [p.strip() for p in fm.group(1).split(",")] if fm else []
            if i < len(params) and params[i]:
                aliases.add(params[i])
            elif not fm:
                problems.append(f"the code hands the whole profile to {fn}, outside this file; "
                                f"what it writes there no header shows")
    base = "(?:" + "|".join(re.escape(a) for a in sorted(aliases, key=len, reverse=True)) + r")"
    start = r"(?<![\w.:])" + base
    reads = {a or b for a, b in re.findall(start + PROFILE_KEY, text)}
    writes = {a or b for a, b in re.findall(start + PROFILE_KEY + r"(?:\.\w+|\[[^\]]*\])*\s*=(?!=)", text)}
    for expr in re.findall(start + r"\[\s*([^\]\"'][^\]]*)\]", text):
        problems.append(f"the code names a profile key at run time (profile[{expr.strip()}]); "
                        f"name each key so Reads and Saves can be checked")
    # a local holding one key's table: `local window = SSF.db.profile.window`, or one name
    # of several in `local saved, status = SSF.db.profile.window, ...`
    held = {}
    for m in re.finditer(r"^\s*local\s+(\w+(?:\s*,\s*\w+)*)\s*=\s*(.+)$", text, re.M):
        names = [x.strip() for x in m.group(1).split(",")]
        values = [x.strip() for x in re.split(r",(?![^()]*\))", strip_comment(m.group(2)))]
        for name, value in zip(names, values):
            vm = re.fullmatch(base + PROFILE_KEY, value)
            if vm:
                held[name] = vm.group(1) or vm.group(2)
    for var, key in held.items():
        for line in text.splitlines():
            if re.match(r"\s*" + re.escape(var) + r"\s*[.\[]", line) and re.search(r"(?<![=~<>])=(?!=)", line):
                writes.add(key)
    return reads, writes, problems


def check_header_truth():
    """Every claim a header makes that code can verify: Listens names exactly the messages
    and events the file registers; Sends names exactly the messages it sends (Hooks has its
    own step, check_hooks); every
    module it calls is named under Reads, and every profile key it touches under Reads or
    Saves (a mention elsewhere in the header's prose is not a claim), and no module Reads
    names is one the code never calls; every
    profile key it writes is named under Saves, and no `profile.<key>` written in Saves is
    one the code does not write (a bare key name there is not checked)."""
    print("== header truth")
    ok = True
    code_files = [f for f in lua_files() if not f.startswith("tests/")]
    module_names = set(module_registry()) - {ADDON}
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

        # modules it calls: named under Reads (a mention in the header's prose is not a claim)
        reads_field = fields.get("Reads", "")
        for name in sorted(set(GETMODULE_RE.findall(text))):
            if name != stem and not word_in(name, reads_field):
                problems.append(f"the code calls GetModule(\"{name}\"), Reads does not name {name}")
        # and back: a module Reads names is one the code calls (a stale claim misleads)
        called = set(GETMODULE_RE.findall(text))
        for name in sorted(module_names - called - {stem}):
            if word_in(name, reads_field):
                problems.append(f"Reads names {name}, the code never calls GetModule(\"{name}\")")

        # profile keys: touched -> named under Reads or Saves; written -> named under Saves; Saves -> written
        reads, writes, unseen = profile_refs(text)
        problems += unseen
        saves = fields.get("Saves", "")
        for key in sorted(reads | writes):
            if not word_in(key, reads_field) and not word_in(key, saves):
                problems.append(f"the code touches profile.{key}, neither Reads nor Saves names it")
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


# ---------------------------------------------------------------- the toc and the files on disk

NOT_ADDON_CODE = {"Libs", "tests", "tools", "media", "_ref"}  # folders whose Lua the game never loads from the toc


def exact_path(rel):
    """True when rel exists under the addon with exactly this spelling, case included. The
    game on Windows forgives case; the packager, Linux and macOS do not."""
    folder = ROOT
    for part in rel.split("/"):
        if not os.path.isdir(folder) or part not in os.listdir(folder):
            return False
        folder = os.path.join(folder, part)
    return True


def addon_lua_on_disk():
    """Every .lua file under the addon that is not a library, a test or a tool, as paths
    from the root: what the game should be loading."""
    out = []
    for folder, dirs, files in os.walk(ROOT):
        rel_folder = os.path.relpath(folder, ROOT).replace(os.sep, "/")
        top = rel_folder.split("/")[0]
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        if top in NOT_ADDON_CODE:
            dirs[:] = []
            continue
        for fn in files:
            if fn.endswith(".lua"):
                out.append(fn if rel_folder == "." else f"{rel_folder}/{fn}")
    return sorted(out)


def check_toc():
    """The toc and the files on disk say the same, both ways, and the checks see every file
    the game loads. A toc line names a file that exists, spelled exactly (case included);
    every Lua file of the addon on disk is on a toc line (one that is not would pass every
    check and never load); and every one of them is a file the header checks or the locale
    checks read (a file in a new folder would otherwise load unchecked). embeds.xml's own
    lines are held to the same spelling rule."""
    print("== toc and files")
    problems = []
    listed = toc_files()
    for rel in listed:
        if not exact_path(rel):
            problems.append(f"the toc names {rel.replace('/', chr(92))}, and no file is spelled exactly that")
    on_disk = addon_lua_on_disk()
    listed_lua = {f for f in listed if f.endswith(".lua")}
    for rel in on_disk:
        if rel not in listed_lua:
            problems.append(f"{rel} is on disk and not in the toc: the game never loads it")
    checked = set(lua_files()) | set(locale_files()) | set(news_files())
    for rel in on_disk:
        if rel not in checked:
            problems.append(f"{rel} is in a place the checks do not read (see lua_files, locale_files, news_files)")
    for xml in [f for f in listed if f.endswith(".xml")]:
        if not exact_path(xml):
            continue
        for inc in re.findall(r'<(?:Include|Script)\s+file\s*=\s*["\']([^"\']+)["\']', read(xml)):
            inc = inc.replace("\\", "/")
            if not exact_path(inc):
                problems.append(f"{xml} names {inc.replace('/', chr(92))}, and no file is spelled exactly that")
    for p in problems:
        print("   " + p)
    print(f"   {len(listed)} toc lines, {len(on_disk)} Lua files of the addon on disk, " + ("ok" if not problems else "FAILED"))
    return not problems


# ---------------------------------------------------------------- Bindings.xml

BINDINGS = "Bindings.xml"
NAMED_FRAME_RE = re.compile(r'\bCreateFrame\(\s*"\w+"\s*,\s*"(\w+)"')
SECTION_RE = re.compile(r'^local\s+SECTION\s*=\s*"([^"]*)"', re.M)
CLICK_RE = re.compile(r"/click\s+(\w+)")
SSF_GLOBAL_RE = re.compile(r"(?<![\w.:\"])(SSF\w*)\b(?!\s*[\"(])")


def named_frames():
    """Every global frame name the code creates (CreateFrame with a quoted name): name -> file."""
    out = {}
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        for name in NAMED_FRAME_RE.findall("\n".join(code for _, code in bare_code(read(rel)))):
            out[name] = rel
    return out


def bindings():
    """[(binding name, category, body)] from Bindings.xml, read as the XML it is: the
    attributes in any order, comments left out. A file the game's XML reader would refuse
    raises ValueError, with the reader's own words."""
    try:
        root = ElementTree.fromstring(read(BINDINGS))
    except ElementTree.ParseError as e:
        raise ValueError(f"{BINDINGS} is not well-formed XML ({e}): the game would load no binding from it")
    return [(b.get("name", ""), b.get("category", ""), b.text or "") for b in root.iter("Binding")]


def bindings_uses():
    """Every use Bindings.xml makes of a module's Public: [(module, name)]. The file is
    Lua inside XML, read by the game and by nothing else until this check."""
    out = []
    try:
        rows = bindings()
    except ValueError:
        return out  # the bindings step reports a file the game would refuse
    for _, _, body in rows:
        out += [(mod, name) for mod, _, name in DIRECT_CALL_RE.findall(body)]
    return out


def check_bindings():
    """Bindings.xml is held to the code it calls, since the game loads it by name and no
    other check reads it: every SSF global it uses is a frame the code creates under that
    name; every module method it calls is defined and listed under that module's Public;
    every binding has its label global (BINDING_NAME_<name>) set in the code; its category
    is the one KeyBindings opens the Key Bindings screen on (SECTION, typed in both files
    because XML cannot read Lua); and every `/click <name>` the README, the shipped docs
    or a locale tells a player to type names a frame the code creates. So a rename cannot
    quietly kill a key binding or every player's macro."""
    print("== bindings")
    problems = []
    if not exact_path(BINDINGS):
        print(f"   FAILED: {BINDINGS} not found (the game loads it by that exact name)")
        return False
    try:
        rows = bindings()
    except ValueError as e:
        print(f"   FAILED: {e}")
        return False
    if not rows:
        problems.append(f"{BINDINGS}: no <Binding> in it: the Key Bindings screen would show no SSF row")
    for name, _, _ in rows:
        if not re.fullmatch(r"SSF_[A-Z_]+", name):
            problems.append(f"{BINDINGS}: a binding named \"{name}\": each needs a name SSF_<WHAT>, its label's key")
    frames = named_frames()
    reg = module_registry()
    code = "\n".join("\n".join(c for _, c in bare_code(read(rel))) for rel in lua_files() if not rel.startswith("tests/"))
    section = SECTION_RE.search(read("Modules/KeyBindings.lua"))
    for name, category, body in rows:
        for glob_name in sorted(set(SSF_GLOBAL_RE.findall(body))):
            if glob_name not in frames:
                problems.append(f"{BINDINGS}: {name} uses the global {glob_name}, and no file creates a frame of that name")
        if not re.search(r"\bBINDING_NAME_" + re.escape(name) + r"\s*=(?!=)", code):
            problems.append(f"{BINDINGS}: {name} has no label: nothing sets BINDING_NAME_{name}")
        if not section or section.group(1) != category:
            problems.append(f"{BINDINGS}: {name} is in category \"{category}\", KeyBindings' SECTION is "
                            f"\"{section.group(1) if section else 'not found'}\": the Keybindings button would open the wrong place")
    for mod, name in bindings_uses():
        if mod not in reg:
            problems.append(f"{BINDINGS}: GetModule(\"{mod}\"): no file makes that module")
        else:
            rel, var, _ = reg[mod]
            if name not in defined_names(rel, var):
                problems.append(f"{BINDINGS}: calls {mod}:{name}, which {rel} does not define")
            elif name not in public_names(rel, var):
                problems.append(f"{BINDINGS}: calls {mod}:{name}, which {rel} does not list under Public")
    docs = [fn for fn in ("README.md",) if os.path.exists(os.path.join(ROOT, fn))]
    docs += [f"media/{fn}" for fn in sorted(os.listdir(os.path.join(ROOT, "media"))) if fn.endswith(".md")]
    for rel in docs + locale_files() + news_files():
        for target in sorted(set(CLICK_RE.findall(read(rel)))):
            if target not in frames:
                problems.append(f"{rel}: tells the player to /click {target}, and no file creates a frame of that name")
    for p in problems:
        print("   " + p)
    print(f"   {len(rows)} bindings, {len(bindings_uses())} module calls, " + ("ok" if not problems else "FAILED"))
    return not problems


# ---------------------------------------------------------------- exceptions and lib internals

STANDARD = "CLAUDE.md"
NUMBER_WORDS = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
                "Eleven", "Twelve"]
EXCEPTIONS_HEAD_RE = re.compile(r"^- (\w+) documented exceptions\b", re.M)
EXCEPTION_ITEM_RE = re.compile(r"^ {4}- (\w+): ")
LIB_PLACES_RE = re.compile(r"only in (Widgets\\.*?), and every such\s+field", re.S)
NUMBERED_RE = re.compile(r"\(\d+\)")


def code_headers():
    return [f for f in lua_files() if not f.startswith("tests/")]


def header_exceptions():
    """file -> how many exceptions its header documents: one for an Exceptions field, or as
    many as it numbers ((1), (2)). Shipped code only: a test's Exceptions is about the test."""
    out = {}
    for rel in code_headers():
        text = header_fields(rel).get("Exceptions")
        if text is not None:
            out[rel] = max(1, len(NUMBERED_RE.findall(text)))
    return out


def standard_exceptions():
    """(the number the standard states, [file name per list line]) from CLAUDE.md's
    "<Number> documented exceptions" bullet and the `    - File: ...` lines under it."""
    text = read(STANDARD)
    m = EXCEPTIONS_HEAD_RE.search(text)
    if not m:
        return None, []
    stated = NUMBER_WORDS.index(m.group(1)) if m.group(1) in NUMBER_WORDS else None
    names, started = [], False
    for line in text[m.end():].splitlines()[1:]:
        item = EXCEPTION_ITEM_RE.match(line)
        if item:
            names.append(item.group(1))
            started = True
        elif started and not line.startswith("      "):
            break
        elif not started and line.startswith("- "):
            break
    return stated, names


def lib_internal_places():
    """(widgets allowed, {module names}) from CLAUDE.md's "only in Widgets\\, the ... modules
    and Core's ..." clause: where a Lib internals field may appear."""
    m = LIB_PLACES_RE.search(read(STANDARD))
    if not m:
        return None, set()
    known = set(module_registry()) - {ADDON} | {"Core"}
    return True, {w for w in re.findall(r"\w+", m.group(1)) if w in known}


def check_exceptions():
    """The standard's two lists are the truth, both ways. Exceptions: the number CLAUDE.md
    states, the lines of its list, and the Exceptions the headers document all agree, file
    by file (so a seventh exception cannot appear in a header, or stay in the list after
    its code is gone, without failing). Lib internals: a header carries the field only in a
    place CLAUDE.md names, and every module it names carries one."""
    print("== exceptions and lib internals")
    problems = []
    stated, listed = standard_exceptions()
    documented = header_exceptions()
    if stated is None:
        problems.append(f"{STANDARD}: no \"<Number> documented exceptions\" line with a number word found")
    else:
        if stated != len(listed):
            problems.append(f"{STANDARD}: says {NUMBER_WORDS[stated]} documented exceptions, lists {len(listed)}")
        by_name = {module_name(rel): (rel, n) for rel, n in documented.items()}
        for name in sorted(set(listed) | set(by_name)):
            want = listed.count(name)
            rel, have = by_name.get(name, (name, 0))
            if want != have:
                problems.append(f"{rel}: its header documents {have} exception(s), {STANDARD} lists {want} for {name}")
    widgets_ok, places = lib_internal_places()
    if widgets_ok is None:
        problems.append(f"{STANDARD}: the \"only in Widgets\\, ...\" clause for Lib internals was not found")
    else:
        carriers = {rel for rel in code_headers() if "Lib internals" in header_fields(rel)}
        for rel in sorted(carriers):
            if not rel.startswith("Widgets/") and module_name(rel) not in places:
                problems.append(f"{rel}: has a Lib internals field, {STANDARD} does not allow one there")
        for name in sorted(places - {module_name(rel) for rel in carriers}):
            problems.append(f"{STANDARD}: allows Lib internals in {name}, whose header has no such field")
    for p in problems:
        print("   " + p)
    print(f"   {sum(documented.values())} exceptions, {len(listed)} listed; Lib internals in "
          f"{sum(1 for rel in code_headers() if 'Lib internals' in header_fields(rel))} files, "
          + ("ok" if not problems else "FAILED"))
    return not problems


def exceptions_tail():
    """The map's closing section, written from the headers: each documented exception in
    its header's own words, and the files that read library internals."""
    out = ["## Shared state and exceptions\n"]
    out.append("The AceDB profile is the one shared state: any module may read it, only its owner derives")
    out.append("a rule from it (CLAUDE.md). NS is the addon-private table Core and the locale registrar")
    out.append("share.\n")
    documented = header_exceptions()
    out.append(f"The documented exceptions to the two rules, {sum(documented.values())} in all, from each header's Exceptions:\n")
    for rel in [f for f in code_headers() if f in documented]:
        out.append(f"- {module_name(rel)}: {header_fields(rel)['Exceptions']}")
    carriers = [module_name(rel) for rel in code_headers() if "Lib internals" in header_fields(rel)]
    out.append("\nLibrary internals are read in: " + ", ".join(carriers) + ". Each header's \"Lib internals\"")
    out.append("names the fields and what breaks when a library moves them.")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- acts on

# What a file does to the game beyond its own frames and the profile. Each entry: the word
# the header's "Acts on" field must carry, the code that counts as doing it, and what it is.
# A word that is a call's own name (starts with a capital, no spaces) is also checked the
# other way: an Acts on that names it while the code no longer does it is stale.
ACTS = [
    ("PickupContainerItem", r"\bPickupContainerItem\b", "picks an item up or drops it (moves items)"),
    ("ClearCursor", r"\bClearCursor\b", "clears the cursor"),
    ("DeleteCursorItem", r"\bDeleteCursorItem\b", "deletes the item on the cursor"),
    ("UseContainerItem", r"\bUseContainerItem\b", "uses an item"),
    ("SplitContainerItem", r"\bSplitContainerItem\b", "splits a stack onto the cursor"),
    ("SortBags", r"\bSort(?:Bank|ReagentBank|AccountBank)?Bags\b", "sorts the bags"),
    ("PutItemIn", r"\bPutItemIn(?:Backpack|Bag)\b", "drops the cursor's item into a bag"),
    ("CreateMacro", r"\bCreateMacro\b", "makes a macro"),
    ("EditMacro", r"\bEditMacro\b", "edits a macro"),
    ("DeleteMacro", r"\bDeleteMacro\b", "deletes a macro"),
    ("RunMacroText", r"\bRunMacroText\b", "runs macro text"),
    ("MuteSoundFile", r"\bMuteSoundFile\b", "mutes a game sound"),
    ("UnmuteSoundFile", r"\bUnmuteSoundFile\b", "unmutes a game sound"),
    ("PlaySoundFile", r"\bPlaySoundFile\b", "plays a sound file"),
    ("PlaySound", r"\bPlaySound\b", "plays a sound"),
    ("ShowMacroFrame", r"\bShowMacroFrame\b", "opens Blizzard's macro window"),
    ("MacroFrame", r"\bMacroFrame\s*[.:]", "reaches into Blizzard's macro window"),
    ("UIErrorsFrame", r"\bUIErrorsFrame\s*:", "puts a line in the game's red error text"),
    ("OpenToCategory", r"\bOpenToCategory\b", "opens Blizzard's settings panel"),
    ("GameTooltip", r"\bGameTooltip\s*:", "fills or hides the game tooltip"),
    ("UISpecialFrames", r"\bUISpecialFrames\b", "adds a frame to the list Escape closes"),
    ("StaticPopup", r"\bStaticPopup_Show\b", "shows a game popup"),
    ("SetCVar", r"\bSetCVar\b", "changes a game setting (CVar)"),
    ("SetBinding", r"\b(?:SetBinding\w*|SaveBindings)\b", "changes a key binding"),
    ("override binding", r"\b(?:SetOverrideBinding\w*|ClearOverrideBindings)\b", "binds or frees a key while the addon runs"),
    ("UIPanel", r"\b(?:Show|Hide|Toggle)UIPanel\b", "opens or closes one of Blizzard's panels"),
    ("ReloadUI", r"\bReloadUI\b", "reloads the UI"),
    ("SendChatMessage", r"\bSendChatMessage\b", "sends a chat message"),
    ("SendAddonMessage", r"\bSendAddonMessage\b", "sends an addon message"),
    ("BINDING_NAME", r"\bBINDING_\w+\s*=(?!=)", "sets a key binding's label (a global)"),
    ("bag button", r"\bCharacter(?:Reagent)?Bag", "draws on one of Blizzard's bag buttons"),
    ("glow", r"\b\w+Glow_Start\b", "starts a glow on a button"),
    ("global", r'_G\[[^\]]+\]\s*=(?!=)|\bCreateFrame\(\s*"\w+"\s*,\s*"', "sets a global name"),
    ("slash", r":RegisterChatCommand\b", "registers a slash command"),
    # any attribute: type and macrotext say what a click does, and spell, item, unit, macro,
    # clickbutton and the rest say what it does it to
    ("secure", r':SetAttribute(?:NoHandler)?\(', "sets a secure button's action"),
    ("LibDBIcon", r'LibStub\(\s*"LibDBIcon-1\.0"', "hands LibDBIcon a table it writes into"),
    ("LibSharedMedia", r':Register\(\s*"(?:sound|font|statusbar|border|background)"', "adds media to the list every addon shares"),
]


def check_acts_on():
    """Acts on is the truth: every thing on the ACTS list a file's code does is named in its
    header's "Acts on" field by the list's word for it, and no "Acts on" names a call the
    code no longer makes. So "what touches the bags?" is answered by the headers, and a
    file cannot start deleting, moving, muting or writing a global without saying so."""
    print("== acts on")
    ok = True
    count = 0
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        lines = bare_code(read(rel))
        field = header_fields(rel).get("Acts on", "")
        for word, pattern, what in ACTS:
            at = next((n for n, code in lines if re.search(pattern, code)), None)
            does = at is not None
            # the word standing alone or as the start of a longer name (BINDING_NAME_SSF_DELETE),
            # never inside another word (PlaySound in PlaySoundFile)
            named = re.search(r"(?<![A-Za-z])" + re.escape(word) + r"(?![A-Za-z])", field) is not None
            count += does
            if does and not named:
                print(f"   {rel}:{at}: {what}, Acts on does not say \"{word}\"")
                ok = False
            elif named and not does and re.match(r"[A-Z]\w+$", word):
                print(f"   {rel}: Acts on names {word}, the code never does it")
                ok = False
    print(f"   {count} acts named, " + ("ok" if ok else "FAILED"))
    return ok


# ---------------------------------------------------------------- hooks and scripts

HOOK_START_RE = re.compile(r"(?:(?<![\w.:])(hooksecurefunc)|:((?:Secure|Raw)?Hook(?:Script)?))\(")
HOOK_ARG1_RE = re.compile(r"\s*([^,()]+?)\s*[,)]")
HOOK_ARG2_RE = re.compile(r'\s*"(\w+)"')
# how a Hooks field names a hook: Owner.Method (AceConfigDialog.Open) or Owner's Script
# (MacroFrame's OnHide). `AceConfigDialog.tooltip's OnShow` names OnShow on tooltip. Each
# match: (owner, method) or (owner, script).
HOOK_CLAIM_RE = re.compile(r"([\w.]*\w)\.(\w+)\b(?!'s)|([\w.]*\w)'s\s+(\w+)")
SETSCRIPT_RE = re.compile(r"((?:\w+\.)*(\w+)):SetScript\(\s*(\"(\w+)\")?")


def owner_word(owner):
    """The last word of an owner, the way the code and the header can both name it:
    MacroFrame.MacroSelector -> macroselector, AceConfigDialog.tooltip -> tooltip."""
    return re.split(r"[.:]", owner)[-1].lower()


def code_text(rel):
    """A file's code with every comment blanked and every line kept, so a place in it is a
    line number in the file."""
    return "\n".join("" if l.lstrip().startswith("--") else strip_comment(l)
                     for l in blank_block_comments(read(rel)).splitlines())


def hooks_made(code):
    """[(line, the hooked name or None when it cannot be read, the raw call's word or None,
    the owner as the code writes it or None for a global function)] for every hook the code
    makes. AceHook's forms: Hook(object, "Method", ...), Hook("GlobalFunction", ...),
    HookScript(frame, "OnScript", ...). Raw: hooksecurefunc in either form, and a frame's
    own frame:HookScript("OnScript", ...)."""
    out = []
    for m in HOOK_START_RE.finditer(code):
        line = code[: m.start()].count("\n") + 1
        word = m.group(1) or m.group(2)
        a1 = HOOK_ARG1_RE.match(code, m.end())
        if not a1:
            out.append((line, None, None, None))
            continue
        first = a1.group(1)
        quoted = re.fullmatch(r'"(\w+)"', first)
        a2 = HOOK_ARG2_RE.match(code, a1.end()) if code[a1.end() - 1] == "," else None
        if quoted:
            raw = word if word in ("hooksecurefunc", "HookScript") else None
            # a frame's own HookScript: the owner is the frame before the colon
            before = re.search(r"([\w.]+)$", code[: m.start()]) if word == "HookScript" else None
            out.append((line, quoted.group(1), raw, before.group(1) if before else None))
        elif a2:
            out.append((line, a2.group(1), word if word == "hooksecurefunc" else None, first))
        else:
            out.append((line, None, None, None))
    return out


def frames_made(code):
    """The names this file gives frames it creates, written out in full (`self.button`,
    `frame`): `name = CreateFrame(`, and `name = Maker(` where Maker is a local function of
    the file that calls CreateFrame. In full, so a stock widget's `inner.frame` is not this
    file's `frame`."""
    lines = code.splitlines()
    makers = set()
    for i, line in enumerate(lines):
        m = re.match(r"(\s*)local function (\w+)\(", line)
        if not m:
            continue
        if re.search(r"\bend\s*$", line):  # a one-line function
            body = [line]
        else:
            body = []
            for nxt in lines[i + 1:]:
                e = re.match(r"(\s*)end\b", nxt)
                if e and e.group(1) == m.group(1):
                    break
                body.append(nxt)
        if any("CreateFrame(" in b for b in body):
            makers.add(m.group(2))
    calls = "|".join(["CreateFrame"] + sorted(re.escape(n) for n in makers))
    made = {own_frame(n) for n in re.findall(r"(?<![\w.:])((?:\w+\.)*\w+)\s*=\s*(?:" + calls + r")\(", code)}
    # and kept under another name: `self.actionbutton = actionbutton`, `widget.button = button`
    for _ in range(3):
        for lhs, rhs in re.findall(r"(?m)^\s*(?:local\s+)?((?:\w+\.)*\w+)\s*=\s*((?:\w+\.)*\w+)\s*$", code):
            if own_frame(rhs) in made:
                made.add(own_frame(lhs))
    return made


def own_frame(expr):
    """A frame's name as frames_made keeps it: in a widget file `self` (in its methods) and
    `widget` (in its constructor) are the same table, so both read as self."""
    return re.sub(r"^(?:self|widget)\.", "self.", expr)


def check_hooks():
    """Hooks is the truth, both ways: every hook the code makes is named under Hooks as
    Owner.Method or Owner's Script, and every hook written there that way is one the code
    makes, on the owner Hooks names (its last word, so MacroSelector.RunSetup is the code's
    MacroFrame.MacroSelector). A raw hook (hooksecurefunc, a frame's own HookScript) is allowed one at a time:
    Exceptions names the raw call once per hook, and what each one is on. And a script set
    on a frame the file did not create (SetScript replaces whatever was there) is named
    under Acts on, with the word SetScript and the script; an Acts on that says SetScript
    with no such call in the code fails too. "Created" goes by the full name within the file
    (frames_made), not by scope: a second local of the same full name as a created frame
    passes, a stock widget's inner.frame does not."""
    print("== hooks")
    ok = True
    count = 0
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        code = code_text(rel)
        fields = header_fields(rel)
        problems = []

        def named(word, where):
            return re.search(r"(?<![A-Za-z])" + re.escape(word) + r"(?![A-Za-z])", where) is not None

        made = hooks_made(code)
        count += len(made)
        owners = {}  # hooked name -> the owners the header names it on
        for o1, n1, o2, n2 in HOOK_CLAIM_RE.findall(fields.get("Hooks", "")):
            name, owner = n1 or n2, o1 or o2
            if name[0].isupper():  # a method or a script, never a field (.tooltip)
                owners.setdefault(name, set()).add(owner_word(owner))
        claims = set(owners)
        for line, name, _, owner in made:
            if name is None:
                problems.append(f"{rel}:{line}: cannot read what this hook is on; write its name as a quoted string")
            elif name not in claims:
                problems.append(f"{rel}:{line}: the code hooks {name}, Hooks does not name it "
                                f"(write it as Owner.{name} or Owner's {name})")
            elif owner and owner_word(owner) not in owners[name]:
                problems.append(f"{rel}:{line}: the code hooks {name} on {owner}, Hooks names it on "
                                f"{' or '.join(sorted(owners[name]))}: name the owner the code hooks")
        for name in sorted(claims - {name for _, name, _, _ in made}):
            problems.append(f"{rel}: Hooks names {name}, the code never hooks it")

        # raw hooks, one at a time
        exceptions = fields.get("Exceptions", "")
        seen = {}
        for line, name, raw, _ in made:
            if not raw:
                continue
            seen[raw] = seen.get(raw, 0) + 1
            if len(re.findall(r"\b" + raw + r"\b", exceptions)) < seen[raw] or not named(name, exceptions):
                problems.append(f"{rel}:{line}: raw hook {raw} on {name}: use AceHook, or name it under "
                                f"Exceptions ({raw} once per raw hook, and {name})")

        # a script set on a frame this file did not create
        mine = frames_made(code)
        acts = fields.get("Acts on", "")
        foreign = False
        for m in SETSCRIPT_RE.finditer(code):
            line = code[: m.start()].count("\n") + 1
            if own_frame(m.group(1)) in mine:
                continue
            foreign = True
            script = m.group(4)
            if script is None:
                problems.append(f"{rel}:{line}: cannot read which script is set on {m.group(1)}; write it as a quoted string")
            elif not (named("SetScript", acts) and named(script, acts)):
                problems.append(f"{rel}:{line}: sets {script} on a frame this file did not create ({m.group(1)}); "
                                f"Acts on does not say SetScript and {script}")
        if named("SetScript", acts) and not foreign:
            problems.append(f"{rel}: Acts on names SetScript, the code sets no script on a frame it did not create")

        for p in problems:
            print(f"   {p}")
            ok = False
    print(f"   {count} hooks named, " + ("ok" if ok else "FAILED"))
    return ok


# ---------------------------------------------------------------- public truth

MODULE_DECL_RE = re.compile(r'^local\s+(\w+)\s*=\s*[^\n]*?:New(Module|Addon)\(\s*"(\w+)"([^)\n]*)\)', re.M)
DIRECT_CALL_RE = re.compile(GM_CALL + r'\s*([:.])\s*(\w+)')
ALIAS_RHS_RE = re.compile(r'^[\w.:()"\-\s]*?' + GM_CALL + r'$')
GM_START_RE = re.compile(r'GetModule\s*\(')
GM_AT_RE = re.compile(GM_ANY + r'(\s*[:.])?')
VALUE_ALIAS_RE = re.compile(r'^\s*local\s+(\w+(?:\s*,\s*\w+)*)\s*=\s*(.+)$')
FUNC_ALIAS_RE = re.compile(r'^\s*local\s+function\s+(\w+)\(\)\s*return\s+[\w.:()"\-\s]*?' + GM_CALL + r'\s*end\s*$')
ADDON_USE_RE = re.compile(r'(?:(?<![\w.:])SSF|GetAddon\(\s*"SSF"\s*\))\s*([:.])\s*(\w+)')
ADDON = "SSF"            # the addon object's name: Core's Public is checked under it
SHARED_STATE = "db"      # the AceDB profile: every module reads it, so the map leaves it out


def strip_comment(line):
    """One source line without its trailing comment (a `--` outside a quoted string)."""
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif line.startswith("--", i):
            return line[:i]
        i += 1
    return line


def blank_strings(code):
    """One code line with the inside of every quoted string emptied, so words in a string
    ("SSF: Bag thunk") are not read as code."""
    return re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', code)


BLOCK_COMMENT_RE = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)


def blank_block_comments(text):
    """Source with every Lua block comment (--[[ ... ]], --[==[ ... ]==]) emptied and its
    line breaks kept, so code disabled in one is not read as live and line numbers stay
    true."""
    return BLOCK_COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def bare_code(text):
    """Source with block comments and comment-only lines dropped and trailing comments cut,
    line numbers kept: [(line number, code)]."""
    out = []
    for n, line in enumerate(blank_block_comments(text).splitlines(), 1):
        if line.lstrip().startswith("--"):
            continue
        out.append((n, strip_comment(line).rstrip()))
    return out


def module_registry():
    """name -> (file, the local the file holds it in, its mixin libraries): Core's addon
    object under "SSF", and every module a code file makes with NewModule."""
    reg = {}
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        for var, _, name, mixins in MODULE_DECL_RE.findall(read(rel)):
            reg[name] = (rel, var, re.findall(r'"([\w.-]+)"', mixins))
    return reg


def public_names(rel, var):
    """The names a header lists under Public: every identifier followed at once by `(`, and
    every `<var>.<FIELD>` (with the bare ALL_CAPS names that follow it in the same list),
    that stands outside any bracket and outside a quoted string. A name qualified by
    another module (`Window:ShowNote(`) is a mention, not a listing."""
    text = re.sub(r'"[^"]*"', '""', header_fields(rel).get("Public", ""))
    names, depth, i = set(), 0, 0
    name_re = re.compile(r"(?:(\w+)[:.])?(\w+)\(")
    # var None: a widget, which has no object name to qualify a field with
    field_re = re.compile(re.escape(var or "\0") + r"\.(\w+)(?![\w(])((?:\s*,\s*(?:and\s+)?[A-Z][A-Z0-9_]*\b(?![.(:]))*)")
    while i < len(text):
        c = text[i]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        elif depth == 0 and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] in "_.:")):
            m = field_re.match(text, i)
            if m:
                names.add(m.group(1))
                names.update(re.findall(r"[A-Z][A-Z0-9_]*", m.group(2)))
                i = m.end()
                continue
            m = name_re.match(text, i)
            if m:
                if m.group(1) in (None, var):
                    names.add(m.group(2))
                i = m.end() - 1
                continue
        i += 1
    return names


def defined_names(rel, var):
    """The names a module's file defines on its object: `function <var>:X(`, `function
    <var>.X(`, and `<var>.X =` or `self.X =`."""
    text = "\n".join(code for _, code in bare_code(read(rel)))
    v = re.escape(var)
    names = set(re.findall(r"\bfunction\s+" + v + r"[:.](\w+)\s*\(", text))
    # `<var>.X =`, and each name of `<var>.X, <var>.Y = 1, 2`
    names |= set(re.findall(r"(?<![\w.:])(?:" + v + r"|self)\.(\w+)(?=\s*(?:,\s*[\w.]+\s*)*=(?!=))", text))
    return names


def ace_names(mixins):
    """Every function name AceAddon and the named mixin libraries define: what an addon or
    module object answers without its own file defining it."""
    names = set()
    for lib in ["AceAddon-3.0"] + list(mixins):
        folder = os.path.join(ROOT, "Libs", lib)
        if not os.path.isdir(folder):
            continue
        for fn in os.listdir(folder):
            if fn.endswith(".lua"):
                names |= set(re.findall(r"\bfunction\s+(?:\w+[:.])?(\w+)\s*\(", read(f"Libs/{lib}/{fn}")))
    return names


def module_uses(rel, reg):
    """Every use one file makes of another module's object or of the addon object:
    [(module, name, line)], and the problems met resolving them. A use is
    `GetModule("M"):X` / `.X`, the same through a local alias (`local Bags =
    SSF:GetModule("Bags")`, or `local function Cap() return SSF:GetModule("Cap") end` used
    as `Cap():Get()`), and `SSF:X` / `SSF.X`. An alias is taken file-wide, so one name
    standing for two things in one file is a problem."""
    own = {name for name, (r, _, _) in reg.items() if r == rel}
    own_vars = {var for _, (r, var, _) in reg.items() if r == rel}
    lines = bare_code(read(rel))
    value_alias, func_alias, problems = {}, {}, []

    def learn(table, other, alias, mod, n):
        if alias in own_vars or alias in other or table.get(alias, mod) != mod:
            problems.append(f"{rel}:{n}: the local {alias} stands for more than one thing; give each module's alias its own name")
        table[alias] = mod

    for n, code in lines:
        aliased = False
        m = FUNC_ALIAS_RE.match(code)
        if m:
            learn(func_alias, value_alias, m.group(1), m.group(2), n)
            aliased = True
        m = not aliased and VALUE_ALIAS_RE.match(code)
        if m:
            names = [x.strip() for x in m.group(1).split(",")]
            values = [x.strip() for x in re.split(r",(?![^()]*\))", m.group(2))]
            for alias, value in zip(names, values):
                am = ALIAS_RHS_RE.match(value)
                if am:
                    learn(value_alias, func_alias, alias, am.group(1), n)
                    aliased = True
        # every module the code asks for is one the check can follow: named in quotes, and
        # called at once or kept in a local alias. A module object kept in a global, a field
        # or a table, or handed around, is a use nothing here can see.
        for start in GM_START_RE.finditer(code):
            at = GM_AT_RE.match(code, start.start())
            if not at:
                problems.append(f"{rel}:{n}: GetModule with no quoted module name; name the module, \"Bags\", so the check can follow it")
            elif not at.group(1) and not aliased:
                problems.append(f"{rel}:{n}: a module object kept anywhere but a local alias (local Bags = SSF:GetModule(\"Bags\")); the check cannot follow it")
    uses = []
    for n, code in lines:
        for mod, _, name in DIRECT_CALL_RE.findall(code):
            uses.append((mod, name, n))
        code = blank_strings(code)
        for alias, mod in value_alias.items():
            for name in re.findall(r"(?<![\w.:])" + re.escape(alias) + r"\s*[:.]\s*(\w+)", code):
                uses.append((mod, name, n))
        for alias, mod in func_alias.items():
            for name in re.findall(r"(?<![\w.:])" + re.escape(alias) + r"\(\)\s*[:.]\s*(\w+)", code):
                uses.append((mod, name, n))
        if ADDON not in own:
            for _, name in ADDON_USE_RE.findall(code):
                uses.append((ADDON, name, n))
    return [u for u in uses if u[0] not in own], problems


def resolved_calls():
    """(calls, problems). calls: caller file -> {module: names it uses}, every one checked:
    the module exists, its file defines the name, and its header lists the name under
    Public. A name the addon or module object gets from AceAddon or a mixin library
    (Print, IsEnabled, GetModule) is the library's, not a module's Public, and is left out.
    problems also holds every name a Public lists that its file does not define, and every
    method a test's stand-in module defines that the real module's Public does not have."""
    reg = module_registry()
    public = {name: public_names(rel, var) for name, (rel, var, _) in reg.items()}
    defined = {name: defined_names(rel, var) for name, (rel, var, _) in reg.items()}
    ace = {name: ace_names(mixins) for name, (_, _, mixins) in reg.items()}
    calls, problems = {}, []
    for name, (rel, _, _) in sorted(reg.items()):
        for missing in sorted(public[name] - defined[name]):
            problems.append(f"{rel}: Public lists {missing}, the file does not define it")
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        uses, bad = module_uses(rel, reg)
        problems += bad
        for mod, name, n in uses:
            if mod not in reg:
                problems.append(f"{rel}:{n}: GetModule(\"{mod}\"): no file makes that module")
            elif name in defined[mod] and name in public[mod]:
                calls.setdefault(rel, {}).setdefault(mod, set()).add(name)
            elif name in defined[mod]:
                problems.append(f"{rel}:{n}: uses {mod}:{name}, which {reg[mod][0]} does not list under Public")
            elif name in public[mod]:
                pass  # listed and not defined: reported once above, under the module's own file
            elif name not in ace[mod]:
                problems.append(f"{rel}:{n}: uses {mod}:{name}, which {reg[mod][0]} does not define")
    # the tests' stand-in modules: SSF:NewModule("Window") in a test file fakes the real one
    for rel in [f for f in lua_files() if f.startswith("tests/")]:
        text = "\n".join(code for _, code in bare_code(read(rel)))
        for var, _, mod, _ in MODULE_DECL_RE.findall(text):
            if mod not in reg:
                continue
            fake = set(re.findall(r"\bfunction\s+" + re.escape(var) + r"[:.](\w+)\s*\(", text))
            fake |= set(re.findall(r"(?<![\w.:])" + re.escape(var) + r"\.(\w+)\s*=(?!=)", text))
            for name in sorted(fake - (public[mod] & defined[mod])):
                problems.append(f"{rel}: its stand-in {mod} defines {name}, which is not a Public method of {reg[mod][0]}")
        # the same for a test that replaces methods on the real module for its own run:
        # `local Window = SSF:GetModule("Window")` then `function Window:InFight()`
        for line in text.splitlines():
            m = VALUE_ALIAS_RE.match(line)
            am = m and "," not in m.group(1) and ALIAS_RHS_RE.match(m.group(2).strip())
            if not am or am.group(1) not in reg:
                continue
            var, mod = m.group(1).strip(), am.group(1)
            swapped = set(re.findall(r"\bfunction\s+" + re.escape(var) + r"[:.](\w+)\s*\(", text))
            swapped |= set(re.findall(r"(?<![\w.:])" + re.escape(var) + r"\.(\w+)\s*=\s*function\b", text))
            for name in sorted(swapped - (public[mod] & defined[mod])):
                problems.append(f"{rel}: replaces {mod}:{name} for its tests, which is not a Public method of {reg[mod][0]}")
    widget_calls, widget_problems = resolved_widget_calls()
    for rel, types in widget_calls.items():
        calls.setdefault(rel, {}).update(types)
    return calls, problems + widget_problems


WIDGET_TYPE_RE = re.compile(r'\blocal\s+Type\s*,\s*Version\s*=\s*"(\w+)"')
WIDGET_METHOD_RE = re.compile(r'\[\s*"(\w+)"\s*\]\s*=(?!=)|\bwidget\.(\w+)\s*=(?!=)')
WIDGET_CREATE_RE = re.compile(r'^\s*(?:local\s+)?([\w.]+)\s*=\s*[\w.:()"\-\s]*:Create\(\s*"(\w+)"\s*\)$')
WIDGET_HANDOVER_RE = re.compile(r'^\s*(self\.\w+)\s*=\s*(\w+)$')
WIDGET_LOOP_RE = re.compile(r'\bfor\s+_\s*,\s*(\w+)\s+in\s+ipairs\(\s*\{([^}]*)\}\s*\)')
ACEGUI = "Libs/AceGUI-3.0"


def widget_registry():
    """widget type -> the Widgets file that registers it (`local Type, Version = "SSFFrame", 4`)."""
    reg = {}
    for rel in [f for f in lua_files() if f.startswith("Widgets/")]:
        for name in WIDGET_TYPE_RE.findall(read(rel)):
            reg[name] = rel
    return reg


def widget_defined(rel):
    """The method names a widget file defines: every `["Name"] =` of a methods table and
    every `widget.Name =`. A file with several widget types answers for all of them at once."""
    text = "\n".join(code for _, code in bare_code(read(rel)))
    return {a or b for a, b in WIDGET_METHOD_RE.findall(text)}


def acegui_method_names(text):
    """The method names one AceGUI file defines, in the three ways its files write them."""
    names = set(re.findall(r'\[\s*"(\w+)"\s*\]\s*=\s*function', text))
    names |= set(re.findall(r"\bfunction\s+\w+[:.](\w+)\s*\(", text))
    return names | set(re.findall(r"\b\w+\.(\w+)\s*=\s*function", text))


def core_names():
    """The method names AceGUI's core gives every widget (IsShown, SetCallback, Fire,
    AddChild): the files directly in Libs/AceGUI-3.0, not the stock widgets under widgets/."""
    names = set()
    folder = os.path.join(ROOT, ACEGUI)
    for fn in os.listdir(folder):
        if fn.endswith(".lua"):
            names |= acegui_method_names(open(os.path.join(folder, fn), encoding="utf-8", errors="replace").read())
    return names


def stock_names(home):
    """The method names an SSF widget answers without its own file defining them: what
    AceGUI's core gives every widget (SetCallback, Fire, AddChild), plus the methods of each
    stock widget the file builds on (the types it creates: SSFFrame creates "Frame", so
    Hide and SetTitle). A stock widget the file does not create lends it nothing, so a
    name is never excused by some unrelated widget happening to have it."""
    built_on = set(re.findall(r':Create\(\s*"(\w+)"\s*\)', read(home)))
    names = set()
    for folder, _, files in os.walk(os.path.join(ROOT, ACEGUI)):
        for fn in files:
            if not fn.endswith(".lua"):
                continue
            text = open(os.path.join(folder, fn), encoding="utf-8", errors="replace").read()
            core = os.path.samefile(folder, os.path.join(ROOT, ACEGUI))  # not under widgets/
            if not core and not built_on & set(re.findall(r'\bType\b[^\n=]*=\s*"(\w+)"', text)):
                continue
            names |= acegui_method_names(text)
    return names


def widget_uses(rel, types):
    """Every method one file calls on an SSF widget it created: [(type, name, line)]. The
    widget is known by what holds it: the target of `x = AceGUI:Create("SSFFrame")` (a local
    or `self.window`), a `self.name = x` that hands such a local on, and the loop variable
    of `for _, v in ipairs({ a, b })` over widgets of one type. Taken file-wide."""
    lines = bare_code(read(rel))
    held = {}
    for _, code in lines:
        m = WIDGET_CREATE_RE.match(code)
        if m and m.group(2) in types:
            held[m.group(1)] = m.group(2)
    for _, code in lines:
        m = WIDGET_HANDOVER_RE.match(code)
        if m and m.group(2) in held:
            held[m.group(1)] = held[m.group(2)]
    for _, code in lines:
        for var, items in WIDGET_LOOP_RE.findall(code):
            kinds = {held.get(item.strip()) for item in items.split(",")}
            if len(kinds) == 1 and None not in kinds:
                held[var] = kinds.pop()
    uses = []
    for n, code in lines:
        code = blank_strings(code)
        for expr, kind in held.items():
            for name in re.findall(r"(?<![\w.:])" + re.escape(expr) + r"\s*:\s*(\w+)\s*\(", code):
                uses.append((kind, name, n))
    return uses


def resolved_widget_calls():
    """(calls, problems) for the widgets, which are AceGUI method tables and not modules.
    Every name a widget's Public writes with its arguments (`FitWidth()`, the widget's own;
    the stock methods it passes through are listed bare) is one its file defines. Every
    method a file calls on an SSF widget it created is either one the widget's file defines
    and its Public names, or one AceGUI itself defines. No widget defines a method AceGUI's
    core already gives every widget (a copy hides a rename: the call falls through to
    AceGUI's and passes). calls: caller file -> {widget type:
    the widget's own methods it calls}. A widget AceConfigDialog drives through
    `dialogControl` has no caller in SSF's code and is checked one way only."""
    types = widget_registry()
    stock = {rel: stock_names(rel) for rel in set(types.values())}
    core = core_names()
    defined = {rel: widget_defined(rel) for rel in set(types.values())}
    calls, problems = {}, []
    for rel in sorted(defined):
        for missing in sorted(public_names(rel, None) - defined[rel]):
            problems.append(f"{rel}: Public lists {missing}(), the file does not define it")
        # no copy of what AceGUI already gives: a widget's method may share a name only with
        # the stock widget it builds on, where it replaces that method on purpose (SetLabel,
        # OnAcquire: the names AceConfigDialog and AceGUI call)
        for name in sorted(defined[rel] & core):
            problems.append(f"{rel}: defines {name}, which AceGUI's core already gives every widget; use AceGUI's, or pick a name of its own")
    for rel in [f for f in lua_files() if not f.startswith("tests/")]:
        for kind, name, n in widget_uses(rel, types):
            home = types[kind]
            if name in defined[home]:
                if re.search(r"\b" + re.escape(name) + r"\b", header_fields(home).get("Public", "")):
                    calls.setdefault(rel, {}).setdefault(kind, set()).add(name)
                else:
                    problems.append(f"{rel}:{n}: calls {kind}:{name}, which {home} does not list under Public")
            elif name not in stock[home]:
                problems.append(f"{rel}:{n}: calls {kind}:{name}, which neither {home} nor AceGUI defines")
    return calls, problems


def check_public_truth():
    """Public is the truth: every use of another module (and of the addon object) names
    something that module's file defines and its header lists under Public; every name a
    Public lists is defined; a test's stand-in for a module only fakes that module's Public.
    So a renamed or removed public method fails here, not in game. The widgets are held to
    the same through resolved_widget_calls."""
    print("== public truth")
    calls, problems = resolved_calls()
    for p in problems:
        print("   " + p)
    count = sum(len(names) for mods in calls.values() for names in mods.values())
    print(f"   {count} uses of another file's Public, " + ("ok" if not problems else "FAILED"))
    return not problems


# ---------------------------------------------------------------- rules luacheck cannot see

def constants(code):
    """[(name, value)] for every `local NAME = <literal>` in a file's code (comments already
    blanked): a number, a string or a table, at any depth of indentation, a table over as
    many lines as it takes. The value comes back with its whitespace removed, so the same
    table laid out two ways is one value. An empty table is not a value (it is state to be
    filled) and is left out."""
    out = []
    lines = code.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"\s*local\s+([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$", lines[i])
        if m:
            name, value = m.groups()
            while value.startswith("{") and value.count("{") > value.count("}") and i + 1 < len(lines):
                i += 1
                value += lines[i].strip()
            value = re.sub(r"\s+", "", value)
            if re.fullmatch(r'-?\d[\d.]*|"[^"]*"|\{.+\}', value):
                out.append((name, value))
        i += 1
    return out


COMBAT_HOMES = {"Modules/Combat.lua", "Modules/Debug.lua"}  # who may call the game's two combat functions
# the pause setting's own get and apply in Options, the only lines besides Trimmer's gate
# that may touch profile.paused
PAUSE_SETTING_LINE = re.compile(r"^\s*(get = function\(\) return SSF\.db\.profile\.paused end|"
                                r"apply = function\(value\) SSF\.db\.profile\.paused = value end),\s*$")

# a function of a module: `function M:Name(...)` up to the `end` at the start of a line,
# or all on one line
MODULE_FUNC_RE = re.compile(r"^function \w+[:.](\w+)\([^)]*\)(.*?)^end\b|^function \w+[:.](\w+)\([^)]*\)(.*?)\bend\s*$",
                            re.M | re.S)
# one statement that only calls another module: `SSF:GetModule("X"):Y(...)` or a local alias
# of one (`Cap():Get()`), returned or not
FORWARD_RE = re.compile(r'^(?:return\s+)?(?:SSF:' + GM_ANY + r'|[A-Z]\w*\(\))\s*[:.]\s*\w+\(.*\)$', re.S)
SETUP_FUNCS = {"OnInitialize", "OnEnable", "OnDisable"}


def pass_through(code):
    """True when every function of the module (its set-up ones aside) is a single statement
    that only calls another module: a file that adds nothing but a hop."""
    bodies = []
    for m in MODULE_FUNC_RE.finditer(code):
        name, body = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
        if name in SETUP_FUNCS:
            continue
        bodies.append(" ".join(l.strip() for l in body.splitlines() if l.strip()))
    return bool(bodies) and all(FORWARD_RE.match(b) for b in bodies)


def check_rules():
    """No module is only a pass-through (every function a single call into another module);
    every widget type registered is used; the shard id is typed in Core only (the locale files' comments included); every
    message a module listens for is sent by some module; and the same ALL_CAPS local with
    the same literal in two files is one value with two homes (or two things that need two
    names)."""
    print("== rules")
    ok = True
    code_files = [f for f in lua_files() if not f.startswith("tests/")]
    texts = {rel: read(rel) for rel in code_files}
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
    # "in combat" is asked of Combat: the game's two calls are typed there and nowhere else
    # (Debug writes both raw answers into its record and decides nothing by them)
    for rel in code_files:
        if rel in COMBAT_HOMES:
            continue
        for n, code in bare_code(texts[rel]):
            m = re.search(r"\b(InCombatLockdown|UnitAffectingCombat)\b", blank_strings(code))
            if m:
                print(f"   {rel}:{n}: {m.group(1)} is typed here; ask Combat (Locked or InFight)")
                ok = False
    # no pass-through module: a file whose every function only calls another module is a hop
    # a cold reader has to follow for nothing; its callers should ask the other module
    for rel in code_files:
        if rel.startswith("Modules/") and pass_through(code_text(rel)):
            print(f"   {rel}: every function only calls another module; a file that adds nothing "
                  f"but a hop (its callers should ask that module, or it should own a rule)")
            ok = False
    # "paused" is asked of Trimmer:Paused, the one pause gate: the saved key is read only
    # there and in the pause setting's own get and apply (Options), so a new meaning of
    # pause in the gate reaches every reader
    for rel in code_files:
        for n, code in bare_code(texts[rel]):
            if not re.search(r"\bprofile\.paused\b", code):
                continue
            if rel == "Modules/Trimmer.lua" or (rel == "Modules/Options.lua" and PAUSE_SETTING_LINE.search(code)):
                continue
            print(f"   {rel}:{n}: profile.paused is read here; ask Trimmer:Paused, the pause gate")
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
        for name, value in constants(code_text(rel)):
            homes.setdefault((name, value), []).append(rel)
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


def toc_files():
    files = []
    for line in open(TOC, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        files.append(line.replace("\\", "/"))
    return files


def code_lines(text):
    """Source lines with block comments and comment-only lines dropped, so a commented-out
    call does not count."""
    return "\n".join(l for l in blank_block_comments(text).splitlines() if not l.lstrip().startswith("--"))


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
    news = [f for f in lua if f.startswith("News/")]

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

    def file_entry(rel):
        """The file's job line, then its header's Public, so the map is also an index of
        what each file offers the others."""
        entry = f"- {rel.replace('/', chr(92))}: {header_job(rel)}"
        public = " ".join(header_fields(rel).get("Public", "").split())
        return entry + (f"\n  Public: {public}" if public else "")

    out.append("## Files, in load order\n")
    out.append("Each file's job line, then what it offers the others (its header's Public).\n")
    out.append("Widgets (custom AceGUI widgets, used from the options table through dialogControl, or")
    out.append("created by Window and by each other):\n")
    for rel in widgets:
        out.append(file_entry(rel))
    out.append("\nCore and modules:\n")
    for rel in core_mods:
        out.append(file_entry(rel))
    out.append("\nLocales:\n")
    for rel in locales:
        if rel.endswith("Register.lua"):
            out.append(f"- {rel.replace('/', chr(92))}: {header_job(rel)}")
    others = [module_name(r) for r in locales if not r.endswith("Register.lua")]
    out.append(f"- Locales\\<code>.lua: the string tables, one per locale: {', '.join(others)}.")
    if news:
        out.append("\nNews:\n")
        for rel in news:
            if rel.endswith("/News.lua"):
                out.append(f"- {rel.replace('/', chr(92))}: {header_job(rel)}")
        others = [module_name(r)[len(NEWS_PREFIX):] for r in news if not r.endswith("/News.lua")]
        out.append(f"- News\\News_<code>.lua: the current announcement's lines, one per locale: {', '.join(others)}.")

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

    out.append("\n## What acts on the game\n")
    out.append("Every file that does something to the game beyond its own frames and the profile, from")
    out.append("its code (the ACTS list in tools/check.py). Each file's header says the same under")
    out.append("\"Acts on\", with the why; the check fails when the two differ.\n")
    out.append("| File | What it does |")
    out.append("|---|---|")
    for rel in widgets + core_mods:
        code = "\n".join(c for _, c in bare_code(read(rel)))
        acts = [what for _, pattern, what in ACTS if re.search(pattern, code)]
        if acts:
            out.append(f"| {module_name(rel)} | {'; '.join(acts)} |")

    out.append("\n## Calls between files (Public)\n")
    out.append("Who uses what of whom: every use of another module's Public, of an SSF widget's own")
    out.append("methods by the file that created it, and of the addon object's")
    out.append(f"({ADDON}, Core.lua; its {SHARED_STATE}, the shared profile, is left out). Rename or remove a name")
    out.append("on the right and the file on the left breaks; the check fails first.\n")
    out.append("| Caller | Uses |")
    out.append("|---|---|")
    calls, _ = resolved_calls()
    for mod, name in bindings_uses():  # the key bindings file calls modules too
        calls.setdefault(BINDINGS, {}).setdefault(mod, set()).add(name)
    for rel in widgets + core_mods + [BINDINGS]:
        mods = {m: sorted(n - {SHARED_STATE}) for m, n in calls.get(rel, {}).items()}
        parts = [f"{m}: {', '.join(names)}" for m, names in sorted(mods.items()) if names]
        if parts:
            out.append(f"| {module_name(rel)} | {'; '.join(parts)} |")

    out.append("")
    out.append(exceptions_tail())
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
    results = [check_luacheck(), check_tests(), check_window(), check_locales(), check_code_keys(), check_colors(), check_headers(),
               check_header_truth(), check_toc(), check_bindings(), check_exceptions(), check_acts_on(), check_hooks(), check_public_truth(), check_rules(), check_blizzard_api(), check_map(), check_libs()]
    ok = all(results)
    print("\nALL PASS" if ok else "\nCHECK FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
