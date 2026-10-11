"""Print a TrueType font's version, table list and cmap subtables. usage: python -I ttfinfo.py <font>..."""
import struct
import sys

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    off = 0
    if data[:4] == b"ttcf":
        off = struct.unpack_from(">I", data, 12)[0]
        print(f"{path}: TTC with {struct.unpack_from('>I', data, 8)[0]} fonts, showing first")
    sfnt, ntables = struct.unpack_from(">IH", data, off)
    tables = {}
    for i in range(ntables):
        tag, _, toff, tlen = struct.unpack_from(">4sIII", data, off + 12 + 16 * i)
        tables[tag.decode("latin-1")] = (toff, tlen)
    print(f"{path}: sfnt=0x{sfnt:08X} size={len(data)} tables={sorted(tables)}")
    head = tables.get("head")
    if head:
        print("  head fontRevision: %.3f" % (struct.unpack_from(">i", data, head[0] + 4)[0] / 65536))
    coff = tables["cmap"][0]
    _, n = struct.unpack_from(">HH", data, coff)
    for i in range(n):
        pid, eid, soff = struct.unpack_from(">HHI", data, coff + 4 + 8 * i)
        fmt = struct.unpack_from(">H", data, coff + soff)[0]
        print(f"  cmap platform={pid} encoding={eid} format={fmt}")
    os2 = tables.get("OS/2")
    if os2:
        ver = struct.unpack_from(">H", data, os2[0])[0]
        r = struct.unpack_from(">IIII", data, os2[0] + 42)
        print(f"  OS/2 v{ver} unicodeRange={' '.join(f'{x:08X}' for x in r)}")
