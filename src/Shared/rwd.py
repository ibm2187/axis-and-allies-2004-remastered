"""Reader for TimeGate TGCK (.rwd) archives used by Axis & Allies (2004).

Layout: the last 288 bytes are three 96-byte section descriptors (Header/Files/Footer), each a
64-byte UTF-16 name followed by offset, size, ptr, size (u64). The Footer section is the
directory: u32 count, then per entry u16 name length, UTF-16 name, u64 offset (relative to the
Files section), u64 size, u32 zero, u32 unknown.
"""
import struct


class Rwd:
    def __init__(self, path):
        self.f = open(path, "rb")
        self.f.seek(-288, 2)
        sections = {}
        for _ in range(3):
            raw = self.f.read(96)
            name = raw[:64].decode("utf-16-le").rstrip("\0")
            sections[name] = struct.unpack_from("<qq", raw, 64)
        self.files_base = sections["Files"][0]
        self.f.seek(sections["Footer"][0])
        (count,) = struct.unpack("<I", self.f.read(4))
        self.entries = {}
        for _ in range(count):
            (n,) = struct.unpack("<H", self.f.read(2))
            name = self.f.read(n * 2).decode("utf-16-le")
            off, size, _, _ = struct.unpack("<qqII", self.f.read(24))
            self.entries[name.lower()] = (name, off, size)

    def names(self):
        return [v[0] for v in self.entries.values()]

    def has(self, name):
        return name.lower() in self.entries

    def read(self, name):
        _, off, size = self.entries[name.lower()]
        self.f.seek(self.files_base + off)
        return self.f.read(size)

    def close(self):
        self.f.close()
