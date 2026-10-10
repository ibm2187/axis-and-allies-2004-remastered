"""Small, reversible byte patches to AA.exe (v1.0.5.0, build 4129.7). Each patch checks the original
bytes before writing, so it refuses to touch a different build.

usage: exe_patch.py <AA.exe> [--check | --apply | --revert]
"""
import os
import stat
import sys

# (name, file offset, original bytes, patched bytes, description)
PATCHES = [
    ("font-unit-pixel", 0x3089CF, b"\x6a\x03", b"\x6a\x02",
     "VA 0x7089CF: Gdiplus::Font(..., UnitPoint) -> UnitPixel, so text size no longer grows with "
     "Windows display scaling (fonts.py scales sizes by 4/3 to keep the 96-DPI look)"),
]


def main():
    path, mode = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "--check")
    data = bytearray(open(path, "rb").read())
    changed = False
    for name, off, old, new, desc in PATCHES:
        cur = bytes(data[off:off + len(old)])
        state = "applied" if cur == new else "original" if cur == old else "UNKNOWN"
        print(f"{name}: {state} ({desc})")
        if state == "UNKNOWN":
            raise SystemExit(f"{name}: unexpected bytes {cur.hex()} at {off:#x}; not this build?")
        want = new if mode == "--apply" else old if mode == "--revert" else cur
        if want != cur:
            data[off:off + len(old)] = want
            changed = True
            print(f"  -> {'applied' if want == new else 'reverted'}")
    if changed:
        os.chmod(path, os.stat(path).st_mode | stat.S_IWRITE)
        with open(path, "r+b") as f:
            f.write(data)


if __name__ == "__main__":
    main()
