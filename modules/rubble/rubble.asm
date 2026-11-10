; ------------------------------------------------------------
; rubble.asm  -  Rubble-Load: the old town is coming down. A plane
; flies back and forth over it, a row lower at every turn; fire drops a
; charge from under the plane, and the block it lands on loses its top
; storey. Flatten every block and the plane glides down and lands on
; the street: the next town is taller and the plane faster. Fly into a
; block and the game is over. A SlopLoad module (MODULES.md).
;
; The town is characters: 16 blocks of two columns, each a stack of
; storeys two rows tall (multicolour, solid in every cell: a block is
; exactly the cells it covers). The charge is two characters whose
; glyphs are redrawn for its line in the row, its screen codes moved when
; it crosses a row; a blast is four characters where the storey was.
; Everything on screen changes in the vertical blank (vbwork), from the
; tables the last tick left, so nothing tears; the tick only changes
; the tables (and the text rows).
;
; The plane is one multicolour sprite, 8 lines tall, flying in one
; character row (one sprite on any raster line: g_jitter has the 8
; cycles it costs). It turns off the screen's edge, out of sight behind
; the border, where it drops its row. Its collisions go by what is
; drawn: its width (every column of it has a pixel) against the blocks'
; cells in its row, in the state the next frame shows.
;
; Memory (vic bank 3): characters $e000-$e3ff (the header is
; characters 0-3), the screen $e400 (the character set's other half,
; never read as glyphs), the sprite frames $e800-$e93f, code after.
; Zero page $10-$6f.
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
scra = $e400                    ; one screen: the kit's two are the same
scrb = scra
d018v = $98                     ; screen $e400, characters $e000
chr = $e000                     ; the character set
sprblk = $e800                  ; the plane's frames (64 bytes each)
sprp0 = $a0                     ; ... their first pointer: ($e800 - $c000) / 64
sprptr = scra+$3f8              ; sprite 0's pointer

; ---- the standard parts ----
g_claim = codeend               ; end of the memory claimed
g_jitter = 56                   ; 48 + 8 for the sprite (MODULES.md); measured (tests/jitter.py
                                ; --module rubble --auto 2): 99.9% 53 pal, 54 ntsc and c128; max 59
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 1                       ; it makes effects on voice 3 (beside SlopLoad's player)
g_wait = 1                      ; with -wait it plays on until SPACE or a game's end (the kit's)
g_count = 1                     ; with -countdown its status line counts blocks (the kit's)
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; the status bar: 9 characters, 1 px a step
gk_srow = 24*40                 ; the status line: row 24

; ---- the town ----
f0 = 2                          ; the plane's first row (rows 0-1: score, messages)
street = 23                     ; the street's row: the blocks stand on it
c0 = 4                          ; the town's first column (16 blocks of 2: to 35)
ntw = 16                        ; blocks
msgrow = 1                      ; the message row
skycol = 8+2                    ; the sky's colour ram: multicolour, red (the charge's sticks)
blastcol = 8+7                  ; a blast's: yellow fire
streetcol = 8+7                 ; the street's: yellow markings
cspd = 4                        ; a charge's fall (lines a tick)
blastt = 2                      ; ticks to a blast's frame (4 frames)
pxend = 368*16                  ; the plane's x (1/16 px) off the right edge (sprite x 368)
landy = 22*8                    ; the plane's y on the street (row 22)
lockout = 50                    ; ticks before game over takes fire
showhit = 8                     ; ticks the plane shows where it hit, before the burst
burstt = 60                     ; ticks the burst shows
landt = 150                     ; ticks after landing before the next town
toplevel = 4                    ; the last row of the level table

; ---- states ----
st_title = 0
st_play = 1
st_over = 2
st_build = 3                    ; a town going up, a row a frame
st_land = 4                     ; landed: the next town soon

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
cpt = $26                       ; the colour ram (2)
level = $28                     ; the town, 0 on
prow = $29                      ; the plane's row (f0-22)
pxl = $2a                       ; its sprite x (9 bits: pxh bit 0)
pxh = $2b
ppl = $2c                       ; ... in 1/16 pixels (16 bits)
pph = $2d
pdir = $2e                      ; 0 flying right, 1 left
pspd = $2f                      ; its speed, 1/16 pixels a tick
py = $30                        ; its top line on the screen (prow x 8, but landing)
pfr = $31                       ; its frame shown (0, 1 right; 2, 3 left; 4 the burst)
pcol = $32                      ; its colour
cact = $33                      ; 1: a charge falling
ccol = $34                      ; ... its column
cy = $35                        ; ... its top line on the screen
chit = $36                      ; ... 1: on a roof (or the street): it goes off the next tick
exf = $37                       ; a blast's frame (1-4; 0: none)
ext = $38                       ; ... ticks left in it
exr = $39                       ; ... its upper row
exc = $3a                       ; ... its left column
scl = $3b                       ; score, bcd (shown x 10): low two digits
sch = $3c                       ; ... high two
bestl = $3d                     ; the best score, bcd
besth = $3e
sfxp = $3f                      ; the effect: its place in sfxdat (0: none)
sfxc = $40                      ; ... its last control byte
msgt = $41                      ; ticks the message row stays (0: for good)
brow = $42                      ; the build's next row (st_build)
landing = $43                   ; 0 flying, 1 gliding down, 2 rolling on the street
hst = $44                       ; the level's tallest block, in storeys
sbr = $45                       ; the charge as shown: its row ($ff: none)
sbc = $46                       ; ... its column
sbb = $47                       ; ... 1: its lower cell too
sexf = $48                      ; the blast's frame shown
sthm = $49                      ; the theme shown ($ff: none yet)
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: 1 plays until the program is in, 2 never gives up
th = $50                        ; the blocks' heights in rows (even: two a storey), 16

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
        lda #6
        sta ntscc
        lda #$a7
        sta rnd
        sta rnd+1
        lda #$ff
        sta smode               ; (the status line: drawn at the first frame)
        sta sthm                ; (the colours: at the first frame)
        sta sbr
        lda #1                  ; the plane: multicolour, red trim, grey, white
        sta $d01c
        sta pcol
        lda #2
        sta $d025
        lda #12
        sta $d026
        lda #f0
        jsr planego
        jsr setlevel
        jsr newtown
        jsr drawall
        jsr drawhud
        jsr vbwork              ; (the sprite where it goes, before it shows)
        lda #1
        sta $d015
        jsr sidinit
        jsr musicgo
        lda #7                  ; the title, in the sky (hi-res colours)
        sta tcol
        ldx #<tx_title
        ldy #>tx_title
        lda #4
        jsr ctext
        lda #1
        sta tcol
        ldx #<tx_t1
        ldy #>tx_t1
        lda #6
        jsr ctext
        lda #3
        sta tcol
        ldx #<tx_t2
        ldy #>tx_t2
        lda #7
        jsr ctext
        ldx #<tx_t3
        ldy #>tx_t3
        lda #8
        jsr ctext
        ldx #<tx_t4
        ldy #>tx_t4
        lda #9
        jsr ctext
        lda #7
        sta tcol
        ldx #<tx_t5
        ldy #>tx_t5
        lda #msgrow
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
; The theme's colours (when they change), the plane, the charge (its
; old cells blank, its glyphs for its line, its new cells), a blast's
; frame, and while a town goes up one of its rows
; ------------------------------------------------------------
vbwork  lda level
        and #3
        cmp sthm
        beq @pl
        sta sthm                ; (colour registers only when they change)
        tax
        lda thsky,x
        sta $d021
        lda thwall,x
        sta $d022
        lda thdark,x
        sta $d023
@pl     lda pxl                 ; the plane
        sta $d000
        lda pxh
        sta $d010
        lda py
        clc
        adc #50                 ; (screen line 0 = sprite y 50)
        sta $d001
        lda pfr
        clc
        adc #sprp0
        sta sprptr
        lda pcol
        sta $d027
        ldy sbr                 ; the charge's old cells blank
        bmi @cn
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        ldy sbc
        lda #c_space
        sta (pt),y
        ldx sbb
        beq @c1
        tya
        clc
        adc #40
        tay
        lda #c_space
        sta (pt),y              ; (the row below)
@c1     lda #$ff
        sta sbr
@cn     lda cact
        beq @bl
        lda cy                  ; its glyphs: the upper cell from strip byte
        and #7                  ; 8 - p, the lower from 16 - p
        eor #7
        tax
        inx
        ldy #0
@g      lda cstrip,x
        sta chr+c_charge*8,y
        lda cstrip+8,x
        sta chr+c_charge*8+8,y
        inx
        iny
        cpy #8
        bne @g
        lda cy                  ; its cells
        lsr a
        lsr a
        lsr a
        sta sbr
        tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        sta pt+1
        ldy ccol
        sty sbc
        lda #c_charge
        sta (pt),y
        lda #0
        sta sbb
        tya
        jsr toprow              ; the lower cell only above what stands there
        sec
        sbc #1
        cmp sbr
        beq @bl
        bcc @bl
        lda ccol
        clc
        adc #40
        tay
        lda #c_charge+1
        sta (pt),y
        lda #1
        sta sbb
@bl     lda exf                 ; a blast's frame, when it changes
        cmp sexf
        beq @bd
        sta sexf
        ldy exr
        lda rowlo,y
        sta pt
        sta cpt
        lda rowhi,y
        sta pt+1
        sec
        sbc #>(scra-$d800)
        sta cpt+1
        lda exf
        beq @bx
        asl a
        asl a
        adc #c_blast-4          ; (carry clear) its four characters, in turn
        ldx #1
        stx tmp2
        ldx #blastcol
        bne @b4
@bx     ldx #0                  ; over: the sky
        stx tmp2
        lda #c_space
        ldx #skycol
@b4     sta tmp
        ldy exc
        jsr @cell               ; upper left
        iny
        jsr @cell               ; upper right
        tya
        clc
        adc #39
        tay
        jsr @cell               ; lower left
        iny
        jsr @cell               ; lower right
@bd     lda st                  ; a town going up: a row a frame, from the
        cmp #st_build           ; street
        bne @x
        lda brow
        cmp #f0
        bcc @x
        dec brow
        jmp drawrow
@x      rts
@cell   lda tmp                 ; (a blast's cell: tmp, then tmp + tmp2)
        sta (pt),y
        clc
        adc tmp2
        sta tmp
        txa
        sta (cpt),y
        rts

; the themes, by town: the sky, the walls ($d022), their frames and
; shade ($d023), and two colours for the lit windows
thsky   byte 6,0,4,11
thwall  byte 12,12,15,12
thdark  byte 11,11,12,0
thwin1  byte 8+7,8+7,8+7,8+7
thwin2  byte 8+1,8+3,8+1,8+5

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
@n      cmp #st_build
        bne @n2
        jmp t_build
@n2     cmp #st_land
        bne t_title
        jmp t_land

; ---- title: the plane flies along the top; fire starts a game (the
; program starts as soon as it's in, unless -wait: the kit's startkey) ----
t_title jsr fly
        lda fpress
        beq @x
        jmp newgame
@x      rts

; ---- playing ----
t_play  jsr fly
        lda landing
        cmp #2
        bne @f
        lda pspd                ; rolled to a stop: landed
        bne @x
        jmp landgo
@f      jsr blast
        jsr charge
        jsr collide
        bcc @d
        jmp crash
@d      jsr drop
        jmp flat
@x      rts

; ------------------------------------------------------------
; fly  the plane along its row: at an edge it turns, out of sight, a
; row lower (not on the title, nor landing). Landing, it glides down a
; line a tick to the street, then rolls to a stop
; ------------------------------------------------------------
fly     lda frm                 ; the propeller
        lsr a
        and #1
        sta tmp
        lda pdir
        asl a
        ora tmp
        sta pfr
        lda landing
        cmp #2
        bne @mv
        lda pspd                ; rolling: slower each tick
        bne @sl
        rts                     ; (stopped)
@sl     dec pspd
@mv     lda pdir
        bne @lt
        lda ppl                 ; right
        clc
        adc pspd
        sta ppl
        lda pph
        adc #0
        sta pph
        cmp #>pxend
        bcc @set
        lda #<pxend             ; off the right edge: turn
        sta ppl
        lda #>pxend
        sta pph
        lda #1
        bne @turn
@lt     lda ppl                 ; left
        sec
        sbc pspd
        sta ppl
        lda pph
        sbc #0
        sta pph
        bcs @set
        lda #0                  ; off the left edge: turn
        sta ppl
        sta pph
@turn   ldx landing
        cpx #2
        bne @tn
        lda #0                  ; (rolling: it stops there)
        sta pspd
        beq @set
@tn     sta pdir
        lda st
        cmp #st_play
        bne @set
        lda landing
        bne @set
        lda prow
        cmp #street-1
        bcs @set                ; (no lower than the street's row above)
        inc prow                ; a row lower
        lda prow
        asl a
        asl a
        asl a
        sta py
@set    lda pph                 ; the sprite's x: the position / 16
        lsr a
        sta pxh
        lda ppl
        ror a
        sta pxl
        lsr pxh
        ror pxl
        lsr pxh
        ror pxl
        lsr pxh
        ror pxl
        lda landing
        cmp #1
        bne @x
        lda py                  ; gliding down: a line a tick
        cmp #landy
        bcs @td
        inc py
@x      rts
@td     lda #2                  ; on the street: roll
        sta landing
        ldx #e_touch
        jmp sfx

; planego  the plane at the left edge, row a, flying right at the level's speed
planego sta prow
        asl a
        asl a
        asl a
        sta py
        lda #0
        sta ppl
        sta pph
        sta pxl
        sta pxh
        sta pdir
        sta landing
        sta pfr
        lda #1
        sta pcol
        rts

; ------------------------------------------------------------
; blast  a blast's frames: blastt ticks each, then gone
; ------------------------------------------------------------
blast   lda exf
        beq @x
        dec ext
        bne @x
        lda #blastt
        sta ext
        inc exf
        lda exf
        cmp #5
        bcc @x
        lda #0
        sta exf
@x      rts

; ------------------------------------------------------------
; charge  the charge falls; on a roof (or the street) it waits a tick
; there, shown touching, then goes off: the block's top storey gone
; ------------------------------------------------------------
charge  lda cact
        beq @x
        lda chit
        bne @boom
        lda cy
        clc
        adc #cspd
        sta cy
        jsr reach               ; a = its lowest line: on what's below
        cmp cy
        beq @on
        bcs @x
@on     sta cy
        lda #1
        sta chit
@x      rts
@boom   lda #0
        sta cact
        sta chit
        lda ccol
        and #$fe                ; the blast: the block's two columns (c0 even)
        sta exc
        lda ccol
        sec
        sbc #c0
        cmp #ntw*2
        bcs @st
        lsr a
        tax
        lda th,x
        beq @st
        lda #street             ; the top storey's upper row
        sec
        sbc th,x
        sta exr
        dec th,x                ; a storey down
        dec th,x
        jsr addpoint
        jsr drawhud
        jmp @go
@st     lda #street-2           ; the street: a blast above it
        sta exr
@go     lda #1
        sta exf
        lda #blastt
        sta ext
        ldx #e_boom
        jmp sfx

; reach  the charge's lowest top line in its column: on what stands
; there (8 lines above its top)
reach   lda ccol
        jsr toprow
        asl a
        asl a
        asl a
        sec
        sbc #8
        rts

; toprow  column a: the top row of what stands there (street: nothing)
;   uses: a, x
toprow  sec
        sbc #c0
        cmp #ntw*2
        bcs @st
        lsr a
        tax
        lda #street
        sec
        sbc th,x
        rts
@st     lda #street
        rts

; ------------------------------------------------------------
; drop  fire: a charge from under the plane (one at a time, none while
; a blast goes off or landing), in the column under its middle
; ------------------------------------------------------------
drop    lda fpress
        beq @x
        jsr canbomb
        bcc @x
        sta ccol
        lda prow                ; the line under the plane
        asl a
        asl a
        asl a
        adc #8                  ; (carry clear)
        sta cy
        lda #1
        sta cact
        lda #0
        sta chit
        jsr reach               ; on a roof already?
        cmp cy
        beq @on
        bcs @s
@on     sta cy
        lda #1
        sta chit
@s      ldx #e_drop
        jmp sfx
@x      rts

; canbomb  can a charge drop now? c set and a = its column
canbomb lda cact
        ora exf
        ora landing
        bne @no
        ldx #baypx              ; the plane's middle
        lda pdir
        beq @r
        ldx #baypxl
@r      txa
        clc
        adc pxl
        sta tmp
        lda pxh
        adc #0
        jsr col8                ; its column (+3)
        sec
        sbc #3
        bcc @no
        cmp #40
        bcs @no
        sec
        rts
@no     clc
        rts

; col8  a:tmp (9 bits) / 8 (the sprite's x as a column, 3 = the screen's 0)
col8    lsr a
        lda tmp
        ror a
        lsr a
        lsr a
        rts

; ------------------------------------------------------------
; collide  the plane's width against the blocks in its row, as the
; next frame shows them
;   out:  c set: a hit
; ------------------------------------------------------------
collide lda landing
        bne @no
        ldx pfr
        lda plx,x               ; its first pixel's column (+3)
        clc
        adc pxl
        sta tmp
        lda pxh
        adc #0
        jsr col8
        cmp #c0+3
        bcs @a
        lda #c0+3
@a      sta tmp2
        lda prx,x               ; its last's
        clc
        adc pxl
        sta tmp
        lda pxh
        adc #0
        jsr col8
        cmp #c0+3+ntw*2
        bcc @b
        lda #c0+3+ntw*2-1
@b      sta tmp3
@c      lda tmp3
        cmp tmp2
        bcc @no                 ; past the last
        lda tmp2
        sec
        sbc #c0+3
        lsr a
        tax
        lda th,x
        beq @n
        clc
        adc prow
        cmp #street             ; its height reaches the plane's row
        bcs @hit
@n      inc tmp2
        bne @c
@no     clc
        rts
@hit    sec
        rts

; ------------------------------------------------------------
; flat  the town all down (and the last blast over): the plane glides
; down to land
; ------------------------------------------------------------
flat    lda landing
        ora cact
        ora exf
        bne @x
        ldx #ntw-1
@o      ora th,x
        dex
        bpl @o
        tax
        bne @x
        lda #1
        sta landing
        ldx #<tx_flat
        ldy #>tx_flat
        lda #7
        jsr message
        lda #0
        sta msgt
@x      rts

; ------------------------------------------------------------
; crash  the game is over: where it hit shown a moment, then a burst
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
; town stays as it was ----
t_over  jsr gk_done
        lda tmr
        cmp #showhit
        bcc @x
        cmp #burstt
        bcc @bu
        lda #0                  ; the burst over: off the screen
        sta pxl
        sta pxh
        beq @lk
@bu     lda #4                  ; the burst, flashing
        sta pfr
        lda tmr
        lsr a
        and #3
        tax
        lda burstc,x
        sta pcol
@lk     lda tmr
        cmp #lockout
        bcc @x
        lda fpress
        beq @x
        jmp newgame
@x      rts
burstc  byte 1,7,8,2

; ------------------------------------------------------------
; a town: a new game's first, or the next after a landing. It goes up
; a row a frame from the street (vbwork), then play
; ------------------------------------------------------------
newgame lda #0
        sta scl
        sta sch
        sta level
buildgo lda #st_build
        sta st
        lda #0
        sta tmr
        sta cact
        sta exf
        lda #f0
        jsr planego
        jsr setlevel
        jsr newtown
        jsr drawhud
        jsr clrmsg
        lda #street-1
        sta brow
        rts

t_build lda brow
        cmp #f0
        bcs @x
        lda #st_play            ; up: play
        sta st
        lda #0
        sta tmr
        ldx #<tx_go
        ldy #>tx_go
        lda #7
        jsr message
        lda #100
        sta msgt
        ldx #e_start
        jmp sfx
@x      rts

; ---- landed: a bonus, and the next town a little later ----
landgo  lda #st_land
        sta st
        lda #0
        sta tmr
        lda #25                 ; 250
        sta tmp3
@b      jsr addpoint
        dec tmp3
        bne @b
        jsr drawhud
        ldx #<tx_landed
        ldy #>tx_landed
        lda #7
        jsr message
        lda #0
        sta msgt
        ldx #e_land
        jmp sfx

t_land  lda tmr
        cmp #landt
        bcc @x
        lda level
        cmp #99
        bcs @b
        inc level
@b      jmp buildgo
@x      rts

; setlevel  the level's plane speed and tallest block
setlevel
        ldx level
        cpx #toplevel
        bcc @l
        ldx #toplevel
@l      lda lvspd,x
        sta pspd
        lda lvhst,x
        sta hst
        rts

; the levels: the plane's speed (1/16 pixels a tick) and the tallest
; block (storeys; each one at least one)
lvspd   byte 32,36,36,40,40
lvhst   byte 6,6,7,7,8

; newtown  the blocks: a height of 1 to hst storeys, a style and a
; window colour each, from one random byte a block (its bits 0-2, 3-4
; and 5)
newtown ldx #ntw-1
@h      jsr rnd4
        sta tmp2
        and #7
        cmp hst
        bcs @h                  ; (too tall: another byte)
        adc #1                  ; (carry clear) 1 to hst storeys
        asl a                   ; two rows each
        sta th,x
        lda tmp2
        lsr a
        lsr a
        lsr a
        and #3
        tay
        lda stymap,y
        sta tsty,x
        lda level
        and #3
        tay
        lda tmp2
        and #$20
        beq @w1
        lda thwin2,y
        bne @w
@w1     lda thwin1,y
@w      sta twin,x
        dex
        bpl @h
        rts
stymap  byte 0,1,2,1            ; two bits to a style (nstyles = 3)

; rnd4  the kit's random, four steps on: its low bits new (one step
; only shifts the last byte along)
rnd4    jsr random
        jsr random
        jsr random
        jmp random
tsty    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; the blocks' styles
twin    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; ... and windows' colour ram

; ------------------------------------------------------------
; drawrow  row a (f0-22) as the tables have it: the sky, and each
; block's cells from its top down (codes and colours)
; ------------------------------------------------------------
drawrow sta tmp3
        tay
        lda rowlo,y
        sta pt
        sta cpt
        lda rowhi,y
        sta pt+1
        sec
        sbc #>(scra-$d800)
        sta cpt+1
        ldy #3                  ; the open ground at each end: sky
@e      lda #c_space
        sta (pt),y
        lda #skycol
        sta (cpt),y
        dey
        bpl @e
        ldy #c0+ntw*2+3
@e2     lda #c_space
        sta (pt),y
        lda #skycol
        sta (cpt),y
        dey
        cpy #c0+ntw*2
        bcs @e2
        lda tmp3                ; a storey's lower row (even rows): +2
        and #1
        eor #1
        asl a
        sta tmp
        ldx #0
        ldy #c0
@t      lda #street             ; the block's top row
        sec
        sbc th,x
        sta tmp2
        lda tmp3
        cmp tmp2
        bcc @sky                ; above it
        lda tsty,x
        asl a
        asl a
        ora tmp
        clc
        adc #c_block
        sta (pt),y
        iny
        clc
        adc #1
        sta (pt),y
        dey
        lda twin,x
        sta (cpt),y
        iny
        sta (cpt),y
        bne @nx
@sky    lda #c_space
        sta (pt),y
        iny
        sta (pt),y
        dey
        lda #skycol
        sta (cpt),y
        iny
        sta (cpt),y
@nx     iny
        inx
        cpx #ntw
        bcc @t
        rts

; ------------------------------------------------------------
; drawall  the whole screen (init, the screen off): the score line and
; the message row blank, the town, the street, the status row blank
; ------------------------------------------------------------
drawall ldx #39
@c      lda #c_space
        sta scra,x
        sta scra+40,x
        sta scra+gk_srow,x
        lda #1
        sta $d800,x
        sta $d800+40,x
        sta $d800+gk_srow,x
        txa
        and #1
        eor #c_street+1         ; the street: a marking every other cell
        sta scra+street*40,x
        lda #streetcol
        sta $d800+street*40,x
        dex
        bpl @c
        lda #3                  ; the score line's names cyan
        ldx #4
@n      sta $d800+1,x
        sta $d800+16,x
        sta $d800+28,x
        dex
        bpl @n
        ldx #4
@hd     lda tx_score+1,x        ; the score line's names
        sta scra+1,x
        dex
        bpl @hd
        ldx #3
@hl     lda tx_town+1,x
        sta scra+16,x
        lda tx_best+1,x
        sta scra+28,x
        dex
        bpl @hl
        lda #c_digit0           ; (the scores' last digit: always 0)
        sta scra+11
        sta scra+37
        lda #f0
        sta tmp3
@r      lda tmp3
        jsr drawrow
        inc tmp3
        lda tmp3
        cmp #street
        bcc @r
        rts

; drawhud  the score, the town and the best on row 0
drawhud lda sch
        ldx #7
        jsr bcd2
        lda scl
        ldx #9
        jsr bcd2
        lda besth
        ldx #33
        jsr bcd2
        lda bestl
        ldx #35
        jsr bcd2
        lda level
        clc
        adc #1
        ldx #c_digit0
@t      cmp #10
        bcc @u
        sbc #10
        inx
        bne @t
@u      stx scra+21
        clc
        adc #c_digit0
        sta scra+22
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

; addpoint  ten points (the score's last digit is always 0): bcd
; without decimal mode (the loader's interrupt doesn't cld)
addpoint
        inc scl
        lda scl
        and #15
        cmp #10
        bcc @x
        lda scl
        adc #5                  ; (carry set: + 6)
        sta scl
        cmp #$a0
        bcc @x
        lda #0
        sta scl
        inc sch
        lda sch
        and #15
        cmp #10
        bcc @x
        lda sch
        adc #5
        sta sch
        cmp #$a0
        bcc @x
        lda #$99                ; (the most it shows)
        sta sch
        sta scl
@x      rts

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
e_drop = *-sfxdat               ; a charge away: a falling whistle
        byte $00,$90,$4c,$11,$48,$11,$44,$11,$40,$11,$3c,$11,$38,$11,$34,$11
        byte $30,$11,$2c,$11,$28,$11,0
e_boom = *-sfxdat               ; it goes off: a thud of noise
        byte $08,$00,$1c,$81,$18,$81,$14,$81,$10,$81,$0e,$81,$0c,$81,$0a,$81
        byte $08,$81,$06,$81,0
e_start = *-sfxdat              ; a town up: three notes
        byte $00,$b0,$22,$41,$22,$41,$22,$41,$2b,$41,$2b,$41,$2b,$41,$33,$41
        byte $33,$41,$33,$41,$33,$41,0
e_touch = *-sfxdat              ; wheels on the street
        byte $04,$00,$0c,$81,$0a,$81,$08,$81,0
e_land = *-sfxdat               ; landed: up and up
        byte $00,$c0,$22,$21,$22,$21,$2b,$21,$2b,$21,$33,$21,$33,$21,$44,$21
        byte $44,$21,$56,$21,$56,$21,$66,$21,$66,$21,$66,$21,0
e_crash = *-sfxdat              ; a block hit: a long roar, falling
        byte $0c,$00,$40,$81,$3a,$81,$34,$81,$30,$81,$2c,$81,$28,$81,$24,$81
        byte $20,$81,$1d,$81,$1a,$81,$17,$81,$14,$81,$12,$81,$10,$81,$0e,$81
        byte $0c,$81,$0a,$81,$09,$81,$08,$81,$07,$81,0

; ------------------------------------------------------------
; autopilot  (debug, the kit's readfire) fire now and then on the title
; and after a game over; playing, a fresh press when a charge can drop
; on a block no lower than the next two ahead of the plane. With
; dbg_auto 1 it gives up once the program has loaded (the plane flies
; on into the town: the game ends), with 2 never
;   out:  a = 0 to press fire, $10 not
; ------------------------------------------------------------
autopilot
        lda st
        cmp #st_play
        beq @play
        cmp #st_build
        beq @no
        cmp #st_land
        beq @no
        lda frm
        and #16
        rts
@play   lda dbg_auto
        cmp #2
        beq @try
        bit ld_state
        bmi @no
@try    lda fire                ; held last tick: let go first
        bne @no
        jsr canbomb
        bcc @no
        sec
        sbc #c0
        cmp #ntw*2
        bcs @no                 ; (not over the town)
        lsr a
        tax
        lda th,x
        beq @no
        sta tmp
        ldy #2                  ; the next two ahead no taller
@a      lda pdir
        bne @l
        inx
        bne @c
@l      dex
@c      cpx #ntw
        bcs @s                  ; (off the town's end)
        lda th,x
        cmp tmp
        beq @s
        bcs @no                 ; a taller one comes: wait for it
@s      dey
        bne @a
        lda #0
        rts
@no     lda #$10
        rts

        incasm "modkit.asm"
        incasm "modinit.asm"
        incasm "tables.asm"
        incasm "fadekit.asm"    ; (every module's tune fades out at the end)
        incasm "fadescr.asm"
codeend
