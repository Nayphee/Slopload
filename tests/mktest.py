#!/usr/bin/env python3
"""Make a self-checking test program for SlopLoad.

    mktest.py out.prg END [SEED]

A BASIC line (10 SYS2061) at $0801, a checker, then pseudo-random bytes up
to END (exclusive, hex or decimal). When run, the checker sums every byte
from $0900 to END with all ROMs and I/O banked out, and prints PASS or
FAIL on the screen with a green or red border. It also leaves $a5 (pass)
or $5a (fail) at $02ff for scripts.
"""
import os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import asm6502

SRC = """
*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        sei
        lda #$34
        sta $01
        lda #$00
        sta $fb
        sta $fd
        sta $fe
        lda #$09
        sta $fc
        ldy #0
loop    lda ($fb),y
        clc
        adc $fd
        sta $fd
        bcc nc
        inc $fe
nc      inc $fb
        bne nh
        inc $fc
nh      lda $fb
        cmp #<dend
        bne loop
        lda $fc
        cmp #>dend
        bne loop
        lda #$37
        sta $01
        cli
        lda $fd
        cmp #<want
        bne bad
        lda $fe
        cmp #>want
        bne bad
        ldx #5
        lda #$a5
        ldy #0
        beq show
bad     ldx #2
        lda #$5a
        ldy #4
show    sta $02ff
        stx $d020
        ldx #0
pr      lda msg,y
        sta $0400,x
        lda #1
        sta $d800,x
        iny
        inx
        cpx #4
        bne pr
        rts
msg     byte 16,1,19,19,6,1,9,12
"""

def main():
    out, end = sys.argv[1], int(sys.argv[2].replace('$', '0x'), 0)
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    rnd = random.Random(seed)
    data = bytes(rnd.randrange(256) for _ in range(end - 0x0900))
    want = sum(data) & 0xffff
    src = SRC.replace('#<dend', f'#${end & 255:02x}').replace('#>dend', f'#${end >> 8:02x}')
    src = src.replace('#<want', f'#${want & 255:02x}').replace('#>want', f'#${want >> 8:02x}')
    o, code, lab, _ = asm6502.assemble(src)
    assert o + len(code) <= 0x0900, "checker too long"
    mem = bytearray(code) + bytes(0x0900 - o - len(code)) + data
    open(out, 'wb').write(bytes([o & 255, o >> 8]) + mem)
    print(f"{out}: ${o:04X}-${end - 1:04X} ({len(mem)} bytes), sum ${want:04X}")

main()
