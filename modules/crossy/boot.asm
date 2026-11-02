; ------------------------------------------------------------
; boot.asm  -  Crossy-Load's setting up, run once: in screen a's rows
; 6-24 (crossy.asm puts it at scra+256), which the game doesn't use
; until it has run (init draws the play field in buffer b; screen a is
; built after, a row at a time). inidone (low.asm) clears them, then
; the title. The room it left in the low part holds copyrow.
; ------------------------------------------------------------

; ------------------------------------------------------------
; init  set up screen and sound; called once
;   in:   screen off, loader interrupt running
;   note: runs from screen a's rows 6-24 (boot.asm), which nothing
;         writes until it ends: inidone (low.asm) clears them
; ------------------------------------------------------------
init    jsr gk_musinit          ; the music's addresses from the header
        lda #0
        sta $d015
        ldx #$7f                ; zero page $10-$8f clear (but the music's)
@z      cpx #$70-$10
        bcc @zc
        cpx #$80-$10
        bcc @zn
@zc     sta $10,x
@zn     dex
        bpl @z
        sta $d020               ; (a 0)
        sta $d021
        lda #$0b
        sta $d011
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc                ; vic bank 3
        sta $dd00
        lda #1
        sta $d022               ; white
        lda #2
        sta $d023               ; red-brown
        lda #$18
        sta $d016               ; multicolour, 40 columns
        lda #$a7
        sta rnd
        sta rnd+1
        jsr sidinit
        jsr musicgo
        jsr clrall
        jsr newworld
@g      jsr genlane
        lda lgen
        cmp #16
        bne @g
@b      lda cprow               ; the play field, all of it, in buffer b
        jsr regenrow
        inc cprow
        lda cprow
        cmp #lastrow+1
        bne @b
        lda #1
        sta front
        sta nfront
        lda #0                  ; next: buffer a, a row on (bready 0:
        sta pmode               ; newworld)
        lda ld_state            ; drawlane on NTSC: a pixel a step (a 3 px
        and #1                  ; step can take 97 lines with the loader
        sta vb1                 ; busy; NTSC's frame has 263)
        lda #251                ; the raster latch's line (no interrupt:
        sta $d012               ; split clears it, bgtail reads it)
        ldx crow
        stx crowd
        inx
        stx crowx
        lda #6
        sta cprow
        sta ntscc
        sta mntsc
        jsr colall
        lda #d018b
        sta $d018
        jsr drawscore
        lda #$ff
        sta smode
        jmp inidone             ; (screen a, where this was, blank: the title)

; ------------------------------------------------------------
; clrall  both screens blank, colour ram black (the screen is off);
;         screen a's rows 6-24 later (this code is there: inidone)
; ------------------------------------------------------------
clrall  ldx #0
@c      lda #c_space
        sta scra,x
        sta scrb,x
        sta scrb+$100,x
        sta scrb+$200,x
        sta scrb+$2e8,x
        lda #0
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne @c
        rts

