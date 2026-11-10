; ------------------------------------------------------------
; show.asm  -  SlopLoad's picture and music module
;
; What shows while the program loads, when it isn't a game:
;   a picture   put on the tape by the tool (-module PICTURE): bitmap
;               at bank+$2000, screen at bank+$0c00 in the VIC bank
;               the tool chose (byte 25); a Koala picture's colours
;               loaded straight into colour ram, a hires one (Art
;               Studio, Doodle: +28 bit 2) has none
;   music       the built-in player or a SID tune (-sid), called
;               every so many raster lines (bytes 20-23: 1/64 lines,
;               PAL and NTSC), so 50 Hz, 60 Hz and faster tunes keep
;               their tempo on either machine
;   neither     with music only, the screen stays off (no bad lines,
;               so the tape can be nearly as fast as with no module)
;               and the border lightens as the program loads
; A tape error turns the border red until the loader recovers. Once
; the program is in it starts, unless the tool asked for an ending
; (+28): -wait puts PRESS SPACE OR FIRE across the picture's bottom row
; and waits for one; -fade then fades the music out (src/fadekit.asm,
; about 2.6 seconds), and the program starts.
;
; No zero page, and it runs wherever the tool assembles it (showbase:
; clear of the tune and the picture). While loading: never sei, never
; touch $01, the cia timers, or $fffa-$ffff (src/abi.asm has the
; rules). Once loaded the tape is stopped: the prompt reads the
; character ROM with interrupts off, as the fade's SID path does.
; ------------------------------------------------------------
        incasm "abi.asm"

showbase = $ca00
builtin_stop = $c006            ; the built-in player's stop and flags
builtin_flags = $c009
fstep = 8                       ; the fade: play calls a volume step (16 x 8: 2.6 s at 50 Hz)
prow = 24                       ; the prompt's character row
prowbm = $2000+prow*320         ; its bitmap in the bank ($3e00: low byte 0)
prowsc = $0c00+prow*40          ; its screen ($0fc0)

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
        byte 0                  ; +26 (a module's block count: none here)
        byte $11                ; +27 bit 0: it leaves the border to the loader (-showstripes);
                                ; bit 4: second in a chain, it plays on the tune the first started
hopt    byte 0                  ; +28 the tool's: bit 0 -fade, bit 1 -wait, bit 2 a hires picture,
                                ; bit 4 a chain's tune already playing (no sidclr, no init)
; the loading sprites (-sprite: the tool's), their data at the picture's
; bank + $3f40 and + $3f80 (pointers $fd, $fe)
hspren  byte 0                  ; +29 $d015: 0 none, 1 or 3
hsprxy  byte 0,0,0,0            ; +30 sprite 0's x (low 8 bits), y; +32 sprite 1's
hsprmsb byte 0                  ; +34 $d010
hsprmc  byte 0                  ; +35 $d01c (multicolour)
hsprxx  byte 0                  ; +36 $d01d (twice as wide)
hspryx  byte 0                  ; +37 $d017 (twice as tall)
hspr25  byte 0,0                ; +38 $d025, $d026 (multicolour's shared colours)
hsprlo  byte 0                  ; +40 the lines they cover (0-255, the tool's):
hsprhi  byte 0                  ; +41 their colour changes outside them
hflen   byte 1                  ; +42 the flash table's length (1-32)
hfspd   byte 1                  ; +43 frames a step
hflash  byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; +44 the colours (32)
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
hcolsrc word 0                  ; +76 a Koala picture's colours in the module's own memory
                                ; (a .lm's: PICTURE-LM, tools/picturelm.py; a part can't
                                ; load into colour ram), copied there at the start; 0:
                                ; none (a picture module loads them there)
; (it leaves the border to the loader while ld_state bit 5 is set:
; -showstripes; the tool knows it does)

mflags = hmflags                ; (fadekit.asm's names)

; ------------------------------------------------------------
; init  the picture on (if any), the music started (if any)
;   in:   screen off, the picture's data and the music loaded
; ------------------------------------------------------------
init    lda #$20                ; the border black, unless the loader's
        bit ld_state            ; (-showstripes)
        bne @nb
        lda #0
        sta $d020
@nb     lda #0
        sta musicon
        sta target
        sta target+1
        sta drawn
        sta keyed
        sta kup
        sta exitreq
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
        lda #3                  ; the bank's base (high byte)
        sec
        sbc hbank
        lsr a
        ror a
        ror a
        sta pbase0
        lda $dd02               ; the vic bank
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        ora hbank
        sta $dd00
        lda #$38                ; screen bank+$0c00, bitmap bank+$2000
        sta $d018
        ldx #$18                ; multicolour, 40 columns
        lda hopt
        and #4
        beq @mc
        ldx #$08                ; (a hires picture)
@mc     stx $d016
        lda hpic
        sta $d021
        jsr colcopy
        jsr sprinit
@vb     bit $d011               ; on in the vertical blank
        bpl @vb
        lda #$3b                ; bitmap, screen on
        sta $d011
@music  lda hsong
        bmi @x
        lda hopt                ; a chain's: the tune playing already, started
        and #$10                ; by the module before: it plays on
        bne @on
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
@on     lda #1
        sta musicon
@x      rts

minit   jmp (hminit)            ; (the header's)
mplay   jmp (hmplay)
mplayr = mplay                  ; (fadekit.asm's name)

; tick  a play call: once loaded and past the key (-wait), the fade
; (-fade) instead
tick    bit ld_state
        bpl @p
        lda hopt
        lsr a
        bcc @p                  ; no fade
        and #1                  ; (-wait)
        beq @f
        lda keyed
        beq @p
@f      jmp fade
@p      jmp mplay

; ------------------------------------------------------------
; frame  wait for the next play call's raster line (or, with no
; music, a new frame), play, set the border
;   out:  carry set once the program may start: it is in, and the
;         ending (+28) is done
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
        jsr sprchk
        cpx th
        bcc @line
        bne @go
        cmp tl
        bcc @line
@go     jsr tick
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
@bord   lda #$20                ; (the border the loader's: -showstripes)
        bit ld_state
        bne ending
        lda ld_state
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
        beq ending              ; makes the 8565's grey dot on the border
        sta lastbd
        sta $d020

; ending  once the program is in: the prompt and a fresh press of space
; or fire (-wait), then the fade (-fade); c set when it may start
ending  bit ld_state
        bmi @in
        clc
        rts
@in     lda hopt
        and #2
        beq @nokey              ; no -wait
        lda keyed
        bne @nokey
        lda drawn
        bne @k
        inc drawn
        jsr prompt
@k      lda kdbg                ; (tests: a press)
        bne @press
        jsr kheld
        bcc @up
        lda kup
        beq @no                 ; held since before the prompt: not a press
@press  inc keyed
        bne @nokey              ; (always)
@up     lda #1
        sta kup                 ; let go: the next is a press
@no     clc
        rts
@nokey  lda hopt
        lsr a
        bcc @go                 ; no -fade
        lda musicon
        beq @go
        lda exitreq             ; the fade's end
        bne @go
        clc
        rts
@go     sec
        rts

; kheld  space, or fire on joystick port 2 (port 1's fire reads as space)
;   out:  c set if held
;   uses: a
kheld   lda #$ff
        sta $dc00               ; no keyboard row: port 2 alone
        lda $dc00
        and #$10
        beq @y
        lda #$7f
        sta $dc00               ; row 7: space
        lda $dc01
        and #$10
        beq @y
        clc
        rts
@y      sec
        rts

; ------------------------------------------------------------
; prompt  PRESS SPACE OR FIRE across the picture's bottom row: its
; bitmap cleared, the letters from the character ROM twice as wide
; (each pixel two: in a multicolour picture a pixel of colour RAM's
; colour), white (black on a white background). Drawn from line 251,
; under the picture, in well under a frame: the row changes whole at
; the next one. The tape is stopped, so the ROM is read with
; interrupts off; colour RAM after, with the I/O back
;   uses: a, x, y
; ------------------------------------------------------------
prompt  lda #3                  ; the bank's base (high byte)
        sec
        sbc hbank
        lsr a
        ror a
        ror a                   ; (3 - bank bits) x $40
        sta pbase
        clc
        adc #>prowbm
        sta @cl1+2              ; the row's bitmap: 320 bytes
        sta pdst+2
        adc #1
        sta @cl2+2
        lda pbase
        clc
        adc #>prowsc
        sta pscr+2
@w      jsr rline               ; under the picture: line 251 on
        cpx #1
        beq @go
        cmp #251
        bcc @w
@go     sei
pdraw   = *                     ; (tests: the drawing's start and end)
        lda $01
        sta pport
        and #$f8
        ora #1                  ; the character ROM at $d000, RAM elsewhere
        sta $01
        lda #0
        ldx #0
@cl1    sta $ff00,x             ; (prowbm's low byte is 0)
        inx
        bne @cl1
        ldx #63
@cl2    sta $ff00,x
        dex
        bpl @cl2
        lda #8                  ; the first letter's cell (column 1)
        sta pdst+1
        ldx #0
@ch     stx pk
        lda ptext,x             ; its glyph: $d000 + 8 x code
        sta pg+1
        lda #0
        asl pg+1
        rol a
        asl pg+1
        rol a
        asl pg+1
        rol a
        ora #$d0
        sta pg+2
        lda pdst+1              ; the right half: 8 bytes on
        clc
        adc #8
        sta pdr+1
        lda pdst+2
        adc #0
        sta pdr+2
        ldy #7
pg      = *
        lda $d000,y
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda twice,x
pdst    = *
        sta $ff00,y
        pla
        and #15
        tax
        lda twice,x
pdr     = *
        sta $ff00,y
        dey
        bpl pg
        lda pdr+1               ; the next letter: 16 bytes on
        clc
        adc #8
        sta pdst+1
        lda pdr+2
        adc #0
        sta pdst+2
        ldx pk
        inx
        cpx #ptextend-ptext
        bne @ch
        lda pport
        sta $01
        cli
        ldx #1                  ; white on the picture's background
        lda hpic
        cmp #1
        bne @c
        dex                     ; (black on white)
@c      lda hopt
        and #4
        beq @mc
        txa                     ; hires: the screen's high nybble, on black
        asl a
        asl a
        asl a
        asl a
        tax
@mc     txa
        ldy #39
pscr    = *
        sta $ffc0,y             ; (prowsc's low byte)
        sta $d800+prow*40,y     ; (multicolour: pairs 11 are colour RAM's)
        dey
        bpl pscr
pdone   rts

; a nybble's four pixels, each twice: 11 for a 1, 00 for a 0
twice   byte $00,$03,$0c,$0f,$30,$33,$3c,$3f,$c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff
ptext   byte 16,18,5,19,19,32,19,16,1,3,5,32,15,18,32,6,9,18,5   ; PRESS SPACE OR FIRE
ptextend

; nextfr  wait for the raster to start a new frame (lower than the
; line it was last seen on)
nextfr  jsr rline
        jsr sprchk
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

; colcopy  hcolsrc's 1,000 colours (if any) into colour ram, a quarter at a time
;   uses: a, x
colcopy lda hcolsrc+1
        beq @x
        ldx #0                  ; the four quarters' sources: + 0, 250, 500, 750
@q      lda hcolsrc
        clc
        adc qoff,x
        sta @s0+1,x             ; (each lda's operand: 6 bytes apart)
        lda hcolsrc+1
        adc qoffh,x
        sta @s0+2,x
        txa
        clc
        adc #6
        tax
        cpx #24
        bcc @q
        ldx #0
@s0     lda $ffff,x
        sta $d800,x
        lda $ffff,x
        sta $d800+250,x
        lda $ffff,x
        sta $d800+500,x
        lda $ffff,x
        sta $d800+750,x
        inx
        cpx #250
        bne @s0
@x      rts
qoff    byte 0,0,0,0,0,0,250,0,0,0,0,0,<500,0,0,0,0,0,<750         ; (by 6: an lda and a sta)
qoffh   byte 0,0,0,0,0,0,0,0,0,0,0,0,>500,0,0,0,0,0,>750

; ------------------------------------------------------------
; sprinit  the loading sprites (+29 on): where, how, their first colour
;   uses: a, x, y
; ------------------------------------------------------------
sprinit lda hspren
        beq @x
        ldx #3
@xy     lda hsprxy,x            ; x0, y0, x1, y1
        sta $d000,x
        dex
        bpl @xy
        lda hsprmsb
        sta $d010
        lda hsprmc
        sta $d01c
        lda hsprxx
        sta $d01d
        lda hspryx
        sta $d017
        lda hspr25
        sta $d025
        lda hspr25+1
        sta $d026
        lda #0
        sta $d01b               ; (in front of the picture)
        sta fcnt
        sta fidx
        sta fpend
        lda hflash
        sta $d027
        sta $d028
        lda pbase0              ; their pointers: screen + $3f8
        clc
        adc #>$0ff8
        sta @p1+2
        sta @p2+2
        lda #$fd
@p1     sta $fff8
        lda #$fe
@p2     sta $fff9
        lda hspren
        sta $d015
@x      rts

; sprchk  from the waits, the raster in a (low byte) and x (bit 8): a
; new frame counts, every hfspd frames the flash's next colour, written
; while the beam is outside the sprites' lines
;   uses: y (a, x kept)
sprchk  ldy hspren
        beq @x
        ldy hflen               ; (one colour: nothing to flash; a store
        cpy #2                  ; to a colour register each frame would
        bcc @x                  ; make the 8565's grey dots)
        sta sprl
        cpx sprh                ; a new frame: the line lower than before
        bcc @new
        bne @old
        cmp sprlo
        bcs @old
@new    ldy fcnt
        iny
        cpy hfspd
        bcc @c
        ldy fidx                ; the next colour
        iny
        cpy hflen
        bcc @i
        ldy #0
@i      sty fidx
        inc fpend
        ldy #0
@c      sty fcnt
@old    stx sprh
        lda sprl
        sta sprlo
        ldy fpend
        beq @r
        cpx #1                  ; (lines 256 on: the border)
        beq @w
        cmp hsprlo
        bcc @w
        cmp hsprhi
        bcc @r
        beq @r
@w      ldy fidx
        lda hflash,y
        sta $d027
        sta $d028
        lda #0
        sta fpend
@r      lda sprl
@x      rts

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

        incasm "fadekit.asm"

; ---- variables (no zero page) ----
musicon byte 0
exitreq byte 0                  ; the fade's end
tmp     byte 0
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
drawn   byte 0                  ; the prompt drawn
keyed   byte 0                  ; space or fire pressed
kup     byte 0                  ; ... let go of since the prompt
kdbg    byte 0                  ; (tests: not 0 is a press)
pbase   byte 0                  ; the picture's bank (high byte)
pport   byte 0                  ; $01 as it was
pk      byte 0                  ; the letter being drawn
pbase0  byte 0                  ; the picture's bank (high byte), from init
fcnt    byte 0                  ; the flash: frames into this step
fidx    byte 0                  ; ... its colour now
fpend   byte 0                  ; ... not yet written
sprl    byte 0                  ; the line last seen (low byte, bit 8)
sprh    byte 0
sprlo   byte 0
codeend
; the fade's scratch (fadekit.asm), past the bytes on the tape
fsh = codeend                   ; (25) the tune's SID registers
fkn = codeend+25                ; (25) 1: written
fsv = codeend+50                ; (34) the RAM under $d400-$d41f; $d41b, $d41c
modend = codeend+84
