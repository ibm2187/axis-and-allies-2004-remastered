"""Reverse-engineering helper for AA.exe (32-bit PE).

usage:
  aa_re.py <exe> floats <value> [...]      find float32/float64 constants in data sections
  aa_re.py <exe> str <regex>               find ASCII and UTF-16LE strings (VA)
  aa_re.py <exe> xrefs <va> [...]          find code that references an absolute VA
  aa_re.py <exe> dis <va> [count]          disassemble from VA
  aa_re.py <exe> func <va>                 disassemble the function containing VA (heuristic start)
Run with a venv that has capstone installed.
"""
import re
import struct
import sys

from capstone import CS_ARCH_X86, CS_MODE_32, Cs


class PE:
    def __init__(self, path):
        self.data = open(path, "rb").read()
        pe = struct.unpack_from("<I", self.data, 0x3C)[0]
        nsec = struct.unpack_from("<H", self.data, pe + 6)[0]
        optsize = struct.unpack_from("<H", self.data, pe + 20)[0]
        self.base = struct.unpack_from("<I", self.data, pe + 24 + 28)[0]
        self.sections = []
        for i in range(nsec):
            o = pe + 24 + optsize + 40 * i
            name = self.data[o:o + 8].rstrip(b"\0").decode()
            vsize, va, rsize, rptr = struct.unpack_from("<IIII", self.data, o + 8)
            self.sections.append((name, self.base + va, max(vsize, rsize), rptr, rsize))
        self.cs = Cs(CS_ARCH_X86, CS_MODE_32)

    def sec(self, name):
        return next(s for s in self.sections if s[0] == name)

    def off(self, va):
        for name, sva, size, rptr, rsize in self.sections:
            if sva <= va < sva + rsize:
                return va - sva + rptr
        raise ValueError(f"VA {va:#x} not in file")

    def va(self, off):
        for name, sva, size, rptr, rsize in self.sections:
            if rptr <= off < rptr + rsize:
                return off - rptr + sva
        return None

    def dis(self, va, count=40):
        o = self.off(va)
        return list(self.cs.disasm(self.data[o:o + count * 16], va, count))

    def text_bytes(self):
        name, sva, size, rptr, rsize = self.sec(".text")
        return sva, self.data[rptr:rptr + rsize]

    def xrefs(self, target):
        """Instructions in .text whose encoding contains the absolute address `target`."""
        sva, code = self.text_bytes()
        needle = struct.pack("<I", target)
        out = []
        mem = f"[0x{target:x}"
        for m in re.finditer(re.escape(needle), code):
            pos = m.start()
            cands = []
            for back in range(1, 12):  # instructions starting before pos that span the needle
                start = pos - back
                ins = next(self.cs.disasm(code[start:start + 16], sva + start, 1), None)
                if ins and start + ins.size >= pos + 4 and ins.size > back:
                    cands.append(ins)
            # prefer a memory operand, then a push/mov immediate, else the shortest decode
            best = (next((c for c in cands if mem in c.op_str), None)
                    or next((c for c in cands if c.mnemonic in ("push", "mov") and f"0x{target:x}" in c.op_str), None)
                    or (cands[0] if cands else None))
            if best:
                out.append(best)
        return out

    def func_start(self, va):
        """Walk back to a likely function start (after int3/ret padding, or push ebp; mov ebp, esp)."""
        sva, code = self.text_bytes()
        i = va - sva
        while i > 0:
            if code[i - 1] in (0xCC, 0x90) and code[i] not in (0xCC, 0x90):
                return sva + i
            if code[i:i + 3] == b"\x55\x8b\xec" and code[i - 1] in (0xC3, 0xCC, 0x90) :
                return sva + i
            i -= 1
        return sva


def fmt(ins):
    return f"{ins.address:08X}  {ins.bytes.hex():<20} {ins.mnemonic} {ins.op_str}"


def main():
    pe = PE(sys.argv[1])
    cmd, args = sys.argv[2], sys.argv[3:]
    if cmd == "floats":
        for a in args:
            v = float(a)
            for kind, pat in (("f32", struct.pack("<f", v)), ("f64", struct.pack("<d", v))):
                for name in (".rdata", ".data"):
                    s = pe.sec(name)
                    blob = pe.data[s[3]:s[3] + s[4]]
                    hits = [s[1] + m.start() for m in re.finditer(re.escape(pat), blob) if m.start() % 4 == 0]
                    for h in hits:
                        print(f"{a} {kind} {name} {h:08X}  xrefs={len(pe.xrefs(h))}")
    elif cmd == "str":
        rx = re.compile(args[0])
        for m in re.finditer(rb"[\x20-\x7e]{4,}", pe.data):
            if rx.search(m.group().decode()):
                print(f"{pe.va(m.start()) or 0:08X}  {m.group().decode()}")
        for m in re.finditer(rb"(?:[\x20-\x7e]\x00){4,}", pe.data):
            s = m.group().decode("utf-16-le")
            if rx.search(s):
                print(f"{pe.va(m.start()) or 0:08X}  L\"{s}\"")
    elif cmd == "xrefs":
        for a in args:
            for ins in pe.xrefs(int(a, 16)):
                print(fmt(ins))
    elif cmd == "dis":
        for ins in pe.dis(int(args[0], 16), int(args[1]) if len(args) > 1 else 40):
            print(fmt(ins))
    elif cmd == "func":
        start = pe.func_start(int(args[0], 16))
        print(f"; function start ~{start:08X}")
        for ins in pe.dis(start, 400):
            print(fmt(ins))
            if ins.mnemonic == "ret" and ins.address > int(args[0], 16):
                break


if __name__ == "__main__":
    main()
