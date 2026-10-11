"""Upscale Axis & Allies (2004) 3D model textures (DDS) with Real-ESRGAN.

Colour goes through realesrgan-x4plus. Alpha does not: most unit and building textures use it as
a binary mask (team colour / cut-outs) or a soft blend (ground decals), so it is resized with
Lanczos and binary masks are re-thresholded to stay crisp. Each texture is re-encoded by
DirectXTex texconv to its original format (DXT1/DXT3/DXT5/uncompressed) with a full mipmap chain
and a DX9 header, and written as a loose override at the same path. 4x colour results are cached.

usage: upscale_textures.py <game dir> --esrgan EXE --texconv EXE [--only PREFIX ...] [--clean]
Scale factors per folder are in GROUPS; terrain and road tiles are upscaled as a 3x3 wrap so they
still tile seamlessly.
Writes <game dir>/data/<path>.dds, listed in data/textures-generated.txt (removed on the next
run, or alone with --clean).
"""
import argparse
import hashlib
import io
import pathlib
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402
from upscale_ui import write_tga  # noqa: E402

FORMATS = {b"DXT1": "BC1_UNORM", b"DXT3": "BC2_UNORM", b"DXT5": "BC3_UNORM"}

# prefix: (scale, max size). Small, numerous-on-screen art gets 4x; big or very numerous art 2x,
# which keeps the 32-bit process's texture memory in check.
GROUPS = {
    "units/": (4, 1024), "doodads/": (4, 1024), "shared/": (4, 1024), "roads/": (4, 1024),
    "bridges/": (4, 1024), "projectiles/": (4, 512), "weather/": (4, 512), "flares/": (4, 1024),
    "specialops/": (4, 1024), "special/": (4, 512), "terrain/": (4, 512),
    "buildings/": (2, 1024), "metagame/": (2, 2048), "effects/": (2, 512), "trailers/": (2, 1024),
    "generals/": (2, 1024), "cutscene/": (2, 2048), "textures/": (2, 1024),
}
SEAMLESS = ("terrain/", "roads/")  # tiling textures: upscaled as a 3x3 wrap so edges still meet
# The ground itself is TGA (terrain *.tgi "texture = X/Y.tga"); the terrain DDS files are only
# water animation frames. TGAs are written back as 32-bit TGA (the terrain pool makes mipmaps).
TGA_GROUPS = ("terrain/",)


def dds_format(blob):
    flags = struct.unpack_from("<I", blob, 80)[0]
    if flags & 4:
        return FORMATS.get(blob[84:88])
    return "B8G8R8A8_UNORM" if struct.unpack_from("<I", blob, 88)[0] == 32 else None


def wrap3(im):
    w, h = im.size
    out = Image.new(im.mode, (w * 3, h * 3))
    for y in range(3):
        for x in range(3):
            out.paste(im, (x * w, y * h))
    return out


def esrgan_rgb(images, esrgan, cache, seamless=()):
    """images: {sha: RGB image} -> {sha: 4x RGB image}, cached by sha. Shas in `seamless` are
    upscaled as a 3x3 tiling and the centre is kept, so the result still tiles."""
    cache.mkdir(parents=True, exist_ok=True)
    todo = {s: im for s, im in images.items() if not (cache / f"{s}.png").exists()}
    if todo:
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = pathlib.Path(tmp, "in"), pathlib.Path(tmp, "out")
            src.mkdir(), dst.mkdir()
            for s, im in todo.items():
                (wrap3(im) if s in seamless else im).save(src / f"{s}.png")
            print(f"  Real-ESRGAN x4 on {len(todo)} images ...", flush=True)
            r = subprocess.run([str(esrgan), "-i", str(src), "-o", str(dst), "-n", "realesrgan-x4plus", "-t", "256", "-f", "png"],
                               cwd=pathlib.Path(esrgan).parent, capture_output=True, text=True)
            missing = [s for s in todo if not (dst / f"{s}.png").exists()]
            if r.returncode or missing:
                raise SystemExit(f"realesrgan failed ({len(missing)} outputs missing):\n{r.stderr[-2000:]}")
            for s, im in todo.items():
                big = Image.open(dst / f"{s}.png").convert("RGB")
                if s in seamless:
                    w, h = im.size[0] * 4, im.size[1] * 4
                    big = big.crop((w, h, 2 * w, 2 * h))
                big.save(cache / f"{s}.png")
    return {s: Image.open(cache / f"{s}.png").convert("RGB") for s in images}


def restore_grain(ai, src, size):
    """Real-ESRGAN reads fine noisy grain (grass, sand) as noise and smooths it flat. Put back the
    high frequencies of a plain Lanczos upscale in proportion to how much detail was lost;
    textures the model sharpened (rock, cracks) are left as they are."""
    from PIL import ImageFilter
    lanc = src.convert("RGB").resize(size, Image.LANCZOS)
    radius = max(1, size[0] // src.size[0])

    def hf(im):
        a = np.asarray(im, np.float32)
        return a - np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), np.float32)
    h_ai, h_l = hf(ai), hf(lanc)
    e_ai, e_l = float((h_ai ** 2).mean()), float((h_l ** 2).mean())
    if e_l <= 0 or e_ai >= e_l:
        return ai
    w = 1 - e_ai / e_l
    out = np.asarray(ai, np.float32) + (h_l - h_ai) * w
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def scale_alpha(a, size):
    """Lanczos-resize alpha; binary masks stay binary."""
    arr = np.asarray(a)
    big = a.resize(size, Image.LANCZOS)
    if arr.min() == 255:
        return Image.new("L", size, 255)
    if ((arr < 16) | (arr > 239)).mean() > 0.97:
        return big.point(lambda v: 255 if v >= 128 else 0)
    return big


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--esrgan")
    ap.add_argument("--texconv")
    ap.add_argument("--only", nargs="*", default=[], help="limit to these path prefixes (default: all GROUPS)")
    ap.add_argument("--cache", default=str(pathlib.Path(__file__).resolve().parent.parent / ".cache" / "upscale3d"))
    ap.add_argument("--clean", action="store_true")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    manifest = game / "data" / "textures-generated.txt"
    if manifest.exists():
        for rel in manifest.read_text(encoding="utf-8").splitlines():
            (game / rel).unlink(missing_ok=True)
        manifest.unlink()
    if a.clean:
        print("removed upscaled model textures")
        return
    if not (a.esrgan and a.texconv):
        raise SystemExit("--esrgan and --texconv are required")
    a.esrgan, a.texconv = (str(pathlib.Path(p).resolve()) for p in (a.esrgan, a.texconv))

    data = Rwd(game / "Data.rwd")
    only = tuple(p.lower() for p in a.only)
    plan = []
    skipped = 0
    for n in sorted(data.names()):
        low = n.lower()
        group = next((g for g in GROUPS if low.startswith(g)), None)
        is_tga = low.endswith(".tga") and group in TGA_GROUPS
        if not group or not (low.endswith(".dds") or is_tga) or (only and not low.startswith(only)):
            continue
        scale, cap = GROUPS[group]
        blob = data.read(n)
        fmt = "TGA" if is_tga else dds_format(blob)
        if not fmt:
            skipped += 1
            continue
        try:
            im = Image.open(io.BytesIO(blob))
            im.load()
        except Exception:
            skipped += 1
            continue
        im = im.convert("RGBA")
        w, h = im.size
        k = max(1, min(scale, cap // max(w, h)))
        if k == 1 or min(w, h) < 8:
            skipped += 1
            continue
        plan.append((n, fmt, im, (w * k, h * k), low.startswith(SEAMLESS)))
    print(f"{len(plan)} textures to upscale ({skipped} skipped: small, at the size cap or unreadable)")

    def key(im, seamless):
        return hashlib.sha1(im.tobytes() + str(im.size).encode() + (b"wrap" if seamless else b"")).hexdigest()

    rgb = {key(im, sl): im.convert("RGB") for _, _, im, _, sl in plan}
    wrap = {key(im, sl) for _, _, im, _, sl in plan if sl}
    big = esrgan_rgb(rgb, pathlib.Path(a.esrgan), pathlib.Path(a.cache), wrap)

    written = []
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        by_fmt = {}
        for i, (n, fmt, im, size, sl) in enumerate(plan):
            s = key(im, sl)
            out = big[s].resize(size, Image.LANCZOS)
            if fmt == "TGA":  # terrain ground tiles
                out = restore_grain(out, im, size)
            out.putalpha(scale_alpha(im.getchannel("A"), size))
            if fmt == "TGA":
                dest = game / "data" / n
                dest.parent.mkdir(parents=True, exist_ok=True)
                write_tga(out, dest)
                written.append(dest)
                continue
            p = tmp / f"{i:05d}.png"
            out.save(p)
            by_fmt.setdefault(fmt, []).append((p, n))
        for fmt, items in by_fmt.items():
            od = tmp / fmt
            od.mkdir()
            lst = tmp / f"{fmt}.txt"
            lst.write_text("\n".join(str(p) for p, _ in items), encoding="utf-8")
            r = subprocess.run([str(a.texconv), "-nologo", "-y", "-dx9", "-f", fmt, "-m", "0", "-o", str(od), "-flist", str(lst)],
                               capture_output=True, text=True)
            if r.returncode:
                raise SystemExit(f"texconv failed:\n{r.stdout[-2000:]}{r.stderr[-2000:]}")
            for p, n in items:
                dest = game / "data" / n
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes((od / (p.stem + ".dds")).read_bytes())
                written.append(dest)
    manifest.write_text("\n".join(str(p.relative_to(game)) for p in written) + "\n", encoding="utf-8")
    print(f"wrote {len(written)} textures")


if __name__ == "__main__":
    main()
