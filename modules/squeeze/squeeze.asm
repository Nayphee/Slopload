; ------------------------------------------------------------
; squeeze.asm  -  Squeeze-Load: steer a rocket up a shaft while
; steel girders, each with a gap, fall down it. Left and right on the
; joystick in port 2 slip it through each gap; every few girders the
; fall speeds up, the gaps narrow and the colours change. Touch a
; girder and the round is over. A SlopLoad module (MODULES.md).
;
; The girders fall smoothly with no vertical scrolling: they all
; share one line in their row (phase, 0-7), and six characters (solid,
; and the two ends at a gap, for even and odd rows) are redrawn for it
; in the vertical blank. A girder covers two rows: its upper row shows
; the girder's lines 0..7-p at the bottom (the "upper" glyph), its lower
; row lines 8-p..7 at the top (the "lower" glyph). Girders are an even
; number of rows apart, so every upper row has the same parity and the
; glyphs go by parity. When the phase passes 7 the parity flips and the
; phase is 0: the old upper row and the new lower row then both show the
; lower glyph at phase 0, which is blank, so their screen codes are
; changed the tick after (stepdraw) wherever the beam is, unseen.
;
; The rocket is one multicolour sprite (one on any raster line:
; g_jitter has the 8 cycles it costs). Collisions go by what is drawn:
; each of the rocket's rows against the girders' lines (a girder line
; is coloured all the way across, the gap excepted), in the state the
; next frame shows.
;
; Memory (vic bank 3): characters $e000-$e3ff (the header is
; characters 0-3), the screen $e400 (the character set's other half,
; never read as glyphs), the sprite frames $e800-$e8bf, code after.
; Zero page $10-$68.
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
scra = $e400                    ; one screen: the kit's two are the same
scrb = scra
d018v = $98                     ; screen $e400, characters $e000
chr = $e000                     ; the character set
sprblk = $e800                  ; the rocket's frames (64 bytes each)
sprp0 = $a0                     ; ... their first pointer: ($e800 - $c000) / 64
sprptr = scra+$3f8              ; sprite 0's pointer

; ---- the standard parts ----
g_claim = codeend               ; end of the memory claimed
g_jitter = 56                   ; 48 + 8 for the sprite (MODULES.md); measured (tests/jitter.py
                                ; --module squeeze --auto 2): 99.9% 52 pal, 53 ntsc and c128; max 60
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 1                       ; it makes effects on voice 3 (beside SlopLoad's player)
g_wait = 1                      ; with -wait it plays on until SPACE or a game's end (the kit's)
g_count = 1                     ; with -countdown its status line counts blocks (the kit's)
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; the status bar: 9 characters, 1 px a step
gk_srow = 24*40                 ; the status line: row 24

; ---- the shaft ----
f0 = 2                          ; the field's first row
fl = 22                         ; ... and last (row 23 is the floor)
fc0 = 4                         ; the field's first column (32 of them: 256 px)
fcols = 32
msgrow = 1                      ; the message row
spacing = 6                     ; rows from one girder to the next (even)
maxw = 8                        ; the girder ring's size
shipy = 168                     ; the rocket's top row, in screen pixels
spry = shipy+50                 ; ... its sprite's y (screen pixel 0 = sprite y 50)
maxx = 255-ship_maxr            ; the rocket's x: 0 to this (field pixels)
fcol = 9                        ; the field's colour ram: multicolour, white highlights
rcol = 14                       ; the rock's: multicolour, blue grains
dark = 11                       ; $d023: dark grey (girders' undersides, the rock)
lockout = 50                    ; ticks before game over takes fire
perlevel = 5                    ; girders to a level
toplevel = 11                   ; the last row of the level table
showhit = 8                     ; ticks the rocket shows where it hit, before the burst

; ---- states ----
st_title = 0
st_play = 1
st_over = 2
st_wipe = 3                     ; the field being cleared for a round

; ---- zero page ($10-$8f; $70-$7f is the music player's) ----
st = $10                        ; state
tmr = $11                       ; ticks in this state (stays at 255)
frm = $12                       ; tick counter (kit)
ntscc = $13                     ; ntsc: 5 ticks in 6 frames
fire = $14                      ; (kit) $10 while held
fpress = $15                    ; (kit) $10: pressed this tick
spc = $16                       ; (kit) space held
skey = $17                      ; (kit) s held
exitreq = $18                   ; (kit) 1: start the program
smode = $19                     ; (kit) status line drawn: mode
sprog = $1a                     ; (kit) ... and progress
musicon = $1b                   ; (kit) 1: music playing
rnd = $1c                       ; (kit) 2 bytes
tmp = $1e                       ; (kit) scratch
tmp2 = $1f
tmp3 = $20
pt2 = $21                       ; (kit) 2
sbcell = $23                    ; (kit) the bar's last filled cell
pt = $24                        ; 2
phase = $26                     ; the girders' line in their row, as shown next (0-7)
pos16 = $27                     ; ... in 1/16 lines (0-127)
par = $28                       ; the parity of the girders' upper rows
stepw = $29                     ; 1: a coarse step's screen codes are due (this tick)
speed = $2a                     ; the fall, 1/16 lines a tick
level = $2b                     ; 0 on
lvcnt = $2c                     ; girders to the next level
shipx = $2d                     ; the rocket's left, in field pixels (0-maxx)
scl = $2e                       ; score, bcd: low two digits
sch = $2f                       ; ... high two
bestl = $30                     ; the best score, bcd
besth = $31
nw = $32                        ; girders in the ring
wh = $33                        ; the ring's lowest girder
sfxp = $34                      ; the effect: its place in sfxdat (0: none)
sfxc = $35                      ; ... its last control byte
msgt = $36                      ; ticks the message row stays (0: for good)
lastgx = $37                    ; the newest girder's gap
wipe = $38                      ; the wipe's next row
fframe = $39                    ; the rocket's frame shown (0, 1: flame; 2: burst)
shipcol = $3a                   ; its colour
gw = $3b                        ; the level's gap width (columns)
ms = $3c                        ; ... the most a gap moves from the last (columns)
pspeed = $3d                    ; ... the rocket's speed (pixels a tick)
gl = $3e                        ; collide: the gap's first pixel
gr = $3f                        ; ... the first past it
wrow = $40                      ; the ring (maxw each): a girder's upper row (1-23)
wgx = $48                       ; ... its gap's first field column
wgw = $50                       ; ... the gap's width
wpass = $58                     ; ... 1 once it is below the rocket
lxp = $60                       ; collide: the frame's row extents (2)
rxp = $62                       ; (2)
srend = $64                     ; collide: the rocket's row past the last to look at
wtop = $65                      ; collide: the girder's top line
target = $66                    ; autosteer: where to go
cpt = $67                       ; ctext: the colour ram (2)
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: 1 plays until the program is in, 2 never loses

*=$e000
        incasm "modhead.asm"
        incasm "chars.asm"

*=sprblk
        incasm "sprites.asm"

; ------------------------------------------------------------
; init  once, the screen off: set up, draw, start the music
; ------------------------------------------------------------
init    jsr gk_musinit          ; first: the header is characters 0-3
        lda #$0b
        sta $d011               ; (screen off: frame turns it on)
        ldx #$5f                ; zero page $10-$6f clear
        lda #0
@z      sta $10,x
        dex
        bpl @z
        sta $d015
        jsr gk_bord             ; (the border: gk_bord, never sta $d020)
        sta $d021
        sta dbg_space
        sta dbg_auto
        sta $d017               ; the sprite: normal size, in front
        sta $d01d
        sta $d01b
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc                ; vic bank 3
        sta $dd00
        lda #d018v
        sta $d018
        lda #$18
        sta $d016               ; multicolour, 40 columns
        lda #dark
        sta $d023
        lda #6
        sta ntscc
        lda #$a7
        sta rnd
        sta rnd+1
        lda #$ff
        sta smode               ; (the status line: drawn at the first frame)
        lda #1                  ; the rocket: multicolour, red and yellow, white
        sta $d01c
        sta shipcol
        lda #2
        sta $d025
        lda #7
        sta $d026
        lda #spry
        sta $d001
        lda #(maxx+1)/2
        sta shipx
        jsr vbwork              ; (the sprite where it goes, before it shows)
        lda #1
        sta $d015
        jsr drawall
        jsr drawhud
        jsr sidinit
        jsr musicgo
        lda #7                  ; the title, in the field (hi-res colours)
        sta tcol
        ldx #<tx_title
        ldy #>tx_title
        lda #6
        jsr ctext
        lda #1
        sta tcol
        ldx #<tx_t1
        ldy #>tx_t1
        lda #9
        jsr ctext
        ldx #<tx_t2
        ldy #>tx_t2
        lda #11
        jsr ctext
        lda #3
        sta tcol
        ldx #<tx_t3
        ldy #>tx_t3
        lda #14
        jsr ctext
        lda #7
        sta tcol
        ldx #<tx_t4
        ldy #>tx_t4
        lda #17
        jmp ctext

; ------------------------------------------------------------
; stop  silence; the core blanks the screen (and the sprite) after
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
@s      lda #0
        sta $d418
        sta $d412
        rts

; ------------------------------------------------------------
; frame  one frame: the vertical blank, one tick, the status line
;   out:  carry set when the program should start
; ------------------------------------------------------------
frame
@w0     lda $d012               ; the last vertical blank over (line 0-250):
        cmp #251                ; the low byte first, then bit 8 (read the
        bcs @w0                 ; other way round, line 255 then 256 looks
        bit $d011               ; like line 0)
        bmi @w0
@w      bit $d011               ; then this one: line 251 on
        bmi @vb
        lda $d012
        cmp #251
        bcc @w
@vb     lda #$1b                ; screen on, 25 rows
        sta $d011
        jsr vbwork
        lda ld_state
        lsr a
        bcc @tick               ; pal: every frame
        dec ntscc
        bne @tick
        lda #6
        sta ntscc
        bne @held               ; ntsc: hold every sixth
@tick   jsr tick
@held   jsr status
        jmp gk_exit             ; (c set: end, the music faded out first)

; ------------------------------------------------------------
; vbwork  in the vertical blank: what the last tick decided, shown.
; The girders' six glyphs for the phase and parity, the rocket (x,
; frame, colour), the level's colour; the wipe's rows
; ------------------------------------------------------------
vbwork  lda #8
        sec
        sbc phase
        tax                     ; the upper glyph from 8 - p, the lower from 16 - p
        ldy #0
        lda par
        bne @odd
@ev     lda strip0,x            ; upper rows even: characters 4-6 upper,
        sta chr+4*8,y           ; 7-9 lower
        lda strip0+8,x
        sta chr+7*8,y
        lda strip1,x
        sta chr+5*8,y
        lda strip1+8,x
        sta chr+8*8,y
        lda strip2,x
        sta chr+6*8,y
        lda strip2+8,x
        sta chr+9*8,y
        inx
        iny
        cpy #8
        bne @ev
        beq @spr
@odd    lda strip0,x            ; upper rows odd: 7-9 upper, 4-6 lower
        sta chr+7*8,y
        lda strip0+8,x
        sta chr+4*8,y
        lda strip1,x
        sta chr+8*8,y
        lda strip1+8,x
        sta chr+5*8,y
        lda strip2,x
        sta chr+9*8,y
        lda strip2+8,x
        sta chr+6*8,y
        inx
        iny
        cpy #8
        bne @odd
@spr    lda shipx               ; sprite x: 24 + 32 (the field) - 6 (the rocket
        clc                     ; in its sprite) + x
        adc #50
        sta $d000
        lda #0
        rol a
        sta $d010
        lda fframe
        clc
        adc #sprp0
        sta sprptr
        lda shipcol
        sta $d027
        lda level
        and #7
        tax
        lda theme,x
        sta $d022
        lda st
        cmp #st_wipe
        bne @x
        jsr wiperow             ; the wipe: two rows a frame
        jmp wiperow
@x      rts

; the level's colour ($d022: the girders, the shaft's lit edges)
theme   byte 15,14,13,7,10,8,4,3

; ------------------------------------------------------------
; tick  one step of the game
; ------------------------------------------------------------
tick    inc frm
        inc tmr
        bne @t
        dec tmr                 ; stays at 255
@t      jsr readfire
        jsr startkey
        jsr soundkey
        lda musicon
        beq @m
        jsr mplay               ; the music: once a tick
@m      jsr sfxtick
        lda msgt                ; a message for a while
        beq @s
        dec msgt
        bne @s
        jsr clrmsg
@s      lda st
        cmp #st_play
        beq t_play
        cmp #st_over
        bne @n
        jmp t_over
@n      cmp #st_wipe
        bne t_title
        jmp t_wipe

; ---- title: fire starts a round (the program starts as soon as it's
; in, unless -wait: the kit's startkey) ----
t_title jsr flame
        lda fpress
        beq @x
        jmp wipego
@x      rts

; ---- playing ----
t_play  lda stepw
        beq @mv
        jsr stepdraw            ; the last tick's coarse step: unseen at phase 0
@mv     jsr steer
        jsr fall
        jsr passed
        jsr flame
        jsr collide
        bcc @x
        jmp crash
@x      rts

; flame  the rocket's flame flickers
flame   lda frm
        lsr a
        lsr a
        and #1
        sta fframe
        rts

; ------------------------------------------------------------
; steer  the rocket: the stick on port 2 (or the autopilot)
; ------------------------------------------------------------
steer   lda dbg_auto
        beq @joy
        jmp autosteer
@joy    lda #$ff
        sta $dc00               ; no keyboard row: port 2 alone
        lda $dc00
        tax
        and #4                  ; left (0: held)
        bne @nl
        lda shipx
        sec
        sbc pspeed
        bcs @l
        lda #0
@l      sta shipx
@nl     txa
        and #8                  ; right
        bne @x
        lda shipx
        clc
        adc pspeed
        bcs @hi
        cmp #maxx+1
        bcc @r
@hi     lda #maxx
@r      sta shipx
@x      rts

; ------------------------------------------------------------
; fall  the girders down by the speed: the phase, and a coarse step
; when it passes 7 (shown at phase 0, parity flipped; the screen codes
; the next tick)
; ------------------------------------------------------------
fall    lda pos16
        clc
        adc speed
        cmp #128
        bcs @step
        sta pos16
        lsr a
        lsr a
        lsr a
        lsr a
        sta phase
        rts
@step   sbc #128                ; (carry set) what's past the step carries on
        sta pos16
        lda #0
        sta phase
        lda par
        eor #1
        sta par
        lda #1
        sta stepw
        ldx wh                  ; every girder a row down
        ldy nw
        beq @x
@r      inc wrow,x
        inx
        txa
        and #maxw-1
        tax
        dey
        bne @r
@x      rts

; ------------------------------------------------------------
; stepdraw  a coarse step's screen codes: each girder's old upper row
; cleared, its new lower row drawn (both show the blank lower glyph at
; phase 0); the one below the field gone; a new one at the top when
; the one before it is a spacing down
; ------------------------------------------------------------
stepdraw
        lda #0
        sta stepw
        ldx wh
        lda nw
        beq @spawn
        sta tmp3
@w      stx tmp2
        lda wrow,x              ; its new upper row, less one: the old
        sec
        sbc #1
        cmp #f0
        bcc @nc
        jsr clrrow
@nc     ldx tmp2
        lda wrow,x              ; its new lower row
        clc
        adc #1
        cmp #fl+1
        bcs @nd
        jsr drawrow
@nd     ldx tmp2
        inx
        txa
        and #maxw-1
        tax
        dec tmp3
        bne @w
        ldx wh                  ; the lowest out of the field: gone
        lda wrow,x
        cmp #fl+1
        bcc @spawn
        inx
        txa
        and #maxw-1
        sta wh
        dec nw
@spawn  lda nw
        beq @new
        clc
        adc wh
        sec
        sbc #1
        and #maxw-1
        tax
        lda wrow,x              ; the highest
        cmp #1+spacing
        bne @x
@new    jmp newwall
@x      rts

; ------------------------------------------------------------
; newwall  a girder at row 1 (its lower row, row 2, drawn: blank until
; it moves), its gap a random step from the last one's, no further
; than the level allows (so the rocket can always reach it)
; ------------------------------------------------------------
newwall lda ms
        asl a
        sta tmp                 ; 2 x the most
@r      jsr random
        and #31
        cmp tmp
        beq @ok
        bcs @r                  ; 0 to 2 x the most
@ok     clc
        adc lastgx
        sec
        sbc ms                  ; the last gap moved by -most to +most
        bmi @lo
        cmp #1
        bcs @c1
@lo     lda #1                  ; a girder end on each side: column 1 on
@c1     sta tmp
        lda #fcols-1
        sec
        sbc gw                  ; ... to 31 - width
        cmp tmp
        bcs @c2
        sta tmp
@c2     lda wh
        clc
        adc nw
        and #maxw-1
        tax
        lda #1
        sta wrow,x
        lda tmp
        sta wgx,x
        sta lastgx
        lda gw
        sta wgw,x
        lda #0
        sta wpass,x
        inc nw
        lda #f0
        ; (on into drawrow)

; ------------------------------------------------------------
; drawrow  girder x's row a (f0-fl): the parity's solid character, its
; two ends at the gap, the gap blank
;   keeps: x
; ------------------------------------------------------------
drawrow stx tmp2
        tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        tya
        and #1
        beq @e
        lda #c_wall+3           ; odd rows: 7-9
        byte $2c                ; (bit abs: past the lda)
@e      lda #c_wall             ; even rows: 4-6
        sta tmp
        ldy #fc0+fcols-1
@f      sta (pt),y
        dey
        cpy #fc0
        bcs @f
        lda wgx,x
        clc
        adc #fc0-1
        tay
        inc tmp                 ; the end on the gap's left
        lda tmp
        sta (pt),y
        iny
        lda wgw,x
        tax
        lda #c_space
@g      sta (pt),y
        iny
        dex
        bne @g
        inc tmp                 ; the end on its right
        lda tmp
        sta (pt),y
        ldx tmp2
        rts

; clrrow  the field's row a blank (screen codes only)
clrrow  tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        lda #c_space
        ldy #fc0+fcols-1
@c      sta (pt),y
        dey
        cpy #fc0
        bcs @c
        rts

; ------------------------------------------------------------
; passed  a girder whose top is below the rocket: a point; every
; perlevel of them a level
; ------------------------------------------------------------
passed  ldx wh
        ldy nw
        beq @x
@w      lda wpass,x
        bne @n
        lda wrow,x
        asl a
        asl a
        asl a
        clc
        adc phase
        cmp #shipy+ship_rows
        bcc @x                  ; (the ones above it are higher still)
        lda #1
        sta wpass,x
        stx tmp2
        sty tmp3
        jsr addpoint
        ldx tmp2
        ldy tmp3
@n      inx
        txa
        and #maxw-1
        tax
        dey
        bne @w
@x      rts

; addpoint  a point; a level every perlevel
addpoint
        inc scl                 ; bcd, without decimal mode (the loader's
        lda scl                 ; interrupt doesn't cld)
        and #15
        cmp #10
        bcc @lv
        lda scl
        adc #5                  ; (carry set: + 6)
        sta scl
        cmp #$a0
        bcc @lv
        lda #0
        sta scl
        inc sch
        lda sch
        and #15
        cmp #10
        bcc @lv
        lda sch
        adc #5
        sta sch
@lv     dec lvcnt
        bne @p
        lda #perlevel
        sta lvcnt
        lda level
        cmp #99
        bcs @p
        inc level
        jsr setlevel
        jsr drawhud
        ldx #e_level
        jsr sfx
        ldx #<tx_level          ; "LEVEL nn" a while
        ldy #>tx_level
        lda #7
        jsr message
        lda level
        clc
        adc #1                  ; (shown from 1)
        jsr twodig
        stx scra+msgrow*40+23
        sty scra+msgrow*40+24
        lda #7
        sta $d800+msgrow*40+23
        sta $d800+msgrow*40+24
        lda #100
        sta msgt
        rts
@p      ldx #e_pass
        jsr sfx
        jmp drawhud

; setlevel  the level's fall speed, gap, its moves and the rocket's speed
setlevel
        ldx level
        cpx #toplevel
        bcc @l
        ldx #toplevel
@l      lda lvspd,x
        sta speed
        lda lvgw,x
        sta gw
        lda lvms,x
        sta ms
        lda lvps,x
        sta pspeed
        rts

; the levels: the fall (1/16 lines a tick), the gap (columns), the most
; a gap moves from the one before (columns: the rocket can make it with
; room to spare), the rocket's speed (pixels a tick)
lvspd   byte 8,10,12,14,16,18,20,22,24,26,28,32
lvgw    byte 6,6,5,5,5,5,4,4,4,4,4,4
lvms    byte 12,11,10,9,8,7,7,6,6,5,5,4
lvps    byte 2,2,2,2,3,3,3,3,3,3,3,3

; ------------------------------------------------------------
; collide  the rocket's rows against the girders, as the next frame
; shows them (the phase, the rocket's x and frame)
;   out:  c set: a hit
; ------------------------------------------------------------
collide ldx fframe              ; the frame's row extents
        lda shlxl,x
        sta lxp
        lda shlxh,x
        sta lxp+1
        lda shrxl,x
        sta rxp
        lda shrxh,x
        sta rxp+1
        ldx wh
        lda nw
        beq @no
        sta tmp3
@w      lda wrow,x
        asl a
        asl a
        asl a
        clc
        adc phase
        sta wtop                ; its top line on the screen
        cmp #shipy+ship_rows
        bcs @nx                 ; below the rocket
        adc #8
        cmp #shipy+1
        bcc @nx                 ; above it
        sbc #shipy              ; (carry set) the rocket's rows: to here
        cmp #ship_rows
        bcc @e
        lda #ship_rows
@e      sta srend
        lda wgx,x               ; the gap's pixels
        asl a
        asl a
        asl a
        sta gl
        lda wgx,x
        clc
        adc wgw,x
        asl a
        asl a
        asl a
        sta gr
        lda wtop                ; from the rocket's row at the girder's top
        sec
        sbc #shipy
        bcs @y
        lda #0
@y      tay
@row    lda (lxp),y
        cmp #$ff
        beq @nr                 ; (an empty row)
        clc
        adc shipx
        cmp gl
        bcc @hit
        lda (rxp),y
        clc
        adc shipx
        cmp gr
        bcs @hit
@nr     iny
        cpy srend
        bcc @row
@nx     inx
        txa
        and #maxw-1
        tax
        dec tmp3
        bne @w
@no     clc
        rts
@hit    sec
        rts
shlxl   byte <shiplx0,<shiplx1
shlxh   byte >shiplx0,>shiplx1
shrxl   byte <shiprx0,<shiprx1
shrxh   byte >shiprx0,>shiprx1

; ------------------------------------------------------------
; crash  the round is over: where it hit shown a moment, then a burst
; ------------------------------------------------------------
crash   lda #st_over
        sta st
        lda #0
        sta tmr
        ldx #e_crash
        jsr sfx
        lda sch                 ; a new best?
        cmp besth
        bcc @m
        bne @b
        lda scl
        cmp bestl
        bcc @m
@b      lda scl
        sta bestl
        lda sch
        sta besth
        jsr drawhud
@m      ldx #<tx_over
        ldy #>tx_over
        lda #1
        jsr message
        lda #0
        sta msgt
        rts

; ---- game over: once loaded, the program starts (gk_done: with -wait,
; the end of a game); before, after a lockout, fire plays again. The
; world stays where it was ----
t_over  jsr gk_done
        lda tmr
        cmp #showhit
        bcc @x
        lda #2                  ; the burst, flashing
        sta fframe
        lda tmr
        lsr a
        and #3
        tax
        lda burstc,x
        sta shipcol
        lda tmr
        cmp #lockout
        bcc @x
        lda fpress
        beq @x
        jmp wipego
@x      rts
burstc  byte 1,7,8,2

; ------------------------------------------------------------
; the wipe: before a round, the field cleared two rows a frame (in
; the vertical blank: vbwork), then play
; ------------------------------------------------------------
wipego  lda #st_wipe
        sta st
        lda #f0
        sta wipe
        lda #0
        sta nw
        sta fframe
        lda #1
        sta shipcol
        jmp clrmsg

wiperow lda wipe
        cmp #fl+1
        bcs @x
        inc wipe
        tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        sec
        sbc #>(scra-$d800)      ; ... and its colours
        sta pt2+1
        lda pt
        sta pt2
        ldy #fc0+fcols-1
@c      lda #c_space
        sta (pt),y
        lda #fcol
        sta (pt2),y
        dey
        cpy #fc0
        bcs @c
@x      rts

t_wipe  jsr flame
        lda wipe
        cmp #fl+1
        bcs playgo
        rts

; playgo  a round: score 0, level 0, the first girder in
playgo  lda #st_play
        sta st
        lda #0
        sta tmr
        sta scl
        sta sch
        sta level
        sta pos16
        sta phase
        sta nw
        sta wh
        sta stepw
        lda #1                  ; (the first girder's upper row: 1)
        sta par
        lda #perlevel
        sta lvcnt
        jsr setlevel
        lda #fcols/2
        sec
        sbc gw
        lsr a
        clc
        adc #fcols/4
        sta lastgx              ; the first gap about the middle
        lda #(maxx+1)/2
        sta shipx
        lda #1                  ; the first girder: the next tick's stepdraw, after
        sta stepw               ; a frame shown with this parity (its row blank)
        jsr drawhud
        ldx #<tx_go
        ldy #>tx_go
        lda #7
        jsr message
        lda #100
        sta msgt
        ldx #e_start
        jmp sfx

; ------------------------------------------------------------
; autosteer  (debug) the autopilot: to the next gap; with dbg_auto 1
; it gives up once the program has loaded (into a girder: the round
; ends), with 2 never
; ------------------------------------------------------------
autosteer
        ldx wh                  ; the lowest girder not past the rocket
        ldy nw
        beq @x
@f      lda wpass,x
        beq @got
        inx
        txa
        and #maxw-1
        tax
        dey
        bne @f
@x      rts
@got    lda dbg_auto
        cmp #2
        beq @play
        bit ld_state
        bpl @play
        lda wgx,x               ; given up: to the side away from the gap
        cmp #fcols/2
        lda #0
        bcs @tgt
        lda #maxx
        bne @tgt
@play   jsr safe                ; its gap: tmp to tmp2
        lda wrow,x              ; at the rocket already (its underside
        asl a                   ; within 2 lines of the rocket's top)?
        asl a
        asl a
        clc
        adc phase
        cmp #shipy-8-2
        bcc @mid                ; no: the middle of its gap
        dey                     ; yes: towards the next one's, inside this one's
        beq @mid
        lda tmp
        sta tmp3
        lda tmp2
        sta target
        inx
        txa
        and #maxw-1
        tax
        jsr safe
        jsr midsafe
        cmp tmp3
        bcs @ab
        lda tmp3
@ab     cmp target
        bcc @tgt
        lda target
        bcs @tgt
@mid    jsr midsafe
@tgt    sta target
        sec
        sbc shipx
        beq @x2
        bcc @left
        cmp pspeed              ; right, no further than the target
        bcc @r
        lda pspeed
@r      clc
        adc shipx
        sta shipx
@x2     rts
@left   lda shipx
        sec
        sbc target
        cmp pspeed
        bcc @l
        lda pspeed
@l      sta tmp
        lda shipx
        sec
        sbc tmp
        sta shipx
        rts

; safe  the rocket's x that fits girder x's gap: tmp to tmp2
safe    lda wgx,x
        asl a
        asl a
        asl a
        sec
        sbc #ship_minl
        sta tmp
        lda wgx,x
        clc
        adc wgw,x
        asl a
        asl a
        asl a
        sec
        sbc #ship_maxr+1
        sta tmp2
        rts

; midsafe  a = the middle of tmp to tmp2
midsafe lda tmp
        clc
        adc tmp2
        ror a
        rts

; ------------------------------------------------------------
; the screen: the shaft's rock, its floor, the score line
; ------------------------------------------------------------
drawall ldx #0                  ; rows 0-1 and 24: blank, white
@c      lda #c_space
        sta scra,x
        sta scra+40,x
        sta scra+gk_srow,x
        lda #1
        sta $d800,x
        sta $d800+40,x
        sta $d800+gk_srow,x
        inx
        cpx #40
        bcc @c
        lda #3                  ; the score line's names cyan
        ldx #4
@n      sta $d800+1,x
        sta $d800+16,x
        sta $d800+30,x
        dex
        bpl @n
        lda #f0
        sta tmp3
@row    ldy tmp3
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        sec
        sbc #>(scra-$d800)
        sta pt2+1
        lda pt
        sta pt2
        ldy #39
@col    lda #rcol               ; the rock
        cpy #fc0
        bcc @rk
        cpy #fc0+fcols
        bcs @rk
        ldx tmp3
        cpx #fl+1
        bcs @fl
        lda #fcol               ; the shaft
        sta (pt2),y
        lda #c_space
        bne @put
@fl     sta (pt2),y             ; the floor (in the rock's colours)
        tya
        and #1
        adc #c_floor-1          ; (carry set)
        bne @put
@rk     sta (pt2),y
        cpy #fc0-1
        beq @el
        cpy #fc0+fcols
        beq @er
        lda tmp3                ; rock: the tile's character, by the row's
        and #1                  ; and the column's parity
        asl a
        sta tmp
        tya
        and #1
        ora tmp
        clc
        adc #c_rock
        bne @put
@el     lda #c_edgel            ; the left face
        ldx #c_cornl
        bne @fc
@er     lda #c_edger            ; the right face
        ldx #c_cornr
@fc     sta tmp
        lda tmp3
        cmp #fl+1
        bcc @fr
        txa                     ; (the floor's row: the corner)
        bcs @put
@fr     and #1                  ; (odd rows: the next)
        adc tmp
@put    sta (pt),y
        dey
        bpl @col
        inc tmp3
        lda tmp3
        cmp #fl+2
        bcc @row
        ldx #4
@hd     lda tx_score+1,x        ; the score line's names
        sta scra+1,x
        dex
        bpl @hd
        ldx #4
@hl     lda tx_level+1,x
        sta scra+16,x
        dex
        bpl @hl
        ldx #3
@hb     lda tx_best+1,x
        sta scra+30,x
        dex
        bpl @hb
        rts

; drawhud  the score, level and best on row 0
drawhud lda sch
        ldx #7
        jsr bcd2
        lda scl
        ldx #9
        jsr bcd2
        lda besth
        ldx #35
        jsr bcd2
        lda bestl
        ldx #37
        jsr bcd2
        lda level
        clc
        adc #1
        jsr twodig
        stx scra+22
        sty scra+23
        rts

; bcd2  a's two bcd digits at row 0, columns x and x + 1
bcd2    pha
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #c_digit0
        sta scra,x
        pla
        and #15
        clc
        adc #c_digit0
        sta scra+1,x
        rts

; twodig  a (0-99) as two digits: x tens, y units
twodig  ldx #c_digit0
@t      cmp #10
        bcc @u
        sbc #10
        inx
        bne @t
@u      clc
        adc #c_digit0
        tay
        rts

; ------------------------------------------------------------
; message  text x/y (length first) centred on the message row, colour a
; ctext    text x/y centred on row a, in colour tcol (hi-res: 0-7)
; clrmsg   the message row blank
; ------------------------------------------------------------
message sta tcol
        lda #msgrow
ctext   stx pt2
        sty pt2+1
        pha
        jsr clrmsgr
        pla
        tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        ldy #0
        lda (pt2),y
        sta tmp                 ; its length
        lda #40
        sec
        sbc tmp
        lsr a
        clc
        adc pt
        sta pt
        sta cpt                 ; (the colour ram: the same low byte)
        lda pt+1
        adc #0
        sta pt+1
        sec
        sbc #>(scra-$d800)
        sta cpt+1
        ldy tmp                 ; from its last character back
@t      lda (pt2),y
        dey
        sta (pt),y
        lda tcol
        sta (cpt),y
        cpy #0
        bne @t
        rts
tcol    byte 1

clrmsg  lda #msgrow
clrmsgr cmp #msgrow             ; only the message row is cleared first
        bne @x
        ldy #39
        lda #c_space
@c      sta scra+msgrow*40,y
        dey
        bpl @c
@x      rts

rowlo   byte <scra,<scra+40,<scra+80,<scra+120,<scra+160,<scra+200,<scra+240
        byte <scra+280,<scra+320,<scra+360,<scra+400,<scra+440,<scra+480
        byte <scra+520,<scra+560,<scra+600,<scra+640,<scra+680,<scra+720
        byte <scra+760,<scra+800,<scra+840,<scra+880,<scra+920,<scra+960
rowhi   byte >scra,>scra+40,>scra+80,>scra+120,>scra+160,>scra+200,>scra+240
        byte >scra+280,>scra+320,>scra+360,>scra+400,>scra+440,>scra+480
        byte >scra+520,>scra+560,>scra+600,>scra+640,>scra+680,>scra+720
        byte >scra+760,>scra+800,>scra+840,>scra+880,>scra+920,>scra+960

; ------------------------------------------------------------
; sound effects on voice 3 (only beside SlopLoad's own player or no
; tune: any other tune has every voice). An effect: attack/decay,
; sustain/release, then a frequency (high byte) and control a tick,
; 0 ends (the gate off)
; ------------------------------------------------------------
sfx     lda mflags
        cmp #2
        beq @x
        lda #0
        sta $d412
        lda sfxdat,x
        sta $d413
        lda sfxdat+1,x
        sta $d414
        inx
        inx
        stx sfxp
@x      rts

sfxtick ldx sfxp
        beq @x
        lda sfxdat,x
        beq @end
        sta $d40f
        lda sfxdat+1,x
        sta $d412
        sta sfxc
        inx
        inx
        stx sfxp
@x      rts
@end    lda sfxc
        and #$fe
        sta $d412
        lda #0
        sta sfxp
        rts

sfxdat  byte 0                  ; (0: no effect)
e_pass = *-sfxdat               ; a girder past: a quick rising chirp
        byte $00,$a0,$30,$11,$40,$11,$50,$11,$60,$11,0
e_level = *-sfxdat              ; a level: up an arpeggio
        byte $00,$c0,$20,$41,$20,$41,$28,$41,$28,$41,$30,$41,$30,$41
        byte $40,$41,$40,$41,$40,$41,$40,$41,0
e_start = *-sfxdat              ; a round
        byte $00,$a0,$30,$21,$30,$21,$3c,$21,$3c,$21,$48,$21,$48,$21,$48,$21,0
e_crash = *-sfxdat              ; a hit: noise, falling
        byte $0b,$00,$48,$81,$40,$81,$38,$81,$30,$81,$2a,$81,$24,$81,$20,$81
        byte $1c,$81,$18,$81,$15,$81,$12,$81,$10,$81,$0e,$81,$0c,$81,$0a,$81
        byte $09,$81,$08,$81,$07,$81,$06,$81,$05,$81,0

; ------------------------------------------------------------
; autopilot  (debug, the kit's readfire) fire on the title and after a
; game over now and then; none while playing
;   out:  a = 0 to press fire, $10 not
; ------------------------------------------------------------
autopilot
        lda st
        cmp #st_play
        beq @no
        lda frm
        and #16
        rts
@no     lda #$10
        rts

        incasm "modkit.asm"
        incasm "modinit.asm"
        incasm "tables.asm"
        incasm "fadekit.asm"    ; (every module's tune fades out at the end)
        incasm "fadescr.asm"
codeend
