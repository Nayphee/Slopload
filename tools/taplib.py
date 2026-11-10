"""TAP file reading/writing, the KERNAL's tape format, and the SlopLoad
turbo format (encoder and a model of the decoder, for checking).

Pulse lengths are in PAL cycles. A .tap (version 1) stores each as
cycles / 8 in one byte, or 0 + 24-bit cycles for long ones.
"""
import struct

PAL_HZ = 985248

# ---------------------------------------------------------------- TAP files

def tap_write(path, pulses, hires=False):
    """hires: every pulse as its exact cycle count (0 + 24 bits), for
    precompensation finer than the usual 8 cycles"""
    out = bytearray()
    for c in pulses:
        v = int(round(c / 8))
        if hires:
            c = int(round(c))
            out += bytes([0, c & 255, (c >> 8) & 255, (c >> 16) & 255])
        elif 1 <= v <= 255:
            out.append(v)
        else:                       # long pulse or pause
            c = int(c)
            out += bytes([0, c & 255, (c >> 8) & 255, (c >> 16) & 255])
    hdr = b'C64-TAPE-RAW' + bytes([1, 0, 0, 0]) + struct.pack('<I', len(out))
    open(path, 'wb').write(hdr + out)


def tap_read(path, phase=0):
    """the pulses (cycles) of a TAP file. Version 2 holds half-waves (as
    some captures write): two make a pulse, paired from the half-wave at
    phase (0 or 1)."""
    d = open(path, 'rb').read()
    if d[:12] != b'C64-TAPE-RAW':
        raise ValueError(f"{path}: not a TAP file")
    ver = d[12]
    if ver == 2:
        h = tap_values(d)[phase:]
        return [a + b for a, b in zip(h[0::2], h[1::2])]
    return tap_values(d)


def tap_values(d):
    ver = d[12]
    p = []
    i = 20
    while i < len(d):
        b = d[i]
        if b == 0:
            if ver >= 1:
                p.append(d[i + 1] | d[i + 2] << 8 | d[i + 3] << 16)
                i += 4
            else:
                p.append(256 * 8)
                i += 1
        else:
            p.append(b * 8)
            i += 1
    return p

# ---------------------------------------------------------------- KERNAL format

ROM_S, ROM_M, ROM_L = 0x30 * 8, 0x42 * 8, 0x56 * 8


def rom_byte(b):
    """One byte as the KERNAL writes it: marker, 8 bits lsb first, odd parity."""
    out = [ROM_L, ROM_M]
    par = 1
    for i in range(8):
        bit = (b >> i) & 1
        par ^= bit
        out += [ROM_M, ROM_S] if bit else [ROM_S, ROM_M]
    out += [ROM_M, ROM_S] if par else [ROM_S, ROM_M]
    return out


def rom_block(data, repeat):
    """Sync countdown, data, xor check, end marker."""
    sync = range(0x09, 0, -1) if repeat else range(0x89, 0x80, -1)
    out = []
    for s in sync:
        out += rom_byte(s)
    chk = 0
    for b in data:
        out += rom_byte(b)
        chk ^= b
    out += rom_byte(chk)
    out += [ROM_L, ROM_S]
    return out


def rom_file(header, data, leader=0x6A00):
    """A whole KERNAL file: header block twice, data block twice."""
    out = [ROM_S] * leader
    out += rom_block(header, False) + [ROM_S] * 79
    out += rom_block(header, True) + [ROM_S] * 79
    out += [ROM_S] * 0x1500
    out += rom_block(data, False) + [ROM_S] * 79
    out += rom_block(data, True) + [ROM_S] * 78
    return out


def rom_decode(pulses):
    """KERNAL blocks found: list of (first pulse, bytes incl. sync)."""
    def cls(c):
        t = c // 8
        if 0x24 <= t <= 0x36:
            return 'S'
        if 0x37 <= t <= 0x4a:
            return 'M'
        if 0x4b <= t <= 0x64:
            return 'L'
        return '?'
    c = ''.join(cls(x) for x in pulses)
    blocks = []
    i = 0
    while True:
        j = c.find('LM', i)
        if j < 0:
            break
        bs = []
        k = j
        while c[k:k + 2] == 'LM':
            bits = []
            for b in range(9):
                pr = c[k + 2 + 2 * b:k + 4 + 2 * b]
                if pr == 'SM':
                    bits.append(0)
                elif pr == 'MS':
                    bits.append(1)
                else:
                    break
            if len(bits) < 9:
                break
            bs.append(sum(bits[b] << b for b in range(8)))
            k += 20
        if len(bs) > 9:
            blocks.append((j, k, bs))
        i = max(k, j + 2)
    return blocks

# ---------------------------------------------------------------- turbo format
#
# A pulse of class k lasts (4 + 2k) * h cycles and carries 2 bits (the
# class number), most significant pair first. Block: pilot of class 0,
# one class 3 sync, bytes. See src/core.asm for the header layout.

TB_START = 11
CAL_START, CAL_END = 16, 144      # stage 1: 128 pulses, once
CAL_LEN = 64                       # the core: 64 pulses, then again
H_DEF = 122
HEADER_SEED = 0xa5

F_GAMEREADY = 0x01
F_MAINEND = 0x02
F_CHAIN = 0x04           # a chain's second module is in: switch to it (src/chain.asm)
F_LAST = 0x80


F_PREFIX = 0x40          # header flags: bits 4-5 = pulse set m - 2, bit 6 prefix code
F_UNDERIO = 0x08         # ... bit 3: the block stores into $d000-$dfff


def pulse(k, h, m=4):
    """class k in pulse set m: (m + 2k) quanta of h cycles"""
    return (m + 2 * k) * h


def prefix_classes(data, key=0):
    """The prefix code (class 0 = 1, 1 = 01, 2 = 001, 3 = 000) of some
    bytes, msb first. The last code is finished with spare bits, which
    the decoder takes as the start of a byte it never completes."""
    bits = []
    for b in data:
        b ^= key
        bits += [(b >> i) & 1 for i in range(7, -1, -1)]
    out = []
    i = 0
    n = len(bits)
    while i < n:
        if bits[i]:
            out.append(0)
            i += 1
        elif i + 1 < n and bits[i + 1]:
            out.append(1)
            i += 2
        elif i + 1 >= n:
            out.append(1)         # "0" then a spare 1
            i += 1
        elif i + 2 < n and bits[i + 2]:
            out.append(2)
            i += 3
        elif i + 2 >= n:
            out.append(2)         # "00" then a spare 1
            i += 2
        else:
            out.append(3)
            i += 3
    return out


def best_prefix_key(data):
    """Xor key giving more 1 bits (a 1 is the shortest pulse alone)."""
    key = 0
    for bit in range(8):
        ones = sum((b >> bit) & 1 for b in data)
        if ones * 2 < len(data):
            key |= 1 << bit
    return key


def turbo_bytes(data, h, key=0):
    out = []
    for b in data:
        b ^= key
        for sh in (6, 4, 2, 0):
            out.append(pulse((b >> sh) & 3, h))
    return out


def turbo_classes(data, key=0):
    """The pulse classes (0-3) for some bytes, msb pair first."""
    out = []
    for b in data:
        b ^= key
        out += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
    return out


def turbo_lead(h, pilot):
    return [pulse(0, h)] * pilot + [pulse(3, h)]


def best_key(data):
    """Xor key that makes the block shortest: chosen per 2-bit position,
    so the most common pair at each position becomes the shortest pulse."""
    key = 0
    for sh in (6, 4, 2, 0):
        freq = [0, 0, 0, 0]
        for b in data:
            freq[(b >> sh) & 3] += 1
        best = min(range(4), key=lambda k: sum(freq[v] * (4 + 2 * (v ^ k)) for v in range(4)))
        key |= best << sh
    return key


def header_bytes(addr, data_len, key, flags, seq, prog):
    lo = data_len & 255
    hi = (data_len + 255) >> 8          # dec-to-zero form used by the core
    h = [addr & 255, addr >> 8, lo, hi, key, flags, seq & 255, prog & 255]
    c = HEADER_SEED
    for b in h:
        c ^= b
    return h + [c]


def xor_all(data):
    c = 0
    for b in data:
        c ^= b
    return c

# ---------------------------------------------------------------- decoder model

class Decoder:
    """Model of the CIA-timer decoder in stage 1 and the core: each pulse
    gives timer b = 11 - floor(T / period), and the period comes from the
    pilot measurement with the same rounding the 6502 code does."""

    DTAB = [3, 3, 3, 2, 2, 1, 1, 0, 0, 0, 0, 0]

    CBASE = [3, 3, 3, 3, 3, 2, 2, 1, 1, 0, 0, 0, 0, 0]   # src/core.asm cbase

    def __init__(self):
        self.reset()

    def reset(self):
        self.period = H_DEF
        self.count = 0
        self.cal = False
        self.elapsed = 0

    core = False        # stage 1's pilot measure (the first block) or the core's

    def tb(self, t):
        n = int(t // self.period)
        return TB_START - n if n <= TB_START else TB_START

    def find_sync(self, pulses, i):
        """Advance through a pilot to the sync pulse. Returns the index
        after the sync, or None at the end of the pulses."""
        self.reset()
        while i < len(pulses):
            t = pulses[i]
            i += 1
            x = self.tb(t)
            if x >= 7:
                if x >= TB_START:
                    self.reset()
                    continue
                self.count = (self.count + 1) & 255
                if self.core:               # 64 pulses from $ff7f, again and again
                    if self.count == CAL_START:
                        self.elapsed = 0
                    elif CAL_START < self.count <= CAL_START + CAL_LEN:
                        self.elapsed += t
                    if self.count == CAL_START + CAL_LEN:
                        e = min(self.elapsed, 0xff7f)
                        hi = 255 - ((0xff7f - e) >> 8)
                        self.period = hi
                        self.cal = True
                        self.count = CAL_START
                        self.elapsed = 0
                    continue
                if self.count == CAL_START:
                    self.elapsed = 0
                elif CAL_START < self.count <= CAL_END:
                    self.elapsed += t
                if self.count == CAL_END:
                    e = min(self.elapsed, 65535)
                    hi = 255 - ((65535 - e) >> 8)
                    self.period = ((hi - 1) >> 1) + 1
                    self.cal = True
                continue
            if x >= 3 or not self.cal:
                self.reset()
                continue
            return i
        return None

    def cls(self, t, m):
        return self.CBASE[self.tb(t) + m - 2]

    def read_bytes(self, pulses, i, n, m=4, prefix=False):
        out = []
        if not prefix:
            for _ in range(n):
                if i + 4 > len(pulses):
                    return out, i
                b = 0
                for _ in range(4):
                    b = (b << 2) | self.cls(pulses[i], m)
                    i += 1
                out.append(b)
            return out, i
        sr = 1                                  # bits over a marker, as the core
        while len(out) < n and i < len(pulses):
            k = self.cls(pulses[i], m)
            i += 1
            for bit in ([1], [0, 1], [0, 0, 1], [0, 0, 0])[k]:
                sr = (sr << 1) | bit
                if sr & 256:
                    out.append(sr & 255)
                    sr = 1
                    if len(out) == n:
                        break
        return out, i


def decode_turbo(pulses, start, s1_pages):
    """Decode the turbo part of a SlopLoad tape: the stage-1 block (core),
    then headered blocks. Returns a list of dicts."""
    dec = Decoder()
    found = []
    i = dec.find_sync(pulses, start)
    if i is None:
        return found
    dec.core = True                     # every block after the core's
    n = s1_pages * 256
    data, i = dec.read_bytes(pulses, i, n + 1)
    found.append(dict(kind='core', addr=0x0400, data=bytes(data[:n]),
                      ok=len(data) == n + 1 and xor_all(data[:n]) == data[n],
                      period=dec.period, pulse=i))
    while True:
        i = dec.find_sync(pulses, i)
        if i is None:
            break
        hdr, i = dec.read_bytes(pulses, i, 9)       # 2 bits a pulse, m = 4
        if len(hdr) < 9 or xor_all(hdr[:9]) ^ HEADER_SEED:
            continue
        m = 2 + ((hdr[5] >> 4) & 3)
        pfx = bool(hdr[5] & F_PREFIX)
        addr = hdr[0] | hdr[1] << 8
        hi = hdr[3] if hdr[2] == 0 else hdr[3] - 1
        ln = hi * 256 + hdr[2]
        raw, i = dec.read_bytes(pulses, i, ln + 2, m, pfx)   # pad, data, check
        raw = raw[1:]
        data = bytes(b ^ hdr[4] for b in raw[:ln])
        ok = len(raw) == ln + 1 and xor_all(data) == raw[ln]
        found.append(dict(kind='block', addr=addr, data=data, key=hdr[4], flags=hdr[5],
                          seq=hdr[6], prog=hdr[7], ok=ok, period=dec.period, pulse=i,
                          m=m, prefix=pfx))
    return found
