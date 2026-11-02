#!/usr/bin/env python3
"""
sim6502.py — run an assembled routine in a minimal 6502 simulator.

For testing pure computation (sorts, maths, table lookups) — no VIC/SID/
CIA emulation, no interrupts, no timing. Executes until a RTS with the
stack back at its starting level, or BRK, or a cycle limit.

Usage from Python:
    from sim6502 import Sim
    s = Sim()
    s.load(origin, data)          # bytes from asm6502.assemble
    s.mem[0xfb] = 5
    s.call(labels['multiply'], a=3, x=0, y=0)
    print(s.a, s.mem[0x00fc])

Usage from shell:
    python3 sim6502.py prog.asm entry_label [--set addr=val ...] [--show addr[:len] ...]
"""
import sys, argparse, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asm6502 import OPS, ILLEGAL, assemble

# opcode -> (mnemonic, mode)
DECODE = {}
for m, modes in list(OPS.items()) + [(k, v) for k, v in ILLEGAL.items() if k not in ('axs', 'asr')]:
    for mode, op in modes.items():
        DECODE[op] = (m, mode)
# the one-byte no-ops a 6510 passes over (a program's 65816 test uses $3a,
# which a 65816 takes for dec a)
for op in (0x1a, 0x3a, 0x5a, 0x7a, 0xda, 0xfa):
    DECODE.setdefault(op, ('nop', 'imp'))

class Sim:
    def __init__(self):
        self.mem = bytearray(65536)
        self.a = self.x = self.y = 0
        self.sp = 0xff
        self.pc = 0
        self.n = self.v = self.d = self.i = self.z = self.c = 0
        self.cycles = 0
        self.read_hook = None        # fn(addr) -> byte or None; lets tests model I/O reads
        self.hook_from = 0xd000      # (the hook sees reads from here up: lower it to model ROMs)
        self.write_hook = None       # fn(addr, value): called on every store to $d000-$dfff

    def load(self, origin, data):
        self.mem[origin:origin+len(data)] = data

    # ---- flags / stack helpers
    def setnz(self, v):
        v &= 0xff; self.z = int(v == 0); self.n = int(v >> 7); return v
    def push(self, v):
        self.mem[0x100 + self.sp] = v & 0xff; self.sp = (self.sp - 1) & 0xff
    def pull(self):
        self.sp = (self.sp + 1) & 0xff; return self.mem[0x100 + self.sp]
    def flags(self):
        return (self.n << 7) | (self.v << 6) | 0x20 | (self.d << 3) | (self.i << 2) | (self.z << 1) | self.c
    def setflags(self, p):
        self.n = p >> 7 & 1; self.v = p >> 6 & 1; self.d = p >> 3 & 1
        self.i = p >> 2 & 1; self.z = p >> 1 & 1; self.c = p & 1

    def _wh(self, a, v):
        if self.write_hook and 0xd000 <= a < 0xe000: self.write_hook(a, v)

    def rd16(self, addr):
        return self.mem[addr] | (self.mem[(addr + 1) & 0xffff] << 8)

    # ---- effective address
    def ea(self, mode):
        m = self.mem; pc = self.pc
        if mode == 'imm': self.pc += 1; return pc
        if mode == 'zp':  self.pc += 1; return m[pc]
        if mode == 'zpx': self.pc += 1; return (m[pc] + self.x) & 0xff
        if mode == 'zpy': self.pc += 1; return (m[pc] + self.y) & 0xff
        if mode == 'abs': self.pc += 2; return self.rd16(pc)
        if mode == 'abx': self.pc += 2; return (self.rd16(pc) + self.x) & 0xffff
        if mode == 'aby': self.pc += 2; return (self.rd16(pc) + self.y) & 0xffff
        if mode == 'izx': self.pc += 1; z = (m[pc] + self.x) & 0xff; return m[z] | (m[(z+1)&0xff] << 8)
        if mode == 'izy': self.pc += 1; z = m[pc]; return ((m[z] | (m[(z+1)&0xff] << 8)) + self.y) & 0xffff
        if mode == 'ind':
            self.pc += 2; p = self.rd16(pc)
            lo = m[p]; hi = m[(p & 0xff00) | ((p + 1) & 0xff)]   # page-wrap bug
            return lo | (hi << 8)
        if mode == 'rel': self.pc += 1; off = m[pc]; return (self.pc + (off - 256 if off > 127 else off)) & 0xffff
        raise ValueError(mode)

    def adc(self, v):
        if self.d:
            # decimal mode, good enough for score counters
            lo = (self.a & 15) + (v & 15) + self.c
            hi = (self.a >> 4) + (v >> 4)
            if lo > 9: lo += 6; hi += 1
            self.c = int(hi > 9)
            if self.c: hi += 6
            r = ((hi & 15) << 4) | (lo & 15)
            self.a = r; self.setnz(r); return
        r = self.a + v + self.c
        self.v = int((~(self.a ^ v) & (self.a ^ r) & 0x80) != 0)
        self.c = int(r > 255)
        self.a = self.setnz(r)

    def sbc(self, v):
        if self.d:
            lo = (self.a & 15) - (v & 15) - (1 - self.c)
            hi = (self.a >> 4) - (v >> 4)
            if lo < 0: lo += 10; hi -= 1
            self.c = int(hi >= 0)
            if hi < 0: hi += 10
            r = ((hi & 15) << 4) | (lo & 15)
            self.a = r; self.setnz(r); return
        self.adc(v ^ 0xff)

    def cmp_(self, r, v):
        d = r - v; self.c = int(d >= 0); self.setnz(d)

    def step(self):
        m = self.mem
        op = m[self.pc]; self.pc = (self.pc + 1) & 0xffff
        if op not in DECODE: raise RuntimeError(f"illegal opcode ${op:02x} at ${self.pc-1:04x}")
        mn, mode = DECODE[op]
        self.cycles += 1
        if mode in ('imp', 'acc') and mn not in ('dop', 'top'):
            a = None
        elif mn in ('dop', 'top'):
            a = None
        else:
            a = self.ea(mode)
        def g():
            if self.read_hook and a is not None and a >= self.hook_from:
                v = self.read_hook(a)          # called exactly once: hooks may model clear-on-read
                if v is not None: return v
            return m[a]
        if mn == 'lda': self.a = self.setnz(g())
        elif mn == 'ldx': self.x = self.setnz(g())
        elif mn == 'ldy': self.y = self.setnz(g())
        elif mn == 'sta': m[a] = self.a; self._wh(a, self.a)
        elif mn == 'stx': m[a] = self.x; self._wh(a, self.x)
        elif mn == 'sty': m[a] = self.y; self._wh(a, self.y)
        elif mn == 'tax': self.x = self.setnz(self.a)
        elif mn == 'tay': self.y = self.setnz(self.a)
        elif mn == 'txa': self.a = self.setnz(self.x)
        elif mn == 'tya': self.a = self.setnz(self.y)
        elif mn == 'tsx': self.x = self.setnz(self.sp)
        elif mn == 'txs': self.sp = self.x
        elif mn == 'pha': self.push(self.a)
        elif mn == 'pla': self.a = self.setnz(self.pull())
        elif mn == 'php': self.push(self.flags() | 0x10)
        elif mn == 'plp': self.setflags(self.pull())
        elif mn == 'adc': self.adc(g())
        elif mn == 'sbc': self.sbc(g())
        elif mn == 'cmp': self.cmp_(self.a, g())
        elif mn == 'cpx': self.cmp_(self.x, g())
        elif mn == 'cpy': self.cmp_(self.y, g())
        elif mn == 'inc': m[a] = self.setnz(m[a] + 1); self._wh(a, m[a])
        elif mn == 'dec': m[a] = self.setnz(m[a] - 1); self._wh(a, m[a])
        elif mn == 'inx': self.x = self.setnz(self.x + 1)
        elif mn == 'iny': self.y = self.setnz(self.y + 1)
        elif mn == 'dex': self.x = self.setnz(self.x - 1)
        elif mn == 'dey': self.y = self.setnz(self.y - 1)
        elif mn == 'and': self.a = self.setnz(self.a & g())
        elif mn == 'ora': self.a = self.setnz(self.a | g())
        elif mn == 'eor': self.a = self.setnz(self.a ^ g())
        elif mn == 'bit':
            v = g(); self.z = int((self.a & v) == 0); self.n = v >> 7; self.v = v >> 6 & 1
        elif mn in ('asl', 'lsr', 'rol', 'ror'):
            v = self.a if mode == 'acc' else m[a]
            if mn == 'asl': c = v >> 7; v = (v << 1) & 0xff
            elif mn == 'lsr': c = v & 1; v >>= 1
            elif mn == 'rol': c = v >> 7; v = ((v << 1) | self.c) & 0xff
            else: c = v & 1; v = (v >> 1) | (self.c << 7)
            self.c = c; v = self.setnz(v)
            if mode == 'acc': self.a = v
            else: m[a] = v; self._wh(a, v)
        elif mn == 'jmp': self.pc = a
        elif mn == 'jsr':
            ret = (self.pc - 1) & 0xffff
            self.push(ret >> 8); self.push(ret & 0xff); self.pc = a
        elif mn == 'rts':
            lo = self.pull(); hi = self.pull(); self.pc = ((hi << 8) | lo) + 1 & 0xffff
        elif mn == 'rti':
            self.setflags(self.pull()); lo = self.pull(); hi = self.pull(); self.pc = (hi << 8) | lo
        elif mn == 'brk': raise StopIteration('brk')
        # ---- illegal opcodes (stable subset)
        elif mn == 'lax': self.a = self.x = self.setnz(g())
        elif mn == 'sax': m[a] = self.a & self.x
        elif mn == 'sbx':
            r = (self.a & self.x) - g(); self.c = int(r >= 0); self.x = self.setnz(r)
        elif mn == 'dcp': m[a] = (m[a] - 1) & 0xff; self.cmp_(self.a, m[a])
        elif mn == 'isc': m[a] = (m[a] + 1) & 0xff; self.sbc(m[a])
        elif mn == 'slo':
            v = m[a]; self.c = v >> 7; m[a] = (v << 1) & 0xff; self.a = self.setnz(self.a | m[a])
        elif mn == 'rla':
            v = m[a]; c = v >> 7; m[a] = ((v << 1) | self.c) & 0xff; self.c = c; self.a = self.setnz(self.a & m[a])
        elif mn == 'sre':
            v = m[a]; self.c = v & 1; m[a] = v >> 1; self.a = self.setnz(self.a ^ m[a])
        elif mn == 'rra':
            v = m[a]; c = v & 1; m[a] = (v >> 1) | (self.c << 7); self.c = c; self.adc(m[a])
        elif mn == 'anc': self.a = self.setnz(self.a & g()); self.c = self.n
        elif mn == 'alr':
            v = self.a & g(); self.c = v & 1; self.a = self.setnz(v >> 1)
        elif mn == 'arr':
            v = self.a & g(); r = (v >> 1) | (self.c << 7); self.a = self.setnz(r)
            self.c = (r >> 6) & 1; self.v = ((r >> 6) ^ (r >> 5)) & 1
        elif mn == 'dop': self.pc = (self.pc + 1) & 0xffff
        elif mn == 'top': self.pc = (self.pc + 2) & 0xffff
        elif mn == 'nop': pass
        elif mn in ('bcc','bcs','beq','bne','bmi','bpl','bvc','bvs'):
            take = {'bcc': not self.c, 'bcs': self.c, 'beq': self.z, 'bne': not self.z,
                    'bmi': self.n, 'bpl': not self.n, 'bvc': not self.v, 'bvs': self.v}[mn]
            if take: self.pc = a
        elif mn == 'clc': self.c = 0
        elif mn == 'sec': self.c = 1
        elif mn == 'cld': self.d = 0
        elif mn == 'sed': self.d = 1
        elif mn == 'cli': self.i = 0
        elif mn == 'sei': self.i = 1
        elif mn == 'clv': self.v = 0
        else: raise RuntimeError(mn)

    def irq(self, addr, limit=2_000_000):
        """Enter an interrupt handler: push a return frame the way the CPU does
        (PC then flags) so the handler's RTI returns to the $fffe sentinel."""
        self.sp = 0xff
        self.push(0xff); self.push(0xfe); self.push(self.flags())
        self.pc = addr; start = self.cycles
        while self.cycles - start < limit:
            if self.pc == 0xfffe: return
            try: self.step()
            except StopIteration: return
        raise RuntimeError("cycle limit")

    def call(self, addr, a=0, x=0, y=0, limit=2_000_000):
        """JSR to addr with registers set; return when the matching RTS pops."""
        self.a, self.x, self.y = a, x, y
        self.sp = 0xff
        self.push(0xff); self.push(0xfd)     # fake return to $fffe
        self.pc = addr
        start = self.cycles
        while self.cycles - start < limit:
            if self.pc == 0xfffe: return
            try: self.step()
            except StopIteration: return
        raise RuntimeError("cycle limit")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source'); ap.add_argument('entry')
    ap.add_argument('--set', action='append', default=[], help='addr=val (hex ok), or label=val')
    ap.add_argument('--show', action='append', default=[], help='addr or addr:len or label:len')
    ap.add_argument('--a', type=lambda s: int(s, 0), default=0)
    ap.add_argument('--x', type=lambda s: int(s, 0), default=0)
    ap.add_argument('--y', type=lambda s: int(s, 0), default=0)
    args = ap.parse_args()
    origin, data, labels, _ = assemble(open(args.source).read())
    s = Sim(); s.load(origin, data)
    def resolve(t): return labels[t] if t in labels else int(t, 0)
    for kv in args.set:
        k, v = kv.split('='); s.mem[resolve(k)] = int(v, 0) & 0xff
    s.call(resolve(args.entry), args.a, args.x, args.y)
    print(f"a={s.a:02x} x={s.x:02x} y={s.y:02x} flags n{s.n}v{s.v}z{s.z}c{s.c}  ({s.cycles} instructions)")
    for sh in args.show:
        t, _, ln = sh.partition(':'); addr = resolve(t); ln = int(ln or 1)
        print(f"{t}: " + ' '.join(f"{b:02x}" for b in s.mem[addr:addr+ln]))

if __name__ == '__main__':
    main()
