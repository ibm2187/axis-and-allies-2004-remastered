"""Set or clear IMAGE_FILE_LARGE_ADDRESS_AWARE (0x20) on a 32-bit PE and fix its checksum.

usage: python -I laa.py <exe> [--check | --set | --clear]
"""
import os
import stat
import struct
import sys

LAA = 0x20


def pe_checksum(data: bytes, checksum_off: int) -> int:
    total = 0
    buf = bytearray(data)
    buf[checksum_off:checksum_off + 4] = b"\0\0\0\0"
    if len(buf) % 2:
        buf.append(0)
    for (word,) in struct.iter_unpack("<H", buf):
        total += word
        total = (total & 0xFFFF) + (total >> 16)
    total = (total & 0xFFFF) + (total >> 16)
    return (total + len(data)) & 0xFFFFFFFF


def main() -> None:
    path, mode = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "--check")
    data = bytearray(open(path, "rb").read())
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe:pe + 4] == b"PE\0\0", "not a PE file"
    chars_off = pe + 22
    checksum_off = pe + 24 + 64
    chars = struct.unpack_from("<H", data, chars_off)[0]
    old_sum = struct.unpack_from("<I", data, checksum_off)[0]
    print(f"Characteristics @0x{chars_off:X}: 0x{chars:04X}  LAA={bool(chars & LAA)}")
    print(f"CheckSum        @0x{checksum_off:X}: 0x{old_sum:08X}")
    if mode == "--check":
        return
    new = chars | LAA if mode == "--set" else chars & ~LAA
    if new == chars:
        print("No change needed.")
        return
    struct.pack_into("<H", data, chars_off, new)
    if old_sum:
        struct.pack_into("<I", data, checksum_off, pe_checksum(bytes(data), checksum_off))
    os.chmod(path, os.stat(path).st_mode | stat.S_IWRITE)
    with open(path, "r+b") as f:
        f.write(data)
    print(f"Characteristics now 0x{new:04X}, CheckSum now 0x{struct.unpack_from('<I', data, checksum_off)[0]:08X}")


if __name__ == "__main__":
    main()
