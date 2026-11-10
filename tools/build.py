#!/usr/bin/env python3
"""Build the SlopLoad loader parts and modules.

    python3 tools/build.py            # stage 1, core, every module in modules/

Each source is assembled with tools/asm6502.py (CBM prg Studio syntax).
`incasm "file"` lines are expanded here first (the verifier skips them),
so the sources stay loadable in prg Studio.

Writes to build/:
    stage1.bin / core.bin        raw bytes from the origin
    <name>.sym.json              every label -> address
    <name>.lst                   listing
    <name>.labels                VICE monitor labels (x64sc -moncommands)
    modules/<module>.prg         a module, as a PRG (and .lm)
"""
import json
import struct
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asm6502  # noqa: E402

BUILD = os.path.join(ROOT, 'build')
INC = re.compile(r'^\s+incasm\s+"([^"]+)"', re.I)


def expand(path, seen=None):
    """Source text with incasm lines replaced by the included file."""
    seen = seen or set()
    path = os.path.abspath(path)
    if path in seen:
        raise SystemExit(f"include loop at {path}")
    seen = seen | {path}
    out = []
    for line in open(path).read().splitlines():
        m = INC.match(line)
        if m:
            name = m.group(1)
            cands = [os.path.join(os.path.dirname(path), name),
                     os.path.join(ROOT, 'src', name)]
            inc = next((c for c in cands if os.path.exists(c)), None)
            if inc is None:
                raise SystemExit(f"{path}: cannot find include {name}")
            out.append(f"; ---- incasm {name}")
            out.extend(expand(inc, seen).splitlines())
            out.append(f"; ---- end {name}")
        else:
            out.append(line)
    return '\n'.join(out) + '\n'


def assemble(path, name, subst=None, transform=None):
    """Assemble one source. Returns (origin, data, labels).
    subst: {equate name: value} replaces `name = ...` lines; transform:
    a function of the expanded source's text, applied first
    (tools/c64build.py's message packing)"""
    src = expand(path)
    if transform:
        src = transform(src)
    for k, v in (subst or {}).items():
        src, n = re.subn(rf'(?m)^{k}\s*=.*$', f'{k} = ${v:04x}', src)
        if n != 1:
            raise SystemExit(f"{path}: expected one '{k} =' line, found {n}")
    try:
        origin, data, labels, listing = asm6502.assemble(src)
    except asm6502.AsmError as ex:
        # line numbers refer to the expanded text: show it
        dump = os.path.join(BUILD, name + '.expanded.asm')
        open(dump, 'w').write(src)
        raise SystemExit(f"{path}: {ex}\n(expanded source: {dump})")
    os.makedirs(BUILD, exist_ok=True)
    with open(os.path.join(BUILD, name + '.lst'), 'w') as f:
        for n, pc, code, raw in listing:
            addr = f"{pc:04X}" if pc is not None else '    '
            hx = ' '.join(f"{b:02X}" for b in code[:6]) + (' ..' if len(code) > 6 else '')
            f.write(f"{addr}  {hx:<20} {raw.rstrip()}\n")
    json.dump({k: v for k, v in labels.items()},
              open(os.path.join(BUILD, name + '.sym.json'), 'w'), indent=0, sort_keys=True)
    with open(os.path.join(BUILD, name + '.labels'), 'w') as f:
        for k, v in sorted(labels.items(), key=lambda kv: kv[1]):
            if '@' not in k:
                f.write(f"al {v:04x} .{k}\n")
    return origin, data, labels


def build_loader():
    # stage 1: the low part (KERNAL data block) is moved up so that it
    # ends at $02ff, right before the BASIC vectors it also carries
    src = os.path.join(ROOT, 'src', 'stage1.asm')
    o, d, lab = assemble(src, 'stage1')
    low = lab['s1lowend'] - lab['s1lo']
    o, d, lab = assemble(src, 'stage1', {'s1lo': 0x0300 - low})
    if lab['s1rel'] != lab['s1ioi']:
        raise SystemExit(f"stage1: s1rel must be at abi.asm's s1ioi, is ${lab['s1rel']:04X}")
    if lab['s1lowend'] != 0x0300 or o < 0x02a7:
        raise SystemExit(f"stage1 low part must fit $02a7-$02ff ({low} bytes)")
    end = o + len(d)
    if end > 0x03fc:
        raise SystemExit(f"stage1 header part must end by $03fb, ends ${end - 1:04X}")
    mem = bytearray(0x10000)
    mem[o:end] = d
    open(os.path.join(BUILD, 'stage1_block.bin'), 'wb').write(mem[o:0x0304])
    open(os.path.join(BUILD, 'stage1_header.bin'), 'wb').write(mem[0x0351:end])
    print(f"stage1  data block ${o:04X}-$0303 {0x0304 - o:3d} bytes,"
          f" header part $0351-${end - 1:04X} {end - 0x0351:3d} bytes ({0x03fc - end} spare)")

    build_core('core', False)
    build_core('core_measure', True)            # tests: timestamps every edge
    # tests: no tracking (clv: b_data reads v as "this block stores under i/o")
    build_core('core_nopll', False, edits=[('        bvc pd_dibit', '        clv\n        jmp pd_dibit'),
                                           ('        bvc pd_pfx', '        clv\n        jmp pd_pfx')])
    # border stripes in a style (slopload.py -stripes): the colour from a
    # table the tool fills, 4 cycles more in the interrupt
    build_core('core_stripes', False, blocks=STRIPE_EDITS)
    # loading line effects (slopload.py -stripes classic, thin, and:N,
    # ora:N, eor:N, mixed): 8 bytes of the tool's code at the stripe
    build_core('core_fx', False, blocks=FX_EDITS)
    # no stripes, the border one colour (slopload.py -stripes black, 6,
    # block): the per-pulse store off, the colour kept by the main loop
    build_core('core_flat', False, blocks=FLAT_EDITS)
    flat_check()
    for name in ('core', 'core_stripes', 'core_flat', 'core_fx'):      # (setm: low bytes only)
        lb = json.load(open(os.path.join(BUILD, name + '.sym.json')))
        for t in ('cbase', 'pbase'):
            if (lb[t] & 0xff) + 14 > 0x100:
                raise SystemExit(f"{name}: {t} crosses a page (setm sets its low byte only)")
    lb = json.load(open(os.path.join(BUILD, 'core_fx.sym.json')))
    if (lb['stripe'] & 0xff) + 8 > 0x100:
        raise SystemExit("core_fx: the effect crosses a page (the tool sets its stores' low bytes)")
    lab = json.load(open(os.path.join(BUILD, 'core_stripes.sym.json')))
    if (lab['stab'] & 0xff) > 0x100 - 12:
        raise SystemExit("core_stripes: the colour table crosses a page (a cycle more)")


# the stripes variant: whole-text replacements, each found exactly once
STRIPE_EDITS = [
    ("stripe  stx $d020               ; border stripes ($2c: bit, when off)",
     "stripe  lda stab,x              ; the style's colour (slopload.py -stripes)\n"
     "stripe3 sta $d020               ; border stripes ($2c: bit, when off)"),
    ("fstr    lda #$8e\n        sta stripe              ; stx: stripes on",
     "fstr    lda #$8d\n        sta stripe3             ; sta: stripes on"),
    ("@ok     lda #$8e                ; stx $d020\n        sta stripe\n",
     "@ok     lda #$8d                ; sta $d020\n        sta stripe3\n"),
    ("stroff  lda #$2c                ; bit $d020\n        sta stripe\n",
     "stroff  lda #$2c                ; bit $d020\n        sta stripe3\n"),
    ("g_init  jmp (pt_init)",
     "stab    byte 0,1,2,3,4,5,6,7,8,9,10,11   ; colour by timer b value (the tool)\n"
     "g_init  jmp (pt_init)"),
]


# the effects variant (slopload.py -stripes classic, thin, and:N, ora:N,
# eor:N, mixed): where the core has stx $d020, the effect's 8 bytes (the
# tool's, as classic loaders did it). Its stores (one or two) are turned
# off by stroff (bit $d020) and on by stron, which also puts the border
# back to the effect's own colour (after a tape error's red); the tool
# sets their opcodes and places (fxs: the stores' low bytes, the effect
# within a page). Made so that SlopLoad 64 can make it from the core in
# place (c64build.py fx_patch): the effect's 5 more bytes the only thing
# inserted, fstr, errshow's way back and stroff changed at their own
# length, and stron after everything
FX_LEN = 8
FX_EDITS = [
    ("stripe  stx $d020               ; border stripes ($2c: bit, when off)",
     "stripe  lda $d020               ; the effect, 8 bytes (the tool's)\n"
     "        eor #$00\n"
     "        inc $d020"),
    ("fstr    lda #$8e\n        sta stripe              ; stx: stripes on",
     "fstr    jsr stron               ; stripes on\n"
     "        nop\n"
     "        nop"),
    ("@ok     lda #$8e                ; stx $d020\n        sta stripe\n        rts\n",
     "@ok     jmp stron\n        nop\n        nop\n        nop\n"),
    ("stroff  lda #$2c                ; bit $d020\n        sta stripe\n        rts\n",
     "stroff                          ; off: the stores bit $d020 (uses a, x)\n"
     "fxa0    lda #$ad                ; (opcodes: the tool's)\n"
     "fxb0    ldx #$2c\n"
     "        bne fxs                 ; (always)\n"),
    ("\nxstubend\n",
     "\nxstubend\n"
     "stron                           ; on: the border the effect's colour,\n"
     "fxbc    lda #0                  ; (the tool's)\n"
     "        sta $d020\n"
     "fxa1    lda #$ad                ; and its stores (opcodes: the tool's)\n"
     "fxb1    ldx #$ee\n"
     "fxs     sta stripe              ; (their places: the tool's)\n"
     "fxs2    stx stripe+5\n"
     "        rts\n"),
]


# the flat border variant (slopload.py -stripes black, 6, block; SlopLoad
# 64's styles black, block, one colour): the core with a few bytes
# changed and its layout kept, so SlopLoad 64 makes it from the core it
# has by flipping them (c64build.py, flat_patch). No stripes (the
# per-pulse store and the final phase's are bit $d020); errshow, the
# main loop's, keeps the border's colour (bflat: ldx ld_seq, a colour a
# block, or the tool's ldx #colour; red on a tape error) through bset,
# after the exit stub, which writes it only when it changes: on a newer
# VIC-II (8565) every write to a colour register leaves a grey dot, and
# the main loop runs this all the time. errshow keeps its length (padded).
FLAT_EDITS = [
    ("stripe  stx $d020               ; border stripes ($2c: bit, when off)",
     "stripe  bit $d020               ; (core_flat: no stripes)"),
    ("fstr    lda #$8e\n        sta stripe              ; stx: stripes on",
     "fstr    lda #$2c\n        sta stripe              ; (core_flat: no stripes)"),
    ("errshow bit ld_state\n        bvc @ok\n        jsr stroff\n        lda #2\n        sta $d020\n        rts\n"
     "@ok     lda #$8e                ; stx $d020\n        sta stripe\n        rts\nersend",
     "errshow\n"
     "bflat   ldx ld_seq              ; the border's colour: the block's (or ldx #colour)\n"
     "        bit ld_state\n        bvc @s\n        ldx #2                  ; a tape error: red\n"
     "@s      jmp bset\n"
     "        byte 0,0,0,0,0,0,0,0     ; (errshow's own length)\n"
     "ersend"),
    ("\nxstubend\n",
     "\nxstubend\n"
     "bset    txa                     ; the border to colour x, when it differs\n"
     "        eor $d020\n        and #15\n        beq @x\n        stx $d020\n@x      rts\n"),
]


def flat_check():
    """core_flat is the core with bytes changed only where FLAT_EDITS says:
    the two stores' opcodes, errshow (its length kept) and bset after
    everything (SlopLoad 64 flips just those bytes)"""
    a = open(os.path.join(BUILD, 'core.bin'), 'rb').read()
    b = open(os.path.join(BUILD, 'core_flat.bin'), 'rb').read()
    la, lb = (json.load(open(os.path.join(BUILD, n + '.sym.json'))) for n in ('core', 'core_flat'))
    for k in ('errshow', 'ersend', 'stripe', 'fstr', 'xstubend', 'g_init', 'pt_step', 'x_run'):
        if la[k] != lb[k]:
            raise SystemExit(f"core_flat: {k} moved (${la[k]:04X} / ${lb[k]:04X})")
    ok = {la['stripe'] - 0x400, la['fstr'] + 1 - 0x400} | set(range(la['errshow'] - 0x400, la['ersend'] - 0x400))
    diff = [i for i in range(len(b)) if i >= len(a) or a[i] != b[i]]
    bad = [i for i in diff if i not in ok and i < len(a)]
    if bad or lb['bset'] - 0x400 < len(a):
        raise SystemExit(f"core_flat: differs from the core outside its places: {[hex(0x400 + i) for i in bad]}")


def build_core(name, measure, subst=None, edits=(), blocks=()):
    """The core; the measuring build enables the lines marked ;measure,
    edits replace exact source lines (test variants), blocks replace
    exact pieces of text."""
    path = os.path.join(ROOT, 'src', 'core.asm')
    if measure or edits or blocks:
        text = open(path).read()
        if measure:                         # timestamps in, speed tracking out
            text = re.sub(r'(?m)^;measure', '', text)
            text = re.sub(r'(?m)^.*;-measure.*\n', '', text)
        for old, new in edits:
            if text.count(old + '\n') != 1:
                raise SystemExit(f"{name}: expected one line '{old}'")
            text = text.replace(old + '\n', new + '\n')
        for old, new in blocks:
            if text.count(old) != 1:
                raise SystemExit(f"{name}: expected one '{old.splitlines()[0]}'")
            text = text.replace(old, new)
        path = os.path.join(BUILD, name + '.asm')
        os.makedirs(BUILD, exist_ok=True)
        open(path, 'w').write(text.replace('incasm "abi.asm"', f'incasm "{os.path.join(ROOT, "src", "abi.asm")}"'))
    o, d, lab = assemble(path, name, subst)
    end = o + len(d)
    if o != 0x0400 or end > 0x0800:
        raise SystemExit(f"core must fit $0400-$07ff, is ${o:04X}-${end - 1:04X}")
    stub = lab['xstubend'] - lab['xstub']
    if 0x0334 + stub > 0x03fc:
        raise SystemExit(f"exit stub too long for the tape buffer ({stub} bytes)")
    open(os.path.join(BUILD, name + '.bin'), 'wb').write(d)
    print(f"{name:7s} ${o:04X}-${end - 1:04X}  {len(d):4d} bytes  (exit stub {stub} bytes)")


CHAIN_PETSCII = 0xa000          # PETSCII-Load's main part in a chain (slopload.py -then)


def build_modules():
    gdir = os.path.join(ROOT, 'modules')
    os.makedirs(os.path.join(BUILD, 'modules'), exist_ok=True)
    for g in sorted(os.listdir(gdir)):
        src = os.path.join(gdir, g, g + '.asm')
        if not os.path.exists(src):
            continue
        gen = os.path.join(gdir, g, 'mkdata.py')
        if os.path.exists(gen):          # generated graphics/tables
            r = os.system(f'{sys.executable} "{gen}"')
            if r:
                raise SystemExit(f"{gen} failed")
        o, d, lab = assemble(src, 'module_' + g)
        low = None
        if 'lowpart' in lab:            # a second part, below the main one (lowpart-lowend)
            lo, hi, top = lab['lowpart'], lab['lowend'], lab['mainpart']
            low = (lo, d[lo - o:hi - o])
            if hi > 0xd000 and lo < 0xe000:
                raise SystemExit(f"{g}: its low part ${lo:04X}-${hi - 1:04X} runs into $D000-$DFFF"
                                 " (i/o: the cpu can't run code there)")
            d, o = d[top - o:], top
        end = o + len(d)
        if 'initend' in lab and lab['initend'] > lab['initpart'] - 256 + 1000:
            raise SystemExit(f"{g}: its setting up (boot.asm) runs into screen a's last 24 bytes"
                             f" (by {lab['initend'] - (lab['initpart'] - 256 + 1000)})")
        if d[:4] != b'PLG1':
            raise SystemExit(f"{g}: a module must start with the bytes 'PLG1'")
        open(os.path.join(BUILD, 'modules', g + '.prg'), 'wb').write(asm6502.to_prg(o, d))
        print(f"module {g:8s} ${o:04X}-${end - 1:04X}  {len(d):4d} bytes")
        # the module in one file for SlopLoad 64 (MODULES.md): each part's
        # address, length and bytes, the main part (the header's) first
        lm = struct.pack('<HH', o, len(d)) + bytes(d)
        spec = {}
        if low:
            lp = os.path.join(BUILD, 'modules', g + '_low.prg')
            open(lp, 'wb').write(asm6502.to_prg(*low))
            print(f"     {g + ' low':8s} ${low[0]:04X}-${low[0] + len(low[1]) - 1:04X}  {len(low[1]):4d} bytes")
            spec['low'] = {'prg': lp, 'always': True}
            lm += struct.pack('<HH', low[0], len(low[1])) + bytes(low[1])
        open(os.path.join(BUILD, 'modules', g + '.lm'), 'wb').write(lm)
        if g == 'petscii':              # (and at $a000 for a chain, clear of a picture: petscii.py)
            o2, d2, lab2 = assemble(src, 'module_petscii_chain', {'petbase': CHAIN_PETSCII,
                                                                   'lowat': CHAIN_PETSCII - 0x400})
            top = lab2['mainpart']
            if bytes(d2[:lab2['lowend'] - o2]) != bytes(low[1]):
                raise SystemExit("petscii: the chain's build has another screen part")
            if lab2['modend'] > 0xb000:
                raise SystemExit("petscii: the chain's build runs into a font's room at $B000")
            open(os.path.join(BUILD, 'modules', 'petscii_chain.prg'), 'wb').write(
                asm6502.to_prg(top, d2[top - o2:]))
            print(f"     {'(chain)':8s} ${top:04X}-${lab2['modend'] - 1:04X}  {lab2['modend'] - top:4d} bytes")
        if g == 'show':                 # (the tools build it in: no .lm)
            os.remove(os.path.join(BUILD, 'modules', g + '.lm'))
        parts = os.path.join(gdir, g, 'parts.json')     # extra files a module brings
        built = os.path.join(BUILD, 'modules', g + '.parts.json')
        if not os.path.exists(parts) and not spec and os.path.exists(built):
            os.remove(built)                            # (one from before: nothing now)
        if os.path.exists(parts) or spec:
            spec.update(json.load(open(parts)) if os.path.exists(parts) else {})
            for k, v in spec.items():       # paths: beside the parts file, else from SlopLoad's folder
                if isinstance(v, dict) and 'prg' in v:
                    p = os.path.normpath(os.path.join(gdir, g, v['prg']))
                    if not os.path.exists(p):
                        print(f"  warning: {g} part '{k}' missing: {p}")
                    mods = os.path.join(BUILD, 'modules')
                    v['prg'] = os.path.relpath(p, mods if p.startswith(mods + os.sep) else ROOT)
            json.dump(spec, open(os.path.join(BUILD, 'modules', g + '.parts.json'), 'w'), indent=1)


if __name__ == '__main__':
    build_loader()
    build_modules()
