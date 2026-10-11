"""Raise Axis & Allies (2004) rendering settings that were sized for 2004 hardware.

Writes <game dir>/data/UVars.tgi, the game's own default settings file with the values below
changed; loose files under data/ override Data.rwd. Settings the player changes in Options are
saved separately (Documents/A&A/data/User/UVars.tgi) and still apply on top.

usage: graphics.py <game dir> [--off]
"""
import argparse
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402

SETTINGS = {
    # upgrades TEXTURE shadows to PROJECTED and grows the shadow pool (UVars comment)
    "ViewQualityExtreme": "true",
    # terrain patches are pre-rendered into this pool; 128 px blurs the ground at 4K
    "TerrainTexturePoolDesiredTextureResolution": "512",
    "TerrainTexturePoolMinTextureResolution": "128",
    # projected shadows
    "ShadowTexturePoolDesiredTextureResolution": "256",
    "ShadowTexturePoolMinTextureResolution": "64",
    # HQ attachments and similar render-to-texture pieces
    "GeneralTexturePoolDesiredTextureResolution": "512",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--off", action="store_true", help="remove the override (game defaults)")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    out = game / "data" / "UVars.tgi"
    if a.off:
        out.unlink(missing_ok=True)
        print("removed data/UVars.tgi (game defaults)")
        return
    text = Rwd(game / "Data.rwd").read("UVars.tgi").decode("latin-1")
    for key, value in SETTINGS.items():
        pat = re.compile(rf"^(\s*(?:int|float|flag)\s+{key}\s*=\s*)([^\s;]+)", re.M)
        text, n = pat.subn(lambda m: m.group(1) + value, text)
        if n != 1:
            raise SystemExit(f"{key} not found exactly once in UVars.tgi")
        print(f"  {key} = {value}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(text.encode("latin-1"))
    print(f"wrote {out.relative_to(game)}")


if __name__ == "__main__":
    main()
