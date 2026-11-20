#!/usr/bin/env python3
"""A module that moves (MODULES.md, "A module that moves"): every module is
built for VIC bank 3 ($C000-$FFF9), and its .lm carries the places of the
bytes that hold its own addresses' high bytes, so that the mastering tools
(slopload.py, SlopLoad 64) can move it a VIC bank down, to $8000-$BFF9,
when the two modules of a chain would share memory. tools/build.py finds
them by assembling the module a second time a bank lower and comparing
(every byte that differs must differ by $40: a high byte).

In the .lm file, after the parts:

    $00 $00          the relocations (no part goes at $0000)
    length           (a word)
    for each part, in the file's order:
        gaps         a byte each: 1-254 the next byte to move is that many
                     on (from the part's start less one); 255: 254 on,
                     nothing moved there; 0: the part's list ends
    n, then n bytes  the main part's bank bytes: their places in its
                     header, its first 32 bytes ($DD00's bank bits, one more
                     a bank down: the show module's +25)

The header's +27 bit 7 says the list is there. Moving: each part at $C000
or above goes $4000 lower, every listed byte $40 lower, each bank byte one
higher; a part below $C000 (a ROM-font screen at $BC00, a font of its own)
stays where it is. Its claims: each from $C000 on $4000 lower, the
main part's claim's end (+10) too ($FFFF, or 0: to the end, $C000), so
the claim must move with it (written mb+...): claim_moves() checks.
"""
import struct

MOVE = 0x4000                   # a VIC bank down
FLAG = 0x80                     # header +27: it carries its relocations
FIXED = 0xc000                  # parts below stay


class Bad(Exception):
    pass


def encode(lists, bank=()):
    """the relocations' block: lists, each part's offsets (sorted), in
    the file's order; bank, the main part's bank bytes"""
    body = bytearray()
    for offs in lists:
        p = -1
        for o in sorted(offs):
            g = o - p
            if g < 1:
                raise Bad(f"relocations: offset {o} twice")
            while g > 254:
                body.append(255)
                g -= 254
            body.append(g)
            p = o
        body.append(0)
    if len(bank) > 32 or any(not 0 <= b < 32 for b in bank):
        raise Bad("relocations: a bank byte past the main part's header (its first 32)")
    body.append(len(bank))
    body += bytes(bank)
    return struct.pack('<HH', 0, len(body)) + bytes(body)


def decode(body, nparts):
    """(lists, bank) from a block's body (after its address and length)"""
    lists, i = [], 0
    for _ in range(nparts):
        offs, p = [], -1
        while True:
            if i >= len(body):
                raise Bad("relocations: the list ends early")
            g = body[i]
            i += 1
            if g == 0:
                break
            if g == 255:
                p += 254
                continue
            p += g
            offs.append(p)
        lists.append(offs)
    if i >= len(body):
        raise Bad("relocations: no bank bytes' count")
    n = body[i]
    bank = list(body[i + 1:i + 1 + n])
    if len(bank) != n:
        raise Bad("relocations: the bank bytes end early")
    return lists, bank


def split(d):
    """a .lm file's bytes: (parts [(address, bytes)], relocations or None)"""
    parts, rel, i = [], None, 0
    while i < len(d):
        if i + 4 > len(d):
            raise Bad("it ends inside a part's header")
        a, n = struct.unpack('<HH', d[i:i + 4])
        if i + 4 + n > len(d):
            raise Bad("a part runs past its end")
        if a == 0:
            if rel is not None or i + 4 + n != len(d):
                raise Bad("its relocations aren't last")
            rel = d[i + 4:i + 4 + n]
        else:
            parts.append((a, bytes(d[i + 4:i + 4 + n])))
        i += 4 + n
    if rel is not None:
        rel = decode(rel, len(parts))
        for (a, data), offs in zip(parts, rel[0]):
            if offs and offs[-1] >= len(data):
                raise Bad(f"a relocation past its part's end (${a:04X})")
    return parts, rel


def join(parts, rel=None):
    """a .lm file's bytes from its parts and relocations ((lists, bank))"""
    out = b''.join(struct.pack('<HH', a, len(d)) + bytes(d) for a, d in parts)
    return out + (encode(*rel) if rel else b'')


def movable(parts, rel):
    """it carries its relocations, and its header says so"""
    return rel is not None and len(parts[0][1]) > 27 and bool(parts[0][1][27] & FLAG)


def moved(parts, rel):
    """the parts a VIC bank down: [(address, bytes)]"""
    lists, bank = rel
    out = []
    for k, ((a, d), offs) in enumerate(zip(parts, lists)):
        d = bytearray(d)
        for o in offs:
            d[o] = (d[o] - 0x40) & 255
        if k == 0:
            for o in bank:
                d[o] = (d[o] + 1) & 255
        out.append((a - MOVE if a >= FIXED else a, bytes(d)))
    return out


def claim(parts, moved=False):
    """the main part's claim's end, as the tools have it (+10, 0 to the
    end: $10000, or $C000 a bank down)"""
    a, d = parts[0]
    w = d[10] | d[11] << 8
    return max(a + len(d), w or (FIXED if moved else 0x10000))


def claim_moves(parts, rel):
    """its header's claim, a bank down (relocated), is what the tools say
    a bank down: its claim less $4000 (to the end: $C000)"""
    c = claim(parts)
    want = c if parts[0][0] < FIXED else FIXED if c >= 0xffff else c - MOVE
    return claim(moved(parts, rel), moved=parts[0][0] >= FIXED) == want


def find(a_parts, b_parts):
    """the relocation lists from two builds of one module, the second a
    VIC bank lower: (lists, problems). Parts below $C000 must be the same
    in both (they stay)"""
    lists, probs = [], []
    if len(a_parts) != len(b_parts):
        return None, [f"{len(a_parts)} parts as built, {len(b_parts)} a bank lower"]
    for (a, d), (b, e) in zip(a_parts, b_parts):
        if len(d) != len(e):
            probs.append(f"its part at ${a:04X}: {len(d)} bytes as built, {len(e)} a bank lower")
            lists.append([])
            continue
        offs = [i for i in range(len(d)) if d[i] != e[i]]
        if a < FIXED:
            if offs:
                probs.append(f"its part at ${a:04X} (it stays) differs a bank lower at {len(offs)} bytes")
            lists.append([])
            continue
        if b != a - MOVE:
            probs.append(f"its part at ${a:04X} is at ${b:04X} a bank lower")
        odd = [i for i in offs if (d[i] - e[i]) & 255 != 0x40]
        if odd:
            probs.append(f"its part at ${a:04X}: {len(odd)} bytes that differ other than by $40 (not an"
                         f" address's high byte), the first at ${a + odd[0]:04X}")
        lists.append(offs)
    return lists, probs
