#!/usr/bin/env python3
"""SlopLoad 64's messages packed (tools/c64build.py): the texts printed
through `print` are scanned at the build, the 64 pieces of them that save
the most chosen, and each of those texts assembled with the byte $c0 + k
in place of piece k. c64/words.asm (written here) has the table and
`prch`, print's character: below $c0 the character, else the piece. The
sources keep their texts as written.

A text is packed only when everything that uses it prints it: its label
is used as #<label / #>label (and not for a file name: setnam), or in a
table of such pointers whose every use goes on to print. A text read a
byte at a time, or at an offset, is left as it is.
"""
import collections
import re

import asm6502

WORDS = 64                      # $c0-$ff
HALF = 32                       # the table in two halves, each under a page
LABEL = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\b')
IDENT = re.compile(r'[A-Za-z_@][A-Za-z0-9_]*')


def split_ops(ops):
    """a text directive's operands: ([operand], comment)"""
    out, cur, q = [], '', False
    for i, ch in enumerate(ops):
        if ch == '"':
            q = not q
        if not q and ch == ';':
            if cur.strip():
                out.append(cur.strip())
            return out, ops[i:]
        if not q and ch == ',':
            out.append(cur.strip())
            cur = ''
            continue
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out, ''


def code_of(line):
    """a line without its comment (quotes respected)"""
    q = False
    for i, ch in enumerate(line):
        if ch == '"':
            q = not q
        elif ch == ';' and not q:
            return line[:i]
    return line


TEXT = re.compile(r'^(\S*)(\s+)(\.?text)(\s+)(.*)$')


def analyse(lines):
    """(the text lines: {index: owner label}, the labels packable)"""
    owner, texts, tables = None, {}, collections.defaultdict(set)
    tabowner = {}
    for i, ln in enumerate(lines):
        c = code_of(ln)
        m = LABEL.match(c)
        if m and not re.match(r'^\w+\s*=', c):
            owner = m.group(1)
        if TEXT.match(c) and owner:
            texts[i] = owner
    labs = set(texts.values())
    bad = set()
    for i, ln in enumerate(lines):
        if i in texts:
            continue
        c = code_of(ln)
        m = LABEL.match(c)
        defined = m.group(1) if m else None
        body = c[len(defined):] if defined else c
        for L in set(IDENT.findall(body)) & labs:
            if re.search(rf'\bld[axy]\s+#[<>]{L}\s*$', c):
                nxt = [code_of(lines[j]) for j in range(i + 1, min(len(lines), i + 7))]
                call = next((re.search(r'\b(jsr|jmp)\s+(\w+)', n) for n in nxt
                             if re.search(r'\b(jsr|jmp)\s+\w+', n)), None)
                if call and call.group(2) == 'setnam':
                    bad.add(L)                          # (a file name)
            elif re.search(rf'[<>]{L}\s*[-+]', body):
                bad.add(L)                              # at an offset: its bytes counted
            elif re.search(r'\bbyte\b', body) and re.search(rf'[<>]{L}\b', body):
                t = defined or tabowner.get(i - 1)
                tabowner[i] = t
                tables[t].add(L)
            else:
                bad.add(L)                              # read some other way
    for t, members in tables.items():                   # a table: every use goes to print
        for i, ln in enumerate(lines):
            c = code_of(ln)
            m = LABEL.match(c)
            body = c[len(m.group(1)):] if m else c
            if t and re.search(rf'\b{t}\b', body) and not goes_to_print(lines, i):
                bad |= members
    return texts, labs - bad


def goes_to_print(lines, i, n=6):
    """the next few lines from i call print, a jmp followed (once) to its
    label, forward"""
    j = i
    for _ in range(n):
        c = code_of(lines[j])
        if re.search(r'\b(jsr|jmp)\s+print\b', c):
            return True
        m = re.search(r'\bjmp\s+(@?\w+)\s*$', c)
        if m:                                           # (its label, the first one on)
            k = next((k for k in range(j + 1, min(len(lines), j + 40))
                      if re.match(rf'^{re.escape(m.group(1))}\b', lines[k])), None)
            if k is None:
                return False
            j = k
            continue
        j += 1
    return False


def strings(lines, texts, ok):
    """the quoted strings of the packable texts"""
    out = []
    for i, lab in texts.items():
        if lab in ok:
            m = TEXT.match(code_of(lines[i]))
            ops, _ = split_ops(m.group(5))
            out += [o[1:-1] for o in ops if o.startswith('"') and o.endswith('"') and len(o) > 1]
    return out


def choose(strs):
    """the pieces, in the order they are replaced: up to 64, each table
    half under 256 bytes"""
    cur = list(strs)
    words, used = [], [0, 0]
    while len(words) < WORDS:
        cnt = collections.Counter()
        for s in cur:
            for n in range(2, 15):
                for k in range(len(s) - n + 1):
                    w = s[k:k + n]
                    if all(ord(ch) < 0x100 for ch in w):
                        cnt[w] += 1
        half = len(words) // HALF
        best, bv = None, 0
        for w, _ in sorted(cnt.items(), key=lambda kv: (-kv[1] * (len(kv[0]) - 1), kv[0]))[:3000]:
            if used[half] + len(w) > 255:
                continue
            v = sum(s.count(w) for s in cur) * (len(w) - 1) - len(w) - 1
            if v > bv or v == bv and best is not None and (len(w), w) < (len(best), best):
                best, bv = w, v
        if best is None or bv <= 0:
            break
        tok = chr(0x100 + len(words))
        cur = [s.replace(best, tok) for s in cur]
        used[half] += len(best)
        words.append(best)
    return words


def encode(s, words):
    """a string as operands: quoted runs and $c0 + k"""
    for k, w in enumerate(words):
        s = s.replace(w, chr(0x100 + k))
    out, run = [], ''
    for ch in s:
        if ord(ch) >= 0x100:
            if run:
                out.append(f'"{run}"')
                run = ''
            out.append(f'${0xc0 + ord(ch) - 0x100:02x}')
        else:
            run += ch
    if run:
        out.append(f'"{run}"')
    return out


def pack(src, words):
    """the expanded source with its packable texts packed"""
    lines = src.split('\n')
    texts, ok = analyse(lines)
    for i, lab in texts.items():
        if lab not in ok:
            continue
        m = TEXT.match(code_of(lines[i]))
        ops, _ = split_ops(m.group(5))
        new = []
        for o in ops:
            if o.startswith('"') and o.endswith('"') and len(o) > 1:
                enc = encode(o[1:-1], words)
                back = ''.join(words[int(e[1:], 16) - 0xc0] if e.startswith('$') else e[1:-1] for e in enc)
                assert back == o[1:-1], (o, enc)       # (each text as it was, word for word)
                new += enc
            else:
                new.append(o)
        lines[i] = f"{m.group(1)}{m.group(2)}{m.group(3)}{m.group(4)}{','.join(new)}"
    return '\n'.join(lines)


def words_asm(words):
    """c64/words.asm: prch and the table"""
    halves = [words[:HALF], words[HALF:]]
    ofs, data = [], []
    for h in halves:
        d, o = [], []
        for w in h:
            o.append(len(d))
            d += [asm6502.petscii(ch) for ch in w[:-1]] + [asm6502.petscii(w[-1]) | 0x80]   # (as text has them)
        assert len(d) <= 256
        ofs += o
        data.append(d)

    def rows(lab, bs):
        out = []
        for k in range(0, max(1, len(bs)), 16):
            chunk = bs[k:k + 16]
            out.append(f"{lab if k == 0 else '':8s}byte " + ','.join(f'${b:02x}' for b in chunk)
                       if chunk else f"{lab:8s}")
        return out
    return '\n'.join([
        "; generated by tools/c64words.py (tools/c64build.py) - do not edit",
        "; ------------------------------------------------------------",
        "; words.asm  -  SlopLoad 64's messages packed: in a text printed by",
        "; print, a byte $c0-$ff is a piece of this table (the 64 that save the",
        "; most, chosen from the texts at the build; the last character of each",
        "; with bit 7 set)",
        "; ------------------------------------------------------------",
        "",
        "; prch  print's character: a, or the piece a - $c0",
        ";   uses: a (x, y kept)",
        "prch    cmp #$c0",
        "        bcs @w",
        "        jmp chrout",
        "@w      sty wsy",
        "        stx wsx",
        "        tax",
        "        ldy wofs-$c0,x",
        "        cpx #$e0",
        "        bcs @2",
        "@1      lda wpc1,y",
        "        jsr @o",
        "        bcc @1",
        "        bcs @r",
        "@2      lda wpc2,y",
        "        jsr @o",
        "        bcc @2",
        "@r      ldy wsy",
        "        ldx wsx",
        "        rts",
        "@o      pha                     ; out, and c set if it was the last",
        "        and #$7f",
        "        jsr chrout",
        "        iny",
        "        pla",
        "        asl a",
        "        rts",
        "wsy     byte 0",
        "wsx     byte 0",
        f"; the pieces: {', '.join(repr(w) for w in words)}",
    ] + rows('wofs', ofs) + rows("wpc1", data[0]) + rows("wpc2", data[1])) + '\n'
