"""Gera os sprites de pixel art do Order Up! a partir de mapas em texto.

Correr com: python3 tools/make_sprites.py
Escreve PNGs em assets/sprites/. Cada mapa usa uma letra por pixel (ver PALETTE).
Os pixels 't'/'T' vão para uma camada separada (_tint) que o jogo pinta com a cor
de cada jogador ou cliente.
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"

PALETTE = {
    "o": "#2b2233",  # contorno
    "w": "#f4f0e8",  # branco
    "g": "#c7c0b4",  # cinzento claro
    "G": "#8a8590",  # cinzento
    "d": "#4a4a52",  # cinzento escuro
    "s": "#f1c27d",  # pele
    "S": "#d9a066",  # pele sombra
    "p": "#3d3248",  # calças
    "r": "#e04a3f",  # vermelho
    "R": "#a8323a",  # vermelho escuro
    "n": "#6cbf4a",  # verde
    "N": "#3f7d2e",  # verde escuro
    "l": "#a8e07a",  # verde claro
    "y": "#f2c94c",  # amarelo
    "a": "#e0703f",  # laranja (sopa)
    "A": "#b5532a",  # laranja escuro
    "b": "#b58a63",  # madeira clara
    "m": "#8c6a4f",  # madeira média
    "M": "#6b4f3a",  # madeira escura
    "c": "#e2c79a",  # tábua
    "k": "#1e1a1a",  # queimado
    "u": "#9fb8c8",  # água clara
    "U": "#5d8aa8",  # água escura
    "h": "#cbd3d8",  # metal claro
    "H": "#7f8a93",  # metal escuro
    "f": "#e3d8c6",  # mosaico claro
    "F": "#d2c5b0",  # mosaico escuro
    "t": "#ffffff",  # tinta (camada _tint)
    "T": "#b0b0b0",  # tinta sombra (camada _tint)
}


def rgba(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def check(name, rows):
    width = len(rows[0])
    for i, row in enumerate(rows):
        assert len(row) == width, f"{name}: linha {i} tem {len(row)} em vez de {width}: {row!r}"


def paint(img, rows, ox=0, oy=0, tint=False):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            is_tint = ch in "tT"
            if is_tint == tint:
                img.putpixel((ox + x, oy + y), rgba(PALETTE[ch]))


def save(name, rows):
    check(name, rows)
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    paint(img, rows)
    img.save(OUT / f"{name}.png")


def save_sheet(name, frames_by_row, with_tint):
    """frames_by_row: lista de linhas, cada uma com uma lista de frames (mapas)."""
    fw, fh = len(frames_by_row[0][0][0]), len(frames_by_row[0][0])
    cols = max(len(r) for r in frames_by_row)
    base = Image.new("RGBA", (fw * cols, fh * len(frames_by_row)), (0, 0, 0, 0))
    tint = base.copy()
    for ry, frames in enumerate(frames_by_row):
        for cx, frame in enumerate(frames):
            check(f"{name}[{ry},{cx}]", frame)
            paint(base, frame, cx * fw, ry * fh)
            paint(tint, frame, cx * fw, ry * fh, tint=True)
    base.save(OUT / f"{name}.png")
    if with_tint:
        tint.save(OUT / f"{name}_tint.png")


# --- Chef (16x22): 3 direções (baixo, cima, lado) x 3 frames (parado, passo A, passo B)

CHEF_HEAD_DOWN = [
    "....oooooooo....",
    "...owwwwwwwwo...",
    "..owwwwwwwgwwo..",
    "..owwgwwwwwwwo..",
    "...owwwwwwwwo...",
    "...oggggggggo...",
    "...osssssssso...",
    "...osossssoso...",
    "...osssssssso...",
    "....oSSssSSo....",
]
CHEF_HEAD_UP = [
    "....oooooooo....",
    "...owwwwwwwwo...",
    "..owwwwwwwgwwo..",
    "..owwgwwwwwwwo..",
    "...owwwwwwwwo...",
    "...oggggggggo...",
    "...oMMMMMMMMo...",
    "...oMMMMMMMMo...",
    "...oSMMMMMMSo...",
    "....oSSSSSSo....",
]
CHEF_HEAD_SIDE = [
    "....oooooooo....",
    "...owwwwwwwwo...",
    "..owwwwwwwgwwo..",
    "..owwgwwwwwwwo..",
    "...owwwwwwwwo...",
    "...oggggggggo...",
    "...oMMMsssssso..",
    "...oMMMssssoso..",
    "...oMMMsssssso..",
    "....oSSSSsSSo...",
]
CHEF_BODY_DOWN = [
    "...owwwttwwwo...",
    "..owwwttttwwwo..",
    ".oswwttttttwwso.",
    ".osowttttttwoso.",
    "..o.oTTTTTTo.o..",
    "....oppppppo....",
]
CHEF_BODY_UP = [
    "...owwwwwwwwo...",
    "..owwwwwwwwwwo..",
    ".oswwwwttwwwwso.",
    ".osowwwwwwwwoso.",
    "..o.ogggggggo...",
    "....oppppppo....",
]
CHEF_BODY_SIDE = [
    "....owwwwttwo...",
    "...owwwwwttwo...",
    "...owwsswtttso..",
    "...owwsswtttoo..",
    "....oggggTTTo...",
    "....oppppppo....",
]
LEGS_DOWN = [
    ["....opo..opo....", "....opo..opo....", "....ooo..ooo...."],
    ["....opo..opo....", "....opo...oo....", "....ooo........."],
    ["....opo..opo....", "....oo...opo....", ".........ooo...."],
]
LEGS_SIDE = [
    [".....opppo......", ".....opppo......", ".....oooooo....."],
    ["....opo.opo.....", "...opo...opo....", "...ooo...oooo..."],
    [".....oppo.......", "......oppo......", "......ooooo....."],
]


def chef_frames(head, body, legs):
    return [head + body + leg for leg in legs]


# --- Cliente (14x20): 3 frames a andar (parado, A, B) e 1 sentado

CUSTOMER_HEAD = [
    "....oooooo....",
    "...oMMMMMMo...",
    "..oMMMMMMMMo..",
    "..oMssssssMo..",
    "..osossssoso..",
    "..ossssssso...",
    "...oSssssSo...",
    "....oSSSSo....",
]
CUSTOMER_BODY = [
    "...ottttttto..",
    "..ottttttttto.",
    ".osttttttttso.",
    ".osottttttoso.",
    "..o.oTTTTTo.o.",
    "....oppppppo..",
]
CUSTOMER_LEGS = [
    ["....opo..opo..", "....opo..opo..", "....ooo..ooo..", ".............."],
    ["....opo..opo..", "....opo...oo..", "....ooo.......", ".............."],
    ["....opo..opo..", "....oo...opo..", ".........ooo..", ".............."],
    ["...oppppppppo.", "...ooooooooo..", "..............", ".............."],
]

# --- Itens

TOMATO = [
    ".....onno.....",
    "...oonNnnoo...",
    "..orrroNorrro.",
    ".orrwrrrrrrrro",
    ".orwrrrrrrrrro",
    "orrrrrrrrrrRro",
    "orrrrrrrrrrRro",
    "orrrrrrrrrRRro",
    ".orrrrrrrRRro.",
    ".oRrrrrrRRRo..",
    "..ooRRRRRoo...",
    "....ooooo.....",
]
LETTUCE = [
    "....oooooo....",
    "..oonlllnnoo..",
    ".onllnnnlllno.",
    "onlnnlllnnnlno",
    "onnllnnnllnnno",
    "onlnnnlnnnlnNo",
    "onnlnnnlnnnNNo",
    ".onnnlnnnnNNo.",
    ".oNnnnnnnNNNo.",
    "..ooNNNNNNoo..",
    "....oooooo....",
]
TOMATO_CHOPPED = [
    "..ooo.....",
    ".orwro.oo.",
    ".orrRoorwo",
    "..ooo.orRo",
    "..ooo..oo.",
    ".orwro....",
    ".orRRo.oo.",
    "..ooo.orro",
    "......oRo.",
    ".......o..",
]
LETTUCE_CHOPPED = [
    ".ooo......",
    "olnno.ooo.",
    "onnNoolnno",
    ".ooo.onnNo",
    "..ooo.ooo.",
    ".olnno....",
    ".onNNo.oo.",
    "..ooo.olno",
    "......onNo",
    ".......oo.",
]
SOUP = [
    "...oooooo...",
    ".ooaaaaaaoo.",
    ".oaayaaaaao.",
    "oaayyaaaaaAo",
    "oaaaaaaaaaAo",
    "oaaaaaaaaAAo",
    ".oaaaaaaAAo.",
    ".ooAAAAAAoo.",
    "...oooooo...",
]
PLATE = [
    "......oooooo......",
    "....oowwwwwwoo....",
    "...owwgggggggwo...",
    "..owggwwwwwwggwo..",
    ".owgwwwwwwwwwwgwo.",
    ".owgwwwwwwwwwwgwo.",
    "owgwwwwwwwwwwwwgwo",
    "owgwwwwwwwwwwwwgwo",
    "owgwwwwwwwwwwwwgwo",
    "owgwwwwwwwwwwwwgwo",
    "owggwwwwwwwwwwggGo",
    ".owgwwwwwwwwwwgGo.",
    ".owggwwwwwwwwggGo.",
    "..owggggggggggGo..",
    "...ooGGGGGGGGoo...",
    ".....oooooooo.....",
]
DIRT = [
    "..................",
    "..................",
    "..................",
    "......m...........",
    ".....mM......m....",
    "............mM....",
    "...m..............",
    "........M.........",
    ".......mm.....m...",
    "..............M...",
    "....mM............",
    "..........m.......",
    "..........Mm......",
    "..................",
    "..................",
    "..................",
]

# --- Estações (24x24, vista de cima com a frente visível em baixo)


def counter_rows():
    top = ["o" * 24] + ["o" + "b" * 22 + "o" for _ in range(17)]
    top[1] = "o" + "c" * 22 + "o"
    top[2] = "o" + "c" + "b" * 20 + "c" + "o"
    edge = ["o" + "m" * 22 + "o", "o" + "M" * 22 + "o"]
    front = ["o" + "m" * 22 + "o" for _ in range(3)] + ["o" * 24]
    rows = top + edge + front
    return rows[:24]


COUNTER = counter_rows()

FLOOR = ["".join(("f" if (x < 12) == (y < 12) else "F") if x % 12 and y % 12 else "g" for x in range(24)) for y in range(24)]
WOOD = []
for y in range(24):
    if y in (7, 15, 23):
        WOOD.append("M" * 24)
    else:
        seam = 6 if y < 8 else (17 if y < 16 else 11)
        WOOD.append("".join("M" if x == seam else ("m" if (x + y * 3) % 11 == 0 else "b") for x in range(24)))

BOARD = [
    "........................",
    "........................",
    "........................",
    "...oooooooooooooooooo...",
    "...occcccccccccccccco...",
    "...occcccccccccccccco...",
    "...occcwcccccccccccco...",
    "...occcccccccccccccco...",
    "...occcccccccccccccco...",
    "...occccccccccccccmco...",
    "...occcccccccccccccco...",
    "...occcccccccccccccco...",
    "...occcccccccccccccco...",
    "...omcccccccccccccmmo...",
    "...ommmmmmmmmmmmmmmmo...",
    "...oooooooooooooooooo...",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
POT = [
    "......oooooooooo......",
    "....ooHHHHHHHHHHoo....",
    "...oHhhhhhhhhhhhhHo...",
    "..oHh..........hhHo...",
    ".ooHh............hHoo.",
    "ohoHh............hHoho",
    "ohoHh............hHoho",
    ".ooHh............hHoo.",
    "..oHh............hHo..",
    "..oHhh..........hhHo..",
    "...oHhhhhhhhhhhhhHo...",
    "....ooHHHHHHHHHHoo....",
    "......oooooooooo......",
]
SINK = [
    "........................",
    "........................",
    "..oooooooooooooooooooo..",
    "..ohhhhhhhhhhhhhhhhhho..",
    "..ohHHHHHHHHHHHHHHHHho..",
    "..ohHuuuuuuuuuuuuuuHho..",
    "..ohHuwuuuuuuuuuuuuHho..",
    "..ohHuuuuuuuuuuuuuuHho..",
    "..ohHuuuuuuuuuuUuuuHho..",
    "..ohHuuuuuuuuuuuuuuHho..",
    "..ohHuuuuuuuUuuuuuuHho..",
    "..ohHuuuuuuuuuuuuuuHho..",
    "..ohHUUUUUUUUUUUUUUHho..",
    "..ohhhhhhhhhhhhhhhhhho..",
    "..oooooooooooooooooooo..",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
TRASH = [
    "........................",
    "........................",
    "......oooooooooooo......",
    ".....oHHHHHHHHHHHHo.....",
    "....oHhhhhhhhhhhhhHo....",
    "....oHhddddddddddhHo....",
    "....oHhdkkkkkkkkdhHo....",
    "....oHhdkkkkkkkkdhHo....",
    "....oHhdkkkkkkkkdhHo....",
    "....oHhddddddddddhHo....",
    "....oHhhhhhhhhhhhhHo....",
    ".....oHHHHHHHHHHHHo.....",
    "......oooooooooooo......",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
CRATE = [
    "........................",
    "..oooooooooooooooooooo..",
    "..ommmmmmmmmmmmmmmmmmo..",
    "..omMMMMMMMMMMMMMMMMmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omM..............Mmo..",
    "..omMMMMMMMMMMMMMMMMmo..",
    "..ommmmmmmmmmmmmmmmmmo..",
    "..oooooooooooooooooooo..",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
TABLE = (["oooooooooooooooooooooooo"]
         + ["o" + "w" * 22 + "o" for _ in range(3)]
         + ["o" + "".join("r" if (x // 3) % 2 == 0 else "w" for x in range(22)) + "o" for _ in range(12)]
         + ["o" + "w" * 22 + "o" for _ in range(2)]
         + ["o" + "R" * 22 + "o", "o" + "M" * 22 + "o"]
         + ["oM" + "." * 20 + "Mo", "oM" + "." * 20 + "Mo", "oo" + "." * 20 + "oo", "........................"])
CHAIR = [
    "........................",
    "........................",
    "........................",
    "........................",
    "......oooooooooooo......",
    "......oMMMMMMMMMMo......",
    "......oMmmmmmmmmMo......",
    "......oooooooooooo......",
    "......oMo......oMo......",
    "......oooooooooooo......",
    "......obbbbbbbbbbo......",
    "......obbbbbbbbbbo......",
    "......obbbbbbbbbbo......",
    "......obbbbbbbbbbo......",
    "......ommmmmmmmmmo......",
    "......oooooooooooo......",
    "......oMo......oMo......",
    "......oMo......oMo......",
    "......ooo......ooo......",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
DOOR = (["oooooooooooooooooooooooo"]
        + ["oMmmmmmmmmmMMmmmmmmmmmMo" for _ in range(9)]
        + ["oMmmmmmmmmmMMmmmmmmmmmMo", "oMmmmmmmyymMMmyymmmmmmMo", "oMmmmmmmyymMMmyymmmmmmMo"]
        + ["oMmmmmmmmmmMMmmmmmmmmmMo" for _ in range(10)]
        + ["oooooooooooooooooooooooo"])
BUBBLE = [
    "..oooooooooooooooooooo..",
    ".owwwwwwwwwwwwwwwwwwwwo.",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    "owwwwwwwwwwwwwwwwwwwwwwo",
    ".owwwwwwwwwwwwwwwwwwwwo.",
    "..oooooooowwwooooooooo..",
    "..........owwo..........",
    "...........oo...........",
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save_sheet("chef", [
        chef_frames(CHEF_HEAD_DOWN, CHEF_BODY_DOWN, LEGS_DOWN),
        chef_frames(CHEF_HEAD_UP, CHEF_BODY_UP, LEGS_DOWN),
        chef_frames(CHEF_HEAD_SIDE, CHEF_BODY_SIDE, LEGS_SIDE),
    ], with_tint=True)
    save_sheet("customer", [[CUSTOMER_HEAD + CUSTOMER_BODY + legs for legs in CUSTOMER_LEGS]], with_tint=True)
    save("tomato", TOMATO)
    save("lettuce", LETTUCE)
    save("tomato_chopped", TOMATO_CHOPPED)
    save("lettuce_chopped", LETTUCE_CHOPPED)
    save("soup", SOUP)
    save("plate", PLATE)
    save("dirt", DIRT)
    save("counter", COUNTER)
    save("floor", FLOOR)
    save("wood", WOOD)
    save("board", BOARD)
    save("pot", POT)
    save("sink", SINK)
    save("trash", TRASH)
    save("crate", CRATE)
    save("table", TABLE)
    save("chair", CHAIR)
    save("door", DOOR)
    save("bubble", BUBBLE)


if __name__ == "__main__":
    main()
