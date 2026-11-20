#!/usr/bin/env python3
"""tmpsrc.py - a module's source respelt for an assembler on a C64, and
written as the text file such an assembler reads (a SEQ file).

    tmpsrc.py SOURCE.asm OUT.seq

The sources here are in CBM prg Studio's spelling. Turbo Macro Pro (and
the Turbo Assemblers it comes from) wants, as LMGUIDE.md says ("In
another assembler"):

  - .byte and .word for byte and word
  - a name of its own for every @label (the scope's name and the
    label's, 15 characters at most)
  - brackets round each product in a sum: it works a sum out from left
    to right, * no sooner than +
  - a line that fits one row of the screen: a list of bytes or words
    split to fit, and no comments
  - _ as C= and @ (PETSCII $A4)

tools/c64build.py puts LMGUIDE.md's least module and Hello-Load on
SlopLoad 64's B side this way (least.s, hello.s); tests/tmproute.py has
Turbo Macro Pro assemble them, to the bytes tools/asm6502.py makes.
"""
import re
import sys

MNEMONICS = set('adc and asl bcc bcs beq bit bmi bne bpl brk bvc bvs clc cld cli clv cmp cpx cpy dec dex dey eor'
                ' inc inx iny jmp jsr lda ldx ldy lsr nop ora pha php pla plp rol ror rti rts sbc sec sed sei'
                ' sta stx sty tax tay tsx txa txs tya'.split())
TAB, WIDTH = 9, 39              # Turbo Macro Pro's column for the instruction; a line's last column


def respell(src):
    """prg Studio's source as Turbo Macro Pro reads it: [lines]"""
    out, scope, names, used = [], '', {}, set()
    lines = [ln.split(';')[0].rstrip() for ln in src.splitlines()]
    lines = [ln for ln in lines if ln.strip()]
    for ln in lines:                            # (every full label, so a new name can't be one)
        m = re.match(r'^([a-z_][a-z0-9_]*)', ln)
        if m:
            used.add(m.group(1))

    def local(sc, name):
        if (sc, name) not in names:
            new, n = (sc + name[1:])[:15], 0
            while new in used or new in MNEMONICS:
                n += 1
                new = f"{(sc + name[1:])[:12]}{n}"
            used.add(new)
            names[(sc, name)] = new
        return names[(sc, name)]

    def expr(e):                                # a product inside a sum: in brackets
        if not re.search(r'[+-]', e):
            return e
        return re.sub(r'(?<![\w$%)])([\w$%]+(?:[*/][\w$%]+)+)', r'(\1)', e)
    for ln in lines:
        m = re.match(r'^(@?[a-z_][a-z0-9_]*)?(\s+(.*))?$', ln)
        if ln.startswith('*='):
            out.append(' *= ' + ln[2:].strip())
            continue
        label, rest = m.group(1) or '', (m.group(3) or '').strip()
        if label and not label.startswith('@') and not rest.startswith('='):
            scope = label
        if label.startswith('@'):
            label = local(scope, label)
        rest = re.sub(r'@[a-z0-9_]+', lambda q: local(scope, q.group(0)), rest)
        if rest.startswith('='):
            out.append(f"{label} = {expr(rest[1:].strip())}")
            continue
        op, _, arg = rest.partition(' ')
        op = {'byte': '.byte', 'word': '.word'}.get(op, op)
        args = [expr(x) for x in arg.strip().split(',')] if arg.strip() else []
        if op in ('.byte', '.word'):            # a line is one row of the screen: a list split to fit
            room = WIDTH - max(TAB, len(label) + 1) - len(op) - 1
            while args:
                n = 1
                while n < len(args) and len(','.join(args[:n + 1])) <= room:
                    n += 1
                out.append(f"{label} {op} {','.join(args[:n])}")
                label, args = '', args[n:]
            continue
        out.append(f"{label} {op} {','.join(args)}".rstrip())

    def cols(ln):                               # as the editor lays the line out
        lab, _, rest = ln.partition(' ')
        return len(ln) if rest.startswith('=') or not rest else max(TAB, len(lab) + 1) + len(rest)
    wide = [ln for ln in out if cols(ln) > WIDTH]
    if wide:
        raise SystemExit(f"tmpsrc: a line too long for Turbo Macro Pro's 40 columns: {wide[0]!r}")
    return out


def seq(lines):
    """a text file as the C64 has it: unshifted letters, _ as C= and @, a
    RETURN after each line"""
    def pet(c):
        o = ord(c)
        return o - 32 if 97 <= o <= 122 else 0xa4 if c == '_' else o
    return b''.join(bytes(pet(c) for c in ln) + b'\r' for ln in lines)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    open(sys.argv[2], 'wb').write(seq(respell(open(sys.argv[1]).read())))
