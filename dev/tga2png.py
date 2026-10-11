"""Convert uncompressed 32-bit TGA to PNG on a dark background, scaled up. usage: tga2png.py in.tga out.png [scale]"""
import struct, sys, zlib
src, dst = sys.argv[1], sys.argv[2]; k = int(sys.argv[3]) if len(sys.argv) > 3 else 1
d = open(src, "rb").read()
idlen, _, itype = d[0], d[1], d[2]
w, h, bpp, desc = struct.unpack_from("<HHBB", d, 12)
assert itype == 2 and bpp == 32, (itype, bpp)
px = d[18 + idlen:]
top_down = bool(desc & 0x20)
rows = []
for y in range(h):
    sy = y if top_down else h - 1 - y
    r = bytearray()
    for x in range(w):
        b, g, rr, a = px[(sy * w + x) * 4:(sy * w + x) * 4 + 4]
        bg = 40
        c = [(ch * a + bg * (255 - a)) // 255 for ch in (rr, g, b)]
        r += bytes(c) * k
    rows += [bytes(r)] * k
raw = b"".join(b"\0" + r for r in rows)
def chunk(t, p): return struct.pack(">I", len(p)) + t + p + struct.pack(">I", zlib.crc32(t + p))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * k, h * k, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
open(dst, "wb").write(png); print(dst, w, h)
