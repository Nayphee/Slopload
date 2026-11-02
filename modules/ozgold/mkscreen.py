#!/usr/bin/env python3
"""OZ GOLD's screen: 40 x 25 PETSCII cells in the C64's own character
set (upper case and graphics), one colour a cell on the blue
background, laid out as U.S. Gold's Novaload screen.

    python3 modules/ozgold/mkscreen.py [preview.png]

Writes modules/ozgold/screen.asm (the 1,000 screen codes: the module's
second part, at $BC00) and colours.asm (the 1,000 colours), and, given a
file name, a picture of the screen as a C64 shows it. Not run by
tools/build.py: it needs the character ROM (VICE's), which only the
Union Jack and the preview use. Run it again after changing the design.

What is on it:
  the Union Jack, 18 x 9 cells at the top left: drawn in pixels, each
    cell made the nearest of the quarter-block and triangle characters,
    in white or red
  the Southern Cross on the right, the Commonwealth Star under the Union
    Jack: bursts of line characters
  OZ GOLD in U.S. Gold's own letters: G, O, L and D are its logo's cells
    exactly (rows 9-13 of its screen, in the same columns), Z is made of
    the same pieces (blocks and triangles)
  ALL AUSTRALIAN SOFTWARE on a gold stripe, a green one under it
  U.S. Gold's bottom rows: BLOCKS TO LOAD and the box for the counter
    (the module writes the digits)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROMFILE = '/usr/share/vice/C64/chargen-901225-01.bin'
BLACK, WHITE, RED, GREEN, BLUE, YELLOW = 0, 1, 2, 5, 6, 7
BG = BLUE

# U.S. Gold's logo, rows 9-13 of its screen: its letters' cells
US_G = [[0xe9, 0xa0, 0xa0, 0xdf], [0xa0, 0x20, 0x20, 0x20], [0xa0, 0x20, 0xcc, 0xa0],
        [0xa0, 0x20, 0x20, 0xa0], [0x5f, 0xa0, 0xa0, 0x69]]
US_O = [[0xe9, 0xa0, 0xa0, 0xdf], [0xa0, 0x20, 0x20, 0xa0], [0xa0, 0x20, 0x20, 0xa0],
        [0xa0, 0x20, 0x20, 0xa0], [0x5f, 0xa0, 0xa0, 0x69]]
US_L = [[0x6a, 0xa0, 0x74, 0x20, 0x20], [0x20, 0xa0, 0x20, 0x20, 0x20], [0x20, 0xa0, 0x20, 0x20, 0x20],
        [0x20, 0xa0, 0x20, 0x20, 0x6f], [0x6a, 0xa0, 0xa0, 0xa0, 0xa0]]
US_D = [[0x6a, 0xa0, 0xa0, 0xa0, 0xdf], [0x20, 0xa0, 0x20, 0x20, 0xa0], [0x20, 0xa0, 0x20, 0x20, 0xa0],
        [0x20, 0xa0, 0x20, 0x20, 0xa0], [0x6a, 0xa0, 0xa0, 0xa0, 0x69]]
OZ_Z = [[0xa0, 0xa0, 0xa0, 0xa0], [0x20, 0x20, 0xe9, 0x69], [0x20, 0xe9, 0x69, 0x20],
        [0xe9, 0x69, 0x20, 0x20], [0xa0, 0xa0, 0xa0, 0xa0]]
# U.S. Gold's rows 22-24 (colour 0: black): a thin line, then the panel
# with BLOCKS TO LOAD (reversed) and the counter's box (digits at 24-26)
US_22 = [0x79] * 40
US_23 = [0xa0] * 23 + [0xec, 0xe2, 0xe2, 0xe2, 0xfb] + [0xa0] * 12
US_24 = [0xa0] * 9 + [0x82, 0x8c, 0x8f, 0x83, 0x8b, 0x93, 0xa0, 0x94, 0x8f, 0xa0, 0x8c, 0x8f, 0x81, 0x84,
                      0x61, 0x30, 0x37, 0x39, 0xe1] + [0xa0] * 12
DIGITS = 24 * 40 + 24        # where the module writes the counter
ERRROW = 21                  # and TAPE ERROR (a blank row)
TX_ERR = "TAPE ERROR: REWIND A BIT, PRESS PLAY"

codes = [0x20] * 1000
cols = [BLUE] * 1000


def put(r, c, code, col):
    codes[r * 40 + c] = code
    cols[r * 40 + c] = col


def glyph_table():
    rom = open(ROMFILE, 'rb').read()[:2048]
    g = [[(rom[k * 8 + y] >> (7 - x)) & 1 for y in range(8) for x in range(8)] for k in range(128)]
    return g + [[1 - b for b in k] for k in g]


def union_jack(glyphs, cw=18, ch=9):
    """the flag in pixels, then each cell the nearest quarter-block or
    triangle character, white or red"""
    from PIL import Image, ImageDraw
    W, H = cw * 8, ch * 8
    img = Image.new('P', (W, H), BG)
    d = ImageDraw.Draw(img)

    def band(p, q, wid, col):
        dx, dy = q[0] - p[0], q[1] - p[1]
        n = math.hypot(dx, dy)
        ox, oy = -dy / n * wid / 2, dx / n * wid / 2
        d.polygon([(p[0] + ox, p[1] + oy), (q[0] + ox, q[1] + oy), (q[0] - ox, q[1] - oy),
                   (p[0] - ox, p[1] - oy)], fill=col)
    u = H / 30                                   # the flag's own measure: 60 x 30
    cx, cy = W / 2, H / 2
    band((0, 0), (W, H), 6 * u, WHITE)           # St Andrew's saltire
    band((0, H), (W, 0), 6 * u, WHITE)
    for p in ((0, 0), (W, H), (W, 0), (0, H)):   # St Patrick's, counterchanged
        dx, dy = cx - p[0], cy - p[1]
        n = math.hypot(dx, dy)
        ox, oy = -dy / n * u, dx / n * u
        band((p[0] + ox, p[1] + oy), (cx + ox, cy + oy), 2 * u, RED)
    d.rectangle([cx - 5 * u, 0, cx + 5 * u, H], fill=WHITE)   # St George's cross
    d.rectangle([0, cy - 5 * u, W, cy + 5 * u], fill=WHITE)
    d.rectangle([cx - 3 * u, 0, cx + 3 * u, H], fill=RED)
    d.rectangle([0, cy - 3 * u, W, cy + 3 * u], fill=RED)
    px = img.load()
    shapes = [0x20, 0xa0, 0x7e, 0x7c, 0x6c, 0x7b, 0x61, 0xe1, 0x62, 0xe2, 0x7f, 0xff, 0xfe, 0xfc, 0xec, 0xfb,
              0x5f, 0x69, 0xdf, 0xe9]        # quarter blocks, halves, three quarters; triangles
    for r in range(ch):
        for c in range(cw):
            cell = [px[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8)]
            best = None
            for col in (WHITE, RED):
                for g in shapes:
                    e = 0
                    for b, p in zip(glyphs[g], cell):
                        if b:
                            e += 0 if p == col else (2 if p == BG else 1)
                        else:
                            e += 0 if p == BG else 2
                    if best is None or e < best[0]:
                        best = (e, g, col)
            put(r, c, best[1], best[2] if best[1] != 0x20 else BG)


def burst(r, c, big=False, col=WHITE):
    """a star: lines out from a dot, 3 x 3 cells (5 x 5 when big)"""
    reach = 2 if big else 1
    for k in range(1, reach + 1):
        for dr, dc, code in ((-k, -k, 0x4d), (-k, k, 0x4e), (k, -k, 0x4e), (k, k, 0x4d),
                             (-k, 0, 0x5d), (k, 0, 0x5d), (0, -k, 0x40), (0, k, 0x40)):
            put(r + dr, c + dc, code, col)
    put(r, c, 0x51, col)


def scode(ch):
    o = ord(ch)
    return o - 64 if 65 <= o <= 90 else o if 32 <= o <= 63 else 32


def text(r, c, s, col, rev=False):
    for k, ch in enumerate(s):
        put(r, c + k, scode(ch) + (128 if rev else 0), col)


def letter(cells, r0, c0, col):
    for r, row in enumerate(cells):
        for k, code in enumerate(row):
            if code != 0x20:
                put(r0 + r, c0 + k, code, col)


def design(glyphs):
    union_jack(glyphs)
    burst(1, 30)                 # the Southern Cross: Gamma,
    burst(5, 23)                 # Beta,
    burst(4, 36)                 # Delta,
    put(7, 32, 0x2a, WHITE)      # Epsilon (the small one)
    burst(16, 30)                # and Alpha
    burst(16, 8, big=True)       # the Commonwealth Star
    letter(US_O, 9, 5, YELLOW)   # OZ, then GOLD in U.S. Gold's own columns
    letter(OZ_Z, 9, 10, YELLOW)
    letter(US_G, 9, 17, YELLOW)
    letter(US_O, 9, 22, YELLOW)
    letter(US_L, 9, 26, YELLOW)
    letter(US_D, 9, 31, YELLOW)
    for c in range(40):          # green and gold
        put(19, c, 0xa0, YELLOW)
        put(20, c, 0xa0, GREEN)
    s = "ALL AUSTRALIAN SOFTWARE"
    text(19, (40 - len(s)) // 2, s, YELLOW, rev=True)
    for r, row in ((22, US_22), (23, US_23), (24, US_24)):
        for c, code in enumerate(row):
            put(r, c, code, BLACK if code != 0x20 else BG)


def asm_bytes(label, data, note):
    out = [f"; {note}", f"{label}"]
    for i in range(0, len(data), 20):
        out.append("        byte " + ",".join(f"${b:02x}" for b in data[i:i + 20]))
    return "\n".join(out) + "\n"


def preview(glyphs, path):
    from PIL import Image
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'tests'))
    from vicshot import PAL
    out = Image.new('RGB', (352, 232), PAL[BLACK])
    o = out.load()
    for r in range(25):
        for c in range(40):
            g = glyphs[codes[r * 40 + c]]
            for y in range(8):
                for x in range(8):
                    o[16 + c * 8 + x, 16 + r * 8 + y] = PAL[cols[r * 40 + c]] if g[y * 8 + x] else PAL[BG]
    out.resize((704, 464), Image.NEAREST).save(path)


def main():
    glyphs = glyph_table()
    design(glyphs)
    head = "; made by mkscreen.py: change the design there and run it again\n"
    open(os.path.join(HERE, 'screen.asm'), 'w').write(
        head + asm_bytes("scrdata", codes, "the screen codes (the second part, at $bc00)"))
    open(os.path.join(HERE, 'colours.asm'), 'w').write(
        head + asm_bytes("coldata", cols, "the colours (copied to $d800 at init)")
        + f"o_digits = {DIGITS}               ; the counter's first digit (row 24, column 24)\n"
        + f"o_errrow = {ERRROW * 40}               ; TAPE ERROR's row (21)\n"
        + asm_bytes("tx_err", [scode(ch) for ch in TX_ERR], "the tape error message (white, on row 21)")
        + "tx_errend\n")
    if len(sys.argv) > 1:
        preview(glyphs, sys.argv[1])
    print("screen.asm, colours.asm")


if __name__ == '__main__':
    main()
