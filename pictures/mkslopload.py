#!/usr/bin/env python3
"""SlopLoad's demo picture, written as a Koala Painter file
(pictures/slopload.koa): SLOPLOAD in chunky slanted letters, a rainbow
through them, a white top edge, blue depth and black speed lines,
a rippling reflection under it, rainbow stripes at the top and bottom and
a few stars. It goes on SlopLoad 64's disks (tools/c64build.py) and is a
picture to try on the PC tool (-module pictures/slopload.koa) and PICTURE-LM.

Run by hand after changing it; with a file name, also a picture of it
(a PNG, twice the size):

    python3 pictures/mkslopload.py [preview.png]

The letters are drawn here (no fonts needed), four times finer than the
C64's hires pixels, slanted, then sampled at the multicolour pixels (two
hires pixels wide). Each 4x8 cell may have the background and three
colours; the design keeps to that (each rainbow band is a cell row), and
the script stops if a cell has more.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'slopload.koa')

BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = 0, 1, 2, 3, 4, 5, 6, 7
ORANGE, BROWN, LRED, DGREY, GREY, LGREEN, LBLUE, LGREY = 8, 9, 10, 11, 12, 13, 14, 15
BG = BLACK
RAINBOW = [LRED, ORANGE, YELLOW, LGREEN, GREEN, CYAN, LBLUE, PURPLE]     # top to bottom, a band a cell row
HILITE, SHADOW = WHITE, BLUE
WATER = [LBLUE, LBLUE, CYAN, LBLUE, BLUE, LBLUE, BLUE, BLUE]           # the reflection, by its cell row

SS = 4                      # design pixels a hires pixel
H = 64                      # letter height (hires pixels = lines)
TOP = 48                    # the logo's top line (a cell row's first)
STEM, BAR = 8, 11           # stroke widths: upright (hires pixels), across (lines)
SLANT = 0.18                # sideways per line up
GAP = 10                    # between letters
WIDTH = {'S': 27, 'L': 22, 'O': 28, 'P': 27, 'A': 28, 'D': 28}
SPEED = {4: 1, 5: 1, 6: 2}  # band: black lines cut at its foot
DEPTH = [(1, 1), (1, 2), (2, 3), (2, 4)]   # the block's depth: steps right (multicolour pixels) and down

# the C64's colours, as VICE's default palette (colodore) shows them
PAL = ["000000", "ffffff", "813338", "75cec8", "8e3c97", "56ac4d", "2e2c9b", "edf171",
       "8e5029", "553800", "c46c71", "4a4a4a", "7b7b7b", "a9ff9f", "706deb", "b2b2b2"]


def glyph(ch):
    """one letter's shape (an L image, 255 inside), cut from a rounded block"""
    w, h = WIDTH[ch] * SS, H * SS
    v, t, r = STEM * SS, BAR * SS, 10 * SS
    mid = h // 2
    im = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(im)

    def block(radius=r, corners=None):
        radius = min(radius, (w - 1) // 2 - 1)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255, corners=corners)

    def cut(x0, y0, x1, y1, radius=3 * SS):
        d.rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius=radius, fill=0)

    if ch == 'S':
        block(radius=14 * SS)
        cut(v, t, w + r, mid - t // 2)              # open to the right above the middle
        cut(-r, mid + t // 2, w - v, h - t)         # and to the left below it
    elif ch == 'L':
        block(corners=(True, False, True, True))
        cut(v, -r, w + r, h - t)
    elif ch == 'O':
        block(radius=15 * SS)
        cut(v, t, w - v, h - t, 5 * SS)
    elif ch == 'P':
        block(corners=(True, True, True, True))
        cut(v, t, w - v, mid - t // 2, 4 * SS)
        cut(v, mid + t // 2, w + r, h + r)
    elif ch == 'A':
        block(radius=16 * SS, corners=(True, True, False, False))
        cut(v, t, w - v, mid - t // 2, 5 * SS)
        cut(v, mid + t // 2, w - v, h + r)
    elif ch == 'D':
        block(radius=16 * SS, corners=(False, True, True, False))
        cut(v, t, w - v, h - t, 6 * SS)
    return im


def logo_mask(text):
    """the word, slanted, as multicolour pixels: a set of (x, y)"""
    widths = [WIDTH[c] for c in text]
    span = sum(widths) + GAP * (len(text) - 1) + SLANT * H
    x = (320 - span) / 2
    canvas = Image.new('L', (320 * SS, 200 * SS), 0)
    for c, w in zip(text, widths):
        canvas.paste(glyph(c), (round(x * SS), TOP * SS))
        x += w + GAP
    base = (TOP + H) * SS                           # slanted about the foot: the top leans right
    canvas = canvas.transform(canvas.size, Image.AFFINE, (1, SLANT, -SLANT * base, 0, 1, 0),
                              resample=Image.BILINEAR)
    small = canvas.resize((160, 200), Image.BOX)    # a multicolour pixel: 2 x 1 hires pixels
    px = small.load()
    return {(x, y) for y in range(200) for x in range(160) if px[x, y] >= 128}


def stripes(img, row, rows, colours):
    """rainbow stripes over cell rows: a colour every 4 lines, each other
    line black (2 colours a cell)"""
    for i in range(rows * 8):
        if i % 2:
            continue
        c = colours[(i // 4) % len(colours)]
        for x in range(160):
            img[row * 8 + i][x] = c


def picture():
    img = [[BG] * 160 for _ in range(200)]
    word = logo_mask('SLOPLOAD')
    foot = TOP + H

    # the reflection: the word upside down, half its height, every other
    # line, rippling sideways
    for r in range(0, 30, 2):
        y = foot + 6 + r
        src = foot - 1 - round(r * 2.1)
        shift = round(0.8 * math.sin(r * 0.4))
        col = WATER[(y // 8) - (foot + 6) // 8] if r < 26 else BLUE
        for x in range(160):
            if (x - shift, src) in word:
                img[y][x] = col

    # the letters' depth (solid, down and right), then the letters: a band
    # a cell row, the top edges white, speed lines cut through the lower bands
    for dx, dy in DEPTH:
        for (x, y) in word:
            sx, sy = x + dx, y + dy
            if sx < 160 and (sx, sy) not in word:
                img[sy][sx] = SHADOW
    for (x, y) in word:
        band = (y - TOP) // 8
        line = (y - TOP) % 8
        if band in SPEED and line >= 8 - SPEED[band]:
            img[y][x] = BG
        elif (x, y - 1) not in word:
            img[y][x] = HILITE
        else:
            img[y][x] = RAINBOW[band]

    stripes(img, 1, 2, RAINBOW)
    stripes(img, 22, 2, RAINBOW[::-1])

    # stars, only in cells with nothing else in them
    rnd = random.Random(1982)
    used = {(x // 4, y // 8) for y in range(200) for x in range(160) if img[y][x] != BG}
    for _ in range(70):
        x, y = rnd.randrange(160), rnd.randrange(200)
        if (x // 4, y // 8) not in used:
            img[y][x] = rnd.choice([WHITE, LGREY, LGREY, GREY, DGREY])
    return img


def koala(img):
    """the picture as a Koala file: load address $6000, bitmap, screen,
    colours, background"""
    bitmap, screen, colour = bytearray(8000), bytearray(1000), bytearray(1000)
    for cy in range(25):
        for cx in range(40):
            cells = [img[cy * 8 + y][cx * 4 + x] for y in range(8) for x in range(4)]
            used = sorted({c for c in cells if c != BG}, key=lambda c: (-cells.count(c), c))
            if len(used) > 3:
                sys.exit(f"cell {cx},{cy}: {len(used)} colours besides the background: {used}")
            slots = used + [BLACK] * (3 - len(used))
            slot = {BG: 0, **{c: i + 1 for i, c in enumerate(used)}}
            for y in range(8):
                b = 0
                for x in range(4):
                    b = b << 2 | slot[img[cy * 8 + y][cx * 4 + x]]
                bitmap[(cy * 40 + cx) * 8 + y] = b
            screen[cy * 40 + cx] = slots[0] << 4 | slots[1]
            colour[cy * 40 + cx] = slots[2]
    return bytes([0x00, 0x60]) + bytes(bitmap) + bytes(screen) + bytes(colour) + bytes([BG])


def preview(img, path):
    rgb = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in PAL]
    border = 24
    im = Image.new('RGB', (320 + 2 * border, 200 + 2 * border), rgb[BLACK])
    px = im.load()
    for y in range(200):
        for x in range(160):
            px[border + 2 * x, border + y] = px[border + 2 * x + 1, border + y] = rgb[img[y][x]]
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(path)


if __name__ == '__main__':
    pic = picture()
    data = koala(pic)
    assert len(data) == 10003
    open(OUT, 'wb').write(data)
    print(f"{OUT}: {len(data)} bytes")
    if len(sys.argv) > 1:
        preview(pic, sys.argv[1])
        print(f"{sys.argv[1]}: a picture of it")
