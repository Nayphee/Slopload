; ------------------------------------------------------------
; show.asm  -  SlopLoad's picture and music module
;
; What shows while the program loads, when it isn't a game:
;   a picture   a Koala picture, put on the tape by the tool
;               (-show picture): bitmap at bank+$2000, screen at
;               bank+$0c00 in the VIC bank the tool chose (byte 25),
;               its colours loaded straight into colour ram
;   music       the built-in player or a SID tune (-sid), called
;               every so many raster lines (bytes 20-23: 1/64 lines,
;               PAL and NTSC), so 50 Hz, 60 Hz and faster tunes keep
;               their tempo on either machine
;   neither     with music only, the screen stays off (no bad lines,
;               so the tape can be nearly as fast as with no module)
;               and the border lightens as the program loads
; A tape error turns the border red until the loader recovers. The
; program starts as soon as it is in: nothing to press.
;
; No zero page, and it runs wherever the tool assembles it (showbase:
; clear of the tune and the picture). Never sei, never touch $01, the
; cia timers, or $fffa-$ffff (src/abi.asm has the rules).
; ------------------------------------------------------------
        incasm "abi.asm"

showbase = $ca00
builtin_stop = $c006            ; the built-in player's stop and flags
builtin_flags = $c009

*=showbase
        byte $50,$4c,$47,$31    ; "PLG1"
        word init
        word frame
        word stop
        word modend             ; end of the memory claimed (the tool adds the picture's, the music's)
        byte 48                 ; +12 worst edge timing jitter with the picture on
hsong   byte $ff                ; +13 song: a for the init (the tool), $ff no music
        byte 85                 ; +14 the most of the cpu (%) the loader may take (the tool)
hpic    byte $ff                ; +15 the picture's background colour (the tool), $ff none
hminit  word $c000              ; +16 music init, +18 play (the tool)
hmplay  word $c003
hper    word 312*64             ; +20 raster lines between play calls, PAL (1/64 lines)
hpern   word 263*64*6/5         ; +22 the same on NTSC
hmflags byte 1                  ; +24 1 the built-in player, 2 a sid tune
hbank   byte 0                  ; +25 the picture's vic bank, as $dd00's low bits (0 = bank 3)

; ------------------------------------------------------------
; init  the picture on (if any), the music started (if any)
;   in:   screen off, the picture's data and the music loaded
; ------------------------------------------------------------
init    lda #0
        sta musicon
        sta $d020
        sta target
        sta target+1
        lda #1
        sta wraps               ; the first play call at the next frame
        lda ld_state
        lsr a
        bcs @nt
        lda #<(312*64)
        ldx #>(312*64)
        ldy #0                  ; offset of the pal period
        beq @fl
@nt     lda #<(263*64)
        ldx #>(263*64)
        ldy #2
@fl     sta flen
        stx flen+1
        lda hper,y
        sta per
        lda hper+1,y
        sta per+1
        jsr settl
        jsr rline
        sta prevl
        stx prevh
        lda hpic
        bmi @music
        lda $dd02               ; the vic bank
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        ora hbank
        sta $dd00
        lda #$38                ; screen bank+$0c00, bitmap bank+$2000
        sta $d018
        lda #$18                ; multicolour, 40 columns
        sta $d016
        lda hpic
        sta $d021
@vb     bit $d011               ; on in the vertical blank
        bpl @vb
        lda #$3b                ; bitmap, screen on
        sta $d011
@music  lda hsong
        bmi @x
        jsr sidclr
        lda #$0f
        sta $d418
        lda hmflags
        lsr a
        bcc @in                 ; a sid tune: no flags
        lda ld_state
        lsr a                   ; c = ntsc
        lda #0                  ; all three voices for the music
        bcc @p
        lda #$80                ; ntsc pitch table
@p      sta builtin_flags
@in     lda hsong
        jsr minit
        lda #1
        sta musicon
@x      rts

minit   jmp (hminit)            ; (the header's)
mplay   jmp (hmplay)

; ------------------------------------------------------------
; frame  wait for the next play call's raster line (or, with no
; music, a new frame), play, set the border
;   out:  carry set once the program is in (it starts then)
; ------------------------------------------------------------
frame   lda musicon
        bne @mus
        jsr nextfr
        jmp @bord
@mus    lda wraps               ; frames to wait for first
        beq @line
@wf     jsr nextfr
        dec wraps
        bne @wf
@line   jsr rline               ; then the line
        cpx th
        bcc @line
        bne @go
        cmp tl
        bcc @line
@go     jsr mplay
        clc                     ; the next call: per lines on
        lda target
        adc per
        sta target
        lda target+1
        adc per+1
        sta target+1
@wr     lda target+1            ; past this frame: into the next ones
        cmp flen+1
        bcc @nw
        bne @sub
        lda target
        cmp flen
        bcc @nw
@sub    sec
        lda target
        sbc flen
        sta target
        lda target+1
        sbc flen+1
        sta target+1
        inc wraps
        bne @wr
@nw     jsr settl
        jsr rline
        sta prevl
        stx prevh
@bord   lda ld_state
        and #$40
        beq @ok
        lda #2                  ; tape error: red until it recovers
        bne @bd
@ok     lda hpic
        bpl @blk                ; a picture: black border
        lda ld_progress         ; music only: lighter as it loads
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda ramp,x
        jmp @bd
@blk    lda #0
@bd     cmp lastbd              ; only when it changes: a store each frame
        beq @same               ; makes the 8565's grey dot on the border
        sta lastbd
        sta $d020
@same   lda ld_state
        asl a                   ; carry = loaded
        rts

; nextfr  wait for the raster to start a new frame (lower than the
; line it was last seen on)
nextfr  jsr rline
        cpx prevh
        bcc @new
        bne @up
        cmp prevl
        bcc @new
@up     sta prevl
        stx prevh
        jmp nextfr
@new    sta prevl
        stx prevh
        rts

; rline  the raster line: a = low byte, x = bit 8
rline   lda $d012
        sta rl
        lda $d011
        asl a
        lda #0
        rol a
        tax
        lda $d012
        cmp rl
        bne rline
        rts

; settl  the target's line (target / 64) into tl, th
settl   lda target
        sta tl
        lda target+1
        sta th
        ldx #6
@s      lsr th
        ror tl
        dex
        bne @s
        rts

ramp    byte 0,0,11,11,12,12,15,15

; ------------------------------------------------------------
; stop  the music off (the loader turns the screen off)
; ------------------------------------------------------------
stop    lda musicon
        beq @x
        lda hmflags
        lsr a
        bcc @sid
        jsr builtin_stop
        jmp @x
@sid    jsr sidclr
@x      lda #0
        sta $d418
        rts

sidclr  ldx #$18                ; every sid register to 0
        lda #0
@c      sta $d400,x
        dex
        bpl @c
        rts

; ---- variables (no zero page) ----
musicon byte 0
flen    word 0                  ; a frame, 1/64 lines
per     word 0                  ; between play calls, 1/64 lines
target  word 0                  ; the next call, 1/64 lines into its frame
wraps   byte 0                  ; frames to wait for before it
tl      byte 0                  ; its line
th      byte 0
prevl   byte 0                  ; the line last seen
prevh   byte 0
rl      byte 0
lastbd  byte $ff                ; the border colour last stored ($ff: none yet)
modend
