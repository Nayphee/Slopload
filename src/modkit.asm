; ------------------------------------------------------------
; modkit.asm  -  what every SlopLoad module does the same way
; (the standard: DESIGN.md section 8). A game includes it after its
; own equates, and gets:
;   gk_musinit  copy the header's music fields (call first in init)
;   musicgo     start the song the tool chose; mstop, minit, mplay
;   sidinit     the SID cleared, voice 3 ready for effects
;   soundkey    S turns the music off and on
;   readfire    fire on joystick port 2 (fpress: a fresh press)
;   startkey    once loaded, a fresh SPACE sets exitreq
;   status      the status line: LOADING and a bar with the percent,
;               TAPE ERROR (flashing), LOADED! PRESS SPACE...
;   random      16-bit lfsr
; It needs from the game:
;   zero page   frm fire fpress spc skey exitreq smode sprog musicon
;               rnd (2) tmp tmp2 tmp3 pt2 (2); dbg_space $8e,
;               dbg_auto $8f (debug hooks, the same in every game)
;   sbcell      a byte anywhere (the bar's last filled cell)
;   scra scrb   its two screens (one screen: the same address twice)
;   gk_srow     the status line's offset in a screen (row x 40)
;   characters  c_space c_bar (9: 0-8 px filled, or with gk_barhalf = 1
;               5: 0, 2, 4, 6, 8) c_barl c_barr c_pct
;               c_digit0 (0-9 in a row)
;   texts       tx_loading tx_error tx_loaded (length first)
;   autopilot   (debug) a = 0 to press fire, $10 not
; ------------------------------------------------------------
music_stop = $c006              ; the built-in player's stop
music_flags = $c009             ; ... and flags: bit 0 leave voice 3 alone, bit 7 ntsc

; gk_musinit  the music's addresses from the header (it may be drawn
; over later: a game's character set often starts there)
gk_musinit
        lda hminit
        sta minit+1
        lda hminit+1
        sta minit+2
        lda hmplay
        sta mplay+1
        lda hmplay+1
        sta mplay+2
        lda hmflags
        sta mflags
        rts

; ---- sound: the music on voices 1 and 2 (and 3 when no effect
; plays: the built-in player is told to leave voice 3 alone) ----
sidinit ldx #$18
        lda #0
@c      sta $d400,x
        dex
        bpl @c
        lda #$0f
        sta $d418
        lda #$08
        sta $d410
        sta $d411               ; voice 3 pulse 50%
        rts

; musicgo  start the song the tool chose (if any)
musicgo lda #0
        sta musicon
        lda hsong
        bmi @x                  ; no music on this tape
        lda mflags
        lsr a                   ; c = the built-in player
        bcc @in
        lda ld_state
        lsr a                   ; c = ntsc
        lda #1                  ; leave voice 3 for the effects
        bcc @p
        ora #$80                ; ntsc pitch table
@p      sta music_flags
@in     lda hsong
        jsr minit
        lda #1
        sta musicon
@x      rts

; the music's entry points (from the header: gk_musinit)
minit   jmp $c000
mplay   jmp $c003
mstop   lda mflags
        lsr a
        bcc @sid
        jmp music_stop          ; the built-in player's
@sid    lda #0                  ; a sid tune: silence the chip
        ldx #$18
@c      sta $d400,x
        dex
        bpl @c
        rts
mflags  byte 1                  ; 1 the built-in player, 2 a sid (no effects)

; soundkey  s: music off and on
soundkey
        lda hsong
        bmi @x
        lda #$fd                ; keyboard row 1, column 5: s
        sta $dc00
        lda $dc01
        and #$20
        tax                     ; 0: held
        eor skey
        beq @x                  ; no change
        stx skey
        txa
        bne @x                  ; let go
        lda musicon
        beq @on
        jsr mstop
        lda #0
        sta musicon
@x      rts
@on     jmp musicgo

; ------------------------------------------------------------
; readfire  fire on joystick port 2 (or the debug autopilot)
;   out:  fpress $10 on a fresh press
; ------------------------------------------------------------
readfire
        lda #$ff
        sta $dc00               ; no keyboard row: port 2 alone
        lda $dc00
        and #$10                ; 0: held
        ldx dbg_auto
        beq @h
        jsr autopilot
@h      eor #$10                ; $10: held
        tax
        lda fire
        eor #$10                ; $10: not held before
        stx fire
        and fire
        sta fpress
        rts

; ------------------------------------------------------------
; startkey  once the program is loaded, space starts it (a fresh
; press: joystick 1's fire reads on the same line, so not while it
; is held)
; ------------------------------------------------------------
startkey
        bit ld_state
        bpl @x
        lda dbg_space
        bne @go
        lda #$ff
        sta $dc00               ; no row: joystick 1 alone
        lda $dc01
        and #$10
        beq @up                 ; its fire: not space
        lda #$7f
        sta $dc00               ; row 7
        lda $dc01
        and #$10                ; 0: space held
        bne @up
        lda spc
        bne @x                  ; held already
        lda #1
        sta spc
@go     lda #1
        sta exitreq
@x      rts
@up     lda #0
        sta spc
        rts

; ------------------------------------------------------------
; status  the status line: loading bar, error or loaded. Both
; screens; colours too (white text, a yellow bar). Call once a frame
; (drawn when it changes; a line on screen keeps it)
; ------------------------------------------------------------
status  lda ld_state
        asl a
        bcs @loaded
        bmi @error
        lda smode               ; loading: redraw when it moves
        bne @newl
        lda ld_progress
        cmp sprog
        beq @x
        jmp bar
@newl   jsr clrstatus
        lda #0
        sta smode
        ldx #<tx_loading
        ldy #>tx_loading
        lda #3
        jsr stext
        jmp barall
@x      rts
@error  lda frm                 ; flashes
        and #16
        ora #1
        cmp smode
        beq @x
        sta smode
        jsr clrstatus
        lda smode
        and #16
        bne @x
        ldx #<tx_error
        ldy #>tx_error
        lda #1
        jmp stext
@loaded lda #3                  ; loaded: space starts the program
        cmp smode
        beq @x
        sta smode
        jsr clrstatus
        ldx #<tx_loaded
        ldy #>tx_loaded
        lda #1
        jmp stext

clrstatus
        ldx #39
        lda #c_space
@c      sta scra+gk_srow,x
        sta scrb+gk_srow,x
        dex
        bpl @c
        rts

; stext  text x/y on the status line (both screens) from column a
stext   stx pt2
        sty pt2+1
        tax
        ldy #0
        lda (pt2),y
        sta tmp
        iny
@t      lda (pt2),y
        sta scra+gk_srow,x
        sta scrb+gk_srow,x
        lda #1                  ; white
        sta $d800+gk_srow,x
        inx
        iny
        dec tmp
        bne @t
        rts

; the bar: 20 cells from column 12 (8 px each: 160 px for 256), the
; percentage at 34-36. barall draws all of it with its colours; bar
; only the cells from the one the last fill ended in to the new fill's
barall  lda #7                  ; yellow
        ldx #21
@cl     sta $d800+gk_srow+11,x
        dex
        bpl @cl
        lda #1
        sta $d800+gk_srow+34
        sta $d800+gk_srow+35
        sta $d800+gk_srow+36
        lda #c_barl
        sta scra+gk_srow+11
        sta scrb+gk_srow+11
        lda #c_barr
        sta scra+gk_srow+32
        sta scrb+gk_srow+32
        lda #c_pct
        sta scra+gk_srow+36
        sta scrb+gk_srow+36
        lda #0
        sta sbcell
        lda #19                 ; the last cell to draw
        bne barc
bar     lda #$ff                ; the last: the fill's own
barc    sta tmp3
        lda ld_progress
        sta sprog
        lsr a                   ; pixels filled = progress * 5 / 8
        lsr a
        lsr a
        sta tmp
        lda sprog
        lsr a
        clc
        adc tmp
        sta tmp                 ; 0-158
        lsr a
        lsr a
        lsr a
        sta tmp2                ; its cell, 0-19
        cmp sbcell
        bcs @fw
        lda #0                  ; gone back: all of it
        sta sbcell
        lda #19
        sta tmp3
@fw     lda tmp3
        bpl @go
        lda tmp2
        sta tmp3
@go     ldx sbcell
@cell   lda tmp                 ; this cell: pixels - 8 x cell, 0-8
        sec
        sbc gk_x8,x
        bcs @pos
        lda #0
@pos    cmp #8
        bcc @ok
        lda #8
@ok     ldy #gk_barhalf         ; (the game's choice: 1 = 5 bar characters)
        beq @nh
        lsr a                   ; 0, 2, 4, 6 or 8 pixels
@nh     clc
        adc #c_bar
        sta scra+gk_srow+12,x
        sta scrb+gk_srow+12,x
        inx
        cpx tmp3
        bcc @cell
        beq @cell
        lda tmp2
        sta sbcell
        lda sprog               ; percent = progress * 100 / 256
        lsr a                   ; = p/4 + p/8 + p/64
        lsr a
        sta tmp
        lsr a
        sta tmp2
        lsr a
        lsr a
        lsr a
        clc
        adc tmp
        adc tmp2                ; 0-97
        ldx #c_digit0-1         ; tens digit
@t      inx
        sec
        sbc #10
        bcs @t
        adc #10+c_digit0
        sta scra+gk_srow+35
        sta scrb+gk_srow+35
        cpx #c_digit0
        bne @t2
        ldx #c_space
@t2     stx scra+gk_srow+34
        stx scrb+gk_srow+34
        rts
gk_x8   byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152

; ------------------------------------------------------------
; random  16-bit galois lfsr
;   out:  a = new low byte (xor the tick count); preserves x, y
; ------------------------------------------------------------
random  lsr rnd+1
        ror rnd
        bcc @x
        lda rnd+1
        eor #$b4
        sta rnd+1
@x      lda rnd
        eor frm
        rts
