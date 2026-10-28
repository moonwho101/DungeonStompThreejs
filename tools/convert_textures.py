"""Normalise texture formats under Textures/ and Models/.

Pass 1: every .dds gets a sibling .jpg (high quality) if one doesn't exist.
        Any .bmp without a .jpg or .png sibling is converted too, so that
        deleting it in pass 2 cannot lose the only copy of a texture.
Pass 2: delete every .dds and .bmp whose conversion succeeded / is covered.
        .jpg and .png files are never touched, and neither are .bmp files
        inside any directory named "3ds" (at any depth); those are not
        converted either.

Usage:  python tools/convert_textures.py [--dry-run] [--quality 95]
Requires: pip install pillow
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DIRS = ("Textures", "Models")


def in_3ds_dir(path):
    return any(part.lower() == "3ds" for part in path.relative_to(ROOT).parent.parts)


def iter_files(*exts):
    for d in DIRS:
        base = ROOT / d
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if not p.is_file() or p.suffix.lower() not in exts:
                continue
            # .bmp files anywhere under a "3ds" directory are left untouched
            if p.suffix.lower() == ".bmp" and in_3ds_dir(p):
                continue
            yield p


def has_sibling(path, *exts):
    # Case-insensitive sibling lookup (Windows is, other platforms are not)
    stem = path.stem.lower()
    for s in path.parent.iterdir():
        if s.is_file() and s.stem.lower() == stem and s.suffix.lower() in exts:
            return True
    return False


def to_rgb(img):
    if img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (0, 0, 0))
        bg.paste(rgba, mask=rgba.getchannel("A"))
        return bg
    return img.convert("RGB")


def open_dds_a16b16g16r16(path):
    # D3DFMT_A16B16G16R16 (fourCC value 36), which Pillow doesn't decode
    data = path.read_bytes()
    if data[:4] != b"DDS " or int.from_bytes(data[84:88], "little") != 36:
        raise ValueError("unsupported DDS format")
    height = int.from_bytes(data[12:16], "little")
    width = int.from_bytes(data[16:20], "little")
    return Image.frombytes("RGBA", (width, height), data[128:128 + width * height * 8], "raw", "RGBA;16L")


def open_image(src):
    try:
        img = Image.open(src)
        img.load()
        return img
    except NotImplementedError:
        if src.suffix.lower() != ".dds":
            raise
        return open_dds_a16b16g16r16(src)


def convert(src, quality, dry_run):
    dst = src.with_suffix(".jpg")
    if dry_run:
        print(f"  [dry-run] would create {dst.relative_to(ROOT)}")
        return True
    try:
        with open_image(src) as img:
            to_rgb(img).save(dst, "JPEG", quality=quality, subsampling=0, optimize=True)
        print(f"  created {dst.relative_to(ROOT)}")
        return True
    except Exception as e:  # unsupported DDS variant, corrupt file, ...
        print(f"  FAILED  {src.relative_to(ROOT)}: {e}", file=sys.stderr)
        if dst.exists():
            dst.unlink()
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--quality", type=int, default=95)
    args = ap.parse_args()

    failed = []
    print("Pass 1: creating missing .jpg files")
    for dds in sorted(iter_files(".dds")):
        if has_sibling(dds, ".jpg"):
            continue
        if not convert(dds, args.quality, args.dry_run):
            failed.append(dds)
    for bmp in sorted(iter_files(".bmp")):
        if has_sibling(bmp, ".jpg", ".png"):
            continue
        # A .dds sibling is converted above (or reported as failed), so it covers the .bmp
        if has_sibling(bmp, ".dds") and bmp.with_suffix(".dds") not in failed:
            continue
        if not convert(bmp, args.quality, args.dry_run):
            failed.append(bmp)

    print("Pass 2: deleting .dds and .bmp")
    failed_set = set(failed)
    deleted = kept = 0
    for f in sorted(iter_files(".dds", ".bmp")):
        stem_failed = any(x.parent == f.parent and x.stem.lower() == f.stem.lower() for x in failed_set)
        if stem_failed:
            kept += 1
            print(f"  kept (no jpg produced) {f.relative_to(ROOT)}")
            continue
        if args.dry_run:
            print(f"  [dry-run] would delete {f.relative_to(ROOT)}")
        else:
            f.unlink()
        deleted += 1

    print(f"\nDone. deleted={deleted} kept={kept} failed={len(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
