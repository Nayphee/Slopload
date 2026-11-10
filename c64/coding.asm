; ------------------------------------------------------------
; coding.asm  -  SlopLoad 64's choice of how each block is written, as
; tools/c64model.py's choose(): every pulse set (h from the block's
; least, m 2-4, every pulse 208 cycles or more), 2 bits a pulse (each
; position's best key) or the prefix code (the key with more 1 bits),
; quickest first; while the game runs, the first that keeps the loader
; within the game's share of the cpu in every frame's worth of tape.
;
; The block's data is at blkb+10 (n bytes). anablk leaves the choice in
; bh, bm, bpf, bk[blk]; encblk lays the block out for the writer.
; ------------------------------------------------------------

pfxs = $a009                    ; prefix symbols (under the BASIC rom, out)
pfxh = pfxs - 9                 ; ... after the block's header

; ------------------------------------------------------------
; anablk  block blk: its check and keys, both codings' lengths, the choice
; ------------------------------------------------------------
anablk  jsr freqs               ; bchk, bkey (2 bits), pkey
        lda pkey
        jsr pfxenc              ; np, sp, pcost (and the symbols)
        lda p2                  ; (kept for layblk: the same block's symbols
        sta pfxe                ; with the same key need no second encoding)
        lda p2+1
        sta pfxe+1
        lda pkey
        sta pfxk
        lda blk
        sta pfxb
        lda bkey
        jsr xordata             ; the data keyed: the 2-bit body at blkb+9
        jsr padchk              ; (its pad and check around it)
        jsr sumbody             ; sk
        jsr choose
        php
        lda bkey                ; the data as it was
        jsr xordata
        plp
        rts

; padchk  $ff before the data, its check after
padchk  lda #$ff
        sta blkb+9
        ldx blk
        lda #<(blkb+10)
        clc
        adc bll,x
        sta p3
        lda #>(blkb+10)
        adc blh,x
        sta p3+1
        ldy #0
        lda bchk
        sta (p3),y
        rts

; ------------------------------------------------------------
; layblk  block blk laid out for the writer as chosen (the data at
; blkb+10 as read): its header (pulse set 4), its body (2 bits a pulse
; or the prefix code), then the bridge (written in one go, but the last
; block) or its trailer; lay/layn: where and how long
; ------------------------------------------------------------
layblk  jsr bdata               ; bchk: the data's xor
        lda #0
        sta bchk
@c      lda t2
        ora t3
        beq @k
        ldy #0
        lda (p1),y
        eor bchk
        sta bchk
        jsr bnext
        jmp @c
@k      ldx blk
        lda bpf,x
        bne @pfx
        lda bk,x                ; 2 bits a pulse: in place
        jsr xordata
        jsr padchk
        lda #<blkb
        sta p3
        lda #>blkb
        sta p3+1
        jsr bhead
        ldx blk                 ; the tail after the check
        lda #<(blkb+11)
        clc
        adc bll,x
        sta p2
        lda #>(blkb+11)
        adc blh,x
        sta p2+1
        jmp @tr
@pfx    lda bk,x                ; the prefix code: symbols at pfxs
        cmp pfxk                ; (there already: this block's, this key)
        bne @enc
        cpx pfxb
        bne @enc
        lda pfxe
        sta p2
        lda pfxe+1
        sta p2+1
        jmp @hd
@enc    jsr pfxenc              ; (p2: after them)
@hd     lda #<pfxh
        sta p3
        lda #>pfxh
        sta p3+1
        jsr bhead
@tr     jsr bridged
        bcc @tz
        lda #$0f                ; the bridge
        ldy #0
        sta (p2),y
        iny
        bne @zx
@tz     ldx blk                 ; the trailer: zero bytes
        lda bh,x
        sta t7
        lda bm,x
        sta t6
        jsr trailn              ; t2 bytes
        ldy #0
        tya
@z      cpy t2
        bcs @zx
        sta (p2),y
        iny
        bne @z
@zx     tya                     ; the length: p2 + y - start
        clc
        adc p2
        sta t2
        lda p2+1
        adc #0
        sta t3
        lda t2
        sec
        sbc p3
        sta layn
        lda t3
        sbc p3+1
        sta layn+1
        lda p3
        sta lay
        lda p3+1
        sta lay+1
        rts
lay     word 0
layn    word 0

; bridged  c set if block blk ends on the bridge (the tape written in
; one go, and not the last block), clear if on its trailer
bridged lda opt_cont
        beq @no
        ldx blk
        inx
        cpx nblk
        bcs @no
        sec
        rts
@no     clc
        rts

; ------------------------------------------------------------
; secblk  block blk's sections at p2: its pilot and sync, then its bytes
; (lay/layn in memory, or the stream's next layn bytes): the header in
; pulse set 4, the rest in its own set; p2 after them
;   out:  c set if there are too many pulse sets (said)
; ------------------------------------------------------------
secblk  ldx blk                 ; its tables: set 4 and its own, at its h
        lda bh,x
        ldy #4
        jsr gettab
        bcs @x
        stx tabA
        ldx blk
        lda bm,x
        tay
        lda bh,x
        jsr gettab
        bcs @x
        stx tabB
        jsr blkpil              ; its pilot and sync
        jsr pilotn              ; t0/t1
        lda tabA
        jsr secpil
        lda lay                 ; its bytes
        sta t0
        lda lay+1
        sta t1
        lda layn
        sta t2
        lda layn+1
        sta t3
        lda tabA
        sta t4
        lda #9
        sta t5
        lda tabB
        sta t6
        lda xmem                ; (from the stream: type 3)
        beq @d
        lda #3
        sta dibtype
@d      jsr secdib
        lda #2
        sta dibtype
        clc
@x      rts
tabA    byte 0
tabB    byte 0
cph     byte 0                  ; choose: 1 for a chain's second module's block

; blkpil  block blk's pilot: a/x its length's table, t7 its quantum
blkpil  ldx blk
        lda bh,x
        sta t7
        lda bset,x
        and #$40
        bne @res
        lda opt_cont
        beq @rst
        lda blk
        bne @blk
        lda #<pilfirst          ; written in one go: the first block's,
        ldx #>pilfirst
        rts
@blk    lda #<pilblk            ; ... then the short one
        ldx #>pilblk
        rts
@rst    lda #<pilrest           ; a block at a time: the motor restarting
        ldx #>pilrest
        rts
@res    lda #<pilres            ; after the game: the loader restarting it
        ldx #>pilres
        rts

; bhead  block blk's 9 header bytes at p3 (key bk, set bm, prefix bpf)
bhead   ldx blk
        ldy #0
        lda bal,x
        sta (p3),y
        iny
        lda bah,x
        sta (p3),y
        iny
        lda bll,x
        sta (p3),y
        iny
        clc
        adc #255
        lda blh,x
        adc #0
        sta (p3),y
        iny
        lda bk,x
        sta (p3),y
        iny
        lda bm,x                ; flags: m - 2 in bits 4-5, prefix bit 6
        sec
        sbc #2
        asl a
        asl a
        asl a
        asl a
        ora bfl,x
        sta t0
        lda bpf,x
        beq @f
        lda #$40
        ora t0
        sta t0
@f      lda t0
        sta (p3),y
        iny
        txa
        sta (p3),y              ; its number
        iny
        lda bprog,x
        sta (p3),y
        lda #$a5                ; the check
        ldy #7
@c      eor (p3),y
        dey
        bpl @c
        ldy #8
        sta (p3),y
        rts

; bpulses  block blk's pulses on tape (as chosen, from anablk's np):
; pilot and sync, header, body, bridge or trailer, added to tapn
bpulses jsr blkpil
        jsr pilotn
        lda t0
        ldy t1
        jsr addn
        lda #36                 ; the header: 9 bytes
        ldy #0
        jsr addn
        jsr bridged
        bcc @tr
        lda #4                  ; the bridge: a byte
        ldy #0
        jsr addn
        jmp @bd
@tr     ldx blk                 ; the trailer: 4 a byte
        lda bm,x
        sta t6
        jsr trailn
        lda t2
        sta t0
        lda #0
        asl t0
        rol a
        asl t0
        rol a
        tay
        lda t0
        jsr addn
@bd     ldx blk
        lda bpf,x
        bne @p2
        lda bll,x               ; 2 bits: 4 x (n + 2)
        clc
        adc #2
        sta t0
        lda blh,x
        adc #0
        jmp @b
@p2     lda np                  ; prefix: np up to a multiple of 4
        clc
        adc #3
        and #$fc
        sta t0
        lda np+1
        adc #0
        sta t1
        lda t0
        ldy t1
        jmp addn
@b      asl t0
        rol a
        asl t0
        rol a
        tay
        lda t0
        jmp addn

; ------------------------------------------------------------
; freqs  bchk (the data's xor), bkey (each 2-bit position's most common
; pair to class 0, the lowest on a tie), pkey (a bit set where fewer than
; half the bytes have it)
; ------------------------------------------------------------
freqs   ldx #31
        lda #0
@z      sta freq,x
        dex
        bpl @z
        ldx #15
@z2     sta ones,x
        dex
        bpl @z2
        sta bchk
        jsr bdata
@c      lda t2
        ora t3
        bne @c1
        jmp @k
@c1     ldy #0
        lda (p1),y
        sta t0
        eor bchk
        sta bchk
        lda t0                  ; the bits' counts (16-bit, bit 0 first)
        ldx #0
@o      lsr a
        bcc @o1
        inc ones,x
        bne @o1
        inc ones+8,x
@o1     inx
        cpx #8
        bcc @o
        ldx #0                  ; 4 positions: pairs from the top
@p      lda #0
        asl t0
        rol a
        asl t0
        rol a
        stx t1
        ora t1
        asl a
        tay
        lda freq,y
        clc
        adc #1
        sta freq,y
        bcc @pn
        lda freq+1,y
        adc #0
        sta freq+1,y
@pn     inx
        inx
        inx
        inx
        cpx #16
        bcc @p
        jsr bnext
        jmp @c
@k      jsr bestkey
        lda #0                  ; pkey: bit set where ones * 2 < n
        sta pkey
        ldx #7
@pk     lda ones,x              ; ones * 2
        asl a
        sta t0
        lda ones+8,x
        rol a
        sta t1
        ldy blk
        lda t0
        cmp bll,y
        lda t1
        sbc blh,y
        rol pkey                ; (c clear: fewer: that bit 1, set below)
        dex
        bpl @pk
        lda pkey
        eor #$ff                ; (the rol shifted in "not fewer")
        sta pkey
        rts
ones    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pkey    byte 0
bkey    byte 0
bchk    byte 0

; bestkey  bkey from freq: per 2-bit position, the key making it shortest
bestkey lda #0
        sta bkey
        ldx #0
@kp     stx t6
        lda #$ff
        sta t4
        sta t5
        lda #0
        sta t7
@kk     lda #0
        sta t2
        sta t3
        ldy #0
@kv     tya
        eor t7
        sta t1
        tya
        clc
        adc t6
        asl a
        tax
@ka     lda t1
        beq @kn
        lda t2
        clc
        adc freq,x
        sta t2
        lda t3
        adc freq+1,x
        sta t3
        dec t1
        jmp @ka
@kn     iny
        cpy #4
        bcc @kv
        lda t2
        cmp t4
        lda t3
        sbc t5
        bcs @kw
        lda t2
        sta t4
        lda t3
        sta t5
        lda t7
        sta t0
@kw     inc t7
        lda t7
        cmp #4
        bcc @kk
        lda bkey
        asl a
        asl a
        ora t0
        sta bkey
        lda t6
        clc
        adc #4
        tax
        cpx #16
        bcc @kp
        rts

; xordata  the data xor a (in place)
xordata sta t4
        jsr bdata
@x      lda t2
        ora t3
        beq @r
        ldy #0
        lda (p1),y
        eor t4
        sta (p1),y
        jsr bnext
        jmp @x
@r      rts

; sumbody  sk: the 2-bit body's pairs summed (pad $ff: 12, the data
; keyed, the check)
sumbody lda #12
        sta sk
        lda #0
        sta sk+1
        ldx bchk
        lda dibsum,x
        jsr @add
        jsr bdata
@s      lda t2
        ora t3
        beq @r
        ldy #0
        lda (p1),y
        tax
        lda dibsum,x
        jsr @add
        jsr bnext
        jmp @s
@add    clc
        adc sk
        sta sk
        bcc @r
        inc sk+1
@r      rts
sk      word 0

; ------------------------------------------------------------
; pfxenc  the prefix code of $00, the data xor a, the check: symbols at
; pfxs (4 a byte, padded with class 0 to a whole byte, not counted); np
; the pulses, sp their classes summed, pcost the loader's cost (88, 99,
; 108, 105 by class, and 50 for the pulse that completes a byte)
; ------------------------------------------------------------
pfxenc  sta pek
        lda #$ff                ; (pfxs rewritten: anablk's no longer there)
        sta pfxb
        lda #<pfxs
        sta p2
        lda #>pfxs
        sta p2+1
        lda #0
        sta np
        sta np+1
        sta sp
        sta sp+1
        sta sp+2
        sta pcost
        sta pcost+1
        sta pcost+2
        sta nbm                 ; code bits so far, mod 8
        sta symn
        lda #0                  ; the stream: $00 first
        sta pebyte
        lda #8
        sta pebits
        lda #0
        sta pephase             ; 0 the pad, 1 the data, 2 the check, 3 done
        jsr bdata
@code   lda pebits              ; no bits left, and none to come: done
        bne @b1
        jsr pefill
        bcc @b1
        jmp @done
@b1     dec pebits              ; a 1 first: class 0
        asl pebyte
        bcs @c0
        lda pebits              ; (past the end, the bits are 1)
        bne @b2
        jsr pefill
        bcs @c1
@b2     dec pebits              ; 01: class 1
        asl pebyte
        bcs @c1
        lda pebits
        bne @b3
        jsr pefill
        bcs @c2
@b3     dec pebits              ; 001: class 2, 000: class 3
        asl pebyte
        bcs @c2
        ldx #3
        bne @put
@c0     ldx #0
        beq @put
@c1     ldx #1
        bne @put
@c2     ldx #2
@put    stx t5                  ; class x: stored (4 a byte, first at the top),
        txa                     ; counted, costed
        asl symacc
        asl symacc
        ora symacc
        sta symacc
        inc symn
        lda symn
        cmp #4
        bne @s1
        lda #0
        sta symn
        tay
        lda symacc
        sta (p2),y
        inc p2
        bne @s1
        inc p2+1
@s1     inc np
        bne @s2
        inc np+1
@s2     txa                     ; sp: the classes summed
        clc
        adc sp
        sta sp
        bcc @s3
        inc sp+1
        bne @s3
        inc sp+2
@s3     lda nbm                 ; completes a byte? 50 more
        clc
        adc pfbits,x
        cmp #8
        bcc @s4
        sbc #8
        sta nbm
        lda pfcost,x
        clc
        adc #50
        jmp @s5
@s4     sta nbm
        lda pfcost,x
@s5     sta t6
        clc
        adc pcost
        sta pcost
        bcc @s6
        inc pcost+1
        bne @s6
        inc pcost+2
@s6     jmp @code
@done   lda symn                ; pad the last byte with class 0
        beq @x
        lda #0
        jsr putsym2
        jmp @done
@x      rts
pek     byte 0
pfxb    byte $ff                ; the block whose symbols pfxs holds ($ff: none),
pfxk    byte 0                  ; their key, and their end (anablk's)
pfxe    word 0
pebyte  byte 0
pebits  byte 0
pephase byte 0
nbm     byte 0
np      word 0
sp      byte 0,0,0
pcost   byte 0,0,0
pfbits  byte 1,2,3,3
pfcost  byte 88,99,108,105

; putsym2  symbol a into the bytes at p2, 4 a byte, first at the top
putsym2 asl symacc
        asl symacc
        ora symacc
        sta symacc
        inc symn
        lda symn
        cmp #4
        bne @x
        lda #0
        sta symn
        tay
        lda symacc
        sta (p2),y
        inc p2
        bne @x
        inc p2+1
@x      rts

; pefill  the stream's next byte (penext), if there is one: c set when
; there are no bits left (past the check)
pefill  lda pephase
        cmp #3
        bcs @x                  ; (c set)
        jsr penext
        lda pebits
        bne @ok
        sec
        rts
@ok     clc
@x      rts

; penext  the stream's next byte into pebyte (pebits 8), or done
penext  lda pephase
        beq @data
        cmp #1
        beq @data1
        cmp #2
        beq @end
        rts
@data   inc pephase             ; after the pad: the data
@data1  lda t2
        ora t3
        beq @chk
        ldy #0
        lda (p1),y
        eor pek
        sta pebyte
        lda #8
        sta pebits
        jmp bnext
@chk    lda #2
        sta pephase
        lda bchk
        sta pebyte
        lda #8
        sta pebits
        rts
@end    lda #3                  ; past the check
        sta pephase
        rts

; ------------------------------------------------------------
; choose  the block's coding: candidates by length (cycles = h x base),
; six lists (2 bits, prefix; m 2-4) merged; each checked with a game
; ------------------------------------------------------------
choose  ldx blk                 ; nbody = n + 2 (pad, check)
        lda bll,x
        clc
        adc #2
        sta nbody
        lda blh,x
        adc #0
        sta nbody+1
        lda #0                  ; (every pulse 208 cycles or more; 212 with
        sta hlo                 ; a style's colour lookup, the screen on)
        lda bset,x              ; (bit 1: a chain's second module, at the
        and #2                  ; first's jitter and share: mdjit+1, mdshr+1)
        lsr a
        sta cph
        lda bset,x              ; the least h, and the share (0: none)
        and #1
        beq @boot
        ldx opt_speed           ; the module's: with the screen on, the
        lda mdscr               ; speed's h + its jitter rounded up to 4
        beq @off                ; (124 at most); off, as at boot
        jsr fxon                ; (core_fx: the effect's cost, the cycle's 3)
        bcs @fx
        jsr flatcol             ; (a table style's lookup: 4 cycles more,
        bcs @n4                 ; an effect's 6-10: every pulse 212 or 218;
        lda opt_lines           ; 1-8 more is 212's sets, 9-16 218's)
        beq @n4
        lda #6
        bne @h6
@fx     lda opt_lines
        cmp #st_fx
        lda #0                  ; (the plain one: 0)
        bcc @pc
        ldy opt_fx
        lda fxcost,y
@pc     ldy opt_cyc
        beq @c3
        clc
        adc #3
@c3     cmp #1
        bcc @n4
        cmp #9
        lda #6
        bcc @h6
        lda #12
@h6     sta hlo
@n4     ldy cph
        lda mdjit,y
        clc
        adc #3
        and #$fc
        clc
        adc spdh,x
        bcs @cap
        cmp #125
        bcc @l2
@cap    lda #124
        bne @l2
@off    lda hminb,x
@l2     sta hmin
        ldy cph
        lda mdshr,y
        sta share
        jmp @b
@boot   ldx opt_speed
        lda hminb,x
        sta hmin
        lda #0
        sta share
@b      ldx hlo                 ; h0 = max(hmin, 52; 56 at 212 cycles)
        lda hmin
        cmp hlow+2,x
        bcs @h0
        lda hlow+2,x
@h0     sta hmin
        ldx #0                  ; the six lists: base and first h
@l      jsr lbase
        txa
        clc
        adc hlo
        tay
        lda hlow,y              ; first h: max(h0, 104 / 72 / 52 for m;
        cmp hmin                ; 108 / 72 / 56 at 212 cycles)
        bcs @f
        lda hmin
@f      sta lh,x
        jsr lcyc
        inx
        cpx #6
        bcc @l
@next   jsr lpick               ; the least head: x, or none
        bmi @none
        stx lsel
        lda lh,x
        sta ch
        lda lm,x
        sta cm
        lda lp,x
        sta cpf
        lda lc0,x
        sta ccyc
        lda lc1,x
        sta ccyc+1
        lda lc2,x
        sta ccyc+2
        lda lc3,x
        sta ccyc+3
        lda lh,x                ; that list on
        clc
        adc #4
        sta lh,x
        jsr lcyc
        lda share
        beq @take
        jsr check               ; c clear: within the share
        bcs @next
@take   ldx blk
        lda ch
        sta bh,x
        lda cm
        sta bm,x
        lda cpf
        sta bpf,x
        beq @k2
        lda pkey
        jmp @k
@k2     lda bkey
@k      sta bk,x
        clc
        rts
@none   ldx #<tx_noset
        ldy #>tx_noset
        jsr print
        sec
        rts
tx_noset text "no coding fits the module's share",13,0

; the lists: 0-2 2 bits a pulse m 2-4, 3-5 the prefix code m 2-4
lm      byte 2,3,4,2,3,4
lp      byte 0,0,0,1,1,1
hlow    byte 104,72,52,104,72,52    ; (208 cycles)
        byte 108,72,56,108,72,56    ; (212, and 216: an effect of 6 or 8 cycles)
        byte 112,76,56,112,76,56    ; (218: one of 10)
hlo     byte 0                  ; 0, 6 or 12: the second row or the third
lh      byte 0,0,0,0,0,0        ; the head's h (past 124: done)
lb0     byte 0,0,0,0,0,0        ; base (24-bit)
lb1     byte 0,0,0,0,0,0
lb2     byte 0,0,0,0,0,0
lc0     byte 0,0,0,0,0,0        ; the head's cycles (32-bit)
lc1     byte 0,0,0,0,0,0
lc2     byte 0,0,0,0,0,0
lc3     byte 0,0,0,0,0,0
lsel    byte 0
ch      byte 0
cm      byte 0
cpf     byte 0
ccyc    byte 0,0,0,0
hmin    byte 0
share   byte 0
nbody   word 0

; lbase  list x's base: 2 bits: 4m x nbody + 2 sk; prefix: m x np + 2 sp
lbase   lda lp,x
        bne @p
        lda nbody               ; 4m x nbody
        sta t0
        lda nbody+1
        sta t1
        lda #0
        sta t2
        lda lm,x
        asl a
        asl a
        jsr mul3
        lda sk                  ; + 2 sk
        asl a
        sta t4
        lda sk+1
        rol a
        sta t5
        lda #0
        rol a
        sta t6
        jmp @s
@p      lda np                  ; m x np
        sta t0
        lda np+1
        sta t1
        lda #0
        sta t2
        lda lm,x
        jsr mul3
        lda sp                  ; + 2 sp
        asl a
        sta t4
        lda sp+1
        rol a
        sta t5
        lda sp+2
        rol a
        sta t6
@s      lda m3r                 ; base = product + t4..t6
        clc
        adc t4
        sta lb0,x
        lda m3r+1
        adc t5
        sta lb1,x
        lda m3r+2
        adc t6
        sta lb2,x
        rts

; mul3  m3r (3 bytes) = t0..t2 x a (small)
mul3    sta t3
        lda #0
        sta m3r
        sta m3r+1
        sta m3r+2
@m      lda t3
        beq @x
        lda m3r
        clc
        adc t0
        sta m3r
        lda m3r+1
        adc t1
        sta m3r+1
        lda m3r+2
        adc t2
        sta m3r+2
        dec t3
        jmp @m
@x      rts
m3r     byte 0,0,0

; lcyc  list x's head cycles: lh x base (32-bit; x kept)
lcyc    lda lb0,x
        sta t0
        lda lb1,x
        sta t1
        lda lb2,x
        sta t2
        lda #0
        sta t3
        sta lc0,x
        sta lc1,x
        sta lc2,x
        sta lc3,x
        lda lh,x
        sta t4
        ldy #8                  ; shift-add, h's bits from the bottom
@b      lsr t4
        bcc @n
        lda lc0,x
        clc
        adc t0
        sta lc0,x
        lda lc1,x
        adc t1
        sta lc1,x
        lda lc2,x
        adc t2
        sta lc2,x
        lda lc3,x
        adc t3
        sta lc3,x
@n      asl t0
        rol t1
        rol t2
        rol t3
        dey
        bne @b
        rts

; lpick  x: the list whose head is least by (cycles, h, m, 2 bits before
; prefix); n set if every list is done (h past 124)
lpick   ldx #$ff
        stx t7
        ldx #0
@c      lda lh,x
        cmp #125
        bcs @n                  ; done
        ldy t7
        bmi @take
        lda lc3,y               ; this one less than the best (y)?
        cmp lc3,x
        bne @d
        lda lc2,y
        cmp lc2,x
        bne @d
        lda lc1,y
        cmp lc1,x
        bne @d
        lda lc0,y
        cmp lc0,x
        bne @d
        lda lh,y                ; same cycles: lower h
        cmp lh,x
        bne @d
        lda lm,y                ; same h: lower m
        cmp lm,x
        bne @d
        lda lp,y                ; same m: 2 bits first
        cmp lp,x
        beq @n
@d      bcc @n                  ; best (y) < this: keep it
@take   stx t7
@n      inx
        cpx #6
        bcc @c
        ldx t7
        rts

; ------------------------------------------------------------
; check  the candidate (ch, cm, cpf, ccyc) against the share: c clear if
; every frame's worth of tape keeps the loader within it
; ------------------------------------------------------------
check   lda cpf
        beq @dib
        jmp chkpfx
@dib    lda #<38400             ; 100 x 384 x nbody > share x cycles: no
        sta m32a
        lda #>38400
        sta m32a+1
        lda nbody
        sta m32b
        lda nbody+1
        sta m32b+1
        jsr mul16
        jsr sharecyc            ; m32s = share x ccyc
        jsr cmp32               ; c set: m32r > m32s
        bcc @tab
        rts
@tab    ldx #0                  ; per pair sum ds: cycles (4m + 2ds) h, and
@t      stx t5                  ; d = 38400 - share x cycles (signed)
        lda cm
        asl a
        asl a
        sta t6
        txa
        asl a
        clc
        adc t6                  ; 4m + 2ds
        jsr timesh              ; t0/t1 = a x h
        ldx t5
        lda t0
        sta wcl,x
        lda t1
        sta wch,x
        lda #<38400
        sta t2
        lda #>38400
        sta t3
        lda #0
        sta t4
        jsr dsub                ; t2..t4 - share x t0/t1
        ldx t5
        lda t2
        sta wd0,x
        lda t3
        sta wd1,x
        lda t4
        sta wd2,x
        inx
        cpx #13
        bcc @t
        lda nbody
        sta t6
        lda nbody+1
        sta t7
        jmp window

; chkpfx  the same for the prefix code, over its pulses
chkpfx  lda #100                ; 100 x pcost > share x cycles: no
        sta m32a
        lda #0
        sta m32a+1
        lda pcost
        sta m32b
        lda pcost+1
        sta m32b+1
        jsr mul16
        lda pcost+2             ; (+ 100 x pcost's top byte x 65536)
        beq @nt
        ldx #100
@tp     lda m32r+2
        clc
        adc pcost+2
        sta m32r+2
        bcc @tq
        inc m32r+3
@tq     dex
        bne @tp
@nt     jsr sharecyc
        jsr cmp32
        bcc @tab
        rts
@tab    ldx #0                  ; class c, completing or not: x = c*2+comp
@t      stx t5
        txa
        and #6                  ; 2c
        clc
        adc cm                  ; m + 2c
        jsr timesh
        ldx t5
        lda t0
        sta wcl,x
        lda t1
        sta wch,x
        txa                     ; cost: 100 x (pfcost[c] + 50 comp)
        lsr a
        tay
        lda pfcost,y
        bcc @nc
        adc #49                 ; (c set: + 50)
@nc     sta t2
        lda #0
        sta t3
        sta t4
        lda t2                  ; x 100: x 64 + x 32 + x 4
        sta t6
        ldy #2
@x4     asl t2
        rol t3
        dey
        bne @x4                 ; x 4
        lda t2
        sta m32b
        lda t3
        sta m32b+1
        ldy #3
@x32    asl t2
        rol t3
        rol t4
        dey
        bne @x32                ; x 32
        lda t2
        clc
        adc m32b
        sta m32b
        lda t3
        adc m32b+1
        sta m32b+1
        lda t4
        adc #0
        sta m32b+2
        asl t2                  ; x 64
        rol t3
        rol t4
        lda t2
        clc
        adc m32b
        sta t2
        lda t3
        adc m32b+1
        sta t3
        lda t4
        adc m32b+2
        sta t4
        jsr dsub
        ldx t5
        lda t2
        sta wd0,x
        lda t3
        sta wd1,x
        lda t4
        sta wd2,x
        inx
        cpx #8
        bcs @w
        jmp @t
@w      lda np                  ; over the pulses
        sta t6
        lda np+1
        sta t7
        jmp windowp

; timesh  t0/t1 = a x ch
timesh  sta t2
        lda #0
        sta t0
        sta t1
        ldy ch
@m      tya
        beq @x
        lda t0
        clc
        adc t2
        sta t0
        bcc @n
        inc t1
@n      dey
        jmp @m
@x      rts

; dsub  t2..t4 = t2..t4 - share x t0/t1 (signed 24-bit)
dsub    ldy share
@s      tya
        beq @x
        lda t2
        sec
        sbc t0
        sta t2
        lda t3
        sbc t1
        sta t3
        lda t4
        sbc #0
        sta t4
        dey
        jmp @s
@x      rts

; per element (13 pair sums, or 8 prefix pulse kinds): cycles, d
wcl     byte 0,0,0,0,0,0,0,0,0,0,0,0,0
wch     byte 0,0,0,0,0,0,0,0,0,0,0,0,0
wd0     byte 0,0,0,0,0,0,0,0,0,0,0,0,0
wd1     byte 0,0,0,0,0,0,0,0,0,0,0,0,0
wd2     byte 0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; window  the 2-bit body's bytes (p2, t6/t7 of them): from each byte on,
; until 19656 cycles or more: d summed must not be above 0 (the whole
; body, if shorter). c clear: within the share
; ------------------------------------------------------------
window  lda #<(blkb+9)          ; i (p2, trailing) and j (p1, leading):
        sta p2                  ; the body from its pad
        sta p1
        lda #>(blkb+9)
        sta p2+1
        sta p1+1
        lda t6                  ; elements left for j
        sta wjn
        lda t7
        sta wjn+1
        jsr wzero
        lda #1
        sta wfirst
@i      lda wsc+2               ; extend j while cycles < 19656
        bne @full
        lda wsc
        cmp #<19656
        lda wsc+1
        sbc #>19656
        bcs @full
        lda wjn
        ora wjn+1
        bne @jm
        jmp @short              ; no more: the rest is shorter than a frame
@jm     ldy #0
        lda (p1),y
        tax
        ldy dibsum,x
        lda wsc                 ; element y into the window: cycles and d
        clc
        adc wcl,y
        sta wsc
        lda wsc+1
        adc wch,y
        sta wsc+1
        bcc @wa
        inc wsc+2
@wa     lda wsd
        clc
        adc wd0,y
        sta wsd
        lda wsd+1
        adc wd1,y
        sta wsd+1
        lda wsd+2
        adc wd2,y
        sta wsd+2
        inc p1
        bne @j1
        inc p1+1
@j1     lda wjn
        bne @j2
        dec wjn+1
@j2     dec wjn
        jmp @i
@full   lda #0
        sta wfirst
        jsr wtest
        bcs @x                  ; over the share
        ldy #0                  ; drop byte i
        lda (p2),y
        tax
        ldy dibsum,x
        lda wsc                 ; element y out of the window
        sec
        sbc wcl,y
        sta wsc
        lda wsc+1
        sbc wch,y
        sta wsc+1
        bcs @ws
        dec wsc+2
@ws     lda wsd
        sec
        sbc wd0,y
        sta wsd
        lda wsd+1
        sbc wd1,y
        sta wsd+1
        lda wsd+2
        sbc wd2,y
        sta wsd+2
        inc p2
        bne @ix
        inc p2+1
@ix     jmp @i
@short  lda wfirst              ; the whole body within one frame: its sum
        beq @ok
        jmp wtest
@ok     clc
@x      rts

; windowp  the same over the prefix pulses (pfxs, t6/t7 of them)
windowp lda #<pfxs
        sta wi
        sta wj
        lda #>pfxs
        sta wi+2                ; (the high bytes: see pnext)
        sta wi+3
        lda #0
        sta wis                 ; symbol in the byte (0-3), code bits mod 8
        sta wjs
        sta win
        sta wjnb
        lda t6
        sta wjn
        lda t7
        sta wjn+1
        jsr wzero
        lda #1
        sta wfirst
@i      lda wsc+2
        bne @full
        lda wsc
        cmp #<19656
        lda wsc+1
        sbc #>19656
        bcs @full
        lda wjn
        ora wjn+1
        bne @jm
        jmp @short
@jm     ldx #1                  ; the leading pulse
        jsr pnext
        lda wsc                 ; element y into the window: cycles and d
        clc
        adc wcl,y
        sta wsc
        lda wsc+1
        adc wch,y
        sta wsc+1
        bcc @wa
        inc wsc+2
@wa     lda wsd
        clc
        adc wd0,y
        sta wsd
        lda wsd+1
        adc wd1,y
        sta wsd+1
        lda wsd+2
        adc wd2,y
        sta wsd+2
        lda wjn
        bne @j2
        dec wjn+1
@j2     dec wjn
        jmp @i
@full   lda #0
        sta wfirst
        jsr wtest
        bcs @x
        ldx #0                  ; drop the trailing pulse
        jsr pnext
        lda wsc                 ; element y out of the window
        sec
        sbc wcl,y
        sta wsc
        lda wsc+1
        sbc wch,y
        sta wsc+1
        bcs @ws
        dec wsc+2
@ws     lda wsd
        sec
        sbc wd0,y
        sta wsd
        lda wsd+1
        sbc wd1,y
        sta wsd+1
        lda wsd+2
        sbc wd2,y
        sta wsd+2
        jmp @i
@short  lda wfirst              ; all of it shorter than a frame: its sum
        beq @ok
        jmp wtest
@ok     clc
@x      rts
wfirst  byte 0

; pnext  pulse x (0 trailing, 1 leading) on: y = class * 2 + completes
pnext   lda wis,x               ; (wi, wj: x 0 / 1 below) at a byte's first
        bne @h                  ; symbol: the byte, kept in wsb to shift
        lda wi,x
        sta p3
        lda wi+2,x
        sta p3+1
        ldy #0
        lda (p3),y
        sta wsb,x
@h      lda #0                  ; the symbol: its top 2 bits
        asl wsb,x
        rol a
        asl wsb,x
        rol a
        sta t5
        inc wis,x
        lda wis,x
        cmp #4
        bcc @nb
        lda #0
        sta wis,x
        inc wi,x
        bne @nb
        inc wi+2,x
@nb     ldy t5                  ; completes a byte?
        lda win,x
        clc
        adc pfbits,y
        ldy #0
        cmp #8
        bcc @n
        sbc #8
        ldy #1
@n      sta win,x
        sty t4
        lda t5
        asl a
        ora t4
        tay
        rts
; (wi and wj interleaved for pnext: lo bytes, then hi bytes)
wi      byte 0
wj      byte 0
        byte 0                  ; wi+1 (hi)
        byte 0                  ; wj+1
wis     byte 0
wjs     byte 0
wsb     byte 0,0                ; (the byte at wi / wj, shifted)
win     byte 0
wjnb    byte 0
wjn     word 0
wsc     byte 0,0,0              ; cycles in the window
wsd     byte 0,0,0              ; d summed (signed)

wzero   lda #0
        sta wsc
        sta wsc+1
        sta wsc+2
        sta wsd
        sta wsd+1
        sta wsd+2
        rts
; wtest  c set if d summed is above 0
wtest   lda wsd+2
        bmi @ok                 ; negative
        ora wsd+1
        ora wsd
        beq @ok                 ; zero
        sec
        rts
@ok     clc
        rts

; sharecyc  m32s = share x ccyc
sharecyc
        lda #0
        sta m32s
        sta m32s+1
        sta m32s+2
        sta m32s+3
        ldy share
@m      tya
        beq @x
        lda m32s
        clc
        adc ccyc
        sta m32s
        lda m32s+1
        adc ccyc+1
        sta m32s+1
        lda m32s+2
        adc ccyc+2
        sta m32s+2
        lda m32s+3
        adc ccyc+3
        sta m32s+3
        dey
        jmp @m
@x      rts

; cmp32  c set if m32r > m32s
cmp32   lda m32s
        cmp m32r
        lda m32s+1
        sbc m32r+1
        lda m32s+2
        sbc m32r+2
        lda m32s+3
        sbc m32r+3
        bcc @gt                 ; (m32s - m32r borrows: m32r > m32s)
        clc
        rts
@gt     sec
        rts
