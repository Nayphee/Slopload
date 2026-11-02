#!/usr/bin/env python3
"""Generate Flappy-Load's graphics and text tables.

Writes (next to this file):
    gfx.asm     charset ($e800, 128 chars) and sprites ($ec00)
    tables.asm  text in screen codes, big score digits (code area)
    preview.png a mock-up of the screen in the C64 palette, 3x
Run by tools/build.py before the game is assembled.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- palette
PAL = [(0, 0, 0), (255, 255, 255), (104, 55, 43), (112, 164, 178), (111, 61, 134),
       (88, 141, 67), (53, 40, 121), (184, 199, 111), (111, 79, 37), (67, 57, 0),
       (154, 103, 89), (68, 68, 68), (108, 108, 108), (154, 210, 132), (108, 94, 181),
       (149, 149, 149)]
SKY, BLACK, GREEN, YELLOW, WHITE = 3, 0, 5, 7, 1
MC1 = WHITE                       # $d022: pipe highlights, the bird's eye
MC2 = BLACK                       # $d023: outlines

# ---------------------------------------------------------------- font
FONT = {
 '0': [".######.", "##...###", "##..####", "##.##.##", "####..##", "###...##", ".######."],
 '1': ["...##...", "..###...", ".####...", "...##...", "...##...", "...##...", ".######."],
 '2': [".######.", "##....##", ".....##.", "...###..", ".###....", "##......", "########"],
 '3': [".######.", "##....##", "......##", "..#####.", "......##", "##....##", ".######."],
 '4': ["....###.", "...####.", "..##.##.", ".##..##.", "########", ".....##.", ".....##."],
 '5': ["########", "##......", "#######.", "......##", "......##", "##....##", ".######."],
 '6': [".######.", "##......", "##......", "#######.", "##....##", "##....##", ".######."],
 '7': ["########", "......##", ".....##.", "....##..", "...##...", "...##...", "...##..."],
 '8': [".######.", "##....##", "##....##", ".######.", "##....##", "##....##", ".######."],
 '9': [".######.", "##....##", "##....##", ".#######", "......##", "......##", ".######."],
 'A': ["..####..", ".##..##.", "##....##", "##....##", "########", "##....##", "##....##"],
 'B': ["#######.", "##....##", "##....##", "#######.", "##....##", "##....##", "#######."],
 'C': [".######.", "##....##", "##......", "##......", "##......", "##....##", ".######."],
 'D': ["######..", "##...##.", "##....##", "##....##", "##....##", "##...##.", "######.."],
 'E': ["########", "##......", "##......", "######..", "##......", "##......", "########"],
 'F': ["########", "##......", "##......", "######..", "##......", "##......", "##......"],
 'G': [".######.", "##....##", "##......", "##..####", "##....##", "##....##", ".######."],
 'H': ["##....##", "##....##", "##....##", "########", "##....##", "##....##", "##....##"],
 'I': [".######.", "...##...", "...##...", "...##...", "...##...", "...##...", ".######."],
 'J': ["....####", ".....##.", ".....##.", ".....##.", "##...##.", "##...##.", ".#####.."],
 'K': ["##...##.", "##..##..", "##.##...", "####....", "##.##...", "##..##..", "##...##."],
 'L': ["##......", "##......", "##......", "##......", "##......", "##......", "########"],
 'M': ["##....##", "###..###", "########", "##.##.##", "##....##", "##....##", "##....##"],
 'N': ["##....##", "###...##", "####..##", "##.##.##", "##..####", "##...###", "##....##"],
 'O': [".######.", "##....##", "##....##", "##....##", "##....##", "##....##", ".######."],
 'P': ["#######.", "##....##", "##....##", "#######.", "##......", "##......", "##......"],
 'Q': [".######.", "##....##", "##....##", "##....##", "##.##.##", "##..##..", ".###.##."],
 'R': ["#######.", "##....##", "##....##", "#######.", "##.##...", "##..##..", "##...##."],
 'S': [".######.", "##....##", "##......", ".######.", "......##", "##....##", ".######."],
 'T': ["########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
 'U': ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", ".######."],
 'V': ["##....##", "##....##", "##....##", "##....##", ".##..##.", "..####..", "...##..."],
 'W': ["##....##", "##....##", "##....##", "##.##.##", "########", "###..###", "##....##"],
 'X': ["##....##", ".##..##.", "..####..", "...##...", "..####..", ".##..##.", "##....##"],
 'Y': ["##....##", ".##..##.", "..####..", "...##...", "...##...", "...##...", "...##..."],
 'Z': ["########", ".....##.", "....##..", "...##...", "..##....", ".##.....", "########"],
 '!': ["...##...", "...##...", "...##...", "...##...", "...##...", "........", "...##..."],
 '-': ["........", "........", "........", ".######.", "........", "........", "........"],
 '%': ["##....##", "##...##.", "....##..", "...##...", "..##....", ".##...##", "##....##"],
 ':': ["........", "...##...", "...##...", "........", "...##...", "...##...", "........"],
 '.': ["........", "........", "........", "........", "........", "...##...", "...##..."],
 ',': ["........", "........", "........", "........", "...##...", "...##...", "..##...."],
 '?': [".######.", "##....##", ".....##.", "....##..", "...##...", "........", "...##..."],
 "'": ["...##...", "...##...", "..##....", "........", "........", "........", "........"],
 ' ': ["........"] * 7,
}


def scode(ch):
    """Character code: plain ASCII (letters 65-90). Codes 0-1 hold the
    game module's header, 96-127 the graphics."""
    return ord(ch)


def glyph(ch):
    rows = FONT[ch] + ["........"]
    return [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows]

# ---------------------------------------------------------------- multicolour chars
# %00 sky, %01 white ($d022), %10 black ($d023), %11 cell colour
MC = {'.': 0, 'L': 1, 'K': 2, 'G': 3}


def mc_rows(rows):
    """8 strings of 4 MC pixels -> 8 bytes."""
    out = []
    for r in rows:
        assert len(r) == 4, r
        b = 0
        for ch in r:
            b = (b << 2) | MC[ch]
        out.append(b)
    return out


def split4(row16):
    return [row16[i:i + 4] for i in (0, 4, 8, 12)]


# pipe: 16 MC pixels across 4 chars; body is pixels 2-13, cap 0-15
BODY = "..KGLGGGGGGGGK.."
CAP_IN = "KGGLGGGGGGGGGGGK"
CAP_EDGE = "KKKKKKKKKKKKKKKK"


def chars4(rows16):
    """8 rows of 16 MC pixels -> 4 chars of 8 bytes"""
    cols = [[], [], [], []]
    for r in rows16:
        for i, part in enumerate(split4(r)):
            cols[i].append(part)
    return [mc_rows(c) for c in cols]


PIPE_BODY = chars4([BODY] * 8)
CAP_TOP = chars4([CAP_EDGE] + [CAP_IN] * 7)
CAP_BOT = chars4([CAP_IN] * 7 + [CAP_EDGE])

GRASS = mc_rows(["KKKK", "GGGG", "GGGK", "GGKG", "GKGG", "KGGG", "GGGG", "KKKK"])
DIRT = mc_rows(["GGGG", "GGGG", "GGGG", "GGGG", "GGGG", "GGGG", "GGGG", "GGGG"])
DIRT_END = mc_rows(["GGGG", "GGGG", "GGGG", "GGGG", "GGGG", "GGGG", "KKKK", "KKKK"])
BAND = [0xff] * 8

# hi-res progress bar: frame lines in rows 1 and 6, fill in rows 2-5
BAR = []
for k in range(9):
    fill = (0xff << (8 - k)) & 0xff
    BAR.append([0, 0xff, fill, fill, fill, fill, 0xff, 0])
BAR_L = [0, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0]     # end caps
BAR_R = [0, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0]

# char codes (text uses screen codes 1-63)
C_SKY = 32
C_BODY = 96          # 96-99
C_CAPT = 100         # 100-103
C_CAPB = 104         # 104-107
C_GRASS = 108
C_DIRT = 109
C_DIRTE = 110
C_BAND = 111
C_BAR = 112          # 112-120: 0-8 pixels filled
C_BARL = 121
C_BARR = 122

charset = [[0] * 8 for _ in range(128)]
for ch in FONT:
    charset[scode(ch)] = glyph(ch)
for i in range(4):
    charset[C_BODY + i] = PIPE_BODY[i]
    charset[C_CAPT + i] = CAP_TOP[i]
    charset[C_CAPB + i] = CAP_BOT[i]
charset[C_GRASS] = GRASS
charset[C_DIRT] = DIRT
charset[C_DIRTE] = DIRT_END
charset[C_BAND] = BAND
for k in range(9):
    charset[C_BAR + k] = BAR[k]
charset[C_BARL] = BAR_L
charset[C_BARR] = BAR_R

# ---------------------------------------------------------------- the bird
# A soft sprite: 9 multicolour pixels by 11 rows, drawn into a 3x3 block
# of characters at run time. Y yellow (cell colour), W white, K black.
BIRD = {
 'up': [
  "...KKKK..",
  "..KYYKWK.",
  "KKKYKWWWK",
  "KWWKKWWKK",
  "KWWWKKWWK",
  ".KKKYYYKK",
  ".KYYYYKWK",
  ".KYYYYKKK",
  ".KYYYYYK.",
  "..KYYYYK.",
  "...KKKK..",
 ],
 'mid': [
  "...KKKK..",
  "..KYYKWK.",
  ".KYYKWWWK",
  ".KYYKWWKK",
  "KKKKYKWWK",
  "KWWWKYYKK",
  "KWWWKYKWK",
  ".KKKYYKKK",
  ".KYYYYYK.",
  "..KYYYYK.",
  "...KKKK..",
 ],
 'down': [
  "...KKKK..",
  "..KYYKWK.",
  ".KYYKWWWK",
  ".KYYKWWKK",
  ".KYYYKWWK",
  "KKKKYYYKK",
  "KWWWKYKWK",
  "KWWWKYKKK",
  ".KKKYYYK.",
  "..KYYYYK.",
  "...KKKK..",
 ],
}
for _n, _a in BIRD.items():
    assert len(_a) == 11 and all(len(r) == 9 for r in _a), _n
BIRD_NAMES = ['up', 'mid', 'down']
BIRD_H = 11
BMC = {'.': 0, 'W': 1, 'K': 2, 'Y': 3}


def bird_shifted(art, shift):
    """3 bytes x BIRD_H rows: the art moved right by shift MC pixels."""
    rows = (art + ['.' * 10] * BIRD_H)[:BIRD_H]
    out = []
    for r in rows:
        r = ('.' * shift + r).ljust(12, '.')[:12]
        v = 0
        for ch in r:
            v = (v << 2) | BMC[ch]
        out += [v >> 16, (v >> 8) & 255, v & 255]
    return out


BIRDIMG = []
for n in BIRD_NAMES:
    for sh in range(4):
        img = bird_shifted(BIRD[n], sh)
        # column by column (11 bytes each): render walks a column's
        # image and its 24 bytes of glyphs with one index
        BIRDIMG += [img[r * 3 + c] for c in range(3) for r in range(BIRD_H)]
# and-mask that clears the background under each drawn pixel
INVMASK = []
for b in range(256):
    m = 0
    for i in range(4):
        if (b >> (2 * i)) & 3:
            m |= 3 << (2 * i)
    INVMASK.append(m ^ 255)

# ---------------------------------------------------------------- text
TEXTS = {
    'tx_title': "FLAPPY-LOAD",
    'tx_ready': "GET READY!",
    'tx_fire': "PRESS FIRE TO FLAP",
    'tx_over': "GAME OVER",
    'tx_score': "SCORE",
    'tx_best': "BEST",
    'tx_again': "PRESS FIRE",
    'tx_loading': "LOADING",
    'tx_error': "TAPE ERROR: REWIND A BIT, PRESS PLAY",
    'tx_loaded': "LOADED! PRESS SPACE TO START THE GAME",
}


LATE_TEXTS = ('tx_error', 'tx_loaded')       # placed after the band copies ($f3xx)


def asm_bytes(label, data, per=16):
    out = [f"{label}"] if label else []
    for i in range(0, len(data), per):
        out.append("        byte " + ','.join(f"${b:02x}" for b in data[i:i + per]))
    return out


def write_asm():
    lines = ["; generated by mkdata.py - do not edit", ""]
    lines += [f"c_sky = {C_SKY}", f"c_body = {C_BODY}", f"c_capt = {C_CAPT}", f"c_capb = {C_CAPB}",
              f"c_grass = {C_GRASS}", f"c_dirt = {C_DIRT}", f"c_dirte = {C_DIRTE}", f"c_band = {C_BAND}",
              f"c_bar = {C_BAR}", f"c_barl = {C_BARL}", f"c_barr = {C_BARR}",
              f"bird_h = {BIRD_H}", ""]
    for k, v in TEXTS.items():
        if k in LATE_TEXTS:
            continue
        codes = [scode(c) for c in v]
        lines += asm_bytes(k, [len(codes)] + codes)
    open(os.path.join(HERE, 'tables.asm'), 'w').write('\n'.join(lines) + '\n')

    # the module header's place: characters 0-3 (2-3 are bird characters,
    # drawn at run time, after init has read the header)
    assert not any(any(charset[i]) for i in range(4))
    g = ["; generated by mkdata.py - do not edit",
         "; characters 4-127 (0-3 hold the module header, at $e000)", "", "*=$e020", "charset4"]
    g += asm_bytes(None, [b for c in charset[4:128] for b in c])
    open(os.path.join(HERE, 'chars.asm'), 'w').write('\n'.join(g) + '\n')
    assert not any(charset[C_SKY])      # render fills sky cells with zeros
    g = ["; generated by mkdata.py - do not edit", "",
         "; and-masks: clear the background under the bird's pixels", "*=$f000", "invmask"]
    g += asm_bytes(None, INVMASK)
    g += ["", "; the bird: 3 frames x 4 shifts x 33 bytes (3 columns of 11)", "birdimg"]
    g += asm_bytes(None, BIRDIMG)
    g += [""] + copy_bands()
    # the longest messages, in the room left before the screens
    late = 0
    for k in LATE_TEXTS:
        codes = [scode(c) for c in TEXTS[k]]
        g += asm_bytes(k, [len(codes)] + codes)
        late += 1 + len(codes)
    open(os.path.join(HERE, 'birdgfx.asm'), 'w').write('\n'.join(g) + '\n')
    end = 0xf100 + len(BIRDIMG) + COPY_BYTES + late
    assert end <= 0xf400, f"birdgfx.asm runs into screen a: ${end:04x}"


# the play field's bands (rows 0-6, 7-13, 14-19), copied one a tick
BANDS = [(0, 7), (7, 14), (14, 20)]
COPY_BYTES = sum(2 * (2 + 6 * (e - s) + 4) for s, e in BANDS)


def copy_bands():
    """cp<buffer><band>: copy a band of the buffer on show into the
    other one, one character to the left. Each band is one run: column
    39 gets the next row's column 0, which the new column then
    replaces. About 9.5 cycles a byte (the loop was 16)."""
    out = ["; ---- band copies (cpa: screen a on show, to b; cpb: b to a)"]
    for name, src, dst in (('cpa', 0xf400, 0xf800), ('cpb', 0xf800, 0xf400)):
        for i, (s, e) in enumerate(BANDS):
            out.append(f"{name}{i}   ldx #39")
            out.append(f"@l")
            for r in range(s, e):
                out.append(f"        lda ${src + r * 40 + 1:04x},x")
                out.append(f"        sta ${dst + r * 40:04x},x")
            out += ["        dex", "        bpl @l", "        rts"]
    return out

# ---------------------------------------------------------------- preview

def preview():
    from PIL import Image
    W, H = 320, 200
    img = Image.new('RGB', (W + 64, H + 70), PAL[0])
    px = img.load()
    cellc = {}
    scr = [[C_SKY] * 40 for _ in range(25)]
    col = [[SKY | 8] * 40 for _ in range(25)]
    for r in range(25):
        for c in range(40):
            col[r][c] = GREEN | 8
    def pipe(x, gap):
        for r in range(20):
            if r < gap - 2 or r >= gap + 8:
                ch = C_BODY
            elif r == gap - 2 or r == gap + 6:
                ch = C_CAPT
            elif r == gap - 1 or r == gap + 7:
                ch = C_CAPB
            else:
                continue
            for k in range(4):
                if 0 <= x + k < 40:
                    scr[r][x + k] = ch + k
    pipe(18, 6)
    pipe(30, 9)
    for c in range(40):
        scr[20][c] = C_GRASS
        scr[21][c] = C_DIRT
        scr[22][c] = C_DIRTE
        col[21][c] = col[22][c] = YELLOW | 8
        scr[23][c] = C_BAND
        col[23][c] = 0
    status = "LOADING "
    for i, ch in enumerate(status):
        scr[24][3 + i] = scode(ch)
        col[24][3 + i] = WHITE
    for i in range(20):
        scr[24][11 + i] = C_BAR + (8 if i < 9 else (5 if i == 9 else 0))
        col[24][11 + i] = YELLOW
    for i, ch in enumerate(" 47%"):
        scr[24][31 + i] = scode(ch)
        col[24][31 + i] = WHITE
    for i, ch in enumerate("GET READY!"):
        scr[6][15 + i] = scode(ch)
        col[6][15 + i] = WHITE
    for r in range(25):
        bg = SKY if r < 23 else BLACK
        for c in range(40):
            gl = charset[scr[r][c]]
            cc = col[r][c]
            for y in range(8):
                b = gl[y]
                if cc & 8:
                    for x in range(4):
                        v = (b >> (6 - 2 * x)) & 3
                        rgb = PAL[[bg, MC1, MC2, cc & 7][v]]
                        px[32 + c * 8 + 2 * x, 35 + r * 8 + y] = rgb
                        px[32 + c * 8 + 2 * x + 1, 35 + r * 8 + y] = rgb
                else:
                    for x in range(8):
                        rgb = PAL[cc] if (b >> (7 - x)) & 1 else PAL[bg]
                        px[32 + c * 8 + x, 35 + r * 8 + y] = rgb
    def draw_bird(name, sx, sy):
        for y, r in enumerate(BIRD[name]):
            for x, ch in enumerate(r):
                if ch != '.':
                    rgb = PAL[{'W': MC1, 'K': MC2, 'Y': YELLOW}[ch]]
                    px[sx + 2 * x, sy + y] = rgb
                    px[sx + 2 * x + 1, sy + y] = rgb
    draw_bird('mid', 32 + 74, 35 + 64)
    for i, n in enumerate(BIRD_NAMES):
        draw_bird(n, 32 + 40 + i * 30, 35 + 120)
    img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    img.save(os.path.join(HERE, 'preview.png'))


if __name__ == '__main__':
    write_asm()
    try:
        preview()
    except ImportError:
        pass
