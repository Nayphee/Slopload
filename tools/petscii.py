#!/usr/bin/env python3
"""PETSCII screens as SlopLoad loader modules: a screen drawn in Petmate
or Marq's PETSCII editor shown while the program loads, through the
module (modules/petscii, PETSCII-Load).

    petscii.py SCREEN OUT.lm [-screen N] [-font FONT.64c] [-scroll TEXT]
               [-scrollrow N] [-scrollspeed N] [-scrollcolours HEX]
               [-counter ROW,COL]           the module, for SlopLoad 64
    petscii.py SCREEN -info [-screen N]     what the file holds

-font FONT.64c   the screen in a font of its own: a .64c file (as Petmate
                 imports one: a load address, then up to 2,048 bytes, 8
                 a character; the rest blank). A .petmate screen drawn in
                 an imported font brings it with it; -font replaces it

-scroll TEXT     a message scrolling across a row (smooth, in that row's
                 colours from the screen, or -scrollcolours; {n} is
                 screen code n)
-scrollrow N     its row, 0-24 (default 24): the rows next to it are
                 cleared (spaces) if they aren't empty, as the split may
                 land a few lines late and shake what is on them
-scrollspeed N   pixels a frame, 1-4 (default 2)
-scrollcolours HEX  the message's row's colours instead of the screen's:
                 a colour (0-f, the C64's numbers) for each column from
                 column 1 on, repeated if shorter than 39 (7: all yellow,
                 27: red and yellow by turns). The colours stay put while
                 the message moves through them; column 0 is the
                 background's (the message leaves the row there)
-counter ROW,COL a block counter: three digits there (in the screen's
                 colours) counting the program's blocks down to 000

SCREEN is one of:
  .petmate  Petmate's own file (JSON): its first screen, or -screen N
  .pet      Petmate's export: width, height, border, background, case
            (0 lower, 1 upper), then the screen codes and the colours
  .c        Marq's PETSCII editor: border, background, screen codes,
            colours as numbers, and a "// META: 40 25 ... upper" line
40 x 25 characters, in the C64's own character set (upper case and
graphics, or lower and upper case) or a font of its own (from the
.petmate, or -font).

The PC tool takes the screen file itself: slopload.py prog.prg prog.tap
-module screen.pet. A .lm goes on a disk for SlopLoad 64 (or is given to
the PC tool as -module OUT.lm). On a C64, PETSCII-LM (on SlopLoad 64's
disk) makes the same .lm from a .pet file.

The module (modules/petscii, built by tools/build.py) is the template:
its second part at $BC00 is the screen codes; its main part has, from
byte 32 on (just after the header), the border, the background, the
$D018 value ($F4 upper case, $F6 lower case), the flags (bit 0 the
counter, bit 1 the scroller), the 1,000 colours, then (byte 1036) the
scroller's row and speed, the counter's place (row x 40 + column) and
the message's length (words), the code, and the message at its end.
Then (byte 1042) the space's code (the scroller's row is cleared with
it) and the digit 0's (the counter's digits follow it): $20 and $30 in
the C64's own set. The header's claim (+10) covers the message; the CPU
share (+14) is 35 with a scroller (its split needs the time), 60 without.

A font of its own is a third part, between the main part and the
screen's: only the characters the module shows (the screen's, the
message's, a space with a message, the digits with a counter), in order
and numbered from 0, 8 bytes each. 128 or fewer go at $B800 ($D018
$FE), more at $B000 ($FC), both in VIC bank 2 with the screen at $BC00;
the screen codes, the message, the space's and the digit 0's codes are
renumbered to match. So the font costs the memory of the characters
shown, not 2 KB.
"""
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MODS = os.path.join(ROOT, 'build', 'modules')
ENDINGS = ('.pet', '.petmate', '.c')
W, H = 40, 25
SET_AT = 32                     # the settings: right after the header
COL_AT = 36                     # the colours
EXT_AT = 1036                   # scroller row, speed, counter (word), message length (word),
EXT_LEN = 8                     # ... the space's code, the digit 0's
SHARE = {True: 35, False: 60}   # header +14: with a scroller or not
MSG_MAX = 1000
SCOLS = 39                      # the message's row's colours: columns 1-39
D018 = {True: 0xf4, False: 0xf6}    # upper case at $1000 in the bank, lower case at $1800
FONT_BYTES = 2048               # a font of its own: 256 characters of 8 bytes
FONT_AT = {True: 0xb800, False: 0xb000}     # its part: 128 characters or fewer, more
FONT_D018 = {True: 0xfe, False: 0xfc}       # (the screen at $3C00 in the bank, the font at $3800, $3000)


class Bad(Exception):
    pass


def _screen(name, w, h, border, bg, upper, codes, cols, font=None, fontname=None):
    if (w, h) != (W, H):
        raise Bad(f"{name}: the screen is {w} x {h}; a C64 screen is {W} x {H}")
    if len(codes) != W * H or len(cols) != W * H:
        raise Bad(f"{name}: {len(codes)} characters and {len(cols)} colours, not {W * H} of each")
    if any(not 0 <= c <= 255 for c in codes):
        raise Bad(f"{name}: a screen code outside 0-255")
    return dict(name=name, border=border & 15, bg=bg & 15, upper=upper,
                codes=bytes(codes), colours=bytes(c & 15 for c in cols), font=font, fontname=fontname)


def read_font(path):
    """a font of its own from a .64c file, as Petmate imports one: a load
    address (2 bytes, not used), then up to 2,048 bytes, 8 a character;
    the characters it doesn't have are blank. (font, its name)"""
    name = os.path.basename(path)
    try:
        raw = open(path, 'rb').read()
    except OSError as ex:
        raise Bad(f"{name}: {ex.strerror}")
    if len(raw) < 2 + 8:
        raise Bad(f"{name}: too short for a font (a load address, then 8 bytes a character)")
    return bytes(raw[2:2 + FONT_BYTES]).ljust(FONT_BYTES, b'\0'), name


def with_font(scr, path):
    """the screen in the font of a .64c file (-font)"""
    font, fname = read_font(path)
    return dict(scr, font=font, fontname=fname)


def describe(scr):
    """the screen's character set, said"""
    if scr.get('font') is not None:
        return f"its own font ({scr['fontname']})"
    return 'upper case and graphics' if scr['upper'] else 'lower and upper case'


def read(path, screen=0):
    """the screen in a file: dict(border, bg, upper, codes, colours)"""
    name = os.path.basename(path)
    low = path.lower()
    try:
        raw = open(path, 'rb').read()
    except OSError as ex:
        raise Bad(f"{name}: {ex.strerror}")
    if low.endswith('.pet'):
        if len(raw) < 5:
            raise Bad(f"{name}: too short for a .pet file")
        w, h, border, bg, case = raw[:5]
        n = w * h
        if (w, h) != (W, H):
            raise Bad(f"{name}: not a {W} x {H} .pet file (its first bytes say {w} x {h})")
        if len(raw) != 5 + 2 * n:
            raise Bad(f"{name}: {len(raw)} bytes; a {w} x {h} .pet file has {5 + 2 * n}")
        if case not in (0, 1):
            raise Bad(f"{name}: its character set ({case}) is neither upper nor lower case")
        if screen:
            raise Bad(f"{name}: a .pet file holds one screen (no screen {screen})")
        return _screen(name, w, h, border, bg, case == 1, raw[5:5 + n], raw[5 + n:])
    if low.endswith('.petmate'):
        try:
            ws = json.loads(raw.decode('utf-8'))
            fbs = ws['framebufs']
        except (ValueError, KeyError, TypeError):
            raise Bad(f"{name}: not a Petmate file")
        if not isinstance(fbs, list):
            raise Bad(f"{name}: not a Petmate file")
        if not 0 <= screen < len(fbs):
            raise Bad(f"{name}: no screen {screen} (it has {len(fbs)}: 0-{len(fbs) - 1})")
        try:
            fb = fbs[screen]
            cs = fb.get('charset', 'upper')
            font = fname = None
            if cs not in ('upper', 'lower'):        # a font Petmate imported: in the file, by its id
                cf = (ws.get('customFonts') or {}).get(cs)
                if not isinstance(cf, dict):
                    raise Bad(f"{name}: screen {screen} uses a font ({cs}) the file doesn't have")
                bits = cf['font']['bits']
                if (not isinstance(bits, list) or not 8 <= len(bits) <= FONT_BYTES
                        or any(not isinstance(b, int) or not 0 <= b <= 255 for b in bits)):
                    raise Bad(f"{name}: its font {cf.get('name', cs)!r} isn't a font as Petmate keeps one")
                font = bytes(bits).ljust(FONT_BYTES, b'\0')
                fname = str(cf.get('name') or cs)
            cells = [c for row in fb['framebuf'] for c in row]
            return _screen(name, fb['width'], fb['height'], fb['borderColor'], fb['backgroundColor'],
                           cs != 'lower', [c['code'] for c in cells], [c['color'] for c in cells],
                           font, fname)
        except (KeyError, TypeError, AttributeError):
            raise Bad(f"{name}: screen {screen} isn't a Petmate screen as it should be (a part missing)")
    if low.endswith('.c'):
        frames, cur, w, h, upper = [], [], W, H, True
        for line in raw.decode('latin-1').splitlines():
            t = line.strip()
            if re.match(r'unsigned char\s+\w+\s*\[\]', t):
                continue
            if t.startswith('};'):
                frames.append(cur)
                cur = []
                continue
            m = re.match(r'//\s*META:\s*(\d+)\s+(\d+)\s+.*\b(upper|lower)', t)
            if m:
                w, h, upper = int(m.group(1)), int(m.group(2)), m.group(3) == 'upper'
                break
            t = t.split('//')[0].strip().rstrip(',')
            if t:
                try:
                    cur += [int(x) for x in t.split(',')]
                except ValueError:
                    raise Bad(f"{name}: not a PETSCII editor .c file (\"{t[:30]}\")")
        if not frames:
            raise Bad(f"{name}: no screen in it")
        if not 0 <= screen < len(frames):
            raise Bad(f"{name}: no screen {screen} (it has {len(frames)}: 0-{len(frames) - 1})")
        b = frames[screen]
        n = w * h
        if len(b) != 2 + 2 * n:
            raise Bad(f"{name}: screen {screen} has {len(b)} numbers; {w} x {h} needs {2 + 2 * n}")
        return _screen(name, w, h, b[0], b[1], upper, b[2:2 + n], b[2 + n:])
    raise Bad(f"{name}: a PETSCII screen ends in {', '.join(ENDINGS)}")


def screencodes(text, upper=True):
    """a message in screen codes: letters as the screen's case shows them
    (upper case set: either case as capitals; lower case set: as typed),
    digits and punctuation as they are, {n} for screen code n"""
    out, i = [], 0
    while i < len(text):
        ch = text[i]
        m = re.match(r'\{(\d+)\}', text[i:])
        if m and int(m.group(1)) < 256:
            out.append(int(m.group(1)))
            i += len(m.group(0))
            continue
        o = ord(ch)
        if 'a' <= ch <= 'z':
            out.append(o - 96)
        elif 'A' <= ch <= 'Z':
            out.append(o - 64 if upper else o)
        elif 32 <= o <= 63:
            out.append(o)
        elif ch in '@[£]':
            out.append({'@': 0, '[': 27, '£': 28, ']': 29}[ch])
        else:
            raise Bad(f"the message: no C64 character for {ch!r} (use {{n}} for a screen code)")
        i += 1
    return bytes(out)


def scroll_colours(text):
    """-scrollcolours: hex digits, a colour a column from column 1, the
    digits repeated to fill the 39 (a list of 39 colours)"""
    t = text.strip().lower()
    if not 1 <= len(t) <= SCOLS or any(c not in '0123456789abcdef' for c in t):
        raise Bad(f"-scrollcolours is 1-{SCOLS} colours as hex digits (0-f), one a column from column 1"
                  f" (such as 7, or 2a7), not {text!r}")
    return [int(t[i % len(t)], 16) for i in range(SCOLS)]


def check(scr, msg=b'', row=24, speed=2, counter=None, colours=None):
    """the scroller's and the counter's places on this screen: None, or Bad"""
    if colours is not None:
        if not msg:
            raise Bad("the scrolling message's colours go with a message")
        if len(colours) != SCOLS or any(not 0 <= c <= 15 for c in colours):
            raise Bad(f"the scrolling message's colours: {SCOLS} of them, 0-15")
    if msg:
        if not 0 <= row <= 24:
            raise Bad(f"the scrolling message's row is 0-24, not {row}")
        if not 1 <= speed <= 4:
            raise Bad(f"the scrolling message's speed is 1-4 pixels a frame, not {speed}")
        if len(msg) > MSG_MAX:
            raise Bad(f"the scrolling message is {len(msg)} characters; {MSG_MAX} at most")
    if counter:
        r, c = counter
        if not (0 <= r <= 24 and 0 <= c <= 37):
            raise Bad(f"the counter's place: row 0-24, column 0-37 (its three digits), not {r},{c}")
        if msg and row - 1 <= r <= row + 1:
            raise Bad(f"the counter on row {r} is on the scrolling message's rows ({max(0, row - 1)}"
                      f"-{min(24, row + 1)})")


def load_prg(path):
    d = open(path, 'rb').read()
    return d[0] | d[1] << 8, d[2:]


def template():
    """the PETSCII-Load module as built: (main address, bytes), (low address, bytes)"""
    main, low = os.path.join(MODS, 'petscii.prg'), os.path.join(MODS, 'petscii_low.prg')
    if not (os.path.exists(main) and os.path.exists(low)):
        raise Bad("the PETSCII-Load module isn't built (run tools/build.py)")
    return load_prg(main), load_prg(low)


def empty_rows(scr):
    """each row of the screen: all spaces?"""
    return [all(c == 0x20 for c in scr['codes'][n * 40:n * 40 + 40]) for n in range(25)]


def clear_next(scr, row):
    """The rows next to a scrolling message's, cleared (spaces): it scrolls
    in a split of the screen, and while the loader runs the split can come
    a few lines late, so what is on them would shake. (the screen, the
    rows cleared)"""
    empty = empty_rows(scr)
    gone = [n for n in (row - 1, row + 1) if 0 <= n <= 24 and not empty[n]]
    codes = bytearray(scr['codes'])
    for n in gone:
        codes[n * 40:n * 40 + 40] = b' ' * 40
    return dict(scr, codes=bytes(codes)), gone


def cleared_note(scr, row, gone):
    """what clear_next did, said"""
    empty = empty_rows(scr)
    ok = [r for r in range(25) if (r == 0 or empty[r - 1]) and (r == 24 or empty[r + 1])]
    return (f"{scr['name']}: row{'s' if len(gone) > 1 else ''} {' and '.join(map(str, gone))} cleared"
            f" for the scrolling message on row {row}: what is next to it would shake (its split can"
            " come a few lines late while the loader runs). Rows that need nothing cleared: "
            + (' '.join(map(str, ok)) if ok else 'none'))


def font_part(codes, msg=b'', counter=False, font=b''):
    """A font of its own, cut to the characters the module shows (the
    screen's, the message's, a space with a message, the digits with a
    counter), numbered from 0 in their order: (the part's address, its
    bytes, the new code of each old one, $D018)"""
    used = set(codes) | set(msg) | ({0x20} if msg else set()) | (set(range(0x30, 0x3a)) if counter else set())
    order = sorted(used)
    small = len(order) <= 128
    return (FONT_AT[small], b''.join(font[c * 8:c * 8 + 8] for c in order),
            {c: i for i, c in enumerate(order)}, FONT_D018[small])


def module(scr, msg=b'', row=24, speed=2, counter=None, notes=None, colours=None):
    """the module with this screen in it, and a scrolling message (screen
    codes) and a counter (row, column) if given: [(address, bytes)], the
    main part first, then a font of its own (font_part) if it has one,
    then the screen's codes. colours: the message's row's colours for
    columns 1-39 (39 of them) instead of the screen's. The rows next to
    the message are cleared (clear_next); notes, a list, gets what was
    cleared and the font's characters"""
    check(scr, msg, row, speed, counter, colours)
    if msg:
        was = scr
        scr, gone = clear_next(scr, row)
        if gone and notes is not None:
            notes.append(cleared_note(was, row, gone))
    (ma, md), (la, ld) = template()
    if md[:4] != b'PLG1' or len(ld) != W * H or len(md) < EXT_AT + EXT_LEN:
        raise Bad("the PETSCII-Load module isn't the expected layout (rebuild it)")
    code = len(md) - (md[EXT_AT + 4] | md[EXT_AT + 5] << 8)    # (the template's own message off)
    codes, d018, space, digit0, fpart = scr['codes'], D018[scr['upper']], 0x20, 0x30, []
    if scr.get('font') is not None:
        fa, fd, new, d018 = font_part(codes, msg, bool(counter), scr['font'])
        codes, msg = bytes(new[c] for c in codes), bytes(new[c] for c in msg)
        space, digit0 = new.get(0x20, 0x20) if msg else 0x20, new[0x30] if counter else 0x30
        fpart = [(fa, fd)]
        if notes is not None:
            notes.append(f"{scr['name']}: its own font ({scr['fontname']}), cut to the {len(fd) // 8}"
                         f" characters it shows: ${fa:04X}-${fa + len(fd) - 1:04X}")
    md = bytearray(md[:code]) + bytes(msg)
    flags = (1 if counter else 0) | (2 if msg else 0)
    md[SET_AT:SET_AT + 4] = bytes([scr['border'], scr['bg'], d018, flags])
    md[COL_AT:COL_AT + W * H] = scr['colours']
    if colours is not None:                             # (the row's colour memory: it stays put)
        at = COL_AT + row * W + 1
        md[at:at + SCOLS] = bytes(colours)
    place = counter[0] * 40 + counter[1] if counter else 0
    md[EXT_AT:EXT_AT + EXT_LEN] = struct.pack('<BBHHBB', row if msg else 24, speed if msg else 2, place,
                                              len(msg), space, digit0)
    md[10:12] = struct.pack('<H', ma + len(md))         # the claim: to the message's end
    md[14] = SHARE[bool(msg)]
    if ma + len(md) > 0xfffa:
        raise Bad("the message is too long for the module's memory")
    return [(ma, bytes(md))] + fpart + [(la, bytes(codes))]


def lm_bytes(parts):
    """a .lm file (MODULES.md): each part's address, length and bytes"""
    return b''.join(struct.pack('<HH', a, len(d)) + bytes(d) for a, d in parts)


def read_lm(path):
    """the parts of a .lm file"""
    d = open(path, 'rb').read()
    parts, i = [], 0
    while i < len(d):
        if i + 4 > len(d):
            raise Bad(f"{os.path.basename(path)}: not a module (.lm): it ends inside a part's header")
        a, n = struct.unpack('<HH', d[i:i + 4])
        if i + 4 + n > len(d):
            raise Bad(f"{os.path.basename(path)}: not a module (.lm): a part runs past its end")
        parts.append((a, d[i + 4:i + 4 + n]))
        i += 4 + n
    if not parts or parts[0][1][:4] != b'PLG1':
        raise Bad(f"{os.path.basename(path)}: not a module (.lm): no PLG1 header first")
    for i, (a, d) in enumerate(parts):
        for b, e in parts[i + 1:]:
            if max(a, b) < min(a + len(d), b + len(e)):
                raise Bad(f"{os.path.basename(path)}: its parts at ${a:04X} and ${b:04X} overlap")
    return parts


def options(o, scr):
    """module()'s scroller and counter from options as given (strings)"""
    counter = None
    if o.get('-counter'):
        try:
            r, c = (int(x) for x in o['-counter'].split(','))
        except ValueError:
            raise Bad(f"-counter is ROW,COL (such as 24,25), not {o['-counter']}")
        counter = (r, c)
    msg = screencodes(o['-scroll'], scr['upper']) if o.get('-scroll') else b''
    for k in ('-scrollrow', '-scrollspeed', '-scrollcolours'):
        if o.get(k) is not None and not o.get('-scroll'):
            raise Bad(f"{k} goes with -scroll (the message)")
    colours = scroll_colours(o['-scrollcolours']) if o.get('-scrollcolours') is not None else None

    def num(k, default):
        try:
            return int(o.get(k) or default)
        except ValueError:
            raise Bad(f"{k} needs a number, not {o[k]!r}")
    return dict(msg=msg, row=num('-scrollrow', 24), speed=num('-scrollspeed', 2), counter=counter,
                colours=colours)


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return 1
    opt = {'-screen': '0', '-scroll': None, '-scrollrow': None, '-scrollspeed': None, '-scrollcolours': None,
           '-counter': None, '-font': None}
    rest = []
    i = 0
    while i < len(argv):
        if argv[i] in opt and i + 1 < len(argv):
            opt[argv[i]] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    argv = rest
    try:
        scr = read(argv[0], int(opt['-screen']))
        if opt['-font']:
            scr = with_font(scr, opt['-font'])
        print(f"{scr['name']}: 40 x 25, {describe(scr)}, border {scr['border']}, background {scr['bg']}")
        if len(argv) < 2 or argv[1] == '-info':
            return 0
        notes = []
        parts = module(scr, **options(opt, scr), notes=notes)
    except (Bad, ValueError) as ex:
        print(f"petscii: {ex}", file=sys.stderr)
        return 1
    for n in notes:
        print(n)
    out = argv[1]
    data = lm_bytes(parts)
    open(out, 'wb').write(data)
    print(f"wrote {out}: {len(data)} bytes ({-(-len(data) // 254)} blocks), parts "
          + ', '.join(f"${a:04X}-${a + len(d) - 1:04X}" for a, d in parts))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
