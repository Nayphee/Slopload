; ------------------------------------------------------------
; notes.asm  -  NOTES: the suite's instructions read on the C64, a
; chapter at a time, from the text files on SlopLoad 64's B side
;
; LOAD"NOTES",8 and RUN. It reads the list of chapters (notes.idx, a
; SEQ file: tools/c64docs.py makes it and the chapters from the
; documents), shows it a page at a time with a number for each chapter,
; and prints the chapter chosen 23 lines to a page: any key for the next
; page, the back arrow or RUN/STOP for the list. RETURN alone at the
; list reads the next chapter, so the whole of it reads straight
; through.
;
; The files are on the drive NOTES was loaded from; if the list isn't
; there it asks for the drive. A chapter is PETSCII text in the lower
; and upper case set, lines of 39 characters at most, each starting
; with its colour; the list is shown in the upper case set, as the
; other tools' menus.
;
; Every file is opened after its drive's command channel, and the drive
; asked whether it opened before a byte is read: reading a file that
; isn't there can leave a C64 waiting for ever (the KERNAL has no time
; limit there). The file is closed first, the command channel after it.
;
; Memory: the program $0801 on, the list after it (4,000 bytes at
; most, 96 lines); zero page $fb-$fe only, so BASIC is as it was when
; it leaves (BASIC's warm start).
; ------------------------------------------------------------

; ---- KERNAL ----
chrout = $ffd2
chrin = $ffcf
getin = $ffe4
setlfs = $ffba
setnam = $ffbd
open = $ffc0
close = $ffc3
chkin = $ffc6
clrchn = $ffcc
readst = $ffb7

; ---- zero page ----
p1 = $fb                        ; a pointer (2)
p2 = $fd                        ; another (2)

maxent = 96                     ; the list's lines at most
idxmax = 4000                   ; ... and its bytes
perpage = 18                    ; the list's lines on a page
txtpage = 23                    ; a chapter's lines on a page

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "noteshd.asm"    ; (tx_head: tools/c64build.py)

; ------------------------------------------------------------
; main  the list read from the drive it was loaded from, then the menu
; ------------------------------------------------------------
main    lda $ba                 ; the drive last used: where it came from
        cmp #8
        bcs @d
        lda #8
@d      sta dev
        lda #1
        sta cur
@load   jsr head
        jsr rdindex
        bcc menu
        ldx #<q_drive           ; no list there: another drive?
        ldy #>q_drive
        jsr print
        lda dev
        jsr prnum
        ldx #<tx_q
        ldy #>tx_q
        jsr print
        lda #2
        jsr readline
        lda inlen
        beq @load               ; (return alone: the same again)
        lda inbuf
        cmp #'q'
        beq quit
        jsr innum
        bcs @load
        cmp #8
        bcc @load
        cmp #31
        bcs @load
        sta dev
        bne @load

; ------------------------------------------------------------
; quit  the upper case set again, and BASIC's READY
; ------------------------------------------------------------
quit    lda #142
        jsr chrout
        lda #13
        jsr chrout
        jmp ($a002)

; ------------------------------------------------------------
; menu  a page of the list, the keys, and what is typed
; ------------------------------------------------------------
menu    jsr showpg
        ldx #<tx_keys
        ldy #>tx_keys
        jsr print
        lda nchap
        jsr prnum
        ldx #<tx_keys2
        ldy #>tx_keys2
        jsr print
        lda cur
        jsr prnum
        ldx #<tx_q
        ldy #>tx_q
        jsr print
        lda #2
        jsr readline
        lda inlen
        bne @typed
        lda cur                 ; return alone: the chapter in the brackets
        bne @read
@typed  lda inbuf
        cmp #'q'
        beq quit
        cmp #'+'
        beq @more
        cmp #'-'
        beq @back
        jsr innum
        bcs menu
        beq menu
        cmp nchap
        beq @read
        bcs menu
@read   sta cur
        jsr chapter
        jmp menu
@more   lda nxttop              ; the next page of the list (round to the first)
        cmp nent
        bcc @t
        lda #0
@t      sta top
        jmp menu
@back   lda top
        sec
        sbc #perpage
        bcs @t
        lda #0
        beq @t

; ------------------------------------------------------------
; head  the screen cleared, the upper case set, the title
; ------------------------------------------------------------
head    lda #142
        jsr chrout
        lda #147
        jsr chrout
        ldx #<tx_head
        ldy #>tx_head
        jsr print
        lda #13
        jmp chrout

; ------------------------------------------------------------
; showpg  the title and the list's page from line top: a heading as it
; is, a chapter with its number. Sets nxttop, the line after the page
;   uses: a, x, y, p1, t0, t1
; ------------------------------------------------------------
showpg  jsr head
        lda #13
        jsr chrout
        ldx #0                  ; the number of the chapter before top
        stx t0
@cn     cpx top
        beq @go
        jsr entry
        ldy #0
        lda (p1),y
        cmp #':'
        beq @h
        inc t0
@h      inx
        bne @cn
@go     lda #perpage
        sta t1
@ln     cpx nent
        beq @end
        jsr entry
        ldy #0
        lda (p1),y
        cmp #':'
        bne @ch
        lda #5                  ; a heading: white
        jsr chrout
        lda #1
        bne @pr
@ch     inc t0
        stx t2                  ; (prnum takes x)
        lda t0
        cmp #10
        bcs @n2
        lda #' '
        jsr chrout
@n2     lda t0
        jsr prnum
        lda #' '
        jsr chrout
        ldx t2
        ldy #0                  ; the title: after the file's name
@sk     lda (p1),y
        beq @af
        iny
        bne @sk
@af     iny
        tya
@pr     clc                     ; (a: where the text starts in the line)
        adc p1
        stx t2
        tax
        lda p1+1
        adc #0
        tay
        jsr print
        lda #30
        jsr chrout
        lda #13
        jsr chrout
        ldx t2
        inx
        dec t1
        bne @ln
@end    stx nxttop
        rts

; ------------------------------------------------------------
; entry  p1 = the list's line x
;   keeps: x
; ------------------------------------------------------------
entry   lda enl,x
        sta p1
        lda enh,x
        sta p1+1
        rts

; ------------------------------------------------------------
; chapter  chapter cur read a page at a time; at its end cur is the
; next one, and the list's page the one with it
;   uses: everything
; ------------------------------------------------------------
chapter ldx #0                  ; its line in the list
        stx t0
@f      jsr entry
        ldy #0
        lda (p1),y
        cmp #':'
        beq @nx
        inc t0
        lda t0
        cmp cur
        beq @got
@nx     inx
        cpx nent
        bne @f
        rts                     ; (no such chapter)
@got    stx t3
        ldy #0                  ; its file's name, then ",s,r"
@nm     lda (p1),y
        beq @ne
        sta fname,y
        iny
        cpy #16
        bne @nm
@ne     ldx #0
@sr     lda tx_sr,x
        sta fname,y
        iny
        inx
        cpx #4
        bne @sr
        tya
        jsr fopen
        bcc @open
        jmp anykey              ; (the drive's words are on the screen)
@open   lda #14                 ; the lower and upper case set
        jsr chrout
@page   lda #147
        jsr chrout
        lda #0
        sta lines
        ldx #2
        jsr chkin
@c      jsr chrin
        tax
        jsr readst
        sta eof
        txa
        jsr chrout
        lda #0                  ; (no quote mode, no insert mode: a quotation
        sta $d4                 ; mark in the text is only that)
        sta $d8
        cpx #13
        bne @e
        inc lines
        lda lines
        cmp #txtpage
        bcc @e
        lda eof                 ; a page full
        bne @fin
        jsr clrchn
        ldx #<tx_more
        ldy #>tx_more
        jsr print
        jsr key
        cmp #95                 ; the back arrow, or run/stop: the list
        beq @out
        cmp #3
        beq @out
        bne @page
@e      lda eof
        beq @c
@fin    jsr clrchn              ; its end: the next chapter is the one offered
        ldx #<tx_end
        ldy #>tx_end
        jsr print
        jsr key
        lda cur
        cmp nchap
        beq @out
        inc cur
        inc t3
@out    jsr fclose
        lda t3                  ; the list's page with the chapter offered
        cmp nxttop
        bcc @lo
        sta top
        rts
@lo     cmp top
        bcs @x
        sta top
@x      rts

; ------------------------------------------------------------
; rdindex  the list read and cut into lines: enl/enh each line's start,
; nent how many, nchap the chapters among them (a heading's line starts
; with a colon; a chapter's is its file's name, a colon, its title: the
; colon and each line's end become 0)
;   out:  c set if it isn't there (the drive's words printed)
; ------------------------------------------------------------
rdindex ldx #0
@n      lda tx_idx,x
        sta fname,x
        inx
        cpx #13
        bne @n
        txa
        jsr fopen
        bcc @op
        rts
@op     lda #<idxbuf
        sta p1
        lda #>idxbuf
        sta p1+1
        ldx #2
        jsr chkin
@rd     jsr chrin
        ldy #0
        sta (p1),y
        jsr readst
        pha
        inc p1
        bne @k
        inc p1+1
@k      pla
        bne @eof
        lda p1+1                ; (room for it)
        cmp #>idxend
        bcc @rd
@eof    lda #13                 ; (a last line with no return)
        ldy #0
        sta (p1),y
        lda p1                  ; p2: the end
        sta p2
        lda p1+1
        sta p2+1
        jsr clrchn
        jsr fclose
        lda #<idxbuf
        sta p1
        lda #>idxbuf
        sta p1+1
        ldx #0
        stx nchap
        stx top
@line   lda p1                  ; a line starts here: past the end?
        cmp p2
        lda p1+1
        sbc p2+1
        bcs @done
        cpx #maxent
        beq @done
        lda p1
        sta enl,x
        lda p1+1
        sta enh,x
        ldy #0
        lda (p1),y
        cmp #13                 ; (an empty line: not one of the list's)
        beq @skip
        cmp #':'
        beq @hd
        inc nchap
@col    lda (p1),y              ; its name's end
        cmp #13
        beq @eol
        cmp #':'
        beq @z
        iny
        bne @col
@z      lda #0
        sta (p1),y
@hd     iny
@fe     lda (p1),y              ; the line's end
        cmp #13
        beq @eol
        iny
        bne @fe
@eol    lda #0
        sta (p1),y
        inx
@skip   iny                     ; on to the next line
        tya
        clc
        adc p1
        sta p1
        bcc @line
        inc p1+1
        bne @line
@done   stx nent
        txa                     ; (nothing in it: as if it weren't there)
        beq @none
        clc
        rts
@none   sec
        rts

; ------------------------------------------------------------
; fopen  the file named in fname (a characters, with its ",s,r") opened
; as file 2 on drive dev, the drive's command channel (file 15) first,
; and the drive asked whether it opened
;   out:  c clear: open. c set: the drive's words printed, nothing open
;   uses: a, x, y
; ------------------------------------------------------------
fopen   pha
        lda #15
        ldx dev
        ldy #15
        jsr setlfs
        lda #0
        jsr setnam
        jsr open
        pla
        ldx #<fname
        ldy #>fname
        jsr setnam
        lda #2
        ldx dev
        ldy #2
        jsr setlfs
        jsr open
        bcs @nodev
        ldx #15                 ; what the drive says: "00, ok,00,00"
        jsr chkin
        bcs @nodev
        ldx #0
@st     jsr chrin
        cmp #13
        beq @se
        sta stbuf,x
        cpx #38
        beq @s2
        inx
@s2     jsr readst
        beq @st
@se     lda #0
        sta stbuf,x
        jsr clrchn
        lda stbuf               ; 00-19: no error
        cmp #'2'
        bcc @ok
        ldx #<stbuf
        ldy #>stbuf
        jsr print
        lda #13
        jsr chrout
        jmp @bad
@nodev  jsr clrchn
        ldx #<tx_nodev
        ldy #>tx_nodev
        jsr print
        lda dev
        jsr prnum
        lda #13
        jsr chrout
@bad    jsr fclose
        sec
        rts
@ok     clc
        rts

; ------------------------------------------------------------
; fclose  the file closed, then its drive's command channel
; ------------------------------------------------------------
fclose  jsr clrchn
        lda #2
        jsr close
        lda #15
        jmp close

; ------------------------------------------------------------
; anykey  "press any key", and one
; key     a key waited for: a
; ------------------------------------------------------------
anykey  ldx #<tx_anyk
        ldy #>tx_anyk
        jsr print
key     jsr getin
        beq key
        rts

; ------------------------------------------------------------
; print  the text at x/y (lo/hi) up to a 0
;   uses: a, y, p2
; ------------------------------------------------------------
print   stx p2
        sty p2+1
        ldy #0
@l      lda (p2),y
        beq @x
        jsr chrout
        iny
        bne @l
@x      rts

; ------------------------------------------------------------
; prnum  a (0-99) in decimal, no leading zero
;   uses: a, x
; ------------------------------------------------------------
prnum   ldx #47                 ; ('0' less one)
        sec
@t      inx
        sbc #10
        bcs @t
        adc #58                 ; (10 and '0')
        pha
        cpx #'0'
        beq @o
        txa
        jsr chrout
@o      pla
        jmp chrout

; ------------------------------------------------------------
; readline  a line typed at the keyboard into inbuf (inlen its length,
; a at most): printable keys, del takes one back, return ends it. Key
; by key, not the screen editor's line
;   uses: a, x, y
; ------------------------------------------------------------
readline
        sta t2
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
        lda #' '
        jsr chrout
        lda #157
        jsr chrout
        jsr chrout
        dex
        jmp @cu
@c      cmp #' '                ; printable: $20-$5f
        bcc @k
        cmp #$60
        bcs @k
        cpx t2
        bcs @k                  ; (full)
        sta inbuf,x
        inx
        jsr chrout
        jmp @cu
@e      lda #' '                ; the cursor off
        jsr chrout
        lda #13
        jmp chrout

; ------------------------------------------------------------
; innum  inbuf as a decimal number: a (0-99), c set if not one
;   uses: a, x, y
; ------------------------------------------------------------
innum   ldx #0
        stx t1
        ldy inlen
        beq @bad
@d      lda inbuf,x
        sec
        sbc #'0'
        cmp #10
        bcs @bad
        pha
        lda t1                  ; times 10
        asl a
        asl a
        adc t1
        asl a
        sta t1
        pla
        clc
        adc t1
        sta t1
        inx
        cpx inlen
        bne @d
        lda t1
        clc
        rts
@bad    sec
        rts

; ---- its words (lowercase here: the unshifted keys, capitals in the
; upper case set, small letters over a chapter) ----
tx_keys text 13,155,"1-",0
tx_keys2 text ": read  +: more  -: back  q: quit",13,"return: the one in the brackets",30,13,"which [",0
tx_q    text "]? ",0
q_drive text "drive with the notes (q: quit) [",0
tx_nodev text "no drive ",0
tx_anyk text 155,"press any key",30,0
tx_more text 155,"more: a key   ",95,": the list",0
tx_end  text 155,"its end: a key",0
tx_idx  text "notes.idx,s,r"
tx_sr   text ",s,r"

; ---- what it keeps ----
dev     byte 8                  ; the drive with the notes
cur     byte 1                  ; the chapter in the brackets
top     byte 0                  ; the list's first line on the page
nxttop  byte 0                  ; ... and the line after the page
nent    byte 0                  ; the list's lines
nchap   byte 0                  ; ... and the chapters among them
lines   byte 0                  ; a chapter's lines on the page so far
eof     byte 0                  ; the file's status after its last byte
inlen   byte 0
inbuf   byte 0,0,0,0
t0      byte 0                  ; scratch
t1      byte 0
t2      byte 0
t3      byte 0
fname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; a file's name and ",s,r"
stbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; the drive's words (40)
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
enl     = *                     ; the list's lines: where each starts
enh     = enl+maxent
idxbuf  = enh+maxent            ; the list as read
idxend  = idxbuf+idxmax
