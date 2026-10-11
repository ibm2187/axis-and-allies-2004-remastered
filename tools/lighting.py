"""Relight the maps of Axis & Allies (2004): less ambient, a warmer sun.

Every shipped map embeds its own light in the SUN entry of the .rmp (the Sun/*.tgi presets are
not used): sun direction 0.41,0.41,-0.82, diffuse 1.0 and ambient 0.8 (1.0 on two). Units and
buildings are lit ambient + diffuse * N.L, so anything facing the sun even slightly clips to full
brightness and models look flat. This writes the maps as loose overrides under data/Maps/ with
a lower, slightly cool ambient and a slightly warm sun; direction and specular stay as they were.

.rmp layout: "TGCK", u32 version, u32 count; entry data from byte 12; at the end, count 96-byte
directory records (64-byte UTF-16 name, u64 offset, u64 stored size, u64 FILETIME, u64 size).
Entries are zlib streams unless stored size == size. SUN: i32 version, i32 1, i32 -1, then two
sets of light colours (direction, diffuse, ambient, specular; diffuse, ambient, specular), ...

Note: modified maps have different checksums, so LAN games need the same overrides on every PC.

usage: lighting.py <game dir> [--ambient r,g,b] [--diffuse r,g,b] [--off]
Written files are listed in data/lighting-generated.txt (removed on the next run or with --off).
"""
import argparse
import pathlib
import struct
import sys
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rwd import Rwd  # noqa: E402

AMBIENT = (0.55, 0.57, 0.62)
DIFFUSE = (1.0, 0.97, 0.90)
SUN_DIR = (0.408, 0.408, -0.816)


def rgb(s):
    v = tuple(float(x) for x in s.split(","))
    if len(v) != 3:
        raise argparse.ArgumentTypeError("expected r,g,b")
    return v


def entries(b):
    magic, _, count = struct.unpack_from("<4sII", b, 0)
    if magic != b"TGCK":
        raise ValueError("not a TGCK map")
    d0 = len(b) - 96 * count
    out = []
    for i in range(count):
        o = d0 + 96 * i
        name = b[o:o + 64].decode("utf-16-le").rstrip("\0")
        off, size, ft, usize = struct.unpack_from("<QQQQ", b, o + 64)
        out.append([name, off, size, ft, usize, b[o:o + 64]])
    return out, d0


def relight(b, ambient, diffuse):
    ents, d0 = entries(b)
    blobs = []
    pos = 12
    for e in sorted(ents, key=lambda e: e[1]):
        name, off, size, ft, usize, raw_name = e
        if off != pos:
            raise ValueError(f"{name}: entries not contiguous")
        blob = b[off:off + size]
        pos = off + size
        if name == "SUN":
            sun = bytearray(zlib.decompress(blob))
            if len(sun) != 134 or any(abs(a - c) > 0.01 for a, c in zip(struct.unpack_from("<3f", sun, 12), SUN_DIR)):
                raise ValueError("unexpected SUN entry")
            # set 1: dir @12, diffuse @24, ambient @36, specular @48; set 2: diffuse @60, ambient @72
            for o in (24, 60):
                struct.pack_into("<3f", sun, o, *diffuse)
            for o in (36, 72):
                struct.pack_into("<3f", sun, o, *ambient)
            blob = zlib.compress(bytes(sun), 9)
            size, usize = len(blob), len(sun)
        blobs.append((name, blob, ft, usize, raw_name))
    if pos != d0:
        raise ValueError("trailing data before the directory")
    data = bytearray(b[:12])
    dirs = {}
    for name, blob, ft, usize, raw_name in blobs:
        dirs[name] = raw_name + struct.pack("<QQQQ", len(data), len(blob), ft, usize)
        data += blob
    for e in ents:  # directory in its original order
        data += dirs[e[0]]
    return bytes(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir")
    ap.add_argument("--ambient", type=rgb, default=AMBIENT)
    ap.add_argument("--diffuse", type=rgb, default=DIFFUSE)
    ap.add_argument("--off", action="store_true", help="only remove previously generated maps")
    a = ap.parse_args()
    game = pathlib.Path(a.game_dir)
    manifest = game / "data" / "lighting-generated.txt"
    if manifest.exists():
        for rel in manifest.read_text(encoding="utf-8").splitlines():
            (game / rel).unlink(missing_ok=True)
        manifest.unlink()
    if a.off:
        print("removed relit maps")
        return
    data = Rwd(game / "Data.rwd")
    written = []
    for n in sorted(x for x in data.names() if x.lower().endswith(".rmp")):
        try:
            out = relight(data.read(n), a.ambient, a.diffuse)
        except ValueError as err:
            print(f"  skipped {n}: {err}")
            continue
        dest = game / "data" / n
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(out)
        written.append(dest)
    manifest.write_text("\n".join(str(p.relative_to(game)) for p in written) + "\n", encoding="utf-8")
    print(f"relit {len(written)} maps: ambient {a.ambient}, sun {a.diffuse}")


if __name__ == "__main__":
    main()
