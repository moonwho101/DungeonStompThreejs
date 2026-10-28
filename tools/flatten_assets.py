"""Flatten Models/ and Textures/ into a single root-level Assets/ directory.

Step 1: every file under Models/ and Textures/ (recursive) is copied into
        Assets/ with no sub directories. Existing files are overwritten, so
        when two files share a name the last one copied wins (Models first,
        then Textures, each in sorted path order).
Step 2: bin/modellist.dat and bin/textures.dat are rewritten so every
        ..\\models\\... or ..\\textures\\... path points at ..\\Assets\\<file>.

The original Models/ and Textures/ folders are left untouched.

Usage:  python tools/flatten_assets.py [--dry-run]
"""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ("Models", "Textures")
ASSETS = ROOT / "Assets"
DAT_FILES = (ROOT / "bin" / "modellist.dat", ROOT / "bin" / "textures.dat")

# ..\models\players\knight\knight.md2  ->  ..\Assets\knight.md2
PATH_RE = re.compile(r"\.\.[\\/](?:models|textures)[\\/](?:[^\s\\/]+[\\/])*([^\s\\/]+)", re.IGNORECASE)


def copy_files(dry_run):
    copied = overwritten = 0
    if not dry_run:
        ASSETS.mkdir(exist_ok=True)
    for d in SOURCE_DIRS:
        base = ROOT / d
        if not base.is_dir():
            print(f"skip: {base} not found")
            continue
        for src in sorted(p for p in base.rglob("*") if p.is_file()):
            dst = ASSETS / src.name
            if dst.exists():
                overwritten += 1
            copied += 1
            if not dry_run:
                shutil.copyfile(src, dst)
    print(f"files copied: {copied} ({overwritten} overwrote an existing file)")


def update_dat(path, dry_run):
    if not path.is_file():
        print(f"skip: {path} not found")
        return
    # newline='' and latin-1 preserve line endings and any non-UTF-8 bytes
    with open(path, "r", encoding="latin-1", newline="") as f:
        text = f.read()
    new_text, count = PATH_RE.subn(lambda m: "..\\Assets\\" + m.group(1), text)
    print(f"{path.name}: {count} paths updated")
    if not dry_run and new_text != text:
        with open(path, "w", encoding="latin-1", newline="") as f:
            f.write(new_text)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="report what would happen without changing anything")
    args = ap.parse_args()
    copy_files(args.dry_run)
    for dat in DAT_FILES:
        update_dat(dat, args.dry_run)
    if args.dry_run:
        print("dry run: nothing was changed")


if __name__ == "__main__":
    main()
