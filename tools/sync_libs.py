#!/usr/bin/env python
"""tools/sync_libs.py: the embedded libraries against their upstream.

Job:    Libs/ is committed and ships as is (no packager externals). This script is the one
        way a library changes: it reads tools/externals.txt (the list the .pkgmeta externals
        block used to hold, same syntax), fetches each library from upstream into a scratch
        folder, and reports every file that differs from Libs/. With --apply it copies the
        upstream files over Libs/, which is a deliberate library bump: in-game pass, then a
        commit of its own with a changelog line.
Takes:  --apply (copy upstream over Libs/); --quiet (one line per library).
        Upstreams: a repos.wowace.com trunk folder (fetched file by file over HTTPS), or a
        GitHub repository (fetched as the zip of its default branch, or of `tag:`).
Writes: nothing without --apply. The scratch folder tools/.sync/ exists only while the
        script runs; it is removed at the end and ignored by git.
Exit:   0 always in report mode (drift is information, the check script prints it);
        1 only when an upstream could not be fetched with --apply.
Touches nothing else.
"""
import io
import os
import re
import shutil
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, "tools", "externals.txt")
SCRATCH = os.path.join(ROOT, "tools", ".sync")
TIMEOUT = 20

LINE_RE = re.compile(r"^\s*(Libs/[^:\s]+):\s*(\S+)?\s*$")
SUB_RE = re.compile(r"^\s+(url|tag|branch):\s*(\S+)\s*$")


def read_list():
    """[(local path, url, tag)] from tools/externals.txt, .pkgmeta externals syntax."""
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


def fetch_wowace(url, dest):
    """A trunk folder on repos.wowace.com: the HTML listing gives the files, fetched one by one."""
    if not url.endswith("/"):
        url += "/"
    html = http(url).decode("utf-8", "replace")
    for href in re.findall(r'href="([^"?]+)"', html):
        if "://" in href or href.startswith("/") or href == "../":
            continue
        if href.endswith("/"):
            fetch_wowace(url + href, os.path.join(dest, href.rstrip("/")))
        else:
            os.makedirs(dest, exist_ok=True)
            with open(os.path.join(dest, href), "wb") as f:
                f.write(http(url + href))


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


def main(argv):
    apply_ = "--apply" in argv
    quiet = "--quiet" in argv
    if os.path.isdir(SCRATCH):
        shutil.rmtree(SCRATCH)
    failed, drifted = 0, 0
    for path, url, tag in read_list():
        name = path.split("/", 1)[1]
        local = os.path.join(ROOT, path.replace("/", os.sep))
        up = os.path.join(SCRATCH, name)
        try:
            if "github.com" in url:
                fetch_github(url, tag, up)
            else:
                fetch_wowace(url, up)
        except Exception as e:  # network, 404, bad zip
            print(f"{name}: upstream not fetched ({e.__class__.__name__}: {e})")
            failed += 1
            continue
        if not os.path.isdir(local):
            print(f"{name}: NOT EMBEDDED, upstream has it")
            drifted += 1
            if apply_:
                shutil.copytree(up, local)
                print(f"   copied in")
            continue
        differs, missing, extra = compare(local, up)
        if not differs and not missing:
            print(f"{name}: same as upstream" + (f" ({len(extra)} local-only file(s))" if extra and not quiet else ""))
            continue
        drifted += 1
        print(f"{name}: DRIFT, {len(differs)} differ, {len(missing)} missing locally")
        if not quiet:
            for rel in differs:
                print(f"   differs: {rel}")
            for rel in missing:
                print(f"   missing: {rel}")
        if apply_:
            for rel in differs + missing:
                src, dst = os.path.join(up, rel), os.path.join(local, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
            print(f"   applied {len(differs) + len(missing)} file(s)")
    shutil.rmtree(SCRATCH, ignore_errors=True) # nothing to keep: a bump copies into Libs/
    if apply_ and failed:
        return 1
    print(f"libs: {drifted} drifted, {failed} not fetched")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
