#!/usr/bin/env python3
"""PETSCII-Load's demo screen, written as a Petmate .pet file
(modules/petscii/demo.pet): what -module petscii shows, and a file to try
PETSCII-LM on. Run by hand after changing it; with a file name, also a
picture of it (needs VICE's character ROM).

    python3 modules/petscii/mkdemo.py [preview.png]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = 0, 1, 2, 3, 4, 5, 6, 7
ORANGE, BROWN, LRED, DGREY, GREY, LGREEN, LBLUE, LGREY = 8, 9, 10, 11, 12, 13, 14, 15
BORDER, BG = DGREY, BLACK

codes = [0x20] * 1000
cols = [WHITE] * 1000


def put(r, c, code, col):
    codes[r * 40 + c] = code
    cols[r * 40 + c] = col


def scode(ch):
    o = ord(ch)
    return o - 64 if 65 <= o <= 90 else o if 32 <= o <= 63 else 32


def text(r, c, s, col):
    for k, ch in enumerate(s):
        put(r, c + k, scode(ch), col)


def centre(r, s, col):
    text(r, (40 - len(s)) // 2, s, col)


# block letters, 4 x 5 cells: full blocks and triangles
F = {
    'S': [[0xe9, 0xa0, 0xa0, 0xdf], [0xa0, 0x20, 0x20, 0x20], [0x5f, 0xa0, 0xa0, 0xdf],
          [0x20, 0x20, 0x20, 0xa0], [0x5f, 0xa0, 0xa0, 0x69]],
    'L': [[0xa0, 0x20, 0x20, 0x20]] * 4 + [[0xa0, 0xa0, 0xa0, 0xa0]],
    'O': [[0xe9, 0xa0, 0xa0, 0xdf]] + [[0xa0, 0x20, 0x20, 0xa0]] * 3 + [[0x5f, 0xa0, 0xa0, 0x69]],
    'P': [[0xa0, 0xa0, 0xa0, 0xdf], [0xa0, 0x20, 0x20, 0xa0], [0xa0, 0xa0, 0xa0, 0x69],
          [0xa0, 0x20, 0x20, 0x20], [0xa0, 0x20, 0x20, 0x20]],
    'A': [[0xe9, 0xa0, 0xa0, 0xdf], [0xa0, 0x20, 0x20, 0xa0], [0xa0, 0xa0, 0xa0, 0xa0],
          [0xa0, 0x20, 0x20, 0xa0], [0xa0, 0x20, 0x20, 0xa0]],
    'D': [[0xa0, 0xa0, 0xa0, 0xdf]] + [[0xa0, 0x20, 0x20, 0xa0]] * 3 + [[0xa0, 0xa0, 0xa0, 0x69]],
}
ROWCOL = [WHITE, CYAN, CYAN, LBLUE, PURPLE]          # top to bottom
for k, ch in enumerate("SLOPLOAD"):
    for r, row in enumerate(F[ch]):
        for c, code in enumerate(row):
            if code != 0x20:
                put(1 + r, k * 5 + c, code, ROWCOL[r])

for c in range(40):                                     # under the name: a line
    put(7, c, 0x40, GREY)
centre(9, "PETSCII LOADING SCREEN", WHITE)

# a box with how to make one
top, bot, l, r = 11, 18, 1, 38
put(top, l, 0x55, LBLUE); put(top, r, 0x49, LBLUE)
put(bot, l, 0x4a, LBLUE); put(bot, r, 0x4b, LBLUE)
for c in range(l + 1, r):
    put(top, c, 0x40, LBLUE)
    put(bot, c, 0x40, LBLUE)
for rr in range(top + 1, bot):
    put(rr, l, 0x5d, LBLUE)
    put(rr, r, 0x5d, LBLUE)
centre(12, "DRAW YOURS IN PETMATE OR MARQ'S", LGREY)
centre(13, "PETSCII EDITOR, THEN:", LGREY)
centre(15, "SLOPLOAD.PY PROG.PRG PROG.TAP", LGREEN)
centre(16, "-MODULE SCREEN.PET", LGREEN)
centre(17, "ON A C64: PETSCII-LM MAKES A .LM", CYAN)

text(20, 11, "BLOCKS TO LOAD ", WHITE)               # the counter: its digits at 26-28
text(20, 26, "000", YELLOW)                             # (mkdata.py: COUNTER)
for c in range(4, 36):                                  # the sixteen colours
    put(22, c, 0xa0, (c - 4) // 2)
for c in range(40):                                     # row 24: the scroller's colours, fading
    d = min(c, 39 - c)                                  # at the ends (row 23 stays empty)
    cols[24 * 40 + c] = [DGREY, GREY, LGREY][d] if d < 3 else WHITE


def main():
    out = os.path.join(HERE, 'demo.pet')
    open(out, 'wb').write(bytes([40, 25, BORDER, BG, 1]) + bytes(codes) + bytes(cols))
    print(out)
    if len(sys.argv) > 1:
        from PIL import Image
        sys.path.insert(0, os.path.join(HERE, '..', '..', 'tests'))
        from vicshot import PAL
        rom = open('/usr/share/vice/C64/chargen-901225-01.bin', 'rb').read()[:2048]
        img = Image.new('RGB', (352, 232), PAL[BORDER])
        px = img.load()
        for rr in range(25):
            for c in range(40):
                g, rev = codes[rr * 40 + c] & 127, codes[rr * 40 + c] >= 128
                for y in range(8):
                    bits = rom[g * 8 + y] ^ (255 if rev else 0)
                    for x in range(8):
                        px[16 + c * 8 + x, 16 + rr * 8 + y] = PAL[cols[rr * 40 + c]] if bits >> (7 - x) & 1 else PAL[BG]
        img.resize((704, 464), Image.NEAREST).save(sys.argv[1])


if __name__ == '__main__':
    main()
