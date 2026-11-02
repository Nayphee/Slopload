#!/usr/bin/env python3
"""SID tunes (PSID/RSID files) for SlopLoad: read one, and run it in the
6502 simulator to see what it needs.

    sidfile.py tune.sid [-song N] [-frames 3000]

check() calls the tune's init (A = song - 1) and then its play routine
once a frame, in tests/sim6502.py with plausible answers for the raster,
the SID's oscillator 3 and the CIA timers, and records:
  - every store outside the tune's own bytes: zero page, other RAM
    (its workspace), the SID's registers, and any to the VIC or the
    CIAs (the loader owns the CIAs: a tune that writes their interrupt
    control can't play beside it);
  - every instruction run outside the tune's bytes (a call into the
    KERNAL or BASIC: their ROMs are out while the loader runs);
  - the cycles of init and of the longest play call (Sim.cycles counts
    instructions, for the limits; TuneSim.clk counts the real NMOS
    cycles, page crossings and taken branches included: the raster and
    the CIA timers read from it, and play calls are a PAL frame of it
    apart);
  - for a tune timed by CIA 1 timer A (its speed bit), the timer latch
    init sets, so its play rate is known.
"""
import os
import random
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tests'))
from sim6502 import Sim, DECODE  # noqa: E402

PAL_FRAME = 19656
PAL_HZ = 985248


class Bad(Exception):
    pass


# real NMOS 6510 cycles: opcode -> (base, what can add one: 'x'/'y'/'iy' an
# indexed read crossing a page, 'b' a branch: +1 taken, +1 more to another page)
_RMW = {'asl', 'lsr', 'rol', 'ror', 'inc', 'dec', 'slo', 'rla', 'sre', 'rra', 'dcp', 'isc'}
_STORE = {'sta', 'stx', 'sty', 'sax'}
_READ = {'imm': 2, 'zp': 3, 'zpx': 4, 'zpy': 4, 'abs': 4, 'abx': 4, 'aby': 4, 'izx': 6, 'izy': 5}
_WRITE = {'zp': 3, 'zpx': 4, 'zpy': 4, 'abs': 4, 'abx': 5, 'aby': 5, 'izx': 6, 'izy': 6}
_MODIFY = {'zp': 5, 'zpx': 6, 'abs': 6, 'abx': 7, 'aby': 7, 'izx': 8, 'izy': 8}
_ONE = {'pha': 3, 'php': 3, 'pla': 4, 'plp': 4, 'rts': 6, 'rti': 6, 'brk': 7, 'dop': 2, 'top': 4}
CYCLES = {}
for _op, (_mn, _mode) in DECODE.items():
    if _mode == 'rel':
        CYCLES[_op] = (2, 'b')
    elif _mn == 'jmp':
        CYCLES[_op] = (3 if _mode == 'abs' else 5, None)
    elif _mn == 'jsr':
        CYCLES[_op] = (6, None)
    elif _mode in ('imp', 'acc'):
        CYCLES[_op] = (_ONE.get(_mn, 2), None)
    elif _mn in _RMW:
        CYCLES[_op] = (_MODIFY[_mode], None)
    elif _mn in _STORE:
        CYCLES[_op] = (_WRITE[_mode], None)
    else:
        CYCLES[_op] = (_READ[_mode], {'abx': 'x', 'aby': 'y', 'izy': 'iy'}.get(_mode))
# a branch's condition, from the flags
TAKEN = {0x10: lambda s: not s.n, 0x30: lambda s: s.n, 0x50: lambda s: not s.v,
         0x70: lambda s: s.v, 0x90: lambda s: not s.c, 0xb0: lambda s: s.c,
         0xd0: lambda s: not s.z, 0xf0: lambda s: s.z}


def read(path):
    d = open(path, 'rb').read()
    magic = d[:4]
    if magic not in (b'PSID', b'RSID'):
        raise Bad(f"{path}: not a SID file (no PSID/RSID at its start)")
    if len(d) < 0x76:
        raise Bad(f"{path}: not a SID file (too short for its header: {len(d)} bytes)")
    ver, off, load, init, play, songs, start = struct.unpack('>HHHHHHH', d[4:18])
    speed = struct.unpack('>I', d[18:22])[0]
    text = lambda a: d[a:a + 32].split(b'\0')[0].decode('latin-1').strip()
    flags = struct.unpack('>H', d[0x76:0x78])[0] if ver >= 2 and len(d) >= 0x78 else 0
    data = d[off:]
    if load == 0:
        if len(data) < 2:
            raise Bad(f"{path}: no tune in it (the data at {off} is {len(data)} bytes)")
        load = data[0] | data[1] << 8
        data = data[2:]
    if not data:
        raise Bad(f"{path}: no tune in it (nothing after its header)")
    if load + len(data) > 0x10000:
        raise Bad(f"{path}: its data runs past $FFFF (${load:04X}, {len(data)} bytes)")
    return dict(path=path, rsid=magic == b'RSID', version=ver, load=load, end=load + len(data),
                init=init or load, play=play, songs=songs, start=start or 1, speed=speed,
                flags=flags, name=text(0x16), author=text(0x36), released=text(0x56),
                data=data, basic=bool(flags & 2) if magic == b'RSID' else False,
                sid2=d[0x7a] if ver >= 3 and len(d) > 0x7a else 0,    # a second SID chip's page
                sid3=d[0x7b] if ver >= 4 and len(d) > 0x7b else 0,    # a third's
                clock={0: 'unknown', 1: 'PAL', 2: 'NTSC', 3: 'PAL/NTSC'}[(flags >> 2) & 3])


def cia_timed(t, song):
    """the song's speed bit: 1 = timed by CIA 1 timer A, 0 = once a frame"""
    bit = min(song - 1, 31)
    return bool(t['speed'] >> bit & 1)


class TuneSim(Sim):
    def __init__(self, t):
        super().__init__()
        self.t = t
        self.load(t['load'], t['data'])
        self.mem[0], self.mem[1] = 0x2f, 0x15   # the port as the loader has it: a tune that
                                                # saves $01 and puts it back writes this
        self.writes = {}                 # address -> count, outside the tune
        self.outside = set()             # pcs run outside the tune
        self.cia = {}                    # cia/vic register -> last value written
        self.clock = 0
        self.clk = 0                     # real cycles (step), for the raster and the timers
        self.hook_from = 0xd000
        self.read_hook = self.io
        self.rnd = random.Random(1)

    def io(self, a):
        if a == 0xd012:                  # the raster: moves with the cycles
            return (self.clk // 63) % 312 & 255
        if a == 0xd011:
            return 0x1b | (0x80 if (self.clk // 63) % 312 > 255 else 0)
        if a in (0xd41b, 0xd41c):        # oscillator 3, envelope 3
            return self.rnd.randrange(256)
        if a in (0xdc04, 0xdd04, 0xdc06, 0xdd06):
            return (65535 - self.clk) & 255
        if a in (0xdc05, 0xdd05, 0xdc07, 0xdd07):
            return ((65535 - self.clk) >> 8) & 255
        if 0xe000 <= a or 0xa000 <= a < 0xc000:
            return None                  # (RAM: what is there)
        return None

    def _wh(self, a, v):
        t = self.t
        if not (t['load'] <= a < t['end']) and not (0x100 <= a < 0x200):
            self.writes[a] = self.writes.get(a, 0) + 1
            if 0xd000 <= a < 0xd400 or 0xdc00 <= a < 0xde00:
                self.cia[a] = v

    def step(self):
        t = self.t
        m, pc = self.mem, self.pc
        cy = CYCLES.get(m[pc])
        if cy:
            c, more = cy
            if more == 'x':
                c += m[(pc + 1) & 0xffff] + self.x > 255
            elif more == 'y':
                c += m[(pc + 1) & 0xffff] + self.y > 255
            elif more == 'iy':
                c += m[m[(pc + 1) & 0xffff]] + self.y > 255
            elif more == 'b' and TAKEN[m[pc]](self):
                off = m[(pc + 1) & 0xffff]
                nxt = (pc + 2) & 0xffff
                c += 1 + (((nxt + off - (256 if off > 127 else 0)) ^ nxt) & 0xff00 != 0)
        else:
            c = 0
        if not (t['load'] <= pc < t['end']) and pc not in (0xfffe, 0xfffd):
            self.outside.add(pc)
        try:
            return super().step()
        finally:
            self.clk += c                # after it: a read in it sees the clock it began at


def check(t, song=None, frames=3000):
    """run init and frames play calls; what the tune touched and took"""
    song = song or t['start']
    if not 1 <= song <= max(1, t['songs']):
        raise Bad(f"{os.path.basename(t['path'])}: no song {song} (it has {t['songs']})")
    s = TuneSim(t)
    out = dict(song=song, errors=[], cia_timed=cia_timed(t, song))
    try:
        c0 = s.cycles
        s.call(t['init'], a=song - 1, limit=5_000_000)
        out['init_cycles'] = s.cycles - c0
    except Exception as ex:
        out['errors'].append(f"init: {ex}")
        out['init_cycles'] = None
    init_io = dict(s.cia)
    worst = 0
    if t['play'] and not out['errors']:
        for _ in range(frames):
            c0, k0 = s.cycles, s.clk
            try:
                s.call(t['play'], limit=200_000)
            except Exception as ex:
                out['errors'].append(f"play: {ex}")
                break
            worst = max(worst, s.cycles - c0)
            s.cycles = c0 + PAL_FRAME     # time passes between calls
            s.clk = k0 + PAL_FRAME
    out['play_cycles'] = worst
    w = s.writes
    out['zp'] = sorted(a for a in w if a < 0x100)
    out['ram'] = sorted(a for a in w if 0x200 <= a < 0xd000 or a >= 0xe000)
    out['sid'] = sorted(a for a in w if 0xd400 <= a < 0xd800)
    out['io'] = {a: v for a, v in s.cia.items()}
    out['init_io'] = init_io
    # code run outside the tune and outside memory it wrote (a tune may
    # copy its player elsewhere first): a call into a ROM that is out
    out['outside'] = sorted(a for a in s.outside if a not in w)
    out['port'] = sorted(a for a in w if a < 2)      # $00/$01: the tape motor is bit 5
    latch = None
    if 0xdc04 in init_io or 0xdc05 in init_io:
        latch = s.mem[0xdc04] | s.mem[0xdc05] << 8
    out['latch'] = latch
    return out


def ranges(addrs):
    """[(lo, hi_exclusive)] runs of consecutive addresses"""
    out = []
    for a in addrs:
        if out and a == out[-1][1]:
            out[-1][1] = a + 1
        else:
            out.append([a, a + 1])
    return [tuple(r) for r in out]


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    song = int(argv[argv.index('-song') + 1]) if '-song' in argv else None
    frames = int(argv[argv.index('-frames') + 1]) if '-frames' in argv else 3000
    t = read(argv[0])
    print(f"{t['name']} / {t['author']} / {t['released']}")
    print(f"  {'RSID' if t['rsid'] else 'PSID'} v{t['version']}, ${t['load']:04X}-${t['end'] - 1:04X}"
          f" ({len(t['data'])} bytes), init ${t['init']:04X}, play ${t['play']:04X},"
          f" {t['songs']} songs (start {t['start']}), {t['clock']}")
    r = check(t, song, frames)
    print(f"  song {r['song']}: {'CIA timed' if r['cia_timed'] else 'once a frame'}"
          + (f", timer latch ${r['latch']:04X}" if r['latch'] else ""))
    print(f"  init {r['init_cycles']} cycles, play at most {r['play_cycles']} cycles")
    print(f"  zero page: {' '.join(f'${a:02X}' for a in r['zp']) or 'none'}")
    print(f"  other RAM: {', '.join(f'${a:04X}-${b - 1:04X}' for a, b in ranges(r['ram'])) or 'none'}")
    if r['io']:
        print(f"  VIC/CIA writes: {', '.join(f'${a:04X}=${v:02X}' for a, v in sorted(r['io'].items()))}")
    if r['port']:
        print(f"  writes the processor port: {', '.join(f'${a:02X}' for a in r['port'])}")
    if r['outside']:
        print(f"  runs code outside itself: {', '.join(f'${a:04X}-${b - 1:04X}' for a, b in ranges(r['outside']))}")
    for e in r['errors']:
        print(f"  error: {e}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
