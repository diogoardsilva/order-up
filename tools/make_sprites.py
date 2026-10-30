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
                    i = 1 if d < 0.55 else 2
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


def sheet(name, frames_by_row, fw, fh, hair_rows=None):
    """Monta uma folha de sprites com contorno automático e camada _tint."""
    cols = max(len(r) for r in frames_by_row)
    base = Image.new("RGBA", (fw * cols, fh * len(frames_by_row)), (0, 0, 0, 0))
    tint = base.copy()
    for ry, frames in enumerate(frames_by_row):
        pal = dict(PALETTE)
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


def chef_sheet():
    rows = []
    for face, coat, legs in [(FACE_DOWN, COAT_DOWN, LEGS_DOWN), (FACE_UP, COAT_UP, LEGS_DOWN),
                             (FACE_SIDE, COAT_SIDE, LEGS_SIDE)]:
        rows.append([HAT + face + coat + leg for leg in legs])
    sheet("chef", rows, 16, 24)


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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    chef_sheet()
    customer_sheet()
    for name, fn in [
        ("tomato", tomato), ("lettuce", lettuce), ("tomato_chopped", tomato_chopped),
        ("lettuce_chopped", lettuce_chopped), ("soup", soup), ("plate", plate), ("dirt", dirt),
        ("bubble", bubble), ("wood", wood_floor), ("floor", tile_floor), ("wall_top", wall_top),
        ("wall_front", wall_front), ("backwall_kitchen", backwall_kitchen), ("window", window),
        ("plant", plant), ("shelf", shelf), ("counter", counter), ("stove", stove), ("board", board),
        ("pot", pot), ("sink", sink), ("trash", trash), ("crate", crate), ("table", table),
        ("chair", chair), ("door", door),
    ]:
        fn().save(name)
    print("Sprites escritos em", OUT)


if __name__ == "__main__":
    main()
