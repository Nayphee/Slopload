; ------------------------------------------------------------
; petsciilm.asm  -  PETSCII-LM: a PETSCII screen (a Petmate .pet file)
; made into a loader module (.lm) for SlopLoad 64: PETSCII-Load with
; that screen, shown while the program loads
;
; LOAD"PETSCII-LM",8 and RUN. A menu of the settings, each on a line of
; its own and changed by its number at any time: the .pet file (read and
; shown), a scrolling message (in an editor of its own), its row (the
; rows that can take it listed) and speed, its row's colours (the
; screen's, or in an editor of their own: they stay put while the
; message moves through them), a block counter (its place) and a font
; of its own (a .64c file, as Petmate imports one). S shows
; the module's screen as it will be; return asks for the module's name
; (the .pet's, ending .lm) and writes it; the settings stay for the
; next (another screen is one change away); q quits. The same file
; tools/petscii.py makes on a PC with the same settings.
;
; A .pet file: width (40), height (25), border, background, the case
; (0 lower, 1 upper), then 1,000 screen codes and 1,000 colours.
;
; The module is PETSCII-Load's (petlm.asm, made by c64build.py from
; build/modules/petscii.lm) with the screen read into it: the settings
; and the colours in its main part, the message after it, the codes in
; its second part. Writing it, the rows next to a scrolling message are
; cleared where they aren't empty (its split can land a few lines late,
; and what is on them would shake) and said, and the row's edited
; colours put in; both are put back after, so any line can change and
; the module be written again. The counter can't be on the message's
; rows. The same as tools/petscii.py does.
;
; A font of its own: a .64c file's load address, then up to 2,048 bytes
; (8 a character; the rest blank) at fontbuf, where the VIC shows it
; for S and the screen's preview ($d018 $1e). Written, it is cut to the
; characters the module shows (mkfont), numbered from 0, a third part at
; $b800 (128 or fewer) or $b000; the codes and the message are written
; through fmap, the new numbers. The editors keep the C64's own set.
;
; Memory: the program $0801 to $37ff, the font $3800-$3fff, its tables
; $4000-$41ff; zero page $20-$3b (BASIC's: it leaves through BASIC's
; warm start).
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
msglen = $36                    ; the message's length (0: none)
srow = $37                      ; its row
place = $38                     ; the counter's place (2), row x 40 + column
crow = $3a                      ; the counter's row ($ff: none)
ccol = $3b                      ; ... its column

; ---- the font of its own ----
fontbuf = $3800                 ; as read: 256 characters of 8 bytes
fontend = $4000                 ; (its end)
fusd = $4000                    ; 1: a character the module shows (256)
fmap = $4100                    ; each character's code in the module (256)

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
prgdev  byte 8                  ; the drive
prglen  byte 0                  ; the .pet's name
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
paddr   word 0                  ; (unused here)
eof     byte 0
tapdev  byte 0                  ; (unused here)
tapfnl  byte 0
tapfname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tapn    byte 0,0,0

; ---- this program's ----
hdr     byte 0,0,0,0,0          ; the .pet's first bytes
pok     byte 0                  ; a .pet read (1)
speed   byte 2                  ; the message's pixels a frame
msgn    byte 0                  ; the message in the editor: its length
cur     byte 0                  ; the editor's cursor, 0-msgn
rdef    byte 24                 ; (rowlist uses srow: the row, kept)
rcnt    byte 0                  ; how many rows need nothing cleared
ncl     byte 0                  ; rows next to the message to clear
rcl     byte 0                  ; ... the one being looked at
clrnow  byte 0                  ; nextrows: 1 clears them, 0 says so
scoled  byte 0                  ; the row's colours: 0 the screen's, 1 scol
ccur    byte 1                  ; the colour editor's cursor: column 1-39
irow    byte 0                  ; the menu: the line's row
usedc   byte 5                  ; ... its value's colour
fok     byte 0                  ; a font of its own read (1)
fdev    byte 8                  ; its drive
fnlen   byte 0                  ; its name
fname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fk      word 0                  ; mkfont: how many characters it shows
fbase   byte 0                  ; ... the font part's page: $b8 or $b0
scol    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; the row's colours as
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; edited (columns 1-39)
csav    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; the screen's, kept
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; while writing
nsav    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; the rows next to the
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; message, kept while
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; writing (above, then
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; below)

; ------------------------------------------------------------
; main
; ------------------------------------------------------------
main    lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        lda #24                 ; the settings at the start (zero page)
        sta srow
        lda #$ff
        sta crow
        lda #0
        sta ccol
        sta msglen
        lda $ba                 ; the drive it was loaded from
        cmp #8
        bcc menu
        sta prgdev
        sta fdev

; ------------------------------------------------------------
; menu  every setting on a line of its own (1-7), changed by its number
; at any time: its name in reverse on row ttlrow and its questions
; under it; s shows the module's screen, return writes the module (the
; settings stay), q quits. An action returns c set when it said
; something: "press any key" first, then the menu again.
; ------------------------------------------------------------
ttlrow  = 13
menu    ldx #$ff
        txs
        jsr clrchn
        lda #2
        jsr close
        jsr mdraw
@k      jsr getin
        beq @k
        cmp #13
        bne @q
        lda #9                  ; return: write the module
        jsr ptitle
        jsr awrite
        jmp @any
@q      cmp #'@'                ; @: the disk, its files and commands
        bne @qq
        lda #11
        jsr ptitle
        jsr adisk
        jmp @any
@qq     cmp #'q'
        bne @s
        jsr cmdclose
        jsr look
        ldx #<tx_bye
        ldy #>tx_bye
        jmp quit
@s      cmp #'s'
        bne @n
        lda #10                 ; s: show it
        jsr ptitle
        jsr ashow
        bcc menu
        jmp @any
@n      cmp #'1'
        bcc @k
        cmp #'9'
        bcs @k
        and #15                 ; 1-8: its line
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
acts    word ascreen,amsg,arow,aspeed,acols,acount,afont,achain

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
@x      sec                     ; (said: a key, then the menu)
        rts

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

quit    jsr print
        lda #$37
        sta $01
        jsr $ff8a               ; the KERNAL's vectors again (RESTORE: not
        jmp ($a002)             ; this program's rti); BASIC's warm start
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
; mdraw  the screen cleared, the menu: the title (rows 0-1), lines 1-7
; (rows 3-9), the keys (rows 10-11)
; ------------------------------------------------------------
mmsg    = $0400+4*40+12         ; the message's start on line 2
mmsgc   = $d800+4*40+12
mdraw   jsr look
        ldx #<tx_head
        ldy #>tx_head
        jsr print
        lda #1                  ; 1 screen
        ldx #3
        jsr item
        lda pok
        beq @s0
        lda prgdev
        ldx #<prglen
        ldy #>prglen
        jsr prfile
        jmp @s1
@s0     jsr none
@s1     lda #2                  ; 2 message: its start, as it shows
        jsr item0
        lda msgn
        bne @m
        jsr none
        jmp @m2
@m      ldx #0
@ml     lda msgbuf,x
        sta mmsg,x
        lda #1
        sta mmsgc,x
        inx
        cpx msgn
        bcs @m2
        cpx #28
        bcc @ml
@m2     jsr used                ; 3 row (grey with no message)
        lda #3
        jsr item0
        lda srow
        ldx #0
        jsr prdec16
        jsr used                ; 4 speed
        lda #4
        jsr item0
        lda speed
        ldx #0
        jsr prdec16
        ldx #<tx_pxf
        ldy #>tx_pxf
        jsr print
        jsr used                ; 5 colours
        lda #5
        jsr item0
        ldx #<tx_asscr
        ldy #>tx_asscr
        lda scoled
        beq @c
        ldx #<tx_edited
        ldy #>tx_edited
@c      jsr print
        lda #6                  ; 6 counter
        jsr item0
        lda crow
        bpl @cn
        jsr none
        jmp @kk
@cn     ldx #<tx_crow
        ldy #>tx_crow
        jsr print
        lda crow
        ldx #0
        jsr prdec16
        ldx #<tx_ccol
        ldy #>tx_ccol
        jsr print
        lda ccol
        ldx #0
        jsr prdec16
@kk     lda #7                  ; 7 font: the C64's, or the file's
        jsr item0
        lda fok
        bne @fo
        ldx #<tx_fc64
        ldy #>tx_fc64
        jsr print
        jmp @k2
@fo     lda fdev
        ldx #<fnlen
        ldy #>fnlen
        jsr prfile
@k2     lda #8                  ; 8 a chain's first (at $a000), or not
        jsr item0
        ldx #<tx_chno
        ldy #>tx_chno
        lda chmask
        beq @c8
        ldx #<tx_chyes
        ldy #>tx_chyes
@c8     jsr print
        ldx #11                 ; the keys
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
lablo   byte <tl1,<tl2,<tl3,<tl4,<tl5,<tl6,<tl7,<tl8,<tl9,<tl10,<tl11
labhi   byte >tl1,>tl2,>tl3,>tl4,>tl5,>tl6,>tl7,>tl8,>tl9,>tl10,>tl11

; used  the next value grey with no message (it doesn't count)
used    lda #5
        ldx msgn
        bne @x
        lda #151
@x      sta usedc
        rts

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

; ptitle  line a's name (8: write it, 9: show it) in reverse on row
; ttlrow, the cursor under it
ptitle  pha
        ldx #ttlrow
        ldy #0
        clc
        jsr plot
        ldx #<tx_ttl
        ldy #>tx_ttl
        jsr print
        pla
        cmp #9
        bcs @w
        pha
        ora #'0'
        jsr chrout
        lda #' '
        jsr chrout
        pla
@w      tax
        lda lablo-1,x
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

; needscr, needmsg  a screen read, a message typed: c set if not (said)
needscr lda pok
        bne ok
        ldx #<tx_needs
        ldy #>tx_needs
        jmp say
needmsg lda msgn
        bne ok
        ldx #<tx_needm
        ldy #>tx_needm
say     jsr print
        sec
        rts
ok      clc
        rts

; ------------------------------------------------------------
; the lines' actions (c set: something said)
; ------------------------------------------------------------
; ascreen  1: the .pet file, read and shown (return alone keeps the one
; there is)
ascreen jsr ask
        bcs @x
        lda inlen
        beq @x                  ; (kept: c clear)
        lda #1
        sta pok
        jsr showit
        clc
@x      rts

; amsg  2: the message, in its editor
amsg    jsr msgedit
        clc
        rts

; afont  7: a font of its own: the drive and the .64c's name, read (and
; the screen shown in it); return alone keeps the one there is, - the
; C64's own again
afont   lda fdev
        ldx #<q_fdrive
        ldy #>q_fdrive
        jsr asknum
        bcs afont
        cmp #8
        bcc afont
        cmp #31
        bcs afont
        sta fdev
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
        jsr rdfont
        bcs @x
        lda pok
        beq @ns
        jsr showit              ; the screen in it
        clc
        rts
@ns     ldx #<tx_fread
        ldy #>tx_fread
        jmp say
@x      rts

; arow  3: the message's row, the rows that need nothing cleared listed;
; the rows next to it that will be cleared for it said
arow    jsr needmsg
        bcs @x
        jsr needscr
        bcs @x
        lda srow
        sta rdef
        jsr rowlist             ; (srow its count)
        lda rdef
        sta srow
@row    lda srow
        ldx #<q_row
        ldy #>q_row
        jsr asknum
        bcs @row
        cmp #25
        bcs @row
        sta srow
        lda #0                  ; what it will clear, said
        jsr nextrows
        lda ncl
        cmp #1                  ; (c set: some)
@x      rts

; aspeed  4: the message's speed, 1-4 pixels a frame
aspeed  jsr needmsg
        bcs @x
@s      lda speed
        ldx #<q_spd
        ldy #>q_spd
        jsr asknum
        bcs @s
        cmp #1
        bcc @s
        cmp #5
        bcs @s
        sta speed
        clc
@x      rts

; acols  5: the message's row's colours: the screen's, or edited
acols   jsr needmsg
        bcs @x
        jsr needscr
        bcs @x
@q      ldx #<q_scol
        ldy #>q_scol
        jsr print
        lda #1
        jsr readline
        lda #0
        ldx inlen
        beq @set                ; (return: the screen's)
        lda inbuf
        cmp #'e'
        bne @q
        jsr coledit
        lda #1
@set    sta scoled
        clc
@x      rts

; acount  6: a block counter: its row (return: none), then its column
acount  lda #$ff
        sta crow
        ldx #<q_crow
        ldy #>q_crow
        jsr print
        lda #3
        jsr readline
        lda inlen
        beq @x
        jsr innum
        bcs acount
        cmp #25
        bcs acount
        sta crow
@col    lda ccol
        ldx #<q_ccol
        ldy #>q_ccol
        jsr asknum
        bcs @col
        cmp #38
        bcs @col
        sta ccol
        jsr cntok               ; not on the message's rows
        bcc @x
        ldx #<tx_cntno
        ldy #>tx_cntno
        jsr print
        jmp acount
@x      clc
        rts

; cntok  c set if the counter is on the message's rows (its row, the
; one above and the one below)
cntok   lda crow
        bmi @ok
        lda msgn
        beq @ok
        lda srow
        sec
        sbc crow
        clc
        adc #1                  ; (row - counter's row + 1: 0-2 is on them)
        cmp #3
        bcs @ok
        sec
        rts
@ok     clc
        rts

; ashow  s: the module's screen as it will be: the message's start on
; its row (from column 1: column 0 is the background's) in the row's
; colours, the rows next to it cleared; a key goes back
ashow   jsr needscr
        bcs @x
        jsr drawscr
        lda msgn
        beq @k
        ldx srow                ; the rows next to it, cleared where
        beq @b                  ; they aren't empty
        dex
        jsr shclr
@b      ldx srow
        cpx #24
        beq @r
        inx
        jsr shclr
@r      ldx srow                ; the row: p2 its screen, p3 its colours
        jsr scrrow
        lda p1
        sec
        sbc #<lmscr
        sta p2
        lda p1+1
        sbc #>lmscr
        clc
        adc #$04
        sta p2+1
        jsr colrow
        ldy #0
        lda #' '
        sta (p2),y
        lda p2+1                ; (column 0: the background's colour)
        pha
        clc
        adc #$d4
        sta p2+1
        lda lmset+1
        sta (p2),y
        pla
        sta p2+1
        ldx #0
@c      iny
        lda #' '
        cpx msgn
        bcs @c1
        lda msgbuf,x
@c1     sta (p2),y
        lda (p3),y              ; its colour: the screen's, or edited
        ldx scoled
        beq @c2
        lda scol,y
@c2     pha
        lda p2+1
        clc
        adc #$d4
        sta p2+1
        pla
        sta (p2),y
        lda p2+1
        sec
        sbc #$d4
        sta p2+1
        tya
        tax
        cpy #39
        bcc @c
@k      jsr getin
        beq @k
        clc
@x      rts

; shclr  row x of the screen shown cleared, if the module's isn't empty
shclr   stx rcl
        jsr rowempty            ; (p1: the module's row)
        bcc @x
        lda p1                  ; the screen's: $0400 + (p1 - lmscr)
        sec
        sbc #<lmscr
        sta p2
        lda p1+1
        sbc #>lmscr
        clc
        adc #$04
        sta p2+1
        ldy #39
        lda #' '
@c      sta (p2),y
        dey
        bpl @c
@x      rts

; ------------------------------------------------------------
; awrite  return: the module written, its settings made; for the writing
; the rows next to the message cleared (said) and its row's edited
; colours put in, both put back after
; ------------------------------------------------------------
awrite  jsr needscr
        bcs @x
        jsr cntok
        bcc @w
        ldx #<tx_cntw
        ldy #>tx_cntw
        jmp say
@w      jsr mkset
        jsr wsave
        jsr mkfont
        jsr name
        jsr wrest
        sec
@x      rts

; ------------------------------------------------------------
; achain  8: the module first in a chain (SlopLoad 64's line 3, a second
; module after it; slopload.py's -then)? Then written at $a000, not
; $e000: clear of a picture module's $c000-$ffbf
; ------------------------------------------------------------
achain  ldx #<q_chain
        ldy #>q_chain
        jsr print
        lda #1
        jsr readline
        lda #0
        ldx inlen
        beq @s
        ldx inbuf
        cpx #'y'
        bne @s
        lda #$40
@s      sta chmask
        clc
        rts
chmask  byte 0                  ; $40: at $a000 (each address's high byte $40 less)

; creloc  the main part moved to $a000 and back (chmask $40; 0: nothing):
; the 149 bytes the two builds differ in, PETSCII-Load's addresses' high
; bytes, eor $40 (tools/c64build.py: lmrlo, lmrhi)
;   uses: a, x, y, t0, t1
creloc  lda chmask
        beq @x
        ldx #0
@r      lda #<lmmain
        clc
        adc lmrlo,x
        sta t0
        lda #>lmmain
        adc lmrhi,x
        sta t1
        ldy #0
        lda (t0),y
        eor #$40
        sta (t0),y
        inx
        cpx #lmnrel
        bne @r
@x      rts

; wsave  with a message: the rows next to it kept and cleared where they
; aren't empty (said); its row's colours kept and the edited ones put in
wsave   lda msgn
        beq @x
        ldx srow
        beq @b
        dex
        jsr scrrow
        ldy #39
@s1     lda (p1),y
        sta nsav,y
        dey
        bpl @s1
@b      ldx srow
        cpx #24
        beq @c
        inx
        jsr scrrow
        ldy #39
@s2     lda (p1),y
        sta nsav+40,y
        dey
        bpl @s2
@c      lda #1
        jsr nextrows
        lda scoled
        beq @x
        jsr colrow
        ldy #39
@s3     lda (p3),y
        sta csav,y
        lda scol,y
        sta (p3),y
        dey
        bne @s3
@x      rts

; wrest  what wsave changed, put back
wrest   lda msgn
        beq @x
        ldx srow
        beq @b
        dex
        jsr scrrow
        ldy #39
@s1     lda nsav,y
        sta (p1),y
        dey
        bpl @s1
@b      ldx srow
        cpx #24
        beq @c
        inx
        jsr scrrow
        ldy #39
@s2     lda nsav+40,y
        sta (p1),y
        dey
        bpl @s2
@c      lda scoled
        beq @x
        jsr colrow
        ldy #39
@s3     lda csav,y
        sta (p3),y
        dey
        bne @s3
@x      rts

; scrrow  p1: row x of the module's screen
scrrow  lda #<lmscr
        sta p1
        lda #>lmscr
        sta p1+1
        cpx #0
        beq @x
@a      lda p1
        clc
        adc #40
        sta p1
        bcc @b
        inc p1+1
@b      dex
        bne @a
@x      rts

; colrow  p3: the message's row (srow) in the module's colours
colrow  lda #<lmcol
        sta p3
        lda #>lmcol
        sta p3+1
        ldx srow
        beq @x
@a      lda p3
        clc
        adc #40
        sta p3
        bcc @b
        inc p3+1
@b      dex
        bne @a
@x      rts

; ------------------------------------------------------------
; ask  the drive and the .pet's name; the file read into the module
;   out:  c set if it can't be used (said); inlen 0: return alone,
;         the screen there is kept
; ------------------------------------------------------------
ask     lda prgdev
        ldx #<q_drive
        ldy #>q_drive
        jsr asknum
        bcs ask
        cmp #8
        bcc ask
        cmp #31
        bcs ask
        sta prgdev
        sta ddev                ; ($ and @: disk.asm, on this drive)
@name   ldx #<q_file
        ldy #>q_file
        jsr print
        lda #16
        jsr readline
        jsr diskkey             ; ($: its files, @: its commands)
        bcs @name
        lda inlen
        bne @nm
        lda pok                 ; return alone: the screen there is, kept
        beq @name
        clc
        rts
@nm     sta prglen
        tax
@c      dex
        lda inbuf,x
        sta prgname,x
        txa
        bne @c
        lda #0                  ; (read into the module: none until read)
        sta pok
        jmp rdpet

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

; ------------------------------------------------------------
; rdpet  the .pet file: its header checked, the codes and colours into
; the module, its settings made
;   out:  c set if it can't be used (said)
; ------------------------------------------------------------
rdpet   ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        lda #2
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
        lda #<lmscr             ; the screen codes
        ldx #>lmscr
        jsr rd1000
        bcs @short
        lda #<lmcol             ; the colours: the last byte ends the file
        ldx #>lmcol
        jsr rd1000
        bcs @short
        and #$40
        beq @size               ; more after it
        jsr clrchn
        lda #2
        jsr close
        lda hdr+2               ; the settings: border, background, $d018
        and #15
        sta lmset
        lda hdr+3
        and #15
        sta lmset+1
        ldx #$f6                ; lower case: the font at $1800 in the bank
        lda hdr+4
        beq @lc
        ldx #$f4                ; upper case: at $1000
@lc     stx lmset+2
        lda #0
        sta lmset+3
        ldx #<tx_ok
        ldy #>tx_ok
        jsr print
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
; bytes into fontbuf, the rest blank (as Petmate reads a .64c); 8 bytes
; at least
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
        lda pok
        beq @x
        ldx #<tx_ok
        ldy #>tx_ok
        jsr print
@x      clc
        rts

; ------------------------------------------------------------
; showit  the screen as it will show (a key goes on)
; ------------------------------------------------------------
showit
@k0     jsr getin               ; a key: then the screen
        beq @k0
        jsr drawscr
@k      jsr getin
        beq @k
        rts

; drawscr  the module's screen on the C64's: codes, colours, border,
; background, case
drawscr ldx #0
@c      lda lmscr,x
        sta $0400,x
        lda lmscr+$100,x
        sta $0500,x
        lda lmscr+$200,x
        sta $0600,x
        lda lmscr+$2e8,x
        sta $06e8,x
        lda lmcol,x
        sta $d800,x
        lda lmcol+$100,x
        sta $d900,x
        lda lmcol+$200,x
        sta $da00,x
        lda lmcol+$2e8,x
        sta $dae8,x
        inx
        bne @c
        lda lmset
        sta $d020
        lda lmset+1
        sta $d021
        lda #$1e                ; a font of its own: at $3800
        ldx fok
        bne @u
        lda #$15                ; the rom font: upper case, or lower ($17)
        ldx hdr+4
        bne @u
        lda #$17
@u      sta $d018
        rts

; ------------------------------------------------------------
; name  the module's name (the .pet's, ending .lm), and it written
; ------------------------------------------------------------
name    ldx #<q_out
        ldy #>q_out
        jsr wname
        jsr wcreate
        bcc @go
        rts
@go     jsr creloc          ; (a chain's first: built at $a000)
        ldx #3
        jsr chkout
        lda #<lmmaddr           ; the main part: its address and length,
        jsr chrout              ; its bytes, the message
        lda #>lmmaddr
        eor chmask
        jsr chrout
        lda #<lmmlen
        clc
        adc msglen
        php
        jsr chrout
        plp
        lda #>lmmlen
        adc #0
        jsr chrout
        lda #<lmmain
        ldx #>lmmain
        ldy #<lmmlen
        sty cnt
        ldy #>lmmlen
        jsr wrblk
        lda msglen
        beq @lo
        sta cnt
        lda #<msgbuf
        ldx #>msgbuf
        ldy #0
        jsr wrmap
@lo     jsr wrfont              ; a font of its own: its part
        lda #<lmladdr           ; the screen's part: the codes
        jsr chrout
        lda #>lmladdr
        jsr chrout
        lda #<1000
        jsr chrout
        lda #>1000
        jsr chrout
        lda #<lmscr
        ldx #>lmscr
        ldy #<1000
        sty cnt
        ldy #>1000
        jsr wrmap
        jsr creloc              ; (back to $e000)
        jsr wclose
        bcs @x
        ldx #<tx_blocks
        ldy #>tx_blocks
        jmp print
@x      rts

; ------------------------------------------------------------
; mkset  the module's settings from the menu's: flags, the scroller's
; row and speed, the counter's place, the message's length, the space's
; and the digit 0's codes, $d018, the claim, the cpu share
; ------------------------------------------------------------
mkset   lda msgn                ; the message, in screen codes already
        sta msglen
        lda #0                  ; the counter's place: row x 40 + column
        sta place+1
        lda ccol
        sta place
        ldx crow
        bmi @set
        beq @set
@pa     lda place
        clc
        adc #40
        sta place
        bcc @pb
        inc place+1
@pb     dex
        bne @pa
@set    ldx #0                  ; flags: bit 0 the counter, bit 1 the scroller
        lda crow
        bmi @f1
        inx
@f1     lda msglen
        beq @f2
        inx
        inx
@f2     stx lmset+3
        lda #24                 ; the scroller's row (24 with none)
        ldx msglen
        beq @r
        lda srow
@r      sta lmext
        lda speed
        ldx msglen
        bne @s
        lda #2                  ; (none: as the PC tool leaves it)
@s      sta lmext+1
        lda #0
        ldx crow
        bmi @p0
        lda place
        sta lmext+2
        lda place+1
        sta lmext+3
        jmp @p1
@p0     sta lmext+2
        sta lmext+3
@p1     lda msglen
        sta lmext+4
        lda #0
        sta lmext+5
        lda #$20                ; the space's code and the digit 0's
        sta lmext+6             ; (mkfont's with a font of its own)
        lda #$30
        sta lmext+7
        ldx #$f6                ; $d018: lower case, the font at $1800
        lda hdr+4               ; in the bank (mkfont's with its own)
        beq @lc
        ldx #$f4                ; upper case: at $1000
@lc     stx lmset+2
        lda #<(lmmaddr+lmmlen)  ; the claim: to the message's end
        clc
        adc msglen
        sta lmclaim
        lda #>(lmmaddr+lmmlen)
        adc #0
        sta lmclaim+1
        lda #shnone             ; the cpu share: less with the split
        ldx msglen
        beq @sh
        lda #shscr
@sh     sta lmshare
        rts

; ------------------------------------------------------------
; mkfont  with a font of its own (fok): the characters the module shows
; (the screen's, the message's, a space with a message, the digits with
; a counter) marked in fusd and numbered from 0 in their order in fmap,
; fk how many; the font part's place (fbase: $b8 for 128 or fewer, else
; $b0), $d018 for it, the space's and the digit 0's new codes in the
; settings. tools/petscii.py's font_part.
;   uses: a, x, y, p1, cnt
; ------------------------------------------------------------
mkfont  lda fok
        bne @go
        rts
@go     lda #0                  ; none marked
        tax
@cl     sta fusd,x
        inx
        bne @cl
        lda #<lmscr             ; the screen's 1,000
        sta p1
        lda #>lmscr
        sta p1+1
        lda #<1000
        sta cnt
        lda #>1000
        sta cnt+1
@s      ldy #0
        lda (p1),y
        tax
        lda #1
        sta fusd,x
        inc p1
        bne @s1
        inc p1+1
@s1     lda cnt
        bne @s2
        dec cnt+1
@s2     dec cnt
        lda cnt
        ora cnt+1
        bne @s
        ldy #0                  ; the message's, and a space
@m      cpy msglen
        bcs @md
        ldx msgbuf,y
        lda #1
        sta fusd,x
        iny
        bne @m
@md     lda msglen
        beq @nm
        lda #1
        sta fusd+$20
@nm     lda crow                ; a counter's digits
        bmi @nc
        ldx #9
        lda #1
@dg     sta fusd+$30,x
        dex
        bpl @dg
@nc     lda #0                  ; numbered in order
        sta fk
        sta fk+1
        tax
@n      lda fusd,x
        beq @nn
        lda fk
        sta fmap,x
        inc fk
        bne @nn
        inc fk+1
@nn     inx
        bne @n
        lda fk+1                ; 256: at $b000
        bne @big
        lda fk
        cmp #129
        bcc @sm                 ; 128 or fewer: at $b800
@big    ldx #$b0
        lda #$fc
        bne @set
@sm     ldx #$b8
        lda #$fe
@set    stx fbase
        sta lmset+2
        lda msglen
        beq @ns
        lda fmap+$20
        sta lmext+6
@ns     lda crow
        bmi @x
        lda fmap+$30
        sta lmext+7
@x      rts

; wrmap  as wrblk (cnt low, y high, bytes from a/x lo/hi to the output),
; each byte through fmap with a font of its own (fok)
;   uses: a, x, y, p1, cnt
wrmap   sta p1
        stx p1+1
        sty cnt+1
        lda cnt
        ora cnt+1
        beq @x
@w      ldy #0
        lda (p1),y
        ldx fok
        beq @o
        tax
        lda fmap,x
@o      jsr chrout
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

; wrfont  with a font of its own, its part to the output: its address
; (fbase), its length (8 x fk), then the characters fusd marks, in order
;   uses: a, x, y, p1, t0, t1
wrfont  lda fok
        beq @x
        lda #0
        jsr chrout
        lda fbase
        jsr chrout
        lda fk                  ; 8 x fk
        sta p1
        lda fk+1
        sta p1+1
        asl p1
        rol p1+1
        asl p1
        rol p1+1
        asl p1
        rol p1+1
        lda p1
        jsr chrout
        lda p1+1
        jsr chrout
        lda #<fontbuf
        sta p1
        lda #>fontbuf
        sta p1+1
        lda #0
        sta t0
@c      ldx t0
        lda fusd,x
        beq @n
        lda #0
        sta t1
@b      ldy t1
        lda (p1),y
        jsr chrout
        inc t1
        lda t1
        cmp #8
        bcc @b
@n      lda p1
        clc
        adc #8
        sta p1
        bcc @nx
        inc p1+1
@nx     inc t0
        bne @c
@x      rts

; rowsok  the rows next to srow empty (spaces)?
;   out:  c clear if so
rowsok  ldx srow
        beq @dn                 ; (row 0: none above)
        dex
        jsr rowempty
        bcs @x
@dn     ldx srow
        cpx #24
        beq @ok                 ; (row 24: none below)
        inx
        jsr rowempty
        rts
@ok     clc
@x      rts

; rowempty  row x of the screen all spaces? c clear if so
;   uses: a, x, y, p1
rowempty
        jsr scrrow
        ldy #39
@t      lda (p1),y
        cmp #$20
        bne @no
        dey
        bpl @t
        clc
        rts
@no     sec
        rts

; rowlist  the rows the message can go on with nothing cleared (the
; rows next to them empty), printed ("none" if none); rcnt how many
;   uses: a, x, y, p1, t0-t3 (prdec16)
rowlist lda #0
        sta rcnt
        sta srow
        ldx #<tx_rows
        ldy #>tx_rows
        jsr print
@l      jsr rowsok
        bcs @n
        inc rcnt
        lda srow
        ldx #0
        jsr prdec16
        lda #' '
        jsr chrout
@n      inc srow
        lda srow
        cmp #25
        bcc @l
        lda rcnt
        bne @x
        ldx #<tx_none
        ldy #>tx_none
        jsr print
@x      lda #13
        jmp chrout

; nextrows  the rows next to the message's (srow) that aren't empty: with
; a 0 said to be cleared for it when written, with a 1 cleared in the
; module's screen and said so (next to it they would shake, as its
; split can come a few lines late: tools/petscii.py's clear_next); ncl
; how many
;   uses: a, x, y, p1, t0-t3 (prdec16)
nextrows sta clrnow
        lda #0
        sta ncl
        ldx srow
        beq @dn                 ; (row 0: none above)
        dex
        jsr nextrow
@dn     ldx srow
        cpx #24
        beq @w                  ; (row 24: none below)
        inx
        jsr nextrow
@w      lda ncl
        beq @x
        ldx #<tx_why
        ldy #>tx_why
        jmp print
@x      rts

; nextrow  row x, if it isn't empty: cleared (clrnow) and said
nextrow stx rcl
        jsr rowempty            ; (p1: the row)
        bcc @x
        inc ncl
        lda clrnow
        beq @say
        ldy #39
        lda #' '
@c      sta (p1),y
        dey
        bpl @c
@say    ldx #<tx_rowc
        ldy #>tx_rowc
        jsr print
        lda rcl
        ldx #0
        jsr prdec16
        ldx #<tx_willc
        ldy #>tx_willc
        lda clrnow
        beq @p
        ldx #<tx_clrd
        ldy #>tx_clrd
@p      jsr print
@x      rts

; ------------------------------------------------------------
; msgedit  the message in an editor of its own: the field, 5 rows of
; 40 (msgmax characters), on a cleared screen in the .pet's case, with
; what was there before (the last screen's message) to change or keep.
; Typing goes in at the cursor; the cursor keys move it (up and down
; by a row), del takes the character before it, inst puts a space in at
; it, home goes to the start, clr empties it; return ends it (empty:
; no message). In msgbuf as screen codes, msgn long.
;   uses: everything
; ------------------------------------------------------------
fld     = $0400+80              ; the field: rows 2-6
fldcol  = $d800+80
msgedit lda #147
        jsr chrout
        lda #$15                ; the .pet's case, as the module shows it
        ldx hdr+4
        bne @u
        lda #$17
@u      sta $d018
        ldx #<tx_edit
        ldy #>tx_edit
        jsr print
        ldx #9                  ; the keys, under the field
        ldy #0
        clc
        jsr plot
        ldx #<tx_keys
        ldy #>tx_keys
        jsr print
        ldx #msgmax             ; the field's colour
        lda #1
@cl     sta fldcol-1,x
        dex
        bne @cl
        lda msgn
        sta cur
@d      jsr drawfld
@k      jsr getin
        beq @k
        cmp #13
        bne @lf
        jmp @x
@lf     cmp #157                ; left
        bne @r
        lda cur
        beq @k
        dec cur
        jmp @d
@r      cmp #29                 ; right
        bne @up
        lda cur
        cmp msgn
        bcs @k
        inc cur
        jmp @d
@up     cmp #145                ; up: a row back
        bne @dn
        lda cur
        sec
        sbc #40
        bcc @k
        sta cur
        jmp @d
@dn     cmp #17                 ; down: a row on (or the end)
        bne @h
        lda cur
        clc
        adc #40
        cmp msgn
        bcc @dn2
        lda msgn
@dn2    sta cur
        jmp @d
@h      cmp #19                 ; home
        bne @clr
        lda #0
        sta cur
        jmp @d
@clr    cmp #147                ; clr: all of it
        bne @del
        lda #0
        sta cur
        sta msgn
        jmp @d
@del    cmp #20                 ; del: the one before the cursor
        bne @ins
        ldx cur
        beq @kk
        dex
        stx cur
@dl     inx                     ; (the rest one back)
        cpx msgn
        bcs @dd
        lda msgbuf,x
        sta msgbuf-1,x
        jmp @dl
@dd     dec msgn
        jmp @d
@kk     jmp @k                  ; (too far for a branch)
@ins    cmp #148                ; inst: a space in at the cursor
        bne @ch
        lda #' '
        jsr msgins
        jmp @d
@ch     cmp #$20                ; a character: in at the cursor
        bcc @kk                 ; (no colours or other control keys)
        cmp #$80
        bcc @ok
        cmp #$a0
        bcc @kk
@ok     jsr p2s
        jsr msgins
        bcs @kk                 ; (full)
        inc cur
        jmp @d
@x      lda #$ff                ; the cursor off; on below the field
        sta cur
        jsr drawfld
        ldx #15
        ldy #0
        clc
        jmp plot

; msgins  screen code a in at the cursor, the rest on one; c set if the
; message is full
msgins  ldx msgn
        cpx #msgmax
        bcs @f
        pha
@m      cpx cur
        beq @p
        lda msgbuf-1,x
        sta msgbuf,x
        dex
        jmp @m
@p      pla
        sta msgbuf,x
        inc msgn
        clc
@f      rts

; drawfld  the message in the field, the cursor's character reversed;
; its length under it ("12 of 200")
drawfld ldx #0
@l      lda #' '
        cpx msgn
        bcs @c
        lda msgbuf,x
@c      cpx cur
        bne @s
        eor #$80
@s      sta fld,x
        inx
        cpx #msgmax
        bcc @l
        ldx #7
        ldy #0
        clc
        jsr plot
        lda msgn
        ldx #0
        jsr prdec16
        ldx #<tx_of
        ldy #>tx_of
        jmp print

; ------------------------------------------------------------
; coledit  the message's row's colours (its colour memory: it stays put
; while the message moves through it), columns 1-39, in an editor of
; their own, on the screen's border and background: the row as the
; module shows it (the message's start in it), under it a bar of each
; column's colour (a space's shows there too), and a mark under the
; cursor. Left and right move it, home goes to column 1; the C64's
; colour keys (ctrl or C= with 1-8) put that colour at the cursor and
; move on; f gives every column the cursor's colour; p puts the
; screen's colours back; return ends it. Column 0 is the background's
; (the module paints it: the message leaves the row there). The
; colours edited in scol (from the last ones edited, or the screen's),
; put in the module's when it is written: tools/petscii.py's
; -scrollcolours.
;   uses: everything
; ------------------------------------------------------------
cerow   = $0400+2*40            ; the row as the module shows it
cebar   = $0400+3*40            ; each column's colour
cemark  = $0400+4*40            ; the cursor's mark
cerowc  = $d800+2*40            ; (their colour memory)
cebarc  = $d800+3*40
cemarkc = $d800+4*40
coledit lda #147
        jsr chrout
        lda lmset               ; the screen's border and background
        sta $d020
        lda lmset+1
        sta $d021
        and #15
        tax
        lda contr,x             ; the text in a colour that shows on it
        sta 646
        lda #$15                ; the .pet's case, as the module shows it
        ldx hdr+4
        bne @u
        lda #$17
@u      sta $d018
        ldx #<tx_cedit
        ldy #>tx_cedit
        jsr print
        ldx #6                  ; the keys, under the row
        ldy #0
        clc
        jsr plot
        ldx #<tx_ckeys
        ldy #>tx_ckeys
        jsr print
        jsr colrow              ; p3: the screen's colours for the row
        lda scoled              ; the colours to edit: the last edited, or
        bne @r0                 ; the screen's
        ldy #39
@sv     lda (p3),y
        sta scol,y
        dey
        bne @sv
@r0     ldx #0                  ; the row: the message's start in columns
@m      lda #' '                ; 1-39; the bar: reversed spaces
        cpx msgn
        bcs @m1
        lda msgbuf,x
@m1     sta cerow+1,x
        lda #160
        sta cebar+1,x
        lda 646                 ; (the mark in the text's colour)
        sta cemarkc+1,x
        inx
        cpx #39
        bcc @m
        lda #1
        sta ccur
@d      jsr cedraw
@k      jsr getin
        beq @k
        cmp #13
        bne @lf
        rts
@lf     cmp #157                ; left
        bne @rt
        ldx ccur
        dex
        beq @k
        stx ccur
        jmp @d
@rt     cmp #29                 ; right
        bne @hm
        ldx ccur
        cpx #39
        bcs @k
        inc ccur
        jmp @d
@hm     cmp #19                 ; home: column 1
        bne @f
        lda #1
        sta ccur
        jmp @d
@f      cmp #'f'                ; f: every column the cursor's colour
        bne @p
        ldy ccur
        lda scol,y
        ldy #39
@fl     sta scol,y
        dey
        bne @fl
        jmp @d
@p      cmp #'p'                ; p: the screen's colours again
        bne @c
        ldy #39
@pl     lda (p3),y
        sta scol,y
        dey
        bne @pl
        jmp @d
@c      ldx #15                 ; a colour key: which colour
@cs     cmp ckeys,x
        beq @cp
        dex
        bpl @cs
        jmp @k
@cp     txa                     ; at the cursor, and on a column
        ldy ccur
        sta scol,y
        cpy #39
        bcs @dd
        inc ccur
@dd     jmp @d

; cedraw  the row and the bar in the row's colours, the mark under the
; cursor
cedraw  ldy #39
@c      lda scol,y
        sta cerowc,y
        sta cebarc,y
        lda #' '
        cpy ccur
        bne @s
        lda #30                 ; (an up arrow)
@s      sta cemark,y
        dey
        bne @c
        rts

; the colour keys' codes (getin), colour 0 to 15
ckeys   byte $90,$05,$1c,$9f,$9c,$1e,$1f,$9e,$81,$95,$96,$97,$98,$99,$9a,$9b
; a text colour that shows on each background: white on the dark ones
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
tx_head text "           ",159,"*** ",5,"petscii-lm",159," ***",13,151,"  a petscii screen to a loader module",30,0
tx_bye  text "bye.",13,0
tl1     text "screen    ",0
tl2     text "message   ",0
tl3     text "row       ",0
tl4     text "speed     ",0
tl5     text "colours   ",0
tl6     text "counter   ",0
tl7     text "font      ",0
tl8     text "chain     ",0
tl9     text "write the module",0
tl10    text "show it",0
tl11    text "@ disk",0
tx_chno text "no: at $e000",0
tx_chyes text "first in a chain: at $a000",0
q_chain text "first in a chain (slopload 64's second",13
        text "module, a picture's, after it): written",13
        text "at $a000, clear of the picture? y/n [n] ",0
tx_pxf  text " pixels a frame",0
tx_asscr text "as on the screen",0
tx_edited text "edited",0
tx_crow text "row ",0
tx_ccol text ", column ",0
tx_mkeys text 155,"1-8: change  s: show  @: disk  q: quit",13,"return: write the module",30,0
tx_ttl  text 154,18," ",0       ; light blue, reverse
tx_ttle text 146,30,13,0        ; (off, green, the next row)
tx_anyk text 155,"press any key",30,0
tx_needs text "choose a screen first (1)",13,0
tx_needm text "type a message first (2)",13,0
tx_cntw text "the counter is on the message's rows:",13,"move one of them (3 or 6)",13,0
q_drive text "drive with the .pet file [",0
q_fdrive text "drive with the font (.64c) [",0
q_ffile text "its file name ($: files, @: disk, return:",13,"keep it, -: the c64's own)? ",0
tx_fc64 text "the c64's own",0
tx_fread text "read: choose a screen (1) to see it in it",13,0
tx_fshort text "too short for a font (8 bytes",13,"a character after its address)",13,0
q_file  text "its file name ($: files, @: disk)? ",0
q_ddrive text "drive [",0
tx_ask  text "]? ",0
tx_reading text "reading it...",13,0
tx_ok   text "a key shows it, another goes on",13,0
tx_short text "the file ended early: not a .pet file",13,0
tx_size text "not a 40 x 25 .pet file",13,0
tx_case text "its case is neither upper nor lower:",13,"not a .pet file",13,0
q_out   text "the module's name [",0
tx_blocks text 13,"choose it in slopload 64 (3: the module)",13,0
tx_edit text "a scrolling message (empty: none)",0
tx_keys text "type it: it goes in at the cursor.",13,"crsr keys move it, del: the one before,",13,"inst: a space, home: the start,",13,"clr (shift home): all of it gone.",13,"return: done.",0
tx_of   text " of 200  ",0
tx_rows text "rows that need nothing cleared: ",0
tx_none text "none",0
q_row   text "its row [",0
tx_rowc text "row ",0
tx_clrd text " cleared for it",13,0
tx_willc text " will be cleared for it",13,0
tx_why  text "(next to the message it would shake:",13,"its split can come a few lines late",13,"while the loader runs)",13,0
q_spd   text "its speed, 1-4 pixels a frame [",0
q_scol  text "its colours (return: as on the screen,",13,"e: edit them)? ",0
tx_cedit text "the scrolling message's colours: they",13,"stay put, the message moves through",0
tx_ckeys text "left, right: move   home: column 1",13,"ctrl or c= and 1-8: that colour here",13,"f: every column this one's colour",13,"p: the screen's colours again",13,"return: done",13,13,"(column 0 shows the background: the",13,"message leaves the row there)",0
q_crow  text "a block counter: its row (return: none)? ",0
q_ccol  text "its column (its first digit of 3) [",0
tx_cntno text "not on the message's rows",13,0
wold    text ".pet"                 ; (wfile.asm: the name's ending, and the new one)
wnew    byte 3
        text ".lm"

        incasm "petlm.asm"      ; the module (c64build.py)
msgbuf                          ; the message (msgmax bytes)
bssend = msgbuf+msgmax
