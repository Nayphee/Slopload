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
screen off (the path that completes a byte, crosses a page and moves the
quantum is 167, `tests/irqcycles.py`), 208 with a module (bad lines
stretch the interrupt). Not every path is under 168: a prefix-code pulse
that completes a byte on its third bit, with the page crossing and the
speed step both, takes 187, and 205 on a block's last byte. Those come
perhaps once in tens of kilobytes; the next edge is then taken up to 19
cycles late (37) and the pulse after it read that much short, inside
the +-44 cycles of the fastest set, and only at the top speeds with the
screen off (with a module the shortest pulse is 208). The test sweeps
every state and fails if that overrun passes 40 cycles.

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
| a Koala picture, speed 0 (measured again, 2026-11-06) | ±49 | 51 |
| ... with one sprite on its lines | ±54 | 59 |
| ... one twice as tall | ±55 | 60 |
| ... two side by side | ±59 | 64 |
| ... three side by side | ±62 | 68 |
| ... four side by side | ±67 | 73 |
| ... eight, twice as tall | ±97 | 118 |
| music alone, screen off (the show module) | ±6 | 8 (and a few edges at block starts, as with the screen off) |

So modules used no sprites at first (Invade-a-Load has none either),
and a module states its jitter in its header (byte 12; all three say
48). Since 2026-11-06 a module may have up to two sprites on a line,
counted in its jitter (8 cycles for one, 16 for two: the loader's pilot
window takes 64 in all); the show module's loading sprites (`-sprite`)
are the first. The
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
- **Measure:** stage 1 and the core time pulses 17-80 (256h) with CIA1
  timer B counting from $FF7F, so its high byte is h rounded, and set
  CIA2 timer A to h; the core then times the next 64, and so on until
  the sync. 256h stays inside the 16-bit timer on NTSC at h = 124. 512h
  does not (65,903 cycles), and until 0.15.0 stage 1 still timed 128
  pulses: the slowest speed (-12) never got past stage 1 on an NTSC
  machine with a deck a hair slow, or on PAL with one 4% slow. A
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

The usual worst path (a pulse that completes a byte on its first bit,
crosses a page and moves the quantum, prefix code) is 167 cycles, under
the 168-cycle shortest pulse (the rarest combinations: above). To get there: the progress count moved to the foreground (the
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
error (pink when that colour is red itself: a border of solid red is
the user's to choose, and the error must still show; `errshow`'s 19
bytes are all used for it, `bset` in a branch's reach), then `bset`
after the core's end, which stores X only when the
border differs: on the 8565 (a C64C, VICE's default) every write to a
colour register leaves a grey dot on the border, so a store each time
round the wait would show. The border changes where `errshow` ran, in
the boot and final phases' wait loops; nothing is added to the
interrupt, so it costs nothing. 33 bytes differ from the core
(`tools/build.py`'s `flat_check` asserts where). Stage 1 is held at the
mode's colour (a style's first) for every mode but rainbow: its
`stx $d020` (`s1str`) becomes `bit`, and `s1bc` stores the colour once.
Where that colour is red, its tape error (`s1bad`, `lda #2` as built)
becomes `lda #10`, pink: the border is one colour then, so red on red
would show nothing (`slopload.py`, `c64model.py` and SlopLoad 64's
`mkhead`, with `cs1er`, the same byte).

## 7. Memory

| range | use |
|---|---|
| $02-$03 | `ld_state`, `ld_progress` (for the module) |
| $04-$0F | loader |
| $10-$8F | module (the music player uses $70-$7F) |
| $0200-$0258 | free for the module: the BASIC input buffer, which the program's start never reads (Crossy-Load keeps a buffer, two tables and four variables at $0200-$0254) |
| $0259-$02C2 | KERNAL variables, kept for the program's start |
| $02C3-$03FA | stage 1 (only until the core runs), but for its last 7 bytes, $02F9-$02FF: the exit's ioinit and RESTORE release (`s1ioi`), kept to the end |
| $0334-$0370 | exit code (copied there at the end) |
| $0400-$07EF | core (in the default screen's memory; the module shows its own) |
| module's claim | Flappy-Load $E000-$FBFF, Crossy-Load $CAEA-$CFFE and $E000-$FFF9, a tune in SlopLoad's player at $C000 (the demos: to $CA87) |
| $FFFA-$FFFF | interrupt vectors in RAM |

The program can use $0801-$FFF9: 250 disk blocks of 254 bytes. Bytes
inside the module's (and music's) claim go into blocks read after the
module has stopped. The motor is stopped while the player finishes; the
blocks after the stop have a 2-second pilot for the deck to get back up
to speed. A CD or MP3 player can't be stopped: `-nomotor` ends the
module as soon as the rest has loaded instead.

RESTORE is locked out from stage 1 to the program's start: stage 1
points the KERNAL's NMI vector ($0318) at an `rti` and enables cia2's
timer A interrupt, which it never reads; the timer runs from the first
edge (the quantum timer), so its first underflow pulls the NMI line low
and leaves it there. The 6510's NMI is edge-triggered, and the RESTORE
key shares that line, so a press makes no edge: no NMI can delay the
tape's interrupt. The exit stub calls `s1ioi` in place of the KERNAL's
ioinit: ioinit (the masks off, the timers stopped), then a read of
$DD0D, which clears the pending interrupt and frees the line for the
program. (TND's Loader Game Tape Master Kit 3 locked RESTORE out the
same way, with no release.)

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
+27 keeps     (byte) the module's: bit 0 the border to the loader (-showstripes),
                      1 effects on voice 3, 2 -wait, 3 -countdown
+28 options   (byte) set by the tool: bit 1 -wait (SPACE alone starts the
                      program), bit 3 -countdown (the status line counts
                      blocks); the show module: bit 0 -fade, 2 hires too
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

**The end: the music fades, in every module.** A game asks to end
through the kit (`startkey` at the load's end, `gk_done` at game over);
its frame's last call is `gk_exit`, which with music playing turns that
into the fade (`gk_fade` 1: the kit's `mplay` plays `fadekit.asm`'s
tick, which calls the tune's own play routine, `mplayr`) and returns
the carry set only when the fade is done (`fdone`), so the game plays
on for its 2.6 seconds. The loading screens drove the same fade
themselves and still do; the show module too. Each module includes
`fadekit.asm` where it has room, about 300 bytes and 84 of scratch:
Flappy-Load and Bounce-Load had none beside their code, so the fade is a
second part at $CE80 (below the module, past SlopLoad's player at
$C000), and Crossy-Load's low part starts $19B lower.

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

`modules/show/` covers the shows with no module file of their own (a
picture given as `-module`, with music or without, and a tune alone): about 1.8 KB, placed by the tool, which fills in the
song (byte 13) and the picture's background colour (byte 15, $FF for
none). A Koala picture is three parts loaded before it starts, with the
screen off (or, made to, it draws in: below): the screen to $CC00, the bitmap to $E000 and the colours
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

Since 2026-11-06 it has grown (about 1.6 KB, 1.7 claimed with the fade's
scratch), with features borrowed from Tape Master Pro, each a header
byte the tool sets:

- **+28, the ending and hires.** Bit 2: a hires picture ($D016 $08, no
  colour RAM part). Bit 1 (`-wait`): once loaded, `prompt` draws PRESS
  SPACE OR FIRE across row 24: the row's 320 bitmap bytes cleared, each
  letter's eight bytes read from the character ROM ($01 with I/O and the
  ROMs out but the character ROM, interrupts off: the tape is stopped)
  and each pixel doubled (a multicolour pair 11 is colour RAM's colour),
  starting at line 251 so the row changes whole (it takes about 220
  lines: done by line 160 of the next frame on PAL, 206 on NTSC, before
  row 24's 243); then a fresh press of SPACE or fire on port 2
  (`kheld`, `kup`: one held before the prompt doesn't count; `kdbg` for
  tests). Bit 0 (`-fade`): `tick` calls the kit's `fade` instead of the
  play routine, after the key if there is one, and `ending` returns
  carry only when it has set `exitreq`.
- **+29 to +75, the loading sprites.** $D015, positions, $D010,
  multicolour, expansion, $D025/$D026, the lines they cover, and a flash
  table (up to 32 colours, frames a step), all as the tool works them
  out; their bytes at the picture's bank + $3F40 (pointers $FD, $FE: the
  192 bytes after the bitmap, free in every bank). The pointers
  themselves (screen + $3F8, $3F9: bank + $0FF8) are in the screen's
  part, which is 1,024 bytes with sprites and 1,000 without
  (`slopload.py`'s `SPRITE_TAIL`, PICTURE-LM's `sptail`): the tools'
  claims come from the parts, so a program's bytes there load after the
  show. Until 0.15.1 they were in no claim, and a program that covered
  them wrote over them while the picture showed. `sprinit` still writes
  them, for a module made before. `sprchk`, called from
  the waits for a line or a frame, counts frames and writes the next
  colour only when the beam is outside the sprites' lines, and never
  when there is one colour (a store to a colour register each frame makes
  the 8565's grey dots).
- **+76, colours to copy.** A module file (PICTURE-LM's, `tools/
  picturelm.py`'s) can't load a part into colour RAM: its parts load
  into RAM. So the Koala picture's colours sit in the module's memory
  and `colcopy` puts them into colour RAM before the screen goes on.
- **+27 bit 6 and +28 bit 6, the picture drawn in** (2026-11-13, the
  user: "the bitmap memory to write to is first cleared with 0 ... loads
  up the picture's colour RAM, then afterwards loads up the video RAM
  ... During loading of the bitmap it draws across the screen ... Loads
  main game afterwards"; then "only ever intended to be an option").
  +27 bit 6 is its maker's choice (`-drawin`, PICTURE-LM's line 9); the
  tools set +28 bit 6 when such a picture is the first module, and order
  its blocks so
  (`slopload.py`'s `draw_split`, SlopLoad 64's `drawq`, `dpart`, `drawn`,
  `c64model.plan`): its code, a `.lm`'s colours (in the module's memory),
  the sprites and a tune first, the last of them with `f_gameready`;
  then colour RAM (the PC's own pictures: a block straight into $D800),
  the screen (bank + $0C00-$0FE7, to $0FFF with sprites: their
  pointers come again with it, the same) and the bitmap (bank +
  $2000-$3F3F),
  coded as the program's blocks while a module runs (the screen is on:
  its jitter, its share); then the program. `init` clears the bitmap
  (`pclear`, `pzero`: 31 pages and 64 bytes, about 40,000 cycles, before
  the screen goes on) and a hires picture's screen RAM (its 0 bits'
  colours) too, never the sprite pointers at screen + $3F8. With the
  bitmap 0, a multicolour picture's colour RAM and screen RAM show
  nothing as they load; the bitmap then appears byte by byte as the core
  stores it, a character row at a time down the screen. SlopLoad 64 cuts
  at fixed places ($CC00, $D000, $E000, $FF40: bank 3, as PICTURE-LM
  makes every picture) and adds the pieces it kept back last, the last
  kept first (screen, then bitmap). A tune starts with the module, so
  there is no music-first player for it. The cost: the picture's 9-10 KB
  at the screen-on pace, about 6 s more at speed 0 than loaded whole.
- **SlopLoad 64's copy stops at `drawcode`.** Everything only a picture
  uses (`colcopy`, `sprinit`, the `-wait` prompt and `kheld`, `pclear`,
  `pzero`) sits after the variables, from `drawcode` to `codeend`.
  SlopLoad 64's own show module (a tune alone, or the music first's
  player) never has a picture, so it keeps only the bytes before
  `drawcode` (1,204 of 1,773; 197 address bytes to move of 260, under
  `prshow`'s 255) and claims the whole module as before (the fade's
  scratch past `codeend` stays where it is). Only `init`'s picture
  branch and `ending`'s `-wait` path call past it. `c64model.show_module`
  does the same.

The core's `-cycle` is the core's, not the module's: three bytes at
`cycle` in `b_data`, on the page crossing (the interrupt's worst path),
`BNE` past themselves when off (3 cycles: 167 of the 168 the shortest
pulse allows) and `INC $D020` when on (the tool adds 3 cycles to the
shortest pulse). It runs whatever the phase, so with a module or show it
needs the border to be the loader's all through (`-showstripes`).

### Novaload's screech in PETSCII-Load

Novaload (as on Spy Hunter's Kixx tape) sets SID voice 1 to a sawtooth
($D404 $21) with sustain 15 ($D406 $F0), frequency low $F0 and the
volume at 15, and in its byte loop stores each byte it loads into
memory and into $D401 as well (`STA ($A5),Y : STA $D401`): the pitch
jumps with the data. SlopLoad's core stores a byte through a
self-modified `STA $FFFF` whose place differs between the cores
($0615-$061C), so a module can't watch it there; and the core has no
bytes to spare for a store of its own (nor should every tape's tune
lose voice 1 to it). What every core does keep, in the same zero page,
is the block's running XOR (`ld_chk`, $07, for the check byte) and the
bytes left (`ld_cnt`, $08): when `ld_cnt` has moved since the module
last looked, `ld_chk` XOR the value it last saw is the byte just stored
(two at once if it looked too late: their XOR). PETSCII-Load's frame
spends most of its time in two waits, for the vertical blank and for
the scroller's split lines, so `screech` is called in their loops: 18
cycles when off, about 40 when a byte came, many times a byte (one
arrives every 1,500-2,500 cycles). Measured in VICE: 99% of the bytes
exactly, PAL, NTSC and a C128; the split still lands in its rows. In a
pilot or a header the last pitch holds, as Novaload's does; once
`ld_state` bit 7 is set the gate goes off, and `stop` sets the volume
to 0. The module's settings byte (+35) has bit 2 for it (`petscii.py
-screech`, PETSCII-LM's line 9). It owns the SID: `init` doesn't start a
tune, and stops one already playing (+28 bit 4: the music first's or a
chain's) with the kit's `mstop`; the PC tool then cues a tune to a
second module (`-musicstart second`).

### Chains: two modules on one tape

`-module A -then B` (2026-11-06): A runs while B's parts load, then B
while the program loads. The user's case was a PETSCII screen with a
scroller and counter while a picture loads, then the picture. The
loader core didn't change; the core has 2 to 23 bytes free in its four
pages, too few for anything.

- **The switch is a module to the core.** The tool assembles
  `src/chain.asm` (112 bytes) for A and B's entry points and loads it to
  $0380 with A's parts. The tape buffer is free once the core runs:
  stage 1's header part ran there, and the core's exit stub, copied to
  $0334-$0371, goes there only after the modules have stopped. The
  core's `pt_init` is A's init, `pt_frame` and `pt_stop` the switch's.
- **The signal is a block flag.** The core ORs every good block's flags
  into `ld_ev`, and bit 2 was spare: B's last block carries `f_chain`
  ($04). The switch's frame tests it each frame and calls A's frame
  until it is set. Then it writes B's frame into the core's `pt_frame`,
  so from the next frame the core calls B directly and the switch isn't
  run again. It writes the program's step into `pt_step` and 0 into
  `ld_progress`; the program's first block comes 0.08 s later with its
  own progress byte. In the vertical blank it turns the screen off and
  puts the sprite registers and `$D016` back to the KERNAL's values. It
  calls B's init, which expects the screen off, as after the boot phase,
  then B's frame. Its `stop` is B's, or A's if the program is in before
  the switch (it never is: the tool refuses a chain where none of the
  program loads while B runs).
- **Progress.** While A runs, the core's step is B's parts' (`pt_step`
  for 512 bytes fewer than they are) and their blocks' progress bytes
  are scaled to match, so `ld_progress` is full ($FF, the core's cap)
  for the last two pages. A's header +26 is B's blocks, and PETSCII-Load
  shows 000 at $FF. Without that its counter would end at 001: blocks −
  ⌊blocks × 255 / 256⌋ is 1 for any number of blocks, and the 000 it
  shows once the program is in never comes for A. In a 48-block picture
  000 shows for about 45 frames.
- **The tune.** One tune for both. Its fields go into both headers, and
  B gets +28 bit 4: the kit's `sidinit` leaves the SID as it is and
  `musicgo` sets `musicon` without the tune's init; the show module
  skips its `sidclr` and init the same way. Measured (`tests/
  chaincheck.py`): the tune's init runs once; B's first play call comes
  a frame after the screen goes off for a picture, and three for
  Flappy-Load, whose init draws its screens.
- **Memory.** B loads while A runs: they can't overlap, and the tune
  must miss both (`SS.game_ok` against each, the tune placed clear of
  both). PETSCII-Load at $E000 overlaps every other module, so a chain
  builds it at $A000 (`petbase`; `tools/build.py` makes
  `petscii_chain.prg` beside the usual one, and its screen part is the
  same). The screen part's origin is a setting too (`lowat`): the
  assembler only moves forward, so the $A000 build assembles a copy of
  it at $9C00, which is thrown away. The program's live blocks come
  after the switch, so only B's claims and the tune's push its bytes to
  after the module; A's memory is the program's once B runs.
- **Speeds.** B's blocks load at A's margin (A's jitter) and A's share
  of the CPU; the program's at B's.
- **The switch's addresses in a table.** Its six (A's frame and stop,
  B's init, frame and stop, the program's step) are 12 bytes at its end,
  used through `jmp ()`, so a copy can be filled in without assembling:
  SlopLoad 64's payload carries it (`pl_sw`) and patches those bytes.
- **SlopLoad 64** chains too. Its module lives in the 12 KB under the
  I/O and the KERNAL, and a PETSCII screen with a picture is about
  16 KB, so it never holds B. Line 4 reads B with the same `ldgame` as A
  (A's 45 bytes of fields set aside with `gswap` and put back), keeps
  B's fields, its first 32 bytes and its claims, and leaves the high pool
  to be read again for A. When the tape is written, B's blocks come from
  B's file (a block's source 3: `readb`, channel 5), as the program's
  blocks come from the program's file. The motor is stopped while each
  block is read, so the disk has the time. The header bytes the tape
  needs (+13 to +28) are written over its first block as it is read.
  B's blocks are in its file's order, at A's jitter and share (the block's
  set byte's bit 1 picks `mdjit+1` and `mdshr+1`), and the program's at
  B's. To stay small it treats A's memory as the program's after-the-
  module memory too (the PC tool loads those bytes while B runs).
  `tools/c64model.py` (`then=`) is the reference, and SlopLoad 64's tapes
  match it byte for byte, to a cassette, a .tap and from an REU.
- **Room for it: SlopLoad 64's messages packed.** SlopLoad 64 had about
  700 bytes before its music pool ($8D00 on, 17 pages) would pass $9FFF;
  the chain took about 1,500. Its 2.6 KB of messages now go through a
  table of 64 pieces chosen at the build (`tools/c64words.py`: greedy, by
  the bytes each saves, pieces of 2 to 14 characters, two halves of
  under 256 bytes). In a packed text the bytes $C0-$FF (unused: no text
  has capitals) are pieces, and `print`'s character routine (`prch`,
  `c64/words.asm`) prints them. That freed 855 bytes. A text is packed
  only when everything that uses it prints it: a label used at an
  offset (`tx_with+2`, an empty string at its end), read a byte at a time
  or given to `setnam` is left as it is, and the build checks each
  packed text decodes to its source. The other C64 tools set
  `prch = chrout`. 91 bytes were left; when pictures became modules
  (PICTURE-LM's, on line 3) SlopLoad 64's own picture reading and its
  bank search went, and about 1,240 are left (the second module's own
  line, 4, took some back).
- **PETSCII-LM** writes A at $A000 when its line 8 says so: the two
  builds differ in 149 bytes, all addresses' high bytes $40 apart, so it
  flips them (EOR $40) in its copy around the writing; the table is
  `tools/c64build.py`'s, from the two builds.

### The music first: a stage before the module

Asked to "play music first before anything else loads" and that "when
music is playing, it should continue playing throughout the load" (the
user, 2026-11-13), the tools make it the default with a tune and a
module. The core had no room for a player of its own (core_fx fills its
1,024 bytes), but it calls the module through vectors, as a chain's
switch shows, so a stage can go first without touching it:

- **The stage is the show module** (the tune alone's), placed clear of
  the tune and the modules, its parts the boot's last: the tune, then
  it, the screen off. The core starts it as its module (pt_init, frame,
  stop); it plays the tune, its pacing by raster lines as always.
- **The module's parts load while it plays**, at the boot's speed and
  the tune's CPU share (SlopLoad 64: block set 5).
- **The hand-over** is the stage's: when `ld_seq` (good blocks) reaches
  its header's +78, it copies the module's frame, stop and progress step
  (+81 to +86) to the core's vectors, which sit side by side in the same
  order, zeroes the progress, then calls the module's init (+79) and
  jumps to its frame. No new block flag: `f_chain` stays the switch's,
  so a chain after the stage works unchanged (the stage hands over to
  the switch's frame).
- **The module plays the tune on**: +28 bit 4, as a chain's second.
  Its init drew for 2-4 frames with no play call, a stumble the user
  would hear; the kit's `gk_keep` (in long init loops) plays the tune at
  each new frame meanwhile, `gk_kend` (init's last call) lines the next
  call up a frame on, and `gk_exit` bridges to the module's own first.
  Measured: play calls 0.27-1.31 frames apart on PAL through the
  hand-over and a chain's switch.
- **SlopLoad 64** builds the stage in its high pool at $F800, beside
  module A's parts (from $D000), so it needs A's file under 10 KB: every
  demo module, not a picture module (which plays the tune itself, after
  its picture). Its mkcore gives the stage the core's vectors and keeps
  the module's in the stage's header. 22 bytes were left.

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
raster's last line, the expansion memory), lines 1-9 one a row. A
number clears the screen, writes that line's number and name at its
top and asks its questions under it; the menu is drawn again after
them (after "press any key", where something was said). Answers are read key by key with GETIN (`io.asm`'s
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

**No stripes** (block, one colour) need `core_flat`, which has
the core's layout: its 33 differing bytes go in `payload.asm` as
(offset, xor) lists. `corefl` xors them into coreb and `corefd`, at the
start of every `mkcore`, xors them back, the same list both ways; so
that it can, `corefd` first puts `bflat` back as built (`ldx ld_seq`),
since one colour writes `ldx #colour` over it (`tests/c64modes.py`
makes the core in one mode after another and checks each). Stage 1
gets the PC tool's two patches.

**Colours and effect: two lines, one mode.** Line 7 picks the colours
(`opt_pal`: a style, rainbow to candy, or your own, `ownl`: a count and
1-12 colours, typed as `6,14,3` and parsed by `ownin`), line 8 the
effect (`opt_eff`, its number in the list: 0 none, 1 classic, 2 sloppy,
3-8 the other six of `slopload.py`'s FX, 9 block; sloppy, SlopLoad's
own stripes, is what it starts with).
`lnset` turns the two into the one mode the plan and the coder read
(`opt_lines`, with `opt_fcol`, `opt_fx`, `opt_fxb`), as
`c64model.lines_for()` does: none is `st_one` with the colours' first
(`stcol` of timer value 0: a style's, your own's, rainbow's black), so
a plain border needs no list of one colour, and no black palette (the
PC tool's `black` is left out of SlopLoad 64's styles, `c64model.STYLES`:
every use of it was rainbow with no effect, or rainbow under an
effect); sloppy draws a style's own number,
your own of one colour `st_one`, of more `st_own` (a
table style whose list is `ownl`: `stcol` reads it there instead of
from the cassette buffer); an effect starts from the colours' first
(rainbow's: 0, the PC tool's default); block is `st_block`. It also
switches the cycle off where it can't go (`cycok`: it goes with a plain
border, and with the effects it shows under, `fxcyc`: thin, eor and
line; the others change the border with every pulse), so the two
lines can be set in either order.

**The effect's 10 bytes.** `line` (`LDA #N : STA $D020 : LDA #B : STA
$D020`) needs two loads and two stores in the interrupt, where only A is
free: X holds the pulse's timer reading for the decoder, and Y is the
module's. So the slot where the core has `STX $D020` grew from 8 bytes
to 10, the 8-byte effects ending with `CMP #$00`; core_fx fills its
1,024 bytes to $07FF, and SlopLoad 64 makes it from the core by moving
the bytes past the effect up 7, not 5 (`cfxlong`). Each effect says
where its value goes (`fxval`: line's at its byte 1, and/ora/eor's at
4) and line where its border's colour goes too (`fxcof`, byte 6). Its
`-cycle` is a block's: stron, which every good block's end calls, has
its `LDA #colour : STA $D020` (5 bytes) made `INC` that byte : `CMP
#$00`, instead of the page crossing's `INC $D020`.

**Room.** The music pool's 17 pages must end by $9FFF, and the tool's
code and buffers come before it. Since the `.sid` trial moved to SID-SLM
(2026-10-30), the pool ends at $8AFF: 5,376 bytes free. What runs once at the start (`startup`:
the core to coreb, the patch to $033C, the NMI's rti, `detect`, and
`dibsum`, each byte's bit pairs summed, built in the page at $C600 that
the REU's sizing borrows first) sits after the payload, in what becomes
the buffers. The @ line (`adisk`, `dirshow`: the directory and the
command channel, through `dstat`'s) fitted in what that freed. So did
line 8's colours (`effsw`: each effect's run of colours from line 7's
first, `effn` a table of their lengths, sloppy's by `prswatch`, and,
ora, eor and line's by the value; `pcell` a cell, black a dark grey
check) when `detect` and its parts moved there too: `machdet.asm`,
split from `machine.asm`, after `startup` in SlopLoad 64 (about 440
bytes; the TAP writer and SID-SLM keep it after `machine.asm`).
Nothing the tool needs after its start may be there (from `bss`, the
core's place in the payload, on): the first tape fills those buffers.
From 0.14.0 to 0.15.2 the menu's title was (`tx_head`, made by the
build with the release's number and put last in `payload.asm`), in
what becomes the KERNAL header's second copy, `romh2`: once a tape had
been made the menu printed that block's pulses for its title, to the
next zero byte, control codes among them. `tools/c64build.py` puts it
before the core and stops the build if any label but the start's own
and the buffers' is at `bss` or after; `tests/c64tool.py` wants the
menu after every tape as it was before it.

**Drives.** Every file can be on a drive of its own. A drive's status
is read on its command channel, and closing that channel closes every
file open on the drive, so `dstat` (`io.asm`) opens a drive's once and
leaves it open: three files (13, 14, 15), each with its drive. A drive
asked again uses the one it has; a new drive takes one that is given
up, never the program's drive's nor the drive's a .tap is being written
on (`cmdkeep`, set by `tapopen` and cleared by `tapclose`). Three files
are open at once at most, a block at a time to a .tap: the program, the
.tap and a chain's second module. Until 0.15.1 there were two (15 for
the program's drive, 14 for "the other"): with those three on three
drives, the second module's status closed the .tap's drive's channel,
and the tape came out cut short with nothing said
(`tests/c64suite.py`: chain-three-drives). The module tools ask one
drive at a time; `wfile.asm`'s scratch sends its command on whichever
file `dstat` gave (`t6`).

**Modules, tunes and pictures from disk.** Nothing module- or tune-specific
is built in (the user's rule: others must be able to add their own). The
menu (`ui.asm`) reads a file when it is chosen (`files.asm`: a whole
file into memory, a drive's files listed by their ending):

| what | where it is kept |
|---|---|
| a module (`.lm`) | the RAM under the I/O and the KERNAL, $D000-$FFF9 (12 KB); read again if the show module was put over it |
| a tune's file (a `.slm`), as read | $A000 (then its bytes to the music pool; its relocations, if it has them, to $C700) |
| the tune | the music pool, 17 pages below $A000, at the same offset in its page as where it plays |
| the show module, moved to its place | made at $BC00, then to $F800 (past a picture in the high pool) |

`setup.asm`'s `prepare` turns the menu's choices into what goes on the
tape, as `c64model.setup()` does, rule for rule and in the same order:
the tune's checks (out of the loader's memory and I/O, its workspace
out of the loader's), beside a module its zero page, rate and longest
call, and its place (where it is, or for a `.slm` that can move the
highest page that works); for the tune alone, the show module's place
(the PC tool's `place_show` with no picture: the least of the program
under it), the module moved by its list of
address high bytes, and the loader's share from the tune's longest call
(integer arithmetic, so the model and the C64 agree to the byte). The
header bytes are patched in place: the module's in the high pool (its
music fields put back from the file's when the next tape has no music),
the show module's in its copy. The planner then takes the parts in tape
order (the tune, then the module's parts with the main one last, or the
show module for a tune alone) and the claims (24 ranges at most) that
decide which of the program loads while the show runs.

**A `.sid`'s trial run** (`trial.asm`, in SID-SLM; SlopLoad 64 itself
takes only `.slm` files; a PRG tune's too, read by `prghdr` from its load
address and called as SID-SLM's menu lines 3-6 say, its play times from
`sidstrip.py`'s `prg_rates` as tables `tools/c64build.py` writes into
`c64/slmgen.asm`): a 6502 emulated in 6502, with
the tune's memory virtual (its pages read where they sit in the music
pool, at $5B00 in SID-SLM, copied on a write; other RAM made on first write; I/O reads
answered as the PC's simulator does), so a tune at $1000 can run on top
of the program's own code. SID-SLM then writes the `.slm` (version 2,
the format `tools/sidstrip.py` writes) with what it found and no
relocations; `tests/sidslm.py` compares each with the PC's check of the
same 3,000 calls, field by field. It notes the zero page and workspace written,
the stores the loader can't allow (then taken out and the tune run
again: the same SID writes, or it is refused), calls outside the tune,
and the longest play call in real cycles, as `tools/sidstrip.py` does
on the PC. It is about 4.3 KB (dispatch and decode tables built in its
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

## 13. PETSCII-ED

A PETSCII screen editor (`c64/petsciied.asm`, with the tools' shared
`io.asm`, `disk.asm` and `wfile.asm`; its title line `peted.asm`, made
by `tools/c64build.py`), for the `.pet` files PETSCII-LM takes.

**Memory.** The program from $0801 (6 KB), a `.pet` read into a buffer
after it first (2,000 bytes: a file that is refused leaves the screen
as it was), the font at $3800-$3FFF (`$D018` $1E in VIC bank 0, as
PETSCII-LM's), the screen's codes at $4000 and colours at $4400. The
build stops if the buffer reaches the font.

**The editor** draws the screen on the C64's own ($0400, colour RAM)
and takes it back when it goes to the menu or to the characters (F1),
so the menu and the 256 characters can use the screen between. Keys are
read with GETIN, never through the screen editor: the KERNAL's cursor
is off (`$CC` not 0) and C= with SHIFT doesn't change the case (`$0291`
$80; set back on quitting), and the cursor is the editor's own: the
cell's character reversed in the pen's colour, by turns with the cell
as it is, every 16 frames of the jiffy clock. Before any key is acted on
the cell is put back (`curoff`), so what is read back or written is
never the cursor. A key is one of the editor's (a table of 18 codes and
their actions), a colour key (CTRL or C= with 1-8, the sixteen codes
PETSCII-LM's colour editor knows), or a character ($20-$7F, $A0-$FF,
made a screen code as PETSCII-LM's `p2s` does, $80 added with reverse
on). The 256 characters fill rows 4-19, columns 12-27; the rest of the
screen is spaces in the background's colour, so nothing else shows
whatever the font's space is, and the one chosen blinks between its
colour and the background's. No text is drawn there: in a font of its
own it couldn't be read.

**Files.** A `.pet` is read as PETSCII-LM reads one (40 x 25, a case of
0 or 1, the colours' low four bits) and written as the PC's
`tools/petscii.py` reads one: 40, 25, border, background, case, the
codes, the colours. The drive asked for a file becomes the screen's (or
the font's) only once the file is read or written, so RETURN alone at
a name keeps both. A font is read as PETSCII-LM reads one, so the editor
shows what the module will.
