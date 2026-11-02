; ------------------------------------------------------------
; writer.asm  -  SlopLoad 64's pulse writer: a list of sections, out to
; the cassette (cia2 timer a timing the edges, $01 bit 3) or as .tap
; bytes (chrout to the open file)
;
; A section is 8 bytes:
;   +0     type: 0 end, 1 run, 2 dibits in memory, 3 dibits from the
;          expansion memory's stream (REU or SuperRAM, read in order)
;   +1/2   run: pulses; dibits: bytes
;   +3/4   run: the half-pulse's timer latch (cycles - 1); dibits: pointer
;          (type 2)
;   +5/6   run: the last pulse's (a pilot's sync, a leader's first L)
;   +5     dibits: table (0-63) for its first bytes
;   +6     dibits: how many bytes use it (then +7's; 0: all)
;   +7     dibits: the table after
; A run hands over to the next section in the first half of its last
; pulse (a sync, an L: the longest), from its handler; a dibits section
; ends on KERNAL short pulses (192-cycle halves), on a bridge (a byte $0f:
; the switch in its third pulse, a long one) or at the tape's end. The
; switch takes up to 180 cycles, more than half a short pulse.
; A dibits section is 2-bit symbols, the first in bits 7-6; a symbol's
; pulse is two halves of htlo/hthi[table * 4 + symbol] + 1 cycles each.
;
; Each pulse: at its start (timer a's underflow) the line goes high and
; hcall gives the next pulse's half; at its middle the line goes low, the
; latch takes that half (used from the next underflow on) and house does
; the bookkeeping for the pulse just taken (the next byte, the next
; section). Halves are 104 cycles at least: hcall takes 51, house 62.
; ------------------------------------------------------------

; ---- the half-pulse tables (latch values, htlo/hthi in bss): up to 64
; tables of 4 symbols. Table 0: the KERNAL's S, M, L; the others made as
; needed (gettab), one for each quantum and pulse set on the tape ----

; ------------------------------------------------------------
; gettab  the table for quantum a, pulse set y: found, or made
;   out:  x = the table; c set if there are 64 already (said)
;   uses: a, x, y, t0-t3
; ------------------------------------------------------------
gettab  sta t0
        sty t1
        ldx #1
@f      cpx ntab
        bcs @new
        lda tabq,x
        cmp t0
        bne @n
        lda tabs,x
        cmp t1
        beq @x
@n      inx
        bne @f
@new    cpx #64
        bcs @full
        lda t0
        sta tabq,x
        lda t1
        sta tabs,x
        inc ntab
        stx t3
        ldy t1
        lda t0
        jsr settab
        ldx t3
@x      clc
        rts
@full   ldx #<tx_tabs
        ldy #>tx_tabs
        jsr print
        sec
        rts
tx_tabs text "too many pulse sets on one tape",13,0
ntab    byte 0
tabq    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tabs    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; settab  table x (1-63) for quantum a, pulse set y: symbol k is
; (y + 2k) * a cycles, a half of it (a even) less 1 in the table
;   uses: a, x, y, t0-t2
; ------------------------------------------------------------
settab  lsr a
        sta t0                  ; h / 2
        txa
        asl a
        asl a
        tax                     ; table * 4
        lda #0
        sta t1                  ; half = y * h/2
        sta t2
@m      lda t1
        clc
        adc t0
        sta t1
        bcc @m1
        inc t2
@m1     dey
        bne @m
        ldy #4
@k      lda t1                  ; symbol k: the half less 1
        sec
        sbc #1
        sta htlo,x
        lda t2
        sbc #0
        sta hthi,x
        lda t1                  ; the next symbol: + 2 * h/2
        clc
        adc t0
        sta t1
        bcc @k1
        inc t2
@k1     lda t1
        clc
        adc t0
        sta t1
        bcc @k2
        inc t2
@k2     inx
        dey
        bne @k
        rts

; the KERNAL's pulses (table 0): 384, 528, 688 cycles
romtab  lda #191
        sta htlo
        lda #263-256
        sta htlo+1
        lda #343-256
        sta htlo+2
        lda #0
        sta hthi
        lda #1
        sta hthi+1
        sta hthi+2
        rts

; ------------------------------------------------------------
; handlers (first half): a/x = the next half's latch, c set at the end
; ------------------------------------------------------------
hcall   jmp (hvec)

hdib    lda #0
        asl sr
        rol a
        asl sr
        rol a
        ora tsel
        tay
        dec dcnt
        lda htlo,y
        ldx hthi,y
        rts                     ; (c clear: the last rol's)

hrun    lda rcnt                ; none left: the next section's first
        ora rcnt+1              ; (here, in the first half of the run's
        beq @next               ; last pulse: a sync or an L, the longest)
        lda rlo
        ldx rhi
        clc
        rts
@next   jsr nextsec
        jmp (hvec)

hend    sec
        rts

; ------------------------------------------------------------
; house (second half): after a pulse was taken
; ------------------------------------------------------------
house   jmp (houvec)

houdib  lda dcnt
        bne @x                  ; symbols left in this byte
        lda bptr
        cmp bend
        bne @ld
        lda bptr+1
        cmp bend+1
        beq @end
@ld     ldy #0
        lda (bptr),y
        sta sr
        lda #4
        sta dcnt
        inc bptr
        bne @s
        inc bptr+1
@s      dec swc
        bne @x
        lda tselb               ; this byte on: the other table
        sta tsel
@x      rts
@end    jmp nextsec

hourun  lda rcnt
        bne @a
        dec rcnt+1
@a      dec rcnt
        bne @one
        rts                     ; (none left: hrun switches)
@one    lda rcnt+1              ; one left: the last pulse's half from now
        bne @x
        lda rcnt
        cmp #1
        bne @x
        lda rlast
        sta rlo
        lda rlast+1
        sta rhi
@x      rts

hounone rts

; houreu  the stream from an REU: the next byte fetched (one byte's DMA)
; half way through the one before, taken when that one is done
houreu  lda dcnt
        beq @ld
        cmp #2
        bne @x
        lda bcnt
        ora bcnt+1
        beq @x
        lda #1
        sta $df07
        lda #$91
        sta $df01
        bit $d020
@x      rts
@ld     lda bcnt
        ora bcnt+1
        beq @end
        lda xbuf
        sta sr
        lda #4
        sta dcnt
        lda bcnt
        bne @d
        dec bcnt+1
@d      dec bcnt
        dec swc
        bne @r
        lda tselb               ; this byte on: the other table
        sta tsel
@r      rts
@end    jmp nextsec

; housr  the stream from SuperRAM (a SuperCPU: 20 MHz, time to spare)
housr   lda dcnt
        bne @x
        lda bcnt
        ora bcnt+1
        beq @end
        ldy #0
        byte $b7,xp             ; lda [xp],y
        sta sr
        inc xp
        bne @i
        inc xp+1
        bne @i
        inc xp+2
@i      lda #4
        sta dcnt
        lda bcnt
        bne @d
        dec bcnt+1
@d      dec bcnt
        dec swc
        bne @x
        lda tselb
        sta tsel
@x      rts
@end    jmp nextsec

; ------------------------------------------------------------
; nextsec  the next section from secp on
; ------------------------------------------------------------
nextsec ldy #0
        lda (secp),y
        bne @go
        jmp @end
@go     cmp #1
        bne @dib
        iny                     ; a run
        lda (secp),y
        sta rcnt
        iny
        lda (secp),y
        sta rcnt+1
        iny
        lda (secp),y
        sta rlo
        iny
        lda (secp),y
        sta rhi
        iny
        lda (secp),y
        sta rlast
        iny
        lda (secp),y
        sta rlast+1
        lda rcnt+1              ; (a run of one: the last pulse's now)
        bne @r1
        lda rcnt
        cmp #1
        bne @r1
        lda rlast
        sta rlo
        lda rlast+1
        sta rhi
@r1     lda #<hrun
        sta hvec
        lda #>hrun
        sta hvec+1
        lda #<hourun
        sta houvec
        lda #>hourun
        sta houvec+1
        jmp @next
@dib    cmp #3
        bne @dib2
        jmp @str
@dib2   ldy #3
        lda (secp),y
        sta bptr
        ldy #1
        clc
        adc (secp),y
        sta bend
        ldy #4
        lda (secp),y
        sta bptr+1
        ldy #2
        adc (secp),y
        sta bend+1
        ldy #5
        lda (secp),y
        asl a
        asl a
        sta tsel
        iny
        lda (secp),y
        sta swc
        iny
        lda (secp),y
        asl a
        asl a
        sta tselb
        ldy #0                  ; its first byte now
        lda (bptr),y
        sta sr
        lda #4
        sta dcnt
        inc bptr
        bne @b
        inc bptr+1
@b      lda #<hdib
        sta hvec
        lda #>hdib
        sta hvec+1
        lda #<houdib
        sta houvec
        lda #>houdib
        sta houvec+1
@next   lda secp
        clc
        adc #8
        sta secp
        bcc @x
        inc secp+1
@x      rts
@str    ldy #1                  ; from the stream: its count, its tables
        lda (secp),y
        sta bcnt
        iny
        lda (secp),y
        sta bcnt+1
        ldy #5
        lda (secp),y
        asl a
        asl a
        sta tsel
        iny
        lda (secp),y
        sta swc
        iny
        lda (secp),y
        asl a
        asl a
        sta tselb
        lda xmem                ; its first byte now
        cmp #2
        beq @sr
        lda #1
        sta $df07
        lda #$91                ; (an REU: one byte to xbuf)
        sta $df01
        bit $d020
        lda xbuf
        jmp @s1
@sr     ldy #0                  ; (SuperRAM)
        byte $b7,xp             ; lda [xp],y
        inc xp
        bne @s1
        inc xp+1
        bne @s1
        inc xp+2
@s1     sta sr
        lda #4
        sta dcnt
        lda bcnt                ; (the bytes after it)
        bne @s2
        dec bcnt+1
@s2     dec bcnt
        lda #<hdib
        sta hvec
        lda #>hdib
        sta hvec+1
        lda xhou
        sta houvec
        lda xhou+1
        sta houvec+1
        jmp @next
@end    lda #<hend
        sta hvec
        lda #>hend
        sta hvec+1
        lda #<hounone
        sta houvec
        lda #>hounone
        sta houvec+1
        rts

; ------------------------------------------------------------
; wtape  the sections at a/x to the cassette: interrupts off, the screen
; off, the motor on (the caller turned it on); returns with the last
; pulse ended (the line high), the timer stopped
;   uses: everything
; ------------------------------------------------------------
wtape   sta secp
        stx secp+1
        sei
        lda $01
        and #$df                ; (motor on)
        ora #$08
        sta porth
        and #$f7
        sta portl
        sta $01                 ; the line low
        lda #$7f
        sta $dd0d               ; no cia2 interrupts (nmis)
        lda #0
        sta $dd0e               ; timer a stopped
        jsr nextsec
        jsr hcall               ; the first pulse
        sta $dd04
        stx $dd05
        jsr house
        lda $dd0d
        lda #$11                ; continuous, force load, start
        sta $dd0e
@loop
@w1     lda $dd0d               ; a pulse begins
        lsr a
        bcc @w1
        lda porth
        sta $01
        jsr hcall               ; the next pulse's half
        bcs @fin
        sta wnlo
        stx wnhi
@w2     lda $dd0d               ; its middle
        lsr a
        bcc @w2
        lda portl
        sta $01
        lda wnlo
        sta $dd04
        lda wnhi
        sta $dd05
        jsr house
        jmp @loop
@fin
@w3     lda $dd0d               ; the last pulse's middle
        lsr a
        bcc @w3
        lda portl
        sta $01
@w4     lda $dd0d               ; and its end
        lsr a
        bcc @w4
        lda porth
        sta $01
        lda #0
        sta $dd0e
        lda $dd0d
        rts

; ------------------------------------------------------------
; wtap  the sections at a/x as .tap bytes, to the output channel (the
; caller's chkout): each pulse (2 * half + 4) / 8 = (latch + 3) / 4
;   uses: everything
; ------------------------------------------------------------
wtap    sta secp
        stx secp+1
        jsr nextsec
@p      jsr hcall
        bcs @x
        clc
        adc #3
        sta t0
        txa
        adc #0
        lsr a
        ror t0
        lsr a
        ror t0
        lda t0
        jsr chrout
        jsr house
        jmp @p
@x      rts
