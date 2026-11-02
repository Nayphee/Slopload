; ------------------------------------------------------------
; disk.asm  -  a drive's directory and its commands, the @ of SlopLoad 64,
; SID-SLM and the TAP writer:
;   dcmd     drive ddev: its status, then lines typed after a ">":
;            "$" (or "$:sl*", "$0"...: a 1541's "*" ends the name, so
;            "$:*.sid" is every file) its directory, anything else a
;            command for the drive (its status after it); return alone:
;            done
;   dirshow  the directory "$..." in inbuf (inlen) of drive ddev, 20
;            lines a page (run/stop: no more); lfn 2
; The text keeps the includer's colour (646): "more: a key" is light grey.
; The includer: io.asm (dstat, prstat, readline, print, prdec16, inbuf,
; inlen), the KERNAL's names (chrout, chrin, chkin, chkout, clrchn,
; setnam, setlfs, open, close, readst, getin, stop) and zero page t0, t5,
; t6.
; ------------------------------------------------------------

dcmd    ldx #<tx_dhelp
        ldy #>tx_dhelp
        jsr print
@st     lda ddev                ; its status
        jsr dstat
        jsr prstat
@q      lda #'>'
        jsr chrout
        lda #38
        jsr readline
        lda inlen
        beq @x
        lda inbuf
        cmp #'$'
        beq @dir
        lda ddev                ; a command: to its channel (dstat opens
        jsr dstat               ; it: t6 its file), then its answer
        ldx t6
        jsr chkout
        bcs @st
        ldx #0
@sc     lda inbuf,x
        jsr chrout
        inx
        cpx inlen
        bcc @sc
        jsr clrchn
        jmp @st
@dir    jsr dirshow
        jmp @q
@x      rts
ddev    byte 8
tx_dhelp text "$ (or $:sl*...): its directory, else",13,"a command; return alone: done",13,0

; dirshow  the directory ("$..." in inbuf), 20 lines a page
dirshow lda inlen
        ldx #<inbuf
        ldy #>inbuf
        jsr setnam
        lda #2
        ldx ddev
        ldy #0
        jsr setlfs
        jsr open
        bcs @e
        ldx #2
        jsr chkin
        bcs @e
        jsr chrin               ; (its load address)
        jsr chrin
        lda #0
        sta t5
@l      jsr chrin               ; a line's link
        jsr chrin
        jsr readst              ; (the end: past the last)
        bne @e
        jsr chrin               ; its number: blocks
        sta t0
        jsr chrin
        tax
        lda t0
        jsr prdec16
        lda #' '
        jsr chrout
@c      jsr chrin
        beq @n
        jsr chrout
        jmp @c
@n      sta $d4                 ; (a 0: no quote mode)
        lda #13
        jsr chrout
        jsr stop                ; run/stop: no more
        beq @e
        inc t5
        lda t5
        cmp #20
        bcc @l
        jsr clrchn              ; a page: a key for the next
        lda 646                 ; (the text's colour: back after it)
        sta dcol
        ldx #<tx_more
        ldy #>tx_more
        jsr print
@k      jsr getin
        beq @k
        ldx dcol
        stx 646
        cmp #3                  ; (run/stop: no more)
        beq @e
        lda #13
        jsr chrout
        lda #0
        sta t5
        ldx #2
        jsr chkin
        jmp @l
@e      jsr clrchn
        lda #2
        jmp close
dcol    byte 0
tx_more text 155,"more: a key",0          ; (light grey)
