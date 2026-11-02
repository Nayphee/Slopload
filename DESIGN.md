# SlopLoad — design notes

How the loader, the tape format, the mastering tool and the module
interface fit together, and where the ideas came from. The user-facing
guide is [README.md](README.md).

## 1. What we studied

### Invade-a-Load (Mastertronic/Ricochet, Richard Aplin, 1987)

Decoded from `Way of the Exploding Fist The (Ricochet).tap` with
`research/tapread.py` and `research/ial.py`:

- **Boot:** a KERNAL file (`FIST!`) of type 3 loading $0326-$04FF. It replaces the
  CHROUT vector at $0326 with $0340, so the KERNAL's own "READY." print
  starts the loader.
- **Turbo:** an interrupt on the cassette line (CIA1 FLAG). Each edge restarts
  CIA1 timer A, a one-shot from $0368. The timer's high byte says short or long:
  288 cycles = 0, 528 = 1, threshold about 360 cycles. About 300 bytes/s.
- **Blocks:** a pilot of $40 bytes, a $5A sync, a 4-byte header (start and
  end address), data, and an XOR check byte. The state machine is
  self-modifying branch offsets.
- **The mini game:** blocks 1-3 load the invaders game ($F800 code,
  $E000 data/music, $7000 data). The foreground then calls $F800 (init)
  once and $F803 (one frame) in a loop until the 4th block, the main game
  ($0801-$B4B3), has loaded. It then sets up BASIC and RUNs. VIC bank 3:
  charset $F000, screen $F400. No raster interrupts and no sprites: the
  tape owns the IRQ line and the game polls the raster.

### slushload v3 (SLC/Nostalgia, 2021)

Studied from `readme.txt` and `huffmanloader.asm`; none of its code is used.

- **CIA timer chain:** CIA2 timer A ticks a quantum, and timer B counts those ticks
  (CRB $59). One read of timer B gives the pulse's length class with no
  arithmetic.
- **Pilot calibration:** pilot pulses are timed and the quantum is set from
  them, so the deck's speed doesn't matter.
- **Multi-length pulses:** four pulse lengths with a prefix code (1, 01, 001, 000),
  about 1.75 bits per pulse; a 3-pulse loader is the other option.
- **Tight interrupt:** no RTI, the stack wraps, and the V flag carries "work
  pending" into the next interrupt. The screen is off for the whole load,
  so there is no bad-line DMA and pulses can be very short (72 cycles at
  speed 13).
- **Speeds 0-13.** Read from `slushload_v3.exe`'s .NET bytecode with
  `research/ildis.py`: base = 19 − speed, pulses of 1.5, 2.5, 3.5 and
  4.5 × base × 8 cycles. Speed 5 means 168, 280, 392 and 504 cycles:
  classes 112 apart, ±56 of margin. Its readme puts real decks at speeds
  6-8 (more with its skew and precompensation options); the rest is for
  playback without a tape.
- **Real tapes:** `-addskew`, `-wpcomp` (precompensation from a calibration
  tape read back from the user's deck) and `-hires` (exact cycle counts).

### Gyrospeed (csdb release 153648)

Looked at as a reference for what real decks carry reliably. Its shortest
pulse is about 168 cycles, the same as slushload speed 5's. SlopLoad never
writes a shorter pulse: 168 cycles is the floor with the screen off.

## 2. What SlopLoad does differently

| | Invade-a-Load | slushload | SlopLoad |
|---|---|---|---|
| foreground | mini game | nothing (screen off) | module |
| coding | 1 bit a pulse | prefix code | per block: 2 bits a pulse or the prefix code, with an XOR key |
| pulse lengths | fixed | fixed per speed | per block: the quickest set that keeps the speed's margin |
| timing | CIA1 TA high byte | CIA2 TA->TB chain | CIA2 TA->TB chain |
| speed setting | fixed | measured on the pilot | measured on every block's pilot, then tracked pulse by pulse |
| block check | XOR, last block only | XOR at the end | XOR per block, header check |
| errors | — | red border, stop | rewind a little and press play: blocks carry sequence numbers |
| CPU left to the foreground | most | none | at least what the module asks for, in every frame |

## 3. Speeds

Speed N keeps slushload speed N's margin for the tape's timing errors:
a pulse may be ±h off and still be read right, with h = (19 − N) × 4
cycles. While a module runs, its own timing jitter is added
(section 4), so h = (19 − N) × 4 + 48 for Flappy-Load.

Below 0 the same formula goes on, to -12 (h = 124: the longest the
core's pilot window takes, `H_MAX`, `pilot_fits`). Every h it uses is
one the tapes with a module already use, so the core and its tests are
unchanged. With a module, speed 0's h is at 124 already (76 + 48, rounded
up to 4), so below 0 changes only the parts loaded with the screen off.
The margin is in cycles, so it helps against errors of a fixed length
(edge jitter, the interrupt's latency) and against a head that loses the
highs (the pulses are longer: lower in frequency), not against wow and
flutter, which stretch a pulse by a share of its length.
`tests/suite.py`'s `dull1300` cases put the tape through a one-pole
1.3 kHz filter: -12 loads it, 0 doesn't (speed 0 holds to 1.9 kHz, -6
to 1.6, -12 to 1.1). SlopLoad 64 keeps the speed as an index (the speed
+ 12) into tables built for -12 to 13.

A class-k pulse is (m + 2k) × h cycles, k = 0-3. m picks the pulse set:

| m | pulses | used when |
|---|---|---|
| 2 | 2h, 4h, 6h, 8h | h is large enough that 2h is still long |
| 3 | 3h, 5h, 7h, 9h | |
| 4 | 4h, 6h, 8h, 10h | pilot and headers always; small h |

The shortest pulse must outlast the core's interrupt: 168 cycles with the
screen off (the worst path is 164, `tests/irqcycles.py`), 208 with a module
(bad lines stretch the interrupt).

For each block the tool tries every pulse set with at least the speed's
h (in steps of 4, up to 124) whose shortest pulse meets the floor, both
codings, and every XOR key, and takes the quickest. A faster speed allows
everything a slower one does, so it is never slower. Rates for a 63 KB
program, PAL, bytes per second:

| speed | random data, screen off | with a module | zeros, screen off | with a module |
|---|---|---|---|---|
| -12 | 455 | 449 | 948 | 766 |
| -6 | 563 | 449 | 1175 | 766 |
| 0 | 670 | 449 | 1394 | 766 |
| 5 | 793 | 534 | 1408 | 848 |
| 9 | 832 | 535 | 1408 | 866 |
| 13 | 832 | 585 | 1408 | 866 |

The scale flattens where the floors bind: past speed 9 with the screen
off, the 168-cycle pulse; with a module, the 208-cycle pulse and the
CPU share (section 4). Invade-a-Load is about 300 bytes/s.

### Codings

- **2 bits a pulse:** each byte is 4 pulses, most significant pair first.
  The key is chosen per 2-bit position, so the commonest pair at each
  position gets the shortest pulse.
- **Prefix code:** class 0 = 1, 1 = 01, 2 = 001, 3 = 000, about 1.75 bits
  a pulse. The key maximises 1 bits (class 0 carries a bit on its own).
  Quicker on random data; dearer per pulse in the interrupt.

## 4. What a running module costs

### Jitter

A tape edge is timed when the interrupt restarts timer A. Anything that
delays the interrupt shifts that moment: the instruction being finished
(up to 7 cycles), a bad line (the CPU stops for 40-43 cycles), sprite
DMA. `tests/jitter.py` timestamps every edge with a measuring build of
the core and compares with the tape:

| | error between two edges, 99.9% | worst |
|---|---|---|
| screen off | ±5 | 6 |
| Flappy-Load with 4 sprites (first version) | ±60 | 99 |
| Flappy-Load, no sprites | ±49 | 52 |
| Crossy-Load, playing | ±49 | 52 |
| Crossy-Load, scrolling all the time (speed 0; speed 13) | ±50; ±48 | 52; 50 |
| Template-Load | ±48 | 51 |
| a Koala picture (the show module) | ±49 | 81 |
| music alone, screen off (the show module) | ±6 | 8 (and a few edges at block starts, as with the screen off) |

So modules use no sprites (Invade-a-Load has none either), and a
module states its jitter in its header (byte 12; all three say 48). The
games' rows were measured again after the core's stopwatch changed (it
counts from $FF7F now: `tests/jitter.py` finds where it restarts and
wraps, and leaves out the record that spans a restart). An earlier
worst of 96 for Flappy-Load was most likely such a record, which the
old measurement kept.

### CPU share

The interrupt takes, per pulse (from `tests/irqcycles.py`, worst over
the decoder's states, entry and RTI included):

| coding | class 0 | 1 | 2 | 3 | completing a byte adds |
|---|---|---|---|---|---|
| 2 bits a pulse | 85 | 85 | 85 | 85 | 44 |
| prefix code | 88 | 99 | 108 | 105 | 50 |

At 208-cycle pulses that is half the CPU. An unpacked program is mostly
zeros, which the key turns into a stream of the shortest pulses: in the
first profile Flappy-Load overran its frames there on NTSC. A module
states in its header (byte 14) the most it can give up (35% for
Flappy-Load), and the tool keeps every frame's worth of tape (19656
cycles) within it, by choosing keys and pulse sets that lengthen the
pulses where needed. Random data rarely notices; zeros load at
850 bytes/s instead of 1100.

`tests/frameprof.py` times each part of Flappy-Load's frame in VICE with
the loader running. Worst frame at speed 13, against the last line where
a late status split is still unseen:

| | PAL (unseen to 295) | NTSC (unseen to 246) |
|---|---|---|
| random program | 192 | 189 |
| all-zero program | 218 | 205 |

## 5. Tape format

A pulse is the time between two falling edges of the cassette signal, in
PAL cycles; a .tap stores cycles/8.

**KERNAL part** (standard ROM-loader encoding, both copies):
- the header block: type 3, start `s1lo`, end $0304, the 16-character name,
  then stage 1's main part in the spare bytes ($0351-$03EB);
- a 58-byte data block, $02CA-$0303: stage 1's subroutines, then the BASIC
  vectors with IMAIN ($0302) pointing at stage 1. After LOAD, BASIC's idle
  loop jumps straight into it.

**Turbo part.**

- **Pilot:** class-0 pulses of set 4 (4h). Until it is measured, the
  decoder counts with h = 122: a pilot pulse may last 122-609 cycles.
  The tool's pilots run from 176 cycles (h = 44) to 496 (h = 124), and
  `pilot_fits` checks every block's with the module's edge jitter, a deck
  3% off speed and an NTSC machine, which counts 3.8% more cycles in a
  pulse than the PAL cycles the tape is written in. The window used to
  be h = 104 (to 519 cycles): at speed 0 a module's ordinary bad-line
  delay pushed a pilot pulse past it, the count started again, and a
  block whose pilot restarted late was missed (Crossy-Load's tape errors
  in long sessions).
- **Measure:** stage 1 times pulses 17-144 (512h) with CIA1 timer B,
  once. The core times pulses 17-80 (256h) with the timer counting from
  $FF7F, so its high byte is h rounded, sets CIA2 timer A to h, and then
  times the next 64, and so on until the sync. 256h stays inside the
  16-bit timer on NTSC at h = 124 (512h did not: 65,903 cycles), and a
  "pilot" the decoder found in a block's data, after a rewind, is
  measured again on the real one.
- **Sync:** one class-3 pulse (10h).
- **Core block** (read by stage 1, set 4, 2 bits a pulse): N pages to
  $0400, then the XOR check byte.
- **Every other block:** a 9-byte header in set 4, 2 bits a pulse, then
  the body in the block's own set and coding:

  | byte | meaning |
  |---|---|
  | 0-1 | load address |
  | 2-3 | length (low byte, then pages rounded up) |
  | 4 | XOR key |
  | 5 | flags: $01 module complete, $02 main part complete, $80 last, $08 stores under I/O, bits 4-5 the set (m − 2), $40 prefix code |
  | 6 | sequence number |
  | 7 | progress (0-255) at the block's start |
  | 8 | check: $A5 XOR bytes 0-8 = 0 |
  | body: pad | one byte in the longest pulses, thrown away: the header's set-up (~310 cycles) runs over its first edge |
  | body: data | XOR key applied |
  | body: check | XOR of the data |

**The decoder** (`src/core.asm`, an interrupt per edge):
```
restart timer A (quantum phase) -> read timer B -> restart timer B (8 cycles)
```
Timer B holds 11 − (quanta since the last edge); a table per pulse set
maps it to the class. Class k is read for anything from (m + 2k − 1)h to
(m + 2k + 1)h: ±h.

**Speed tracking.** A pulse of nominal length sits on the boundary
between two timer-B counts, so each data pulse votes "late" (on or past
it) or "early". Interrupt jitter is symmetric and cancels; a tape
running slow or fast tips the votes, and after a net 32 the quantum
moves by a cycle. In the channel model, 6% wow fails without it and
loads with it (`tests/suite.py`, the `_nopll` cases).

## 6. The interrupt's budget

The worst path (a pulse that completes a byte, crosses a page and moves
the quantum, prefix code) is 164 cycles, under the 168-cycle shortest
pulse. To get there: the progress count moved to the foreground (the
module loop follows the store pointer's page), the speed vote became a
signed add with the overflow flag, completions jump through a vector,
the data store ends in its own RTI, banking for stores under I/O is
patched out for blocks that don't need it, and there is no CLD (modules
may not use decimal mode).

**Border stripes.** The prologue's `stx $d020` puts the timer-B value
(11 less the pulse's quanta) on the border at every edge: a band for
each pulse, its colour by pulse length. `-stripes STYLE` uses
`core_stripes`, built from the same source with `lda stab,x : sta
$d020` and a 12-byte colour table the tool fills (1,023 bytes). The
lookup costs 4 cycles: its worst path is 168, so the tool raises the
shortest pulse to 172 with the screen off and 212 with a module (checked by
`tests/irqcycles.py`).

**No stripes** (`black`, `block`, a single colour) use `core_flat`,
which keeps the core's layout: the prologue's store becomes `bit $d020`
(as `fstr`'s operand, so the final phase doesn't turn stripes back on),
and `errshow` becomes `bflat`, `ldx ld_seq` (the block's number: a
colour a block) or `ldx #colour` (the tool's patch), red on a tape
error, then `bset` after the core's end, which stores X only when the
border differs: on the 8565 (a C64C, VICE's default) every write to a
colour register leaves a grey dot on the border, so a store each time
round the wait would show. The border changes where `errshow` ran, in
the boot and final phases' wait loops; nothing is added to the
interrupt, so it costs nothing. 33 bytes differ from the core
(`tools/build.py`'s `flat_check` asserts where). Stage 1 is held at the
mode's colour (a style's first) for every mode but rainbow: its
`stx $d020` (`s1str`) becomes `bit`, and `s1bc` stores the colour once.

## 7. Memory

| range | use |
|---|---|
| $02-$03 | `ld_state`, `ld_progress` (for the module) |
| $04-$0F | loader |
| $10-$8F | module (the music player uses $70-$7F) |
| $0200-$0258 | free for the module: the BASIC input buffer, which the program's start never reads (Crossy-Load keeps a buffer, two tables and four variables at $0200-$0254) |
| $0259-$02C9 | KERNAL variables, kept for the program's start |
| $02CA-$03EB | stage 1 (only until the core runs) |
| $0334-$0370 | exit code (copied there at the end) |
| $0400-$07EF | core (in the default screen's memory; the module shows its own) |
| module's claim | Flappy-Load $E000-$FBFF, Crossy-Load $CAEA-$CFFE and $E000-$FFF9, the built-in music $C000-$C9C8 |
| $FFFA-$FFFF | interrupt vectors in RAM |

The program can use $0801-$FFF9: 250 disk blocks of 254 bytes. Bytes
inside the module's (and music's) claim go into blocks read after the
module has stopped. The motor is stopped while the player finishes; the
blocks after the stop have a 2-second pilot for the deck to get back up
to speed. A CD or MP3 player can't be stopped: `-nomotor` ends the
module as soon as the rest has loaded instead.

## 8. Module interface

A module is a PRG with this header at its load address:

```
+0  "PLG1"
+4  init    (word)   once; screen off, loader interrupt running
+6  frame   (word)   in a loop; one frame including its own wait for the
                     raster; return carry set to say "go on" (only
                     looked at once ld_state bit 7 is set)
+8  stop    (word)   once; silence the SID
+10 claim end (word) end of the memory it uses, run-time buffers included
+12 jitter    (byte) its worst edge timing jitter in cycles (tests/jitter.py)
+13 song      (byte) set by the tool: the song to play, $FF none
+14 CPU share (byte) the most of the CPU (%) the loader may take; 0: 35
+15           (byte) the show module: the picture's background colour
+16 music init (word) set by the tool; init takes A = byte 13
+18 music play (word)
+20 PAL period (word) raster lines between play calls, in 1/64 lines
+22 NTSC period (word)
+24 music kind (byte) 1 the built-in player (stop $C006, flags $C009),
                      2 a SID tune (all three voices; stop: clear the SID)
+25           (byte) the show module: the picture's VIC bank ($DD00 bits)
+26 blocks    (byte) set by the tool for a module: the program's size in disk
                      blocks (OZ GOLD counts them down)
```

A module that plays music calls play once a tick (the other modules) or
every period's worth of raster lines (the show module), and copies the
words it needs at init: the header may be overwritten after.

Rules: run with $01 = $15 (I/O in, ROMs out) and never write $01. Never
`sei`, never touch CIA timers/interrupts or $FFFA-$FFFF, no raster
interrupts: poll $D012. No sprites. No decimal mode. Zero page $10-$8F
only. Read `ld_state` (bit 7 loaded, bit 6 tape error: tell the player
to rewind, bit 1 autorun, bit 0 NTSC) and `ld_progress`. Any instruction
can be delayed by the loader's interrupt (up to ~170 cycles), so
raster-timed writes need slack.

A module with music lists it in `modules/<name>/parts.json`; the tool loads
it first, as part of the module, and puts the chosen song in byte 13.

### The module standard

Every module behaves the same way, so a tape works the same whichever
module it carries and a new module drops in. The standard is written
for module authors in [MODULES.md](MODULES.md): the header
(`src/modhead.asm`), the shared kit (`src/modkit.asm`: status line,
start key, fire, music), when the program starts, the debug hooks, the
memory a module may use (including a second part), and the tests a
module passes. Flappy-Load, Crossy-Load, the minimal Template-Load,
OZ GOLD and PETSCII-Load all keep it.

### Crossy-Load's frame

A vertical scroller with a status bar on top, and no interrupts to split
the screen with. The status rows (0-2) are shown with the normal fine
scroll 3 (bad lines at 51, 59, 67); rows 3 and 4 are blank, and the play
field's fine scroll f + 3 is written while the beam is in them, so that
row 5 on starts at line 91 + f.

A store to $D011 must never start a bad line in the middle of a line
(the "VSP" case: the rest of the screen shifts sideways, and some C64s
crash), make two bad lines in a row, or start a row early. The first
version read the raster line and stored when it was in a two-line
window, and missed the window in about one frame in 14 when the
loader's interrupt (up to 164 cycles) and a bad line fell between two
reads: that frame showed the play field unscrolled, a flicker. No
window is safe from that: an interrupt can always come between the read
and the store. So `split` doesn't decide once. From line 60 it reads
the line y and stores, over and over:

| line read | value stored | |
|---|---|---|
| below 85 | 3 | as the status rows have it: rows 3 and 4 start at 75 and 83 |
| 85 to 84 + f | (y - 1) & 7 | the line just passed: the next line it matches is 8 on |
| 85 + f on | f + 3 | then it returns |

Any store may still be in force up to 6 lines after its read (two
interrupts and a bad line between a read and the next store). At every
line, every value that may be in force agrees on whether that line is a
bad line, so no store starts one mid-line, and row 5 starts at 91 + f
whatever the delays. `tests/splitmodel.py` checks this for every f and
every line the loop may start on, against a model of the VIC's rows;
with 7 lines of delay it fails, as it must. The loop must start by line
85; the work before it in the frame (colour rows to line 58, background
rows started before line 12) ends by about line 81, and the music plays
after it. `tests/crossyprof.py` counts frames where it starts too late
(none in 1,500 frames each on PAL, NTSC, a C128, speed 13 and with a
SID tune, the play field scrolling all the time), and
`tests/splitlook.py` compares the emulator's own picture of each frame
with the one the screen memory gives.
The same write sets the 24-row border, so the bottom of the play field
ends cleanly at line 247 for every scroll; the vertical blank puts 25
rows back for the status.

The colours are black, white ($D022) and red-brown ($D023) everywhere,
plus one colour per lane from colour RAM (green grass, blue river, a
colour per road, white rails that flash red). Lanes are two rows high;
a lane's bottom-row characters are its top-row ones + 10.

A car, a log or a train is a left end, a run of identical middle cells
and a right end, over the lane's ground. A car's or a log's end is two
multicolour pixels wide (outer, inner): a log's rounded, ringed cut end;
a car's bonnet with its light below the cabin, and a wheel. Pre-shifted
to the four multicolour positions that is L0-L3, R0-R3 and two more
cells: LX (the cell after L3, holding the inner column) and RX (the
last cell at shift 1). An end's inner column has the middle's top half,
so LX and RX need characters for the bottom row only: 22 per kind.
A move of one pixel still rewrites at most three cells, and only at the
ends of each object. Trains move a whole cell a tick. The first version
had one-pixel ends (20 characters per kind): flat bars, cars and logs
hard to tell apart; the four characters came from the status bar,
which now fills 2 pixels a step (`gk_barhalf`).

**Scrolling a whole row** needs every row moved down one. The other
screen buffer is the one on show a row lower: its rows are copied from
it two at a time (`copyrow`, about 20 lines a pair with the loader busy),
the cells under the hen's block from the 9 she keeps under her, in the
vertical blank's spare time and at the end of each frame; every change
to the rows on show is written to it too, a row lower, so the copy stays
right. (They were drawn from the lane tables a row at a time, 25-60
lines each. With the hen hopping and steering, the camera waited 2-4
frames at every row for the buffer: the scroll stuttered. A new world is
still drawn from the lane tables.) When the camera reaches fine scroll 7
and the other buffer is ready, the step gets a frame of its own: that
frame's tick is held (on NTSC it counts as the sixth, so the game is no
slower there), and it makes the new lane, draws the row coming in at the
top of the other buffer and places the hen in it (`camstep`). The
vertical blank after it switches buffers. Chasing the hen, the camera
asks for the step in the tick it reaches 7; asked a tick later, the
field stood still a frame at every row. Creeping, it waits for the next
creep's step as it always has: asked at once, it crept 8 pixels in 7
steps, a seventh faster, and caught a walking hen sooner
(`tests/crossywalk.py` found it). If the other buffer isn't ready, the
camera waits. In 600 frames of hopping and steering on PAL, the field
stands still in 3% of the frames the camera chases her (27% before), on
a C128 9%, and on NTSC little more than its held sixth.

Colour RAM can't be double-buffered, so the rows whose colour changes
are rewritten from the top down, each before the beam reaches it in the
first frame of the new buffer. A row written as the beam crosses it shows
its old colour on a few lines, for one frame. Each row needs about 7
lines (up to 19 with the loader busy), and on the screen the beam gains
on a row being written. So the rows start early: from the camera's step,
a row is rewritten as soon as the beam has passed it in the frame still
on show (`colrows`, called while the game waits for the vertical blank,
up to line 240). The vertical blank then does more, up to line 58. The
rest come after the split, ahead of the beam.

The step had first been made in the tick, after the hen's move, with the
new lane and the top row drawn in the next vertical blank. With the hen
hopping nonstop and the program loading at speed 0, that tick's frame ran
into the next frame's top. The next frame's blank then started late, and
the lane and row took most of it (about 63 lines on NTSC), so the colour
rows started behind the beam and never caught up: a few lines of a lane
in its neighbour's colour, for one frame, in about one row scroll in 15.
With the step in a frame of its own, `tests/crossyprof.py` finds no
colour row late in 2,400 frames of nonstop hopping on PAL and 3,600 on
NTSC.

**A frame that runs late.** The scroll glitch a user saw on PAL was not a
drawing error. It was frames whose work ran past the next frame's top.
That next frame got no vertical blank work and no split, so it showed
with the split's last value: the play field 8 px off, for one frame. With
the hen hopping nonstop the old build did that 50 times in 600 frames on
PAL and 78 on NTSC (`tests/framecap.py`, which looks at the emulator's
own picture each frame). Now:

- The game knows when it is late. `$D012` = 251 is set once, and the
  split clears the VIC's raster latch (`$D019` = 1). From then on `beam`
  reads 255 once line 251 has passed, even after the line count has gone
  back to 0. No interrupt is used: `$D01A` stays 0.
- A tick that would start past line 150 (NTSC 115) is held, as NTSC's
  sixth is. The game loses a 50th of a second; the picture stays right.
- `lanedraw` starts no lane past line 150 (NTSC 130); in a held frame,
  180. A rail lane whose warning flash only changes colour waits a tick
  when time is short.
- The hidden buffer's work (`bgtail`) stops when `beam` says the frame is
  over. `lanevb` gives way to it while the buffer isn't ready.
- The hen's block waits for the next tick when it would start past line
  250 (NTSC 200): with her render it can take 100 lines. She is then a
  frame behind, as she already is when a lane is redrawn under her. On
  NTSC this was the last cause of missed frames: a full tick started just
  before line 115 (the lanes, a train drawn late, then the hen) ran into
  the next frame's top about once in 600 frames of nonstop hopping. She
  now waits in about 6% of NTSC's ticks hopping nonstop while the program
  loads, and never on PAL.
- A frame whose work ends in the next frame's top border (before line 41)
  does that frame's vertical blank work at once, rather than missing it.

In 4,800 frames of nonstop hopping on PAL and 2,400 on NTSC, no frame is
missed and the field never moves the wrong way, and none in normal play.

**Drawing a lane while the beam is away from it**: lanes that moved are
redrawn before the beam reaches them or after it has passed, never while
it is on them, so each frame shows every lane whole. Railways go first
(their trains move a cell a tick). A train used to be drawn at once when
the frame was short of time, wherever the beam was; with the hen hopping
and steering that tore it now and then, its top row from one tick and
its bottom row from the next, or a cell half drawn. It now waits for the
beam to pass like any lane (40 lines at most), and no frame is missed
for it. `tests/crosstear.py` checks every row the beam draws against
memory as it was before and after the frame's changes. Then the rest from both ends: the
bottom ones while the beam is well above them, the top ones once it has
passed. After line 150 no more lanes start; the rest catch up next tick.
A lane behind by more than a pixel catches up by up to 3 pixels at once,
redrawing the three cells at each end of every object (a whole cell's
step would leave its old tail). Lanes off the screen are kept drawn
where they are, so one coming in at the top appears in the right place.

**The hen** is drawn into 9 characters like Flappy-Load's bird. A lane
redraw that falls on her block doesn't overwrite her: the new character
goes into the 9 she keeps under her, which go back when she moves on.

**Memory.** The character set is 128 characters at $E000, so the two
screens fit in the half of its 2 KB the VIC never reads glyphs from
($E400 and $E800); code and tables from $EC00. A second part, loaded
with it, holds the status line, sound, keys, the camera and the row
copy at $CAEA. Setting up runs once, from screen a's rows 6-24
(`boot.asm`, at $E500): nothing writes there until it is done (it draws
the play field in buffer b), and its last step (`inidone`) clears them.
That made the room for the row copy; `tools/build.py` checks it ends
before the screen's last 24 bytes, which hold tables. 40 bytes are spare
at the top, 74 in the second part.
Characters 125-127 are never shown: they hold the hen's state on show
(`hshown`), the road speeds and `putv`'s addresses, with 1 byte spare.

**Rules of the world.** The lanes move (`lanemove`) only in the title
and in play: when the hen dies everything stops where it is, through the
game over (no `lanedraw` then, and no `lanevb` catching a lane up).
Lanes get a random direction, but a river lane takes its lane number's
parity: two rivers side by side (a run of water is one or two lanes)
always go opposite ways. Going the same way at speeds alike, their logs
kept the same offset for good, and a pair whose logs never overlapped
couldn't be crossed. `tests/crossyrules.py` checks both.

The hop is held back while the hen is near the top of the play field
(her block must stay below row 5), and the camera follows her there at a
pixel a tick. `tests/crossycheck.py` compares the screen with the lane
tables as the game plays; `tests/crossyprof.py` times the frame.

**Walking.** Joystick left and right move the hen a multicolour pixel a
tick, on the ground or in the air (`henmove`, before the collisions, so
a car or the river is checked where she now is), from `playlo` to
`walkhi`: columns 2-37, clear of the edge trees (a log can still carry
her to `playhi`). A walking hen is redrawn every tick, and that ate the
spare time the hidden buffer is drawn in: with her walking while
hopping nonstop, the scroll stood at fine scroll 7 waiting for the
buffer for up to 46 frames. So while the camera waits for it in play,
the tick is held (NTSC: as its sixth) and the frame's time goes to the
buffer: the longest pause was then 3-4 frames (with the buffer copied,
see above, 2-3 and rare), and the field moves in as many frames as
without walking. (The hold found an old fault: the
buffer's drawing waited for 16 lanes made (`lgen`), a new world's rule,
and `lgen` counts to 256 and starts again, so after 256 lanes it stood
still until the ticks made more. Held ticks make none: the game froze
248 hops in, the program loaded but never started. The rule is now the
build's alone.) `tests/crossywalk.py` walks her with the
monitor's joystick; `tests/framecap.py --walk` captures frames while she
walks and hops.

**Keeping every lane drawn.** A road or river lane is redrawn only while
the beam is clear of it, and the tick's `lanedraw` runs after the split
(from about line 105-150 with the loader busy) and stops at line 150. A
lane the beam was near all that time waited for the next tick, and with
the timing the same every tick the same middle lanes waited for good;
`drawlane` also returned early unless the lane had moved on that very
tick, so a slow lane that missed its turn was never caught up. Their cars
and logs stood still on screen while the hen met them where they really
were (a user's real C64, Battle Royale loading). Now:

- `drawlane` catches a lane up whenever it is drawn behind, one step of
  up to 3 px a call (so a call stays under about 75 lines). A 3 px step
  redraws the three cells at each end of every object, and the cell one
  in from its right end: a step right into the next cell leaves the old
  end piece there (`crossycheck.py` found it).
- `lanevb` draws the lanes furthest behind in the vertical blank while
  the beam is below the picture (each started between lines 200 and 290,
  so it is done before the split). NTSC's blank is too short to look for
  them first, so the tick picks the first one (`lanepick`, kept in
  `vbpick`) and the blank starts drawing at once. There, a draw moves a
  lane one pixel (`vb1`: about 3 cells an object, at most 63 lines) and
  starts by line 255: a 3-pixel step redraws 7 cells an object and took
  up to 97 lines with the loader busy, which ran past the next frame's
  split now and then (1 to 4 skipped splits in 800 frames of nonstop
  scrolling with a SID tune playing, `tests/crossyprof.py`).
- The hen's collisions use where the lanes are drawn, so a lane drawn
  late is never an unfair death.
- The play field is rows 5-20, eight lanes (`lastrow`); rows 21-24 stay
  blank. Drawing all ten in time was the trouble, and the user allowed
  the cut. The camera starts four rows further down (`cutrows`), so the
  start lanes keep their places on screen, and every write to a row that
  isn't there goes to a 40-byte buffer at $0200 (with `rowcol` and
  `ldrawn` and four variables after it, to $0254: the room the code
  needed).

`tests/lanelag.py` measures how far each lane on show is drawn behind:
at most 4 px on PAL in normal play, and 11-28 px with the hen hopping
forward nonstop (the screen scrolling every tick; it varies from run to
run), 17-26 px on a C128. On NTSC, whose frame has the least time, up to
23 px in normal play and 32-53 px hopping nonstop, a lane staying behind for seconds at a time (before:
128 px on PAL, one lane frozen for 412 ticks). The held ticks and lane
budgets that keep every frame whole cost this. With the hidden buffer
copied rather than drawn (above), the frame has more time for the lanes:
hopping nonstop, 4 px on PAL and 26 on NTSC in a 600-tick run. On NTSC under the heaviest
load the game also runs slower, by the held ticks. No frame's
split is skipped, also with tunes of up to 3,695 cycles a call on NTSC
(`crossyprof.py`, `splitlook.py`), and `crossycheck.py` finds the screen
as the lanes say.

### The show module

`modules/show/` covers the modes with no other module (`-show picture`,
`picmusic`, `music`): 208 bytes at $CA00, with the tool filling in the
song (byte 13) and the picture's background colour (byte 15, $FF for
none). A Koala picture is three parts loaded before it starts, with the
screen off: the screen to $CC00, the bitmap to $E000 and the colours
straight into colour RAM at $D800 (a block the tool doesn't mark as
stores under I/O, so the core writes it with I/O in). `init` puts VIC
bank 3 on ($D018 $38, multicolour bitmap) in the vertical blank and
starts the song; `frame` waits for a new frame, steps the music (5 in 6
on NTSC), keeps the border black (red on a tape error; with music alone,
lightening as it loads) and says "go on" as soon as the program is in.

With a picture the screen is on, so the tool treats it like any other
module: the jitter in byte 12 (48) is added to the margin and the
shortest pulse is 208 cycles. Music alone keeps the screen off:
screen-off speeds, with the CPU share in byte 14 (85%) leaving the music
its time.

### SID tunes

Tunes written for two or three SID chips are refused (the header says
so, or the tune keeps writing above $D41F as it plays: on one chip those
writes land on its mirrors). An init that clears $D400-$D47F through the
mirrors is fine. Workspace a tune writes as it plays may be in
$0200-$03FF, which stage 1 has finished with by then.

`tools/sidstrip.py` (also run by `-sid`) runs the chosen song in
`tests/sim6502.py`, with plausible answers for the raster, oscillator 3
and the CIA timers, for 15,000 frames (5 minutes). Stores the loader can't allow ($00/$01,
the VIC, colour RAM, the CIAs, $DE00-$DFFF, $0400-$07FF, the CPU
vectors) become `NOP #imm` (plus `NOP` for three-byte ones): no memory
read, so a dummy read of a CIA's interrupt register can't take the
tape's interrupt. The patched tune must then write exactly the same to
the SID, frame by frame. A CIA-timed tune's timer latch (or the KERNAL's
$4025) gives its rate; the period between calls is kept in 1/64 raster
lines for PAL and NTSC, so the show module calls it at the right line
and a PAL tune keeps its tempo on NTSC (five calls in six frames).

`tools/sidreloc.py` traces which bytes are high bytes of addresses inside
the tune: absolute operands (and operands the tune writes itself, back to
the immediate or table byte they came from), the high byte of zero-page
pointers (through loads, stores, transfers, the stack, and arithmetic,
where the input that looks like an address in the tune is the one
followed), and addresses pushed for an RTS. A move by whole pages adds
to those bytes; the moved tune, alone at its new place, must write the
same to the SID as the original, for 5 minutes of play. Code the run
never reaches is found too: from every branch, JMP and JSR it ran, the
ways not taken are decoded until they end, and their absolute operands
inside the tune move as well (a way that runs into a byte that starts
no instruction is taken for data and left alone). The SlopLoad tune has
a branch that first runs about 110 seconds in: moved by the trace alone
(then one minute), it jumped back to its old address in the middle of
Battle Royale's code. In another sample of 200 HVSC tunes (187 PSID),
159 move with and without the static pass, and in 149 of them it moves
code that a minute of play never ran. Of 200 random HVSC tunes, 166 move
(90% of the 184 PSID ones; the rest are RSID); the 17 the trace can't
follow play only where they are.

The tool then chooses the tune's place, the picture's VIC bank and the
show module's address together: clear of the loader, I/O and each other,
with the least of the program under them.

## 9. Real tapes, CD and MP3

VICE plays pulses with perfect timing, so any speed works there.

**A real deck** adds speed error (absorbed by the per-block pilot
measurement), wow (tracked), flutter (eats margin directly) and peak
shift (a pulse's neighbours move its edges). `-calibrate`, `-analyse`
and `-precomp` measure the last three on the user's deck and correct the
peak shift.

**Sound** (`tools/audio.py`): a CD, an MP3 player or a PC, through a
cassette adapter or a lead. Each pulse becomes one period of a square
wave, its falling edge at the pulse's start, box-filtered so an edge
keeps its time between samples. Read back, falling zero crossings with
hysteresis, interpolated between samples. Through LAME and back (a
63 KB program at speed 13), the worst edge moved:

| | worst edge error |
|---|---|
| WAV, 44.1 kHz | 3.8 cycles |
| MP3 320 kbit/s | 4.6 |
| MP3 256 | 4.7 |
| MP3 192 | 6.7 |
| MP3 160 | 11.5 |
| MP3 128 | 21 |
| MP3 96 | extra edges: unreadable |

The tool reads every .wav or .mp3 it writes back and refuses one that
moves an edge by half the block's margin or more. In VICE, through a
one-pole 12 kHz low-pass and 20 Hz high-pass for the player and adapter,
these load with a module running: CD and MP3 192 kbit/s at speed 13
(PAL, and the whole 250-block program with `-nomotor`), MP3 160 kbit/s
at speed 13 on NTSC, MP3 128 kbit/s at speed 5.

The polarity matters: inverted, every falling edge moves to mid-pulse
and nothing loads, not even the KERNAL part. `-invert` writes it the
other way round.

## 10. Tape sides

`slopload.py -tapeside` puts many programs on one tape: each is its own
SlopLoad file (KERNAL header and stage 1, core, blocks, trailer), built
by `master()` with `-show none` and checked by decoding it again, then
the files are put end to end. Each starts with the KERNAL's standard
10-second leader, which is also what a deck needs to come up to speed
when the next `LOAD` starts the motor, so nothing else goes between
them. With a side's length (`-tape C60`, `-side MM:SS`, less `-margin`),
each program goes on the first side with room for it: first-fit in the
given order, which keeps the order wherever the sides allow it and fills
each side about as well as any packing would for a handful of programs.
Slushload's `-mixtape` was the model (every .prg in a folder, alphabetical
or shuffled, its run length reported); the length limit and the sides
are SlopLoad's.

**No trailer between files.** A tape ends with 200 short pulses after its
last block (the last data pulse is only measured at the next edge). The
core stops the motor right after that block, so on a tape with another
file after it the next `LOAD` starts reading inside those pulses: 304
cycles at speed 0, shorter than any the KERNAL writes. Its tape interrupt
re-enables interrupts inside itself (`JMP $FF43` with a return address
pushed), and on such pulses it nested until an `RTI` took a return
address off a clobbered stack: in VICE, three of four second loads
crashed during SEARCHING, in the first program's data at $2528. Without
them, the next file's KERNAL leader ends the last pulse, and every load
passed. Tape sides and `tools/speedtest.py`'s tapes keep the trailer only
after their last file.

## 11. SlopLoad 64: the mastering tool on a C64

`c64/slopload64.asm` (with `writer.asm`, `coding.asm`, `plan.asm`,
`xmem.asm`, `io.asm`, `ui.asm`, `files.asm`, `setup.asm`, `math.asm`;
`tools/c64build.py` puts the loader, the show module and per-speed
tables into `payload.asm`). Two more programs share its disk and some
of its files: PETSCII-LM (`petsciilm.asm`, with `wfile.asm`) and SID-SLM
(`sidslm.asm`, with `sidread.asm`, `trial.asm` and `wfile.asm`). `tools/c64model.py` is the same tool in
Python, and `tests/c64tool.py` runs SlopLoad 64 in VICE, works its menu,
and compares its output with the model's, byte for byte (.tap) or edge
for edge (a cassette recording).

**The menu** (`ui.asm`) is drawn whole on a cleared screen each time:
the title, the machine (`machine.asm`: the CPU, PAL or NTSC from the
raster's last line, the expansion memory), lines 1-9 and 0 one a row. A
number writes that line's name in reverse under the menu and asks its
questions below it; "press any key" then clears the screen and draws the
menu again. Answers are read key by key with GETIN (`io.asm`'s
`readline`, with a cursor of its own and DEL): the KERNAL's screen
editor would read the whole screen line, and anything an earlier message
left on it came back as part of the answer. The name on tape is read by
`readname`, which keeps control keys (the tape's FOUND prints them: a
CLR and a colour before the name), and `prsafe` shows them as quote mode
does, reversed, so that drawing the menu doesn't act on them.

**Loading lines in a style** (the PC tool's `-stripes`) need
`core_stripes`, the core with a colour lookup in its interrupt. A second
core would cost 1 KB SlopLoad 64 doesn't have. It is the core with two
insertions (`lda stab,x` before the border's store; the 12-byte colour
table) and 101 bytes that differ by +3, +15 or -1 (addresses past an
insertion, an opcode). `tools/c64build.py` asserts that and writes the
pairs (gap, delta), 205 bytes copied to $C610 at the start; `plan.asm`'s
`corestr` moves coreb's two tails up, writes the lookup and adds the
deltas, `corestd` takes them off and moves the tails back. (The pairs
are packed a byte each, a 6-bit gap and a 2-bit delta code, and with the
styles' colour lists they are 181 bytes in the cassette buffer, $033C:
SlopLoad 64 never calls the KERNAL's tape routines, the only users of
it on the mastering machine. In case a cartridge or a wedge writes
there, `prepare` checks them against their bytes xored before a styled
tape.) `mkcore`
patches its fields in the core's own layout first (none of them is one
of the 101), so they move with it. With a module or a picture showing,
every pulse is then 212 cycles or more (`coding.asm`'s second row of
first h: 108, 72, 56).

**No stripes** (black, block, one colour) need `core_flat`, which has
the core's layout: its 33 differing bytes go in `payload.asm` as
(offset, xor) lists. `corefl` xors them into coreb and `corefd`, at the
start of every `mkcore`, xors them back, the same list both ways; so
that it can, `corefd` first puts `bflat` back as built (`ldx ld_seq`),
since one colour writes `ldx #colour` over it (`tests/c64modes.py`
makes the core in one mode after another and checks each). Stage 1
gets the PC tool's two patches. The menu's list has the three after
the styles, one colour asking for its colour (`opt_fcol`).

**Room.** The music pool's 17 pages must end by $9FFF, and the tool's
code and buffers come before it. Since the `.sid` trial moved to SID-SLM
(2026-10-30), the pool ends at $8AFF: 5,376 bytes free. What runs once at the start (`startup`:
the core to coreb, the patch to $033C, the NMI's rti, `detect`, and
`dibsum`, each byte's bit pairs summed, built in the page at $C600 that
the REU's sizing borrows first) sits after the payload, in what becomes
the buffers. The @ line (`adisk`, `dirshow`: the directory and the
command channel, through `dstat`'s channels 15 and 14) fitted in what
that freed.

**Modules, tunes and pictures from disk.** Nothing module- or tune-specific
is built in (the user's rule: others must be able to add their own). The
menu (`ui.asm`) reads a file when it is chosen (`files.asm`: a whole
file into memory, a drive's files listed by their ending):

| what | where it is kept |
|---|---|
| a module (`.lm`) or a picture (`.koa`) | the RAM under the I/O and the KERNAL, $D000-$FFF9 (12 KB), one at a time: the other is read again when the show wants it |
| a tune's file (a `.slm`), as read | $A000 (then its bytes to the music pool; its relocations, if it has them, to $C700) |
| the tune | the music pool, 17 pages below $A000, at the same offset in its page as where it plays |
| the show module, moved to its place | made at $BC00, then to $F800 (past a picture in the high pool) |

`setup.asm`'s `prepare` turns the menu's choices into what goes on the
tape, as `c64model.setup()` does, rule for rule and in the same order:
the tune's checks (out of the loader's memory and I/O, its workspace
out of the loader's), beside a module its zero page, rate and longest
call, and its place (where it is, or for a `.slm` that can move the
highest page that works); for a picture or music show, the show
module's place and the picture's VIC bank (the PC tool's `place_show`:
the least of the program under them), the module moved by its list of
address high bytes, and the loader's share from the tune's longest call
(integer arithmetic, so the model and the C64 agree to the byte). The
header bytes are patched in place: the module's in the high pool (its
music fields put back from the file's when the next tape has no music),
the show module's in its copy. The planner then takes the parts in tape
order (the tune, the picture's screen, colours and bitmap, the module's
parts with the main one last) and the claims (24 ranges at most) that
decide which of the program loads while the show runs.

**A `.sid`'s trial run** (`trial.asm`, in SID-SLM; SlopLoad 64 itself
takes only `.slm` files): a 6502 emulated in 6502, with
the tune's memory virtual (its pages read where they sit in the music
pool, at $4000 in SID-SLM, copied on a write; other RAM made on first write; I/O reads
answered as the PC's simulator does), so a tune at $1000 can run on top
of the program's own code. SID-SLM then writes the `.slm` (version 2,
the format `tools/sidstrip.py` writes) with what it found and no
relocations; `tests/sidslm.py` compares each with the PC's check of the
same 3,000 calls, field by field. It notes the zero page and workspace written,
the stores the loader can't allow (then taken out and the tune run
again: the same SID writes, or it is refused), calls outside the tune,
and the longest play call in real cycles, as `tools/sidstrip.py` does
on the PC. It is 3,945 bytes (dispatch and decode tables built in its
scratch at $A000-$BFFF each run), about 35 host cycles an emulated
one: 3,000 calls of the SlopLoad tune take 117 seconds on a C64.
`tests/trialtest.py` runs it in `tests/sim6502.py` and in VICE against
`sidstrip.strip()` (lockstep: every instruction's registers, flags and
clock compared) on the project's tunes, 30 from the HVSC and synthetic
ones for each refusal: the same results, but for two things it does
differently. It refuses the undocumented opcodes other than lax, sax and
the NOPs (the PC runs slo, dcp and the rest too; about one tune in 400
uses any), and a store that hits both I/O and memory, or one whose
opcode the tune rewrites, is caught by the patched second run instead
(refused for playing differently, not for its own reason).
`tools/sidfile.py`'s simulator counts real cycles too (`play_clk`,
which is what `.slm` files hold since version 2); it used to count
instructions, about 3.4 times fewer.

**What it writes.** The PC tool's format; the coding chosen the same way
(`choose()` in the model): every pulse set from the block's least h up
to 124, m from 2 to 4, every pulse 208 cycles or more; 2 bits a pulse
with each bit pair's best key, or the prefix code with the key that gives
more 1 bits; the quickest first, and with a module running the first that
keeps the loader within the module's share of the CPU in every frame's
worth of tape (integer windows of 19,656 cycles). On the C64: `anablk`
counts the bit pairs and the bits, codes the block both ways to get each
one's length, and walks six lists (2 bits or prefix, m 2-4, each by h)
merged by length; the share check slides a window over the body's bytes
(2 bits) or pulses (prefix) with per-element tables of cycles and cost.

**Two layouts.**

| | written a block at a time | in one go |
|---|---|---|
| when | to a cassette, no expansion memory | a .tap file; a cassette from an REU or SuperRAM |
| pilot | 0.5 s (the motor restarting), 2.0 s after the module stops | 0.25 s for the first block, then 0.08 s (the PC tool's); 2.0 s after the module stops |
| after a block | a 0.1 s trailer (class 0 pulses of its set): the motor's stop falls after the data | the bridge, a byte $0F in its set; only the last block has a trailer |
| 63 KB, Crossy-Load, speed 0 | 188 s | 178 s (the PC tool: 171) |

**The writer** (`writer.asm`). CIA 2's timer A runs continuously; the
latch takes each half pulse. At each underflow the line on $01 bit 3
toggles: at a pulse's start the handler (`hcall`) gives the next pulse's
half, at its middle the latch takes it and the bookkeeping (`house`)
runs for the pulse just taken. Only the pulse's start edges are timed
(the read side measures start to start), so a handler may run past the
middle, but handler and bookkeeping together must end within the pulse.
The shortest pulse is 208 cycles (104 a half), which is why PMIN is 208.

The tape is a list of 8-byte sections: runs (a pilot and its sync, the
KERNAL's leaders: a count, a half, the last pulse's half) and dibits
(bytes, 2 bits a pulse, through a table of 4 halves; one switch to a
second table after a given number of bytes, for a header in set 4 and a
body in the block's set). Switching sections costs up to about 180
cycles, so a switch must happen during a long pulse: a run hands over in
its last pulse (a sync, 10h; or the KERNAL's L); a dibits section ends at
the tape's end, on the KERNAL's short pulses, or on the bridge, whose
third pulse (class 3) is where the switch to the next pilot happens.
Tables are made as needed, one per quantum and pulse set on the tape (64
at most), so a whole tape's sections can be listed at once.

**From expansion memory.** Each block is laid out (header, body, bridge)
and put in a stream: an REU stash checked with its verify, or SuperRAM
written a byte at a time with long addressing (`sta [xp],y`). Its
sections say "the stream's next n bytes" (type 3). Writing, an REU is
read a byte a DMA, the C64 address held (`$df0a` = $80): the next byte
is fetched half way through the one before, so taking it costs a load.
Every REU command is followed by an I/O read (`bit $d020`), which a
SuperCPU needs before the transfer happens. SuperRAM is the free area in
CMD's variables at `$d27c`-`$d27f`; an REU is sized by writing each of
16 banks' first bytes (their old contents put back).

**Accelerators** (`detect`, `fast`, `slow`). A SuperCPU (opcode $3a,
then `$d0bc` bit 7) runs at 20 MHz with every write mirrored; an
Ultimate whose `$d031` answers gets `$0f` there while coding; a C128
(`$d030` bit 0 follows writes) gets 2 MHz from a raster interrupt at
line 251 to one at line 44, the picture at 1 MHz. `slow` before every
disk access and before the tape: the serial bus fails at 2 MHz. A
SuperCPU can't drive the datasette (the tape lines are the 6510's own
port, which it replaces; VICE's SuperCPU has no tape port either), so it
writes .tap files only.

**Memory.** The tool and what it writes to tape (the loader's core and
stage 1, the show module) from $0801 (about 23 KB); its buffers after
them (the KERNAL file's symbols, a block of 4,300 bytes, the block
table), then the music pool (17 pages), below $A000; a tune's file as
read, the trial's scratch, or a block in the prefix code at $A000-$C0FF
under the BASIC ROM (switched out); the section list and the pulse
tables at $C100-$C5FF; the show module moved to $CB00; and the module
or the picture read from disk into the RAM under the I/O and the
KERNAL, $D000-$FFF9.

## 12. The TAP writer

`c64/tapwriter.asm`, on the SlopLoad 64 disk: any .tap to a cassette from
a C64 with an REU of 512 KB or more (`machine.asm` sizes it, up to 16 MB).
A tape needs a byte every few hundred cycles, and the KERNAL's serial bus
gives one every few thousand, so the whole file goes into the REU first,
a page at a time. On the way in, a version 1 long count that fits a byte
(under 2,044 cycles, which is every pulse of a `-hires` tape) becomes
that byte, rounded to 8 cycles; true pauses stay as 0 and three bytes. So
the REU never needs more than the file's size, and the writer's common
path is one byte a pulse.

**Writing.** CIA 2's timer A runs continuously; each pulse is two equal
halves, so the latch is written once a pulse. At a pulse's start (an
underflow) the write line goes high and the byte two pulses on is
fetched (one byte's REU DMA into a held address); at its middle the line
goes low and the next pulse's half goes into the latch from two
256-byte tables (4n - 1 for a byte n). That is about 35 cycles in each
half, so pulses down to about 100 cycles are written on time; SlopLoad's
shortest is 168. VICE records a pulse at each rise of the line, which is
where each pulse starts here.

A 0 (a long count, or a version 0 overflow, 2,048 cycles): the pulse
starts with a 512-cycle chunk while the three bytes are fetched and its
halves worked out (2,048 cycles at least; the low half c/2, or 32,768
from 131,072 on), then the rest of its high half in chunks of up to
32,768 cycles with the line left high, then its low half. A 3-second
pause is about 90 chunks.
