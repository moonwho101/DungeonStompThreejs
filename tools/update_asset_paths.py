"""Rewrite texture and model manifest paths to ..\\Assets\\<filename>.

Assets are already in Assets/; this tool does not copy or delete asset files.
All other manifest content, filename casing, and line endings are preserved.

Usage: python tools/update_asset_paths.py [--dry-run]
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DAT_FILES = (ROOT / "bin" / "textures.dat", ROOT / "bin" / "modellist.dat")
PATH_RE = re.compile(
    r"\.\.[\\/](?:models|textures|assets)[\\/](?:[^\s\\/]+[\\/])*([^\s\\/]+)",
    re.IGNORECASE,
)


def update_dat(path, dry_run=False):
    # newline='' and latin-1 preserve line endings and any non-UTF-8 bytes
    with open(path, "r", encoding="latin-1", newline="") as f:
        text = f.read()
    count = 0

    def replace_path(match):
        nonlocal count
        replacement = "..\\Assets\\" + match.group(1)
        if replacement != match.group(0):
            count += 1
        return replacement

    new_text = PATH_RE.sub(replace_path, text)
    print(f"{path.name}: {count} paths updated")
    if not dry_run and new_text != text:
        with open(path, "w", encoding="latin-1", newline="") as f:
            f.write(new_text)
    return count


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="report changes without writing files")
    args = ap.parse_args()
    for dat in DAT_FILES:
        update_dat(dat, args.dry_run)
    if args.dry_run:
        print("dry run: nothing was changed")


if __name__ == "__main__":
    main()
