"""Raise Axis & Allies (2004) rendering settings that were sized for 2004 hardware.

Writes <game dir>/data/UVars.tgi, the game's own default settings file with the values below
changed; loose files under data/ override Data.rwd. Settings the player changes in Options are
saved separately (Documents/A&A/data/User/UVars.tgi) and still apply on top. Also sets the AVARS
values in data/AVars.tgi (written by widescreen.py; created from Data.rwd if missing).

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
    # terrain patches are pre-rendered into this pool; a patch covers ~640 screen px at 4K and
    # default zoom, so 128 px (and still 512) blurs the ground
    "TerrainTexturePoolDesiredTextureResolution": "1024",
    "TerrainTexturePoolMinTextureResolution": "128",
    # "approximately 20% more than on-screen for max zoom": 120 for the stock zoom-out limit of
    # 1.4; exe_patch.py raises it to 1.8, (1.8 / 1.4)^2 = 1.65x the ground on screen
    "TerrainTexturePoolDesiredNumEntries": "200",
    # projected shadows
    "ShadowTexturePoolDesiredTextureResolution": "256",
    "ShadowTexturePoolMinTextureResolution": "64",
    # HQ attachments and similar render-to-texture pieces
    "GeneralTexturePoolDesiredTextureResolution": "512",
    # sun highlights on the ground (strength: AVars TerrainSpecular, 15%)
    "TerrainSpecularEnabled": "true",
    # "performance: extra whiz bangs" (units react to hits)
    "HitAnimations": "true",
    # particles generated, 1 = 100%: denser smoke, fire, dust and explosions
    "ParticleGeneratePCG": "1.5",
}

AVARS = {
    # shadow colour = this share of the sun colour; lower is a deeper shadow
    "DynamicShadowSunModulate": "0.4",
    # dev-mode zoom limit; kept at or above the gameplay limit exe_patch.py sets
    "CameraZoomMax": "1.8",
}


def set_vars(text, values, name):
    for key, value in values.items():
        pat = re.compile(rf"^(\s*(?:int|float|flag)\s+{key}\s*=\s*)([^\s;]+)", re.M)
        text, n = pat.subn(lambda m: m.group(1) + value, text)
        if n != 1:
            raise SystemExit(f"{key} not found exactly once in {name}")
        print(f"  {key} = {value}")
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--off", action="store_true", help="remove the override (game defaults)")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    data = Rwd(game / "Data.rwd")
    out = game / "data" / "UVars.tgi"
    avars = game / "data" / "AVars.tgi"
    if a.off:
        out.unlink(missing_ok=True)
        print("removed data/UVars.tgi (game defaults)")
        if avars.exists():
            stock = data.read("AVars.tgi").decode("latin-1")
            defaults = {k: re.search(rf"^\s*(?:int|float|flag)\s+{k}\s*=\s*([^\s;]+)", stock, re.M).group(1) for k in AVARS}
            avars.write_bytes(set_vars(avars.read_bytes().decode("latin-1"), defaults, "AVars.tgi").encode("latin-1"))
        return
    text = set_vars(data.read("UVars.tgi").decode("latin-1"), SETTINGS, "UVars.tgi")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(text.encode("latin-1"))
    print(f"wrote {out.relative_to(game)}")
    src = avars.read_bytes() if avars.exists() else data.read("AVars.tgi")
    avars.write_bytes(set_vars(src.decode("latin-1"), AVARS, "AVars.tgi").encode("latin-1"))
    print(f"wrote {avars.relative_to(game)}")


if __name__ == "__main__":
    main()
