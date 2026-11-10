#!/usr/bin/env python3
"""Pictures as SlopLoad loader modules: a picture (Koala, or hires: Art
Studio, Doodle), with up to two loading sprites and an ending, shown
while the program loads, in a module file (.lm) of its own: the show
module (modules/show) with the picture in it, as slopload.py -module
PICTURE makes too.
PICTURE-LM (on SlopLoad 64's disk) makes the same file on a C64.

    picturelm.py PICTURE OUT.lm [-sprite FILE] [-spritepos X,Y]
                 [-spritecolours C,C,...] [-spritespeed N] [-spritemc A,B]
                 [-spriteexpand] [-wait]

PICTURE takes these C64 formats (FORMATS, below; slopload.py's -module too):
Koala Painter and its kind (Interpaint, Face Painter, Run Paint),
Advanced Art Studio, Blazing Paddles, Artist 64, Image System, Saracen
Paint, Vidcom 64 and Dolphin Ed (both lengths), Drazpaint (unpacked), Micro
Illustrator, CDU-Paint and Paint Magic in multicolour; Art Studio and
its kind (Interpaint hires), Doodle, Image System and Hi-Eddi in hires.
Each is told by its length (and, where two share one, its load
address). Packed files, FLI and the like aren't: unpack or convert them
first. An image from another computer is a converter's job.

The options are slopload.py's (a picture module's): -wait puts PRESS SPACE
OR FIRE across the picture's bottom row once the program is in, and
waits for one; -sprite and its options put one or two sprites over the
picture, flashing through up to 32 colours. Its tune (the tool's -sid,
or SlopLoad 64's music line) fades out at the end, as every module's
does (-fade is kept for old command lines).

Then: slopload.py prog.prg prog.tap -module OUT.lm [-sid TUNE] on a PC,
or OUT.lm as the module (line 3) in SlopLoad 64. After another module
(a PETSCII screen that shows while the picture loads): slopload.py ...
-module screen.pet -then OUT.lm, or -then PICTURE itself.

The file (MODULES.md's .lm): VIC bank 3, two parts.
  $C000-$CFE7  the module (assembled at $C000), its scratch, a Koala
               picture's colours (+76 says where: the module copies them
               into colour RAM as it starts, as a module's parts can't
               load there), then the screen at $CC00
  $E000-$FFBF  the bitmap, then the sprites at $FF40 (64 bytes each)
The header: +12 the jitter (48, and 8 a sprite on a line), +14 the
loader's share (64: room beside the slowest tune a module takes, 3,700
cycles a call), +15 the picture's background (0 for hires), +25 the bank
(bank 3), +28 the ending and hires, +29 to +75 the sprites, +76 the
colours' place (0: none).
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import slopload as S  # noqa: E402

LM_BASE = 0xc000            # the module
LM_SHARE = 64               # the loader's share: beside a 3,700-cycle tune
OPTS = ('sprite', 'spritepos', 'spritecolours', 'spritespeed', 'spritemc', 'spriteexpand', 'wait', 'fade')


class Bad(Exception):
    pass


def module_at(base):
    """the show module assembled at base: (bytes, its labels)"""
    import build as B
    import contextlib
    import io
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        org, data, labs = B.assemble(os.path.join(ROOT, 'modules', 'show', 'show.asm'), 'module_show_lm',
                                     {'showbase': base})
    assert org == base
    return bytes(data), labs


# The C64 picture formats PICTURE-LM and this tool read, by file: (name,
# its lengths (lowest, highest), its load address (None: any), hires,
# then where in the file (from its first byte, the load address's
# included) the bitmap, the screen, the colours (None: hires; a negative
# number -N: one colour, the byte at N, for all of colour RAM) and the
# background (past the file's end: black) are. The offsets are RECOIL's
# (recoil.sourceforge.net) and, where it lists them, ShowVIC's. The
# first that fits a file is it; c64build.py makes PICTURE-LM's table
# from this one.
FORMATS = [
    ('koala',          (10000, 10001), None,   False, 0,     8000,  9000,    10000),
    ('koala',          (10002, 10007), None,   False, 2,     8002,  9002,    10002),   # Interpaint, Face Painter, Run Paint
    ('adv art studio', (10018, 10018), None,   False, 2,     8002,  9018,    9003),
    ('blazing paddles', (10242, 10242), 0xa000, False, 2,     8194,  9218,    8066),
    ('artist 64',      (10242, 10242), 0x4000, False, 2,     8194,  9218,    10241),
    ('image system',   (10218, 10218), None,   False, 1026,  9218,  2,       9217),
    ('saracen paint',  (10219, 10219), None,   False, 1026,  2,     9218,    1010),
    ('vidcom 64',      (10050, 10050), None,   False, 2050,  1026,  2,       2026),    # Dolphin Ed too
    ('dolphin ed',     (10242, 10242), 0x5800, False, 2050,  1026,  2,       2026),
    ('drazpaint',      (10051, 10051), None,   False, 2050,  1026,  2,       10050),
    ('micro illustr.', (10022, 10022), None,   False, 0x7e6, 0x16,  0x3fe,   8),
    ('cdu-paint',      (10277, 10277), None,   False, 0x113, 0x2053, 0x243b, 0x2823),
    ('paint magic',    (9332, 9332),   None,   False, 0x74,  0x2074, -0x1fb7, 0x1fb4),
    ('doodle',         (9026, 9218),   'dd',   True,  1026,  2,     None,    None),
    ('art studio',     (9002, 9011),   'bm',   True,  2,     8002,  None,    None),    # Interpaint hires
    ('image sys hires', (9194, 9194),  None,   True,  2,     8194,  None,    None),
    ('hi-eddi',        (9218, 9218),   0x2000, True,  2,     8194,  None,    None),
]
BM_LOADS = (0x2000, 0x4000, 0x6000, 0xa000, 0xe000)       # 'bm': a bitmap's load addresses
DD_LOADS = (0x1c00, 0x5c00)                               # 'dd': Doodle's (the bitmap $400 on)


def read_picture(path):
    """a picture in one of FORMATS: dict(path, kind, name, bitmap, screen,
    colour (None for hires), bg)"""
    try:
        d = open(path, 'rb').read()
    except OSError as ex:
        raise Bad(f"{path}: {ex}")
    la = d[0] | d[1] << 8 if len(d) >= 2 else -1
    for name, (lo, hi), load, hires, bm, scr, col, bg in FORMATS:
        if not lo <= len(d) <= hi:
            continue
        if load == 'bm' and la not in BM_LOADS or load == 'dd' and la not in DD_LOADS:
            continue
        if isinstance(load, int) and la != load:
            continue
        colour = None
        if col is not None:
            colour = bytes([d[-col]]) * 1000 if col < 0 else d[col:col + 1000]
        return dict(path=path, kind='hires' if hires else 'koala', name=name, bitmap=d[bm:bm + 8000],
                    screen=d[scr:scr + 1000], colour=colour,
                    bg=d[bg] & 15 if bg is not None and bg < len(d) else 0)
    raise Bad(f"{path}: not a picture this knows ({len(d)} bytes): Koala, Advanced Art Studio, Blazing Paddles,"
              " Artist 64, Image System, Saracen Paint, Vidcom, Drazpaint, Micro Illustrator, CDU-Paint, Paint"
              " Magic, Art Studio, Doodle, Hi-Eddi (unpacked, as their tools save them)")


def make(picture, o):
    """the .lm's parts for the picture and the options o (slopload.py's
    names: sprite, spritepos, ..., wait, fade)"""
    pic = read_picture(picture)
    spr = None
    if o.get('sprite'):
        try:
            spr = S.load_sprites(o['sprite'], o)
        except S.Fail as ex:
            raise Bad(str(ex))
    else:
        for k in ('spritepos', 'spritecolours', 'spritespeed', 'spritemc', 'spriteexpand'):
            if o.get(k):
                raise Bad(f"-{k} goes with -sprite FILE")
    data, labs = module_at(LM_BASE)
    d = bytearray(data)
    claim = labs['modend']
    d[12] = 48 + (S.SPRITE_JITTER[spr['across']] if spr else 0)
    d[13] = 0xff                                    # (no song: the tool's -sid)
    d[14] = LM_SHARE
    d[15] = pic['bg']
    d[25] = 0                                       # bank 3 ($dd00's bits)
    d[28] = 1 | (2 if o.get('wait') else 0) | (4 if pic['colour'] is None else 0)   # (the fade: always)
    if spr:
        d[29:76] = spr['header']
    main = bytearray(d) + bytes(claim - LM_BASE - len(d))      # (its scratch: zeros)
    if pic['colour'] is not None:
        at = (claim + 15) // 16 * 16
        main += bytes(at - LM_BASE - len(main)) + bytes(pic['colour'])
        struct.pack_into('<H', main, 76, at)
    if len(main) > 0xcc00 - LM_BASE:
        raise Bad("the module and the colours run into the screen at $CC00")
    main += bytes(0xcc00 - LM_BASE - len(main)) + bytes(pic['screen'])
    second = bytes(pic['bitmap']) + (spr['data'] if spr else b'')
    return [(LM_BASE, bytes(main)), (0xe000, second)]


def lm_bytes(parts):
    """a .lm file (MODULES.md): each part's address, length and bytes"""
    return b''.join(struct.pack('<HH', a, len(d)) + bytes(d) for a, d in parts)


def main(argv):
    o, pos = {}, []
    i = 0
    while i < len(argv):
        a = argv[i]
        k = a.lstrip('-').lower()
        if a.startswith('-') and k in ('wait', 'fade', 'spriteexpand'):
            o[k] = True
        elif a.startswith('-') and k in OPTS:
            if i + 1 >= len(argv):
                print(f"picturelm: {a} needs a value", file=sys.stderr)
                return 2
            o[k] = argv[i + 1]
            i += 1
        elif a in ('-h', '--help'):
            print(__doc__)
            return 0
        elif a.startswith('-'):
            print(f"picturelm: unknown option {a}", file=sys.stderr)
            return 2
        else:
            pos.append(a)
        i += 1
    if len(pos) != 2:
        print(__doc__)
        return 2
    try:
        parts = make(pos[0], o)
    except Bad as ex:
        print(f"picturelm: {ex}", file=sys.stderr)
        return 1
    b = lm_bytes(parts)
    open(pos[1], 'wb').write(b)
    print(f"{pos[1]}: {len(b)} bytes; " + ', '.join(f"${a:04X}-${a + len(dd) - 1:04X}" for a, dd in parts))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
