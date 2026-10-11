"""Disassembler for the game's compiled vertex shaders (Data.rwd Shaders/*.vso, D3D9 vs_1_1 bytecode).

usage:
  vso_dis.py <file.vso> [...]
Covers the opcodes and registers vs_1_1 uses; enough to read extrude.vso, skin.vso and skinnl.vso.
"""
import struct
import sys

OPS = {0: "nop", 1: "mov", 2: "add", 3: "sub", 4: "mad", 5: "mul", 6: "rcp", 7: "rsq", 8: "dp3",
       9: "dp4", 10: "min", 11: "max", 12: "slt", 13: "sge", 14: "exp", 15: "log", 16: "lit",
       17: "dst", 18: "lrp", 19: "frc", 20: "m4x4", 21: "m4x3", 22: "m3x4", 23: "m3x3", 24: "m3x2",
       46: "mova"}
REGS = {0: "r", 1: "v", 2: "c", 3: "a", 5: "oD", 6: "oT"}
RASTER = {0: "oPos", 1: "oFog", 2: "oPts"}
USAGE = {0: "position", 1: "blendweight", 2: "blendindices", 3: "normal", 5: "texcoord", 10: "color"}


def register(token, dest):
    number = token & 0x7FF
    kind = ((token >> 28) & 7) | ((token >> 8) & 0x18)
    if kind == 4:
        text = RASTER.get(number, "o?")
    elif kind == 2 and not dest and token & 0x2000:
        text = f"c[a0.x+{number}]"
    else:
        text = REGS.get(kind, f"?{kind}_") + str(number)
    if dest:
        mask = (token >> 16) & 0xF
        if mask != 0xF:
            text += "." + "".join("xyzw"[i] for i in range(4) if mask >> i & 1)
    else:
        swizzle = "".join("xyzw"[(token >> (16 + 2 * i)) & 3] for i in range(4))
        if swizzle != "xyzw":
            text += "." + swizzle
        if (token >> 24) & 0xF == 1:
            text = "-" + text
    return text


def disassemble(data):
    words = struct.unpack(f"<{len(data) // 4}I", data)
    yield f"vs_{(words[0] >> 8) & 0xFF}_{words[0] & 0xFF}"
    i = 1
    while i < len(words) and words[i] != 0xFFFF:
        op = words[i] & 0xFFFF
        if op == 0xFFFE:  # comment block
            i += 1 + ((words[i] >> 16) & 0x7FFF)
            continue
        if op == 81:  # def: register + four raw floats
            values = struct.unpack("<4f", struct.pack("<4I", *words[i + 2:i + 6]))
            yield f"def {register(words[i + 1], True)}, {', '.join(f'{v:g}' for v in values)}"
            i += 6
            continue
        j = i + 1  # vs_1_1 tokens carry no length: parameters have bit 31 set
        while j < len(words) and words[j] & 0x80000000:
            j += 1
        params = words[i + 1:j]
        if op == 31:
            yield f"dcl_{USAGE.get(params[0] & 0x1F, params[0] & 0x1F)}{(params[0] >> 16) & 0xF} {register(params[1], True)}"
        else:
            operands = [register(params[0], True)] + [register(p, False) for p in params[1:]]
            yield f"{OPS.get(op, f'op{op}')} {', '.join(operands)}"
        i = j


def main():
    for path in sys.argv[1:]:
        print(f"; {path}")
        for line in disassemble(open(path, "rb").read()):
            print(line)


if __name__ == "__main__":
    main()
