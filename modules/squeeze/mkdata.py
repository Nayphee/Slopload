#!/usr/bin/env python3
"""Squeeze-Load's graphics and texts.

Writes (next to this file):
    chars.asm   characters 4-127 at $e020 (0-3 hold the module header)
    tables.asm  the girders' glyph strips, the rocket's sprite frames and
                its row extents, texts in screen codes, the character
                codes the kit and the game need
Run by tools/build.py before the module is assembled.

Text uses plain ASCII codes (the shared font's letters at 65-90, digits
at 48-57); the status bar's characters are at 96-106.

Multicolour characters (the play field and the shaft's rock): pairs
'.' 00 background, 'a' 01 $d022 (the level's colour), 'd' 10 $d023
(dark grey), 'h' 11 the cell's colour ram (white in the shaft, blue in
the rock). A girder line has no background pair in it: its drawn pixels
are the whole cell, which is what the collisions take.

The rocket: one multicolour sprite, pairs 'r' 01 $d025 (red), 'w' 10
its own colour (white), 'y' 11 $d026 (yellow), in multicolour columns
3-8 of the sprite (hi-res pixels 6-17).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))
from modfont import FONT  # noqa: E402

C_SPACE = 32
C_WALL = 4                    # 4-6 even rows (solid, left end, right end), 7-9 odd rows
C_ROCK = 10                   # 10-13 the shaft's rock: a 2 x 2 tile (+1 odd columns, +2 odd rows)
C_EDGEL = 14                  # 14-15 the left face (col 3; +1 odd rows)
C_EDGER = 16                  # 16-17 the right face (col 36)
C_FLOOR = 18                  # 18-19 the floor under the shaft (row 23; +1 odd columns)
C_CORNL, C_CORNR = 20, 21     # the floor's corners (cols 3, 36)
C_BAR = 96                    # 96-104: 0-8 pixels filled (hi-res)
C_BARL, C_BARR = 105, 106

PAIR = {'.': 0, 'a': 1, 'd': 2, 'h': 3}


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


# the girder: a white top edge, the level's colour with rivets, a dark
# underside; the ends next to the gap have an edge of their own
GIRDER = {
    'solid': ["hhhh", "aaaa", "ahaa", "aaaa", "aaaa", "ahaa", "aaaa", "dddd"],
    'lend': ["hhhd", "aaad", "ahad", "aaad", "aaad", "ahad", "aaad", "dddd"],   # gap on its right
    'rend': ["hhhh", "haaa", "haha", "haaa", "haaa", "haha", "haaa", "hddd"],   # gap on its left
}

# the rocket, frames 0 and 1 (the flame flickers) and 2 (a crash)
ROCKET = ["..rr..", "..rr..", ".rwwr.", ".wwww.", ".wrrw.", ".wrrw.", ".wwww.",
          ".wwww.", ".wwww.", "rwwwwr", "rwwwwr", "rr..rr"]
FLAME = [["..yy..", "..yy.."], ["..yy..", "......"]]
CRASH = ["....r.......", "..r..y..r...", "...yyyy...r.", "r.ywwwwy....", "..ywrrwy.r..",
         ".yywrrwyy...", "..ywwwwy..r.", "r..yyyy.....", "...y..y.r...", ".r..r.....r.",
         "......r....."]
SHIP_ROWS = len(ROCKET) + 2          # 14 rows: what collides


def sprite(rows, col0):
    """multicolour rows (2 bits a pixel) from column col0 of 12 -> 63 bytes"""
    sp = {'.': 0, 'r': 1, 'w': 2, 'y': 3}
    out = []
    for y in range(21):
        bits = [0] * 12
        if y < len(rows):
            for i, ch in enumerate(rows[y]):
                bits[col0 + i] = sp[ch]
        v = 0
        for b in bits:
            v = v << 2 | b
        out += [v >> 16 & 255, v >> 8 & 255, v & 255]
    return out + [0]


def extents(rows, col0):
    """each row's first and last drawn hi-res pixel from the ship's left
    (multicolour column 3 = 0); $ff, 0 for an empty row"""
    lx, rx = [], []
    for y in range(SHIP_ROWS):
        r = rows[y] if y < len(rows) else ''
        xs = [col0 + i for i, ch in enumerate(r) if ch != '.']
        if xs:
            lx.append((min(xs) - 3) * 2)
            rx.append((max(xs) - 3) * 2 + 1)
        else:
            lx.append(0xff)
            rx.append(0)
    return lx, rx


TEXTS = {
    'tx_title': "SQUEEZE-LOAD",
    'tx_t1': "SLIP THROUGH THE GAPS",
    'tx_t2': "IN THE FALLING GIRDERS",
    'tx_t3': "LEFT AND RIGHT TO STEER",
    'tx_t4': "FIRE TO PLAY",
    'tx_over': "GAME OVER - FIRE TO PLAY AGAIN",
    'tx_go': "SQUEEZE THROUGH!",
    'tx_level': "LEVEL",
    'tx_score': "SCORE",
    'tx_best': "BEST",
    # the standard status texts (src/modkit.asm)
    'tx_loading': "LOADING",
    'tx_error': "TAPE ERROR: REWIND A BIT, PRESS PLAY",
    'tx_loaded': "LOADED! PRESS SPACE TO START THE GAME",
}


def asm_bytes(label, data, per=16):
    out = [label] if label else []
    for i in range(0, len(data), per):
        out.append("        byte " + ','.join(f"${b:02x}" for b in data[i:i + per]))
    return out


def charset():
    cs = [[0] * 8 for _ in range(128)]
    for ch, rows in FONT.items():
        cs[ord(ch)] = [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows + ["........"]]
    for k in range(9):
        fill = (0xff << (8 - k)) & 0xff
        cs[C_BAR + k] = [0, 0xff, fill, fill, fill, fill, 0xff, 0]
    cs[C_BARL] = [0, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0]
    cs[C_BARR] = [0, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0]
    # the rock: dark grey stones with blue grains, black cracks between,
    # a tile of 2 x 2 characters (8 multicolour pixels by 16 lines)
    for k in range(4):
        cs[C_ROCK + k] = mc(tile(k & 1, k >> 1))
    # the shaft's faces, lit in the level's colour: the left (column 3,
    # odd: the tile's right half) on its right, the right (36) on its left
    for r in range(2):
        cs[C_EDGEL + r] = mc([t[:3] + 'a' for t in tile(1, r)])
        cs[C_EDGER + r] = mc(['a' + t[1:] for t in tile(0, r)])
    # the floor (row 23, odd): its top line lit; the corners where the
    # faces meet it
    for c in range(2):
        cs[C_FLOOR + c] = mc(["aaaa"] + tile(c, 1)[1:])
    cs[C_CORNL] = mc([tile(1, 1)[0][:3] + 'a'] + tile(1, 1)[1:])
    cs[C_CORNR] = mc(['a' + tile(0, 1)[0][1:]] + tile(0, 1)[1:])
    return cs


ROCK = ["dddd.ddd",
        "dhdd.ddh",
        "dddd.ddd",
        "ddd..ddd",
        "....dddd",
        "dd.dddhd",
        "dd.ddddd",
        "dd.ddddd",
        "dd......",
        "d.ddd.dd",
        "ddhdd.dd",
        "ddddd.dh",
        "ddddd.dd",
        "....d...",
        "dd.ddddd",
        "dd.dhddd"]


def tile(c, r):
    """the rock tile's character at column c, row r (0 or 1): 8 rows of 4"""
    return [ROCK[8 * r + y][4 * c:4 * c + 4] for y in range(8)]


def main():
    cs = charset()
    assert not any(any(cs[i]) for i in range(4)), "characters 0-3 hold the header"
    for ch in ''.join(TEXTS.values()):
        assert ch in FONT or ch == ' ', f"no '{ch}' in the font"
    t = ["; generated by mkdata.py - do not edit", "",
         f"c_space = {C_SPACE}", f"c_bar = {C_BAR}", f"c_barl = {C_BARL}", f"c_barr = {C_BARR}",
         f"c_digit0 = {ord('0')}", f"c_pct = {ord('%')}", f"c_wall = {C_WALL}", f"c_rock = {C_ROCK}",
         f"c_edgel = {C_EDGEL}", f"c_edger = {C_EDGER}", f"c_floor = {C_FLOOR}",
         f"c_cornl = {C_CORNL}", f"c_cornr = {C_CORNR}", f"ship_rows = {SHIP_ROWS}", ""]
    # the girders' strips: 8 blank lines, the girder, 8 blank: a glyph of
    # the upper row at phase p is 8 bytes from 8 - p, of the lower row
    # from 16 - p
    for k, name in enumerate(('solid', 'lend', 'rend')):
        t += asm_bytes(f"strip{k}", [0] * 8 + mc(GIRDER[name]) + [0] * 8)
    for f in range(2):
        rows = ROCKET + FLAME[f]
        lx, rx = extents(rows, 3)
        t += asm_bytes(f"shiplx{f}", lx)
        t += asm_bytes(f"shiprx{f}", rx)
    lx0, rx0 = extents(ROCKET + FLAME[0], 3)
    lx1, rx1 = extents(ROCKET + FLAME[1], 3)
    t += [f"ship_minl = {min(min(lx0), min(lx1))}",
          f"ship_maxr = {max(max(rx0), max(rx1))}", ""]
    for k, v in TEXTS.items():
        t += asm_bytes(k, [len(v)] + [ord(c) for c in v])
    open(os.path.join(HERE, 'tables.asm'), 'w').write('\n'.join(t) + '\n')
    g = ["; generated by mkdata.py - do not edit",
         "; characters 4-127 (0-3 hold the module header, at $e000)", "", "*=$e020"]
    g += asm_bytes(None, [b for c in cs[4:128] for b in c])
    open(os.path.join(HERE, 'chars.asm'), 'w').write('\n'.join(g) + '\n')
    s = ["; generated by mkdata.py - do not edit",
         "; the rocket: frames 0 and 1 (its flame), 2 (a crash); 64 bytes each", ""]
    s += asm_bytes("sprites", sprite(ROCKET + FLAME[0], 3) + sprite(ROCKET + FLAME[1], 3) + sprite(CRASH, 0))
    open(os.path.join(HERE, 'sprites.asm'), 'w').write('\n'.join(s) + '\n')


if __name__ == '__main__':
    main()
