; ------------------------------------------------------------
; ui.asm  -  SlopLoad 64's menu: every setting on a line of its own,
; changed by its number at any time; return writes the tape (and the
; settings stay for the next one)
;
; The screen is cleared and the menu drawn whole each time (rows 0-13:
; the title, the machine, lines 1-9 and 0 in a row, the keys). A number
; puts that line's name in reverse on row 15 and its questions under
; it; when it is done, "press any key" and the menu again.
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
@nd     cmp #'0'
        bcc @k
        cmp #'9'+1
        bcs @k
        and #15                 ; 0-9: its line
        pha
        jsr ptitle
        pla
        asl a
        tax
        lda acts,x
        sta @j+1
        lda acts+1,x
        sta @j+2
@j      jsr @j                  ; (patched: the line's action)
        jsr anykey
        jmp ui
@go     lda #10                 ; "write the tape"
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
acts    word acol,aprog,aname,ashow,agame,amusic,apic,aspeed,astart,aout
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
; ptitle  line a's name (10: writing the tape) in reverse on row ttlrow,
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
        lda lablo,x
        ldy labhi,x
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
tx_write text "write the tape",0
tx_disk text "@ disk",0

; ------------------------------------------------------------
; mdraw  the screen cleared, the menu (rows 0-14)
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
        jmp @p1
@p0     jsr none
@p1     lda #2                  ; 2 name on tape
        jsr item0
        jsr prtname
        lda #3                  ; 3 show
        jsr item0
        ldx opt_show
        lda showlo,x
        ldy showhi,x
        tax
        jsr print
        ldx #1                  ; 4 module (grey when the show has none)
        jsr used
        lda #4
        jsr item0
        lda gok
        beq @g0
        lda gdev
        ldx #<gnlen
        ldy #>gnlen
        jsr prfile
        jmp @g1
@g0     jsr none
@g1     ldx #2                  ; 5 music
        jsr used
        lda #5
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
@m2     ldx #3                  ; 6 picture
        jsr used
        lda #6
        jsr item0
        lda kok
        beq @k0
        lda kdev
        ldx #<knlen
        ldy #>knlen
        jsr prfile
        jmp @k1
@k0     jsr none
@k1     lda #7                  ; 7 speed
        jsr item0
        jsr prspeed
        lda opt_speed
        cmp #spneg
        bne @sp
        ldx #<tx_sdef           ; 0: the default
        ldy #>tx_sdef
        jsr print
@sp     lda #8                  ; 8 start
        jsr item0
        lda opt_start
        ora opt_start+1
        bne @sys
        ldx #<tx_run
        ldy #>tx_run
        jsr print
        jmp @au
@sys    ldx #<tx_sys
        ldy #>tx_sys
        jsr print
        lda opt_start
        ldx opt_start+1
        jsr prhex4
@au     lda opt_auto
        beq @au0
        ldx #<tx_atonce
        ldy #>tx_atonce
        jsr print
@au0    lda #9                  ; 9 write to
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
        beq @o2
        lda #28
        jsr room
        bcs @o2
        ldx #<tx_onego
        ldy #>tx_onego
        jsr print
@o2     ldx #12                 ; 0 the loading lines' colours
        lda #0
        jsr item
        ldy opt_lines
        jsr prsname
        lda #' '
        jsr chrout
        ldy opt_lines
        lda #1                  ; (all 12 timer values)
        jsr prswatch
        ldx #13                 ; the keys
        ldy #0
        clc
        jsr plot
        ldx #<tx_keys
        ldy #>tx_keys
        jmp print
showlo  byte <tx_sh0,<tx_sh1,<tx_sh2,<tx_sh3,<tx_sh4
showhi  byte >tx_sh0,>tx_sh1,>tx_sh2,>tx_sh3,>tx_sh4
tx_sh0  text "nothing (the screen off)",0
tx_sh1  text "a loader module",0
tx_sh2  text "a picture",0
tx_sh3  text "a picture and music",0
tx_sh4  text "music",0
tx_head text 147,5,"            ",159,"*** ",5,"slopload",159," ***",13,152,0
tx_sdef text " (the default)",0
tx_run  text "run",0
tx_sys  text "sys ",0
tx_atonce text ", at once",0
tx_cass text "cassette",0
tx_onego text ", in one go",0
tx_keys text 155,"0-9: change  @: disk  return: write it",5,0

; item  line a's number and name (green) on row x; the value's colour
; next (white, or grey: used); item0: on the row after the last
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
        lda lablo,x
        ldy labhi,x
        tax
        jsr print
        lda usedc               ; the value: white, or grey if unused
        jsr chrout
        lda #5
        sta usedc
        rts
irow    byte 0
usedc   byte 5
lablo   byte <tl0,<tl1,<tl2,<tl3,<tl4,<tl5,<tl6,<tl7,<tl8,<tl9
labhi   byte >tl0,>tl1,>tl2,>tl3,>tl4,>tl5,>tl6,>tl7,>tl8,>tl9
tl0     text "colours   ",0
tl1     text "program   ",0
tl2     text "name      ",0
tl3     text "show      ",0
tl4     text "module    ",0
tl5     text "music     ",0
tl6     text "picture   ",0
tl7     text "speed     ",0
tl8     text "start     ",0
tl9     text "write to  ",0

; used  the next value grey unless the show uses it: x 1 a game, 2 a
; tune, 3 a picture (0: always used)
used    lda #5
        sta usedc
        txa
        beq @x
        ldy opt_show
        lda usetab,y
        and usebit,x
        bne @x
        lda #151
        sta usedc
@x      rts
usetab  byte 0,1+2,4,2+4,2      ; (game 1, tune 2, picture 4) by show
usebit  byte 0,1,2,4

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
@st     lda #0                  ; how it starts: RUN at $0801, else sys
        sta opt_start
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
@x      rts
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

; 3  what shows while it loads
ashow   ldx #<q_show
        ldy #>q_show
        jsr print
        lda opt_show
        ldx #<q_show2
        ldy #>q_show2
        jsr asknum
        bcs @x
        cmp #5
        bcs @x
        sta opt_show
@x      rts
q_show  text "0 nothing",13
        text "1 loader module",13
        text "2 picture",13
        text "3 picture and music",13
        text "4 music",13,0
q_show2 text "show [",0

; 4  the module: a .lm file
agame   lda gdev
        ldx #<sfx_lm
        ldy #>sfx_lm
        jsr pickfile
        bcs @x
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr ldgame
        bcs @x
        lda fdev
        sta gdev
        ldx #16
@c      lda fnlen,x
        sta gnlen,x
        dex
        bpl @c
        lda #1
        sta gok
        sta opt_show            ; (the show: this game)
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
        jmp chrout
@x      rts
sfx_lm  byte 3,$2e,$4c,$4d,0    ; ".lm"
tx_gok  text "a module, parts at ",0
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
        jsr chrout
        lda opt_show            ; (the show: music, or picture and music)
        bne @s2
        lda #4
        sta opt_show
@s2     cmp #2
        bne @x
        lda #3
        sta opt_show
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

; 6  the picture: a .koa
apic    lda kdev
        ldx #<sfx_koa
        ldy #>sfx_koa
        jsr pickfile
        bcs @x
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr ldpic
        bcs @x
        lda fdev
        sta kdev
        ldx #16
@c      lda fnlen,x
        sta knlen,x
        dex
        bpl @c
        lda opt_show            ; (the show: a picture, with its music)
        cmp #3
        beq @x
        cmp #4
        bne @p
        lda #3
        sta opt_show
        rts
@p      lda #2
        sta opt_show
@x      rts
sfx_koa byte 4,$2e,$4b,$4f,$41,0  ; ".koa"

; 7  the speed: -12 (the most margin) to 13 (opt_speed: the speed +
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

; 8  how it starts: sys (a program not at $0801), and at once or not
astart  lda pok
        beq @au
        lda paddr               ; at $0801: run
        cmp #$01
        bne @sys
        lda paddr+1
        cmp #$08
        beq @au
@sys    ldx #<q_start
        ldy #>q_start
        jsr print
        lda opt_start
        ldx opt_start+1
        jsr prhex4
        ldx #<q_end
        ldy #>q_end
        jsr print
        lda #6
        jsr readline
        lda inlen
        beq @au
        jsr inhex
        bcs @sys
        cpx #0                  ; (0 isn't one: it would be taken as RUN,
        bne @st                 ; and the program never started)
        cmp #0
        beq @sys
@st     sta opt_start
        stx opt_start+1
@au     lda #0
        sta opt_auto
        ldx #<q_auto
        ldy #>q_auto
        jsr print
        jsr askyn
        bne @x
        inc opt_auto
@x      rts
q_start text "start with sys [",0
q_end   text "]? ",0
q_auto  text "with a module or a show: start as soon",13,"as it is loaded? y/n [n] ",0

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

; 0  the loading lines' colours: a style (the pc's -stripes)
acol    ldx #0                  ; the styles, two a row: number, colours, name
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
        lda #2
        jsr prswatch
        lda #' '
        jsr chrout
        ldy t2
        jsr prsname
        lda t2
        lsr a
        bcs @r
        lda #19                 ; (the second column: "one colour" to 38)
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
        cpx #nmodes
        bcc @l
        lda opt_lines
        ldx #<q_col
        ldy #>q_col
        jsr asknum
        bcs @x
        cmp #nmodes
        bcs @x
        sta opt_lines
        cmp #st_one             ; one colour: which
        bne @x
        lda opt_fcol
        ldx #<q_fcol
        ldy #>q_fcol
        jsr asknum
        bcs @x
        cmp #16
        bcs @x
        sta opt_fcol
@x      rts
q_col   text "colours [",0
q_fcol  text "its colour 0-15 [",0

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
