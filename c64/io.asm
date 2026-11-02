; ------------------------------------------------------------
; io.asm  -  SlopLoad 64's screen and disk: text out and in, the
; program file (read), the .tap file (written), the drive's status
; ------------------------------------------------------------

; ------------------------------------------------------------
; print  the text at x/y (lo/hi) up to a 0
;   uses: a, y, p3
; ------------------------------------------------------------
print   stx p3
        sty p3+1
        ldy #0
@c      lda (p3),y
        beq @x
        jsr chrout
        iny
        bne @c
        inc p3+1
        bne @c
@x      rts

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

; ------------------------------------------------------------
; prdec  the 24-bit number n24 (3 bytes) in decimal
;   uses: a, x, y, n24 (cleared), t0-t3
; ------------------------------------------------------------
prdec   ldx #0                  ; digits on the stack, then printed
        stx t3
@d      lda #0                  ; n24 / 10, remainder in a
        ldy #24
@b      asl n24
        rol n24+1
        rol n24+2
        rol a
        cmp #10
        bcc @n
        sbc #10
        inc n24
@n      dey
        bne @b
        pha
        inc t3
        lda n24
        ora n24+1
        ora n24+2
        bne @d
@p      pla
        ora #'0'
        jsr chrout
        dec t3
        bne @p
        rts

; prdec16  a/x in decimal
prdec16 sta n24
        stx n24+1
        lda #0
        sta n24+2
        jmp prdec

; ------------------------------------------------------------
; readline  a line typed at the keyboard into inbuf (inlen: its
; length, at most a; spaces at its end dropped): printable keys, del
; takes one back, return ends it. Key by key, not the screen editor's
; line (whatever else is on that line can't creep in)
; readname  the same, but every key is kept but return and del:
; control keys too (a tape's name: clr, colours), shown as quote mode
; shows them
;   uses: a, x, y, t6, t7
; ------------------------------------------------------------
readname
        ldy #1
        bne rdl
readline
        ldy #0
rdl     sta t7
        sty t6
        jsr clrchn
        ldx #0
@cu     stx inlen
        lda #18                 ; the cursor: a reversed space, then back
        jsr chrout
        lda #' '
        jsr chrout
        lda #146
        jsr chrout
        lda #157
        jsr chrout
@k      jsr getin
        beq @k
        ldx inlen
        cmp #13
        beq @e
        cmp #20                 ; del: the last one off
        bne @c
        txa
        beq @k
        lda #' '                ; (the cursor off, back onto the last)
        jsr chrout
        lda #157
        jsr chrout
        jsr chrout
        dex
        jmp @cu
@c      ldy t6
        bne @in                 ; (a name: any key)
        cmp #' '                ; printable: $20-$7f, $a0-$ff
        bcc @k
        cmp #$80
        bcc @in
        cmp #$a0
        bcc @k
@in     cpx t7
        bcs @k                  ; (full)
        sta inbuf,x
        inx
        jsr prsafe
        jmp @cu
@e      stx inlen
        lda #' '                ; the cursor off
        jsr chrout
        lda #13
        jsr chrout
@t      ldx inlen               ; trailing spaces
        beq @x
        lda inbuf-1,x
        cmp #' '
        bne @x
        dec inlen
        bne @t
@x      rts

; prsafe  character a printed; a control code as quote mode shows it
; (reversed: code + $40), so that it does nothing
;   keeps: x, y
prsafe  cmp #' '
        bcc @c
        cmp #$80
        bcc @p
        cmp #$a0
        bcs @p
@c      ora #$40
        pha
        lda #18
        jsr chrout
        pla
        jsr chrout
        lda #146
@p      jsr chrout
        lda #0                  ; (no quote mode after a ")
        sta $d4
        rts

; innum  inbuf as a decimal number: a (0-255), c set if not one (or
; empty: z set then)
innum   lda #0
        sta t0
        ldx #0
        cpx inlen
        beq @e
@c      cpx inlen
        beq @ok
        lda inbuf,x
        cmp #' '
        beq @s
        sec
        sbc #'0'
        cmp #10
        bcs @bad
        sta t1
        lda t0                  ; t0 x 10 + the digit, over 255 not one
        asl a                   ; (it wrapped: 264 was taken as 9)
        bcs @bad
        asl a
        bcs @bad
        adc t0
        bcs @bad
        asl a
        bcs @bad
        adc t1
        bcs @bad
        sta t0
@s      inx
        bne @c
@ok     lda t0
        clc
        ldx #1                  ; (z clear)
        rts
@e      sec
        lda #0                  ; (z set: empty)
        rts
@bad    sec
        ldx #1
        rts

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

; ------------------------------------------------------------
; the drive's status: dstat  read channel 15 of drive a into dsbuf;
; c set if it isn't "00" (or 73, the power-on message)
;   uses: a, x, y
; ------------------------------------------------------------
dstat   ldy #15                 ; lfn 15 for the program's drive, 14 for
        cmp prgdev              ; the other: opened once and left open
        bne @o                  ; (closing it closes the drive's files);
        cmp cmd15dev            ; either closed when its drive is another
        beq @l                  ; than before
        sta cmd15dev
        bne @cl                 ; (z: the cmp's, not equal)
@o      ldy #14
        cmp cmd14dev
        beq @l
        sta cmd14dev
@cl     pha
        lda cmdopen-14,y
        beq @l0
        sty t6
        tya
        jsr close
        ldy t6
        lda #0
        sta cmdopen-14,y
@l0     pla
@l      sty t6
        tax
        lda cmdopen-14,y
        bne @rd
        lda #0                  ; is a drive there? LISTEN and a secondary
        sta $90                 ; address: st bit 7 if none answers (an OPEN
        txa                     ; without a name doesn't touch the bus, and
        pha                     ; CHKIN would wait for one for ever)
        jsr k_listen
        lda #$6f
        jsr k_second
        jsr k_unlsn
        pla
        tax
        lda $90
        bmi @nodev
        lda t6
        ldy #15
        jsr setlfs
        lda #0
        jsr setnam
        jsr open
        bcs @nodev
        jsr readst
        and #$80
        bne @nodev
        ldy t6
        lda #1
        sta cmdopen-14,y
@rd     ldx t6
        jsr chkin
        ldx #0
@r      jsr chrin
        sta dsbuf,x
        inx
        cmp #13
        beq @e
        cpx #39
        bcc @r
@e      lda #0
        sta dsbuf,x
        jsr clrchn
        lda dsbuf
        cmp #'0'
        bne @bad
        lda dsbuf+1
        cmp #'0'
        bne @bad
        clc
        rts
@bad    cmp #'3'                ; 73: the drive's power-on message
        bne @no
        lda dsbuf
        cmp #'7'
        bne @no
        clc
        rts
@nodev  lda t6
        jsr close
        ldx #0
@cp     lda tx_nodev,x
        sta dsbuf,x
        beq @no
        inx
        bne @cp
@no     sec
        rts
cmdopen byte 0,0                ; lfn 14, 15 open
cmd14dev byte 0                 ; lfn 14's drive
cmd15dev byte 0                 ; lfn 15's (the program's drive when opened)
k_listen = $ffb1                ; (KERNAL: the serial bus)
k_second = $ff93
k_unlsn = $ffae

; cmdclose  both command channels closed (no files open then)
cmdclose
        lda #14
        jsr close
        lda #15
        jsr close
        lda #0
        sta cmdopen
        sta cmdopen+1
        rts

; prstat  print the drive's status line
prstat  ldx #<dsbuf
        ldy #>dsbuf
        jmp print

; ------------------------------------------------------------
; the program file: openprg (channel 2 on prgdev, name prgname), its
; load address read into paddr; rdbyte one byte (c set at the end, or
; at a read error: rderr 1 then; z
; clear: the last byte was read); closeprg
; ------------------------------------------------------------
openprg lda #2
        ldx prgdev
        ldy #2
        jsr setlfs
        lda prglen
        ldx #<prgname
        ldy #>prgname
        jsr setnam
        jsr open
        lda prgdev
        jsr dstat
        bcs @bad
        ldx #2
        jsr chkin
        jsr chrin
        sta paddr
        jsr chrin
        sta paddr+1
        jsr readst
        and #$bf                ; (end of file: a 2-byte file is still one)
        bne @rd
        lda #0
        sta eof
        sta rderr
        clc
        rts
@rd     jsr closeprg
        ldx #<tx_rderr
        ldy #>tx_rderr
        jsr print
        sec
        rts
@bad    jsr closeprg
        jsr prstat
        sec
        rts

rdbyte  lda eof
        bne @end
        jsr chrin
        pha
        jsr readst
        tax
        and #$bf                ; a read error: the end, and rderr says why
        bne @er                 ; (not the end of the file: the program
        txa                     ; would be taken as shorter)
        and #$40
        sta eof
        pla
        clc
        rts
@er     lda #1
        sta rderr
        sta eof
        pla
@end    lda #0
        sec
        rts
rderr   byte 0                  ; 1: the last read stopped at an error

closeprg
        jsr clrchn
        lda #2
        jmp close

; ------------------------------------------------------------
; the .tap file: tapopen (channel 3 on tapdev, "name,p,w"), tapout (its
; chkout), taphead (the 20-byte header with the size), tapclose
; ------------------------------------------------------------
tapopen ldx tapfnl              ; name,p,w after the typed name
        lda #','
        sta tapfname,x
        lda #'p'
        sta tapfname+1,x
        lda #','
        sta tapfname+2,x
        lda #'w'
        sta tapfname+3,x
        txa
        clc
        adc #4
        ldx #<tapfname
        ldy #>tapfname
        jsr setnam
        lda #3
        ldx tapdev
        ldy #3
        jsr setlfs
        jsr open
        lda tapdev
        jsr dstat
        bcc @ok
        jsr prstat
        lda #3
        jsr close
        sec
@ok     rts

tapout  ldx #3
        jmp chkout

taphead jsr tapout
        ldx #0
@c      lda tx_c64tape,x
        jsr chrout
        inx
        cpx #16
        bcc @c
        lda tapn                ; the size: the pulses (one byte each)
        jsr chrout
        lda tapn+1
        jsr chrout
        lda tapn+2
        jsr chrout
        lda #0
        jsr chrout
        jmp clrchn

tapclose
        jsr clrchn
        lda #3
        jsr close
        lda tapdev
        jsr dstat
        bcc @x
        jsr prstat              ; (c set: the drive's error, said)
        sec
@x      rts

tx_c64tape
        byte $43,$36,$34,$2d,$54,$41,$50,$45,$2d,$52,$41,$57   ; "C64-TAPE-RAW"
        byte 1,0,0,0
tx_nodev text "no drive there",13,0
tx_rderr text "read error",13,0
