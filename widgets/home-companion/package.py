#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reproducible data/app package for the existing signed Crates installer."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parent
VERSION = "0.1.1"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-f0-9]{40}", args.revision):
        parser.error("Provide the committed source revision")
    args.output.mkdir(parents=True, exist_ok=True)
    name = f"home-companion-{VERSION}-linux.tar.gz"
    archive = args.output / name
    if archive.exists():
        parser.error("Output exists; published bytes are immutable")
    files = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in sorted(ROOT.rglob("*"))
             if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"}
    # Git's Windows checkout may use CRLF. Linux env shebangs require LF.
    for key in files:
        if key.endswith(".py"):
            files[key] = files[key].replace(b"\r\n", b"\n")
    package = {k: v for k, v in files.items() if k not in ("package.py", "test_package.py")}

    def write(path, contents, prefix=""):
        with path.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode="w") as tar:
                for key, data in sorted(contents.items()):
                    info = tarfile.TarInfo(prefix + key)
                    info.size = len(data)
                    info.mode = 0o755 if key == "launch.py" else 0o644
                    tar.addfile(info, io.BytesIO(data))
    write(archive, package)
    source = args.output / f"home-companion-{VERSION}-source.tar.gz"
    write(source, files, "home-companion/")
    record = dict(id="home-companion", title="Companion (alpha)", kind="app", version=VERSION,
                  entry="launch.py", icon="icon.svg", license="GPL-3.0-or-later",
                  repository="https://github.com/EriArk/crates.git", revision=args.revision,
                  size=archive.stat().st_size, unpackedSize=sum(map(len, package.values())) + 1048576,
                  sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), channel="Experimental",
                  compatibility="untested",
                  compatibilityNote="New reactions and shutters require TrainerOS host commit 5420614a or newer. Package does not update the shell. Handheld acceptance pending.",
                  notes="Companion host integration refresh: autonomous idle, notification wave, achievement lift and sliding shutters with updated TrainerOS. Home-only widget; care state preserved.",
                  url=f"https://github.com/EriArk/crates/releases/download/home-companion-v{VERSION}/{name}")
    for arch in ("aarch64", "x86_64"):
        (args.output / f"home-companion-{arch}-record.json").write_text(
            json.dumps(dict(record, architecture=arch), indent=2) + "\n", encoding="utf-8")
    (args.output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in (archive, source)), encoding="utf-8")
    print(archive)


if __name__ == "__main__":
    main()
