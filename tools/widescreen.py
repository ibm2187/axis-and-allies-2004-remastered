"""Generate widescreen UI overrides for Axis & Allies (2004) from the installed game's own data.

The UI is laid out in a virtual space InterfacePositioningWidth x InterfacePositioningHeight
(1024 x 768) and scaled per axis to the screen, so wide screens stretch it. This script widens
the virtual space to 768 * aspect (E extra units) and repositions layouts so nothing stretches:

  right   shift by E (things that belong at the right edge)
  center  shift by E/2 (dialogs and centered panels)
  stretch widen by E, keeping the left edge
  (scale, W) scale a child's position and width with a parent W units wide that was stretched
  box     turn a full-screen root into a centered 1024-wide box (whole menu screens)
  The in-game control panel art is cut into five slices (left, stretchable middles, emblem,
  right) for the default UI and every nation skin.

usage: widescreen.py <game dir> [--aspect 16:9] [-v]
Writes loose override files under <game dir>/data and <game dir>/skins/<nation>.
"""
import argparse
import pathlib
import re
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402

# (file inside Data.rwd, line of the block header or of its L assignment, kind)
RULES = [
    # main menus: the button column belongs at the right edge
    ("UI/Menus/main.tgi", 14, "right"),
    ("UI/Menus/singleplayer_menu.tgi", 4, "right"),
    ("UI/Menus/multiplayer.tgi", 4, "right"),
    ("UI/Menus/menu_background.tgi", 46, "right"),
    # full-screen menu screens: centered 4:3 box
    ("UI/Loading/loading_screen.tgi", 15, "box"),
    ("UI/Menus/choose_campaign.tgi", 18, "box"),
    ("UI/Menus/credits.tgi", 15, "box"),
    ("UI/Menus/debriefing.tgi", 22, "box"),
    ("UI/Menus/lobby.tgi", 95, "box"),
    ("UI/Menus/scoring.tgi", 8, "box"),
    ("UI/Menus/staging.tgi", 115, "box"),
    ("UI/Shared/options_dialog.tgi", 179, "box"),
    # (UI/Shared/video.tgi is left alone: boxing FullscreenVideoWidget stalls the intro videos)
    # in-game HUD
    ("UI/Game/action_buttons.tgi", 4, "right"),
    ("UI/Game/control_panel.tgi", 69, "right"),   # objectives button
    ("UI/Game/control_panel.tgi", 99, "right"),   # technology button
    ("UI/Game/control_panel.tgi", 129, "right"),  # politics button
    ("UI/Game/control_panel.tgi", 159, "right"),  # message log button
    ("UI/Game/time_message.tgi", 3, "right"),
    ("UI/Game/time_message.tgi", 18, "right"),
    ("UI/Game/politics_display.tgi", 20, "right"),
    ("UI/Game/object_display.tgi", 2, "stretch"),  # keep left-aligned in the panel, widen
    # economy bars sit over the info display: widen them the same way, and scale their fields
    # with the stretched bar art so values stay between the painted separators
    ("UI/Game/economy_bar.tgi", 1, "stretch"),
    ("UI/Game/economy_bar.tgi", 15, "stretch"),
    ("UI/Game/template_game.tgi", 430, ("scale", 459)),  # money
    ("UI/Game/template_game.tgi", 440, ("scale", 459)),  # ammo
    ("UI/Game/template_game.tgi", 450, ("scale", 459)),  # oil
    ("UI/Game/template_game.tgi", 461, ("scale", 459)),  # building limit
    ("UI/Game/template_game.tgi", 484, ("scale", 459)),  # unit limit
    ("UI/Game/template_game.tgi", 507, ("scale", 459)),  # faction experience
    ("UI/Game/favorites_display.tgi", 2, "center"),
    ("UI/Game/objectives_display.tgi", 1, "center"),
    ("UI/Game/technology_display.tgi", 1, "center"),
    ("UI/Game/game_interface.tgi", 84, "center"),   # side message log panel
    ("UI/Game/game_interface.tgi", 460, "center"),  # upkeep shortage icon
    ("UI/Shared/display_banner.tgi", 75, "center"),
    ("UI/Shared/display_banner.tgi", 87, "center"),
    # dialogs
    ("UI/Game/chat_panel.tgi", 1, "center"),
    ("UI/Game/connection_status_dialog.tgi", 2, "center"),
    ("UI/Game/file_dialog.tgi", 1, "center"),
    ("UI/Game/game_menu.tgi", 4, "center"),
    ("UI/Game/game_menu.tgi", 175, "center"),
    # long labels ("Quit Axis & Allies", "Connection Status") overflow the 182-unit menu button
    # without the old horizontal stretch: widen to 220, centered in the dialog
    ("UI/Game/game_menu.tgi", 20, ("width", 82, 220)),    # separator
    ("UI/Game/game_menu.tgi", 60, ("width", 82, 220)),    # options
    ("UI/Game/game_menu.tgi", 75, ("width", 82, 220)),    # load
    ("UI/Game/game_menu.tgi", 90, ("width", 82, 220)),    # save
    ("UI/Game/game_menu.tgi", 105, ("width", 82, 220)),   # connection status
    ("UI/Game/game_menu.tgi", 120, ("width", 82, 220)),   # abort mission
    ("UI/Game/game_menu.tgi", 152, ("width", 82, 220)),   # quit
    ("UI/Game/game_menu.tgi", 167, ("width", 82, 220)),   # return to game
    ("UI/Game/game_menu.tgi", 199, ("width", 73, 220)),   # resign dialog: resign
    ("UI/Game/game_menu.tgi", 214, ("width", 73, 220)),   # leave game
    ("UI/Game/game_menu.tgi", 229, ("width", 73, 220)),   # cancel
    ("UI/Lobby/player_profile_dialog.tgi", 638, "center"),
    ("UI/Menus/create_game_dialog.tgi", 2, "center"),
    ("UI/Menus/join_direct_dialog.tgi", 2, "center"),
    ("UI/Menus/login.tgi", 4, "center"),
    ("UI/Menus/menu_file_dialog.tgi", 5, "center"),
    ("UI/Menus/profile_management.tgi", 4, "center"),
    ("UI/Menus/server_info_dialog.tgi", 2, "center"),
    ("UI/Menus/staging.tgi", 2, "center"),          # map preview dialog
    ("UI/Shared/buddy_dialog.tgi", 2, "center"),
    ("UI/Shared/buddy_dialog.tgi", 261, "center"),
    ("UI/Shared/download_dialog.tgi", 4, "center"),
    ("UI/Shared/file_dialog.tgi", 5, "center"),
    ("UI/Shared/file_dialog.tgi", 137, "center"),
    ("UI/Shared/file_dialog.tgi", 275, "center"),
    ("UI/Shared/multiplayer_options_dialog.tgi", 7, "center"),
    ("UI/Shared/staging_file_dialog.tgi", 2, "center"),
    ("UI/Shared/staging_file_dialog.tgi", 249, "center"),
    ("UI/Shared/staging_file_saved_dialog.tgi", 3, "center"),
    ("UI/Shared/team_management_dialog.tgi", 41, "center"),
    ("UI/Editor/map_properties.tgi", 4, "center"),
    ("UI/Editor/new_map_dialog.tgi", 4, "center"),
    ("UI/Editor/objectives_dialog.tgi", 4, "center"),
    ("UI/Editor/properties_dialog.tgi", 7, "center"),
]

# Control panel art cuts, as positions in the 1024-unit layout (= fraction of texture width).
CUTS = [0, 320, 448, 624, 792, 1024]
SLICES = ["WsBgLeft", "WsBgMidL", "WsBgEmblem", "WsBgMidR", "WsBgRight"]
CP_VARIANTS = ["UI/1280/Game/ControlPanel", "UI/800/Game/ControlPanel", "UI/Game/ControlPanel"]
NATIONS = ["USA", "GBR", "GER", "RUS", "JPN"]

COORD = re.compile(r"^(\s*)(L|T|R|B)(\s*=\s*)([+-]?)([0-9.]+)(%|r|b|t)?(.*)$")


def num(v):
    return f"{v:.4f}".rstrip("0").rstrip(".")


def set_width(lines, i, left, width, verbose):
    """Set L and the width (R = +width) of the coordinate run starting at lines[i]."""
    m = COORD.match(lines[i])
    pre, eq, post = m.group(1), m.group(3), m.group(7)
    before = lines[i]
    lines[i] = f"{pre}L{eq}{num(left)}{post}"
    j, last = i + 1, i
    while j < len(lines) and j - i < 6 and COORD.match(lines[j]):
        if COORD.match(lines[j]).group(2) == "R":
            lines[j] = f"{pre}R{eq}+{num(width)}"
            break
        last = j
        j += 1
    else:
        lines.insert(last + 1, f"{pre}R{eq}+{num(width)}")
    if verbose:
        print(f"    {i + 1}: {before.strip()} -> L {num(left)}, width {num(width)}")


def apply_rule(lines, line_no, kind, e, verbose=False):
    i = line_no - 1
    while i < len(lines) and not re.match(r"^\s*L\s*=", lines[i]):
        i += 1
        if i - (line_no - 1) > 40:
            raise ValueError(f"no L assignment near line {line_no}")
    if isinstance(kind, tuple) and kind[0] == "width":
        set_width(lines, i, kind[1], kind[2], verbose)
        return
    j = i
    while j < len(lines) and j - i < 10 and not re.match(r"^\s*[\[}]", lines[j]):
        m = COORD.match(lines[j])
        before = lines[j]
        if m:
            pre, key, eq, sign, val, suf, post = m.groups()
            v = float(val)
            if kind == "box":
                if key == "L":
                    lines[j] = f"{pre}L{eq}{num(e / 2)}{post}"
                elif key == "R":
                    lines[j] = f"{pre}R{eq}+1024{post}"
            elif kind in ("right", "center") and key in ("L", "R") and not sign and not suf:
                lines[j] = f"{pre}{key}{eq}{num(v + (e if kind == 'right' else e / 2))}{post}"
            elif kind == "stretch" and key == "R" and not suf:
                lines[j] = f"{pre}R{eq}{sign}{num(v + e)}{post}"
            elif isinstance(kind, tuple) and kind[0] == "scale" and key in ("L", "R") and not suf:
                k = (kind[1] + e) / kind[1]  # child of a parent kind[1] units wide that was stretched by e
                lines[j] = f"{pre}{key}{eq}{sign}{num(v * k)}{post}"
            if verbose and lines[j] != before:
                print(f"    {j + 1}: {before.strip()} -> {lines[j].strip()}")
        j += 1


def control_panel_art(text, e):
    """Replace the single stretched background decal with five slices."""
    lefts = [CUTS[0], CUTS[1], CUTS[2] + e / 2, CUTS[3] + e / 2, CUTS[4] + e]
    widths = [CUTS[1] - CUTS[0], CUTS[2] - CUTS[1] + e / 2, CUTS[3] - CUTS[2], CUTS[4] - CUTS[3] + e / 2, CUTS[5] - CUTS[4]]
    nl = "\r\n"
    blocks = []
    for name, left, width in zip(SLICES, lefts, widths):
        blocks.append(nl.join([
            "\t\t[Child Template=DecalVE]", "\t\t{",
            f"\t\t\ttexture = /UI/%s/Game/ControlPanel/{name}.tga",
            f"\t\t\tL = {num(left)}", "\t\t\tT = 0", f"\t\t\tR = +{num(width)}", "\t\t\tB = 100%",
            "\t\t\tclient_L = 0%", "\t\t\tclient_T = 170b", "\t\t\tclient_R = 100%", "\t\t\tclient_B = 100%",
            "\t\t}"]))
    pat = re.compile(r"\t\t\[Child Template=DecalVE\]\r?\n\t\t\{\r?\n\t\t\ttexture = /UI/%s/Game/ControlPanel/Background\.tga.*?\r?\n\t\t\}", re.S)
    # several decals with the same 'when' state need validation off (as staging.tgi does)
    new, n = pat.subn(lambda _: "\t\tvalidate_decal_children = false" + nl + nl.join(blocks), text, count=1)
    if n != 1:
        raise ValueError("control panel background decal not found")
    return new


def crop_tga(data, x0, x1):
    idlen, cmtype, itype = data[0], data[1], data[2]
    w, h, bpp, desc = struct.unpack_from("<HHBB", data, 12)
    if cmtype or itype != 2 or bpp not in (24, 32):
        raise ValueError(f"unsupported TGA type={itype} bpp={bpp}")
    px = bpp // 8
    body = data[18 + idlen:]
    rows = [body[(y * w + x0) * px:(y * w + x1) * px] for y in range(h)]
    head = bytearray(data[:18])
    head[0] = 0
    struct.pack_into("<HH", head, 12, x1 - x0, h)
    return bytes(head) + b"".join(rows)


def slice_background(src, write, base, variant):
    w = struct.unpack_from("<H", src, 12)[0]
    xs = [round(c * w / 1024) for c in CUTS]
    for name, x0, x1 in zip(SLICES, xs, xs[1:]):
        write(f"{variant}/{name}.tga", crop_tga(src, x0, x1), base)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--aspect", default="16:9")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    aw, ah = (float(x) for x in a.aspect.split(":"))
    width = 768 * aw / ah
    e = width - 1024
    print(f"virtual UI width {num(width)} (extra {num(e)})")
    data = Rwd(game / "Data.rwd")
    out = game / "data"
    manifest = out / "widescreen-generated.txt"
    if manifest.exists():  # remove what the previous run generated
        for rel in manifest.read_text(encoding="utf-8").splitlines():
            (game / rel).unlink(missing_ok=True)
        manifest.unlink()
    written = []

    def write(rel, payload, base=None):
        p = (base or out) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(payload)
        written.append(p)

    def save_manifest():
        out.mkdir(parents=True, exist_ok=True)
        manifest.write_text("\n".join(str(p.relative_to(game)) for p in written) + "\n", encoding="utf-8")

    avars = data.read("AVars.tgi")
    avars, n = re.subn(rb"(float InterfacePositioningWidth = )1024", lambda m: m.group(1) + num(width).encode(), avars)
    if n != 1:
        raise SystemExit("InterfacePositioningWidth not found in AVars.tgi")
    write("AVars.tgi", avars)
    if e <= 0:
        save_manifest()
        print("aspect is 4:3 or narrower; only AVars written")
        return

    by_file = {}
    for f, line, kind in RULES:
        by_file.setdefault(f, []).append((line, kind))
    for f, rules in by_file.items():
        raw = data.read(f).decode("latin-1").splitlines(keepends=True)
        ends = [l[len(l.rstrip("\r\n\x0b\x0c\x1c\x1d\x1e\x85")):] for l in raw]
        lines = [l[:len(l) - len(end)] for l, end in zip(raw, ends)]
        for line, kind in sorted(rules, key=lambda r: -r[0]):  # bottom-up: width rules may insert lines
            if a.verbose:
                print(f"  {f}:{line} {kind}")
            try:
                apply_rule(lines, line, kind, e, a.verbose)
            except ValueError as err:
                raise SystemExit(f"{f}: {err}")
        text = "".join(l + end for l, end in zip(lines, ends))
        if f == "UI/Game/control_panel.tgi":
            text = control_panel_art(text, e)
        write(f, text.encode("latin-1"))

    if "UI/Game/control_panel.tgi" not in by_file:
        write("UI/Game/control_panel.tgi", control_panel_art(data.read("UI/Game/control_panel.tgi").decode("latin-1"), e).encode("latin-1"))
    for v in CP_VARIANTS:
        slice_background(data.read(f"{v}/Background.tga"), write, out, v)
    for nation in NATIONS:
        skin = Rwd(game / "skins" / f"{nation}.rwd")
        for v in CP_VARIANTS:
            if skin.has(f"{v}/Background.tga"):
                slice_background(skin.read(f"{v}/Background.tga"), write, game / "skins" / nation, v)
        skin.close()
    save_manifest()
    print(f"wrote {len(written)} files (layouts, settings, control panel slices for default + {len(NATIONS)} skins)")


if __name__ == "__main__":
    main()
