#!/usr/bin/env python3
"""Rubble-Load's graphics and texts.

Writes (next to this file):
    chars.asm    characters 4-127 at $e020 (0-3 hold the module header)
    sprites.asm  the plane's sprite frames (right, left, the crash)
    tables.asm   the charge's glyph strip, the plane's extents, texts in
                 screen codes, the character codes the kit and the game
                 need
Run by tools/build.py before the module is assembled.

Text uses plain ASCII codes (the shared font's letters at 65-90, digits
at 48-57); the status bar's characters are at 96-106.

Multicolour characters (the town, the street, the charge and the
blasts): pairs '.' 00 the sky ($d021), 'a' 01 $d022 (the walls), 'd' 10
$d023 (frames and shadow), 'h' 11 the cell's colour ram (a block's
windows, the charge's sticks, a blast's fire). A block's characters have
no sky in them: a block is solid across every cell it covers, which is
what the plane collides with.

The plane: one multicolour sprite, pairs 'r' 01 $d025 (red trim), 'w' 10
its own colour (white), 'y' 11 $d026 (grey: the propeller, the wheels),
8 lines tall so that it flies in one character row.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))
from modfont import FONT  # noqa: E402

C_SPACE = 32
C_CHARGE = 4                  # 4 its upper cell, 5 its lower (glyphs redrawn each frame)
C_BLOCK = 6                   # 6-17: style s at 6 + 4s; +2 a storey's lower row, +1 its right half
C_STREET = 18                 # 18 a road marking, 19 none
C_BAR = 96                    # 96-104: 0-8 pixels filled (hi-res)
C_BARL, C_BARR = 105, 106
C_BLAST = 107                 # 107-122: frame f at 107 + 4f: upper left, upper right, lower left, lower right

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


def quarters(art):
    """16 rows of 8 multicolour pixels -> 4 characters (upper left,
    upper right, lower left, lower right)"""
    assert len(art) == 16 and all(len(r) == 8 for r in art), art
    return [mc([r[4 * c:4 * c + 4] for r in art[8 * h:8 * h + 8]]) for h in (0, 1) for c in (0, 1)]


# the blocks: a storey is 2 x 2 characters (16 pixels square); the
# storey's top line is its floor slab, dark, which reads as the roof's
# edge on the top storey. Each block's right column is its shady side.
STYLES = [
    # offices: a grid of lit windows
    ["dddddddd",
     "aaaaaaad",
     "ahhdahhd",
     "ahhdahhd",
     "ahhdahhd",
     "adddaddd",
     "aaaaaaad",
     "aaaaaaad",
     "aaaaaaad",
     "ahhdahhd",
     "ahhdahhd",
     "ahhdahhd",
     "adddaddd",
     "aaaaaaad",
     "aaaaaaad",
     "adadadad"],
    # brick flats: tall windows under lintels, courses of brick
    ["dddddddd",
     "dadddadd",
     "aaadaaad",
     "dhhddhhd",
     "dhhddhhd",
     "dhhddhhd",
     "dhhddhhd",
     "addaaddd",
     "ddaddddd",
     "dddddadd",
     "aaadaaad",
     "dhhddhhd",
     "dhhddhhd",
     "dhhddhhd",
     "dhhddhhd",
     "addaaddd"],
    # a glass tower: panels between steel mullions, a band each floor
    ["dddddddd",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "dddddddd",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "ahhahhad",
     "aaaaaaad",
     "dddddddd"],
]

# the street under the town (row 23): a kerb, asphalt, a dashed line
STREET = ["aaaa", "dddd", "dddd", "dddd", "dhhd", "dddd", "dddd", "dddd"]
STREET_PLAIN = ["aaaa", "dddd", "dddd", "dddd", "dddd", "dddd", "dddd", "dddd"]

# the charge: a bundle of red sticks (the sky's colour ram), two bands,
# a fuse (8 lines)
CHARGE = ["..a.",
          ".a..",
          "hhhh",
          "dddd",
          "hhhh",
          "hhhh",
          "dddd",
          "hhhh"]

# a blast where a storey was: fire (the cell's colour, yellow), smoke
# (the walls' two colours), four frames
BLAST = [
    ["........",
     "........",
     "........",
     "........",
     "...h....",
     "..hhh.h.",
     ".hhhhhh.",
     "..hhhhh.",
     ".hhhhhh.",
     "..hhhh..",
     "...hhh..",
     "..h..h..",
     "........",
     "........",
     "........",
     "........"],
    ["...a..d.",
     ".d......",
     "....h..a",
     "..hhhh..",
     ".hhhhhh.",
     "hhhhhhhh",
     "ahhhhhhd",
     ".hhhhhh.",
     "hhhhhhhh",
     ".hhhhhh.",
     "dhhhhhha",
     "..hhhh..",
     ".h.hh.h.",
     "a......d",
     "...d....",
     "........"],
    ["..a..a..",
     "a..aa..d",
     "..aaaa..",
     ".aaddaa.",
     "aadhhdaa",
     "adhhhhda",
     "adhhhhda",
     "aadhhdaa",
     ".aaddaa.",
     "aaddddaa",
     ".adaada.",
     "..a..a..",
     ".d....d.",
     "........",
     "a......a",
     "........"],
    ["........",
     "..a..a..",
     "........",
     "...a....",
     ".a..d.a.",
     "...dd...",
     "..d..d..",
     ".a.aa.a.",
     "...dd...",
     "..a..a..",
     ".d....d.",
     "....a...",
     "..a.....",
     "......a.",
     "........",
     "........"],
]

# the plane, flying right (its nose and propeller on the right); frames
# 0 and 1 turn the propeller. Left: the same, mirrored
PLANE = [
    "r...........",
    "rr...wwwww..",
    "rrr.wwrrwww.",
    "wwwwwwwwwww.",
    "rrrrrrrrrww.",
    "...wwwwww...",
    "....y..y....",
    "...yy..yy...",
]
PROP = ["yyyy", ".yy."]          # the propeller (column 11, lines 2-5), frames 0 and 1
CRASH = [
    "....r.......",
    "..r..y..r...",
    "...yyyy...r.",
    "r.ywwwwy....",
    "..ywrrwy.r..",
    ".yywrrwyy...",
    "..ywwwwy..r.",
    "r..yyyy.....",
    "...y..y.r...",
    ".r..r.....r.",
    "......r.....",
]


def frame_rows(f):
    """the plane's 8 rows (flying right), propeller frame f"""
    rows = list(PLANE)
    for i, p in enumerate(PROP[f]):
        rows[2 + i] = rows[2 + i][:11] + p
    return rows


def sprite(rows):
    """multicolour rows (12 pixels of 2 bits) -> 64 bytes"""
    sp = {'.': 0, 'r': 1, 'w': 2, 'y': 3}
    out = []
    for y in range(21):
        bits = [0] * 12
        if y < len(rows):
            for i, ch in enumerate(rows[y]):
                bits[i] = sp[ch]
        v = 0
        for b in bits:
            v = v << 2 | b
        out += [v >> 16 & 255, v >> 8 & 255, v & 255]
    return out + [0]


def extent(rows):
    """the first and last drawn hi-res pixel of the plane (from the
    sprite's left); every column between them has a pixel in it, so a
    block's cell (all 8 lines solid) overlaps the plane exactly when its
    columns do"""
    xs = sorted({2 * i + d for r in rows for i, ch in enumerate(r) if ch != '.' for d in (0, 1)})
    assert xs == list(range(xs[0], xs[-1] + 1)), "the plane's pixels must cover its width"
    return xs[0], xs[-1]


TEXTS = {
    'tx_title': "RUBBLE-LOAD",
    'tx_t1': "THE OLD TOWN IS COMING DOWN",
    'tx_t2': "FIRE DROPS A CHARGE BELOW THE PLANE",
    'tx_t3': "IT FLIES A ROW LOWER EVERY PASS:",
    'tx_t4': "FLATTEN THE SITE, THEN LAND",
    'tx_t5': "FIRE TO PLAY",
    'tx_over': "GAME OVER - FIRE TO PLAY AGAIN",
    'tx_go': "CLEAR THE SITE!",
    'tx_flat': "SITE CLEAR - TOUCH DOWN",
    'tx_landed': "LANDED! BONUS 250",
    'tx_town': "TOWN",
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
    for s, art in enumerate(STYLES):
        assert all('.' not in r for r in art), "a block is solid: no sky in it"
        ul, ur, ll, lr = quarters(art)
        cs[C_BLOCK + 4 * s:C_BLOCK + 4 * s + 4] = [ul, ur, ll, lr]
    cs[C_STREET] = mc(STREET)
    cs[C_STREET + 1] = mc(STREET_PLAIN)
    for f, art in enumerate(BLAST):
        cs[C_BLAST + 4 * f:C_BLAST + 4 * f + 4] = quarters(art)
    return cs


def main():
    cs = charset()
    assert not any(any(cs[i]) for i in range(4)), "characters 0-3 hold the header"
    for ch in ''.join(TEXTS.values()):
        assert ch in FONT or ch == ' ', f"no '{ch}' in the font"
    used = set(range(C_BLOCK, C_STREET + 2)) | set(range(C_BLAST, C_BLAST + 16)) | {C_CHARGE, C_CHARGE + 1}
    font = {ord(c) for c in FONT} | set(range(C_BAR, C_BARR + 1))
    assert not used & font, "graphics over the font"
    t = ["; generated by mkdata.py - do not edit", "",
         f"c_space = {C_SPACE}", f"c_bar = {C_BAR}", f"c_barl = {C_BARL}", f"c_barr = {C_BARR}",
         f"c_digit0 = {ord('0')}", f"c_pct = {ord('%')}", f"c_charge = {C_CHARGE}", f"c_block = {C_BLOCK}",
         f"c_street = {C_STREET}", f"c_blast = {C_BLAST}", f"nstyles = {len(STYLES)}", ""]
    # the charge's strip: 8 blank lines, the charge, 8 blank: its upper
    # cell's glyph at phase p is 8 bytes from 8 - p, its lower cell's
    # from 16 - p
    t += asm_bytes("cstrip", [0] * 8 + mc(CHARGE) + [0] * 8)
    # the plane's drawn width in each frame (0, 1 right; 2, 3 left), hi-res
    # pixels from the sprite's left
    ext = [extent(frame_rows(f)) for f in (0, 1)]
    ext += [(23 - r, 23 - l) for l, r in ext]
    t += asm_bytes("plx", [e[0] for e in ext])
    t += asm_bytes("prx", [e[1] for e in ext])
    l0, r0 = ext[0]
    t += [f"baypx = {(l0 + r0) // 2}", ""]          # where a charge leaves, flying right
    t += [f"baypxl = {23 - (l0 + r0) // 2}", ""]    # ... and left
    for k, v in TEXTS.items():
        t += asm_bytes(k, [len(v)] + [ord(c) for c in v])
    open(os.path.join(HERE, 'tables.asm'), 'w').write('\n'.join(t) + '\n')
    g = ["; generated by mkdata.py - do not edit",
         "; characters 4-127 (0-3 hold the module header, at $e000)", "", "*=$e020"]
    g += asm_bytes(None, [b for c in cs[4:128] for b in c])
    open(os.path.join(HERE, 'chars.asm'), 'w').write('\n'.join(g) + '\n')
    s = ["; generated by mkdata.py - do not edit",
         "; the plane: frames 0, 1 flying right (the propeller), 2, 3 left, 4 a crash; 64 bytes each", ""]
    frames = [frame_rows(0), frame_rows(1)]
    frames += [[r[::-1] for r in fr] for fr in frames]
    s += asm_bytes("sprites", [b for fr in frames for b in sprite(fr)] + sprite(CRASH))
    open(os.path.join(HERE, 'sprites.asm'), 'w').write('\n'.join(s) + '\n')


if __name__ == '__main__':
    main()
