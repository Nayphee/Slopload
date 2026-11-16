; ------------------------------------------------------------
; petsciied.asm  -  PETSCII-ED: a PETSCII screen editor, for the
; screens PETSCII-LM makes into modules (a Petmate .pet file, read and
; written), with a font of its own to try the screen in
;
; LOAD"PETSCII-ED",8 and RUN. A menu of the settings, each on a line of
; its own and changed by its number at any time: the screen (a .pet
; read, or a new blank one), its border and background colours, the pen
; (the colour typed in), the case (the C64's upper case and graphics, or
; lower and upper), a font of its own (a .64c, as PETSCII-LM takes one:
; the screen is drawn in it). RETURN edits the screen, W writes it as a
; .pet, @ is the disk, Q quits (asked first if it isn't written).
;
; The editor is the whole screen, the screen itself, drawn as it will
; show (its border, background, case or font): a blinking cursor in the
; pen's colour; the keys type as on the C64 (SHIFT and C= the graphics,
; CTRL 9 and 0 reverse on and off, CTRL or C= with 1-8 the pen's
; colour), the cursor keys, HOME and RETURN move; DEL takes the one
; before. F1 shows all 256 characters (in the font) to choose one from;
; F3 colours the one under the cursor; F5 takes its colour for the pen;
; F2 and F4 step the border and the background on; F6 the case; F7 or
; RUN/STOP goes back to the menu. CLR does nothing (a new screen is
; line 1's).
;
; A .pet file: width (40), height (25), border, background, the case
; (0 lower, 1 upper), then 1,000 screen codes and 1,000 colours.
;
; Memory: the program $0801 on (to $37fd at most), the font $3800-$3fff
; ($d018 $1e, VIC bank 0), the screen's codes $4000-$43e7 and colours
; $4400-$47e7 (the editor draws them on the C64's screen and takes them
; back); zero page $20-$3b (BASIC's: it leaves through BASIC's warm
; start).
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
chkout = $ffc9
clrchn = $ffcc
readst = $ffb7
stop = $ffe1
plot = $fff0

; ---- zero page ----
t0 = $20                        ; scratch
t1 = $21
t2 = $22
t3 = $23
t4 = $24
t5 = $25
t6 = $26
t7 = $27
p1 = $28                        ; pointers (2 each)
p2 = $2a
p3 = $2c
n24 = $30                       ; numbers to print (3)
cnt = $34                       ; bytes to go (2)
sp = $36                        ; the editor: the cursor's place on the screen (2)
cp = $38                        ; ... and in colour memory (2)

; ---- memory ----
fontbuf = $3800                 ; a font of its own: 256 characters of 8 bytes
fontend = $4000                 ; (its end)
pcod = $4000                    ; the screen: its 1,000 codes
pcol = $4400                    ; ... and its 1,000 colours

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "io.asm"
        incasm "disk.asm"       ; ($ and @: a drive's files and commands)
prch = chrout                   ; (print's character: no words packed here)
        incasm "wfile.asm"

; ---- io.asm's variables ----
inlen   byte 0
inbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dsbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
prgdev  byte 8                  ; the screen's drive
prglen  byte 0                  ; ... its name (0: a new screen)
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ---- this program's ----
hdr     byte 0,0,0,0,0          ; a .pet's first bytes
border  byte 0                  ; the screen's border colour
bg      byte 0                  ; ... its background
case    byte 1                  ; ... its case: 1 upper case and graphics, 0 lower
pen     byte 1                  ; the colour typed in
rvs     byte 0                  ; $80: reverse on
dirty   byte 0                  ; 1: changed since read or written
fok     byte 0                  ; a font of its own read (1)
fdev    byte 8                  ; its drive
fnlen   byte 0                  ; its name
fname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
irow    byte 0                  ; the menu: the line's row
usedc   byte 5                  ; ... its value's colour
crow    byte 0                  ; the editor's cursor: row 0-24
ccol    byte 0                  ; ... column 0-39
cch     byte 0                  ; ... the character under it
ccl     byte 0                  ; ... and its colour
cvis    byte 0                  ; ... 1: shown (the cell changed)
cph     byte 0                  ; ... the clock's bit 4 at the last blink
pick    byte 0                  ; the characters (f1): the one chosen last
sdev    byte 8                  ; a drive asked, the screen's or the font's
                                ; (theirs once a file is read: return alone
                                ; at its name keeps the one there is)
odev    byte 8                  ; (awrite: the screen's drive before)
pcn     byte 0                  ; (prcol: the colour)
pli     byte 0                  ; (apen: the colour listed)

; ------------------------------------------------------------
; main
; ------------------------------------------------------------
main    lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        lda #$80                ; c= and shift don't change the case: the
        sta $0291               ; screen's is the menu's line 4
        lda #1                  ; (the keyboard's cursor never blinks: the
        sta $cc                 ; editor has its own)
        lda $ba                 ; the drive it was loaded from
        cmp #8
        bcc @n
        sta prgdev
        sta fdev
        sta ddev
@n      jsr newscr              ; a new screen to start with

; ------------------------------------------------------------
; menu  every setting on a line of its own (1-5), changed by its number
; at any time, as the other tools': the screen cleared, its name in a
; light blue bar on the top row and its questions under it; return
; edits the screen, w writes it, @ the disk, q quits. An action returns
; c set when it said something: "press any key" first, then the menu
; again.
; ------------------------------------------------------------
menu    ldx #$ff
        txs
        jsr clrchn
        lda #2
        jsr close
        jsr mdraw
@k      jsr getin
        beq @k
        cmp #13
        bne @w
        jsr edit                ; return: edit it
        jmp menu
@w      cmp #'w'
        bne @q
        lda #10                 ; w: write it
        jsr ptitle
        jsr awrite
        jmp @any
@q      cmp #'@'                ; @: the disk, its files and commands
        bne @qq
        lda #12
        jsr ptitle
        jsr adisk               ; (it ends on return alone: the menu again)
        jmp menu
@qq     cmp #'q'
        bne @n
        lda #11
        jsr ptitle
        jsr unsaved             ; (not written: asked)
        bcs menu
        jsr cmdclose
        jsr look
        ldx #<tx_bye
        ldy #>tx_bye
        jmp quit
@n      cmp #'1'
        bcc @k
        cmp #'5'+1
        bcs @k
        and #15                 ; 1-5: its line
        pha
        jsr ptitle
        pla
        asl a
        tax
        lda acts-2,x
        sta @j+1
        lda acts-1,x
        sta @j+2
@j      jsr @j                  ; (patched: the line's action)
        bcc menu
@any    jsr anykey
        jmp menu
acts    word ascreen,acolours,apen,acase,afont

; adisk  @: a drive [8], then its status and commands, and $ its files
; (disk.asm, as SlopLoad 64's @)
adisk   lda ddev
        ldx #<q_ddrive
        ldy #>q_ddrive
        jsr asknum
        bcs @x
        cmp #8
        bcc @x
        cmp #31
        bcs @x
        sta ddev
        jsr dcmd
@x      rts

; diskkey  a file name typed as $ (the drive's files) or @ alone (its
; status and commands): done, c set (ask again); else c clear
diskkey lda inlen
        beq @no
        lda inbuf
        cmp #'$'
        bne @at
        jsr dirshow
        sec
        rts
@at     cmp #'@'
        bne @no
        lda inlen
        cmp #1
        bne @no
        jsr dcmd
        sec
        rts
@no     clc
        rts

; unsaved  the screen changed and not written: asked whether to go on
;   out:  c clear: go on; c set: not (back to the menu)
unsaved lda dirty
        beq @go
        ldx #<q_lose
        ldy #>q_lose
        jsr print
@k      jsr getin
        beq @k
        cmp #'y'
        bne @no
        jsr chrout
        lda #13
        jsr chrout
@go     clc
        rts
@no     sec
        rts

quit    jsr print
        lda #0                  ; c= and shift change the case again
        sta $0291
        lda #$37
        sta $01
        sei                     ; (RESTOR writes $0314/$0315 a byte at a time)
        jsr $ff8a               ; the KERNAL's vectors again (RESTORE: not
        jsr $e453               ; this program's rti), BASIC's own, and its
        jsr $e3bf               ; zero page: this program kept its pointers
        jsr $a644               ; where BASIC's are ($2B on), and a LOAD after
        cli                     ; it went wherever they pointed. NEW, and
        jmp ($a002)             ; BASIC's warm start
rtiv    rti

; look  the screen cleared, its colours and character set the tool's
look    lda #0
        sta $d020
        sta $d021
        lda #$15
        sta $d018
        lda #5
        sta 646
        lda #147
        jmp chrout

; ------------------------------------------------------------
; mdraw  the screen cleared, the menu: the title (rows 0-1), lines 1-5
; (rows 3-7), the keys (rows 9-10), the editor's keys (rows 12-22)
; ------------------------------------------------------------
mdraw   jsr look
        ldx #<tx_head
        ldy #>tx_head
        jsr print
        lda #1                  ; 1 screen: its file, or new
        ldx #3
        jsr item
        lda prglen
        beq @s0
        lda prgdev
        ldx #<prglen
        ldy #>prglen
        jsr prfile
        jmp @s1
@s0     ldx #<tx_new
        ldy #>tx_new
        jsr print
@s1     lda dirty               ; (changed since: said; * where that
        beq @s2                 ; wouldn't fit before column 40)
        sec
        jsr plot
        cpy #29
        bcs @st
        ldx #<tx_chgd
        ldy #>tx_chgd
        bne @pr                 ; (always)
@st     ldx #<tx_star
        ldy #>tx_star
@pr     jsr print
@s2     lda #2                  ; 2 colours: border, background
        jsr item0
        ldx #<tx_bord
        ldy #>tx_bord
        jsr print
        lda border
        ldx #0
        jsr prdec16
        ldx #<tx_bgnd
        ldy #>tx_bgnd
        jsr print
        lda bg
        ldx #0
        jsr prdec16
        lda #3                  ; 3 pen: its number and name
        jsr item0
        lda pen
        jsr prcol
        lda fok                 ; 4 case (grey with a font of its own)
        beq @c4
        lda #151
        sta usedc
@c4     lda #4
        jsr item0
        ldx #<tx_upper
        ldy #>tx_upper
        lda case
        bne @c5
        ldx #<tx_lower
        ldy #>tx_lower
@c5     jsr print
        lda #5                  ; 5 font: the C64's, or the file's
        jsr item0
        lda fok
        bne @fo
        ldx #<tx_fc64
        ldy #>tx_fc64
        jsr print
        jmp @k
@fo     lda fdev
        ldx #<fnlen
        ldy #>fnlen
        jsr prfile
@k      ldx #9                  ; the keys (a row on, as the other tools')
        ldy #0
        clc
        jsr plot
        ldx #<tx_mkeys
        ldy #>tx_mkeys
        jmp print

; item  line a's number and name (green) on row x, then its value's
; colour (white, or grey: usedc); item0: on the row after the last
item0   inc irow
        ldx irow
item    stx irow
        pha
        ldy #0
        clc
        jsr plot
        lda #30                 ; green
        jsr chrout
        pla
        pha
        ora #'0'
        jsr chrout
        lda #' '
        jsr chrout
        pla
        tax
        lda lablo-1,x
        ldy labhi-1,x
        tax
        jsr print
        lda usedc
        jsr chrout
        lda #5                  ; (white for the next)
        sta usedc
        rts
lablo   byte <tl1,<tl2,<tl3,<tl4,<tl5,<tl10,<tl11,<tl12
labhi   byte >tl1,>tl2,>tl3,>tl4,>tl5,>tl10,>tl11,>tl12

; prcol  colour a: its number and its name ("1 white")
;   uses: a, x, y, t0-t3, p3
prcol   sta pcn
        ldx #0
        jsr prdec16
        lda #' '
        jsr chrout
        ldx pcn
        lda cnlo,x
        ldy cnhi,x
        tax
        jmp print

; none  "-"
none    lda #'-'
        jmp chrout

; prfile  "d:name" for drive a, the length and name at x/y
prfile  stx p1
        sty p1+1
        ldx #0
        jsr prdec16
        lda #':'
        jsr chrout
        ldy #0
        lda (p1),y
        sta t0
@c      cpy t0
        bcs @x
        iny
        lda (p1),y
        jsr chrout
        jmp @c
@x      rts

; ptitle  the screen cleared, line a's name (10: write it, 11: quit,
; 12: @ disk) in a light blue bar on the top row, the cursor under it
ptitle  pha
        ldx #<tx_ttl
        ldy #>tx_ttl
        jsr print
        pla
        cmp #10
        bcs @w
        pha
        ora #'0'
        jsr chrout
        lda #' '
        jsr chrout
        pla
        tax
        bne @l                  ; (always)
@w      sec                     ; (10-12: their names after the five)
        sbc #4
        tax
@l      lda lablo-1,x
        ldy labhi-1,x
        tax
        jsr print
@sp     sec                     ; the bar to column 38
        jsr plot
        cpy #39
        bcs @e
        lda #' '
        jsr chrout
        jmp @sp
@e      ldx #<tx_ttle
        ldy #>tx_ttle
        jmp print

; anykey  "press any key" under what was said; a key
anykey  sec                     ; (on a new line, unless at its start)
        jsr plot
        tya
        beq @p
        lda #13
        jsr chrout
@p      ldx #<tx_anyk
        ldy #>tx_anyk
        jsr print
@k      jsr getin
        beq @k
        rts

say     jsr print
        sec
        rts

; ------------------------------------------------------------
; the lines' actions (c set: something said)
; ------------------------------------------------------------
; ascreen  1: a .pet file read, or (drive 0) a new blank screen; return
; alone at the name keeps the one there is
ascreen jsr unsaved
        bcc @a
        clc                     ; (no: the menu again)
        rts
@a      lda prgdev
        ldx #<q_drive
        ldy #>q_drive
        jsr asknum
        bcs @a
        cmp #0                  ; 0: a new screen
        bne @dr
        jsr newscr
        clc
        rts
@dr     cmp #8
        bcc @a
        cmp #31
        bcs @a
        sta sdev
        sta ddev                ; ($ and @: disk.asm, on this drive)
@name   ldx #<q_file
        ldy #>q_file
        jsr print
        lda #16
        jsr readline
        jsr diskkey             ; ($: its files, @: its commands)
        bcs @name
        lda inlen
        beq @keep               ; return alone: kept
        sta t1
        tax
@c      dex
        lda inbuf,x
        sta inbuf+20,x          ; (the name, until it is read)
        txa
        bne @c
        jmp rdpet
@keep   clc
        rts

; newscr  a new screen: spaces in the pen's colour, no file
;   uses: a, x
newscr  ldx #0
@f      lda #' '
        sta pcod,x
        sta pcod+$100,x
        sta pcod+$200,x
        sta pcod+$2e8,x
        lda pen
        sta pcol,x
        sta pcol+$100,x
        sta pcol+$200,x
        sta pcol+$2e8,x
        inx
        bne @f
        stx prglen              ; (no file)
        stx dirty
        stx crow
        stx ccol
        rts

; acolours  2: the border's colour and the background's
acolours
@b      lda border
        ldx #<q_bord
        ldy #>q_bord
        jsr asknum
        bcs @b
        cmp #16
        bcs @b
        cmp border
        beq @g
        sta border
        lda #1
        sta dirty
@g      lda bg
        ldx #<q_bgnd
        ldy #>q_bgnd
        jsr asknum
        bcs @g
        cmp #16
        bcs @g
        cmp bg
        beq @x
        sta bg
        lda #1
        sta dirty
@x      clc
        rts

; apen  3: the pen's colour, the colours listed
apen    ldx #<tx_pens
        ldy #>tx_pens
        jsr print
        ldx #0                  ; 0-15, two a row, each in its colour (on
@l      stx pli                 ; black: dark blue and black in grey)
        txa
        and #1
        beq @c
        lda #20                 ; (the second column)
        sta t3
        sec
        jsr plot
        ldy t3
        clc
        jsr plot
@c      ldx pli
        lda ckeys,x
        cpx #0
        beq @g
        cpx #6
        bne @p
@g      lda #155                ; (grey for black and blue)
@p      jsr chrout
        lda pli
        cmp #10
        bcs @nn
        lda #' '
        jsr chrout
@nn     lda pli
        jsr prcol
        lda pli
        and #1
        beq @r
        lda #13
        jsr chrout
@r      ldx pli
        inx
        cpx #16
        bcc @l
        lda #5
        jsr chrout
@a      lda pen
        ldx #<q_pen
        ldy #>q_pen
        jsr asknum
        bcs @a
        cmp #16
        bcs @a
        sta pen
        clc
        rts

; acase  4: the case, the C64's upper case and graphics or lower and
; upper (with a font of its own: the file says it, for PETSCII-LM)
acase   lda case
        eor #1                  ; (1 upper: the first choice)
        ldx #<q_case
        ldy #>q_case
        jsr ask12
        eor #1
        cmp case
        beq @x
        sta case
        lda #1
        sta dirty
@x      clc
        rts

; afont  5: a font of its own: the drive and the .64c's name, read;
; return alone keeps the one there is, - the C64's own again
afont   lda fdev
        ldx #<q_fdrive
        ldy #>q_fdrive
        jsr asknum
        bcs afont
        cmp #8
        bcc afont
        cmp #31
        bcs afont
        sta sdev
        sta ddev                ; ($ and @: disk.asm, on this drive)
@fn     ldx #<q_ffile
        ldy #>q_ffile
        jsr print
        lda #16
        jsr readline
        jsr diskkey             ; ($: its files, @: its commands)
        bcs @fn
        lda inlen
        beq @keep               ; return alone: kept
        cmp #1
        bne @nm
        lda inbuf
        cmp #'-'
        bne @nm
        lda #0                  ; -: the C64's own
        sta fok
@keep   clc
        rts
@nm     sta fnlen
        tax
@c      dex
        lda inbuf,x
        sta fname,x
        txa
        bne @c
        lda #0                  ; (none until read)
        sta fok
        lda sdev                ; (the file's drive)
        sta fdev
        jmp rdfont

; asknum  the question at x/y, its default a in brackets: a number in a,
; c set if not one (the default on an empty line)
asknum  sta t5
        jsr print
        lda t5
        ldx #0
        jsr prdec16
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #3
        jsr readline
        jsr innum
        bcc @x
        bne @x
        lda t5
        clc
@x      rts

; ask12  a choice of two, the question at x/y (it lists them as 1 and
; 2), the default a (0 or 1): a = 0 or 1 (the default if neither), z set
; for 0
ask12   sta t4                  ; (t4: readline takes t6)
        clc
        adc #1
        jsr asknum
        bcs @d
        sec
        sbc #1
        cmp #2
        bcc @x
@d      lda t4
@x      cmp #0
        rts

; ------------------------------------------------------------
; rdpet  the .pet file (its name t1 bytes at inbuf+20): its header
; checked, the codes and colours read into the screen, its border,
; background and case taken; the file the screen's then
;   out:  c set if it can't be used (said; the screen there is kept)
; ------------------------------------------------------------
rdpet   ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        lda #2
        ldx sdev
        ldy #2
        jsr setlfs
        lda t1
        ldx #<(inbuf+20)
        ldy #>(inbuf+20)
        jsr setnam
        jsr open
        lda sdev
        jsr dstat
        bcc @o
        jsr prstat
        jmp @bad
@o      ldx #2
        jsr chkin
        ldy #0                  ; the header
@h      jsr chrin
        sta hdr,y
        jsr readst
        bne @short
        iny
        cpy #5
        bcc @h
        lda hdr                 ; 40 x 25, upper or lower case
        cmp #40
        bne @size
        lda hdr+1
        cmp #25
        bne @size
        lda hdr+4
        cmp #2
        bcs @case
        lda #<rdbuf             ; the codes and the colours, read whole
        ldx #>rdbuf             ; before they are taken (an error keeps
        jsr rd1000              ; the screen there is)
        bcs @short
        lda #<(rdbuf+1000)
        ldx #>(rdbuf+1000)
        jsr rd1000
        bcs @short
        and #$40
        beq @size               ; more after it
        jsr clrchn
        lda #2
        jsr close
        jsr petin               ; the screen: what was read
        lda hdr+2               ; its border, background and case
        and #15
        sta border
        lda hdr+3
        and #15
        sta bg
        lda hdr+4
        sta case
        lda sdev                ; the file the screen's
        sta prgdev
        ldx t1
        stx prglen
@nm     dex
        lda inbuf+20,x
        sta prgname,x
        txa
        bne @nm
        stx dirty               ; (0)
        stx crow
        stx ccol
        clc
        rts
@short  ldx #<tx_short
        ldy #>tx_short
        bne @say
@size   ldx #<tx_size
        ldy #>tx_size
        bne @say
@case   ldx #<tx_case
        ldy #>tx_case
@say    stx p2
        sty p2+1
        jsr clrchn
        lda #2
        jsr close
        ldx p2
        ldy p2+1
        jsr print
@bad    sec
        rts

; petin  the codes and colours read (rdbuf) the screen's: the colours'
; low four bits, as tools/petscii.py keeps them
;   uses: a, x
petin        ldx #0
@m      lda rdbuf,x
        sta pcod,x
        lda rdbuf+$100,x
        sta pcod+$100,x
        lda rdbuf+$200,x
        sta pcod+$200,x
        lda rdbuf+$2e8,x
        sta pcod+$2e8,x
        lda rdbuf+1000,x
        and #15
        sta pcol,x
        lda rdbuf+1000+$100,x
        and #15
        sta pcol+$100,x
        lda rdbuf+1000+$200,x
        and #15
        sta pcol+$200,x
        lda rdbuf+1000+$2e8,x
        and #15
        sta pcol+$2e8,x
        inx
        bne @m
        rts

; rd1000  1,000 bytes from the open file to a/x (lo/hi)
;   out:  c set if the file ended first; a = the last byte's status
;   uses: a, x, y, p1, cnt
rd1000  sta p1
        stx p1+1
        lda #<1000
        sta cnt
        lda #>1000
        sta cnt+1
        ldy #0
@r      jsr readst
        and #$40
        bne @end                ; ended before this byte
        jsr chrin
        sta (p1),y
        inc p1
        bne @n
        inc p1+1
@n      lda cnt
        bne @l
        dec cnt+1
@l      dec cnt
        lda cnt
        ora cnt+1
        bne @r
        jsr readst
        clc
        rts
@end    sec
        rts

; ------------------------------------------------------------
; rdfont  the font file: its load address (not used), then up to 2,048
; bytes into fontbuf, the rest blank (as PETSCII-LM reads a .64c); 8
; bytes at least
;   out:  c set if it can't be used (said); fok 1 if it can
;   uses: a, x, y, p1, p2
; ------------------------------------------------------------
rdfont  ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        lda #2
        ldx fdev
        ldy #2
        jsr setlfs
        lda fnlen
        ldx #<fname
        ldy #>fname
        jsr setnam
        jsr open
        lda fdev
        jsr dstat
        bcc @o
        jsr prstat
        sec
        rts
@o      ldx #2
        jsr chkin
        lda #<fontbuf
        sta p1
        lda #>fontbuf
        sta p1+1
        ldx #2                  ; the load address
@a      jsr readst
        and #$40
        bne @end
        jsr chrin
        dex
        bne @a
@r      jsr readst              ; the characters, to 2,048 bytes
        and #$40
        bne @end
        jsr chrin
        ldy #0
        sta (p1),y
        inc p1
        bne @r1
        inc p1+1
@r1     lda p1+1
        cmp #>fontend
        bcc @r
@end    jsr clrchn
        lda #2
        jsr close
        lda p1+1                ; 8 bytes at least
        cmp #>fontbuf
        bne @ok
        lda p1
        cmp #8
        bcs @ok
        ldx #<tx_fshort
        ldy #>tx_fshort
        jmp say
@ok     ldy #0                  ; the rest blank
        tya
@z      ldx p1+1
        cpx #>fontend
        bcs @d
        sta (p1),y
        inc p1
        bne @z
        inc p1+1
        bne @z
@d      lda #1
        sta fok
        clc
        rts

; ------------------------------------------------------------
; awrite  w: the drive and the name (the screen's, or screen.pet), and
; the .pet written: the header, the codes, the colours
; ------------------------------------------------------------
awrite  lda prgdev
        ldx #<q_wdrive
        ldy #>q_wdrive
        jsr asknum
        bcs awrite
        cmp #8
        bcc awrite
        cmp #31
        bcs awrite
        ldx prgdev              ; (the screen's, back if it isn't written)
        stx odev
        sta prgdev
        lda prglen              ; a new screen: screen.pet
        bne @nm
        ldx #5
@s      lda tx_scr,x
        sta prgname,x
        dex
        bpl @s
        lda #6
        sta prglen
        jsr wname0
        lda #0                  ; (still none until written)
        sta prglen
        beq @cr
@nm     jsr wname0
@cr     jsr wcreate
        bcc @go
@no     lda odev                ; (not written: the screen's drive)
        sta prgdev
        sec
        rts
@go     ldx #3
        jsr chkout
        lda #40                 ; the header
        jsr chrout
        lda #25
        jsr chrout
        lda border
        jsr chrout
        lda bg
        jsr chrout
        lda case
        jsr chrout
        lda #<1000              ; the codes, the colours
        sta cnt
        ldy #>1000
        lda #<pcod
        ldx #>pcod
        jsr wrblk
        lda #<1000
        sta cnt
        ldy #>1000
        lda #<pcol
        ldx #>pcol
        jsr wrblk
        jsr wclose
        bcs @no
        ldx outlen              ; the file the screen's now
        stx prglen
@n      dex
        lda outname,x
        sta prgname,x
        txa
        bne @n
        stx dirty               ; (0)
        sec                     ; ("written: ...": a key)
        rts

; wname0  wfile's wname with this tool's question
wname0  ldx #<q_out
        ldy #>q_out
        jmp wname

; ------------------------------------------------------------
; edit  the screen on the C64's, as it will show, and edited there
; (the keys: the header's list); f7 or run/stop back to the menu
; ------------------------------------------------------------
edit    jsr drawscr
@loop   jsr curat               ; the cursor's cell, kept
@w      jsr getin
        bne @key
        lda $a2                 ; the clock: a blink every 16 frames
        and #$10
        cmp cph
        beq @w
        sta cph
        jsr curblink
        jmp @w
@key    pha
        jsr curoff
        pla
        ldx #ekeyn-1            ; a key of the editor's?
@f      cmp ekeys,x
        beq @go
        dex
        bpl @f
        ldx #15                 ; a colour key: the pen's colour
@cf     cmp ckeys,x
        beq @col
        dex
        bpl @cf
        cmp #$20                ; a character: $20-$7f, $a0-$ff
        bcc @loop
        cmp #$80
        bcc @ch
        cmp #$a0
        bcc @loop
@ch     jsr p2s
        ora rvs
        jsr putch
        jsr right
        jmp @loop
@col    stx pen
        jmp @loop
@go     txa
        asl a
        tax
        lda eacts,x
        sta @j+1
        lda eacts+1,x
        sta @j+2
@j      jsr @j                  ; (patched: the key's action)
        bcc @loop
        jsr scrtake             ; (c set: back to the menu)
        rts

; the editor's keys and what each does (c set: back to the menu)
ekeys   byte $91,$11,$9d,$1d,$13,$0d,$8d,$14,$12,$92,$85,$86,$87,$89,$8a,$8b,$88,$03
ekeyn   = 18
eacts   word up,down,left,right,home,ret,ret,del,rvson,rvsoff,chars,paint,takec
        word bordup,bgup,caset,done,done

up      lda crow
        beq ok
        dec crow
ok      clc
        rts
down    lda crow
        cmp #24
        bcs ok
        inc crow
        clc
        rts
left    lda ccol                ; (the row before's end at column 0)
        bne @l
        lda crow
        beq ok
        dec crow
        lda #40
        sta ccol
@l      dec ccol
        clc
        rts
right   inc ccol                ; (the next row's start at column 39; the
        lda ccol                ; last cell stays)
        cmp #40
        bcc ok
        lda #0
        sta ccol
        lda crow
        cmp #24
        bcc @d
        lda #39
        sta ccol
        clc
        rts
@d      inc crow
        clc
        rts
home    lda #0
        sta crow
        sta ccol
        clc
        rts
ret     lda #0
        sta ccol
        jmp down
del     lda crow                ; the one before: a space (its colour kept)
        ora ccol
        beq ok
        jsr left
        jsr curat
        lda #' '
        ldy #0
        sta (sp),y
        lda #1
        sta dirty
        clc
        rts
rvson   lda #$80
        sta rvs
        clc
        rts
rvsoff  lda #0
        sta rvs
        clc
        rts
paint   jsr curat               ; f3: the pen's colour on the one under it
        lda pen
        ldy #0
        sta (cp),y
        lda #1
        sta dirty
        jmp right
takec   lda ccl                 ; f5: its colour the pen's
        sta pen
        clc
        rts
bordup  inc border              ; f2: the border's colour on one
        lda border
        and #15
        sta border
        sta $d020
        lda #1
        sta dirty
        clc
        rts
bgup    inc bg                  ; f4: the background's
        lda bg
        and #15
        sta bg
        sta $d021
        lda #1
        sta dirty
        clc
        rts
caset   lda fok                 ; f6: the case (the C64's own font)
        beq @c
        clc
        rts
@c
        lda case
        eor #1
        sta case
        lda #1
        sta dirty
        jsr setvic
        clc
        rts
done    sec
        rts

; putch  code a at the cursor, in the pen's colour
;   uses: a, y
putch   pha
        jsr curat
        pla
        ldy #0
        sta (sp),y
        lda pen
        sta (cp),y
        lda #1
        sta dirty
        rts

; curat  sp, cp the cursor's place; the character and colour there kept
; (cch, ccl), the cursor not shown
;   uses: a, x, y
curat   ldx crow
        lda rowlo,x
        clc
        adc ccol
        sta sp
        sta cp
        lda rowhi,x
        adc #0
        sta sp+1
        clc
        adc #$d8-$04
        sta cp+1
        ldy #0
        lda (sp),y
        sta cch
        lda (cp),y
        and #15
        sta ccl
        sty cvis
        rts

; curblink  the cursor shown (the character reversed, in the pen's
; colour) or the cell as it is, by turns
curblink
        ldy #0
        lda cvis
        bne curoff
        lda cch
        eor #$80
        sta (sp),y
        lda pen
        sta (cp),y
        lda #1
        sta cvis
        rts
; curoff  the cell as it is (if the cursor showed)
curoff  ldy #0
        lda cvis
        beq @x
        lda cch
        sta (sp),y
        lda ccl
        sta (cp),y
        sty cvis
@x      rts

; ------------------------------------------------------------
; chars  f1: all 256 characters, 16 to a row (rows 4-19, columns
; 12-27), in the font and the pen's colour; the cursor keys choose
; (the one chosen blinks), return puts it at the editor's cursor, f1,
; f7 or run/stop goes back without
; ------------------------------------------------------------
chars   jsr scrtake             ; (the screen kept: drawn again after)
        ldx #0                  ; nothing but the characters: the rest in
@cl     lda #' '                ; the background's colour
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e8,x
        lda bg
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne @cl
        lda pen                 ; (their colour: the pen's, or one that
        cmp bg                  ; shows when that is the background's)
        bne @pc
        ldx bg
        lda contr,x
@pc     sta t3
        ldx #0                  ; the grid
@g      stx t2
        txa
        jsr gridat
        lda t2
        sta (sp),y
        lda t3
        sta (cp),y
        ldx t2
        inx
        bne @g
@k      lda pick                ; the chosen one, blinking
        jsr gridat
        lda $a2                 ; (by turns its colour and the
        and #$10                ; background's)
        bne @on
        lda bg
        jmp @sh
@on     lda t3
@sh     sta (cp),y
        jsr getin
        beq @k
        pha
        lda pick                ; (shown again)
        jsr gridat
        lda t3
        sta (cp),y
        pla
        cmp #$1d
        bne @l
        inc pick
        jmp @k
@l      cmp #$9d
        bne @u
        dec pick
        jmp @k
@u      cmp #$91
        bne @d
        lda pick
        sec
        sbc #16
        sta pick
        jmp @k
@d      cmp #$11
        bne @h
        lda pick
        clc
        adc #16
        sta pick
        jmp @k
@h      cmp #$13
        bne @r
        lda #0
        sta pick
        jmp @k
@r      cmp #13
        bne @x
        jsr drawscr             ; return: it goes in at the cursor
        lda pick
        jsr putch
        jmp right
@x      cmp #$85                ; f1, f7, run/stop: back
        beq @b
        cmp #$88
        beq @b
        cmp #$03
        beq @b
        jmp @k
@b      jsr drawscr
        clc
        rts

; gridat  sp, cp the grid's cell for character a; y 0
;   uses: a, x, y
gridat  pha
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #4
        tax
        pla
        and #15
        clc
        adc #12
        adc rowlo,x
        sta sp
        sta cp
        lda rowhi,x
        adc #0
        sta sp+1
        clc
        adc #$d8-$04
        sta cp+1
        ldy #0
        rts

; ------------------------------------------------------------
; drawscr  the screen on the C64's: codes, colours, border, background,
; case or font
; scrtake  the C64's screen back into it (the colours' low four bits)
; setvic   $d018: the font of its own, or the C64's in the screen's case
; ------------------------------------------------------------
drawscr ldx #0
@c      lda pcod,x
        sta $0400,x
        lda pcod+$100,x
        sta $0500,x
        lda pcod+$200,x
        sta $0600,x
        lda pcod+$2e8,x
        sta $06e8,x
        lda pcol,x
        sta $d800,x
        lda pcol+$100,x
        sta $d900,x
        lda pcol+$200,x
        sta $da00,x
        lda pcol+$2e8,x
        sta $dae8,x
        inx
        bne @c
        lda border
        sta $d020
        lda bg
        sta $d021
setvic  lda #$1e                ; a font of its own: at $3800
        ldx fok
        bne @u
        lda #$15                ; the rom font: upper case, or lower ($17)
        ldx case
        bne @u
        lda #$17
@u      sta $d018
        rts

scrtake ldx #0
@c      lda $0400,x
        sta pcod,x
        lda $0500,x
        sta pcod+$100,x
        lda $0600,x
        sta pcod+$200,x
        lda $06e8,x
        sta pcod+$2e8,x
        lda $d800,x
        and #15
        sta pcol,x
        lda $d900,x
        and #15
        sta pcol+$100,x
        lda $da00,x
        and #15
        sta pcol+$200,x
        lda $dae8,x
        and #15
        sta pcol+$2e8,x
        inx
        bne @c
        rts

; each row's start on the screen
rowlo   byte <$0400,<$0428,<$0450,<$0478,<$04a0,<$04c8,<$04f0,<$0518,<$0540,<$0568
        byte <$0590,<$05b8,<$05e0,<$0608,<$0630,<$0658,<$0680,<$06a8,<$06d0,<$06f8
        byte <$0720,<$0748,<$0770,<$0798,<$07c0
rowhi   byte >$0400,>$0428,>$0450,>$0478,>$04a0,>$04c8,>$04f0,>$0518,>$0540,>$0568
        byte >$0590,>$05b8,>$05e0,>$0608,>$0630,>$0658,>$0680,>$06a8,>$06d0,>$06f8
        byte >$0720,>$0748,>$0770,>$0798,>$07c0

; the colour keys' codes (getin), colour 0 to 15
ckeys   byte $90,$05,$1c,$9f,$9c,$1e,$1f,$9e,$81,$95,$96,$97,$98,$99,$9a,$9b
; a colour that shows on each background: white on the dark ones
contr   byte 1,0,1,0,1,0,1,0,1,1,0,1,0,0,0,0

; p2s  a typed (petscii) character as a screen code
p2s     cmp #$40
        bcc @x                  ; $20-$3f: the same
        cmp #$60
        bcc @m40                ; $40-$5f: less $40
        cmp #$80
        bcc @m20                ; $60-$7f: less $20
        cmp #$c0
        bcc @m40                ; $a0-$bf: less $40
        cmp #$ff
        beq @pi
        and #$7f                ; $c0-$fe: less $80
@x      rts
@m40    sec
        sbc #$40
        rts
@m20    sec
        sbc #$20
        rts
@pi     lda #$5e
        rts

; ---- texts ----
tl1     text "screen    ",0
tl2     text "colours   ",0
tl3     text "pen       ",0
tl4     text "case      ",0
tl5     text "font      ",0
tl10    text "write the screen",0
tl11    text "quit",0
tl12    text "@ disk",0
cn0     text "black",0
cn1     text "white",0
cn2     text "red",0
cn3     text "cyan",0
cn4     text "purple",0
cn5     text "green",0
cn6     text "blue",0
cn7     text "yellow",0
cn8     text "orange",0
cn9     text "brown",0
cn10    text "light red",0
cn11    text "dark grey",0
cn12    text "grey",0
cn13    text "light green",0
cn14    text "light blue",0
cn15    text "light grey",0
cnlo    byte <cn0,<cn1,<cn2,<cn3,<cn4,<cn5,<cn6,<cn7,<cn8,<cn9,<cn10,<cn11,<cn12,<cn13,<cn14,<cn15
cnhi    byte >cn0,>cn1,>cn2,>cn3,>cn4,>cn5,>cn6,>cn7,>cn8,>cn9,>cn10,>cn11,>cn12,>cn13,>cn14,>cn15
tx_bye  text "bye.",13,0
tx_new  text "new",0
tx_chgd text " (changed)",0
tx_star text " *",0
tx_bord text "border ",0
tx_bgnd text ", background ",0
tx_upper text "upper case and graphics",0
tx_lower text "lower and upper case",0
tx_fc64 text "the c64's own",0
tx_mkeys text 155,"1-5: change  w: write  @: disk  q: quit",13,"return: edit the screen",13,13
        text "in the editor:",13
        text " crsr keys, home, return: move",13
        text " keys: type, in the pen's colour",13
        text " ctrl or c= with 1-8: the pen's colour",13
        text " ctrl 9, ctrl 0: reverse on, off",13
        text " del: a space over the one before",13
        text " f1: all 256 characters, to choose",13
        text " f3: colour the one under the cursor",13
        text " f5: the pen takes its colour",13
        text " f2, f4, f6: border, background, case",13
        text " f7 or run/stop: back to this menu",30,0
tx_ttl  text 147,154,18," ",0   ; cleared; light blue, reverse
tx_ttle text 146,30,13,0        ; (off, green, the next row)
tx_anyk text 155,"press any key",30,0
q_lose  text "the screen isn't written: go on",13,"anyway (y/n)? ",0
q_drive text "drive with the .pet file (0: a new,",13,"blank screen) [",0
q_file  text "its file name ($: files, @: disk,",13,"return: keep it)? ",0
q_bord  text "its border colour 0-15 [",0
q_bgnd  text "its background colour 0-15 [",0
tx_pens text "the colour typed in (ctrl or c= with",13,"1-8 in the editor):",13,0
q_pen   text "the pen's colour 0-15 [",0
q_case  text "the case:",13,"  1 upper case and graphics",13,"  2 lower and upper case",13
        text "(a font of its own: kept in the file,",13,"for petscii-lm)",13,"which [",0
q_fdrive text "drive with the font (.64c) [",0
q_ffile text "its file name ($: files, @: disk,",13,"return: keep it, -: the c64's own)? ",0
tx_fshort text "too short for a font (8 bytes",13,"a character after its address)",13,0
q_ddrive text "drive [",0
q_wdrive text "drive to write it to [",0
q_out   text "its name [",0
tx_scr  text "screen"
tx_ask  text "]? ",0
tx_reading text "reading it...",13,0
tx_short text "the file ended early: not a .pet file",13,0
tx_size text "not a 40 x 25 .pet file",13,0
tx_case text "its case is neither upper nor lower:",13,"not a .pet file",13,0
wold    text ".pet"                 ; (wfile.asm: the name's ending, and the new one)
wnew    byte 4
        text ".pet"

        incasm "peted.asm"      ; (the top lines: tools/c64build.py)
rdbuf                           ; a .pet read here first (2,000 bytes)
bssend  = rdbuf+2000            ; (the end: the font at $3800 after it)
