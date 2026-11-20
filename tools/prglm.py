#!/usr/bin/env python3
"""prglm.py - a module's .lm from the programs (.prg) any assembler wrote.

    prglm.py OUT.lm MAIN.prg [PART.prg ...] [-lower MAIN.prg [PART.prg ...]]

A module assembled without tools/build.py (in CBM prg Studio, in an
assembler on a C64, anywhere) is a .prg: its load address, then its
bytes, the header ("PLG1") first. This writes them as a .lm, each part's
address, length and bytes (LMFORMAT.md), the main part first.

-lower: the same parts assembled a VIC bank lower (the source's
`mb = $8000` in place of `mb = $c000`), in the same order. The bytes
that differ are the module's relocations (each must be $40 less: the
high byte of an address of its own); they go after the parts, and the
header's +27 bit 7 is set: the tools can then move the module for a
chain. A part below $C000 stays where it is: leave it out of -lower's
list from the end, or give the same file.

PRG-LM on SlopLoad 64's disks (c64/prglm.bas) does the same on a C64,
and writes the same file.
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmreloc as LR  # noqa: E402


class Fail(Exception):
    pass


def load(path):
    try:
        d = open(path, 'rb').read()
    except OSError as ex:
        raise Fail(f"{path}: {ex.strerror}")
    if len(d) < 3:
        raise Fail(f"{path}: not a program (a load address, then bytes)")
    return struct.unpack('<H', d[:2])[0], d[2:]


def make(mains, lowers=()):
    """(the .lm's bytes, its parts, relocations or None) from the parts'
    (address, bytes) and, to make it move, the same a bank lower"""
    parts = [(a, bytes(d)) for a, d in mains]
    a, d = parts[0]
    if d[:4] != b'PLG1':
        raise Fail("the first program isn't a module: no 'PLG1' at its start")
    if len(d) < 32:
        raise Fail(f"the first program isn't a module: its header is 32 bytes, this is {len(d)}")
    if not lowers:
        return LR.join(parts), parts, None
    lowers = list(lowers)
    if len(lowers) > len(parts):
        raise Fail(f"{len(parts)} parts, {len(lowers)} a bank lower")
    for k in range(len(lowers), len(parts)):    # (parts that stay: the same a bank lower)
        if parts[k][0] >= LR.FIXED:
            raise Fail(f"the part at ${parts[k][0]:04X} moves with the module: give its build a bank lower too")
        lowers.append(parts[k])
    lists, probs = LR.find(parts, lowers)
    if probs:
        raise Fail("it doesn't move a bank down as it should: " + "; ".join(probs)
                   + " (every address in its bank written from mb: LMFORMAT.md)")
    rel = (lists, [])
    d = bytearray(d)
    d[27] |= LR.FLAG
    parts[0] = (a, bytes(d))
    if not LR.claim_moves(parts, rel):
        raise Fail("its header's claim (+10) doesn't move with it: write it mb+... (LMFORMAT.md)")
    return LR.join(parts, rel), parts, rel


def main(argv):
    if len(argv) < 2 or argv[0].startswith('-'):
        print(__doc__)
        return 1
    out, rest = argv[0], argv[1:]
    lower = []
    if '-lower' in rest:
        i = rest.index('-lower')
        rest, lower = rest[:i], rest[i + 1:]
        if not lower:
            print("prglm: -lower takes the programs assembled a bank lower", file=sys.stderr)
            return 1
    try:
        lm, parts, rel = make([load(p) for p in rest], [load(p) for p in lower])
    except (Fail, LR.Bad) as ex:
        print(f"prglm: {ex}", file=sys.stderr)
        return 1
    open(out, 'wb').write(lm)
    for a, d in parts:
        print(f"  ${a:04X}-${a + len(d) - 1:04X}  {len(d)} bytes")
    if rel:
        print(f"  {sum(len(x) for x in rel[0])} relocations: the tools can move it a VIC bank down")
    else:
        print("  no relocations (no -lower): it can't move for a chain")
    print(f"{out}: {len(lm)} bytes")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
