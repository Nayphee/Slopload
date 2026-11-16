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
  -module FILE|none  what runs while it loads: a module's .lm (the demos:
                     build/modules/flappy.lm, crossy.lm, squeeze.lm,
                     rubble.lm, bounce.lm, template.lm, ozgold.lm,
                     petscii.lm), a module's .prg
                     with its .parts.json beside it, a PETSCII screen
                     (.pet, .petmate or Marq's .c: shown while it loads),
                     a picture in one of picturelm.py's formats (Koala,
                     Art Studio, Doodle and 13 more: made into the picture
                     module here, as PICTURE-LM does on a C64), or none
                     (the default: the screen off, or the -sid tune alone)
  -drawin            a picture as the first module draws in: it starts
                     first, its bitmap cleared, and its colours, screen
                     and bitmap load while it shows, appearing as they
                     come (about 5-8 s more at speed 0); without it the
                     picture loads whole, then shows. A .lm draws in if
                     it was made to (picturelm.py -drawin, PICTURE-LM)
  -then FILE         a second module after the first (-module): the first
                     shows while the second's parts load, then the second
                     while the program loads (module chaining: a PETSCII
                     screen with its scroller and counter, then a
                     picture). FILE is a module (.lm, a module's .prg, a
                     PETSCII screen) or a picture in one of picturelm.py's
                     formats, made into the picture module (-wait, -fade
                     and -sprite go to it). The tune plays on through
                     both (-musicstart: from before the first, or
                     with the first or second); a PETSCII screen's counter, first, counts the
                     second module's blocks down to 000. A PETSCII screen
                     in a chain is built at $A000, clear of a picture
  -show MODE         module, none or music: what -module and -sid say
                     already (a module; the tune alone, the screen off;
                     nothing), so seldom needed
  -wait              hold the end of the load for the player: without it
                     (or -waitgame) the module or show ends as soon as the
                     program is in (a game mid-round too) and the program
                     starts. With a picture, PRESS SPACE OR FIRE across its
                     bottom row (joystick port 2); with a module that keeps
                     it (its header's byte 27: the demo modules do), SPACE
                     alone: a game plays on, game after game, until then;
                     a loading screen (OZ GOLD, a PETSCII screen) holds
                     at 000
  -waitgame          with a game module that keeps it (its header's byte
                     27, bit 5: the demo games do): once the program is
                     in, the player plays on to the end of the game, and
                     the program starts then (not with -wait)
  -countdown         with a module whose status line counts (the demo
                     games): the blocks still to load ("024", down to
                     000) in place of the percent
  -sprite FILE       with a picture (-module or -then): one or two sprites over it (64 bytes
                     each, 63 will do; a .prg's load address skipped), the
                     second beside the first; -spritepos X,Y their top left
                     on the picture (0-319, 0-199; default bottom right),
                     -spritecolours C,C,... their colour, or up to 32 they
                     flash through (default 1, white), -spritespeed N
                     frames a colour (default 2), -spritemc A,B multicolour
                     sprites with these shared colours, -spriteexpand twice
                     as wide and tall. Each sprite on a line costs the
                     loader margin: one 8 cycles, two 16
  -fade              (kept for old command lines: every module's music
                     fades out now, about 2.6 seconds once the program is
                     in, and after -wait's key, before the program starts)
  -sid FILE          the music: a .sid (-song N: its song N, else its
                     own default), a .slm (sidstrip.py's) or a C64 PRG
                     tune (any other file: a music editor's, such as
                     DMC, EMS or Future Composer; its load address its
                     first two bytes): -init HHHH and -inita HH (hex:
                     lda #$HH, jsr $HHHH; the defaults its load address
                     and 00), -play HHHH (jsr $HHHH; three past the load
                     address), -calls N (play calls a frame, 1-8; 1) and
                     -clock pal|ntsc (the machine it was made for; pal).
                     The demos are music/build/enigma.sid, slopload.sid
                     and ozgold.sid. A tune in SlopLoad's own player
                     (those are) goes at $C000 where it can: there a
                     module that makes sound effects keeps them (voice 3)
  -musicstart WHEN   with a module and -sid: when the tune starts, before
                     (the default: before anything else loads, SlopLoad's
                     player playing it while the module's parts load),
                     first (with the first module) or second (with -then's
                     module: the first is silent, its sound effects on).
                     It plays on to the end of the load either way
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
  -screech           with a PETSCII screen: Novaload's loading noise, the
                     program's bytes as they load played as voice 1's pitch
                     (a sawtooth). It has the SID: a tune playing is cut
                     off when the screen starts; with a second module
                     (-then) the tune starts with that one instead
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
  -stripes STYLE     the border's loading lines: rainbow (default), a
                     style, colours, black, block, or an effect: classic,
                     thin, mixed, and:N, ora:N, eor:N, line:N (,B: its
                     colour to start from; line: the border's);
                     -showstripes: on through the show too
  -cycle             the border's colour one on with every 256 bytes
                     loaded, under an effect or one colour (-stripes
                     thin, eor:N, black, 6 ...): 3 cycles a pulse
  -blocksize N       bytes per block (default 4096): after a tape error,
                     rewinding one block's worth is enough to retry
  -leader N          KERNAL leader pulses before the header (default 27136)
  -precomp FILE      write the pulses against what a real deck was measured
                     to do to them (FILE from -analyse ... -out FILE)
  -hires             exact cycle counts in the .tap (finer than 8 cycles)
  -nomotor           for players the C64 can't stop (CD, MP3, a PC): when
                     part of the program loads after the module, the
                     module ends as soon as the rest has loaded (the loader
                     cuts it off), instead of stopping the motor while the
                     player plays on (-wait)
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
# loading line effects (-stripes NAME[:N][,B]: core_fx): the interrupt's 10
# bytes where the core has stx $d020, each pulse, as classic loaders did
# it; the cycles they take beyond stx's 4 (the shortest pulses that much
# longer: the 8-byte ones 2 more for their cmp #$00, line's two loads and
# stores filling the 10). and and ora take the byte coming in off the
# tape (ld_sr). line: a line of its own colour (N) on a border of B, every
# pulse (lda #N : sta $d020 : lda #B : sta $d020); its -cycle steps B a
# block at a time, not the border a page
FX = {'classic': 10, 'thin': 12, 'mixed': 12, 'and': 8, 'ora': 8, 'eor': 8, 'line': 8}
FX_VALUE = ('and', 'ora', 'eor', 'line')        # these take a value (0-15: line's, its colour)
FX_LEN = 10                                     # (tools/build.py's: the effect's bytes)
CYCLE_COST = 3              # -cycle: inc $d020 where the core skips 3 bytes, on a page crossing
GAME_JITTER_DEFAULT = 48
# a loading sprite's cost (-sprite): what it adds to the worst edge timing
# error with the picture on, by how many share a raster line (tests/jitter.py
# with sprites: 51 cycles with none, 59 with one); the core's pilot window
# (GAME_JITTER_MAX) takes two
SPRITE_JITTER = {1: 8, 2: 16}
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


DRAW_IN = ((0x0c00, 0x1000), (0x2000, 0x3f40))     # a picture's screen and bitmap, in its VIC bank
# a picture with sprites: the 24 bytes after its screen's 1,000 are its too
# (its screen part 1,024 bytes), for the VIC reads the sprites' pointers
# at screen + $3f8: the two loading sprites' ($fd, $fe: bank + $3f40, +
# $3f80). A program's bytes there then load after the show, as the rest
# under the picture does, and not over the pointers while it shows
SPRITE_TAIL = bytes(16) + bytes([0xfd, 0xfe]) + bytes(6)


def draw_split(parts, bank):
    """a picture module's parts (address, bytes, io) for its drawing in:
    (first, drawn). first: what starts it (its code, a .lm's colours, the
    sprites, a tune); drawn: what loads while it shows, colour RAM (io)
    first, then its screen and bitmap (DRAW_IN in the bank), by address"""
    pb = bank * 0x4000
    cuts = [(pb + lo, pb + hi) for lo, hi in DRAW_IN]
    first, drawn = [], []
    for a, d, io in parts:
        if io:
            drawn.append((a, d, io))
            continue
        pieces = [(a, a + len(d))]
        for c in cuts:
            nxt = []
            for rng in pieces:
                out, inside = subtract(rng, c)
                nxt += out
                if inside:
                    drawn.append((inside[0], d[inside[0] - a:inside[1] - a], False))
            pieces = nxt
        first += [(lo, d[lo - a:hi - a], False) for lo, hi in pieces]
    drawn.sort(key=lambda p: (not p[2], p[0]))
    return first, drawn


def pilot_len(seconds, h):
    return max(300, int(seconds * T.PAL_HZ / (4 * h)))


ALIASES = {'mixtape': 'tapeside', 'analyze': 'analyse', 'measure': 'core'}
# what each kind of run uses: an option typed that the run doesn't use is
# refused, not ignored
SOUND_OPTS = {'rate', 'bitrate', 'invert'}
PRG_OPTS = ('init', 'inita', 'play', 'calls', 'clock')     # a PRG tune's (-sid tune.prg)
TAPE_OPTS = {'speed', 'bootspeed', 'blocksize', 'leader', 'precomp', 'hires', 'core', 'stripes', 'showstripes',
             'cycle'}
SIDE_ONLY = {'tape', 'side', 'margin', 'random'}
MODE_OPTS = {
    'master': TAPE_OPTS | SOUND_OPTS | {'filename', 'module', 'start', 'status', 'autorun', 'nomotor',
                                        'music', 'sid', 'song', 'init', 'inita', 'play', 'calls', 'clock',
                                        'show', 'picture', 'scroll', 'scrollrow',
                                        'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font', 'screech',
                                        'fade', 'wait', 'waitgame', 'countdown', 'drawin', 'sprite', 'spritepos', 'spritecolours',
                                        'spritespeed', 'spritemc', 'spriteexpand', 'then', 'musicstart'},
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
    if 'rate' in given and not 8000 <= (o.get('rate') or 0) <= 192000:
        raise Fail("-rate must be 8000 to 192000 (the sound's samples a second: 44100 if not given)")
    if 'bitrate' in given and not 32 <= (o.get('bitrate') or 0) <= 320:
        raise Fail("-bitrate must be 32 to 320 (an .mp3's kbit/s: 320 if not given)")
    ext = os.path.splitext(out or '')[1].lower()
    if out is not None and ext not in ('.wav', '.mp3'):
        for k in ('rate', 'bitrate', 'invert'):
            if k in given:
                raise Fail(f"-{k} goes with a .wav or .mp3 (the tape written as sound)")
    if out is not None and ext == '.wav' and 'bitrate' in given:
        raise Fail("-bitrate goes with an .mp3 (a .wav's sound isn't compressed: -rate sets its sample rate)")


def parse_args(argv):
    opts = dict(filename=None, module='none', speed=DEF_SPEED, bootspeed=None,
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
            elif k in ('nomotor', 'invert', 'random', 'showstripes', 'fade', 'wait', 'waitgame', 'countdown',
                       'cycle', 'drawin', 'screech',
                       'spriteexpand'):
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
                       'counter', 'screen', 'font', 'sprite', 'spritepos', 'spritecolours', 'spritespeed',
                       'spritemc', 'then', 'musicstart', 'init', 'inita', 'play', 'calls', 'clock'):
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


def ending_bits(o):
    """a module's header +28, the tool's options that end it: bit 1
    -wait (SPACE), bit 5 -waitgame (a game's end), bit 3 -countdown"""
    return ((2 if o.get('wait') else 0) | (0x20 if o.get('waitgame') else 0)
            | (8 if o.get('countdown') else 0))


def find_game(spec, o=None, chain=False, parts=None):
    """the module, from its file: a .lm (all its parts in one file), a
    module's .prg (its parts file beside it), or a PETSCII screen (.pet,
    .petmate, .c: PETSCII-Load with that screen, and the options'
    scroller and counter; chain: built at $A000, for a chain). Nothing
    is looked up by name: the demo modules are files like any other
    (build/modules/*.lm). parts: the module's parts, made here (a
    picture: then_module)"""
    if spec.lower() == 'none':
        return None
    import petscii as P
    pj = None
    if parts is not None:
        pass
    elif spec.lower().endswith('.lg'):
        raise Fail(f"{spec}: modules are .lm files now (the same inside): rename it to end in .lm")
    if spec.lower().endswith(P.ENDINGS + ('.lm',)) and not os.path.exists(spec):
        raise Fail(f"no file {spec}")
    o = o or {}
    pet = ('scroll', 'scrollrow', 'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font', 'screech')
    if any(o.get(k) is not None for k in pet) and not spec.lower().endswith(P.ENDINGS):
        raise Fail(f"-{next(k for k in pet if o.get(k) is not None)} goes with a PETSCII screen as -module"
                   " (a .pet, .petmate or .c file)" + (" or -then" if chain else ""))
    if parts is not None:
        path = spec
        (addr, data), extra = parts[0], parts[1:]
    elif spec.lower().endswith(P.ENDINGS):
        if not str(o.get('screen') or 0).isdigit():
            raise Fail(f"-screen needs a screen's number (0 the first), not {o['screen']!r}")
        try:
            scr = P.read(spec, int(o.get('screen') or 0))
            if o.get('font'):
                scr = P.with_font(scr, o['font'])
            notes = []
            parts = P.module(scr, **P.options({'-' + k: o.get(k) for k in pet}, scr), notes=notes, chain=chain)
        except (P.Bad, ValueError) as ex:
            raise Fail(str(ex))
        for n in notes:
            print(f"  {n}")
        path = spec
        (addr, data), extra = parts[0], parts[1:]
    elif spec.lower().endswith('.lm'):
        try:
            parts = P.read_lm(spec)
        except (P.Bad, OSError) as ex:
            raise Fail(str(getattr(ex, 'strerror', None) or ex))
        path = spec
        (addr, data), extra = parts[0], parts[1:]
    else:
        path = spec
        if not os.path.isfile(path):
            raise Fail(f"no file {spec}: -module takes a module's file (a .lm; the demos are"
                       " build/modules/flappy.lm, crossy.lm, squeeze.lm, rubble.lm, bounce.lm, template.lm,"
                       " ozgold.lm and petscii.lm),"
                       " a PETSCII screen, or none")
        addr, data = load_prg(path)
        extra = None
        pj = os.path.splitext(path)[0] + '.parts.json'
    if data[:4] != b'PLG1':
        raise Fail(f"{path}: not a SlopLoad module (no 'PLG1' at its start), nor a picture this knows (Koala,"
                   " Art Studio, Doodle and the rest of picturelm.py's formats)")
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
    # +27: bit 0 it leaves the border to the loader, bit 1 it makes effects
    # on voice 3 beside SlopLoad's own player
    sfx = len(data) > 27 and bool(data[27] & 2)
    g = dict(path=path, addr=addr, data=data, end=addr + len(data), claim=claim,
             init=w(4), frame=w(6), stop=w(8), jitter=jit, share=share, sfx=sfx, extra=[])
    if pj and os.path.exists(pj):
        spec = json.load(open(pj))
        for v in spec.values():         # a part: beside the parts file, else in SlopLoad's folder
            if isinstance(v, dict) and 'prg' in v and not os.path.isabs(v['prg']):
                near = os.path.join(os.path.dirname(os.path.abspath(pj)), v['prg'])
                v['prg'] = near if os.path.exists(near) else os.path.join(ROOT, v['prg'])
        if 'music' in spec:
            raise Fail(f"{pj}: a module brings no songs of its own any more: take 'music' out"
                       " (the tune is a file of its own: -sid FILE)")
        for k, v in spec.items():       # parts always loaded with it (more of its code)
            if isinstance(v, dict) and v.get('always') and extra is None:
                if not os.path.exists(v['prg']):
                    raise Fail(f"{path}: its part '{k}' is missing: {v['prg']}")
                g['extra'].append(load_prg(v['prg']))
    if extra:                           # (a .lm's or a screen's other parts)
        g['extra'] = [(a, bytes(d)) for a, d in extra]
    if path.lower().endswith(P.ENDINGS):
        g['label'] = f"PETSCII-Load with {os.path.basename(path)}"
    g['claims'] = [(addr, claim)] + [(a, a + len(d)) for a, d in g['extra']]
    for clo, chi in g['claims']:
        for lo, hi, what in LOADER_RANGES:
            if overlap((clo, chi), (lo, hi)):
                raise Fail(f"module ${clo:04X}-${chi - 1:04X} overlaps {what} (${lo:04X}-${hi - 1:04X})")
    return g


def then_module(spec, o, screen):
    """-then's module: a module's file (find_game; screen: it is the
    PETSCII screen, the options' scroller and counter its), or a picture
    in one of picturelm.py's formats, made into the picture module with
    the options' -wait, -fade and sprites. (the module, a picture?)"""
    import petscii as P
    import picturelm as PL
    low = spec.lower()
    if low.endswith('.lg'):
        return find_game(spec), False                   # (its message: rename it)
    if not os.path.isfile(spec):
        raise Fail(f"no file {spec}")
    head = open(spec, 'rb').read(6)
    if low.endswith(('.lm',) + P.ENDINGS) or head[2:6] == b'PLG1':
        return find_game(spec, o if screen else {}, chain=True), False
    try:
        parts = PL.make(spec, {k: o.get(k) for k in PL.OPTS})
    except PL.Bad as ex:
        raise Fail(f"-then: {ex} (or a module: a .lm, a module's .prg, a PETSCII screen)")
    g = find_game(spec, {}, parts=parts)
    g['label'] = f"{os.path.basename(spec)} ({PL.read_picture(spec)['name']}), as the picture module"
    return g, True


CHAIN_AT = 0x0380              # the switch's code: src/chain.asm (the tape buffer)


def chain_shim(a, b, pstep, cs):
    """src/chain.asm assembled for the modules a (first) and b (second):
    dict(addr, data, cframe, cstop); pstep: the program's progress a page
    (8.8), cs: the core's symbols (its vectors)"""
    import build as B
    import contextlib
    import io
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        org, data, labs = B.assemble(os.path.join(ROOT, 'src', 'chain.asm'), 'chain_placed',
                                     {'chainat': CHAIN_AT, 'a_frame': a['frame'], 'a_stop': a['stop'],
                                      'b_init': b['init'], 'b_frame': b['frame'], 'b_stop': b['stop'],
                                      'pstep': pstep, 'pt_frame': cs['pt_frame'], 'pt_step': cs['pt_step']})
    assert org == CHAIN_AT and labs['chainend'] <= 0x0400, "src/chain.asm runs past the tape buffer"
    assert all(labs[v] & 255 != 255 for v in ('cafr', 'cast', 'cbin', 'cbfr', 'cbst')), \
        "src/chain.asm: a jmp () vector on a page's last byte"
    return dict(addr=org, data=bytes(data), cframe=labs['cframe'], cstop=labs['cstop'])


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
    if 'status' in (o.get('given') or ()) and o['start'] is None:
        raise Fail("-status goes with -start ADDR (the port's value at the jump; a program started with RUN"
                   " gets BASIC's own)")
    # ---- what shows while the program loads (SHOWS): the module (a
    # picture made into one here), the tune alone, or nothing
    given = o.get('given') or set()
    if o.get('picture') is not None:
        raise Fail("-picture is gone: a picture is a module now, -module FILE (Koala, Art Studio, Doodle or any"
                   " of picturelm.py's formats; -sid FILE for its music)")
    show = str(o.get('show') or ('module' if str(o['module']).lower() != 'none' else
                                 'music' if o.get('sid') else 'module')).lower()
    if show in ('picture', 'picmusic'):
        raise Fail(f"-show {show} is gone: a picture is a module now, -module FILE (Koala, Art Studio, Doodle or"
                   " any of picturelm.py's formats; -sid FILE for its music)")
    if show not in SHOWS:
        raise Fail(f"-show must be one of {', '.join(SHOWS)}")
    if show == 'module' and str(o['module']).lower() == 'none':
        show = 'none'
    pic_first = False
    if show == 'module' and picture_file(o['module']):
        if o.get('then'):                       # (first in a chain: its module made as -then's is)
            pic_first = True
        else:                                   # (the picture module: the show module, placed)
            o['picture'] = o['module']
            show = 'picmusic' if o.get('sid') else 'picture'
    what = {'none': 'nothing (the screen off)', 'picture': 'a picture', 'picmusic': 'a picture and music',
            'music': 'music'}
    if 'module' in given and show in ('none', 'music') and str(o['module']).lower() != 'none':
        raise Fail(f"-module goes with -show module (the default): -show {show} shows {what[show]}")
    pet = [k for k in ('scroll', 'scrollrow', 'scrollspeed', 'scrollcolours', 'counter', 'screen', 'font',
                       'screech') if o.get(k) is not None]
    if pet and show != 'module':
        raise Fail(f"-{pet[0]} goes with a PETSCII screen as -module (-show module): -show {show}"
                   f" shows {what[show]}")
    # ---- a chain (-then): the second module (chainb) shows after the first
    then = o.get('then')
    chainb, pic_then, b_scr = None, False, False
    if then:
        if show != 'module':
            raise Fail("-then follows a first module: -module FILE -then FILE" if show == 'none' else
                       f"-then goes with -module (-show module); -show {show} shows {what[show]}")
        import petscii as P
        b_scr = then.lower().endswith(P.ENDINGS)
        if b_scr and str(o['module']).lower().endswith(P.ENDINGS):
            raise Fail("-module and -then: two PETSCII screens, both PETSCII-Load in the same memory")
        chainb, pic_then = then_module(then, o, b_scr)
    if o.get('wait') and show not in ('picture', 'picmusic', 'module'):
        raise Fail(f"-wait goes with a picture (-module PICTURE: its prompt shows on the picture)"
                   f" or a module that keeps it; -show {show} shows {what[show]}")
    if o.get('wait') and o.get('waitgame'):
        raise Fail("-wait and -waitgame: one ending or the other (SPACE, or the end of a game)")
    if o.get('waitgame') and (show != 'module' or pic_first or pic_then):
        raise Fail("-waitgame goes with a game module (the end of a game); "
                   + ("a picture has no game: -wait for its SPACE OR FIRE" if pic_first or pic_then
                      else f"-show {show} shows {what[show]}"))
    if o.get('countdown') and show != 'module':
        raise Fail(f"-countdown goes with a module's status line (-show module); -show {show} shows"
                   f" {what[show]}")
    pic = None
    if show == 'none':
        game = None
    elif show == 'module' and pic_first:
        if pet and not b_scr:                       # (no PETSCII screen in this chain)
            raise Fail(f"-{pet[0]} goes with a PETSCII screen as -module or -then (a .pet, .petmate or .c"
                       " file)")
        import picturelm as PL
        try:
            parts = PL.make(o['module'], {'drawin': o.get('drawin')})
        except PL.Bad as ex:
            raise Fail(str(ex))
        game = find_game(o['module'], {}, parts=parts)
        game['label'] = f"{os.path.basename(o['module'])} ({picture_file(o['module'])}), as the picture module"
    elif show == 'module':
        game = find_game(o['module'], {} if b_scr else o, chain=bool(then))
    else:
        game = find_game(os.path.join(BUILD, 'modules', 'show.prg'))     # (the tool's own)
        if show in ('picture', 'picmusic'):
            pic = load_picture(o['picture'])
    if show == 'module':
        last = chainb or game                       # (the module showing when the program is in)
        gflags = last['data'][27] if len(last['data']) > 27 else 0
        for k, bit, what in (('wait', 4, "-wait (SPACE alone starts the program once it's in)"),
                             ('waitgame', 32, "-waitgame (the end of a game starts the program)"),
                             ('countdown', 8, "-countdown (its status line counting the blocks)")):
            if o.get(k) and not gflags & bit and not (pic_then and k == 'wait'):
                raise Fail(f"{last.get('path', 'the module')}: it doesn't keep {what}: its header's byte 27,"
                           f" bit {bit.bit_length() - 1} (MODULES.md)" +
                           ("; OZ GOLD counts blocks itself, a PETSCII screen with -counter ROW,COL"
                            if k == 'countdown' else ""))
    if o.get('drawin'):                         # a picture drawn in: its maker's option (+27 bit 6)
        if show in ('picture', 'picmusic'):     # (the tool's own picture module: set once
            pass                                # it is placed, below)
        elif pic_then and not pic_first:
            raise Fail("-drawin: a picture second in a chain (-then) loads while the first shows and appears"
                       " whole; -drawin goes with a picture as the first module")
        elif not (show == 'module' and len(game['data']) > 28 and game['data'][27] & 0x40):
            raise Fail("-drawin goes with a picture as the first module (-module PICTURE, or a .lm made to draw"
                       " in: picturelm.py -drawin, PICTURE-LM's line 9)"
                       + (f"; {os.path.basename(o['module'])} wasn't" if show == 'module' else ""))
    spr = None
    sopts = [k for k in ('spritepos', 'spritecolours', 'spritespeed', 'spritemc', 'spriteexpand') if o.get(k)]
    if sopts and not o.get('sprite'):
        raise Fail(f"-{sopts[0]} goes with -sprite FILE")
    if o.get('sprite') and not pic_then:            # (-then's picture: in its module's header)
        if pic_first:
            raise Fail("-sprite: in a chain the sprites go over -then's picture; over the first module's,"
                       " make the picture a .lm with its sprites (picturelm.py -sprite, PICTURE-LM)")
        if show not in ('picture', 'picmusic'):
            raise Fail(f"-sprite goes with a picture (-module PICTURE, or -then PICTURE): the"
                       " sprites show over it")
        spr = load_sprites(o['sprite'], o)
    if chainb:
        na, nb = (os.path.basename(g['path']) for g in (game, chainb))
        for ca in game['claims']:
            for cb in chainb['claims']:
                if overlap(ca, cb):
                    raise Fail(f"-then: {na} (${ca[0]:04X}-${ca[1] - 1:04X}) and {nb} (${cb[0]:04X}-${cb[1] - 1:04X})"
                               " share memory, and the second loads while the first runs. (A PETSCII screen"
                               " made into a .lm for a chain: petscii.py -chain puts it at $A000, clear of a"
                               " picture)")
        if not chainb['addr'] or len(chainb['data']) < 32:
            raise Fail(f"{nb}: not a module")
    # the screen is on (bad lines) while a game or a picture shows; music
    # alone keeps it off, and loads at screen-off speeds
    screen_on = game is not None and show != 'music'
    jit = (chainb or game)['jitter'] if screen_on else 0
    jit_a = game['jitter'] if chainb else None      # (the first's, while the second loads)
    if spr:
        jit += SPRITE_JITTER[spr['across']]
    # the measuring core's timestamp hook lengthens every interrupt
    pmin_boot = PMIN_BOOT + (MEASURE_COST if o.get('core') == 'core_measure' else 0)
    pmin_game = PMIN_GAME + (MEASURE_COST if o.get('core') == 'core_measure' else 0)
    smode, scol = stripe_mode(o.get('stripes'))
    stripes = stripe_table(o.get('stripes')) if smode == 'table' else None
    fx = stripe_fx(o.get('stripes')) if smode == 'fx' else None
    if o.get('cycle'):
        if smode in ('rainbow', 'table'):
            raise Fail(f"-cycle goes with an effect (-stripes {', '.join(FX)}) or one colour (-stripes black,"
                       f" -stripes 6): -stripes {o.get('stripes') or 'rainbow'} sets the border every pulse")
        if smode == 'block':
            raise Fail("-cycle and -stripes block: one or the other (block steps a colour a block)")
        if smode == 'flat':                     # one colour: the plain effect (no lines), on
            smode, fx = 'fx', plain_fx(scol)    # the effects core, which cycles it
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
    if fx:
        if o.get('core', 'core') != 'core':
            raise Fail("-stripes and -core: one or the other")
        o['core'] = 'core_fx'
        pmin_boot += FX.get(fx['name'], 0)
        pmin_game += FX.get(fx['name'], 0)
    if o.get('cycle'):                          # inc $d020 at each page: the worst path 3 more
        pmin_boot += CYCLE_COST
        pmin_game += CYCLE_COST
        if game:                                # the lines on through the module (the border
            o['showstripes'] = True             # is its otherwise: the colour would step unseen)
    if o.get('showstripes'):                # the loading lines through the show too
        if not game:
            raise Fail("-showstripes goes with a module or music (-module FILE, or -sid FILE alone)")
        if smode in ('flat', 'block'):
            raise Fail(f"-showstripes goes with loading lines: -stripes {o['stripes']} has none")
        for g in ([game] + ([chainb] if chainb else [])) if show == 'module' else []:
            if not (len(g['data']) > 27 and g['data'][27] & 1):
                raise Fail(f"{g.get('path', 'the module')}: it doesn't leave the border to the loader (its"
                           " header's byte 27: MODULES.md), so -showstripes (or -cycle, which keeps the lines"
                           " on) can't go with it")
    h_game = min(H_MAX, ceil4(speed_h(o['speed']) + jit))
    h_chain = min(H_MAX, ceil4(speed_h(o['speed']) + jit_a)) if chainb else None
    h_boot = max(H_MIN_BOOT, speed_h(o['bootspeed']))
    h_pre = max(H_MIN_BOOT, speed_h(o['speed']))    # (the music first: the screen off, as the tune alone)
    if screen_on:
        h_live, pmin_live = h_game, pmin_game
    else:
        h_live, pmin_live = max(H_MIN_BOOT, speed_h(o['speed'])), pmin_boot
    live_phase = {'none': 'program', 'module': 'program, second module running' if chainb else 'program, module running',
                  'picture': 'program, picture showing', 'picmusic': 'program, picture and music',
                  'music': 'program, music playing'}[show]

    maddr, mdata = load_prg(prg)
    mend = maddr + len(mdata)
    if mend > 0x10000:
        raise Fail("program runs past $ffff")
    if maddr == 0x0800 and mdata[:1] not in (b'', b'\x00'):
        raise Fail(f"{os.path.basename(prg)} has ${mdata[0]:02X} at $0800, which the start clears (BASIC's"
                   " zero byte before a program: the KERNAL's own start writes it): a program from $0801, or"
                   " a 0 there")
    for lo, hi, what in LOADER_RANGES:
        if overlap((maddr, mend), (lo, hi)):
            raise Fail(f"program ${maddr:04X}-${mend - 1:04X} overlaps {what} (${lo:04X}-${hi - 1:04X})")
    run = o['start'] is None
    if run and maddr != 0x0801:
        raise Fail(f"program loads at ${maddr:04X}, not $0801: give -start ADDR")

    # the name: -filename's (control codes in braces), else the file's
    # (its braces only characters)
    name = o['filename'] or os.path.splitext(os.path.basename(prg))[0].replace('{', '(').replace('}', ')')

    # ---- the music: a SID tune (-sid FILE); a part of the module,
    # loaded with it
    mus = None
    if 'autorun' in o.get('given', ()):
        raise Fail("-autorun is gone: a module or show ends as soon as the program is in, on its own"
                   " (a game mid-round too); -wait holds it for the player instead")
    if o.get('music') is not None:
        raise Fail("-music: the songs aren't built in any more: a tune is a file of its own, -sid FILE"
                   " (.sid or .slm; the demos: music/build/enigma.sid, slopload.sid, ozgold.sid)")
    if o.get('sid'):
        if show == 'none':
            raise Fail(f"-sid plays with a module or alone, not with -show none")
        import sidstrip as SS
        import sidfile as SF
        if o['sid'].lower().endswith('.slm') and o.get('song') is not None:
            raise Fail("-song picks a .sid's song; a .slm's was chosen when it was made")
        given = {k: o[k] for k in PRG_OPTS if o.get(k) is not None}
        try:
            prg = None                          # a PRG tune: called as -init, -play... say
            if not o['sid'].lower().endswith('.slm') and not SF.is_sid(o['sid']):
                if o.get('song') is not None:
                    raise Fail("-song is a .sid's: a PRG tune's song is init's A (-inita)")
                prg = SS.prg_opts(**given)
            elif given:
                raise Fail(f"-{sorted(given)[0]} is for a PRG tune: a .sid or .slm says it itself")
            m = SS.load_music(o['sid'], o.get('song'), prg=prg)
        except (SS.Refused, SF.Bad) as ex:
            raise Fail(str(ex))
        except OSError as ex:
            raise Fail(f"{o['sid']}: {ex}")
        for g in ([game] + ([chainb] if chainb else [])) if show == 'module' else []:
            why = SS.game_ok(m, [(a, c) for a, c in g['claims']], os.path.basename(g['path']))
            if why:
                raise Fail(f"{os.path.basename(o['sid'])} can't play beside {os.path.basename(g['path'])}:"
                           f" {why}. Alone (no -module), or with a picture, it can play")
        end_ = m['load'] + len(m['data'])
        mus = dict(addr=m['load'], data=m['data'], claims=[(m['load'], end_)] + list(m['workspace']),
                   relocs=m.get('relocs'), workspace=list(m['workspace']), songs=m.get('songs', 1),
                   init=m['init'], play=m['play'], per_pal=m['per_pal'], per_ntsc=m['per_ntsc'],
                   flags=2, song_a=m['song'] - 1, play_cycles=m['play_clk'], sid=m,
                   label=(f"{m['name']} (a PRG tune)" if m.get('prg') else
                          f"{m['name']} / {m['author']}" + (f", song {m['song']}" if m.get('songs', 1) > 1 else "")))
        # SlopLoad's own player: at $C000 a module's kit finds its stop and
        # flags, hands voice 3 to the module's effects and sets the NTSC
        # pitch; the show module too (the pitch)
        mus['player'] =(SS.slp_player(m['load'], m['data'], m['init'], m['play'])
                         and (show != 'module' or (chainb or game)['sfx'])
                         and (m['load'] == 0xc000 or m.get('relocs') is not None))
    elif o.get('song') is not None:
        raise Fail("-song picks a song of a -sid tune")
    elif any(o.get(k) is not None for k in PRG_OPTS):
        raise Fail(f"-{[k for k in PRG_OPTS if o.get(k) is not None][0]} goes with a PRG tune: -sid FILE")
    if show == 'music' and mus is None:
        raise Fail(f"-show {show} needs a tune: -sid FILE")
    if mus:
        # the tune's own bytes load: they keep out of the loader's memory;
        # its workspace is only written as it plays, once stage 1 is done
        # with $0200-$03ff (the exit code goes there after the music stops)
        busy = [(lo, hi, what) for lo, hi, what in LOADER_RANGES]
        busy_ws = [(0, 0x200, 'zero page and the stack'), (0x400, 0x800, 'the core'),
                   (0x2f9, 0x300, "the loader's exit ($02F9-$02FF: stage 1's last bytes, run at the end)"),
                   (0xfffa, 0x10000, "the CPU's vectors")]
        if o.get('then'):                           # (the switch runs every frame, the tune playing)
            busy_ws.append((CHAIN_AT, 0x400, "the chain's switch ($0380-$03FF, with -then)"))
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
    if mus and (mus.get('relocs') is not None or mus['player']) or showing:
        cands = [mus['addr']] if mus else [None]
        if mus and mus.get('relocs') is not None:
            low = mus['addr'] & 0xff
            cands += [p * 256 + low for p in range(0xff, 0x07, -1) if p * 256 + low != mus['addr']]
        prog = (maddr, mend)
        under = lambda rs: sum(max(0, min(hi, prog[1]) - max(lo, prog[0])) for lo, hi in rs)

        def plan_at(to):
            mc = []
            if mus:
                mc = [(to, to + len(mus['data']))] + mus['claims'][1:]
                if mc[0][1] > 0xfffa or any(overlap(mc[0], r) for r in
                                            [(0, 0x800), (0xd000, 0xe000), (0xfffa, 0x10000)]):
                    return None
                if to != mus['addr'] and any(overlap(mc[0], w) for w in mus['claims'][1:]):
                    return None
            if show == 'module':
                if any(overlap(r, c) for r in mc for c in game['claims'] + (chainb['claims'] if chainb else [])):
                    return None
                return (under(mc), to != mus['addr']), to, None, None
            try:
                b_, base_, sc = place_show(game['claim'] - game['addr'], mc, pic, prog, len(spr['data']) if spr else 0)
            except Fail:
                return None
            return (under(mc) + sc, mus is not None and to != mus['addr']), to, b_, base_
        best = plan_at(0xc000) if mus and mus['player'] else None
        if best:
            mus['flags'] = 1            # (SlopLoad's player where the kit has it)
        elif mus and mus.get('relocs') is None and show == 'module':
            best = ((0, False), mus['addr'], None, None)    # (where it is: game_ok said it fits)
        else:
            for to in cands:
                plan = plan_at(to)
                if plan is None:
                    continue
                if best is None or plan[0] < best[0]:
                    best = plan
                if plan[0] == (0, False):
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
        if pic and o.get('drawin'):             # (-drawin: the picture draws in)
            game['data'] = bytearray(game['data'])
            game['data'][27] |= 0x40
        if pic:
            pb = bank * 0x4000
            pic['parts'] = [(pb + 0x0c00, bytes(pic['screen']) + (SPRITE_TAIL if spr else b''), False)] + \
                ([(0xd800, pic['colour'], True)] if pic['colour'] is not None else []) + \
                [(pb + 0x2000, pic['bitmap'], False)] + \
                ([(pb + 0x3f40, spr['data'], False)] if spr else [])
            pic['bank'] = bank
        # what the loader may take of the cpu: what the music leaves
        if mus:
            # in integers, as SlopLoad 64 works it out (c64model.show_share):
            # play calls a frame (x 256, the most of PAL's and NTSC's) x the
            # longest call x 1.3, plus 900, out of an NTSC frame (less a
            # picture's bad lines)
            game['share'], calls256 = tune_share(mus, pic)
            if game['share'] < 25:
                raise Fail(f"the tune needs {mus['play_cycles']} cycles {calls256 / 256:.1f} times a frame:"
                           " too much to load beside it")
    ms = o.get('musicstart')
    if ms not in (None, 'before', 'first', 'second'):
        raise Fail(f"-musicstart {ms}: before (the default: before the modules load), first (with the first"
                   " module) or second (with the second, -then's)")
    if ms and not mus:
        raise Fail("-musicstart goes with a tune (-sid)")
    modules = show in ('module', 'picmusic')            # (a picture is a module too)
    if ms in ('first', 'second') and not modules:
        raise Fail(f"-musicstart {ms} goes with a module (-module): with none the tune starts as soon as it's in")
    late = ms == 'second'                               # (the tune with the chain's second)
    # the screech (a PETSCII screen's -screech) has the SID: it cuts a tune
    # off, so with a second module after it the tune waits for that one
    screech_first = bool(o.get('screech') and not b_scr)
    cued = bool(screech_first and mus and chainb and ms is None)
    if cued:
        late = True
    if late and not chainb:
        raise Fail("-musicstart second goes with a second module (-then) and a tune (-sid): the tune"
                   " starts when the second module does")
    # a picture module first draws in (its header's +27 bit 6, the show
    # module's): it starts, then its screen and bitmap load while it shows
    # (draw_split); the music, with it, then starts before them
    pictured = bool(game and len(game['data']) > 28 and game['data'][27] & 0x40
                    and (pic is not None or (show == 'module' and game['data'][15] != 0xff)))
    # the music first (the default with a module): the show module plays
    # it, the screen off, while the module's parts load, then hands over
    early, early_why = None, None
    if mus and modules and ms in (None, 'before') and not pictured and not late:
        if not (len(game['data']) > 27 and game['data'][27] & 0x10):
            early_why = (f"{os.path.basename(game.get('path', 'the module'))} doesn't keep a tune that is"
                         " playing (its header's byte 27, bit 4)")
        else:
            early = music_stage(mus, mus['claims'] + game['claims']
                                + ([(a, a + len(d)) for a, d, io in pic['parts'] if not io] if pic else []), song)
            if early is None:
                early_why = "no room for its player (the show module) beside the tune and the module"
        if early_why and ms == 'before':
            raise Fail(f"-musicstart before: {early_why}")
    for g in [game] + ([chainb] if chainb else []) if game else []:
        g['data'] = bytearray(g['data'])
        g['data'][14] = g['share']
        if late and g is game:                                  # (-musicstart second: the first
            g['data'][13] = 0xff                                # silent, its music fields as its
            continue                                            # file has them)
        g['data'][13] = 0xff if song is None else song         # header: the song (both of a chain's)
        if mus:
            g['data'][16:25] = struct.pack('<HHHHB', mus['init'], mus['play'], mus['per_pal'],
                                           mus['per_ntsc'], mus['flags'])
    if chainb:
        if len(game['data']) > 28 and game['data'][27] & 0x2c:     # the first: no -wait, -waitgame
            game['data'][28] &= ~0x2a & 255                         # or -countdown (the second ends
                                                                    # the load)
        if song is not None and not late and chainb['data'][27] & 0x10:   # the second: the tune
            chainb['data'][28] |= 0x10                                      # plays on
        if len(chainb['data']) > 28 and chainb['data'][27] & 0x2c:
            chainb['data'][28] = (chainb['data'][28] & ~0x2a & 255 | ending_bits(o))
    if game:
        if show in ('picture', 'picmusic', 'music'):
            game['data'][15] = 0xff if pic is None else pic['bg']   # header: the picture
            game['data'][25] = 3 - (pic['bank'] if pic else 3)     # $dd00's bits
            game['data'][28] = ((1 if mus else 0) | (2 if o.get('wait') else 0)
                                | (4 if pic and pic['colour'] is None else 0))      # the ending, hires
            if spr:
                game['data'][12] = jit                              # the jitter, with the sprites'
                game['data'][29:76] = spr['header']
        elif not chainb and len(game['data']) > 28 and game['data'][27] & 0x2c:   # a module that keeps -wait,
            game['data'][28] = (game['data'][28] & ~0x2a & 255        # -waitgame or -countdown:
                                | ending_bits(o))                     # those bits
        if early:                                       # the music first: the tune playing already
            game['data'][28] |= 0x10
        if pictured:                                    # it draws in: its picture loads after it
            game['data'][28] |= 0x40

    # ---- the main program: loaded while the game runs, except what
    # falls inside the game's memory (and the music's), loaded after it stops
    claims = []
    if game:                                    # (a chain: the second's; the first is gone by then)
        claims += (chainb or game).get('claims', [(game['addr'], game['claim'])])
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
    if later and (show != 'module' or pic_then) and o.get('wait'):
        lo, hi = later[0]
        raise Fail(f"-wait: the program's ${lo:04X}-${hi - 1:04X} loads where the show is (its picture, music or"
                   " code), after the show has gone: there is nothing left to wait on. Leave -wait out")
    total_live = sum(len(d) for _, d in live_blocks)
    if show == 'module' and len((chainb or game)['data']) > 26:
        # header +26: the disk blocks its counter counts down, those that
        # load while it runs (all the program's, unless some of it loads
        # into the module's memory after it); a chain's first: the
        # second's
        (chainb or game)['data'][26] = min(255, -(-(total_live + 2) // 254))
    if chainb:
        if not live_blocks:
            raise Fail(f"-then: all of the program loads into {os.path.basename(chainb['path'])}'s memory, after"
                       " it: it would show for no time at all")
        bparts = [(a, bytes(d)) for a, d in chainb.get('extra', [])] + [(chainb['addr'], bytes(chainb['data']))]
        nchain = sum(len(d) for _, d in bparts)
        game['data'][26] = min(255, -(-(nchain + 2) // 254))
        # the first's progress: full ($ff, a counter's 000) two pages before
        # the second is in (the progress moves on at whole pages only)
        neff = max(256, nchain - 512)

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
    put('pt_strs', 0x20 if o.get('showstripes') else 0)
    if stripes:
        for i, c in enumerate(stripes):
            put('stab', c, at=i)
    if fx:                                        # the effect, its stores' opcodes and places
        for i, b in enumerate(fx['code']):
            put('stripe', b, at=i)
        put('fxbc', fx['base'], at=1)
        put('fxa1', fx['a'][0], at=1)
        put('fxb1', fx['b'][0], at=1)
        put('fxa0', fx['a'][1], at=1)
        put('fxb0', fx['b'][1], at=1)
        put('fxs', (cs['stripe'] + fx['pa']) & 255, at=1)
        put('fxs2', (cs['stripe'] + fx['pb']) & 255, at=1)
    if o.get('cycle') and fx and fx['name'] == 'line':      # line: its border's colour one on a
        to = cs['stripe'] + fx['cat']                       # block (inc there, in stron: at each
        for i, b in enumerate((0xee, to & 255, to >> 8, 0xc9, 0x00)):    # good block's end)
            put('fxbc', b, at=i)
    elif o.get('cycle'):                          # the border a colour on each page
        for i, b in enumerate((0xee, 0x20, 0xd0)):
            put('cycle', b, at=i)
    if smode == 'flat':                           # (core_flat: no stripes; the border
        put('bflat', 0xa2)                        # the block's colour, ldx ld_seq, or
        put('bflat', scol, at=1)                  # one: ldx #colour)
    nomotor_auto = bool(o.get('nomotor') and later_blocks and not o['autorun'])
    if nomotor_auto and (o.get('wait') or o.get('waitgame')):
        lo, hi = later[0]
        w = '-wait' if o.get('wait') else '-waitgame'
        raise Fail(f"{w} and -nomotor: the program's ${lo:04X}-${hi - 1:04X} loads into the module's memory"
                   " after it, and with a player the C64 can't stop the module must end the moment the rest"
                   f" is in: there is nothing to wait on. Leave {w} out")
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
    shim = None
    if chainb:                                    # the switch (src/chain.asm), its frame and stop
        shim = chain_shim(game, chainb, step, cs)  # the core's; the progress the second's parts'
        put('pt_frame', shim['cframe'], 2)        # until then
        put('pt_stop', shim['cstop'], 2)
        put('pt_step', min(65535, round(16777216 / neff)), 2)

    def nchunks(parts):
        return sum(-(-len(p[1]) // o['blocksize']) for p in parts)
    if early:                                     # the music first: the stage is the core's
        boot_parts = [(mus['addr'], mus['data']), (early['addr'], early['data'])]   # module until the
        stage_parts = ([(a, d, io) for a, d, io in (pic['parts'] if pic else [])]  # first's parts are in
                       + [(a, d, False) for a, d in game.get('extra', [])] + [(game['addr'], game['data'], False)]
                       + ([(shim['addr'], shim['data'], False)] if shim else []))
        nseq = nchunks(boot_parts) + nchunks(stage_parts)
        if nseq > 255:
            raise Fail(f"the music first: {nseq} blocks before the module starts, 255 at most (-blocksize)")
        h0 = early['hand']                        # its hand-over: when, to what, the progress then
        early['data'][h0] = nseq
        early['data'][h0 + 1:h0 + 9] = struct.pack('<HHHH', game['init'], shim['cframe'] if shim else game['frame'],
                                                   shim['cstop'] if shim else game['stop'],
                                                   min(65535, round(16777216 / neff)) if shim else step)
        put('pt_init', early['init'], 2)
        put('pt_frame', early['frame'], 2)
        put('pt_stop', early['stop'], 2)
        put('pt_step', min(65535, round(16777216 / max(1, sum(len(p[1]) for p in stage_parts)))), 2)

    # ---- stage 1, in the KERNAL file
    ss = sym('stage1')
    block = bytearray(open(os.path.join(BUILD, 'stage1_block.bin'), 'rb').read())
    s1lo = ss['s1lo']
    block[ss['s1_pages'] - s1lo] = pages
    hpart = bytearray(open(os.path.join(BUILD, 'stage1_header.bin'), 'rb').read())
    if smode != 'rainbow':                        # stage 1: one colour, not the timer's
        block[ss['s1str'] - s1lo] = 0x2c
        hpart[ss['s1bc'] + 1 - 0x0351] = scol
        if scol == 2:                             # (its tape error red on red: pink, as
            hpart[ss['s1bad'] + 1 - 0x0351] = 10  # the core's on a red border)
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

    # the game (and its music), screen off; with the music first, the
    # tune and its player (the show module), then the game's parts while it
    # plays (the screen still off)
    if early:
        def split(parts):
            return [(a, bytes(p[1][a - p[0]:a - p[0] + o['blocksize']]), p[2] if len(p) > 2 else False)
                    for p in parts for a in range(p[0], p[0] + len(p[1]), o['blocksize'])]
        bb0, sb = split(boot_parts), split(stage_parts)
        for i, (a, d, io) in enumerate(bb0):
            emit(a, d, T.F_GAMEREADY if i == len(bb0) - 1 else 0, h_boot, pilot_next(), 0,
                 'music first', pmin_boot)
        done, ns = 0, sum(len(d) for _, d, _ in sb)
        for i, (a, d, io) in enumerate(sb):
            emit(a, d, T.F_MAINEND if i == len(sb) - 1 and not live_blocks and not chainb else 0,
                 h_pre, pilot_next(), min(255, (256 * done) // max(1, ns)), 'module, the music playing',
                 pmin_boot, early['share'] / 100, io=io)
            done += len(d)
        assert seq[0] == early['data'][early['hand']], (seq[0], early['data'][early['hand']])
    elif game:
        gb = []
        parts = [(a, d, False) for a, d in game.get('extra', [])] + [(game['addr'], game['data'], False)]
        if pic:
            parts = pic['parts'] + parts
        drawn = []
        if pictured:                            # its screen and bitmap after it starts
            parts, drawn = draw_split(parts, pic['bank'] if pic else 3 - game['data'][25])
        if mus:
            parts.insert(0, (mus['addr'], mus['data'], False))
        if shim:
            parts.append((shim['addr'], shim['data'], False))

        def blocks_of(parts):
            out = []
            for base, pdata, io in parts:
                a = base
                while a < base + len(pdata):
                    b = min(base + len(pdata), a + o['blocksize'])
                    out.append((a, bytes(pdata[a - base:b - base]), io))
                    a = b
            return out
        gb, db = blocks_of(parts), blocks_of(drawn)
        # its last block starts it; with none of the program loading while
        # it runs (all of it in its memory) that block ends the main load
        # too, or the core would never stop the tape (as SlopLoad 64 does)
        ends = 0 if live_blocks or chainb else T.F_MAINEND
        last = T.F_GAMEREADY | (0 if db else ends)
        for i, (a, d, io) in enumerate(gb):
            emit(a, d, last if i == len(gb) - 1 else 0, h_boot, pilot_next(), 0, 'module data',
                 pmin_boot, io=io)
        # a picture drawn in: its colours, screen and bitmap while it shows,
        # as the program loads then (its jitter, its share)
        jd = game['jitter'] + (SPRITE_JITTER[spr['across']] if spr else 0)
        for i, (a, d, io) in enumerate(db):
            emit(a, d, ends if i == len(db) - 1 else 0, min(H_MAX, ceil4(speed_h(o['speed']) + jd)),
                 pilot_next(), 0, 'picture drawing in', pmin_game, game['share'] / 100, io=io,
                 jit_b=max(8, jd))

    # a chain's second module, the first running: its last block the switch
    if chainb:
        bb = []
        for base, pdata in bparts:
            for a in range(base, base + len(pdata), o['blocksize']):
                bb.append((a, pdata[a - base:a - base + o['blocksize']]))
        done = 0
        for i, (a, d) in enumerate(bb):
            emit(a, d, T.F_CHAIN if i == len(bb) - 1 else 0, h_chain, pilot_next(), min(255, (256 * done) // neff),
                 'second module, first running', pmin_game, game['share'] / 100, jit_b=max(8, jit_a))
            done += len(d)

    # the program, game running
    done = 0
    for i, (a, d) in enumerate(live_blocks):
        fl = 0
        if i == len(live_blocks) - 1:
            fl = T.F_MAINEND | (0 if later_blocks else T.F_LAST)
        emit(a, d, fl, h_live, pilot_next(), (256 * done) // max(1, total_live),
             live_phase, pmin_live, (chainb or game)['share'] / 100 if game else None, jit_b=max(8, jit))
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
    what = {'module': 'the second module runs' if chainb else 'the module runs', 'picture': 'the picture shows',
            'picmusic': 'the picture and music play', 'music': 'the music plays'}.get(show)
    if game:
        nb_live = blocks(nlive + 2) if nlive else 0     # (as header +26: the load address with them)
        print(f"  {nb_live} blocks load while {what}"
              + (f", {blocks(len(mdata) + 2) - nb_live} after (they fall in its memory)" if nlater else ""))
        if early:
            print(f"  the music first: SlopLoad's player (the show module) ${early['addr']:04X}-"
                  f"${early['claim'] - 1:04X} starts the tune as soon as it's in, the screen off, while"
                  f" the {'picture' if pic else 'module'}'s parts load; then the {'picture' if pic else 'module'},"
                  " the tune playing on")
        elif early_why:
            print(f"  note: the music starts with the module, not before it: {early_why}")
        if cued:
            print("  the screech first, then the music: the tune starts with the second module"
                  " (as -musicstart second: the screech has the SID)")
        elif o.get('screech') and mus and not late:
            print("  note: the screech cuts the tune off when "
                  + ("the second module, the PETSCII screen, starts" if b_scr else "the PETSCII screen starts")
                  + " (it has the SID): the tune plays only before it"
                  + ("" if b_scr else "; with a second module after it (-then) the tune starts there"))
        if pictured:
            print("  the picture draws in: the module starts first (its code"
                  + (", the tune" if mus and not late else "") + (", its sprites" if spr or (not pic and
                                                                   game['data'][29]) else "")
                  + "), clears the bitmap and puts the screen on; then "
                  + ("colour RAM, " if pic and pic['colour'] is not None else "")
                  + "the screen and the bitmap load while it shows, the picture appearing as they come"
                  + (" (the tune playing)" if mus and not late else ""))
        if show == 'module':
            for g, which in ((game, 'first module' if chainb else 'module'),) + (((chainb, 'then module'),)
                                                                                  if chainb else ()):
                print(f"  {which} {g.get('label') or os.path.basename(g['path'])} ${g['addr']:04X}-${g['end'] - 1:04X}"
                      f" ({len(g['data'])} bytes), claims "
                      + ', '.join(f"${a:04X}-${b - 1:04X}" for a, b in g.get('claims', [(g['addr'], g['claim'])])))
            if chainb:
                print(f"  the second module's {game['data'][26]} blocks load while the first runs (a counter on the"
                      f" first counts them down to 000), then it shows; the switch ${shim['addr']:04X}-"
                      f"${shim['addr'] + len(shim['data']) - 1:04X}" +
                      (", the tune starting with the second (-musicstart second)" if late and song is not None
                       else ", the tune playing on through both" if song is not None else ""))
                if song is not None and not late and not chainb['data'][27] & 0x10:
                    print(f"  note: {os.path.basename(chainb['path'])} doesn't keep a chain's music (its header's"
                          " byte 27, bit 4): it starts the tune again")
            if o.get('countdown'):
                print("  its status line counts the blocks still to load (-countdown)")
            if o.get('wait') and not pic_then:
                print("  once the program is in, SPACE alone starts it (-wait): a game plays on, a loading"
                      " screen holds at 000")
            if o.get('waitgame'):
                print("  once the program is in, the end of the game starts it (-waitgame)")
            if pic_then and o.get('sprite'):
                sp = load_sprites(o['sprite'], o)
                print(f"  sprites: {sp['across']} at {sp['pos'][0]},{sp['pos'][1]} on the picture, in its module"
                      f" ({SPRITE_JITTER[sp['across']]} cycles of jitter more, in its header's)")
        else:
            print(f"  show module ${game['addr']:04X}-${game['end'] - 1:04X} ({len(game['data'])} bytes)")
        if pic:
            pb = pic['bank'] * 0x4000
            print(f"  picture: {os.path.basename(pic['path'])}, " +
                  (f"background {pic['bg']}" if pic['colour'] is not None else "hires") +
                  f"; VIC bank {pic['bank']}: screen ${pb + 0xc00:04X}-${pb + 0xfe7:04X},"
                  f" bitmap ${pb + 0x2000:04X}-${pb + 0x3f3f:04X}" +
                  (", colours in colour RAM" if pic['colour'] is not None else ""))
        if spr:
            ps = pic['bank'] * 0x4000 + 0x3f40
            print(f"  sprites: {spr['across']} at {spr['pos'][0]},{spr['pos'][1]} on the picture"
                  f" ({spr['size'][0]} x {spr['size'][1]} pixels{', multicolour' if spr['mc'] else ''}),"
                  f" their bytes ${ps:04X}-${ps + len(spr['data']) - 1:04X}, their pointers"
                  f" ${ps - 0x2f48:04X}-${ps - 0x2f47:04X} (the screen's part to ${ps - 0x2f41:04X}); " +
                  (f"colour {spr['colours'][0]}" if len(spr['colours']) == 1 else
                   f"flashing through {len(spr['colours'])} colours, {spr['speed']} frames each") +
                  f"; {SPRITE_JITTER[spr['across']]} cycles of jitter more")
        if (o.get('wait') or mus) and (show != 'module' or pic_then):    # (a picture's ending)
            print("  once the program is in: " + ', then '.join(
                (["PRESS SPACE OR FIRE across the picture's bottom row, and a press of either"]
                 if o.get('wait') else []) + (["the music fades out (about 2.6 s)"] if mus else []))
                  + ", then the program starts")
        if mus:
            ws = ''.join(f", workspace ${a:04X}-${b - 1:04X}" for a, b in mus['claims'][1:])
            hz = PAL_FPS * 312 * 64 / mus['per_pal']
            mv = f", moved from ${mus['moved_from']:04X}" if mus.get('moved_from') is not None else ""
            if mus['flags'] == 1:
                mv += ", SlopLoad's player: " + ("voice 3 for the module's effects" if show == 'module'
                                                 else "the NTSC pitch table")
            print(f"  music: \"{mus['label']}\" ${mus['addr']:04X}-${mus['addr'] + len(mus['data']) - 1:04X}"
                  f" ({len(mus['data'])} bytes{ws}{mv}), init ${mus['init']:04X}, play ${mus['play']:04X},"
                  f" {hz:.1f} play calls a second, up to"
                  f" {mus['play_cycles']} cycles each" + (f"; {len(mus['sid']['patched'])} stores taken out"
                                                            if mus['sid'] and mus['sid']['patched'] else ""))
    sets = lambda ss: ', '.join(f"{m}h={m * h}" for h, m in ss)
    if screen_on:
        capped = speed_h(o['speed']) + jit > H_MAX
        print(f"  speed {o['speed']}: margin at least +-{h_game} cycles while {what} ({speed_h(o['speed'])}"
              f" + {jit} of jitter: the screen is on" + (f"; {H_MAX} at most, the core's pilot window"
                                                          + (": below 0 is speed 0 here" if o['speed'] < 0 else "")
                                                          if capped else "")
              + f"); the loader takes at most {(chainb or game)['share']}% of"
              f" the CPU; shortest pulse per set {sets(game_sets(o['speed'], jit))}")
        if capped and spr:
            left = H_MAX - jit
            print(f"  the sprites can't make the pulses longer there: they take the tape's own margin, +-{left}"
                  f" left for the deck (speed {19 - left // 4}'s: a faster speed's, with no sprites)")
    if chainb:
        print(f"  speed {o['speed']}: margin at least +-{h_chain} cycles while the first module runs ("
              f"{speed_h(o['speed'])} + {jit_a} of jitter); the loader takes at most {game['share']}% of the CPU")
    if game and not screen_on:
        print(f"  speed {o['speed']}: margin at least +-{h_live} cycles while {what} (the screen is off);"
              f" the loader takes at most {game['share']}% of the CPU;"
              f" shortest pulse per set {sets(boot_sets(o['speed']))}")
    if stripes:
        print(f"  border stripes: {o['stripes']} (colours {', '.join(str(c) for c in sorted(set(stripes)))});"
              f" the colour lookup makes the shortest pulses {STRIPES_COST} cycles longer")
    elif fx and fx['name'] == 'plain':
        print(f"  border: colour {fx['base']}, no stripes (the effects core, for -cycle)")
    elif fx:
        print(f"  border stripes: {fx['name']} ({fx['says']}), from colour {fx['base']};"
              f" the shortest pulses {FX[fx['name']]} cycles longer")
    if o.get('cycle'):
        print(f"  border cycle: the border's colour one on with each page (256 bytes) loaded; the"
              f" shortest pulses {CYCLE_COST} cycles longer")
    if o.get('showstripes'):
        print("  the loading lines go on in the border while the module or show runs (it leaves the border"
              f" alone; a tape error turns it {'pink' if smode == 'flat' and scol == 2 else 'red'})")
    elif smode == 'flat':
        print(f"  border: colour {scol} all through, no stripes ({'pink' if scol == 2 else 'red'}"
              f" after a tape error{': red is its own colour' if scol == 2 else ''})")
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
    black, or a single number); ('block', 0) the border a colour a block;
    ('fx', its colour at the start) an effect (stripe_fx)"""
    if spec is None or str(spec).lower() == 'rainbow':
        return 'rainbow', None
    if str(spec).lower() == 'block':
        return 'block', 0
    f = stripe_fx(spec)
    if f:
        return 'fx', f['base']
    t = stripe_table(spec)
    if len(set(t)) == 1:
        return 'flat', t[0]
    return 'table', t[0]


def stripe_fx(spec):
    """-stripes NAME[:N][,B]: a loading line effect (FX): classic (lda
    $d020, eor #$00, inc $d020: the colour on one each pulse), thin (inc
    $d020, dec $d020: a thin line on a plain border, then eor #$00, its 2
    cycles after), mixed (inc $d020, eor #$00, inc $d020), and:N and ora:N
    (lda the byte coming in, and or ora #N, sta $d020), eor:N (lda $d020,
    eor #N, sta $d020: two colours by turns); B the border's colour to
    start from (and after a tape error), 0 if not given. None if spec
    isn't one. dict(name, n, base, code: its 8 bytes, pa, a: the first
    store's place and opcodes on and off, pb, b: the second's, says)"""
    t = str(spec or '').lower().strip()
    head, _, base = t.partition(',')
    name, _, val = head.partition(':')
    if name not in FX:
        return None

    def colour(v, what):
        try:
            c = int(v, 0)
        except ValueError:
            c = -1
        if not 0 <= c <= 15:
            raise Fail(f"-stripes {spec}: {what} is 0-15 (or $0-$f), not {v!r}")
        return c
    if name in FX_VALUE:
        if not val:
            raise Fail(f"-stripes {name}:N, N 0-15: the value to {name} with (such as {name}:5)" if name != 'line'
                       else "-stripes line:N,B: N the line's colour, B the border's (such as line:14,0)")
        n = colour(val.replace('$', '0x'), "the line's colour" if name == 'line' else 'its value')
    elif val:
        raise Fail(f"-stripes {name} takes no value (and, ora, eor and line do)")
    else:
        n = 0
    b = colour(base.replace('$', '0x'), "the border's colour") if base else 0
    lda_d020, inc_d020, sta_d020 = [0xad, 0x20, 0xd0], [0xee, 0x20, 0xd0], [0x8d, 0x20, 0xd0]
    on_off = lambda op: (op, 0xad if op == 0xad else 0x2c)      # (a store off: bit $d020)
    sr = 0x06                                   # ld_sr, src/abi.asm's: the byte coming in
    if name == 'classic':
        code, pa, pb, says = lda_d020 + [0x49, 0x00] + inc_d020, 0, 5, 'lda $d020 : eor #$00 : inc $d020'
    elif name == 'mixed':
        code, pa, pb, says = inc_d020 + [0x49, 0x00] + inc_d020, 0, 5, 'inc $d020 : eor #$00 : inc $d020'
    elif name == 'thin':
        code, pa, pb, says = inc_d020 + [0xce, 0x20, 0xd0, 0x49, 0x00], 0, 3, 'inc $d020 : dec $d020'
    elif name == 'eor':
        code, pa, pb, says = lda_d020 + [0x49, n] + sta_d020, 0, 5, f'lda $d020 : eor #${n:02x} : sta $d020'
    elif name == 'line':                        # (its value byte 1, the border's colour byte 6)
        code, pa, pb = [0xa9, n] + sta_d020 + [0xa9, b] + sta_d020, 2, 7
        says = f'lda #${n:02x} : sta $d020 : lda #${b:02x} : sta $d020'
    else:
        op = 0x29 if name == 'and' else 0x09
        code, pa, pb = [0xad, sr, 0x00, op, n] + sta_d020, 0, 5
        says = f'lda $0006 (the byte coming in) : {name} #${n:02x} : sta $d020'
    if len(code) == 8:                          # (the 10-byte slot: then cmp #$00, 2 cycles)
        code += [0xc9, 0x00]
    assert len(code) == FX_LEN
    return dict(name=name, n=n, base=b, code=code, pa=pa, a=on_off(code[pa]), pb=pb, b=on_off(code[pb]),
                says=says, vat=1 if name == 'line' else 4 if name in FX_VALUE else 0,
                cat=6 if name == 'line' else 0)


def plain_fx(colour):
    """-stripes with one colour and -cycle: the effects core with no
    lines at all (its 10 bytes jump past themselves: 3 cycles, less than
    the core's stx $d020), the border colour, stepped by -cycle; its
    stores, never run, are the bytes after the jump"""
    to = sym('core_fx')['stripe'] + FX_LEN
    code = [0x4c, to & 255, to >> 8, 0x2c, 0x20, 0xd0, 0x2c, 0x20, 0xd0, 0xea]
    return dict(name='plain', n=0, base=colour, code=code, pa=3, a=(0x2c, 0x2c), pb=6, b=(0x2c, 0x2c),
                says=f'no lines, colour {colour}', vat=0, cat=0)


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
SHOWS = ('module', 'none', 'music')       # (-show's: a picture module runs as 'picture' or 'picmusic')


def picture_file(spec):
    """-module FILE a picture in one of picturelm.py's formats (not a
    module's file: a .lm, a PETSCII screen, a module's .prg)? Its format's
    name, else None"""
    import petscii as P
    import picturelm as PL
    low = str(spec).lower()
    if low == 'none' or low.endswith(('.lm', '.lg') + P.ENDINGS) or not os.path.isfile(spec):
        return None
    if open(spec, 'rb').read(6)[2:6] == b'PLG1':
        return None
    try:
        return PL.read_picture(spec)['name']
    except PL.Bad:
        return None


def load_picture(path):
    """the picture for a picture module (-module PICTURE): one of
    picturelm.py's formats (Koala and its kind, Art Studio, Doodle and the
    rest). A hires picture has no colours of its own for colour RAM
    (colour None)"""
    import picturelm as PL
    try:
        pic = PL.read_picture(path)
    except PL.Bad as ex:
        raise Fail(str(ex))
    return dict(pic, kind='koala' if pic['colour'] is not None else 'hires', bank=3)


def load_sprites(path, o):
    """-sprite FILE and its options: the sprites (one or two, 64 bytes each,
    63 padded; a .prg's load address skipped) at the picture's bank +
    $3f40, and the show module's header bytes +29 to +75 for them:
    enabled, positions (the second beside the first), multicolour,
    expansion, the lines they cover, the flash. dict(data, across: how
    many share a raster line, header, pos, colours)"""
    try:
        d = open(path, 'rb').read()
    except OSError as ex:
        raise Fail(f"{path}: {ex}")
    sizes = {63: 1, 64: 1, 126: 2, 127: 2, 128: 2}
    if len(d) in sizes:
        body = d
    elif len(d) - 2 in sizes:
        body = d[2:]
    else:
        raise Fail(f"{path}: not one or two sprites ({len(d)} bytes: 64 a sprite, 63 will do, a .prg's"
                   " 2-byte load address before them)")
    n = sizes[len(body)]
    per = 63 if len(body) in (63, 126) else 64 if n == 1 or len(body) == 128 else None
    if per is None:
        raise Fail(f"{path}: {len(body)} bytes is neither two sprites of 63 nor two of 64")
    data = b''.join(body[i * per:i * per + 63] + bytes(1) for i in range(n))
    big = bool(o.get('spriteexpand'))
    w, h = (48 if big else 24) * n, 42 if big else 21

    def pair(k, v, lo, hi, what):
        try:
            a, b = (int(x, 0) for x in str(v).split(','))
        except ValueError:
            raise Fail(f"-{k} takes {what}")
        if not (lo[0] <= a <= hi[0] and lo[1] <= b <= hi[1]):
            raise Fail(f"-{k} {v}: {what}, {lo[0]}-{hi[0]} and {lo[1]}-{hi[1]}")
        return a, b
    if o.get('spritepos'):
        px, py = pair('spritepos', o['spritepos'], (0, 0), (320 - w, 200 - h),
                      "X,Y: the sprites' top left on the picture, inside it")
    else:
        px, py = 320 - w - 8, 200 - h - 8
    cols = [1]
    if o.get('spritecolours'):
        try:
            cols = [int(c, 0) for c in str(o['spritecolours']).split(',')]
        except ValueError:
            cols = []
        if not 1 <= len(cols) <= 32 or any(not 0 <= c <= 15 for c in cols):
            raise Fail("-spritecolours: 1 to 32 colours, each 0-15 (one: the sprites' colour; more: they flash"
                       " through them)")
    speed = 2
    if o.get('spritespeed') is not None:
        try:
            speed = int(o['spritespeed'], 0)
        except ValueError:
            speed = 0
        if not 1 <= speed <= 255:
            raise Fail("-spritespeed: frames a colour, 1-255")
    mc = (0, 0)
    if o.get('spritemc'):
        mc = pair('spritemc', o['spritemc'], (0, 0), (15, 15), "A,B: the multicolour sprites' shared colours")
    x0, y0 = px + 24, py + 50
    xs = [x0 + i * (48 if big else 24) for i in range(n)]
    mask = (1 << n) - 1
    head = bytearray(47)
    head[0] = mask                                          # +29 $d015
    for i in range(2):                                      # +30 x, y (sprite 1 at 0, 0 if none)
        head[1 + 2 * i] = xs[i] & 255 if i < n else 0
        head[2 + 2 * i] = y0 if i < n else 0
    head[5] = sum(1 << i for i in range(n) if xs[i] > 255)  # +34 $d010
    head[6] = mask if o.get('spritemc') else 0              # +35 $d01c
    head[7] = mask if big else 0                            # +36 $d01d
    head[8] = mask if big else 0                            # +37 $d017
    head[9], head[10] = mc                                  # +38 $d025, $d026
    head[11] = max(0, y0 - 2)                               # +40 their lines: the colours change
    head[12] = min(255, y0 + h + 2)                         # +41 outside them
    head[13] = len(cols)                                    # +42 the flash
    head[14] = speed                                        # +43
    head[15:15 + len(cols)] = bytes(cols)                   # +44
    return dict(data=data, across=n, header=bytes(head), pos=(px, py), size=(w, h), colours=cols,
                speed=speed, mc=bool(o.get('spritemc')), big=big)


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
    return dict(path=path, kind='koala', bg=bg, bitmap=bitmap, screen=screen, colour=colour, bank=3,
                parts=[(0xcc00, screen, False), (0xd800, colour, True), (0xe000, bitmap, False)])


PAL_FPS = 985248 / (63 * 312)


def tune_share(mus, pic=False):
    """what the loader may take of the CPU beside the tune's play calls
    (%), in integers as SlopLoad 64 works it out (c64model.show_share):
    play calls a frame (x 256, the most of PAL's and NTSC's) x the
    longest call x 1.3, plus 900, out of an NTSC frame (less a picture's
    bad lines)"""
    calls256 = max(312 * 64 * 256 // mus['per_pal'], 263 * 64 * 256 // mus['per_ntsc'])
    avail = 263 * 65 - (1000 if pic else 0)
    need = mus['play_cycles'] * calls256 * 13 // 2560 + 900
    return min(85, 100 * (avail - need) // avail if need < avail else 0), calls256


def music_stage(mus, avoid, song):
    """the music first (-musicstart before): SlopLoad's show module, the
    tune alone with the screen off, placed clear of the loader, the tune
    and avoid (the module's memory: its parts load while this plays), and
    its header set for the tune; dict as find_game's, or None (no room).
    The tool fills in its hand-over (+78 to +86) once the blocks are
    known"""
    import build as B
    import contextlib
    import io

    def asm(base):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return B.assemble(os.path.join(ROOT, 'modules', 'show', 'show.asm'), 'module_show_stage',
                              {'showbase': base})
    org, data, labs = asm(0xca00)
    mlen = labs['modend'] - org
    banned = [(lo, hi) for lo, hi, _ in LOADER_RANGES] + list(avoid) + [(0xd000, 0xe000)]
    for base in range(0xfe00 - mlen // 256 * 256, 0x07ff, -0x100):
        if base + mlen <= 0xfffa and not any(overlap((base, base + mlen), b) for b in banned):
            break
    else:
        return None
    org, data, labs = asm(base)
    d = bytearray(data)
    share, _ = tune_share(mus)
    d[13] = song
    d[14] = share
    d[15] = 0xff                                # (no picture)
    d[16:25] = struct.pack('<HHHHB', mus['init'], mus['play'], mus['per_pal'], mus['per_ntsc'], mus['flags'])
    d[28] = 0                                   # (no ending: it hands over)
    return dict(addr=org, data=d, end=org + len(d), claim=labs['modend'], init=labs['init'],
                frame=labs['frame'], stop=labs['stop'], claims=[(org, labs['modend'])], share=share,
                hand=labs['hnseq'] - org)


def place_show(mlen, music, pic, prog, sprites=0):
    """(vic bank, module address) for the show module and the picture
    (and its sprites' bytes: at bank + $3f40, and with them the screen's
    page to its end, their pointers in it): clear of the loader, the
    music and each other, with the least of the program under them (that
    part loads after the show)"""
    banned = [(lo, hi) for lo, hi, _ in LOADER_RANGES] + list(music) + [(0xd000, 0xe000)]
    def clear(r):
        return not any(overlap(r, b) for b in banned)
    def under(rs):
        return sum(max(0, min(hi, prog[1]) - max(lo, prog[0])) for lo, hi in rs)
    best = None
    for bank in ((3, 2, 1, 0) if pic else (3,)):
        b = bank * 0x4000
        prs = [(b + 0x0c00, b + (0x1000 if sprites else 0x0fe8)), (b + 0x2000, b + 0x3f40)] if pic else []
        if sprites:
            prs.append((b + 0x3f40, b + 0x3f40 + sprites))
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
                if os.path.isfile(path) and not os.path.getsize(path):
                    os.remove(path)                 # (the encoder's empty file)
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
    jit = o.get('jitter') or GAME_JITTER_DEFAULT    # (no module goes with -analyse: -jitter N, or the default)
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
        for k in ('sid', 'picture', 'show', 'start', 'filename'):
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
        po = dict(o, module='none', show='none', music=None, start=None,     # (the file's name: its
                  filename=None)                                             # braces only characters)
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
