# Your first loader module, by hand

This guide writes a loader module from nothing: **Hello-Load**, a red
hot-air balloon drifting over green hills under the words HELLO WORLD,
with a loading bar along the top. You steer it with a joystick in port 2
while the program loads from tape; fire lights the burner, and the
balloon rises with a roar. Its source is `modules/hello/hello.asm`, about
600 lines; every instruction is below, and the rows of data (the font,
the balloon) as they first come.

It uses nothing but the 6502 and the C64's chips: no kit, no include
files. Along the way it covers the four things most modules need:

- **the header and the three calls**: how the loader finds the module
  and runs it;
- **text**: letters of the module's own, drawn into the picture;
- **sprites and sound**: the balloon, and the burner on the SID;
- **bitmap graphics**: a 320 x 200 picture, a pixel at a time.

`LMFORMAT.md` is the reference for the module's file, byte by byte, and
`MODULES.md` the full standard and the kit the demo modules share. Read
this first.

## What you need

- The SlopLoad folder, with Python 3 (it builds and masters tapes).
- An assembler that reads CBM prg Studio's syntax. `tools/build.py`
  uses `tools/asm6502.py`, which reads exactly that, so the source
  also builds in prg Studio. (Another assembler, or no PC at all, only
  a C64: "With any assembler, or on a C64 alone", near the end.)
- VICE (`x64sc`), to try it.
- Some 6502: what `lda`, `sta`, `ldx`, `inx`, `bne`, `jsr` and `rts` do,
  and that a `#` means a number rather than an address. Everything else
  is explained as it comes.

The syntax, briefly: a label starts in the first column; everything
else is indented; `;` starts a comment; `$` is hex, `%` binary; `<x`
and `>x` are the low and high bytes of `x`; `@name` is a label local to
the last label without an `@`; `name = value` names a number; `*=`
sets the address the following bytes go to; `byte` and `word` put bytes
and two-byte words (low byte first) into memory.

## How the loader runs a module

A SlopLoad tape loads in four steps, and the module has a place in each:

1. **The KERNAL's file.** The C64 loads a short file the ordinary way
   (LOAD, or SHIFT and RUN/STOP). It holds stage 1, which loads the
   rest at turbo speed.
2. **The core.** Stage 1 loads the loader's core to $0400-$07FF and
   starts it. From here on an interrupt reads the tape, a pulse at a
   time, whatever else is running. The screen is off.
3. **The module.** The core loads the module's parts first, to where
   they belong (Hello-Load's one part to $C000), then calls the
   module's **init** once, with the screen still off. From then on it
   calls the module's **frame** over and over, once a frame, while its
   interrupt goes on loading. The module learns how far the load has got
   from two bytes the core keeps in zero page: `ld_progress` ($03, 0 to
   255) and `ld_state` ($02: bit 7 set when the program is in, bit 6
   during a tape error).
4. **The program.** When the program is in, the module's frame returns
   with the carry flag set ("I'm done"). The core calls the module's
   **stop** once, blanks the screen and starts the program.

So a module is three routines and the 32 bytes that say where they
are: the header. The rest is what makes it yours.

The core's interrupt has to come in on time for every pulse, so a module
lives by a few rules (`MODULES.md` has them all):

- never `sei` (interrupts off), never raster interrupts, never write
  `$01`, the CIAs' timers or interrupt bits, or $FFFA-$FFFF;
- at most two sprites on any raster line;
- read `ld_state` and `ld_progress`, never write them;
- stay in your own memory: zero page $10-$8F, and VIC bank 3
  ($C000-$FFF9) but for the I/O at $D000-$DFFF.

## The file, step by step

### Where everything is

```
mb      = $c000                 ; bank 3 (tools/build.py: $8000, bank 2, to
                                ; find what moves when a chain moves it)
```

`mb` names the start of the module's VIC bank: the 16 KB of memory the
graphics chip (the VIC-II) can see at once. The C64 has four such banks;
SlopLoad modules live in bank 3, $C000-$FFFF. Every address of the
module's own below is written from `mb`, and that matters: when two
modules share a tape (a chain), the tools may move one of them to bank
2, $8000-$BFFF. `tools/build.py` assembles the module twice, once with
`mb = $c000` and once with `mb = $8000`, and the bytes that come out
different are the ones the tools change to move it. An address written
as a plain number would be missed.

```
screen  = mb+$0c00              ; the bitmap's colours: a byte for each cell
sprptr  = screen+$03f8          ; sprite 0's pointer, after the 1,000 cells
shape   = mb+$0a00              ; the balloon's 63 bytes
bitmap  = mb+$2000              ; 8,000 bytes: 320 x 200 pixels
textat  = bitmap+3*320+14*8     ; HELLO WORLD: cell row 3, column 14
barat   = bitmap+1*320+4*8      ; the loading bar: cell row 1, columns 4-35
fieldat = bitmap+21*320         ; the field: cell rows 21-24
```

The map of the module, all inside the bank:

| where | what |
|---|---|
| `mb`+$0000 | the header, the code and the data (to about +$0A00) |
| `mb`+$0A00 | the balloon's shape (a sprite: 63 bytes) |
| `mb`+$0C00 | the screen: in bitmap mode, the colours of each 8 x 8 cell |
| `mb`+$0FF8 | the sprite pointers: where the VIC finds the shape |
| `mb`+$2000 | the bitmap: 8,000 bytes |

The VIC wants the screen at a multiple of $0400 in the bank, the bitmap
at +$0000 or +$2000, and a sprite's shape at a multiple of 64. `textat`,
`barat` and `fieldat` are places in the bitmap, worked out below ("The
bitmap").

### The loader's two bytes, and our zero page

```
ld_state = $02                  ; bit 7 loaded, bit 6 a tape error, bit 5
                                ; the border is the loader's, bit 0 NTSC
ld_progress = $03               ; how much is in: 0-255
```

The core's two bytes. Bit 5 of `ld_state` is set when the tape was made
with the loading lines on through the module (`-showstripes`): the
border is then the loader's to colour. Bit 0 says the C64 is an NTSC
one (60 frames a second rather than PAL's 50).

```
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
```

The module's variables, in zero page ($10-$8F is ours). Zero page is
quicker to use, and only there can a pair of bytes be a pointer:
`lda (ptr),y` reads from the address in `ptr` and `ptr+1`, plus Y.

### The header

```
*=mb
        byte $50,$4c,$47,$31    ; +0  "PLG1": a SlopLoad module, version 1
```

`*=mb` puts what follows at $C000, the module's first byte. The header
comes first: the tools find it there. Its first four bytes are the
letters PLG1, which mark the file as a SlopLoad module.

```
        word init               ; +4  called once, the screen off
        word frame              ; +6  called every frame
        word stop               ; +8  called once, at the end
```

The three calls' addresses. `word` writes each as two bytes, low byte
first, as the 6502 wants them. The core reads them from here and calls
each with `jsr`.

```
        word mb+$3f40           ; +10 the end of its memory: the bitmap's end
```

Where the module's memory ends. The tools keep everything else out of
$C000 up to here while the module runs: the tune goes elsewhere, and any
of the program that would load here loads after the module has stopped.

```
        byte 56                 ; +12 its jitter: 48, and 8 for a sprite
```

How late the module can make the loader's interrupt, in cycles: 48 for
an ordinary module, and 8 more for each sprite on a line (the VIC takes
cycles from the CPU to fetch a sprite). The tools use it to choose how
fast the tape can be. `tests/jitter.py` measures a module's own.

```
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
```

The rest of the 32 bytes. Most of them are filled in by the mastering
tool on the copy it writes to tape, so here they are just room: if the
tape has a tune, the tool writes the song's number into +13 and the
tune's two routines into +16 and +18. Three get labels (`song`,
`tinit`, `tplay`, `opts`) because the code reads them. +14 asks for a
share of the CPU for the loader: 0 means the usual 35%. +27 says which
of the tool's options the module keeps (none, here: so `-wait` and
`-countdown` are refused for it).

### init: the VIC's bank

```
init    lda $dd02               ; the VIC's bank: CIA 2's port A, bits 0-1
        ora #3                  ; as outputs
        sta $dd02
```

The VIC's bank is chosen by two bits of a port on the second CIA chip,
$DD00. `$DD02` says which of that port's bits are outputs: `ora #3`
sets bits 0 and 1 without touching the others, and `sta` writes it back.

```
        lda #>init              ; our own page: $c0-$cf, or $80-$8f moved
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a                   ; its top two bits: the bank, 3 or 2
        eor #3                  ; $dd00's bits for it: 0 or 1
        sta ptr
```

Which bank are we in? Ask where our own code is. `#>init` is the high
byte of `init`'s address: $C0 in bank 3, or $80 if the tools moved the
module to bank 2. Each `lsr a` shifts A one bit right; after six, only
the top two bits are left: 3 for $C0, 2 for $80, the bank's number.
$DD00 wants it upside down (0 means bank 3, 1 bank 2), and `eor #3`
flips both bits. `sta ptr` keeps it a moment.

```
        lda $dd00
        and #$fc
        ora ptr
        sta $dd00
```

$DD00's other bits belong to the disk drive's lines, so change only
bits 0 and 1: `and #$fc` clears them, `ora ptr` puts ours in.

### init: the screen mode

```
        lda #$0b                ; the screen off
        sta $d011
```

$D011 is the VIC's control register. $0B is 25 rows, the screen off
(bit 4 clear), no bitmap yet. The screen stays off until the picture
is ready; `frame` turns it on.

```
        lda #$38                ; colours at bank+$0c00, bitmap at bank+$2000
        sta $d018
```

$D018 says where in the bank the VIC finds things. The top four bits
are the screen's place in 1 KB steps ($3: +$0C00); in bitmap mode, bit
3 is the bitmap's half of the bank (set: +$2000). $30 + $08 = $38.

```
        lda #$08                ; hires, 40 columns
        sta $d016
```

$D016: 40 columns, no fine scroll, and bit 4 clear, so the bitmap is
hires (a pixel a bit, two colours to each cell) rather than multicolour.

### The bitmap

A hires bitmap is 320 x 200 pixels, one bit each: 8,000 bytes. It is
laid out in 8 x 8 cells, as the text screen is: 40 cells across, 25
down. Each cell is 8 bytes in a row, one byte for each of its 8 lines,
the leftmost pixel in bit 7. So the byte holding pixel (x, y) is

    bitmap + (y / 8) * 320 + (x / 8) * 8 + (y and 7)

(320 bytes to a row of cells: 40 cells of 8), and its bit is
`$80 >> (x and 7)`. Each cell takes its two colours from its byte on
the screen: the high four bits for the pixels that are set, the low
four for the rest.

```
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
```

First, every pixel off. `ptr` points at the bitmap; `sta (ptr),y`
stores A (0) at `ptr` + Y. Y counts 0 to 255 and back to 0 (`iny`, and
`bne` loops until it wraps), which fills a page of 256 bytes; then
`inc ptr+1` moves `ptr` a page on, and X counts 31 pages down. That is
7,936 bytes; the last 64 (Y from 63 down to 0: `bpl` loops while Y is
0 or more) make 8,000. Clearing 32 whole pages would run on to $FFFF,
over the loader's vectors.

```
        ldx #0                  ; every cell sky: white on light blue
        lda #$1e
@sky    sta screen,x
        sta screen+250,x
        sta screen+500,x
        sta screen+750,x
        inx
        cpx #250
        bne @sky
```

Every cell's colours: $1E is 1 (white) in the high four bits, for the
pixels that are set (the letters, the bar), and 14 (light blue) in the
low four, for the sky. The screen is 1,000 bytes, more than X can
count, so each pass of the loop stores four, a quarter of the screen
apart.

```
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
```

Then the land: the cells of rows 18-20 (3 rows of 40: 120 cells) green
pixels on the sky's light blue, so the hills drawn there are green; and
rows 21-24 (160 cells) light green on green, for the grass. The first
loop counts X from 119 down to 0 and stops when it goes below 0
(`bpl`, "branch if plus", loops while bit 7 of X is clear). That can't
count from 160: 160 has bit 7 set, so `bpl` would stop at once. The
second loop counts from 160 down to 1 instead (`bne` loops until X is
0) and stores one cell earlier (`-1`).

```
        jsr field               ; the picture: the field, the hills, the
        jsr hills               ; words, the empty bar
        jsr words
        jsr bar0
```

The picture itself, in four routines, each below.

#### Plotting a pixel

```
plot    lda py                  ; its cell row (y / 8): the row's place
        lsr a
        lsr a
        lsr a
        tay
        lda rowlo,y
        sta ptr
        lda rowhi,y
        sta ptr+1
```

`plot` sets the pixel at (`px`, `py`). Three `lsr`s divide `py` by 8:
the row of cells. Multiplying by 320 is slow on a 6502, so two tables
hold the answer for each row: `rowlo` and `rowhi`, the low and high
bytes of `bitmap` + row x 320. Y picks the row's entry, and `ptr`
points at the row's first byte.

```
        lda px                  ; + its cell's 8 bytes (x less x's low 3
        and #$f8                ; bits)
        clc
        adc ptr
        sta ptr
        lda px+1
        adc ptr+1
        sta ptr+1
```

Then the cell along the row. (x / 8) * 8 is x with its low three bits
cleared: `and #$f8`. Adding a 16-bit number is two `adc`s: the low
bytes first (`clc` before, so no carry is added in), then the high
bytes, which add in the carry from the first.

```
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
```

The pixel's bit is x's low three bits counted from the left, so X picks
it from `bits`; the line in the cell is y's low three bits, and Y adds
it to `ptr`. `ora` sets that bit in the byte, leaving its other pixels
as they were, and `sta` writes it back.

```
rowlo   byte <bitmap,<bitmap+320,<bitmap+640,<bitmap+960,<bitmap+1280
        ...
rowhi   byte >bitmap,>bitmap+320,>bitmap+640,>bitmap+960,>bitmap+1280
        ...
```

The two tables: 25 rows each. `<bitmap+320` is the low byte of
bitmap + 320. The high bytes in `rowhi` are addresses of ours, so they
move with the module; the low bytes don't change when it moves.

#### The hills

```
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
```

For each column x from 0 to 319, the hill's top. `and #127` gives x's
place in each 128 pixels; less 64 that runs from -64 up to 63. `sbc`
(with `sec` first, so nothing extra is taken off) leaves the carry
clear when the answer went below 0, and then `eor #$ff` and `adc #1`
turn it positive (two's complement: flip the bits and add one; the
carry is clear there, so `adc #1` adds just 1). The distance from the
middle, 0 to 64, divided by 4 (two `lsr`s) and added to 144 gives a
top between 144 and 160: up and down, every 128 pixels.

```
@line   jsr plot
        inc py
        lda py
        cmp #168
        bcc @line
```

A line down from the top to line 167, the field's edge. `cmp` sets the
carry when A is 168 or more, so `bcc` ("carry clear") loops while it is
less.

```
        inc px                  ; the next column, to 319
        bne @nx
        inc px+1
@nx     lda px+1
        beq @col
        lda px
        cmp #<320
        bcc @col
        rts
```

`px` is 16 bits (320 doesn't fit in a byte): `inc px` and, when it
wraps to 0, `inc px+1`. While the high byte is 0 (x under 256) go on;
past that, go on while the low byte is under 64 (`<320`: 320 is
$0140).

#### The field

```
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
```

Rows 21 to 24 of cells, 4 x 320 = 1,280 bytes, straight into the
bitmap, five pages of it. Each byte is one line of 8 pixels; within a
cell, the byte's place counts its line, so Y's lowest bit says whether
the line is even or odd. Even lines get %10001000, odd ones %00100010:
light green dots, staggered, on the cells' green. Writing whole bytes
is far quicker than plotting each pixel, when the pattern allows it.
(`bne @s` after loading a number that isn't 0 always branches: a short
jump.)

### Text

A module in bank 3 can't use the C64's own letters: the VIC sees the
character ROM only in banks 0 and 2, and the module isn't allowed to
switch the ROM in for the CPU to copy it (that means writing $01). So
Hello-Load brings its own, eight of them, at the end of the source:

```
font    byte %01100110          ; 0 H
        byte %01100110
        byte %01100110
        byte %01111110
        byte %01100110
        byte %01100110
        byte %01100110
        byte %00000000
        byte %01111110          ; 1 E
        ...
```

A letter is 8 bytes, its 8 lines from the top, a pixel a bit, the same
shape as a bitmap cell. Written in binary you can see it. H is letter
0, E 1, L 2, O 3, W 4, R 5, D 6, and 7 is a space (all 0).

```
words   lda #<textat
        sta ptr
        lda #>textat
        sta ptr+1
        ldx #0                  ; the letter
@ch     lda hello,x
        bmi @x                  ; ($ff: the end)
```

`ptr` starts at `textat`, row 3's cell 14 (bitmap + 3 x 320 + 14 x 8:
HELLO WORLD is 11 letters, about the middle of 40). `hello` is the
message as letter numbers; X goes through it. $FF ends it: `bmi`
branches when bit 7 is set, as it is for $FF and for none of the
letters.

```
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
```

Three `asl`s multiply the letter's number by 8: its first byte in
`font`. X is needed for that, so the place in the message is kept in
`keepx`. Then 8 bytes from the font to the cell, X going through the
font and Y through the cell.

```
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
```

The next cell is 8 bytes on: add 8 to `ptr`, and carry into its high
byte if the low one went past 255. Then the next letter.

Text on a character screen is simpler (a byte a letter), but the VIC
shows a character screen or a bitmap, not both. To write more, add
letters to `font` and their numbers to a message.

### The loading bar

```
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
```

The empty bar: 32 cells of row 1 (from column 4), each with its top and
bottom lines set ($FF is all 8 pixels). X steps 8 bytes a cell; after
32 cells it has gone round to 0 and the loop ends. A held $FF, but `txa`
put X in it, so it is loaded again.

```
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
```

Each tick: `ld_progress` (0-255) divided by 8 is how many cells should
be full (0-31). If `cells` is behind, fill the next one, its six inner
lines. One cell a tick at most, so the drawing is short.

### The balloon: a sprite

A sprite is a 24 x 21 picture the VIC draws over the screen, anywhere,
without the CPU drawing it: 63 bytes, 3 to a line, a pixel a bit.

```
*=shape
        byte %00000000,%11111111,%00000000
        byte %00000111,%10111101,%11100000
        byte %00011111,%01111110,%11111000
        ...
        byte %00000000,%01111110,%00000000
        byte %00000000,%00111100,%00000000
```

At the end of the source, `*=shape` moves the assembler on to
`mb`+$0A00, a multiple of 64, and the balloon is drawn in binary, line
by line: the envelope with its seams (the 0s inside it), the ropes,
the basket.

```
        lda #<160               ; the balloon: the middle, high up
        sta bx
        lda #>160
        sta bx+1
        lda #80
        sta by
```

In `init`, its place. A sprite's x runs from 24 (the screen's left
edge) to 343, which needs 9 bits, so `bx` is two bytes; y runs from 50
(the top) to 249.

```
        lda #(shape-mb)/64      ; its shape's place in the bank, in 64s
        sta sprptr
```

The VIC finds each sprite's shape from its pointer, a byte in the last
8 of the screen's 1 KB: the shape's place in the bank divided by 64
($0A00 / 64 = 40). It is a place in the bank, not an address, so it is
the same whichever bank the module is in.

```
        lda #2                  ; red
        sta $d027
        lda #0                  ; one colour, normal size
        sta $d01c
        sta $d017
        sta $d01d
        lda #1                  ; sprite 0 on
        sta $d015
        jsr place
```

Sprite 0's colour ($D027: red), not multicolour ($D01C), not stretched
down or across ($D017, $D01D), and on ($D015: a bit for each sprite).

```
place   lda bx
        sta $d000
        lda bx+1
        sta $d010
        lda by
        sta $d001
        rts
```

Sprite 0's x is $D000, its y $D001. The ninth bit of every sprite's x
is in $D010, sprite 0's in bit 0, which is just `bx+1` (0 or 1).

### Sound

The SID chip has three voices. With a tune on the tape, the tune has
them; with none, Hello-Load makes the burner's roar on voice 3.

```
        lda #0
        sta tick
        sta nframe
        sta cells
        lda #$10
        sta fired
        lda song                ; a tune on the tape?
        cmp #$ff
        beq @quiet
```

The rest of `init` sets the counters to 0, says fire isn't held (`fired`
is $10 when it is up, as the joystick port reads it), and looks at the
header's +13: $FF is no tune.

```
@quiet  ldx #$18                ; no tune: the SID ours, silent, loud
        lda #0
@sid    sta $d400,x
        dex
        bpl @sid
        lda #15
        sta $d418
        rts
```

No tune: all 25 SID registers ($D400-$D418) to 0, then the volume
($D418's low four bits) up full.

```
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
```

Each tick: fire is bit 4 of $DC00, 0 while held. Only a change matters
(pressed, or let go): if it's what it was last tick, nothing to do.
Then, a tune on the tape? `song` + 1 is 0 only for $FF (`inx` on $FF
wraps to 0), so with a tune, stop here: the SID isn't ours. Last, A
($00 or $10) says which change it was.

```
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
```

Voice 3's registers are $D40E-$D414. Its frequency ($D40E low, $D40F
high: $0800, a low rumble for noise); its envelope: $D413 the attack
(how quickly it gets loud: 0, at once) and decay, $D414 the sustain (how
loud it stays while held: 15, the most) and release (how slowly it
fades once let go: 9, about three quarters of a second); and $D412,
the waveform and gate: $80 is noise, and bit 0, the gate, starts the
sound. Let go, the gate goes off and the release fades it out.

### The tune from the tape

```
        lda opts                ; playing already (a chain's second, or the
        and #$10                ; music first): it plays on
        bne @x
        lda song                ; else started: A the song
        jsr tuneinit
@x      rts
...
tuneinit jmp (tinit)            ; (jsr here: the tune's own rts comes back)
tuneplay jmp (tplay)
```

With a tune, start it: its init routine, with A the song's number. The
tool may have started it already (+28 bit 4: a chain's second module, or
the music first, playing while the module loaded), and then it plays on.
The tool wrote the tune's two addresses into the header, so we call
them through it: `jmp (tinit)` jumps to the address held at `tinit`.
There is no `jsr (...)` on the 6502, so `jsr tuneinit` calls a `jmp`
that goes on to the tune; the tune's own `rts` comes back to us.

### frame: the vertical blank

```
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
```

The core calls `frame` again as soon as it returns, so `frame` paces
itself: it waits for the vertical blank, the lines below the picture
(251 on), where it can change the screen without the beam drawing a
half-changed picture. $D012 is the raster line the beam is on, its
ninth bit bit 7 of $D011 (`bit $d011` puts that in the N flag, so `bmi`
branches when it is set). First wait for the beam to be back in the
picture (a line under 251, and the ninth bit clear), then for it to
reach line 251 again. Waiting for line 251 alone isn't enough: a short
frame would come round again in the same blank.

```
@vb     lda #$3b                ; the bitmap, the screen on
        sta $d011
        jsr place               ; the balloon where the last tick put it
        jsr border
```

In the blank: $3B is $0B with bit 5 (bitmap mode) and bit 4 (the
screen on). Then the balloon to its place, and the border.

```
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
```

An NTSC C64 has 60 frames a second to PAL's 50. So that the balloon and
the tune go at the same speed on both, an NTSC frame skips the module's
work one frame in six: 5 ticks in 6 frames, 50 a second. `lsr a` moves
`ld_state`'s bit 0 (NTSC) into the carry.

```
@tick   inc tick
        lda song
        cmp #$ff
        beq @nt
        jsr tuneplay            ; the tune, once a tick
@nt     jsr steer
        jsr burner
        jsr bar
```

A tick: the tune's play routine (once a tick, 50 times a second), the
joystick, the burner, the bar.

```
@end    lda ld_state            ; bit 7, loaded, into the carry: the program
        asl a                   ; starts
        rts
```

The end of every frame: `asl a` shifts `ld_state`'s bit 7 (the program
is in) into the carry, and the carry is what the core reads. Clear,
the core calls `frame` again; set, the module is done.

### The border, and the joystick

```
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
```

The border ($D020) black, or red while the tape has an error (bit 6:
rewind a little and press PLAY; the loader picks up again). Not at all
while bit 5 is set: then it's the loader's. Only write it when it
changes: on newer C64s each write of a colour register shows a grey dot
for a pixel. `eor` compares the colour with the register's (which reads
back with its unused top bits set: `and #15` drops them).

```
steer   lda $dc00               ; port 2: a bit 0 when pressed: 0 up,
        lsr a                   ; 1 down, 2 left, 3 right, 4 fire
        lsr a
        lsr a                   ; (left into the carry)
        bcs @nl
```

$DC00 is joystick port 2: a bit for each direction and fire, 0 while
held. Shifting right moves the bits one at a time into the carry: after
three, the carry is left's bit, and `bcs` skips when it's 1 (not held).

```
        ldx bx+1                ; left: to x 24 at least
        bne @l
        ldx bx
        cpx #25
        bcc @nl
@l      ldx bx
        bne @l2
        dec bx+1
@l2     dec bx
```

Left: if `bx` is 256 or more (its high byte not 0) there's room; else
only if it is 25 or more. Taking 1 from a 16-bit number: if the low
byte is 0 it is about to wrap to 255, so take 1 from the high byte
first. X does the comparing, so A keeps the joystick's bits.

```
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
```

Right, the same the other way: under 256 there's room; past it, only
under 320. Adding 1: if the low byte wraps to 0, add 1 to the high.

```
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
```

Up and down are skipped (the fourth shift reads right, the fifth fire).
Fire held: up a line a tick, to line 50, the top. Not held: it sinks, a
line every fourth tick (`tick` and 3 is 0 one tick in four), down to
200.

### stop

```
stop    ldx #$18
        lda #0
@s      sta $d400,x
        dex
        bpl @s
        rts
```

Once, at the end: the SID silent. The core blanks the screen and starts
the program.

## Build it

```bash
python3 tools/build.py
```

`tools/build.py` builds every module in `modules/`, this one from
`modules/hello/hello.asm`. It prints:

```
module hello    $C000-$CA3E  2623 bytes
     (moves)  73 relocations, a bank down $8000
```

and writes `build/modules/hello.lm`: the module's file. It holds the
module's bytes (the header first) and its relocations: the 73 bytes
that differed between the build at `mb = $c000` and the one at `mb =
$8000`, the high bytes of every address of ours. It also sets bit 7 of
the header's +27 in the file, which says the list is there. With them, the tools
can move Hello-Load to bank 2 when it shares a tape with another
module in bank 3, and it runs there unchanged: its own address tells
`init` which bank to use.

## Master a tape, and play it

Any program will do; `tests/mktest.py` makes one that checks itself:

```bash
python3 tests/mktest.py mytest.prg 0x3f00
python3 tools/slopload.py mytest.prg hello.tap -module build/modules/hello.lm
x64sc -autostart hello.tap
```

With a tune: add `-sid music/build/slopload.sid`. The burner is then
quiet (the tune has the SID). As the first of two (it moves a bank
down to make room for the second):

```bash
python3 tools/slopload.py mytest.prg hello.tap -module build/modules/hello.lm -then build/modules/crossy.lm
```

On a C64, `hello-load.lm` is on SlopLoad 64's B side (the second 1541
disk; the .d81 has it too): choose it on line 3 (the module) or line 4
(the second). A `.lm` of your own goes onto any disk with any disk tool.

## Check it

These scripts are in the project's `tests/` folder. A release has only
`tests/mktest.py`: there, playing the tape in VICE is the check.

```bash
python3 tests/loadtest.py hello.tap
python3 tests/jitter.py --module hello
python3 tests/movecheck.py build/modules/hello.lm
python3 tests/movecheck.py build/modules/hello.lm --second
```

The first loads the tape in VICE and passes when the program's own
check does. `jitter.py` measures how late the module makes the loader's
interrupt (the header's +12 must be at least that). `movecheck.py` runs
it moved to bank 2, first and second in a chain, with a joystick that
wanders, and fails if any of its code reads or writes bank 3: an
address of ours written as a number rather than from `mb`.

## With any assembler, or on a C64 alone

Nothing above needs SlopLoad's own build, or a PC. `tools/build.py` does
three things for Hello-Load, and each can be done another way:

| the build | without it |
|---|---|
| assembles the source | any 6502 assembler: CBM prg Studio, or one that runs on the C64 itself |
| writes the `.lm`: the part's address and length in front of its bytes | `tools/prglm.py` on a PC; PRG-LM on a C64 |
| assembles it a second time a bank lower, and lists the bytes that differ: its relocations | the same two: give them both builds |

### All a module needs is in its source

A module calls nothing of the loader's, and includes no file of
SlopLoad's. The loader finds it by its header and calls it. So the
"extra code" a module of your own needs is the 32 bytes of the header,
the three routines it names, and the rules ("How the loader runs a
module"). Here is all of it, as small as it goes: a module that turns
the whole screen a new colour sixteen times as the program comes in.
Type it into any assembler, or copy its header into a program of your
own:

<!-- least.asm -->
```
; least.asm - the least a SlopLoad module can be: the whole screen
; changes colour, black to light grey in 16 steps, as the program loads

mb      = $c000                 ; its VIC bank ($8000: the build a bank lower)
ld_state = $02                  ; the loader's: bit 7 loaded, bit 6 a tape error
ld_progress = $03               ; the loader's: how much is in, 0-255
last    = $10                   ; ours: the colour last written

*=mb
        byte $50,$4c,$47,$31    ; +0  "PLG1"
        word init               ; +4  called once, the screen off
        word frame              ; +6  called once a frame
        word stop               ; +8  called once, at the end
        word mb+$0100           ; +10 the end of our memory
        byte 0                  ; +12 jitter: 0, the usual 48
        byte $ff                ; +13 the tool's: the song
        byte 0,0                ; +14 the loader's share: 0, 35%; +15
        word 0,0,0,0            ; +16 to +23 the tool's: the tune
        byte 0,0,0              ; +24 to +26 the tool's
        byte 0                  ; +27 what it keeps: none of the options
        byte 0,0,0,0            ; +28 the tool's; +29 to +31 spare

init    lda #$ff                ; no colour written yet
        sta last
        rts                     ; (the screen stays off: all border)

frame   lda $d012               ; wait for the frame's blank: the last
        cmp #251                ; one over (lines 0-250) ...
        bcs frame
        bit $d011
        bmi frame
wait    bit $d011               ; ... and this one begun: line 251 on
        bmi blank
        lda $d012
        cmp #251
        bcc wait
blank   lda ld_progress         ; 0-255: its top four bits, a colour
        lsr a
        lsr a
        lsr a
        lsr a
        bit ld_state            ; bit 6 into the V flag: a tape error
        bvc show
        lda #2                  ; ... is red
show    cmp last                ; the border written only when it
        beq done                ; changes
        sta last
        sta $d020
done    lda ld_state            ; bit 7, loaded, into the carry: the
        asl a                   ; program starts
        rts

stop    rts                     ; no sound to silence
```

- The header is Hello-Load's, with our own four addresses in it ("The
  header" above says what each byte is). The zeros are the mastering
  tool's to fill in.
- `init` leaves the screen off, so the border's colour fills the
  picture. A module with a picture sets up its screen here.
- `frame` waits for the bottom of the picture, as Hello-Load's does,
  does a frame's work and returns the carry: set, once `ld_state` says
  the program is in.
- `stop` has nothing to do. A module that made a sound silences it
  here.
- It plays no tune: one on the tape is started in `init` and called
  once a tick ("The tune from the tape").

It uses no local labels (`@name`), so it goes into any assembler with
no more than the respellings below.

### In another assembler

The listings here are in CBM prg Studio's syntax. What changes
elsewhere is small, and your assembler's manual has it:

| here | what it is | elsewhere, often |
|---|---|---|
| `byte 1,2,3` | bytes | `.byte 1,2,3` (Turbo Macro Pro and most C64 assemblers), `!byte` (ACME), `dc.b` |
| `word init` | a two-byte address, low byte first | `.word init`, `!word`, `dc.w` |
| `*=mb` | where the next bytes go | the same nearly everywhere |
| `name = value` | a name for a number | the same |
| `<x`, `>x` | the low and high byte of `x` | the same |
| `@name` | a label local to the last full label | not everywhere: give each a name of its own (`@w0` in `frame` becomes `fw0`) |
| `lsr a` | a shift of A | sometimes plain `lsr` (Turbo Macro Pro takes either) |
| `a+3*320` | a product in a sum | Turbo Macro Pro works a sum out from left to right, `*` no sooner than `+`: write `a+(3*320)` |
| `ld_state` | a name with `_` | the C64's keyboard has no such key: in Turbo Macro Pro it is C= and @, or leave it out of the name |
| a long line | five addresses on a `byte` line, a comment after an instruction | on a C64 a line is often one row of the screen: fewer values on a line, and the comments left out |

Three things to keep whatever the assembler:

- name every zero-page address (`ptr = $10`) before the code that uses
  it, or the assembler may take it for a two-byte address;
- write every address of the module's own from `mb` ("Where everything
  is"), so that the build a bank lower is one changed line;
- assemble to a file on the disk, not into memory: an assembler on a
  C64 often sits where the module goes (Turbo Macro Pro is at
  $8000-$CFFF).

What comes out is a program (a `.prg`): two bytes with its load
address, $C000, then the module.

### From the program to the module's file

**On a PC**, the mastering tool takes the program as it is:

```bash
python3 tools/slopload.py mytest.prg least.tap -module least.prg
```

That is enough to try it. SlopLoad 64 wants a `.lm`, and a module that
can move for a chain needs its relocations in one. `tools/prglm.py`
writes it:

```bash
python3 tools/prglm.py least.lm least.prg -lower least8.prg
```

`least8.prg` is the same source assembled with `mb = $8000`: change
the one line, assemble again under another name. `prglm.py` compares
the two, as `tools/build.py` does: every byte that differs must be $40
less (the high byte of an address written from `mb`), and those are the
relocations. Anything else stops it with the address; the cause is
nearly always an address written as a number, not from `mb`. Left out
(`prglm.py least.lm least.prg`), the `.lm` has no relocations: it loads
and runs as it is, and shares a tape only with a module that keeps out
of its memory or can move out of its way (every demo can). A module of several parts: name each part's program, the main one
first (`prglm.py my.lm main.prg font.prg -lower main8.prg font8.prg`).

**On a C64**, PRG-LM does the same. It is a BASIC program, `prg-lm` on
SlopLoad 64's B side (the second 1541 disk, and the .d81), and its
listing is below. Put your assembler's two programs on a disk, then:

```
LOAD "PRG-LM",8
RUN
```

```
             *** PRG-LM ***
  A PROGRAM (.PRG) TO A LOADER MODULE

DRIVE WITH THE PROGRAM [8]?
ITS FILE NAME ($: FILES)? LEAST.PRG
THE SAME, A VIC BANK LOWER (0: NONE):
DRIVE [0]? 8
ITS FILE NAME ($: FILES)? LEAST8.PRG
ANOTHER PART (0: NO MORE):
DRIVE [0]?
DRIVE FOR THE MODULE [8]?
THE MODULE'S NAME [LEAST.LM]?
READING LEAST.PRG
WRITING LEAST.LM
DONE: 101 BYTES
 4 RELOCATIONS: IT CAN MOVE A BANK
CHOOSE IT IN SLOPLOAD 64: 3, THE MODULE
```

RETURN alone takes what is in the brackets; each file may be on a drive
of its own; `$` at a file's name lists that drive's disk. It writes the
same file as `tools/prglm.py`, byte for byte, and refuses the same
things, in its own words (`NOT $40 LESS (AN ADDRESS NOT FROM MB)`, with
the address). BASIC reads a byte at a time, so it is slow: Hello-Load's
2,623 bytes take just under four minutes on a 1541.

Then SlopLoad 64, on the same C64: line 3, the module (or line 4, the
second), and the tape. Assembler, PRG-LM and SlopLoad 64: no PC
anywhere.

### The whole way on a C64, with Turbo Macro Pro

Tried in VICE with Turbo Macro Pro v1.2 (Style, 2006: its disk is at
turbo.style64.org). Its command key is the back arrow, at the keyboard's
top left.

1. `LOAD"TMP",8,1` and `SYS32768`: its editor.
2. Type the module in, respelt as the table above says. For the least
   module that is `.byte` and `.word`, no comments, and C= and @ for
   the `_` in `ld_state` and `ld_progress`. Hello-Load needs the rest
   as well: a name for each `@` label, brackets in the five sums with
   a product (`textat = bitmap+(3*320)+(14*8)`, `sta
   screen+(18*40),x`), and its tables of addresses split, one or two
   to a line. Or read it in: the B side has both, spelt this way, as
   text files (`LEAST.S` and `HELLO.S`), and back arrow, then E, reads
   a text file in (a SEQ file with a line of source on each line).
3. Back arrow, then 5, assembles to a file: name it `LEAST.PRG`. It
   must say `ERRORS: 0`.
4. Change the first line to `mb = $8000`; back arrow, 5 again:
   `LEAST8.PRG`.
5. Back arrow, then 1, leaves for BASIC. Type `NEW` (BASIC still
   thinks Turbo Macro Pro's own file is its program, and `LOAD` would
   say OUT OF MEMORY), then `LOAD"PRG-LM",8` and `RUN`, and answer as
   above.
6. `SYS32768` goes back to Turbo Macro Pro, the source still there.

Done this way, the least module and Hello-Load (563 lines once respelt)
come out of Turbo Macro Pro byte for byte as `tools/build.py`'s
assembler makes them, and PRG-LM's `.lm` files from them are the same
as the PC's; SlopLoad 64 mastered a tape with the least module's, and
it loaded. `tests/tmproute.py` does all of it but the typing: it puts
the respelt source on the disk as a text file for Turbo Macro Pro to
read in. Other C64 assemblers will differ in their keys and their
spelling; none of them was tried.

### PRG-LM's listing

<!-- prglm.bas -->
```
100 rem prg-lm: a loader module (.lm) from the programs an assembler wrote
110 dim g%(999),pa(3),pn(3),pd(3),qd(3),f$(3),l$(3),ha(31),hb(31)
120 z$=chr$(0):h$="0123456789abcdef"
130 print"{clr}{cyn}             *** {wht}prg-lm{cyn} ***"
140 print"{gry1}  a program (.prg) to a loader module{grn}":print
150 rem what to read: the main part, then up to three more
160 q$="drive with the program":dd=8:gosub 870:if d=0 then end
170 pd(0)=d:f$(0)=n$:np=1:print"the same, a vic bank lower (0: none):"
180 q$="drive":dd=0:gosub 870:qd(0)=d:if d then l$(0)=n$:rl=1
190 if np=4 then 250
200 print"another part (0: no more):":q$="drive":dd=0:gosub 870:if d=0 then 250
210 pd(np)=d:f$(np)=n$:np=np+1:if rl=0 then 190
220 print"the same, a vic bank lower (0: none):"
230 q$="drive":dd=0:gosub 870:qd(np-1)=d:l$(np-1)="":if d then l$(np-1)=n$
240 goto 190
250 o$=f$(0):if right$(o$,4)=".prg" then o$=left$(o$,len(o$)-4)
260 o$=left$(o$,13)+".lm"
270 d$=mid$(str$(pd(0)),2):print"drive for the module [";d$;:input"]";d$
280 od=val(d$):if od<8 or od>30 then 270
290 print"the module's name [";o$;:input"]";o$
300 rem each part read: its length counted, the two builds compared
310 for k=0 to np-1:print"reading ";f$(k):t=0:e$=f$(k):open 15,pd(k),15
320 open 2,pd(k),2,e$+",p,r":input#15,e,m$,x,y:if e>19 then 1130
330 get#2,x$,y$:m$="it can't be read":if st then 1130
340 a=asc(x$+z$)+256*asc(y$+z$):pa(k)=a:lw=0:if l$(k)="" then 410
350 e$=l$(k):open 14,qd(k),15:open 3,qd(k),3,e$+",p,r":input#14,e,m$,x,y
360 if e>19 then 1130
370 get#3,x$,y$:m$="it can't be read":if st then 1130
380 lw=1:b=asc(x$+z$)+256*asc(y$+z$):v=a:if a>=49152 then v=a-16384
390 if b=v then 410
400 gosub 1110:m$="a bank lower, it must load at $"+hx$:goto 1130
410 m$="it moves: it needs a build a bank lower"
420 e$=f$(k):if rl and lw=0 and a>=49152 then 1130
430 n=0:p=-1:if k then 490
440 for i=0 to 31:get#2,x$:s=st:ha(i)=asc(x$+z$):hb(i)=ha(i):if lw=0 then 460
450 get#3,y$:t=st:hb(i)=asc(y$+z$):if x$<>y$ then n=i:gosub 1000
460 if s or t then i=99
470 next:m$="not a module (no plg1 at its start)":n=32
480 if s or t or ha(0)<>80 or ha(1)<>76 or ha(2)<>71 or ha(3)<>49 then 1130
490 if lw=0 then 540
500 for n=n to 65535:get#2,x$:s=st:get#3,y$:t=st:if x$<>y$ then gosub 1000
510 if s=0 and t=0 then next
520 m$="a bank lower, it is not as long":if s<>64 or t<>64 then 1130
530 goto 560
540 for n=n to 65535:get#2,x$:if st=0 then next
550 m$="it can't be read to its end":if st<>64 then 1130
560 close 2:close 3:close 14:close 15:pn(k)=n+1:if rl then g%(ng)=0:ng=ng+1
570 next k:if rl=0 then 670
580 rem its claim (+10) must move with it
590 c=ha(10)+256*ha(11):if c=0 then c=65536
600 if pa(0)+pn(0)>c then c=pa(0)+pn(0)
610 w=c:tp=65536:bb=pa(0):if bb<49152 then 630
620 tp=49152:bb=bb-16384:w=c-16384:if c>=65535 then w=49152
630 m=hb(10)+256*hb(11):if m=0 then m=tp
640 if bb+pn(0)>m then m=bb+pn(0)
650 e$="its claim (+10) doesn't move with it:":m$="write it mb+..."
660 if m<>w then 1130
670 rem the module written: each part's address, length and bytes
680 print"writing ";o$:open 15,od,15
690 open 4,od,4,o$+",p,w":input#15,e,e$,x,y:if e<>63 then 730
700 close 4:y$="n":input"it is there already: replace it [n]";y$
710 if y$="y" then print#15,"s0:"+o$:goto 690
720 close 15:end
730 m$="":if e>=20 then 1130
740 tb=0:for k=0 to np-1:v=pa(k):gosub 1100:v=pn(k):gosub 1100:tb=tb+4+pn(k)
750 open 2,pd(k),2,f$(k)+",p,r":get#2,x$,x$:i=0:if k or rl=0 then 780
760 for i=0 to 27:get#2,x$:x=asc(x$+z$):if i=27 then x=x or 128
770 print#4,chr$(x);:next
780 for i=i to pn(k)-1:get#2,x$:if x$="" then x$=z$
790 print#4,x$;:next:close 2:next k:if rl=0 then 820
800 v=0:gosub 1100:v=ng+1:gosub 1100:for i=0 to ng-1:print#4,chr$(g%(i));:next
810 print#4,z$;:tb=tb+5+ng
820 close 4:input#15,e,e$,x,y:m$="":if e>=20 then 1130
830 close 15:print"done:";tb;"bytes"
840 if rl then print nr;"relocations: it can move a bank"
850 if rl=0 then print"no relocations: it can't move"
860 print"choose it in slopload 64: 3, the module":end
870 rem a file: q$ asked, dd the drive offered; d (0: none) and n$ come back
880 d$=mid$(str$(dd),2):print q$;" [";d$;:input"]";d$:d=val(d$)
890 if d=0 then return
900 if d<8 or d>30 then 880
910 n$="":input"its file name ($: files)";n$:if n$="" then 910
920 if n$<>"$" then return
930 open 15,d,15:open 1,d,0,"$":input#15,e,m$,x,y:if e>19 then print m$:goto 990
940 get#1,x$,x$
950 get#1,x$,x$:if st then 990
960 get#1,x$,y$:print asc(x$+z$)+256*asc(y$+z$);
970 get#1,x$:if x$<>"" then print x$;:goto 970
980 print:goto 950
990 close 1:close 15:goto 910
1000 rem a byte that differs a bank lower: a relocation (it must be $40 less)
1010 x=asc(x$+z$):y=asc(y$+z$)
1020 if a>=49152 and ((x-y)and 255)=64 and ng<990 then 1070
1030 v=a+n:gosub 1110:e$=e$+", at $"+hx$+":":m$="over 990 relocations"
1040 if ((x-y)and 255)<>64 then m$="not $40 less (an address not from mb)"
1050 if a<49152 then m$="it stays, but differs a bank lower"
1060 goto 1130
1070 q=n-p:p=n:nr=nr+1
1080 if q>254 then g%(ng)=255:ng=ng+1:q=q-254:goto 1080
1090 g%(ng)=q:ng=ng+1:return
1100 print#4,chr$(v-256*int(v/256));chr$(int(v/256));:return
1110 hx$="":for j=1 to 4:u=int(v/16):hx$=mid$(h$,v-u*16+1,1)+hx$:v=u:next:return
1120 rem e$ and m$ said, and every file closed: the drives' own channels last
1130 print e$:if m$<>"" then print m$
1140 close 1:close 2:close 3:close 4:close 14:close 15:end
```

Type it in lowercase as it is printed (the C64 shows capitals). The
words in braces in lines 130 and 140 are keys: `{clr}` is SHIFT and
CLR/HOME, `{cyn}` CTRL and 4, `{wht}` CTRL and 2, `{gry1}` C= and 4,
`{grn}` CTRL and 6. They only colour the title; leave them out if you
like. What it does, by line:

| lines | what |
|---|---|
| 100-140 | its tables and its title |
| 150-290 | the questions: the main part, its build a bank lower, up to three more parts, the module's drive and name |
| 300-570 | each part read once: opened, and the drive asked whether it is there (reading a file that isn't can leave the C64 waiting for ever); its two address bytes, then every byte counted and, with a build a bank lower, compared (the first 32 of the main part kept: the header) |
| 580-660 | the header's claim (+10) checked: it must move with the module |
| 670-860 | the file written: each part's address, length and bytes (the main part's +27 with bit 7 set, when there are relocations), then the relocation block |
| 870-990 | a file asked for; `$` lists the disk |
| 1000-1090 | a byte that differs: it must be $40 less; its place added to the list as a gap ("The relocation block" in `LMFORMAT.md`) |
| 1100-1140 | a word written; a number in hex; what is said when it stops, every file closed |


## Where next

- `MODULES.md`'s kit (`src/modkit.asm`) does what every demo module
  shares: the status line, `-wait` and `-countdown`, the music's fade
  at the end, S to turn the music off. Its template (`modules/template/`)
  is a small game built on it.
- A character screen with letters of your own (a font at a multiple of
  2 KB in the bank) is quicker to draw than a bitmap, and can scroll.
- The C64's own letters after all: the VIC sees the ROM's font in bank
  2, so a module can keep a character screen there, at $BC00, as a
  second part that stays put when the rest moves, and show bank 2
  always. PETSCII-Load does, for any PETSCII screen (OZ GOLD is one:
  `MODULES.md`, "Not only games").
- More sprites: up to eight, but at most two on any raster line while
  the tape loads.
- Effects with a tune: keep $C000-$CAE9 free and set +27 bit 1, and
  the tools put SlopLoad's own player there (+24 is then 1); set bit 0
  of its flags at $C009 before you call its init, and it leaves voice 3
  to you (the kit's `musicgo` does).
