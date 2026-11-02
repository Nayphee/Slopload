; ------------------------------------------------------------
; world.asm  -  Crossy-Load's lanes: making, moving, drawing
;
; The world is lanes 16 px high (two character rows), numbered up
; from 0; the last 16 made are kept in a ring (index lane & 15).
; Screen row r (4-24) shows world row crow + 24 - r: the lane is
; that over 2, the top half if it is odd. Only rows up to lastrow (20)
; are drawn; those below stay blank (their writes go to trash), and the
; camera starts cutrows rows down (crow -4), so the start lanes are
; where they were, moved up.
;
; A road or river lane holds the objects of a pattern (cell offset
; and length pairs) 4 x offset + lx multicolour px from the left of a
; 256 px loop, of which the screen shows 160. A rail lane holds at
; most one train, moving a cell a tick.
; ------------------------------------------------------------

lt_grass = 0
lt_road = 1
lt_water = 2
lt_rail = 3
nopat = $80                     ; lhead: no train

; ------------------------------------------------------------
; newworld  camera at 0, lanes 0-15 made (a run of grass first),
; the hidden buffer to be drawn from scratch, the hen at the start
; ------------------------------------------------------------
newworld
        lda #256-cutrows        ; (the bottom rows blank: the camera that far down)
        sta crow                ; (vs, crowd: when the new world is shown)
        sta crowx
        lda #0
        sta cfrac
        sta lgen
        sta bready
        sta scl
        sta sch
        lda #lt_grass
        sta runt
        lda #4
        sta runn
        lda #5
        sta cprow
        lda #1
        sta pmode
        jmp henreset            ; (t_build makes the lanes)

; ------------------------------------------------------------
; genlane  make lane lgen in its ring slot
;   uses: a, x, y, tmp
; ------------------------------------------------------------
genlane lda runn
        bne @same
        jsr newrun
@same   dec runn
        lda lgen
        and #15
        tax
        lda runt
        sta ltype,x
        lda #0
        sta lfrac,x
        sta lmov,x
        sta lspd,x
        jsr random
        sta lx,x
        sta ldrawn,x
        and #1
        sta ldir,x
        lda lgen                ; difficulty: + 1 every 16 lanes, to 6
        lsr a
        lsr a
        lsr a
        lsr a
        cmp #7
        bcc @lv
        lda #6
@lv     sta tmp
        jsr random
        and #3
        clc
        adc tmp                 ; 0-9: the speed's index
        tay
        lda runt
        beq @grass
        cmp #lt_water
        beq @water
        bcs @rail
        lda roadspd,y           ; road: a colour, a pattern, cars by direction
        sta lspd,x
        jsr random
        and #ncarcols-1
        tay
        lda carcols,y
        sta lcol,x
        jsr random
        and #3
        adc #0                  ; 0-4 (carry from the compare: a little more often 4)
        sta lpat,x
        lda #p_car
        sta lbase,x
        bne @n
@water  txa                     ; next to another river, the other way:
        and #1                  ; by the lane's parity (its slot's), so
        sta ldir,x              ; their logs pass and come to line up
        lda waterspd,y
        sta lspd,x
        jsr random
        and #3
        clc
        adc #5
        sta lpat,x
        lda #col_water
        sta lcol,x
        lda #p_log
        sta lbase,x
        bne @n
@rail   lda #nopat
        sta lhead,x
        lda #col_rail
        sta lcol,x
        lda #p_train
        sta lbase,x
        jsr random
        and #15
        adc #16                 ; 16-32 cells long
        sta llen,x
        jsr random
        and #63
        adc #warntime+20        ; the first one soon
        sta ltim,x
        bne @n
@grass  lda #col_grass
        sta lcol,x
        lda #p_grass
        sta lbase,x
@n      inc lgen
        rts

; newrun  the next run of lanes: its type (not the last one's) and
; its length; no railway in the first 12 lanes
newrun  jsr random
        and #7
        tay
        lda runtypes,y
        cmp runt
        beq newrun
        cmp #lt_rail
        bne @t
        ldy lgen
        cpy #12
        bcc newrun
@t      sta runt
        tay
        jsr random
        and runmask,y
        clc
        adc #1
        sta runn
        rts

runtypes byte lt_grass,lt_road,lt_road,lt_road,lt_water,lt_water,lt_rail,lt_grass
runmask byte 1,3,1,1            ; run lengths: grass 1-2, road 1-4, water 1-2, rail 1-2

; ---- object patterns: cell offset, length; $ff ends. An object
; needs its length + 2 cells before the next (the cells either side
; of it are redrawn as it moves) ----
patlo   byte <pr0,<pr1,<pr2,<pr3,<pr4,<pw0,<pw1,<pw2,<pw3
pathi   byte >pr0,>pr1,>pr2,>pr3,>pr4,>pw0,>pw1,>pw2,>pw3
pr0     byte 0,3,13,3,26,3,42,3,$ff
pr1     byte 0,3,21,3,42,3,$ff
pr2     byte 0,5,30,5,$ff
pr3     byte 0,3,16,5,40,3,$ff
pr4     byte 0,5,20,3,36,5,$ff
pw0     byte 0,6,20,6,40,6,$ff
pw1     byte 0,4,14,4,30,5,46,4,$ff
pw2     byte 0,8,32,8,$ff
pw3     byte 0,5,16,5,34,5,50,5,$ff

; ------------------------------------------------------------
; lanemove  one tick of every lane: objects 1 px when their speed
; says, trains a cell; lmov set where something moved
;   uses: a, x, y
; ------------------------------------------------------------
lanemove
        ldx #15
@l      lda #0
        sta lmov,x
        lda ltype,x
        beq @n                  ; grass
        cmp #lt_rail
        beq @rail
        lda lfrac,x
        clc
        adc lspd,x
        sta lfrac,x
        bcc @n
        inc lmov,x
        lda ldir,x
        bne @left
        inc lx,x
        jmp @n
@left   dec lx,x
        jmp @n
@rail   jsr railmove
@n      dex
        bpl @l
        jsr lanepick            ; the vertical blank's first lane, ready
                                ; (and the lanes off the screen synced)
        sty vbpick              ; (NTSC's has no time for the look)
        rts

; railmove  lane x: the warning, the train
railmove
        lda lhead,x
        cmp #nopat
        bne @run
        dec ltim,x
        beq @start
        lda ltim,x
        cmp #warntime
        bcs @x
        and #8                  ; warning: red and white
        beq @w
        lda ltim,x
        and #15
        cmp #15
        bne @red
        jsr sfxding             ; as it turns red
@red    lda #col_warn
        bne @c
@w      lda #col_rail
@c      sta lcol,x
@x      rts
@start  lda #col_warn
        sta lcol,x
        lda llen,x              ; ticks to cross: 40 + its length + 2
        clc
        adc #42
        sta ltim,x
        lda #$ff                ; the head comes in at cell 0 or 39
        ldy ldir,x
        beq @h
        lda #40
@h      sta lhead,x
@run    inc lmov,x
        lda ldir,x
        bne @rl
        inc lhead,x
        jmp @rd
@rl     dec lhead,x
@rd     dec ltim,x
        bne railx
        lda #nopat              ; gone: the next one later
        sta lhead,x
        lda #col_rail
        sta lcol,x
        jsr random
        and #127
        adc #warntime+60
        sta ltim,x
railx   rts                     ; (lanedraw's too)

; ------------------------------------------------------------
; lanedraw  redraw the lanes that moved (or changed colour), each
; while the beam is away from it: from the bottom up while it is
; well above them, from the top down once it has passed them, so the
; frame shows each lane whole. Into the buffer on show, and the same
; cells a row lower in the hidden one (rows drawn there already stay
; right; the rest are drawn later anyway).
;   uses: everything
; ------------------------------------------------------------
margin = 44                     ; lines a lane can take to draw

lanedraw
        jsr laneset
        ldx #0                  ; railways first (a train moves a cell a
@rp     stx ehi                 ; tick, so it never waits for the next)
        jsr israil
        beq @rn
        jsr lanework
        bcc @rn
        lda lmov,y              ; a colour alone (a warning's flash: two
        bne @tm                 ; colour rows, 28 lines with the loader
        jsr budget              ; busy) waits a tick when time is short;
        bcs @rn                 ; a train is drawn every tick
@tm     ldx ehi                 ; well above it: now; else once past it,
        jsr lanefirst           ; late or not (drawn with the beam in it,
                                ; a train's halves showed out of line)
        sta tmp4
        jsr beam
        clc
        adc #24
        bcs @rw
        cmp tmp4
        bcc @rd
@rw     ldx ehi
        jsr lanelast
        jsr waitpast
@rd     ldx ehi
        jsr entry
        jsr drawlane
        ldy lj
        lda #0
        sta lmov,y              ; (done)
@rn     ldx ehi
        inx
        cpx elast
        bcc @rp
        beq @rp
        lda elast               ; then roads and rivers, from both ends
        sta elo
        lda #0
        sta ehi
@d      ldx ehi                 ; the top one, if the beam has passed it
        cpx elo
        beq @last
        bcs @x
        jsr budget
        bcs @late
        jsr lanework
        bcc @hi
        jsr lanelast
        sta tmp
        jsr beam
        cmp tmp
        bcc @lo
        beq @lo
@hi     ldx ehi
        inc ehi
        jmp @go
@lo     ldx elo                 ; else the bottom one, if well above it
        jsr lanework
        bcc @l2
        jsr lanefirst
        sta tmp
        jsr beam
        clc
        adc #margin
        bcs @d                  ; (wait)
        cmp tmp
        bcs @d
@l2     ldx elo
        dec elo
@go     jsr budget
        bcs @d
        jsr entry
        jsr drawlane
        jmp @d
@last   jsr lanework            ; the one left: once the beam has passed
        bcc @l3                 ; (a road or river lane rather waits for
        jsr budget              ; the next tick than for a long way)
        bcs @x
        jsr lanelast
        sta tmp4
        cmp #255
        beq @w
        jsr beam
        clc
        adc #16
        bcs @w
        cmp tmp4
        bcc @x                  ; a long way: next tick
@w      lda tmp4
        jsr waitpast
@l3     ldx ehi
        jsr entry
        jsr drawlane
@x      rts
@late   rts                     ; out of time: the rest catch up next tick

; ------------------------------------------------------------
; lanevb  in the vertical blank, before bgwork: the lane on show furthest
; behind (2 px or more), then the next, while the beam is below the
; picture. The tick's lanedraw runs after the split, and a lane the beam
; is near all the time it has (neither passed nor well below) waits for
; the next tick: with the loader busy, the same middle lanes every tick,
; so they froze, their cars and logs still moving for the hen. Here the
; beam is above them all. A lane can take 71 lines with the loader busy:
; started between lines 200 and 290 (vbok, checked again after the look
; at the lanes), it is done by line 50 (the split by 85).
; With the screen scrolling, the colour rows and bgwork take the rest of
; the vertical blank (a scroll waiting for its hidden buffer only pauses).
;   uses: everything
; ------------------------------------------------------------
lanevb  lda bready               ; the hidden buffer first (bgwork's time)
        bne @g                  ; once the camera nears a whole row (it
        lda vs                  ; waits for it there): fine scroll 4 on
        cmp #4
        bcs @x
@g      jsr vbok                ; time? (else not even the look: the
        bcs @x                  ; split may need the lines)
        ldy vbpick              ; the one picked at the tick, first
        bpl @have
        jsr lanepick            ; then a look now (PAL has the time)
        bmi @x
@have   lda #$ff
        sta vbpick
        sty ehi
        jsr laneset             ; its entry: ej0 - lane
        lda ej0
        sec
        sbc ehi
        and #15
        tax
        cpx elast
        beq @on
        bcc @on
        lda lx,y                ; not on show after all (below the last
        sta ldrawn,y            ; row): nothing to draw
        jmp lanevb
@on     jsr vbok                ; still time? (on NTSC a pixel a draw,
        bcs @x                  ; vb1: 63 lines at most, so one started by
                                ; line 262 is done by 62, before the split)
        jsr entry
        jsr drawlane
        jmp lanevb              ; the next, while there is time
@x      rts

; lanepick  y: the road or river lane furthest behind, 2 px or more (n
; set: none). By lane: one off show is never behind
lanepick
        jsr laneset             ; (ej0: the top entry's lane)
        lda #1                  ; (the most so far: 2 at least to count)
        sta tmp4
        ldx #$ff
        stx ehi                 ; (none)
        ldy #15
@l      tya                     ; on the screen? entry ej0 - lane, from 0
        eor #$ff                ; to the last row's
        sec
        adc ej0
        and #15
        cmp #(lastrow-4)/2+1
        bcc @s
        lda lx,y                ; off it: drawn where it is (before one
        sta ldrawn,y            ; comes in at the top)
        bcs @n                  ; (c set)
@s      lda ltype,y
        beq @n                  ; grass
        cmp #lt_rail
        beq @n
        lda lx,y                ; how far behind, either way
        sec
        sbc ldrawn,y
        bpl @p
        eor #$ff
        clc
        adc #1
@p      cmp tmp4
        bcc @n
        beq @n
        sta tmp4
        sty ehi
@n      dey
        bpl @l
        ldy ehi
        rts

; entry  entry x: lrow = its top row, lj (and y) = its lane
;   preserves: x
entry   txa
        asl a
        adc erow0               ; (carry clear)
        sta lrow
        txa
        eor #$ff
        sec
        adc ej0
        and #15
        sta lj
        tay
        rts

; israil  z clear if entry x's lane is a railway
israil  jsr entry
        lda ltype,y
        cmp #lt_rail
        beq @r
        lda #0
        rts
@r      lda #1
        rts

; budget  c set once the beam is past line budgetl: a road or river
; lane waits for the next tick (its objects catch up then)
budgetl = 150                   ; (a lane started before it can take 55 lines)

; lanework  c set if entry x's lane has something to draw
lanework
        jsr entry
        lda ltype,y
        beq @c                  ; grass: only a colour
        cmp #lt_rail
        beq @rl
        lda ldrawn,y            ; road, river: drawn behind where it is
        cmp lx,y
        bne @y
        beq @c
@rl     lda lmov,y
        bne @y
@c      lda lrow                ; its colour: checked on its last row
        clc
        adc #1
        cmp #lastrow+1
        bcc @r
        lda #lastrow
@r      stx tmp3
        tax
        lda rowcol,x
        ldx tmp3
        cmp lcol,y
        bne @y
        clc
        rts
@y      sec
        rts

; lanefirst / lanelast  the first / last line of entry x's lane
lanefirst
        jsr entry
        lda lrow
        cmp #5
        bcs lineof
        lda #5
        bne lineof
lanelast
        jsr entry
        lda lrow
        clc
        adc #1
        cmp #lastrow+1          ; (below row 20: blank)
        bcc @l
        lda #lastrow
@l      jsr lineof
        clc
        adc #7
        rts
; lineof  the first line of row a (5-23): 91 + 8 (a - 5) + fine scroll
lineof  asl a
        asl a
        asl a
        adc #83-32              ; (carry clear)
        adc vcur
        rts

; beam  the raster line, 255 in the vertical blank
beam    lda $d019               ; the beam past line 251 since the split
        lsr a                   ; (the raster latch: the line alone can't
        bcs @b                  ; say, it starts again at the top): 255
        bit $d011
        bmi @b
        lda $d012
        cmp #251
        bcc @x
@b      lda #255
@x      rts

; drawlane  lane lj, whose top row is lrow (3-24: drawn from 4 to 24)
drawlane
        ldx lj
        ldy lrow                ; y = its last row on show
        iny
        cpy #lastrow+1
        bcc @l
        dey
@l      lda ltype,x             ; a road or river behind where it is (it
        beq @c                  ; may not have moved this tick: drawn late,
        cmp #lt_rail            ; it catches up whenever it's drawn), a
        beq @rl                 ; railway that moved, a colour changed
        lda lx,x
        cmp ldrawn,x
        bne @go
        beq @c
@rl     lda lmov,x
        bne @go
@c      lda lcol,x
        cmp rowcol,y
        bne @go
        rts                     ; nothing changed
@go     sty tmp2
        ldx lj
        lda lcol,x              ; its colour, if that changed (railways)
        ldy tmp2
        cmp rowcol,y
        beq @pts
        tax
        jsr setrowcol
        ldy lrow
        cpy #5
        bcc @pts
        cpy tmp2
        beq @pts
        ldx lj
        lda lcol,x
        tax
        jsr setrowcol
@pts    jsr lanepts
        ldx lj
        lda ltype,x
        beq @x2
        cmp #lt_rail
        bne @rd
        jmp @tr
@rd     lda lpat,x              ; road or river: the objects' ends, a px
        tay                     ; at a time from where they were drawn
        lda patlo,y
        sta pt
        lda pathi,y
        sta pt+1
        lda ldir,x
        sta lt
@step   ldx lj
        lda lx,x                ; how far behind (in its direction)
        sec
        sbc ldrawn,x
        beq @x2
        ldy lt
        beq @r
        eor #$ff                ; left: drawn - lx
        clc
        adc #1
@r      sta tmp4                ; 1: one px, the ends' cells as they change
        cmp #2
        bcc @one
        ldy vb1                 ; (NTSC's blank: one px at a time)
        bne @one
        cmp #4                  ; more: up to 3 px at once, and the six
        bcc @n                  ; cells at the ends as they are (a whole
        lda #3                  ; cell's step would leave its old tail)
@n      ldy lt
        beq @add
        eor #$ff
        clc
        adc #1
@add    clc
        adc ldrawn,x
        sta ldrawn,x
        lda #0
        sta tmp4
        jmp @sd
@x2     rts
@one    ldy lt
        bne @dl
        inc ldrawn,x            ; right
        jmp @sd
@dl     dec ldrawn,x            ; left
@sd     ldy #0
@o      lda (pt),y              ; cell offset
        bmi @x2                 ; (one step a call, 3 px at most: a lane far
                                ; behind catches up over a few ticks, and a
                                ; call's time stays bounded)
        asl a
        asl a
        adc ldrawn,x            ; (carry clear: offsets < 64)
        sta ox
        iny
        lda (pt),y
        sta on
        iny
        sty oi
        lda ox                  ; off the screen (its cells 41 to 63)?
        cmp #41*4
        bcc @on
        lsr a
        lsr a
        adc on                  ; (carry clear) its last cell + 1
        cmp #63
        bcc @o                  ; (y is still the next pair)
@on     lda tmp4
        beq @six
        jsr objmove
        jmp @nx
@six    jsr objends
@nx     ldx lj
        ldy oi
        jmp @o
@x      rts
@tr     lda lmov,x
        beq @x
@train  lda lhead,x             ; a train: its head and its tail
        cmp #nopat
        beq @x
        tay
        lda ldir,x
        bne @tl
        lda #6                  ; right: head (R0) and the body behind it
        jsr putt
        dey
        lda #5
        jsr putt
        lda lhead,x
        sec
        sbc llen,x
        tay                     ; behind the tail: rails again
        lda #0
        jsr putt
        iny
        lda #1                  ; the tail (L0)
        jmp putt
@tl     lda #1                  ; left: head (L0) and the body behind
        jsr putt
        iny
        lda #5
        jsr putt
        lda lhead,x
        clc
        adc llen,x
        tay
        lda #0
        jsr putt
        dey
        lda #6
        jmp putt

; setrowcol  colour ram row y (on show) to colour x; preserves y
setrowcol
        txa
        sta rowcol,y
        sty tmp
        tax
        lda rowlo,y
        sta pt3
        lda rowhi,y
        ora #$d8
        sta pt3+1
        txa
        ldy #39
@f      sta (pt3),y
        dey
        bpl @f
        ldy tmp
        rts

; waitpast  until the beam is past line a (255: in the blank)
waitpast
        clc                     ; (255, the blank: until it comes)
        adc #1
        bcc @k
        lda #255
@k      sta tmp
@w      jsr beam
        cmp tmp
        bcc @w
        rts

; lanepts  pa/pa2: the lane's rows (lrow, lrow+1) on show; pb/pb2:
; the same a row lower in the hidden buffer. lcode: its characters.
lanepts ldx lj
        lda lbase,x
        sta lcode
        lda #0                  ; her block in the lane's rows?
        sta henin
        lda hseen
        beq @nh
        lda bbuf
        cmp front
        bne @nh
        lda lrow
        sec
        sbc brow                ; top row - her top: -1 to 2 touch it
        clc
        adc #1
        cmp #4
        bcs @nh
        tax
        lda heninb,x
        sta henin
        txa                     ; hent = (lrow - brow) x 3 - bcol
        sec
        sbc #1
        sta tmp
        asl a
        clc                     ; (asl of -1 sets the carry)
        adc tmp
        sec
        sbc bcol
        sta hent
@nh     ldy lrow                ; rows 5-22: four pointers from one
        cpy #5
        bcc @slow
        cpy #lastrow-1          ; (the hidden one's row + 2 up to 20)
        bcs @slow
        ldx front
        lda rowlo,y
        sta pa
        adc #40                 ; (carry clear)
        sta pa2
        sta pb
        lda rowhi,y
        ora scrhi,x
        sta pa+1
        adc #0
        sta pa2+1
        eor #$0c                ; the other buffer
        sta pb+1
        lda pb
        adc #40                 ; (carry clear)
        sta pb2
        lda pb+1
        adc #0
        sta pb2+1
        rts
@slow   ldx front
        ldy lrow
        lda #pa
        jsr rowpt
        iny
        lda #pa2
        jsr rowpt
        txa
        eor #1
        tax
        lda #pb
        jsr rowpt
        iny
        lda #pb2
        ; fall through


; rowpt  zero page pointer at a = row y of buffer x. A row outside
; 5-24 gets 40 bytes of its own instead (writes there go nowhere).
;   preserves: x, y
rowpt   sty tmp
        stx tmp3
        tax
        cpy #5
        bcc @t
        cpy #lastrow+1
        bcs @t
        lda rowlo,y
        sta 0,x
        ldy tmp3
        lda scrhi,y
        ldy tmp
        ora rowhi,y
@h      sta 1,x
        ldx tmp3
        rts
@t      lda #<trash
        sta 0,x
        lda #>trash
        ldy tmp
        jmp @h

; ------------------------------------------------------------
; objends  an object moved up to 3 px: the three cells at each end
; drawn as they are now (c0-1 .. c0+1, c0+n-2 .. c0+n+1: a step right
; into the next cell leaves its old RX one cell in from the end)
; ------------------------------------------------------------
objends lda ox
        lsr a
        lsr a
        tay
        dey                     ; c0 - 1: ground
        lda #0
        jsr putc
        iny                     ; c0: L[p]
        lda ox
        and #3
        sta tmp4
        clc
        adc #1
        jsr putc
        iny                     ; c0 + 1: LX at p = 3, else inside
        lda tmp4
        cmp #3
        bne @in
        lda #10
        bne @i2
@in     lda #5
@i2     jsr putc
        tya
        clc
        adc on
        tay
        dey
        dey                     ; c0 + n - 1: R0 at p = 0, RX at 1, else inside
        lda on                  ; (4 cells or more: c0 + n - 2 is inside,
        cmp #4                  ; and held RX if a step right crossed a
        bcc @rx                 ; cell)
        dey
        lda #5
        jsr putc
        iny
@rx     lda tmp4
        bne @p
        lda #6
        jsr putc
        iny                     ; c0 + n: ground
        lda #0
        jsr putc
        jmp @g
@p      cmp #1
        bne @p2
        lda #11
        bne @p3
@p2     lda #5
@p3     jsr putc
        iny                     ; c0 + n: R[p]
        lda tmp4
        clc
        adc #6
        jsr putc
@g      iny                     ; c0 + n + 1: ground
        lda #0
        jsr putc
        lda #0                  ; (tmp4: back to "more than one")
        sta tmp4
        rts

; ------------------------------------------------------------
; objmove  an object moved 1 px (lt: 0 right, 1 left): its new
; cells at the ends, three at most. In: ox, on.
;   cells: L[p] = 1+p, INT = 5, R0 = 6 (p = 0, the last cell),
;   R[p] = 6+p (p > 0, a cell after the last), BG = 0, LX = 10
;   (c0 + 1 at p = 3), RX = 11 (the last cell at p = 1)
; ------------------------------------------------------------
objmove lda ox
        lsr a
        lsr a
        sta cell                ; c0
        lda ox
        and #3
        sta tmp4                ; p
        ldx lt
        bne @left
        tax                     ; moved right
        beq @r0
        ldy cell                ; same first cell: L[p]
        clc
        adc #1
        jsr putc
        cpx #3
        bne @rn3
        iny                     ; p = 3: INT -> LX after it
        lda #10
        jsr putc
@rn3    lda cell
        clc
        adc on
        tay                     ; c0 + n
        cpx #1
        bne @r2
        dey                     ; p = 1: R0 -> RX, and R1 after it
        lda #11
        jsr putc
        iny
        lda #7
        jmp putc
@r2     cpx #2
        bne @r3
        dey                     ; p = 2: RX -> INT, and R2 after it
        lda #5
        jsr putc
        iny
@r3     txa
        clc
        adc #6
        jmp putc
@r0     ldy cell                ; into a new cell: BG, L0 (from LX) ... R0
        dey
        lda #0
        jsr putc
        iny
        lda #1
        jsr putc
        lda cell
        clc
        adc on
        tay
        dey
        lda #6
        jmp putc
@left   cmp #3
        beq @l3
        tax                     ; same first cell: L[p]
        ldy cell
        clc
        adc #1
        jsr putc
        cpx #2
        bne @ln2
        iny                     ; p = 2: LX -> INT after it
        lda #5
        jsr putc
@ln2    lda cell
        clc
        adc on
        tay                     ; c0 + n
        txa
        bne @l1
        lda #0                  ; p = 0: R1 -> BG, RX -> R0 before it
        jsr putc
        dey
        lda #6
        jmp putc
@l1     cpx #1
        bne @l2
        dey                     ; p = 1: INT -> RX before it, R1
        lda #11
        jsr putc
        iny
        lda #1
@l2     clc                     ; R[p]
        adc #6
        jmp putc
@l3     ldy cell                ; into a new cell: L3, LX (from L0) ... R3
        lda #4
        jsr putc
        iny
        lda #10
        jsr putc
        lda cell
        clc
        adc on
        tay
        lda #9                  ; (into putc)

; ------------------------------------------------------------
; putc  a lane cell, column y (taken mod 64, drawn if under 40);
; putt  the same for a signed column (a train's)
;   in:   a = code in the lane's block (0-9; +10 in its bottom row)
;   out:  in pb2/pa2 (bottom row) and pb/pa (top row). On show, a cell
;         of the hen's block keeps her, and the code goes in bsave
;         (henin bit 7/6: her block is in the bottom/top row; hent: the
;         bsave index of column 0 of the top row)
;   preserves: x, y
; ------------------------------------------------------------
putc    pha
        tya
        and #63
        jmp putx
putt    pha
        tya
putx    cmp #40
        bcs @skip
        sty tmp
        tay
        pla
        cmp #10
        bcs @xc                 ; LX, RX: the inside's top half
        adc lcode               ; (carry clear)
        sta tmp2
@bt     adc #10                 ; the bottom row's character
        sta (pb2),y
        bit henin
        bmi @hb
        sta (pa2),y
@top    lda tmp2
        sta (pb),y
        bit henin
        bvs @ht
        sta (pa),y
@x      ldy tmp
        rts
@skip   pla
        rts
@xc     pha                     ; (carry set: + 5 is + 4)
        lda lcode
        adc #4
        sta tmp2
        pla
        clc
        adc lcode               ; 20 or 21 below
        jmp @bt
@hb     pha                     ; the bottom row has her block
        lda (pa2),y
        jsr henchr
        pla
        bcs @hb1
        sta (pa2),y
        jmp @top
@hb1    stx tmp3
        pha
        tya
        clc
        adc hent
        clc                     ; (hent is often negative: a carry)
        adc #3
        tax
        pla
        cpx #9                  ; (never outside her 9: zero page wraps)
        bcs @hb2
        sta bsave,x
@hb2    ldx tmp3
        jmp @top
@ht     pha                     ; the top row has her block
        lda (pa),y
        jsr henchr
        pla
        bcs @ht1
        sta (pa),y
        jmp @x
@ht1    stx tmp3
        pha
        tya
        clc
        adc hent
        tax
        pla
        cpx #9
        bcs @ht2
        sta bsave,x
@ht2    ldx tmp3
        jmp @x

; rput / rputt  as putc / putt, into pa alone (a row from scratch)
rput    pha
        tya
        and #63
        jmp rputx
rputt   pha
        tya
rputx   cmp #40
        bcs @skip
        sty tmp
        tay
        pla
        cmp #10
        bcs @xc                 ; LX, RX
@w      adc lcode               ; (carry clear)
        sta (pa),y
        ldy tmp
        rts
@skip   pla
        rts
@xc     bit lbot                ; a bottom row: lcode (+10) + 10 or 11
        bpl @xb
        lda #5                  ; a top row: the inside's
@xb     clc
        bcc @w
lbot    byte 0                  ; regen1: bit 7 set while it draws a lane's top row

; putv / puttv  objwhole's and the train's writer: putc/putt, or
; rput/rputt while a row is drawn from scratch
putv    jmp putc
puttv   jmp putt

; henchr  c set if a is one of the hen's characters
henchr  cmp #hen0
        bcc @n
        cmp #hen1+9
        bcs @no
        sec
        rts
@no     clc
@n      rts

; ------------------------------------------------------------
; regenrow  row a of the hidden buffer from scratch: world row
; crowx + 24 - a (crowx: crow as it will be when that buffer shows)
;   uses: everything
; ------------------------------------------------------------
regenrow
        pha
        ldx #4
        jsr @v
        pla
        jsr regen1
        ldx #9
@v      ldy #4                  ; putv/puttv's addresses from pvtab
@c      lda pvtab,x
        sta putv+1,y
        dex
        dey
        bpl @c
        rts
regen1  sta lrow
        tay
        lda front
        eor #1
        tax
        lda #pa
        jsr rowpt
        lda crowx
        clc
        adc #24
        sec
        sbc lrow
        sta lw
        lsr a
        php
        and #15
        sta lj
        tax
        lda #0
        plp
        ror lbot                ; bit 7 set: the top half (odd)
        bmi @top
        lda #10
@top    clc
        adc lbase,x
        sta lcode
        ldy #39                 ; the lane's ground
@f      sta (pa),y
        dey
        bpl @f
        lda ltype,x
        beq @grass
        cmp #lt_rail
        beq @rail
        lda lpat,x              ; road or river: the objects, whole
        tay
        lda patlo,y
        sta pt
        lda pathi,y
        sta pt+1
        ldy #0
@o      lda (pt),y
        bmi @x
        asl a
        asl a
        adc ldrawn,x
        sta ox
        iny
        lda (pt),y
        sta on
        iny
        sty oi
        jsr objwhole
        ldx lj
        ldy oi
        jmp @o
@x      rts
@grass  lda lw                  ; trees at the edges (3 lanes in 4)
        lsr a
        sta tmp4                ; the lane's number
        and #3
        beq @nt
        ldy #0
        lda #g_treel
        jsr putv
        iny
        lda #g_treer
        jsr putv
        ldy #38
        lda #g_treel
        jsr putv
        iny
        lda #g_treer
        jsr putv
@nt     lda tmp4                ; tufts
        asl a
        asl a
        asl a
        sbc tmp4                ; x 7 (near enough)
        and #15
        adc #4
        tay
@tf     lda #g_tuft
        jsr putv
        tya
        clc
        adc #13
        tay
        cmp #38
        bcc @tf
        rts
@rail   jsr trainspan           ; a train: cells lo-hi (signed), clipped
        bcc @bx
        lda tmp
        sta tmp4                ; (putt uses tmp)
        ldy tmp4                ; the ends
        lda #1
        jsr puttv
        ldy tmp2
        lda #6
        jsr puttv
        ldy tmp4                ; the body between, on screen
@b      iny
        cpy tmp2
        beq @bx
        tya
        bmi @b                  ; off the left
        cmp #40
        bcs @bx                 ; off the right
        lda #5
        jsr puttv
        jmp @b
@bx     rts

; trainspan  lane x's train: c clear if none; else tmp = its first
; cell, tmp2 its last (signed)
trainspan
        lda lhead,x
        cmp #nopat
        clc
        beq @x
        ldy ldir,x
        bne @l
        sta tmp2                ; right: from head - len + 1 to head
        sec
        sbc llen,x
        clc
        adc #1
        sta tmp
        sec
        rts
@l      sta tmp                 ; left: from head to head + len - 1
        clc
        adc llen,x
        sec
        sbc #1
        sta tmp2
        sec
@x      rts

; objwhole  an object at ox, on cells long, all of it
objwhole
        lda ox
        lsr a
        lsr a
        tay                     ; c0
        lda ox
        and #3
        sta tmp4                ; p
        clc
        adc #1
        jsr putv                ; L[p]
        iny                     ; c0 + 1: LX at p = 3, else inside
        lda tmp4
        cmp #3
        bne @in
        lda #10
        bne @i2
@in     lda #5
@i2     jsr putv
        ldx on                  ; the rest of the inside (n is 3 or more)
        dex
        dex
        dex
        beq @e
@m      iny
        lda #5
        jsr putv
        dex
        bne @m
@e      iny                     ; c0 + n - 1
        lda tmp4
        bne @p
        lda #6                  ; p = 0: R0 here, ground after
        jmp putv
@p      cmp #1
        bne @p2
        lda #11                 ; p = 1: RX
        bne @p3
@p2     lda #5
@p3     jsr putv
        iny
        lda tmp4
        clc
        adc #6                  ; R[p] after
        jmp putv

; ------------------------------------------------------------
; bgwork  in the vertical blank, while there is time: the hidden
; buffer's rows cprow-24 for camera row crowx (bgrow). pmode 0: the
; next whole-row scroll's (rows 6-24, copied a pair at a time; row 5
; is drawn when it happens), then bready; 1: a new world's (4-24,
; drawn, t_build shows it)
; ------------------------------------------------------------
bgwork  lda bready
        bne @x
        lda pmode               ; a new world: once its lanes are made (in
        beq @r                  ; play they are; lgen wraps at 256)
        lda lgen
        cmp #16
        bcc @x
@r      lda cprow
        cmp #lastrow+1
        bcs @done
        lda #12                 ; (a row can take 60 lines with the loader busy;
                                ; the split starts by line 85)
        jsr beamto
        bcs @x
        lda cprow
        jsr bgrow
        inc cprow
        bne @r
@done   lda pmode
        bne @x
        lda #1
        sta bready
@x      rts

; bgtail  the same at the end of a frame's work, while the beam is
; above line 222 (a row can take 25 lines)
bgtail  lda bready
        bne @x
        lda pmode
        beq @r
        lda lgen
        cmp #16
        bcc @x
@r      lda cprow
        cmp #lastrow+1
        bcs @d
        jsr beam
        cmp #222
        bcs @x
        lda cprow
        jsr bgrow
        inc cprow
        bne @r
@d      lda pmode
        bne @x
        lda #1
        sta bready
@x      rts

; ------------------------------------------------------------
; colrows  colour ram rows colr-24 that differ from their lanes'
;   in:   c set: stop when the beam nears the top (vertical blank);
;         before the flip (colreq 0), at the first row the beam hasn't
;         passed yet, or at line 240
; colall  every row (the screen is off)
; ------------------------------------------------------------
colrows ror tmp4
@r      ldy colr
        cpy #lastrow+1
        bcs @done
        bit tmp4
        bpl @go
        lda colreq
        bne @vb
        tya                     ; (c clear: cpy) the row's last line + 1,
        asl a                   ; any fine scroll
        asl a
        asl a
        adc #66
        sta oi
        jsr beam
        cmp #240
        bcs @x
        cmp oi
        bcs @go
        rts
@vb     jsr beamok
        bcs @x
@go     lda crow
        clc
        adc #24
        sec
        sbc colr
        lsr a
        and #15
        tax
        lda lcol,x
        cmp rowcol,y
        beq @n
        tax
        jsr setrowcol
@n      inc colr
        bne @r
@done   lda #0
        sta colreq
@x      rts

colall  ldy #24
        lda #$ff
@c      sta rowcol,y
        dey
        bpl @c
        ldy #4                  ; status rows 0-2: hi-res white; 3-4 black
@s      ldx #0
        cpy #3
        bcs @k
        inx
@k      jsr setrowcol           ; (keeps x, y)
        dey
        bpl @s
        lda #5
        sta colr
        clc
        jmp colrows
