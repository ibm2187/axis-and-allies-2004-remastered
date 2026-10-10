"""Generate font overrides (data/Fonts/font_*.tgi) from the installed game's Data.rwd.

- Drops the Korean GulimChe character sets and replaces Arial: on current Windows builds the
  engine aborts with "Processing non-Unicode TrueType font" on both.
- Arial's replacement: with --liberation <dir>, Liberation Sans Bold (SIL OFL, metric-compatible
  with Arial) loaded from a file, which goes through the engine's GDI+ file-font path like the
  game's own A&A.TTF (proper tails); without it, the system font Tahoma.
- Scales the sizes of fonts that were file fonts originally (A&A.TTF) by --scale (default 4/3).
  exe_patch.py makes GDI+ create fonts in pixels instead of DPI-dependent points; at the 96 DPI
  the game was made for, points = pixels * 4/3, so this keeps the original text size on any
  Windows display scaling. Former Arial fonts were drawn at their plain size and keep it.

usage: fonts.py <game dir> [--liberation <dir with LiberationSans-Bold.ttf>] [--scale 1.3333] [--out dir]
"""
import argparse
import pathlib
import re
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402

FILES = ["font_large.tgi", "font_medium.tgi", "font_metagame.tgi", "font_small.tgi", "font_tiny.tgi"]
LIBERATION = "LiberationSans-Bold.ttf"
HANGUL = re.compile(r"[ \t]*\[CharacterSet\][ \t]*\r?\n[ \t]*ids[ \t]*=[ \t]*hangul_\w+[^\n]*\n[ \t]*font[ \t]*=[ \t]*GulimChe[^\n]*\n?")
ARIAL = re.compile(r"(?m)^([ \t]*(?:backup_)?font[ \t]*=[ \t]*)Arial([ \t]*\r?)$")
SIZES = re.compile(r"(?m)^([ \t]*(?:size|backup_font_size|use_backup_font_when_smaller_than)[ \t]*=[ \t]*)(\d+)")
FONT_BLOCK = re.compile(r"\[Font template = Font\].*?(?=\[Font template = Font\]|\Z)", re.S)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--liberation", help="folder containing LiberationSans-Bold.ttf and LICENSE")
    ap.add_argument("--scale", type=float, default=4 / 3)
    ap.add_argument("--out", help="output folder (default <game dir>/data/Fonts)")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    data = Rwd(game / "Data.rwd")
    out = pathlib.Path(a.out) if a.out else game / "data" / "Fonts"
    out.mkdir(parents=True, exist_ok=True)
    if a.liberation:
        src = pathlib.Path(a.liberation)
        (out / "TrueType").mkdir(exist_ok=True)
        shutil.copyfile(src / LIBERATION, out / "TrueType" / LIBERATION)
        shutil.copyfile(src / "LICENSE", out / "TrueType" / "LiberationSans-LICENSE.txt")
        replacement = f"/fonts/truetype/{LIBERATION}"
    else:
        replacement = "Tahoma"
    for f in FILES:
        text = data.read(f"Fonts/{f}").decode("latin-1")
        text, n_hangul = HANGUL.subn("", text)
        sizes = []

        def fix_block(block):
            b = block.group(0)
            base = re.search(r"ids\s*=\s*base.*?\n\s*font\s*=\s*(\S+)", b, re.S)
            # Only fonts that were file fonts originally (A&A.TTF) went through GDI+ in points;
            # the former system fonts (Arial) were drawn at their plain size, so keep theirs.
            if not base or base.group(1).startswith("/"):
                def scale(m):
                    new = max(1, round(int(m.group(2)) * a.scale))
                    sizes.append(f"{m.group(2)}->{new}")
                    return f"{m.group(1)}{new}"
                b = SIZES.sub(scale, b)
            return ARIAL.sub(lambda m: f"{m.group(1)}{replacement}{m.group(2)}", b)

        n_arial = len(ARIAL.findall(text))
        text = FONT_BLOCK.sub(fix_block, text)
        (out / f).write_bytes(text.encode("latin-1"))
        print(f"{f}: -{n_hangul} GulimChe sets, {n_arial} Arial->{replacement}, sizes {' '.join(sizes) or 'unchanged'}")


if __name__ == "__main__":
    main()
