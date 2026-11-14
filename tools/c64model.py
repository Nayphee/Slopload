#!/usr/bin/env python3
"""The C64 mastering tool's output, in Python: the reference its 6502 code
(c64/slopload64.asm) is checked against, pulse for pulse.

    c64model.py program.prg out.tap [-module NAME|FILE.lm|none] [-slm TUNE.slm]
                [-speed N] [-start HEX] [-name NAME] [-nostops] [-then FILE.lm]

What shows follows from the module and the tune, as on SlopLoad 64: the
module (with the tune, if any), the tune alone (the show module, the
screen off), or nothing. A picture is a module (PICTURE-LM's).

The same tape format as tools/slopload.py writes (any SlopLoad core reads
it), made the simpler way a C64 can, with the program read from disk a
block at a time:

- every turbo block is 2 bits a pulse (no prefix code, no precompensation),
  in one pulse set per speed: the quickest for random data that keeps the
  loader within the module's share of the CPU even if every pulse were the
  shortest (so no look at the data is needed), and the XOR key per block
  that makes it shortest;
- a block's pilot, sync and header are one run of 2-bit symbols in pulse
  set 4 (the pilot's length is 3 more than a multiple of 4, so the sync
  ends a byte), followed by its body (pad, data XOR key, check) in the
  block's set;
- each block is made ready (read from disk, keyed) with the tape motor
  stopped: its pilot is longer (PILOT_RESTART) for the motor to come up
  to speed, and a short trailer follows its check byte (class 0 pulses
  of its own set), so the motor's stop falls after the data.

Written without stops (stops=False: a .tap file, or a cassette from
expansion memory), the pilots are slopload.py's (PILOT_FIRST, then
PILOT_BLOCK; PILOT_RESUME after the module) and a block's check byte is
followed by the bridge, one byte $0F in its own set (pulses of class 0,
0, 3, 3), where the writer moves on to the next pilot during a long
pulse; only the last block has a trailer.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import taplib as T  # noqa: E402
import slopload as S  # noqa: E402

BUILD = os.path.join(os.path.dirname(HERE), 'build')
PILOT_CORE = 1.0                # after the KERNAL's load, as slopload.py
PILOT_RESTART = 0.5             # every block: the tool stops the motor to make each ready
PILOT_RESUME = 2.0              # after the loader stopped the motor (the module ended)
TRAILER = 0.1                   # pilot pulses after a block read from disk
BRIDGE = 0x0F                   # without stops: after the core and each block but the last
BLOCK = 4096
PMIN = 208                      # every pulse: the writer's edge loop needs 104 cycles a half
DIBIT_IRQ = 96                  # the core's interrupt per pulse, 2 bits a pulse, worst
GAMES = ('flappy', 'crossy')
TUNE_MAX = 4096                 # SlopLoad 64 takes tunes of 4 KB at most (the user's limit)
GAME_PLAY_MAX = 3700            # cycles a tune's play call may take beside a module (the
                                # heaviest tried: Uridium, 3,695, with Crossy-Load on NTSC)
SHOW_BASE = 0xca00              # the show module as SlopLoad 64 holds it (moved by its relocs)
SHOWS = ('none', 'module', 'music')
# SlopLoad 64's colours line (its palettes: the styles, then your own),
# its effect line, and the loading-line modes they make (its opt_lines:
# payload.asm's st_ numbers, in this order)
PALETTES = list(S.STRIPES) + ['your own']
EFFECTS = ['standard'] + list(S.FX) + ['block']
MODES = list(S.STRIPES) + ['block', 'one colour', 'effect', 'own']


def lines_for(colours='rainbow', effect='standard'):
    """SlopLoad 64's lnset: plan()'s lines, fcol, fx, fxb and own from its
    colours line (a style's name, or your own: a list of 1-12 colours) and
    its effect line (EFFECTS): standard draws the colours as stripes (your
    own of one: a plain border), an effect starts from their first colour
    (rainbow's: 0), block steps a colour a block"""
    own = list(colours) if isinstance(colours, (list, tuple)) else None
    first = own[0] if own else (S.STRIPES[colours] or [0])[0]
    if effect == 'block':
        return dict(lines=MODES.index('block'), own=own)
    if effect != 'standard':
        return dict(lines=MODES.index('effect'), fx=list(S.FX).index(effect), fxb=first, own=own)
    if own is None:
        return dict(lines=MODES.index(colours))
    if len(own) == 1:
        return dict(lines=MODES.index('one colour'), fcol=own[0], own=own)
    return dict(lines=MODES.index('own'), own=own)


def pilot_count(seconds, h):
    """pilot pulses: at least slopload's count, 3 more than a multiple of 4"""
    n = S.pilot_len(seconds, h)
    return n + (3 - n % 4) % 4


def trailer_count(h, m):
    """the trailer: class 0 pulses of the block's own set (zero bytes
    after its check, so the writer has no section to switch to), TRAILER
    seconds, a multiple of 4"""
    n = -(-int(TRAILER * T.PAL_HZ) // (m * h))
    return n + (-n % 4)


def best_set(h_min, pmin, share=None):
    """(h, m): the quickest for random data, (m + 3)h, with every pulse
    pmin or longer and, with a module, the loader's worst case (all the
    shortest pulses) within share percent"""
    floor = pmin if share is None else max(pmin, -(-DIBIT_IRQ * 100 // share))
    best = None
    h0 = max(h_min, S.ceil4(-(-pmin // 4)))
    for h in range(h0, S.H_MAX + 1, 4):
        for m in (2, 3, 4):
            if m * h >= floor and (best is None or (m + 3) * h < (best[1] + 3) * best[0]):
                best = (h, m)
    if best is None:
        raise S.Fail(f"no pulse set for h >= {h_min}")
    return best


def choose(d, h_min, share, pmin=PMIN):
    """phase 2: the quickest coding for block d, as slopload.py's
    choose_coding but with one key for 2 bits a pulse (each position's
    best): candidates (cycles, h, m, prefix, key) for every set with h from
    h_min and every pulse PMIN or longer, by cycles; with a module (share, a
    percentage) the first that keeps the loader within it in every frame's
    worth of tape. Returns (h, m, prefix, key, body classes)."""
    chk = T.xor_all(d)
    sets = S.block_sets(h_min, pmin)
    pkey = T.best_prefix_key(d)
    pcl = T.prefix_classes([0x00] + [b ^ pkey for b in d] + [chk])
    key = T.best_key(d)
    body = bytes([0xff]) + bytes(b ^ key for b in d) + bytes([chk])
    sums = [S.DIBIT_SUM[b] for b in body]
    np_, sp, sk = len(pcl), sum(pcl), sum(sums)
    cands = []
    for h, m in sets:
        cands.append((h * (m * np_ + 2 * sp), h, m, True, pkey))
        cands.append((h * (4 * m * len(body) + 2 * sk), h, m, False, key))
    cands.sort()
    for cyc, h, m, pfx, k in cands:
        if share is not None:
            if pfx:
                costs, extra = S.IRQ_COST['prefix']
                bits, nb, cost = (1, 2, 3, 3), 0, []
                for c in pcl:
                    cost.append(costs[c] + (extra if (nb + bits[c]) // 8 > nb // 8 else 0))
                    nb += bits[c]
                if 100 * sum(cost) > share * cyc:
                    continue
                if not share_ok([(m + 2 * c) * h for c in pcl], cost, share):
                    continue
            else:
                costs, extra = S.IRQ_COST['dibit']
                per = 4 * max(costs) + extra
                if 100 * per * len(body) > share * cyc:
                    continue
                if not share_ok([(4 * m + 2 * x) * h for x in sums], [per] * len(body), share):
                    continue
        if pfx:
            return h, m, True, k, pcl + [0] * (-len(pcl) % 4)
        return h, m, False, k, T.turbo_classes(body)
    raise S.Fail("no coding keeps the loader within the module's share")


def share_ok(cyc, cost, share, window=S.SHARE_WINDOW):
    """slopload.max_share(cyc, cost) <= share percent, in integers: every
    run of pulses (or bytes) from each one on until window cycles or more
    (or the whole, if shorter) has 100 x cost <= share x cycles"""
    tc = sum(cyc)
    if tc <= window:
        return 100 * sum(cost) <= share * tc
    j = sc = sk = 0
    n = len(cyc)
    for i in range(n):
        while j < n and sc < window:
            sc += cyc[j]
            sk += cost[j]
            j += 1
        if sc < window:
            break
        if 100 * sk > share * sc:
            return False
        sc -= cyc[i]
        sk -= cost[i]
    return True


class Refused(S.Fail):
    """SlopLoad 64 says no: the reason, as it prints it"""


def load_lm(spec):
    """a module in one file (MODULES.md: each part's address, length
    and bytes, the main part first): its parts, header and claims"""
    path = spec if os.path.exists(spec) else os.path.join(BUILD, 'modules', spec + '.lm')
    d = open(path, 'rb').read()
    parts, i = [], 0
    while i + 4 <= len(d):
        a, n = d[i] | d[i + 1] << 8, d[i + 2] | d[i + 3] << 8
        if i + 4 + n > len(d):
            raise Refused(f"{os.path.basename(path)}: a part runs past the file's end")
        parts.append((a, bytes(d[i + 4:i + 4 + n])))
        i += 4 + n
    if not parts or parts[0][1][:4] != b'PLG1' or len(parts[0][1]) < 32:
        raise Refused(f"{os.path.basename(path)}: not a module (no PLG1)")
    a, m = parts[0]
    w = lambda o: m[o] | m[o + 1] << 8
    claim = max(a + len(m), w(10) or 0x10000)
    jit = m[12] or S.GAME_JITTER_DEFAULT
    if jit > S.GAME_JITTER_MAX:
        raise Refused(f"its jitter is {jit}: 64 at most")
    claims = [(a, claim)] + [(pa, pa + len(pd)) for pa, pd in parts[1:]]
    for lo, hi in claims:
        for blo, bhi in ((0, 0x800), (0xfffa, 0x10000)):
            if lo < bhi and hi > blo:
                raise Refused(f"it needs ${lo:04X}-${hi - 1:04X}, the loader's memory")
    return dict(path=path, parts=parts, addr=a, init=w(4), frame=w(6), stop=w(8), claims=claims,
                jitter=jit, share=m[14] or S.GAME_SHARE_DEFAULT)


def slm_music(path):
    """a prepared tune (.slm, version 2: its longest play call in real
    cycles) as SlopLoad 64 holds it"""
    import struct
    d = open(path, 'rb').read()
    if d[:4] != b'SLM2':
        raise Refused(f"{os.path.basename(path)}: not a version 2 .slm")
    load, n, init, play, song, flags, pp, pn, pc = struct.unpack('<HHHHBBHHH', d[4:20])
    zp = {a for a in range(256) if d[20 + (a >> 3)] >> (a & 7) & 1}
    k = d[52]
    ws = [struct.unpack('<HH', d[53 + 4 * i:57 + 4 * i]) for i in range(k)]
    o = 53 + 4 * k
    nr = struct.unpack('<H', d[o:o + 2])[0]
    relocs = list(struct.unpack(f'<{nr}H', d[o + 2:o + 2 + 2 * nr]))
    o += 2 + 2 * nr + 96
    movable = bool(flags & 8) and 0 < nr < 512
    return dict(load=load, data=d[o:o + n], init=init, play=play, song=song, per_pal=pp, per_ntsc=pn,
                cyc=pc, zp=zp, ws=[tuple(w) for w in ws], relocs=relocs if movable else None)


DRAW_CUTS = (0xcc00, 0xd000, 0xe000, 0xff40)     # a picture drawn in: its parts cut there (bank 3),
DRAW_KEPT = ((0xcc00, 0xd000), (0xe000, 0xff40))    # these pieces kept back: its screen and bitmap


def show_module():
    """the show module at SHOW_BASE and the offsets of its address high
    bytes (assembled again a page on: the bytes one more), as SlopLoad 64
    has it: up to its drawcode (a picture's drawing in, which SlopLoad
    64's own never does), its claim the whole module's"""
    import build as B
    import contextlib
    import io
    out = []
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        for base in (SHOW_BASE, SHOW_BASE + 0x100):
            org, data, labs = B.assemble(os.path.join(os.path.dirname(HERE), 'modules', 'show', 'show.asm'),
                                         'c64_show', {'showbase': base})
            out.append((data, labs))
    (d0, l0), (d1, _) = out
    cut = l0['drawcode'] - SHOW_BASE            # (a picture's drawing in: never SlopLoad 64's)
    relocs = [i for i in range(cut) if d0[i] != d1[i]]
    assert all((d1[i] - d0[i]) & 255 == 1 for i in relocs), "the show module doesn't move by its high bytes"
    return dict(data=bytes(d0[:cut]), relocs=relocs, claim=l0['modend'] - SHOW_BASE, hand=l0['hnseq'] - SHOW_BASE)


def moved(m, at):
    """a prepared tune moved to at (its relocs: high bytes to add the move to)"""
    dp = (at - m['load']) >> 8
    d = bytearray(m['data'])
    for o in m['relocs']:
        d[o] = (d[o] + dp) & 255
    return dict(m, load=at, data=bytes(d), init=(m['init'] + dp * 256) & 0xffff,
                play=(m['play'] + dp * 256) & 0xffff, moved_from=m['load'])


def overlaps(r, rs):
    return any(r[0] < hi and r[1] > lo for lo, hi in rs)


def under(rs, prog):
    """bytes of the program under the ranges rs"""
    return sum(max(0, min(hi, prog[1]) - max(lo, prog[0])) for lo, hi in rs)


def place_show(mlen, music, prog):
    """the show module's address (VIC bank 3), as slopload.py's place_show
    with no picture: clear of the loader, the music and $D000-$DFFF, with
    the least of the program under it; None if there's no room"""
    banned = [(0, 0x800), (0xfffa, 0x10000)] + list(music) + [(0xd000, 0xe000)]
    best = None
    for base in [0xca00] + list(range(0xfe00 - mlen // 256 * 256, 0x07ff, -0x100)):
        mr = (base, base + mlen)
        if overlaps(mr, banned):
            continue
        score = under([mr], prog)
        if best is None or score < best[0]:
            best = (score, base)
        if score == 0:
            break
    return None if best is None else best[1]


def music_ranges(m):
    return [(m['load'], m['load'] + len(m['data']))] + list(m['ws'])


def tune_checks(m):
    """what any tune must keep to (both modes); the reason, or None"""
    end = m['load'] + len(m['data'])
    if len(m['data']) > TUNE_MAX:
        return f"it is {len(m['data'])} bytes: 4096 at most"
    if overlaps((m['load'], end), [(0, 0x800), (0xd000, 0xe000), (0xfffa, 0x10000)]):
        return f"it sits at ${m['load']:04X}-${end - 1:04X}: the loader's memory or I/O"
    for lo, hi in m['ws']:
        if overlaps((lo, hi), [(0, 0x200), (0x400, 0x800), (0xfffa, 0x10000)]):
            return f"it writes ${lo:04X}-${hi - 1:04X}, the loader's memory"
    return None


def game_tune(m, g):
    """beside a module: the reason it can't play, or None (where it
    sits is placement's business)"""
    z = sorted(a for a in m['zp'] if 0x10 <= a < 0x90 and not 0x70 <= a < 0x80)
    if z:
        return f"it uses zero page ${z[0]:02X}, the module's (a tune may use $70-$7F)"
    if abs(m['per_pal'] - 19968) > 19968 // 50:
        return "it doesn't play once a frame, as a module plays it"
    if m['cyc'] > GAME_PLAY_MAX:
        return f"its play call takes up to {m['cyc']} cycles: {GAME_PLAY_MAX} at most beside a module"
    return None


def place_tune(m, ok, sfx=False):
    """with sfx, a tune in SlopLoad's own player at $C000 if ok there
    (flags 1: the player's stop and flags where the kit has them, voice 3
    for a module's effects, the NTSC pitch); else the tune where it is if
    ok(that), else (a prepared tune that can move) the highest page, at
    the same offset, that is ok (flags 2); None if none"""
    import sidstrip as SS
    if sfx and SS.slp_player(m['load'], m['data'], m['init'], m['play']):
        mm = None
        if m['load'] == 0xc000:
            mm = m
        elif m.get('relocs') is not None:
            if not overlaps((0xc000, 0xc000 + len(m['data'])), [(0, 0x800), (0xd000, 0xe000)] + list(m['ws'])):
                mm = moved(m, 0xc000)
        if mm is not None and ok(mm):
            return dict(mm, flags=1)
    m = dict(m, flags=2)
    if ok(m):
        return m
    if m.get('relocs') is None:
        return None
    lo = m['load'] & 255
    for p in range(0xff, 0x07, -1):
        at = p * 256 + lo
        if at == m['load']:
            continue
        r = (at, at + len(m['data']))
        if r[1] > 0xfffa or overlaps(r, [(0, 0x800), (0xd000, 0xe000)] + list(m['ws'])):
            continue
        mm = moved(m, at)
        if ok(mm):
            return mm
    return None


def show_share(m):
    """the loader's share beside a show's music, in integers: the music's
    play calls a frame (the most of PAL's and NTSC's) x its longest call
    x 1.3, plus 900, out of an NTSC frame; 85 at most, 25 at least"""
    calls256 = max(19968 * 256 // m['per_pal'], 16832 * 256 // m['per_ntsc'])
    need = m['cyc'] * calls256 * 13 // 2560 + 900
    avail = 17095
    share = 100 * (avail - need) // avail if need < avail else 0
    if share < 25:
        raise Refused(f"its play calls take too long to load beside it ({m['cyc']} cycles)")
    return min(85, share)


def setup(show, game=None, music=None, prog=(0x0801, 0x0802), wait=False, fade=False, count=False, then=None,
          waitgame=False, mstart='before'):
    """what SlopLoad 64 works out before the blocks: the module (a game,
    or the show module placed), its header patched, the parts in tape
    order (addr, data, io), the claims, the share and the jitter.
    music: the tune as SlopLoad 64 holds it: load, data (patched), init,
    play, song (A for init), per_pal, per_ntsc, cyc, zp, ws, relocs (a
    prepared tune that can move, else None). fade: kept for old callers
    (the tune alone always fades out, as every module's tune); with a
    module, wait, waitgame and count (-wait, -waitgame, -countdown) where
    it keeps them (its header's +27 bits 2, 5, 3: SlopLoad 64 asks only
    then).
    then: a second module after the first (a chain: slopload.py's -then),
    its parts read from its file as the tape is written; wait and count
    are its own. mstart: when the tune starts with a module (SlopLoad 64's
    opt_mst, slopload.py's -musicstart): 'before' (the default) the show
    module plays it while the module's parts load, then hands over to it
    (as SlopLoad 64's mfirst: when the module keeps a tune playing on, its
    file is under 10 KB, the show module's room in SlopLoad 64's high
    pool, and there's a place for it and a share of 25% or more beside the
    tune; else as 'first'); 'first' the first module starts it; 'second' a
    chain's second does (the first's song $ff, its music fields as its
    file has them)"""
    if show not in SHOWS:
        raise Refused(f"no show '{show}'")
    out = dict(show=show, module=None, parts=[], claims=[], share=None, jit=0, song=None, music=None)
    if show == 'none':
        return out
    if show == 'music' and music is None:
        raise Refused(f"this show needs music")
    m = music
    if m is not None:
        why = tune_checks(m)
        if why:
            raise Refused(why)
    if then is not None and show != 'module':
        raise Refused("a second module goes with a module")
    if show == 'module':
        g = load_lm(game)
        b = load_lm(then) if then is not None else None
        if b and any(overlaps(r, b['claims']) for r in g['claims']):
            raise Refused("the two modules share memory")
        both = g['claims'] + (b['claims'] if b else [])
        if m is not None:
            for x in [g] + ([b] if b else []):
                why = game_tune(m, x)
                if why:
                    raise Refused(why)
            hx = (b or g)['parts'][0][1]                # (a chain: the second's effects)
            sfx = bool(hx[27] & 2) if len(hx) > 27 else False
            m = place_tune(m, lambda t: not any(overlaps(r, both) for r in music_ranges(t)), sfx)
            if m is None:
                raise Refused("it sits in the module's memory")
        head = bytearray(g['parts'][0][1])
        head[13] = 0xff if m is None else m['song']
        head[14] = g['share']
        mf = None if m is None else bytes([m['init'] & 255, m['init'] >> 8, m['play'] & 255, m['play'] >> 8,
                                           m['per_pal'] & 255, m['per_pal'] >> 8, m['per_ntsc'] & 255,
                                           m['per_ntsc'] >> 8, m['flags']])
        late = bool(mstart == 'second' and b and m is not None)
        # a picture that draws in (SlopLoad 64's drawq): the show module as a
        # picture (+27 bit 6, +15 not $ff) in bank 3 (+25 0); it starts the
        # tune itself, before its picture loads (no player first)
        drawin = bool(len(head) > 28 and head[27] & 0x40 and head[15] != 0xff and head[25] == 0)
        stage = None                        # the music first: the show module, where SlopLoad 64's
        if (m is not None and mstart == 'before' and len(head) > 27 and head[27] & 0x10    # mfirst
                and os.path.getsize(g['path']) < 0x2800 and not drawin):
            sm = show_module()
            base = place_show(sm['claim'], music_ranges(m) + both, prog)
            try:
                sshare = show_share(m) if base is not None else None
            except Refused:
                sshare = None
            if sshare is not None:
                d = bytearray(sm['data'])
                for o in sm['relocs']:
                    d[o] = (d[o] + ((base - SHOW_BASE) >> 8)) & 255
                d[13] = m['song']
                d[14] = sshare
                d[15] = 0xff
                d[16:25] = mf
                d[25] = 0
                d[28] = 0                   # (no ending: it hands over)
                w = lambda o: d[o] | d[o + 1] << 8
                stage = dict(addr=base, data=d, init=w(4), frame=w(6), stop=w(8), share=sshare,
                             hand=sm['hand'])
        if late:                            # (the first silent: its fields as its file has them)
            head[13] = 0xff
        elif mf:
            head[16:25] = mf
        head[26] = 0                    # (+26: plan(), from what loads while it runs)
        kept = head[27] if len(head) > 27 else 0
        if len(head) > 28 and kept & 0x2c:  # +28: the tool's options it keeps (bits 1, 5, 3;
            head[28] = head[28] & 0xd5 | (0 if b else ending_bits(kept, wait, waitgame, count))
        if stage:                           # (+28 bit 4: the tune playing already)
            head[28] |= 0x10
        if drawin:                          # (+28 bit 6: its screen and bitmap after it starts)
            head[28] |= 0x40
        gparts = [(g['addr'], bytes(head))] + g['parts'][1:]           # (the rest as the file has
                                                                        # them; a chain's first: none)
        hd = g['parts'][0][1]
        mod = dict(addr=g['addr'], init=g['init'], frame=g['frame'], stop=g['stop'], claims=both,
                   jitter=g['jitter'], share=g['share'], bord=len(hd) > 27 and hd[27] & 1, stage=stage,
                   drawin=drawin)
        parts = [(a, d, False) for a, d in gparts[1:]] + [(g['addr'], bytes(head), False)]
        if b:                               # the second: the song and the music's fields as the
            bh = bytearray(b['parts'][0][1])    # first's (not +15: a picture's background), +26
            bh[13] = 0xff if m is None else m['song']   # plan()'s, its options its own, and the
            if m is not None:                   # tune playing on (+28 bit 4) where it keeps it
                bh[16:25] = mf                  # (late: the second starts it)
            bh[14] = b['share']
            bh[26] = 0
            bk = bh[27]
            if bk & 0x2c:
                bh[28] = bh[28] & 0xd5 | ending_bits(bk, wait, waitgame, count)
            if m is not None and bk & 0x10 and not late:
                bh[28] |= 0x10
            bd = b['parts'][0][1]
            mod.update(chain=dict(b=b, parts=[(b['addr'], bytes(bh))] + b['parts'][1:]),
                       cjit=g['jitter'], cshare=g['share'], jitter=b['jitter'], share=b['share'],
                       bord=mod['bord'] and len(bd) > 27 and bd[27] & 1)
    else:
        sm = show_module()
        mlen = sm['claim']
        place = []

        def ok(t):
            r = place_show(mlen, music_ranges(t), prog)
            place[:] = [r] if r else []
            return r is not None
        m = place_tune(m, ok, True)
        if m is None:
            raise Refused("no room for the music and the show module together")
        base = place[0]
        d = bytearray(sm['data'])
        for o in sm['relocs']:
            d[o] = (d[o] + ((base - SHOW_BASE) >> 8)) & 255
        share = show_share(m)
        d[13] = m['song']
        d[14] = share
        d[15] = 0xff
        d[16:25] = bytes([m['init'] & 255, m['init'] >> 8, m['play'] & 255, m['play'] >> 8,
                          m['per_pal'] & 255, m['per_pal'] >> 8, m['per_ntsc'] & 255,
                          m['per_ntsc'] >> 8, m['flags']])
        d[25] = 0
        d[28] = 1                       # (the fade: always)
        w = lambda o: d[o] | d[o + 1] << 8
        mod = dict(addr=base, init=w(4), frame=w(6), stop=w(8), claims=[(base, base + sm['claim'])],
                   jitter=d[12], share=share, ending=d[28] & 3)
        parts = [(base, bytes(d), False)]
    if m is not None:
        parts.insert(0, (m['load'], m['data'], False))
    if mod.get('stage'):                         # the music first: its player, the boot's last part
        parts.insert(1, (mod['stage']['addr'], mod['stage']['data'], False))
    claims = list(mod['claims'])                 # the program's bytes there load after the show
    if m is not None:
        claims += music_ranges(m)
    screen_on = show != 'music'
    out.update(module=mod, parts=parts, claims=claims, share=mod['share'],
               jit=mod['jitter'] if screen_on else 0, screen_on=screen_on,
               song=None if m is None else m['song'], music=m)
    return out


def ending_bits(kept, wait, waitgame, count):
    """a module's +28 bits for the tool's options it keeps (its +27,
    kept): bit 1 -wait (SPACE: +27 bit 2), bit 5 -waitgame (a game's end:
    +27 bit 5), bit 3 -countdown (+27 bit 3)"""
    return ((2 if wait and kept & 4 else 0) | (0x20 if waitgame and kept & 0x20 else 0)
            | (8 if count and kept & 8 else 0))


def plan(prg_addr, prg, show='none', game=None, music=None, speed=0, start=None,
         autorun=False, name=None, phase=2, stops=True, lines=0, fcol=6, fx=0, fxn=5, fxb=0, own=None,
         showl=False, cycle=False, wait=False, fade=False, count=False, then=None, waitgame=False,
         mstart='before'):
    """the blocks, in tape order: dicts with addr, data, flags, h, m, pilot
    (pulses), trailer (pulses), bridge, prog, seq; and the core image and
    stage 1. show, game (the module), music: as setup(). stops: the motor
    stopped before each block (a cassette written a block at a time), else
    written in one go. lines: the loading lines' mode, by its number in
    MODES (SlopLoad 64's opt_lines, from its colours and effect lines:
    lines_for() gives it and the rest): slopload.py's STRIPES, then block,
    then one colour: fcol, then effect: slopload.py's FX by its place fx,
    its value fxn, the colour it starts from fxb, then your own colours:
    own, a list (as -stripes 6,14,3). showl: the lines on
    through the module or show (slopload.py's -showstripes). cycle: the
    border a colour on each page (-cycle: an effect, or one colour, black
    included, which runs as the plain effect; with a module or show it
    keeps the lines on through it). wait, waitgame, fade: the show's
    ending (setup's). then: a
    chain's second module (setup's): its blocks after the first's, in its
    file's order, at the first's speed and share, the last flagged
    f_chain; the switch (src/chain.asm) the first's last part"""
    modes = MODES
    spec = ','.join(str(c) for c in own) if modes[lines] == 'own' else modes[lines]
    if modes[lines] == 'effect':
        fname = list(S.FX)[fx]
        fxs = S.stripe_fx(fname + (f':{fxn}' if fname in S.FX_VALUE else '') + f',{fxb}')
        smode, scol = 'fx', fxb
    else:
        fxs = None
        smode, scol = ('flat', fcol) if modes[lines] == 'one colour' else S.stripe_mode(spec)
    if cycle:
        if smode == 'flat' and modes[lines] != 'block':
            fxs, smode = S.plain_fx(scol), 'fx'
        elif smode != 'fx':
            raise Refused("the border cycle goes with an effect or one colour")
    end = prg_addr + len(prg)
    su = setup(show, game, music, (prg_addr, end), wait, fade, count, then, waitgame, mstart)
    g = su['module']
    jit = su['jit']
    ch = g.get('chain') if g else None
    h_boot = max(S.H_MIN_BOOT, S.speed_h(speed))
    boot = best_set(h_boot, PMIN)
    if g and su['screen_on']:
        h_live = min(S.H_MAX, S.ceil4(S.speed_h(speed) + jit))
    else:
        h_live = h_boot
    # a style of stripes: the colour lookup makes the interrupt 4 cycles
    # longer, so with the screen on every pulse 212 cycles or more (as
    # slopload.py's -stripes). One colour or a colour a block costs nothing
    pmin_live = PMIN + (S.STRIPES_COST if smode == 'table' and su.get('screen_on') else 0)
    if fxs and su.get('screen_on'):              # (an effect: 6-10 cycles more; -cycle 3)
        pmin_live = PMIN + S.FX.get(fxs['name'], 0) + (S.CYCLE_COST if cycle else 0)
    strs = bool((showl or cycle) and g and smode not in ('flat', 'block'))   # (the cycle: the lines on)
    if strs and not g.get('bord', True):         # (the show module leaves it)
        raise Refused("the module keeps its border: the lines can't go on through it")
    live = best_set(h_live, pmin_live, su['share']) if g else boot
    stage_set = best_set(h_boot, PMIN, g['stage']['share']) if g and g.get('stage') else None
    if ch:                                       # the second's blocks: the first's speed
        h_chain = min(S.H_MAX, S.ceil4(S.speed_h(speed) + g['cjit']))
        live_c = best_set(h_chain, pmin_live, g['cshare'])
    claims = su['claims']
    parts = su['parts']                          # the module's blocks: (addr, data, io)
    live_r, later_r = [(prg_addr, end)], []
    for c in claims:
        nl = []
        for rng in live_r:
            out, inside = S.subtract(rng, c)
            nl += out
            if inside:
                later_r.append(inside)
        live_r = nl
    live_r.sort()
    later_r.sort()

    def chunks(rs, data, base):
        out = []
        for lo, hi in rs:
            a = lo
            while a < hi:
                b = min(hi, a + BLOCK)
                out.append((a, data[a - base:b - base]))
                a = b
        return out
    blocks = []
    gb = []
    lb = chunks(live_r, prg, prg_addr)
    total = sum(len(d) for _, d in lb)
    cname = {'table': 'core_stripes', 'flat': 'core_flat', 'block': 'core_flat', 'fx': 'core_fx'}.get(smode, 'core')
    cs = S.sym(cname)
    cb = []
    if ch:                                       # a chain: the switch, the first's last part
        if not lb:
            raise Refused("all of the program loads into the modules' memory: the second would show for"
                          " no time")
        b = ch['b']
        sw = S.chain_shim(g, b, min(65535, round(16777216 / total)), cs)
        parts = parts + [(sw['addr'], sw['data'], False)]
        for a, d in ch['parts']:                 # its parts in its file's order
            for i in range(0, len(d), BLOCK):
                cb.append((a + i, d[i:i + BLOCK]))
        nchain = sum(len(d) for _, d in ch['parts'])
        neff = max(256, nchain - 512)            # (full two pages early: slopload.py's)
    stg = g.get('stage') if g else None
    ndraw = None
    if g and g.get('drawin'):                    # a picture drawn in (SlopLoad 64's dpart, drawn):
        first, kept = [], []                     # each part cut at $cc00, $d000, $e000, $ff40, the
        for a, d, io in parts:                   # pieces in its screen and bitmap kept back, then
            cuts = [c for c in DRAW_CUTS if a < c < a + len(d)]     # added after the rest, the last
            for lo, hi in zip([a] + cuts, cuts + [a + len(d)]):     # kept back first
                piece = (lo, d[lo - a:hi - a], io)
                (kept if any(r0 <= lo < r1 for r0, r1 in DRAW_KEPT) else first).append(piece)
        parts = first + kept[::-1]
        ndraw = len(first)
    nbootb = ndrawb = 0
    for k, (a, d, io) in enumerate(parts):
        if stg and k == 2:                       # (the music first: the tune and its player first)
            nbootb = len(gb)
        if k == ndraw:
            ndrawb = len(gb)
        for i in range(0, len(d), BLOCK):
            gb.append((a + i, d[i:i + BLOCK], io))
    if ch:                                       # +26: the first counts the second's blocks,
        k = next(i for i, (a, d, io) in enumerate(gb) if a == g['addr'] and d[:4] == b'PLG1')
        a, d, io = gb[k]                         # the second the program's
        d = bytearray(d)
        d[26] = min(255, -(-(nchain + 2) // 254))
        gb[k] = (a, bytes(d), io)
        a, d = cb[0]
        d = bytearray(d)
        d[26] = min(255, -(-(total + 2) // 254))
        cb[0] = (a, bytes(d))
    elif show == 'module':
        # header +26: the disk blocks its counter counts down, those that
        # load while it runs (as SlopLoad 64's liveblk)
        k = next(i for i, (a, d, io) in enumerate(gb) if a == su['module']['addr'] and d[:4] == b'PLG1')
        a, d, io = gb[k]
        d = bytearray(d)
        d[26] = min(255, -(-(total + 2) // 254))
        gb[k] = (a, bytes(d), io)
    last = T.F_GAMEREADY | (0 if lb else T.F_MAINEND)   # (no program while it runs: it ends the main load)
    if stg:                                      # the player's hand-over (SlopLoad 64's mkcore): when
        k = next(i for i, (a, d, io) in enumerate(gb) if a == stg['addr'])      # the module's parts are
        a, d, io = gb[k]                         # in, to its init, frame and stop (or the switch's),
        d = bytearray(d)                         # the progress a page from then on
        h0 = stg['hand']
        d[h0] = len(gb)
        d[h0 + 1:h0 + 7] = bytes([g['init'] & 255, g['init'] >> 8]) + (
            bytes([sw['cframe'] & 255, sw['cframe'] >> 8, sw['cstop'] & 255, sw['cstop'] >> 8]) if ch else
            bytes([g['frame'] & 255, g['frame'] >> 8, g['stop'] & 255, g['stop'] >> 8]))
        st_ = min(65535, round(16777216 / (neff if ch else max(1, total))))
        d[h0 + 7:h0 + 9] = bytes([st_ & 255, st_ >> 8])
        gb[k] = (a, bytes(d), io)
    for i, (a, d, io) in enumerate(gb):
        if stg and i < nbootb:                   # (the music first: the tune, its player: they start)
            fl = T.F_GAMEREADY if i == nbootb - 1 else 0
            kind = 'module'
        elif ndraw is not None:                  # (drawn in: it starts before them; they load as
            fl = (T.F_GAMEREADY if i == ndrawb - 1 else 0) | (           # the program does)
                last & ~T.F_GAMEREADY if i == len(gb) - 1 else 0)
            kind = 'drawn' if i >= ndrawb else 'module'
        else:
            fl = (last & ~T.F_GAMEREADY if stg else last) if i == len(gb) - 1 else 0
            kind = 'stage' if stg else 'module'
        blocks.append(dict(addr=a, data=d, flags=fl, kind=kind, pilot_s=PILOT_RESTART, prog=0, io=io))
    done = 0
    for i, (a, d) in enumerate(cb):
        blocks.append(dict(addr=a, data=d, flags=T.F_CHAIN if i == len(cb) - 1 else 0, kind='chain',
                           pilot_s=PILOT_RESTART, prog=min(255, (256 * done) // neff)))
        done += len(d)
    done = 0
    later = chunks(later_r, prg, prg_addr)
    for i, (a, d) in enumerate(lb):
        fl = 0
        if i == len(lb) - 1:
            fl = T.F_MAINEND | (0 if later else T.F_LAST)
        blocks.append(dict(addr=a, data=d, flags=fl, kind='live', pilot_s=PILOT_RESTART,
                           prog=(256 * done) // max(1, total)))
        done += len(d)
    for i, (a, d) in enumerate(later):
        blocks.append(dict(addr=a, data=d, flags=T.F_LAST if i == len(later) - 1 else 0, kind='later',
                           pilot_s=PILOT_RESUME if i == 0 else PILOT_RESTART, prog=255))
    first_later = len(blocks) - len(later)
    for i, b in enumerate(blocks):
        b['seq'] = i
        if not stops:
            b['pilot_s'] = (S.PILOT_FIRST if i == 0 else S.PILOT_RESUME if i == first_later and later
                            else S.PILOT_BLOCK)
        last = i == len(blocks) - 1
        if b['addr'] < 0xe000 and b['addr'] + len(b['data']) > 0xd000 and not b.get('io'):
            b['flags'] |= T.F_UNDERIO
        running = b['kind'] in ('live', 'chain', 'stage', 'drawn') and g is not None
        hl, sl, ll = ((h_chain, g['cshare'], live_c) if b['kind'] == 'chain' or b['kind'] == 'drawn' and ch else
                      (h_boot, stg['share'], stage_set) if b['kind'] == 'stage' else (h_live, su['share'], live))
        if phase == 2:
            h, m, pfx, key, body = choose(b['data'], hl if running else h_boot, sl if running else None,
                                          pmin_live if running and b['kind'] != 'stage' else PMIN)
        else:
            h, m = ll if running else boot
            pfx, key = False, T.best_key(b['data'])
            body = T.turbo_classes(bytes([0xff]) + bytes(x ^ key for x in b['data'])
                                   + bytes([T.xor_all(b['data'])]))
        b.update(set=(h, m), key=key, body=body, pilot=pilot_count(b['pilot_s'], h),
                 trailer=trailer_count(h, m) if stops or last else 0, bridge=not stops and not last)
        b['flags'] |= ((m - 2) << 4) | (T.F_PREFIX if pfx else 0)

    # the core, patched as slopload.py does (a style's lines: core_stripes;
    # no stripes: core_flat)
    core = bytearray(open(os.path.join(BUILD, cname + '.bin'), 'rb').read())
    pages = (len(core) + 255) // 256
    core += bytes(pages * 256 - len(core))

    def put(label, val, size=1, at=0):
        a = cs[label] - 0x0400 + at
        for i in range(size):
            core[a + i] = (val >> (8 * i)) & 255
    run = start is None
    put('pt_game', 1 if g else 0)
    put('pt_auto', 1 if autorun else 0)
    if g:
        put('pt_init', g['init'], 2)
        put('pt_frame', sw['cframe'] if ch else g['frame'], 2)
        put('pt_stop', sw['cstop'] if ch else g['stop'], 2)
    if stg:                                      # the music first: its player is the core's module
        put('pt_init', stg['init'], 2)           # until it hands over
        put('pt_frame', stg['frame'], 2)
        put('pt_stop', stg['stop'], 2)
    put('x_run', 1 if run else 0, at=1)
    put('x_jmp', start or 0, 2, at=1)
    put('x_port', 0x37, at=1)
    put('x_irq', 0x58)
    put('x_vt1', end & 255, at=1)
    put('x_vt2', end >> 8, at=1)
    put('pt_step', 0 if stg else min(65535, round(16777216 / (neff if ch else max(1, total)))), 2)
    if smode == 'table':
        for i, c in enumerate(S.stripe_table(spec)):
            put('stab', c, at=i)
    if smode == 'flat':
        put('bflat', 0xa2)                       # ldx #colour (else ldx ld_seq)
        put('bflat', scol, at=1)
    put('pt_strs', 0x20 if strs else 0)
    line_cycle = bool(cycle and fxs and fxs['name'] == 'line')
    if cycle and not line_cycle:                 # the border a colour on each page
        for i, b in enumerate((0xee, 0x20, 0xd0)):
            put('cycle', b, at=i)
    if fxs:                                      # the effect (slopload.py's)
        for i, b in enumerate(fxs['code']):
            put('stripe', b, at=i)
        put('fxbc', fxs['base'], at=1)
        if line_cycle:                           # line: its border's colour one on a block (stron)
            to = cs['stripe'] + fxs['cat']
            for i, b in enumerate((0xee, to & 255, to >> 8, 0xc9, 0x00)):
                put('fxbc', b, at=i)
        put('fxa1', fxs['a'][0], at=1)
        put('fxb1', fxs['b'][0], at=1)
        put('fxa0', fxs['a'][1], at=1)
        put('fxb0', fxs['b'][1], at=1)
        put('fxs', (cs['stripe'] + fxs['pa']) & 255, at=1)
        put('fxs2', (cs['stripe'] + fxs['pb']) & 255, at=1)

    ss = S.sym('stage1')
    s1 = bytearray(open(os.path.join(BUILD, 'stage1_block.bin'), 'rb').read())
    s1[ss['s1_pages'] - ss['s1lo']] = pages
    hpart = bytearray(open(os.path.join(BUILD, 'stage1_header.bin'), 'rb').read())
    if smode != 'rainbow':                       # stage 1: one colour, not the timer's
        s1[ss['s1str'] - ss['s1lo']] = 0x2c
        hpart[ss['s1bc'] + 1 - 0x0351] = scol
    hpart = bytes(hpart)
    if isinstance(name, (bytes, bytearray)):    # (as typed on the C64: any codes)
        nm = bytes(name[:16]) + bytes([0x20]) * (16 - len(name[:16]))
    else:
        nm = S.petscii_name(name or 'SLOPLOAD')
    header = bytes([3, ss['s1lo'] & 255, ss['s1lo'] >> 8, 0x04, 0x03]) + nm + hpart
    header += bytes([0x20]) * (192 - len(header))
    return dict(blocks=blocks, core=bytes(core), header=header, s1=bytes(s1), boot=boot, live=live,
                stops=stops, setup=su)


def pulses(p):
    """the whole tape, PAL cycles"""
    out = T.rom_file(p['header'], p['s1'])
    hb = p['boot'][0]
    syms = [0] * pilot_count(PILOT_CORE, hb) + [3] + T.turbo_classes(p['core'] + bytes([T.xor_all(p['core'])]))
    if not p['stops']:
        syms += T.turbo_classes(bytes([BRIDGE]))
    out += [T.pulse(k, hb, 4) for k in syms]
    for b in p['blocks']:
        h, m = b['set']
        d = b['data']
        hdr = T.header_bytes(b['addr'], len(d), b['key'], b['flags'], b['seq'], b['prog'])
        out += [T.pulse(k, h, 4) for k in [0] * b['pilot'] + [3] + T.turbo_classes(bytes(hdr))]
        out += [T.pulse(k, h, m) for k in b['body']]
        out += [T.pulse(0, h, m)] * b['trailer']
        if b['bridge']:
            out += [T.pulse(k, h, m) for k in T.turbo_classes(bytes([BRIDGE]))]
    return out


def tap_bytes(pu):
    """a .tap (version 1) as the C64 tool writes it: each pulse
    (pulse + 4) // 8, all under 2,048 cycles"""
    body = bytes((c + 4) // 8 for c in pu)
    assert all(0 < c < 2048 for c in pu)
    return b'C64-TAPE-RAW' + bytes([1, 0, 0, 0]) + len(body).to_bytes(4, 'little') + body


def main(argv):
    o = dict(module='crossy', slm=None, speed=0, start=None, autorun=False, name=None,
             phase='2', stops=True, then=None)
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-module', '-slm', '-speed', '-start', '-name', '-phase', '-then'):
            o[a[1:]] = argv[i + 1]
            i += 2
        elif a == '-nostops':
            o['stops'] = False
            i += 1
        else:
            pos.append(a)
            i += 1
    d = open(pos[0], 'rb').read()
    addr, prg = d[0] | d[1] << 8, d[2:]
    music = slm_music(o['slm']) if o['slm'] else None
    show = 'module' if o['module'] != 'none' else 'music' if music else 'none'
    start = int(o['start'], 16) if o['start'] else (None if addr == 0x0801 else addr)
    p = plan(addr, prg, show, o['module'], music, int(o['speed']), start, o['autorun'],
             o['name'] or os.path.splitext(os.path.basename(pos[0]))[0].upper(), int(o['phase']),
             o['stops'], then=o['then'])
    pu = pulses(p)
    open(pos[1], 'wb').write(tap_bytes(pu))
    rom_end = T.rom_decode(pu)[-1][1]
    got = T.decode_turbo([(v + 4) // 8 * 8 for v in pu], rom_end, len(p['core']) // 256)
    ok = len(got) == len(p['blocks']) + 1 and all(b['ok'] for b in got)
    print(f"{pos[1]}: {len(p['blocks'])} blocks, sets boot {p['boot']} live {p['live']},"
          f" {sum(pu) / T.PAL_HZ:.1f} s; self-check {'all decode' if ok else 'FAILED'}")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
