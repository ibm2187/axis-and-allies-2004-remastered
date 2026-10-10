"""Write copies of the font .tgi files without the GulimChe (Korean) character sets.

Windows substitutes Arial for the missing GulimChe font and the engine aborts with
"ERROR: Processing non-Unicode TrueType font." The English game never uses those glyphs.

usage: python -I strip_hangul.py <extracted Fonts dir> <game data/Fonts dir>
"""
import pathlib
import re
import sys

BLOCK = re.compile(r"[ \t]*\[CharacterSet\][ \t]*\r?\n[ \t]*ids[ \t]*=[ \t]*hangul_\w+[^\n]*\n[ \t]*font[ \t]*=[ \t]*GulimChe[^\n]*\n?")

src, dst = map(pathlib.Path, sys.argv[1:3])
dst.mkdir(parents=True, exist_ok=True)
for f in sorted(src.glob("font_*.tgi")):
    text = f.read_bytes().decode("latin-1")
    new, n = BLOCK.subn("", text)
    left = new.count("GulimChe")
    print(f"{f.name}: removed {n} blocks, GulimChe left: {left}")
    if n:
        (dst / f.name).write_bytes(new.encode("latin-1"))
