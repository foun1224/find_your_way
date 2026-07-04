#!/usr/bin/env python3
# Find Your Way — 角色像素 sprite 樣本（純標準庫產 PNG）
# 手工像素圖，用專案調色盤（03_DESIGN_SYSTEM §1.2）。側面朝右的中古旅人。
import zlib, struct

# 調色盤（legend -> RGBA）
PAL = {
    '.': (0, 0, 0, 0),          # 透明
    'o': (0x3A, 0x33, 0x30, 255),  # Ink Umber 描邊（暖黑）
    'H': (0xE6, 0xEC, 0xF3, 255),  # 白髮/兜帽緣
    'h': (0xC9, 0xD2, 0xDE, 255),  # 髮陰影
    'S': (0xEB, 0xC4, 0x9A, 255),  # 膚色
    's': (0xC9, 0x9E, 0x74, 255),  # 膚陰影
    'R': (0xC5, 0x6A, 0x4E, 255),  # Traveler Terracotta 袍主色
    'D': (0x9B, 0x4E, 0x38, 255),  # 袍陰影
    'L': (0xDB, 0x8B, 0x70, 255),  # 袍亮部
    'P': (0xA6, 0x76, 0x3E, 255),  # 背包
    'p': (0x7A, 0x56, 0x30, 255),  # 背包陰影
    'B': (0x4A, 0x37, 0x28, 255),  # 靴/腰帶
    'g': (0x8A, 0x6A, 0x44, 255),  # 木杖
}

# 20 寬 × 32 高，側面朝右的披風旅人（白髮、背包、木杖、瘦身版）
SPRITE = [
    "....................",  # 0
    "...........g........",  # 1  木杖頂
    "......oooo.g........",  # 2
    ".....oHHHHo.g.......",  # 3  兜帽/白髮
    "....oHHHHHHog.......",  # 4
    "....oHhHHSSog.......",  # 5  臉朝右
    "....oHhHSSSog.......",  # 6
    ".....oHSSSSg........",  # 7
    "......ossog.........",  # 8  頸
    ".....ooRRRog........",  # 9  肩
    "....oPpRRRRgo.......",  # 10 背包+披風+握杖
    "...oPPpRRRRLo.......",  # 11
    "...oPPpRRRRLo.......",  # 12
    "....opRRRRLLo.......",  # 13 手臂
    ".....oRRRRLLo.......",  # 14
    ".....oRRRRLLo.......",  # 15
    ".....oRRRRLLo.......",  # 16
    ".....oRRRRLDo.......",  # 17
    ".....oRRRRLDo.......",  # 18
    ".....oRRRRDDo.......",  # 19
    ".....oRRRRDDo.......",  # 20 披風下擺
    "......oRRRDo........",  # 21
    "......oRRRDo........",  # 22
    "......oo.ooo........",  # 23 雙腿分開
    ".....oBo.oBo........",  # 24
    ".....oBo.oBo........",  # 25
    "....oBBo.oBo........",  # 26 前腳跨步
    "....oBBo.oBBo.......",  # 27
    "...oBBBo.oBBBo......",  # 28 靴
    "....ooo..ooo........",  # 29
    "....................",  # 30
    "....................",  # 31
]

def encode_png(pixels, w, h):
    # pixels: list of (r,g,b,a) row-major
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter type 0
        for x in range(w):
            raw.extend(pixels[y * w + x])
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")

def render(grid, scale, bg=None):
    gh = len(grid); gw = len(grid[0])
    W, H = gw * scale, gh * scale
    px = [(0,0,0,0)] * (W * H)
    # 背景（可選）：天空藍上、草地綠下、山徑赭條帶
    if bg:
        for Y in range(H):
            gy = Y // scale
            for X in range(W):
                if gy < gh * 0.5:
                    col = (0x8F, 0xC7, 0xE8, 255)      # 天空
                elif gy < gh - 4:
                    col = (0x7F, 0xB0, 0x69, 255)      # 草地
                else:
                    col = (0xC9, 0xA3, 0x6B, 255)      # 山徑
                px[Y * W + X] = col
    for gy, row in enumerate(grid):
        for gx, ch in enumerate(row):
            rgba = PAL[ch]
            if rgba[3] == 0:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    X = gx * scale + dx; Y = gy * scale + dy
                    px[Y * W + X] = rgba
    return encode_png(px, W, H)

# 驗證所有 row 同寬
assert all(len(r) == 20 for r in SPRITE), [len(r) for r in SPRITE]
assert len(SPRITE) == 32

out = "/private/tmp/claude-501/-Users-sean-chen-Desktop-project-find-your-way/7dc71c10-3e3c-4583-8710-3059fe1381f4/scratchpad/"
open(out + "sprite_transparent.png", "wb").write(render(SPRITE, 12))
open(out + "sprite_in_scene.png", "wb").write(render(SPRITE, 12, bg=True))
print("done")
