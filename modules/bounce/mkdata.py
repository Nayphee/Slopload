#!/usr/bin/env python3
"""Bounce-Load's graphics, levels and texts.

Writes (next to this file):
    chars.asm   characters 4-127 at $e020 (0-3 hold the module header)
    tables.asm  the ball's and the bat's images (pre-shifted, with masks),
                the levels, the angles, texts in screen codes and the
                character codes the kit and the game need
Run by tools/build.py before the module is assembled. tests/bouncecheck.py
imports BALL, BAT and the glyphs from here to model the screen.

Text uses plain ASCII codes (the shared font's letters at 65-90, digits
at 48-57); the status bar's characters are at 96-106.

Everything in the play field is multicolour: pairs '.' 00 the
background (black), 'a' 01 $d022 (white), 'g' 10 $d023 (light grey),
'h' 11 the cell's colour ram (a brick's colour, the bat's cyan, the
frame's blue). The ball uses 'a' and 'g' only, so it looks the same in
any cell it crosses.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))
from modfont import FONT  # noqa: E402

C_SPACE = 32
C_SETA, C_SETB = 4, 12        # the soft sprites' characters: two sets of 8
C_WALLL, C_WALLR, C_WALLT = 20, 21, 22
C_CORNL, C_CORNR = 23, 24
C_SIDE = 25                   # the backdrop outside the frame
C_BRICK = 26                  # 26-31: plain (left, right), tough, cracked
C_BAR = 96                    # 96-104: 0-8 pixels filled (hi-res)
C_BARL, C_BARR = 105, 106
C_FREE = 107                  # 107-127: never shown (the module's run-time buffers)

PAIR = {'.': 0, 'a': 1, 'g': 2, 'h': 3}

# the play field (screen multicolour pixels across, lines down)
FX0, FX1 = 16, 144            # the field: columns 4-35
FY0 = 16                      # rows 2-23 (the top wall is row 1)
BATY = 178                    # the bat's top line (row 22, line 2)
BRICK_ROW0 = 4                # bricks: rows 4-11, 16 to a row
BRICK_ROWS = 8

BALL = [".a.",
        "aaa",
        "aaa",
        "aag",
        "agg",
        ".g."]
BAT = ["aaaaaaaaaaaa",          # (its top line, what the ball meets, drawn across)
       "ahhhhhhhhhhg",
       "ahhhhhhhhhhg",
       "ahhhhhhhhhhg",
       ".gggggggggg."]
BALLW, BALLH = len(BALL[0]), len(BALL)
BATW, BATH = len(BAT[0]), len(BAT)

# a brick: two characters. Every pixel is drawn (no background pair),
# so a brick's cells are exactly what the ball can touch
BRICKS = {
    'plain': (["aaaa", "ahhh", "ahhh", "ahhh", "ahhh", "ahhh", "ahhh", "gggg"],
              ["aaag", "hhhg", "hhhg", "hhhg", "hhhg", "hhhg", "hhhg", "gggg"]),
    'tough': (["aaaa", "ahhh", "ahgh", "ahhh", "ahhh", "ahgh", "ahhh", "gggg"],
              ["aaag", "hghg", "hhhg", "hhhg", "hhhg", "hhhg", "hghg", "gggg"]),
    'cracked': (["aaaa", "ahhh", "ahgh", "ahhg", "ahgh", "ahgh", "ahhh", "gggg"],
                ["aaag", "hghg", "ghhg", "hghg", "hhgg", "hhhg", "hghg", "gggg"]),
}

# the frame: a blue tube, white highlight, grey inner edge (layers from
# the outside in), so the edge the ball meets is drawn
LAYER = "hahg"


def frame_char(kind):
    rows = []
    for line in range(8):
        lp = line // 2
        r = ''
        for px in range(4):
            d = {'l': px, 'r': 3 - px, 't': lp, 'cl': min(px, lp), 'cr': min(3 - px, lp)}[kind]
            r += LAYER[d]
        rows.append(r)
    return rows


SIDE = ["hhh.", "hhh.", "hhh.", "....", "h.hh", "h.hh", "h.hh", "...."]

# the levels: 16 bricks a row, 8 rows (rows 4-11). Capitals a plain
# brick of that colour (W white, R red, C cyan, P purple, G green, B
# blue, Y yellow), small letters a tough one (two hits), '.' none
COLOURS = {'W': 1, 'R': 2, 'C': 3, 'P': 4, 'G': 5, 'B': 6, 'Y': 7}
LEVELS = [
    # a dome
    ["......YYYY......",
     "....YYYYYYYY....",
     "..RRRRRRRRRRRR..",
     ".RRRRRRRRRRRRRR.",
     "PPPPPPPPPPPPPPPP",
     "BBBBBBBBBBBBBBBB",
     "CCCCCCCCCCCCCCCC",
     "................"],
    # a cassette
    ["WWWWWWWWWWWWWWWW",
     "WCCCCCCCCCCCCCCW",
     "WC.YYY.CC.YYY.CW",
     "WC.YrY.CC.YrY.CW",
     "WC.YYY.CC.YYY.CW",
     "WCCCCCCCCCCCCCCW",
     "WWWWBBBBBBBBWWWW",
     "................"],
    # two stairs
    ["G..............G",
     "GG............GG",
     "GGY..........YGG",
     "GGYY........YYGG",
     "GGYYR......RYYGG",
     "GGYYRR....RRYYGG",
     "ggggggg..ggggggg",
     "................"],
    # a chequerboard
    ["P.P.P.P.P.P.P.P.",
     ".B.B.B.B.B.B.B.B",
     "C.C.C.C.C.C.C.C.",
     ".G.G.G.G.G.G.G.G",
     "Y.Y.Y.Y.Y.Y.Y.Y.",
     ".R.R.R.R.R.R.R.R",
     "w.w.w.w.w.w.w.w.",
     "................"],
    # a diamond
    [".......RR.......",
     ".....RRYYRR.....",
     "...RRYYGGYYRR...",
     ".RRYYGGccGGYYRR.",
     "...RRYYGGYYRR...",
     ".....RRYYRR.....",
     ".......RR.......",
     "................"],
    # waves
    ["CC......CC......",
     "..CC......CC....",
     "....CC......CC..",
     "BB....BB....BB..",
     "..BB....BB....BB",
     "PPPPPPPPPPPPPPPP",
     "pppppppppppppppp",
     "................"],
    # a keep: tough walls round a soft middle
    ["yyyyyyyyyyyyyyyy",
     "y..............y",
     "y.RRRRRRRRRRRR.y",
     "y.RGGGGGGGGGGR.y",
     "y.RGGGGGGGGGGR.y",
     "y.RRRRRRRRRRRR.y",
     "y..............y",
     "yyyyyyy..yyyyyyy"],
    # columns
    ["W.W.W.W.W.W.W.W.",
     "C.C.C.C.C.C.C.C.",
     "B.B.B.B.B.B.B.B.",
     "P.P.P.P.P.P.P.P.",
     "R.R.R.R.R.R.R.R.",
     "Y.Y.Y.Y.Y.Y.Y.Y.",
     "g.g.g.g.g.g.g.g.",
     "GGGGGGGGGGGGGGGG"],
]

# points for a brick, in tens, by colour (1-7); a tough one cracking 1,
# breaking 10
POINTS = [0, 7, 6, 3, 5, 2, 4, 1]

# the ball's speeds (1/16 line a tick, along its path) and the angles
# from straight up it leaves the bat at (degrees)
SPEEDS = [26, 30, 34, 38, 42, 47, 52, 58]
ANGLES = [20, 35, 50, 62]
# the bat's 14 places the ball's middle can meet it at (its left - 1 to
# its right + 1): the angle's index, and the way it goes (0 right, 1 left,
# 2 the way it came)
ZONES = [(3, 1), (3, 1), (2, 1), (2, 1), (1, 1), (1, 1), (0, 2),
         (0, 2), (1, 0), (1, 0), (2, 0), (2, 0), (3, 0), (3, 0)]

TEXTS = {
    'tx_title': "BOUNCE-LOAD",
    'tx_t1': "KNOCK THE WALL DOWN",
    'tx_t2': "LEFT AND RIGHT MOVE THE BAT",
    'tx_t3': "FIRE TO PLAY",
    'tx_over': "GAME OVER",
    'tx_again': "FIRE TO PLAY AGAIN",
    'tx_down': "WALL DOWN!",
    'tx_lvmsg': "LEVEL 00",
    'tx_score': "SCORE",
    'tx_balls': "BALLS",
    'tx_hi': "HI",
    # the standard status texts (src/modkit.asm)
    'tx_loading': "LOADING",
    'tx_error': "TAPE ERROR: REWIND A BIT, PRESS PLAY",
    'tx_loaded': "LOADED! PRESS SPACE TO START THE GAME",
}


def mc(rows):
    """8 rows of 4 multicolour pixels -> 8 bytes"""
    out = []
    for r in rows:
        assert len(r) == 4, r
        b = 0
        for ch in r:
            b = b << 2 | PAIR[ch]
        out.append(b)
    return out


def shifted(img, shift, cells):
    """an image's rows moved right by shift multicolour pixels, as
    `cells` character columns: (image, mask) bytes [cell][row]"""
    im, mk = [], []
    for c in range(cells):
        ci, cm = [], []
        for r in img:
            b = m = 0
            for p in range(4):
                x = c * 4 + p - shift
                ch = r[x] if 0 <= x < len(r) else '.'
                b = b << 2 | PAIR[ch]
                m = m << 2 | (0 if ch != '.' else 3)
            ci.append(b)
            cm.append(m)
        im.append(ci)
        mk.append(cm)
    return im, mk


def charset():
    cs = [[0] * 8 for _ in range(128)]
    for ch, rows in FONT.items():
        cs[ord(ch)] = [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows + ["........"]]
    for k in range(9):
        fill = (0xff << (8 - k)) & 0xff
        cs[C_BAR + k] = [0, 0xff, fill, fill, fill, fill, 0xff, 0]
    cs[C_BARL] = [0, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0]
    cs[C_BARR] = [0, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0]
    for code, kind in ((C_WALLL, 'l'), (C_WALLR, 'r'), (C_WALLT, 't'), (C_CORNL, 'cl'), (C_CORNR, 'cr')):
        cs[code] = mc(frame_char(kind))
    cs[C_SIDE] = mc(SIDE)
    for k, name in enumerate(('plain', 'tough', 'cracked')):
        left, right = BRICKS[name]
        assert all('.' not in r for r in left + right), "a brick has no background pixels"
        cs[C_BRICK + 2 * k] = mc(left)
        cs[C_BRICK + 2 * k + 1] = mc(right)
    return cs


def level_bytes(rows):
    """a level: 64 bytes, two bricks a byte (the left one in the low
    nibble): 0 none, 1-7 a plain brick of that colour, 9-15 a tough one"""
    assert len(rows) == BRICK_ROWS and all(len(r) == 16 for r in rows), rows
    nib = []
    for r in rows:
        for ch in r:
            if ch == '.':
                nib.append(0)
            elif ch.isupper():
                nib.append(COLOURS[ch])
            else:
                nib.append(8 + COLOURS[ch.upper()])
    return [nib[i] | nib[i + 1] << 4 for i in range(0, len(nib), 2)]


def asm_bytes(label, data, per=16):
    out = [label] if label else []
    for i in range(0, len(data), per):
        out.append("        byte " + ','.join(f"${b:02x}" for b in data[i:i + per]))
    return out


def main():
    cs = charset()
    assert not any(any(cs[i]) for i in range(4)), "characters 0-3 hold the header"
    assert not any(any(cs[i]) for i in range(C_FREE, 128)), "characters 107-127 are buffers"
    for ch in ''.join(TEXTS.values()):
        assert ch in FONT or ch == ' ', f"no '{ch}' in the font"
    t = ["; generated by mkdata.py - do not edit", "",
         f"c_space = {C_SPACE}", f"c_bar = {C_BAR}", f"c_barl = {C_BARL}", f"c_barr = {C_BARR}",
         f"c_digit0 = {ord('0')}", f"c_pct = {ord('%')}", f"c_seta = {C_SETA}", f"c_setb = {C_SETB}",
         f"c_walll = {C_WALLL}", f"c_wallr = {C_WALLR}", f"c_wallt = {C_WALLT}",
         f"c_cornl = {C_CORNL}", f"c_cornr = {C_CORNR}", f"c_side = {C_SIDE}", f"c_brick = {C_BRICK}",
         f"ballw = {BALLW}", f"ballh = {BALLH}", f"batw = {BATW}", f"bath = {BATH}",
         f"fx0 = {FX0}", f"fx1 = {FX1}", f"fy0 = {FY0}", f"baty = {BATY}",
         f"brow0 = {BRICK_ROW0}", f"nlevels = {len(LEVELS)}", f"nspeeds = {len(SPEEDS)}", ""]
    # the ball, 4 shifts x 2 cells x 6 rows (image, then mask); the bat,
    # 4 shifts x 4 cells x 5 rows
    bi, bm, ti, tm = [], [], [], []
    for s in range(4):
        im, mk = shifted(BALL, s, 2)
        bi += [b for c in im for b in c]
        bm += [b for c in mk for b in c]
        im, mk = shifted(BAT, s, 4)
        ti += [b for c in im for b in c]
        tm += [b for c in mk for b in c]
    t += asm_bytes("ballimg", bi) + asm_bytes("ballmsk", bm)
    t += asm_bytes("batimg", ti) + asm_bytes("batmsk", tm)
    # the angles: for each speed, x (1/16 multicolour pixel: half the
    # line's width) and y (1/16 line) for each angle
    vx, vy = [], []
    for s in SPEEDS:
        for a in ANGLES:
            vx.append(round(s * math.sin(math.radians(a)) / 2))
            vy.append(round(s * math.cos(math.radians(a))))
    assert max(vy) < 64 and max(vx) < 32
    t += asm_bytes("angvx", vx) + asm_bytes("angvy", vy)
    t += asm_bytes("zoneang", [z[0] for z in ZONES]) + asm_bytes("zonedir", [z[1] for z in ZONES])
    t += asm_bytes("points", POINTS)
    lv = []
    for rows in LEVELS:
        lv += level_bytes(rows)
    t += asm_bytes("levels", lv)
    for k, v in TEXTS.items():
        t += asm_bytes(k, [len(v)] + [ord(c) for c in v])
    open(os.path.join(HERE, 'tables.asm'), 'w').write('\n'.join(t) + '\n')
    g = ["; generated by mkdata.py - do not edit",
         "; characters 4-127 (0-3 hold the module header, at $e000)", "", "*=$e020"]
    g += asm_bytes(None, [b for c in cs[4:128] for b in c])
    open(os.path.join(HERE, 'chars.asm'), 'w').write('\n'.join(g) + '\n')


if __name__ == '__main__':
    main()
