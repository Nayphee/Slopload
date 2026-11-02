#!/usr/bin/env python3
"""SlopLoad - tape mastering tool: a PRG in, an autobooting .tap out,
with a module to show while the program loads: a game to play, a
loading screen, a picture or music.

Usage:
  slopload.py <in.prg> <out.tap> [options]      master a tape
  slopload.py <in.prg> <out.wav|out.mp3> [opts] the same as sound, for a CD,
                                                an MP3 player or a PC played
                                                through an adapter or lead
  slopload.py -info <file.tap|.wav|.mp3>        decode and list a SlopLoad tape
  slopload.py -version                          which SlopLoad this is
  slopload.py -tapeside <out.tap|.wav|.mp3> [prgs or folders] [-tape C60]
                                                many programs on whole tape
                                                sides (below)

Options (only the ones that differ from the defaults are needed):
  -filename "NAME"   name the KERNAL shows when it finds the file (16 chars;
                     default: the .prg's name); control codes in braces,
                     e.g. "{clr}{white}MY GAME" ({name} or {n}, n a code)
  -module NAME|FILE  what runs while it loads: a module in build/modules
                     (default flappy: flappy, crossy, template, ozgold,
                     petscii), a module's .prg, a .lm, a PETSCII screen
                     (.pet, .petmate or Marq's .c: shown while it loads),
                     or none. A .lm is the module alone: a built-in
                     module's songs come with its name (-module flappy)
  -scroll TEXT       with a PETSCII screen: a message scrolling across a
                     row ({n}: screen code n); -scrollrow N (0-24, default
                     24: the rows next to it must be empty), -scrollspeed
                     N (1-4 pixels a frame, default 2), -scrollcolours
                     HEX (the row's colours instead of the screen's: a
                     hex digit a column from column 1, repeated: 7 all
                     yellow; they stay put as the message moves through);
                     -screen N: a .petmate or .c file's screen N (default 0)
  -counter ROW,COL   with a PETSCII screen: a block counter there, three
                     digits counting down to 000 as it loads
  -font FONT.64c     with a PETSCII screen: drawn in a font of its own (a
                     .64c, as Petmate imports one; a .petmate screen in an
                     imported font brings it with it)
  -speed N           -12 (slowest, the most margin) to 13; 0 the default:
                     the same margin on the tape as slushload's speed N
                     (+-(19 - N) x 4 cycles; below 0, 4 more a step, for
                     a deck speed 0 is too tight for); each speed is at
                     least as fast as the one below it. With a module or
                     a picture showing, 0 has the most margin already:
                     below 0 is the same as 0 there. With
                     a module running its own timing jitter is added on
                     top, and the loader's share of the CPU is held within
                     what the module allows, so it is slower then.
                     Cassette: 0, faster only after -calibrate shows the
                     deck carries it. No tape (VICE, Ultimate, TAPuino,
                     CD, MP3 at 192 kbit/s or more, PC playback): 13.
  -bootspeed N       speed for the screen-off parts (default: as -speed)
  -start ADDR        start with JMP ADDR (default: RUN, for programs at $0801)
  -status VAL        $01 value for -start (default 0x37)
  -music N|NAME|none song for the module (default: its first; none
                     leaves the music off the tape and its memory free)
  -autorun           start the program as soon as it is loaded, cutting
                     the module off (Invade-a-Load style); default is to
                     let a game's player finish and press fire
  -blocksize N       bytes per block (default 4096): after a tape error,
                     rewinding one block's worth is enough to retry
  -leader N          KERNAL leader pulses before the header (default 27136)
  -precomp FILE      write the pulses against what a real deck was measured
                     to do to them (FILE from -analyse ... -out FILE)
  -hires             exact cycle counts in the .tap (finer than 8 cycles)
  -nomotor           for players the C64 can't stop (CD, MP3, a PC): when
                     part of the program loads after the module, the
                     module ends as soon as the rest has loaded (as -autorun),
                     instead of stopping the motor while the player plays on
  -rate N            sample rate of a .wav or .mp3 (default 44100)
  -bitrate N         MP3 bitrate in kbit/s, constant (default 320). 192 or
                     more suits every speed; 128 only up to speed 5. The
                     tool reads the file back and refuses one that moves
                     the edges by half the margin or more
  -invert            the sound's polarity swapped, for a player or lead that
                     inverts it (with the wrong one nothing loads at all)

Tape sides (-tapeside): programs one after another, each its own file on
the tape (its own KERNAL header, loader and blocks), no module, music or
picture: LOAD (or LOAD"NAME") and RUN as with any tape, the next LOAD
going on to the next program. The programs: the .prg files named, or
every .prg in the folders named (alphabetical), or in this folder; each
loads at $0801 and starts with RUN, named on tape after its file.
  -tape CNN          a cassette's length (C60: 30 minutes a side): the
                     programs go on the first side with room for them, in
                     order, and each side is its own file (out-1A.tap,
                     out-1B.tap, out-2A.tap ... for tape 1 side A, ...);
                     without it, everything on one file
  -side MM:SS        the same, a side's length given directly
  -margin S          seconds kept free on each side (default 10: the
                     cassette's clear leader, and the deck's slack)
  -random            the programs shuffled first (the order is printed)
  -speed, -bootspeed, -blocksize, -leader, -precomp, -hires, the sound
  options: as for one program, for every program on the tape

Real decks (wow, flutter, peak shift: VICE has none of these):
  slopload.py -calibrate cal.tap            every speed's test pulses
  slopload.py -analyse dump.tap [-out deck.json] [-jitter N]
                     the read-back dump of cal.tap from your deck: what it
                     does to each speed, and the speeds it can carry
  For sound files: -calibrate cal.wav, put it through the same encoder
  (or the player, recorded back), and -analyse that .wav or .mp3.
"""
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import taplib as T  # noqa: E402
import realtape as R  # noqa: E402

BUILD = os.path.join(ROOT, 'build')
# the release (VERSION, beside tools/): 'dev' in a working copy without one
try:
    VERSION = open(os.path.join(ROOT, 'VERSION')).read().strip()
except OSError:
    VERSION = 'dev'

# quantum h per speed setting; a class-k pulse is (4 + 2k) * h cycles
# Speed N keeps the tape-side margin of slushload's speed N: classes are
# 2h apart, h = (19 - N) * 4 cycles (slushload: pulses (1.5 + k)(19 - N)*8).
# With the game running the game's own timing jitter is added to h (from
# its header), so the tape keeps that margin even at the game's worst
# moment. The screen-off phases never go below H_MIN_BOOT: the core's
# interrupt needs the time.
# Below 0, for a deck that needs more than speed 0's margin (or a slower
# load): each step 4 cycles more, to -12, whose 124 is the most the
# core's pilot window takes (H_MAX). The scale above 0 is slushload's.
# With a game running, speed 0 is at H_MAX already (its jitter added),
# so the speeds below it are speed 0 there.
SPEED_MIN, SPEED_MAX = -12, 13
SPEEDS = range(SPEED_MIN, SPEED_MAX + 1)


def speed_h(n):
    """speed n's quantum: 76 at 0, 24 at 13, 124 at -12"""
    return (19 - n) * 4


DEF_SPEED = 0                  # what a real, slightly misaligned deck loads every time
H_MIN_BOOT = 44
H_MAX = 124                                      # the pilot window (pilot_fits)
# Before a block's pilot is measured the core counts its pulses with the
# quantum T.H_DEF: a pilot pulse (4h) must last 1 to 4 of them. A real NTSC
# machine counts 3.8% more cycles in a pulse than the PAL ones the tape
# is written in (VICE plays a .tap's cycles unscaled), a deck may run off
# speed, and a game delays edges by up to its jitter.
NTSC_STRETCH = 1022730 / 985248
DECK_OFF = 0.03


def pilot_fits(h, jit):
    """True when a pilot of h, with jit cycles of edge jitter, stays inside
    the core's unmeasured window on PAL and NTSC with a deck DECK_OFF off speed"""
    lo = 4 * h * (1 - DECK_OFF) - jit
    hi = 4 * h * NTSC_STRETCH * (1 + DECK_OFF) + jit
    return lo >= T.H_DEF and hi < 5 * T.H_DEF
# shortest data pulse: what a deck carries well (Gyrospeed's and slushload
# speed 5's shortest is about 168 cycles) and longer than the core's
# longest interrupt path plus the game's delays, while the game runs
PMIN_BOOT = 168
MAX_BLOCKS = -(-(0xfffa - 0x0801 + 2) // 254)     # a program from $0801 to $fff9
PMIN_GAME = 208
MEASURE_COST = 48           # tests/jitter.py's timestamp hook (core_measure)
STRIPES_COST = 4            # -stripes STYLE: the colour lookup in the interrupt (core_stripes)
# border stripe styles: colours by the pulse's timer value (each colour two
# values: pulse classes are two apart, so neighbouring ones differ).
# rainbow is the timer value itself, with no lookup (the standard core).
STRIPES = {
    'rainbow': None,
    'mono': [0, 1], 'c64': [6, 14], 'blue': [6, 14, 3], 'red': [2, 10], 'green': [5, 13],
    'fire': [2, 8, 7], 'ice': [6, 14, 3, 1], 'grey': [11, 12, 15], 'sunset': [4, 2, 8, 7],
    'stealth': [0, 11], 'gold': [9, 8, 7], 'candy': [10, 4, 14], 'black': [0],
}
GAME_JITTER_DEFAULT = 48
GAME_JITTER_MAX = 64            # a pilot of h = 124 must still fit the unmeasured window
# The core's interrupt, cycles per pulse of each class (0-3), and what
# completing a byte adds: the worst over the decoder's states, from
# tests/irqcycles.py (which checks these against the core). With the
# game running, the loader's share of the CPU is these over the pulses'
# lengths; a game says in its header how much it can give up.
IRQ_COST = {'dibit': ((85, 85, 85, 85), 44), 'prefix': ((88, 99, 108, 105), 50)}
# The share is checked over every stretch of tape a frame long (a PAL
# frame), since a game misses its frame wherever the loader takes too
# much, not on average. The default share for a game that doesn't say.
SHARE_WINDOW = 19656
GAME_SHARE_DEFAULT = 35


def ceil4(x):
    return (x + 3) // 4 * 4

# memory the loader itself needs while loading (main program can't go here)
LOADER_RANGES = [(0x0000, 0x0800, 'zero page, stack, KERNAL work areas, stage 1 and core'),
                 (0xfffa, 0x10000, 'the interrupt vectors')]

PILOT_CORE = 1.0        # seconds: motor restarting after the KERNAL's load
PILOT_FIRST = 0.25      # first block after the core (core start-up)
PILOT_BLOCK = 0.08      # between blocks
PILOT_RESUME = 2.0      # after the motor was stopped for the end of the game
TRAILER_PULSES = 200    # after the last block: its last pulse ends at the first of these.
                        # Only at a tape's end: a LOAD started in them (shorter than the
                        # KERNAL's own pulses) can crash the KERNAL's tape interrupt, so
                        # where another file follows, its leader ends the pulse instead


class Fail(Exception):
    pass


def load_prg(path):
    d = open(path, 'rb').read()
    if len(d) < 3:
        raise Fail(f"{path}: too short for a .prg")
    return d[0] | d[1] << 8, d[2:]


def sym(name):
    return json.load(open(os.path.join(BUILD, name + '.sym.json')))


# control codes a tape's name may hold (what LOAD's FOUND prints: a {clr}
# and a colour before the name, say), by name in braces; {n} is code n
PETSCII_CODES = {'clr': 147, 'clear': 147, 'home': 19, 'black': 144, 'blk': 144, 'white': 5, 'wht': 5,
                 'red': 28, 'cyan': 159, 'purple': 156, 'pur': 156, 'green': 30, 'grn': 30, 'blue': 31,
                 'blu': 31, 'yellow': 158, 'yel': 158, 'orange': 129, 'brown': 149, 'lred': 150,
                 'pink': 150, 'grey1': 151, 'dgrey': 151, 'grey2': 152, 'grey': 152, 'lgreen': 153,
                 'lblue': 154, 'grey3': 155, 'lgrey': 155, 'rvs': 18, 'rvson': 18, 'rvsoff': 146,
                 'down': 17, 'up': 145, 'right': 29, 'left': 157}


def petscii_codes(s):
    """text as PETSCII: letters as typed on the C64 (unshifted), other
    printable characters as they are, {name} or {n} a control code"""
    out, i = [], 0
    s = s.upper()                       # ('ß' is then 'SS'; a code's name is read in lower case)
    while i < len(s):
        if s[i] == '{' and '}' in s[i:]:
            j = s.index('}', i)
            k = s[i + 1:j].strip().lower()
            if k.isdigit() and int(k) < 256:
                out.append(int(k))
            elif k in PETSCII_CODES:
                out.append(PETSCII_CODES[k])
            else:
                raise Fail(f"-filename: no control code {{{k}}} (known: {', '.join(sorted(PETSCII_CODES))})")
            i = j + 1
            continue
        o = ord(s[i])
        out.append(o if 0x20 <= o <= 0x5f else 0x20)
        i += 1
    return bytes(out)


def petscii_name(s):
    """a tape's name: 16 codes (spaces after it), control codes in braces"""
    b = petscii_codes(s)[:16]
    return b + bytes([0x20]) * (16 - len(b))


def name_shown(s):
    """the tape's name as the report shows it: its 16 codes, a control
    code by its name in braces"""
    names = {}
    for k, c in PETSCII_CODES.items():
        names.setdefault(c, k)
    return ''.join(chr(c) if 0x20 <= c <= 0x5f else '{' + names.get(c, str(c)) + '}'
                   for c in petscii_codes(s)[:16]).rstrip()


def overlap(a, b):
    return max(a[0], b[0]) < min(a[1], b[1])


def subtract(rng, cut):
    """Parts of rng outside cut, and the part inside."""
    lo, hi = rng
    out = []
    if lo < cut[0]:
        out.append((lo, min(hi, cut[0])))
    if hi > cut[1]:
        out.append((max(lo, cut[1]), hi))
    inside = (max(lo, cut[0]), min(hi, cut[1]))
    return out, (inside if inside[0] < inside[1] else None)


def pilot_len(seconds, h):
    return max(300, int(seconds * T.PAL_HZ / (4 * h)))


ALIASES = {'mixtape': 'tapeside', 'analyze': 'analyse', 'measure': 'core'}
# what each kind of run uses: an option typed that the run doesn't use is
# refused, not ignored
SOUND_OPTS = {'rate', 'bitrate', 'invert'}
TAPE_OPTS = {'speed', 'bootspeed', 'blocksize', 'leader', 'precomp', 'hires', 'core', 'stripes'}
SIDE_ONLY = {'tape', 'side', 'margin', 'random'}
MODE_OPTS = {
    'master': TAPE_OPTS | SOUND_OPTS | {'filename', 'module', 'start', 'status', 'autorun', 'nomotor',
                                        'music', 'sid', 'song', 'show', 'picture', 'scroll', 'scrollrow',
                                        'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font'},
    'tapeside': TAPE_OPTS | SOUND_OPTS | SIDE_ONLY | {'tapeside'},
    'calibrate': SOUND_OPTS | {'calibrate', 'jitter'},
    'analyse': {'analyse', 'jitter', 'out'},
    'info': {'info'},
    'version': {'version'},
}


def check_given(o, mode, out=None):
    """refuse an option typed that this kind of run (MODE_OPTS) would
    ignore; out: the file written, for the sound options"""
    given = o.get('given') or set()
    for k in sorted(given - MODE_OPTS[mode]):
        if k in SIDE_ONLY:
            raise Fail(f"-{k} goes with -tapeside (many programs on tape sides)")
        if k == 'out':
            raise Fail("-out goes with -analyse (the deck file it writes)")
        if k == 'jitter':
            raise Fail("-jitter goes with -analyse or -calibrate")
        if mode == 'tapeside':
            raise Fail(f"-tapeside: -{k} doesn't go on a tape side (each program is named after"
                       " its file, starts with RUN, and loads with no module, music or picture)")
        raise Fail(f"-{k} doesn't go with -{mode}" if mode != 'master' else f"-{k} isn't used here")
    ext = os.path.splitext(out or '')[1].lower()
    if out is not None and ext not in ('.wav', '.mp3'):
        for k in ('rate', 'bitrate', 'invert'):
            if k in given:
                raise Fail(f"-{k} goes with a .wav or .mp3 (the tape written as sound)")
    if out is not None and ext == '.wav' and 'bitrate' in given:
        raise Fail("-bitrate goes with an .mp3 (a .wav's sound isn't compressed: -rate sets its sample rate)")


def parse_args(argv):
    opts = dict(filename=None, module='flappy', speed=DEF_SPEED, bootspeed=None,
                start=None, status=0x37, autorun=False, blocksize=4096, leader=0x6A00)
    given = opts['given'] = set()       # the options typed (check_given)
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith('-') and len(a) > 1:
            k = a.lstrip('-').lower()
            if k == 'autorun':
                opts['autorun'] = True
            elif k in ('nomotor', 'invert', 'random'):
                opts[k] = True
            elif k in ('tapeside', 'mixtape'):
                opts['tapeside'] = True
            elif k == 'info':
                opts['info'] = True
            elif k == 'version':
                opts['version'] = True
            elif k == 'measure':          # test builds: timestamp every edge
                opts['core'] = 'core_measure'
            elif k in ('calibrate', 'analyse', 'analyze'):
                opts['mode'] = 'analyse' if k.startswith('analy') else k
            elif k == 'hires':
                opts['hires'] = True
            elif k in ('filename', 'module', 'speed', 'bootspeed', 'start', 'status',
                       'blocksize', 'leader', 'precomp', 'out', 'jitter', 'core', 'music',
                       'rate', 'bitrate', 'show', 'picture', 'sid', 'song', 'stripes',
                       'tape', 'side', 'margin', 'scroll', 'scrollrow', 'scrollspeed', 'scrollcolours',
                       'counter', 'screen', 'font'):
                if i + 1 >= len(argv):
                    raise Fail(f"{a} needs a value")
                v = argv[i + 1]
                i += 1
                if k in ('speed', 'bootspeed', 'start', 'status', 'blocksize', 'leader', 'jitter',
                         'rate', 'bitrate', 'song'):
                    v = number(a, v)
                opts[k] = v
            elif k in ('h', 'help'):
                print(__doc__)
                sys.exit(0)
            else:
                raise Fail(f"unknown option {a}")
            given.add(ALIASES.get(k, k))
        else:
            pos.append(a)
        i += 1
    return opts, pos


def find_game(spec, o=None):
    """the module: a name (build/modules/NAME.prg), a module's .prg (its
    parts file beside it), a .lm (all its parts in one file), or a PETSCII
    screen (.pet, .petmate, .c: PETSCII-Load with that screen, and the
    options' scroller and counter)"""
    if spec.lower() == 'none':
        return None
    import petscii as P
    pj = None
    if spec.lower().endswith('.lg'):
        raise Fail(f"{spec}: modules are .lm files now (the same inside): rename it to end in .lm")
    if spec.lower().endswith(P.ENDINGS + ('.lm',)) and not os.path.exists(spec):
        raise Fail(f"no file {spec}")
    o = o or {}
    pet = ('scroll', 'scrollrow', 'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font')
    if any(o.get(k) is not None for k in pet) and not spec.lower().endswith(P.ENDINGS):
        raise Fail(f"-{next(k for k in pet if o.get(k) is not None)} goes with a PETSCII screen as -module"
                   " (a .pet, .petmate or .c file)")
    if spec.lower().endswith(P.ENDINGS):
        if not str(o.get('screen') or 0).isdigit():
            raise Fail(f"-screen needs a screen's number (0 the first), not {o['screen']!r}")
        try:
            scr = P.read(spec, int(o.get('screen') or 0))
            if o.get('font'):
                scr = P.with_font(scr, o['font'])
            notes = []
            parts = P.module(scr, **P.options({'-' + k: o.get(k) for k in pet}, scr), notes=notes)
        except (P.Bad, ValueError) as ex:
            raise Fail(str(ex))
        for n in notes:
            print(f"  {n}")
        path = spec
        (addr, data), extra = parts[0], parts[1:]
        pj = os.path.join(BUILD, 'modules', 'petscii.parts.json')    # (its music)
    elif spec.lower().endswith('.lm'):
        try:
            parts = P.read_lm(spec)
        except (P.Bad, OSError) as ex:
            raise Fail(str(getattr(ex, 'strerror', None) or ex))
        path = spec
        (addr, data), extra = parts[0], parts[1:]
    else:
        path = spec if os.path.exists(spec) else os.path.join(BUILD, 'modules', spec + '.prg')
        if not os.path.exists(path):
            raise Fail(f"no module '{spec}' (looked for {path}; run tools/build.py)")
        addr, data = load_prg(path)
        extra = None
        pj = os.path.splitext(path)[0] + '.parts.json'
    if data[:4] != b'PLG1':
        raise Fail(f"{path}: not a SlopLoad module (no 'PLG1' at its start)")
    if len(data) < 32:
        raise Fail(f"{path}: not a SlopLoad module (its header is 32 bytes; this part is {len(data)})")
    w = lambda o: data[o] | data[o + 1] << 8
    # +10: end of the memory the game claims (its run-time buffers too)
    claim = max(addr + len(data), w(10) or 0x10000 if len(data) > 11 else 0)
    # +12: the game's worst edge-timing jitter in cycles (tests/jitter.py)
    jit = data[12] if len(data) > 12 and data[12] else GAME_JITTER_DEFAULT
    if jit > GAME_JITTER_MAX:
        raise Fail(f"{path}: jitter {jit} in the header; the loader allows {GAME_JITTER_MAX} at most")
    # +14: the most of the CPU (percent) the loader may take while it runs
    share = data[14] if len(data) > 14 and data[14] else GAME_SHARE_DEFAULT
    g = dict(path=path, addr=addr, data=data, end=addr + len(data), claim=claim,
             init=w(4), frame=w(6), stop=w(8), jitter=jit, share=share, music=None, extra=[])
    if pj and os.path.exists(pj):
        spec = json.load(open(pj))
        for v in spec.values():         # a part: beside the parts file, else in SlopLoad's folder
            if isinstance(v, dict) and 'prg' in v and not os.path.isabs(v['prg']):
                near = os.path.join(os.path.dirname(os.path.abspath(pj)), v['prg'])
                v['prg'] = near if os.path.exists(near) else os.path.join(ROOT, v['prg'])
        m = spec.get('music')
        if m and os.path.exists(m['prg']):
            maddr, mdata = load_prg(m['prg'])
            g['music'] = dict(path=m['prg'], addr=maddr, data=mdata,
                              claim=maddr + len(mdata) + m.get('workspace', 0),
                              songs=m.get('songs', []))
        for k, v in spec.items():       # parts always loaded with it (more of its code)
            if isinstance(v, dict) and v.get('always') and extra is None:
                if not os.path.exists(v['prg']):
                    raise Fail(f"{path}: its part '{k}' is missing: {v['prg']}")
                g['extra'].append(load_prg(v['prg']))
    if extra:                           # (a .lm's or a screen's other parts)
        g['extra'] = [(a, bytes(d)) for a, d in extra]
    if pj and pj.endswith('petscii.parts.json') and path.lower().endswith(P.ENDINGS):
        g['label'] = f"PETSCII-Load with {os.path.basename(path)}"
    g['claims'] = [(addr, claim)] + [(a, a + len(d)) for a, d in g['extra']]
    for clo, chi in g['claims']:
        for lo, hi, what in LOADER_RANGES:
            if overlap((clo, chi), (lo, hi)):
                raise Fail(f"module ${clo:04X}-${chi - 1:04X} overlaps {what} (${lo:04X}-${hi - 1:04X})")
    return g


def number(opt, v):
    """an option's whole number: decimal, or hex as $c000 or 0xc000"""
    t = v.strip().lower()
    neg = t.startswith('-')
    t = t[1:] if neg else t
    try:
        n = int(t[1:], 16) if t.startswith('$') else int(t, 16) if t.startswith('0x') else int(t, 10)
    except ValueError:
        raise Fail(f"{opt} needs a whole number (or $hex), not {v!r}")
    return -n if neg else n


def master(prg, tap, o, quiet=False):
    """one program's tape: written to tap (.tap, .wav or .mp3) and
    reported; with tap None, only built and checked (a tape side's part).
    Returns the pulses; quiet: a dict of the pulses, the blocks' spans
    (for the sound check), the name, the program's range and its seconds,
    with no report"""
    if tap is not None and os.path.splitext(tap)[1].lower() not in ('.tap', '.wav', '.mp3'):
        raise Fail(f"{tap}: the tape is written as a .tap, a .wav or an .mp3 (by its ending)")
    if o['bootspeed'] is None:
        o['bootspeed'] = o['speed']
    for k in ('speed', 'bootspeed'):
        if o[k] not in SPEEDS:
            raise Fail(f"-{k} must be {SPEED_MIN} to {SPEED_MAX}")
    if not 256 <= o['blocksize'] <= 0xffff:
        raise Fail("-blocksize must be 256 to 65535")
    if o['start'] is not None and not 0 <= o['start'] <= 0xffff:
        raise Fail("-start must be an address, $0000 to $FFFF")
    if not 0 <= o['status'] <= 0xff:
        raise Fail("-status must be a byte, $00 to $FF")
    if o['leader'] < 256:
        raise Fail("-leader must be 256 pulses or more (the KERNAL finds the header by it)")
    # ---- what shows while the program loads (SHOWS)
    show = str(o.get('show') or 'module').lower()
    if show not in SHOWS:
        raise Fail(f"-show must be one of {', '.join(SHOWS)}")
    if show == 'module' and str(o['module']).lower() == 'none':
        show = 'none'
    given = o.get('given') or set()
    what = {'none': 'nothing (the screen off)', 'picture': 'a picture', 'picmusic': 'a picture and music',
            'music': 'music'}
    if 'module' in given and show != 'module' and str(o['module']).lower() != 'none':
        raise Fail(f"-module goes with -show module (the default): -show {show} shows {what[show]}")
    pet = [k for k in ('scroll', 'scrollrow', 'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font')
           if o.get(k) is not None]
    if pet and show != 'module':
        raise Fail(f"-{pet[0]} goes with a PETSCII screen as -module (-show module): -show {show}"
                   f" shows {what[show]}")
    if o.get('picture') and show not in ('picture', 'picmusic'):
        raise Fail("-picture goes with -show picture or -show picmusic")
    pic = None
    if show == 'none':
        game = None
    elif show == 'module':
        game = find_game(o['module'], o)
    else:
        game = find_game('show')
        if show in ('picture', 'picmusic'):
            if not o.get('picture'):
                raise Fail(f"-show {show} needs -picture FILE.koa")
            pic = load_koala(o['picture'])
        if show == 'picture' and o.get('music') not in (None, 'none'):
            raise Fail("-show picture has no music: -show picmusic has")
        if show in ('picmusic', 'music') and str(o.get('music', '')).lower() == 'none':
            raise Fail(f"-show {show} needs a song")
    # the screen is on (bad lines) while a game or a picture shows; music
    # alone keeps it off, and loads at screen-off speeds
    screen_on = game is not None and show != 'music'
    jit = game['jitter'] if screen_on else 0
    # the measuring core's timestamp hook lengthens every interrupt
    pmin_boot = PMIN_BOOT + (MEASURE_COST if o.get('core') == 'core_measure' else 0)
    pmin_game = PMIN_GAME + (MEASURE_COST if o.get('core') == 'core_measure' else 0)
    smode, scol = stripe_mode(o.get('stripes'))
    stripes = stripe_table(o.get('stripes')) if smode == 'table' else None
    if smode in ('flat', 'block'):
        if o.get('core', 'core') != 'core':
            raise Fail(f"-stripes {o['stripes']} and -core {o['core']}: one or the other")
        o['core'] = 'core_flat'
    if stripes:
        if o.get('core', 'core') != 'core':
            raise Fail("-stripes and -core: one or the other")
        o['core'] = 'core_stripes'
        pmin_boot += STRIPES_COST
        pmin_game += STRIPES_COST
    h_game = min(H_MAX, ceil4(speed_h(o['speed']) + jit))
    h_boot = max(H_MIN_BOOT, speed_h(o['bootspeed']))
    if screen_on:
        h_live, pmin_live = h_game, pmin_game
    else:
        h_live, pmin_live = max(H_MIN_BOOT, speed_h(o['speed'])), pmin_boot
    live_phase = {'none': 'program', 'module': 'program, module running',
                  'picture': 'program, picture showing', 'picmusic': 'program, picture and music',
                  'music': 'program, music playing'}[show]

    maddr, mdata = load_prg(prg)
    mend = maddr + len(mdata)
    if mend > 0x10000:
        raise Fail("program runs past $ffff")
    for lo, hi, what in LOADER_RANGES:
        if overlap((maddr, mend), (lo, hi)):
            raise Fail(f"program ${maddr:04X}-${mend - 1:04X} overlaps {what} (${lo:04X}-${hi - 1:04X})")
    run = o['start'] is None
    if run and maddr != 0x0801:
        raise Fail(f"program loads at ${maddr:04X}, not $0801: give -start ADDR")

    # the name: -filename's (control codes in braces), else the file's
    # (its braces only characters)
    name = o['filename'] or os.path.splitext(os.path.basename(prg))[0].replace('{', '(').replace('}', ')')

    # ---- the music: the built-in songs (-music) or a SID tune (-sid);
    # a part of the game, loaded with it
    mus = None
    if o.get('sid'):
        if o.get('music') not in (None, 'none'):
            raise Fail("-sid and -music: one or the other")
        if show in ('none', 'picture'):
            raise Fail(f"-sid plays with -show music, picmusic or module, not -show {show}")
        import sidstrip as SS
        import sidfile as SF
        if o['sid'].lower().endswith('.slm') and o.get('song') is not None:
            raise Fail("-song picks a .sid's song; a .slm's was chosen when it was made")
        try:
            m = SS.load_music(o['sid'], o.get('song'))
        except (SS.Refused, SF.Bad) as ex:
            raise Fail(str(ex))
        except OSError as ex:
            raise Fail(f"{o['sid']}: {ex}")
        if show == 'module':
            why = SS.game_ok(m, [(a, c) for a, c in game['claims']], os.path.basename(game['path']))
            if why:
                raise Fail(f"{os.path.basename(o['sid'])} can't play beside {os.path.basename(game['path'])}:"
                           f" {why}. -show music or picmusic can play it")
        end_ = m['load'] + len(m['data'])
        mus = dict(addr=m['load'], data=m['data'], claims=[(m['load'], end_)] + list(m['workspace']),
                   relocs=m.get('relocs'), workspace=list(m['workspace']), songs=m.get('songs', 1),
                   init=m['init'], play=m['play'], per_pal=m['per_pal'], per_ntsc=m['per_ntsc'],
                   flags=2, song_a=m['song'] - 1, play_cycles=m['play_clk'], sid=m,
                   label=f"{m['name']} / {m['author']}" + (f", song {m['song']}" if m.get('songs', 1) > 1 else ""))
    elif o.get('song') is not None:
        raise Fail("-song picks a song of a -sid tune; the built-in ones are -music N")
    elif game and game['music'] and show != 'picture':
        mo = o.get('music')
        song = None
        if mo is None:
            song = 0
        elif str(mo).lower() != 'none':
            try:
                song = int(mo)
            except ValueError:
                names = [n.lower() for n in game['music']['songs']]
                if str(mo).lower() not in names:
                    raise Fail(f"no song '{mo}': {', '.join(game['music']['songs'])}")
                song = names.index(str(mo).lower())
            if not 0 <= song < max(1, len(game['music']['songs'])):
                raise Fail(f"-music must be 0-{len(game['music']['songs']) - 1} or none")
        if song is not None:
            gm = game['music']
            nm = gm['songs'][song] if song < len(gm['songs']) else f'song {song}'
            mus = dict(addr=gm['addr'], data=gm['data'], claims=[(gm['addr'], gm['claim'])],
                       init=0xc000, play=0xc003, per_pal=312 * 64, per_ntsc=263 * 64 * 6 // 5,
                       flags=1, song_a=song, play_cycles=BUILTIN_PLAY_CYCLES, sid=None, label=nm)
            if show == 'module':        # (a module's own music: it must keep out of the module)
                for clo, chi in game['claims']:
                    if overlap((gm['addr'], gm['claim']), (clo, chi)):
                        raise Fail(f"{os.path.basename(game['path'])}: its music (${gm['addr']:04X}-"
                                   f"${gm['claim'] - 1:04X}) overlaps it (${clo:04X}-${chi - 1:04X})")
    elif o.get('music') not in (None, 'none') and show != 'picture':
        lm = game and game['path'].lower().endswith('.lm')
        raise Fail(f"{os.path.basename(game['path'])} brings no songs: a .lm is the module alone"
                   " (-module NAME brings a built-in module's songs; -sid FILE plays a tune beside it)"
                   if lm else "this module has no music" if game else
                   "-music goes with a module that has music, or -show picmusic or music")
    if show in ('picmusic', 'music') and mus is None:
        raise Fail(f"-show {show} needs a song (-music N, or -sid FILE)")
    if mus:
        # the tune's own bytes load: they keep out of the loader's memory;
        # its workspace is only written as it plays, once stage 1 is done
        # with $0200-$03ff (the exit code goes there after the music stops)
        busy = [(lo, hi, what) for lo, hi, what in LOADER_RANGES]
        busy_ws = [(0, 0x200, 'zero page and the stack'), (0x400, 0x800, 'the core'),
                   (0xfffa, 0x10000, "the CPU's vectors")]
        for i, (lo, hi) in enumerate(mus['claims']):
            for llo, lhi, what in (busy if i == 0 else busy_ws):
                if overlap((lo, hi), (llo, lhi)):
                    raise Fail(f"the music's ${lo:04X}-${hi - 1:04X} overlaps {what}")
    song = mus['song_a'] if mus else None

    # ---- where things go: a SID tune that can move goes where it costs
    # least (the least of the program under it and the show), then the
    # show module and the picture, clear of it and of each other
    bank, base = 3, None
    showing = show in ('picture', 'picmusic', 'music')
    if mus and mus.get('relocs') is not None or showing:
        cands = [mus['addr']] if mus else [None]
        if mus and mus.get('relocs') is not None:
            low = mus['addr'] & 0xff
            cands += [p * 256 + low for p in range(0xff, 0x07, -1) if p * 256 + low != mus['addr']]
        prog = (maddr, mend)
        under = lambda rs: sum(max(0, min(hi, prog[1]) - max(lo, prog[0])) for lo, hi in rs)
        best = None
        for to in cands:
            mc = []
            if mus:
                mc = [(to, to + len(mus['data']))] + mus['claims'][1:]
                if mc[0][1] > 0xfffa or any(overlap(mc[0], r) for r in
                                            [(0, 0x800), (0xd000, 0xe000), (0xfffa, 0x10000)]):
                    continue
                if to != mus['addr'] and any(overlap(mc[0], w) for w in mus['claims'][1:]):
                    continue
            if show == 'module':
                if any(overlap(r, c) for r in mc for c in game['claims']):
                    continue
                key = (under(mc), to != mus['addr'])
                plan = (key, to, None, None)
            else:
                try:
                    b_, base_, sc = place_show(len(game['data']), mc, pic, prog)
                except Fail:
                    continue
                key = (under(mc) + sc, mus is not None and to != mus['addr'])
                plan = (key, to, b_, base_)
            if best is None or key < best[0]:
                best = plan
            if key == (0, False):
                break
        if best is None:
            raise Fail("no room for the music, the picture and the show module together")
        _, to, b_, base_ = best
        if b_ is not None:
            bank, base = b_, base_
        if mus and to != mus['addr']:
            import sidreloc as SR
            tl = dict(path=o['sid'], load=mus['addr'], end=mus['addr'] + len(mus['data']), data=mus['data'],
                      init=mus['init'], play=mus['play'], songs=mus['songs'], rsid=False)
            try:
                n = SR.move_checked(tl, mus['relocs'], to, mus['song_a'] + 1, 1500, mus['claims'][1:])
            except SR.Unmovable as ex:
                raise Fail(f"{os.path.basename(o['sid'])}: {ex}")
            mus.update(moved_from=mus['addr'], addr=to, data=n['data'], init=n['init'], play=n['play'],
                       claims=[(to, to + len(n['data']))] + mus['claims'][1:])
    if showing:
        import build as B
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            org, gdata, labs = B.assemble(os.path.join(ROOT, 'modules', 'show', 'show.asm'),
                                          'module_show_placed', {'showbase': base})
        game.update(addr=org, data=gdata, end=org + len(gdata), claim=labs['modend'],
                    init=labs['init'], frame=labs['frame'], stop=labs['stop'],
                    claims=[(org, labs['modend'])])
        if pic:
            pb = bank * 0x4000
            pic['parts'] = [(pb + 0x0c00, pic['screen'], False), (0xd800, pic['colour'], True),
                            (pb + 0x2000, pic['bitmap'], False)]
            pic['bank'] = bank
        # what the loader may take of the cpu: what the music leaves
        if mus:
            # in integers, as SlopLoad 64 works it out (c64model.show_share):
            # play calls a frame (x 256, the most of PAL's and NTSC's) x the
            # longest call x 1.3, plus 900, out of an NTSC frame (less a
            # picture's bad lines)
            calls256 = max(312 * 64 * 256 // mus['per_pal'], 263 * 64 * 256 // mus['per_ntsc'])
            avail = 263 * 65 - (1000 if pic else 0)
            need = mus['play_cycles'] * calls256 * 13 // 2560 + 900
            game['share'] = min(85, 100 * (avail - need) // avail if need < avail else 0)
            if game['share'] < 25:
                raise Fail(f"the tune needs {mus['play_cycles']} cycles {calls256 / 256:.1f} times a frame:"
                           " too much to load beside it")
    if game:
        game['data'] = bytearray(game['data'])
        game['data'][13] = 0xff if song is None else song      # header: the song
        game['data'][14] = game['share']
        if mus:
            game['data'][16:25] = struct.pack('<HHHHB', mus['init'], mus['play'], mus['per_pal'],
                                              mus['per_ntsc'], mus['flags'])
        if show in ('picture', 'picmusic', 'music'):
            game['data'][15] = 0xff if pic is None else pic['bg']   # header: the picture
            game['data'][25] = 3 - (pic['bank'] if pic else 3)     # $dd00's bits

    # ---- the main program: loaded while the game runs, except what
    # falls inside the game's memory (and the music's), loaded after it stops
    claims = []
    if game:
        claims += game.get('claims', [(game['addr'], game['claim'])])
        if mus:
            claims += mus['claims']
        if pic:
            claims += [(a, a + len(d)) for a, d, io in pic['parts'] if not io]
    live, later = [(maddr, mend)], []
    for c in claims:
        nl = []
        for rng in live:
            out, inside = subtract(rng, c)
            nl += out
            if inside:
                later.append(inside)
        live = nl
    live.sort()
    later.sort()

    def chunks(parts):
        out = []
        for lo, hi in parts:
            a = lo
            while a < hi:
                b = min(hi, a + o['blocksize'])
                out.append((a, mdata[a - maddr:b - maddr]))
                a = b
        return out

    live_blocks, later_blocks = chunks(live), chunks(later)
    total_live = sum(len(d) for _, d in live_blocks)
    if show == 'module' and len(game['data']) > 26:
        # header +26: the disk blocks its counter counts down, those that
        # load while it runs (all the program's, unless some of it loads
        # into the module's memory after it)
        game['data'][26] = min(255, -(-(total_live + 2) // 254))

    # ---- the core, patched
    cname = o.get('core', 'core')               # test variants: see tools/build.py
    cs = sym(cname)
    core = bytearray(open(os.path.join(BUILD, cname + '.bin'), 'rb').read())
    pages = (len(core) + 255) // 256
    core += bytes(pages * 256 - len(core))

    def put(label, val, size=1, at=0):
        a = cs[label] - 0x0400 + at
        for i in range(size):
            core[a + i] = (val >> (8 * i)) & 255

    put('pt_game', 1 if game else 0)
    if stripes:
        for i, c in enumerate(stripes):
            put('stab', c, at=i)
    if smode == 'flat':                           # (core_flat: no stripes; the border
        put('bflat', 0xa2)                        # the block's colour, ldx ld_seq, or
        put('bflat', scol, at=1)                  # one: ldx #colour)
    nomotor_auto = bool(o.get('nomotor') and later_blocks and not o['autorun'])
    if nomotor_auto:
        o['autorun'] = True                       # nothing can stop the player
    put('pt_auto', 1 if o['autorun'] else 0)
    if game:
        put('pt_init', game['init'], 2)
        put('pt_frame', game['frame'], 2)
        put('pt_stop', game['stop'], 2)
    put('x_run', 1 if run else 0, at=1)           # the exit code's operands
    put('x_jmp', o['start'] or 0, 2, at=1)
    put('x_port', o['status'], at=1)
    put('x_irq', 0x58 if (o['status'] & 2) else 0x78)   # cli, or sei: KERNAL out
    put('x_vt1', mend & 255, at=1)
    put('x_vt2', mend >> 8, at=1)
    step = min(65535, round(16777216 / max(1, total_live)))
    put('pt_step', step, 2)

    # ---- stage 1, in the KERNAL file
    ss = sym('stage1')
    block = bytearray(open(os.path.join(BUILD, 'stage1_block.bin'), 'rb').read())
    s1lo = ss['s1lo']
    block[ss['s1_pages'] - s1lo] = pages
    hpart = bytearray(open(os.path.join(BUILD, 'stage1_header.bin'), 'rb').read())
    if smode != 'rainbow':                        # stage 1: one colour, not the timer's
        block[ss['s1str'] - s1lo] = 0x2c
        hpart[ss['s1bc'] + 1 - 0x0351] = scol
    hpart = bytes(hpart)
    header = bytes([3, s1lo & 255, s1lo >> 8, 0x04, 0x03]) + petscii_name(name) + hpart
    header += bytes([0x20]) * (192 - len(header))
    assert len(header) == 192

    table = None
    if o.get('precomp'):
        try:
            table = json.load(open(o['precomp']))['precomp']
        except (ValueError, KeyError, TypeError):
            raise Fail(f"{o['precomp']}: not a deck's file (slopload.py -analyse dump.tap -out deck.json makes one)")

    def enc(classes, h, m=4):
        return R.apply_precomp(classes, h, table, m)

    pulses = T.rom_file(header, block, leader=o['leader'])
    rom_end = len(pulses)
    times = {'KERNAL boot': sum(pulses)}

    # ---- turbo: the core (stage 1 has no header for it)
    t0 = sum(pulses)
    pulses += enc([0] * pilot_len(PILOT_CORE, h_boot) + [3]
                  + T.turbo_classes(bytes(core) + bytes([T.xor_all(core)])), h_boot)
    times['core'] = sum(pulses) - t0

    seq = [0]
    report = []
    spans = []                  # each block's pulses: first, end, h, phase

    def emit(addr, data, flags, hmin, pilot_s, prog, phase, pmin, share=None, io=False, jit_b=8):
        """one block: pilot and header (pulse set 4, 2 bits a pulse), then
        pad, data and check in whichever pulse set (block_sets) and coding
        (2 bits a pulse or the prefix code) is quickest for this block;
        with a game running, only one that leaves the loader no more than
        share of the CPU (a fraction) in any frame's worth of tape"""
        t0 = sum(pulses)
        best = choose_coding(data, block_sets(hmin, pmin), share)
        if best is None:
            raise Fail(f"block ${addr:04X}: no pulse set keeps the loader within"
                       f" {share * 100:.0f}% of the CPU")
        _, h, m, pfx, key, body, sh = best
        if not pilot_fits(h, jit_b):
            raise Fail(f"block ${addr:04X}: a pilot of h={h} with {jit_b} cycles of jitter doesn't"
                       f" fit the core's window (a game's jitter must be 64 or less)")
        fl = flags | ((m - 2) << 4) | (T.F_PREFIX if pfx else 0)
        if addr < 0xe000 and addr + len(data) > 0xd000 and not io:
            fl |= T.F_UNDERIO                          # the core banks i/o out
        lead = [0] * pilot_len(pilot_s, h) + [3]
        lead += T.turbo_classes(T.header_bytes(addr, len(data), key, fl, seq[0], prog))
        i0 = len(pulses)
        pulses.extend(enc(lead, h))
        pulses.extend(R.apply_precomp(body, h, table, m, prev=lead[-1]))
        spans.append((i0, len(pulses), h, phase, jit_b))
        dt = sum(pulses) - t0
        report.append((seq[0], addr, len(data), key, flags, h, dt, phase, m, pfx, sh))
        times[phase] = times.get(phase, 0) + dt
        seq[0] += 1

    first = [True]

    def pilot_next():
        p = PILOT_FIRST if first[0] else PILOT_BLOCK
        first[0] = False
        return p

    # the game (and its music), screen off
    if game:
        gb = []
        parts = [(a, d, False) for a, d in game.get('extra', [])] + [(game['addr'], game['data'], False)]
        if pic:
            parts = pic['parts'] + parts
        if mus:
            parts.insert(0, (mus['addr'], mus['data'], False))
        for base, pdata, io in parts:
            a = base
            while a < base + len(pdata):
                b = min(base + len(pdata), a + o['blocksize'])
                gb.append((a, bytes(pdata[a - base:b - base]), io))
                a = b
        # its last block starts it; with none of the program loading while
        # it runs (all of it in its memory) that block ends the main load
        # too, or the core would never stop the tape (as SlopLoad 64 does)
        last = T.F_GAMEREADY | (0 if live_blocks else T.F_MAINEND)
        for i, (a, d, io) in enumerate(gb):
            emit(a, d, last if i == len(gb) - 1 else 0, h_boot, pilot_next(), 0, 'module data',
                 pmin_boot, io=io)

    # the program, game running
    done = 0
    for i, (a, d) in enumerate(live_blocks):
        fl = 0
        if i == len(live_blocks) - 1:
            fl = T.F_MAINEND | (0 if later_blocks else T.F_LAST)
        emit(a, d, fl, h_live, pilot_next(), (256 * done) // max(1, total_live),
             live_phase, pmin_live, game['share'] / 100 if game else None, jit_b=max(8, jit))
        done += len(d)

    # what the game's memory held, after it stops (motor was stopped)
    for i, (a, d) in enumerate(later_blocks):
        fl = T.F_LAST if i == len(later_blocks) - 1 else 0
        emit(a, d, fl, h_boot, PILOT_RESUME if i == 0 else PILOT_BLOCK, 255,
             'program, after the module' if show == 'module' else 'program, after the show',
             pmin_boot)

    if seq[0] > 256:                    # (a block's number is a byte: the core finds its place by it)
        raise Fail(f"{seq[0]} blocks on the tape, 256 at most: a larger -blocksize")
    pulses += [T.pulse(0, h_boot)] * TRAILER_PULSES   # trailer
    ext = os.path.splitext(tap)[1].lower() if tap else ''
    if tap is None:
        back = pulses
    elif ext in ('.wav', '.mp3'):
        back = write_sound(tap, pulses, o)
        if len(back) != len(pulses):
            os.remove(tap)
            raise Fail(f"{tap}: read back, the sound has {len(back) - len(pulses):+d} edges against"
                       f" the tape's {len(pulses)}: too much lost in it ("
                       + ("raise -bitrate; 192 or more suits every speed)" if ext == '.mp3' else
                          "raise -rate; 44100 suits every speed)"))
    else:
        T.tap_write(tap, pulses, hires=o.get('hires', False))
        back = T.tap_read(tap)

    # ---- check: decode it again with the model of the decoder
    got = T.decode_turbo([max(8, round(v)) for v in back], rom_end, pages)
    want = [('core', 0x0400, bytes(core))] + [(None, r[1], None) for r in report]
    if len(got) != len(want) or not all(g['ok'] for g in got):
        raise Fail(f"self-check failed: decoded {len(got)} blocks, wanted {len(want)}")
    if got[0]['data'] != bytes(core):
        raise Fail("self-check failed: core differs")
    mem = {}
    for g in got[1:]:
        for i, b in enumerate(g['data']):
            mem[g['addr'] + i] = b
    for i, b in enumerate(mdata):
        if mem.get(maddr + i) != b:
            raise Fail(f"self-check failed: program byte ${maddr + i:04X} differs")
    if quiet:
        return dict(pulses=pulses, spans=spans, name=name_shown(name), addr=maddr, end=mend,
                    seconds=sum(pulses) / T.PAL_HZ, trailer=TRAILER_PULSES)

    # ---- report
    sec = lambda c: c / T.PAL_HZ
    blocks = lambda n: -(-n // 254)                  # CBM disk blocks, 254 bytes each
    nlive = sum(len(d) for _, d in live_blocks)
    nlater = sum(len(d) for _, d in later_blocks)
    how = 'RUN' if run else f"JMP ${o['start']:04X} with $01=${o['status']:02X}"
    cut = len(petscii_codes(name)) > 16
    print(f"{os.path.basename(tap)}: \"{name_shown(name)}\"{' (the name cut to 16)' if cut else ''}  program ${maddr:04X}-${mend - 1:04X}"
          f" ({len(mdata)} bytes, {blocks(len(mdata) + 2)} blocks of the {MAX_BLOCKS} that fit), {how}")
    what = {'module': 'the module runs', 'picture': 'the picture shows',
            'picmusic': 'the picture and music play', 'music': 'the music plays'}.get(show)
    if game:
        nb_live = blocks(nlive + 2) if nlive else 0     # (as header +26: the load address with them)
        print(f"  {nb_live} blocks load while {what}"
              + (f", {blocks(len(mdata) + 2) - nb_live} after (they fall in its memory)" if nlater else ""))
        if show == 'module':
            print(f"  module {game.get('label') or os.path.basename(game['path'])} ${game['addr']:04X}-${game['end'] - 1:04X}"
                  f" ({len(game['data'])} bytes), claims "
                  + ', '.join(f"${a:04X}-${b - 1:04X}" for a, b in game.get('claims', [(game['addr'], game['claim'])])))
        else:
            print(f"  show module ${game['addr']:04X}-${game['end'] - 1:04X} ({len(game['data'])} bytes)")
        if pic:
            pb = pic['bank'] * 0x4000
            print(f"  picture: {os.path.basename(pic['path'])}, background {pic['bg']}; VIC bank {pic['bank']}:"
                  f" screen ${pb + 0xc00:04X}-${pb + 0xfe7:04X}, bitmap ${pb + 0x2000:04X}-${pb + 0x3f3f:04X},"
                  " colours in colour RAM")
        if mus:
            ws = ''.join(f", workspace ${a:04X}-${b - 1:04X}" for a, b in mus['claims'][1:])
            hz = PAL_FPS * 312 * 64 / mus['per_pal']
            mv = f", moved from ${mus['moved_from']:04X}" if mus.get('moved_from') is not None else ""
            print(f"  music: \"{mus['label']}\" ${mus['addr']:04X}-${mus['addr'] + len(mus['data']) - 1:04X}"
                  f" ({len(mus['data'])} bytes{ws}{mv}), {hz:.1f} play calls a second, up to"
                  f" {mus['play_cycles']} cycles each" + (f"; {len(mus['sid']['patched'])} stores taken out"
                                                            if mus['sid'] and mus['sid']['patched'] else ""))
    sets = lambda ss: ', '.join(f"{m}h={m * h}" for h, m in ss)
    if screen_on:
        capped = speed_h(o['speed']) + jit > H_MAX
        print(f"  speed {o['speed']}: margin at least +-{h_game} cycles while {what} ({speed_h(o['speed'])}"
              f" + {jit} of jitter: the screen is on" + (f"; {H_MAX} at most, the core's pilot window"
                                                          + (": below 0 is speed 0 here" if o['speed'] < 0 else "")
                                                          if capped else "")
              + f"); the loader takes at most {game['share']}% of"
              f" the CPU; shortest pulse per set {sets(game_sets(o['speed'], jit))}")
    elif game:
        print(f"  speed {o['speed']}: margin at least +-{h_live} cycles while {what} (the screen is off);"
              f" the loader takes at most {game['share']}% of the CPU;"
              f" shortest pulse per set {sets(boot_sets(o['speed']))}")
    if stripes:
        print(f"  border stripes: {o['stripes']} (colours {', '.join(str(c) for c in sorted(set(stripes)))});"
              f" the colour lookup makes the shortest pulses {STRIPES_COST} cycles longer")
    elif smode == 'flat':
        print(f"  border: colour {scol} all through, no stripes (red after a tape error)")
    elif smode == 'block':
        print("  border: a colour a block (its number, through all 16), no stripes")
    print(f"  bootspeed {o['bootspeed']}: margin at least +-{h_boot} cycles with the screen off;"
          f" shortest pulse per set {sets(boot_sets(o['bootspeed']))}")
    print("   seq  address       bytes  key  flags   h  pulses     seconds  bytes/s  cpu  phase")
    for s, a, n, key, fl, h, dt, ph, m, pfx, sh in report:
        code = f"{m}h+{'pfx' if pfx else '2b'}"
        cpu = f"{sh * 100:3.0f}%" if sh is not None else "   -"
        print(f"  {s:4d}  ${a:04X}-${a + n - 1:04X} {n:6d}  ${key:02X}  ${fl:02X}  {h:4d}  {code:9s} {sec(dt):7.2f}"
              f" {n / sec(dt):8.0f}  {cpu}  {ph}")
    tot = 0
    for k, v in times.items():
        print(f"  {k:28s} {sec(v):7.1f} s")
        tot += v
    print(f"  {'total':28s} {sec(tot):7.1f} s   (self-check: all {len(got)} turbo blocks decode)")
    if ext in ('.wav', '.mp3'):
        sound_check(tap, pulses, back, spans, o)
    if later_blocks and o['autorun'] and nomotor_auto:
        print("  -nomotor: part of the program loads after the module, so the module ends as soon"
              " as the rest has loaded")
    elif later_blocks and not o['autorun'] and ext in ('.wav', '.mp3'):
        print("  note: part of the program loads after the module, and the loader stops the motor"
              " while the player finishes. A CD or MP3 player can't be stopped: use -nomotor")
    return pulses


MP3_BITRATE = 320


def stripe_mode(spec):
    """-stripes: (mode, colour): ('rainbow', None) the timer's own colours;
    ('table', first colour) a style of two or more colours (stripe_table);
    ('flat', colour) one colour, no stripes (a style of one, such as
    black, or a single number); ('block', 0) the border a colour a block"""
    if spec is None or str(spec).lower() == 'rainbow':
        return 'rainbow', None
    if str(spec).lower() == 'block':
        return 'block', 0
    t = stripe_table(spec)
    if len(set(t)) == 1:
        return 'flat', t[0]
    return 'table', t[0]


def stripe_table(spec):
    """-stripes: None (rainbow, the standard core) or the 12 colours by
    timer b value, from a style's name or a list of colours (0-15)"""
    if spec is None or str(spec).lower() == 'rainbow':
        return None
    spec = str(spec).lower()
    if spec in STRIPES:
        cols = STRIPES[spec]
    else:
        try:
            cols = [int(c) for c in spec.split(',')]
        except ValueError:
            raise Fail(f"-stripes: a style ({', '.join(STRIPES)}) or colours like 6,14")
        if not cols or len(cols) > 12 or any(not 0 <= c < 16 for c in cols):
            raise Fail("-stripes: 1 to 12 colours, each 0-15")
    return [cols[(v // 2) % len(cols)] for v in range(12)]
SHOWS = ('module', 'none', 'picture', 'picmusic', 'music')


def load_koala(path):
    """a Koala Painter picture (10003 bytes: load address, 8000 bitmap,
    1000 screen, 1000 colour, background) as the show module's parts:
    screen $cc00, colours straight into colour ram, bitmap $e000"""
    d = open(path, 'rb').read()
    if len(d) in (10003, 10002):
        d = d[2:]
    if len(d) not in (10001, 10000):
        raise Fail(f"{path}: not a Koala picture ({len(d)} bytes; 10003 with its load address)")
    bitmap, screen, colour = d[:8000], d[8000:9000], d[9000:10000]
    bg = d[10000] & 15 if len(d) > 10000 else 0
    return dict(path=path, bg=bg, bitmap=bitmap, screen=screen, colour=colour, bank=3,
                parts=[(0xcc00, screen, False), (0xd800, colour, True), (0xe000, bitmap, False)])


PAL_FPS = 985248 / (63 * 312)
BUILTIN_PLAY_CYCLES = 2251       # the built-in player's longest play call, cycles (VICE: the JSR and RTS included)


def place_show(mlen, music, pic, prog):
    """(vic bank, module address) for the show module and the picture:
    clear of the loader, the music and each other, with the least of the
    program under them (that part loads after the show)"""
    banned = [(lo, hi) for lo, hi, _ in LOADER_RANGES] + list(music) + [(0xd000, 0xe000)]
    def clear(r):
        return not any(overlap(r, b) for b in banned)
    def under(rs):
        return sum(max(0, min(hi, prog[1]) - max(lo, prog[0])) for lo, hi in rs)
    best = None
    for bank in ((3, 2, 1, 0) if pic else (3,)):
        b = bank * 0x4000
        prs = [(b + 0x0c00, b + 0x0fe8), (b + 0x2000, b + 0x3f40)] if pic else []
        if not all(clear(r) for r in prs):
            continue
        for base in [0xca00] + list(range(0xfe00 - mlen // 256 * 256, 0x07ff, -0x100)):
            mr = (base, base + mlen)
            if not clear(mr) or any(overlap(mr, r) for r in prs):
                continue
            score = (under(prs + [mr]), )
            if best is None or score < best[0]:
                best = (score, bank, base)
            if score == (0,):
                break
        if best and best[0] == (0,):
            break
    if best is None:
        raise Fail("no room for the show module and the picture beside the music")
    return best[1], best[2], best[0][0]


def sound_check(path, pulses, back, spans, o):
    """how far the sound moved the edges, against what each block allows
    (spans: first pulse, end, h, phase, jitter); said, and the file
    removed if too far"""
    worst = None
    for i0, i1, h, ph, jb in spans:
        e = max(abs(b - a) for a, b in zip(pulses[i0:i1], back[i0:i1]))
        allow = h - jb
        if worst is None or e / allow > worst[0] / worst[1]:
            worst = (e, allow, ph)
    e, allow, ph = worst
    how = f"MP3 {o.get('bitrate') or MP3_BITRATE} kbit/s" if path.lower().endswith('.mp3') else "WAV"
    print(f"  sound: {how}, {o.get('rate') or 44100} Hz{', inverted' if o.get('invert') else ''};"
          f" read back, the edges moved at most {e:.1f} cycles; the block that allows"
          f" least takes +-{allow} ({ph}){'' if e < allow / 2 else ': TOO CLOSE'}")
    if e >= allow / 2:
        os.remove(path)
        raise Fail(f"{path}: the sound moves edges by {e:.1f} cycles, too close to the"
                   f" +-{allow} the tape allows: use a lower -speed or a higher -bitrate")


def write_sound(path, pulses, o):
    """the tape as a .wav or .mp3 (tools/audio.py); returns the pulses
    read back from the file written"""
    import audio as A
    rate = o.get('rate') or A.RATE
    samples = A.synth(pulses, rate, invert=o.get('invert', False))
    if path.lower().endswith('.mp3'):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            w = os.path.join(d, 'tape.wav')
            A.write_wav(w, samples, rate)
            try:
                A.encode_mp3(w, path, bitrate=o.get('bitrate') or MP3_BITRATE)
            except (RuntimeError, FileNotFoundError) as ex:
                raise Fail(f"MP3 encoding needs GStreamer with lamemp3enc: {ex}")
    else:
        A.write_wav(path, samples, rate)
    r, s = A.read_audio(path)
    if o.get('invert'):
        s = [-v for v in s]
    return A.pulses_from_audio(s, r)


def read_pulses(path):
    """a .tap's pulses, or a sound file's (its falling edges)"""
    if path.lower().endswith('.tap'):
        try:
            return T.tap_read(path)
        except (ValueError, IndexError):
            raise Fail(f"{path}: not a TAP file (or one cut short)")
    if not path.lower().endswith(('.wav', '.mp3')):
        raise Fail(f"{path}: a tape is a .tap, a .wav or an .mp3")
    import audio as A
    try:
        r, s = A.read_audio(path)
    except (RuntimeError, ValueError) as ex:
        raise Fail(f"{path}: can't read it as sound ({ex})")
    return [max(8, round(v)) for v in A.pulses_from_audio(s, r)]


def info(path):
    p = read_pulses(path)
    rom = T.rom_decode(p)
    print(f"{path}: {len(p)} pulses, {sum(p) / T.PAL_HZ:.1f} s")
    if not rom:
        print("  no KERNAL blocks found")
        return
    hdr = rom[0][2][9:]
    name = bytes(hdr[5:21]).decode('latin-1')
    print(f"  KERNAL file \"{name.rstrip()}\" type {hdr[0]}  ${hdr[1] | hdr[2] << 8:04X}-${(hdr[3] | hdr[4] << 8) - 1:04X}")
    last = rom[-1][1]
    try:
        ss = sym('stage1')
        blk = rom[2][2][9:]
        pages = blk[ss['s1_pages'] - ss['s1lo']]
    except Exception:
        pages = 3
    for g in T.decode_turbo(p, last, pages):
        if g['kind'] == 'core':
            print(f"  core   ${g['addr']:04X}-${g['addr'] + len(g['data']) - 1:04X}"
                  f"  period {g['period']}  {'ok' if g['ok'] else 'BAD CHECK'}")
        else:
            print(f"  #{g['seq']:<3d}  ${g['addr']:04X}-${g['addr'] + len(g['data']) - 1:04X}"
                  f"  key ${g['key']:02X} flags ${g['flags']:02X} progress {g['prog']:3d}"
                  f"  period {g['period']}  {'ok' if g['ok'] else 'BAD CHECK'}")


def pulse_sets(h_min, pmin):
    """The pulse sets (h, m) a block may use: at least h_min's margin, a
    shortest data pulse (m x h) of pmin or more, and pilot pulses (4h) of
    pmin or more. For each m the smallest such h; a bigger h only adds
    margin, so a faster speed number can't end up slower. A set with
    the same h and a bigger m is slower and no safer: left out."""
    h_min = max(h_min, ceil4(-(-pmin // 4)))
    out = []
    for m in (2, 3, 4):
        h = max(h_min, ceil4(-(-pmin // m)))
        if h <= H_MAX and not any(h2 == h for h2, _ in out):
            out.append((h, m))
    return out


def game_hmin(n, jit):
    return min(H_MAX, ceil4(speed_h(n) + jit))


def boot_hmin(n):
    return max(H_MIN_BOOT, speed_h(n))


def game_sets(n, jit):
    return pulse_sets(game_hmin(n, jit), PMIN_GAME)


def boot_sets(n):
    return pulse_sets(boot_hmin(n), PMIN_BOOT)


def cal_sets(jit):
    """every (h, m) the tool can use, screen off and with a game"""
    out = []
    for n in SPEEDS:
        for hm in boot_sets(n) + game_sets(n, jit):
            if hm not in out:
                out.append(hm)
    return sorted(out)


# ---- the coding of a block's body, and the loader's share of the CPU

DIBIT_SUM = [((x >> 6) & 3) + ((x >> 4) & 3) + ((x >> 2) & 3) + (x & 3) for x in range(256)]


def max_share(cyc, cost, window=SHARE_WINDOW):
    """the biggest cost / cycles over every run of consecutive pulses (or
    bytes) at least window cycles long; the whole run if it is shorter"""
    tc = sum(cyc)
    if tc <= window:
        return sum(cost) / max(1, tc)
    best = 0.0
    j = sc = sk = 0
    n = len(cyc)
    for i in range(n):
        while j < n and sc < window:
            sc += cyc[j]
            sk += cost[j]
            j += 1
        if sc < window:
            break
        if sk > best * sc:
            best = sk / sc
        sc -= cyc[i]
        sk -= cost[i]
    return best


def block_sets(h_min, pmin):
    """Every pulse set a block may use: h from h_min (at least the speed's
    margin) to H_MAX, each m with m x h and the 4h pilot no shorter than
    pmin. A faster speed's sets include a slower one's, so it is never
    slower; a bigger h than the least can win when the CPU share limit
    makes the shortest sets' keys slow."""
    h0 = max(h_min, ceil4(-(-pmin // 4)))
    return [(h, m) for h in range(h0, H_MAX + 1, 4) for m in (2, 3, 4) if m * h >= pmin]


def choose_coding(data, sets, share):
    """The quickest way to write a block's body (pad, data xor key,
    check): over the pulse sets, 2 bits a pulse (any of the 256 keys) or
    the prefix code (the key giving most 1 bits), keeping the loader's
    share of the CPU in every frame's worth of tape within share (a
    fraction; None: no limit). Returns (cycles, h, m, prefix, key,
    classes, share) or None."""
    chk = T.xor_all(data)
    n = len(data) + 2
    cands = []
    # prefix code: one key, so one list of classes for every set
    pkey = T.best_prefix_key(data)
    pcl = T.prefix_classes([0x00] + [b ^ pkey for b in data] + [chk])
    np_, sp = len(pcl), sum(pcl)
    for h, m in sets:
        cands.append((h * (m * np_ + 2 * sp), h, m, True, pkey))
    # 2 bits a pulse: each key's class total from the pairs' counts
    freq = [[0] * 4 for _ in range(4)]
    for b in data:
        for p in range(4):
            freq[p][(b >> (6 - 2 * p)) & 3] += 1
    tab = [[sum(freq[p][v] * (v ^ k) for v in range(4)) for k in range(4)] for p in range(4)]
    fixed = DIBIT_SUM[0xff] + DIBIT_SUM[chk]               # pad and check: not keyed
    for key in range(256):
        sk = fixed + sum(tab[p][(key >> (6 - 2 * p)) & 3] for p in range(4))
        for h, m in sets:
            cands.append((h * (4 * m * n + 2 * sk), h, m, False, key))
    cands.sort()
    pcost = None
    for cyc_total, h, m, pfx, key in cands:
        if pfx:
            sh = None
            if share is not None:
                if pcost is None:
                    costs, extra = IRQ_COST['prefix']
                    bits = (1, 2, 3, 3)
                    pcost, nb = [], 0
                    for k in pcl:
                        c = costs[k] + (extra if (nb + bits[k]) // 8 > nb // 8 else 0)
                        nb += bits[k]
                        pcost.append(c)
                if sum(pcost) > share * cyc_total:
                    continue
                sh = max_share([(m + 2 * k) * h for k in pcl], pcost)
                if sh > share:
                    continue
            return cyc_total, h, m, True, key, pcl, sh
        body = [0xff] + [b ^ key for b in data] + [chk]
        sh = None
        if share is not None:
            costs, extra = IRQ_COST['dibit']
            per_byte = 4 * max(costs) + extra
            if per_byte * n > share * cyc_total:
                continue
            sums = bytes(body).translate(bytes(DIBIT_SUM))
            sh = max_share([(4 * m + 2 * x) * h for x in sums], [per_byte] * n)
            if sh > share:
                continue
        return cyc_total, h, m, False, key, T.turbo_classes(body), sh
    return None


def analyse_cmd(path, o):
    jit0 = o.get('jitter') or GAME_JITTER_DEFAULT
    res = R.analyse(read_pulses(path), cal_sets(jit0))
    if path.lower().endswith('.tap') and open(path, 'rb').read(13)[12:13] == b'\x02':
        other = R.analyse(T.tap_read(path, phase=1), cal_sets(jit0))     # half-waves paired the other way
        if len(other['sections']) > len(res['sections']):
            res = other
    if not res['sections']:
        raise Fail(f"{path}: no calibration sections found (is it a dump of -calibrate's tape?)")
    jit = o.get('jitter')
    if not jit:
        try:
            jit = find_game(o['module'], o)['jitter']
        except Fail:
            jit = GAME_JITTER_DEFAULT
    print(f"{path}: {len(res['sections'])} of {len(cal_sets(jit0))} pulse sets found")
    print("    h m  deck speed   wow    flutter  margin (raw / precomp)  misread pulses")
    for s in res['sections']:
        print(f"  {s['h_nominal']:3d} {s['m']}   {s['deck_speed'] * 100:6.2f}%  +-{s['wow'] * 100:4.2f}%"
              f"  {s['flutter_h'] * s['h_nominal']:5.1f} cyc   {s['margin_h'] * s['h_nominal']:6.1f} / "
              f"{s['margin_precomp_h'] * s['h_nominal']:6.1f} cycles      {s['errors']}")
    rec = R.recommend(res, SPEEDS, lambda n: game_sets(n, jit), boot_sets, jit)
    for mode, label in (('module', '-speed (a module running)'), ('screen_off', '-bootspeed (screen off)')):
        a, b = rec.get((mode, False)), rec.get((mode, True))
        print(f"  {label:24s}: {a if a is not None else 'none safe'} without -precomp,"
              f" {b if b is not None else 'none safe'} with it")
    print(f"  (fastest speed whose worst pulse leaves 15% of h after {jit} cycles of module"
          " jitter, or 8 with the screen off)")
    if o.get('out'):
        json.dump({'deck': res, 'precomp': R.precomp_table(res)}, open(o['out'], 'w'), indent=1)
        print(f"  wrote {o['out']}: use -precomp {o['out']} when mastering")
    return 0


def side_seconds(o):
    """a side's usable seconds from -tape CNN or -side MM:SS, less -margin;
    None: no limit"""
    if o.get('tape') and o.get('side'):
        raise Fail("-tape and -side: one or the other")
    if o.get('tape'):
        t = str(o['tape']).upper().lstrip('C')
        if not t.isdigit() or int(t) < 2:
            raise Fail(f"-tape {o['tape']}: a cassette's length, such as C60 or C90")
        full = int(t) * 60 / 2
    elif o.get('side'):
        try:
            parts = [float(x) for x in str(o['side']).split(':')]
        except ValueError:
            raise Fail(f"-side {o['side']}: minutes, or MM:SS")
        if len(parts) > 2:
            raise Fail(f"-side {o['side']}: minutes, or MM:SS")
        full = parts[0] * 60 + (parts[1] if len(parts) == 2 else 0)
    else:
        return None
    try:
        margin = float(o.get('margin', 10))
    except ValueError:
        raise Fail(f"-margin {o['margin']}: seconds")
    if full - margin <= 0:
        raise Fail("no time left on a side after -margin")
    return full - margin


def tapeside(out, inputs, o):
    """many programs on whole tape sides: see the usage"""
    import random
    if 'given' not in o:                # (called with options of its own)
        for k in ('music', 'sid', 'picture', 'show', 'start', 'filename'):
            if o.get(k) is not None:
                raise Fail(f"-tapeside: -{k} doesn't go on a tape side (each program is named after"
                           " its file, starts with RUN, and loads with no module, music or picture)")
    files = []
    for x in (inputs or ['.']):
        if os.path.isdir(x):
            fs = sorted(f for f in os.listdir(x) if f.lower().endswith('.prg'))
            files += [os.path.join(x, f) for f in fs]
        elif os.path.isfile(x):
            files.append(x)
        else:
            raise Fail(f"{x}: no such file or folder")
    seen = set()
    files = [f for f in files if not (os.path.abspath(f) in seen or seen.add(os.path.abspath(f)))]
    if not files:
        raise Fail("-tapeside: no .prg files")
    if o.get('random'):
        random.shuffle(files)
    limit = side_seconds(o)
    ext = os.path.splitext(out)[1].lower()
    if ext not in ('.tap', '.wav', '.mp3'):
        raise Fail(f"{out}: .tap, .wav or .mp3")
    # each program's tape, built and checked
    parts = []
    for f in files:
        po = dict(o, module='none', show='none', music='none', start=None,
                  filename=os.path.splitext(os.path.basename(f))[0])
        addr = load_prg(f)[0]
        if addr != 0x0801:
            raise Fail(f"{f}: loads at ${addr:04X}; programs on a tape side load at $0801 and"
                       " start with RUN (master it on its own tape with -start)")
        r = master(f, None, po, quiet=True)
        r['path'] = f
        if limit is not None and r['seconds'] > limit:
            raise Fail(f"{f}: {r['seconds']:.0f} s, longer than a side ({limit:.0f} s after the margin)")
        parts.append(r)
    # the trailer only after the last program on a side: before the next
    # one its KERNAL leader ends the last pulse, and a LOAD started in a
    # trailer of pulses shorter than the KERNAL's (304 cycles at speed 0)
    # can crash its tape interrupt
    for r in parts:
        r['bare'] = r['pulses'][:len(r['pulses']) - r['trailer']]
        r['bare_s'] = sum(r['bare']) / T.PAL_HZ
    # onto sides: each program on the first side with room for it
    sides = []
    for r in parts:
        for sd in sides:
            if limit is None or sum(x['seconds'] for x in sd) + r['seconds'] <= limit:
                sd.append(r)
                break
        else:
            sides.append([r])
    stem, _ = os.path.splitext(out)
    names = [out] if len(sides) == 1 else [f"{stem}-{i // 2 + 1}{'AB'[i % 2]}{ext}" for i in range(len(sides))]
    blocks = lambda n: -(-n // 254)
    if o.get('random'):
        print("shuffled: " + ', '.join(os.path.basename(r['path']) for r in parts))
    for i, (sd, path) in enumerate(zip(sides, names)):
        pulses = []
        spans = []
        for k, r in enumerate(sd):
            base = len(pulses)
            pulses += r['pulses'] if k == len(sd) - 1 else r['bare']
            spans += [(a + base, b + base, h, f"{r['name']}: {ph}", jb) for a, b, h, ph, jb in r['spans']]
        if ext == '.tap':
            T.tap_write(path, pulses, hires=o.get('hires', False))
            if len(T.tap_read(path)) != len(pulses):
                raise Fail(f"{path}: read back, the pulses differ")
        else:
            back = write_sound(path, pulses, o)
            if len(back) != len(pulses):
                os.remove(path)
                raise Fail(f"{path}: read back, the sound has {len(back) - len(pulses):+d} edges against"
                           f" the tape's {len(pulses)}: too much lost in it (raise -bitrate)")
        tot = sum(pulses) / T.PAL_HZ
        where = f"tape {i // 2 + 1} side {'AB'[i % 2]}: " if len(sides) > 1 else ""
        left = f", {limit - tot:.0f} s of the side's {limit:.0f} left" if limit is not None else ""
        print(f"{os.path.basename(path)}: {where}{len(sd)} programs, {int(tot // 60)}:{tot % 60:04.1f}{left}")
        t = 0
        for k, r in enumerate(sd):
            n = r['end'] - r['addr']
            print(f"  {int(t // 60):3d}:{t % 60:04.1f}  \"{r['name']}\"  ${r['addr']:04X}-${r['end'] - 1:04X}"
                  f" ({blocks(n + 2)} blocks), {r['seconds']:.1f} s")
            t += r['seconds'] if k == len(sd) - 1 else r['bare_s']
        if ext != '.tap':
            sound_check(path, pulses, back, spans, o)
    print(f"  speed {o['speed']}; every program checked by decoding its tape again")
    return sides


def main(argv):
    try:
        o, pos = parse_args(argv)
        if o.get('version'):
            check_given(o, 'version')
            print(f"SlopLoad {VERSION}")
            return 0
        if o.get('info'):
            check_given(o, 'info')
            for p in pos:
                info(p)
            return 0
        if o.get('mode') == 'calibrate':
            if len(pos) != 1:
                raise Fail("usage: slopload.py -calibrate out.tap")
            check_given(o, 'calibrate', pos[0])
            sets = cal_sets(o.get('jitter') or GAME_JITTER_DEFAULT)
            if pos[0].lower().endswith(('.wav', '.mp3')):
                import tempfile
                with tempfile.TemporaryDirectory() as d:
                    p = R.calibration_tap(os.path.join(d, 'cal.tap'), sets)
                write_sound(pos[0], p, o)
            else:
                p = R.calibration_tap(pos[0], sets)
            how = (" Put it through the encoder (or player) the tape will go through, then:"
                   " slopload.py -analyse that.mp3 (or .wav) -out deck.json"
                   if pos[0].lower().endswith(('.wav', '.mp3')) else
                   " Record it to a cassette, dump the cassette back to a .tap with the same deck,"
                   " then: slopload.py -analyse dump.tap -out deck.json")
            print(f"{pos[0]}: {sum(p) / T.PAL_HZ:.0f} s of test pulses, the {len(sets)} pulse sets"
                  " with each speed's least margin." + how)
            return 0
        if o.get('mode') == 'analyse':
            if len(pos) != 1:
                raise Fail("usage: slopload.py -analyse dump.tap [-out deck.json]")
            check_given(o, 'analyse')
            return analyse_cmd(pos[0], o)
        if o.get('tapeside'):
            if not pos:
                raise Fail("usage: slopload.py -tapeside out.tap [programs or folders] [-tape C60]")
            check_given(o, 'tapeside', pos[0])
            tapeside(pos[0], pos[1:], o)
            return 0
        if len(pos) != 2:
            print(f"SlopLoad {VERSION}")
            print(__doc__)
            return 1
        check_given(o, 'master', pos[1])
        master(pos[0], pos[1], o)
        return 0
    except (Fail, OSError) as ex:
        print(f"slopload: {ex}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
