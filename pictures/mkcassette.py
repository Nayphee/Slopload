#!/usr/bin/env python3
"""SlopLoad's demo loading sprite: a cassette, one hires sprite (24 x 15
pixels of its 24 x 21), written as pictures/cassette.spr: the format
PICTURE-LM and slopload.py's -sprite take, 64 bytes a sprite (3 bytes a
row, 21 rows, then a spare byte; no load address). It goes on SlopLoad
64's disks (tools/c64build.py) beside the demo picture.

    python3 pictures/mkcassette.py [preview.png]

With a file name, also a picture of it (white on blue, 8 times the size).
Its top left is the cassette's top left, for -spritepos and PICTURE-LM's
WHERE. Two of them (-sprite with a 128-byte file) would stand side by
side; this is one.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'cassette.spr')

# '#' a set pixel; 24 wide. The shell, the label's frame with the two
# reels (a hub in each) and the tape window between them, and the bottom
# edge with its two guide holes
CASSETTE = """
.######################.
#......................#
#.####################.#
#.#..................#.#
#.#..###........###..#.#
#.#.#...#.####.#...#.#.#
#.#.#.#.#.#..#.#.#.#.#.#
#.#.#...#.####.#...#.#.#
#.#..###........###..#.#
#.#..................#.#
#.####################.#
#......................#
#....##############....#
#...#.#..........#.#...#
.######################.
""".split()


def sprite():
    """the 64 bytes"""
    assert all(len(r) == 24 for r in CASSETTE) and len(CASSETTE) <= 21
    rows = CASSETTE + ['.' * 24] * (21 - len(CASSETTE))
    out = bytearray()
    for r in rows:
        bits = int(''.join('1' if c == '#' else '0' for c in r), 2)
        out += bits.to_bytes(3, 'big')
    return bytes(out) + b'\x00'


def main(argv):
    d = sprite()
    open(OUT, 'wb').write(d)
    print(f"{OUT}: {len(d)} bytes")
    if argv:
        from PIL import Image
        im = Image.new('RGB', (24 * 8, 21 * 8), (64, 49, 141))
        for y in range(21):
            for x in range(24):
                if d[y * 3 + x // 8] >> (7 - x % 8) & 1:
                    for dy in range(8):
                        for dx in range(8):
                            im.putpixel((x * 8 + dx, y * 8 + dy), (255, 255, 255))
        im.save(argv[0])
        print(f"{argv[0]}: the preview")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
