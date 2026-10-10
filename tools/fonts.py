"""Generate font overrides (data/Fonts/font_*.tgi) from the installed game's Data.rwd.

- Drops the Korean GulimChe character sets and replaces Arial with Tahoma: on current Windows
  builds the engine aborts with "Processing non-Unicode TrueType font" on both.
- Scales font sizes by --scale (default 4/3). exe_patch.py makes GDI+ create fonts in pixels
  instead of DPI-dependent points; at the 96 DPI the game was made for, points = pixels * 4/3,
  so this keeps the original text size on any Windows display scaling.

usage: fonts.py <game dir> [--scale 1.3333]
"""
import argparse
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402

FILES = ["font_large.tgi", "font_medium.tgi", "font_metagame.tgi", "font_small.tgi", "font_tiny.tgi"]
HANGUL = re.compile(r"[ \t]*\[CharacterSet\][ \t]*\r?\n[ \t]*ids[ \t]*=[ \t]*hangul_\w+[^\n]*\n[ \t]*font[ \t]*=[ \t]*GulimChe[^\n]*\n?")
ARIAL = re.compile(r"(?m)^([ \t]*(?:backup_)?font[ \t]*=[ \t]*)Arial([ \t]*\r?)$")
SIZES = re.compile(r"(?m)^([ \t]*(?:size|backup_font_size|use_backup_font_when_smaller_than)[ \t]*=[ \t]*)(\d+)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--scale", type=float, default=4 / 3)
    ap.add_argument("--out", help="output folder (default <game dir>/data/Fonts)")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    data = Rwd(game / "Data.rwd")
    out = pathlib.Path(a.out) if a.out else game / "data" / "Fonts"
    out.mkdir(parents=True, exist_ok=True)
    for f in FILES:
        text = data.read(f"Fonts/{f}").decode("latin-1")
        text, n_hangul = HANGUL.subn("", text)
        text, n_arial = ARIAL.subn(r"\1Tahoma\2", text)
        sizes = []

        def scale(m):
            new = max(1, round(int(m.group(2)) * a.scale))
            sizes.append(f"{m.group(2)}->{new}")
            return f"{m.group(1)}{new}"

        text = SIZES.sub(scale, text)
        (out / f).write_bytes(text.encode("latin-1"))
        print(f"{f}: -{n_hangul} GulimChe sets, {n_arial} Arial->Tahoma, sizes {' '.join(sizes)}")


if __name__ == "__main__":
    main()
