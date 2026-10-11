"""Build a ReShade UIMask texture for the widescreen in-game HUD.

White = HUD (UIMask restores the original pixels there), black = 3D scene. The bottom control
panel comes from the real panel art (union of the default and all nation skins), placed where
widescreen.py puts its five slices, and filled from its top edge down; the top-left resource
bar and the special-ops column are rectangles. Edges are blurred slightly.

usage: reshade_uimask.py <game dir> <out.png> [--width 3840 --height 2160]
"""
import argparse
import io
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402
from widescreen import CUTS, NATIONS  # noqa: E402

PANEL_TOP = 768 - 257          # control_panel.tgi: T = 257b
RECTS = [                      # layout units (x0, y0, x1, y1), measured from in-game screenshots
    (0, 0, 492, 38),           # resources + build queue bar
    (0, 0, 48, 262),           # special-ops column
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("out")
    ap.add_argument("--width", type=int, default=3840)
    ap.add_argument("--height", type=int, default=2160)
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    k = a.height / 768                     # px per layout unit
    vw = a.width / k                       # virtual layout width
    e = vw - 1024

    alpha = None
    sources = [Rwd(game / "Data.rwd")] + [Rwd(game / "skins" / f"{n}.rwd") for n in NATIONS]
    for arc in sources:
        n = "UI/Game/ControlPanel/Background.tga"
        if arc.has(n):
            al = np.asarray(Image.open(io.BytesIO(arc.read(n))).convert("RGBA").resize((1024, 256)))[..., 3]
            alpha = al if alpha is None else np.maximum(alpha, al)

    mask = Image.new("L", (a.width, a.height), 0)
    lefts = [CUTS[0], CUTS[1], CUTS[2] + e / 2, CUTS[3] + e / 2, CUTS[4] + e]
    widths = [CUTS[1] - CUTS[0], CUTS[2] - CUTS[1] + e / 2, CUTS[3] - CUTS[2], CUTS[4] - CUTS[3] + e / 2, CUTS[5] - CUTS[4]]
    top_px = round(PANEL_TOP * k)
    h_px = a.height - top_px
    for x0, x1, left, width in zip(CUTS, CUTS[1:], lefts, widths):
        sl = Image.fromarray(alpha[:, x0:x1]).resize((max(1, round(width * k)), h_px), Image.BILINEAR)
        mask.paste(sl, (round(left * k), top_px))
    m = np.asarray(mask).copy()
    solid = (m > 128)
    first = np.where(solid.any(axis=0), solid.argmax(axis=0), a.height)   # top edge per column
    rows = np.arange(a.height)[:, None]
    m = np.where(rows >= first[None, :], 255, 0).astype(np.uint8)
    out = Image.fromarray(m)
    for x0, y0, x1, y1 in RECTS:
        out.paste(255, tuple(round(v * k) for v in (x0, y0, x1, y1)))
    out = out.filter(ImageFilter.GaussianBlur(2))
    out.save(a.out)
    print(f"wrote {a.out} ({a.width}x{a.height}); HUD covers {np.asarray(out).mean() / 255:.0%} of the screen")


if __name__ == "__main__":
    main()
