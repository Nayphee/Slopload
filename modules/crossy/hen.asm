; ------------------------------------------------------------
; hen.asm  -  the hen: hopping, riding logs, dying; the camera;
; her soft sprite
;
; hsy is her lane's bottom above the screen's bottom (px); on
; screen her image's top is at line 236 - hsy + hoff - lift.
; ------------------------------------------------------------

; henreset  on lane 1, in the middle, standing
henreset
        lda #1
        sta hl
        sta hmax
        lda #16+8*cutrows       ; (lane 0 below her, at the play field's bottom)
        sta hsy
        lda #76
        sta hx
        lda #0
        sta hop
        sta hopq
        sta hoff
        sta hfrm
        lda #40                 ; the camera's crawl: a px every 6 ticks
        sta cspd
        jmp drawscore

; hopgo  hop a lane forward (fire, or the screen's bottom)
hopgo   inc hl
        lda hsy
        clc
        adc #16
        sta hsy
        lda #16
        sta hoff
        lda #hoptime
        sta hop
        lda #0
        sta hopq
        jsr sfxhop
        lda hl                  ; further than ever: a point
        sec
        sbc hmax
        beq @x
        bmi @x
        lda hl
        sta hmax
        jsr addpoint
@x      jmp lanegen

; ------------------------------------------------------------
; henmove  a tick of play: the hop, riding, collisions, fire
; ------------------------------------------------------------
henmove lda $dc00               ; joystick 2 left/right (bits 2, 3: 0
        ldx hx                  ; pushed): she walks a px a tick, on or
        lsr a                   ; off the ground, kept on the screen
        lsr a                   ; (playlo-walkhi); collisions and her log
        lsr a                   ; are checked where she is now
        bcs @wr
        cpx #playlo+1
        bcc @wr
        dex
@wr     lsr a
        bcs @ws
        cpx #walkhi
        bcs @ws
        inx
@ws     stx hx
        lda hop
        beq @ground
        dec hop                 ; in the air
        dec hoff
        dec hoff
        lda fpress
        beq @nq
        sta hopq                ; pressed again: hop on landing
@nq     lda hop
        beq @land
        cmp #hoptime/2
        bcs @x                  ; over the lane she left
        jmp crash               ; in her new lane's traffic
@land
@ground jsr ride
        lda st
        cmp #st_play
        bne @x
        jsr crash
        lda st
        cmp #st_play
        bne @x
        lda fpress
        ora hopq
        beq @push
        lda hsy                 ; too near the top: once the screen has
        cmp #hsymax             ; caught up (held till then)
        bcc @go
        lda #$10
        sta hopq
        rts
@push   lda hsy                 ; the play field's bottom has caught her
        cmp #8+8*cutrows        ; (the hidden rows above the screen's)
        bcs @x
@go     jmp hopgo
@x      rts

; ride  on a river: carried by her log, or drowned; swept away
; past the edge
ride    lda hl
        and #15
        tax
        lda ltype,x
        cmp #lt_water
        bne @x
        lda lmov,x
        beq @chk
        lda ldir,x
        bne @l
        inc hx
        bne @e
@l      dec hx
@e      lda hx
        cmp #playlo
        bcc @swept
        cmp #playhi+1
        bcs @swept
@chk    lda hx
        clc
        adc #4
        sta tmp4                ; her middle
        jsr overlap
        bcs @x
        lda #1                  ; in the water
        jmp die
@swept  lda #2
        jmp die
@x      rts

; overlap  lane x: c set if an object, as drawn, covers px tmp4 + (0 to
; tmp3) (tmp3 = 0: that px alone)
overlap lda #0
        sta tmp3
overlapw
        lda lpat,x
        tay
        lda patlo,y
        sta pt
        lda pathi,y
        sta pt+1
        ldy #0
@o      lda (pt),y
        bmi @no
        asl a
        asl a
        adc ldrawn,x            ; (where it's drawn: she meets what's on
        sta tmp                 ; show, not one drawn a tick late) x0
        iny
        lda (pt),y              ; 4 x length + width - 1
        asl a
        asl a
        adc tmp3
        sta tmp2
        iny
        lda tmp4
        clc
        adc tmp3
        sec
        sbc tmp                 ; (right edge - x0) mod 256
        cmp tmp2
        bcc @yes
        jmp @o
@no     clc
        rts
@yes    sec
        rts

; crash  cars or a train where she is
crash   lda hl
        and #15
        tax
        lda ltype,x
        cmp #lt_road
        beq @road
        cmp #lt_rail
        bne @x
        jsr trainspan           ; a train: cells lo-hi against hers
        bcc @x
@tc     lda hx                  ; her cells: (hx+1)/4 to (hx+7)/4
        clc
        adc #7
        lsr a
        lsr a
        sec
        sbc tmp                 ; lo <= her last?
        bmi @x
        lda hx
        clc
        adc #1
        lsr a
        lsr a
        sta tmp3
        lda tmp2
        sec
        sbc tmp3                ; hi >= her first?
        bmi @x
        lda #3
        jmp die
@road   lda hx                  ; cars: px hx+1 to hx+7
        clc
        adc #1
        sta tmp4
        lda #6
        sta tmp3
        jsr overlapw
        bcc @x
        lda #0
        jmp die
@x      rts

; die  a = how (0 car, 1 river, 2 swept away, 3 train)
die     ldx dbg_auto            ; (debug: 2 plays without dying; swept
        cpx #2                  ; away, back to the middle)
        bne @d
        ldx #76
        cmp #2
        bne @g
        stx hx
@g      rts
@d      sta death
        lda #st_dead
        sta st
        lda #0
        sta tmr
        sta hop
        sta hoff
        sta hopq
        lda #1
        sta hfrm
        lda #3
        sta flash
        jsr sfxdie
        ldx death
        lda deathlo,x
        ldy deathhi,x
        tax
        jsr setmsg
        lda sch                 ; best score
        cmp besth
        bcc @x
        bne @new
        lda scl
        cmp bestl
        bcc @x
@new    lda scl
        sta bestl
        lda sch
        sta besth
        jmp drawscore
@x      rts

; ------------------------------------------------------------
; camstep  the camera's whole-row step: the other buffer from the next
;          vblank (flipset), with its new lane and its top row (flipwk)
; flipwk   the other buffer's new lane and top row (crowx: its crow)
;   uses: everything
; ------------------------------------------------------------
camstep inc crow
        lda crow
        sta crowx
        dec hsy
        jsr flipset
flipwk  jsr lanegen
        lda #5
        jmp regenrow

; ------------------------------------------------------------
; flipset  the other buffer shown from the next vblank, at fine scroll
;          0, its colour rows from row 5 (from the beam's wake on:
;          frame's wait)
;   uses: a
; ------------------------------------------------------------
flipset lda #0
        sta vs
        lda #5
        sta colr
        sta flipreq
        lda front
        eor #1
        sta nfront
        rts

; clrmsg  the message row (row 1) blank, in both screens (low.asm's, here
; for the room)
clrmsg  ldx #39
        lda #c_space
@c      sta scra+40,x
        sta scrb+40,x
        dex
        bpl @c
        rts

; lanegen  lanes made up to two above the top row
lanegen lda crow
        clc
        adc #24
        lsr a
        sec
        sbc lgen
        and #127
        cmp #64
        bcs @x
        jsr genlane
        jmp lanegen
@x      rts

; ------------------------------------------------------------
; henpos  stage the hen's block for the next vblank: where it goes
; in the buffer that will be on show, what is under it, and her
; characters drawn in the set not on show
;   in:   hx, hsy, hoff, hop, hfrm, vs, nfront
; ------------------------------------------------------------
henpos  lda st
        cmp #st_build
        bne @go
        rts
@go     lda hx
        lsr a
        lsr a
        sta ncol
        lda hx
        and #3
        ldx hfrm
        beq @sh
        lda #0                  ; flat: one image
@sh     sta bshift
        ldx hop
        lda #236-91             ; (hsy at most 137: no step borrows
        sec                     ; but the last)
        sbc hsy
        clc
        adc hoff
        sec
        sbc lift,x
        sec
        sbc vs                  ; lines below row 5's top
        bcs @v                  ; (above it: there, for safety)
        lda #0
@v      cmp #(lastrow-6)*8      ; (lower: there; her block's 3 rows
        bcc @v2                 ; end by the play field's last)
        lda #(lastrow-6)*8-1
@v2     tax
        and #7
        sta bys
        txa
        lsr a
        lsr a
        lsr a
        clc
        adc #5
        sta nrow
        tax                     ; pt = top left in buffer nfront
        ldy nfront
        lda rowlo,x
        clc
        adc ncol
        sta pt
        lda rowhi,x
        adc #0
        ora scrhi,y
        sta pt+1
        ldx #0
@g      ldy cellofs,x
        lda (pt),y
        cmp #hen0               ; a hen character: her old block in
        bcc @k                  ; this buffer; what is under it is in
        cmp #hen1+9             ; bsave
        bcs @k
        lda nrow
        clc
        adc celly3,x
        sec
        sbc brow
        sta tmp
        asl a
        adc tmp                 ; x3
        adc ncol
        adc cellx,x
        sec
        sbc bcol
        tay
        lda bsave,y
@k      sta nsave,x
        inx
        cpx #9
        bne @g
        lda hseen               ; the same as on show: nothing to do
        beq @r
        lda bbuf
        cmp nfront
        bne @r
        ldx #11
@s      lda ncol,x              ; (ncol nrow nset nsave, bcol brow bset
        cmp bcol,x              ; bsave: in the same order)
        bne @r
        dex
        bpl @s
        lda bshift
        cmp hshown
        bne @r
        lda bys
        cmp hshown+1
        bne @r
        lda hfrm
        cmp hshown+2
        beq @x
@r      lda bset
        eor #1
        sta nset
        lda bshift
        sta hshown
        lda bys
        sta hshown+1
        lda hfrm
        sta hshown+2
        jsr render
        lda #1
        sta nvalid
@x      rts

lift    byte 0,1,3,4,5,5,4,3,1  ; by hop ticks left

; ------------------------------------------------------------
; show  (vertical blank) the staged block: the old one out (if it
; is in the buffer now on show), the new one in
; ------------------------------------------------------------
show    lda nvalid
        beq @x
        lda hseen
        beq @new
        lda bbuf
        cmp front
        bne @new
        jsr unplace
@new    lda ncol
        sta bcol
        lda nrow
        sta brow
        lda nset
        sta bset
        lda front
        sta bbuf
        lda #1
        sta hseen
        ldx #8
@c      lda nsave,x
        sta bsave,x
        dex
        bpl @c
        lda #0
        sta nvalid
        jmp place
@x      rts

; place  her characters into the buffer on show
; unplace  what was under her back, where she still is
place   jsr blockptr
        lda #hen0
        ldx bset
        beq @s
        lda #hen1
@s      sta tmp
        ldx #0
@p      ldy cellofs,x
        lda cellchr,x           ; numbered down the columns
        clc
        adc tmp
        sta (pt),y
        inx
        cpx #9
        bne @p
        rts

unplace jsr blockptr
        ldx #0
@u      ldy cellofs,x
        lda (pt),y
        cmp #hen0
        bcc @n                  ; drawn over since (a car): leave it
        cmp #hen1+9
        bcs @n
        lda bsave,x
        sta (pt),y
@n      inx
        cpx #9
        bne @u
        rts

; pt = the block's top left in buffer bbuf
blockptr
        ldx brow
        ldy bbuf
        lda rowlo,x
        clc
        adc bcol
        sta pt
        lda rowhi,x
        adc #0
        ora scrhi,y
        sta pt+1
        rts

; ------------------------------------------------------------
; render  the hen into the 9 characters of set nset: the glyphs under
; the block copied in (numbered down the columns, so each column's
; three are 24 bytes in a row), then the image's 14 rows laid over
; each column from its row bys
; ------------------------------------------------------------
render  ldx nset
        lda setlo,x
        sta pt2
        lda #>chrset
        sta pt2+1
        ldx #8                  ; x = cell, down the columns
@cell   ldy cellchr,x           ; (the transpose: its nsave index)
        lda nsave,y
        ldy x8p7,x              ; y = the cell's last byte in the set
        sta tmp                 ; pt = glyph - 8 x cell, so that
        lsr a                   ; (pt),y reads it with the same y
        lsr a
        lsr a
        lsr a
        lsr a
        ora #>chrset
        sta pt+1
        lda tmp
        asl a
        asl a
        asl a
        sec
        sbc x8,x
        sta pt
        bcs @c8
        dec pt+1
@c8     lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dex
        bpl @cell
        lda hfrm                ; pt3 = the image's first column, less
        asl a                   ; bys: y = bys + row reads both
        asl a
        adc bshift              ; (carry clear: hfrm x 4 < 12)
        tax
        lda imglo,x
        sec
        sbc bys
        sta pt3
        lda imghi,x
        sbc #0
        sta pt3+1
        lda bys
        clc
        adc #hen_h
        sta tmp                 ; y's end
        lda #3
        sta cell                ; columns to go
@col    ldy bys
@row    lda (pt3),y
        beq @nx                 ; nothing drawn in this byte
        sta tmp2
        tax
        lda (pt2),y
        and invmask,x
        ora tmp2
        sta (pt2),y
@nx     iny
        cpy tmp
        bne @row
        dec cell
        beq @x
        lda pt2                 ; next column: glyphs +24, image +14
        clc
        adc #24
        sta pt2
        lda pt3
        clc
        adc #hen_h
        sta pt3
        bcc @col
        inc pt3+1
        bne @col
@x      rts

; ------------------------------------------------------------
; autopilot  (debug) hop every 16 ticks; once the program is in,
; stop, so the screen pushes her into something and the round ends
;   out:  a = 0 to press fire, $10 not
; ------------------------------------------------------------
autopilot
        bit ld_state
        bmi @no
        lda frm
        and #15
        beq @x                  ; 0: pressed
@no     lda #$10
@x      rts
