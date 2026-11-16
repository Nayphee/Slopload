; ------------------------------------------------------------
; machdet.asm  -  the machine found, once at the start (machine.asm's
; variables and the rest: fast, slow, srpages): the accelerator, PAL or
; NTSC, the expansion memory. SlopLoad 64 has it after its start, where
; the buffers go (it runs once, before they are used); the TAP writer
; and SID-SLM after machine.asm
; ------------------------------------------------------------

; ------------------------------------------------------------
; detect  the accelerator and the expansion memory (prmach says them)
; ------------------------------------------------------------
detect  lda #0
        sta cpu
        sta xkind
        sta reubanks
        sta srsb
        sta isntsc
        sei                     ; PAL or NTSC: the raster's last line's
@r0     lda $d012               ; low byte (PAL 311: $37, NTSC 262: $06)
@r1     cmp $d012
        beq @r1
        bmi @r0
        cli
        cmp #$20
        bcs @pal
        inc isntsc
@pal
        lda #1                  ; a 65816 takes $3a as dec a
        byte $3a
        bne @n816
        lda $d0bc               ; ... and a SuperCPU has bit 7 clear here
        bmi @n816
        sta $d07e               ; every write copied (mirror all)
        sta $d077
        sta $d07f
        sta $d07b               ; 20 MHz
        lda #2
        sta cpu
        jsr srdet
        jmp @reu
@n816   lda $d031               ; an Ultimate's turbo registers
        cmp #$ff
        beq @n64
        sta u64old
        lda #3
        sta cpu
        bne @reu
@n64    lda $d030               ; a C128: bit 0 follows writes
        eor #1
        sta $d030
        cmp $d030
        bne @reu
        lda #0
        sta $d030
        lda #1
        sta cpu
@reu    jsr reudet
        lda srsb                ; SuperRAM first, else an REU
        beq @u
        lda #2
        sta xkind
        bne @say
@u      lda reubanks
        beq @say
        lda #1
        sta xkind
@say    rts

; ------------------------------------------------------------
; srdet  SuperRAM's free area, as CMD documents it: the ROM's version
; (1.40 on), then $d27c-$d27f; a byte written there and read back
;   out:  srsb 0 if there is none
; ------------------------------------------------------------
srdet   lda $e488               ; a version number ("d.dd")?
        cmp #$2e                ; (VICE's own ROM has other text here,
        bne @var                ;  and keeps the variables)
        lda $e487
        cmp #$31                ; below 1: no SuperRAM support
        bcc @none
        bne @var
        lda $e489               ; 1.40 and up
        cmp #$34
        bcc @none
@var    lda $d27d               ; the first free page's bank: 2 or more
        cmp #2                  ; (all 0: no SuperRAM)
        bcc @none
        sta srsb
        lda $d27c
        sta srsp
        lda $d27e
        sta srep
        lda $d27f
        sta sreb
        cmp #$f7                ; (a bank past $f6: not a sane value)
        bcs @none
        jsr srpages             ; at least 16 pages (c clear: the end
        bcc @none               ; before the start)
        lda t1
        bne @t
        lda t0
        cmp #16
        bcc @none
@t      lda #0                  ; a byte there, and back
        sta xp
        lda srsp
        sta xp+1
        lda srsb
        sta xp+2
        ldy #0
        lda #$a5
        byte $97,xp             ; sta [xp],y
        lda #0
        byte $b7,xp             ; lda [xp],y
        cmp #$a5
        bne @none
        lda #$5a
        byte $97,xp
        lda #0
        byte $b7,xp
        cmp #$5a
        bne @none
        rts
@none   lda #0
        sta srsb
        rts

; ------------------------------------------------------------
; reudet  an REU: its address registers keep a pattern, and its banks
; (up to reumax) each keep their own byte; their first bytes put back
;   out:  reubanks (0: none)
; ------------------------------------------------------------
reudet  ldx #3
@w      txa
        ora #$50
        sta $df02,x
        dex
        bpl @w
        ldx #3
@r      txa
        ora #$50
        cmp $df02,x
        bne @no
        dex
        bpl @r
        ldx #0                  ; each bank's first byte, kept
@sv     stx t4
        lda #$91
        jsr reu1
        ldx t4
        lda xbuf
        sta reusav,x
        inx
        cpx #reumax
        bcc @sv
        ldx #reumax-1           ; then bank b gets b + $40, from the top
@st     stx t4
        txa
        clc
        adc #$40
        sta xbuf
        lda #$90
        jsr reu1
        ldx t4
        dex
        cpx #$ff                ; (down to bank 0; more than 128 banks)
        bne @st
        ldx #0                  ; the first bank that doesn't keep its own
@ck     stx t4                  ; is as many as there are
        lda #0
        sta xbuf
        lda #$91
        jsr reu1
        lda t4
        clc
        adc #$40
        cmp xbuf
        bne @end
        ldx t4
        inx
        cpx #reumax
        bcc @ck
        stx t4
@end    lda t4
        sta reubanks
        ldx #reumax-1           ; the first bytes back, from the top
@bk     stx t4
        lda reusav,x
        sta xbuf
        lda #$90
        jsr reu1
        ldx t4
        dex
        cpx #$ff                ; (down to bank 0; more than 128 banks)
        bne @bk
        rts
@no     lda #0
        sta reubanks
        rts

; reu1  command a on one byte: xbuf and the REU's bank x, byte 0
reu1    pha
        lda #<xbuf
        sta $df02
        lda #>xbuf
        sta $df03
        lda #0
        sta $df04
        sta $df05
        stx $df06
        sta $df08
        sta $df09
        sta $df0a
        lda #1
        sta $df07
        pla
        sta $df01
        bit $d020               ; (a SuperCPU: the transfer happens now)
        rts

