; ------------------------------------------------------------
; machsay.asm  -  the machine said (machine.asm's detect found it):
; SlopLoad 64's title line. The other tools don't say it.
; ------------------------------------------------------------

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
