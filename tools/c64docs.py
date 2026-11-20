#!/usr/bin/env python3
"""c64docs.py - the suite's instructions as text files a C64 reads: the
chapters NOTES shows (c64/notes.asm), on SlopLoad 64's B side.

    c64docs.py [OUTDIR]         the chapters listed; with OUTDIR, written
                                there (notes.idx, notes.01 ...)

What goes on the disk, from the documents as they are:

  README.md    "SlopLoad 64: mastering on a C64" (every tool on the
               disks) and "Tape errors"
  LMGUIDE.md   all of it: a module by hand
  LMFORMAT.md  all of it: the .lm file

Each is cut into chapters at its headings (a part over 7,000 bytes at its
sub-headings too, a very short piece joined to the one before), and each
chapter is a SEQ file of PETSCII text:

  - lines of 39 characters at most, a RETURN after each, so that no line
    reaches column 40 and a page is a number of lines
  - the lower and upper case set (the reader switches to it): a to z as
    $41-$5A, A to Z as $C1-$DA
  - each line starts with its colour: text green ($1E), headings white
    ($05), listings and what is typed light blue ($9A)
  - Markdown's marks taken out: a table's row becomes its first cell and
    the others under it, a listing's comment goes on the line after its
    instruction, a long line is folded

notes.idx lists them for the reader's menu, a line each: the file's
name, a colon, the title (in the upper case set's letters); a line that
starts with the colon is a heading in the menu.
"""
import os
import re
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIDTH = 39
MAX = 7000                      # a part's bytes before it is cut at its sub-headings
SMALL = 700                     # a sub-heading's piece too short for a chapter of its own
TEXT, HEAD, CODE = 0x1e, 0x05, 0x9a
PLAIN = {'_': 0xa4, '|': 0xdd, '{': ord('('), '}': ord(')'), '\\': ord('/'), '~': ord('-'), '`': ord("'"),
         '^': 0x5e}

# (document, the menu's heading, [(from this heading, up to this one or None)] or None for all of it)
SOURCES = [
    ('README.md', 'slopload 64 and its tools', [('## SlopLoad 64: mastering on a C64', '## Writing a module'),
                                               ('## Tape errors', '## CD, MP3 and PC playback')]),
    ('LMGUIDE.md', 'a loader module, by hand', None),
    ('LMFORMAT.md', 'the .lm file, byte by byte', None),
]


def listing(text, mark):
    """the fenced listing after the comment <!-- mark --> in a document"""
    m = re.search(rf'<!-- {mark} -->\s*```[a-z]*\n(.*?)```', text, re.S)
    if not m:
        raise SystemExit(f"no listing marked {mark}")
    return m.group(1)


def pet(s):
    """text in the lower and upper case set's codes"""
    out = bytearray()
    for c in s:
        o = ord(c)
        if 97 <= o <= 122:
            out.append(o - 32)
        elif 65 <= o <= 90:
            out.append(o + 128)
        elif c in PLAIN:
            out.append(PLAIN[c])
        elif 32 <= o < 96:
            out.append(o)
        else:
            raise SystemExit(f"c64docs: a character the C64 hasn't: {c!r} in {s!r}")
    return bytes(out)


def inline(s):
    """a line's Markdown marks out: code, bold, links"""
    parts = s.split('`')
    for i in range(0, len(parts), 2):           # (outside code spans)
        t = parts[i].replace('**', '')
        t = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', t)
        t = re.sub(r'<(https?://[^>]+)>', r'\1', t)
        parts[i] = t.replace('\\|', '|')
    for i in range(1, len(parts), 2):
        parts[i] = parts[i].replace('\\|', '|')
    return ''.join(parts)


def wrap(text, first='', rest=''):
    return textwrap.wrap(' '.join(text.split()), WIDTH, initial_indent=first, subsequent_indent=rest,
                         break_long_words=True, break_on_hyphens=False) or [first.rstrip()]


def code(line):
    """a listing's line in 39 columns: its comment on the next line, the rest folded"""
    line = line.expandtabs(8).rstrip()
    if len(line) <= WIDTH:
        return [line]
    out = []
    m = re.search(r'\s+;', line)
    if m and line[:m.start()].strip():          # an instruction and its comment
        out += code(line[:m.start()])
        for i, w in enumerate(textwrap.wrap(line[m.end():].strip(), WIDTH - 10)):
            out.append('        ; ' + w)
        return out
    if line.lstrip().startswith(';'):           # a comment's own line (one that carries on from an
        ind = min(8, len(line) - len(line.lstrip()))        # instruction's: under its comment)
        return [' ' * ind + ('; ' if i else '') + w
                for i, w in enumerate(textwrap.wrap(line.strip(), WIDTH - ind - 2))]
    first = True
    while line:
        cut = WIDTH if first else WIDTH - 2
        if len(line) > cut and ' ' in line[cut // 2:cut + 1]:
            cut = line.rindex(' ', 0, cut + 1)
        out.append(('' if first else '  ') + line[:cut].rstrip())
        line, first = line[cut:].lstrip(), False
    return out


def render(md):
    """Markdown lines as [(colour, text)], 39 columns"""
    out, i, n = [], 0, len(md)

    def blank():
        if out and out[-1][1] != '':
            out.append((TEXT, ''))
    while i < n:
        ln = md[i]
        if ln.strip().startswith('<!--'):
            mark = ln.strip()
            i += 1
            if mark == '<!-- prglm.bas -->':    # (105 lines of BASIC of 80 columns: it is on the disk)
                while not md[i].startswith('```'):
                    i += 1
                i += 1
                while not md[i].startswith('```'):
                    i += 1
                i += 1
                blank()
                out += [(CODE, x) for x in ('LOAD"PRG-LM",8', 'LIST')]
                out += [(TEXT, x) for x in wrap('(The listing itself is not in these notes: the program is on'
                                                ' this disk.)')]
                out.append((TEXT, ''))
            continue
        if ln.startswith('```'):
            i += 1
            blank()
            while i < n and not md[i].startswith('```'):
                out += [(CODE, x) for x in code(md[i])]
                i += 1
            i += 1
            out.append((TEXT, ''))
            continue
        if ln.startswith('#'):
            blank()
            out += [(HEAD, x) for x in wrap(inline(ln.lstrip('#').strip()))]
            out.append((TEXT, ''))
            i += 1
            continue
        if ln.startswith('|'):                  # a table: each row its first cell, the others under it
            rows = []
            while i < n and md[i].startswith('|'):
                cells = [inline(c.strip()) for c in re.split(r'(?<!\\)\|', md[i].strip().strip('|'))]
                if not all(re.fullmatch(r':?-+:?', c) for c in cells):
                    rows.append(cells)
                i += 1
            blank()
            head, body = rows[0], rows[1:]
            for r in body:
                out += [(HEAD if len(head) > 1 else TEXT, x) for x in wrap(r[0])]
                for k, c in enumerate(r[1:], 1):
                    if c:
                        label = (head[k] + ': ') if len(head) > 2 and k < len(head) and head[k] else ''
                        out += [(TEXT, x) for x in wrap(label + c, '  ', '  ')]
            out.append((TEXT, ''))
            continue
        m = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)$', ln)
        if m:                                   # a list's item, with the lines that carry it on
            ind, mark, text = len(m.group(1)), m.group(2), m.group(3)
            i += 1
            while i < n and md[i].strip() and md[i].startswith(' ' * (ind + 2)) \
                    and not re.match(r'^\s*([-*]|\d+\.)\s', md[i]) and not md[i].lstrip().startswith('```'):
                text += ' ' + md[i].strip()
                i += 1
            lead = ' ' * ind + ('-' if mark in '-*' else mark) + ' '
            out += [(TEXT, x) for x in wrap(inline(text), lead, ' ' * len(lead))]
            if i < n and md[i].strip() and md[i].lstrip().startswith('```'):
                continue
            continue
        if not ln.strip():
            blank()
            i += 1
            continue
        text = ln.strip()
        i += 1
        while i < n and md[i].strip() and not re.match(r'^(#|\||```|<!--|\s*([-*]|\d+\.)\s)', md[i]):
            text += ' ' + md[i].strip()
            i += 1
        ind = '    ' if ln.startswith('    ') else ''
        out += [(TEXT, x) for x in wrap(inline(text), ind, ind)]
    while out and out[-1][1] == '':
        out.pop()
    wide = [t for _, t in out if len(t) > WIDTH]
    if wide:
        raise SystemExit(f"c64docs: a line over {WIDTH} columns: {wide[0]!r}")
    return out


def size(lines):
    return sum(len(t) + 2 for _, t in lines)


def pieces(md, level):
    """[(title, lines)] cut at the headings of level (and above); what
    comes before the first is the first piece, titled by the document"""
    out, cur, title = [], [], None
    fence = False
    for ln in md:
        if ln.startswith('```'):
            fence = not fence
        m = None if fence else re.match(r'^(#{1,%d}) (.*)$' % level, ln)
        if m:
            if cur and (title or any(x.strip() for x in cur)):
                out.append((title, cur))
            title, cur = inline(m.group(2).strip()), [ln] if len(m.group(1)) == 1 else []
            if len(m.group(1)) == 1:
                cur = []
        else:
            cur.append(ln)
    if cur:
        out.append((title, cur))
    return out


def chapters():
    """[{'group', 'title', 'file', 'lines': [(colour, text)], 'data': bytes}] and the index's bytes"""
    out = []
    for doc, group, spans in SOURCES:
        md = open(os.path.join(ROOT, doc)).read().splitlines()
        if spans:
            keep = []
            for a, b in spans:
                i = md.index(a)
                j = md.index(b) if b else len(md)
                keep += md[i:j]
            md = keep
        made = []
        for title, body in pieces(md, 2):       # the document's parts
            whole = render(body)
            if size(whole) <= MAX:
                made.append((title, whole))
                continue
            sub = [(t, render(b)) for t, b in pieces(body, 3)]      # a long part: a chapter for each
            cur_t, cur = None, []                                   # sub-heading (a very short one
            for t, lines in sub:                                    # joined to the one before it)
                t = t or title
                if cur and size(lines) >= SMALL:
                    made.append((cur_t, cur))
                    cur_t, cur = None, []
                if cur:
                    cur += [(TEXT, '')] + [(HEAD, x) for x in wrap(t)] + [(TEXT, '')] + lines
                else:
                    cur_t, cur = t, list(lines)
            if cur:
                made.append((cur_t, cur))
        for title, lines in made:
            if not any(t.strip() for _, t in lines):
                continue
            out.append(dict(group=group, title=title or group, lines=lines))
    idx, last = bytearray(), None
    for n, ch in enumerate(out, 1):
        ch['file'] = f'notes.{n:02d}'
        head = [(HEAD, x) for x in wrap(ch['title'])] + [(TEXT, '')]
        ch['lines'] = head + ch['lines']
        ch['data'] = b''.join(bytes([c]) + pet(t) + b'\r' for c, t in ch['lines'])
        if ch['group'] != last:
            idx += b':' + pet(ch['group'].lower()) + b'\r'
            last = ch['group']
        title = ch['title'].lower()
        if len(title) > 35:                     # (the menu's line: its number, then 35 columns)
            title = title[:34]
            title = title[:title.rindex(' ')].rstrip(' ,:') + '..'
        idx += pet(ch['file']) + b':' + pet(title) + b'\r'
    return out, bytes(idx)


def main():
    ch, idx = chapters()
    blocks = lambda n: -(-n // 254)
    for c in ch:
        print(f"  {c['file']}  {len(c['lines']):4d} lines {len(c['data']):6d} bytes {blocks(len(c['data'])):3d} blocks"
              f"  {c['title']}")
    total = sum(blocks(len(c['data'])) for c in ch) + blocks(len(idx))
    print(f"{len(ch)} chapters, {sum(len(c['data']) for c in ch)} bytes, {total} blocks with the index"
          f" ({len(idx)} bytes)")
    if len(sys.argv) > 1:
        os.makedirs(sys.argv[1], exist_ok=True)
        open(os.path.join(sys.argv[1], 'notes.idx'), 'wb').write(idx)
        for c in ch:
            open(os.path.join(sys.argv[1], c['file']), 'wb').write(c['data'])


if __name__ == '__main__':
    main()
