"""Index L/T/R/B layout entries in extracted UI .tgi files and match them to runtime view elements.

usage:
  ui_layout.py index <extracted Data dir>                         print every layout entry
  ui_layout.py match <extracted Data dir> <memscan ves output>    map runtime elements to file entries
"""
import pathlib
import re
import sys

COORD = re.compile(r"^(\s*)(L|T|R|B)(\s*=\s*)([+-]?[0-9.]+)(%|r|b|t)?(\s*(?:;.*)?)$")
HEADER = re.compile(r"^\s*\[([^\]\s]+)")


def entries(root):
    """Yield (file, line_no_of_L, block_path, {L,T,R,B: token}) for each run of coordinate lines."""
    for f in sorted(pathlib.Path(root, "UI").rglob("*.tgi")):
        lines = f.read_bytes().decode("latin-1").splitlines()
        stack, cur, start = [], {}, None
        for n, line in enumerate(lines, 1):
            h = HEADER.match(line)
            if h:
                stack.append(h.group(1))
                stack = stack[-4:]
            m = COORD.match(line)
            if m:
                if not cur:
                    start = n
                cur[m.group(2)] = (m.group(4), m.group(5) or "")
                continue
            if cur and line.strip() and not line.strip().startswith(";"):
                yield f, start, "/".join(stack), cur
                cur = {}
        if cur:
            yield f, start, "/".join(stack), cur


def fmt(c):
    return " ".join(f"{k}={v[0]}{v[1]}" for k, v in c.items())


def main():
    cmd, root = sys.argv[1], sys.argv[2]
    idx = list(entries(root))
    if cmd == "index":
        for f, n, path, c in idx:
            print(f"{f.relative_to(root)}:{n} [{path}] {fmt(c)}")
        return
    rx = re.compile(r"^(\w+) vt=(\w+) raw=\(([^)]*)\) scr=\(([^)]*)\)")
    for line in open(sys.argv[3]):
        m = rx.match(line)
        if not m:
            continue
        raw = [float(x) for x in m.group(3).split(",")]
        hits = []
        for f, n, path, c in idx:
            try:
                vals = [abs(float(c[k][0])) for k in "LTRB"]
            except KeyError:
                continue
            if all(abs(a - b) < 0.05 for a, b in zip(vals, raw)):
                hits.append(f"{f.relative_to(root)}:{n} [{path}] {fmt(c)}")
        print(f"raw=({m.group(3)}) scr=({m.group(4)})")
        for hit in hits[:6]:
            print("    " + hit)
        if not hits:
            print("    (no file match)")


if __name__ == "__main__":
    main()
