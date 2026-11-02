#!/usr/bin/env python3
"""Generate Crossy-Load's character set, hen images and text tables.

Writes (next to this file):
    chars.asm    characters 4-255 at $e020 (0-3 hold the module header)
    hengfx.asm   the hen's pre-shifted images and the and-mask table
    tables.asm   text in screen codes, character code equates
    preview.png  a mock-up in the C64 palette, 3x
Run by tools/build.py before the game is assembled.

Multicolour pixels: '.' %00 black (the background), 'W' %01 white
($d022), 'R' %10 red-brown ($d023), 'C' %11 the lane's colour (colour
ram, the same along a row).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))
from modfont import FONT  # noqa: E402

PAL = [(0, 0, 0), (255, 255, 255), (104, 55, 43), (112, 164, 178), (111, 61, 134),
       (88, 141, 67), (53, 40, 121), (184, 199, 111), (111, 79, 37), (67, 57, 0),
       (154, 103, 89), (68, 68, 68), (108, 108, 108), (154, 210, 132), (108, 94, 181),
       (149, 149, 149)]
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
MC1 = WHITE                       # $d022
MC2 = RED                         # $d023
MC = {'.': 0, 'W': 1, 'R': 2, 'C': 3}

# lane colours (colour ram, multicolour bit added in the code)
COL_GRASS, COL_WATER, COL_RAIL, COL_WARN = GREEN, BLUE, WHITE, RED
CAR_COLS = [YELLOW, CYAN, PURPLE, GREEN]      # (not red: logs are; not white: the windows are)


def mc_bytes(rows):
    """rows of 4 MC pixels -> bytes"""
    out = []
    for r in rows:
        assert len(r) == 4, r
        b = 0
        for ch in r:
            b = (b << 2) | MC[ch]
        out.append(b)
    return out


def cell(cols):
    """4 columns of 16 pixels (top to bottom) -> (top glyph, bottom glyph)"""
    assert len(cols) == 4 and all(len(c) == 16 for c in cols), cols
    rows = [''.join(c[y] for c in cols) for y in range(16)]
    return mc_bytes(rows[:8]), mc_bytes(rows[8:])


# ---------------------------------------------------------------- profiles
# An object that slides along its lane is a left end (two columns: outer,
# inner), a run of identical interior columns and a right end (inner,
# outer), over the lane's own background column. At shift p (0-3
# multicolour pixels into its first cell c0) its cells are
#     c0: L[p]   c0+1: LX if p = 3, else INT   ...   INT
#     c0+n-1: R0 if p = 0, RX if p = 1, else INT   c0+n: R[p] (p > 0)
# so a one-pixel move changes at most three cells. Each profile is 22
# characters: BG L0 L1 L2 L3 INT R0 R1 R2 R3 for the lane's top row, the
# same ten for its bottom row (+10), then LX and RX for the bottom row.
# LX and RX in the top row are INT's: an end's inner column has the
# interior's top half (the code writes INT there).

def profile(bg, capl, mid, capr):
    a, b = capl                       # outer, inner
    c, d = capr                       # inner, outer
    for inner in (b, c):
        assert inner[:8] == mid[:8], (inner, mid)
    g = [cell([bg] * 4),
         cell([a, b, mid, mid]), cell([bg, a, b, mid]), cell([bg, bg, a, b]), cell([bg, bg, bg, a]),
         cell([mid] * 4),
         cell([mid, mid, c, d]), cell([d, bg, bg, bg]), cell([c, d, bg, bg]), cell([mid, c, d, bg])]
    lx, rx = cell([b, mid, mid, mid]), cell([mid, mid, mid, c])
    assert lx[0] == g[5][0] and rx[0] == g[5][0]
    return [t for t, _ in g] + [b_ for _, b_ in g] + [lx[1], rx[1]]


#           0123456789abcdef   (pixel rows, top to bottom)
ROAD    = "................"
CAR_MID = "...WCC..CCCCRR.."     # roof edge, roof, windows, body, shade
CAR_IN  = "...WCC..CCCCRRR."     # (its top half as the middle) a wheel
CAR_OUT = "........CWCCR..."     # the bonnet, below the cabin: a light
WATER   = "CCCCCCCCCCCCCCCC"
LOG_MID = "CC..WRRRRRRRR.CC"     # dark edge, highlight, bark, waterline
LOG_IN  = "CC..WRRRRRRR.CCC"     # (its top half as the middle) rounder
LOG_OUT = "CCC..RWWWR..CCCC"     # the cut end
PROFILES = {
    'car': profile(ROAD, (CAR_OUT, CAR_IN), CAR_MID, (CAR_IN, CAR_OUT)),
    'log': profile(WATER, (LOG_OUT, LOG_IN), LOG_MID, (LOG_IN, LOG_OUT)),
}


def art(rows):
    """explicit art: 16 rows of 4 pixels -> (top, bottom)"""
    assert len(rows) == 16, rows
    return mc_bytes(rows[:8]), mc_bytes(rows[8:])


# the train moves a whole cell a tick, so its cells are drawn as they are
RAILS = ["....", "....", "....", "....", "....", "....", "....", "R...",
         "R...", "CCCC", "R...", "R...", "R...", "CCCC", "R...", "...."]
TRAIN_END = ["....", ".CCC", "CCCC", "CWWW", "CWWW", "CWWW", "CCCC", "CCCC",
             "CWWC", "CCCC", ".R.R", "....", "....", "CCCC", "R...", "...."]
TRAIN_MID = ["....", "CCCC", "CCCC", "WW.W", "WW.W", "WW.W", "CCCC", "CCCC",
             "CCCC", "CCCC", "R..R", "....", "....", "CCCC", "R...", "...."]


def mirror(rows):
    return [r[::-1] for r in rows]


def train_profile():
    bg = art(RAILS)
    le = art(TRAIN_END)
    mid = art(TRAIN_MID)
    re_ = art(mirror(TRAIN_END))
    no = ([0] * 8, [0] * 8)     # slots it never uses (grass and the bar caps go there)
    g = [bg, le, no, no, no, mid, re_, no, no, no]
    return [t for t, b in g] + [b for t, b in g]


PROFILES['train'] = train_profile()

# grass: a raised slab, its front face in soil below the top face
GRASS = ["CCCC"] * 13 + ["RRRR", "RRRR", "...."]
GRASS_TUFT = ["CCCC", "CCCC", "CCCC", "C.CC", "CCCC", "CCCC", "CCCC", "CCCC",
              "CCCC", "CCC.", "CC.C", "CCCC", "CCCC", "RRRR", "RRRR", "...."]
# a tree two cells wide, for the edges of grass lanes: a block of
# leaves (lit top, dark front) on a trunk
TREE = ["CC....CC", "C.WCWC.C", ".WCWCWC.", ".CCCCCC.", ".C.C.C..", "..C.C.C.",
        ".C.C.C..", "C......C", "CCC.R.CC", "CCCRR.CC", "CCCRR.CC", "CCCRR.CC",
        "CC....CC", "RRRRRRRR", "RRRRRRRR", "........"]
TREE_L = [r[:4] for r in TREE]
TREE_R = [r[4:] for r in TREE]

# ---------------------------------------------------------------- the hen
# A soft sprite: up to 9 multicolour pixels by 14 rows, drawn into a 3x3
# block of characters over what is there. White body, red-brown comb,
# beak and feet; the eye is a hole.
HEN = {
 'stand': [
  ".....RR..",
  "....RWWR.",
  "....WW.WR",
  "....WWWRR",
  "....WWWR.",
  "W...WWW..",
  "WW.WWWWW.",
  "WWWWWWWW.",
  "WWWWWWWW.",
  ".WWWWWWW.",
  "..WWWWW..",
  "...R.R...",
  "...R.R...",
  "..RR.RR..",
 ],
 'hop': [
  ".....RR..",
  "....RWWR.",
  "....WW.WR",
  "....WWWRR",
  "W...WWWR.",
  "WW.WWWW..",
  "WWWWWWWW.",
  "WWWWWWWW.",
  ".WWWWWWW.",
  "..WWWWW..",
  "..RR.RR..",
  ".........",
  ".........",
  ".........",
 ],
 'flat': [
  ".........",
  ".........",
  ".........",
  ".........",
  ".........",
  ".........",
  ".........",
  ".........",
  ".....RR..",
  "....RWWR.",
  ".WWWWW.WR",
  "WWWWWWWWR",
  ".WWWWWWW.",
  "RR.....RR",
 ],
}
HEN_NAMES = ['stand', 'flat']       # (a hop is the standing hen in an arc)
HEN_H = 14
HMC = {'.': 0, 'W': 1, 'R': 2}
for _n, _a in HEN.items():
    assert len(_a) == HEN_H and all(len(r) == 9 for r in _a), _n


def hen_shifted(rows, shift):
    out = []
    for r in rows:
        r = ('.' * shift + r).ljust(12, '.')[:12]
        v = 0
        for ch in r:
            v = (v << 2) | HMC[ch]
        out += [v >> 16, (v >> 8) & 255, v & 255]
    return out


HENIMG = []
for n in HEN_NAMES:
    for sh in (range(4) if n == 'stand' else range(1)):     # (she doesn't move when flat)
        img = hen_shifted(HEN[n], sh)
        HENIMG += [img[r * 3 + c] for c in range(3) for r in range(HEN_H)]   # column-major
INVMASK = []
for b in range(256):
    m = 0
    for i in range(4):
        if (b >> (2 * i)) & 3:
            m |= 3 << (2 * i)
    INVMASK.append(m ^ 255)

# ---------------------------------------------------------------- the status bar (hi-res)
BAR = []
for k in range(9):
    fill = (0xff << (8 - k)) & 0xff
    BAR.append([0, 0xff, fill, fill, fill, fill, 0xff, 0])
BAR_L = [0, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0]
BAR_R = [0, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0]

# ---------------------------------------------------------------- character codes
# 128 characters ($e000-$e3ff), so the screens can sit at $e400 and
# $e800, in the character set's other half that is never shown
HEN0, HEN1 = 4, 13            # the hen's two sets of 9 (4-21)
FONT_CHARS = " 0123456789ABCDEFGHILMNOPRSTVWY-!:,%"
FONT0 = 22
SCODE = {ch: FONT0 + i for i, ch in enumerate(FONT_CHARS)}
C_SPACE = SCODE[' ']
C_DIGIT0 = SCODE['0']
C_BAR = FONT0 + len(FONT_CHARS)            # 5: 0, 2, 4, 6, 8 pixels filled (gk_barhalf)
P_CAR = C_BAR + 5
P_LOG = P_CAR + 22
P_TRAIN = P_LOG + 22          # the train's block: BG L0 . . . INT R0 . . .
P_GRASS = P_TRAIN + 2         # grass in the train block's spare slots
G_PLAIN, G_TUFT, G_TREEL, G_TREER = 0, 1, 2, 5
C_BARL, C_BARR = P_TRAIN + 8, P_TRAIN + 9
NCHARS = P_TRAIN + 20
assert NCHARS <= 128, NCHARS

charset = [[0] * 8 for _ in range(128)]
for ch in FONT_CHARS:
    charset[SCODE[ch]] = [int(r.replace('#', '1').replace('.', '0'), 2) for r in FONT[ch] + ["........"]]
for k in range(5):
    charset[C_BAR + k] = BAR[2 * k]
for base, name in ((P_CAR, 'car'), (P_LOG, 'log'), (P_TRAIN, 'train')):
    for i, g in enumerate(PROFILES[name]):
        if any(g):
            charset[base + i] = g
for off, rows in ((G_PLAIN, GRASS), (G_TUFT, GRASS_TUFT), (G_TREEL, TREE_L), (G_TREER, TREE_R)):
    t, b = art(rows)
    for k, g in ((P_GRASS + off, t), (P_GRASS + 10 + off, b)):
        assert not any(charset[k]), k
        charset[k] = g
for k, g in ((C_BARL, BAR_L), (C_BARR, BAR_R)):
    assert not any(charset[k]), k
    charset[k] = g


def scode(ch):
    return SCODE[ch]


# ---------------------------------------------------------------- text
TEXTS = {
    'tx_title': "CROSSY-LOAD",
    'tx_score': "SCORE",
    'tx_best': "BEST",
    'tx_hop': "PRESS FIRE TO HOP",
    'tx_over': "GAME OVER",
    'tx_again': "GAME OVER - PRESS FIRE",
    'tx_splat': "SPLAT!",
    'tx_splash': "SPLASH!",
    'tx_swept': "SWEPT AWAY!",
    'tx_train': "CHOO CHOO!",
    'tx_loading': "LOADING",
    'tx_error': "TAPE ERROR: REWIND A BIT, PRESS PLAY",
    'tx_loaded': "LOADED! PRESS SPACE TO START THE GAME",
}
DEATHS = ['tx_splat', 'tx_splash', 'tx_swept', 'tx_train']


def asm_bytes(label, data, per=16):
    out = [f"{label}"] if label else []
    for i in range(0, len(data), per):
        out.append("        byte " + ','.join(f"${b:02x}" for b in data[i:i + per]))
    return out


def write_asm():
    eq = ["; generated by mkdata.py - do not edit", ""]
    eq += [f"c_space = {C_SPACE}", f"c_digit0 = {C_DIGIT0}", f"c_pct = {SCODE['%']}", f"hen0 = {HEN0}", f"hen1 = {HEN1}",
           f"hen_h = {HEN_H}", f"c_bar = {C_BAR}", f"c_barl = {C_BARL}", f"c_barr = {C_BARR}",
           f"p_car = {P_CAR}", f"p_log = {P_LOG}", f"p_train = {P_TRAIN}", f"p_grass = {P_GRASS}",
           f"g_tuft = {G_TUFT}", f"g_treel = {G_TREEL}", f"g_treer = {G_TREER}",
           f"col_grass = {COL_GRASS + 8}", f"col_water = {COL_WATER + 8}",
           f"col_rail = {COL_RAIL + 8}", f"col_warn = {COL_WARN + 8}", ""]
    eq += asm_bytes("carcols", [c + 8 for c in CAR_COLS])
    eq.append(f"ncarcols = {len(CAR_COLS)}")
    for k, v in TEXTS.items():
        codes = [scode(c) for c in v]
        eq += asm_bytes(k, [len(codes)] + codes)
    eq += ["deathlo  byte " + ','.join(f"<{k}" for k in DEATHS),
           "deathhi  byte " + ','.join(f">{k}" for k in DEATHS)]
    open(os.path.join(HERE, 'tables.asm'), 'w').write('\n'.join(eq) + '\n')

    assert not any(any(charset[i]) for i in range(4)), "characters 0-3 hold the header"
    assert not any(any(charset[i]) for i in range(HEN0, HEN1 + 9)), "hen sets"
    assert not any(charset[C_SPACE])
    g = ["; generated by mkdata.py - do not edit",
         "; characters 4-124 (0-3 hold the module header, at $e000; 125-127,",
         "; never shown, hold crossy.asm's own bytes)", "", "*=$e020", "charset4"]
    assert not any(any(c) for c in charset[125:128])
    g += asm_bytes(None, [b for c in charset[4:125] for b in c])
    open(os.path.join(HERE, 'chars.asm'), 'w').write('\n'.join(g) + '\n')

    # the and-masks and the hen, in the unused characters 212-255 and on
    g = ["; generated by mkdata.py - do not edit", "",
         "; and-masks: clear the background under the hen's pixels", "invmask"]
    g += asm_bytes(None, INVMASK)
    g += ["", f"; the hen: standing, 4 shifts; flat, 1 (3 columns of {HEN_H} each)", "henimg"]
    g += asm_bytes(None, HENIMG)
    open(os.path.join(HERE, 'hengfx.asm'), 'w').write('\n'.join(g) + '\n')


# ---------------------------------------------------------------- preview

def preview():
    from PIL import Image
    scr = [[C_SPACE] * 40 for _ in range(25)]
    charset_full = charset
    col = [[WHITE] * 40 for _ in range(25)]
    lanes = ['grass', 'road', 'road', 'water', 'water', 'grass', 'rail', 'road', 'grass', 'grass']

    def put(r, c, code, colour, base=None):
        # code: a profile cell; LX/RX (base + 10/11): INT on top, 20/21 below
        top, bot = code, code + 10
        if base is not None and code - base in (10, 11):
            top = base + 5
        if 0 <= c < 40:
            scr[r][c] = top
            if r + 1 < 25:
                scr[r + 1][c] = bot
            col[r][c] = colour
            if r + 1 < 25:
                col[r + 1][c] = colour

    def obj(r, base, x, n, colour):
        c0, p = x >> 2, x & 3
        put(r, c0, base + 1 + p, colour)
        for k in range(1, n - 1):
            put(r, c0 + k, base + (10 if k == 1 and p == 3 else 5), colour, base)
        put(r, c0 + n - 1, base + (6 if p == 0 else 11 if p == 1 else 5), colour, base)
        put(r, c0 + n, base + (6 + p if p else 0), colour)

    for i, kind in enumerate(lanes):
        r = 24 - 2 * i - 1
        if r < 4:
            break
        if kind == 'grass':
            for c in range(40):
                put(r, c, P_GRASS + (G_TUFT if c % 7 == 3 else 0), COL_GRASS | 8)
            for c in (0, 38):
                put(r, c, P_GRASS + G_TREEL, COL_GRASS | 8)
                put(r, c + 1, P_GRASS + G_TREER, COL_GRASS | 8)
        elif kind == 'road':
            cc = CAR_COLS[i % len(CAR_COLS)] | 8
            base = P_CAR
            for c in range(40):
                put(r, c, base, cc)
            for x in (5 + i, 70 + i, 115):
                obj(r, base, x, 3 if x < 100 else 5, cc)
        elif kind == 'water':
            for c in range(40):
                put(r, c, P_LOG, COL_WATER | 8)
            for x in (10 + i, 70 + 2 * i, 130):
                obj(r, P_LOG, x, 5, COL_WATER | 8)
        else:
            for c in range(40):
                put(r, c, P_TRAIN, COL_WARN | 8)
            for c in range(12, 30):
                put(r, c, P_TRAIN + (1 if c == 12 else 6 if c == 29 else 5), COL_WARN | 8)
    for i, t in enumerate(["SCORE 12", "CROSSY-LOAD", "BEST 34"]):
        c = [1, 14, 32][i]
        for k, ch in enumerate(t):
            scr[0][c + k] = scode(ch)
    for k, ch in enumerate("PRESS FIRE TO HOP"):
        scr[1][11 + k] = scode(ch)
    for k, ch in enumerate("LOADING"):
        scr[2][3 + k] = scode(ch)
    for k in range(20):
        scr[2][12 + k] = C_BAR + (4 if k < 9 else 0)
        col[2][12 + k] = YELLOW
    W, H = 320, 200
    img = Image.new('RGB', (W + 64, H + 70), PAL[0])
    px = img.load()
    for r in range(25):
        for c in range(40):
            gl = charset[scr[r][c]]
            cc = col[r][c]
            for y in range(8):
                b = gl[y]
                for x in range(8):
                    if cc & 8:
                        v = (b >> (6 - 2 * (x // 2))) & 3
                        rgb = PAL[[BLACK, MC1, MC2, cc & 7][v]]
                    else:
                        rgb = PAL[cc] if (b >> (7 - x)) & 1 else PAL[BLACK]
                    px[32 + c * 8 + x, 35 + r * 8 + y] = rgb

    def hen(name, sx, sy):
        for y, row in enumerate(HEN[name]):
            for x, ch in enumerate(row):
                if ch != '.':
                    rgb = PAL[{'W': MC1, 'R': MC2}[ch]]
                    px[sx + 2 * x, sy + y] = rgb
                    px[sx + 2 * x + 1, sy + y] = rgb
    hen('stand', 32 + 150, 35 + 8 * 21 + 1)
    for i, n in enumerate(HEN_NAMES):
        hen(n, 32 + 40 + i * 30, 35 + 205)
    img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    img.save(os.path.join(HERE, 'preview.png'))


if __name__ == '__main__':
    write_asm()
    try:
        preview()
    except ImportError:
        pass
