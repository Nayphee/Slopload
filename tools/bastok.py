#!/usr/bin/env python3
"""bastok.py - a BASIC V2 listing (text) as a C64 program (.prg at $0801).

    bastok.py LISTING.bas OUT.prg

The listing is as it is typed on a C64, in lowercase: a line number, then
the line. In strings, a lowercase letter is the unshifted key (what the
C64 shows as a capital) and {name} a control code: {clr} {home} {down}
{up} {left} {right} {rvon} {rvof} and the colours {blk} {wht} {red}
{cyn} {pur} {grn} {blu} {yel} {orng} {brn} {lred} {gry1} {gry2} {lgrn}
{lblu} {gry3}. Lines that start with ; and blank lines are skipped.
tools/c64build.py uses it for PRG-LM (c64/prglm.bas).
"""
import re
import struct
import sys

TOKENS = ['end', 'for', 'next', 'data', 'input#', 'input', 'dim', 'read', 'let', 'goto', 'run', 'if', 'restore',
          'gosub', 'return', 'rem', 'stop', 'on', 'wait', 'load', 'save', 'verify', 'def', 'poke', 'print#',
          'print', 'cont', 'list', 'clr', 'cmd', 'sys', 'open', 'close', 'get', 'new', 'tab(', 'to', 'fn',
          'spc(', 'then', 'not', 'step', '+', '-', '*', '/', '^', 'and', 'or', '>', '=', '<', 'sgn', 'int',
          'abs', 'usr', 'fre', 'pos', 'sqr', 'rnd', 'log', 'exp', 'cos', 'sin', 'tan', 'atn', 'peek', 'len',
          'str$', 'val', 'asc', 'chr$', 'left$', 'right$', 'mid$', 'go']
ORDER = sorted(TOKENS, key=len, reverse=True)       # (input# before input)
CTRL = {'clr': 147, 'home': 19, 'down': 17, 'up': 145, 'left': 157, 'right': 29, 'rvon': 18, 'rvof': 146,
        'blk': 144, 'wht': 5, 'red': 28, 'cyn': 159, 'pur': 156, 'grn': 30, 'blu': 31, 'yel': 158,
        'orng': 129, 'brn': 149, 'lred': 150, 'gry1': 151, 'gry2': 152, 'lgrn': 153, 'lblu': 154, 'gry3': 155}


def petscii(ch):
    o = ord(ch)
    if 97 <= o <= 122:
        return o - 32
    if 65 <= o <= 90:
        return o + 128
    if not 32 <= o < 96:
        raise ValueError(f"a character the C64 hasn't: {ch!r}")
    return o


def line(body):
    out, i, quote, rest = bytearray(), 0, False, False
    while i < len(body):
        c = body[i]
        if quote or rest:
            if c == '{' and quote:
                j = body.index('}', i)
                out.append(CTRL[body[i + 1:j]])
                i = j + 1
                continue
            quote = quote and c != '"'
            out.append(petscii(c))
            i += 1
            continue
        if c == '"':
            quote = True
            out.append(34)
            i += 1
            continue
        for t in ORDER:
            if body.startswith(t, i):
                out.append(0x80 + TOKENS.index(t))
                i += len(t)
                rest = t in ('rem', 'data')         # (to the line's end, as it is; data: to a colon)
                break
        else:
            out.append(petscii(c))
            i += 1
    return bytes(out)


def tokenise(text, at=0x0801):
    """the program's bytes, its load address first"""
    out, last = bytearray(), 0
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith(';'):
            continue
        m = re.match(r'\s*(\d+)\s?(.*)$', raw)
        if not m or not 0 < int(m.group(1)) < 64000 or int(m.group(1)) <= last:
            raise ValueError(f"not a numbered line, or out of order: {raw!r}")
        last, body = int(m.group(1)), line(m.group(2).rstrip())
        if len(m.group(0).rstrip()) > 80:
            raise ValueError(f"line {last} is over 80 characters: it can't be typed in")
        nxt = at + len(out) + 4 + len(body) + 1
        out += struct.pack('<HH', nxt, last) + body + b'\x00'
    return struct.pack('<H', at) + bytes(out) + b'\x00\x00'


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    open(sys.argv[2], 'wb').write(tokenise(open(sys.argv[1]).read()))
