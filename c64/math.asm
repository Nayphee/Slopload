; ------------------------------------------------------------
; math.asm  -  multiply and divide, for SlopLoad 64 and SID-SLM
;   mul16  m32r (32 bits) = m32a (16) x m32b (16); uses a, y, t0-t3
;   divn   q24 (4 bytes) = n24 (4 bytes) / dvs (16), remainder in rem;
;          uses a, y (n24 is shifted through)
; The includer's zero page: t0-t3, n24 (4), q24 (4), rem (2).
; ------------------------------------------------------------

; ---- 32-bit helpers ----
m32a    byte 0,0
m32b    byte 0,0,0
m32r    byte 0,0,0,0
m32s    byte 0,0,0,0

; mul16  m32r = m32a (16) x m32b (16)
mul16   lda #0
        sta m32r
        sta m32r+1
        sta m32r+2
        sta m32r+3
        lda m32b
        sta t0
        lda m32b+1
        sta t1
        lda #0
        sta t2
        sta t3
        ldy #16
@b      lsr m32a+1
        ror m32a
        bcc @n
        lda m32r
        clc
        adc t0
        sta m32r
        lda m32r+1
        adc t1
        sta m32r+1
        lda m32r+2
        adc t2
        sta m32r+2
        lda m32r+3
        adc t3
        sta m32r+3
@n      asl t0
        rol t1
        rol t2
        rol t3
        dey
        bne @b
        rts


; divn  q24 = n24 / dvs
divn    lda #0
        sta rem
        sta rem+1
        ldy #32
@b      asl n24
        rol n24+1
        rol n24+2
        rol n24+3
        rol rem
        rol rem+1
        bcs @sub                ; past 16 bits: more than the divisor
        lda rem
        cmp dvs
        lda rem+1
        sbc dvs+1
        bcc @n
@sub    lda rem
        sec
        sbc dvs
        sta rem
        lda rem+1
        sbc dvs+1
        sta rem+1
        inc n24                 ; (the quotient's bit, shifted in)
@n      dey
        bne @b
        lda n24
        sta q24
        lda n24+1
        sta q24+1
        lda n24+2
        sta q24+2
        lda n24+3
        sta q24+3
        rts
dvs     word 0
