; ------------------------------------------------------------
; ioprg.asm  -  SlopLoad 64's files: the program (read a byte at a
; time) and the .tap (written); io.asm's, for SlopLoad 64 alone (the
; other tools read and write theirs whole: wfile.asm)
; ------------------------------------------------------------

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
        lda tapdev              ; its drive's command channel kept while it
        sta cmdkeep             ; is written (dstat: closing that would
        jsr dstat               ; close the .tap)
        bcc @ok
        jsr prstat
        lda #3
        jsr close
        sec
        bcs tapfree
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
        bcc tapfree
        jsr prstat              ; (c set: the drive's error, said)
        sec
tapfree lda #$ff                ; (the carry kept)
        sta cmdkeep
        rts

tx_c64tape
        byte $43,$36,$34,$2d,$54,$41,$50,$45,$2d,$52,$41,$57   ; "C64-TAPE-RAW"
        byte 1,0,0,0
