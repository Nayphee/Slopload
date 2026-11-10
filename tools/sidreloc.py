#!/usr/bin/env python3
"""sidreloc.py - move a SID tune to another address.

    sidreloc.py in.sid out.sid -to C000 [-song N] [-frames N]
    sidreloc.py in.sid -info [-song N] [-frames N]

Runs the tune in the 6502 simulator (tests/sim6502.py) and follows where
every byte of the address an instruction uses came from: an absolute
operand (or one the tune wrote itself, from an immediate or a table), the
high byte of a pointer in zero page (back through the loads and stores
that put it there), an address pushed for an RTS jump. Each byte of the
tune that ends up as the high byte of an address inside the tune is one
to move, and so is the immediate of a compare with such a byte (a copy
loop's end: CMP #$7E, the page past the tune). Moving the tune by whole pages is then adding to those bytes.

The moved tune is run again, at its new address with nothing left at the
old one: its SID register writes must be exactly the original's, frame
by frame, for every song (or the one -song names). Then out.sid is
written: a PSID with the new load, init and play addresses.

What can't move is said: code that builds an address from arithmetic the
trace can't follow, or a target that would overlap the tune's workspace
(RAM it uses outside its own bytes, which stays where it is), zero page,
the stack or I/O.

-info shows the bytes to move, the workspace, and a test move.
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sidfile as F  # noqa: E402
import sim6502  # noqa: E402  (tests/, on the path through sidfile)

DECODE = sim6502.DECODE
OFFICIAL = {op for m, modes in sim6502.OPS.items() for op in modes.values()}
SIZE = {'imp': 1, 'acc': 1, 'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'izx': 2, 'izy': 2, 'rel': 2,
        'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3}
FRAMES = 15000                  # 5 minutes of play: a song's rarer paths too
RMW = {'inc', 'dec', 'asl', 'lsr', 'rol', 'ror', 'dcp', 'isc', 'slo', 'sre', 'rla', 'rra'}


class Unmovable(Exception):
    pass


class TraceSim(F.TuneSim):
    """the tune, following the high bytes of the addresses it uses"""
    def __init__(self, t):
        super().__init__(t)
        self.lo, self.hi = t['load'], t['end']
        self.morig = {}                     # address -> the tune byte its value came from
        self.oa = self.ox = self.oy = None
        self.marks = set()                  # tune bytes that are address high bytes
        self.spans = set()                  # (such a byte, a page reached with it)
        self.cmps = {}                      # cmp/cpx/cpy #imm operand (where it came from) ->
                                            # where the register's value came from (cmp_marks)
        self.code = set()                   # instructions run
        self.sid_log = []
        self.frame = 0

    def org(self, a):
        if a in self.morig:
            return self.morig[a]
        return a if self.lo <= a < self.hi else None

    def inr(self, a):
        return self.lo <= a < self.hi

    def mark(self, o, ea=None):
        """o: a tune byte that is an address's high byte; ea: the address
        reached with it (its page, noted in spans)"""
        if o is not None and self.lo <= o < self.hi:
            self.marks.add(o)
            if ea is not None and self.inr(ea):
                self.spans.add((o, ea >> 8))

    def _wh(self, a, v):
        if 0xd400 <= a < 0xd800:
            self.sid_log.append((self.frame, a & 0x1f, v))
        super()._wh(a, v)

    def step(self):
        m = self.mem
        pc = self.pc
        op = m[pc]
        if op not in DECODE:
            return super().step()
        mn, mode = DECODE[op]
        self.code.add(pc)
        sp0, x, y = self.sp, self.x, self.y
        ea = None
        p1, p2 = (pc + 1) & 0xffff, (pc + 2) & 0xffff
        if mode in ('abs', 'abx', 'aby'):
            base = m[p1] | m[p2] << 8
            ea = (base + (x if mode == 'abx' else y if mode == 'aby' else 0)) & 0xffff
            if self.inr(ea) or self.inr(base):
                self.mark(self.org(p2), ea)
        elif mode == 'ind':
            ptr = m[p1] | m[p2] << 8
            if self.inr(ptr):
                self.mark(self.org(p2), ptr)
            hl = (ptr & 0xff00) | ((ptr + 1) & 0xff)
            if self.inr(m[ptr] | m[hl] << 8):
                self.mark(self.org(hl), m[ptr] | m[hl] << 8)
        elif mode == 'izy':
            z = m[p1]
            hl = (z + 1) & 0xff
            ptr = m[z] | m[hl] << 8
            ea = (ptr + y) & 0xffff
            if self.inr(ea) or self.inr(ptr):
                self.mark(self.org(hl), ea)
        elif mode == 'izx':
            z = (m[p1] + x) & 0xff
            hl = (z + 1) & 0xff
            ea = m[z] | m[hl] << 8
            if self.inr(ea):
                self.mark(self.org(hl), ea)
        elif mode in ('zp', 'zpx', 'zpy'):
            ea = (m[p1] + (x if mode == 'zpx' else y if mode == 'zpy' else 0)) & 0xff
        if mn in ('cmp', 'cpx', 'cpy') and mode == 'imm':
            o = {'cmp': self.oa, 'cpx': self.ox, 'cpy': self.oy}[mn]
            k = self.org(p1)                # (the immediate's own origin: code may store it)
            if o is not None and k is not None:     # (an end page, if o turns out a high byte)
                self.cmps[k] = o
        if mn in ('adc', 'sbc', 'ora', 'eor', 'and'):
            # the result comes from whichever input looks like a high byte
            # inside the tune (lda #0 : adc table,x builds one in A)
            op_o = p1 if mode == 'imm' else (self.org(ea) if ea is not None else None)
            op_v = m[p1] if mode == 'imm' else (m[ea] if ea is not None else None)
            pages = range(self.lo >> 8, ((self.hi - 1) >> 8) + 1)
            a_in = self.a in pages
            arith = (op_o, op_v is not None and op_v in pages, a_in)
        else:
            arith = None
        if mn == 'rts':                     # a pushed address: its high byte
            lo_s, hi_s = 0x100 + ((sp0 + 1) & 0xff), 0x100 + ((sp0 + 2) & 0xff)
            if self.inr(((m[lo_s] | m[hi_s] << 8) + 1) & 0xffff):
                self.mark(self.org(hi_s), ((m[lo_s] | m[hi_s] << 8) + 1) & 0xffff)
        r = super().step()
        if mn in ('lda', 'ldx', 'ldy', 'lax'):
            o = p1 if mode == 'imm' else (self.org(ea) if ea is not None else None)
            if mn in ('lda', 'lax'):
                self.oa = o
            if mn in ('ldx', 'lax'):
                self.ox = o
            if mn == 'ldy':
                self.oy = o
        elif mn in ('sta', 'stx', 'sty', 'sax') and ea is not None:
            self.morig[ea] = {'sta': self.oa, 'stx': self.ox, 'sty': self.oy, 'sax': None}[mn]
        elif arith is not None:
            op_o, op_in, a_in = arith
            if op_in and not a_in:
                self.oa = op_o
        elif mn == 'tax':
            self.ox = self.oa
        elif mn == 'tay':
            self.oy = self.oa
        elif mn == 'txa':
            self.oa = self.ox
        elif mn == 'tya':
            self.oa = self.oy
        elif mn == 'tsx':
            self.ox = None
        elif mn == 'pha':
            self.morig[0x100 + sp0] = self.oa
        elif mn == 'php':
            self.morig[0x100 + sp0] = None
        elif mn == 'pla':
            self.oa = self.org(0x100 + self.sp)
        elif mn == 'jsr':
            self.morig[0x100 + sp0] = None
            self.morig[0x100 + ((sp0 - 1) & 0xff)] = None
        return r


def play_run(sim, t, song, frames):
    """init then frames play calls; the sim, for its log and marks"""
    sim.call(t['init'], a=song - 1, limit=5_000_000)
    for f in range(frames):
        sim.frame = f + 1
        c0 = sim.cycles
        sim.call(t['play'], limit=200_000)
        sim.cycles = c0 + F.PAL_FRAME
    return sim


def static_marks(t, code):
    """static_walk's address bytes, and how many instructions it found"""
    marks, done = static_walk(t, code)
    return marks, len(done)


def static_walk(t, code):
    """Address bytes in code the run never reached, and that code (its
    instructions' first bytes). From every branch,
    JMP and JSR it ran, the ways not taken are decoded in the tune's
    bytes until they end (RTS, RTI, JMP) or join code already known; each
    absolute operand inside the tune is one to move. A way that runs into
    a byte no (official) instruction starts with, a BRK, or out of the
    tune is taken to be data, and nothing in it is moved."""
    lo, hi, data = t['load'], t['end'], t['data']
    b = lambda a: data[a - lo]
    known = {a for a in code if lo <= a < hi}
    starts = []

    def exits(a, mn, mode):
        if mode == 'rel':
            off = b(a + 1)
            return [a + 2, a + 2 + off - (256 if off > 127 else 0)]
        if mn in ('jmp', 'jsr') and mode == 'abs':
            return [b(a + 1) | b(a + 2) << 8] + ([a + 3] if mn == 'jsr' else [])
        return []
    for a in known:
        if a + 2 < hi and b(a) in DECODE:
            starts += exits(a, *DECODE[b(a)])
    marks, done = set(), set()
    while starts:
        a = starts.pop()
        if a in known or a in done or not lo <= a < hi:
            continue
        path, pm, more, ok = [], set(), [], True
        while True:
            if a in known or a in done or a in path:
                break                       # joins code already known
            if not lo <= a < hi or b(a) not in OFFICIAL or b(a) == 0x00:
                ok = False
                break
            mn, mode = DECODE[b(a)]
            size = SIZE[mode]
            if a + size > hi:
                ok = False
                break
            path.append(a)
            if mode in ('abs', 'abx', 'aby', 'ind') and lo <= (b(a + 1) | b(a + 2) << 8) < hi:
                pm.add(a + 2)
            more += exits(a, mn, mode)
            if mn in ('rts', 'rti', 'jmp'):
                break
            a += size
        if ok:
            done.update(path)
            marks |= pm
            starts += more
    return marks, done


def cmp_marks(t, cmps, marks):
    """Compares with a page: the immediate of a CMP, CPX or CPY whose
    register came from an address high byte (a copy loop's source page,
    counted up to the page past the end: inc src+2 : lda src+2 : cmp #$7E),
    when it names one of the tune's pages or the one just past its end"""
    pages = range(t['load'] >> 8, ((t['end'] - 1) >> 8) + 2)
    return {a for a, o in cmps.items() if o in marks and t['data'][a - t['load']] in pages}


def songs_of(t, song):
    return [song] if song else list(range(1, max(1, t['songs']) + 1))


PLAYER_FLAGS = (0x01, 0x80, 0x81)        # SlopLoad's player: voice 3 handed over, NTSC, both
PLAYER_FRAMES = 300


def trace(t, song=None, frames=FRAMES, player=False):
    """the bytes to move (tune addresses), the workspace, and each song's
    SID log, over the songs to keep (and code the run didn't reach:
    static_marks). player: a tune in SlopLoad's own player (sidstrip's
    slp_player): its other ways are run too, as a module runs them (its
    flags byte, +9, at each of PLAYER_FLAGS, then its stop, +6, and a play
    after it), for what only they use; their sound isn't compared"""
    if t['rsid'] or not t['play']:
        raise Unmovable("an RSID tune, or one with no play routine: it can't be run here")
    marks, ws, logs, code, cmps = set(), set(), {}, set(), {}

    def take(s):
        nonlocal marks, code, ws
        marks |= s.marks
        cmps.update(s.cmps)
        code |= s.code
        ws |= {a for a in s.writes if 0x200 <= a < 0xd000 or a >= 0xe000}
        outside = [a for a in s.outside if a not in s.writes]
        if outside:
            raise Unmovable(f"it runs code outside itself (${outside[0]:04X}: a ROM)")
    for sg in songs_of(t, song):
        s = play_run(TraceSim(t), t, sg, frames)
        take(s)
        logs[sg] = s.sid_log
    for fl in (PLAYER_FLAGS if player else ()):
        tf = dict(t, data=t['data'][:9] + bytes([fl]) + t['data'][10:])
        for sg in songs_of(t, song):
            s = play_run(TraceSim(tf), tf, sg, PLAYER_FRAMES)
            s.call(t['load'] + 6, limit=200_000)        # stop
            s.call(t['play'], limit=200_000)            # (then play does nothing)
            take(s)
    marks |= static_marks(t, code)[0]
    marks |= cmp_marks(t, cmps, marks)
    return marks, sorted(ws), logs


def moved(t, marks, to):
    """the tune moved to address to (a whole number of pages away)"""
    d = (to - t['load']) >> 8
    if (to - t['load']) & 0xff:
        raise Unmovable("tunes move by whole pages: the new address must end in 00 as the old")
    data = bytearray(t['data'])
    for a in marks:
        i = a - t['load']
        data[i] = (data[i] + d) & 0xff
    sh = lambda a: (a + d * 256) & 0xffff if t['load'] <= a < t['end'] else a
    return dict(t, data=bytes(data), load=to, end=to + len(data), init=sh(t['init']), play=sh(t['play']))


def check_target(t, to, workspace):
    end = to + len(t['data'])
    if to < 0x200 or end > 0xfffa:
        raise Unmovable(f"${to:04X}-${end - 1:04X} would reach zero page, the stack or the CPU's vectors")
    if to < 0xe000 and end > 0xd000:
        raise Unmovable(f"${to:04X}-${end - 1:04X} would sit under I/O, where the tune can't run")
    hit = [a for a in workspace if to <= a < end and not t['load'] <= a < t['end']]
    if hit:
        raise Unmovable(f"${to:04X}-${end - 1:04X} would cover the tune's workspace (${hit[0]:04X})")


def relocate(t, to, song=None, frames=FRAMES, traced=None):
    """the tune moved to address to and checked; (moved tune, bytes moved)"""
    marks, ws, logs = traced or trace(t, song, frames)
    check_target(t, to, ws)
    n = moved(t, marks, to)
    for sg, log in logs.items():
        s = play_run(TraceSim(n), n, sg, frames)
        if s.sid_log != log:
            first = next((i for i, (a, b) in enumerate(zip(s.sid_log, log)) if a != b),
                         min(len(s.sid_log), len(log)))
            fr = log[first][0] if first < len(log) else '?'
            raise Unmovable(f"moved, song {sg} plays differently from frame {fr}: some address in it"
                            " is built in a way the trace couldn't follow")
    return n, len(marks)


def move_checked(t, offsets, to, song, frames=1500, workspace=()):
    """the tune moved to address to by its known address bytes (offsets
    into it), run beside the unmoved one: the same SID writes, or Unmovable"""
    check_target(t, to, [a for lo, hi in workspace for a in range(lo, hi)])
    n = moved(t, {t['load'] + o for o in offsets}, to)
    a = play_run(TraceSim(t), t, song, frames).sid_log
    b = play_run(TraceSim(n), n, song, frames).sid_log
    if a != b:
        raise Unmovable(f"moved to ${to:04X}, it plays differently")
    return n


def test_target(t, ws):
    """somewhere far from the tune to try a move"""
    size, low = len(t['data']), t['load'] & 0xff        # a move keeps the low byte
    for to in [p * 256 + low for p in list(range(0x80, 0xd0)) + list(range(0x08, 0x80))]:
        if to + size > 0xd000 and to < 0xe000:
            continue
        if abs(to - t['load']) < size + 0x100:
            continue
        try:
            check_target(t, to, ws)
            return to
        except Unmovable:
            continue
    return None


def write_psid(path, src_path, n):
    """a PSID like the original, at its new place (load address in the data)"""
    d = open(src_path, 'rb').read()
    off = struct.unpack('>H', d[6:8])[0]
    hdr = bytearray(d[:off])
    hdr[0:4] = b'PSID'
    struct.pack_into('>HHH', hdr, 8, 0, n['init'], n['play'])
    if len(hdr) >= 0x7a:
        hdr[0x78] = 0                       # no free-page information
        hdr[0x79] = 0
    open(path, 'wb').write(bytes(hdr) + struct.pack('<H', n['load']) + n['data'])


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    opt = lambda k, f=None: argv[argv.index(k) + 1] if k in argv and argv.index(k) + 1 < len(argv) else f
    try:
        song = int(opt('-song')) if '-song' in argv else None
        frames = int(opt('-frames', FRAMES))
        to = int(opt('-to').replace('$', ''), 16) if opt('-to') else None
    except ValueError:
        print("sidreloc: -song and -frames need a number, -to an address in hex", file=sys.stderr)
        return 1
    pos = [a for i, a in enumerate(argv) if not a.startswith('-')
           and (i == 0 or argv[i - 1] not in ('-song', '-frames', '-to'))]
    if not pos or ('-info' not in argv and (to is None or len(pos) < 2)):
        print(__doc__)
        return 1
    try:
        t = F.read(pos[0])
        print(f"{t['name']} / {t['author']}: ${t['load']:04X}-${t['end'] - 1:04X}"
              f" ({len(t['data'])} bytes), {t['songs']} songs")
        traced = trace(t, song, frames)
        marks, ws, _ = traced
        print(f"  {len(marks)} address bytes to move; workspace outside the tune:"
              f" {', '.join(f'${a:04X}-${b - 1:04X}' for a, b in F.ranges([a for a in ws if not t['load'] <= a < t['end']])) or 'none'}")
        if '-info' in argv:
            to = test_target(t, ws)
            if to is None:
                print("  no room for a test move")
                return 1
            relocate(t, to, song, frames, traced)
            print(f"  a test move to ${to:04X}: plays the same ({'song ' + str(song) if song else 'every song'},"
                  f" {frames} frames each)")
            return 0
        n, k = relocate(t, to, song, frames, traced)
        write_psid(pos[1], pos[0], n)
        print(f"  moved to ${n['load']:04X}-${n['end'] - 1:04X}, init ${n['init']:04X}, play ${n['play']:04X};"
              f" plays the same ({'song ' + str(song) if song else 'every song'}, {frames} frames each)")
        print(f"  wrote {pos[1]}")
        return 0
    except (Unmovable, F.Bad) as ex:
        print(f"sidreloc: {ex}", file=sys.stderr)
        return 1
    except OSError as ex:
        print(f"sidreloc: {ex.filename}: {ex.strerror}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
