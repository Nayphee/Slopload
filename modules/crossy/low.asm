; ------------------------------------------------------------
; low.asm  -  Crossy-Load's second part ($caea-$cfff, loaded with
; the game): the status rows, sound, keys, the hidden buffer's row
; copy (setting up: boot.asm, in screen a)
; ------------------------------------------------------------

; ------------------------------------------------------------
; inidone  init's end: screen a's rows 6-24 blank (init ran from there:
;          boot.asm), then the title
; ------------------------------------------------------------
inidone ldx #0
        lda #c_space
@c      sta scra+256,x
        sta scra+512,x
        sta scra+744,x          ; (to 999)
        inx
        bne @c
        jmp titlego

; ------------------------------------------------------------
; stop  silence; the core blanks the screen after
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
@s      lda #0
        sta $d418
        sta $d404
        sta $d40b
        sta $d412
        rts

; ------------------------------------------------------------
; setmsg  a message on row 1, centred, both buffers (x/y: text)
; clrmsg  row 1 blank
; ------------------------------------------------------------
setmsg  stx pt3
        sty pt3+1
        jsr clrmsg
        ldy #0
        lda (pt3),y
        eor #$ff
        sec
        adc #40                 ; 40 - length
        lsr a
        adc #40                 ; row 1, centred
        ldx pt3
        ldy pt3+1
        jmp ptext

; ------------------------------------------------------------
; drawscore  row 0: "SCORE nnn", the title, "BEST nnn"
; ------------------------------------------------------------
drawscore
        ldx #<tx_score
        ldy #>tx_score
        lda #1
        jsr ptext
        ldx #<tx_title
        ldy #>tx_title
        lda #14
        jsr ptext
        ldx #<tx_best
        ldy #>tx_best
        lda #30
        jsr ptext
        lda scl
        ldy sch
        ldx #7
        jsr bcd3
        lda bestl
        ldy besth
        ldx #35
        ; fall through

; three digits of bcd y:a at row 0, column x (no leading zeros)
bcd3    sta tmp
        sty tmp2
        lda #0
        sta tmp3                ; non-zero once a digit was put
        lda tmp2
        and #15
        jsr @dig
        lda tmp
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @dig
        lda #1
        sta tmp3                ; the last digit always
        lda tmp
        and #15
@dig    bne @put                ; (z: from and/lsr before)
        ldy tmp3
        bne @put
        lda #c_space            ; leading zero: blank
        bne @w
@put    ldy #1
        sty tmp3
        clc
        adc #c_digit0
@w      sta scra,x
        sta scrb,x
        inx
        rts

; addpoint  score + 1 in bcd, without decimal mode (the loader's
; interrupt doesn't cld); the camera a little quicker every 8
addpoint
        inc scl
        lda scl
        and #15
        cmp #10
        bcc @d
        lda scl
        adc #5                  ; (carry set: + 6) the next ten
        sta scl
        cmp #$a0
        bcc @d
        lda #0
        sta scl
        inc sch
@d      lda scl
        and #7
        bne @s
        lda cspd
        cmp #120
        bcs @s
        adc #6
        sta cspd
@s      jmp drawscore

; ptext  text x/y at screen offset a (row x 40 + column, rows 0-1),
; both buffers
ptext   stx pt2
        sty pt2+1
        tax
        ldy #0
        lda (pt2),y
        sta tmp
        iny
@t      lda (pt2),y
        sta scra,x
        sta scrb,x
        inx
        iny
        dec tmp
        bne @t
        rts

; (world.asm's, here for the room)
; laneset  the entries on show: entry k (0 at the top, to elast) has its
; top row erow0 + 2k (4-24) and lane ej0 - k (crowd: the buffer on
; show's whole rows)
laneset lda crowd
        clc
        adc #19
        lsr a
        sta ej0
        lda #5
        bcs @t                  ; row 5 is a lane's top half
        lda #4                  ; ... else its top is the blank row 4
@t      sta erow0
        lda #lastrow            ; the last entry: (20 - erow0) / 2
        sec
        sbc erow0
        lsr a
        sta elast
        rts

; vbok  c clear while the beam is between lines 200 and 290 (below the
; picture, room for a lane before the split)
vbok    bit $d011
        bmi @hi
        lda #199                ; up to 255: c set above line 200
        cmp $d012
        rts
@hi     lda $d012               ; 256 on: up to 290 (c set from there)
        cmp #290-256
        rts

waterspd byte 48,56,64,72,80,88,96,104,112,120  ; (world.asm's: the room)

; (world.asm's, here for the room)
; budget  c set once the beam is past line budgetl: a road or river
; lane waits for the next tick (its objects catch up then)
budget  jsr beam
budop   cmp #budgetl            ; (an NTSC frame without a tick: later)
        rts
heninb  byte $80,$c0,$c0,$40     ; top row - her top + 1: which rows have her

; ------------------------------------------------------------
; camera  creep up (faster as the score grows); chase a hen high on
; the screen. A whole row needs the hidden buffer ready: until it
; is, the camera waits. (The row's new lane and its top row are made
; at the flip, in the vertical blank: 40 lines the tick hasn't got.)
; (In the low part, for the room: hen.asm's neighbours are full.)
; ------------------------------------------------------------
camera  lda hsy
        cmp #htarget
        bcs @go
        lda cfrac
        clc
        adc cspd
        sta cfrac
        bcc @x
@go     lda vs
        cmp #7
        bcs @w                  ; at 7: the whole row, when it can be
        inc vs
        dec hsy
        lda vs                  ; 7 now, chasing her still: the whole row
        cmp #7                  ; next frame if the other buffer is ready
        bne @x                  ; (asked a tick later, the field stood
        lda hsy                 ; still a frame each row). Creeping, at
        cmp #htarget            ; the next creep's step as ever: asked at
        bcc @x                  ; once, it crept 8 px in 7 steps, faster
@w      lda bready              ; a whole row: due when the other buffer is
        beq @x                  ; ready (bready 2), made in a frame of its
        inc bready              ; own (crossy.asm's @ct: camstep)
@x      rts

; ------------------------------------------------------------
; bgrow    row a of the hidden buffer (bgwork, bgtail): a new world's
;          from scratch (regenrow); else copyrow
; copyrow  rows a and a+1 of the hidden buffer: rows a-1 and a on show,
;          the same world rows (lanepts' pointers: drawlane keeps both
;          buffers' rows alike from then on), and the cells under the
;          hen from what she keeps under her (bsave); cprow one on (its
;          second row done). A pair takes about 20 lines, where a row
;          drawn from scratch took 25-60: the scroll's whole-row step no
;          longer waits frames for the hidden buffer
;   uses: everything
; ------------------------------------------------------------
bgrow   ldx pmode
        beq copyrow
        jmp regenrow
copyrow tax
        dex
        stx lrow
        jsr lanepts
        ldy #39
@c      lda (pa),y
        sta (pb),y
        lda (pa2),y
        sta (pb2),y
        dey
        bpl @c
        inc cprow
        lda henin               ; her block in these rows on show?
        beq @x
        lda bcol                ; her columns, right to left
        clc
        adc #2
        tay
@h      tya
        clc
        adc hent                ; (the top row's bsave index)
        tax
        bit henin
        bvc @b
        lda bsave,x
        sta (pb),y
@b      bit henin
        bpl @n
        lda bsave+3,x
        sta (pb2),y
@n      cpy bcol
        beq @x
        dey
        bpl @h
@x      rts

        incasm "modkit.asm"
        incasm "tables.asm"
