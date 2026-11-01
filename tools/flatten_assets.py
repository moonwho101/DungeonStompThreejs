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
import shutil
from pathlib import Path

from update_asset_paths import update_dat

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ("Models", "Textures")
ASSETS = ROOT / "Assets"
DAT_FILES = (ROOT / "bin" / "modellist.dat", ROOT / "bin" / "textures.dat")

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


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="report what would happen without changing anything")
    args = ap.parse_args()
    copy_files(args.dry_run)
    for dat in DAT_FILES:
        if dat.is_file():
            update_dat(dat, args.dry_run)
        else:
            print(f"skip: {dat} not found")
    if args.dry_run:
        print("dry run: nothing was changed")


if __name__ == "__main__":
    main()
