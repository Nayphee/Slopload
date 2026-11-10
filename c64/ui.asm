; ------------------------------------------------------------
; ui.asm  -  SlopLoad 64's menu: every setting on a line of its own,
; changed by its number at any time; return masters the tape (and the
; settings stay for the next one)
;
; The screen is cleared and the menu drawn whole each time (rows 0-12:
; the title, the machine, lines 1-8 in a row, the keys). A number
; puts that line's name in reverse on row 15 and its questions under
; it; when it is done, "press any key" and the menu again. What shows
; while the program loads follows from lines 3 and 4: the module (with
; the tune, if any), the tune alone on a blank screen, or neither (the
; screen off). A picture is a module (PICTURE-LM makes one).
; ------------------------------------------------------------
pok     byte 0                  ; a program read
tnset   byte 0                  ; the name on tape typed (else the program's)
ttlrow  = 15                    ; the line being changed: its title's row

; ------------------------------------------------------------
; ui  the menu, until return with what it needs
;   out:  (c clear) ready to write
; ------------------------------------------------------------
uinit   lda #0
        sta $d020
        sta $d021
        rts
ui      jsr mdraw
@k      jsr getin
        beq @k
        cmp #13
        beq @go
        cmp #'@'                ; the disk: its directory, its commands
        bne @nd
        lda #11
        jsr ptitle
        jsr adisk
        jmp @j+3
@nd     cmp #'1'
        bcc @k
        cmp #'9'+1
        bcs @k
        and #15                 ; 1-9: its line
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
        jsr anykey
        jmp ui
@go     lda #10                 ; "master the tape"
        jsr ptitle
        lda pok                 ; a program?
        bne @c
        ldx #<tx_needp
        ldy #>tx_needp
        bne @no
@c      lda opt_out             ; a cassette: not with a SuperCPU
        bne @ok
        lda cpu
        cmp #2
        bne @ok
        ldx #<tx_notape
        ldy #>tx_notape
@no     jsr print
        jsr anykey
        jmp ui
@ok     clc
        rts
acts    word aprog,aname,agame,asecond,amusic,aspeed,acol,aeff,aout
tx_needp text "choose a program first (1)",13,0
tx_notape text "a supercpu can't reach the cassette:",13,"write a .tap file (9), or switch it off",13,0

; ------------------------------------------------------------
; anykey  "press any key" under what was said; a key
; ------------------------------------------------------------
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
tx_anyk text 155,"press any key",5,0

; ------------------------------------------------------------
; ptitle  line a's name (10: mastering the tape) in reverse on row ttlrow,
; the cursor under it
; ------------------------------------------------------------
ptitle  pha
        ldx #ttlrow
        ldy #0
        clc
        jsr plot
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
        lda lablo-1,x
        ldy labhi-1,x
        tax
        jmp @p
@w      ldx #<tx_write
        ldy #>tx_write
        cmp #10
        beq @p
        ldx #<tx_disk
        ldy #>tx_disk
@p      jsr print
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
tx_ttl  text 154,18," ",0       ; light blue, reverse
tx_ttle text 146,5,13,0         ; (off, white, the next row)
tx_write text "master the tape",0
tx_disk text "@ disk",0

; ------------------------------------------------------------
; mdraw  the screen cleared, the menu (rows 0-12)
; ------------------------------------------------------------
mdraw   ldx #<tx_head
        ldy #>tx_head
        jsr print
        jsr prmach              ; the machine, grey, centred on row 1
        jsr centre1
        ldx #3                  ; 1 program
        lda #1
        jsr item
        lda pok
        beq @p0
        lda prgdev
        ldx #<prglen
        ldy #>prglen
        jsr prfile
        lda #27                 ; its addresses, if they fit
        jsr room
        bcs @p1
        lda #' '
        jsr chrout
        jsr prrange
        lda opt_start           ; and sys (not at $0801), if it fits
        ora opt_start+1
        beq @p1
        lda #29
        jsr room
        bcs @p1
        ldx #<tx_sys
        ldy #>tx_sys
        jsr print
        lda opt_start
        ldx opt_start+1
        jsr prhex4
        jmp @p1
@p0     jsr none
@p1     lda #2                  ; 2 name on tape
        jsr item0
        jsr prtname
        lda #3                  ; 3 module
        jsr item0
        lda gok
        beq @g0
        lda gdev
        ldx #<gnlen
        ldy #>gnlen
        jsr prfile
        lda bok                 ; (its options, when it ends the load)
        bne @g1
        jsr propts
        jmp @g1
@g0     jsr none
@g1     lda #4                  ; 4 second module, after it
        jsr item0
        lda bok
        beq @b0
        lda bdev
        ldx #<bnlen
        ldy #>bnlen
        jsr prfile
        jsr propts
        jmp @b1
@b0     jsr none
@b1     lda #5                  ; 5 music
        jsr item0
        lda mok
        beq @m0
        cmp #2
        bne @m1
        lda #28                 ; refused: red (why: when it was read)
        jsr chrout
@m1     lda mdev
        ldx #<mnlen
        ldy #>mnlen
        jsr prfile
        jmp @m2
@m0     jsr none
@m2     lda #6                  ; 6 speed
        jsr item0
        jsr prspeed
        lda opt_speed
        cmp #spneg
        bne @sp
        ldx #<tx_sdef           ; 0: the default
        ldy #>tx_sdef
        jsr print
@sp     lda #7                  ; 7 colours: the palette, its colours
        jsr item0
        ldy opt_pal
        jsr prsname
        lda #' '
        jsr chrout
        ldy opt_pal
        jsr palst
        lda #1                  ; (all 12 timer values)
        jsr prswatch
        lda #8                  ; 8 effect
        jsr item0
        jsr prfx                ; (its name and value)
        lda opt_cyc             ; (the cycle: lnset keeps it where it goes)
        beq @cy
        ldx #<tx_pcyc
        ldy #>tx_pcyc
        jsr print
@cy     lda opt_showl           ; (on through the module or show)
        beq @au
        jsr lined
        bcc @au
        ldx #<tx_pshow
        ldy #>tx_pshow
        jsr print
@au     lda #9                  ; 9 write to
        jsr item0
        lda opt_out
        bne @tap
        ldx #<tx_cass
        ldy #>tx_cass
        jsr print
        jmp @o1
@tap    lda tapdev
        ldx #<tapfnl
        ldy #>tapfnl
        jsr prfile
@o1     lda xmem                ; in one go from the expansion memory
        beq @kp
        lda #28
        jsr room
        bcs @kp
        ldx #<tx_onego
        ldy #>tx_onego
        jsr print
@kp     ldx #12                 ; the keys
        ldy #0
        clc
        jsr plot
        ldx #<tx_keys
        ldy #>tx_keys
        jmp print
tx_head text 147,5,"            ",159,"*** ",5,"slopload",159," ***",13,152,0
tx_sdef text " (the default)",0
tx_sys  text " sys ",0
tx_cass text "cassette",0
tx_onego text ", in one go",0
tx_keys text 155,"1-9: change @: disk return: master tape",5,0

; propts  the module's options as the menu shows them: +wait, +count
propts  lda opt_gopt
        and #2
        beq @c
        ldx #<tx_pwait
        ldy #>tx_pwait
        jsr print
@c      lda opt_gopt
        and #8
        beq @x
        ldx #<tx_pcnt
        ldy #>tx_pcnt
        jmp print
@x      rts

; item  line a's number and name (green) on row x, the value white next;
; item0: on the row after the last
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
        lda #5
        jmp chrout
irow    byte 0
lablo   byte <tl1,<tl2,<tl3,<tl4,<tl5,<tl6,<tl7,<tl8,<tl9
labhi   byte >tl1,>tl2,>tl3,>tl4,>tl5,>tl6,>tl7,>tl8,>tl9
tl1     text "program   ",0
tl2     text "name      ",0
tl3     text "module    ",0
tl4     text "second    ",0
tl5     text "music     ",0
tl6     text "speed     ",0
tl7     text "colours   ",0
tl8     text "effect    ",0
tl9     text "write to  ",0

; room  c clear if the cursor is at column a or before
room    sta t0
        sec
        jsr plot
        cpy t0
        beq @y
        rts                     ; (c: past it)
@y      clc
        rts

; centre1  row 1 (the machine) centred: moved right by half what is left
centre1 ldy #39
@l      lda $0428,y
        cmp #' '
        bne @f
        dey
        bpl @l
        rts
@f      tya                     ; (its last column)
        eor #$ff
        sec
        adc #39
        lsr a                   ; (39 - last) / 2
        beq @x
        sta t0
@m      tya
        clc
        adc t0
        tax
        lda $0428,y
        sta $0428,x
        lda $d828,y
        sta $d828,x
        dey
        bpl @m
        ldy t0
        lda #' '
@s      dey
        sta $0428,y
        bne @s
@x      rts

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

; prrange  the program's addresses: "$0801-$1fff"
prrange lda paddr
        ldx paddr+1
        jsr prhex4
        lda #'-'
        jsr chrout
        lda pend
        sec
        sbc #1
        pha
        lda pend+1
        sbc #0
        tax
        pla
        jmp prhex4

; prtname  the name on tape, control codes as quote mode shows them
prtname lda tnlen
        beq @n
        ldx #0
@c      lda tname,x
        jsr prsafe
        inx
        cpx tnlen
        bcc @c
        rts
@n      jmp none

; prsname  style y's name
prsname ldx stnlo,y
        lda stnhi,y
        tay
        jmp print

; prswatch  style y's colours as reversed spaces, by timer value 0-11 in
; steps of a (1: 12 of them, 2: 6)
prswatch
        sty t1
        sta t3
        lda #18
        jsr chrout
        ldx #0
@c      txa
        ldy t1
        jsr stcol
        tay
        lda colcode,y
        jsr chrout
        lda #' '
        jsr chrout
        txa
        clc
        adc t3
        tax
        cpx #12
        bcc @c
        lda #146
        jsr chrout
        lda #5
        jmp chrout
colcode byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

; ------------------------------------------------------------
; the actions, one a line: their questions under the title
; ------------------------------------------------------------
; 1  the program: its drive and name, read through for its length
aprog   lda prgdev
        ldx #<q_drive
        ldy #>q_drive
        jsr asknum
        bcs @x
        cmp #8
        bcc @x
        cmp #31
        bcs @x
        sta prgdev
        ldx #<q_prog
        ldy #>q_prog
        jsr print
        lda #16
        jsr readline
        lda inlen
        beq @x
        sta prglen
        ldx #0
@cn     lda inbuf,x
        sta prgname,x
        inx
        cpx inlen
        bcc @cn
        lda #0
        sta pok
        jsr prepass
        bcs @x
        inc pok
        jsr prpinfo             ; what it is
        lda tnset               ; the name on tape: the program's, unless typed
        bne @st
        jsr tnprog
@st     lda #0                  ; how it starts: RUN at $0801, else sys,
        sta opt_start           ; asked (its load address unless another)
        sta opt_start+1
        lda paddr
        cmp #$01
        bne @sys
        lda paddr+1
        cmp #$08
        beq @x
@sys    lda paddr
        sta opt_start
        lda paddr+1
        sta opt_start+1
        bne askst               ; (never 0: it's past $0801)
@x      rts
askst   ldx #<q_start
        ldy #>q_start
        jsr print
        lda opt_start
        ldx opt_start+1
        jsr prhex4
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #6
        jsr readline
        lda inlen
        beq @x
        jsr inhex
        bcs askst
        cpx #0                  ; (0 isn't one: it would be taken as RUN,
        bne @a                  ; and the program never started)
        cmp #0
        beq askst
@a      sta opt_start
        stx opt_start+1
@x      rts
q_start text "it isn't at $0801: start with sys [",0
q_drive text "drive with the program [",0
q_prog  text "its file name? ",0

; prpinfo  "$0801-$1fff, 6143 bytes"
prpinfo jsr prrange
        lda #','
        jsr chrout
        lda #' '
        jsr chrout
        lda plen
        ldx plen+1
        jsr prdec16
        ldx #<tx_bytes
        ldy #>tx_bytes
        jmp print
tx_bytes text " bytes",13,0

; tnprog  the name on tape: the program's
tnprog  ldx prglen
        stx tnlen
@c      dex
        bmi @x
        lda prgname,x
        sta tname,x
        jmp @c
@x      rts

; 2  the name on tape: any keys, control keys too (what the tape's FOUND
; shows: clr, home, colours, reverse...), shown as quote mode shows them
aname   ldx #<q_tname
        ldy #>q_tname
        jsr print
        lda #16
        jsr readname
        lda inlen
        bne @t
        lda #0                  ; (return: the program's)
        sta tnset
        jmp tnprog
@t      sta tnlen
        lda #1
        sta tnset
        ldx #0
@c      lda inbuf,x
        sta tname,x
        inx
        cpx tnlen
        bcc @c
        rts
q_tname text "the name after found (16 keys; clr,",13
        text "colours too). return: the program's",13,"? ",0

; 3  the module: a .lm file (a game, a loading screen, a picture:
; PICTURE-LM makes one); 0: none. Another one clears line 4's second
agame   ldx #<tx_mod0
        ldy #>tx_mod0
        jsr print
        lda gdev
        ldx #<sfx_lm
        ldy #>sfx_lm
        jsr pickfile
        bcc @rd
        lda pkzero              ; 0: none (and no second, no options)
        beq @x0
        lda #0
        sta gok
        sta bok
        sta opt_gopt
@x0     rts
@rd     lda #0                  ; (a new first: no second)
        sta bok
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr ldgame
        bcc @ok
        rts
@ok
        lda fdev
        sta gdev
        ldx #16
@c      lda fnlen,x
        sta gnlen,x
        dex
        bpl @c
        lda #1
        sta gok
        ldx #<tx_gok
        ldy #>tx_gok
        jsr print
        ldx #0                  ; its parts
@p      stx t6
        lda gpal,x
        pha
        lda gpah,x
        tax
        pla
        jsr prhex4
        lda #' '
        jsr chrout
        ldx t6
        inx
        cpx gnp
        bcc @p
        lda #13
        jsr chrout
        jmp askopt

; 4  the second module, after the first (a chain, the PC tool's -then):
; the first shows while the second's parts load, then the second while
; the program loads; 0: none
asecond lda gok
        bne @ok
        ldx #<tx_first
        ldy #>tx_first
        jmp print
@ok     ldx #<tx_mod0
        ldy #>tx_mod0
        jsr print
        jsr athen               ; (chain.asm)
        lda #1                  ; (the first stays chosen, whatever the second)
        sta gok

; askopt  the tool's options the module that ends the load keeps (its
; +27 bits 2, 3: -wait, -countdown): asked, else off
askopt  lda gbord
        ldx bok
        beq @kb
        lda bbord
@kb     sta kbord
        lda #0                  ; the tool's options it keeps (its +27 bits
        sta opt_gopt            ; 2, 3): asked, else off
        lda kbord
        and #4
        beq @nw
        ldx #<q_gwait
        ldy #>q_gwait
        jsr ynq
        asl a                   ; y: bit 1 (-wait)
        sta opt_gopt
@nw     lda kbord
        and #8
        beq @x
        ldx #<q_gcnt
        ldy #>q_gcnt
        jsr ynq
        beq @x
        lda opt_gopt
        ora #8                  ; y: bit 3 (-countdown)
        sta opt_gopt
@x      rts
sfx_lm  byte 3,$2e,$4c,$4d,0    ; ".lm"
tx_mod0 text "a .lm (pictures: picture-lm); 0: none",13,0
tx_gok  text "a module, parts at ",0
tx_first text "choose a module first (3)",13,0
q_gwait text "once loaded, wait for space or the game's",13,"end? y/n [n] ",0
q_gcnt  text "count the blocks down? y/n [n] ",0
tx_reading text "reading it...",13,0

; 5  the music: a .slm (0: none); a .sid is refused: SID-SLM makes one
amusic  ldx #<tx_mus0
        ldy #>tx_mus0
        jsr print
        lda mdev
        ldx #<sfx_mus
        ldy #>sfx_mus
        jsr pickfile
        bcc @f
        lda pkzero              ; 0: none
        beq @x
        lda #0
        sta mok
        rts
@f      ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr ldmus
        bcs @x
        lda fdev
        sta mdev
        ldx #16
@c      lda fnlen,x
        sta mnlen,x
        dex
        bpl @c
        lda mok                 ; what it is: its name, or why not
        cmp #2
        beq @r
        ldx #0
@mt     lda mtitle,x
        beq @mte
        jsr chrout
        inx
        cpx #32
        bcc @mt
@mte    lda #13
        jmp chrout              ; (it fades out at the end, as every module's tune)
@x      rts
@r      jmp prwhyr
; prwhyr  why the tune was refused, in red, and a new line
prwhyr  lda #28
        jsr chrout
        jsr prwhy2
        lda #5
        jsr chrout
        lda #13
        jmp chrout
sfx_mus byte 4,$2e,$53,$4c,$4d,0  ; ".slm"
tx_mus0 text "a .slm (sid-slm makes one); 0: none",13,0

; 6  the speed: -12 (the most margin) to 13 (opt_speed: the speed +
; spneg). A minus anywhere makes it below 0 (a space for innum, which
; skips them)
aspeed  ldx #<q_speed
        ldy #>q_speed
        jsr print
        jsr prspeed             ; [the speed now]
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #3
        jsr readline
        ldx #0
        stx t5
@m      cpx inlen
        beq @n
        lda inbuf,x
        cmp #'-'
        bne @nx
        lda #' '
        sta inbuf,x
        sta t5                  ; (non-zero: below 0)
@nx     inx
        bne @m
@n      jsr innum
        bcs @x                  ; empty, or not a number: as it was
        ldx t5
        beq @p
        sta t1                  ; -n: spneg - n
        lda #spneg
        sec
        sbc t1
        bcc @x                  ; (below -12)
        bcs @s
@p      clc                     ; n: spneg + n
        adc #spneg
        bcs @x
        cmp #nspeed
        bcs @x                  ; (above 13)
@s      sta opt_speed
@x      rts
q_speed text "speed -12 (safest) to 13 [",0

; prspeed  the speed: opt_speed less spneg, a minus below 0
prspeed lda opt_speed
        sec
        sbc #spneg
        bcs @p
        eor #$ff
        adc #1                  ; (carry clear) its size
        pha
        lda #'-'
        jsr chrout
        pla
@p      ldx #0
        jmp prdec16

; 9  cassette or a .tap file (its drive and name); with expansion
; memory, in one go from it or a block at a time
aout    lda #1
        clc
        adc opt_out
        ldx #<q_out
        ldy #>q_out
        jsr asknum
        bcs @xm
        cmp #1
        bcc @xm
        cmp #3
        bcs @xm
        sbc #0                  ; (carry clear) 1 -> 0, 2 -> 1
        sta opt_out
        beq @xm
@td     lda tapdev              ; the .tap file's drive and name
        ldx #<q_tdrive
        ldy #>q_tdrive
        jsr asknum
        bcs @td
        cmp #8
        bcc @td
        cmp #31
        bcs @td
        sta tapdev
        ldx #<q_tfile
        ldy #>q_tfile
        jsr print
        lda #16
        jsr readline
        lda inlen
        bne @tf
        ldx #0                  ; (return: the name on tape's printable
        ldy #0                  ; characters, at most 12, then .tap)
@t2     cpx tnlen
        bcs @t2e
        lda tname,x
        inx
        cmp #' '
        bcc @t2
        cmp #$80
        bcc @t2k
        cmp #$a0
        bcc @t2
@t2k    sta tapfname,y
        iny
        cpy #12
        bcc @t2
@t2e    ldx #0
@t3     lda tx_dottap,x
        sta tapfname,y
        iny
        inx
        cpx #4
        bcc @t3
        sty tapfnl
        jmp @xm
@tf     sta tapfnl
        tax
@t4     dex
        lda inbuf,x
        sta tapfname,x
        txa
        bne @t4
@xm     lda xkind               ; in one go from the expansion memory?
        beq @x
        lda #0
        sta xmem
        ldx #<q_xmem
        ldy #>q_xmem
        jsr print
        jsr askyn
        cmp #'n'
        beq @x
        lda xkind
        sta xmem
@x      rts
q_out   text "write to: 1 cassette  2 .tap file [",0
q_tdrive text "drive for the .tap file [",0
q_tfile text ".tap file [name on tape.tap]? ",0
tx_dottap text ".tap"
q_xmem  text "write it in one go from the expansion",13,"memory? y/n [y] ",0

; 7  the colours: a palette, as the pc's -stripes NAME (a style: rainbow
; to black), or your own (1 to 12 colours, as -stripes 6,14,3; one alone
; a plain border). The standard effect draws them as stripes; the others
; start from the first (line 8)
acol    ldx #0                  ; the palettes, two a row: number, colours, name
@l      stx t2
        cpx #10
        bcs @nn
        lda #' '
        jsr chrout
@nn     txa
        ldx #0
        jsr prdec16
        lda #' '
        jsr chrout
        ldy t2
        jsr palst
        lda #2
        jsr prswatch
        lda #' '
        jsr chrout
        ldy t2
        jsr prsname
        lda t2
        lsr a
        bcs @r
        lda #19                 ; (the second column)
        sta t0
        sec
        jsr plot
        ldy t0
        clc
        jsr plot
        jmp @n
@r      lda #13
        jsr chrout
@n      ldx t2
        inx
        cpx #npal
        bcc @l
        lda #13
        jsr chrout
        lda opt_pal
        ldx #<q_col
        ldy #>q_col
        jsr asknum
        bcs @x
        cmp #npal
        bcs @x
        sta t2
        cmp #npal-1             ; your own: its colours
        bne @s
        ldx #<q_own
        ldy #>q_own
        jsr print
        jsr prown
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #36
        jsr readline
        jsr ownin
        bcs @x
@s      lda t2
        sta opt_pal
        jmp lnset
@x      rts
q_col   text "colours [",0
q_own   text "your own, 1-12 of 0-15 [",0

; 8  the effect: 1 standard (the colours as stripes, SlopLoad's own), 2-7
; the classic loaders' (the pc's -stripes classic ... eor:N, from the
; colours' first), 8 a colour a block (-stripes block); its value (and,
; ora, eor); then the cycle, where it goes, and the lines on through the
; module or the music
aeff    ldx #0                  ; the effects: number and name
@l      stx t2
        txa
        clc
        adc #1
        ldx #0
        jsr prdec16
        lda #' '
        jsr chrout
        ldx t2
        lda effnlo,x
        ldy effnhi,x
        tax
        jsr print
        lda #' '
        jsr chrout
        ldx t2
        inx
        cpx #neff
        bcc @l
        lda #13
        jsr chrout
        lda opt_eff
        clc
        adc #1
        ldx #<q_fx
        ldy #>q_fx
        jsr asknum
        bcs @q
        cmp #1
        bcc @q
        cmp #neff+1
        bcs @q
        sbc #0                  ; (c clear: one less)
        sta opt_eff
        tax
        dex
        cpx #nfxs
        bcs @q                  ; (standard, block: no value)
        lda fxval,x
        beq @q
        lda opt_fxn
        ldx #<q_fxn
        ldy #>q_fxn
        jsr asknum
        bcs @q
        cmp #16
        bcs @q
        sta opt_fxn
@q      jsr lnset
        jsr cycok               ; the cycle, where it goes
        bcc @l2
        ldx #<q_cyc
        ldy #>q_cyc
        jsr ynq
        sta opt_cyc
@l2     jsr lined               ; bars (or the cycle): during the module too?
        bcc @x
        ldx #<q_showl
        ldy #>q_showl
        jsr ynq
        sta opt_showl
@x      rts
q_fx    text "effect [",0
q_fxn   text "its value 0-15 [",0
q_cyc   text "a colour on each page loaded? y/n [n] ",0
q_showl text "bars during the module or music? y/n [n] ",0

; lnset  opt_lines (and opt_fcol, opt_fx, opt_fxb) from the colours
; (opt_pal, ownl) and the effect (opt_eff), as tools/c64model.py's
; lines_for; the cycle off where it can't go
;   uses: a, x, y, p3
lnset   ldx opt_eff
        beq @std
        lda #st_block
        cpx #neff-1
        beq @set                ; (a colour a block)
        dex                     ; an effect, from the colours' first
        stx opt_fx
        ldy opt_pal
        jsr palst
        lda #0
        jsr stcol
        sta opt_fxb
        lda #st_fx
        bne @set
@std    lda opt_pal             ; standard: a style's number (black: st_black)
        cmp #npal-1
        bne @set
        lda #st_own             ; your own: two or more, a list
        ldx ownl
        dex
        bne @set
        lda ownl+1              ; one: that colour (core_flat)
        sta opt_fcol
        lda #st_one
@set    sta opt_lines
        jsr cycok
        bcs @x
        lda #0
        sta opt_cyc
@x      rts

; cycok  c set when the cycle can go: an effect, black or one colour
cycok   lda opt_lines
        cmp #st_fx
        beq @y
        cmp #st_black
        beq @y
        cmp #st_one
        beq @y
        clc
        rts
@y      sec
        rts

; palst  y: palette y's style (your own: st_own)
palst   cpy #npal-1
        bne @x
        ldy #st_own
@x      rts

; ownin  your own colours from inbuf: 1 to 12 of 0-15, apart by commas
; or spaces, to ownl (an empty line keeps it); c set if not (as it was)
;   uses: a, x, y, t0, t1, dsbuf
ownin   ldx #0
        ldy #0
        lda inlen
        beq @ok
@nx     lda #$ff                ; (no digits yet)
        sta t0
@c      cpx inlen
        beq @end
        lda inbuf,x
        inx
        cmp #','
        beq @sep
        cmp #' '
        beq @sep
        sec
        sbc #'0'
        cmp #10
        bcs @bad
        sta t1
        lda t0
        bmi @d0                 ; (the first digit)
        beq @d0                 ; (0 then a digit: the digit)
        cmp #1
        bne @bad
        lda t1                  ; 1 then a digit: 10-15
        adc #9                  ; (c set: + 10)
        cmp #16
        bcs @bad
        bcc @st
@d0     lda t1
@st     sta t0
        jmp @c
@sep    jsr @put
        bcs @bad
        bcc @nx
@end    jsr @put
        bcs @bad
        tya
        beq @bad                ; (none)
        sta ownl
@cp     lda dsbuf-1,y
        sta ownl,y
        dey
        bne @cp
@ok     clc
        rts
@put    lda t0                  ; the number ended: kept (12 at most)
        bmi @ok
        cpy #12
        bcs @bad
        sta dsbuf,y
        iny
        clc
        rts
@bad    sec
        rts

; prown  your own colours: "6,14,3"
prown   ldy #1
@l      sty t6
        cpy #2
        bcc @n
        lda #','
        jsr chrout
@n      ldy t6
        lda ownl,y
        ldx #0
        jsr prdec16
        ldy t6
        cpy ownl
        iny
        bcc @l
        rts

; prfx  the effect's name, and its value (and, ora, eor)
prfx    ldx opt_eff
        lda effnlo,x
        ldy effnhi,x
        tax
        jsr print
        ldx opt_eff
        dex
        cpx #nfxs
        bcs @x                  ; (standard, block)
        lda fxval,x
        beq @x
        lda #' '
        jsr chrout
        lda opt_fxn
        ldx #0
        jmp prdec16
@x      rts

; ynq  the question at x/y, answered y or n: a = 1 for y
ynq     jsr print
        jsr askyn
        ldx #0
        cmp #'y'
        bne @n
        inx
@n      txa
        rts
tx_pshow text " +during",0
tx_pcyc text " +cycle",0
tx_pwait text " +wait",0
tx_pcnt text " +count",0

; @  a drive's directory and its commands (the command channel), until
; return alone
adisk   lda ddev
        ldx #<q_fdrive
        ldy #>q_fdrive
        jsr asknum
        bcs @x
        cmp #8
        bcc @x
        cmp #31
        bcs @x
        sta ddev
        jmp dcmd                ; (disk.asm)
@x      rts

; askyn  a y or an n (a line of one): a = its first key, z set if y
askyn   lda #1
        jsr readline
        lda inbuf
        ldx inlen
        bne @k
        lda #0
@k      cmp #'y'
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
        bne @x                  ; not a number: c set
        lda t5                  ; empty: the default
        clc
@x      rts
tx_ask  text "]? ",0

; ------------------------------------------------------------
; prepass  the program read through: paddr, plen, pend (said)
;   out:  c set if it can't be read or doesn't fit
; ------------------------------------------------------------
prepass ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr openprg
        bcc @o
        rts
@o      lda #0
        sta plen
        sta plen+1
@r      jsr rdbyte
        bcs @e
        inc plen
        bne @r
        inc plen+1
        bne @r
        jmp @big                ; (64 KB: too big)
@e      jsr closeprg
        lda rderr               ; a read error: not the program's end
        beq @n
        ldx #<tx_rderr
        ldy #>tx_rderr
        jsr print
        sec
        rts
@n
        lda paddr
        clc
        adc plen
        sta pend
        lda paddr+1
        adc plen+1
        sta pend+1
        bcs @big
        lda paddr               ; $0801 on? (the loader has $0000-$07ff)
        cmp #<$0800
        lda paddr+1
        sbc #>$0800
        bcc @big
        lda pend                ; to $fff9 (the cpu's vectors are the loader's):
        cmp #<$fffb             ; its end + 1 at most $fffa
        lda pend+1
        sbc #>$fffb
        bcs @big
        lda plen
        ora plen+1
        beq @big
        clc
        rts
@big    jsr closeprg
        ldx #<tx_nofit
        ldy #>tx_nofit
        jsr print
        sec
        rts
tx_nofit text "it must be in $0801-$fff9",13,0
