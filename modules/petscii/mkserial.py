#!/usr/bin/env python3
"""A mock of Novaload's boot screen, written as a Petmate .pet file
(modules/petscii/serial.pet): what a Novaload tape shows once its first
program is RUN and the screech begins. Taken from Spy Hunter's (Kixx),
read in VICE at the screech's first byte: a black border, a dark grey
screen, the tape's name in white on row 8 and "NOVALOAD A100222" in
light grey on row 23 (columns 12-27), and nothing else.

Here it says SLOPLOAD, with a serial number of zeros in Novaload's form
(a letter and six digits), and 1234567890123456 stands where the name
goes: the sixteen characters of a tape's name, centred, over the bottom
line's sixteen. On SlopLoad 64's disks as SERIAL.PET, a second screen to
try PETSCII-LM on. Run by hand after changing it; with a file name, also
a picture of it (needs VICE's character ROM).

    python3 modules/petscii/mkserial.py [preview.png]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BLACK, WHITE, DGREY, LBLUE, LGREY = 0, 1, 11, 14, 15
BORDER, BG = BLACK, DGREY
NAME_ROW, LINE_ROW, COL = 8, 23, 12                     # (Novaload's rows; 16 characters from column 12)
NAME = "1234567890123456"                               # the tape's name: its 16 characters
LINE = "SLOPLOAD A000000"                               # (Novaload's: NOVALOAD A100222)
assert len(NAME) == len(LINE) == 16 and COL == (40 - 16) // 2

codes = [0x20] * 1000
cols = [LBLUE] * 1000                                   # (the cells Novaload leaves: the C64's own colour)


def scode(ch):
    o = ord(ch)
    return o - 64 if 65 <= o <= 90 else o if 32 <= o <= 63 else 32


def text(r, c, s, col):
    for k, ch in enumerate(s):
        codes[r * 40 + c + k] = scode(ch)
        cols[r * 40 + c + k] = col


text(NAME_ROW, COL, NAME, WHITE)
text(LINE_ROW, COL, LINE, LGREY)


def main():
    out = os.path.join(HERE, 'serial.pet')
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
