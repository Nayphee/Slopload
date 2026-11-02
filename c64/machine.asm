; ------------------------------------------------------------
; machine.asm  -  what the machine has, for SlopLoad 64 and the TAP
; writer: an accelerator (for the work between disk and tape) and
; expansion memory
;
; Accelerators (found once, at the start; turbo only while computing:
; fast / slow around it, 1 MHz for the KERNAL's disk routines and the
; tape):
;   SuperCPU  20 MHz throughout, every write copied to the C64's memory
;             (its own ROM serves the serial bus at that speed)
;   Ultimate  with its turbo registers on: $d031 = $0f while computing,
;             its old value after
;   C128      2 MHz in the vertical border only (raster interrupts at
;             lines 251 and 44), the picture at 1 MHz
; Expansion memory:
;   SuperRAM  a SuperCPU's, the free area CMD's ROM keeps at $d27c-$d27f
;   REU       any 17xx (or one on a SuperCPU, a C128, an Ultimate), sized
;             up to reumax banks of 64 KB (the includer's equate, with
;             reusav: reumax bytes for each bank's first byte, put back)
; ------------------------------------------------------------

cpu     byte 0                  ; 0 C64, 1 C128, 2 SuperCPU, 3 Ultimate
u64old  byte 0                  ; $d031 as found
infast  byte 0
irqst   byte 0
reubanks byte 0                 ; an REU's 64 KB banks (reumax: that or more)
srsp    byte 0                  ; SuperRAM: first free page, its bank,
srsb    byte 0                  ; the last free page + 1, its bank (0:
srep    byte 0                  ; none)
sreb    byte 0
xkind   byte 0                  ; what there is: 0 none, 1 REU, 2 SuperRAM
xbuf    byte 0                  ; an REU's byte at a time
isntsc  byte 0                  ; 1: an NTSC picture (263 lines or 262)

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

; prmach  the machine, PAL or NTSC, its expansion memory: "c128 pal
; (2 mhz), 512 kb reu"
prmach  ldx cpu
        lda cpunl,x
        ldy cpunh,x
        tax
        jsr print
        ldx #<tx_pal
        ldy #>tx_pal
        lda isntsc
        beq @v
        ldx #<tx_ntsc
        ldy #>tx_ntsc
@v      jsr print
        ldx cpu
        lda cpuxl,x
        ldy cpuxh,x
        tax
        jsr print
        lda xkind
        beq @x
        ldx #<tx_with
        ldy #>tx_with
        jsr print
        jmp prxmem
@x      rts
cpunl   byte <tx_c64,<tx_c128,<tx_scpu,<tx_u64
cpunh   byte >tx_c64,>tx_c128,>tx_scpu,>tx_u64
cpuxl   byte <tx_with+2,<tx_c128x,<tx_with+2,<tx_u64x
cpuxh   byte >tx_with+2,>tx_c128x,>tx_with+2,>tx_u64x
tx_c64  text "c64",0
tx_c128 text "c128",0
tx_scpu text "supercpu",0
tx_u64  text "ultimate",0
tx_c128x text " (2 mhz)",0
tx_u64x text " (turbo)",0
tx_pal  text " pal",0
tx_ntsc text " ntsc",0
tx_with text ", ",0

; prxmem  "512 kb reu", "16 mb reu" (16 banks or more) / "1024 kb superram"
prxmem  lda xkind
        cmp #2
        beq @sr
        lda reubanks            ; 16 banks or more: (banks + 1) / 16 MB
        cmp #16                 ; (255 banks sized: 16 MB)
        bcc @kb
        adc #0                  ; (carry set: + 1, the 9th bit in carry)
        ror a
        lsr a
        lsr a
        lsr a
        ldx #0
        jsr prdec16
        ldx #<tx_mreu
        ldy #>tx_mreu
        jmp print
@kb     lda reubanks            ; banks x 64
        sta t0
        lda #0
        ldx #6
@m      asl t0
        rol a
        dex
        bne @m
        tax
        lda t0
        jsr prdec16
        ldx #<tx_kreu
        ldy #>tx_kreu
        jmp print
@sr     jsr srpages             ; pages / 4
        lsr t1
        ror t0
        lsr t1
        ror t0
        lda t0
        ldx t1
        jsr prdec16
        ldx #<tx_ksr
        ldy #>tx_ksr
        jmp print
tx_kreu text " kb reu",0
tx_mreu text " mb reu",0
tx_ksr  text " kb superram",0

; srpages  t0/t1: SuperRAM's free pages (c clear if the end is before
; the start)
srpages lda srep
        sec
        sbc srsp
        sta t0
        lda sreb
        sbc srsb
        sta t1
        rts

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

; ------------------------------------------------------------
; fast / slow  the accelerator on for computing, and off again (1 MHz
; for the disk and the tape); a SuperCPU stays at 20 MHz
; ------------------------------------------------------------
fast    lda infast
        bne @x
        inc infast
        lda cpu
        cmp #3
        bne @c
        lda #$0f                ; an Ultimate: top speed
        sta $d031
        rts
@c      cmp #1
        bne @x
        sei                     ; a C128: 2 MHz from line 251 to 44
        lda $0314               ; (the interrupt it had, whatever it is:
        sta irqk+1              ; irq2 passes the rest to it, and slow
        lda $0315               ; puts it back)
        sta irqk+2
        lda #<irq2
        sta $0314
        lda #>irq2
        sta $0315
        lda #0
        sta irqst
        lda $d011
        and #$7f
        sta $d011
        lda #251
        sta $d012
        lda #$0f                ; (anything pending cleared first)
        sta $d019
        lda #1
        sta $d01a
        cli
@x      rts

slow    php                     ; (the flags kept)
        lda infast
        beq @x
        lda #0
        sta infast
        lda cpu
        cmp #3
        bne @c
        lda u64old
        sta $d031
        plp
        rts
@c      cmp #1
        bne @x
        sei
        lda #0
        sta $d01a
        sta $d030
        lda #$0f
        sta $d019
        lda irqk+1
        sta $0314
        lda irqk+2
        sta $0315
@x      plp
        rts

; irq2  a C128's raster interrupts: 2 MHz at line 251, 1 MHz at 44 (else
; the interrupt there was before fast: irqk, set by fast)
irq2    lda $d019
        lsr a
        bcc irqk
        lda #1
        sta $d019
        lda irqst
        eor #1
        sta irqst
        sta $d030
        tax
        lda irqln,x
        sta $d012
        jmp $ea81
irqk    jmp $ea31
irqln   byte 251,44
