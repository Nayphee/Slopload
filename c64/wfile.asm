; ------------------------------------------------------------
; wfile.asm  -  a file named after the one read and written to its
; drive: for PETSCII-LM (a .pet to a .lm) and SID-SLM (a .sid to a .slm)
;
;   wname    outname: prgname with its ending (wold, 4 characters: ".pet")
;            changed to wnew's (its length, then the ending); the question
;            at x/y asked with that as the default; wnew added to an
;            answer without it, where there's room
;   wcreate  outname opened for writing as lfn 3, asked before replacing
;            a file: c set if not (said)
;   wclose   lfn 3 closed and the drive's status read: c set if it failed
;            (said); else "written: " and the name in quotes
;   wrblk    cnt (low) / y (high) bytes from a/x (lo/hi) to the output
;   prout    outname, in quotes
;
; The includer: wold, wnew, the texts tx_ask ("]? "), and io.asm (dstat,
; prstat, readline, print, cmdopen); zero page t4, p1 (2), cnt (2).
; ------------------------------------------------------------

outlen  byte 0                  ; the name written
outname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
cmdbuf  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; "s0:" and the name

wname   stx p1                  ; (the question)
        sty p1+1
        ldx #0                  ; the default: the name less wold, + wnew
        ldy prglen
        cpy #5
        bcc @cp
        lda prgname-4,y
        cmp wold
        bne @cp
        lda prgname-3,y
        cmp wold+1
        bne @cp
        lda prgname-2,y
        cmp wold+2
        bne @cp
        lda prgname-1,y
        cmp wold+3
        bne @cp
        dey
        dey
        dey
        dey
@cp     sty t4                  ; (16 less the ending at most)
        lda #16
        sec
        sbc wnew
        cmp t4
        bcs @c1
        sta t4
@c1     cpx t4
        bcs @ext
        lda prgname,x
        sta outname,x
        inx
        bne @c1
@ext    ldy #0
@e      lda wnew+1,y
        sta outname,x
        inx
        iny
        cpy wnew
        bcc @e
        stx outlen
        ldx p1                  ; the question, the default in brackets
        ldy p1+1
        jsr print
        jsr prout
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #16
        jsr readline
        ldx inlen
        beq @x                  ; (the default)
        stx outlen
@n      dex
        lda inbuf,x
        sta outname,x
        txa
        bne @n
        ldx outlen              ; ending as wnew?
        cpx wnew
        bcc @add
        ldy wnew
@q      dex
        lda outname,x
        cmp wnew,y
        bne @add0
        dey
        bne @q
@x      rts
@add0   ldx outlen
@add    txa                     ; no: added (if there's room)
        clc
        adc wnew
        cmp #17
        bcs @x
        ldy #0
@a      lda wnew+1,y
        sta outname,x
        inx
        iny
        cpy wnew
        bcc @a
        stx outlen
        rts

; wcreate  outname for writing (lfn 3); if it's there, asked first
wcreate jsr wopen
        bcc @x
        lda dsbuf               ; 63: it's there already
        cmp #'6'
        bne @err
        lda dsbuf+1
        cmp #'3'
        bne @err
        jsr prout
        ldx #<q_repl
        ldy #>q_repl
        jsr print
@k      jsr getin
        beq @k
        cmp #'y'
        bne @no
        jsr chrout
        lda #13
        jsr chrout
        jsr scratch             ; ("01, files scratched" is fine)
        lda dsbuf
        cmp #'0'
        bne @err
        lda dsbuf+1
        cmp #'2'
        bcs @err
        jsr wopen
        bcc @x
@err    jsr prstat
@no     lda #13
        jsr chrout
        sec
@x      rts

; wclose  the file closed, its status: written (said), or c set
wclose  jsr clrchn
        lda #3
        jsr close
        lda prgdev
        jsr dstat
        bcc @ok
        jsr prstat
        lda #13
        jsr chrout
        sec
        rts
@ok     ldx #<tx_wrote
        ldy #>tx_wrote
        jsr print
        jsr prout
        clc
        rts

; wrblk  cnt (low) / y (high) bytes from a/x (lo/hi) to the output
;   uses: a, y, p1, cnt
wrblk   sta p1
        stx p1+1
        sty cnt+1
        lda cnt
        ora cnt+1
        beq @x
        ldy #0
@w      lda (p1),y
        jsr chrout
        inc p1
        bne @n
        inc p1+1
@n      lda cnt
        bne @l
        dec cnt+1
@l      dec cnt
        lda cnt
        ora cnt+1
        bne @w
@x      rts

; wopen  outname opened for writing (lfn 3, ",p,w")
;   out:  c set if not (the status in dsbuf)
wopen   ldx outlen
        ldy #0
@c      lda tx_pw,y
        sta outname,x
        inx
        iny
        cpy #4
        bcc @c
        lda #3
        ldx prgdev
        ldy #3
        jsr setlfs
        lda outlen
        clc
        adc #4
        ldx #<outname
        ldy #>outname
        jsr setnam
        jsr open
        lda prgdev
        jsr dstat
        bcc @x
        lda #3
        jsr close
        sec
@x      rts

; scratch  outname scratched ("s0:" on the command channel)
;   out:  c set if it failed (the status in dsbuf)
scratch ldx #0
@p      lda tx_s0,x
        sta cmdbuf,x
        inx
        cpx #3
        bcc @p
        ldy #0
@n      lda outname,y
        sta cmdbuf,x
        inx
        iny
        cpy outlen
        bcc @n
        stx t4
        lda #15                 ; the command channel: lfn 15 (dstat opened it)
        jsr close
        lda #0
        sta cmdopen+1
        lda #15
        ldx prgdev
        ldy #15
        jsr setlfs
        lda t4
        ldx #<cmdbuf
        ldy #>cmdbuf
        jsr setnam
        jsr open
        lda #1
        sta cmdopen+1
        lda prgdev
        jmp dstat

; prout  outname, in quotes
prout   lda #34
        jsr chrout
        ldx #0
@c      cpx outlen
        bcs @q
        lda outname,x
        jsr chrout
        inx
        bne @c
@q      lda #34
        jmp chrout

q_repl  text " is there: replace it (y/n)? ",0
tx_wrote text "written: ",0
tx_pw   text ",p,w"
tx_s0   text "s0:"
