#!/usr/bin/env python3
"""The C64 mastering tool's output, in Python: the reference its 6502 code
(c64/slopload64.asm) is checked against, pulse for pulse.

    c64model.py program.prg out.tap [-show module|none|picture|picmusic|music]
                [-module NAME|FILE.lm] [-slm TUNE.slm] [-picture FILE.koa]
                [-speed N] [-start HEX] [-autorun] [-name NAME] [-nostops]

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
SHOWS = ('none', 'module', 'picture', 'picmusic', 'music')


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


def load_koa(raw):
    """a Koala picture file as SlopLoad 64 reads it: (bitmap, screen,
    colour, background)"""
    d = raw[2:] if len(raw) in (10003, 10002) else raw
    if len(d) not in (10000, 10001):
        raise Refused(f"not a Koala picture ({len(raw)} bytes)")
    return dict(bitmap=d[:8000], screen=d[8000:9000], colour=d[9000:10000],
                bg=d[10000] & 15 if len(d) > 10000 else 0)


def show_module():
    """the show module at SHOW_BASE and the offsets of its address high
    bytes (assembled again a page on: the bytes one more)"""
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
    relocs = [i for i in range(len(d0)) if d0[i] != d1[i]]
    assert all((d1[i] - d0[i]) & 255 == 1 for i in relocs), "the show module doesn't move by its high bytes"
    return dict(data=bytes(d0), relocs=relocs, claim=l0['modend'] - SHOW_BASE)


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


def place_show(mlen, music, pic, prog):
    """(vic bank, module address) for the show module and the picture, as
    slopload.py's place_show: clear of the loader, the music, $D000-$DFFF
    and each other, with the least of the program under them; None if
    there's no room"""
    banned = [(0, 0x800), (0xfffa, 0x10000)] + list(music) + [(0xd000, 0xe000)]
    best = None
    for bank in ((3, 2, 1, 0) if pic else (3,)):
        b = bank * 0x4000
        prs = [(b + 0x0c00, b + 0x0fe8), (b + 0x2000, b + 0x3f40)] if pic else []
        if any(overlaps(r, banned) for r in prs):
            continue
        for base in [0xca00] + list(range(0xfe00 - mlen // 256 * 256, 0x07ff, -0x100)):
            mr = (base, base + mlen)
            if overlaps(mr, banned) or overlaps(mr, prs):
                continue
            score = under(prs + [mr], prog)
            if best is None or score < best[0]:
                best = (score, bank, base)
            if score == 0:
                break
        if best and best[0] == 0:
            break
    return None if best is None else (best[1], best[2])


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


def place_tune(m, ok):
    """the tune where it is if ok(that), else (a prepared tune that can
    move) the highest page, at the same offset, that is ok; None if none"""
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


def show_share(m, pic):
    """the loader's share beside a show's music, in integers: the music's
    play calls a frame (the most of PAL's and NTSC's) x its longest call
    x 1.3, plus 900, out of an NTSC frame (less 1,000 for a picture's bad
    lines); 85 at most, 25 at least"""
    calls256 = max(19968 * 256 // m['per_pal'], 16832 * 256 // m['per_ntsc'])
    need = m['cyc'] * calls256 * 13 // 2560 + 900
    avail = 17095 - (1000 if pic else 0)
    share = 100 * (avail - need) // avail if need < avail else 0
    if share < 25:
        raise Refused(f"its play calls take too long to load beside it ({m['cyc']} cycles)")
    return min(85, share)


def setup(show, game=None, music=None, picture=None, prog=(0x0801, 0x0802)):
    """what SlopLoad 64 works out before the blocks: the module (a game,
    or the show module placed), its header patched, the parts in tape
    order (addr, data, io), the claims, the share and the jitter.
    music: the tune as SlopLoad 64 holds it: load, data (patched), init,
    play, song (A for init), per_pal, per_ntsc, cyc, zp, ws, relocs (a
    prepared tune that can move, else None)"""
    if show not in SHOWS:
        raise Refused(f"no show '{show}'")
    out = dict(show=show, module=None, parts=[], claims=[], share=None, jit=0, song=None, music=None)
    if show == 'none':
        return out
    if show in ('picmusic', 'music') and music is None:
        raise Refused(f"this show needs music")
    if show in ('picture', 'picmusic') and picture is None:
        raise Refused(f"this show needs a picture")
    m = music if show in ('module', 'picmusic', 'music') else None
    if m is not None:
        why = tune_checks(m)
        if why:
            raise Refused(why)
    pic = load_koa(picture) if show in ('picture', 'picmusic') else None
    if show == 'module':
        g = load_lm(game)
        if m is not None:
            why = game_tune(m, g)
            if why:
                raise Refused(why)
            m = place_tune(m, lambda t: not any(overlaps(r, g['claims']) for r in music_ranges(t)))
            if m is None:
                raise Refused("it sits in the module's memory")
        head = bytearray(g['parts'][0][1])
        head[13] = 0xff if m is None else m['song']
        head[14] = g['share']
        if m is not None:
            head[16:25] = bytes([m['init'] & 255, m['init'] >> 8, m['play'] & 255, m['play'] >> 8,
                                 m['per_pal'] & 255, m['per_pal'] >> 8, m['per_ntsc'] & 255,
                                 m['per_ntsc'] >> 8, 2])
        head[26] = 0                    # (+26: plan(), from what loads while it runs)
        gparts = [(g['addr'], bytes(head))] + g['parts'][1:]
        mod = dict(addr=g['addr'], init=g['init'], frame=g['frame'], stop=g['stop'], claims=g['claims'],
                   jitter=g['jitter'], share=g['share'])
        parts = [(a, d, False) for a, d in gparts[1:]] + [(g['addr'], bytes(head), False)]
    else:
        sm = show_module()
        mlen = len(sm['data'])
        place = []

        def ok(t):
            r = place_show(mlen, music_ranges(t) if t else [], pic, prog)
            place[:] = [r] if r else []
            return r is not None
        if m is not None:
            m = place_tune(m, ok)
            if m is None:
                raise Refused("no room for the music, the picture and the show module together")
        elif not ok(None):
            raise Refused("no room for the picture and the show module together")
        bank, base = place[0]
        d = bytearray(sm['data'])
        for o in sm['relocs']:
            d[o] = (d[o] + ((base - SHOW_BASE) >> 8)) & 255
        share = show_share(m, pic) if m is not None else d[14]
        d[13] = 0xff if m is None else m['song']
        d[14] = share
        d[15] = 0xff if pic is None else pic['bg']
        if m is not None:
            d[16:25] = bytes([m['init'] & 255, m['init'] >> 8, m['play'] & 255, m['play'] >> 8,
                              m['per_pal'] & 255, m['per_pal'] >> 8, m['per_ntsc'] & 255,
                              m['per_ntsc'] >> 8, 2])
        d[25] = 3 - (bank if pic else 3)
        w = lambda o: d[o] | d[o + 1] << 8
        mod = dict(addr=base, init=w(4), frame=w(6), stop=w(8), claims=[(base, base + sm['claim'])],
                   jitter=d[12], share=share, bank=bank)
        parts = []
        if pic:
            pb = bank * 0x4000
            parts = [(pb + 0x0c00, pic['screen'], False), (0xd800, pic['colour'], True),
                     (pb + 0x2000, pic['bitmap'], False)]
        parts.append((base, bytes(d), False))
    if m is not None:
        parts.insert(0, (m['load'], m['data'], False))
    claims = list(mod['claims'])                 # the program's bytes there load after the show
    if m is not None:
        claims += music_ranges(m)
    if pic:
        claims += [(a, a + len(dd)) for a, dd, io in parts[1 if m is not None else 0:][:3] if not io]
    screen_on = show != 'music'
    out.update(module=mod, parts=parts, claims=claims, share=mod['share'],
               jit=mod['jitter'] if screen_on else 0, screen_on=screen_on,
               song=None if m is None else m['song'], music=m, pic=pic)
    return out


def plan(prg_addr, prg, show='none', game=None, music=None, picture=None, speed=0, start=None,
         autorun=False, name=None, phase=2, stops=True, lines=0, fcol=6):
    """the blocks, in tape order: dicts with addr, data, flags, h, m, pilot
    (pulses), trailer (pulses), bridge, prog, seq; and the core image and
    stage 1. show, game (the module), music, picture: as setup(). stops: the motor
    stopped before each block (a cassette written a block at a time), else
    written in one go. lines: the loading lines' mode, by its number in
    SlopLoad 64's list (slopload.py's STRIPES, then block, then one
    colour: fcol)"""
    modes = list(S.STRIPES) + ['block', 'one colour']
    smode, scol = ('flat', fcol) if modes[lines] == 'one colour' else S.stripe_mode(modes[lines])
    end = prg_addr + len(prg)
    su = setup(show, game, music, picture, (prg_addr, end))
    g = su['module']
    jit = su['jit']
    h_boot = max(S.H_MIN_BOOT, S.speed_h(speed))
    boot = best_set(h_boot, PMIN)
    if g and su['screen_on']:
        h_live = min(S.H_MAX, S.ceil4(S.speed_h(speed) + jit))
    else:
        h_live = h_boot
    # a style of stripes: the colour lookup makes the interrupt 4 cycles
    # longer, so with the screen on every pulse 212 cycles or more (as
    # slopload.py's -stripes). One colour or a colour a block costs nothing
    pmin_live = PMIN + (S.STRIPES_COST if smode == 'table' and su['screen_on'] else 0)
    live = best_set(h_live, pmin_live, su['share']) if g else boot
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
    for a, d, io in parts:
        for i in range(0, len(d), BLOCK):
            gb.append((a + i, d[i:i + BLOCK], io))
    lb = chunks(live_r, prg, prg_addr)
    total = sum(len(d) for _, d in lb)
    if show == 'module':
        # header +26: the disk blocks its counter counts down, those that
        # load while it runs (as SlopLoad 64's liveblk)
        k = next(i for i, (a, d, io) in enumerate(gb) if a == su['module']['addr'] and d[:4] == b'PLG1')
        a, d, io = gb[k]
        d = bytearray(d)
        d[26] = min(255, -(-(total + 2) // 254))
        gb[k] = (a, bytes(d), io)
    last = T.F_GAMEREADY | (0 if lb else T.F_MAINEND)   # (no program while it runs: it ends the main load)
    for i, (a, d, io) in enumerate(gb):
        blocks.append(dict(addr=a, data=d, flags=last if i == len(gb) - 1 else 0,
                           kind='module', pilot_s=PILOT_RESTART, prog=0, io=io))
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
        running = b['kind'] == 'live' and g is not None
        if phase == 2:
            h, m, pfx, key, body = choose(b['data'], h_live if running else h_boot,
                                          su['share'] if running else None, pmin_live if running else PMIN)
        else:
            h, m = live if running else boot
            pfx, key = False, T.best_key(b['data'])
            body = T.turbo_classes(bytes([0xff]) + bytes(x ^ key for x in b['data'])
                                   + bytes([T.xor_all(b['data'])]))
        b.update(set=(h, m), key=key, body=body, pilot=pilot_count(b['pilot_s'], h),
                 trailer=trailer_count(h, m) if stops or last else 0, bridge=not stops and not last)
        b['flags'] |= ((m - 2) << 4) | (T.F_PREFIX if pfx else 0)

    # the core, patched as slopload.py does (a style's lines: core_stripes;
    # no stripes: core_flat)
    cname = {'table': 'core_stripes', 'flat': 'core_flat', 'block': 'core_flat'}.get(smode, 'core')
    cs = S.sym(cname)
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
        put('pt_frame', g['frame'], 2)
        put('pt_stop', g['stop'], 2)
    put('x_run', 1 if run else 0, at=1)
    put('x_jmp', start or 0, 2, at=1)
    put('x_port', 0x37, at=1)
    put('x_irq', 0x58)
    put('x_vt1', end & 255, at=1)
    put('x_vt2', end >> 8, at=1)
    put('pt_step', min(65535, round(16777216 / max(1, total))), 2)
    if smode == 'table':
        for i, c in enumerate(S.stripe_table(modes[lines])):
            put('stab', c, at=i)
    if smode == 'flat':
        put('bflat', 0xa2)                       # ldx #colour (else ldx ld_seq)
        put('bflat', scol, at=1)

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
    o = dict(show=None, module='crossy', slm=None, picture=None, speed=0, start=None, autorun=False, name=None,
             phase='2', stops=True)
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-show', '-module', '-slm', '-picture', '-speed', '-start', '-name', '-phase'):
            o[a[1:]] = argv[i + 1]
            i += 2
        elif a == '-autorun':
            o['autorun'] = True
            i += 1
        elif a == '-nostops':
            o['stops'] = False
            i += 1
        else:
            pos.append(a)
            i += 1
    d = open(pos[0], 'rb').read()
    addr, prg = d[0] | d[1] << 8, d[2:]
    show = o['show'] or ('none' if o['module'] == 'none' else 'module')
    music = slm_music(o['slm']) if o['slm'] else None
    pic = open(o['picture'], 'rb').read() if o['picture'] else None
    start = int(o['start'], 16) if o['start'] else (None if addr == 0x0801 else addr)
    p = plan(addr, prg, show, o['module'], music, pic, int(o['speed']), start, o['autorun'],
             o['name'] or os.path.splitext(os.path.basename(pos[0]))[0].upper(), int(o['phase']),
             o['stops'])
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
