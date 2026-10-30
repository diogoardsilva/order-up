"""Gera os sprites de pixel art do Order Up!

Correr com: python3 tools/make_sprites.py
Escreve PNGs em assets/sprites/.

Estilo: cores quentes, sombreado com luz de cima à esquerda e contorno castanho
escuro à volta de cada objeto. As personagens são mapas em texto (uma letra por
píxel, ver PALETTE) e o contorno é acrescentado automaticamente. Os píxeis
't'/'T' vão para uma camada separada (_tint) que o jogo pinta com a cor de cada
jogador ou cliente. O resto (chão, bancadas, comida) é desenhado por código.
"""
import math
import random
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
OUTLINE = "#3b2027"

# Rampas de cor, da mais clara para a mais escura.
WOOD = ["#f6c47a", "#e09a55", "#c0763a", "#94532a", "#6b3a1f"]
DARK_WOOD = ["#b8703f", "#94532a", "#7a4224", "#5c2f1b", "#432015"]
RED = ["#ffb08a", "#f2604a", "#d23a32", "#a02530", "#6e1a26"]
GREEN = ["#d4f28a", "#9ad655", "#5fae3a", "#3a7f2f", "#245226"]
CREAM = ["#fff8e6", "#f6e6c4", "#e6cfa0", "#c9a877", "#9c7b52"]
WHITE = ["#ffffff", "#f1eef6", "#d9d3e6", "#aaa2c0", "#7c7396"]
STEEL = ["#f2f6f8", "#c9d3dc", "#98a6b4", "#6a7888", "#47505e"]
IRON = ["#6b6470", "#4f4954", "#3a3540", "#2a262f", "#1d1a21"]
COPPER = ["#ffc58a", "#f0914e", "#c8652f", "#93421f", "#632a16"]
SOUP = ["#ffd08a", "#f59a45", "#e0702e", "#b04e22", "#7a3218"]
WATER = ["#c8f0ff", "#8fd3f0", "#5aaedb", "#3d7fb8"]
WALLPAPER = ["#9cc27a", "#86b064", "#6f9a52", "#587f42"]

PALETTE = {
    "w": WHITE[0], "W": WHITE[2], "V": WHITE[3],
    "s": "#ffd7a8", "S": "#efa877", "c": "#f48a7a", "e": "#3b2027", "m": "#b8504a",
    "p": "#4a3a5c", "P": "#352a45", "b": "#5c3420",
    "h": "#8a4e2a", "H": "#5e321c",
    "r": RED[2], "R": RED[3],
    "t": "#ffffff", "T": "#b4b4b4",
}
HAIR = [("#8a4e2a", "#5e321c"), ("#f2c45a", "#c88f32"), ("#3d3045", "#241c2b"), ("#d8642e", "#9e3e1c")]


def rgba(c, a=255):
    h = c.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), rgba(c) if isinstance(c, str) else c)

    def opaque(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.im.getpixel((x, y))[3] > 0

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def ellipse(self, cx, cy, rx, ry, ramp, light=(-0.55, -0.8), flat=False):
        """Elipse sombreada como uma esfera (ou plana, com borda escura)."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if d > 1.0:
                    continue
                if flat:
                    i = min(1 if d < 0.55 else 2, len(ramp) - 1)
                else:
                    shade = -(nx * light[0] + ny * light[1])
                    shade = shade * 0.8 + (1 - d) * 0.4
                    i = min(len(ramp) - 1, max(0, int((1.0 - shade) / 2.0 * len(ramp))))
                self.px(x, y, ramp[i])

    def outline(self, c=OUTLINE, diagonal=False):
        mask = [[self.opaque(x, y) for x in range(self.w)] for y in range(self.h)]
        dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            dirs += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if mask[y][x]:
                    continue
                for dx, dy in dirs:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and mask[yy][xx]:
                        self.px(x, y, c)
                        break
        return self

    def paste(self, other, ox, oy):
        self.im.alpha_composite(other.im, (ox, oy))

    def save(self, name):
        self.im.save(OUT / f"{name}.png")


def speckle(s, x, y, w, h, colors, n, rng):
    for _ in range(n):
        s.px(rng.randrange(x, x + w), rng.randrange(y, y + h), rng.choice(colors))


# --- Personagens ---------------------------------------------------------

def check(name, rows):
    width = len(rows[0])
    for i, row in enumerate(rows):
        assert len(row) == width, f"{name}: linha {i} tem {len(row)} em vez de {width}: {row!r}"


def sheet(name, frames_by_row, fw, fh, hair_rows=None, colors=None, with_tint=True):
    """Monta uma folha de sprites com contorno automático e camada _tint."""
    cols = max(len(r) for r in frames_by_row)
    base = Image.new("RGBA", (fw * cols, fh * len(frames_by_row)), (0, 0, 0, 0))
    tint = base.copy()
    for ry, frames in enumerate(frames_by_row):
        pal = dict(PALETTE)
        pal.update(colors or {})
        if hair_rows:
            pal["h"], pal["H"] = hair_rows[ry]
        for cx, rows in enumerate(frames):
            check(f"{name}[{ry},{cx}]", rows)
            assert len(rows) == fh and len(rows[0]) == fw, f"{name}[{ry},{cx}] tamanho errado"
            b, t = Spr(fw, fh), Spr(fw, fh)
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch == ".":
                        continue
                    (t if ch in "tT" else b).px(x, y, pal[ch])
            both = Spr(fw, fh)
            both.paste(b, 0, 0)
            both.paste(t, 0, 0)
            both.outline()
            # O contorno fica na camada base, por baixo da tinta.
            for y in range(fh):
                for x in range(fw):
                    if both.opaque(x, y) and not b.opaque(x, y) and not t.opaque(x, y):
                        b.px(x, y, OUTLINE)
            base.alpha_composite(b.im, (cx * fw, ry * fh))
            tint.alpha_composite(t.im, (cx * fw, ry * fh))
    base.save(OUT / f"{name}.png")
    if with_tint:
        tint.save(OUT / f"{name}_tint.png")


HAT = [
    "................",
    "....wwwwwwww....",
    "...wwwwwwwwwW...",
    "..wwwwwwwwwwWW..",
    "..wwwwwwwwwwWW..",
    "...WwwwwwwwWW...",
    "...VVVVVVVVVV...",
]
FACE_DOWN = [
    "...hssssssssh...",
    "...ssessssesS...",
    "...ssessssesS...",
    "...scsssssscS...",
    "....SssmmssS....",
    ".....SSSSSS.....",
]
FACE_UP = [
    "...hhhhhhhhhh...",
    "...hhhhhhhhhH...",
    "...hhhhhhhhhH...",
    "...hhhhhhhhHH...",
    "....HhhhhhhH....",
    ".....SSSSSS.....",
]
FACE_SIDE = [
    "...hhhhssssss...",
    "...hhhsssssess..",
    "...hhhsssssess..",
    "...hhSssssscss..",
    "....hSsssssSs...",
    ".....SSSSS......",
]
COAT_DOWN = [
    "...wwwttttwww...",
    "..wwwwwttwwwwW..",
    ".wwwwwVwwVwwwWW.",
    ".wwwttttttttwWW.",
    ".sWwttttttttWWs.",
    "..WwttttttttWW..",
    "...wTTTTTTTTW...",
]
COAT_UP = [
    "...wwwwwwwwww...",
    "..wwwwwwwwwwwW..",
    ".wwwwwwwwwwwwWW.",
    ".wwwwwtTtwwwwWW.",
    ".swwwwwtwwwwWWs.",
    "..WwwwwwwwwWW...",
    "...wwwwwwwwwW...",
]
COAT_SIDE = [
    "....wwwwwtt.....",
    "....wwwwwwtw....",
    "...wWwwwwwwtt...",
    "...wWwwwwwttt...",
    "...wWsswwtttt...",
    "...WWsswwttTT...",
    "....WWWWTTTT....",
]
LEGS_DOWN = [
    ["....pppppppP....", "....ppP..ppP....", "....bbb..bbb....", "................"],
    ["....pppppppP....", "....ppP...pP....", "....bbb.........", "................"],
    ["....pppppppP....", "....pP...ppP....", ".........bbb....", "................"],
]
LEGS_SIDE = [
    [".....ppppP......", ".....ppPpP......", ".....bbbbbb.....", "................"],
    ["....pppppPP.....", "...ppP...pP.....", "...bbb...bbb....", "................"],
    [".....ppppP......", "......ppP.......", "......bbbb......", "................"],
]


SKINS = {
    "clara": ("#ffd7a8", "#efa877"), "morena": ("#e8b07a", "#c8834f"),
    "media": ("#d39260", "#ac6a3c"), "escura": ("#97603c", "#74452a"),
}
## Personagens que se podem escolher no lobby: (pele, cabelo, cabelo comprido, bigode).
CHARACTERS = [
    ("clara", ("#8a4e2a", "#5e321c"), False, False),
    ("clara", ("#f2c45a", "#c88f32"), True, False),
    ("morena", ("#3d3045", "#241c2b"), False, True),
    ("escura", ("#2e2430", "#1a141c"), True, False),
    ("media", ("#d8642e", "#9e3e1c"), False, False),
    ("clara", ("#b07ad8", "#7e4fa6"), True, False),
]


def put(rows, x, y, ch):
    rows[y] = rows[y][:x] + ch + rows[y][x + 1:]


def chef_frames(long_hair, mustache):
    result = []
    for d, (face, coat, legs) in enumerate([(FACE_DOWN, COAT_DOWN, LEGS_DOWN), (FACE_UP, COAT_UP, LEGS_DOWN),
                                            (FACE_SIDE, COAT_SIDE, LEGS_SIDE)]):
        frames = []
        for leg in legs:
            rows = list(HAT + face + coat + leg)
            if long_hair:
                if d == 0:
                    for y in range(7, 12):
                        put(rows, 2, y, "h"); put(rows, 13, y, "H")
                elif d == 1:
                    for y in (12, 13, 14):
                        for x in range(5, 11):
                            put(rows, x, y, "h" if y < 14 else "H")
                else:
                    for y in range(7, 13):
                        put(rows, 2, y, "h")
                    put(rows, 3, 13, "H"); put(rows, 3, 12, "h")
            if mustache and d == 0:
                put(rows, 6, 10, "H"); put(rows, 7, 10, "H"); put(rows, 8, 10, "H"); put(rows, 9, 10, "H")
            if mustache and d == 2:
                put(rows, 11, 11, "H"); put(rows, 12, 11, "H")
            frames.append(rows)
        result.append(frames)
    return result


def chef_sheet():
    for i, (skin, hair, long_hair, mustache) in enumerate(CHARACTERS):
        colors = {"s": SKINS[skin][0], "S": SKINS[skin][1], "h": hair[0], "H": hair[1]}
        sheet(f"chef_{i}", chef_frames(long_hair, mustache), 16, 24, colors=colors, with_tint=(i == 0))
    (OUT / "chef_0_tint.png").replace(OUT / "chef_tint.png")


CUSTOMER_HAIR = [
    [  # curto
        "................",
        "....hhhhhhhh....",
        "...hhhhhhhhhH...",
        "...hhhhhhhhhH...",
        "...hhsssssshH...",
        "...hsessssesH...",
        "...ssessssesS...",
        "...scsssssscS...",
        "....SssmmssS....",
        ".....SSSSSS.....",
    ],
    [  # comprido
        "................",
        "....hhhhhhhh....",
        "...hhhhhhhhhH...",
        "..hhhhhhhhhhhH..",
        "..hhhsssssshhH..",
        "..hssessssesSh..",
        "..hssessssesSh..",
        "..hscsssssscSh..",
        "..h.SssmmssS.H..",
        "..h..SSSSSS..H..",
    ],
    [  # carrapito
        "......hhhh......",
        "....hhhhhhhh....",
        "...hhhhhhhhhH...",
        "...hhhhhhhhhH...",
        "...hsssssssshH..",
        "...hsessssesH...",
        "...ssessssesS...",
        "...scsssssscS...",
        "....SssmmssS....",
        ".....SSSSSS.....",
    ],
    [  # boné
        "................",
        "....rrrrrrrr....",
        "...rrrrrrrrrR...",
        "...rrrrrrrrrrrr.",
        "...hhsssssshH...",
        "...hsessssesH...",
        "...ssessssesS...",
        "...scsssssscS...",
        "....SssmmssS....",
        ".....SSSSSS.....",
    ],
]
CUSTOMER_BODY = [
    "...tttssstttt...",
    "..tttttttttttT..",
    ".ttttttttttttTT.",
    ".tttttttttttTTT.",
    ".sttttttttttTTs.",
    "..TttttttttTTT..",
    "...pppppppPP....",
]
CUSTOMER_LEGS = [
    ["....pppppppP....", "....ppP..ppP....", "....bbb..bbb....", "................", "................"],
    ["....pppppppP....", "....ppP...pP....", "....bbb.........", "................", "................"],
    ["....pppppppP....", "....pP...ppP....", ".........bbb....", "................", "................"],
    ["...ppppppppPP...", "...pPpppppppP...", "...bb......bb...", "................", "................"],
]


def customer_sheet():
    rows = [[hair + CUSTOMER_BODY + legs for legs in CUSTOMER_LEGS] for hair in CUSTOMER_HAIR]
    sheet("customer", rows, 16, 22, hair_rows=HAIR)


# --- Comida e pratos -------------------------------------------------------

def tomato():
    s = Spr(14, 14)
    s.ellipse(7, 8, 5.6, 5.0, RED)
    s.px(4, 6, RED[0]); s.px(5, 5, "#ffffff"); s.px(4, 5, RED[0])
    for x, y in [(6, 3), (7, 3), (8, 3), (5, 4), (9, 4), (7, 2)]:
        s.px(x, y, GREEN[2])
    s.px(7, 3, GREEN[3]); s.px(7, 1, GREEN[3])
    return s.outline()


def lettuce():
    s = Spr(15, 14)
    s.ellipse(7.5, 7.5, 6.2, 5.6, GREEN)
    rng = random.Random(3)
    for a in range(0, 360, 40):
        r = math.radians(a)
        for t in range(1, 5):
            s.px(int(7.5 + math.cos(r) * t), int(7.5 + math.sin(r) * t * 0.9), GREEN[0] if t < 3 else GREEN[1])
    for x, y in [(3, 4), (11, 5), (4, 10), (10, 10), (7, 3)]:
        s.px(x, y, GREEN[3])
    speckle(s, 4, 4, 7, 7, [GREEN[0]], 3, rng)
    return s.outline()


def tomato_chopped():
    s = Spr(12, 11)
    for cx, cy in [(3.5, 3.5), (8.5, 4.5), (5.5, 8)]:
        s.ellipse(cx, cy, 2.8, 2.4, RED, flat=True)
        s.px(int(cx), int(cy), "#ffd0a0")
        s.px(int(cx) - 1, int(cy), RED[0])
    return s.outline()


def lettuce_chopped():
    s = Spr(12, 11)
    for cx, cy in [(3.5, 3.5), (8.5, 3.5), (6, 7.5), (3, 8)]:
        s.ellipse(cx, cy, 2.6, 2.0, GREEN, flat=True)
        s.px(int(cx), int(cy) - 1, GREEN[0])
    return s.outline()


def soup():
    s = Spr(13, 9)
    s.ellipse(6.5, 4.5, 5.5, 3.6, SOUP, flat=True)
    for x, y in [(4, 3), (5, 3), (4, 4)]:
        s.px(x, y, SOUP[0])
    s.px(8, 5, GREEN[2]); s.px(9, 5, GREEN[1]); s.px(8, 4, GREEN[1])
    return s.outline()


def plate():
    s = Spr(18, 13)
    s.ellipse(9, 6.5, 8, 5.6, ["#ffffff", "#f1eef6", "#7fa8d8"], flat=True)
    s.ellipse(9, 6.8, 5.2, 3.4, ["#ffffff", "#f6f3fa", "#e3dfec"], flat=True)
    for x in range(4, 14):
        s.px(x, 11, WHITE[3])
    s.px(5, 3, "#ffffff"); s.px(6, 2, "#ffffff")
    return s.outline()


def dirt():
    s = Spr(18, 13)
    rng = random.Random(9)
    for cx, cy in [(6, 5), (11, 7), (8, 9), (12, 4)]:
        for _ in range(5):
            s.px(cx + rng.randint(-1, 1), cy + rng.randint(-1, 1), rng.choice(["#8a5a32", "#6b4022", "#a87a45"]))
    return s


def bubble():
    s = Spr(24, 22)
    for y in range(1, 17):
        for x in range(1, 23):
            corner = (x in (1, 22) and y in (1, 16))
            if not corner:
                s.px(x, y, CREAM[0] if y < 13 else CREAM[1])
    for i, w in enumerate([6, 4, 2]):
        s.hline(9 + i, 17 + i, w - i, CREAM[1])
    s.outline()
    return s


# --- Chão e paredes -------------------------------------------------------

def wood_floor():
    """Soalho de tábuas, 4x4 células (96x96) para não se ver a repetição."""
    W = H = 96
    ph = 6
    s = Spr(W, H)
    rng = random.Random(7)
    tones = [("#d99558", "#c98448", "#e8a866"), ("#cf8a4e", "#bb773f", "#dea062"), ("#e0a060", "#cc8a4c", "#efb574")]
    for row in range(H // ph):
        y0 = row * ph
        x = rng.randrange(W)
        covered = 0
        while covered < W:
            length = min(rng.randint(22, 44), W - covered)
            base, grain, light = rng.choice(tones)
            for i in range(length):
                xx = (x + i) % W
                for dy in range(ph):
                    c = base
                    if dy == 0:
                        c = light
                    elif dy == ph - 1:
                        c = "#8a4f2a"
                    s.px(xx, y0 + dy, c)
                if rng.random() < 0.18:
                    s.px(xx, y0 + rng.randint(1, ph - 2), grain)
            s.vline((x + length - 1) % W, y0, ph, "#8a4f2a")
            if rng.random() < 0.5:
                s.px((x + 2) % W, y0 + 2, "#7a4222")
            x += length
            covered += length
    return s


def tile_floor():
    """Mosaico da cozinha em xadrez creme/ocre com relevo, 2x2 células."""
    s = Spr(48, 48)
    rng = random.Random(11)
    for j in range(4):
        for i in range(4):
            x, y = i * 12, j * 12
            ramp = ["#fbefd6", "#f2e0bd", "#dcc49a"] if (i + j) % 2 == 0 else ["#f0d8ae", "#e8cc9e", "#cfae80"]
            s.rect(x, y, 12, 12, ramp[1])
            s.hline(x, y, 12, ramp[0]); s.vline(x, y, 12, ramp[0])
            s.hline(x, y + 11, 12, ramp[2]); s.vline(x + 11, y, 12, ramp[2])
            speckle(s, x + 2, y + 2, 8, 8, [ramp[0], ramp[2]], 3, rng)
    return s


def wall_top():
    """Topo das paredes do salão (vigas de madeira escura)."""
    s = Spr(24, 24)
    s.rect(0, 0, 24, 24, DARK_WOOD[2])
    for x in range(0, 24, 6):
        s.vline(x, 0, 24, DARK_WOOD[4])
        s.vline(x + 1, 0, 24, DARK_WOOD[1])
    rng = random.Random(5)
    speckle(s, 0, 0, 24, 24, [DARK_WOOD[3], DARK_WOOD[1]], 18, rng)
    return s


def wall_front():
    """Parede vista de frente: topo de madeira, papel de parede às riscas e lambrim."""
    s = wall_top()
    s.hline(0, 7, 24, DARK_WOOD[0])
    s.hline(0, 8, 24, OUTLINE)
    for y in range(9, 18):
        for x in range(24):
            s.px(x, y, WALLPAPER[0] if (x // 3) % 2 == 0 else WALLPAPER[1])
    for x in range(1, 24, 6):
        s.px(x, 12, "#f6e6c4"); s.px(x + 3, 15, "#f6e6c4")
    s.hline(0, 18, 24, WOOD[0])
    s.rect(0, 19, 24, 4, WOOD[2])
    for x in range(0, 24, 8):
        s.vline(x, 19, 4, WOOD[3])
    s.hline(0, 23, 24, WOOD[4])
    return s


def backwall_kitchen():
    """Azulejos brancos atrás da cozinha (faixa acima da primeira fila)."""
    s = Spr(24, 22)
    s.rect(0, 0, 24, 22, "#c9bfae")
    for row in range(0, 22, 5):
        off = 0 if (row // 5) % 2 == 0 else 4
        for x in range(-8 + off, 24, 8):
            for yy in range(row, min(row + 4, 22)):
                for xx in range(max(x, 0), min(x + 7, 24)):
                    s.px(xx, yy, "#f8f4ec" if yy == row else "#ece5d8")
    s.hline(0, 0, 24, DARK_WOOD[2]); s.hline(0, 1, 24, DARK_WOOD[0])
    return s


def window():
    s = Spr(18, 14)
    s.rect(0, 0, 18, 14, CREAM[1])
    s.rect(2, 2, 14, 10, "#a8dcf0")
    s.rect(2, 2, 14, 4, "#c8ecf8")
    s.vline(8, 2, 10, CREAM[1]); s.vline(9, 2, 10, CREAM[2])
    s.hline(2, 7, 14, CREAM[1])
    s.px(4, 3, "#ffffff"); s.px(5, 3, "#ffffff"); s.px(11, 4, "#ffffff")
    s.hline(0, 13, 18, CREAM[3])
    return s.outline()


def plant():
    s = Spr(16, 20)
    rng = random.Random(4)
    for cx, cy, r in [(8, 6, 4.5), (4.5, 8, 3.4), (11.5, 8, 3.4), (8, 3, 3)]:
        s.ellipse(cx, cy, r, r * 0.9, GREEN)
    speckle(s, 3, 2, 10, 8, [GREEN[0]], 6, rng)
    s.rect(4, 12, 8, 6, COPPER[2])
    s.hline(3, 11, 10, COPPER[1]); s.hline(3, 12, 10, COPPER[0])
    s.vline(4, 13, 5, COPPER[1]); s.vline(11, 13, 5, COPPER[3])
    return s.outline()


def shelf():
    """Prateleira com frascos para pôr na parede da cozinha."""
    s = Spr(22, 12)
    s.rect(0, 9, 22, 2, WOOD[2]); s.hline(0, 9, 22, WOOD[0])
    for x, col, h in [(2, RED, 6), (7, GREEN, 7), (12, COPPER, 5), (17, ["#fff3c0", "#f2d06a", "#c89a3a"], 6)]:
        s.rect(x, 9 - h, 4, h, "#dfeef2")
        s.rect(x, 9 - h + 2, 4, h - 2, col[1])
        s.vline(x, 9 - h + 2, h - 2, col[0])
        s.hline(x, 9 - h, 4, WOOD[3])
    return s.outline()


# --- Mobília e estações (24x24: tampo em cima, frente em baixo) ------------

def counter():
    s = Spr(24, 24)
    rng = random.Random(1)
    # Tampo.
    s.hline(0, 0, 24, OUTLINE)
    s.rect(0, 1, 24, 14, WOOD[1])
    s.hline(0, 1, 24, WOOD[0])
    s.hline(0, 8, 24, WOOD[2])
    s.hline(0, 9, 24, WOOD[0])
    for _ in range(14):
        x, y = rng.randrange(24), rng.choice([3, 4, 5, 6, 11, 12, 13])
        s.hline(x, y, rng.randint(2, 4), WOOD[2])
    s.hline(0, 14, 24, WOOD[0])
    s.hline(0, 15, 24, OUTLINE)
    # Frente (armário).
    s.rect(0, 16, 24, 7, WOOD[3])
    s.rect(3, 17, 18, 5, WOOD[2])
    s.hline(3, 17, 18, WOOD[3]); s.vline(3, 17, 5, WOOD[3])
    s.px(18, 19, CREAM[1]); s.px(18, 20, CREAM[3])
    s.vline(0, 16, 7, WOOD[4]); s.vline(23, 16, 7, WOOD[4])
    s.hline(0, 23, 24, OUTLINE)
    return s


def stove():
    s = Spr(24, 24)
    s.hline(0, 0, 24, OUTLINE)
    s.rect(0, 1, 24, 14, IRON[2])
    s.hline(0, 1, 24, IRON[0])
    s.rect(1, 2, 22, 12, IRON[1])
    for r, c in [(7.5, IRON[4]), (6, IRON[3]), (4.5, IRON[4]), (2.5, IRON[2])]:
        s.ellipse(12, 8, r, r * 0.62, [c], flat=False)
    s.hline(0, 14, 24, IRON[0])
    s.hline(0, 15, 24, OUTLINE)
    s.rect(0, 16, 24, 7, IRON[2])
    s.rect(4, 17, 16, 4, "#5a3a2a")
    s.rect(5, 18, 14, 2, "#e0703f")
    s.hline(5, 18, 14, "#f6b45a")
    for x in (1, 21):
        s.px(x, 18, STEEL[1]); s.px(x + 1, 18, STEEL[3])
    s.hline(0, 23, 24, OUTLINE)
    return s


def board():
    s = Spr(24, 24)
    s.rect(3, 3, 16, 10, CREAM[1])
    s.hline(3, 3, 16, CREAM[0]); s.hline(3, 12, 16, CREAM[3])
    s.vline(18, 3, 10, CREAM[2])
    for x, y in [(6, 6), (10, 9), (14, 5), (8, 10)]:
        s.hline(x, y, 3, CREAM[2])
    # Faca.
    s.hline(15, 14, 6, STEEL[1]); s.hline(15, 15, 6, STEEL[3])
    s.hline(20, 14, 3, DARK_WOOD[1]); s.hline(20, 15, 3, DARK_WOOD[3])
    out = Spr(24, 24)
    out.paste(s, 0, 0)
    return out.outline()


def pot():
    s = Spr(20, 14)
    s.rect(3, 4, 14, 8, COPPER[2])
    s.vline(3, 4, 8, COPPER[1]); s.vline(4, 4, 8, COPPER[0]); s.vline(16, 4, 8, COPPER[3])
    s.hline(4, 11, 12, COPPER[3])
    s.ellipse(10, 4, 7.5, 2.8, [COPPER[1]], flat=False)
    s.ellipse(10, 4, 6, 1.9, ["#3a2420"], flat=False)
    for x in (0, 1):
        s.px(x, 6, COPPER[3]); s.px(19 - x, 6, COPPER[3])
    return s.outline()


def sink():
    s = counter()
    s.rect(4, 2, 16, 11, STEEL[3])
    s.rect(5, 3, 14, 9, STEEL[2])
    s.hline(5, 3, 14, STEEL[4])
    s.rect(6, 8, 12, 4, WATER[2])
    s.hline(6, 8, 12, WATER[1])
    s.px(8, 9, WATER[0]); s.px(14, 10, WATER[0])
    # Torneira.
    s.vline(11, 0, 3, STEEL[1]); s.vline(12, 0, 3, STEEL[3]); s.hline(10, 0, 4, STEEL[0])
    return s


def register():
    """Balcão com a caixa registadora em cima."""
    s = Spr(24, 24)
    base = counter()
    s.paste(base, 0, 0)
    # Máquina: corpo de latão, visor verde, teclas e gaveta.
    m = Spr(18, 15)
    m.rect(1, 5, 16, 9, COPPER[2])
    m.hline(1, 5, 16, COPPER[0]); m.vline(1, 5, 9, COPPER[1]); m.vline(16, 5, 9, COPPER[3])
    m.hline(1, 13, 16, COPPER[4])
    for x in range(3, 15, 3):
        for y in (7, 9):
            m.rect(x, y, 2, 1, CREAM[1])
    m.rect(9, 1, 7, 4, IRON[2])
    m.rect(10, 2, 5, 2, "#6fcf6a"); m.hline(10, 2, 5, "#b8f2a0")
    m.rect(2, 11, 14, 2, COPPER[3]); m.px(9, 11, CREAM[0])
    m.outline()
    s.paste(m, 3, 0)
    return s


def trash():
    s = Spr(24, 24)
    s.rect(4, 6, 16, 16, STEEL[2])
    s.vline(4, 6, 16, STEEL[1]); s.vline(5, 6, 16, STEEL[0]); s.vline(19, 6, 16, STEEL[4])
    for x in (8, 12, 16):
        s.vline(x, 9, 11, STEEL[3])
    s.hline(4, 21, 16, STEEL[4])
    s.ellipse(12, 5, 9, 3, [STEEL[1], STEEL[1], STEEL[2]], flat=True)
    s.rect(10, 1, 4, 2, STEEL[3]); s.hline(10, 1, 4, STEEL[1])
    return s.outline()


def crate():
    s = Spr(24, 18)
    s.rect(1, 1, 22, 15, WOOD[2])
    s.rect(3, 3, 18, 9, "#5a3220")
    for y in (1, 12):
        s.hline(1, y, 22, WOOD[0])
        s.hline(1, y + 1, 22, WOOD[1])
    s.hline(1, 15, 22, WOOD[3])
    s.vline(1, 1, 15, WOOD[1]); s.vline(22, 1, 15, WOOD[3])
    s.px(3, 13, WOOD[4]); s.px(20, 13, WOOD[4])
    return s.outline()


def table():
    s = Spr(24, 24)
    # Toalha.
    s.rect(1, 2, 22, 13, CREAM[0])
    s.hline(1, 2, 22, "#ffffff")
    s.rect(1, 15, 22, 4, CREAM[1])
    for x in range(1, 23, 4):
        s.vline(x, 15, 4, CREAM[2])
    s.hline(1, 18, 22, CREAM[3])
    for x in range(2, 23, 4):
        s.px(x, 19, CREAM[2])
    # Pernas.
    s.rect(3, 19, 2, 4, DARK_WOOD[2]); s.rect(19, 19, 2, 4, DARK_WOOD[2])
    s.outline()
    # Florzinha num jarro.
    s.rect(18, 4, 2, 3, "#9cc2e0"); s.px(18, 3, RED[1]); s.px(19, 2, RED[1]); s.px(20, 3, RED[1])
    s.px(19, 3, "#ffe08a")
    return s


def chair():
    s = Spr(24, 24)
    s.rect(6, 3, 12, 2, WOOD[1]); s.hline(6, 3, 12, WOOD[0])
    s.rect(6, 5, 2, 9, WOOD[2]); s.rect(16, 5, 2, 9, WOOD[2])
    s.rect(9, 6, 2, 6, WOOD[2]); s.rect(13, 6, 2, 6, WOOD[2])
    s.rect(5, 13, 14, 4, WOOD[1]); s.hline(5, 13, 14, WOOD[0]); s.hline(5, 16, 14, WOOD[3])
    s.rect(6, 17, 2, 5, WOOD[3]); s.rect(16, 17, 2, 5, WOOD[3])
    return s.outline()


def door():
    s = Spr(24, 24)
    s.rect(0, 0, 24, 24, DARK_WOOD[3])
    s.rect(3, 0, 18, 24, "#d99558")
    for y in range(0, 24, 6):
        s.hline(3, y + 5, 18, "#8a4f2a")
    s.rect(5, 6, 14, 12, RED[3])
    s.rect(6, 7, 12, 10, RED[2])
    for x in range(7, 17, 3):
        s.vline(x, 8, 8, RED[1])
    s.vline(0, 0, 24, OUTLINE); s.vline(23, 0, 24, OUTLINE)
    return s


# --- Interface (guardada a 2x: cada píxel da arte ocupa 2x2 no ecrã) ---------

def x2(spr):
    out = Spr(spr.w * 2, spr.h * 2)
    out.im = spr.im.resize((spr.w * 2, spr.h * 2), Image.NEAREST)
    return out


def ui_panel():
    """Moldura de madeira com papel creme por dentro (9-slice, margem 6)."""
    s = Spr(16, 16)
    s.rect(0, 0, 16, 16, OUTLINE)
    s.rect(1, 1, 14, 14, WOOD[2])
    s.hline(1, 1, 14, WOOD[0]); s.vline(1, 1, 14, WOOD[1])
    s.hline(1, 14, 14, WOOD[4]); s.vline(14, 1, 14, WOOD[3])
    s.rect(4, 4, 8, 8, CREAM[1])
    s.hline(4, 4, 8, CREAM[3]); s.vline(4, 4, 8, CREAM[3])
    s.hline(4, 11, 8, CREAM[0]); s.vline(11, 4, 8, CREAM[0])
    s.rect(5, 5, 6, 6, CREAM[1])
    for x, y in [(2, 2), (13, 2), (2, 13), (13, 13)]:
        s.px(x, y, CREAM[3])
    return s


def ui_paper():
    s = Spr(12, 12)
    s.rect(0, 0, 12, 12, OUTLINE)
    s.rect(1, 1, 10, 10, CREAM[1])
    s.hline(1, 1, 10, CREAM[0]); s.hline(1, 10, 10, CREAM[2])
    for x in (0, 11):
        for y in (0, 11):
            s.px(x, y, (0, 0, 0, 0))
    return s


def ui_button(state):
    """Botão de madeira: 0 normal, 1 com foco, 2 carregado."""
    s = Spr(16, 12)
    ramp = WOOD if state != 1 else ["#ffe0a0", "#f6c47a", "#e09a55", "#c0763a", "#94532a"]
    top = 1 if state == 2 else 0
    s.rect(0, top, 16, 12 - top, OUTLINE)
    s.rect(1, top + 1, 14, 9 - top, ramp[1])
    s.hline(1, top + 1, 14, ramp[0])
    s.rect(1, 10, 14, 1, ramp[3])
    if state != 2:
        s.hline(1, 9, 14, ramp[2])
    for x in (0, 15):
        s.px(x, top, (0, 0, 0, 0)); s.px(x, 11, (0, 0, 0, 0))
    if state == 1:
        s.px(2, top + 2, "#ffffff")
    return s


def star(full):
    s = Spr(13, 13)
    pts = []
    for i in range(10):
        r = 6.0 if i % 2 == 0 else 2.6
        a = math.radians(-90 + i * 36)
        pts.append((6.5 + math.cos(a) * r, 6.8 + math.sin(a) * r))
    from PIL import ImageDraw
    d = ImageDraw.Draw(s.im)
    d.polygon(pts, fill=rgba("#f6c444" if full else "#9c7b52"))
    if full:
        s.px(5, 4, "#fff3b0"); s.px(4, 5, "#fff3b0"); s.px(5, 5, "#ffe070")
    return s.outline()


def arrow():
    s = Spr(6, 9)
    for i in range(4):
        s.vline(1 + i, 1 + i, 7 - 2 * i, CREAM[0] if i < 2 else CREAM[1])
    return s.outline()


def clock():
    s = Spr(12, 12)
    s.ellipse(6, 6, 5, 5, ["#ffffff", "#f6e6c4", "#e6cfa0"], flat=True)
    s.vline(6, 3, 4, OUTLINE); s.hline(6, 6, 3, OUTLINE)
    return s.outline()


def coin():
    s = Spr(12, 12)
    s.ellipse(6, 6, 5, 5, ["#fff3b0", "#f6c444", "#d89a2a", "#a86a1a"])
    s.vline(6, 3, 6, "#a86a1a")
    return s.outline()


def cloche():
    """Campânula de prata em cima de um prato, para o logótipo do menu."""
    dome = Spr(30, 22)
    dome.ellipse(15, 16, 11, 11, STEEL, light=(-0.6, -0.7))
    s = Spr(30, 22)
    s.im.paste(dome.im.crop((0, 0, 30, 16)), (0, 0))
    s.rect(13, 3, 4, 2, STEEL[2]); s.hline(13, 3, 4, STEEL[0])
    s.px(9, 9, "#ffffff"); s.px(8, 10, "#ffffff"); s.px(8, 11, STEEL[0])
    s.ellipse(15, 17, 14, 3, [WHITE[0], WHITE[1], WHITE[2]], flat=True)
    s.hline(4, 16, 23, STEEL[3])
    return s.outline()


def sign():
    """Placa de madeira pendurada por duas cordas, para o nome no menu."""
    s = Spr(132, 64)
    for x in (22, 108):
        for y in range(0, 12):
            s.px(x + (y // 3) % 2, y, CREAM[3] if y % 2 else CREAM[2])
    board = Spr(132, 52)
    board.rect(1, 1, 130, 50, WOOD[2])
    rng = random.Random(21)
    for i, y in enumerate((1, 18, 35)):
        tone = [WOOD[1], WOOD[2], WOOD[1]][i]
        board.rect(1, y, 130, 16, tone)
        board.hline(1, y, 130, WOOD[0])
        board.hline(1, y + 15, 130, WOOD[4])
        for _ in range(16):
            board.hline(rng.randrange(2, 120), y + rng.randrange(3, 13), rng.randint(3, 9), WOOD[3])
    board.vline(1, 1, 50, WOOD[0]); board.vline(130, 1, 50, WOOD[4])
    for x, y in [(5, 5), (126, 5), (5, 46), (126, 46)]:
        board.px(x, y, STEEL[1]); board.px(x + 1, y + 1, STEEL[4])
    board.outline()
    s.paste(board, 0, 11)
    return s


# --- Comida dos restaurantes temáticos ---------------------------------------

BROWN = ["#e0a070", "#b8703f", "#8a4e2a", "#6b3a1f", "#4a2614"]
MEAT = ["#f6a0a0", "#e06a6a", "#c04848", "#902e36", "#64202a"]
COOKED = ["#d8945a", "#a8642e", "#844a22", "#5e321a", "#40200f"]
YOLK = ["#fff3b0", "#f6c444", "#e09a2a", "#b06a1a"]
GOLD = ["#fff0b0", "#f6d26a", "#e0a83a", "#b07a24", "#80521a"]
SALMON = ["#ffd0b0", "#f8a070", "#e47a4a", "#b85430"]
NORI = ["#4a6a4a", "#2f4a34", "#203626", "#14241a"]
CUKE = ["#c8f0a0", "#8fd06a", "#5aa84a", "#3a7a34"]
KALE = ["#9ad655", "#5fae3a", "#3a7f2f", "#245226", "#183a1c"]
RICE = ["#ffffff", "#f6f3ea", "#e4dccb", "#bfb49c"]
DOUGH = ["#fff2d0", "#f6dca8", "#e6c088", "#c49a64"]
SAUCE = ["#ff8a6a", "#e04a3f", "#b02e2e", "#7a1e22"]


def potato():
    s = Spr(13, 11)
    s.ellipse(6.5, 5.5, 5.5, 4.2, BROWN)
    for x, y in [(4, 4), (8, 6), (6, 7)]:
        s.px(x, y, BROWN[3])
    return s.outline()


def egg():
    s = Spr(10, 12)
    s.ellipse(5, 6.5, 3.8, 4.8, WHITE)
    s.px(3, 4, "#ffffff")
    return s.outline()


def steak():
    s = Spr(14, 11)
    s.ellipse(7, 5.5, 6, 4.2, MEAT)
    for x in range(3, 11):
        s.px(x, 3 + (x % 3 == 0), "#ffe6e0")
    return s.outline()


def cod():
    s = Spr(15, 10)
    s.ellipse(7, 5, 6.2, 3.4, ["#ffffff", "#ece6d8", "#d6ccb6", "#b4a88e"])
    s.px(13, 3, "#d6ccb6"); s.px(14, 2, "#b4a88e"); s.px(13, 7, "#d6ccb6"); s.px(14, 8, "#b4a88e")
    for x in (4, 7, 10):
        s.vline(x, 3, 4, "#c9bea6")
    return s.outline()


def kale():
    s = Spr(14, 13)
    for cx, cy in [(5, 5), (9, 5), (7, 8)]:
        s.ellipse(cx, cy, 4, 3.6, KALE)
    for x, y in [(4, 4), (9, 4), (7, 8), (6, 6)]:
        s.px(x, y, KALE[0])
    s.vline(7, 9, 3, "#c8e6a0")
    return s.outline()


def rice():
    """Saco de arroz."""
    s = Spr(12, 13)
    s.rect(2, 3, 8, 9, CREAM[2])
    s.vline(2, 3, 9, CREAM[1]); s.vline(9, 3, 9, CREAM[3])
    s.rect(3, 1, 6, 2, CREAM[3])
    s.rect(3, 6, 6, 3, RED[2])
    s.px(5, 7, "#ffffff"); s.px(6, 7, "#ffffff")
    return s.outline()


def salmon():
    s = Spr(15, 10)
    s.ellipse(7, 5, 6.2, 3.6, SALMON)
    for x in (4, 7, 10):
        s.px(x, 3, "#fff0e0"); s.px(x + 1, 4, "#fff0e0"); s.px(x, 5, "#fff0e0")
    return s.outline()


def nori():
    s = Spr(12, 10)
    s.rect(1, 1, 10, 8, NORI[1])
    s.hline(1, 1, 10, NORI[0]); s.vline(10, 1, 8, NORI[2])
    s.px(3, 4, NORI[0]); s.px(7, 6, NORI[0])
    return s.outline()


def cucumber():
    s = Spr(15, 8)
    s.ellipse(7.5, 4, 6.5, 2.6, CUKE[1:] + [CUKE[3]])
    for x in (4, 8, 11):
        s.px(x, 3, CUKE[0])
    return s.outline()


def bun():
    s = Spr(14, 10)
    s.ellipse(7, 6, 6, 4.2, GOLD)
    s.rect(1, 7, 12, 2, GOLD[2])
    for x, y in [(4, 4), (7, 3), (10, 4), (6, 5)]:
        s.px(x, y, "#fff8e6")
    return s.outline()


def patty():
    s = Spr(13, 9)
    s.ellipse(6.5, 4.5, 5.5, 3.4, MEAT, flat=True)
    for x, y in [(4, 4), (8, 3), (7, 5)]:
        s.px(x, y, MEAT[0])
    return s.outline()


def cheese():
    s = Spr(13, 10)
    for y in range(2, 9):
        w = 3 + (y - 2) * 1.4
        s.hline(1, y, int(w), YOLK[1] if y > 2 else YOLK[0])
    s.hline(1, 8, 10, YOLK[2])
    s.px(3, 6, YOLK[2]); s.px(6, 7, YOLK[2]); s.px(4, 4, YOLK[2])
    return s.outline()


def pasta():
    """Molho de esparguete cru."""
    s = Spr(14, 9)
    for y in range(2, 7):
        s.hline(1, y, 12, GOLD[1] if y % 2 else GOLD[2])
    s.rect(6, 1, 2, 7, RED[2])
    return s.outline()


def dough():
    s = Spr(13, 10)
    s.ellipse(6.5, 5.5, 5.5, 4, DOUGH)
    s.px(4, 4, "#ffffff")
    return s.outline()


def potato_chopped():
    s = Spr(12, 11)
    for x, y in [(1, 2), (5, 1), (8, 4), (3, 6), (7, 7)]:
        s.rect(x, y, 3, 3, "#f6e0a0"); s.px(x, y, "#fff4d0"); s.px(x + 2, y + 2, "#d8b870")
    return s.outline()


def cod_chopped():
    s = Spr(12, 11)
    for cx, cy in [(3.5, 3.5), (8, 3), (5.5, 7.5), (9, 7.5)]:
        s.ellipse(cx, cy, 2.4, 1.8, ["#ffffff", "#ece6d8", "#cfc4ac"], flat=True)
    return s.outline()


def salmon_chopped():
    s = Spr(13, 10)
    for x in (1, 5, 9):
        s.rect(x, 2, 3, 6, SALMON[1])
        s.vline(x, 2, 6, SALMON[0]); s.px(x + 1, 4, "#fff0e0"); s.px(x + 1, 6, "#fff0e0")
    return s.outline()


def cucumber_chopped():
    s = Spr(12, 11)
    for cx, cy in [(3.5, 3.5), (8.5, 4), (5.5, 7.5)]:
        s.ellipse(cx, cy, 2.6, 2.4, [CUKE[0], CUKE[0], CUKE[3]], flat=True)
        s.px(int(cx), int(cy), "#f0ffe0")
    return s.outline()


def cheese_chopped():
    s = Spr(12, 11)
    for x, y in [(1, 2), (6, 1), (3, 6), (8, 6)]:
        s.rect(x, y, 3, 3, YOLK[1]); s.px(x, y, YOLK[0]); s.px(x + 2, y + 2, YOLK[2])
    return s.outline()


def kale_chopped():
    s = Spr(12, 11)
    for i, (x, y) in enumerate([(1, 2), (2, 5), (1, 8), (6, 3), (5, 7)]):
        s.hline(x, y, 6, KALE[1] if i % 2 else KALE[2])
    return s.outline()


def steak_cooked():
    s = Spr(14, 11)
    s.ellipse(7, 5.5, 6, 4.2, COOKED)
    for x in (4, 7, 10):
        for d in range(4):
            s.px(x - d + 1, 3 + d, COOKED[4])
    return s.outline()


def egg_fried():
    s = Spr(14, 11)
    for cx, cy, r in [(6, 5.5, 4.6), (9, 6, 3.6), (5, 7, 3)]:
        s.ellipse(cx, cy, r, r * 0.8, ["#ffffff", "#ffffff", "#ece6f2"], flat=True)
    s.ellipse(7, 5, 2.4, 2.2, YOLK)
    return s.outline()


def fries():
    s = Spr(13, 12)
    rng = random.Random(8)
    for i in range(7):
        x = 1 + i * 1.6
        h = rng.randint(6, 9)
        s.rect(int(x), 11 - h, 2, h, GOLD[1] if i % 2 else GOLD[2])
        s.px(int(x), 11 - h, GOLD[0])
    return s.outline()


def bras():
    s = Spr(15, 11)
    s.ellipse(7.5, 5.5, 6.5, 4.4, ["#fff3b0", "#f6dc7a", "#e8c45a", "#c49a3a"], flat=True)
    rng = random.Random(12)
    for _ in range(12):
        s.px(rng.randint(3, 11), rng.randint(3, 7), rng.choice(["#fff8e0", "#d8a840"]))
    for x, y in [(5, 4), (10, 6)]:
        s.px(x, y, "#2a2030")
    for x, y in [(7, 3), (8, 7), (4, 6)]:
        s.px(x, y, GREEN[2])
    return s.outline()


def caldo():
    s = Spr(13, 9)
    s.ellipse(6.5, 4.5, 5.5, 3.6, ["#c8e890", "#9ac860", "#78a848", "#587f32"], flat=True)
    s.ellipse(4.5, 4, 1.4, 1.2, ["#e0503a"], flat=True)
    s.px(8, 5, KALE[2]); s.px(9, 4, KALE[2]); s.px(7, 3, KALE[1])
    return s.outline()


def rice_cooked():
    s = Spr(12, 9)
    s.ellipse(6, 5, 5, 3.6, RICE)
    for x, y in [(3, 3), (6, 2), (8, 4), (5, 5)]:
        s.px(x, y, "#ffffff")
    return s.outline()


def patty_cooked():
    s = Spr(13, 9)
    s.ellipse(6.5, 4.5, 5.5, 3.4, COOKED, flat=True)
    for x, y in [(4, 4), (8, 3), (7, 5)]:
        s.px(x, y, COOKED[0])
    return s.outline()


def pizza():
    s = Spr(16, 13)
    s.ellipse(8, 6.5, 7, 5.6, DOUGH[1:] + [DOUGH[3]], flat=True)
    s.ellipse(8, 6.5, 5.6, 4.4, SAUCE, flat=True)
    for cx, cy in [(6, 5), (10, 6), (7, 8), (9, 4)]:
        s.ellipse(cx, cy, 1.6, 1.3, ["#fff8e6", "#fff8e6", "#f6e6c4"], flat=True)
    s.px(8, 6, GREEN[2]); s.px(5, 7, GREEN[2]); s.px(11, 5, GREEN[2])
    return s.outline()


def pasta_cooked():
    s = Spr(14, 11)
    s.ellipse(7, 5.5, 6, 4.2, GOLD[:4], flat=True)
    for i in range(6):
        a = i * 1.1
        s.px(int(7 + math.cos(a) * 3), int(5.5 + math.sin(a) * 2), GOLD[3])
    s.ellipse(7, 4.5, 2.6, 1.8, SAUCE, flat=True)
    s.px(7, 3, GREEN[2])
    return s.outline()


def dish_burger():
    s = Spr(14, 13)
    s.ellipse(7, 4, 6, 3.4, GOLD)
    for x, y in [(4, 3), (7, 2), (10, 3)]:
        s.px(x, y, "#fff8e6")
    s.hline(1, 6, 12, KALE[0]); s.px(2, 7, KALE[1]); s.px(6, 7, KALE[1]); s.px(10, 7, KALE[1])
    s.rect(1, 7, 12, 2, COOKED[2])
    s.rect(1, 9, 12, 2, GOLD[2]); s.hline(1, 10, 12, GOLD[3])
    return s.outline()


def dish_cheeseburger():
    s = dish_burger()
    s2 = Spr(14, 13)
    s2.paste(s, 0, 0)
    s2.hline(1, 6, 12, YOLK[1]); s2.px(3, 7, YOLK[1]); s2.px(9, 7, YOLK[1])
    return s2


def dish_nigiri():
    s = Spr(16, 10)
    for x in (1, 8):
        s.rect(x, 4, 7, 4, RICE[1]); s.hline(x, 7, 7, RICE[3])
        s.rect(x, 2, 7, 3, SALMON[1]); s.hline(x, 2, 7, SALMON[0]); s.px(x + 2, 3, "#fff0e0"); s.px(x + 4, 3, "#fff0e0")
    return s.outline()


def dish_maki():
    s = Spr(16, 8)
    for x in (2.5, 8, 13.5):
        s.ellipse(x, 4, 2.6, 2.6, [NORI[1], NORI[1], NORI[2]], flat=True)
        s.ellipse(x, 4, 1.7, 1.7, ["#ffffff", "#ffffff", RICE[2]], flat=True)
        s.px(int(x), 4, CUKE[1])
    return s.outline()


def dish_bitoque():
    s = Spr(16, 12)
    for i in range(4):
        s.rect(11 + i, 3 + (i % 2), 1, 6, GOLD[1] if i % 2 else GOLD[2])
    s.ellipse(6, 7, 5.4, 3.8, COOKED)
    s.ellipse(6, 5.5, 3.6, 2.6, ["#ffffff", "#ffffff", "#ece6f2"], flat=True)
    s.ellipse(6, 5, 1.6, 1.4, YOLK)
    return s.outline()


def pan():
    s = Spr(22, 14)
    s.ellipse(9, 7, 8.5, 5.5, IRON[1:], flat=True)
    s.ellipse(9, 7, 6.5, 3.8, [IRON[3], IRON[3], IRON[2]], flat=True)
    s.rect(17, 6, 5, 2, DARK_WOOD[2]); s.hline(17, 6, 5, DARK_WOOD[1])
    return s.outline()


def oven():
    """Forno de lenha (pizza)."""
    s = Spr(22, 18)
    s.ellipse(11, 10, 10, 8, ["#e8956a", "#c8653f", "#a04a2e", "#7a3420"])
    s.rect(1, 12, 20, 5, "#a04a2e")
    for y in (6, 10, 14):
        for x in range(2 + (y // 4) % 2 * 2, 20, 5):
            s.px(x, y, "#7a3420")
    s.ellipse(11, 13, 5, 3.6, ["#2a1a14", "#3a2018", "#ff9a3a"], flat=True)
    s.hline(7, 16, 8, "#ffb04a")
    return s.outline()


FOOD = [
    potato, egg, steak, cod, kale, rice, salmon, nori, cucumber, bun, patty, cheese, pasta, dough,
    potato_chopped, cod_chopped, salmon_chopped, cucumber_chopped, cheese_chopped, kale_chopped,
    steak_cooked, egg_fried, fries, bras, caldo, rice_cooked, patty_cooked, pizza, pasta_cooked,
    dish_burger, dish_cheeseburger, dish_nigiri, dish_maki, dish_bitoque,
]


# --- Temas dos restaurantes (salão) ------------------------------------------

def _floor_checker(a, b, size=12):
    s = Spr(96, 96)
    rng = random.Random(31)
    for j in range(96 // size):
        for i in range(96 // size):
            c = a if (i + j) % 2 == 0 else b
            s.rect(i * size, j * size, size, size, c[1])
            s.hline(i * size, j * size, size, c[0]); s.hline(i * size, j * size + size - 1, size, c[2])
            speckle(s, i * size + 1, j * size + 1, size - 2, size - 2, [c[0], c[2]], 2, rng)
    return s


def floor_portugal():
    """Mosaico de pedra clara com losangos, como numa tasca."""
    s = _floor_checker(["#f4ead6", "#e8dcc2", "#cdbd9c"], ["#efe2c8", "#e2d2b2", "#c6b38e"])
    for j in range(0, 96, 24):
        for i in range(0, 96, 24):
            cx, cy = i + 12, j + 12
            for d in range(4):
                s.px(cx - d, cy - 3 + d, "#5a7fb8"); s.px(cx + d, cy - 3 + d, "#5a7fb8")
                s.px(cx - d, cy + 3 - d, "#5a7fb8"); s.px(cx + d, cy + 3 - d, "#5a7fb8")
    return s


def wall_front_portugal():
    """Azulejos azuis e brancos em baixo, cal em cima."""
    s = wall_top()
    s.hline(0, 7, 24, DARK_WOOD[0]); s.hline(0, 8, 24, OUTLINE)
    s.rect(0, 9, 24, 15, "#f6f8fc")
    for ty in (9, 15):
        for tx in (0, 6, 12, 18):
            s.rect(tx, ty, 6, 6, "#f6f8fc")
            s.hline(tx, ty, 6, "#9ab4dc"); s.vline(tx, ty, 6, "#9ab4dc")
            s.px(tx + 3, ty + 2, "#2f5aa8"); s.px(tx + 2, ty + 3, "#2f5aa8"); s.px(tx + 4, ty + 3, "#2f5aa8"); s.px(tx + 3, ty + 4, "#2f5aa8")
            s.px(tx + 1, ty + 1, "#5a7fb8"); s.px(tx + 5, ty + 5, "#5a7fb8")
    s.hline(0, 23, 24, "#2f5aa8")
    return s


def wall_deco_portugal():
    """Painel de azulejo com um galo de Barcelos."""
    s = Spr(20, 16)
    s.rect(0, 0, 20, 16, "#f6f8fc")
    for x in range(0, 20, 5):
        s.vline(x, 0, 16, "#c8d6ee")
    for y in range(0, 16, 5):
        s.hline(0, y, 20, "#c8d6ee")
    # Galo.
    s.ellipse(10, 9, 4, 3, ["#2a2030"], flat=True)
    s.rect(12, 4, 2, 4, "#2a2030"); s.px(13, 3, RED[2]); s.px(14, 3, RED[2]); s.px(14, 5, "#f6c444")
    s.px(7, 7, RED[2]); s.px(9, 8, "#f6c444"); s.px(11, 9, RED[2]); s.px(8, 10, "#2f8fd8")
    s.px(6, 6, "#2a2030"); s.px(5, 5, "#2a2030")
    s.vline(9, 12, 2, "#e09a2a"); s.vline(11, 12, 2, "#e09a2a")
    return s.outline()


def corner_deco_portugal():
    """Pipa de vinho."""
    s = Spr(16, 18)
    s.ellipse(8, 10, 7, 7.5, WOOD)
    for y in (5, 15):
        s.hline(2, y, 12, IRON[2])
    s.ellipse(8, 10, 2, 2, [DARK_WOOD[3]], flat=True)
    s.rect(7, 14, 2, 3, IRON[1])
    return s.outline()


def table_portugal(h=13):
    return table_cloth(["#ffffff", "#f1f4fa", "#c8d6ee", "#9ab4dc"], pattern="#2f5aa8", h=h)


def floor_japan():
    """Tatami: esteiras verde-palha com bordas escuras."""
    s = Spr(96, 96)
    for j in range(0, 96, 48):
        for i in range(0, 96, 24):
            vertical = ((i // 24) + (j // 48)) % 2 == 0
            w, h = (24, 48) if vertical else (24, 48)
            s.rect(i, j, w, h, "#d6d08a")
            for k in range(0, h, 2):
                s.hline(i, j + k, w, "#c8c07a")
            s.hline(i, j, w, "#4a5a3a"); s.hline(i, j + h - 1, w, "#4a5a3a")
            s.vline(i, j, h, "#6a7a4a")
    return s


def wall_front_japan():
    """Shoji: papel de arroz com grelha de madeira."""
    s = Spr(24, 24)
    s.rect(0, 0, 24, 8, DARK_WOOD[3]); s.hline(0, 7, 24, DARK_WOOD[1])
    s.hline(0, 8, 24, OUTLINE)
    s.rect(0, 9, 24, 12, "#fbf6e6")
    for x in (0, 8, 16):
        s.vline(x, 9, 12, DARK_WOOD[2])
    s.hline(0, 14, 24, DARK_WOOD[2])
    s.rect(0, 21, 24, 3, DARK_WOOD[3]); s.hline(0, 23, 24, DARK_WOOD[4])
    return s


def wall_top_japan():
    s = Spr(24, 24)
    s.rect(0, 0, 24, 24, DARK_WOOD[3])
    for x in range(0, 24, 8):
        s.vline(x, 0, 24, DARK_WOOD[4]); s.vline(x + 1, 0, 24, DARK_WOOD[2])
    return s


def wall_deco_japan():
    """Lanterna de papel vermelha."""
    s = Spr(14, 18)
    s.vline(7, 0, 3, OUTLINE)
    s.rect(5, 2, 4, 2, "#2a2030")
    s.ellipse(7, 9, 6, 6, ["#ff8a6a", "#e04a3f", "#b02e2e", "#7a1e22"])
    for y in (6, 9, 12):
        s.hline(2, y, 10, "#a02530")
    s.rect(5, 15, 4, 2, "#2a2030")
    s.vline(7, 17, 1, "#f6c444")
    return s.outline()


def corner_deco_japan():
    """Bonsai num vaso baixo."""
    s = Spr(16, 18)
    for cx, cy, r in [(5, 5, 3.5), (11, 4, 3), (8, 7, 3.4)]:
        s.ellipse(cx, cy, r, r * 0.8, GREEN)
    s.vline(8, 8, 5, DARK_WOOD[2]); s.px(7, 10, DARK_WOOD[2]); s.px(9, 9, DARK_WOOD[2])
    s.rect(2, 13, 12, 4, "#3a4a6a"); s.hline(2, 13, 12, "#5a6a8a")
    return s.outline()


def table_japan():
    """Mesa baixa de madeira escura."""
    s = Spr(24, 24)
    s.rect(1, 4, 22, 12, DARK_WOOD[1]); s.hline(1, 4, 22, DARK_WOOD[0]); s.hline(1, 15, 22, DARK_WOOD[3])
    for x in (5, 12, 18):
        s.hline(x, 8, 3, DARK_WOOD[2])
    s.rect(1, 16, 22, 3, DARK_WOOD[3])
    s.rect(2, 19, 3, 3, DARK_WOOD[4]); s.rect(19, 19, 3, 3, DARK_WOOD[4])
    s.outline()
    s.rect(17, 6, 3, 3, "#f6f3ea"); s.px(18, 6, "#2a2030")  # copo de chá
    return s


def chair_japan():
    """Almofada (zabuton)."""
    s = Spr(24, 24)
    s.rect(5, 10, 14, 10, "#b8304a"); s.hline(5, 10, 14, "#e0607a"); s.hline(5, 19, 14, "#7a1e30")
    s.px(12, 15, "#f6c444")
    return s.outline()


def floor_diner():
    return _floor_checker(["#ffffff", "#f1eef6", "#c9c3d6"], ["#3a3540", "#2a262f", "#1d1a21"])


def wall_front_diner():
    """Azulejo cor de menta com faixa cromada e vermelha."""
    s = Spr(24, 24)
    s.rect(0, 0, 24, 8, "#c8303a"); s.hline(0, 0, 24, "#e8606a"); s.hline(0, 7, 24, "#901e2a")
    s.hline(0, 8, 24, OUTLINE)
    s.rect(0, 9, 24, 10, "#9ee0d0")
    for x in range(0, 24, 6):
        s.vline(x, 9, 10, "#7cc4b4")
    s.hline(0, 14, 24, "#7cc4b4")
    s.hline(0, 19, 24, STEEL[0]); s.rect(0, 20, 24, 3, STEEL[2]); s.hline(0, 23, 24, STEEL[4])
    return s


def wall_top_diner():
    s = Spr(24, 24)
    s.rect(0, 0, 24, 24, "#c8303a")
    for x in range(0, 24, 6):
        s.vline(x, 0, 24, "#a02530")
    return s


def wall_deco_diner():
    """Letreiro de néon."""
    s = Spr(22, 12)
    s.rect(0, 0, 22, 12, "#241c2b")
    s.hline(2, 2, 18, "#ff6ad0"); s.hline(2, 9, 18, "#ff6ad0")
    s.vline(2, 2, 8, "#ff6ad0"); s.vline(19, 2, 8, "#ff6ad0")
    for x, col in [(5, "#6af0ff"), (9, "#ffe06a"), (13, "#6af0ff"), (16, "#ffe06a")]:
        s.rect(x, 4, 2, 4, col)
    return s.outline()


def corner_deco_diner():
    """Jukebox."""
    s = Spr(16, 20)
    s.ellipse(8, 6, 7, 6, ["#ffd06a", "#f0914e", "#c8652f", "#93421f"])
    s.rect(1, 6, 14, 12, "#c8652f")
    s.rect(3, 7, 10, 5, "#6af0ff"); s.hline(3, 7, 10, "#c8fcff")
    for x in (4, 7, 10):
        s.rect(x, 13, 2, 3, "#ff6ad0")
    return s.outline()


def table_diner():
    s = Spr(24, 24)
    s.rect(1, 3, 22, 13, "#f04a52"); s.hline(1, 3, 22, "#ff8a8a"); s.hline(1, 15, 22, "#a02530")
    s.rect(1, 16, 22, 2, STEEL[1]); s.hline(1, 17, 22, STEEL[3])
    s.rect(10, 18, 4, 5, STEEL[2])
    s.outline()
    s.rect(17, 5, 2, 4, "#e04a3f"); s.rect(20, 5, 2, 4, "#f6c444")  # ketchup e mostarda
    return s


def chair_diner():
    s = Spr(24, 24)
    s.rect(6, 3, 12, 12, "#d0303a"); s.hline(6, 3, 12, "#f06a6a")
    for x in (9, 12, 15):
        s.vline(x, 4, 10, "#a02530")
    s.rect(5, 13, 14, 4, "#d0303a"); s.hline(5, 13, 14, "#f06a6a"); s.hline(5, 16, 14, "#901e2a")
    s.rect(7, 17, 2, 5, STEEL[2]); s.rect(15, 17, 2, 5, STEEL[2])
    return s.outline()


def floor_italy():
    """Terracota em losango."""
    s = Spr(96, 96)
    rng = random.Random(41)
    for j in range(0, 96, 12):
        for i in range(0, 96, 12):
            c = ["#e8956a", "#d47a50", "#b0603c"] if (i // 12 + j // 12) % 3 else ["#f0a878", "#e08a5c", "#b86a44"]
            s.rect(i, j, 12, 12, c[1]); s.hline(i, j, 12, c[0]); s.vline(i, j, 12, c[0])
            s.hline(i, j + 11, 12, "#8a4a30"); s.vline(i + 11, j, 12, "#8a4a30")
            speckle(s, i + 2, j + 2, 8, 8, [c[0], c[2]], 2, rng)
    return s


def wall_front_italy():
    """Reboco amarelo com pedras à mostra e rodapé de tijolo."""
    s = Spr(24, 24)
    s.rect(0, 0, 24, 8, DARK_WOOD[2]); s.hline(0, 7, 24, DARK_WOOD[0])
    s.hline(0, 8, 24, OUTLINE)
    s.rect(0, 9, 24, 10, "#f2d08a")
    s.rect(3, 11, 5, 3, "#d8b070"); s.rect(15, 14, 6, 3, "#d8b070")
    s.rect(0, 19, 24, 5, "#b05a3a")
    for x in range(0, 24, 6):
        s.vline(x, 19, 5, "#8a3e28")
    s.hline(0, 21, 24, "#8a3e28")
    return s


def wall_top_italy():
    s = wall_top()
    return s


def wall_deco_italy():
    """Janela com portadas verdes e bandeirinhas."""
    s = Spr(22, 16)
    s.rect(4, 2, 14, 12, "#a8dcf0"); s.rect(4, 2, 14, 4, "#c8ecf8")
    s.vline(10, 2, 12, CREAM[1]); s.hline(4, 8, 14, CREAM[1])
    s.rect(0, 2, 4, 12, "#3a8a4a"); s.rect(18, 2, 4, 12, "#3a8a4a")
    for y in range(4, 13, 3):
        s.hline(0, y, 4, "#2a6a3a"); s.hline(18, y, 4, "#2a6a3a")
    for i, col in enumerate(["#3a9a4a", "#ffffff", "#e04a3f"] * 3):
        s.px(2 + i * 2, 0, col); s.px(2 + i * 2, 1, col)
    return s.outline()


def corner_deco_italy():
    """Oliveira num vaso de barro."""
    s = Spr(16, 20)
    for cx, cy, r in [(8, 5, 4.5), (4.5, 8, 3.2), (11.5, 7, 3.2)]:
        s.ellipse(cx, cy, r, r * 0.85, ["#c8d8a0", "#98b070", "#6a8a4a", "#4a6a34"])
    for x, y in [(6, 4), (10, 6), (4, 8)]:
        s.px(x, y, "#2a2030")
    s.vline(8, 10, 3, DARK_WOOD[2])
    s.rect(4, 13, 8, 5, "#c8653f"); s.hline(3, 12, 10, "#e8956a")
    return s.outline()


def table_italy(h=13):
    return table_cloth(["#ffffff", "#ffffff", "#f6e6e6", "#d8c0c0"], check="#d23a32", h=h)


def table_cloth(ramp, pattern=None, check=None, h=13):
    """Mesa com toalha (cores e padrão por tema). h é a altura do tampo."""
    s = Spr(24, 24 + (h - 13))
    s.rect(1, 2, 22, h, ramp[0])
    if check:
        for y in range(2, 2 + h):
            for x in range(1, 23):
                if ((x - 1) // 3 + (y - 2) // 3) % 2 == 0:
                    s.px(x, y, check)
    if pattern:
        for y in range(4, 2 + h, 4):
            for x in range(3, 22, 4):
                s.px(x, y, pattern)
    s.hline(1, 2, 22, "#ffffff")
    s.rect(1, 2 + h, 22, 4, ramp[1] if not check else "#e8e0e0")
    for x in range(1, 23, 4):
        s.vline(x, 2 + h, 4, ramp[2])
    s.hline(1, 5 + h, 22, ramp[3])
    s.rect(3, 6 + h, 2, 4, DARK_WOOD[2]); s.rect(19, 6 + h, 2, 4, DARK_WOOD[2])
    s.outline()
    s.rect(18, 4, 2, 3, "#9cc2e0"); s.px(18, 3, RED[1]); s.px(19, 2, RED[1]); s.px(20, 3, RED[1])
    return s


def tall(table_fn):
    """Versão para 4 pessoas (duas células de altura) de uma mesa."""
    small = table_fn()
    s = Spr(24, 48)
    top = small.im.crop((0, 0, 24, 10))
    mid = small.im.crop((0, 10, 24, 11))
    bottom = small.im.crop((0, 11, 24, 24))
    s.im.paste(top, (0, 0))
    for y in range(10, 35):
        s.im.paste(mid, (0, y))
    s.im.paste(bottom, (0, 35))
    return s


THEMES = {
    "classic": {"floor": lambda: wood_floor(), "wall_front": lambda: wall_front(), "wall_top": lambda: wall_top(),
                "wall_deco": lambda: window(), "corner_deco": lambda: plant(), "table": lambda: table(), "chair": lambda: chair()},
    "portugal": {"floor": floor_portugal, "wall_front": wall_front_portugal, "wall_top": lambda: wall_top(),
                 "wall_deco": wall_deco_portugal, "corner_deco": corner_deco_portugal, "table": table_portugal, "chair": lambda: chair()},
    "japan": {"floor": floor_japan, "wall_front": wall_front_japan, "wall_top": wall_top_japan,
              "wall_deco": wall_deco_japan, "corner_deco": corner_deco_japan, "table": table_japan, "chair": chair_japan},
    "diner": {"floor": floor_diner, "wall_front": wall_front_diner, "wall_top": wall_top_diner,
              "wall_deco": wall_deco_diner, "corner_deco": corner_deco_diner, "table": table_diner, "chair": chair_diner},
    "italy": {"floor": floor_italy, "wall_front": wall_front_italy, "wall_top": wall_top_italy,
              "wall_deco": wall_deco_italy, "corner_deco": corner_deco_italy, "table": table_italy, "chair": lambda: chair()},
}


def write_food_and_themes():
    (OUT / "food").mkdir(exist_ok=True)
    (OUT / "themes").mkdir(exist_ok=True)
    for name, fn in [("tomato", tomato), ("lettuce", lettuce), ("tomato_chopped", tomato_chopped),
                     ("lettuce_chopped", lettuce_chopped), ("soup", soup)]:
        fn().im.save(OUT / "food" / f"{name}.png")
    for fn in FOOD:
        fn().im.save(OUT / "food" / f"{fn.__name__}.png")
    pan().save("pan")
    oven().save("oven")
    for theme, parts in THEMES.items():
        for part, fn in parts.items():
            fn().im.save(OUT / "themes" / f"{theme}_{part}.png")
        # As toalhas com padrão desenham-se já altas (esticar estragava o padrão).
        big = parts["table"](h=37) if theme in ("portugal", "italy") else tall(parts["table"])
        big.im.save(OUT / "themes" / f"{theme}_table_big.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    chef_sheet()
    customer_sheet()
    for name, fn in [
        ("plate", plate), ("dirt", dirt),
        ("bubble", bubble), ("wood", wood_floor), ("floor", tile_floor), ("wall_top", wall_top),
        ("wall_front", wall_front), ("backwall_kitchen", backwall_kitchen), ("window", window),
        ("plant", plant), ("shelf", shelf), ("counter", counter), ("stove", stove), ("board", board),
        ("pot", pot), ("sink", sink), ("trash", trash), ("crate", crate), ("table", table),
        ("chair", chair), ("door", door), ("sign", sign), ("register", register),
    ]:
        fn().save(name)
    for name, fn in [
        ("ui_panel", ui_panel), ("ui_paper", ui_paper), ("ui_button", lambda: ui_button(0)),
        ("ui_button_focus", lambda: ui_button(1)), ("ui_button_pressed", lambda: ui_button(2)),
        ("star", lambda: star(True)), ("star_empty", lambda: star(False)), ("arrow", arrow),
        ("clock", clock), ("coin", coin), ("cloche", cloche),
    ]:
        x2(fn()).save(name)
    write_food_and_themes()
    print("Sprites escritos em", OUT)


if __name__ == "__main__":
    main()
