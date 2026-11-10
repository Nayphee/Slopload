; ------------------------------------------------------------
; bounce.asm  -  Bounce-Load: knock a wall of bricks down with a
; ball, bouncing it off a bat at the bottom of the field. Left and
; right on the joystick in port 2 move the bat (fire serves the ball,
; or it goes by itself); where the ball meets the bat sets its angle.
; Clear the wall and the next one is built, the ball faster; lose the
; last of three balls and the game is over. A SlopLoad module
; (MODULES.md).
;
; No hardware sprites. The ball (3 multicolour pixels by 6 lines) and
; the bat (12 by 5) are soft sprites: each frame they are drawn into
; up to 8 characters (the bat's 3-4 cells on row 22, the ball's 1-4,
; one character where they share a cell), each started from the glyph
; of what is under it. Two sets of 8 take turns: the tick draws into
; the set that isn't on show, and the vertical blank swaps the screen
; codes (the old cells put back, the new ones placed). Everything that
; changes the screen is written in the vertical blank: those cells,
; bricks knocked out, rows built or cleared, the score line. A map of
; what is under the soft sprites (bgmap: every cell's code, kept beside
; the screen) gives their glyphs, puts cells back, and is what the ball
; collides with.
;
; Collisions go by what is drawn. The ball moves a pixel at a time and
; stops at whatever it meets: a brick (whose cells are drawn to every
; pixel), the frame's inner edge, the bat's top line. It turns there,
; and that tick ends with it touching: the next frame shows the ball
; against what it hit. A brick it hit goes (or cracks) at the tick
; after, so it is seen touched before it is seen gone.
;
; Memory (vic bank 3): characters $e000-$e3ff (the header is
; characters 0-3; 107-127, never shown, hold the wall and the soft
; sprites' cells at run time), the screen $e400 (the character set's
; other half, never read as glyphs), code from $e800, the map in the
; page after it (run time, not on the tape). $0200-$0253: two rows'
; colours. Zero page $10-$63.
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
scra = $e400                    ; one screen: the kit's two are the same
scrb = scra
d018v = $98                     ; screen $e400, characters $e000
chr = $e000                     ; the character set
bgmap = $fc00                   ; every cell's code under the soft sprites: rows
                                ; 1-23 ($fc28-$ffbf; rows 0 and 24 never used, so
                                ; the code may run into its first 40 bytes)
bgk = (bgmap-scra)/256          ; ... its pages from the screen's
crk = (scra-$d800)/256          ; ... the colour ram's

; ---- the standard parts ----
g_claim = bgmap+960             ; end of the memory claimed
g_jitter = 48                   ; measured (tests/jitter.py --module bounce --auto 2): 99.9%
                                ; 48 on pal, ntsc and a c128; 51 at most
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 1                       ; it makes effects on voice 3 (beside SlopLoad's player)
g_wait = 1                      ; with -wait it plays on until SPACE or a game's end (the kit's)
g_count = 1                     ; with -countdown its status line counts blocks (the kit's)
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; the status bar: 9 characters, 1 px a step
gk_srow = 24*40                 ; the status line: row 24

; ---- the field ----
batrow = 22                     ; the bat's row (its top line: baty)
fcols = 32                      ; the field's columns (4-35)
msgrow = 16                     ; the message row
fcol = 8                        ; colour ram: the field, multicolour (black)
batcol = 8+3                    ; ... the bat's row (cyan)
wallcol = 8+6                   ; ... the frame (blue)
sidecol = 8+6                   ; ... the backdrop outside it
c1v = 1                         ; $d022: white
c2v = 15                        ; $d023: light grey
batmin = fx0                    ; the bat's left: batmin to batmax
batmax = fx1-batw
batmid = (batmin+batmax)/2
lostline = 192                  ; a ball whose bottom gets here is lost (row 24)
nballs = 3
lockout = 50                    ; ticks before game over takes fire
serveticks = 150                ; the ball leaves the bat by itself after this
losttime = 60                   ; ticks after a ball is lost
cleartime = 90                  ; ticks after a wall is down
bonus = 50                      ; a wall down: 500 points (in tens)
hitsup = 6                      ; bat hits to each speed up
topspd = 7                      ; the fastest speed (nspeeds - 1)

; ---- states ----
st_title = 0
st_play = 1
st_over = 2
st_build = 3                    ; a wall being built (a row a tick)
st_serve = 4                    ; the ball on the bat
st_lost = 5                     ; a ball lost
st_clear = 6                    ; a wall down

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
pt3 = $26                       ; 2
ballx = $28                     ; the ball's left, screen multicolour pixels (fx0 on)
bally = $29                     ; ... its top line (fy0 on)
bxacc = $2a                     ; ... fractions of a pixel (1/16)
byacc = $2b
bvx = $2c                       ; its speed across (1/16 pixel a tick)
bvy = $2d                       ; ... and down or up (1/16 line a tick)
bdx = $2e                       ; 0 right, 1 left
bdy = $2f                       ; 0 down, 1 up
bspd = $30                      ; the speed (0-topspd)
hits = $31                      ; bat hits since the serve
batx = $32                      ; the bat's left (screen multicolour pixels)
batrun = $33                    ; ticks the stick has been held (the bat speeds up)
balls = $34                     ; balls left, the one in play too
level = $35                     ; 0 on
bleft = $36                     ; bricks left in the wall
ballon = $37                    ; 1: the ball is shown
vis = $38                       ; the soft sprites' set on show: 0 a, 1 b
nready = $39                    ; 1: the other set is drawn, ready to show
curn = $3a                      ; the cells on show
newn = $3b                      ; ... and drawn for the next frame
hset = $3c                      ; the set being drawn: its first code
nph = $3d                       ; bricks hit, to knock out next tick
ph = $3e                        ; ... them (2)
sc = $40                        ; the score: 6 digits, 0-9 a byte, high first
hi = $46                        ; the best score (6)
sfxp = $4c                      ; the effect: its place in sfxdat (0: none)
sfxc = $4d                      ; ... its last control byte
sfxtr = $4e                     ; ... added to its pitch
hud = $4f                       ; 1: the score line to draw
nrq = $50                       ; rows to copy to the screen (0-2)
rq = $51                        ; ... them (2)
aim = $53                       ; autopilot: where on the bat it takes the ball
build = $54                     ; the next row to build
bumped = $55                    ; 1: the ball met something this tick
nsx = $56                       ; steps left this tick, across
nsy = $57                       ; ... and up or down
ncq = $58                       ; cells to copy to the screen
batc = $59                      ; render: the bat's first cell
bsft = $5a                      ; ... its shift (0-3)
nbc = $5b                       ; ... its cells
bsh = $5c                       ; ... the ball's shift
bys = $5d                       ; ... its line in its first row
ncols = $5e                     ; ... its cells across
nrows = $5f                     ; ... and down
cnt = $60                       ; scratch
tcol = $61                      ; a message's colour
bix = $62                       ; render: the ball's image index (shift x 12)
hrow = $63                      ; collide: a cell's row
bend = $64                      ; the build: the row it stops before
bnext = $65                     ; ... then: the title (0) or the serve (1)
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: 1 plays until the program is in, 2 never loses

*=$ce80                         ; the fade (every module's tune fades out at the
lowpart                         ; end) and its scratch: a second part, past
        incasm "fadekit.asm"    ; SlopLoad's player at $c000 (tools/build.py
        incasm "fadescr.asm"    ; splits it off)
lowend

*=$e000
mainpart
        incasm "modhead.asm"
        incasm "chars.asm"

*=$e800

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
        sta $d015               ; no sprites
        jsr gk_bord             ; (the border: gk_bord, never sta $d020)
        sta $d021
        sta dbg_space
        sta dbg_auto
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
        lda #c1v
        sta $d022
        lda #c2v
        sta $d023
        lda #6
        sta ntscc
        lda #$a7
        sta rnd
        sta rnd+1
        lda #$ff
        sta smode               ; (the status line: drawn at the first frame)
        lda #nballs
        sta balls
        jsr drawall             ; the frame, an empty field, the score line
        lda #7                  ; the title, in the field
        sta tcol
        ldx #<tx_title
        ldy #>tx_title
        lda #13
        jsr puttext
        lda #1
        sta tcol
        ldx #<tx_t1
        ldy #>tx_t1
        lda #15
        jsr puttext
        ldx #<tx_t2
        ldy #>tx_t2
        lda #17
        jsr puttext
        lda #3
        sta tcol
        ldx #<tx_t3
        ldy #>tx_t3
        lda #19
        jsr puttext
        jsr loadlevel           ; the first wall, built over the title's first
        lda #st_build           ; ticks (rows 2-12: the texts stay)
        sta st
        lda #2
        sta build
        lda #13
        sta bend
        lda #batmid
        sta batx
        jsr render              ; the bat, shown at once
        jsr swap
        jsr sidinit
        jmp musicgo

; ------------------------------------------------------------
; stop  silence; the core blanks the screen after
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
; vbwork  in the vertical blank: what the last tick drew, shown. The
; score line, then the soft sprites' cells put back, the cells and
; rows the tick changed, the new soft sprites placed
; ------------------------------------------------------------
vbwork  lda hud
        beq @c
        jsr drawhud
        lda #0
        sta hud
@c      lda nready
        beq @x                  ; (no tick since the last: nothing changed)
        jsr restore             ; the cells on show put back
        ldx ncq                 ; bricks knocked out or cracked
        beq @rows
@cq     dex
        lda cqlo,x
        sta pt
        sta pt3
        lda cqhi,x
        sta pt+1
        clc
        adc #bgk
        sta pt3+1
        ldy #0
        lda (pt3),y
        sta (pt),y
        txa
        bne @cq
        stx ncq
@rows   jsr flushrows           ; rows built or cleared
        jmp place               ; the new cells
@x      rts

; ------------------------------------------------------------
; flushrows  the rows asked for (rq, nrq) to the screen: codes from the
; map, colours from the row's buffer
; ------------------------------------------------------------
flushrows
        lda nrq
        beq @x
        cmp #2
        bne @one
        lda rq+1
        ldx #1
        jsr putrow
@one    lda rq
        ldx #0
        jsr putrow
        lda #0
        sta nrq
@x      rts

; putrow  row a's field (columns 4-35: the frame and backdrop never
; change) to the screen from the map, its colours from buffer x
putrow  tay
        lda rowlo,y
        clc
        adc #4
        sta pt
        sta pt3
        sta pt2
        lda rowhi,y
        adc #0
        sta pt+1
        adc #bgk                ; (carry clear)
        sta pt3+1
        lda pt+1
        sec
        sbc #crk
        sta pt2+1
        lda bufhi,x             ; (the buffer, from its column 4: tmp, tmp2)
        sta tmp2
        lda buflo,x
        clc
        adc #4
        sta tmp
        ldy #fcols-1
@c      lda (pt3),y
        sta (pt),y
        dey
        bpl @c
        lda tmp                 ; the colours: the buffer through pt3
        sta pt3
        lda tmp2
        sta pt3+1
        ldy #fcols-1
@k      lda (pt3),y
        sta (pt2),y
        dey
        bpl @k
        rts
buflo   byte <rowbuf0,<rowbuf1
bufhi   byte >rowbuf0,>rowbuf1

; ------------------------------------------------------------
; swap  the soft sprites drawn for the next frame put on the screen
; (the old cells first put back: vbwork); place does the second half
; ------------------------------------------------------------
swap    jsr restore
        jmp place

; restore  the soft sprites' cells on show put back from the map
restore ldx curn
        beq @x
@r      dex
        lda curlo,x
        sta pt
        sta pt3
        lda curhi,x
        sta pt+1
        clc
        adc #bgk
        sta pt3+1
        ldy #0
        lda (pt3),y
        sta (pt),y
        txa
        bne @r
@x      rts

; place  the cells drawn for the next frame on the screen; that set on show
place   ldx newn
        stx curn
        beq @d
@p      dex
        lda newlo,x
        sta pt
        sta curlo,x
        lda newhi,x
        sta pt+1
        sta curhi,x
        lda newcd,x
        ldy #0
        sta (pt),y
        txa
        bne @p
@d      lda vis
        eor #1
        sta vis
        lda #0
        sta nready
        rts

; ------------------------------------------------------------
; tick  one step of the game, then the soft sprites drawn for the
; next frame
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
        jsr @go
        jmp render
@go     ldx st
        lda sthi,x
        pha
        lda stlo,x
        pha
        rts
stlo    byte <t_title-1,<t_play-1,<t_over-1,<t_build-1,<t_serve-1,<t_lost-1,<t_clear-1
sthi    byte >t_title-1,>t_play-1,>t_over-1,>t_build-1,>t_serve-1,>t_lost-1,>t_clear-1

; ---- title: fire starts a game (the program starts as soon as it's
; in, unless -wait: the kit's startkey) ----
t_title jsr steer
        lda fpress
        beq @x
        jmp newgame
@x      rts

; ---- a wall being built: a row a tick, then the serve ----
t_build jsr steer
        lda build
        jsr rowreq
        inc build
        lda build
        cmp bend
        bcc @x
        lda bnext
        bne @s
        sta st                  ; (the title's wall: st_title)
        rts
@s      jmp servego
@x      rts

; ---- the serve: the ball rides the bat; fire (or time) sends it ----
t_serve jsr steer
        jsr onbat
        lda fpress
        bne @go
        lda tmr
        cmp #serveticks
        bcc @x
@go     jmp launch
@x      rts

; ---- playing ----
t_play  lda nph
        beq @mv
        jsr applyhits           ; the last tick's bricks
        lda st
        cmp #st_play
        bne @x                  ; (the wall is down)
@mv     jsr steer
        jmp moveball
@x      rts

; ---- a ball lost: a moment, then the next, or the game is over ----
t_lost  jsr steer
        lda tmr
        cmp #losttime
        bcc @x
        lda balls
        bne @s
        jmp overgo
@s      jmp servego
@x      rts

; ---- a wall down: a moment, then the next is built ----
t_clear jsr steer
        lda tmr
        cmp #cleartime
        bcc @x
        lda level
        cmp #98
        bcs @l
        inc level
@l      lda #1
        sta hud
        jsr loadlevel
        jmp buildgo
@x      rts

; ---- game over: once loaded, the program starts (gk_done: with -wait,
; the end of a game); before, after a lockout, fire plays again ----
t_over  jsr gk_done
        jsr steer
        lda tmr
        cmp #lockout
        bcc @x
        lda fpress
        beq @x
        jmp newgame
@x      rts

; ------------------------------------------------------------
; the game's steps
; ------------------------------------------------------------
newgame lda #0
        ldx #5
@z      sta sc,x
        dex
        bpl @z
        sta level
        lda #nballs
        sta balls
        lda #1
        sta hud
        jsr loadlevel
buildgo lda #st_build
        sta st
        lda #0
        sta tmr
        sta ballon
        lda #2                  ; rows 2-21: the wall and the rows round it
        sta build
        lda #batrow
        sta bend
        lda #1                  ; then the serve
        sta bnext
        rts

servego lda #st_serve
        sta st
        lda #0
        sta tmr
        sta hits
        sta bxacc
        sta byacc
        lda #1
        sta ballon
        lda level               ; the level's first speed
        cmp #4
        bcc @s
        lda #4
@s      sta bspd
        jsr onbat
        lda #7                  ; "LEVEL nn" a while
        sta tcol
        ldx #<tx_lvmsg
        ldy #>tx_lvmsg
        lda #msgrow
        jsr message
        bcs @x
        lda level
        clc
        adc #1
        jsr twodig
        txa
        ldy #22
        sta (pt),y
        lda tcol
        sta (pt3),y
        iny
        lda twodu
        sta (pt),y
        lda tcol
        sta (pt3),y
@x      ldx #e_serve
        jmp sfx

; onbat  the ball on the bat's middle
onbat   lda batx
        clc
        adc #(batw-ballw)/2
        sta ballx
        lda #baty-ballh
        sta bally
        rts

; launch  the ball off the bat, up and to one side at random
launch  lda #st_play
        sta st
        lda #0
        sta tmr
        jsr random
        and #1
        sta bdx
        lda #1
        sta bdy
        lda #1                  ; the second angle
        jsr setvel
        lda #msgrow             ; the message gone
        jsr rowreq
        ldx #e_serve
        jmp sfx

; setvel  the ball's speed along angle a (0-3) at speed bspd
setvel  sta tmp
        lda bspd
        asl a
        asl a
        ora tmp
        tax
        lda angvx,x
        sta bvx
        lda angvy,x
        sta bvy
        rts

overgo  lda #st_over
        sta st
        lda #0
        sta tmr
        sta ballon
        lda #7
        sta tcol
        ldx #<tx_over
        ldy #>tx_over
        lda #15
        jsr message
        lda #1
        sta tcol
        ldx #<tx_again
        ldy #>tx_again
        lda #17
        jsr message
        ldx #e_over
        jmp sfx

; lost  the ball gone past the bat
lost    lda #st_lost
        sta st
        lda #0
        sta tmr
        sta ballon
        dec balls
        lda #1
        sta hud
        sta bumped
        ldx #e_lost
        jmp sfx

; ------------------------------------------------------------
; steer  the bat: the stick on port 2 (or the autopilot); in the
; serve the ball goes with it
; ------------------------------------------------------------
steer   lda dbg_auto
        beq @joy
        jmp autosteer
@joy    lda #$ff
        sta $dc00               ; no keyboard row: port 2 alone
        lda $dc00
        and #$0c                ; left, right (0: held)
        cmp #$0c
        beq @none
        tax
        ldy batrun              ; it speeds up while held
        cpy #batacc_n-1
        bcs @r
        inc batrun
@r      lda batacc,y
        cpx #8                  ; left held (right not)
        beq @left
        cpx #4
        bne @x                  ; both: nothing
        jmp batright
@left   jmp batleft
@none   lda #0
        sta batrun
@x      rts
batacc  byte 1,1,2,2,2,3
batacc_n = *-batacc

; batleft, batright  the bat a pixels that way, no further than the frame
batleft sta tmp
        lda batx
        sec
        sbc tmp
        bcc @lo
        cmp #batmin
        bcs @s
@lo     lda #batmin
@s      sta batx
        rts

batright
        clc
        adc batx
        cmp #batmax+1
        bcc @s
        lda #batmax
@s      sta batx
        rts

; ------------------------------------------------------------
; moveball  the ball by its speed, a pixel at a time, across and down
; or up in turn; it stops at the first thing it meets (bumped)
; ------------------------------------------------------------
moveball
        lda #0
        sta bumped
        lda bxacc
        clc
        adc bvx
        tax
        and #15
        sta bxacc
        txa
        lsr a
        lsr a
        lsr a
        lsr a
        sta nsx
        lda byacc
        clc
        adc bvy
        tax
        and #15
        sta byacc
        txa
        lsr a
        lsr a
        lsr a
        lsr a
        sta nsy
@step   lda nsy
        beq @nx
        dec nsy
        jsr stepy
        lda bumped
        bne @x
@nx     lda nsx
        beq @n
        dec nsx
        jsr stepx
        lda bumped
        bne @x
@n      lda nsx
        ora nsy
        bne @step
@x      rts

; stepx  a pixel across
stepx   lda bdx
        bne @left
        lda ballx               ; right: the column the ball's right edge moves to
        clc
        adc #ballw
        cmp #fx1
        bcs @wall
        jsr colhit
        bcs @bump
        inc ballx
        rts
@left   lda ballx               ; left: the column its left edge moves to
        sec
        sbc #1
        cmp #fx0
        bcc @wall
        jsr colhit
        bcs @bump
        dec ballx
        rts
@wall   jsr wallsfx
@bump   lda bdx
        eor #1
        sta bdx
        lda #1
        sta bumped
        rts

; stepy  a line down or up
stepy   lda bdy
        bne @up
        lda bally               ; down: the line its bottom moves to
        clc
        adc #ballh
        cmp #baty
        bne @nb
        jsr batcheck            ; at the bat's top line: on the bat?
        bcs @x
        lda #baty
@nb     cmp #lostline
        bcc @d
        jmp lost
@d      jsr rowhit
        bcs @bump
        inc bally
@x      rts
@up     lda bally               ; up: the line its top moves to
        sec
        sbc #1
        cmp #fy0
        bcc @wall
        jsr rowhit
        bcs @bump
        dec bally
        rts
@wall   jsr wallsfx
@bump   lda bdy
        eor #1
        sta bdy
        lda #1
        sta bumped
        rts

; colhit  column a (multicolour pixels) over the ball's lines: a brick?
;   out:  c set: hit (the bricks noted for the next tick)
colhit  lsr a
        lsr a
        tay                     ; the cell's column
        lda bally
        lsr a
        lsr a
        lsr a
        jsr cellhit
        php
        lda bally
        clc
        adc #ballh-1
        lsr a
        lsr a
        lsr a
        cmp hrow
        beq @one                ; (one row)
        jsr cellhit
        bcc @one
        pla
        sec
        rts
@one    plp
        rts

; rowhit  line a over the ball's columns: a brick?
;   out:  c set: hit
rowhit  lsr a
        lsr a
        lsr a
        sta hrow
        lda ballx
        lsr a
        lsr a
        tay
        lda hrow
        jsr cellhit
        php
        lda ballx
        clc
        adc #ballw-1
        lsr a
        lsr a
        sta tmp
        cpy tmp
        beq @one
        ldy tmp
        lda hrow
        jsr cellhit
        bcc @one
        pla
        sec
        rts
@one    plp
        rts

; cellhit  the cell at row a, column y: a brick? (noted if so)
;   out:  c set: a brick; keeps y; hrow = a
cellhit sta hrow
        tax
        lda rowlo,x
        sta pt3
        lda rowhi,x
        clc
        adc #bgk
        sta pt3+1
        lda (pt3),y
        sec
        sbc #c_brick
        cmp #6
        bcs @no
        tya                     ; the brick: (row - 4) x 16 + (column - 4) / 2
        sec
        sbc #4
        lsr a
        sta tmp
        lda hrow
        sec
        sbc #brow0
        asl a
        asl a
        asl a
        asl a
        ora tmp
        ldx nph                 ; noted once
        beq @add
        cmp ph
        beq @yes
        cpx #2
        bcs @yes
@add    sta ph,x
        inc nph
@yes    sec
        rts
@no     clc
        rts

; batcheck  the ball's bottom at the bat's top line: on the bat? Then
; up, at the angle where it met it (the middle keeps its way across)
;   out:  c set: it bounced
batcheck
        lda ballx
        clc
        adc #ballw-1
        cmp batx
        bcc @no                 ; all left of it
        lda batx
        clc
        adc #batw-1
        cmp ballx
        bcc @no                 ; all right of it
        lda ballx               ; where: 0-13 (the ball's middle from the
        clc                     ; bat's left - 1 to its right + 1)
        adc #2
        sec
        sbc batx
        tax
        lda zonedir,x
        cmp #2
        bcs @k
        sta bdx
@k      lda #1
        sta bdy
        sta bumped
        inc hits
        lda hits
        cmp #hitsup
        bcc @a
        lda #0
        sta hits
        lda bspd
        cmp #topspd
        bcs @a
        inc bspd
@a      lda zoneang,x
        jsr setvel
        lda dbg_auto            ; the autopilot: somewhere else on the bat next time
        beq @s
        jsr random
        and #7
        sec
        sbc #4
        sta aim
@s      ldx #e_bat
        jsr sfx
        sec
        rts
@no     clc
        rts

; ------------------------------------------------------------
; applyhits  the bricks the ball hit last tick: a tough one cracks,
; any other goes; points; the wall down when none is left
; ------------------------------------------------------------
applyhits
        ldx #0
@h      stx cnt
        ldy ph,x
        sty tmp2
        lda bricks,y
        beq @n                  ; (gone already)
        cmp #8
        bcc @gone
        cmp #$10
        bcs @gone
        and #7                  ; tough: cracked
        ora #$10
        sta bricks,y
        lda #1
        jsr addpts
        ldx #e_tough
        jsr sfx
        jmp @draw
@gone   and #$f8
        cmp #$10
        lda #10                 ; a cracked one: 100
        bcs @p
        lda bricks,y
        tax
        lda points,x
@p      jsr addpts
        ldy tmp2
        lda #0
        sta bricks,y
        dec bleft
        tya                     ; the pitch by its row
        lsr a
        lsr a
        lsr a
        lsr a
        eor #7
        asl a
        asl a
        pha
        ldx #e_brick
        jsr sfx
        pla
        sta sfxtr
@draw   ldy tmp2
        jsr drawbrick
@n      ldx cnt
        inx
        cpx nph
        bne @h
        lda #0
        sta nph
        lda bleft
        bne @x
        lda #st_clear           ; the wall is down
        sta st
        lda #0
        sta tmr
        sta ballon
        lda #bonus
        jsr addpts
        lda #7
        sta tcol
        ldx #<tx_down
        ldy #>tx_down
        lda #msgrow
        jsr message
        ldx #e_clear
        jmp sfx
@x      rts

; drawbrick  brick y's two cells into the map, and asked for
drawbrick
        tya
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #brow0
        tax                     ; its row
        tya
        and #15
        asl a
        adc #4                  ; its first column
        clc
        adc rowlo,x
        sta pt3
        lda rowhi,x
        adc #0
        sta tmp
        clc
        adc #bgk
        sta pt3+1
        lda bricks,y
        jsr brcode
        ldy #0
        sta (pt3),y
        cmp #c_space
        beq @r
        clc
        adc #1
@r      iny
        sta (pt3),y
        ldx ncq                 ; both cells to the screen
        lda pt3
        sta cqlo,x
        clc
        adc #1
        sta cqlo+1,x
        lda tmp
        sta cqhi,x
        adc #0
        sta cqhi+1,x
        inx
        inx
        stx ncq
        rts

; brcode  a brick's value -> a = its left cell's code (the right's + 1,
; but a space for none), x = its colour ram
brcode  tax
        beq @n
        lsr a
        lsr a
        and #6                  ; plain 0, tough 2, cracked 4
        clc
        adc #c_brick
        pha
        txa
        and #7
        ora #8
        tax
        pla
        rts
@n      ldx #fcol
        lda #c_space
        rts

; ------------------------------------------------------------
; the score: 6 digits a byte each (no decimal mode: the loader's
; interrupt doesn't cld). addpts adds a tens of points; the best
; follows it
; ------------------------------------------------------------
addpts  ldx #4
@d      clc
        adc sc,x
        ldy #0                  ; the carry to the next digit
@s      cmp #10
        bcc @ok
        sbc #10
        iny
        bne @s
@ok     sta sc,x
        tya
        beq @hi
        dex
        bpl @d
        lda #9                  ; past 999,990: nines
        ldx #5
@n      sta sc,x
        dex
        bpl @n
@hi     lda #1
        sta hud
        ldx #0
@c      lda sc,x
        cmp hi,x
        bcc @x
        bne @new
        inx
        cpx #6
        bne @c
@x      rts
@new    ldx #5
@cp     lda sc,x
        sta hi,x
        dex
        bpl @cp
        rts

; twodig  a (0-99) as two digit codes: x tens, twodu units
twodig  ldx #c_digit0
@t      cmp #10
        bcc @u
        sbc #10
        inx
        bne @t
@u      clc
        adc #c_digit0
        sta twodu
        rts
twodu   byte 0

; drawhud  the score line's numbers (row 0)
drawhud ldx #5
@s      lda sc,x
        clc
        adc #c_digit0
        sta scra+7,x
        lda hi,x
        clc
        adc #c_digit0
        sta scra+34,x
        dex
        bpl @s
        lda level
        clc
        adc #1
        jsr twodig
        stx scra+20
        lda twodu
        sta scra+21
        lda balls
        clc
        adc #c_digit0
        sta scra+29
        rts

; ------------------------------------------------------------
; loadlevel  the level's wall into bricks (its layout: level mod 8)
; ------------------------------------------------------------
loadlevel
        lda level
        and #nlevels-1
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a
        sta pt                  ; 64 bytes a level
        lda #0
        rol a                   ; (nlevels 8: up to 448)
        sta pt+1
        lda pt
        clc
        adc #<levels
        sta pt
        lda pt+1
        adc #>levels
        sta pt+1
        ldy #0
        ldx #0
        stx bleft
@b      lda (pt),y
        and #15
        jsr @put
        lda (pt),y
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @put
        iny
        cpy #64
        bne @b
        rts
@put    sta bricks,x
        inx
        cmp #0
        beq @e
        inc bleft
@e      rts

; ------------------------------------------------------------
; rows: mkrow builds a row of the field in the map (its colours in a
; buffer); rowreq asks for it on the screen at the next vertical blank;
; message does the same with a text in it
; ------------------------------------------------------------
; rowreq  row a built and asked for
;   out:  c set: no room this tick (two rows asked already)
rowreq  ldx nrq
        cpx #2
        bcs @x
        sta rq,x
        inc nrq
        jsr mkrow
        clc
@x      rts

; message  text x/y (length first) centred on row a, colour tcol
;   out:  c set: no room; else pt the row in the map, pt3 its colours
message stx pt2
        sty pt2+1
        jsr rowreq
        bcs @x
        ldy #0
        lda (pt2),y
        sta tmp
        lda #40
        sec
        sbc tmp
        lsr a
        sta tmp2                ; its first column
        clc
        adc pt
        sta pt
        bcc @c
        inc pt+1
@c      lda tmp2
        clc
        adc pt3
        sta pt3
        bcc @c2
        inc pt3+1
@c2     ldy tmp
@t      lda (pt2),y
        dey
        sta (pt),y
        lda tcol
        sta (pt3),y
        cpy #0
        bne @t
        lda pt                  ; (pt, pt3 back to the row's start)
        sec
        sbc tmp2
        sta pt
        bcs @c3
        dec pt+1
@c3     lda pt3
        sec
        sbc tmp2
        sta pt3
        bcs @c4
        dec pt3+1
@c4     clc
@x      rts

; mkrow  row a (0-23) into the map, its colours into buffer x
;   out:  pt the row in the map, pt3 its colours
mkrow   sta tmp3
        tay
        lda rowlo,y
        sta pt
        lda rowhi,y
        clc
        adc #bgk
        sta pt+1
        lda buflo,x
        sta pt3
        lda bufhi,x
        sta pt3+1
        ldy #39                 ; the backdrop
@sd     lda #c_side
        sta (pt),y
        lda #sidecol
        sta (pt3),y
        dey
        cpy #36
        bne @sd
        ldy #2
@sl     lda #c_side
        sta (pt),y
        lda #sidecol
        sta (pt3),y
        dey
        bpl @sl
        lda #wallcol
        ldy #3
        sta (pt3),y
        ldy #36
        sta (pt3),y
        lda tmp3
        cmp #1
        bne @f
        lda #c_cornr            ; the frame's top
        sta (pt),y
        ldy #3
        lda #c_cornl
        sta (pt),y
        iny
@tw     lda #c_wallt
        sta (pt),y
        lda #wallcol
        sta (pt3),y
        iny
        cpy #36
        bne @tw
        rts
@f      lda #c_wallr            ; its sides
        sta (pt),y
        ldy #3
        lda #c_walll
        sta (pt),y
        lda tmp3                ; inside: a row of the wall?
        sec
        sbc #brow0
        cmp #8
        bcs @blank
        asl a
        asl a
        asl a
        asl a
        sta tmp2                ; the row's first brick
        ldy #4
@br     ldx tmp2
        lda bricks,x
        jsr brcode
        sta (pt),y
        cmp #c_space
        beq @sp
        clc
        adc #1
@sp     iny
        sta (pt),y
        txa
        sta (pt3),y
        dey
        sta (pt3),y
        iny
        iny
        inc tmp2
        cpy #36
        bne @br
        rts
@blank  ldx #fcol
        lda tmp3
        cmp #batrow
        bne @bc
        ldx #batcol
@bc     stx tmp
        ldy #4
@bl     lda #c_space
        sta (pt),y
        lda tmp
        sta (pt3),y
        iny
        cpy #36
        bne @bl
        rts

; ------------------------------------------------------------
; drawall  the whole screen (init, the screen off, quickly: a chain's
; second module is set up while the tune waits): the screen and the map
; blank, the colours the field's; then the frame, the backdrop beside
; it, the bat's row, the score line
; ------------------------------------------------------------
drawall ldx #0
@f      lda #c_space
        sta scra,x
        sta scra+$100,x
        sta scra+$200,x
        sta scra+$2e8,x
        sta bgmap+40,x          ; (the map's rows 1-23)
        sta bgmap+40+$100,x
        sta bgmap+40+$200,x
        sta bgmap+960-$100,x
        lda #fcol
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne @f
        lda #1                  ; rows 0 and 24: hi-res, white
        ldx #39
@w      sta $d800,x
        sta $d800+gk_srow,x
        dex
        bpl @w
        lda #batcol             ; the bat's row
        ldx #fcols-1
@b      sta $d800+batrow*40+4,x
        dex
        bpl @b
        lda #1                  ; rows 1-23: the frame and the backdrop
@r      sta tmp3
        tax
        lda rowlo,x
        sta pt
        sta pt3
        sta pt2
        lda rowhi,x
        sta pt+1
        clc
        adc #bgk
        sta pt3+1
        lda rowhi,x
        sec
        sbc #crk
        sta pt2+1
        ldx #7
@e      ldy edgecol,x
        lda edgecode,x
        sta (pt),y
        sta (pt3),y
        lda edgeclr,x
        sta (pt2),y
        dex
        bpl @e
        ldx tmp3
        inx
        txa
        cpx #24
        bcc @r
        lda #c_cornl            ; row 1: the frame's top
        sta scra+40+3
        sta bgmap+40+3
        lda #c_cornr
        sta scra+40+36
        sta bgmap+40+36
        ldx #fcols-1            ; row 1: the frame's top
@t      lda #c_wallt
        sta scra+40+4,x
        sta bgmap+40+4,x
        lda #wallcol
        sta $d800+40+4,x
        dex
        bpl @t
        ldx #4                  ; the score line's names, cyan
@n      lda tx_score+1,x
        sta scra+1,x
        lda tx_lvmsg+1,x        ; ("LEVEL")
        sta scra+14,x
        lda tx_balls+1,x
        sta scra+23,x
        lda #3
        sta $d800+1,x
        sta $d800+14,x
        sta $d800+23,x
        dex
        bpl @n
        lda tx_hi+1
        sta scra+31
        lda tx_hi+2
        sta scra+32
        lda #3
        sta $d800+31
        sta $d800+32
        jmp drawhud
edgecol byte 0,1,2,3,36,37,38,39        ; a row's edges: backdrop, walls
edgecode byte c_side,c_side,c_side,c_walll,c_wallr,c_side,c_side,c_side
edgeclr byte sidecol,sidecol,sidecol,wallcol,wallcol,sidecol,sidecol,sidecol

; puttext  text x/y (length first) centred on row a, colour tcol, at
; once: the screen, the map, the colours (init)
puttext stx pt2
        sty pt2+1
        tax
        lda rowlo,x
        sta pt
        sta pt3
        lda rowhi,x
        sta pt+1
        clc
        adc #bgk
        sta pt3+1
        ldy #0
        lda (pt2),y
        sta tmp
        lda #40                 ; its first column, less one (y counts from 1)
        sec
        sbc tmp
        lsr a
        sec
        sbc #1
        clc
        adc pt
        sta pt
        sta pt3
        bcc @c
        inc pt+1
        inc pt3+1
@c      ldy tmp
@t      lda (pt2),y
        sta (pt),y
        sta (pt3),y
        dey
        bne @t
        lda pt+1                ; the colours
        sec
        sbc #crk
        sta pt3+1
        lda tcol
        ldy tmp
@k      sta (pt3),y
        dey
        bne @k
        rts

; ------------------------------------------------------------
; render  the soft sprites into the set not on show, for the next
; frame: the bat's cells on its row, then the ball's (sharing the bat's
; where they meet), each started from the glyph under it
; ------------------------------------------------------------
render  lda vis
        bne @a
        lda #c_setb
        byte $2c                ; (bit abs: past the lda)
@a      lda #c_seta
        sta hset
        lda #0
        sta newn
        lda batx                ; the bat
        and #3
        sta bsft
        lda batx
        lsr a
        lsr a
        sta batc
        ldx #3                  ; 3 cells, or 4 when not on a cell's edge
        lda bsft
        beq @n3
        inx
@n3     stx nbc
        lda bsft                ; its images: shift x 20
        asl a
        asl a
        sta tmp
        asl a
        asl a
        adc tmp
        sta bix
        lda #0
        sta cnt
@bc     lda cnt
        clc
        adc batc
        tay
        lda #batrow
        jsr newslot             ; x = the cell's first byte in the set's page
        ldy bix
        lda #bath               ; its lines 2-6
        sta tmp
@bl     lda chr+2,x
        and batmsk,y
        ora batimg,y
        sta chr+2,x
        inx
        iny
        dec tmp
        bne @bl
        lda bix
        clc
        adc #bath
        sta bix
        inc cnt
        lda cnt
        cmp nbc
        bne @bc
        lda ballon
        bne ballspr
        lda #1
        sta nready
        rts

; the ball: its cells (1-4), then its lines laid over them
ballspr lda ballx
        and #3
        sta bsh
        asl a                   ; its images: shift x 12
        adc bsh
        asl a
        asl a
        sta bix
        lda bsh
        clc
        adc #ballw+3
        lsr a
        lsr a
        sta ncols
        lda bally
        and #7
        sta bys
        clc
        adc #ballh+7
        lsr a
        lsr a
        lsr a
        sta nrows
        lda #0
        sta cnt                 ; the cell: row x 2 + column
@cell   lda cnt
        lsr a
        cmp nrows
        bcs @lay
        sta tmp3
        lda cnt
        and #1
        cmp ncols
        bcs @next
        sta tmp
        lda ballx
        lsr a
        lsr a
        clc
        adc tmp
        tay                     ; its column
        lda bally
        lsr a
        lsr a
        lsr a
        clc
        adc tmp3                ; its row
        cmp #batrow
        bne @own
        tya
        sec
        sbc batc
        cmp nbc
        bcs @own2
        clc                     ; one of the bat's: the same character
        adc hset
        asl a
        asl a
        asl a
        tax
        bne @got
@own2   lda #batrow
@own    jsr newslot
@got    txa
        ldx cnt
        sta bslot8,x
@next   inc cnt
        bne @cell
@lay    ldx #0                  ; line by line
@ln     stx cnt
        txa
        clc
        adc bys
        tay
        and #7
        sta tmp2                ; the line in its cell
        tya
        lsr a
        lsr a
        and #2                  ; the cell's row x 2 (rows 0, 1: bit 3 of the line)
        sta tmp3
        txa
        clc
        adc bix
        sta tmp                 ; the image's byte (column 0)
        ldy tmp3
        lda bslot8,y
        ora tmp2
        tay
        ldx tmp
        lda chr,y
        and ballmsk,x
        ora ballimg,x
        sta chr,y
        lda ncols
        cmp #2
        bne @n2
        ldy tmp3
        lda bslot8+1,y
        ora tmp2
        tay
        lda chr,y
        and ballmsk+ballh,x
        ora ballimg+ballh,x
        sta chr,y
@n2     ldx cnt
        inx
        cpx #ballh
        bne @ln
        lda #1
        sta nready
        rts

; newslot  a new cell for the soft sprites: row a, column y. Its screen
; address and its character (the next of the set) noted, the glyph under
; it copied into that character
;   out:  x = the character's first byte in the set's page (code x 8)
newslot tax
        lda rowlo,x
        sta tmp
        lda rowhi,x
        sta pt3+1
        tya
        clc
        adc tmp
        sta pt3
        bcc @p
        inc pt3+1
@p      ldx newn
        sta newlo,x
        lda pt3+1
        sta newhi,x
        clc
        adc #bgk
        sta pt3+1
        txa
        clc
        adc hset
        sta newcd,x
        inc newn
        asl a
        asl a
        asl a
        sta tmp                 ; the character's first byte
        ldy #0
        lda (pt3),y             ; the code under it
        sta pt2
        lda #0
        asl pt2
        rol a
        asl pt2
        rol a
        asl pt2
        rol a
        ora #>chr
        sta pt2+1               ; its glyph
        ldx tmp
@c      lda (pt2),y
        sta chr,x
        inx
        iny
        cpy #8
        bne @c
        ldx tmp
        rts

; ------------------------------------------------------------
; autosteer  (debug) the autopilot: the bat under the ball, taking it
; at aim from the bat's middle; with dbg_auto 1 it gives up once the
; program has loaded (the bat runs from the ball), with 2 never
; ------------------------------------------------------------
autosteer
        lda st
        cmp #st_play
        bne @x
        lda dbg_auto
        cmp #2
        beq @play
        bit ld_state
        bpl @play
        lda ballx               ; given up: to the side away from the ball
        cmp #(fx0+fx1)/2
        lda #batmin
        bcs @tgt
        lda #batmax
        bne @tgt
@play   lda ballx               ; the ball's middle at the bat's middle + aim
        sec
        sbc #(batw-ballw)/2
        bcc @lo
        sec
        sbc aim
        cmp #batmin
        bcs @c2
@lo     lda #batmin
@c2     cmp #batmax+1
        bcc @tgt
        lda #batmax
@tgt    sec
        sbc batx
        beq @x
        bcc @left
        cmp #3                  ; right, no further than the target
        bcc @r
        lda #3
@r      jmp batright
@left   eor #$ff                ; left
        adc #1
        cmp #3
        bcc @l
        lda #3
@l      jmp batleft
@x      rts

; ------------------------------------------------------------
; autopilot  (debug, the kit's readfire) fire now and then while the
; ball isn't in play (the title, the serve, after a game); none in play
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

; ------------------------------------------------------------
; sound effects on voice 3 (only beside SlopLoad's own player or no
; tune: any other tune has every voice). An effect: attack/decay,
; sustain/release, then a frequency (high byte, + sfxtr) and control a
; tick, 0 ends (the gate off)
; ------------------------------------------------------------
sfx     lda #0
        sta sfxtr
        lda mflags
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

; wallsfx  a tick off the frame, unless another effect is playing
wallsfx lda sfxp
        bne @x
        ldx #e_wall
        jmp sfx
@x      rts

sfxtick ldx sfxp
        beq @x
        lda sfxdat,x
        beq @end
        clc
        adc sfxtr
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
e_bat = *-sfxdat                ; the bat: a hollow knock
        byte $00,$90,$12,$41,$12,$41,$0e,$41,0
e_brick = *-sfxdat              ; a brick: a bright blip (pitched by its row)
        byte $00,$a0,$24,$11,$24,$11,$30,$11,$30,$11,0
e_tough = *-sfxdat              ; a tough brick cracking: a clank
        byte $00,$a0,$70,$81,$40,$41,$40,$41,$38,$41,0
e_wall = *-sfxdat               ; the frame: a tick
        byte $00,$60,$50,$11,0
e_serve = *-sfxdat              ; a serve: two notes up
        byte $00,$a0,$1c,$11,$1c,$11,$1c,$11,$2a,$11,$2a,$11,$2a,$11,0
e_lost = *-sfxdat               ; a ball lost: a slide down
        byte $00,$f0,$30,$21,$2c,$21,$28,$21,$24,$21,$20,$21,$1c,$21,$18,$21
        byte $15,$21,$12,$21,$10,$21,$0e,$21,$0c,$21,0
e_clear = *-sfxdat              ; a wall down: up an arpeggio, twice
        byte $00,$c0,$20,$41,$28,$41,$30,$41,$40,$41,$28,$41,$30,$41,$40,$41
        byte $50,$41,$50,$41,$50,$41,0
e_over = *-sfxdat               ; game over: down, slowly
        byte $00,$f0,$20,$11,$20,$11,$20,$11,$20,$11,$1a,$11,$1a,$11,$1a,$11
        byte $1a,$11,$15,$11,$15,$11,$15,$11,$15,$11,$15,$11,$15,$11,0

; ------------------------------------------------------------
; tables
; ------------------------------------------------------------
rowlo   byte <scra,<scra+40,<scra+80,<scra+120,<scra+160,<scra+200,<scra+240
        byte <scra+280,<scra+320,<scra+360,<scra+400,<scra+440,<scra+480
        byte <scra+520,<scra+560,<scra+600,<scra+640,<scra+680,<scra+720
        byte <scra+760,<scra+800,<scra+840,<scra+880,<scra+920,<scra+960
rowhi   byte >scra,>scra+40,>scra+80,>scra+120,>scra+160,>scra+200,>scra+240
        byte >scra+280,>scra+320,>scra+360,>scra+400,>scra+440,>scra+480
        byte >scra+520,>scra+560,>scra+600,>scra+640,>scra+680,>scra+720
        byte >scra+760,>scra+800,>scra+840,>scra+880,>scra+920,>scra+960

        incasm "modkit.asm"
        incasm "modinit.asm"
        incasm "tables.asm"

        word 65535+*+2-bgmap-40 ; (a guard: the build fails if the code runs into the map)
codetop                         ; (the end of what goes on the tape)

; ---- run-time buffers, in memory the module has but never shows ----
bricks = chr+107*8              ; the wall: 128 bricks (0 none, 1-7 plain, 9-15
                                ; tough, $11-$17 cracked; the colour in bits 0-2),
                                ; in characters 107-122
curlo = bricks+128              ; the soft sprites' cells on show (8; characters
curhi = curlo+8                 ; 123-127 with the next three)
newlo = curhi+8                 ; ... drawn for the next frame
newhi = newlo+8
newcd = newhi+8                 ; ... their characters
cqlo = scra+1000                ; cells for the screen: bricks (8; the screen's
cqhi = cqlo+8                   ; spare bytes, not the sprite pointers)
rowbuf0 = $0200                 ; two rows' colours (40 each; the BASIC input
rowbuf1 = rowbuf0+40            ; buffer: scratch until the program starts)
bslot8 = rowbuf1+40             ; the ball's cells' characters, code x 8 (4)
codeend = codetop
