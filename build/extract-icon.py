#!/usr/bin/env python3
"""Extract the main icon group from a Windows PE .exe as an .ico file (stdlib only).

Usage: extract-icon.py <file.exe> <out.ico>
"""
import struct
import sys

RT_ICON, RT_GROUP_ICON = 3, 14


def main(exe_path, out_path):
    d = open(exe_path, "rb").read()
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    optsz = struct.unpack_from("<H", d, pe + 20)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", d, opt)[0]
    ddir = opt + (96 if magic == 0x10B else 112)
    rsrc_rva = struct.unpack_from("<I", d, ddir + 2 * 8)[0]
    secs = []
    for i in range(nsec):
        s = opt + optsz + i * 40
        vsz, va, rawsz, rawptr = struct.unpack_from("<IIII", d, s + 8)
        secs.append((va, max(vsz, rawsz), rawptr))

    def off(rva):
        for va, sz, raw in secs:
            if va <= rva < va + sz:
                return rva - va + raw
        raise ValueError(hex(rva))

    base = off(rsrc_rva)

    def entries(dir_off):
        named, ids = struct.unpack_from("<HH", d, base + dir_off + 12)
        for k in range(named + ids):
            name, ptr = struct.unpack_from("<II", d, base + dir_off + 16 + k * 8)
            yield name, ptr

    def leaf(ptr):
        # descend through subdirectories (name -> language) to the data entry
        while ptr & 0x80000000:
            ptr = next(entries(ptr & 0x7FFFFFFF))[1]
        rva, size = struct.unpack_from("<II", d, base + ptr)
        return d[off(rva):off(rva) + size]

    by_type = {}
    for t, ptr in entries(0):
        by_type[t] = {n: p for n, p in entries(ptr & 0x7FFFFFFF)}

    icons = by_type[RT_ICON]
    group = leaf(next(iter(by_type[RT_GROUP_ICON].values())))
    count = struct.unpack_from("<H", group, 4)[0]
    images = []
    for k in range(count):
        e = group[6 + k * 14: 6 + (k + 1) * 14]
        w, h, colors, _, planes, bpp, size, icon_id = struct.unpack("<BBBBHHIH", e)
        images.append((e[:12], leaf(icons[icon_id])))
        print(f"  {w or 256}x{h or 256} {bpp}bpp")

    out = bytearray(struct.pack("<HHH", 0, 1, len(images)))
    pos = 6 + 16 * len(images)
    for hdr, data in images:
        out += hdr[:8] + struct.pack("<II", len(data), pos)
        pos += len(data)
    for _, data in images:
        out += data
    open(out_path, "wb").write(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
