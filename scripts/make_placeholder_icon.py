#!/usr/bin/env python3
"""產一張純色佔位 PNG（無外部相依，純 stdlib zlib/struct）。
`10_PHASE5_SPEC.md` §5.3：正式 App icon 留 Phase 4 美術，Phase 5 只需佔位讓雙擊/關於不空白。
用陶紅 #C56A4E（`03_DESIGN_SYSTEM.md` 角色主色）填滿方塊。
"""
import struct
import sys
import zlib

def write_png(path: str, size: int, rgba):
    raw = bytearray()
    row = bytes(rgba) * size
    for _ in range(size):
        raw.append(0)  # filter type 0 (none)
        raw.extend(row)
    compressed = zlib.compress(bytes(raw), 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")

    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png"
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    write_png(out_path, size, (0xC5, 0x6A, 0x4E, 255))
    print(f"wrote {out_path} ({size}x{size})")
