; ------------------------------------------------------------
; hello.asm  -  Hello-Load: a hot-air balloon over a hires bitmap, the
; words HELLO WORLD and a loading bar, written by hand with no kit.
; LMGUIDE.md walks through every line. Joystick in port 2: left and
; right steer, fire lights the burner (the balloon rises, and with no
; tune on the tape the burner roars). The program starts as soon as
; it is in.
; ------------------------------------------------------------

; ---- where everything is: all from mb, the module's VIC bank ----
mb      = $c000                 ; bank 3 (tools/build.py: $8000, bank 2, to
                                ; find what moves when a chain moves it)
screen  = mb+$0c00              ; the bitmap's colours: a byte for each cell
sprptr  = screen+$03f8          ; sprite 0's pointer, after the 1,000 cells
shape   = mb+$0a00              ; the balloon's 63 bytes
bitmap  = mb+$2000              ; 8,000 bytes: 320 x 200 pixels
textat  = bitmap+3*320+14*8     ; HELLO WORLD: cell row 3, column 14
barat   = bitmap+1*320+4*8      ; the loading bar: cell row 1, columns 4-35
fieldat = bitmap+21*320         ; the field: cell rows 21-24

; ---- the loader's two bytes (read them, never write them) ----
ld_state = $02                  ; bit 7 loaded, bit 6 a tape error, bit 5
                                ; the border is the loader's, bit 0 NTSC
ld_progress = $03               ; how much is in: 0-255

; ---- zero page: $10-$8f is the module's ----
ptr     = $10                   ; a pointer (2 bytes)
bx      = $12                   ; the balloon's x (2 bytes: 24-320)
by      = $14                   ; its y (50-200)
tick    = $15                   ; ticks so far
nframe  = $16                   ; NTSC: frames, 0-5
fired   = $17                   ; the fire button, last tick ($10: up)
px      = $18                   ; plot's x (2 bytes: 0-319)
py      = $1a                   ; plot's y (0-199)
keepx   = $1b                   ; (words: x kept)
cells   = $1c                   ; the loading bar's cells filled

*=mb
; ---- the header: 32 bytes, the module's first ----
        byte $50,$4c,$47,$31    ; +0  "PLG1": a SlopLoad module, version 1
        word init               ; +4  called once, the screen off
        word frame              ; +6  called every frame
        word stop               ; +8  called once, at the end
        word mb+$3f40           ; +10 the end of its memory: the bitmap's end
        byte 56                 ; +12 its jitter: 48, and 8 for a sprite
song    byte $ff                ; +13 the tool's: the song, $ff none
        byte 0                  ; +14 the loader's share of the CPU: 0, 35%
        byte 0                  ; +15 (the show module's)
tinit   word 0                  ; +16 the tool's: the tune's init
tplay   word 0                  ; +18 ... and its play
        word 0,0                ; +20, +22 the tool's: the tune's timing
        byte 0                  ; +24 the tool's: which player
        byte 0                  ; +25 (the show module's)
        byte 0                  ; +26 the tool's: the program's blocks
        byte 0                  ; +27 what it keeps: none of the options
opts    byte 0                  ; +28 the tool's options
        byte 0,0,0              ; +29 to +31: spare

; ------------------------------------------------------------
; init  once, the screen off: the VIC, the picture, the balloon, the
; sound
; ------------------------------------------------------------
init    lda $dd02               ; the VIC's bank: CIA 2's port A, bits 0-1
        ora #3                  ; as outputs
        sta $dd02
        lda #>init              ; our own page: $c0-$cf, or $80-$8f moved
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a                   ; its top two bits: the bank, 3 or 2
        eor #3                  ; $dd00's bits for it: 0 or 1
        sta ptr
        lda $dd00
        and #$fc
        ora ptr
        sta $dd00
        lda #$0b                ; the screen off
        sta $d011
        lda #$38                ; colours at bank+$0c00, bitmap at bank+$2000
        sta $d018
        lda #$08                ; hires, 40 columns
        sta $d016

        lda #<bitmap            ; the bitmap cleared: 31 pages, then 64
        sta ptr
        lda #>bitmap
        sta ptr+1
        lda #0
        tay
        ldx #31
@cb     sta (ptr),y
        iny
        bne @cb
        inc ptr+1
        dex
        bne @cb
        ldy #63
@cb2    sta (ptr),y
        dey
        bpl @cb2

        ldx #0                  ; every cell sky: white on light blue
        lda #$1e
@sky    sta screen,x
        sta screen+250,x
        sta screen+500,x
        sta screen+750,x
        inx
        cpx #250
        bne @sky
        ldx #119                ; rows 18-20, the hills: green on light blue
        lda #$5e
@hc     sta screen+18*40,x
        dex
        bpl @hc
        ldx #160                ; rows 21-24, the field: light green on green
        lda #$d5                ; (160 cells: x 160 down to 1)
@fc     sta screen+21*40-1,x
        dex
        bne @fc

        jsr field               ; the picture: the field, the hills, the
        jsr hills               ; words, the empty bar
        jsr words
        jsr bar0

        lda #<160               ; the balloon: the middle, high up
        sta bx
        lda #>160
        sta bx+1
        lda #80
        sta by
        lda #(shape-mb)/64      ; its shape's place in the bank, in 64s
        sta sprptr
        lda #2                  ; red
        sta $d027
        lda #0                  ; one colour, normal size
        sta $d01c
        sta $d017
        sta $d01d
        lda #1                  ; sprite 0 on
        sta $d015
        jsr place

        lda #0
        sta tick
        sta nframe
        sta cells
        lda #$10
        sta fired
        lda song                ; a tune on the tape?
        cmp #$ff
        beq @quiet
        lda opts                ; playing already (a chain's second, or the
        and #$10                ; music first): it plays on
        bne @x
        lda song                ; else started: A the song
        jsr tuneinit
@x      rts
@quiet  ldx #$18                ; no tune: the SID ours, silent, loud
        lda #0
@sid    sta $d400,x
        dex
        bpl @sid
        lda #15
        sta $d418
        rts

tuneinit jmp (tinit)            ; (jsr here: the tune's own rts comes back)
tuneplay jmp (tplay)

; ------------------------------------------------------------
; frame  every frame: wait for the vertical blank, a tick (5 frames in
; 6 on NTSC), and the carry set once the program is in
; ------------------------------------------------------------
frame
@w0     lda $d012               ; the last blank over (lines 0-250) ...
        cmp #251
        bcs @w0
        bit $d011
        bmi @w0
@w1     bit $d011               ; ... and this one begun: line 251 on
        bmi @vb
        lda $d012
        cmp #251
        bcc @w1
@vb     lda #$3b                ; the bitmap, the screen on
        sta $d011
        jsr place               ; the balloon where the last tick put it
        jsr border
        lda ld_state            ; NTSC: 60 frames a second, a tick in 5
        lsr a                   ; (bit 0 into the carry)
        bcc @tick
        inc nframe
        lda nframe
        cmp #6
        bcc @tick
        lda #0
        sta nframe
        beq @end                ; (the sixth: no tick)
@tick   inc tick
        lda song
        cmp #$ff
        beq @nt
        jsr tuneplay            ; the tune, once a tick
@nt     jsr steer
        jsr burner
        jsr bar
@end    lda ld_state            ; bit 7, loaded, into the carry: the program
        asl a                   ; starts
        rts

; ------------------------------------------------------------
; stop  once, at the end: the SID silent
; ------------------------------------------------------------
stop    ldx #$18
        lda #0
@s      sta $d400,x
        dex
        bpl @s
        rts

; ------------------------------------------------------------
; border  black, red while the tape has an error; untouched while
; the loader has it (the loading lines on through the module). Written
; only when it changes: a write shows a grey dot on newer C64s
; ------------------------------------------------------------
border  lda ld_state
        and #$20
        bne @x
        ldx #0                  ; black
        lda ld_state
        and #$40
        beq @b
        ldx #2                  ; red
@b      txa
        eor $d020               ; (it reads back with bits 4-7 set)
        and #15
        beq @x
        stx $d020
@x      rts

; ------------------------------------------------------------
; steer  the joystick in port 2: left and right move the balloon, fire
; lifts it; with no fire it sinks, a line every fourth tick
; ------------------------------------------------------------
steer   lda $dc00               ; port 2: a bit 0 when pressed: 0 up,
        lsr a                   ; 1 down, 2 left, 3 right, 4 fire
        lsr a
        lsr a                   ; (left into the carry)
        bcs @nl
        ldx bx+1                ; left: to x 24 at least
        bne @l
        ldx bx
        cpx #25
        bcc @nl
@l      ldx bx
        bne @l2
        dec bx+1
@l2     dec bx
@nl     lsr a                   ; (right into the carry)
        bcs @nr
        ldx bx+1                ; right: to x 320 at most
        beq @r
        ldx bx
        cpx #<320
        bcs @nr
@r      inc bx
        bne @nr
        inc bx+1
@nr     lsr a                   ; (fire into the carry)
        bcs @sink
        lda by                  ; fire: up a line, to 50 at most
        cmp #51
        bcc @x
        dec by
        rts
@sink   lda tick                ; no fire: down a line every 4th tick, to
        and #3                  ; 200 at least
        bne @x
        lda by
        cmp #200
        bcs @x
        inc by
@x      rts

; place  sprite 0 at bx, by: x's low 8 bits in $d000, its ninth in
; $d010's bit 0
place   lda bx
        sta $d000
        lda bx+1
        sta $d010
        lda by
        sta $d001
        rts

; ------------------------------------------------------------
; burner  with no tune, the burner roars while fire is held: voice 3,
; noise, its gate on at the press and off at the release
; ------------------------------------------------------------
burner  lda $dc00
        and #$10                ; 0: fire held
        cmp fired
        beq @x                  ; no change
        sta fired
        ldx song                ; a tune: the SID is the tune's
        inx
        bne @x
        tax
        bne @off
        lda #$00                ; pressed: a low noise, at once, held
        sta $d40e
        lda #$08
        sta $d40f
        lda #$00                ; attack 0, decay 0
        sta $d413
        lda #$f9                ; sustain 15, release 9
        sta $d414
        lda #$81                ; noise, the gate on
        sta $d412
        rts
@off    lda #$80                ; let go: the gate off (the release fades it)
        sta $d412
@x      rts

; ------------------------------------------------------------
; plot  a pixel on: x px (0-319), y py (0-199)
;   uses: a, x, y, ptr
; ------------------------------------------------------------
plot    lda py                  ; its cell row (y / 8): the row's place
        lsr a
        lsr a
        lsr a
        tay
        lda rowlo,y
        sta ptr
        lda rowhi,y
        sta ptr+1
        lda px                  ; + its cell's 8 bytes (x less x's low 3
        and #$f8                ; bits)
        clc
        adc ptr
        sta ptr
        lda px+1
        adc ptr+1
        sta ptr+1
        lda px                  ; its bit: x's low 3 bits, from the left
        and #7
        tax
        lda py                  ; its line in the cell: y's low 3 bits
        and #7
        tay
        lda bits,x
        ora (ptr),y
        sta (ptr),y
        rts
bits    byte $80,$40,$20,$10,$08,$04,$02,$01
rowlo   byte <bitmap,<bitmap+320,<bitmap+640,<bitmap+960,<bitmap+1280
        byte <bitmap+1600,<bitmap+1920,<bitmap+2240,<bitmap+2560,<bitmap+2880
        byte <bitmap+3200,<bitmap+3520,<bitmap+3840,<bitmap+4160,<bitmap+4480
        byte <bitmap+4800,<bitmap+5120,<bitmap+5440,<bitmap+5760,<bitmap+6080
        byte <bitmap+6400,<bitmap+6720,<bitmap+7040,<bitmap+7360,<bitmap+7680
rowhi   byte >bitmap,>bitmap+320,>bitmap+640,>bitmap+960,>bitmap+1280
        byte >bitmap+1600,>bitmap+1920,>bitmap+2240,>bitmap+2560,>bitmap+2880
        byte >bitmap+3200,>bitmap+3520,>bitmap+3840,>bitmap+4160,>bitmap+4480
        byte >bitmap+4800,>bitmap+5120,>bitmap+5440,>bitmap+5760,>bitmap+6080
        byte >bitmap+6400,>bitmap+6720,>bitmap+7040,>bitmap+7360,>bitmap+7680

; ------------------------------------------------------------
; hills  each column x, from its hill's top down to line 167: a top
; between 144 and 160, up and down every 128 pixels
; ------------------------------------------------------------
hills   lda #0
        sta px
        sta px+1
@col    lda px                  ; (x mod 128) - 64, made positive: 0-64
        and #127
        sec
        sbc #64
        bcs @pos
        eor #$ff
        adc #1
@pos    lsr a                   ; a quarter: 0-16
        lsr a
        clc
        adc #144
        sta py
@line   jsr plot
        inc py
        lda py
        cmp #168
        bcc @line
        inc px                  ; the next column, to 319
        bne @nx
        inc px+1
@nx     lda px+1
        beq @col
        lda px
        cmp #<320
        bcc @col
        rts

; ------------------------------------------------------------
; field  rows 21-24 (lines 168-199) a field of grass: two patterns,
; turn about, line by line (1,280 bytes)
; ------------------------------------------------------------
field   lda #<fieldat
        sta ptr
        lda #>fieldat
        sta ptr+1
        ldx #5                  ; 5 pages: 1,280 bytes
        ldy #0
@f      tya                     ; even lines one pattern, odd the other
        and #1
        beq @e
        lda #%00100010
        bne @s
@e      lda #%10001000
@s      sta (ptr),y
        iny
        bne @f
        inc ptr+1
        dex
        bne @f
        rts

; ------------------------------------------------------------
; words  HELLO WORLD from the font below into the bitmap: each letter's
; 8 bytes into a cell's 8, a cell after another
; ------------------------------------------------------------
words   lda #<textat
        sta ptr
        lda #>textat
        sta ptr+1
        ldx #0                  ; the letter
@ch     lda hello,x
        bmi @x                  ; ($ff: the end)
        asl a                   ; its glyph: 8 bytes a letter
        asl a
        asl a
        stx keepx
        tax
        ldy #0
@b      lda font,x
        sta (ptr),y
        inx
        iny
        cpy #8
        bne @b
        lda ptr                 ; the next cell: 8 bytes on
        clc
        adc #8
        sta ptr
        bcc @n
        inc ptr+1
@n      ldx keepx
        inx
        bne @ch
@x      rts
hello   byte 0,1,2,2,3,7,4,3,5,2,6,$ff  ; H E L L O _ W O R L D

; ------------------------------------------------------------
; bar0  the empty loading bar: 32 cells, a line along each one's top
; and bottom; bar  each tick, a cell filled for each 8 of ld_progress
; ------------------------------------------------------------
bar0    ldx #0
        lda #$ff
@c      sta barat,x             ; byte 0 of a cell: its top line
        sta barat+7,x           ; byte 7: its bottom line
        txa
        clc
        adc #8
        tax
        lda #$ff
        cpx #0                  ; (32 cells: 256 bytes)
        bne @c
        rts

bar     lda ld_progress         ; the cells it should show: progress / 8
        lsr a
        lsr a
        lsr a
        cmp cells
        bcc @x                  ; (as many already)
        beq @x
        lda cells               ; the next one filled: bytes 1-6 of its 8
        asl a
        asl a
        asl a
        tax
        lda #$ff
        sta barat+1,x
        sta barat+2,x
        sta barat+3,x
        sta barat+4,x
        sta barat+5,x
        sta barat+6,x
        inc cells
@x      rts

; ------------------------------------------------------------
; the font: a letter's 8 lines, top first, a pixel a bit
; ------------------------------------------------------------
font    byte %01100110          ; 0 H
        byte %01100110
        byte %01100110
        byte %01111110
        byte %01100110
        byte %01100110
        byte %01100110
        byte %00000000
        byte %01111110          ; 1 E
        byte %01100000
        byte %01100000
        byte %01111100
        byte %01100000
        byte %01100000
        byte %01111110
        byte %00000000
        byte %01100000          ; 2 L
        byte %01100000
        byte %01100000
        byte %01100000
        byte %01100000
        byte %01100000
        byte %01111110
        byte %00000000
        byte %00111100          ; 3 O
        byte %01100110
        byte %01100110
        byte %01100110
        byte %01100110
        byte %01100110
        byte %00111100
        byte %00000000
        byte %01100011          ; 4 W
        byte %01100011
        byte %01100011
        byte %01101011
        byte %01111111
        byte %01110111
        byte %01100011
        byte %00000000
        byte %01111100          ; 5 R
        byte %01100110
        byte %01100110
        byte %01111100
        byte %01111000
        byte %01101100
        byte %01100110
        byte %00000000
        byte %01111000          ; 6 D
        byte %01101100
        byte %01100110
        byte %01100110
        byte %01100110
        byte %01101100
        byte %01111000
        byte %00000000
        byte %00000000          ; 7 a space
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000

; ------------------------------------------------------------
; the balloon: 21 rows of 24 pixels, 3 bytes a row, a pixel a bit
; (63 bytes, on a 64-byte boundary in the bank)
; ------------------------------------------------------------
*=shape
        byte %00000000,%11111111,%00000000
        byte %00000111,%10111101,%11100000
        byte %00011111,%01111110,%11111000
        byte %00111110,%11111111,%01111100
        byte %01111110,%11111111,%01111110
        byte %01111101,%11111111,%10111110
        byte %11111101,%11111111,%10111111
        byte %11111101,%11111111,%10111111
        byte %11111101,%11111111,%10111111
        byte %01111101,%11111111,%10111110
        byte %01111110,%11111111,%01111110
        byte %00111110,%11111111,%01111100
        byte %00011111,%01111110,%11111000
        byte %00001111,%10111101,%11110000
        byte %00000011,%11011011,%11000000
        byte %00000001,%00000000,%10000000
        byte %00000000,%10000001,%00000000
        byte %00000000,%01000010,%00000000
        byte %00000000,%01111110,%00000000
        byte %00000000,%01111110,%00000000
        byte %00000000,%00111100,%00000000
