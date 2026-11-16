#!/usr/bin/env python
"""tools/sync_libs.py: the embedded libraries against their upstream.

Job:    Libs/ is committed and ships as is (no packager externals). This script is the one
        way a library changes: it reads tools/externals.txt (the list the .pkgmeta externals
        block used to hold, in its syntax; url: and tag: are read, a branch: is taken as a
        tag, other keys are ignored), holds a copy of each library's upstream in tools/.sync/,
        and reports every file that differs from Libs/, is missing locally, or exists only
        locally. With --apply it makes Libs/ equal upstream, line endings aside (copies the
        first two kinds, deletes the third; a file that differs only in CRLF/LF is left
        alone), which is a deliberate library bump: in-game pass, then a commit of its own
        with a changelog line.
Speed:  the kept copy is downloaded again only when its upstream's version changed. The
        version is one small question per source (six sources for eighteen libraries), all
        asked at once: the revision number a repos.wowace.com folder listing states (their
        projects are Subversion; no Subversion client is needed to read the number), or
        the commit `git ls-remote` gives for a GitHub branch or tag. A library that does
        need fetching has its files downloaded at once, on threads. Measured 2026-11-16:
        17 s before (everything, one request after another), 2 s with nothing kept, under
        half a second on a normal run.
Takes:  --apply (copy upstream over Libs/; every library is downloaded fresh first, the
        kept copy is not trusted for a bump); --quiet (one line per library); --keep
        (accepted and does nothing: tools/.sync/ is always kept now, so a drifted file can
        always be diffed against its upstream copy, as the upkeep check does).
        Upstreams: a repos.wowace.com trunk folder (fetched file by file over HTTPS), or a
        GitHub repository (fetched as the zip of its default branch, or of `tag:`).
Writes: tools/.sync/ (ignored by git): one folder per library and versions.txt, the
        version each was fetched at. Deleting it costs one slower run. Libs/ only with
        --apply.
Exit:   0 in report mode, drift included (it is information, the check script prints it);
        1 only when an upstream could not be fetched with --apply.
Touches nothing else.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, "tools", "externals.txt")
KEPT = os.path.join(ROOT, "tools", ".sync")
VERSIONS = os.path.join(KEPT, "versions.txt")
TIMEOUT = 20
LIBRARIES_AT_ONCE = 18   # every library on the list can be in flight together
FILES_AT_ONCE = 32       # files of the libraries being fetched, shared between them

LINE_RE = re.compile(r"^\s*(Libs/[^:\s]+):\s*(\S+)?\s*$")
SUB_RE = re.compile(r"^\s+(url|tag|branch):\s*(\S+)\s*$")
WOWACE_PROJECT_RE = re.compile(r"(https://repos\.wowace\.com/wow/[^/]+)/")
REVISION_RE = re.compile(r"Revision (\d+)")


def read_list():
    """[(local path, url, tag)] from tools/externals.txt, .pkgmeta externals syntax: url: and
    tag: are read, branch: is stored as the tag, other keys are ignored."""
    out, cur = [], None
    for raw in open(LIST, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = LINE_RE.match(line)
        if m:
            cur = {"path": m.group(1), "url": m.group(2), "tag": None}
            out.append(cur)
            continue
        m = SUB_RE.match(line)
        if m and cur is not None:
            cur[m.group(1) if m.group(1) != "branch" else "tag"] = m.group(2)
    return [(e["path"], e["url"], e["tag"]) for e in out]


def http(url):
    req = urllib.request.Request(url, headers={"User-Agent": "SSF-sync-libs"})
    return urllib.request.urlopen(req, timeout=TIMEOUT).read()


def is_github(url):
    return "github.com" in url


def source_of(url):
    """What one version question covers: a wowace project (every trunk folder in it shares
    the project's revision number) or a GitHub repository."""
    m = WOWACE_PROJECT_RE.match(url)
    return m.group(1) if m else url.rstrip("/")


def version_of(url, tag):
    """The upstream's version from one small question, or None when it cannot be asked
    (offline): "r1424" from the revision a wowace folder listing states, or the commit a
    GitHub tag or default branch points at."""
    try:
        if is_github(url):
            ref = f"refs/tags/{tag}" if tag else "HEAD"
            proc = subprocess.run(["git", "ls-remote", url, ref], text=True, capture_output=True, timeout=TIMEOUT)
            words = proc.stdout.split()
            return words[0] if words else None
        m = REVISION_RE.search(http(url if url.endswith("/") else url + "/").decode("utf-8", "replace"))
        return "r" + m.group(1) if m else None
    except Exception:  # network, timeout, no git
        return None


def wowace_files(url, rel=""):
    """Every file under a trunk folder on repos.wowace.com, as (relative path, file url),
    read from the HTML listings."""
    if not url.endswith("/"):
        url += "/"
    out = []
    for href in re.findall(r'href="([^"?]+)"', http(url).decode("utf-8", "replace")):
        if "://" in href or href.startswith("/") or href == "../":
            continue
        if href.endswith("/"):
            out += wowace_files(url + href, rel + href)
        else:
            out.append((rel + href, url + href))
    return out


def fetch_wowace(url, dest, files):
    """A trunk folder on repos.wowace.com: the listings give the files, downloaded at once
    on the shared `files` pool."""
    def one(item):
        rel, file_url = item
        target = os.path.join(dest, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(http(file_url))
    os.makedirs(dest, exist_ok=True)
    list(files.map(one, wowace_files(url)))


def fetch_github(url, tag, dest):
    """A GitHub repository as a zip: the tag if given, else the default branch. The zip's
    single top folder is stripped; .git files and the repo's own packaging files are left out,
    as the packager leaves them out."""
    repo = re.sub(r"^https?://github\.com/", "", url).rstrip("/")
    if tag:
        zip_url = f"https://github.com/{repo}/archive/refs/tags/{tag}.zip"
    else:
        zip_url = f"https://github.com/{repo}/archive/HEAD.zip"
    data = http(zip_url)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for info in z.infolist():
            parts = info.filename.split("/", 1)
            if len(parts) < 2 or not parts[1] or info.is_dir():
                continue
            rel = parts[1]
            top = rel.split("/")[0]
            if top in (".git", ".github", ".pkgmeta", ".gitignore", ".gitattributes", ".editorconfig"):
                continue
            target = os.path.join(dest, rel.replace("/", os.sep))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "wb") as f:
                f.write(z.read(info))


def refresh(name, url, tag, files):
    """Download one library into tools/.sync/<name>, replacing the kept copy only once the
    whole download is in (a broken download leaves the old copy and its version alone).
    Returns None, or the reason it could not be fetched."""
    final, partial = os.path.join(KEPT, name), os.path.join(KEPT, name + ".partial")
    shutil.rmtree(partial, ignore_errors=True)
    try:
        if is_github(url):
            fetch_github(url, tag, partial)
        else:
            fetch_wowace(url, partial, files)
    except Exception as e:  # network, 404, bad zip
        shutil.rmtree(partial, ignore_errors=True)
        return f"{e.__class__.__name__}: {e}"
    shutil.rmtree(final, ignore_errors=True)
    os.replace(partial, final)
    return None


def read_versions():
    """name -> the version its kept copy was fetched at."""
    if not os.path.exists(VERSIONS):
        return {}
    return dict(line.split(None, 1) for line in open(VERSIONS, encoding="utf-8").read().splitlines() if " " in line)


def write_versions(versions):
    os.makedirs(KEPT, exist_ok=True)
    with open(VERSIONS, "w", encoding="utf-8", newline="\n") as f:
        for name in sorted(versions):
            f.write(f"{name} {versions[name]}\n")


def normalized(path):
    with open(path, "rb") as f:
        return f.read().replace(b"\r\n", b"\n")


def compare(local, upstream):
    """(differs, missing locally, local only) as lists of relative paths."""
    differs, missing, extra = [], [], []
    for root, _, files in os.walk(upstream):
        for fn in files:
            u = os.path.join(root, fn)
            rel = os.path.relpath(u, upstream)
            l = os.path.join(local, rel)
            if not os.path.exists(l):
                missing.append(rel)
            elif normalized(u) != normalized(l):
                differs.append(rel)
    for root, _, files in os.walk(local):
        for fn in files:
            l = os.path.join(root, fn)
            rel = os.path.relpath(l, local)
            if not os.path.exists(os.path.join(upstream, rel)):
                extra.append(rel)
    return sorted(differs), sorted(missing), sorted(extra)


def bring_up_to_date(libs, fresh):
    """Make tools/.sync/ hold each library's current upstream. Returns (failed, offline):
    name -> why it has no upstream copy at all, and the names compared with a kept copy
    because the upstream could not be asked. fresh: download every one, kept or not."""
    kept = read_versions()
    sources = {}
    for _, url, tag in libs:
        sources.setdefault(source_of(url), (url, tag))
    with ThreadPoolExecutor(len(sources) or 1) as pool:
        now = dict(zip(sources, pool.map(lambda s: version_of(*sources[s]), sources)))

    stale, offline = [], []
    for path, url, tag in libs:
        name = path.split("/", 1)[1]
        version = now[source_of(url)]
        have = os.path.isdir(os.path.join(KEPT, name))
        if version is None and have and not fresh:
            offline.append(name)  # cannot ask: the kept copy is the best there is
        elif fresh or not have or kept.get(name) != version:
            stale.append((name, url, tag, version))

    failed = {}
    with ThreadPoolExecutor(LIBRARIES_AT_ONCE) as lib_pool, ThreadPoolExecutor(FILES_AT_ONCE) as files:
        reasons = list(lib_pool.map(lambda item: refresh(item[0], item[1], item[2], files), stale))
    for (name, _, _, version), reason in zip(stale, reasons):
        if reason:
            failed[name] = reason
            if os.path.isdir(os.path.join(KEPT, name)):
                offline.append(name)  # the old copy is still there and still compared
        elif version:
            kept[name] = version
        else:
            kept.pop(name, None)  # fetched, version unknown: fetched again next run
    write_versions(kept)
    return failed, offline


def main(argv):
    apply_ = "--apply" in argv
    quiet = "--quiet" in argv
    libs = read_list()
    failed, offline = bring_up_to_date(libs, fresh=apply_)
    not_fetched, drifted = 0, 0
    for path, url, tag in libs:
        name = path.split("/", 1)[1]
        local = os.path.join(ROOT, path.replace("/", os.sep))
        up = os.path.join(KEPT, name)
        if name in failed and (apply_ or not os.path.isdir(up)):
            print(f"{name}: upstream not fetched ({failed[name]})")
            not_fetched += 1
            continue
        if not os.path.isdir(local):
            print(f"{name}: NOT EMBEDDED, upstream has it")
            drifted += 1
            if apply_:
                shutil.copytree(up, local)
                print(f"   copied in")
            continue
        differs, missing, extra = compare(local, up)
        if not differs and not missing and not extra:
            print(f"{name}: same as upstream")
            continue
        drifted += 1
        print(f"{name}: DRIFT, {len(differs)} differ, {len(missing)} missing locally, {len(extra)} local only")
        if not quiet:
            for rel in differs:
                print(f"   differs: {rel}")
            for rel in missing:
                print(f"   missing: {rel}")
            for rel in extra:
                print(f"   local only: {rel}")
        if apply_:
            for rel in differs + missing:
                src, dst = os.path.join(up, rel), os.path.join(local, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
            for rel in extra: # a file upstream dropped goes too: Libs/ equals upstream (line endings aside)
                os.remove(os.path.join(local, rel))
            print(f"   applied {len(differs) + len(missing)} file(s), removed {len(extra)}")
    if apply_ and not_fetched:
        return 1
    tail = f", {len(offline)} compared with a kept copy (upstream not reached)" if offline else ""
    print(f"libs: {drifted} drifted, {not_fetched} not fetched{tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
