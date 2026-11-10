; ------------------------------------------------------------
; picturelm.asm  -  PICTURE-LM: a picture, with up to two loading
; sprites and an ending, made into a loader module (.lm) for SlopLoad 64
; (and the PC tool): the show module with the picture in it, shown while
; the program loads. The same file tools/picturelm.py makes on a PC.
;
; LOAD"PICTURE-LM",8 and RUN. A menu of the settings, each on a line of
; its own and changed by its number at any time: the picture (a Koala
; .koa, or any C64 format in tools/picturelm.py's FORMATS: Advanced Art
; Studio, Blazing Paddles, Doodle and a dozen more), the sprites (one or
; two, 64 bytes each, 63 will do; a .prg's load address skipped), where
; they go (or moved over the picture with the joystick: s), the colours
; they flash through (hex digits, one a colour: 1fcb0bcf), frames a
; colour, multicolour (and its two shared colours), twice as big, and
; the ending (press space or fire; the music fades). S shows the picture
; and the sprites as they will be, the joystick in port 2 moving them
; (fire keeps the place); return asks for the module's name (the
; picture's, ending .lm) and writes it; the settings stay for the next;
; q quits.
;
; The file (tools/picturelm.py has the why of each byte): VIC bank 3,
; two parts. $c000-$cfe7: the module (pl_lm, assembled at $c000), its
; scratch (zeros), a Koala picture's colours (at +76: the module copies
; them into colour RAM as it starts), zeros, the screen at $cc00.
; $e000: the bitmap, then the sprites ($ff40 on). The header: +12 the
; jitter (48; 8 a sprite on a line more), +13 no song, +14 the share
; (64), +15 the background, +25 the bank, +28 the ending and hires,
; +29 to +75 the sprites (as slopload.py's load_sprites makes them).
;
; Memory: the program $0801 on; the sprites shown at $4000 and $4040,
; the screen at $4c00, the bitmap at $6000 (VIC bank 1, for s); the
; picture's file as read $8000-$a8ff, the sprites' $a900-$a9ff and a
; picture's one colour for all $ac00-$afe7 (the BASIC ROM switched out); zeros $3f00-$3fff; zero page $20-$3f (BASIC's:
; it leaves through BASIC's warm start).
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
fend = $36                      ; rdfile: the buffer's end (2)

; ---- memory ----
pvspr = $4000                   ; s: the sprites, the screen, the bitmap
pvscr = $4c00                   ; (VIC bank 1)
pvbit = $6000
pbuf = $8000                    ; the picture's file, as read (10,277 bytes at most)
pbufend = $a900
sbuf = $a900                    ; the sprites' file
sbufend = $aa00
onebuf = $ac00                  ; a picture's one colour, 1,000 times (paint magic)
zeros = $3f00                   ; a page of zeros (written as the module's gaps)
lmbase = $c000                  ; the module, in the file
lmscr = $cc00                   ; the screen
lmbit = $e000                   ; the bitmap, then the sprites

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "io.asm"
        incasm "disk.asm"       ; ($ and @: a drive's files and commands)
prch = chrout                   ; (print's character: no words packed here)
        incasm "wfile.asm"

; ---- io.asm's and wfile.asm's variables ----
inlen   byte 0
inbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dsbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
prgdev  byte 8                  ; the picture's drive
prglen  byte 0                  ; ... its name
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
paddr   word 0                  ; (unused here)
eof     byte 0
tapdev  byte 0                  ; (unused here)
tapfnl  byte 0
tapfname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tapn    byte 0,0,0
wold    byte $2e,$4b,$4f,$41    ; ".koa": the picture's name less it, + ".lm"
wnew    byte 3,$2e,$4c,$4d

; ---- this program's settings ----
pok     byte 0                  ; a picture read (1)
phires  byte 0                  ; ... hires (1): no colours
kbit    word 0                  ; its bitmap, screen and colours in pbuf
kscr    word 0
kcol    word 0
kbg     byte 0                  ; its background
nspr    byte 0                  ; sprites read: 0 none, 1, 2
sdev    byte 8                  ; their drive and name
snlen   byte 0
sname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
posset  byte 0                  ; 1: px, py set (else bottom right)
px      word 0                  ; their top left on the picture
py      byte 0
flen    byte 1                  ; the colours they flash through
ftab    byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fspd    byte 2                  ; frames a colour
smc     byte 0                  ; multicolour (1), its shared colours
smca    byte 0
smcb    byte 0
sbig    byte 0                  ; twice as wide and tall (1)
ewait   byte 0                  ; the ending: space or fire (1)
irow    byte 0                  ; the menu: the line's row
usedc   byte 5                  ; ... its value's colour
shead   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; mkhead: +29 to +75
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
sw      byte 0                  ; mkhead: the sprites' width (all of them), height
sh      byte 0
sstep   byte 0                  ; ... from one to the next
lmhead  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; the module's header, made
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; (its first 78 bytes)
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
colat   word 0                  ; the colours' place in the module (0: none)

; ------------------------------------------------------------
; main
; ------------------------------------------------------------
main    lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        lda #$36                ; the BASIC ROM out: its RAM for the files
        sta $01
        ldx #0                  ; a page of zeros
        txa
@z      sta zeros,x
        inx
        bne @z
        lda $ba                 ; the drive it was loaded from
        cmp #8
        bcc menu
        sta prgdev
        sta sdev

; ------------------------------------------------------------
; menu  every setting on a line of its own (1-8), changed by its number
; at any time: its name in reverse on row ttlrow and its questions
; under it; s shows the picture and moves the sprites, return writes
; the module (the settings stay), q quits. An action returns c set when
; it said something: "press any key" first, then the menu again.
; ------------------------------------------------------------
ttlrow  = 14
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
acts    word apic,aspr,apos,acols,aspeed,amc,abig,aend

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
; mdraw  the screen cleared, the menu: the title (rows 0-1), lines 1-8
; (rows 3-10), the keys (rows 12-13)
; ------------------------------------------------------------
mdraw   jsr look
        ldx #<tx_head
        ldy #>tx_head
        jsr print
        lda #1                  ; 1 picture
        ldx #3
        jsr item
        lda pok
        beq @p0
        lda prgdev
        ldx #<prglen
        ldy #>prglen
        jsr prfile
        ldx #<tx_koala
        ldy #>tx_koala
        lda phires
        beq @pk
        ldx #<tx_hires
        ldy #>tx_hires
@pk     jsr print
        jmp @p1
@p0     jsr none
@p1     lda #2                  ; 2 sprites
        jsr item0
        lda nspr
        bne @s1
        ldx #<tx_none
        ldy #>tx_none
        jsr print
        jmp @s2
@s1     lda sdev
        ldx #<snlen
        ldy #>snlen
        jsr prfile
        lda #' '
        jsr chrout
        lda #'('
        jsr chrout
        lda nspr
        ora #'0'
        jsr chrout
        lda #')'
        jsr chrout
@s2     jsr used                ; 3 where (grey with no sprites)
        lda #3
        jsr item0
        lda posset
        bne @ps
        ldx #<tx_br
        ldy #>tx_br
        jsr print
        jmp @s3
@ps     lda px
        ldx px+1
        jsr prdec16
        lda #','
        jsr chrout
        lda py
        ldx #0
        jsr prdec16
@s3     jsr used                ; 4 colours: each its hex digit, in reverse
        lda #4                  ; in its colour (black: grey, not reversed)
        jsr item0
        jsr prcols
        jsr used                ; 5 speed
        lda #5
        jsr item0
        lda fspd
        ldx #0
        jsr prdec16
        ldx #<tx_fac
        ldy #>tx_fac
        jsr print
        jsr used                ; 6 multicolour
        lda #6
        jsr item0
        lda smc
        bne @m1
        ldx #<tx_no
        ldy #>tx_no
        jsr print
        jmp @m2
@m1     ldx #<tx_mcw
        ldy #>tx_mcw
        jsr print
        lda smca
        ldx #0
        jsr prdec16
        ldx #<tx_and
        ldy #>tx_and
        jsr print
        lda smcb
        ldx #0
        jsr prdec16
@m2     jsr used                ; 7 size
        lda #7
        jsr item0
        ldx #<tx_norm
        ldy #>tx_norm
        lda sbig
        beq @b
        ldx #<tx_big
        ldy #>tx_big
@b      jsr print
        lda #8                  ; 8 the ending
        jsr item0
        ldx #<tx_atonce
        ldy #>tx_atonce
        lda ewait
        beq @e1
        ldx #<tx_pwait
        ldy #>tx_pwait
@e1     jsr print
        ldx #12                 ; the keys
        ldy #0
        clc
        jsr plot
        ldx #<tx_mkeys
        ldy #>tx_mkeys
        jmp print

; hexdig  a (0-15) as its hex digit
hexdig  cmp #10
        bcc @d
        adc #'a'-11
        rts
@d      adc #'0'
        rts

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

; used  the next value grey with no sprites (it doesn't count)
used    lda #5
        ldx nspr
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

; ptitle  line a's name (9: write it, 10: show it) in reverse on row
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

; needpic, needspr  a picture read, sprites read: c set if not (said)
needpic lda pok
        bne ok
        ldx #<tx_needp
        ldy #>tx_needp
        jmp say
needspr lda nspr
        bne ok
        ldx #<tx_needs
        ldy #>tx_needs
say     jsr print
        sec
        rts
ok      clc
        rts

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

; askyn  the question at x/y: a = 1 for y, 0 for anything else
askyn   jsr print
        lda #1
        jsr readline
        ldx #0
        lda inlen
        beq @n
        lda inbuf
        cmp #'y'
        bne @n
        inx
@n      txa
        rts

; askfile  the drive (a: its default; x/y the question) and a file's
; name into fnbuf (fnl its length; 0: return alone)
;   out:  a = the drive, c set if none was typed right
askfile stx p2
        sty p2+1
@d      pha
        ldx p2
        ldy p2+1
        jsr asknum
        bcs @no
        tax                     ; drive 0: none (as "-")
        beq @none
        cmp #8
        bcc @no
        cmp #31
        bcs @no
        sta fdrv
        sta ddev                ; ($ and @: disk.asm, on this drive)
        pla
@nm     ldx #<q_file
        ldy #>q_file
        jsr print
        lda #16
        jsr readline
        lda inlen
        beq @in
        lda inbuf
        cmp #'$'                ; its files
        bne @at
        jsr dirshow
        jmp @nm
@at     cmp #'@'                ; its status and commands
        bne @in
        lda inlen
        cmp #1
        bne @in
        jsr dcmd
        jmp @nm
@none   pla
        lda #1
        sta fnl
        lda #'-'
        sta fnbuf
        lda fdrv
        clc
        rts
@in     ldx inlen
        stx fnl
@c      dex
        bmi @x
        lda inbuf,x
        sta fnbuf,x
        jmp @c
@x      lda fdrv
        clc
        rts
@no     pla
        jmp @d
fdrv    byte 0
fnl     byte 0
fnbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; rdfile  the file fdrv/fnbuf read whole into p1 on, to fend at most
;   out:  p1 one past its last byte; c set if it can't be read or is
;         too long (said)
; ------------------------------------------------------------
rdfile  ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        lda #2
        ldx fdrv
        ldy #2
        jsr setlfs
        lda fnl
        ldx #<fnbuf
        ldy #>fnbuf
        jsr setnam
        jsr open
        lda fdrv
        jsr dstat
        bcc @o
        jsr prstat
        jsr @cl
        sec
        rts
@o      ldx #2
        jsr chkin
@r      jsr chrin
        ldy #0
        sta (p1),y
        inc p1
        bne @1
        inc p1+1
@1      jsr readst
        and #$40
        bne @end
        lda p1+1
        cmp fend+1
        bcc @r
        lda p1
        cmp fend
        bcc @r
        jsr @cl                 ; too long
        ldx #<tx_long
        ldy #>tx_long
        jmp say
@end    jsr @cl
        clc
        rts
@cl     jsr clrchn
        lda #2
        jmp close

; ------------------------------------------------------------
; the lines' actions (c set: something said)
; ------------------------------------------------------------
; apic  1: the picture, in one of tools/picturelm.py's FORMATS (piclm.asm
; has them as a table, made by c64build.py): the first whose length (and
; load address, where it says one) fits; the bitmap, screen, colours and
; background where it puts them
apic    ldx #<tx_fmts           ; the formats it reads
        ldy #>tx_fmts
        jsr print
        lda prgdev
        ldx #<q_pdrive
        ldy #>q_pdrive
        jsr askfile
        sta prgdev
        lda fnl
        beq @k0                 ; (return alone: kept)
        cmp #1
        bne @r
        lda fnbuf
        cmp #'-'                ; (- or drive 0: no picture to take)
        bne @r
@k0     clc
        rts
@r      lda #0
        sta pok
        lda #<pbuf
        sta p1
        lda #>pbuf
        sta p1+1
        lda #<pbufend
        sta fend
        lda #>pbufend
        sta fend+1
        jsr rdfile
        bcc @k
        rts
@k      ldx fnl                 ; its name (for the module's)
        stx prglen
@n      dex
        bmi @t
        lda fnbuf,x
        sta prgname,x
        jmp @n
@t      lda p1                  ; its length
        sec
        sbc #<pbuf
        sta t0
        lda p1+1
        sbc #>pbuf
        sta t1
        jsr pformat
        bcc @ok
        ldx #<tx_notpic
        ldy #>tx_notpic
        jsr print
        ldx #<tx_fmts           ; (the ones it knows)
        ldy #>tx_fmts
        jmp say
@ok     lda #1
        sta pok
        ldx #<tx_isa            ; which it is
        ldy #>tx_isa
        jsr print
        ldx pfmt
        lda fmnlo,x
        ldy fmnhi,x
        tax
        jsr print
        lda #13
        jsr chrout
        sec                     ; (said: a key, then the menu)
        rts

; pformat  the format of the file in pbuf (t0/t1 bytes): kbit, kscr, kcol
; (high byte 0: hires), kbg, phires, pfmt
;   out:  c set if none fits
pformat ldx #0
@f      cpx #nfmt
        bcc @l
        rts                     ; (c set: none)
@l      lda t1                  ; its lengths: lowest <= t0/t1 <= highest
        cmp fmlh,x
        bcc @no
        bne @h
        lda t0
        cmp fmll,x
        bcc @no
@h      lda fmhh,x
        cmp t1
        bcc @no
        bne @la
        lda fmhl,x
        cmp t0
        bcc @no
@la     lda fmla,x              ; its load address: 0 any, $ff a bitmap's, $fe
        beq @fit                ; doodle's, else that high byte (on a page's start)
        ldy pbuf
        bne @no
        cmp #$fe                ; ($fe: doodle's, $1c00 or $5c00)
        bne @bm
        lda pbuf+1
        cmp #$1c
        beq @fit
        cmp #$5c
        beq @fit
        bne @no
@bm     cmp #$ff
        bne @one
        ldy #4
        lda pbuf+1
@bl     cmp hrla,y
        beq @fit
        dey
        bpl @bl
        bmi @no
@one    cmp pbuf+1
        beq @fit
@no     inx
        jmp @f
@fit    stx pfmt
        lda #<pbuf              ; the bitmap, the screen
        clc
        adc fmbl,x
        sta kbit
        lda #>pbuf
        adc fmbh,x
        sta kbit+1
        lda #<pbuf
        clc
        adc fmsl,x
        sta kscr
        lda #>pbuf
        adc fmsh,x
        sta kscr+1
        lda #0
        sta kcol
        sta kcol+1
        sta kbg
        lda fmk,x               ; bit 0 hires, bit 1 one colour for all
        and #1
        sta phires
        bne @bg
        lda #<pbuf              ; the colours' place
        clc
        adc fmcl,x
        sta kcol
        lda #>pbuf
        adc fmch,x
        sta kcol+1
        lda fmk,x
        and #2
        beq @bg
        lda kcol                ; (one colour: 1,000 of it, at onebuf)
        sta p2
        lda kcol+1
        sta p2+1
        ldy #0
        lda (p2),y
        ldy #0
@o1     sta onebuf,y
        sta onebuf+256,y
        sta onebuf+512,y
        sta onebuf+744,y
        iny
        bne @o1
        lda #<onebuf
        sta kcol
        lda #>onebuf
        sta kcol+1
@bg     lda fmgh,x              ; the background ($ffff: none; past the
        cmp #$ff                ; file's end: black)
        beq @x
        cmp t1
        bcc @in
        bne @x
        lda fmgl,x
        cmp t0
        bcs @x
@in     lda #<pbuf
        clc
        adc fmgl,x
        sta p2
        lda #>pbuf
        adc fmgh,x
        sta p2+1
        ldy #0
        lda (p2),y
        and #15
        sta kbg
@x      clc
        rts
hrla    byte $20,$40,$60,$a0,$e0        ; a bitmap's load addresses (high bytes)
pfmt    byte 0                  ; the picture's format (piclm.asm's table)

; aspr  2: the sprites: one or two, 63 or 64 bytes each (64: the last
; padded 0), after a .prg's load address or not (as load_sprites);
; return alone keeps them, - none
aspr    ldx #<tx_sprf           ; what a sprites' file is
        ldy #>tx_sprf
        jsr print
        lda sdev
        ldx #<q_sdrive
        ldy #>q_sdrive
        jsr askfile
        sta sdev
        lda fnl
        bne @nm
        clc                     ; (return alone: kept)
        rts
@nm     cmp #1
        bne @r
        lda fnbuf
        cmp #'-'
        bne @r
        lda #0                  ; -: none
        sta nspr
        clc
        rts
@r      lda #0
        sta nspr
        lda #<sbuf
        sta p1
        lda #>sbuf
        sta p1+1
        lda #<sbufend
        sta fend
        lda #>sbufend
        sta fend+1
        jsr rdfile
        bcc @k
        rts
@k      lda p1                  ; its length (under 256)
        sec
        sbc #<sbuf
        ldx #0                  ; from the file's start
        jsr sizes
        bcc @f
        sec                     ; (or past a load address)
        sbc #2
        bcc @bad
        ldx #2
        jsr sizes
        bcs @bad
@f      sta t2                  ; t2 sprites, t3 bytes each, x where
        sty t3
        stx t4
        ldx #0                  ; to sbuf's start: 63 each, then a 0
@s      ldy #0
@c      sty t5
        ldy t4
        lda sbuf,y
        inc t4
        ldy t5
        sta sprn,x
        inx
        iny
        cpy #63
        bcc @c
        lda #0
        sta sprn,x
        inx
        lda t3                  ; (64 bytes each: one more skipped)
        cmp #64
        bne @n
        inc t4
@n      dec t2
        bne @s
        txa
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        sta nspr
        ldx fnl                 ; its name
        stx snlen
@nn     dex
        bmi @x
        lda fnbuf,x
        sta sname,x
        jmp @nn
@x      clc
        rts
@bad    ldx #<tx_notspr
        ldy #>tx_notspr
        jmp say
sprn    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; the sprites,
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 64 bytes each
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; sizes  a bytes of sprites (load_sprites' sizes): 63 or 64 one, 126,
; 127 or 128 two (127: not of 63 nor of 64, refused)
;   out:  c clear: a sprites, y bytes each (a kept on c set; x kept)
sizes   cmp #63
        beq @1a
        cmp #64
        beq @1b
        cmp #126
        beq @2a
        cmp #128
        beq @2b
        sec
        rts
@1a     ldy #63
        lda #1
        clc
        rts
@1b     ldy #64
        lda #1
        clc
        rts
@2a     ldy #63
        lda #2
        clc
        rts
@2b     ldy #64
        lda #2
        clc
        rts

; apos  3: where the sprites go: their top left on the picture, x
; (0-319) and y (0-199), inside it (checked on writing)
apos    jsr needspr
        bcs @x
        ldx #<q_px
        ldy #>q_px
        jsr print
        lda #3
        jsr readline
        jsr indec16
        bcs @x0
        sta px
        stx px+1
        lda #0
        ldx #<q_py
        ldy #>q_py
        jsr asknum
        bcs @x0
        sta py
        lda #1
        sta posset
@x0     clc
@x      rts

; indec16  inbuf as a decimal word: a/x, c set if not one (or empty)
indec16 lda #0
        sta t0
        sta t1
        ldx #0
        cpx inlen
        beq @bad
@c      cpx inlen
        beq @ok
        lda inbuf,x
        sec
        sbc #'0'
        cmp #10
        bcs @bad
        pha                     ; t0/t1 x 10 + the digit
        lda t0
        sta t2
        lda t1
        sta t3
        asl t0
        rol t1
        asl t0
        rol t1
        lda t0
        clc
        adc t2
        sta t0
        lda t1
        adc t3
        sta t1
        asl t0
        rol t1
        pla
        clc
        adc t0
        sta t0
        bcc @n
        inc t1
@n      inx
        bne @c
@ok     lda t0
        ldx t1
        clc
        rts
@bad    sec
        rts

; acols  4: the colours: hex digits, one a colour (1 to 32)
acols   jsr needspr
        bcs @x
        ldx #<q_cols
        ldy #>q_cols
        jsr print
        lda #32
        jsr readline
        lda inlen
        beq @k                  ; (kept)
        ldx #0                  ; every one a hex digit first
@c      lda inbuf,x
        cmp #'0'
        bcc @bad
        cmp #'9'+1
        bcc @d
        cmp #'a'
        bcc @bad
        cmp #'f'+1
        bcs @bad
@d      inx
        cpx inlen
        bcc @c
        ldx #0
@cp     lda inbuf,x             ; again, kept
        cmp #'a'
        bcc @dg
        sbc #'a'-10
        jmp @st
@dg     sec
        sbc #'0'
@st     sta ftab,x
        inx
        cpx inlen
        bcc @cp
        stx flen
        ldy #0                  ; (the rest 0)
@z      cpx #32
        bcs @k
        tya
        sta ftab,x
        inx
        bne @z
@k      clc
@x      rts
@bad    ldx #<tx_badcol
        ldy #>tx_badcol
        jmp say

; aspeed  5: frames a colour (1-255)
aspeed  jsr needspr
        bcs @x
        lda fspd
        ldx #<q_spd
        ldy #>q_spd
        jsr asknum
        bcs @k
        cmp #1
        bcc @k
        sta fspd
@k      clc
@x      rts

; amc  6: multicolour: y and its shared colours, or not
amc     jsr needspr
        bcs @x
        ldx #<q_mc
        ldy #>q_mc
        jsr askyn
        sta smc
        beq @k
        lda smca
        ldx #<q_mca
        ldy #>q_mca
        jsr asknum
        bcs @k
        and #15
        sta smca
        lda smcb
        ldx #<q_mcb
        ldy #>q_mcb
        jsr asknum
        bcs @k
        and #15
        sta smcb
@k      clc
@x      rts

; abig  7: twice as wide and tall, or not
abig    jsr needspr
        bcs @x
        ldx #<q_big
        ldy #>q_big
        jsr askyn
        sta sbig
        clc
@x      rts

; aend  8: the ending: space or fire, the music faded
aend    ldx #<q_wait
        ldy #>q_wait
        jsr askyn
        sta ewait
        clc
        rts

; prcols  the sprites' colours: each its hex digit in reverse in its own
; colour (0, black: a grey 0, not reversed), 24 at most and then a +
;   uses: a, x, y
prcols  ldx #0
@c      cpx #24
        bcs @more
        lda ftab,x
        tay
        lda nspr
        beq @p                  ; (no sprites: plain, as the line's grey)
        tya
        bne @r
        lda #155                ; (black: a grey 0)
        jsr chrout
@p      tya
        jsr hexdig
        jsr chrout
        jmp @n
@r      lda #18                 ; reverse on, in its colour
        jsr chrout
        lda colcode,y
        jsr chrout
        tya
        jsr hexdig
        jsr chrout
        lda #146
        jsr chrout
@n      inx
        cpx flen
        bcc @c
        bcs @x
@more   lda #'+'
        jsr chrout
@x      lda usedc
        jmp chrout
colcode byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

; ------------------------------------------------------------
; mkhead  the sprites' header bytes (+29 to +75) into shead, as
; load_sprites makes them: enabled, x and y (the second beside the
; first), $d010, multicolour, expansion, the shared colours, the lines
; they cover, the flash. px, py the bottom right when not set
;   out:  c set if they run off the picture (said)
; ------------------------------------------------------------
mkhead  ldx #46                 ; all 0 first
        lda #0
@z      sta shead,x
        dex
        bpl @z
        lda #24                 ; one sprite's width, the height
        ldx #21
        ldy sbig
        beq @w
        lda #48
        ldx #42
@w      sta sstep
        stx sh
        ldy nspr                ; the width of them all
        cpy #2
        bcc @w1
        asl a
@w1     sta sw
        lda posset
        bne @set
        lda #<(320-8)           ; bottom right: 320 - w - 8, 200 - h - 8
        sec
        sbc sw
        sta px
        lda #>(320-8)
        sbc #0
        sta px+1
        lda #200-8
        sec
        sbc sh
        sta py
@set    lda #<320               ; inside: px <= 320 - w, py <= 200 - h
        sec
        sbc sw
        sta t0
        lda #>320
        sbc #0
        sta t1
        lda t1
        cmp px+1
        bcc @of
        bne @y
        lda t0
        cmp px
        bcc @of
@y      lda #200
        sec
        sbc sh
        cmp py
        bcs @in
@of     jmp @off
@in     lda nspr                ; +29 $d015
        lsr a
        lda #1
        bcs @m
        lda #3
@m      sta shead
        sta t7                  ; (the mask)
        lda px                  ; +30 x0 = px + 24, y0 = py + 50
        clc
        adc #24
        sta shead+1
        sta t0
        lda px+1
        adc #0
        sta t1
        beq @lo
        lda #1                  ; (+34 $d010)
        sta shead+5
@lo     lda py
        clc
        adc #50
        sta shead+2
        sta t2
        lda nspr
        cmp #2
        bcc @one
        lda t0                  ; +32 the second: x + 24 (48 big), y
        clc
        adc sstep
        sta shead+3
        lda t1
        adc #0
        beq @lo2
        lda shead+5
        ora #2
        sta shead+5
@lo2    lda t2
        sta shead+4
@one    lda smc                 ; +35 multicolour, its colours (+38, +39)
        beq @nm
        lda t7
        sta shead+6
        lda smca
        sta shead+9
        lda smcb
        sta shead+10
@nm     lda sbig                ; +36, +37 twice as wide and tall
        beq @nb
        lda t7
        sta shead+7
        sta shead+8
@nb     lda t2                  ; +40 their lines: y0 - 2 (y0 is 50 or
        sec                     ; more) to y0 + h + 2, 255 at most
        sbc #2
        sta shead+11
        lda t2
        clc
        adc sh
        bcs @ff
        adc #2
        bcc @hl
@ff     lda #255
@hl     sta shead+12
        lda flen                ; +42 the flash
        sta shead+13
        lda fspd
        sta shead+14
        ldx #0
@f      lda ftab,x
        sta shead+15,x
        inx
        cpx flen
        bcc @f
        clc
        rts
@off    ldx #<tx_off
        ldy #>tx_off
        jmp say

; ------------------------------------------------------------
; mkmod  the module's header: the template's first 78 bytes into lmhead,
; patched as tools/picturelm.py does; colat where the colours go
;   out:  c set if the sprites run off the picture (said)
; ------------------------------------------------------------
mkmod   ldx #77
@c      lda pl_lm,x
        sta lmhead,x
        dex
        bpl @c
        lda #48                 ; +12 the jitter
        ldx nspr
        beq @j
        lda #48+8
        cpx #2
        bcc @j
        lda #48+16
@j      sta lmhead+12
        lda #$ff                ; +13 no song (the tool's)
        sta lmhead+13
        lda #64                 ; +14 the share
        sta lmhead+14
        lda kbg                 ; +15 the background
        sta lmhead+15
        lda #0                  ; +25 bank 3
        sta lmhead+25
        lda #1                  ; +28 the ending (the fade: always), hires
        ldx ewait
        beq @w
        ora #2
@w      ldx phires
        beq @h
        ora #4
@h      sta lmhead+28
        lda nspr
        beq @ns
        jsr mkhead
        bcc @hd
        rts
@hd     ldx #46
@s      lda shead,x
        sta lmhead+29,x
        dex
        bpl @s
@ns     lda #0                  ; +76 the colours' place (a Koala picture's)
        sta colat
        sta colat+1
        lda phires
        bne @x
        lda #<(lmclaim+15)      ; (claim + 15) rounded down to 16
        and #$f0
        sta colat
        sta lmhead+76
        lda #>(lmclaim+15)
        sta colat+1
        sta lmhead+77
@x      clc
        rts

; ------------------------------------------------------------
; awrite  return: the module written (the picture's name, ending .lm)
; ------------------------------------------------------------
awrite  jsr needpic
        bcc @a
        rts
@a      jsr mkmod
        bcc @b
        rts
@b      ldx #<q_out
        ldy #>q_out
        jsr wname
        lda #13
        jsr chrout
        jsr wcreate
        bcc @c
        rts
@c      ldx #3                  ; (the file the output)
        jsr chkout
        lda #<lmbase            ; the main part: $c000, to $cfe7
        sta p2hd
        lda #>lmbase
        sta p2hd+1
        lda #<(lmscr+1000-lmbase)
        sta p2hd+2
        lda #>(lmscr+1000-lmbase)
        sta p2hd+3
        jsr wr4
        lda #78                 ; the header, made
        sta cnt
        ldy #0
        lda #<lmhead
        ldx #>lmhead
        jsr wrblk
        lda #<(lmlen-78)        ; the template's rest
        sta cnt
        ldy #>(lmlen-78)
        lda #<(pl_lm+78)
        ldx #>(pl_lm+78)
        jsr wrblk
        lda #<(lmbase+lmlen)    ; zeros to the colours (or the screen)
        sta t0
        lda #>(lmbase+lmlen)
        sta t1
        lda colat+1
        beq @nc
        ldx colat
        ldy colat+1
        jsr wzero
        lda kcol                ; the colours
        ldx kcol+1
        jsr w1000
        lda colat
        clc
        adc #<1000
        sta t0
        lda colat+1
        adc #>1000
        sta t1
@nc     ldx #<lmscr             ; zeros to the screen, the screen
        ldy #>lmscr
        jsr wzero
        lda kscr
        ldx kscr+1
        jsr w1000
        lda #<lmbit             ; the second part: $e000, the bitmap and
        sta p2hd                ; the sprites
        lda #>lmbit
        sta p2hd+1
        lda nspr
        lsr a
        ror a
        ror a                   ; 64 x nspr
        clc
        adc #<8000
        sta p2hd+2
        lda #>8000
        adc #0
        sta p2hd+3
        jsr wr4
        lda #<8000
        sta cnt
        ldy #>8000
        lda kbit
        ldx kbit+1
        jsr wrblk
        lda nspr
        beq @cl
        lsr a
        ror a
        ror a
        sta cnt
        ldy #0
        lda #<sprn
        ldx #>sprn
        jsr wrblk
@cl     jsr wclose
        bcs @x
        ldx #<tx_after
        ldy #>tx_after
        jmp say
@x      rts
p2hd    byte 0,0,0,0            ; a part's address and length

; wr4  p2hd's 4 bytes to the output
wr4     lda #4
        sta cnt
        ldy #0
        lda #<p2hd
        ldx #>p2hd
        jmp wrblk

; w1000  1,000 bytes from a/x to the output
w1000   pha
        lda #<1000
        sta cnt
        pla
        ldy #>1000
        jmp wrblk

; wzero  zeros from t0/t1 up to x/y (lo/hi): their count written from
; the page of zeros, a page at a time
wzero   txa
        sec
        sbc t0
        sta t2
        tya
        sbc t1
        sta t3
@l      lda t3
        beq @last
        lda #0                  ; a page
        sta cnt
        ldy #1
        lda #<zeros
        ldx #>zeros
        jsr wrblk
        dec t3
        jmp @l
@last   lda t2
        beq @x
        sta cnt
        ldy #0
        lda #<zeros
        ldx #>zeros
        jmp wrblk
@x      rts

; ------------------------------------------------------------
; ashow  s: the picture and the sprites as they will be (VIC bank 1);
; the joystick in port 2 moves the sprites, fire keeps the place, any
; key leaves them where they were
; ------------------------------------------------------------
ashow   jsr needpic
        bcc @go
        rts
@go     lda nspr
        beq @nh
        lda posset              ; (kept, to put back on a key)
        sta svset
        lda px
        sta svx
        lda px+1
        sta svx+1
        lda py
        sta svy
        jsr mkhead
        bcc @nh
        rts
@nh     lda #0                  ; the screen off while the picture goes in
        sta $d011
        lda kbit                ; the bitmap
        sta p1
        lda kbit+1
        sta p1+1
        lda #<pvbit
        sta p2
        lda #>pvbit
        sta p2+1
        lda #<8000
        ldx #>8000
        jsr copy
        lda kscr                ; the screen
        sta p1
        lda kscr+1
        sta p1+1
        lda #<pvscr
        sta p2
        lda #>pvscr
        sta p2+1
        lda #<1000
        ldx #>1000
        jsr copy
        lda phires              ; the colours (a Koala picture's)
        bne @nc
        lda kcol
        sta p1
        lda kcol+1
        sta p1+1
        lda #<$d800
        sta p2
        lda #>$d800
        sta p2+1
        lda #<1000
        ldx #>1000
        jsr copy
@nc     ldx #127                ; the sprites, at $4000 (pointers 0, 1)
@sp     lda sprn,x
        sta pvspr,x
        dex
        bpl @sp
        lda #0
        sta pvscr+$3f8
        lda #1
        sta pvscr+$3f9
        lda $dd02               ; VIC bank 1
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        ora #2
        sta $dd00
        lda #$38
        sta $d018
        ldx #$18
        lda phires
        beq @mc
        ldx #$08
@mc     stx $d016
        lda kbg
        sta $d021
        lda #0
        sta $d020
        sta fc
        sta fi
        jsr sprset
@vb     bit $d011               ; on in the vertical blank
        bpl @vb
        lda #$3b
        sta $d011
@fr     lda $d012               ; a frame: below the picture
        cmp #251
        bne @fr
@frm    lda nspr                ; (tests: once a frame)
        beq @key
        lda $dc00               ; the joystick: 1 a pixel a frame
        sta t6
        lsr a
        bcs @nu
        lda py
        beq @nu
        dec py
@nu     lsr t6
        lsr t6
        bcs @nd
        lda py
        clc
        adc sh
        cmp #200
        bcs @nd
        inc py
@nd     lsr t6
        bcs @nl
        lda px
        ora px+1
        beq @nl
        lda px
        bne @l1
        dec px+1
@l1     dec px
@nl     lsr t6
        bcs @nr
        lda px                  ; (px + w < 320)
        clc
        adc sw
        sta t0
        lda px+1
        adc #0
        cmp #>320
        bcc @r1
        lda t0
        cmp #<320
        bcs @nr
@r1     inc px
        bne @nr
        inc px+1
@nr     lda #1
        sta posset
        jsr mkhead
        jsr sprset
        jsr flash
        lsr t6                  ; fire: kept
        bcs @key
        jmp @done
@key    jsr getin
        bne @ky
        jmp @fr
@ky     lda nspr                ; a key: the place they had
        beq @done
        lda svset
        sta posset
        lda svx
        sta px
        lda svx+1
        sta px+1
        lda svy
        sta py
@done   lda #0
        sta $d015
        sta $d011
        lda $dd00               ; VIC bank 0 again
        ora #3
        sta $dd00
        lda #$c8
        sta $d016
        lda #$1b
        sta $d011
        clc
        rts
svset   byte 0
svx     word 0
svy     byte 0
fc      byte 0                  ; the flash: frames into this colour
fi      byte 0                  ; ... which

; sprset  the sprites from shead (as the module's sprinit)
sprset  lda nspr
        bne @s
        sta $d015
        rts
@s      ldx #3
@xy     lda shead+1,x
        sta $d000,x
        dex
        bpl @xy
        lda shead+5
        sta $d010
        lda shead+6
        sta $d01c
        lda shead+7
        sta $d01d
        lda shead+8
        sta $d017
        lda shead+9
        sta $d025
        lda shead+10
        sta $d026
        lda #0
        sta $d01b
        lda shead
        sta $d015
        rts

; flash  a frame of the flash: the next colour every fspd frames
flash   ldx fi
        lda ftab,x
        sta $d027
        sta $d028
        inc fc
        lda fc
        cmp fspd
        bcc @x
        lda #0
        sta fc
        inx
        cpx flen
        bcc @i
        ldx #0
@i      stx fi
@x      rts

; copy  a/x (lo/hi) bytes from p1 to p2
copy    sta t0
        stx t1
        ldy #0
@l      lda t0
        ora t1
        beq @x
        lda (p1),y
        sta (p2),y
        inc p1
        bne @1
        inc p1+1
@1      inc p2
        bne @2
        inc p2+1
@2      lda t0
        bne @3
        dec t1
@3      dec t0
        jmp @l
@x      rts

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

; ---- texts ----
tl1     text "picture     ",0      ; (12 each, so that the values line up at column 14:
tl2     text "sprites     ",0      ;   the user, 2026-11-06, "the PICTURE-LM menu looks like a
tl3     text " where      ",0      ;   mess": names and values ran together; the sprites'
tl4     text " colours    ",0      ;   own lines set in under them)
tl5     text " speed      ",0
tl6     text " mode       ",0
tl7     text " size       ",0
tl8     text "ending      ",0
tl9     text "write the module",0
tl10    text "show it",0
tl11    text "@ disk",0
tx_head text "           ",159,"*** ",5,"picture-lm",159," ***",13,151,"   a picture to a loader module",30,0
tx_bye  text "bye.",13,0
tx_koala text " (multi)",0
tx_hires text " (hires)",0
tx_none text "none",0
tx_br   text "bottom right",0
tx_fac  text " frames a colour",0
tx_no   text "hires",0
tx_mcw  text "multicolour ",0
tx_and  text " and ",0
tx_norm text "normal",0
tx_big  text "twice as big",0
tx_atonce text "the program starts at once",0
tx_pwait text "wait for space or fire",0
tx_mkeys text 155,"1-8: change  s: show  @: disk  q: quit",13,"return: write the module",30,0
tx_ttl  text 154,18," ",0       ; light blue, reverse
tx_ttle text 146,30,13,0        ; (off, green, the next row)
tx_anyk text 155,"press any key",30,0
tx_needp text "choose a picture first (1)",13,0
tx_needs text "choose the sprites first (2)",13,0
tx_ask  text "]? ",0
tx_reading text "reading it...",13,0
tx_long text "too long for one",13,0
tx_notpic text "not a picture it knows. ",0
tx_fmts text "multicolour: koala (and interpaint, face",13
        text "painter, run paint), advanced art studio,",13
        text "blazing paddles, artist 64, image",13
        text "system, saracen paint, vidcom 64,",13
        text "dolphin ed, drazpaint, micro illustrator,",13
        text "cdu-paint, paint magic. hires: art",13
        text "studio, doodle, image system, hi-eddi.",13
        text "unpacked files, as their tools save them",13,0
tx_isa  text "a picture in ",0
tx_notspr text "not one or two sprites (64 bytes each,",13,"63 will do, a .prg's load address first)",13,0
tx_badcol text "colours are hex digits: 0-9, a-f",13,0
tx_off  text "they run off the picture: move them (3)",13,0
tx_after text "choose it in slopload 64 (3: the module)",13,0
q_pdrive text "drive with the picture [",0
q_ddrive text "drive [",0
q_sdrive text "drive with the sprites [",0
tx_sprf text "one or two sprites, 64 bytes each (63",13,"will do; a .prg's load address skipped):",13
        text "cassette.spr on this disk is one",13,0
q_file  text "its file name ($: files, @: disk, return:",13,"keep it, -: none)? ",0
q_px    text "x, 0-319 (its left on the picture)? ",0
q_py    text "y, 0-199 [",0
q_cols  text "their colours, hex digits (1-32 of",13,"them: more flash)? ",0
q_spd   text "frames a colour [",0
q_mc    text "multicolour? y/n ",0
q_mca   text "its shared colour a (01) [",0
q_mcb   text "its shared colour b (11) [",0
q_big   text "twice as wide and tall? y/n ",0
q_wait  text "once it's in, wait for space or fire? y/n ",0
q_out   text "the module's name [",0

        incasm "piclm.asm"      ; the module (c64build.py): pl_lm, lmlen, lmclaim
bssend
