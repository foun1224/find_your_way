#!/usr/bin/env python3
"""切圖管線（Phase 4 `12_PHASE4_SPEC.md` §1）：純標準庫 PNG 讀寫 + 去背/自動裁邊/列切格。

`design/assets/asset_sheet.png` 是唯一真相來源；本腳本可重跑，產出到 `Resources/art/`。
不依賴 PIL/ImageMagick，只用 zlib + struct 自行解析/組裝 PNG。

用法：
    python3 scripts/slice_assets.py            # 產出 4a 所需資源
    python3 scripts/slice_assets.py --inspect  # 印出座標校準用的亮度剖面（除錯用，不產出檔案）
"""
from __future__ import annotations

import os
import struct
import sys
import zlib
from dataclasses import dataclass

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_SHEET = os.path.join(REPO_ROOT, "design", "assets", "asset_sheet.png")
OUT_ROOT = os.path.join(REPO_ROOT, "Resources", "art")


# ---------------------------------------------------------------------------
# PNG 解碼（8-bit RGB / RGBA，無 interlace；asset_sheet.png 為此格式）
# ---------------------------------------------------------------------------

class Image:
    """簡單的 RGBA 像素容器，`pixels[y][x]` 為 `(r, g, b, a)` tuple（0-255）。"""

    def __init__(self, width: int, height: int, pixels: list):
        self.width = width
        self.height = height
        self.pixels = pixels  # list of rows, each row = list of (r,g,b,a)

    @staticmethod
    def new(width: int, height: int, fill=(0, 0, 0, 0)) -> "Image":
        return Image(width, height, [[fill] * width for _ in range(height)])

    def get(self, x: int, y: int):
        return self.pixels[y][x]

    def set(self, x: int, y: int, rgba):
        self.pixels[y][x] = rgba

    def crop(self, x: int, y: int, w: int, h: int) -> "Image":
        rows = [row[x:x + w] for row in self.pixels[y:y + h]]
        return Image(w, h, rows)


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode_png(path: str) -> Image:
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG file"

    pos = 8
    width = height = None
    bit_depth = color_type = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break

    assert bit_depth == 8, f"unsupported bit depth {bit_depth}"
    assert color_type in (2, 6), f"unsupported color type {color_type}"  # 2=RGB, 6=RGBA
    channels = 3 if color_type == 2 else 4

    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    pixels = []
    prev = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset:offset + stride])
        offset += stride

        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filter_type == 0:
                pass
            elif filter_type == 1:
                line[i] = (line[i] + a) & 0xFF
            elif filter_type == 2:
                line[i] = (line[i] + b) & 0xFF
            elif filter_type == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif filter_type == 4:
                line[i] = (line[i] + _paeth(a, b, c)) & 0xFF
            else:
                raise ValueError(f"unsupported filter type {filter_type}")

        row = []
        for x in range(width):
            base = x * channels
            if channels == 4:
                row.append((line[base], line[base + 1], line[base + 2], line[base + 3]))
            else:
                row.append((line[base], line[base + 1], line[base + 2], 255))
        pixels.append(row)
        prev = line

    return Image(width, height, pixels)


def encode_png(img: Image, path: str) -> None:
    stride = img.width * 4
    raw = bytearray()
    for row in img.pixels:
        raw.append(0)  # filter type 0 (None) — 簡單、正確性優先於壓縮率
        for (r, g, b, a) in row:
            raw.extend((r, g, b, a))

    compressed = zlib.compress(bytes(raw), 9)

    def chunk(ctype: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + ctype
            + payload
            + struct.pack(">I", zlib.crc32(ctype + payload) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", img.width, img.height, 8, 6, 0, 0, 0)
    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(out)


# ---------------------------------------------------------------------------
# 去背 / 自動裁邊 / 列切格
# ---------------------------------------------------------------------------

def _brightness(rgba) -> int:
    r, g, b, _ = rgba
    return (r + g + b) // 3


def chroma_key_flood(img: Image, threshold: int = 28) -> Image:
    """近黑底去背：只把「從畫布四邊 flood-fill 連通、且亮度 < threshold」的像素轉透明。
    這樣角色的暗部（靴子、陰影描邊）若沒有連到邊界就不會被誤挖空（`12` §1 / §7 風險）。
    """
    w, h = img.width, img.height
    visited = [[False] * w for _ in range(h)]
    out = Image(w, h, [row[:] for row in img.pixels])

    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))

    while stack:
        x, y = stack.pop()
        if x < 0 or x >= w or y < 0 or y >= h or visited[y][x]:
            continue
        visited[y][x] = True
        if _brightness(img.get(x, y)) >= threshold:
            continue
        r, g, b, _ = out.get(x, y)
        out.set(x, y, (r, g, b, 0))
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))

    return out


def despeckle_neutral_residue(img: Image, lo: int = 24, hi: int = 45, max_spread: int = 8) -> Image:
    """清掉「殘留背景色」的雜點像素：素材表底色是近乎無彩度的深灰 #1B1B1B（≈27,27,27），
    跟 `chroma_key_flood` 的 threshold（28）太接近，邊界像素常落在 27-33 附近而漏網
    （亮度剛好卡在 threshold 兩側）。這批殘留像素的特徵是「亮度落在窄帶內、且幾乎無彩度
    （r/g/b 三色非常接近）」；相對地，角色本體的暗部（髮絲陰影、皮革、瞳孔）即使很暗，
    也都帶有明顯色相（暖棕/冷藍等），spread 遠大於這裡的門檻，不會被誤清。
    這一步是純顏色判斷（不看連通性），所以就算雜點像素直接貼著角色邊緣（例如頭髮邊界），
    也能清掉——`chroma_key_flood`／`keep_largest_component` 都無法處理這種「貼在本體上」的殘留。
    """
    w, h = img.width, img.height
    out = Image(w, h, [row[:] for row in img.pixels])
    for y in range(h):
        for x in range(w):
            r, g, b, a = out.pixels[y][x]
            if a == 0:
                continue
            brightness = (r + g + b) // 3
            spread = max(r, g, b) - min(r, g, b)
            if lo <= brightness <= hi and spread <= max_spread:
                out.pixels[y][x] = (r, g, b, 0)
    return out


def keep_largest_component(img: Image) -> Image:
    """去背後常殘留「未連到畫布邊界、亮度剛好卡在 threshold 附近」的孤立暗色雜點
    （素材表背景近黑色 #1B1B1B 本身就落在 27-30 左右，跟 `chroma_key_flood` 的
    threshold=28 太接近，導致部分背景像素沒被 flood 到、留下散落雜點——例如主角
    頭部右上那撮雜點）。這裡用連通元件分析清掉它們：主角/旅伴走路 frame 本體
    永遠是單一個大連通塊（頭髮/描邊/靴子暗部都跟身體相連），其餘每個 frame 只會
    殘留數十像素等級的小雜點，因此「只保留最大連通塊、其餘轉透明」對本體零傷害。
    """
    w, h = img.width, img.height
    visited = [[False] * w for _ in range(h)]
    best_pixels: list = []

    for sy in range(h):
        for sx in range(w):
            if visited[sy][sx] or img.get(sx, sy)[3] == 0:
                continue
            stack = [(sx, sy)]
            visited[sy][sx] = True
            pixels = []
            while stack:
                x, y = stack.pop()
                pixels.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and img.get(nx, ny)[3] > 0:
                        visited[ny][nx] = True
                        stack.append((nx, ny))
            if len(pixels) > len(best_pixels):
                best_pixels = pixels

    keep = set(best_pixels)
    out = Image(w, h, [row[:] for row in img.pixels])
    for y in range(h):
        for x in range(w):
            if out.pixels[y][x][3] > 0 and (x, y) not in keep:
                r, g, b, _ = out.pixels[y][x]
                out.pixels[y][x] = (r, g, b, 0)
    return out


def remove_small_components(img: Image, min_area: int = 12) -> Image:
    """去背後常殘留「未連到畫布邊界、亮度剛好卡在 threshold 附近」的孤立暗色雜點
    （原因同 `keep_largest_component` 的說明）。道具（`slice_props`）跟角色走路 frame
    不同：不少道具本體本來就是「多個分離部件」組成（例如柵欄是好幾根柱子中間有透明間隙、
    路標是柱+牌、haycart 是車體+輪子），若直接套用「只留最大連通塊」會把這些合理部件
    誤刪成只剩最大的一塊。因此這裡改用「面積門檻」：只清掉像素數 < `min_area`
    （數十像素等級的雜點）的連通塊，其餘（不論大小、只要夠大）一律保留，
    對道具的多部件結構零傷害，仍能清掉散落雜點。
    """
    w, h = img.width, img.height
    visited = [[False] * w for _ in range(h)]
    small: list = []

    for sy in range(h):
        for sx in range(w):
            if visited[sy][sx] or img.get(sx, sy)[3] == 0:
                continue
            stack = [(sx, sy)]
            visited[sy][sx] = True
            pixels = [(sx, sy)]
            while stack:
                x, y = stack.pop()
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and img.get(nx, ny)[3] > 0:
                        visited[ny][nx] = True
                        pixels.append((nx, ny))
                        stack.append((nx, ny))
            if len(pixels) < min_area:
                small.extend(pixels)

    out = Image(w, h, [row[:] for row in img.pixels])
    for (x, y) in small:
        r, g, b, _ = out.pixels[y][x]
        out.pixels[y][x] = (r, g, b, 0)
    return out


def autocrop(img: Image) -> Image:
    """裁到非透明像素的 bounding box；若全透明則回傳原圖。"""
    min_x, min_y = img.width, img.height
    max_x, max_y = -1, -1
    for y in range(img.height):
        row = img.pixels[y]
        for x in range(img.width):
            if row[x][3] > 0:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    if max_x < 0:
        return img
    return img.crop(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


def column_has_opaque(img: Image, x: int, alpha_threshold: int = 8) -> bool:
    return any(img.pixels[y][x][3] > alpha_threshold for y in range(img.height))


def segment_row_by_gaps(img: Image, expected_count: int) -> list:
    """依透明間隙把一排（已去背）frame 切開。回傳每個 frame 的 (x, w) 範圍列表。
    若偵測到的段數與 `expected_count` 不符，退回等寬切割（保守 fallback）。
    """
    cols_opaque = [column_has_opaque(img, x) for x in range(img.width)]
    segments = []
    x = 0
    while x < img.width:
        if not cols_opaque[x]:
            x += 1
            continue
        start = x
        while x < img.width and cols_opaque[x]:
            x += 1
        segments.append((start, x - start))

    if len(segments) != expected_count:
        # fallback：等寬切割
        seg_w = img.width // expected_count
        segments = [(i * seg_w, seg_w) for i in range(expected_count)]
    return segments


# ---------------------------------------------------------------------------
# 座標設定表（由 Read asset_sheet.png 目視校準，1536x1024）
# ---------------------------------------------------------------------------

@dataclass
class Region:
    x: int
    y: int
    w: int
    h: int


# 主角（金髮藍衫）「向右」列：目視校準——標籤欄約到 x=95，列高約 92px，
# 4 排（向右/向左/向前/向後）從 y≈40 起、每排約 92px；5 格等寬跨列 x 95..480。
HERO_RIGHT_ROW = Region(x=95, y=42, w=390, h=90)
HERO_RIGHT_FRAME_COUNT = 5

# 旅伴（藍衫紅披風）「向右」列：與主角同一 y 帶（同一排「向右」），x 落在主角區塊之後、
# 道具區塊之前；4 格（旅伴只有 4 走路 frame，主角 5 格）。目視校準見 Phase 4b 校準紀錄。
COMPANION_RIGHT_ROW = Region(x=650, y=42, w=320, h=90)
COMPANION_RIGHT_FRAME_COUNT = 4

# 道具／互動物件（Phase 4b `12_PHASE4_SPEC.md` §1/§6）：素材表右上角三排。
# 每個道具各自獨立裁切區（而非整排切格）——因為道具尺寸/間距不一（不像角色走路 frame 等寬等距），
# 逐一目視校準座標，範圍刻意留一點餘裕，去背 + autocrop 後會收斂到道具本身的精確 bounding box；
# 餘裕只要不切進「相鄰道具」即可，不需要對到道具本身邊緣的像素級精準。
PROP_REGIONS: dict = {
    "crate_large": Region(x=1010, y=60, w=95, h=100),
    "crate_medium": Region(x=1108, y=60, w=58, h=100),
    "crate_small": Region(x=1168, y=60, w=55, h=100),
    "barrel_small": Region(x=1228, y=60, w=52, h=100),
    "signpost": Region(x=1298, y=55, w=60, h=105),
    "lantern": Region(x=1358, y=50, w=80, h=110),
    "barrel_large": Region(x=1012, y=160, w=90, h=105),
    "fence": Region(x=1100, y=165, w=146, h=100),
    "haystack": Region(x=1252, y=150, w=98, h=120),
    "haycart": Region(x=1350, y=150, w=186, h=130),
    "flower": Region(x=995, y=268, w=105, h=120),
    "rock": Region(x=1130, y=275, w=90, h=110),
    "bush": Region(x=1225, y=275, w=100, h=110),
    "grass": Region(x=1330, y=275, w=70, h=110),
    "arrow_sign": Region(x=1400, y=285, w=120, h=105),
}

# 背景 panorama：左側「遠景/中景/近景/地面平台」中文標籤欄，內容區從 x=95 到 x=1525
# （用逐像素亮度掃描找到左右內容邊界，兩側外面是畫布留白/標籤底的近黑色 #1B1B1B）。
# y 範圍同樣以逐像素掃描找到分區間的清楚亮度斷點（見 `--inspect` 校準過程）：
#   遠景（山+城堡天空）：y=472..636（斷點在 636/637，四個取樣 x 一致）
#   中景（村莊天空）：   y=637..773（斷點在 773/774，四個取樣 x 一致，774 起轉近黑）
#   近景+地面平台為同一連續圖塊（近黑底 + 道具剪影 + 底部草地/泥土）；
#   4a 只需要「地面平台」草地+泥土帶，取草線以上一點到內容下緣（987，988 起是外框黑）。
BG_FAR = Region(x=95, y=472, w=1431, h=164)
BG_MID = Region(x=95, y=637, w=1431, h=136)
BG_GROUND = Region(x=95, y=915, w=1431, h=73)

# mid 疊在 far 之前且上緣重疊（`ParallaxBackground.midFarOverlap`）；兩張各自獨立 panorama
# 顏色在重疊區未必連續，硬邊會在 mid 上緣形成接縫。淡出 12px 讓 mid 上緣透出後方的 far。
BG_MID_TOP_FADE_PX = 22


def slice_walk_row(sheet: Image, region: Region, frame_count: int) -> list:
    """依 `region` 裁出一整排走路 frame、去背，再依透明間隙切成 `frame_count` 格並各自 autocrop。
    共用邏輯，供主角/旅伴兩排走路動畫共用（`12` §1）。
    """
    row_img = sheet.crop(region.x, region.y, region.w, region.h)
    keyed = chroma_key_flood(row_img, threshold=28)
    keyed = despeckle_neutral_residue(keyed)
    segments = segment_row_by_gaps(keyed, frame_count)
    frames = []
    for (sx, sw) in segments:
        frame = keyed.crop(sx, 0, sw, keyed.height)
        frame = keep_largest_component(frame)
        frame = autocrop(frame)
        frames.append(frame)
    return frames


def slice_hero_right(sheet: Image) -> list:
    return slice_walk_row(sheet, HERO_RIGHT_ROW, HERO_RIGHT_FRAME_COUNT)


def slice_companion_right(sheet: Image) -> list:
    return slice_walk_row(sheet, COMPANION_RIGHT_ROW, COMPANION_RIGHT_FRAME_COUNT)


def slice_props(sheet: Image) -> dict:
    """逐一裁切 `PROP_REGIONS` 各道具：裁切區域 → 去背 → autocrop。
    每個道具獨立裁切（而非整排切格），因為道具尺寸/間距不一（`12` §1 / Phase 4b 校準）。
    """
    out = {}
    for name, region in PROP_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        keyed = chroma_key_flood(cropped, threshold=28)
        keyed = despeckle_neutral_residue(keyed)
        keyed = remove_small_components(keyed)
        out[name] = autocrop(keyed)
    return out


def fade_top_edge(img: Image, fade_px: int) -> Image:
    """把 `img` 最上緣 `fade_px` 列做垂直 alpha 漸層淡出（頂端 alpha=0，`fade_px` 列處回到原 alpha）。
    用途：`bg/mid.png` 疊在 `bg/far.png` 之前（`ParallaxBackground` mid/far 有重疊區，
    mid zPosition 較高蓋住 far），兩張各自獨立 panorama 在重疊區顏色未必連續，
    硬邊會在 mid 上緣形成明顯接縫。淡出後 mid 上緣透出後方的 far，接縫變成漸層過渡。
    """
    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    fade_px = min(fade_px, img.height)
    for y in range(fade_px):
        factor = y / fade_px  # 0.0 at top row -> ~1.0 just before fade_px
        for x in range(img.width):
            r, g, b, a = out.pixels[y][x]
            out.pixels[y][x] = (r, g, b, int(a * factor))
    return out


def pad_to_common_size(frames: list) -> list:
    """把一組 frame pad 成相同尺寸（以最大寬高為準、水平置中、底部對齊）避免走路動畫抖動。"""
    if not frames:
        return frames
    max_w = max(f.width for f in frames)
    max_h = max(f.height for f in frames)
    out = []
    for f in frames:
        canvas = Image.new(max_w, max_h)
        off_x = (max_w - f.width) // 2
        off_y = max_h - f.height  # 底部對齊（腳站在同一條線上）
        for y in range(f.height):
            for x in range(f.width):
                canvas.set(off_x + x, off_y + y, f.get(x, y))
        out.append(canvas)
    return out


def main() -> None:
    sheet = decode_png(ASSET_SHEET)
    print(f"asset_sheet: {sheet.width}x{sheet.height}")

    if "--inspect" in sys.argv:
        inspect(sheet)
        return

    os.makedirs(OUT_ROOT, exist_ok=True)

    # --- 背景三條 panorama（不透明，crop 即可） ---
    bg_dir = os.path.join(OUT_ROOT, "bg")
    for name, region in (("far", BG_FAR), ("mid", BG_MID), ("ground", BG_GROUND)):
        img = sheet.crop(region.x, region.y, region.w, region.h)
        if name == "mid":
            # mid 疊在 far 之前、上緣與 far 重疊，淡出上緣讓接縫變成漸層（見 `fade_top_edge`）。
            img = fade_top_edge(img, fade_px=BG_MID_TOP_FADE_PX)
        out_path = os.path.join(bg_dir, f"{name}.png")
        encode_png(img, out_path)
        print(f"wrote {out_path} ({img.width}x{img.height})")

    # --- 主角向右走路 frame ---
    frames = slice_hero_right(sheet)
    frames = pad_to_common_size(frames)
    char_dir = os.path.join(OUT_ROOT, "char_hero")
    for i, frame in enumerate(frames):
        out_path = os.path.join(char_dir, f"right_{i}.png")
        encode_png(frame, out_path)
        print(f"wrote {out_path} ({frame.width}x{frame.height})")

    # --- 旅伴向右走路 frame（Phase 4b）---
    companion_frames = slice_companion_right(sheet)
    companion_frames = pad_to_common_size(companion_frames)
    companion_dir = os.path.join(OUT_ROOT, "char_companion")
    for i, frame in enumerate(companion_frames):
        out_path = os.path.join(companion_dir, f"right_{i}.png")
        encode_png(frame, out_path)
        print(f"wrote {out_path} ({frame.width}x{frame.height})")

    # --- 道具／互動物件（Phase 4b）---
    props = slice_props(sheet)
    props_dir = os.path.join(OUT_ROOT, "props")
    for name, img in props.items():
        out_path = os.path.join(props_dir, f"{name}.png")
        encode_png(img, out_path)
        print(f"wrote {out_path} ({img.width}x{img.height})")


def inspect(sheet: Image) -> None:
    """輔助校準：印出整體垂直亮度剖面（每 8px 一行的平均亮度），協助抓分區 y 邊界。"""
    step = 8
    for y in range(0, sheet.height, step):
        row = sheet.pixels[y]
        avg = sum(_brightness(p) for p in row) // len(row)
        bar = "#" * (avg // 4)
        print(f"y={y:4d} avg={avg:3d} {bar}")


if __name__ == "__main__":
    main()
