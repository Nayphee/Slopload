#!/usr/bin/env python3
"""PETSCII-Load's demo into source: modules/petscii/demo.pet (a Petmate
.pet file, made by mkdemo.py) read by tools/petscii.py and written as
screen.asm (the screen codes: the second part, at $BC00), colours.asm
(the settings and colours: the main part from byte 32 on) and
message.asm (the scrolling message: the main part's end), with the
demo's scroller and counter below. tools/build.py runs this before it assembles the
module; tools/petscii.py and PETSCII-LM put another screen in the same
places.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import petscii as P  # noqa: E402


# the demo's scroller and counter (-module petscii)
MESSAGE = ("PETSCII-LOAD: YOUR OWN PETSCII SCREEN WHILE THE PROGRAM LOADS, WITH A SCROLLING MESSAGE"
           " AND A BLOCK COUNTER ... DRAW THE SCREEN IN PETMATE OR MARQ'S PETSCII EDITOR, THEN"
           " SLOPLOAD.PY PROG.PRG PROG.TAP -MODULE SCREEN.PET -SCROLL \"YOUR MESSAGE\" -COUNTER 20,26"
           " ... OR ON A C64, PETSCII-LM ASKS FOR THEM ...          ")
ROW, SPEED, COUNTER = 24, 2, (20, 26)


def asm_bytes(data):
    return ["        byte " + ",".join(f"${b:02x}" for b in data[i:i + 20]) for i in range(0, len(data), 20)]


def main():
    s = P.read(os.path.join(HERE, 'demo.pet'))
    msg = P.screencodes(MESSAGE, s['upper'])
    P.check(s, msg, ROW, SPEED, COUNTER)
    head = "; made by mkdata.py from demo.pet and its settings: change them there (and mkdemo.py)"
    open(os.path.join(HERE, 'screen.asm'), 'w').write(
        "\n".join([head, "scrdata"] + asm_bytes(s['codes'])) + "\n")
    open(os.path.join(HERE, 'colours.asm'), 'w').write("\n".join(
        [head,
         f"pborder byte {s['border']}                ; +32 the border",
         f"pbg     byte {s['bg']}                 ; +33 the background",
         f"pd018   byte ${P.D018[s['upper']]:02x}               ; +34 $d018: $f4 upper case, $f6 lower case",
         "pflags  byte 3                  ; +35 bit 0 the counter, bit 1 the scroller",
         "coldata                         ; +36 the colours"] + asm_bytes(s['colours']) +
        [f"prow    byte {ROW}                ; +1036 the scroller's row",
         f"pspeed  byte {SPEED}                 ; +1037 its pixels a frame",
         f"pcount  word {COUNTER[0] * 40 + COUNTER[1]}               ; +1038 the counter's first digit (row x 40 + column)",
         f"pmsglen word {len(msg)}               ; +1040 the message's length",
         "pspace  byte $20               ; +1042 the space's code (the scroller's row cleared with it)",
         "pdigit0 byte $30               ; +1043 the digit 0's (the counter's 0-9 from it)",
         f"g_share = {P.SHARE[True]}                    ; (header +14: with the scroller)"]) + "\n")
    open(os.path.join(HERE, 'message.asm'), 'w').write(
        "\n".join([head] + asm_bytes(msg)) + "\n")
    return 0


if __name__ == '__main__':
    sys.exit(main())
