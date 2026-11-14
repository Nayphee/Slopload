; ------------------------------------------------------------
; io.asm  -  the tools' screen and disk: text out and in, the drive's
; status (iohex.asm: hexadecimal; ioprg.asm: SlopLoad 64's program file
; and .tap file)
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
        jsr prch                ; (chrout; SlopLoad 64's words.asm: $c0-$ff a word)
        iny
        bne @c
        inc p3+1
        bne @c
@x      rts

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

; ------------------------------------------------------------
; the drive's status: dstat  read channel 15 of drive a into dsbuf;
; c set if it isn't "00" (or 73, the power-on message)
;   out:  t6 the command channel's file (13-15)
;   uses: a, x, y
;   note: a drive's command channel is opened once and left open, since
;         closing it closes every file open on that drive. Three files
;         (13, 14, 15), each with its drive: the one this drive has
;         already, else one given up, never the program's drive's nor
;         cmdkeep's (a drive with a file being written). SlopLoad 64
;         has three files open at most (the program, the .tap, a
;         second module), each on a drive of its own if need be. A tool
;         that only asks for prgdev's status is always given file 15.
; ------------------------------------------------------------
dstat   ldy #15                 ; a file on this drive already?
@f      cmp cmddev-13,y
        beq @l
        dey
        cpy #13
        bcs @f
        ldy #15                 ; none: one given up
@v      ldx cmddev-13,y
        cpx prgdev
        beq @nv
        cpx cmdkeep
        bne @take
@nv     dey
        cpy #13                 ; (two kept at most: the third is free)
        bne @v
@take   sta cmddev-13,y
        pha
        lda cmdopen-13,y
        beq @l0
        sty t6
        tya
        jsr close
        ldy t6
        lda #0
        sta cmdopen-13,y
@l0     pla
@l      sty t6
        tax
        lda cmdopen-13,y
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
        sta cmdopen-13,y
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
cmdopen byte 0,0,0              ; files 13, 14, 15: open
cmddev  byte 0,0,0              ; ... their drives (0: none yet)
cmdkeep byte $ff                ; a drive whose file is kept ($ff: none)
k_listen = $ffb1                ; (KERNAL: the serial bus)
k_second = $ff93
k_unlsn = $ffae

; cmdclose  the command channels closed (no files open then)
cmdclose
        ldx #2
@c      txa
        pha
        clc
        adc #13
        jsr close
        pla
        tax
        lda #0
        sta cmdopen,x
        dex
        bpl @c
        rts

; prstat  print the drive's status line
prstat  ldx #<dsbuf
        ldy #>dsbuf
        jmp print

tx_nodev text "no drive there",13,0
tx_rderr text "read error",13,0
