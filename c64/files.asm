; ------------------------------------------------------------
; files.asm  -  SlopLoad 64's files from disk: a whole file read into
; memory, the drive's files listed by their ending, and the high pool
; (the RAM under the I/O and the KERNAL, $d000-$fff9) read and written
;
; Where the files go:
;   a module (.lm) or a picture (.koa): the high pool, one at a
;     time (hpool says which; the other is read again when it's wanted)
;   a tune (.sid, .slm): read whole into $a000 (scratch), then its bytes
;     to the music pool (mpool, below $a000), at the same offset in
;     their page as where they play; a prepared tune's relocations to
;     $c700
;   the show module, moved to its place: the high pool from $f800
; ------------------------------------------------------------

hpbase  = $d000                 ; the high pool
hpmax   = $fffa-$d000           ; ... its size
stage   = $a000                 ; a tune's file, as read (7.5 KB)
stagemax = $1e00
mrel    = $c700                 ; a prepared tune's relocations (512 words)
showbuf = $f800                 ; the show module, moved: in the high pool,
                                ; past a picture (a game longer than $2800
                                ; is read again after)
dnames  = $be00                 ; names listed: 16 x (length, 16 characters)
dmax    = 16

fdev    byte 8                  ; fload's file: drive, name
fnlen   byte 0
fname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fmax    word 0                  ; ... the most bytes to read
flen    word 0                  ; ... the bytes read
flong   byte 0                  ; ... 1: it was longer than fmax
dnum    byte 0                  ; names listed

; ------------------------------------------------------------
; fload  the file fdev/fname into memory from p1 (the high pool
; written with the I/O and KERNAL switched out for each byte)
;   in:   p1, fmax
;   out:  flen; c set on an error (said: the drive's status, too long,
;         empty)
;   uses: a, x, y, p1, t0
; ------------------------------------------------------------
fload   lda #0
        sta flen
        sta flen+1
        sta flong
        lda #4
        ldx fdev
        ldy #4
        jsr setlfs
        lda fnlen
        ldx #<fname
        ldy #>fname
        jsr setnam
        jsr open
        bcs @nodev
        lda fdev
        jsr dstat
        bcs @bad
        ldx #4
        jsr chkin
@r      jsr chrin
        sta t0
        jsr readst
        and #$bf                ; (end of file is fine)
        bne @rderr
        lda flen                ; room for it?
        cmp fmax
        lda flen+1
        sbc fmax+1
        bcs @long
        lda t0
        ldy #0
        jsr hput
        inc p1
        bne @p
        inc p1+1
@p      inc flen
        bne @e
        inc flen+1
@e      jsr readst
        and #$40
        beq @r
        jsr fclose
        lda flen
        ora flen+1
        beq @empty
        clc
        rts
@nodev  ldx #<tx_nodev
        ldy #>tx_nodev
        jsr print
        jsr fclose
        sec
        rts
@bad    jsr fclose
        jsr prstat
        sec
        rts
@rderr  jsr fclose
        ldx #<tx_rderr
        ldy #>tx_rderr
        jsr print
        sec
        rts
@long   jsr fclose
        inc flong
        ldx #<tx_long
        ldy #>tx_long
        jsr print
        sec
        rts
@empty  ldx #<tx_empty
        ldy #>tx_empty
        jsr print
        sec
        rts
fclose  jsr clrchn
        lda #4
        jmp close
tx_long text "too long for slopload 64",13,0
tx_empty text "it's empty",13,0

; ------------------------------------------------------------
; hput / hget  a byte to / from (p1),y, the high pool's RAM under the
; I/O and the KERNAL too (hget: n and z as the byte); hget3 / hput3 the
; same at p3
;   uses: a (hget: the byte)
; ------------------------------------------------------------
hput    php
        sei
        pha
        lda #$34                ; all RAM
        sta $01
        pla
        sta (p1),y
        pha
        lda #$36
        sta $01
        pla
        plp
        rts
hget    php
        sei
        lda #$34
        sta $01
        lda (p1),y
        pha
        lda #$36
        sta $01
        pla
        plp
        ora #0                  ; (its flags)
        rts
hget3   php
        sei
        lda #$34
        sta $01
        lda (p3),y
        pha
        lda #$36
        sta $01
        pla
        plp
        ora #0
        rts
hput3   php
        sei
        pha
        lda #$34
        sta $01
        pla
        sta (p3),y
        pha
        lda #$36
        sta $01
        pla
        plp
        rts

; ------------------------------------------------------------
; dirlist  the names on drive fdev ending in one of the endings at x/y
; (each a length, then its characters; a 0 after the last): the first
; dmax into dnames
;   out:  dnum; c set if the directory can't be read (said)
;   uses: a, x, y, t0-t6, p3
; ------------------------------------------------------------
dirlist stx dsuf
        sty dsuf+1
        lda #0
        sta dnum
        lda #4
        ldx fdev
        ldy #0
        jsr setlfs
        lda #1
        ldx #<tx_dollar
        ldy #>tx_dollar
        jsr setnam
        jsr open
        bcc @bq1
        jmp @nodev
@bq1
        ldx #4
        jsr chkin
        bcc @bq2
        jmp @nodev
@bq2
        jsr chrin               ; (its load address)
        jsr chrin
        jsr readst
        bne @nodev
        lda #1                  ; (the first line: the disk's name)
        sta t6
@ln     jsr chrin               ; a line: its link (0: the end)
        sta t0
        jsr chrin
        ora t0
        beq @end
        jsr readst
        bne @end
        jsr chrin               ; (its number)
        jsr chrin
        ldx #0                  ; the name between the quotes
        stx t1                  ; (in it?)
@ch     jsr readst
        bne @end
        jsr chrin
        cmp #0
        beq @eol
        cmp #$22
        bne @nq
        lda t1
        eor #1
        sta t1
        jmp @ch
@nq     ldy t1
        beq @ch
        cpx #16
        bcs @ch
        sta dname,x
        inx
        bne @ch
@eol    lda t6                  ; the disk's name: not a file
        beq @f
        lda #0
        sta t6
        beq @ln
@f      stx dnlen
        jsr dmatch
        bcc @ln
        lda dnum                ; one more
        cmp #dmax
        bcs @ln
        jsr dslot
        lda dnlen
        ldy #0
        sta (p3),y
@cp     lda dname,y
        iny
        sta (p3),y
        cpy dnlen
        bcc @cp
        inc dnum
        jmp @ln
@end    jsr fclose
        clc
        rts
@nodev  jsr fclose
        ldx #<tx_nodev
        ldy #>tx_nodev
        jsr print
        sec
        rts
dsuf    word 0
dname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dnlen   byte 0
tx_dollar text "$"

; dslot  p3: dnames' entry a (17 bytes each)
dslot   sta t0
        lda #<dnames
        sta p3
        lda #>dnames
        sta p3+1
        ldx t0
        beq @x
@a      lda p3
        clc
        adc #17
        sta p3
        bcc @n
        inc p3+1
@n      dex
        bne @a
@x      rts

; dmatch  c set if dname (dnlen) ends in one of the endings at dsuf
dmatch  lda dsuf
        sta p3
        lda dsuf+1
        sta p3+1
@s      ldy #0
        lda (p3),y              ; this ending's length (0: none left)
        beq @no
        sta t2
        cmp dnlen
        bcs @next               ; (as long as the name, or longer: no)
        lda dnlen               ; the name's last t2 characters
        sec
        sbc t2
        tax
@c      iny
        lda (p3),y
        cmp dname,x
        bne @next
        inx
        cpy t2
        bcc @c
        sec
        rts
@next   lda p3                  ; past it
        sec
        adc t2
        sta p3
        bcc @s
        inc p3+1
        bne @s
@no     clc
        rts

; ------------------------------------------------------------
; dshow  the names listed, numbered, two to a line
;   uses: a, x, y, t0-t2, p3
; ------------------------------------------------------------
dshow   lda #0
        sta t2
@n      lda t2
        cmp dnum
        bcs @x
        clc
        adc #1
        ldx #0
        cmp #10
        bcs @two
        pha
        lda #' '
        jsr chrout
        pla
@two    ldx #0
        jsr prdec16
        lda #' '
        jsr chrout
        lda t2
        jsr dslot
        ldy #0
        lda (p3),y
        sta t1
@c      cpy t1
        bcs @pad
        iny
        lda (p3),y
        jsr chrout
        jmp @c
@pad    lda t2                  ; two a line: pad the first to 20
        and #1
        bne @nl
@sp     cpy #16
        bcs @nx
        lda #' '
        jsr chrout
        iny
        bne @sp
@nl     lda #13
        jsr chrout
@nx     inc t2
        bne @n
@x      lda t2
        and #1
        beq @r
        lda #13
        jsr chrout
@r      rts

; ------------------------------------------------------------
; pickfile  a file of one of the endings at x/y on drive a: the list,
; then a number from it or a name typed; into fdev/fname
;   out:  c set if nothing was chosen (an empty line; pkzero 1: 0 typed)
;   uses: a, x, y, t0-t7, p3
; ------------------------------------------------------------
pickfile
        stx pksuf               ; (the endings, kept)
        sty pksuf+1
        ldx #0
        stx pkzero
        ldx #<q_fdrive
        ldy #>q_fdrive
        jsr asknum
        bcs @no
        tax                     ; (drive 0: none, as 0 from the list)
        beq @zero
        cmp #8
        bcc @no
        cmp #31
        bcs @no
        sta fdev
        ldx pksuf
        ldy pksuf+1
        jsr dirlist
        bcs @no
        jsr dshow
        lda dnum
        beq @nm
        ldx #<q_fpick
        ldy #>q_fpick
        jsr print
        jmp @in
@nm     ldx #<q_fname
        ldy #>q_fname
        jsr print
@in     lda #16
        jsr readline
        lda inlen
        beq @no
        jsr innum               ; a number from the list?
        bcs @name
        cmp #1
        bcc @zero
        cmp dnum
        beq @num
        bcs @name
@num    sec
        sbc #1
        jsr dslot
        ldy #0
        lda (p3),y
        sta fnlen
@cn     iny
        lda (p3),y
        sta fname-1,y
        cpy fnlen
        bcc @cn
        clc
        rts
@name   lda inlen
        sta fnlen
        ldx #0
@ct     lda inbuf,x
        sta fname,x
        inx
        cpx inlen
        bcc @ct
        clc
        rts
@no     sec
        rts
@zero   inc pkzero              ; 0: none
        sec
        rts
pksuf   word 0
pkzero  byte 0
q_fdrive text "drive [",0
q_fpick text "number or name? ",0
q_fname text "name? ",0
