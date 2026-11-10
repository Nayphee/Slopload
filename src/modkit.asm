; ------------------------------------------------------------
; modkit.asm  -  what every SlopLoad module does the same way
; (the standard: MODULES.md). A module includes it after its own
; equates (and modinit.asm, the routines only init calls: gk_musinit,
; sidinit), and gets:
;   musicgo     start the song the tool chose; mstop, minit, mplay
;   soundkey    S turns the music off and on
;   readfire    fire on joystick port 2 (fpress: a fresh press)
;   startkey    once loaded, exitreq: at once, or with the tool's -wait
;               on a fresh SPACE (the module plays on until then)
;   gk_done     a game over: once loaded, exitreq (with -wait, the end
;               of a game starts the program too)
;   gk_exit     the frame's last call: c set when the module may end,
;               exitreq set and the music faded out first (fadekit.asm:
;               every module includes it, where it has room)
;   status      the status line: LOADING and a bar with the percent (or
;               with -countdown the blocks still to load), TAPE ERROR
;               (flashing), LOADED! PRESS SPACE...
;   random      16-bit lfsr
;   gk_bord     the border, unless it is the loader's
; It needs from the module:
;   zero page   frm fire fpress spc skey exitreq smode sprog musicon
;               rnd (2) tmp tmp2 tmp3 pt2 (2); dbg_space $8e,
;               dbg_auto $8f (debug hooks, the same in every module)
;   fadekit.asm included (anywhere), and its scratch fsh fkn fsv:
;               25, 25 and 34 bytes untouched while the module still runs
;               once the program is in (fadescr.asm: as bytes)
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
fstep = 8                       ; the fade: ticks a volume step (16 x 8: 2.6 s at 50 Hz)
gk_chain = $10                  ; header +28 (and +27) bit 4: a chain's music playing on
music_flags = $c009             ; ... and flags: bit 0 leave voice 3 alone, bit 7 ntsc

; gk_bord  the border = a, unless it is the loader's (ld_state bit 5:
; -showstripes, the loading lines on through the module)
;   uses: nothing (a, x, y kept; the flags a's)
gk_bord pha
        lda #$20
        bit ld_state
        bne @x
        pla
        sta $d020
        rts
@x      pla
        rts

; ---- sound: the music on voices 1 and 2 (and 3 when no effect
; plays: the built-in player is told to leave voice 3 alone) ----
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
@in     lda gk_opt              ; a chain's second module (+28 bit 4): the
        and #gk_chain           ; tune is playing already, started by the
        bne @on                 ; module before: it plays on
        lda hsong
        jsr minit
@on     lda gk_opt              ; (once: S starts it again from its start)
        and #$ff-gk_chain
        sta gk_opt
        lda #1
        sta musicon
@x      rts

; the music's entry points (from the header: gk_musinit): minit, and
; mplay the tick's music: the tune's play routine (mplayr), or once
; gk_exit has begun the fade, the fade's tick (which plays it quieter)
minit   jmp $c000
mplay   lda gk_fade
        beq mplayr
        jmp fade
mplayr  jmp $c003
gk_fade byte 0                  ; 1: fading out (gk_exit)
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
gk_opt  byte 0                  ; header +28: the tool's options (gk_musinit)
gk_blk  byte 0                  ; header +26: the program's blocks (gk_musinit)

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
; startkey  once the program is loaded, it starts (exitreq): at once,
; or with the tool's -wait (header +28 bit 1, gk_opt) on a fresh SPACE
; press, the module playing on until then (joystick 1's fire reads on
; the same line, so not while it is held). Call it once a tick
; ------------------------------------------------------------
startkey
        bit ld_state
        bpl @x
        lda gk_opt
        and #2
        beq @go                 ; no -wait: now
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
; gk_done  a game is over: once the program is in, it starts. Only
; -wait (header +28 bit 1) keeps a module running once it's in
; (startkey), so this is its other way out: SPACE, or the end of a game
;   out:  c set: asked to start (exitreq 1); c clear: still loading
;   uses: a
; ------------------------------------------------------------
gk_done bit ld_state
        bpl @no
        lda #1
        sta exitreq
        sec
        rts
@no     clc
        rts

; ------------------------------------------------------------
; gk_exit  the frame's last call, for its carry: set when the module
; may end. Asked to (exitreq, from startkey or gk_done), it ends at
; once with no music playing; with music the tune fades out first (the
; module plays on for its 2.6 seconds: mplay plays the fade), as the
; loading screens' does
;   out:  c set: end; c clear: run on
;   uses: a
; ------------------------------------------------------------
gk_exit lda exitreq
        beq @no
        lda musicon
        beq @yes                ; (no music: at once)
        lda fdone
        bne @yes                ; (faded)
        lda #1
        sta gk_fade
@no     clc
        rts
@yes    sec
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
; the number after the bar: the percent (" 97%": hundreds at column 33,
; leading zeros blank), or with -countdown (header +28 bit 3) the
; blocks still to load ("024" at 34-36, over the %): header +26, the
; program's blocks that load while the module runs, less their share
; loaded
        ldy #0                  ; y: 0 the percent, 1 the count
        lda gk_opt
        and #8
        beq @pc
        iny
        lda gk_blk
        byte $2c                ; (bit abs: past the lda #100)
@pc     lda #100
        sty tmp3                ; 0: zeros blank until a digit, 1: shown
        sta tmp                 ; progress x m / 256 (m: 100 or the blocks)
        lda sprog
        sta tmp2
        lda #0
        ldx #8
        lsr tmp2
@mul    bcc @ns
        clc
        adc tmp
@ns     ror a
        ror tmp2
        dex
        bne @mul
        cpy #0
        beq @pr                 ; the percent, 0-99
        eor #$ff                ; the count: m less the blocks loaded
        sec
        adc tmp
@pr     ldx #c_digit0-1         ; hundreds
        sec
@h      inx
        sbc #100
        bcs @h
        adc #100
        jsr @put
        ldx #c_digit0-1         ; tens
        sec
@t      inx
        sbc #10
        bcs @t
        adc #10+c_digit0
        jsr @put
        sta tmp3                ; units: always shown
        tax
@put    pha
        cpx #c_digit0
        bne @nz
        lda tmp3
        bne @st                 ; zeros shown (the count, or after a digit)
        ldx #c_space
        byte $2c                ; (bit abs: past the stx; reads ram at tmp3*256+$86)
@nz     stx tmp3
@st     txa
        sta scra+gk_srow+33,y
        sta scrb+gk_srow+33,y
        pla
        iny
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
