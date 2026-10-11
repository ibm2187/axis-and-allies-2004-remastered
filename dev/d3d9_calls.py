"""Finds IDirect3DDevice9 calls in AA.exe by vtable offset (static scan, heuristic).

usage:
  d3d9_calls.py <exe> [min_va]     count calls per method, list lighting call sites at or above min_va
Any C++ virtual call at the same vtable offset also matches, so check a site with
`aa_re.py <exe> dis <va>` before relying on it. Gamebryo's NiDX9 code sits at 0x700000 and up
(default min_va); the device is the first pushed argument.
"""
import collections
import re
import sys

from aa_re import PE

METHODS = {0xC4: "SetMaterial", 0xCC: "SetLight", 0xD4: "LightEnable", 0xE4: "SetRenderState",
           0x10C: "SetTextureStageState", 0x16C: "CreateVertexShader", 0x170: "SetVertexShader",
           0x178: "SetVertexShaderConstantF", 0x1A8: "CreatePixelShader", 0x1AC: "SetPixelShader",
           0x1B4: "SetPixelShaderConstantF"}
LIGHTING_STATES = {0x1C: "FOGENABLE", 0x1D: "SPECULARENABLE", 0x89: "LIGHTING", 0x8B: "AMBIENT",
                   0x8D: "COLORVERTEX", 0x8F: "NORMALIZENORMALS", 0x91: "DIFFUSEMATERIALSOURCE"}


def main():
    pe = PE(sys.argv[1])
    min_va = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x700000
    start, code = pe.text_bytes()
    pe.cs.skipdata = True
    counts, sites, recent = collections.Counter(), collections.defaultdict(list), []
    for ins in pe.cs.disasm(code, start):
        if ins.mnemonic == "call":
            m = re.fullmatch(r"dword ptr \[e\w\w \+ (0x[0-9a-f]+)\]", ins.op_str)
            if m and int(m.group(1), 16) in METHODS:
                name = METHODS[int(m.group(1), 16)]
                counts[name] += 1
                sites[name].append((ins.address, list(recent)))
        recent = (recent + [f"{ins.mnemonic} {ins.op_str}"])[-6:]
    for name, count in counts.most_common():
        print(f"{count:4d}  {name}")
    print()
    for name in ("SetLight", "LightEnable", "SetMaterial", "SetPixelShader", "SetVertexShader"):
        for va, before in sites[name]:
            if va >= min_va:
                print(f"{va:08X}  {name:<16} {' | '.join(before[-4:])}")
    for va, before in sites["SetRenderState"]:
        state = next((int(x[5:], 16) for x in reversed(before) if re.fullmatch(r"push 0x[0-9a-f]+", x)), None)
        if va >= min_va and state in LIGHTING_STATES:
            print(f"{va:08X}  SetRenderState   D3DRS_{LIGHTING_STATES[state]}")


if __name__ == "__main__":
    main()
