"""Read-only memory scanner for a running AA.exe (32-bit). Never writes to the process.

usage:
  memscan.py pairs <a> <b> [<a> <b> ...]   find float32 a and b stored within 16 bytes of each other
  memscan.py floats <v> [...]              find float32 values
  memscan.py ints <v> [...]                find int32 values in the EXE's own .data/.bss image region
  memscan.py dump <hexaddr> [n]            dump n dwords as int/float
"""
import ctypes
import ctypes.wintypes as wt
import struct
import subprocess
import sys

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
PROCESS_VM_READ, PROCESS_QUERY_INFORMATION = 0x10, 0x400
MEM_COMMIT, PAGE_GUARD, PAGE_NOACCESS = 0x1000, 0x100, 0x01


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p), ("AllocationProtect", wt.DWORD),
                ("PartitionId", wt.WORD), ("RegionSize", ctypes.c_size_t), ("State", wt.DWORD), ("Protect", wt.DWORD), ("Type", wt.DWORD)]


def pid_of(name="AA.exe"):
    out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {name}", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout
    return int(out.split(",")[1].strip('"'))


def regions(h):
    addr, mbi = 0, MBI()
    while addr < 0x7FFF0000 and k32.VirtualQueryEx(h, ctypes.c_void_p(addr), ctypes.byref(mbi), ctypes.sizeof(mbi)):
        size = mbi.RegionSize
        if mbi.State == MEM_COMMIT and not (mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS)):
            yield addr, size, mbi.Type
        addr += size


def read(h, addr, size):
    buf, n = ctypes.create_string_buffer(size), ctypes.c_size_t()
    if k32.ReadProcessMemory(h, ctypes.c_void_p(addr), buf, size, ctypes.byref(n)):
        return buf.raw[:n.value]
    return b""


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    h = k32.OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid_of())
    if not h:
        raise OSError(ctypes.get_last_error())
    if cmd == "dump":
        a, n = int(args[0], 16), int(args[1]) if len(args) > 1 else 16
        data = read(h, a, n * 4)
        for i in range(0, len(data), 4):
            iv, fv = struct.unpack_from("<i", data, i)[0], struct.unpack_from("<f", data, i)[0]
            print(f"{a + i:08X}  {iv:>12}  {fv:.6g}")
        return
    for base, size, typ in regions(h):
        if cmd == "ints" and not (0x400000 <= base < 0x1000000):
            continue
        data = read(h, base, size)
        if cmd == "pairs":
            vals = [float(x) for x in args]
            for a, b in zip(vals[::2], vals[1::2]):
                pa, pb = struct.pack("<f", a), struct.pack("<f", b)
                i = data.find(pa)
                while i != -1:
                    if i % 4 == 0:
                        for j in range(max(0, i - 16), min(len(data) - 3, i + 20), 4):
                            if j != i and data[j:j + 4] == pb:
                                print(f"{base + i:08X}  {a} with {b} at {base + j:08X}  type={typ:#x}")
                    i = data.find(pa, i + 1)
        else:
            for v in args:
                pat = struct.pack("<f", float(v)) if cmd == "floats" else struct.pack("<i", int(v))
                i = data.find(pat)
                while i != -1:
                    if i % 4 == 0:
                        print(f"{base + i:08X}  {v}  type={typ:#x}")
                    i = data.find(pat, i + 1)


if __name__ == "__main__":
    main()
