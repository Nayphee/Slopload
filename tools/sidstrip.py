#!/usr/bin/env python3
"""sidstrip.py - a SID tune made ready for SlopLoad.

    sidstrip.py tune.sid [out.slm] [-song N] [-frames N] [-cut]

Reads a PSID file, runs the chosen song in the 6502 simulator
(tools/sidfile.py) and makes it safe to play beside the loader:

  - stores the loader can't allow are turned into no-ops of the same
    length (NOP #imm, and a NOP after it for three-byte ones: no memory
    read, so a dummy read of a CIA's interrupt register can't eat the
    tape's interrupt). They are writes to the processor port $00/$01
    (bit 5 is the tape motor: many tunes set $36 for a moment), the
    VIC, colour RAM, the CIAs (the loader owns them; a CIA-timed tune's
    timer latch is kept as its play rate), I/O expansion, the loader's
    $0400-$07FF and the CPU's vectors;
  - then the patched tune is run again: it must touch none of those,
    and its SID register writes must be exactly the original's.

-cut keeps only the chosen song's part of the tune. In a tune with many
songs they share one player, but each song uses only some of the
memory: -cut keeps the pages the song uses in its play calls (-frames:
five minutes), and the code its branches could reach, packs them
together, moves every address in them with its page, and plays the cut
tune beside the whole one (the same SID writes). It is how a song of a
tune over 4 KB can fit SlopLoad 64's 4,096 bytes. What the song does
only after five minutes isn't seen: -frames 30000 looks at ten. If that
cut is still over 4,096 bytes, or can't be made, the tune is cut again
as its init leaves it (a tune whose init copies its song somewhere, as
The Last Ninja's does, then keeps only the copy): its memory then, with
a short init of its own that sets again what the tune's init set (the
zero page it wrote, its SID writes, the CIA's timer), checked to play
as the whole tune does.

Refused, with the reason: tunes for two or three SID chips, RSID tunes
(they take the interrupts), tunes
with no play routine, a tune that banks I/O out (the loader's interrupt
could come while it is), one that stores into those places through a
pointer (that can't be patched), one that calls into the ROMs (they are
out while the loader runs), and one that uses the loader's zero page
$02-$0F.

The .slm file (SlopLoad music), all words little-endian:
   0  "SLM2" (SLM1, before October 2026: byte 18 counted instructions)
   4  load address, length                     (words)
   8  init, play                               (words)
  12  song for init (A, 0-based)               (byte)
  13  flags: 1 made for PAL, 2 for NTSC, 4 CIA-timed, 8 can be moved
  14  time between play calls, PAL, 1/64 raster lines   (word)
  16  the same on NTSC                         (word)
  18  longest play call, cycles, the JSR and RTS included   (word)
  20  zero page used: 32 bytes, a bit per address
  52  workspace: count, then that many (from, to) word pairs
      bytes to move it (tools/sidreloc.py): a word count, then that many
      word offsets into the tune, each a high byte to add the move to
      name, author, released: 32 bytes each, then the tune's bytes
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sidfile as F  # noqa: E402

PAL_HZ, NTSC_HZ = 985248, 1022727
PAL_FPS, NTSC_FPS = PAL_HZ / (63 * 312), NTSC_HZ / (65 * 263)
DEFAULT_LATCH = 0x4025          # the KERNAL's 60 Hz timer: a CIA tune's rate if init sets none
GAME_PLAY_MAX = 3700            # cycles a play call may take beside a module (c64model's;
                                # the heaviest tried, 3,695, with Crossy-Load on NTSC; the
                                # built-in tune: 2,251)
TUNE_MAX = 4096                 # SlopLoad 64's limit (c64model.TUNE_MAX)
GAME_ZP = (0x10, 0x90)          # a module's zero page (MODULES.md) ...
MUSIC_ZP = (0x70, 0x80)         # ... less the music player's, which a tune may use

# stores the loader can't allow
def harmful(a):
    return (a < 2 or 0x0400 <= a < 0x0800 or 0xd000 <= a < 0xd400 or 0xd800 <= a < 0xe000
            or a >= 0xfffa)


import sim6502  # noqa: E402  (tests/, on the path through sidfile)

MODE_LEN = {'imp': 1, 'acc': 1, 'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'izx': 2, 'izy': 2,
            'rel': 2, 'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3}
LEN = {op: MODE_LEN[mode] for op, (mn, mode) in sim6502.DECODE.items()}   # opcode -> length
INDIRECT = {0x81, 0x91}          # sta (zp,x), sta (zp),y


class StripSim(F.TuneSim):
    """the tune in the simulator, noting each store's instruction"""
    def __init__(self, t):
        super().__init__(t)
        self.stores = {}         # pc -> set of addresses it stored to
        self.port_values = set()
        self.sid_log = []        # (frame, register, value)
        self.frame = 0
        self.stack_data = set()  # direct stores into $0100-$01ff
        self.mirror_play = set() # play-time stores above $d41f (a second chip)

    def step(self):
        self.cur = self.pc
        return super().step()

    def _wh(self, a, v):
        self.stores.setdefault(self.cur, set()).add(a)
        if a < 2:
            if a == 1:
                self.port_values.add(v)
        elif 0xd400 <= a < 0xd800:
            self.sid_log.append((self.frame, a & 0x1f, v))
            if a >= 0xd420 and self.frame:
                self.mirror_play.add(a)
        elif 0x100 <= a < 0x200:
            self.stack_data.add(a)
        super()._wh(a, v)


def run(t, song, frames, data=None):
    tt = dict(t)
    if data is not None:
        tt['data'] = data
    s = StripSim(tt)
    s.call(t['init'], a=song - 1, limit=5_000_000)
    worst = worst_clk = 0
    for f in range(frames):
        s.frame = f + 1
        c0, k0 = s.cycles, s.clk
        s.call(t['play'], limit=200_000)
        worst = max(worst, s.cycles - c0)
        worst_clk = max(worst_clk, s.clk - k0)
        s.cycles = c0 + F.PAL_FRAME
        s.clk = k0 + F.PAL_FRAME            # the next call a PAL frame on (real cycles)
    s.worst = worst                         # instructions
    s.worst_clk = worst_clk + 6 if frames else 0    # real cycles, the JSR (and RTS) included
    return s


class Refused(Exception):
    pass


def io_out(v):
    """does processor port value v bank I/O out?"""
    return (v & 4) == 0 or (v & 3) == 0


def cut_song(t, song, frames, name, after=None, whole=None):
    """cut_pages, then the cut tune played beside the whole one: its SID
    writes must be the same, frame by frame. after: t is after_init's
    tune (its stub's bytes, floating; whole: the whole tune's SID writes,
    which its own must be as well). Returns (the cut tune, the whole
    tune's SID writes, what was cut)."""
    tc, log, _, info = cut_pages(t, song, frames, name, after)
    if whole is not None and log != whole:
        raise Refused(f"{name}: as its init leaves it, song {song} plays differently: it can't be"
                      " cut after its init")
    plays_as(tc, log, song, frames, name)
    return tc, log, info


def plays_as(tc, log, song, frames, name):
    """the cut tune tc plays as log says (the whole tune's SID writes), or
    Refused"""
    import sidreloc as R
    try:
        s2 = R.play_run(R.TraceSim(tc), tc, song, frames)
        same = s2.sid_log == log
    except Exception:
        s2, same = None, False
    if not same:
        b_ = s2.sid_log if s2 else []
        k = next((i for i, (x, y) in enumerate(zip(log, b_)) if x != y), min(len(log), len(b_)))
        fr = log[k][0] if k < len(log) else '?'
        raise Refused(f"{name}: cut to song {song}, it plays differently from frame {fr} (an address"
                      " in it is made in a way the cut can't follow): this tune can't be cut")


def cut_best(t, song, frames, name):
    """-cut: the plain cut (cut_pages); if that is over TUNE_MAX, the cut
    of the tune as its init leaves it (after_init), taken if it fits and
    plays as the whole tune; else the plain one, which must play as the
    whole tune too (as SID-SLM decides: the second try only for a cut
    over 4,096 bytes, before trying it out). Returns (the cut tune, what
    was cut)."""
    tc, whole, _, info = cut_pages(t, song, frames, name)
    if len(tc['data']) > TUNE_MAX:
        try:
            t2, ai = after_init(t, song, name)
            tc2, _, info2 = cut_song(t2, song, frames, name, after=ai['stub'], whole=whole)
            if len(tc2['data']) <= TUNE_MAX:
                return tc2, dict(info2, after=ai, of=len(t['data']),
                                 of_pages=((t['end'] - 1) >> 8) - (t['load'] >> 8) + 1)
        except Refused:
            pass
    plays_as(tc, whole, song, frames, name)
    return tc, info


STUB_MAX = 255                  # after_init's stub: within a page (SID-SLM's length a byte)


def after_init(t, song, name, sim=None):
    """The tune as its init leaves it, a tune of its own (cut_best's
    second try): from the lower of its first page and the lowest page
    init wrote ($0200 on, I/O left out) to the higher of its last page
    and the highest init wrote; then on the page after that a stub, its
    init: each zero page byte init wrote (2-255) put back as it left it
    (lda #v : sta zp), init's SID writes in their order (lda #v : sta
    $d4rr) and CIA 1's timer A latch if it isn't 0 then, then rts. Play
    is the tune's. Refused if the stub is over a page, or the tune would
    reach $D000-$DFFF or past $FFFF. sim: the simulator's class (the
    tests': trial.asm's model). Returns (the tune, dict(stub=(its first
    byte, past its last), its parts' counts))."""
    lo, hi = t['load'], t['end']
    s = (sim or StripSim)(t)
    try:
        s.call(t['init'], a=song - 1, limit=5_000_000)
    except Exception as ex:
        raise Refused(f"{name}: its init doesn't run in the simulator ({ex})")
    wrote = set(s.writes)                   # (outside the tune, the stack left out)
    pages = {a >> 8 for a in wrote if a >= 0x200 and not 0xd000 <= a < 0xe000}
    t2lo = min(pages | {lo >> 8})
    sp = max(pages | {(hi - 1) >> 8}) + 1   # the stub's page
    if sp > 0xff or (t2lo <= 0xdf and sp >= 0xd0):
        raise Refused(f"{name}: as its init leaves it, it would reach "
                      + ("past $FFFF" if sp > 0xff else "$D000-$DFFF") + ": it can't be cut after its init")
    zp = sorted(a for a in wrote if 2 <= a < 0x100)
    stub = bytearray()
    for a in zp:
        stub += bytes([0xa9, s.mem[a], 0x85, a])
    for _, r, v in s.sid_log:
        stub += bytes([0xa9, v, 0x8d, r, 0xd4])
    cia = bool(s.mem[0xdc04] | s.mem[0xdc05])     # (as trial.asm sees it: the latch not 0)
    if cia:
        stub += bytes([0xa9, s.mem[0xdc04], 0x8d, 0x04, 0xdc, 0xa9, s.mem[0xdc05], 0x8d, 0x05, 0xdc])
    stub += b'\x60'
    if len(stub) > STUB_MAX:
        raise Refused(f"{name}: what its init sets up takes {len(stub)} bytes to set again, over a page:"
                      " it can't be cut after its init")
    load = lo if t2lo == lo >> 8 else t2lo << 8
    sa = sp << 8
    mem = bytearray(s.mem)
    mem[sa:sa + len(stub)] = stub
    t2 = dict(t, load=load, end=sa + len(stub), data=bytes(mem[load:sa + len(stub)]), init=sa)
    return t2, dict(stub=(sa, sa + len(stub)), zp=len(zp), sid=len(s.sid_log), cia=cia,
                    pages=sorted(p for p in pages if not lo >> 8 <= p <= (hi - 1) >> 8))


def pack(keep, anchor):
    """the kept pages' new pages, in their order and together: from the
    first's (anchor False), or round the longest run of pages that follow
    one another, whose first keeps its place"""
    j, best, i = 0, 0, 0
    while anchor and i < len(keep):
        k = i
        while k + 1 < len(keep) and keep[k + 1] == keep[k] + 1:
            k += 1
        if k - i + 1 > best:
            j, best = i, k - i + 1
        i = k + 1
    return {p: keep[j] + n - j for n, p in enumerate(keep)}


def cut_pages(t, song, frames, name, after=None):
    """The tune cut down to one song (-cut): the pages of it the song
    runs, reads or writes in frames play calls, and the pages of the code
    its branches could reach (sidreloc.static_walk), packed together in
    their order from the first; within them, from the first such byte to
    the last. Every address byte into the tune (sidreloc's trace and
    static marks, and the page a compare names: sidreloc.cmp_marks)
    moves with its page; one whose page went, but whose next page stayed
    (a table's base just below what is used of it), goes to the page
    before the next one's, and a compare's page past a kept one (a copy
    loop's end) to the page after that one's. Where an address is made by
    adding pages to such a byte, every page from the byte's own to the one
    reached is kept, so the sum lands on the same data. Then the cut tune is played beside
    the whole one (cut_song). after: (first, past the last) of after_init's
    stub: its page left out, the pages packed round their longest run
    (pack), the stub put just after the last byte kept (its address bytes
    moved as the rest), and init there. Returns (the cut tune, the whole
    one's SID writes, the pages' map (old page: new), what was cut)."""
    import sidreloc as R
    lo, hi = t['load'], t['end']

    class CutSim(R.TraceSim):
        """the trace, noting each byte of the tune used"""
        def __init__(self, t):
            super().__init__(t)
            self.used = set()
            self.hook_from = 0              # (every read: the tune's own too)
            self.read_hook = self.rd

        def rd(self, a):
            if lo <= a < hi:
                self.used.add(a)
            return self.io(a) if a >= 0xd000 else None

        def _wh(self, a, v):
            if lo <= a < hi:
                self.used.add(a)
            super()._wh(a, v)

        def step(self):
            pc, m = self.pc, self.mem
            if lo <= pc < hi:
                op = m[pc]
                self.used.update(range(pc, pc + LEN.get(op, 1)))
                if op == 0x6c:              # jmp (vector): its two bytes
                    p = m[(pc + 1) & 0xffff] | m[(pc + 2) & 0xffff] << 8
                    self.used.update((p, (p & 0xff00) | ((p + 1) & 0xff)))
            return super().step()
    try:
        s = R.play_run(CutSim(t), t, song, frames)
    except Exception as ex:
        raise Refused(f"{name}: it doesn't run in the simulator ({ex})")
    outside = sorted(a for a in s.outside if a not in s.writes)
    if outside:
        raise Refused(f"{name} calls code outside itself (${outside[0]:04X}...): the KERNAL or BASIC"
                      " ROM, which are out while the loader runs")
    smarks, scode = R.static_walk(t, s.code)
    used = set(s.used)
    for a in scode:
        used.update(range(a, a + LEN.get(t['data'][a - lo], 1)))
    used = {a for a in used if lo <= a < hi}
    pages = set(range(lo >> 8, ((hi - 1) >> 8) + 1))
    if after:                               # (the stub: floating, not a page of its own)
        used = {a for a in used if a >> 8 != after[0] >> 8}
        pages.discard(after[0] >> 8)
    keep = {a >> 8 for a in used}
    for o, p in s.spans:                    # an address made from a byte by adding pages
        v = t['data'][o - lo]               # to it (lda tab,x : adc #2): every page from
        if v in pages and v != p:           # the byte's own to the one reached stays
            keep |= set(range(min(v, p), max(v, p) + 1)) & pages
    keep = sorted(keep)
    first, last = min(used), max(used)
    nstub = after[1] - after[0] if after else 0

    def fits(pm):
        """every page $02-$FF, none $D0-$DF; the stub too"""
        if any(not 2 <= v <= 0xff or 0xd0 <= v <= 0xdf for v in pm.values()):
            return False
        e = (pm[last >> 8] << 8 | (last & 0xff)) + 1    # (the stub's first byte)
        return e + nstub <= 0x10000 and not (e < 0xe000 and e + nstub > 0xd000)
    pmap = pack(keep, bool(after))
    if after and not fits(pmap):
        pmap = pack(keep, False)
        if not fits(pmap):
            raise Refused(f"{name}: cut after its init, it would reach $D000-$DFFF or past $FFFF")
    new = lambda a: pmap[a >> 8] << 8 | (a & 0xff)
    nf = new(first)
    data = bytearray(new(last) + 1 - nf + nstub)
    for p in keep:
        a0, a1 = max(p << 8, first), min((p + 1) << 8, last + 1)
        data[new(a0) - nf:new(a0) - nf + a1 - a0] = t['data'][a0 - lo:a1 - lo]
    if after:                               # the stub, just after the last byte kept
        data[new(last) + 1 - nf:] = t['data'][after[0] - lo:after[1] - lo]
        stubat = lambda a: new(last) + 1 + a - after[0]
    marks = s.marks | smarks
    ends = R.cmp_marks(t, s.cmps, marks)    # a compare's page: an end, past a kept page
    for a in marks | ends:
        if first <= a <= last and a >> 8 in pmap:
            i = new(a) - nf
        elif after and after[0] <= a < after[1]:
            i = stubat(a) - nf
        else:
            continue
        v = data[i]
        if v in pmap:
            data[i] = pmap[v]
        elif a in ends and v - 1 in pmap:
            data[i] = pmap[v - 1] + 1
        elif v + 1 in pmap:
            data[i] = pmap[v + 1] - 1
    out = lambda a: (stubat(a) if after and after[0] <= a < after[1] else
                     new(a) if lo <= a < hi else a)     # (a play routine init built elsewhere stays)
    tc = dict(t, load=nf, end=nf + len(data), data=bytes(data), init=out(t['init']),
              play=out(t['play']))
    return tc, s.sid_log, pmap, dict(of=len(t['data']), pages=len(keep),
                                     of_pages=((hi - 1) >> 8) - (lo >> 8) + 1, frames=frames)


def strip(path, song=None, frames=15000, cut=False):
    t = F.read(path)
    name = os.path.basename(path)
    if t['rsid']:
        raise Refused(f"{name} is an RSID tune: it sets up its own interrupts, which the loader"
                      " owns while it runs")
    if not t['play']:
        raise Refused(f"{name} has no play routine: its init sets up its own interrupt")
    song = t['start'] if song is None else song
    if not 1 <= song <= max(1, t['songs']):
        raise Refused(f"{name}: no song {song} (it has {t['songs']})")
    cutinfo = None
    if cut:
        t, cutinfo = cut_best(t, song, frames, name)
    try:
        s = run(t, song, frames)
    except Exception as ex:
        raise Refused(f"{name}: it doesn't run in the simulator ({ex})")
    outside = sorted(a for a in s.outside if a not in s.writes)
    if outside:
        raise Refused(f"{name} calls code outside itself (${outside[0]:04X}...): the KERNAL or BASIC"
                      " ROM, which are out while the loader runs")
    bad_port = sorted(v for v in s.port_values if io_out(v))
    if bad_port:
        raise Refused(f"{name} banks I/O out (it writes ${bad_port[0]:02X} to $01); the loader's"
                      " interrupt could come while it is")
    # (an init that clears $d400-$d47f through the mirrors is harmless)
    if t['sid2'] or t['sid3'] or s.mirror_play:
        extra = min(s.mirror_play) if s.mirror_play else (t['sid2'] or t['sid3']) << 4 | 0xd000
        raise Refused(f"{name} is for more than one SID chip (it plays ${extra:04X} as well); a C64"
                      " has one, and those writes would reach it too")
    zp = sorted(a for a in s.writes if 2 <= a < 0x100)
    clash = [a for a in zp if a < 0x10]
    if clash:
        raise Refused(f"{name} uses the loader's zero page (${clash[0]:02X}; the loader has $02-$0F)")
    if any(a >= 0x180 for a in s.stack_data):
        raise Refused(f"{name} stores into the stack page (${max(s.stack_data):04X})")
    # the stores to patch
    data = bytearray(t['data'])
    patched = []
    for pc, addrs in sorted(s.stores.items()):
        hit = [a for a in addrs if harmful(a)]
        if not hit:
            continue
        if any(not harmful(a) for a in addrs):
            raise Refused(f"{name}: the store at ${pc:04X} writes both ${hit[0]:04X} and memory it"
                          " needs; it can't be taken out")
        if not t['load'] <= pc < t['end']:
            raise Refused(f"{name}: a store to ${hit[0]:04X} from code it built at ${pc:04X};"
                          " it can't be patched")
        op = data[pc - t['load']]
        if op in INDIRECT:
            raise Refused(f"{name} stores to ${hit[0]:04X} through a pointer (at ${pc:04X})")
        n = LEN.get(op, 0)
        if n not in (2, 3):
            raise Refused(f"{name}: an odd store at ${pc:04X} (opcode ${op:02X})")
        i = pc - t['load']
        data[i] = 0x80                      # nop #imm: no read, no flags
        if n == 3:
            data[i + 2] = 0xea              # and a nop
        patched.append((pc, min(hit), max(hit)))
    # the patched tune: none of those stores, the same SID writes
    try:
        s2 = run(t, song, frames, bytes(data))
    except Exception as ex:
        raise Refused(f"{name}: patched, it no longer runs ({ex})")
    left = sorted(a for a in s2.writes if harmful(a))
    if left:
        raise Refused(f"{name}: still writes ${left[0]:04X} once patched")
    if s2.sid_log != s.sid_log:
        raise Refused(f"{name}: patched, it plays differently (it needed what was taken out)")
    # its rate: once a frame, or CIA 1 timer A
    cia = F.cia_timed(t, song)
    ntsc_tune = t['clock'] == 'NTSC'
    if cia:
        latch = s.mem[0xdc04] | s.mem[0xdc05] << 8 if (0xdc04 in s.writes or 0xdc05 in s.writes) else 0
        latch = latch or DEFAULT_LATCH
        hz = (NTSC_HZ if ntsc_tune else PAL_HZ) / (latch + 1)
    else:
        latch = None
        hz = NTSC_FPS if ntsc_tune else PAL_FPS
    per_pal = round(312 * 64 * PAL_FPS / hz)
    per_ntsc = round(263 * 64 * NTSC_FPS / hz)
    if per_pal < 312 * 64 // 8:
        raise Refused(f"{name} plays {hz:.0f} times a second: more than 8 a frame")
    if max(per_pal, per_ntsc) > 0xffff:
        raise Refused(f"{name} plays {hz:.1f} times a second: 16 at least (its timer is too slow)")
    ws = [r for r in F.ranges(sorted(a for a in s.writes if 0x200 <= a < 0xd000 or a >= 0xe000))
          if not (t['load'] <= r[0] and r[1] <= t['end'])]
    # can it move? (the patched tune: trace it, try a move, keep the bytes)
    import sidreloc as R
    tp = dict(t, data=bytes(data))
    relocs, reloc_why = None, None
    try:
        traced = R.trace(tp, song, frames, player=slp_player(t['load'], tp['data'], t['init'], t['play']))
        to = R.test_target(tp, traced[1])
        if to is None:
            raise R.Unmovable("there is no room to try a move")
        R.relocate(tp, to, song, frames, traced)
        relocs = sorted(a - t['load'] for a in traced[0])
    except R.Unmovable as ex:
        reloc_why = str(ex)
    return dict(path=path, name=t['name'], author=t['author'], released=t['released'],
                load=t['load'], data=bytes(data), init=t['init'], play=t['play'], song=song,
                songs=t['songs'], clock=t['clock'], cia=cia, latch=latch, hz=hz,
                per_pal=per_pal, per_ntsc=per_ntsc, play_cycles=s.worst, play_clk=s.worst_clk,
                zp=zp, workspace=ws,
                patched=patched, frames=frames, relocs=relocs, reloc_why=reloc_why, cut=cutinfo,
                flags=(1 if not ntsc_tune else 0) | (2 if t['clock'] in ('NTSC', 'PAL/NTSC') else 0)
                | (4 if cia else 0) | (8 if relocs is not None else 0))


def game_ok(m, claims=((0xe000, 0xfc00),), name='the module'):
    """can it play beside a module? (None, or why not; a tune that
    can move is moved out of its way). claims: the module's memory, [lo, hi)
    ranges; zero page by the standard (MODULES.md): the module's $10-$8F, of
    which $70-$7F is the music player's and a tune's to use"""
    z = [a for a in m['zp'] if GAME_ZP[0] <= a < GAME_ZP[1] and not MUSIC_ZP[0] <= a < MUSIC_ZP[1]]
    if z:
        return (f"it uses zero page ${z[0]:02X}, the module's (a tune may use ${MUSIC_ZP[0]:02X}-"
                f"${MUSIC_ZP[1] - 1:02X} of its $10-$8F)")
    end = m['load'] + len(m['data'])
    for lo, hi in ([] if m.get('relocs') is not None else [(m['load'], end)]) + m['workspace']:
        for clo, chi in claims:
            if lo < chi and hi > clo:
                return f"it sits in {name}'s memory (${clo:04X}-${chi - 1:04X})"
    if abs(m['per_pal'] - 312 * 64) > 312 * 64 // 50:
        return f"it plays {m['hz']:.0f} times a second; a module plays music once a frame"
    if m['play_clk'] > GAME_PLAY_MAX:
        return (f"its play call takes up to {m['play_clk']} cycles; a module's frame has"
                f" room for {GAME_PLAY_MAX}")
    return None


def slp_player(load, data, init, play):
    """True for a tune in SlopLoad's own player (music/player.asm): its
    jump table at the start of a page (init, play, stop, then the flags
    byte), init and play its first two jumps, "SLP1" after the flags. At
    $C000 a module's kit finds its stop and flags where it looks ($C006,
    $C009): voice 3 for the module's effects, the NTSC pitch table"""
    return (load & 255 == 0 and init == load and play == load + 3 and len(data) >= 14
            and data[0] == data[3] == data[6] == 0x4c and bytes(data[10:14]) == b'SLP1')


def write_slm(path, m):
    zp = bytearray(32)
    for a in m['zp']:
        zp[a >> 3] |= 1 << (a & 7)
    txt = lambda s: s.encode('latin-1', 'replace')[:32].ljust(32, b'\0')
    out = (b'SLM2' + struct.pack('<HHHHBBHHH', m['load'], len(m['data']), m['init'], m['play'],
                                  m['song'] - 1, m['flags'], m['per_pal'], m['per_ntsc'],
                                  min(65535, m['play_clk']))
           + bytes(zp) + bytes([len(m['workspace'])])
           + b''.join(struct.pack('<HH', lo, hi) for lo, hi in m['workspace'])
           + struct.pack('<H', len(m['relocs'] or [])) + b''.join(struct.pack('<H', r) for r in m['relocs'] or [])
           + txt(m['name']) + txt(m['author']) + txt(m['released']) + m['data'])
    open(path, 'wb').write(out)


def read_slm(path):
    d = open(path, 'rb').read()
    if d[:4] not in (b'SLM1', b'SLM2'):
        raise Refused(f"{path}: not a .slm file")
    try:
        t = _read_slm(path, d)
    except (struct.error, IndexError):
        t = None
    if t is None or len(t['data']) != t['n']:
        raise Refused(f"{path}: a .slm cut short")
    del t['n']
    return t


def _read_slm(path, d):
    load, n, init, play, song, flags, pp, pn, pc = struct.unpack('<HHHHBBHHH', d[4:20])
    if d[:4] == b'SLM1':                # (instructions then: about 3.4 cycles each, so 4)
        pc = min(65535, pc * 4)
    zp = [a for a in range(256) if d[20 + (a >> 3)] >> (a & 7) & 1]
    k = d[52]
    ws = [struct.unpack('<HH', d[53 + 4 * i:57 + 4 * i]) for i in range(k)]
    o = 53 + 4 * k
    nr = struct.unpack('<H', d[o:o + 2])[0]
    relocs = list(struct.unpack(f'<{nr}H', d[o + 2:o + 2 + 2 * nr])) if flags & 8 else None
    o += 2 + 2 * nr
    txt = lambda b: b.split(b'\0')[0].decode('latin-1')
    return dict(path=path, name=txt(d[o:o + 32]), author=txt(d[o + 32:o + 64]), n=n,
                released=txt(d[o + 64:o + 96]), load=load, data=d[o + 96:o + 96 + n], init=init,
                play=play, song=song + 1, flags=flags, per_pal=pp, per_ntsc=pn, play_clk=pc,
                play_cycles=None,
                zp=zp, workspace=[tuple(w) for w in ws], cia=bool(flags & 4), relocs=relocs,
                reloc_why=None if relocs is not None else "stripped without moving",
                hz=PAL_FPS * 312 * 64 / pp, patched=[], clock=('NTSC' if not flags & 1 else 'PAL'))


def load_music(path, song=None):
    """a .sid (stripped now, or found stripped in the cache) or a .slm
    (stripped before)"""
    if path.lower().endswith('.slm'):
        return read_slm(path)
    hit = cache_get(path, song)
    if hit:
        return hit
    m = strip(path, song)
    cache_put(path, song, m)
    return m


# Stripping a .sid runs its tune for 15,000 frames, three times over
# (about 20 seconds); what comes of it depends only on the file, the song
# and this code. So it is kept in ~/.cache/slopload/sid (XDG_CACHE_HOME),
# by the file's SHA-256, the song and the code's, and found there the next
# time. A refusal isn't kept (it is quick to find again); a cache that
# can't be written is no cache.
def cache_name(path, song):
    import hashlib
    h = hashlib.sha256(open(path, 'rb').read())
    for src in ('sidstrip.py', 'sidfile.py', 'sidreloc.py'):
        h.update(open(os.path.join(HERE, src), 'rb').read())
    base = os.environ.get('XDG_CACHE_HOME') or os.path.join(os.path.expanduser('~'), '.cache')
    return os.path.join(base, 'slopload', 'sid', f"{h.hexdigest()[:40]}-{song or 0}.json")


def cache_get(path, song):
    import json
    try:
        c = json.load(open(cache_name(path, song)))
    except (OSError, ValueError):
        return None
    try:
        c['data'] = bytes.fromhex(c['data'])
        c['workspace'] = [tuple(w) for w in c['workspace']]
        c['patched'] = [tuple(p) for p in c['patched']]
        c['path'] = path
    except (KeyError, TypeError, ValueError):
        return None
    return c


def cache_put(path, song, m):
    import json
    import tempfile
    try:
        name = cache_name(path, song)
        os.makedirs(os.path.dirname(name), exist_ok=True)
        c = dict(m, data=bytes(m['data']).hex())
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(name), suffix='.tmp')
        with os.fdopen(fd, 'w') as fh:
            json.dump(c, fh)
        os.replace(tmp, name)
    except (OSError, TypeError, ValueError):
        pass


def report(m):
    end = m['load'] + len(m['data'])
    print(f"{m['name']} / {m['author']} / {m['released']}")
    print(f"  song {m['song']} of {m.get('songs', '?')}, ${m['load']:04X}-${end - 1:04X}"
          f" ({len(m['data'])} bytes), init ${m['init']:04X}, play ${m['play']:04X}")
    c = m.get('cut')
    if c and c.get('after'):
        a = c['after']
        print(f"  cut to this song as its init leaves it: {len(m['data'])} of the tune's {c['of']} bytes,"
              f" the {c['pages']} pages the song uses in {c['frames']} play calls (and its code could"
              f" reach), packed together, and an init of {a['stub'][1] - a['stub'][0]} bytes that sets"
              f" again what the tune's init set ({a['zp']} zero page bytes, {a['sid']} SID writes"
              + (", the CIA's timer" if a['cia'] else "") + "); plays the same")
    elif c:
        print(f"  cut to this song: {len(m['data'])} of the tune's {c['of']} bytes, the {c['pages']}"
              f" of its {c['of_pages']} pages the song uses in {c['frames']} play calls (and its code"
              " could reach), packed together; plays the same")
    if len(m['data']) > TUNE_MAX:
        more = (": -cut keeps only this song's part" if not c and (m.get('songs') or 1) > 1 else "")
        print(f"  over {TUNE_MAX} bytes: SlopLoad 64 takes {TUNE_MAX} at most{more}")
    rate = (f"CIA timed ({m['hz']:.1f} a second)" if m['cia'] else
            f"once a frame ({m['hz']:.1f} a second)")
    clk = f"{m['play_clk']} cycles (jsr+rts included)" + (
        f", {m['play_cycles']} instructions" if m.get('play_cycles') is not None else "")
    print(f"  plays {rate}; every {m['per_pal'] / 64:.1f} raster lines on PAL,"
          f" {m['per_ntsc'] / 64:.1f} on NTSC; longest play call {clk}")
    print(f"  zero page: {' '.join(f'${a:02X}' for a in m['zp']) or 'none'}")
    if m['workspace']:
        print(f"  workspace: {', '.join(f'${a:04X}-${b - 1:04X}' for a, b in m['workspace'])}")
    for pc, lo, hi in m['patched']:
        what = f"${lo:04X}" + (f"-${hi:04X}" if hi != lo else "")
        print(f"  taken out: the store at ${pc:04X} (to {what})")
    if m['relocs'] is not None:
        print(f"  can be moved: {len(m['relocs'])} address bytes (a test move plays the same)")
    else:
        print(f"  plays only where it is: {m['reloc_why']}")
    why = game_ok(m)
    print(f"  with the picture and music modes: yes; with a module: {'yes' if not why else 'no, ' + why}")


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    try:
        song = int(argv[argv.index('-song') + 1]) if '-song' in argv else None
        frames = int(argv[argv.index('-frames') + 1]) if '-frames' in argv else 15000
    except (ValueError, IndexError):
        print("sidstrip: -song and -frames need a number", file=sys.stderr)
        return 1
    pos = [a for i, a in enumerate(argv) if not a.startswith('-') and (i == 0 or argv[i - 1] not in ('-song', '-frames'))]
    if not pos:
        print(__doc__)
        return 1
    try:
        m = strip(pos[0], song, frames, cut='-cut' in argv)
    except (Refused, F.Bad) as ex:
        print(f"sidstrip: {ex}", file=sys.stderr)
        return 1
    except OSError as ex:
        print(f"sidstrip: {pos[0]}: {ex.strerror}", file=sys.stderr)
        return 1
    report(m)
    if len(pos) > 1:
        write_slm(pos[1], m)
        print(f"  wrote {pos[1]}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
