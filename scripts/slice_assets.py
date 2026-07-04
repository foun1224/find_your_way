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
KINGDOM_SHEET = os.path.join(REPO_ROOT, "design", "kingdom.png")
KINGDOM_CHARACTERS_SHEET = os.path.join(REPO_ROOT, "design", "kingdom_characters.png")
SEA_CITY_SHEET = os.path.join(REPO_ROOT, "design", "sea_city.png")
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


def chroma_key_flood_color(img: Image, bg_color, threshold: int = 30) -> Image:
    """近黑底去背（顏色距離版）：`chroma_key_flood` 用「亮度 < threshold」判斷背景，適合背景
    接近純黑（`#1B1B1B` 系）的舊素材表；Stage C 新版 kingdom.png / sea_city.png 底部道具列畫布
    背景其實是偏藍的深灰（約 RGB(30,41,55)，亮度已到 ~40），跟不少道具本體的暗部（黑色鐵件、
    深色木頭陰影）亮度區間重疊（12～50 都有），純亮度门檻分不開兩者——亮度門檻調高到蓋住
    背景，會連道具暗部一起流失；調低則背景本身流不掉。
    改用「與已知背景色的歐氏距離」分背景/本體：背景是同一張畫布，顏色一致（只有些微漸層/雜訊），
    跟背景『同色系』的像素距離很小；道具的黑色鐵件、深色木頭雖然亮度相近，色相不同
    （更中性灰或偏棕，不是背景那種偏藍深灰），距離明顯較大，因此能在亮度重疊的情況下正確分離。
    只把「從畫布四邊 flood-fill 連通、且與 bg_color 距離 < threshold」的像素轉透明，
    手法（flood-fill 而非全圖门檻）與 `chroma_key_flood` 相同，本體暗部不連到邊界不會被誤挖空。
    """
    w, h = img.width, img.height
    bg_r, bg_g, bg_b = bg_color[:3]

    def close_to_bg(rgba) -> bool:
        r, g, b, _ = rgba
        dist_sq = (r - bg_r) ** 2 + (g - bg_g) ** 2 + (b - bg_b) ** 2
        return dist_sq < threshold * threshold

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
        if not close_to_bg(img.get(x, y)):
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


def keep_largest_component_dilated(img: Image, dilate_px: int = 2) -> Image:
    """`keep_largest_component` 的強化版：先把 alpha 遮罩做 Chebyshev 距離 `dilate_px` 的
    形態學膨脹，再用膨脹後的遮罩做 4-連通元件分析選出「最大連通塊」，最後只保留落在該
    最大連通塊範圍內的『原始』不透明像素（膨脹只用來決定連通性/誰是最大塊，不會真的
    新增任何不透明像素——輸出的 alpha 值完全等於輸入）。
    動機（Stage C QA 發現的燈柱斷桿問題）：`chroma_key_flood_color` 逐像素判斷背景色距離，
    細長桿狀部件（燈柱柱身、旗桿等）只有 ~3-4px 寬，若某幾列桿身像素顏色恰好非常接近
    背景色（例如陰影處），會被單獨誤判成背景挖空，把桿子從中間切成兩段互不相連的
    alpha 色塊；`keep_largest_component` 只看嚴格 4-連通，就會把面積較小的那段（通常是
    桿身+底座）整段當雜訊丟棄，只留下面積較大的那段（通常是燈頭），造成道具殘缺。
    用膨脹後的遮罩判斷連通性，能讓中間 1-2px 的斷點在「是否算同一塊」的判斷上被跨過，
    避免整段被誤刪，同時因為最終只保留原始不透明像素、不新增任何像素，不會讓道具邊緣
    變粗糊或引入額外雜訊。
    """
    w, h = img.width, img.height
    opaque = [[img.pixels[y][x][3] > 0 for x in range(w)] for y in range(h)]

    dilated = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if opaque[y][x]:
                dilated[y][x] = True
                continue
            found = False
            for dy in range(-dilate_px, dilate_px + 1):
                ny = y + dy
                if ny < 0 or ny >= h:
                    continue
                for dx in range(-dilate_px, dilate_px + 1):
                    nx = x + dx
                    if nx < 0 or nx >= w:
                        continue
                    if opaque[ny][nx]:
                        found = True
                        break
                if found:
                    break
            dilated[y][x] = found

    visited = [[False] * w for _ in range(h)]
    best_component: list = []
    best_original_count = -1

    for sy in range(h):
        for sx in range(w):
            if visited[sy][sx] or not dilated[sy][sx]:
                continue
            stack = [(sx, sy)]
            visited[sy][sx] = True
            comp = []
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and dilated[ny][nx]:
                        visited[ny][nx] = True
                        stack.append((nx, ny))
            original_count = sum(1 for (x, y) in comp if opaque[y][x])
            if original_count > best_original_count:
                best_original_count = original_count
                best_component = comp

    keep = set(best_component)
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

# 主角「向前」列（第 3 排，面向觀看者）：與「向右」同一 x 範圍、同寬 5 格，
# 列距目視校準約 92px/排（向右 y=42 → 向左 y≈134 → 向前 y≈226 → 向後 y≈318）；
# 已用 `--inspect` 之外的獨立裁切校驗（見 scratchpad 交叉檢查），y=226,h=90 完整框住
# 頭頂到鞋底、左右不切邊。此列供「偶爾看向使用者」微行為使用（`13_PSYCH_AUDIT.md` P1/P2）。
HERO_FRONT_ROW = Region(x=95, y=226, w=390, h=90)
HERO_FRONT_FRAME_COUNT = 5

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


# ---------------------------------------------------------------------------
# 王國首都座標設定表（Stage C `19_STAGE_C_SPEC.md` §1，由 Read design/kingdom.png 目視 +
# 逐像素亮度/連通元件掃描校準，1774x887，Fable 提供的更精緻重繪版，取代舊 1536x1024 版本，
# 座標與舊版完全無法沿用——版面比例不同，重新校準。）
# ---------------------------------------------------------------------------

# 內容左右邊界：新版與舊版不同——整張圖沒有「留白邊界欄」，遠/中/前景場景內容本身
# 直接畫到左右兩側畫布邊緣（x=0 起到 x=1774 止，逐欄亮度掃描確認左右兩側都是滿版場景色，
# 不是近黑留白）。但每層左上角疊了一塊「遠景/中景/前景/地面平台」中文標籤黑底方框
# （蓋在場景內容上，不是獨立留白欄——與舊版留白版式不同），裁完後用 `patch_label_box` 蓋掉
# （見下方 `KINGDOM_LABEL_BOX_RECTS`），否則水平無縫平鋪時方框會每個 tile 週期性重複出現。
#
# 背景四層 y 範圍：以逐像素亮度掃描 + 標籤方框位置交叉校準（方框永遠貼齊自己所屬圖層的
# 左上角，方框出現的 y 位置＝該圖層的起點附近，比場景內容本身的漸層亮度斷點更可靠）：
#   遠景（城堡群+河+橋+雲）：      y=0..236（237/238 起亮度陡升，轉中景自己的天空）
#   中景（藍頂塔樓城牆密城）：    y=237..462（前景標籤方框貼齊 463 起點）
#   前景（旗幟石牆+燈柱+桶箱車花）：y=463..584（往下漸暗轉地面平台石板的陰影帶）
#   地面平台（灰石板走道）：      y=585..634（635/636 起陡降轉近黑，是底部道具列畫布）
KINGDOM_BG_FAR = Region(x=0, y=0, w=1774, h=237)
KINGDOM_BG_MID = Region(x=0, y=237, w=1774, h=226)
KINGDOM_BG_FORE = Region(x=0, y=463, w=1774, h=122)
KINGDOM_BG_GROUND = Region(x=0, y=585, w=1774, h=50)

# 各層左上角標籤方框（相對於該層裁切後的區域座標，供 `patch_label_box` 蓋掉）：
# 方框大小/位置在遠景/中景/前景三層一致（同一套 UI 素材），逐層獨立校準。
# 地面平台層沒有方框——「地面平台」文字方框實際疊在更下面的道具列畫布上（見
# `KINGDOM_PROP_REGIONS` 校準時的觀察），地面平台裁切範圍本身乾淨、不需要 patch。
KINGDOM_LABEL_BOX_RECTS: dict = {
    "far": Region(x=5, y=14, w=145, h=60),
    "mid": Region(x=5, y=6, w=145, h=56),
    "fore": Region(x=5, y=3, w=145, h=50),
}

# mid 疊在 far 之前、fore 疊在 mid 之前，皆有小段上緣重疊（`ParallaxBackground` 對應 overlap 常數），
# 各自獨立 panorama，淡出上緣讓接縫變成漸層過渡（同 `BG_MID_TOP_FADE_PX` 手法）。
KINGDOM_BG_MID_TOP_FADE_PX = 18
KINGDOM_BG_FORE_TOP_FADE_PX = 14

# 道具／互動物件：新版 kingdom.png 底部道具列（y=636..887，近黑色畫布），逐一目視校準座標
# （先用「欄有無亮於背景像素」做連通分段掃描抓出候選範圍，再逐一裁切 Read 目視確認身份、
# 命名依實際外觀）。素材表最左側 3 格是牆面/短柱材質色板（非獨立道具，供環境圖層本身使用，
# 不適合當散落道具——花箱/欄杆之類「有機」道具才需要細部去背，牆材質色板本身就是矩形色塊，
# 沒有散落擺放的意義），故本表不收錄。範圍刻意留餘裕，去背 + autocrop 後收斂到精確 bounding box。
KINGDOM_PROP_REGIONS: dict = {
    "lamppost": Region(x=510, y=636, w=90, h=251),
    "banner": Region(x=574, y=636, w=132, h=251),
    "crate": Region(x=696, y=636, w=100, h=251),
    "barrel": Region(x=785, y=636, w=107, h=251),
    "cart": Region(x=885, y=636, w=136, h=251),
    "crate_reinforced": Region(x=1010, y=636, w=140, h=251),
    "planter": Region(x=1160, y=636, w=110, h=251),
    "fence": Region(x=1300, y=636, w=172, h=251),
    "fence_low": Region(x=1461, y=636, w=182, h=251),
    "pillar": Region(x=1638, y=636, w=106, h=251),
}


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


def slice_hero_front(sheet: Image) -> list:
    return slice_walk_row(sheet, HERO_FRONT_ROW, HERO_FRONT_FRAME_COUNT)


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


def patch_label_box(img: Image, rect: "Region") -> Image:
    """蓋掉素材表上疊在場景內容之上的「遠景/中景/前景/地面平台」中文標籤黑底方框
    （Stage C 新版 kingdom.png / sea_city.png 的方框是直接疊在畫面左上角內容上，不是像舊版
    asset_sheet.png / 舊 kingdom.png 那樣留一條獨立的留白邊界——若照舊只裁 x 起點跳過方框，
    這裡因為方框只佔內容角落一小塊，硬跳過整欄會裁掉方框右側的合法內容）。
    做法：把 `rect` 這塊區域整個用「`rect` 正上方那一列像素」往下重複貼滿，蓋掉黑底文字方框。
    背景在方框所在位置多半是天空/牆面等變化平緩的漸層，用上緣那一列重複填滿，
    視覺上會是一小段平頂色塊，遠比保留黑底方框自然；且此圖層會做水平無縫平鋪，
    方框不處理掉的話會在畫面上週期性重複出現，比單次的色塊瑕疵更顯眼。
    若 `rect.y == 0`（方框緊貼裁切區頂緣，例如 sea_city.png 前景層方框），正上方已經沒有
    合法背景可取（那一列還是方框本身），改用「正下方那一列」（方框底下已經是真正的場景內容）
    往上重複貼滿，效果相同、方向相反。
    """
    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    if rect.y <= 0:
        src_y = min(img.height - 1, rect.y + rect.h)
    else:
        src_y = rect.y - 1
    for y in range(max(0, rect.y), min(img.height, rect.y + rect.h)):
        for x in range(max(0, rect.x), min(img.width, rect.x + rect.w)):
            out.pixels[y][x] = out.pixels[src_y][x]
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


# Stage C 新版 kingdom.png 道具（`KINGDOM_PROP_REGIONS`）去雜點策略：
# - `keep_largest_component`：本體是「單一連通塊」、沒有細長分離部件的道具——燈柱/旗幟/木箱/
#   木桶/貨車/石柱本體造型雖然有細桿（燈柱柱身、旗幟旗桿、石柱本身），但桿身跟底座/主體像素
#   相連成一塊，不會被誤判成小雜點清掉，用「只留最大連通塊」最乾淨、順便清掉鄰居道具碎片。
# - `remove_small_components`（面積門檻，同既有 `slice_props` 手法）：本體「本來就有分離部件」
#   的道具——花箱（箱體+花叢，花瓣末梢常因去背斷開變小碎塊）、欄杆（扶手柱之間本來就有透空
#   間隙，是好幾根柱子的集合，不是單一連通塊）——用最大連通塊會誤刪成只剩一根柱子。
_KINGDOM_LARGEST_COMPONENT_PROPS = {"lamppost", "banner", "crate", "crate_reinforced", "barrel", "cart", "pillar"}
_KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA = 80
_KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA_OVERRIDES: dict = {}

# 道具列畫布上緣（裁切框相對 y=0..~68）其實是一整條青苔石牆「背板」紋理，橫跨整張素材表
# 寬度、跟旁邊道具的背板紋理連成同一塊（不是雜點，是刻意畫的展示背板），色彩/亮度都跟真正
# 道具本體重疊，`chroma_key_flood_color`／`remove_small_components`／`keep_largest_component`
# 都無法單純用顏色或面積分開它——校準時發現它會被誤判成「最大連通塊」（贏過矮小道具本體）
# 或以「大於門檻的鄰居碎片」身分留下來。這裡改用最直接的作法：裁切後（去背前）直接把背板所在的
# 矩形區域填成透明，跟舊版 kingdom.png `signpost`/`tree` 用的 `_apply_exclude_rects` 手法一致。
# 大多數道具本體全部落在背板下方（不需要背板那段），可以整條清空；只有燈柱的燈頭會伸進背板
# 高度——燈柱用「左右兩側」exclude rect（保留中間燈頭/燈柱那條窄窗），其餘道具直接整條清空。
_KINGDOM_PROP_EXCLUDE_RECTS: dict = {
    "lamppost": [
        Region(x=0, y=0, w=25, h=70),   # 背板左側
        Region(x=65, y=0, w=25, h=70),  # 背板右側（中間 x=25..65 留給燈頭/燈柱）
    ],
    "banner": [
        Region(x=0, y=0, w=45, h=45),    # 背板左上角
        Region(x=90, y=0, w=42, h=45),   # 背板右上角（中間 x=45..90 留給旗桿橫臂/尖頂裝飾）
    ],
    "crate": [Region(x=0, y=0, w=100, h=68)],
    "barrel": [Region(x=0, y=0, w=107, h=68)],
    "cart": [Region(x=0, y=0, w=136, h=100)],
    "crate_reinforced": [Region(x=0, y=0, w=140, h=68)],
    "planter": [Region(x=0, y=0, w=148, h=68)],
    "fence": [Region(x=0, y=0, w=172, h=68)],
    "fence_low": [Region(x=0, y=0, w=182, h=68)],
    "pillar": [Region(x=0, y=0, w=106, h=68)],
}


def _apply_exclude_rects(img: Image, rects: list) -> Image:
    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    for rect in rects:
        for y in range(max(0, rect.y), min(img.height, rect.y + rect.h)):
            for x in range(max(0, rect.x), min(img.width, rect.x + rect.w)):
                out.pixels[y][x] = (0, 0, 0, 0)
    return out


# 王國市民 NPC（Stage B+ 社會臨場感）：素材表左下角「角色（像素風）」區塊三種角色
# （王國士兵/王國衛兵隊長/王國貴族·公主）各只取「向前」列第 1 格當代表幀（純裝飾站立姿，
# 不需要整組走路循環）。座標為逐像素校準：先框住整排「向前」四向列（y=815..935），
# 再在該列裡框住每種角色最左邊一格，刻意避開左側列標籤文字（"向前" 中文字樣）與右側鄰居角色。
KINGDOM_NPC_REGIONS: dict = {
    "soldier": Region(x=85, y=815, w=95, h=120),
    "guard": Region(x=430, y=815, w=100, h=120),
    "noble": Region(x=735, y=815, w=85, h=120),
}


def slice_kingdom_npcs(sheet: Image) -> dict:
    """王國市民 NPC 代表幀切圖：與 `slice_kingdom_props` 同一套去背流程，只是本體是單一
    連通角色（無細長分離部件），套用 `keep_largest_component` 去掉框到的鄰居殘影/標籤文字碎片。
    """
    out = {}
    for name, region in KINGDOM_NPC_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        keyed = chroma_key_flood(cropped, threshold=28)
        keyed = despeckle_neutral_residue(keyed)
        keyed = keep_largest_component(keyed)
        out[name] = autocrop(keyed)
    return out


# 王國道具列畫布背景色（Stage C 新版 kingdom.png，逐像素取樣畫布邊角確認，見 `chroma_key_flood_color`
# 說明——這張畫布背景是偏藍深灰，亮度已到 ~40，跟不少道具暗部亮度重疊，改用顏色距離去背）。
_KINGDOM_PROP_BG_COLOR = (31, 42, 54)


def slice_kingdom_props(sheet: Image) -> dict:
    """王國道具切圖：座標表 `KINGDOM_PROP_REGIONS`（`19_STAGE_C_SPEC.md` §1）；
    去背用 `chroma_key_flood_color`（畫布背景亮度跟部分道具暗部重疊，見其說明）；
    去雜點/去鄰居碎片策略見 `_KINGDOM_LARGEST_COMPONENT_PROPS` 說明。"""
    out = {}
    for name, region in KINGDOM_PROP_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        if name in _KINGDOM_PROP_EXCLUDE_RECTS:
            cropped = _apply_exclude_rects(cropped, _KINGDOM_PROP_EXCLUDE_RECTS[name])
        keyed = chroma_key_flood_color(cropped, _KINGDOM_PROP_BG_COLOR, threshold=16)
        if name in _KINGDOM_LARGEST_COMPONENT_PROPS:
            # 用膨脹連通版而非原始 `keep_largest_component`：細長桿狀部件（燈柱柱身、
            # 旗桿）在色距去背下可能因陰影處顏色貼近背景而被攔腰挖空，見
            # `keep_largest_component_dilated` docstring（Stage C QA 發現的燈柱斷桿問題）。
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            min_area = _KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA_OVERRIDES.get(name, _KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA)
            keyed = remove_small_components(keyed, min_area=min_area)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 港口海城座標設定表（Stage C `19_STAGE_C_SPEC.md` §1，第三地域，由 Read design/sea_city.png
# 目視 + 逐像素亮度/連通元件掃描校準，1536x1024）。
# ---------------------------------------------------------------------------

# 與 kingdom.png 同款版式（無留白邊界欄，內容滿版到左右畫布邊緣；每層左上角疊標籤黑底方框）。
# 背景四層 y 範圍（方框位置 + 內容亮度斷點交叉校準，同 kingdom.png 手法）：
#   遠景（海岸城+燈塔+帆船+雲）：  y=0..243
#   中景（港埠城鎮+大帆船）：      y=244..484
#   前景（碼頭+大帆船+海港建築+旗幟）：y=485..708
#   地面平台（碼頭石板）：         y=709..762（763 起「地面平台」標籤方框開始疊在道具列畫布上，
#                                   裁到 762 為止可以完全避開方框，不需要 `patch_label_box`）
SEA_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=244)
SEA_CITY_BG_MID = Region(x=0, y=244, w=1536, h=241)
SEA_CITY_BG_FORE = Region(x=0, y=485, w=1536, h=224)
SEA_CITY_BG_GROUND = Region(x=0, y=709, w=1536, h=54)

# 各層左上角標籤方框（同 `KINGDOM_LABEL_BOX_RECTS` 手法，相對於該層裁切後的區域座標）。
SEA_CITY_LABEL_BOX_RECTS: dict = {
    "far": Region(x=5, y=8, w=150, h=72),
    "mid": Region(x=0, y=10, w=155, h=85),
    "fore": Region(x=5, y=0, w=115, h=58),
}

SEA_CITY_BG_MID_TOP_FADE_PX = 18
SEA_CITY_BG_FORE_TOP_FADE_PX = 14

# 道具／互動物件：底部道具列（y=800..1024，近黑色畫布），逐一目視校準座標，命名依實際外觀。
# 同 kingdom.png，最左側 3 格是牆面/短柱材質色板，非散落道具，不收錄。
# 「繫纜柱」「吊車」是海城特有（碼頭意象），其餘與王國同款道具（燈柱/旗幟/木箱/木桶/花箱/欄杆/石柱）
# 重新繪製過、素材不共用，需各自獨立切一份。
SEA_CITY_PROP_REGIONS: dict = {
    "lamppost": Region(x=436, y=800, w=46, h=224),
    "banner": Region(x=497, y=800, w=68, h=224),
    "crate": Region(x=590, y=800, w=90, h=224),
    "barrel": Region(x=692, y=800, w=68, h=224),
    "bollard": Region(x=751, y=800, w=112, h=224),
    "crane": Region(x=871, y=800, w=172, h=224),
    "crate_sack": Region(x=1047, y=800, w=152, h=224),
    "planter": Region(x=1195, y=800, w=106, h=224),
    "fence": Region(x=1312, y=800, w=136, h=224),
    "pillar": Region(x=1459, y=800, w=53, h=224),
}

# 去雜點策略（同 `_KINGDOM_LARGEST_COMPONENT_PROPS` 說明）：本體單一連通塊的道具用
# `keep_largest_component`；有分離部件的道具（吊車的吊鉤鏈條、木箱+麻袋組合、花箱花叢、
# 欄杆扶手柱間隙）用 `remove_small_components` 保留分離部件。
_SEA_CITY_LARGEST_COMPONENT_PROPS = {"lamppost", "banner", "crate", "barrel", "bollard", "pillar"}
_SEA_CITY_NEIGHBOR_DEBRIS_MIN_AREA = 80

# 海城道具列畫布背景色（同 `_KINGDOM_PROP_BG_COLOR` 說明，海城畫布顏色略深/略藍，各自取樣）。
_SEA_CITY_PROP_BG_COLOR = (27, 41, 58)


def slice_sea_city_props(sheet: Image) -> dict:
    """海城道具切圖：與 `slice_kingdom_props` 同一套去背流程（`chroma_key_flood_color`，
    理由同 `_KINGDOM_PROP_BG_COLOR`），座標表換成 `SEA_CITY_PROP_REGIONS`（`19` §1）。"""
    out = {}
    for name, region in SEA_CITY_PROP_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        keyed = chroma_key_flood_color(cropped, _SEA_CITY_PROP_BG_COLOR, threshold=16)
        if name in _SEA_CITY_LARGEST_COMPONENT_PROPS:
            # 同 `slice_kingdom_props`：用膨脹連通版避免細長桿狀部件被色距去背攔腰挖空。
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=_SEA_CITY_NEIGHBOR_DEBRIS_MIN_AREA)
        out[name] = autocrop(keyed)
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
    # 同步寫兩份：`bg/`（既有路徑，向後相容——地標 signpost 等非地域限定資源仍讀這裡）
    # + `regions/meadow/bg/`（`18_STAGE_B_SPEC.md` §1「既有草原素材同步地域化」，供 Region
    # 系統依地域挑背景）。草原沒有前景層（`fore`），地域切換時該地域直接略過 fore。
    bg_dir = os.path.join(OUT_ROOT, "bg")
    meadow_bg_dir = os.path.join(OUT_ROOT, "regions", "meadow", "bg")
    for name, region in (("far", BG_FAR), ("mid", BG_MID), ("ground", BG_GROUND)):
        img = sheet.crop(region.x, region.y, region.w, region.h)
        if name == "mid":
            # mid 疊在 far 之前、上緣與 far 重疊，淡出上緣讓接縫變成漸層（見 `fade_top_edge`）。
            img = fade_top_edge(img, fade_px=BG_MID_TOP_FADE_PX)
        for out_dir in (bg_dir, meadow_bg_dir):
            out_path = os.path.join(out_dir, f"{name}.png")
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

    # --- 主角向前（面向觀看者）frame：供「偶爾看向使用者」微行為使用 ---
    front_frames = slice_hero_front(sheet)
    front_frames = pad_to_common_size(front_frames)
    for i, frame in enumerate(front_frames):
        out_path = os.path.join(char_dir, f"front_{i}.png")
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
    # 同步寫 `props/`（既有路徑，地標 signpost 等非地域限定用途）+ `regions/meadow/props/`
    # （地域化，`18` §1，供 `PropScatter` 依地域挑草原道具池）。
    props = slice_props(sheet)
    props_dir = os.path.join(OUT_ROOT, "props")
    meadow_props_dir = os.path.join(OUT_ROOT, "regions", "meadow", "props")
    for name, img in props.items():
        for out_dir in (props_dir, meadow_props_dir):
            out_path = os.path.join(out_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

    # --- 王國首都地域（Stage B `18_STAGE_B_SPEC.md` §1 → Stage C `19_STAGE_C_SPEC.md` §1
    # 重切）：環境（背景+道具）讀新版 design/kingdom.png（更精緻、無角色列）；
    # NPC 讀救回的舊版 design/kingdom_characters.png（唯一還保留角色列的素材表）。---
    if os.path.exists(KINGDOM_SHEET):
        kingdom_sheet = decode_png(KINGDOM_SHEET)
        print(f"kingdom_sheet: {kingdom_sheet.width}x{kingdom_sheet.height}")

        kingdom_bg_dir = os.path.join(OUT_ROOT, "regions", "kingdom", "bg")
        kingdom_layers = (
            ("far", KINGDOM_BG_FAR, None, "far"),
            ("mid", KINGDOM_BG_MID, KINGDOM_BG_MID_TOP_FADE_PX, "mid"),
            ("fore", KINGDOM_BG_FORE, KINGDOM_BG_FORE_TOP_FADE_PX, "fore"),
            ("ground", KINGDOM_BG_GROUND, None, None),
        )
        for name, region, fade_px, label_key in kingdom_layers:
            img = kingdom_sheet.crop(region.x, region.y, region.w, region.h)
            if label_key is not None and label_key in KINGDOM_LABEL_BOX_RECTS:
                # 蓋掉疊在內容左上角的「遠景/中景/前景」標籤黑底方框（見 `patch_label_box` 說明）。
                img = patch_label_box(img, KINGDOM_LABEL_BOX_RECTS[label_key])
            if fade_px:
                # mid/fore 疊在後方層之前、上緣重疊，淡出讓接縫變漸層（同 `BG_MID_TOP_FADE_PX` 手法）。
                img = fade_top_edge(img, fade_px=fade_px)
            out_path = os.path.join(kingdom_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        kingdom_props = slice_kingdom_props(kingdom_sheet)
        kingdom_props_dir = os.path.join(OUT_ROOT, "regions", "kingdom", "props")
        for name, img in kingdom_props.items():
            out_path = os.path.join(kingdom_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {KINGDOM_SHEET} not found, skipping kingdom region bg/props slicing")

    # 王國 NPC 改讀救回的舊版素材表（`19` §1「王國市民 NPC 保留」）：舊版座標可續用
    # （`KINGDOM_NPC_REGIONS` 未變），只換來源圖檔。
    if os.path.exists(KINGDOM_CHARACTERS_SHEET):
        kingdom_characters_sheet = decode_png(KINGDOM_CHARACTERS_SHEET)
        print(f"kingdom_characters_sheet: {kingdom_characters_sheet.width}x{kingdom_characters_sheet.height}")

        kingdom_npcs = slice_kingdom_npcs(kingdom_characters_sheet)
        kingdom_npc_dir = os.path.join(OUT_ROOT, "regions", "kingdom", "npc")
        for name, img in kingdom_npcs.items():
            out_path = os.path.join(kingdom_npc_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {KINGDOM_CHARACTERS_SHEET} not found, skipping kingdom NPC slicing")

    # --- 港口海城地域（Stage C `19_STAGE_C_SPEC.md` §1，第三地域）：獨立素材表
    # design/sea_city.png，無角色列 → 無海城 NPC（本階段）。---
    if os.path.exists(SEA_CITY_SHEET):
        sea_city_sheet = decode_png(SEA_CITY_SHEET)
        print(f"sea_city_sheet: {sea_city_sheet.width}x{sea_city_sheet.height}")

        sea_city_bg_dir = os.path.join(OUT_ROOT, "regions", "sea_city", "bg")
        sea_city_layers = (
            ("far", SEA_CITY_BG_FAR, None, "far"),
            ("mid", SEA_CITY_BG_MID, SEA_CITY_BG_MID_TOP_FADE_PX, "mid"),
            ("fore", SEA_CITY_BG_FORE, SEA_CITY_BG_FORE_TOP_FADE_PX, "fore"),
            ("ground", SEA_CITY_BG_GROUND, None, None),
        )
        for name, region, fade_px, label_key in sea_city_layers:
            img = sea_city_sheet.crop(region.x, region.y, region.w, region.h)
            if label_key is not None and label_key in SEA_CITY_LABEL_BOX_RECTS:
                img = patch_label_box(img, SEA_CITY_LABEL_BOX_RECTS[label_key])
            if fade_px:
                img = fade_top_edge(img, fade_px=fade_px)
            out_path = os.path.join(sea_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        sea_city_props = slice_sea_city_props(sea_city_sheet)
        sea_city_props_dir = os.path.join(OUT_ROOT, "regions", "sea_city", "props")
        for name, img in sea_city_props.items():
            out_path = os.path.join(sea_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {SEA_CITY_SHEET} not found, skipping sea_city region slicing")


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
