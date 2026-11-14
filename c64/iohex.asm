; ------------------------------------------------------------
; iohex.asm  -  hexadecimal out and in (io.asm's, for the tools that
; show or ask an address: SlopLoad 64, SID-SLM)
; ------------------------------------------------------------

; prhex4  a/x (lo/hi) as $hhhh; prhex2  a as hh
prhex4  pha
        lda #'$'
        jsr chrout
        txa
        jsr prhex2
        pla
prhex2  pha
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @d
        pla
        and #15
@d      cmp #10
        bcc @n
        adc #6                  ; (carry set) 'a'-'9'-1
@n      adc #'0'
        jmp chrout

; inhex  inbuf as a hexadecimal word ($ optional): a/x, c set if not one
inhex   lda #0
        sta t0
        sta t1
        ldy #0
        cpy inlen
        beq @bad
        lda inbuf
        cmp #'$'
        bne @c
        iny
@c      cpy inlen
        beq @ok
        lda inbuf,y
        sec
        sbc #'0'
        cmp #10
        bcc @d
        sbc #7                  ; 'a' -> 10
        cmp #10
        bcc @bad
        cmp #16
        bcs @bad
@d      ldx t1                  ; a fifth digit: not an address (it was
        cpx #$10                ; dropped, 12345 taken as $2345)
        bcs @bad
        ldx #4
@sh     asl t0
        rol t1
        dex
        bne @sh
        ora t0
        sta t0
        iny
        bne @c
@ok     lda t0
        ldx t1
        clc
        rts
@bad    sec
        rts
