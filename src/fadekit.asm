; ------------------------------------------------------------
; fadekit.asm  -  every module's end: once the program is in (and the
; module has asked to end: a game's kit, gk_exit; a loading screen
; keeps its screen, the counter at 000), the music fades out, 16 steps
; of fstep ticks (the kit's 8: about 2.6 seconds), before the module
; ends. The kit includes it; the show module too.
;
; The module (or the kit's mplay) calls fade from its tick once ld_state
; bit 7 is set (the loader's "loaded": the tape is stopped), instead of
; the music, and has:
;   fstep        ticks a volume step (an equate: the kit's)
;   zero page    tmp, musicon, exitreq (the kit's)
;   mplayr       the tune's play routine (the kit's), mflags
;   fsh fkn fsv  scratch free once loaded: 25, 25 and 34 bytes
;   fdirect      1 (set in init) when its tune sets $d418 at its init
;                only, filter off: then it fades as the built-in player
; and at the end fdone is 1 (as exitreq).
;
; $d418 is write-only, so a tune's filter mode (its top half) can't be
; read back, and writing the volume alone would silence the voices a
; tune routes to the filter. The built-in player (and a tune the module
; knows) sets $d418 at its init only, filter off: it plays as it is and
; $d418 is the volume. Any other SID tune runs its play routine with
; the I/O banked out (fsid): the tape is stopped, so no tape interrupt
; is missed. MODULES.md has the why of each step.
; ------------------------------------------------------------

; ------------------------------------------------------------
; fade  a tick once loaded (the module keeps its screen, the counter at
; 000): the music on at a volume a step lower every fstep ticks (the
; module's), 15 to 0 (16 steps); then exitreq. No music: half as long
;   uses: a, x, y, tmp
; ------------------------------------------------------------
fade    lda fadev
        bpl @on
        ldx #fstep              ; the first: from the volume as it is
        lda musicon
        bne @m
        ldx #fstep/2
@m      stx fadel
        stx fadet
        lda #15
        sta fadev
        lda #0                  ; nothing of the tune's known yet
        ldx #$18
@k      sta fkn,x
        dex
        bpl @k
@on     lda musicon
        beq @st
        lda mflags              ; the built-in player, or a tune the module
        and #1                  ; knows, plays as it is
        ora fdirect
        bne @bi
        jsr fsid
        jmp @st
@bi     jsr mplayr              ; (filter off: $d418 the volume)
        lda #15
        jsr fscale
        sta $d418
@st     dec fadet
        bne @x
        lda fadel
        sta fadet
        dec fadev
        bpl @x
        inc fadev               ; (0: silent) the program now
        lda #1
        sta exitreq
        sta fdone
@x      rts

; fscale  volume a (0-15) faded: a x (fadev + 1) / 16
;   uses: a, x, tmp
fscale  sta tmp
        lda #0
        ldx fadev
@a      clc
        adc tmp
        dex
        bpl @a
        lsr a
        lsr a
        lsr a
        lsr a
        rts

; ------------------------------------------------------------
; fsid  a SID tune's tick at the faded volume: its play routine with
; the I/O banked out (the tape is stopped: no tape interrupts, and the
; FLAG interrupt is off as well, in case it plays with cli), its
; writes noted (fsh: what it wrote; fkn: a register it has written),
; the RAM under the SID kept for the program, then each register it
; has written to the SID, $d417 down to $d400 (a voice's ADSR before
; its gate), and $d418 its filter mode with the volume faded. A
; register not yet written reads as a mark ($a5, then $5a): a write of
; the mark itself is seen the next tick. A tune that hasn't written
; $d418 since loaded keeps its own until the first step down, then
; gets low-pass (the commonest with voices routed to the filter;
; without any routed the mode makes no difference)
;   uses: a, x, y, tmp
; ------------------------------------------------------------
fsid    lda $d41b               ; voice 3's oscillator and envelope, as
        sta fsv+$20             ; the tune may read them
        lda $d41c
        sta fsv+$21
        sei
        lda #$10                ; no FLAG interrupt
        sta $dc0d
        lda $01
        sta fport
        and #$f8                ; all ram (the motor as it is)
        sta $01
        ldx #$1f
@sv     lda $d400,x             ; the program's bytes there
        sta fsv,x
        dex
        bpl @sv
        ldx #$18
@pl     lda fsh,x               ; what it wrote last, or the mark
        ldy fkn,x
        bne @p1
        lda fmark
@p1     sta $d400,x
        dex
        bpl @pl
        lda fsv+$20
        sta $d41b
        lda fsv+$21
        sta $d41c
        jsr mplayr
        ldx #$18
@cp     lda $d400,x
        ldy fkn,x
        bne @c1
        cmp fmark
        beq @c2                 ; (not written)
        inc fkn,x
@c1     sta fsh,x
@c2     dex
        bpl @cp
        ldx #$1f
@rs     lda fsv,x
        sta $d400,x
        dex
        bpl @rs
        lda fport
        sta $01
        lda #$90                ; FLAG interrupt on
        sta $dc0d
        cli
        lda fmark
        eor #$ff
        sta fmark
        ldx #$17
@w      lda fkn,x
        beq @w1
        lda fsh,x
        sta $d400,x
@w1     dex
        bpl @w
        lda #$1f                ; (not written: low-pass, volume 15)
        ldx fkn+$18
        beq @u
        lda fsh+$18
        jmp @v
@u      ldx fadev
        cpx #15
        beq @x                  ; (its own until the first step down)
@v      pha
        and #15
        jsr fscale
        sta tmp
        pla
        and #$f0
        ora tmp
        sta $d418
@x      rts

fdirect byte 0                  ; 1: the tune sets $d418 at its init only (the module's)
fadev   byte $ff                ; the volume's scale: 15 down to 0 ($ff: not yet)
fadet   byte 0                  ; ticks to the next step
fadel   byte 0                  ; ticks a step
fport   byte 0                  ; $01 as it was
fmark   byte $a5                ; a register not written yet
fdone   byte 0                  ; 1: faded out (gk_exit)
