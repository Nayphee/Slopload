; ------------------------------------------------------------
; xmem.asm  -  SlopLoad 64's expansion memory stream: every block laid
; out into an REU or SuperRAM (machine.asm finds them), then read back a
; byte at a time while the tape is written in one go
; ------------------------------------------------------------

xmem    byte 0                  ; what is used for this tape (as xkind)
xpos    byte 0,0,0              ; the stream's next byte (REU address, or
xlim    byte 0,0,0              ; SuperRAM bank:page:byte), and its end
xhou    word 0                  ; the writer's house for the stream

; ------------------------------------------------------------
; xinit  the stream empty: its start and end
; ------------------------------------------------------------
xinit   lda #0
        sta xpos
        lda xmem
        cmp #2
        beq @sr
        lda #0                  ; an REU: from 0 to its banks
        sta xpos+1
        sta xpos+2
        sta xlim
        sta xlim+1
        lda reubanks
        sta xlim+2
        rts
@sr     lda srsp
        sta xpos+1
        lda srsb
        sta xpos+2
        lda #0
        sta xlim
        lda srep
        sta xlim+1
        lda sreb
        sta xlim+2
        rts

; ------------------------------------------------------------
; xput  layn bytes from lay into the stream (an REU's stash checked by
; its verify)
;   out:  c set if there's no room (z set) or the REU lost it (said)
;   uses: a, x, y, t0-t6, p1
; ------------------------------------------------------------
xput    lda xpos                ; its end, t4-t6: within the limit?
        clc
        adc layn
        sta t4
        lda xpos+1
        adc layn+1
        sta t5
        lda xpos+2
        adc #0
        sta t6
        lda xlim
        cmp t4
        lda xlim+1
        sbc t5
        lda xlim+2
        sbc t6
        bcs @room
        lda #0                  ; (z set: no room)
        sec
        rts
@room   lda xmem
        cmp #2
        beq @sr
        jsr xregs               ; an REU: stash, then verify
        lda #$90
        sta $df01
        bit $d020
        jsr xregs
        lda $df00               ; (its status cleared)
        lda #$93
        sta $df01
        bit $d020
        lda $df00
        and #$20
        beq @adv
        ldx #<tx_reubad
        ldy #>tx_reubad
        jsr print
        lda #1                  ; (z clear)
        sec
        rts
@sr     lda xpos                ; SuperRAM: a byte at a time
        sta xp
        lda xpos+1
        sta xp+1
        lda xpos+2
        sta xp+2
        lda lay
        sta p1
        lda lay+1
        sta p1+1
        lda layn
        sta t0
        lda layn+1
        sta t1
        ldy #0
@c      lda t0
        ora t1
        beq @adv
        lda (p1),y
        byte $97,xp             ; sta [xp],y
        inc p1
        bne @1
        inc p1+1
@1      inc xp
        bne @2
        inc xp+1
        bne @2
        inc xp+2
@2      lda t0
        bne @3
        dec t1
@3      dec t0
        jmp @c
@adv    lda t4
        sta xpos
        lda t5
        sta xpos+1
        lda t6
        sta xpos+2
        clc
        rts
tx_reubad text "the reu didn't keep what was written",13,0

; xregs  the REU's registers for lay/layn at xpos
xregs   lda lay
        sta $df02
        lda lay+1
        sta $df03
        lda xpos
        sta $df04
        lda xpos+1
        sta $df05
        lda xpos+2
        sta $df06
        lda layn
        sta $df07
        lda layn+1
        sta $df08
        lda #0
        sta $df09
        sta $df0a
        rts

; ------------------------------------------------------------
; xrdinit  the stream read from its start, a byte at a time (an REU:
; into xbuf, the C64 address held); the writer's house for it
; xdone    the REU's address control as it was
; ------------------------------------------------------------
xrdinit lda xmem
        cmp #2
        beq @sr
        lda #<xbuf
        sta $df02
        lda #>xbuf
        sta $df03
        lda #0
        sta $df04
        sta $df05
        sta $df06
        sta $df08
        sta $df09
        lda #1
        sta $df07
        lda #$80                ; the C64 address held
        sta $df0a
        lda #<houreu
        sta xhou
        lda #>houreu
        sta xhou+1
        rts
@sr     lda #0
        sta xp
        lda srsp
        sta xp+1
        lda srsb
        sta xp+2
        lda #<housr
        sta xhou
        lda #>housr
        sta xhou+1
        rts
xdone   lda xmem
        cmp #1
        bne @x
        lda #0
        sta $df0a
@x      rts

