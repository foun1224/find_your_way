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
# 美術大改版第 1 波（`21_ASSET_OVERHAUL_PLAN.md` §4）：主角/旅伴/草原三份新素材表。
MAIN_ROLE_SHEET = os.path.join(REPO_ROOT, "design", "main_role.png")
# 主角走路循環圖（Fable 產出，取代 main_role.png 向右列的舊 3 姿勢）：上排「走路(Walk)」
# 8 幀，側視朝右、左右腳明確交替的完整循環；下排「待機(Idle)」本波不用（待機仍讀
# main_role.png 的「向前」欄，見 `MAIN_ROLE_FRONT_ROWS`）。
MAIN_ROLE_WALK_SHEET = os.path.join(REPO_ROOT, "design", "main_role_walk.png")
# v2 走路/待機循環圖（接手任務：更高品質的主角素材表，取代 `main_role_walk.png`）：
# `design/main_role_walk_v2.png` supersedes `main_role_walk.png` — 上排「走路(Walk)」8 幀
# （側視朝右，完整左右腳交替循環）、下排「待機(Idle)」4 幀（frame 2 帶呼吸白霧、
# frame 3 帶飄落樹葉+閃光，皆為細膩待機微互動，`21`/`12_PHASE4_SPEC.md` 4d 範疇）。
# 背景改為深藏青 `RGB(15,15,20)`（非 `main_role_walk.png` 的深紫），去背需用
# `chroma_key_flood_color` 指定新背景色。座標由 `--inspect`-style 逐像素亮度掃描校準
# （見 scratchpad 校準紀錄）；v2 完全取代 v1 走路 8 幀（`right_0..7.png`），並新增
# 待機 4 幀（`idle_0..3.png`，本波只切圖，動畫接線由後續 session 處理）。
MAIN_ROLE_WALK_V2_SHEET = os.path.join(REPO_ROOT, "design", "main_role_walk_v2.png")
RESOURCE_V2_SHEET = os.path.join(REPO_ROOT, "design", "resource_v2.png")
GRASSLAND_SHEET = os.path.join(REPO_ROOT, "design", "grassland.png")
# 美術大改版第 2 波（`21_ASSET_OVERHAUL_PLAN.md` §4「其餘地域切圖」）：5 個新地域素材表，
# 皆 1536x1024、與 grassland.png 同款版式（`20_ASSET_SHEET_SPEC.md` 規格：4 層 + 道具列，
# 每層/道具列左上角疊「遠景/中景/前景/地面平台/道具素材」標籤黑底方框）。
VALLEY_SHEET = os.path.join(REPO_ROOT, "design", "valley.png")
VILLAGE_2_SHEET = os.path.join(REPO_ROOT, "design", "village_2.png")
VILLAGE_3_SHEET = os.path.join(REPO_ROOT, "design", "village_3.png")
SKY_VILLAGE_SHEET = os.path.join(REPO_ROOT, "design", "sky_village.png")
SKY_CITY_SHEET = os.path.join(REPO_ROOT, "design", "sky_city_magic.png")
# 美術大改版第 3 波（`21_ASSET_OVERHAUL_PLAN.md` §3「NPC→地域分配」）：兩份共用居民 NPC 素材表。
NPC_1_SHEET = os.path.join(REPO_ROOT, "design", "npc_1.png")
NPC_2_SHEET = os.path.join(REPO_ROOT, "design", "npc_2.png")
# 美術流程驗證（`20_ASSET_SHEET_SPEC.md` §8A「洋紅去背 + 真多層視差」試驗）：
# `design/harbor_test.png`（1086x1448 直式，5 帶）——只有 far 帶含天空（當完整 backdrop），
# mid/fore/道具都畫在洋紅 `#FF00FF` 底上，可去背後疊出真正的多層視差（取代先前「只渲染
# far」的過渡 workaround）。harbor 目前只是驗證用地域，不排進 8 地域循環（見 `RegionType`）。
HARBOR_SHEET = os.path.join(REPO_ROOT, "design", "harbor_test.png")
# 第 4 波（接手任務：把 harbor 驗證過的「洋紅去背 + 真多層視差」管線推廣到第二個 layered
# 地域）：`design/hotspring_village.png`（1536x1024，日式溫泉山村，遠景含天空不去背、
# 中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。座標表/去背
# 流程與 harbor 完全同款手法，只是版式改回跟其餘 8 地域素材表一樣的「橫式 1536x1024、
# 4 層背景 + 底部道具列」佈局（而非 harbor 那張特例的 1086x1448 直式 5 帶），
# 五個分區座標由 Read + 逐像素洋紅比例掃描校準（見 scratchpad 校準紀錄）。
HOTSPRING_VILLAGE_SHEET = os.path.join(REPO_ROOT, "design", "hotspring_village.png")
# 第 5 波（接手任務：hotspring 管線推廣到第三個 layered 地域）：`design/mountain_palace.png`
# （1536x1024，仙俠山宮/天界宮闕，版式與 hotspring_village 完全相同——遠景含天空不去背、
# 中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。座標由 Read +
# 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。
MOUNTAIN_PALACE_SHEET = os.path.join(REPO_ROOT, "design", "mountain_palace.png")
# 第 6 波（接手任務：hotspring/mountain_palace 管線推廣到第四、第五個 layered 地域）：
# `design/snow_mountain.png`（歐式中世紀奇幻雪山王國，石造拱門城牆/藍色紋章旗/雪中廢墟塔樓/
# 吊橋/火把）與 `design/magic_city.png`（漂浮魔法之城，穹頂尖塔/水晶噴泉/符文法陣/藍金紋章），
# 皆 1536x1024，版式與 hotspring_village/mountain_palace 完全相同——遠景含天空不去背、
# 中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口。座標由 Read +
# 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。
SNOW_MOUNTAIN_SHEET = os.path.join(REPO_ROOT, "design", "snow_mountain.png")
MAGIC_CITY_SHEET = os.path.join(REPO_ROOT, "design", "magic_city.png")
# 第 7 波（接手任務：hotspring/mountain_palace/magic_city 管線推廣到第六個 layered 地域）：
# `design/holy_city.png`（歐式高奇幻聖光之城，白金聖堂/天使雕像/鐘塔拱門/十字紋章旗/
# 玫瑰花窗/噴泉/燭台，聖光天空），1536x1024，版式與 magic_city 完全相同——遠景含天空
# 不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口。座標由
# Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。
HOLY_CITY_SHEET = os.path.join(REPO_ROOT, "design", "holy_city.png")
# 第 8 波（接手任務：holy_city 管線推廣到第七個 layered 地域）：
# `design/steampunk_city.png`（蒸氣龐克飛船城，黃銅飛船/鐘塔/煙囪/蒸汽火車頭/瓦斯燈/
# 齒輪/黃銅儀表/望遠鏡/十字旗幟，暖黃銅金工業色調），1536x1024，版式與 holy_city 完全
# 相同——遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補
# 頂緣洋紅缺口。座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。
STEAMPUNK_CITY_SHEET = os.path.join(REPO_ROOT, "design", "steampunk_city.png")
# 第 9 波（接手任務：steampunk_city 管線推廣到第八個 layered 地域）：
# `design/future_city.png`（賽博龐克霓虹夜城，懸浮載具/霓虹全息廣告牌/懸浮平台/
# 全息地球儀/水晶/霓虹櫻花樹/咖啡廳與大門招牌，冷紫藍霓虹夜色調），1536x1024，版式與
# steampunk_city 完全相同——遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、
# 地面平台不去背只補頂緣洋紅缺口。座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad
# 校準紀錄。⚠️ 此圖美術本身大量使用洋紅/桃紅/紫色霓虹（招牌、燈光），與去背用的
# `#FF00FF` 洋紅色極為接近，flood-fill 去背只會吃掉「與畫面邊緣連通」的洋紅（不會吃到
# 建築內部被深色像素包住的霓虹色塊），但仍需逐張目視確認霓虹燈牌沒有被誤挖洞、也沒有
# 洋紅殘留邊緣。
FUTURE_CITY_SHEET = os.path.join(REPO_ROOT, "design", "future_city.png")
# `design/village_layered.png`（歐式中世紀奇幻村莊，農舍/教堂/風車/石拱橋/瀑布/遠山城堡，
# 版式與 holy_city 完全相同——遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、
# 地面平台不去背只補頂緣洋紅缺口），1536x1024。座標由 Read + 逐像素洋紅比例掃描校準，
# 見 scratchpad 校準紀錄。取代 meadowOrigin 舊版單張背景（`grassland`），讓開場地域也是
# layered 格式，角色不再有浮空違和感。
MEADOW_VILLAGE_SHEET = os.path.join(REPO_ROOT, "design", "village_layered.png")
# 接手任務（2026-07-05）：把 `kingdom`/`village3` 這兩個休眠中的「舊單 backdrop」地域
# 重新指到新的 layered 格式美術，重新排回循環（`meadowOrigin` 重排回循環的同一手法，
# `21` §2/§4 holy_city/meadow_village 管線原樣複製）：`design/city_layered_1.png`（歐式
# 白金王國首都：尖塔/拱橋/雪山遠景/天使雕像/紋章大門/華麗宅邸/噴泉）→ `RegionType.kingdom`
# 新資源夾 `"kingdom_city"`；`design/village3_layered.png`（森林樹屋村落：巨木/樹屋/繩橋/
# 瀑布/苔蘚屋頂農舍/市集攤位）→ `RegionType.village3` 新資源夾 `"tree_village"`。皆
# 1536x1024，版式與 meadow_village/holy_city 完全相同——遠景含天空不去背、中景/前景/道具
# 皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口。座標由 Read + 逐像素洋紅比例
# 掃描校準，見 scratchpad 校準紀錄（兩張圖的 Mid/Fore、Ground 邊界與 meadow_village 略有
# 出入，各自獨立校準，不共用同一組座標）。
KINGDOM_CITY_SHEET = os.path.join(REPO_ROOT, "design", "city_layered_1.png")
TREE_VILLAGE_SHEET = os.path.join(REPO_ROOT, "design", "village3_layered.png")
# 接手任務（2026-07-05）：把休眠中的 `RegionType.skyCity`（舊單 backdrop `sky_city`，因
# 舊格式浮空違和感被踢出循環）重新指到新的 layered 格式美術，重新排回循環尾端（壓軸，
# `kingdom`/`village3` 重排回循環的同一手法，管線原樣複製）：`design/sky_layered.png`
# （白金浮空天空之城：漂浮宮殿島/瀑布/飛船/牌樓拱門/停泊飛船碼頭/水晶）→
# `RegionType.skyCity` 新資源夾 `"sky_city_v2"`。1536x1024，版式與 meadow_village/
# kingdom_city 完全相同——遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、
# 地面平台不去背只補頂緣洋紅缺口。座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad
# 校準紀錄（此圖的 Mid/Fore/Ground 邊界與 kingdom_city/village3 略有出入，獨立校準，
# 不共用同一組座標）。
SKY_CITY_V2_SHEET = os.path.join(REPO_ROOT, "design", "sky_layered.png")
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


def _is_magenta_hued(rgba, g_max: int = 70, min_rb: int = 70, max_rb_diff: int = 60) -> bool:
    """判斷像素是否「洋紅色系」（不論明暗）：`design/harbor_test.png`（`20` §8A 新流程）
    mid/fore/道具底色是純洋紅 `#FF00FF`，但陰影/半透明邊緣會把洋紅調暗（例如長椅座板縫隙
    畫成陰影洋紅 `(139,10,138)`），這類像素亮度已經很低、跟道具本體的深色木頭/鐵件亮度
    重疊，用亮度或距純洋紅的歐氏距離都分不乾淨。改用色相判斷：洋紅系像素的特徵是
    「G 遠低於 R、B，且 R≈B」；不論明暗都成立（純洋紅到深洋紅陰影皆然），而道具本體的
    木頭/石材/金屬色調 R/G/B 不會有這種「G 特別低、R 與 B 又幾乎相等」的組合，能安全區分。
    """
    r, g, b, _ = rgba
    return g <= g_max and min(r, b) >= min_rb and abs(r - b) <= max_rb_diff


def _is_magenta_hued_relative(rgba, min_rb: int = 70, g_ratio: float = 0.75, max_rb_ratio: float = 0.35) -> bool:
    """`_is_magenta_hued` 的比例版：harbor mid/fore 校準時發現，抗鋸齒邊緣的洋紅像素常常
    在「往真正物件顏色過渡」的半途被同時拉亮 G、拉開 R/B 差距（例如 `(247,105,178)`——
    G 已經到 105、R 與 B 差到 69，雙雙超出 `_is_magenta_hued` 的絕對門檻 `g_max=70`／
    `max_rb_diff=60`，因而漏網、殘留成畫面上可見的洋紅/紫色雜邊）。改用「相對於自身
    亮度」的比例門檻取代絕對值：只要 G 明顯低於 R/B 中較小值的 `g_ratio`（預設 75%），
    且 R/B 差距沒有超過「較大值的 `max_rb_ratio`（35%）」（跟至少 40 取大，避免暗部
    誤傷），就算洋紅系——這樣不論這個像素被抗鋸齒拉到多亮/多暗，只要「G 相對凹陷、
    R≈B」這個洋紅色相特徵還在，都能抓到。與 `_is_magenta_hued` 一樣不誤傷道具實際
    暖色（木頭/石材/花色）：這些顏色的最小通道幾乎都是 G 或 B 更低而非「R、B 同時偏高、
    只有 G 凹陷」的洋紅特徵組合（見 harbor 素材表道具調色盤逐色核對，未發現誤傷案例）。
    """
    r, g, b, _ = rgba
    lo = min(r, b)
    hi = max(r, b)
    if lo < min_rb:
        return False
    if abs(r - b) > max(40, hi * max_rb_ratio):
        return False
    return g < lo * g_ratio


def remove_magenta_spill(img: Image) -> Image:
    """`chroma_key_flood_color` 只能挖掉「從畫布邊界 flood-fill 連通」的洋紅像素；道具本體內部
    被完全包圍、連不到邊界的洋紅色殘留（例如長椅座板/靠背縫隙、噴泉底座陰影，`20` §8A 新流程
    校準時發現）無法靠 flood-fill 處理到。這裡不管連通性，直接對每個不透明像素做色相判斷
    （`_is_magenta_hued` **或** `_is_magenta_hued_relative`，後者專門補前者對「抗鋸齒半洋紅
    邊緣」的漏網——見其說明），命中就轉透明——因為這些縫隙/雜邊原本就代表「這裡應該透出
    後方」，轉透明才是正確效果（而非誤傷道具本體，道具的木頭/金屬色調不會被誤判，見兩個
    判準函式的說明）。
    """
    w, h = img.width, img.height
    out = Image(w, h, [row[:] for row in img.pixels])
    for y in range(h):
        for x in range(w):
            r, g, b, a = out.pixels[y][x]
            if a == 0:
                continue
            pixel = (r, g, b, a)
            if _is_magenta_hued(pixel) or _is_magenta_hued_relative(pixel):
                out.pixels[y][x] = (r, g, b, 0)
    return out


def defringe_magenta_edges(img: Image, passes: int = 2) -> Image:
    """去除洋紅去背後、物件輪廓上殘留的「抗鋸齒洋紅光暈」（洋紅與內容混色的 1~2px 邊緣像素，
    例如 `(205,87,126)`/`(121,11,203)`——G 明顯凹陷、R≈B 或偏紫，散在物件邊緣形成可見的
    粉紫雜邊）。`remove_magenta_spill` 的 `|r-b|` 護欄為了不誤傷暖色花草會放過這些偏粉/偏紫
    的邊緣像素；本函式改用「**只清緊鄰透明的邊緣像素**」策略：洋紅系（G 相對凹陷）且**四鄰
    至少一個是透明**的像素才清掉——因為真正的道具內容（花瓣/木頭）位於物件內部、不鄰透明，
    不會被誤傷；只有「去背邊界上被磁染的抗鋸齒像素」會鄰透明而被清。跑 `passes` 次以吃掉
    1~2px 的光暈。"""
    w, h = img.width, img.height
    out = Image(w, h, [row[:] for row in img.pixels])
    for _ in range(passes):
        clear = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = out.pixels[y][x]
                if a == 0:
                    continue
                lo = min(r, b)
                if lo < 90 or g >= lo * 0.78:
                    continue  # 非洋紅/粉紫系（G 沒有明顯凹陷）→ 放過
                # 四鄰有透明才算「邊緣被磁染」
                near_transp = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and out.pixels[ny][nx][3] == 0:
                        near_transp = True
                        break
                if near_transp:
                    clear.append((x, y))
        for x, y in clear:
            px = out.pixels[y][x]
            out.pixels[y][x] = (px[0], px[1], px[2], 0)
    return out


def strip_magenta_bleed_rows(img: Image, g_margin: int = 15, min_brightness: int = 150, max_rows: int = 8) -> Image:
    """`design/harbor_test.png` 每一帶（far/mid/fore/...）交界處都疊了細細的分隔線，這條線
    本身在洋紅底上做抗鋸齒時，會整條「洋紅→白」漸層（例如 mid 帶最底兩列量到
    `(255,207,255)`／`(255,234,255)`：R、B 已經頂到 255、幾乎看不出彩度，但 G 仍比 R/B
    低 20～50，肉眼是一條明顯的粉紅/洋紅線）。這種像素亮度太高、太接近白色，
    `_is_magenta_hued`／`_is_magenta_hued_relative`（比例門檻 `g_ratio=0.75`）都抓不到
    （`234 < 255*0.75=191.25` 為假）——但整條線橫跨全寬、逐像素平均後洋紅色相訊號非常
    穩定，因此改用「整列平均」判斷：只掃描 mid/fore 裁切後最上/下緣最多 `max_rows` 列，
    只要某列不透明像素的平均 G 比平均 min(R,B) 低超過 `g_margin`（且亮度夠高，排除誤判
    暗部），就整列清成透明；一旦某列不成立就停止往內掃，保證只清掉貼著裁切邊界的
    分隔線殘影，不會誤傷帶子內部的真實內容（chroma_key_flood_color 之後這幾列本來就
    只剩下分隔線，沒有道具/建築內容，全部清透明不會造成畫面缺口）。
    """
    w, h = img.width, img.height
    out = Image(w, h, [row[:] for row in img.pixels])

    def row_is_bleed(y: int) -> bool:
        total = 0
        sum_g = 0
        sum_minrb = 0
        for x in range(w):
            r, g, b, a = out.pixels[y][x]
            if a == 0:
                continue
            total += 1
            sum_g += g
            sum_minrb += min(r, b)
        if total == 0:
            return False
        avg_g = sum_g / total
        avg_minrb = sum_minrb / total
        return avg_minrb >= min_brightness and (avg_minrb - avg_g) >= g_margin

    def clear_row(y: int) -> None:
        for x in range(w):
            r, g, b, _ = out.pixels[y][x]
            out.pixels[y][x] = (r, g, b, 0)

    for y in range(0, min(max_rows, h)):
        if row_is_bleed(y):
            clear_row(y)
        else:
            break
    for y in range(h - 1, max(-1, h - 1 - max_rows), -1):
        if row_is_bleed(y):
            clear_row(y)
        else:
            break
    return out


def patch_magenta_columns(img: Image, tol: int = 75) -> Image:
    """`design/harbor_test.png` Ground 帶（`20` §8A：地面平台不去背，全層保持不透明）本身
    在頂緣散布幾處洋紅色缺口（碼頭平台高低落差處露出底下的洋紅畫布，非道具/非要去背的
    範圍，肉眼校準時發現），若照樣輸出會在石砌碼頭上留下刺眼的洋紅色斑塊。逐欄處理：
    把每一欄裡洋紅色的像素，用同一欄「最近的非洋紅色像素」（優先往下找——碼頭實體通常在
    缺口下方，找不到才往上找）取代，等於把旁邊的碼頭紋理「拉」過來蓋住缺口，比留著洋紅色
    或整塊挖透明都自然（挖透明會在不透去背的地面層開洞，看起來像地面破損）。
    """
    w, h = img.width, img.height

    def is_magenta(rgba) -> bool:
        # 亮洋紅（原絕對門檻）或較暗/抗鋸齒的洋紅（相對門檻，補抓 ground 上緣殘留的暗洋紅列）。
        # 灰石陰影 g≈r≈b、相對門檻要求 G 明顯凹陷，不會誤中石材。
        return _is_magenta_hued(rgba, g_max=tol, min_rb=255 - tol, max_rb_diff=2 * tol) \
            or _is_magenta_hued_relative(rgba)

    out = Image(w, h, [row[:] for row in img.pixels])
    for x in range(w):
        col = [out.pixels[y][x] for y in range(h)]
        magenta_ys = [y for y in range(h) if is_magenta(col[y])]
        if not magenta_ys:
            continue
        for y in magenta_ys:
            replacement = None
            for yy in range(y + 1, h):
                if not is_magenta(col[yy]):
                    replacement = col[yy]
                    break
            if replacement is None:
                for yy in range(y - 1, -1, -1):
                    if not is_magenta(col[yy]):
                        replacement = col[yy]
                        break
            if replacement is not None:
                out.pixels[y][x] = replacement
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


def flip_horizontal(img: Image) -> Image:
    """左右鏡像翻轉（美術大改版第 1 波用途：`design/resource_v2.png` 的「主角-女」走路/待機幀
    本體朝**左**走——素材表沒有畫向右走的版本，只能用向左幀水平鏡像取代，產出旅伴的
    `char_companion/right_*.png`。純幾何鏡像、不影響去背/裁邊結果，鏡像後角色朝右，
    與主角 `main_role.png` 的「向右」欄一致。）
    """
    out = Image(img.width, img.height, [list(reversed(row)) for row in img.pixels])
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


# 主角「向右」列 / 旅伴「向右」列的舊座標表（`asset_sheet.png`）已隨美術大改版第 1 波
# （`21_ASSET_OVERHAUL_PLAN.md` §4）作廢——主角/旅伴改讀 `design/main_role.png` /
# `design/resource_v2.png`，座標表見下方「美術大改版第 1 波」章節
# （`MAIN_ROLE_RIGHT_ROWS` / `MAIN_ROLE_FRONT_ROWS` / `RESOURCE_V2_FEMALE_WALK_FRAMES`）。
# `asset_sheet.png` 的角色列本身保留在圖檔中未變，只是程式不再讀取。

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
# 王國首都座標設定表（美術大改版第 2 波，`21_ASSET_OVERHAUL_PLAN.md` §4，由 Read
# design/kingdom.png 目視 + 逐像素亮度/連通元件掃描校準，新版 1536x1024，取代 Stage C
# 舊 1774x887 版本——版面/道具完全不同，重新校準，座標與舊版無法沿用。
# 新版與 grassland.png 同款版式（`20_ASSET_SHEET_SPEC.md`）：四層 y 帶 + 底部道具列，
# 每層/道具列左上角疊「遠景/中景/前景/地面平台/道具素材」標籤黑底方框。）
# ---------------------------------------------------------------------------

# 背景四層 y 範圍（逐像素亮度斷點掃描校準，與 grassland/valley/village_2/village_3/
# sky_village/sky_city 六張新版素材表共用同一套版面帶——皆由同一模板產生，斷點 y 座標
# 彼此一致，見 scratchpad 校準紀錄）：
#   遠景：y=0..233　中景：y=234..451　前景：y=452..665　地面平台：y=666..787
#   （788 起「道具素材」標籤方框開始疊在道具列畫布上）
KINGDOM_BG_FAR = Region(x=0, y=0, w=1536, h=234)
KINGDOM_BG_MID = Region(x=0, y=234, w=1536, h=218)
KINGDOM_BG_FORE = Region(x=0, y=452, w=1536, h=214)
KINGDOM_BG_GROUND = Region(x=0, y=666, w=1536, h=122)

# 各層左上角標籤方框（同 `GRASSLAND_LABEL_BOX_RECTS` 手法，六張新地域素材表版式一致，
# 沿用同一份方框座標）。
KINGDOM_LABEL_BOX_RECTS: dict = {
    "far": Region(x=0, y=0, w=150, h=48),
    "mid": Region(x=0, y=0, w=150, h=48),
    "fore": Region(x=0, y=0, w=150, h=48),
    "ground": Region(x=0, y=15, w=115, h=38),
}

# mid 疊在 far 之前、fore 疊在 mid 之前，皆有小段上緣重疊（`ParallaxBackground` 對應 overlap 常數），
# 各自獨立 panorama，淡出上緣讓接縫變成漸層過渡（同 `BG_MID_TOP_FADE_PX` 手法）。
KINGDOM_BG_MID_TOP_FADE_PX = 18
KINGDOM_BG_FORE_TOP_FADE_PX = 14

# 道具／互動物件：新版 kingdom.png 底部道具列（y=790..1024，近黑色畫布），逐一 Read 裁切
# 目視 + 逐像素連通分段掃描校準座標（見 scratchpad 校準紀錄）。11 個道具：
# 旗幟／燈柱／樹／石獅／噴泉／市集推車／木箱+木桶／天使雕像／公告牌／石柱／藍頂小圓頂建築。
# 範圍刻意留餘裕，去背 + autocrop 後收斂到精確 bounding box。
KINGDOM_PROP_REGIONS: dict = {
    "banner": Region(x=5, y=790, w=135, h=234),
    "lamppost": Region(x=145, y=790, w=100, h=234),
    "tree": Region(x=248, y=790, w=150, h=234),
    "lion": Region(x=400, y=790, w=150, h=234),
    "fountain": Region(x=552, y=790, w=148, h=234),
    "cart": Region(x=701, y=790, w=160, h=234),
    "crate": Region(x=863, y=790, w=182, h=234),
    "angel": Region(x=1045, y=790, w=105, h=234),
    "signboard": Region(x=1150, y=790, w=108, h=234),
    "pillar": Region(x=1258, y=790, w=122, h=234),
    "dome": Region(x=1380, y=790, w=156, h=234),
}

# 第一個道具（`banner`）與其餘 5 張新地域素材表的第一個道具一樣，裁切區左上角會框到
# 「道具素材」標籤黑底方框（見 `_GRASSLAND_PROP_EXCLUDE_RECTS` 同款動機），用 exclude rect
# 蓋掉再去背。
_KINGDOM_PROP_EXCLUDE_RECTS: dict = {
    "banner": [Region(x=0, y=0, w=150, h=52)],
}

# 去雜點策略（同 `_GRASSLAND_DILATED_PROPS` 說明）：細桿件/薄邊框（燈柱、旗幟旗桿、石柱、
# 公告牌邊框、噴泉裝飾細節、市集推車車輪輻條）用 `keep_largest_component_dilated` 防斷；
# 其餘本身多個分離部件（樹叢、木箱+木桶組合、天使雕像羽翼、圓頂建築裝飾）用
# `remove_small_components` 保留分離部件。
_KINGDOM_DILATED_PROPS = {"banner", "lamppost", "fountain", "cart", "signboard", "pillar"}
_KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA = 30

# 王國道具列畫布背景色（逐像素取樣畫布角落確認，同 `_GRASSLAND_PROP_BG_COLOR` 說明）。
_KINGDOM_PROP_BG_COLOR = (14, 28, 40)


# ---------------------------------------------------------------------------
# 美術大改版第 1 波（`21_ASSET_OVERHAUL_PLAN.md` §4）：主角 = design/main_role.png、
# 旅伴 = design/resource_v2.png 的「主角-女（冒險者）」走路幀。
# ---------------------------------------------------------------------------

# `main_role.png`（1536x1024，近黑底 #15171 系）版面：頂部標題列 + 4 欄（向右/向左/向前/背面）
# 標籤列 + 3 排姿勢（每排一種 pose：站姿／跨步走／持物），由逐像素亮度列/欄投影校準
# （見 scratchpad 校準紀錄）：
#   欄：向右 x≈220-370、向左 x≈540-680、向前 x≈850-1030、背面 x≈1180-1320
#   排：第1排 y≈190-440、第2排 y≈470-700、第3排 y≈730-960
# 本波只取「向右」（走路循環）與「向前」（待機/看你）兩欄，「向左」「背面」暫不用（`21` §4）。
MAIN_ROLE_RIGHT_ROWS = [
    Region(x=210, y=185, w=170, h=260),
    Region(x=210, y=465, w=170, h=250),
    Region(x=210, y=725, w=170, h=245),
]
MAIN_ROLE_FRONT_ROWS = [
    Region(x=840, y=185, w=200, h=260),
    Region(x=840, y=465, w=200, h=250),
    Region(x=840, y=725, w=200, h=245),
]

# `main_role_walk.png`（1536x1024，深紫底）版面：上排「走路(Walk)」8 幀（側視朝右，
# 左右腳明確交替的完整循環，標號 1~8）、下排「待機(Idle)」4 幀（本波不用）。取代
# `MAIN_ROLE_RIGHT_ROWS`（原本從 `main_role.png` 切 3 個靜態姿勢當「走路」，腳步不連續）。
# 座標由逐像素亮度掃描校準（見 scratchpad 校準紀錄）：
#   Walk 排內容 y=194..431（8 個字元 bounding box 在此 y 帶內），扣掉下方標號列（y=455..476）
#   與上方「走路(Walk)」標題（y=96..150）後，取 y=186..439（上下各留 8px 餘裕）。
#   8 幀 x 範圍（逐欄亮度掃描，欄間最窄間隙僅 5~8px，故每幀左右餘裕依實際間隙動態調整，
#   避免相鄰幀被框進來）：
MAIN_ROLE_WALK_ROW = [
    Region(x=25, y=186, w=199, h=254),
    Region(x=228, y=186, w=186, h=254),
    Region(x=416, y=186, w=189, h=254),
    Region(x=611, y=186, w=179, h=254),
    Region(x=791, y=186, w=180, h=254),
    Region(x=974, y=186, w=182, h=254),
    Region(x=1156, y=186, w=175, h=254),
    Region(x=1332, y=186, w=176, h=254),
]


# `main_role_walk_v2.png`（1536x1024，深藏青底 `RGB(15,15,20)`）版面：標題「旅行者
# （側視 朝右）動作表」置中於頂部；「走路(Walk)」列（標籤方框 + 8 幀 + 下方 1~8 標號）；
# 「待機(Idle)」列（標籤方框 + 4 幀 + 下方 1~4 標號）。座標由逐像素「與背景色歐氏距離」
# 掃描校準（見 scratchpad 校準紀錄）：
#   Walk 內容 y 帶 202..438（8 幀 bounding box 皆落在此帶內，上方標籤列 y=114..171、
#   下方數字標號列 y=459..482，皆已排除）；8 幀 x 範圍（逐欄掃描 + 15px 內縫隙合併）：
#   [56,207] [253,385] [441,585] [627,751] [811,943] [988,1129] [1164,1302] [1342,1485]。
#   Idle 內容 y 帶 645..872（上方標籤列 y=558..615、下方標號列 y=893..915，皆已排除）；
#   4 幀 x 範圍：[77,204] [312,459] [545,698]（含 frame 3 右側的飄葉+閃光裝飾）[766,891]。
# 每幀外擴 4px 餘裕（避免切到邊緣抗鋸齒），去背 + autocrop 後會收斂到本體 bounding box。
MAIN_ROLE_WALK_V2_ROW = [
    Region(x=52, y=198, w=160, h=245),
    Region(x=249, y=198, w=141, h=245),
    Region(x=437, y=198, w=153, h=245),
    Region(x=623, y=198, w=133, h=245),
    Region(x=807, y=198, w=141, h=245),
    Region(x=984, y=198, w=150, h=245),
    Region(x=1160, y=198, w=147, h=245),
    Region(x=1338, y=198, w=152, h=245),
]
MAIN_ROLE_IDLE_V2_ROW = [
    Region(x=73, y=641, w=136, h=236),
    Region(x=308, y=641, w=156, h=236),
    Region(x=541, y=641, w=162, h=236),
    Region(x=762, y=641, w=134, h=236),
]

# `main_role_walk_v2.png` 背景色（逐像素取樣畫布角落確認，深藏青，非其餘素材表慣用的
# 近黑 `#1B1B1B`），`chroma_key_flood_color` 需指定此色才能乾淨去背。
MAIN_ROLE_WALK_V2_BG_COLOR = (15, 15, 20)


def _lowest_opaque_row(img: Image) -> int:
    """回傳最下面一列「有任何不透明像素」的 row index；全透明則回傳 -1。"""
    for y in range(img.height - 1, -1, -1):
        if any(p[3] > 0 for p in img.pixels[y]):
            return y
    return -1


def _autocrop_left_right_top(img: Image) -> Image:
    """`autocrop` 的變體：只裁左/右/上緣到 bounding box，**刻意不動下緣**（最後一列原樣
    保留，即使該列在裁切前不是本體 bounding box 的最下緣）。用於「共享地面基準線」裁切
    流程（見 `slice_main_role_walk_v2`）：所有 frame 已先被裁到同一條共享基準線收尾，
    這裡只需再收掉左右上的多餘留白，不能再對下緣做 autocrop，否則會抹掉「刻意讓每張
    frame 的最後一列都等於基準線」這個效果。
    """
    min_x, max_x, min_y = img.width, -1, img.height
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
    if max_x < 0:
        return img
    h = img.height - min_y
    return img.crop(min_x, min_y, max_x - min_x + 1, h)


def slice_main_role_walk_v2(sheet: Image, regions: list, dedup_fn) -> list:
    """裁出 `main_role_walk_v2.png` 某一列（走路 8 幀或待機 4 幀）：去背 + 去雜點 + 依
    `dedup_fn` 決定的策略清連通塊，最後用「共享地面基準線」裁切取代逐幀獨立 autocrop。

    背景：舊版 `slice_main_role_column`（`main_role_walk.png`）對每個 frame 各自
    `autocrop`，取「該 frame 自己的最下面不透明像素」當作 frame 底邊。這在走路循環圖裡
    是個問題——素材表本體腳步高度天生有 1~2px 的自然擺動（加上腳底若殘留一絲去背後的
    陰影殘跡，殘跡範圍逐幀不同），逐幀獨立 autocrop 會讓每幀的「底邊」落在不同的
    實際地面高度，套用到遊戲的 anchorPoint (0.5,0) 底部對齊後，角色在原地走路動畫時
    會逐幀垂直跳動，就是使用者回報的「像在飄」的成因。

    修法：**共享基準線**——8 幀（或 4 幀）先各自跑完整去背流程，量出每幀「自己最下面
    的不透明列」，取這批數值裡最小的一個（即最保守、離頂端最近的那條線）當全部 frame
    共用的地面基準線；每幀都裁到「最後一列 = 這條共享基準線」，落差在基準線以下的 1~2px
    （其他 frame 天然多出來的腳步差異）直接裁掉——因為基準線取的是「最小值」，保證每幀
    在該列本身一定还有不透明像素（该列必然落在該幀腳部本體範圍內，不會裁出空白列），
    所以每一幀輸出的 bottomPad 必為 0。裁完基準線後才對左/右/上緣做 `autocrop`
    （`_autocrop_left_right_top`，不可再動下緣），確保左右邊界依然貼合本體。
    最後套 `pad_to_common_size`（水平置中 + 底部對齊）讓 8（或 4）幀寬高一致——因為
    下緣已經是共享基準線，底部對齊不會重新引入垂直跳動，只是把較窄/較矮的 frame 置中/
    向上補滿透明像素。

    `dedup_fn` 由呼叫端決定：
    - 走路 8 幀：`keep_largest_component_dilated`（本體是單一連通塊，含影子的孤立
      殘留可直接靠「只留最大塊」丟棄，同 `slice_main_role_column`）。
    - 待機 4 幀：**不能**用「只留最大塊」——frame 2 的呼吸白霧、frame 3 的飄落樹葉+
      閃光都是刻意設計、與角色本體不相連的獨立小色塊（`21_ASSET_OVERHAUL_PLAN.md`
      待機微互動範疇），用 `keep_largest_component_dilated` 會把這些裝飾當雜訊砍掉。
      改用 `remove_small_components`（面積門檻，同 `slice_props` 對多部件道具的處理），
      只清掉真正的雜點殘留，保留這些故意分離的裝飾色塊。
    """
    processed = []
    baselines = []
    for region in regions:
        cropped = sheet.crop(region.x, region.y, region.w, region.h)
        keyed = chroma_key_flood_color(cropped, MAIN_ROLE_WALK_V2_BG_COLOR, threshold=32)
        keyed = despeckle_neutral_residue(keyed)
        keyed = dedup_fn(keyed)
        processed.append(keyed)
        baselines.append(_lowest_opaque_row(keyed))

    common_baseline = min(baselines)
    frames = []
    for keyed in processed:
        trimmed = keyed.crop(0, 0, keyed.width, common_baseline + 1)
        trimmed = _autocrop_left_right_top(trimmed)
        frames.append(trimmed)
    return pad_to_common_size(frames)


def slice_main_role_column(sheet: Image, rows: list) -> list:
    """裁出 `main_role.png` 某一欄（向右或向前）的 3 排姿勢，各自去背/去雜點/autocrop。
    `main_role.png` 背景近黑（同 `asset_sheet.png` 系），沿用 `chroma_key_flood` 去背流程；
    每排是單一姿勢（非同一姿勢的多張走路 frame），故不需要 `segment_row_by_gaps` 這種
    「一排切多格」的邏輯，直接整塊裁切即可。

    用 `keep_largest_component_dilated` 而非單純 `keep_largest_component`：校準時發現
    「向前」姿勢的頭部與身體之間的頸部連接處，去背後偶爾只剩 1px 連通，`chroma_key_flood`
    的 flood-fill 在該處會把頭部與身體分成兩個獨立連通塊，`keep_largest_component`
    （只留最大塊）會直接把整顆頭砍掉、只留下軀幹——跟燈柱細桿斷裂是同一類問題
    （`21_ASSET_OVERHAUL_PLAN.md` §5「細桿件用 keep_largest_component_dilated 防去斑咬斷」，
    頸部連接處本質上也是一種「細桿件」）。膨脹後的連通判斷能跨過這種 1-2px 斷點，
    且膨脹只影響「誰被判定為最大塊」，不影響最終保留哪些像素（見其 docstring）。
    """
    frames = []
    for region in rows:
        cropped = sheet.crop(region.x, region.y, region.w, region.h)
        keyed = chroma_key_flood(cropped, threshold=28)
        keyed = despeckle_neutral_residue(keyed)
        keyed = keep_largest_component_dilated(keyed, dilate_px=3)
        frames.append(autocrop(keyed))
    return frames


# `resource_v2.png`（1536x1024，**白底**，與其餘素材表的近黑底不同，去背需用
# `chroma_key_flood_color` 指定白色背景）版面：「主角-女（冒險者）」走路列，逐像素欄投影
# 校準（見 scratchpad 校準紀錄）抓出 8 個等寬 frame 的 x 範圍，y 帶 503..593（含頭頂到鞋底，
# 上下留一點餘裕）。**素材本體朝左走**（沒有畫朝右的版本）——切出後用 `flip_horizontal`
# 水平鏡像成朝右，才能當旅伴「向右走路」用（與主角 `main_role.png` 的「向右」欄方向一致）。
RESOURCE_V2_FEMALE_WALK_ROW_Y = 503
RESOURCE_V2_FEMALE_WALK_ROW_H = 90
RESOURCE_V2_FEMALE_WALK_FRAME_XS = [112, 217, 316, 412, 517, 611, 704, 792]
RESOURCE_V2_FEMALE_WALK_FRAME_W = 60


def slice_resource_v2_companion_walk(sheet: Image) -> list:
    """裁出 `resource_v2.png` 女冒險者走路列的 8 個 frame，去背（白底）+ 去雜點 + autocrop，
    再水平鏡像成向右（素材本體朝左，見上方欄位說明），供旅伴 `char_companion/right_*.png` 用。
    """
    frames = []
    for x in RESOURCE_V2_FEMALE_WALK_FRAME_XS:
        w = min(RESOURCE_V2_FEMALE_WALK_FRAME_W, sheet.width - x)
        cropped = sheet.crop(x, RESOURCE_V2_FEMALE_WALK_ROW_Y, w, RESOURCE_V2_FEMALE_WALK_ROW_H)
        keyed = chroma_key_flood_color(cropped, (255, 255, 255), threshold=40)
        # `keep_largest_component_dilated`（同 `slice_main_role_column` 說明）：防止頭部與
        # 身體間的頸部連接處因去背斷開 1-2px 而被判定成兩個連通塊，導致頭被誤刪。
        keyed = keep_largest_component_dilated(keyed, dilate_px=3)
        keyed = autocrop(keyed)
        frames.append(flip_horizontal(keyed))
    return frames


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


def patch_label_box_horizontal(img: Image, rect: "Region") -> Image:
    """`patch_label_box` 的水平版：把 `rect` 這塊區域用「`rect` 正右方同一列」的像素往左貼過來
    （逐 row 各自抓自己那一列 `rect.x + rect.w` 處的像素，而非單一列垂直重複）。

    動機（草原 `design/grassland.png` 地面平台層「地面平台」標籤方框）：`patch_label_box`
    假設方框所在區域背景是「垂直方向變化平緩」的漸層（天空/牆面），單一列垂直重複貼滿
    在那種場景下不明顯；但地面平台層本身是「草地/泥土路徑」紋理，同一行內左右紋理相近、
    但同一列的上下紋理變化劇烈（石板/雜草/陰影交錯），垂直重複反而會貼出一塊突兀的
    平頂色塊。地面紋理沿水平方向大致重複（本來就要做水平無縫平鋪），改成「抓方框右側同一
    列」逐行取代，貼出來的內容跟方框正下方的真實地面紋理在垂直方向上完全對齊、只是左右
    平移，視覺上遠比垂直重複貼近「這裡本來就是草地」的樣子。
    """
    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    src_x = min(img.width - 1, rect.x + rect.w)
    for y in range(max(0, rect.y), min(img.height, rect.y + rect.h)):
        for x in range(max(0, rect.x), min(img.width, rect.x + rect.w)):
            out.pixels[y][x] = out.pixels[y][src_x]
    return out


def patch_label_box_sky(img: Image, rect: "Region") -> Image:
    """遠景（far）天空 backdrop 層專用的標籤方框補丁——取代 `patch_label_box` 的「單一列
    往下重複」。單列重複在天空層會留下一塊平頂色塊 / 一條淡直紋（village_3 左上最明顯，
    grassland/kingdom/sky 系列為淡直紋），因為它只複製「方框上/下緣一列」的顏色、無法跟隨
    天空的垂直漸層與水平雲色變化。

    做法：對方框內每個像素，取「上/下/左/右」四個方向、方框「外緣」最近的真實像素當來源，
    用**反距離加權**（1/軸向距離）混合。等於用方框四周的真實天空把這塊洞平滑內插補回來
    （inpainting-lite）：垂直漸層由上下鄰邊帶入、水平雲色由左右鄰邊帶入，離哪邊近就更像那邊，
    不會出現死板色塊或直紋。方框貼邊（如 far 標籤 y=0 貼頂、x=0 貼左）時該方向無來源，
    自動只用另外兩到三邊，效果一樣自然。

    **僅用於不透明 far backdrop 層**：絕不用於 mid/fore 洋紅去背層——把洋紅(255,0,255)與相鄰
    內容內插會混出中間色，chroma-key 抓不到而留下彩色殘留。mid/fore 的標籤方框在去背後本來
    就變透明、看不見，維持用 `patch_label_box` 即可。
    """
    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    x0, y0 = max(0, rect.x), max(0, rect.y)
    x1, y1 = min(img.width, rect.x + rect.w), min(img.height, rect.y + rect.h)
    if x1 <= x0 or y1 <= y0:
        return out
    top_y = y0 - 1 if y0 - 1 >= 0 else None       # 上緣外一列
    bot_y = y1 if y1 < img.height else None         # 下緣外一列
    left_x = x0 - 1 if x0 - 1 >= 0 else None        # 左緣外一欄
    right_x = x1 if x1 < img.width else None         # 右緣外一欄

    def _norm(px):
        return px if len(px) == 4 else (px[0], px[1], px[2], 255)

    for yy in range(y0, y1):
        for xx in range(x0, x1):
            acc = [0.0, 0.0, 0.0, 0.0]
            wsum = 0.0
            # 四個軸向鄰邊，權重 = 1/軸向距離（離得近的真實邊界影響更大）
            neighbors = []
            if top_y is not None:
                neighbors.append((img.pixels[top_y][xx], yy - top_y))
            if bot_y is not None:
                neighbors.append((img.pixels[bot_y][xx], bot_y - yy))
            if left_x is not None:
                neighbors.append((img.pixels[yy][left_x], xx - left_x))
            if right_x is not None:
                neighbors.append((img.pixels[yy][right_x], right_x - xx))
            for px, dist in neighbors:
                px = _norm(px)
                w = 1.0 / max(1, dist)
                for k in range(4):
                    acc[k] += w * px[k]
                wsum += w
            if wsum > 0:
                out.pixels[yy][xx] = tuple(int(round(acc[k] / wsum)) for k in range(4))
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


def make_horizontally_seamless(img: Image, blend_px: int = 64) -> Image:
    """把 `img` 左右緣做水平 cross-fade，讓「右緣接左緣」時無跳變，可真無縫橫向平鋪
    （`ParallaxBackground.buildLayer` 用 `WorldScroll.panoramaTileXs` 把同一張圖一張接一張
    左右排列，接縫正是「這張的右緣」貼著「下一張（同一張圖）的左緣」）。

    治本保險（取代先前撤掉的「奇數 tile 鏡像平鋪」ABAB 手法——那會讓遠景左右對稱鏡射，
    使用者要真無縫、不鏡射）：即使來源美術（ChatGPT 生成）左右緣像素本身有落差，也能靠
    這裡的後製羽化消除接縫，不必依賴生成端完美對齊、也不必犧牲畫面不對稱性。

    作法：取最右 `blend_px` 寬直條與最左 `blend_px` 寬直條，對每一欄做線性 alpha 混合——
    最右緣（欄 `width-1`）幾乎全採「最左欄」內容，越往左（往 `width-1-blend_px` 方向）越多
    採原本右緣內容，在 `width-1-blend_px` 處恢復成幾乎全原圖。這樣「右緣」的內容被漸變成
    「左緣」的內容，橫向重複貼圖時右緣視覺上等於左緣，接縫消失；只動右緣一側的一條窄帶，
    左緣本身完全不動、不影響圖的其餘畫面。
    """
    blend_px = min(blend_px, img.width // 2) if img.width > 1 else 0
    if blend_px <= 0:
        return img

    out = Image(img.width, img.height, [row[:] for row in img.pixels])
    width = img.width
    for y in range(img.height):
        for d in range(blend_px):
            # `d` = 離右緣的距離：d=0 是最右緣一欄（x=width-1），越大越往內。
            # 配對的「左緣欄」用同樣的距離 `d`（即 `img[d]`）——這樣 x=width-1 配 `img[0]`、
            # x=width-2 配 `img[1]`……使兩者的「距各自邊緣的距離」相等，横向拼接時邊緣
            # 兩側的漸變坡度對稱、平滑；`t` 在 d=0 時幾乎全採左緣內容（讓 x=width-1 實質上
            # 等於 `img[0]`，銜接下一張貼圖的左緣時完全連續），隨 `d` 增大線性收斂回原圖。
            x = width - 1 - d
            t = 1.0 - d / blend_px  # d=0 → t≈1（幾乎全左緣）；d=blend_px-1 → t 趨近 0（幾乎全原圖）。
            right_px = img.pixels[y][x]
            left_px = img.pixels[y][d]
            blended = tuple(
                int(round(right_px[c] * (1 - t) + left_px[c] * t))
                for c in range(4)
            )
            out.pixels[y][x] = blended
    return out


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


def slice_kingdom_props(sheet: Image) -> dict:
    """王國道具切圖（美術大改版第 2 波，新版 1536x1024 kingdom.png）：座標表
    `KINGDOM_PROP_REGIONS`，流程與 `slice_grassland_props` 相同（`chroma_key_flood_color` +
    exclude rect 蓋標籤方框 + 依 `_KINGDOM_DILATED_PROPS` 選去雜點策略）。"""
    out = {}
    for name, region in KINGDOM_PROP_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        if name in _KINGDOM_PROP_EXCLUDE_RECTS:
            cropped = _apply_exclude_rects(cropped, _KINGDOM_PROP_EXCLUDE_RECTS[name])
        keyed = chroma_key_flood_color(cropped, _KINGDOM_PROP_BG_COLOR, threshold=20)
        if name in _KINGDOM_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=_KINGDOM_NEIGHBOR_DEBRIS_MIN_AREA)
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


# ---------------------------------------------------------------------------
# 草原地域座標設定表（美術大改版第 1 波，`21_ASSET_OVERHAUL_PLAN.md` §4，取代 meadow，
# 由 Read design/grassland.png 目視 + 逐像素亮度/連通元件掃描校準，1536x1024）。
# ---------------------------------------------------------------------------

# 版式與 kingdom.png/sea_city.png 相同（無留白邊界欄，內容滿版到左右畫布邊緣；每層/道具列
# 左上角疊「遠景/中景/前景/地面平台/道具素材」標籤黑底方框）。背景四層 y 範圍以逐像素亮度
# 斷點交叉校準（見 scratchpad 校準紀錄）：
#   遠景（浮空島+雪山+遠丘）：      y=0..234
#   中景（風車村+石橋+河谷）：      y=234..452
#   前景（石屋市集+旗幟+井+攤販）： y=452..666
#   地面平台（石磚步道+青苔矮牆）： y=666..788（789 起「道具素材」標籤方框開始疊在道具列畫布上）
GRASSLAND_BG_FAR = Region(x=0, y=0, w=1536, h=234)
GRASSLAND_BG_MID = Region(x=0, y=234, w=1536, h=218)
GRASSLAND_BG_FORE = Region(x=0, y=452, w=1536, h=214)
GRASSLAND_BG_GROUND = Region(x=0, y=666, w=1536, h=122)

# 各層左上角標籤方框（同 `KINGDOM_LABEL_BOX_RECTS`/`SEA_CITY_LABEL_BOX_RECTS` 手法，相對於
# 該層裁切後的區域座標；四層都有方框疊在內容左上角，含地面平台——與 kingdom/sea_city 不同，
# 這裡「地面平台」文字方框確實疊在地面平台層本身而非道具列畫布上，需一併 patch）。
GRASSLAND_LABEL_BOX_RECTS: dict = {
    "far": Region(x=0, y=0, w=150, h=48),
    "mid": Region(x=0, y=0, w=150, h=48),
    "fore": Region(x=0, y=0, w=150, h=48),
    "ground": Region(x=0, y=15, w=115, h=38),
}

GRASSLAND_BG_MID_TOP_FADE_PX = 18
GRASSLAND_BG_FORE_TOP_FADE_PX = 14

# 道具列（y=790..1024，近黑色畫布，同 kingdom/sea_city 手法）：11 個獨立道具，逐一用
# 「欄有無亮於背景像素」連通分段掃描抓出候選 x 範圍（見 scratchpad 校準紀錄），
# 命名依實際外觀（樹/旗幟/路標/井/貨車/花箱/桶/攤/箱/風車/立石）。
GRASSLAND_PROP_REGIONS: dict = {
    "tree": Region(x=5, y=790, w=207, h=234),
    "banner": Region(x=235, y=790, w=85, h=234),
    "signpost": Region(x=343, y=790, w=85, h=234),
    "well": Region(x=454, y=790, w=112, h=234),
    "haycart": Region(x=580, y=790, w=144, h=234),
    "planter": Region(x=746, y=790, w=112, h=234),
    "barrel": Region(x=883, y=790, w=69, h=234),
    "market_stall": Region(x=977, y=790, w=170, h=234),
    "crate": Region(x=1153, y=790, w=109, h=234),
    "windmill": Region(x=1279, y=790, w=124, h=234),
    "monolith": Region(x=1414, y=790, w=100, h=234),
}

# `tree` 唯一框到「道具素材」標籤方框的道具（方框疊在樹冠左上角，見 `slice_grassland_props`
# 校準時的觀察，其餘道具的裁切區右移過標籤範圍不受影響）——用 exclude rect 蓋掉再去背，
# 手法同 `_KINGDOM_PROP_EXCLUDE_RECTS`。
_GRASSLAND_PROP_EXCLUDE_RECTS: dict = {
    "tree": [Region(x=0, y=0, w=145, h=50)],
}

# 去雜點策略（同 `_KINGDOM_LARGEST_COMPONENT_PROPS`/`_SEA_CITY_LARGEST_COMPONENT_PROPS` 說明）：
# 細桿件（旗桿/路標柱/井頂支架/貨車輪輻/風車軸）用 `keep_largest_component_dilated`
# 防止色距去背把細桿攔腰挖空、誤刪成兩截（`21` §5「細桿件用 keep_largest_component_dilated
# 防去斑咬斷」）；其餘本身就有多個分離部件（樹叢+柵欄+花、花箱花叢、市集攤位+籃子蔬果、
# 立石+base 花叢、箱子+小綠植）的道具用 `remove_small_components` 保留分離部件。
_GRASSLAND_DILATED_PROPS = {"banner", "signpost", "well", "haycart", "windmill"}
_GRASSLAND_NEIGHBOR_DEBRIS_MIN_AREA = 30

# 草原道具列畫布背景色（同 `_KINGDOM_PROP_BG_COLOR`/`_SEA_CITY_PROP_BG_COLOR` 說明，逐像素
# 取樣畫布角落確認）。
_GRASSLAND_PROP_BG_COLOR = (15, 29, 37)


def slice_grassland_props(sheet: Image) -> dict:
    """草原道具切圖：座標表 `GRASSLAND_PROP_REGIONS`，去背用 `chroma_key_flood_color`
    （理由同 `_KINGDOM_PROP_BG_COLOR`），去雜點/去鄰居碎片策略見 `_GRASSLAND_DILATED_PROPS` 說明。"""
    out = {}
    for name, region in GRASSLAND_PROP_REGIONS.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        if name in _GRASSLAND_PROP_EXCLUDE_RECTS:
            cropped = _apply_exclude_rects(cropped, _GRASSLAND_PROP_EXCLUDE_RECTS[name])
        keyed = chroma_key_flood_color(cropped, _GRASSLAND_PROP_BG_COLOR, threshold=16)
        if name in _GRASSLAND_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=_GRASSLAND_NEIGHBOR_DEBRIS_MIN_AREA)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 美術大改版第 2 波（`21_ASSET_OVERHAUL_PLAN.md` §4「其餘地域切圖」）：5 個新地域
# valley / village_2 / village_3 / sky_village / sky_city，皆 1536x1024、與
# grassland.png 完全同款版式（由 Read 逐張目視 + 逐像素亮度/連通元件掃描校準，
# 見 scratchpad 校準紀錄）——背景四層 y 帶與 `GRASSLAND_BG_*`/`GRASSLAND_LABEL_BOX_RECTS`
# 完全一致（同一模板產生，斷點 y 座標六張素材表彼此吻合），故共用同一份層 y 帶常數，
# 只有道具列 x 座標表 + 道具列畫布背景色因每張圖內容不同而各自校準。
# ---------------------------------------------------------------------------

# 六張新地域素材表（含重切的 kingdom）共用同一套背景層 y 帶（`GRASSLAND_BG_*`）與標籤
# 方框座標（`GRASSLAND_LABEL_BOX_RECTS`）——直接沿用，不重複定義。
NEW_REGION_BG_FAR = GRASSLAND_BG_FAR
NEW_REGION_BG_MID = GRASSLAND_BG_MID
NEW_REGION_BG_FORE = GRASSLAND_BG_FORE
NEW_REGION_BG_GROUND = GRASSLAND_BG_GROUND
NEW_REGION_LABEL_BOX_RECTS = GRASSLAND_LABEL_BOX_RECTS
NEW_REGION_MID_TOP_FADE_PX = GRASSLAND_BG_MID_TOP_FADE_PX
NEW_REGION_FORE_TOP_FADE_PX = GRASSLAND_BG_FORE_TOP_FADE_PX

# --- valley（山谷，design/valley.png：高科技/魔法感浮空峽谷——市集推車、玄光膠囊、
# 螢幕看板等道具帶著奇幻科技風，與其餘地域的中古田園風不同，但仍溫暖無威脅，符合
# `20_ASSET_SHEET_SPEC.md` §0 世界觀鐵律）道具列座標（11 個道具：樹／燈柱／發光膠囊／
# 螢幕看板／市集推車／花箱／木箱／霓虹路牌／浮空平台／懸吊木架／骷髏頭螢幕）。
VALLEY_PROP_REGIONS: dict = {
    "tree": Region(x=5, y=790, w=165, h=234),
    "lamppost": Region(x=178, y=790, w=90, h=234),
    "capsule": Region(x=271, y=790, w=145, h=234),
    "screen_panel": Region(x=416, y=790, w=150, h=234),
    "market_stall": Region(x=566, y=790, w=135, h=234),
    "planter": Region(x=701, y=790, w=134, h=234),
    "crate_chest": Region(x=835, y=790, w=147, h=234),
    "signpost_neon": Region(x=982, y=790, w=90, h=234),
    "floating_orb": Region(x=1072, y=790, w=133, h=234),
    "hanging_frame": Region(x=1205, y=790, w=150, h=234),
    "screen_skull": Region(x=1355, y=790, w=181, h=234),
}
_VALLEY_PROP_EXCLUDE_RECTS: dict = {"tree": [Region(x=0, y=0, w=150, h=52)]}
_VALLEY_DILATED_PROPS = {"lamppost", "signpost_neon", "hanging_frame"}
_VALLEY_PROP_BG_COLOR = (14, 27, 40)

# --- village_2（村莊 A，design/village_2.png：田園河谷村落——風車/石橋/市集，中古田園風）
# 道具列座標（11 個道具：樹／路標／燈柱／長椅／市集攤車／木桶／木箱／花箱／水井／
# 花缽立柱／柵欄）。
VILLAGE_2_PROP_REGIONS: dict = {
    "tree": Region(x=2, y=790, w=219, h=234),
    "signpost": Region(x=225, y=790, w=102, h=234),
    "lamppost": Region(x=331, y=790, w=135, h=234),
    "bench": Region(x=466, y=790, w=135, h=234),
    "market_stall": Region(x=606, y=790, w=169, h=234),
    "barrel": Region(x=779, y=790, w=115, h=234),
    "crate": Region(x=904, y=790, w=130, h=234),
    "planter": Region(x=1034, y=790, w=133, h=234),
    "well": Region(x=1174, y=790, w=111, h=234),
    "pedestal_planter": Region(x=1289, y=790, w=101, h=234),
    "fence": Region(x=1396, y=790, w=140, h=234),
}
_VILLAGE_2_PROP_EXCLUDE_RECTS: dict = {"tree": [Region(x=0, y=0, w=150, h=52)]}
_VILLAGE_2_DILATED_PROPS = {"signpost", "lamppost", "well", "pedestal_planter", "fence"}
_VILLAGE_2_PROP_BG_COLOR = (21, 28, 35)

# --- village_3（村莊 B，design/village_3.png：森林樹屋村落）道具列座標（11 個道具：
# 樹／燈柱／路標／長椅／市集攤車（藥水）／木桶／木箱／花箱／蘑菇樹墩燈／繩橋／水晶井）。
VILLAGE_3_PROP_REGIONS: dict = {
    "tree": Region(x=2, y=790, w=193, h=234),
    "lamppost": Region(x=195, y=790, w=125, h=234),
    "signpost": Region(x=320, y=790, w=142, h=234),
    "bench": Region(x=462, y=790, w=130, h=234),
    "market_stall": Region(x=592, y=790, w=190, h=234),
    "barrel": Region(x=782, y=790, w=113, h=234),
    "crate": Region(x=895, y=790, w=135, h=234),
    "planter": Region(x=1030, y=790, w=110, h=234),
    "stump_lantern": Region(x=1140, y=790, w=120, h=234),
    "bridge": Region(x=1260, y=790, w=120, h=234),
    "crystal_well": Region(x=1380, y=790, w=156, h=234),
}
_VILLAGE_3_PROP_EXCLUDE_RECTS: dict = {"tree": [Region(x=0, y=0, w=150, h=52)]}
_VILLAGE_3_DILATED_PROPS = {"lamppost", "signpost", "stump_lantern", "bridge"}
_VILLAGE_3_PROP_BG_COLOR = (15, 23, 32)

# --- sky_village（天空村莊，design/sky_village.png：浮空平台迴廊）道具列座標
# （12 個道具：浮空小樹／石柱／燈柱／路標／花缽／噴泉／木箱／木桶／旗幟燈柱／飛船／
# 水晶柱／欄杆）。
SKY_VILLAGE_PROP_REGIONS: dict = {
    "tree": Region(x=5, y=790, w=155, h=234),
    "pillar": Region(x=160, y=790, w=136, h=234),
    "lamppost": Region(x=330, y=790, w=101, h=234),
    "signpost": Region(x=461, y=790, w=104, h=234),
    "planter": Region(x=565, y=790, w=131, h=234),
    "fountain": Region(x=707, y=790, w=123, h=234),
    "crate": Region(x=850, y=790, w=80, h=234),
    "barrel": Region(x=930, y=790, w=74, h=234),
    "banner_post": Region(x=1021, y=790, w=78, h=234),
    "airship": Region(x=1115, y=790, w=155, h=234),
    "crystal_pillar": Region(x=1270, y=790, w=89, h=234),
    "fence": Region(x=1376, y=790, w=143, h=234),
}
_SKY_VILLAGE_PROP_EXCLUDE_RECTS: dict = {"tree": [Region(x=0, y=0, w=150, h=52)]}
_SKY_VILLAGE_DILATED_PROPS = {"pillar", "lamppost", "signpost", "fountain", "banner_post", "crystal_pillar", "fence"}
_SKY_VILLAGE_PROP_BG_COLOR = (20, 31, 40)

# --- sky_city（天空魔法城，design/sky_city_magic.png：金色魔法水晶城）道具列座標
# （12 個道具：水晶噴泉／石柱／旗幟燈柱／掛燈／花箱／市集攤車／魔法鏡／寶箱／水晶／
# 路標／飛船／魔法拱門）。
SKY_CITY_PROP_REGIONS: dict = {
    "crystal_fountain": Region(x=5, y=790, w=122, h=234),
    "pillar": Region(x=141, y=790, w=112, h=234),
    "banner_post": Region(x=259, y=790, w=94, h=234),
    "lamp": Region(x=353, y=790, w=55, h=234),
    "planter": Region(x=408, y=790, w=105, h=234),
    "market_stall": Region(x=513, y=790, w=192, h=234),
    "mirror": Region(x=725, y=790, w=105, h=234),
    "chest": Region(x=846, y=790, w=141, h=234),
    "crystal": Region(x=1002, y=790, w=100, h=234),
    "signpost": Region(x=1107, y=790, w=75, h=234),
    "airship": Region(x=1187, y=790, w=143, h=234),
    "gate": Region(x=1330, y=790, w=195, h=234),
}
_SKY_CITY_PROP_EXCLUDE_RECTS: dict = {"crystal_fountain": [Region(x=0, y=0, w=150, h=52)]}
_SKY_CITY_DILATED_PROPS = {"pillar", "banner_post", "lamp", "signpost", "gate", "crystal_fountain"}
_SKY_CITY_PROP_BG_COLOR = (10, 23, 38)


def slice_new_region_props(
    sheet: Image, regions: dict, bg_color: tuple, dilated_names: set,
    exclude_rects: dict, min_area: int = 30,
) -> dict:
    """5 個新地域（valley/village_2/village_3/sky_village/sky_city）共用的道具切圖流程：
    與 `slice_grassland_props`/`slice_kingdom_props` 同一套手法（`chroma_key_flood_color` +
    exclude rect 蓋標籤方框 + 依 `dilated_names` 選去雜點策略），只是座標表/背景色/
    細桿件分類逐張各自校準，抽成通用函式避免 5 份幾乎重複的程式碼。
    """
    out = {}
    for name, region in regions.items():
        w = min(region.w, sheet.width - region.x)
        h = min(region.h, sheet.height - region.y)
        cropped = sheet.crop(region.x, region.y, w, h)
        if name in exclude_rects:
            cropped = _apply_exclude_rects(cropped, exclude_rects[name])
        keyed = chroma_key_flood_color(cropped, bg_color, threshold=20)
        if name in dilated_names:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=min_area)
        out[name] = autocrop(keyed)
    return out


def slice_new_region_bg(sheet: Image) -> dict:
    """5 個新地域共用的背景四層切圖流程（層 y 帶/標籤方框與 grassland 共用，見
    `NEW_REGION_BG_*`/`NEW_REGION_LABEL_BOX_RECTS`）。回傳 `{layer_name: Image}`。"""
    layers = (
        ("far", NEW_REGION_BG_FAR, None, "far"),
        ("mid", NEW_REGION_BG_MID, NEW_REGION_MID_TOP_FADE_PX, "mid"),
        ("fore", NEW_REGION_BG_FORE, NEW_REGION_FORE_TOP_FADE_PX, "fore"),
        ("ground", NEW_REGION_BG_GROUND, None, "ground"),
    )
    out = {}
    for name, region, fade_px, label_key in layers:
        img = sheet.crop(region.x, region.y, region.w, region.h)
        if label_key is not None and label_key in NEW_REGION_LABEL_BOX_RECTS:
            if label_key == "ground":
                img = patch_label_box_horizontal(img, NEW_REGION_LABEL_BOX_RECTS[label_key])
            elif label_key == "far":
                img = patch_label_box_sky(img, NEW_REGION_LABEL_BOX_RECTS[label_key])
            else:
                img = patch_label_box(img, NEW_REGION_LABEL_BOX_RECTS[label_key])
        if fade_px:
            img = fade_top_edge(img, fade_px=fade_px)
        if name == "far":
            # far 橫向平鋪的接縫治本，推廣到所有地域（同 `slice_harbor_bg` 手法）：
            # 這裡覆蓋 valley/village_2/village_3/sky_village/sky_city 五個新地域。
            img = make_horizontally_seamless(img, blend_px=64)
        out[name] = img
    return out


# ---------------------------------------------------------------------------
# 美術流程驗證（`20_ASSET_SHEET_SPEC.md` §8A）：`design/harbor_test.png`（1086x1448 直式，
# 5 帶，由 Read 逐帶目視 + 逐像素亮度/連通元件掃描校準，見 scratchpad 校準紀錄）。
# 與其餘 8 地域素材表版式完全不同（直式、5 帶、mid/fore/道具皆洋紅 `#FF00FF` 底，
# 只有 far 帶含天空），座標表/去背流程獨立一套，不與 `NEW_REGION_*` 共用。
# 五帶 y 範圍（逐像素掃描全寬洋紅比例找到的斷點，見校準紀錄）：
#   Far（含天空，不去背）：  y=0..458    （h=459）
#   Mid（洋紅底，去背）：    y=459..736  （h=278）
#   Fore（洋紅底，去背）：   y=737..1043 （h=307，1044..1097 是「Ground」標籤用的洋紅留白，
#                                          不屬於 Fore/Ground 任一帶內容，捨棄不用）
#   Ground（石砌碼頭，不去背，只需 `patch_magenta_columns` 補頂緣缺口）：
#                             y=1098..1243（h=146）
#   Items（洋紅底道具列，去背）：y=1244..1447（h=204）
# ---------------------------------------------------------------------------
HARBOR_BG_FAR = Region(x=0, y=0, w=1086, h=459)
HARBOR_BG_MID = Region(x=0, y=459, w=1086, h=278)
HARBOR_BG_FORE = Region(x=0, y=737, w=1086, h=307)
HARBOR_BG_GROUND = Region(x=0, y=1098, w=1086, h=146)
HARBOR_ITEMS_REGION = Region(x=0, y=1244, w=1086, h=204)

# 各帶左上角標籤黑底方框（Far/Mid/Fore/Items 皆疊在自己帶的內容/洋紅底上；Ground 的標籤
# 落在上面捨棄的洋紅留白裡，不出現在 `HARBOR_BG_GROUND` 裁切範圍內，不需要處理）。方框本身
# 目視校準約 90x40，這裡留餘裕到 110x46（四帶左上角實際內容——Far 雲朵/Mid 城市天際線/
# Fore 路燈/Items 道具——皆從 x≈95 起才開始，餘裕不會裁到任何合法內容）。
HARBOR_LABEL_RECT = Region(x=0, y=0, w=110, h=46)

# 道具列 11 個道具座標（逐像素欄投影分段掃描 + 目視命名校準，見 scratchpad 校準紀錄）：
# 木牌路標／花箱／木桶／盆栽／錨形吊牌路標／藍色旗幟柱／街燈／花缽底座／長椅／市集推車／噴泉。
HARBOR_PROP_REGIONS: dict = {
    "signpost": Region(x=15, y=0, w=86, h=204),
    "planter": Region(x=105, y=0, w=101, h=204),
    "barrel": Region(x=207, y=0, w=86, h=204),
    "plant": Region(x=302, y=0, w=85, h=204),
    "anchor_sign": Region(x=393, y=0, w=100, h=204),
    "banner": Region(x=504, y=0, w=78, h=204),
    "lamp": Region(x=585, y=0, w=69, h=204),
    "flower_urn": Region(x=658, y=0, w=75, h=204),
    "bench": Region(x=734, y=0, w=118, h=204),
    "market_cart": Region(x=852, y=0, w=113, h=204),
    "fountain": Region(x=972, y=0, w=102, h=204),
}
_HARBOR_DILATED_PROPS = {"signpost", "anchor_sign", "banner", "lamp", "flower_urn"}


def slice_harbor_bg(sheet: Image) -> dict:
    """海港五帶背景切圖（`20` §8A 新流程驗證）：far 完整含天空、不去背，當獨立 backdrop；
    mid/fore 洋紅底去背成透明（`chroma_key_flood_color` + `remove_magenta_spill` 清封閉殘留 +
    `strip_magenta_bleed_rows` 清掉裁切邊界貼著的分隔線洋紅殘影，見三者 docstring），疊在
    far 之前形成真多層視差；ground 不去背，只補頂緣洋紅缺口（`patch_magenta_columns`，見其
    docstring 動機）。回傳 `{layer_name: Image}`。
    """
    far = patch_label_box_sky(sheet.crop(HARBOR_BG_FAR.x, HARBOR_BG_FAR.y, HARBOR_BG_FAR.w, HARBOR_BG_FAR.h), HARBOR_LABEL_RECT)
    # 遠景 backdrop 是唯一會被無限橫向平鋪的 layered 底圖（`18`/`20` §8A）：左右緣羽化交融，
    # 讓生成端即使沒有完美對齊也能真無縫 loop、不必鏡射（見 `make_horizontally_seamless` docstring）。
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(HARBOR_BG_MID.x, HARBOR_BG_MID.y, HARBOR_BG_MID.w, HARBOR_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, HARBOR_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(HARBOR_BG_FORE.x, HARBOR_BG_FORE.y, HARBOR_BG_FORE.w, HARBOR_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, HARBOR_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    ground_raw = sheet.crop(HARBOR_BG_GROUND.x, HARBOR_BG_GROUND.y, HARBOR_BG_GROUND.w, HARBOR_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_harbor_props(sheet: Image) -> dict:
    """海港道具列切圖（`20` §8A）：`chroma_key_flood_color` 洋紅去背 + `remove_magenta_spill`
    清掉封閉洋紅殘留（同 `slice_harbor_bg` 手法）+ 依 `_HARBOR_DILATED_PROPS` 選細桿件保護
    （`keep_largest_component_dilated`，防止燈柱/路標/旗桿因去背斷點被誤判成兩段）。
    """
    items = sheet.crop(HARBOR_ITEMS_REGION.x, HARBOR_ITEMS_REGION.y, HARBOR_ITEMS_REGION.w, HARBOR_ITEMS_REGION.h)
    items = patch_label_box(items, HARBOR_LABEL_RECT)
    out = {}
    for name, region in HARBOR_PROP_REGIONS.items():
        w = min(region.w, items.width - region.x)
        h = min(region.h, items.height - region.y)
        cropped = items.crop(region.x, region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _HARBOR_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 溫泉山村（接手任務：harbor 管線推廣到第二個 layered 地域，`design/hotspring_village.png`，
# 1536x1024，由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄）。五帶 y 範圍：
#   Far（含天空+雪山+遠方城堡，不去背）：      y=0..279   （h=280）
#   Mid（洋紅底村莊聚落，去背）：              y=280..494 （h=215）
#   Fore（洋紅底溫泉旅館/拱橋/招牌，去背）：    y=495..743 （h=249）
#   Ground（石磚步道，不去背，只補頂緣洋紅缺口）：y=814..858 （h=45，x=12..1523，
#                                          左右各裁掉 12px——逐像素掃描發現 mid/fore/ground
#                                          三帶在畫布最左/右緣各有約 10px 完全沒有內容、
#                                          整欄純洋紅到底（不是「頂緣殘留」而是畫布留白邊界），
#                                          `patch_magenta_columns` 逐欄用「同欄最近的非洋紅
#                                          像素」補洞，若整欄從上到下都是洋紅就無法自癒、
#                                          會在地面平台留下貫穿全高的洋紅色縱線；y 起點同理
#                                          需晚於「地面平台」標籤方框 + 石磚頂緣尚未長滿雜草
#                                          的過渡帶（y=744..813 多數欄仍大半是洋紅，逐欄補洞
#                                          會把附近抗鋸齒的淡粉像素往上拉成一整條色塊），
#                                          兩者都往內收到「幾乎每一欄在裁切範圍內都已有真實
#                                          內容」的高度，逐像素洋紅比例掃描 + 目視反覆試裁
#                                          校準出 x=12..1523／y=814..858 為零殘留的最小安全框）。
#   Props（洋紅底道具列，去背）：              y=860..1023（h=164）
# 與 harbor 差異只在版式（橫式 4 層+底部道具列，同其餘 8 地域素材表版式，而非 harbor 那張
# 特例的直式 5 帶獨立畫布）；去背手法（`chroma_key_flood_color`+`remove_magenta_spill`+
# `strip_magenta_bleed_rows`+`defringe_magenta_edges`／ground 用 `patch_magenta_columns`）
# 完全沿用 harbor 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
HOTSPRING_VILLAGE_BG_FAR = Region(x=0, y=0, w=1536, h=280)
HOTSPRING_VILLAGE_BG_MID = Region(x=0, y=280, w=1536, h=215)
HOTSPRING_VILLAGE_BG_FORE = Region(x=0, y=495, w=1536, h=249)
HOTSPRING_VILLAGE_BG_GROUND = Region(x=12, y=814, w=1512, h=45)
HOTSPRING_VILLAGE_PROPS_REGION = Region(x=0, y=860, w=1536, h=164)

# far/mid/fore/ground 四層左上角標籤黑底方框（逐像素掃描校準：方框約 x=0..125、y=5..47，
# 四層版式一致，沿用同一份座標，留餘裕不裁到內容——四層左上角實際內容皆從 x≈135 起才開始）。
HOTSPRING_VILLAGE_LABEL_RECT = Region(x=0, y=0, w=130, h=48)
# 道具列標籤方框位置與其餘四層不同（貼在道具列較下方，逐像素掃描校準：約 x=0..135、
# y=10..50），獨立一份座標。
HOTSPRING_VILLAGE_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=44)

# 道具列 12 個道具座標（逐像素欄投影分段掃描 + 目視命名校準，見 scratchpad 校準紀錄，順序
# 由左到右）：櫻花樹／石燈籠／木牌路標／木箱／木桶／花箱／溫泉旗幡／石燈籠（矮）／
# 溫泉岩石噴泉／長椅／市集攤棚／柵欄。範圍刻意留餘裕，去背 + autocrop 後收斂到精確
# bounding box；相鄰槽位的餘裕重疊落在洋紅留白（實際內容間距 ≥20px），不會誤裁鄰居。
HOTSPRING_VILLAGE_PROP_REGIONS: dict = {
    "cherry_tree": Region(x=115, y=0, w=155, h=164),
    "stone_lantern": Region(x=260, y=0, w=75, h=164),
    "signpost": Region(x=325, y=0, w=105, h=164),
    "crate": Region(x=430, y=0, w=105, h=164),
    "barrel": Region(x=532, y=0, w=105, h=164),
    "planter": Region(x=635, y=0, w=120, h=164),
    "onsen_banner": Region(x=760, y=0, w=100, h=164),
    "lantern_stone": Region(x=872, y=0, w=90, h=164),
    "hotspring_rock": Region(x=962, y=0, w=135, h=164),
    "bench": Region(x=1095, y=0, w=125, h=164),
    "market_stall": Region(x=1220, y=0, w=180, h=164),
    "fence": Region(x=1390, y=0, w=146, h=164),
}
# 細桿件/薄邊框（路標柱、旗幡桿、石燈籠柱身、柵欄橫木）用 `keep_largest_component_dilated`
# 防斷（同 `_HARBOR_DILATED_PROPS` 動機）；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件（例如市集攤棚的棚頂+攤台是兩個分離區塊）。
_HOTSPRING_VILLAGE_DILATED_PROPS = {"signpost", "onsen_banner", "stone_lantern", "lantern_stone", "fence"}


def slice_hotspring_village_bg(sheet: Image) -> dict:
    """溫泉山村背景切圖：手法與 `slice_harbor_bg` 完全一致（far 不去背當 backdrop + 水平無縫
    羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(HOTSPRING_VILLAGE_BG_FAR.x, HOTSPRING_VILLAGE_BG_FAR.y, HOTSPRING_VILLAGE_BG_FAR.w, HOTSPRING_VILLAGE_BG_FAR.h),
        HOTSPRING_VILLAGE_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(HOTSPRING_VILLAGE_BG_MID.x, HOTSPRING_VILLAGE_BG_MID.y, HOTSPRING_VILLAGE_BG_MID.w, HOTSPRING_VILLAGE_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, HOTSPRING_VILLAGE_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(HOTSPRING_VILLAGE_BG_FORE.x, HOTSPRING_VILLAGE_BG_FORE.y, HOTSPRING_VILLAGE_BG_FORE.w, HOTSPRING_VILLAGE_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, HOTSPRING_VILLAGE_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `HOTSPRING_VILLAGE_BG_GROUND` 校準說明）已經避開「地面平台」標籤方框
    # 所在的 y 範圍，不需要（也不能）再套 `patch_label_box`——標籤方框已經不在這個裁切區內，
    # 若誤套會把裁切框左上角的真實石磚內容覆蓋成重複色塊。
    ground_raw = sheet.crop(HOTSPRING_VILLAGE_BG_GROUND.x, HOTSPRING_VILLAGE_BG_GROUND.y, HOTSPRING_VILLAGE_BG_GROUND.w, HOTSPRING_VILLAGE_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_hotspring_village_props(sheet: Image) -> dict:
    """溫泉山村道具列切圖：手法與 `slice_harbor_props` 完全一致（先蓋掉整條道具列的標籤方框，
    再逐一裁切去背 + 依 `_HOTSPRING_VILLAGE_DILATED_PROPS` 選細桿件保護）。
    """
    region = HOTSPRING_VILLAGE_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, HOTSPRING_VILLAGE_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in HOTSPRING_VILLAGE_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _HOTSPRING_VILLAGE_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 仙俠山宮（接手任務：hotspring 管線推廣到第三個 layered 地域，`design/mountain_palace.png`，
# 1536x1024，由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄）。五帶 y 範圍：
#   Far（天空+雲海+飄浮宮闕/山峰，不去背）：            y=0..275   （h=276）
#   Mid（洋紅底四座山峰宮闕聚落，去背）：                y=276..495 （h=220）
#   Fore（洋紅底牌坊拱門/仙鶴噴泉水晶座/涼亭，去背）：    y=496..729 （h=234；尾端切在
#                                          內容實際結束處，不可再往下延伸到 y=730..787——
#                                          那段除了純洋紅過渡留白外，還疊了「地面平台」
#                                          標籤黑底方框，該方框不是洋紅色、去背後不會被
#                                          清除，若切進來會在 Fore 圖層留下文字方框殘影）。
#   Ground（石磚步道，不去背，只補頂緣洋紅缺口）：        y=788..847 （h=60，x=12..1523，
#                                          左右各裁掉 12px——逐像素掃描發現 mid/fore/ground
#                                          三帶在畫布最左/右緣各有一小段完全洋紅到底的留白欄，
#                                          與 hotspring 同款問題，用同一組 12px inset 校準；
#                                          「地面平台」標籤方框本身落在 y=745..775 的洋紅
#                                          過渡帶內、不在 y=788 起的真實石磚範圍內，因此
#                                          y 起點只需晚於過渡帶、不需要另外 patch 標籤方框，
#                                          與 hotspring 做法一致）。
#   Props（洋紅底道具列，去背）：                        y=850..1023（h=174）
# 去背手法（`chroma_key_flood_color`+`remove_magenta_spill`+`strip_magenta_bleed_rows`+
# `defringe_magenta_edges`／ground 用 `patch_magenta_columns`）完全沿用 hotspring 驗證過的
# 管線，不發明新做法。
# ---------------------------------------------------------------------------
MOUNTAIN_PALACE_BG_FAR = Region(x=0, y=0, w=1536, h=276)
MOUNTAIN_PALACE_BG_MID = Region(x=0, y=276, w=1536, h=220)
MOUNTAIN_PALACE_BG_FORE = Region(x=0, y=496, w=1536, h=234)
MOUNTAIN_PALACE_BG_GROUND = Region(x=12, y=788, w=1512, h=60)
MOUNTAIN_PALACE_PROPS_REGION = Region(x=0, y=850, w=1536, h=174)

# far/mid/fore/ground 四層左上角標籤黑底方框：版式與 hotspring 一致，沿用同一組座標
# （四層左上角實際內容皆從 x≈130 起才開始）。
MOUNTAIN_PALACE_LABEL_RECT = Region(x=0, y=0, w=130, h=48)
# 道具列標籤方框位置與其餘四層不同（貼在道具列較下方），獨立一份座標，沿用 hotspring 校準值。
MOUNTAIN_PALACE_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=44)

# 道具列 11 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：仙鶴石像／石燈籠／仙字幡旗燈／寶塔石燈籠／盆栽奇石／
# 漂浮水晶／香爐／石拱橋／瀑布奇石／石碑／山門小屋。範圍刻意留餘裕，去背 + autocrop
# 後收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
MOUNTAIN_PALACE_PROP_REGIONS: dict = {
    "crane_statue": Region(x=115, y=0, w=104, h=174),
    "stone_lantern": Region(x=219, y=0, w=97, h=174),
    "immortal_banner": Region(x=316, y=0, w=92, h=174),
    "pagoda_lantern": Region(x=408, y=0, w=90, h=174),
    "bonsai_rock": Region(x=498, y=0, w=147, h=174),
    "crystal": Region(x=645, y=0, w=124, h=174),
    "incense_burner": Region(x=769, y=0, w=120, h=174),
    "stone_bridge": Region(x=889, y=0, w=211, h=174),
    "waterfall_rock": Region(x=1100, y=0, w=144, h=174),
    "stone_stele": Region(x=1244, y=0, w=116, h=174),
    "shrine_gate": Region(x=1360, y=0, w=176, h=174),
}
# 細桿件/薄邊框（仙鶴細腳、幡旗燈桿、燈籠柱身、拱橋欄杆）用 `keep_largest_component_dilated`
# 防斷（同 `_HOTSPRING_VILLAGE_DILATED_PROPS` 動機）；其餘本身較粗實的道具用
# `remove_small_components` 保留分離部件。
_MOUNTAIN_PALACE_DILATED_PROPS = {"crane_statue", "stone_lantern", "immortal_banner", "pagoda_lantern", "stone_bridge"}


def slice_mountain_palace_bg(sheet: Image) -> dict:
    """仙俠山宮背景切圖：手法與 `slice_hotspring_village_bg` 完全一致（far 不去背當 backdrop +
    水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(MOUNTAIN_PALACE_BG_FAR.x, MOUNTAIN_PALACE_BG_FAR.y, MOUNTAIN_PALACE_BG_FAR.w, MOUNTAIN_PALACE_BG_FAR.h),
        MOUNTAIN_PALACE_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(MOUNTAIN_PALACE_BG_MID.x, MOUNTAIN_PALACE_BG_MID.y, MOUNTAIN_PALACE_BG_MID.w, MOUNTAIN_PALACE_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, MOUNTAIN_PALACE_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(MOUNTAIN_PALACE_BG_FORE.x, MOUNTAIN_PALACE_BG_FORE.y, MOUNTAIN_PALACE_BG_FORE.w, MOUNTAIN_PALACE_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, MOUNTAIN_PALACE_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `MOUNTAIN_PALACE_BG_GROUND` 校準說明）已經避開「地面平台」標籤方框
    # 所在的 y 範圍，不需要（也不能）再套 `patch_label_box`——標籤方框已經不在這個裁切區內，
    # 若誤套會把裁切框左上角的真實石磚內容覆蓋成重複色塊。
    ground_raw = sheet.crop(MOUNTAIN_PALACE_BG_GROUND.x, MOUNTAIN_PALACE_BG_GROUND.y, MOUNTAIN_PALACE_BG_GROUND.w, MOUNTAIN_PALACE_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_mountain_palace_props(sheet: Image) -> dict:
    """仙俠山宮道具列切圖：手法與 `slice_hotspring_village_props` 完全一致（先蓋掉整條道具列的
    標籤方框，再逐一裁切去背 + 依 `_MOUNTAIN_PALACE_DILATED_PROPS` 選細桿件保護）。
    """
    region = MOUNTAIN_PALACE_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, MOUNTAIN_PALACE_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in MOUNTAIN_PALACE_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _MOUNTAIN_PALACE_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 雪山王國（接手任務：hotspring/mountain_palace 管線推廣到第四個 layered 地域，
# `design/snow_mountain.png`，1536x1024，版式與 hotspring_village/mountain_palace 完全相同——
# 遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。五帶 y 範圍：
#   Far（雪山群峰+石造拱門城牆天際線，不去背）：          y=0..273   （h=274）
#   Mid（洋紅底雪山城牆聚落/吊橋/塔樓，去背）：            y=274..493 （h=220）
#   Fore（洋紅底石拱門/營帳/絞架/符文石碑/雪松，去背）：    y=494..733 （h=240；尾端切在
#                                          內容實際結束處，不可再往下延伸——那段除了純洋紅
#                                          過渡留白外還疊了「地面平台」標籤黑底方框）。
#   Ground（石磚步道，不去背，只補頂緣洋紅缺口）：          y=788..847 （h=60，x=12..1523，
#                                          左右各裁掉 12px，與 hotspring/mountain_palace 同款
#                                          問題，用同一組 12px inset 校準）。
#   Props（洋紅底道具列，去背）：                          y=850..1023（h=174）
# 去背手法完全沿用 hotspring/mountain_palace 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
SNOW_MOUNTAIN_BG_FAR = Region(x=0, y=0, w=1536, h=274)
SNOW_MOUNTAIN_BG_MID = Region(x=0, y=274, w=1536, h=220)
SNOW_MOUNTAIN_BG_FORE = Region(x=0, y=494, w=1536, h=240)
SNOW_MOUNTAIN_BG_GROUND = Region(x=12, y=788, w=1512, h=60)
SNOW_MOUNTAIN_PROPS_REGION = Region(x=0, y=850, w=1536, h=174)

SNOW_MOUNTAIN_LABEL_RECT = Region(x=0, y=0, w=130, h=48)
SNOW_MOUNTAIN_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=44)

# 道具列 12 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：雪松／藍色紋章旗／指標路牌／火把石柱／木箱／木桶／
# 尖刺木柵欄／雪堆石堆／交叉木柵欄／燈柱／符文石碑／告示板。範圍刻意留餘裕，去背 +
# autocrop 後收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
SNOW_MOUNTAIN_PROP_REGIONS: dict = {
    "snow_pine": Region(x=92, y=0, w=117, h=174),
    "heraldic_banner": Region(x=209, y=0, w=73, h=174),
    "signpost": Region(x=296, y=0, w=95, h=174),
    "torch_pillar": Region(x=395, y=0, w=96, h=174),
    "crate": Region(x=496, y=0, w=125, h=174),
    "barrel": Region(x=626, y=0, w=103, h=174),
    "wooden_barricade": Region(x=740, y=0, w=131, h=174),
    "snow_cairn": Region(x=880, y=0, w=93, h=174),
    "wooden_fence": Region(x=975, y=0, w=161, h=174),
    "lamp_post": Region(x=1136, y=0, w=92, h=174),
    "rune_stele": Region(x=1235, y=0, w=101, h=174),
    "notice_board": Region(x=1349, y=0, w=137, h=174),
}
# 細桿件/薄邊框（紋章旗桿、路牌柱身、火把柱、柵欄交叉桿、燈柱）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件。
_SNOW_MOUNTAIN_DILATED_PROPS = {"heraldic_banner", "signpost", "torch_pillar", "wooden_barricade", "wooden_fence", "lamp_post"}


def slice_snow_mountain_bg(sheet: Image) -> dict:
    """雪山王國背景切圖：手法與 `slice_mountain_palace_bg` 完全一致（far 不去背當 backdrop +
    水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(SNOW_MOUNTAIN_BG_FAR.x, SNOW_MOUNTAIN_BG_FAR.y, SNOW_MOUNTAIN_BG_FAR.w, SNOW_MOUNTAIN_BG_FAR.h),
        SNOW_MOUNTAIN_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(SNOW_MOUNTAIN_BG_MID.x, SNOW_MOUNTAIN_BG_MID.y, SNOW_MOUNTAIN_BG_MID.w, SNOW_MOUNTAIN_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, SNOW_MOUNTAIN_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(SNOW_MOUNTAIN_BG_FORE.x, SNOW_MOUNTAIN_BG_FORE.y, SNOW_MOUNTAIN_BG_FORE.w, SNOW_MOUNTAIN_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, SNOW_MOUNTAIN_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `SNOW_MOUNTAIN_BG_GROUND` 校準說明）已經避開「地面平台」標籤方框
    # 所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(SNOW_MOUNTAIN_BG_GROUND.x, SNOW_MOUNTAIN_BG_GROUND.y, SNOW_MOUNTAIN_BG_GROUND.w, SNOW_MOUNTAIN_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_snow_mountain_props(sheet: Image) -> dict:
    """雪山王國道具列切圖：手法與 `slice_mountain_palace_props` 完全一致（先蓋掉整條道具列的
    標籤方框，再逐一裁切去背 + 依 `_SNOW_MOUNTAIN_DILATED_PROPS` 選細桿件保護）。
    """
    region = SNOW_MOUNTAIN_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, SNOW_MOUNTAIN_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in SNOW_MOUNTAIN_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _SNOW_MOUNTAIN_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 浮空魔法之城（接手任務：hotspring/mountain_palace 管線推廣到第五個 layered 地域，
# `design/magic_city.png`，1536x1024，版式與 hotspring_village/mountain_palace 完全相同——
# 遠景含天空不去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。五帶 y 範圍：
#   Far（漂浮尖塔穹頂天際線+雲海，不去背）：              y=0..277   （h=278）
#   Mid（洋紅底漂浮城邦聚落，去背）：                      y=278..491 （h=214）
#   Fore（洋紅底水晶噴泉/涼亭/符文法陣/花壇，去背）：       y=492..729 （h=238；尾端切在
#                                          內容實際結束處，不可再往下延伸——那段除了純洋紅
#                                          過渡留白外還疊了「地面平台」標籤黑底方框）。
#   Ground（石磚步道，不去背，只補頂緣洋紅缺口）：          y=777..846 （h=70，x=12..1523，
#                                          左右各裁掉 12px，與 hotspring/mountain_palace 同款
#                                          問題，用同一組 12px inset 校準）。
#   Props（洋紅底道具列，去背）：                          y=850..1023（h=174）
# 去背手法完全沿用 hotspring/mountain_palace 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
MAGIC_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=278)
MAGIC_CITY_BG_MID = Region(x=0, y=278, w=1536, h=214)
MAGIC_CITY_BG_FORE = Region(x=0, y=492, w=1536, h=238)
MAGIC_CITY_BG_GROUND = Region(x=12, y=777, w=1512, h=70)
MAGIC_CITY_PROPS_REGION = Region(x=0, y=850, w=1536, h=174)

MAGIC_CITY_LABEL_RECT = Region(x=0, y=0, w=130, h=48)
MAGIC_CITY_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=44)

# 道具列 11 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：水晶噴泉座／水晶燈柱／符文紋章旗／花卉水甕／木箱／木桶／
# 藍白遮陽市集攤／水晶柱座／望遠鏡／符文法輪／告示板。範圍刻意留餘裕，去背 + autocrop
# 後收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
MAGIC_CITY_PROP_REGIONS: dict = {
    "crystal_shard": Region(x=23, y=0, w=124, h=174),
    "crystal_lamp": Region(x=171, y=0, w=78, h=174),
    "arcane_banner": Region(x=275, y=0, w=82, h=174),
    "flower_urn": Region(x=378, y=0, w=123, h=174),
    "crate": Region(x=516, y=0, w=123, h=174),
    "barrel": Region(x=663, y=0, w=96, h=174),
    "market_stall": Region(x=775, y=0, w=200, h=174),
    "crystal_pillar": Region(x=980, y=0, w=107, h=174),
    "telescope": Region(x=1090, y=0, w=123, h=174),
    "arcane_wheel": Region(x=1222, y=0, w=118, h=174),
    "notice_board": Region(x=1360, y=0, w=147, h=174),
}
# 細桿件/薄邊框（水晶燈柱身、紋章旗桿、望遠鏡支架、法輪細輻條、水晶柱座）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件。
_MAGIC_CITY_DILATED_PROPS = {"crystal_lamp", "arcane_banner", "telescope", "arcane_wheel", "crystal_pillar"}


def slice_magic_city_bg(sheet: Image) -> dict:
    """浮空魔法之城背景切圖：手法與 `slice_mountain_palace_bg` 完全一致（far 不去背當 backdrop +
    水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(MAGIC_CITY_BG_FAR.x, MAGIC_CITY_BG_FAR.y, MAGIC_CITY_BG_FAR.w, MAGIC_CITY_BG_FAR.h),
        MAGIC_CITY_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(MAGIC_CITY_BG_MID.x, MAGIC_CITY_BG_MID.y, MAGIC_CITY_BG_MID.w, MAGIC_CITY_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, MAGIC_CITY_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(MAGIC_CITY_BG_FORE.x, MAGIC_CITY_BG_FORE.y, MAGIC_CITY_BG_FORE.w, MAGIC_CITY_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, MAGIC_CITY_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `MAGIC_CITY_BG_GROUND` 校準說明）已經避開「地面平台」標籤方框
    # 所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(MAGIC_CITY_BG_GROUND.x, MAGIC_CITY_BG_GROUND.y, MAGIC_CITY_BG_GROUND.w, MAGIC_CITY_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_magic_city_props(sheet: Image) -> dict:
    """浮空魔法之城道具列切圖：手法與 `slice_mountain_palace_props` 完全一致（先蓋掉整條道具列的
    標籤方框，再逐一裁切去背 + 依 `_MAGIC_CITY_DILATED_PROPS` 選細桿件保護）。
    """
    region = MAGIC_CITY_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, MAGIC_CITY_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in MAGIC_CITY_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _MAGIC_CITY_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 聖光之城（接手任務：magic_city 管線推廣到第六個 layered 地域，`design/holy_city.png`，
# 1536x1024，版式與 magic_city 完全相同——遠景含天空不去背、中景/前景/道具皆洋紅
# `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。五帶 y 範圍：
#   Far（聖光雲海+漂浮聖城天際線+光柱，不去背）：           y=0..274   （h=275）
#   Mid（洋紅底聖堂/鐘塔聚落，去背）：                      y=275..494 （h=220）
#   Fore（洋紅底鐘塔拱門/主教堂/天使雕像/紀念碑噴泉，去背）： y=495..730 （h=236）
#   Ground（石磚步道+十字紋章鑲嵌，不去背，只補頂緣洋紅缺口）：y=790..851 （h=62，
#                                          x=12..1523，左右各裁掉 12px，同
#                                          magic_city 12px inset 校準；平台為透視梯形，
#                                          頂緣兩側有較寬洋紅殘留，交給 `patch_magenta_columns`
#                                          逐欄向下/向上找最近非洋紅像素填補）。
#   Props（洋紅底道具列，去背）：                          y=852..1023（h=172）
# 去背手法完全沿用 magic_city 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
HOLY_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=275)
HOLY_CITY_BG_MID = Region(x=0, y=275, w=1536, h=220)
HOLY_CITY_BG_FORE = Region(x=0, y=495, w=1536, h=236)
HOLY_CITY_BG_GROUND = Region(x=12, y=790, w=1512, h=62)
HOLY_CITY_PROPS_REGION = Region(x=0, y=852, w=1536, h=172)

HOLY_CITY_LABEL_RECT = Region(x=0, y=0, w=112, h=44)
HOLY_CITY_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=44)

# 道具列 12 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：路燈／十字紋章旗／天使雕像／柏樹／花卉水甕／木箱／木桶／
# 花圃／石長椅／噴泉／燭台／彩繪玫瑰窗。範圍刻意留餘裕，去背 + autocrop 後收斂到精確
# bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
HOLY_CITY_PROP_REGIONS: dict = {
    "street_lamp": Region(x=90, y=0, w=120, h=172),
    "cross_banner": Region(x=210, y=0, w=79, h=172),
    "angel_statue": Region(x=289, y=0, w=102, h=172),
    "cypress": Region(x=391, y=0, w=84, h=172),
    "flower_urn": Region(x=475, y=0, w=124, h=172),
    "crate": Region(x=599, y=0, w=147, h=172),
    "barrel": Region(x=746, y=0, w=100, h=172),
    "flower_box": Region(x=846, y=0, w=160, h=172),
    "stone_bench": Region(x=1006, y=0, w=161, h=172),
    "fountain": Region(x=1167, y=0, w=142, h=172),
    "candelabra": Region(x=1309, y=0, w=80, h=172),
    "stained_window": Region(x=1389, y=0, w=147, h=172),
}
# 細桿件/薄邊框（路燈燈柱、紋章旗桿、燭台細枝）用 `keep_largest_component_dilated`
# 防斷；其餘本身較粗實的道具用 `remove_small_components` 保留分離部件。
_HOLY_CITY_DILATED_PROPS = {"street_lamp", "cross_banner", "candelabra"}


def slice_holy_city_bg(sheet: Image) -> dict:
    """聖光之城背景切圖：手法與 `slice_magic_city_bg` 完全一致（far 不去背當 backdrop +
    水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(HOLY_CITY_BG_FAR.x, HOLY_CITY_BG_FAR.y, HOLY_CITY_BG_FAR.w, HOLY_CITY_BG_FAR.h),
        HOLY_CITY_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(HOLY_CITY_BG_MID.x, HOLY_CITY_BG_MID.y, HOLY_CITY_BG_MID.w, HOLY_CITY_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, HOLY_CITY_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(HOLY_CITY_BG_FORE.x, HOLY_CITY_BG_FORE.y, HOLY_CITY_BG_FORE.w, HOLY_CITY_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, HOLY_CITY_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `HOLY_CITY_BG_GROUND` 校準說明）已經避開「地面平台」標籤方框
    # 所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(HOLY_CITY_BG_GROUND.x, HOLY_CITY_BG_GROUND.y, HOLY_CITY_BG_GROUND.w, HOLY_CITY_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_holy_city_props(sheet: Image) -> dict:
    """聖光之城道具列切圖：手法與 `slice_magic_city_props` 完全一致（先蓋掉整條道具列的
    標籤方框，再逐一裁切去背 + 依 `_HOLY_CITY_DILATED_PROPS` 選細桿件保護）。
    """
    region = HOLY_CITY_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, HOLY_CITY_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in HOLY_CITY_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _HOLY_CITY_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 蒸氣龐克飛船城（接手任務：holy_city 管線推廣到第七個 layered 地域，
# `design/steampunk_city.png`，1536x1024，版式與 holy_city 完全相同——遠景含天空不去背、
# 中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。五帶 y 範圍：
#   Far（暮色天際+飛船剪影，不去背）：                       y=0..271   （h=272）
#   Mid（洋紅底鐘塔/煙囪聚落，去背）：                       y=272..494 （h=223）
#   Fore（洋紅底黃銅飛船塢/齒輪高塔/蒸汽管線，去背）：        y=495..785 （h=291）
#   Ground（鉚接鋼板步道，不去背，只補頂緣洋紅缺口）：        y=790..851 （h=62，
#                                          x=12..1523，左右各裁掉 12px，同
#                                          holy_city 12px inset 校準；平台頂緣兩側有
#                                          較寬洋紅殘留，交給 `patch_magenta_columns`
#                                          逐欄向下/向上找最近非洋紅像素填補）。
#   Props（洋紅底道具列，去背）：                           y=852..1023（h=172）
# 去背手法完全沿用 holy_city 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
STEAMPUNK_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=272)
STEAMPUNK_CITY_BG_MID = Region(x=0, y=272, w=1536, h=223)
STEAMPUNK_CITY_BG_FORE = Region(x=0, y=495, w=1536, h=291)
STEAMPUNK_CITY_BG_GROUND = Region(x=12, y=790, w=1512, h=62)
STEAMPUNK_CITY_PROPS_REGION = Region(x=0, y=852, w=1536, h=172)

STEAMPUNK_CITY_LABEL_RECT = Region(x=0, y=0, w=120, h=52)
STEAMPUNK_CITY_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=48)

# 道具列 12 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：瓦斯燈／指路牌／木箱／木桶／齒輪引擎／發光管／蒸汽火車頭／
# 黃銅儀表台／十字紋章旗／特斯拉燈柱／黃銅望遠鏡／公告板。範圍以相鄰道具中點分界，留
# 餘裕，去背 + autocrop 後收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，
# 不會誤裁鄰居。
STEAMPUNK_CITY_PROP_REGIONS: dict = {
    "gas_lamp": Region(x=0, y=0, w=219, h=172),
    "signpost": Region(x=219, y=0, w=114, h=172),
    "crate": Region(x=333, y=0, w=129, h=172),
    "barrel": Region(x=462, y=0, w=108, h=172),
    "gear_engine": Region(x=570, y=0, w=148, h=172),
    "glow_tube": Region(x=718, y=0, w=120, h=172),
    "steam_engine": Region(x=838, y=0, w=146, h=172),
    "brass_gauge": Region(x=984, y=0, w=125, h=172),
    "cross_banner": Region(x=1109, y=0, w=87, h=172),
    "tesla_lamp": Region(x=1196, y=0, w=77, h=172),
    "brass_telescope": Region(x=1273, y=0, w=117, h=172),
    "notice_board": Region(x=1390, y=0, w=146, h=172),
}
# 細桿件/薄邊框（瓦斯燈柱、指路牌柱、紋章旗桿、特斯拉燈柱）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用
# `remove_small_components` 保留分離部件。
_STEAMPUNK_CITY_DILATED_PROPS = {"gas_lamp", "signpost", "cross_banner", "tesla_lamp"}


def slice_steampunk_city_bg(sheet: Image) -> dict:
    """蒸氣龐克飛船城背景切圖：手法與 `slice_holy_city_bg` 完全一致（far 不去背當
    backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，
    只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(STEAMPUNK_CITY_BG_FAR.x, STEAMPUNK_CITY_BG_FAR.y, STEAMPUNK_CITY_BG_FAR.w, STEAMPUNK_CITY_BG_FAR.h),
        STEAMPUNK_CITY_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(STEAMPUNK_CITY_BG_MID.x, STEAMPUNK_CITY_BG_MID.y, STEAMPUNK_CITY_BG_MID.w, STEAMPUNK_CITY_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, STEAMPUNK_CITY_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(STEAMPUNK_CITY_BG_FORE.x, STEAMPUNK_CITY_BG_FORE.y, STEAMPUNK_CITY_BG_FORE.w, STEAMPUNK_CITY_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, STEAMPUNK_CITY_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `STEAMPUNK_CITY_BG_GROUND` 校準說明）已經避開「地面平台」標籤
    # 方框所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(STEAMPUNK_CITY_BG_GROUND.x, STEAMPUNK_CITY_BG_GROUND.y, STEAMPUNK_CITY_BG_GROUND.w, STEAMPUNK_CITY_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_steampunk_city_props(sheet: Image) -> dict:
    """蒸氣龐克飛船城道具列切圖：手法與 `slice_holy_city_props` 完全一致（先蓋掉整條
    道具列的標籤方框，再逐一裁切去背 + 依 `_STEAMPUNK_CITY_DILATED_PROPS` 選細桿件保護）。
    """
    region = STEAMPUNK_CITY_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, STEAMPUNK_CITY_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in STEAMPUNK_CITY_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _STEAMPUNK_CITY_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 賽博龐克霓虹夜城（接手任務：steampunk_city 管線推廣到第八個 layered 地域，
# `design/future_city.png`，1536x1024，版式與 steampunk_city 完全相同——遠景含天空不
# 去背、中景/前景/道具皆洋紅 `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準（見 scratchpad 校準紀錄），五帶 y 範圍與
# steampunk_city 完全相同的網格（同一張底稿模板產生，邊界落在同樣的整條洋紅分隔帶內）：
#   Far（霓虹夜空+懸浮載具剪影，不去背）：                     y=0..271   （h=272）
#   Mid（洋紅底懸浮平台聚落，去背）：                          y=272..494 （h=223）
#   Fore（洋紅底咖啡廳/大門招牌/路燈/水晶/霓虹樹，去背）：      y=495..785 （h=291）
#   Ground（金屬拼接步道，不去背，只補頂緣洋紅缺口）：          y=790..851 （h=62，
#                                          x=12..1523，左右各裁掉 12px，同
#                                          steampunk_city 12px inset 校準）。
#   Props（洋紅底道具列，去背）：                              y=852..1023（h=172）
# ⚠️ 去背風險：本圖美術本身大量使用洋紅/桃紅/紫色霓虹（招牌、燈光），色相非常接近去背
# 用的 `#FF00FF`。`chroma_key_flood_color` 是「從畫面邊緣 flood-fill」，只會吃掉與背景
# 邊緣連通的洋紅，不會吃到被深色建築像素包住的內部霓虹色塊，因此大部分招牌霓虹安全；
# 經實測 threshold=60（與其餘地域一致）不會咬到中景/前景/道具的霓虹招牌或水晶（皆與
# 邊緣有深色像素隔開），維持 60 不下修——若之後改版美術把霓虹貼到與洋紅背景直接相鄰，
# 才需要下修到 40 甚至 30。去背手法完全沿用 steampunk_city 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
FUTURE_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=272)
FUTURE_CITY_BG_MID = Region(x=0, y=272, w=1536, h=223)
FUTURE_CITY_BG_FORE = Region(x=0, y=495, w=1536, h=291)
FUTURE_CITY_BG_GROUND = Region(x=12, y=790, w=1512, h=62)
FUTURE_CITY_PROPS_REGION = Region(x=0, y=852, w=1536, h=172)

FUTURE_CITY_LABEL_RECT = Region(x=0, y=0, w=120, h=52)
FUTURE_CITY_PROPS_LABEL_RECT = Region(x=0, y=8, w=140, h=48)

# 道具列 12 個道具座標（逐欄「非洋紅像素」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：全息廣告牌／街燈／霓虹直幅招牌「未來都市」／全息地球儀／
# 板條箱／木桶／發光水晶／護欄路障／無人機／停車指示牌／霓虹櫻花盆栽／大門歡迎看板。
# 範圍以相鄰道具中點分界，留餘裕，去背 + autocrop 後收斂到精確 bounding box；相鄰槽位
# 的餘裕重疊落在洋紅留白，不會誤裁鄰居。
FUTURE_CITY_PROP_REGIONS: dict = {
    "holo_billboard": Region(x=0, y=0, w=223, h=172),
    "street_lamp": Region(x=223, y=0, w=97, h=172),
    "neon_banner": Region(x=320, y=0, w=107, h=172),
    "hologram_globe": Region(x=427, y=0, w=150, h=172),
    "crate": Region(x=577, y=0, w=132, h=172),
    "barrel": Region(x=709, y=0, w=104, h=172),
    "crystal": Region(x=813, y=0, w=105, h=172),
    "barricade": Region(x=918, y=0, w=146, h=172),
    "drone": Region(x=1064, y=0, w=114, h=172),
    "parking_sign": Region(x=1178, y=0, w=103, h=172),
    "neon_tree": Region(x=1281, y=0, w=110, h=172),
    "welcome_sign": Region(x=1391, y=0, w=145, h=172),
}
# 細桿件/薄邊框（街燈柱、霓虹直幅招牌、停車指示牌柱、護欄路障細框）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用
# `remove_small_components` 保留分離部件。
_FUTURE_CITY_DILATED_PROPS = {"street_lamp", "neon_banner", "parking_sign", "barricade"}


def slice_future_city_bg(sheet: Image) -> dict:
    """賽博龐克霓虹夜城背景切圖：手法與 `slice_steampunk_city_bg` 完全一致（far 不去背當
    backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，
    只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(FUTURE_CITY_BG_FAR.x, FUTURE_CITY_BG_FAR.y, FUTURE_CITY_BG_FAR.w, FUTURE_CITY_BG_FAR.h),
        FUTURE_CITY_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(FUTURE_CITY_BG_MID.x, FUTURE_CITY_BG_MID.y, FUTURE_CITY_BG_MID.w, FUTURE_CITY_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, FUTURE_CITY_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(FUTURE_CITY_BG_FORE.x, FUTURE_CITY_BG_FORE.y, FUTURE_CITY_BG_FORE.w, FUTURE_CITY_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, FUTURE_CITY_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `FUTURE_CITY_BG_GROUND` 校準說明）已經避開「地面平台」標籤
    # 方框所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(FUTURE_CITY_BG_GROUND.x, FUTURE_CITY_BG_GROUND.y, FUTURE_CITY_BG_GROUND.w, FUTURE_CITY_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_future_city_props(sheet: Image) -> dict:
    """賽博龐克霓虹夜城道具列切圖：手法與 `slice_steampunk_city_props` 完全一致（先蓋掉
    整條道具列的標籤方框，再逐一裁切去背 + 依 `_FUTURE_CITY_DILATED_PROPS` 選細桿件
    保護）。
    """
    region = FUTURE_CITY_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, FUTURE_CITY_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in FUTURE_CITY_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _FUTURE_CITY_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 中世紀奇幻村莊（接手任務：meadowOrigin 重新指回 layered 美術，`design/village_layered.png`，
# 1536x1024，版式與 holy_city 完全相同——遠景含天空不去背、中景/前景/道具皆洋紅
# `#FF00FF` 底去背、地面平台不去背只補頂緣洋紅缺口）。
# 座標由 Read + 逐像素洋紅比例掃描校準，見 scratchpad 校準紀錄。五帶 y 範圍：
#   Far（藍天白雲+遠山剪影，不去背）：                      y=0..273   （h=274，
#                                          比 holy_city 少 1px——y=274 那一行已經
#                                          帶有部分洋紅殘留，往上收 1px 避免 far
#                                          backdrop 留下洋紅雜點）
#   Mid（洋紅底農舍/教堂聚落，去背）：                       y=274..494 （h=221）
#   Fore（洋紅底風車/石拱橋/瀑布/前景農舍，去背）：           y=495..747 （h=253；
#                                          實際內容在 y≈722 前已收尾，747 之後到
#                                          787 是「地面平台」標籤方框
#                                          （y≈749..778）+ 洋紅留白，不可併入 Fore，
#                                          否則深色標籤方框不會被洋紅去背去除，會變成
#                                          浮在 Fore 圖層上的黑色色塊瑕疵）
#   Ground（石磚步道，不去背，只補頂緣洋紅缺口）：            y=788..851 （h=64，
#                                          x=12..1523，左右各裁掉 12px，同
#                                          holy_city 12px inset 校準；788 是磚紋
#                                          實際內容開始處，此前是「地面平台」標籤
#                                          方框與洋紅留白）
#   Props（洋紅底道具列，去背）：                           y=852..1023（h=172）
# 去背手法完全沿用 holy_city 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
MEADOW_VILLAGE_BG_FAR = Region(x=0, y=0, w=1536, h=274)
MEADOW_VILLAGE_BG_MID = Region(x=0, y=274, w=1536, h=221)
MEADOW_VILLAGE_BG_FORE = Region(x=0, y=495, w=1536, h=253)
MEADOW_VILLAGE_BG_GROUND = Region(x=12, y=788, w=1512, h=64)
MEADOW_VILLAGE_PROPS_REGION = Region(x=0, y=852, w=1536, h=172)

MEADOW_VILLAGE_LABEL_RECT = Region(x=0, y=0, w=120, h=50)
MEADOW_VILLAGE_PROPS_LABEL_RECT = Region(x=0, y=0, w=140, h=48)

# 道具列 11 個道具座標（逐欄「非洋紅像素密度」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：松樹／路燈／指路牌／木柵欄／木桶／木箱／花卉推車／花圃／
# 曬衣繩／石牆（原推測「石井」，目視後確認是矮石牆＋花草，無水桶/井繩結構，改實名）／
# 十字聖壇。範圍刻意留餘裕，去背 + autocrop 後收斂到精確 bounding box；相鄰槽位的餘裕
# 重疊落在洋紅留白，不會誤裁鄰居。
MEADOW_VILLAGE_PROP_REGIONS: dict = {
    "pine_tree": Region(x=0, y=0, w=214, h=172),
    "lamp_post": Region(x=214, y=0, w=81, h=172),
    "signpost": Region(x=295, y=0, w=92, h=172),
    "wooden_fence": Region(x=387, y=0, w=146, h=172),
    "barrel": Region(x=533, y=0, w=89, h=172),
    "crate": Region(x=622, y=0, w=110, h=172),
    "flower_cart": Region(x=732, y=0, w=157, h=172),
    "flower_box": Region(x=889, y=0, w=147, h=172),
    "laundry_line": Region(x=1036, y=0, w=178, h=172),
    "stone_wall": Region(x=1214, y=0, w=156, h=172),
    "cross_shrine": Region(x=1370, y=0, w=166, h=172),
}
# 細桿件/薄邊框（路燈燈柱、指路牌柱、曬衣繩桿+繩、十字聖壇頂端細十字）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件。
_MEADOW_VILLAGE_DILATED_PROPS = {"lamp_post", "signpost", "laundry_line", "cross_shrine"}


def slice_meadow_village_bg(sheet: Image) -> dict:
    """中世紀奇幻村莊背景切圖：手法與 `slice_holy_city_bg` 完全一致（far 不去背當
    backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；ground 不去背，
    只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(MEADOW_VILLAGE_BG_FAR.x, MEADOW_VILLAGE_BG_FAR.y, MEADOW_VILLAGE_BG_FAR.w, MEADOW_VILLAGE_BG_FAR.h),
        MEADOW_VILLAGE_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(MEADOW_VILLAGE_BG_MID.x, MEADOW_VILLAGE_BG_MID.y, MEADOW_VILLAGE_BG_MID.w, MEADOW_VILLAGE_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, MEADOW_VILLAGE_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(MEADOW_VILLAGE_BG_FORE.x, MEADOW_VILLAGE_BG_FORE.y, MEADOW_VILLAGE_BG_FORE.w, MEADOW_VILLAGE_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, MEADOW_VILLAGE_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見 `MEADOW_VILLAGE_BG_GROUND` 校準說明）已經避開「地面平台」標籤
    # 方框所在的 y 範圍，不需要（也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(MEADOW_VILLAGE_BG_GROUND.x, MEADOW_VILLAGE_BG_GROUND.y, MEADOW_VILLAGE_BG_GROUND.w, MEADOW_VILLAGE_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_meadow_village_props(sheet: Image) -> dict:
    """中世紀奇幻村莊道具列切圖：手法與 `slice_holy_city_props` 完全一致（先蓋掉整條
    道具列的標籤方框，再逐一裁切去背 + 依 `_MEADOW_VILLAGE_DILATED_PROPS` 選細桿件保護）。
    """
    region = MEADOW_VILLAGE_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, MEADOW_VILLAGE_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in MEADOW_VILLAGE_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _MEADOW_VILLAGE_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 接手任務（2026-07-05）：`kingdom`/`village3` 重新指回 layered 美術，`21` §2/§4，
# meadow_village/holy_city 管線原樣複製。座標校準紀錄（Read + 逐像素洋紅比例掃描）：
#   Far（不去背，當完整 backdrop）：                        y=0..273（h=274，與 meadow_village 相同）
#   Mid（洋紅底，去背成透明中景）：                          y=274..501（h=228，比 meadow_village
#                                          的 221 略高——`village3_layered.png` 本身
#                                          Mid/Fore 分界略往下，逐像素校準得出）
#   Fore（洋紅底，去背成透明前景）：                         y=502..747（h=246）
#   Ground（不去背，只補頂緣洋紅缺口，12px inset 避開                y=792..855（h=64，128px inset 校準；
#     「地面平台」標籤方框，見下方 city 版本的另一組數字）：              855 是磚紋實際內容開始處）
#   Props（洋紅底道具列，去背）：                           y=856..1023（h=168）
# `city_layered_1.png` 的 Mid/Fore/Ground 邊界與上面的 village3 版本不同（各自獨立掃描
# 校準，未套用同一組數字）：
#   Far：  y=0..273（h=274）
#   Mid：  y=274..494（h=221，與 meadow_village 相同）
#   Fore： y=495..747（h=253，與 meadow_village 相同）
#   Ground：y=788..851（h=64，與 meadow_village 相同，12px inset）
#   Props：y=852..1023（h=172，與 meadow_village 相同）
# 兩張圖的 Fore/Ground 之間都留了 40px 上下的「地面平台」標籤方框 + 洋紅留白（748..788
# 或 748..792），刻意不裁進 Fore（避免 meadow_village 曾踩過的 navy-artifact bug：Fore
# 只去背不補標籤方框，方框留在 Fore 裡會變實心色塊）也不裁進 Ground（Ground 起點就是
# 磚紋內容真正開始處），完全跳過。
# 去背手法完全沿用 holy_city/meadow_village 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
KINGDOM_CITY_BG_FAR = Region(x=0, y=0, w=1536, h=274)
KINGDOM_CITY_BG_MID = Region(x=0, y=274, w=1536, h=221)
KINGDOM_CITY_BG_FORE = Region(x=0, y=495, w=1536, h=253)
KINGDOM_CITY_BG_GROUND = Region(x=12, y=788, w=1512, h=64)
KINGDOM_CITY_PROPS_REGION = Region(x=0, y=852, w=1536, h=172)

KINGDOM_CITY_LABEL_RECT = Region(x=0, y=0, w=120, h=50)
KINGDOM_CITY_PROPS_LABEL_RECT = Region(x=0, y=0, w=140, h=48)

# 道具列 12 個道具座標（逐欄「非洋紅像素密度」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：石環底座大樹／街燈／紋章旗幟／花卉甕／盆栽柏樹／木箱／
# 木桶／花圃木箱／石長椅／市集攤位（洋紅密度連續無內部空隙，確認是單一寬道具，非兩件
# 相鄰）／告示牌／石柱。範圍刻意留餘裕，去背 + autocrop 後收斂到精確 bounding box；
# 相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
KINGDOM_CITY_PROP_REGIONS: dict = {
    "tree": Region(x=95, y=0, w=125, h=172),
    "lamp_post": Region(x=220, y=0, w=84, h=172),
    "heraldic_banner": Region(x=304, y=0, w=88, h=172),
    "flower_urn": Region(x=392, y=0, w=104, h=172),
    "cypress": Region(x=496, y=0, w=76, h=172),
    "crate": Region(x=572, y=0, w=124, h=172),
    "barrel": Region(x=696, y=0, w=84, h=172),
    "flower_box": Region(x=780, y=0, w=124, h=172),
    "stone_bench": Region(x=904, y=0, w=144, h=172),
    "market_stall": Region(x=1048, y=0, w=212, h=172),
    "notice_board": Region(x=1260, y=0, w=130, h=172),
    "pillar": Region(x=1390, y=0, w=146, h=172),
}
# 細桿件/薄邊框（路燈燈柱+燈臂、紋章旗幟細桿）用 `keep_largest_component_dilated` 防斷；
# 其餘本身較粗實的道具用 `remove_small_components` 保留分離部件。
_KINGDOM_CITY_DILATED_PROPS = {"lamp_post", "heraldic_banner"}


def slice_kingdom_city_bg(sheet: Image) -> dict:
    """歐式白金王國首都背景切圖：手法與 `slice_meadow_village_bg`/`slice_holy_city_bg` 完全
    一致（far 不去背當 backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；
    ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(KINGDOM_CITY_BG_FAR.x, KINGDOM_CITY_BG_FAR.y, KINGDOM_CITY_BG_FAR.w, KINGDOM_CITY_BG_FAR.h),
        KINGDOM_CITY_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(KINGDOM_CITY_BG_MID.x, KINGDOM_CITY_BG_MID.y, KINGDOM_CITY_BG_MID.w, KINGDOM_CITY_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, KINGDOM_CITY_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(KINGDOM_CITY_BG_FORE.x, KINGDOM_CITY_BG_FORE.y, KINGDOM_CITY_BG_FORE.w, KINGDOM_CITY_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, KINGDOM_CITY_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見上方校準說明）已經避開「地面平台」標籤方框所在的 y 範圍，不需要
    # （也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(KINGDOM_CITY_BG_GROUND.x, KINGDOM_CITY_BG_GROUND.y, KINGDOM_CITY_BG_GROUND.w, KINGDOM_CITY_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_kingdom_city_props(sheet: Image) -> dict:
    """歐式白金王國首都道具列切圖：手法與 `slice_meadow_village_props`/`slice_holy_city_props`
    完全一致（先蓋掉整條道具列的標籤方框，再逐一裁切去背 + 依 `_KINGDOM_CITY_DILATED_PROPS`
    選細桿件保護）。
    """
    region = KINGDOM_CITY_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, KINGDOM_CITY_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in KINGDOM_CITY_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _KINGDOM_CITY_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 白金浮空天空之城（`design/sky_layered.png`，1536x1024）的分區座標校準：
#   Far：  y=0..281（h=282）
#   Mid：  y=282..499（h=218）
#   Fore： y=500..732（h=233）
#   Ground：y=792..851（h=60，12px inset，起點跳過「地面平台」標籤方框+留白，磚紋內容
#           真正開始處）
#   Props：y=854..1023（h=170）
# Fore 刻意在「地面平台」標籤方框（y=733..790 一帶）開始前收尾，不裁進 Fore（避免
# meadow_village 曾踩過的 navy-artifact bug：Fore 只去背不補標籤方框，方框留在 Fore 裡
# 會變實心色塊），Ground 起點也跳過方框本身。去背手法完全沿用 kingdom_city/meadow_village
# 驗證過的管線，不發明新做法。
# ---------------------------------------------------------------------------
SKY_CITY_V2_BG_FAR = Region(x=0, y=0, w=1536, h=282)
SKY_CITY_V2_BG_MID = Region(x=0, y=282, w=1536, h=218)
SKY_CITY_V2_BG_FORE = Region(x=0, y=500, w=1536, h=233)
SKY_CITY_V2_BG_GROUND = Region(x=12, y=792, w=1512, h=60)
SKY_CITY_V2_PROPS_REGION = Region(x=0, y=854, w=1536, h=170)

SKY_CITY_V2_LABEL_RECT = Region(x=0, y=0, w=120, h=50)
SKY_CITY_V2_PROPS_LABEL_RECT = Region(x=0, y=0, w=140, h=48)

# 道具列 13 個道具座標（逐欄「非洋紅像素密度」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：路燈／旗幟／指路牌／水晶（底座）／花卉甕／水晶柱／寶箱／
# 木桶／木箱／花圃木箱／長椅／噴泉／告示牌（涼亭式佈告欄）。範圍刻意留餘裕，去背 +
# autocrop 後收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
SKY_CITY_V2_PROP_REGIONS: dict = {
    "lamp_post": Region(x=40, y=0, w=98, h=170),
    "banner": Region(x=138, y=0, w=90, h=170),
    "signpost": Region(x=228, y=0, w=90, h=170),
    "crystal": Region(x=318, y=0, w=104, h=170),
    "flower_urn": Region(x=422, y=0, w=122, h=170),
    "crystal_pillar": Region(x=544, y=0, w=94, h=170),
    "chest": Region(x=638, y=0, w=118, h=170),
    "barrel": Region(x=756, y=0, w=92, h=170),
    "crate": Region(x=848, y=0, w=112, h=170),
    "flower_box": Region(x=960, y=0, w=122, h=170),
    "bench": Region(x=1082, y=0, w=118, h=170),
    "fountain": Region(x=1200, y=0, w=144, h=170),
    "notice_board": Region(x=1344, y=0, w=186, h=170),
}
# 細桿件/薄邊框（路燈燈柱+燈臂、旗幟細桿、指路牌柱、水晶柱細尖）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件。
_SKY_CITY_V2_DILATED_PROPS = {"lamp_post", "banner", "signpost", "crystal_pillar"}


def slice_sky_city_v2_bg(sheet: Image) -> dict:
    """白金浮空天空之城背景切圖：手法與 `slice_kingdom_city_bg`/`slice_meadow_village_bg`
    完全一致（far 不去背當 backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景
    物件層；ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(SKY_CITY_V2_BG_FAR.x, SKY_CITY_V2_BG_FAR.y, SKY_CITY_V2_BG_FAR.w, SKY_CITY_V2_BG_FAR.h),
        SKY_CITY_V2_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(SKY_CITY_V2_BG_MID.x, SKY_CITY_V2_BG_MID.y, SKY_CITY_V2_BG_MID.w, SKY_CITY_V2_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, SKY_CITY_V2_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(SKY_CITY_V2_BG_FORE.x, SKY_CITY_V2_BG_FORE.y, SKY_CITY_V2_BG_FORE.w, SKY_CITY_V2_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, SKY_CITY_V2_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見上方校準說明）已經避開「地面平台」標籤方框所在的 y 範圍，不需要
    # （也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(SKY_CITY_V2_BG_GROUND.x, SKY_CITY_V2_BG_GROUND.y, SKY_CITY_V2_BG_GROUND.w, SKY_CITY_V2_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_sky_city_v2_props(sheet: Image) -> dict:
    """白金浮空天空之城道具列切圖：手法與 `slice_kingdom_city_props`/`slice_meadow_village_props`
    完全一致（先蓋掉整條道具列的標籤方框，再逐一裁切去背 + 依 `_SKY_CITY_V2_DILATED_PROPS`
    選細桿件保護）。
    """
    region = SKY_CITY_V2_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, SKY_CITY_V2_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in SKY_CITY_V2_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _SKY_CITY_V2_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


TREE_VILLAGE_BG_FAR = Region(x=0, y=0, w=1536, h=274)
TREE_VILLAGE_BG_MID = Region(x=0, y=274, w=1536, h=228)
TREE_VILLAGE_BG_FORE = Region(x=0, y=502, w=1536, h=246)
TREE_VILLAGE_BG_GROUND = Region(x=12, y=792, w=1512, h=64)
TREE_VILLAGE_PROPS_REGION = Region(x=0, y=856, w=1536, h=168)

TREE_VILLAGE_LABEL_RECT = Region(x=0, y=0, w=120, h=50)
TREE_VILLAGE_PROPS_LABEL_RECT = Region(x=0, y=0, w=140, h=48)

# 道具列 11 個道具座標（逐欄「非洋紅像素密度」投影分段掃描 + 目視命名校準，見 scratchpad
# 校準紀錄，順序由左到右）：路燈／旗幡／指路牌／盆栽樹／花卉推車／木桶／花卉篷車／
# 曬衣繩／告示牌／圓形徽章告示／拱門（藤蔓花飾）。範圍刻意留餘裕，去背 + autocrop 後
# 收斂到精確 bounding box；相鄰槽位的餘裕重疊落在洋紅留白，不會誤裁鄰居。
TREE_VILLAGE_PROP_REGIONS: dict = {
    "lamp_post": Region(x=90, y=0, w=117, h=168),
    "banner": Region(x=207, y=0, w=101, h=168),
    "signpost": Region(x=308, y=0, w=103, h=168),
    "potted_tree": Region(x=411, y=0, w=101, h=168),
    "flower_cart": Region(x=512, y=0, w=116, h=168),
    "barrel": Region(x=628, y=0, w=95, h=168),
    "flower_wagon": Region(x=723, y=0, w=155, h=168),
    "laundry_line": Region(x=878, y=0, w=178, h=168),
    "notice_board": Region(x=1056, y=0, w=151, h=168),
    "round_sign": Region(x=1207, y=0, w=94, h=168),
    "arch_gate": Region(x=1301, y=0, w=172, h=168),
}
# 細桿件/薄邊框（路燈燈柱+燈臂、旗幡細桿、指路牌柱、曬衣繩桿+繩、拱門立柱）用
# `keep_largest_component_dilated` 防斷；其餘本身較粗實的道具用 `remove_small_components`
# 保留分離部件。
_TREE_VILLAGE_DILATED_PROPS = {"lamp_post", "banner", "signpost", "laundry_line", "arch_gate"}


def slice_tree_village_bg(sheet: Image) -> dict:
    """森林樹屋村落背景切圖：手法與 `slice_meadow_village_bg`/`slice_holy_city_bg` 完全一致
    （far 不去背當 backdrop + 水平無縫羽化；mid/fore 洋紅底去背成透明中景/前景物件層；
    ground 不去背，只補頂緣洋紅缺口）。
    """
    far = patch_label_box_sky(
        sheet.crop(TREE_VILLAGE_BG_FAR.x, TREE_VILLAGE_BG_FAR.y, TREE_VILLAGE_BG_FAR.w, TREE_VILLAGE_BG_FAR.h),
        TREE_VILLAGE_LABEL_RECT,
    )
    far = make_horizontally_seamless(far, blend_px=64)

    mid_raw = sheet.crop(TREE_VILLAGE_BG_MID.x, TREE_VILLAGE_BG_MID.y, TREE_VILLAGE_BG_MID.w, TREE_VILLAGE_BG_MID.h)
    mid_raw = patch_label_box(mid_raw, TREE_VILLAGE_LABEL_RECT)
    mid = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(mid_raw, (255, 0, 255), threshold=60))))

    fore_raw = sheet.crop(TREE_VILLAGE_BG_FORE.x, TREE_VILLAGE_BG_FORE.y, TREE_VILLAGE_BG_FORE.w, TREE_VILLAGE_BG_FORE.h)
    fore_raw = patch_label_box(fore_raw, TREE_VILLAGE_LABEL_RECT)
    fore = defringe_magenta_edges(strip_magenta_bleed_rows(remove_magenta_spill(chroma_key_flood_color(fore_raw, (255, 0, 255), threshold=60))))

    # Ground 裁切框（見上方校準說明）已經避開「地面平台」標籤方框所在的 y 範圍，不需要
    # （也不能）再套 `patch_label_box`。
    ground_raw = sheet.crop(TREE_VILLAGE_BG_GROUND.x, TREE_VILLAGE_BG_GROUND.y, TREE_VILLAGE_BG_GROUND.w, TREE_VILLAGE_BG_GROUND.h)
    ground = patch_magenta_columns(ground_raw)

    return {"far": far, "mid": mid, "fore": fore, "ground": ground}


def slice_tree_village_props(sheet: Image) -> dict:
    """森林樹屋村落道具列切圖：手法與 `slice_meadow_village_props`/`slice_holy_city_props`
    完全一致（先蓋掉整條道具列的標籤方框，再逐一裁切去背 + 依 `_TREE_VILLAGE_DILATED_PROPS`
    選細桿件保護）。
    """
    region = TREE_VILLAGE_PROPS_REGION
    items = sheet.crop(region.x, region.y, region.w, region.h)
    items = patch_label_box(items, TREE_VILLAGE_PROPS_LABEL_RECT)
    out = {}
    for name, prop_region in TREE_VILLAGE_PROP_REGIONS.items():
        w = min(prop_region.w, items.width - prop_region.x)
        h = min(prop_region.h, items.height - prop_region.y)
        cropped = items.crop(prop_region.x, prop_region.y, w, h)
        keyed = defringe_magenta_edges(remove_magenta_spill(chroma_key_flood_color(cropped, (255, 0, 255), threshold=60)))
        if name in _TREE_VILLAGE_DILATED_PROPS:
            keyed = keep_largest_component_dilated(keyed, dilate_px=2)
        else:
            keyed = remove_small_components(keyed, min_area=20)
        out[name] = autocrop(keyed)
    return out


# ---------------------------------------------------------------------------
# 美術大改版第 3 波（`21_ASSET_OVERHAUL_PLAN.md` §3）：共用居民 NPC——泛用化
# `RegionNpcScatter` 消費的美術改由**共享** `Resources/art/npc/<name>.png` 讀取（不再放在
# 各地域 `regions/<r>/npc/` 底下），因為同一種 NPC（例如商人/旅人）會出現在多個地域，
# 沒有必要每個地域各存一份重複檔案。每種 NPC 只取「向前（面向鏡頭）」單幀（站姿代表幀，
# townsfolk 純裝飾用，不需要整組走路循環），由 Read `design/npc_1.png` / `design/npc_2.png`
# 目視 + 逐像素亮度/連通元件掃描校準座標（見 scratchpad 校準紀錄）。
# ---------------------------------------------------------------------------

# `npc_1.png`（1402x1122，近黑底 `#242527` 系）版式：4 種角色（商人/農夫/孩童/樂手）
# 各一排、每排 4 欄（向右/向左/向前/背面）。本波只取「孩童」的向前欄（npc_2 沒有孩童，
# 商人/農夫/樂手 npc_2 都有品質更一致的版本，統一改用 npc_2 那份維持風格一致，`21` §3 圖說
# 「若兩張都有取品質好的一張即可」）。
_NPC_1_BG_COLOR = (36, 37, 39)
NPC_1_CHILD_FRONT_REGION = Region(x=700, y=615, w=220, h=220)


def slice_npc1_child(sheet: Image) -> Image:
    """裁出 `npc_1.png`「孩童」列向前欄代表幀，去背/去雜點/autocrop（同
    `slice_main_role_column` 手法：`keep_largest_component_dilated` 防止頭部與身體間
    因去背斷開 1-2px 而被誤判成兩個連通塊、砍掉頭部）。"""
    region = NPC_1_CHILD_FRONT_REGION
    w = min(region.w, sheet.width - region.x)
    h = min(region.h, sheet.height - region.y)
    cropped = sheet.crop(region.x, region.y, w, h)
    keyed = chroma_key_flood_color(cropped, _NPC_1_BG_COLOR, threshold=26)
    keyed = despeckle_neutral_residue(keyed)
    keyed = keep_largest_component_dilated(keyed, dilate_px=3)
    return autocrop(keyed)


# `npc_2.png`（1536x1024，近黑底 `#1D1E1F` 系）版式：上下兩區塊，各 8 欄 x 4 排（向右/向左/
# 向前/背面）。上區塊：國王/王后/王子/公主/大臣/騎士/衛兵/商人；下區塊：農夫/漁夫/麵包師/
# 鐵匠/藥師/學者/樂師/旅人。本波只取每欄的「向前」排（第 3 排），8 欄 x 座標兩區塊共用
# （同一份版型上下重複，逐像素欄投影校準確認上下區塊欄位 x 完全對齊，見 scratchpad 校準紀錄）。
_NPC_2_BG_COLOR = (29, 30, 31)

# 8 欄 (x, w)，由左到右：依序對應上/下區塊各自的 8 種角色名稱。
NPC_2_COLUMN_XS: list = [
    (130, 152),
    (282, 154),
    (436, 166),
    (602, 174),
    (776, 168),
    (944, 160),
    (1104, 172),
    (1276, 144),
]

# 「向前」排 y 帶：上區塊（含頁首標題列 + 向右/向左兩排）y=284..392；下區塊（頁面下半，
# 同款版式，含自己的標題列 + 向右/向左兩排）y=792..896。
NPC_2_TOP_FRONT_ROW = Region(x=0, y=284, w=0, h=108)
NPC_2_BOTTOM_FRONT_ROW = Region(x=0, y=792, w=0, h=104)

NPC_2_TOP_NAMES = ["king", "queen", "prince", "princess", "minister", "knight", "guard", "merchant"]
NPC_2_BOTTOM_NAMES = ["farmer", "fisher", "baker", "blacksmith", "apothecary", "scholar", "musician", "traveler"]


def slice_npc2_row(sheet: Image, names: list, row_y: int, row_h: int) -> dict:
    """裁出 `npc_2.png` 某區塊「向前」排的 8 個角色代表幀，去背/去雜點/autocrop
    （流程同 `slice_npc1_child`）。"""
    out = {}
    for name, (x, w) in zip(names, NPC_2_COLUMN_XS):
        cw = min(w, sheet.width - x)
        ch = min(row_h, sheet.height - row_y)
        cropped = sheet.crop(x, row_y, cw, ch)
        keyed = chroma_key_flood_color(cropped, _NPC_2_BG_COLOR, threshold=26)
        keyed = despeckle_neutral_residue(keyed)
        keyed = keep_largest_component_dilated(keyed, dilate_px=3)
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
        if name == "far":
            # far 橫向平鋪的接縫治本（同 `slice_harbor_bg` 手法，`make_horizontally_seamless`
            # docstring）：推廣到所有地域，過渡期舊格式地域也無縫 loop。
            img = make_horizontally_seamless(img, blend_px=64)
        for out_dir in (bg_dir, meadow_bg_dir):
            out_path = os.path.join(out_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

    # --- 主角向右走路 frame + 向前（面向觀看者）frame（美術大改版第 1 波，`21` §4：
    # 主角改讀 design/main_role.png，取代舊 asset_sheet.png 角色列）---
    char_dir = os.path.join(OUT_ROOT, "char_hero")
    if os.path.exists(MAIN_ROLE_SHEET):
        main_role_sheet = decode_png(MAIN_ROLE_SHEET)
        print(f"main_role_sheet: {main_role_sheet.width}x{main_role_sheet.height}")

        # 重切前先清掉舊的 numbered 幀：新素材幀數可能比舊的少（如舊 5 幀→新 3 幀），
        # 殘留的舊 right_3/right_4 會被 CharacterNode 的 sequentialTextures 一併載入、
        # 把新舊角色混進走路循環而閃爍。
        if os.path.isdir(char_dir):
            for _f in os.listdir(char_dir):
                if (_f.startswith("right_") or _f.startswith("front_")) and _f.endswith(".png"):
                    os.remove(os.path.join(char_dir, _f))

        # 走路 8 幀改讀 `main_role_walk.png`（真正的走路循環，取代舊的 3 靜態姿勢）；
        # 若走路循環圖不存在則退回舊 `main_role.png` 3 姿勢（向後相容）。
        if os.path.exists(MAIN_ROLE_WALK_SHEET):
            main_role_walk_sheet = decode_png(MAIN_ROLE_WALK_SHEET)
            print(f"main_role_walk_sheet: {main_role_walk_sheet.width}x{main_role_walk_sheet.height}")
            hero_frames = slice_main_role_column(main_role_walk_sheet, MAIN_ROLE_WALK_ROW)
        else:
            print(f"note: {MAIN_ROLE_WALK_SHEET} not found, falling back to {MAIN_ROLE_SHEET} right rows")
            hero_frames = slice_main_role_column(main_role_sheet, MAIN_ROLE_RIGHT_ROWS)
        hero_frames = pad_to_common_size(hero_frames)
        for i, frame in enumerate(hero_frames):
            out_path = os.path.join(char_dir, f"right_{i}.png")
            encode_png(frame, out_path)
            print(f"wrote {out_path} ({frame.width}x{frame.height})")

        hero_front_frames = slice_main_role_column(main_role_sheet, MAIN_ROLE_FRONT_ROWS)
        hero_front_frames = pad_to_common_size(hero_front_frames)
        for i, frame in enumerate(hero_front_frames):
            out_path = os.path.join(char_dir, f"front_{i}.png")
            encode_png(frame, out_path)
            print(f"wrote {out_path} ({frame.width}x{frame.height})")
    else:
        print(f"note: {MAIN_ROLE_SHEET} not found, skipping hero slicing")

    # --- 接手任務：`design/main_role_walk_v2.png` 取代 `main_role_walk.png`，重切主角
    # 走路 8 幀（OVERWRITE 上面剛寫的 `right_0..7.png`，v2 勝出，見 `slice_main_role_walk_v2`
    # docstring）+ 新增待機 4 幀（`idle_0..3.png`，本波只切圖，動畫接線留給後續 session）。
    # 刻意放在舊 `MAIN_ROLE_WALK_SHEET` 區塊之後執行，讓 v2 產出的 `right_*.png` 是磁碟上
    # 最終版本；若 v2 素材表不存在則整段略過，保留舊版 `right_0..7.png` 不變（向後相容）。
    if os.path.exists(MAIN_ROLE_WALK_V2_SHEET):
        main_role_walk_v2_sheet = decode_png(MAIN_ROLE_WALK_V2_SHEET)
        print(f"main_role_walk_v2_sheet: {main_role_walk_v2_sheet.width}x{main_role_walk_v2_sheet.height}")

        walk_v2_frames = slice_main_role_walk_v2(
            main_role_walk_v2_sheet,
            MAIN_ROLE_WALK_V2_ROW,
            lambda im: keep_largest_component_dilated(im, dilate_px=3),
        )
        for i, frame in enumerate(walk_v2_frames):
            out_path = os.path.join(char_dir, f"right_{i}.png")
            encode_png(frame, out_path)
            print(f"wrote {out_path} ({frame.width}x{frame.height}) [v2, overwrites v1]")

        idle_v2_frames = slice_main_role_walk_v2(
            main_role_walk_v2_sheet,
            MAIN_ROLE_IDLE_V2_ROW,
            lambda im: remove_small_components(im, min_area=12),
        )
        for i, frame in enumerate(idle_v2_frames):
            out_path = os.path.join(char_dir, f"idle_{i}.png")
            encode_png(frame, out_path)
            print(f"wrote {out_path} ({frame.width}x{frame.height}) [v2 idle]")
    else:
        print(f"note: {MAIN_ROLE_WALK_V2_SHEET} not found, keeping v1 right_0..7.png, no idle frames")

    # --- 旅伴向右走路 frame（美術大改版第 1 波，`21` §4：旅伴改讀 design/resource_v2.png
    # 的「主角-女（冒險者）」走路幀，取代舊 asset_sheet.png 角色列）---
    companion_dir = os.path.join(OUT_ROOT, "char_companion")
    if os.path.exists(RESOURCE_V2_SHEET):
        resource_v2_sheet = decode_png(RESOURCE_V2_SHEET)
        print(f"resource_v2_sheet: {resource_v2_sheet.width}x{resource_v2_sheet.height}")

        # 重切前先清掉舊的 numbered 幀（同 hero，避免殘留混入）。
        if os.path.isdir(companion_dir):
            for _f in os.listdir(companion_dir):
                if _f.startswith("right_") and _f.endswith(".png"):
                    os.remove(os.path.join(companion_dir, _f))

        companion_frames = slice_resource_v2_companion_walk(resource_v2_sheet)
        companion_frames = pad_to_common_size(companion_frames)
        for i, frame in enumerate(companion_frames):
            out_path = os.path.join(companion_dir, f"right_{i}.png")
            encode_png(frame, out_path)
            print(f"wrote {out_path} ({frame.width}x{frame.height})")
    else:
        print(f"note: {RESOURCE_V2_SHEET} not found, skipping companion slicing")

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

    # --- 王國首都地域（美術大改版第 2 波，`21_ASSET_OVERHAUL_PLAN.md` §4 重切）：
    # 環境（背景+道具）讀新版 1536x1024 design/kingdom.png（與 grassland 同款版式，取代
    # Stage C 舊 1774x887 版本，尺寸 guard 已移除）；NPC 讀救回的舊版
    # design/kingdom_characters.png（唯一還保留角色列的素材表，不受本次重切影響）。---
    if os.path.exists(KINGDOM_SHEET):
        kingdom_sheet = decode_png(KINGDOM_SHEET)
        print(f"kingdom_sheet: {kingdom_sheet.width}x{kingdom_sheet.height}")

        kingdom_bg_dir = os.path.join(OUT_ROOT, "regions", "kingdom", "bg")
        kingdom_layers = (
            ("far", KINGDOM_BG_FAR, None, "far"),
            ("mid", KINGDOM_BG_MID, KINGDOM_BG_MID_TOP_FADE_PX, "mid"),
            ("fore", KINGDOM_BG_FORE, KINGDOM_BG_FORE_TOP_FADE_PX, "fore"),
            ("ground", KINGDOM_BG_GROUND, None, "ground"),
        )
        for name, region, fade_px, label_key in kingdom_layers:
            img = kingdom_sheet.crop(region.x, region.y, region.w, region.h)
            if label_key is not None and label_key in KINGDOM_LABEL_BOX_RECTS:
                # 蓋掉疊在內容左上角的「遠景/中景/前景/地面平台」標籤黑底方框
                # （同 `slice_grassland_props` 手法，地面平台用水平版 patch）。
                if label_key == "ground":
                    img = patch_label_box_horizontal(img, KINGDOM_LABEL_BOX_RECTS[label_key])
                elif label_key == "far":
                    img = patch_label_box_sky(img, KINGDOM_LABEL_BOX_RECTS[label_key])
                else:
                    img = patch_label_box(img, KINGDOM_LABEL_BOX_RECTS[label_key])
            if fade_px:
                # mid/fore 疊在後方層之前、上緣重疊，淡出讓接縫變漸層（同 `BG_MID_TOP_FADE_PX` 手法）。
                img = fade_top_edge(img, fade_px=fade_px)
            if name == "far":
                # far 橫向平鋪的接縫治本，推廣到所有地域（同 `slice_harbor_bg` 手法）。
                img = make_horizontally_seamless(img, blend_px=64)
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
            if name == "far":
                # far 橫向平鋪的接縫治本，推廣到所有地域（同 `slice_harbor_bg` 手法）。
                img = make_horizontally_seamless(img, blend_px=64)
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

    # --- 草原地域（美術大改版第 1 波，`21_ASSET_OVERHAUL_PLAN.md` §4）：取代 meadow，
    # 獨立素材表 design/grassland.png（浮空島+風車村+石屋市集，四層+11 個道具）。
    # `RegionType.meadowOrigin.assetFolder` 已改指到 `"grassland"`（`Region.swift`），
    # 這裡把切好的背景/道具寫到 `regions/grassland/`，取代原本讀 `regions/meadow/` 的內容。---
    if os.path.exists(GRASSLAND_SHEET):
        grassland_sheet = decode_png(GRASSLAND_SHEET)
        print(f"grassland_sheet: {grassland_sheet.width}x{grassland_sheet.height}")

        grassland_bg_dir = os.path.join(OUT_ROOT, "regions", "grassland", "bg")
        grassland_layers = (
            ("far", GRASSLAND_BG_FAR, None, "far"),
            ("mid", GRASSLAND_BG_MID, GRASSLAND_BG_MID_TOP_FADE_PX, "mid"),
            ("fore", GRASSLAND_BG_FORE, GRASSLAND_BG_FORE_TOP_FADE_PX, "fore"),
            ("ground", GRASSLAND_BG_GROUND, None, "ground"),
        )
        for name, region, fade_px, label_key in grassland_layers:
            img = grassland_sheet.crop(region.x, region.y, region.w, region.h)
            if label_key is not None and label_key in GRASSLAND_LABEL_BOX_RECTS:
                # 草原素材表四層（含地面平台）左上角都疊了標籤黑底方框，皆需 patch
                # （與 kingdom/sea_city 只有 far/mid/fore 有方框、地面平台無方框不同）。
                # 地面平台層本身是紋理密集的草地/泥土路徑（非天空/牆面那種垂直平緩漸層），
                # 用水平版 `patch_label_box_horizontal`（抓方框右側同一列，沿水平紋理貼過來）
                # 比垂直重複自然，見其 docstring。
                if label_key == "ground":
                    img = patch_label_box_horizontal(img, GRASSLAND_LABEL_BOX_RECTS[label_key])
                elif label_key == "far":
                    img = patch_label_box_sky(img, GRASSLAND_LABEL_BOX_RECTS[label_key])
                else:
                    img = patch_label_box(img, GRASSLAND_LABEL_BOX_RECTS[label_key])
            if fade_px:
                img = fade_top_edge(img, fade_px=fade_px)
            if name == "far":
                # far 橫向平鋪的接縫治本，推廣到所有地域（同 `slice_harbor_bg` 手法）。
                img = make_horizontally_seamless(img, blend_px=64)
            out_path = os.path.join(grassland_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        grassland_props = slice_grassland_props(grassland_sheet)
        grassland_props_dir = os.path.join(OUT_ROOT, "regions", "grassland", "props")
        for name, img in grassland_props.items():
            out_path = os.path.join(grassland_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {GRASSLAND_SHEET} not found, skipping grassland region slicing")

    # --- 美術大改版第 2 波（`21_ASSET_OVERHAUL_PLAN.md` §4）：5 個新地域，共用
    # `slice_new_region_bg`/`slice_new_region_props`（見上方定義），逐張各自的座標表/
    # 背景色/dilated 分類。---
    new_regions = (
        ("valley", VALLEY_SHEET, VALLEY_PROP_REGIONS, _VALLEY_PROP_BG_COLOR,
         _VALLEY_DILATED_PROPS, _VALLEY_PROP_EXCLUDE_RECTS),
        ("village_2", VILLAGE_2_SHEET, VILLAGE_2_PROP_REGIONS, _VILLAGE_2_PROP_BG_COLOR,
         _VILLAGE_2_DILATED_PROPS, _VILLAGE_2_PROP_EXCLUDE_RECTS),
        ("village_3", VILLAGE_3_SHEET, VILLAGE_3_PROP_REGIONS, _VILLAGE_3_PROP_BG_COLOR,
         _VILLAGE_3_DILATED_PROPS, _VILLAGE_3_PROP_EXCLUDE_RECTS),
        ("sky_village", SKY_VILLAGE_SHEET, SKY_VILLAGE_PROP_REGIONS, _SKY_VILLAGE_PROP_BG_COLOR,
         _SKY_VILLAGE_DILATED_PROPS, _SKY_VILLAGE_PROP_EXCLUDE_RECTS),
        ("sky_city", SKY_CITY_SHEET, SKY_CITY_PROP_REGIONS, _SKY_CITY_PROP_BG_COLOR,
         _SKY_CITY_DILATED_PROPS, _SKY_CITY_PROP_EXCLUDE_RECTS),
    )
    for region_name, sheet_path, prop_regions, bg_color, dilated_names, exclude_rects in new_regions:
        if not os.path.exists(sheet_path):
            print(f"note: {sheet_path} not found, skipping {region_name} region slicing")
            continue
        region_sheet = decode_png(sheet_path)
        print(f"{region_name}_sheet: {region_sheet.width}x{region_sheet.height}")

        bg_dir_out = os.path.join(OUT_ROOT, "regions", region_name, "bg")
        for name, img in slice_new_region_bg(region_sheet).items():
            out_path = os.path.join(bg_dir_out, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        props_dir_out = os.path.join(OUT_ROOT, "regions", region_name, "props")
        props = slice_new_region_props(region_sheet, prop_regions, bg_color, dilated_names, exclude_rects)
        for name, img in props.items():
            out_path = os.path.join(props_dir_out, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

    # --- 美術大改版第 3 波（`21_ASSET_OVERHAUL_PLAN.md` §3）：共用居民 NPC，寫到共享
    # `Resources/art/npc/<name>.png`（不放在各地域 `regions/<r>/npc/` 底下——`RegionNpcScatter`
    # 只指定「哪些地域用哪些 NPC 型別」，實際美術是跨地域共享的單一份檔案）。---
    npc_dir = os.path.join(OUT_ROOT, "npc")
    if os.path.exists(NPC_1_SHEET):
        npc1_sheet = decode_png(NPC_1_SHEET)
        print(f"npc1_sheet: {npc1_sheet.width}x{npc1_sheet.height}")
        child_img = slice_npc1_child(npc1_sheet)
        out_path = os.path.join(npc_dir, "child.png")
        encode_png(child_img, out_path)
        print(f"wrote {out_path} ({child_img.width}x{child_img.height})")
    else:
        print(f"note: {NPC_1_SHEET} not found, skipping npc_1 slicing")

    if os.path.exists(NPC_2_SHEET):
        npc2_sheet = decode_png(NPC_2_SHEET)
        print(f"npc2_sheet: {npc2_sheet.width}x{npc2_sheet.height}")
        npc2_npcs = {}
        npc2_npcs.update(slice_npc2_row(
            npc2_sheet, NPC_2_TOP_NAMES, NPC_2_TOP_FRONT_ROW.y, NPC_2_TOP_FRONT_ROW.h,
        ))
        npc2_npcs.update(slice_npc2_row(
            npc2_sheet, NPC_2_BOTTOM_NAMES, NPC_2_BOTTOM_FRONT_ROW.y, NPC_2_BOTTOM_FRONT_ROW.h,
        ))
        for name, img in npc2_npcs.items():
            out_path = os.path.join(npc_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {NPC_2_SHEET} not found, skipping npc_2 slicing")

    # --- 海港（美術流程驗證，`20` §8A）：`design/harbor_test.png`，「洋紅去背 + 真多層視差」
    # 新流程試驗地域，只供 `FYW_DEBUG_REGION=harbor` 截圖驗收，不排進 8 地域循環。---
    if os.path.exists(HARBOR_SHEET):
        harbor_sheet = decode_png(HARBOR_SHEET)
        print(f"harbor_sheet: {harbor_sheet.width}x{harbor_sheet.height}")

        harbor_bg_dir = os.path.join(OUT_ROOT, "regions", "harbor", "bg")
        for name, img in slice_harbor_bg(harbor_sheet).items():
            out_path = os.path.join(harbor_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        harbor_props_dir = os.path.join(OUT_ROOT, "regions", "harbor", "props")
        for name, img in slice_harbor_props(harbor_sheet).items():
            out_path = os.path.join(harbor_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {HARBOR_SHEET} not found, skipping harbor region slicing")

    # --- 溫泉山村（接手任務：harbor 管線推廣，`design/hotspring_village.png`）：排進 9 地域
    # 循環（取代原 8 地域循環，`RegionType.layeredRegions`/`cycle`），`FYW_DEBUG_REGION=
    # hotspring_village` 可直接截圖驗收。---
    if os.path.exists(HOTSPRING_VILLAGE_SHEET):
        hotspring_sheet = decode_png(HOTSPRING_VILLAGE_SHEET)
        print(f"hotspring_village_sheet: {hotspring_sheet.width}x{hotspring_sheet.height}")

        hotspring_bg_dir = os.path.join(OUT_ROOT, "regions", "hotspring_village", "bg")
        for name, img in slice_hotspring_village_bg(hotspring_sheet).items():
            out_path = os.path.join(hotspring_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        hotspring_props_dir = os.path.join(OUT_ROOT, "regions", "hotspring_village", "props")
        for name, img in slice_hotspring_village_props(hotspring_sheet).items():
            out_path = os.path.join(hotspring_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {HOTSPRING_VILLAGE_SHEET} not found, skipping hotspring_village region slicing")

    # --- 仙俠山宮（接手任務：hotspring 管線推廣，`design/mountain_palace.png`）：排進 10
    # 地域循環（取代原 9 地域循環，`RegionType.layeredRegions`/`cycle`），`FYW_DEBUG_REGION=
    # mountain_palace` 可直接截圖驗收。---
    if os.path.exists(MOUNTAIN_PALACE_SHEET):
        mountain_palace_sheet = decode_png(MOUNTAIN_PALACE_SHEET)
        print(f"mountain_palace_sheet: {mountain_palace_sheet.width}x{mountain_palace_sheet.height}")

        mountain_palace_bg_dir = os.path.join(OUT_ROOT, "regions", "mountain_palace", "bg")
        for name, img in slice_mountain_palace_bg(mountain_palace_sheet).items():
            out_path = os.path.join(mountain_palace_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        mountain_palace_props_dir = os.path.join(OUT_ROOT, "regions", "mountain_palace", "props")
        for name, img in slice_mountain_palace_props(mountain_palace_sheet).items():
            out_path = os.path.join(mountain_palace_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {MOUNTAIN_PALACE_SHEET} not found, skipping mountain_palace region slicing")

    # --- 雪山王國（接手任務：hotspring/mountain_palace 管線推廣，`design/snow_mountain.png`）：
    # 排進 11 地域循環，`FYW_DEBUG_REGION=snow_mountain` 可直接截圖驗收。---
    if os.path.exists(SNOW_MOUNTAIN_SHEET):
        snow_mountain_sheet = decode_png(SNOW_MOUNTAIN_SHEET)
        print(f"snow_mountain_sheet: {snow_mountain_sheet.width}x{snow_mountain_sheet.height}")

        snow_mountain_bg_dir = os.path.join(OUT_ROOT, "regions", "snow_mountain", "bg")
        for name, img in slice_snow_mountain_bg(snow_mountain_sheet).items():
            out_path = os.path.join(snow_mountain_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        snow_mountain_props_dir = os.path.join(OUT_ROOT, "regions", "snow_mountain", "props")
        for name, img in slice_snow_mountain_props(snow_mountain_sheet).items():
            out_path = os.path.join(snow_mountain_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {SNOW_MOUNTAIN_SHEET} not found, skipping snow_mountain region slicing")

    # --- 浮空魔法之城（接手任務：hotspring/mountain_palace 管線推廣，`design/magic_city.png`）：
    # 排進 12 地域循環，`FYW_DEBUG_REGION=magic_city` 可直接截圖驗收。---
    if os.path.exists(MAGIC_CITY_SHEET):
        magic_city_sheet = decode_png(MAGIC_CITY_SHEET)
        print(f"magic_city_sheet: {magic_city_sheet.width}x{magic_city_sheet.height}")

        magic_city_bg_dir = os.path.join(OUT_ROOT, "regions", "magic_city", "bg")
        for name, img in slice_magic_city_bg(magic_city_sheet).items():
            out_path = os.path.join(magic_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        magic_city_props_dir = os.path.join(OUT_ROOT, "regions", "magic_city", "props")
        for name, img in slice_magic_city_props(magic_city_sheet).items():
            out_path = os.path.join(magic_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {MAGIC_CITY_SHEET} not found, skipping magic_city region slicing")

    # --- 聖光之城（接手任務：magic_city 管線推廣，`design/holy_city.png`）：
    # 排進 13 地域循環，`FYW_DEBUG_REGION=holy_city` 可直接截圖驗收。---
    if os.path.exists(HOLY_CITY_SHEET):
        holy_city_sheet = decode_png(HOLY_CITY_SHEET)
        print(f"holy_city_sheet: {holy_city_sheet.width}x{holy_city_sheet.height}")

        holy_city_bg_dir = os.path.join(OUT_ROOT, "regions", "holy_city", "bg")
        for name, img in slice_holy_city_bg(holy_city_sheet).items():
            out_path = os.path.join(holy_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        holy_city_props_dir = os.path.join(OUT_ROOT, "regions", "holy_city", "props")
        for name, img in slice_holy_city_props(holy_city_sheet).items():
            out_path = os.path.join(holy_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {HOLY_CITY_SHEET} not found, skipping holy_city region slicing")

    # --- 蒸氣龐克飛船城（接手任務：holy_city 管線推廣，`design/steampunk_city.png`）：
    # 排進 14 地域循環，`FYW_DEBUG_REGION=steampunk_city` 可直接截圖驗收。---
    if os.path.exists(STEAMPUNK_CITY_SHEET):
        steampunk_city_sheet = decode_png(STEAMPUNK_CITY_SHEET)
        print(f"steampunk_city_sheet: {steampunk_city_sheet.width}x{steampunk_city_sheet.height}")

        steampunk_city_bg_dir = os.path.join(OUT_ROOT, "regions", "steampunk_city", "bg")
        for name, img in slice_steampunk_city_bg(steampunk_city_sheet).items():
            out_path = os.path.join(steampunk_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        steampunk_city_props_dir = os.path.join(OUT_ROOT, "regions", "steampunk_city", "props")
        for name, img in slice_steampunk_city_props(steampunk_city_sheet).items():
            out_path = os.path.join(steampunk_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {STEAMPUNK_CITY_SHEET} not found, skipping steampunk_city region slicing")

    # --- 賽博龐克霓虹夜城（接手任務：steampunk_city 管線推廣，`design/future_city.png`）：
    # 排進 15 地域循環，`FYW_DEBUG_REGION=future_city` 可直接截圖驗收。---
    if os.path.exists(FUTURE_CITY_SHEET):
        future_city_sheet = decode_png(FUTURE_CITY_SHEET)
        print(f"future_city_sheet: {future_city_sheet.width}x{future_city_sheet.height}")

        future_city_bg_dir = os.path.join(OUT_ROOT, "regions", "future_city", "bg")
        for name, img in slice_future_city_bg(future_city_sheet).items():
            out_path = os.path.join(future_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        future_city_props_dir = os.path.join(OUT_ROOT, "regions", "future_city", "props")
        for name, img in slice_future_city_props(future_city_sheet).items():
            out_path = os.path.join(future_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {FUTURE_CITY_SHEET} not found, skipping future_city region slicing")

    # --- 中世紀奇幻村莊（接手任務：holy_city 管線推廣，`design/village_layered.png`）：
    # 重新指回循環第一個地域（開場）`meadowOrigin`，`FYW_DEBUG_REGION=meadow_village`
    # 可直接截圖驗收。---
    if os.path.exists(MEADOW_VILLAGE_SHEET):
        meadow_village_sheet = decode_png(MEADOW_VILLAGE_SHEET)
        print(f"meadow_village_sheet: {meadow_village_sheet.width}x{meadow_village_sheet.height}")

        meadow_village_bg_dir = os.path.join(OUT_ROOT, "regions", "meadow_village", "bg")
        for name, img in slice_meadow_village_bg(meadow_village_sheet).items():
            out_path = os.path.join(meadow_village_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        meadow_village_props_dir = os.path.join(OUT_ROOT, "regions", "meadow_village", "props")
        for name, img in slice_meadow_village_props(meadow_village_sheet).items():
            out_path = os.path.join(meadow_village_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {MEADOW_VILLAGE_SHEET} not found, skipping meadow_village region slicing")

    # --- 歐式白金王國首都（接手任務：`RegionType.kingdom` 重新指回 layered 美術，
    # `design/city_layered_1.png`，`FYW_DEBUG_REGION=kingdom_city` 可直接截圖驗收）：
    # 重新排回 9→11 地域循環。---
    if os.path.exists(KINGDOM_CITY_SHEET):
        kingdom_city_sheet = decode_png(KINGDOM_CITY_SHEET)
        print(f"kingdom_city_sheet: {kingdom_city_sheet.width}x{kingdom_city_sheet.height}")

        kingdom_city_bg_dir = os.path.join(OUT_ROOT, "regions", "kingdom_city", "bg")
        for name, img in slice_kingdom_city_bg(kingdom_city_sheet).items():
            out_path = os.path.join(kingdom_city_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        kingdom_city_props_dir = os.path.join(OUT_ROOT, "regions", "kingdom_city", "props")
        for name, img in slice_kingdom_city_props(kingdom_city_sheet).items():
            out_path = os.path.join(kingdom_city_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {KINGDOM_CITY_SHEET} not found, skipping kingdom_city region slicing")

    # --- 森林樹屋村落（接手任務：`RegionType.village3` 重新指回 layered 美術，
    # `design/village3_layered.png`，`FYW_DEBUG_REGION=tree_village` 可直接截圖驗收）：
    # 重新排回 9→11 地域循環。---
    if os.path.exists(TREE_VILLAGE_SHEET):
        tree_village_sheet = decode_png(TREE_VILLAGE_SHEET)
        print(f"tree_village_sheet: {tree_village_sheet.width}x{tree_village_sheet.height}")

        tree_village_bg_dir = os.path.join(OUT_ROOT, "regions", "tree_village", "bg")
        for name, img in slice_tree_village_bg(tree_village_sheet).items():
            out_path = os.path.join(tree_village_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        tree_village_props_dir = os.path.join(OUT_ROOT, "regions", "tree_village", "props")
        for name, img in slice_tree_village_props(tree_village_sheet).items():
            out_path = os.path.join(tree_village_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {TREE_VILLAGE_SHEET} not found, skipping tree_village region slicing")

    # --- 白金浮空天空之城（接手任務：`RegionType.skyCity` 重新指回 layered 美術，
    # `design/sky_layered.png`，`FYW_DEBUG_REGION=sky_city_v2` 可直接截圖驗收）：
    # 重新排回循環尾端，作為壓軸地域。---
    if os.path.exists(SKY_CITY_V2_SHEET):
        sky_city_v2_sheet = decode_png(SKY_CITY_V2_SHEET)
        print(f"sky_city_v2_sheet: {sky_city_v2_sheet.width}x{sky_city_v2_sheet.height}")

        sky_city_v2_bg_dir = os.path.join(OUT_ROOT, "regions", "sky_city_v2", "bg")
        for name, img in slice_sky_city_v2_bg(sky_city_v2_sheet).items():
            out_path = os.path.join(sky_city_v2_bg_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")

        sky_city_v2_props_dir = os.path.join(OUT_ROOT, "regions", "sky_city_v2", "props")
        for name, img in slice_sky_city_v2_props(sky_city_v2_sheet).items():
            out_path = os.path.join(sky_city_v2_props_dir, f"{name}.png")
            encode_png(img, out_path)
            print(f"wrote {out_path} ({img.width}x{img.height})")
    else:
        print(f"note: {SKY_CITY_V2_SHEET} not found, skipping sky_city_v2 region slicing")


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
