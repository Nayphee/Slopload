# SlopLoad

A C64 tape mastering system: give it a program (`.prg`), get back an
autobooting `.tap` with a fast loader and a game to play while the program
loads. Or a `.wav` or `.mp3` of the same tape, for a CD, an MP3 player or a
PC.

SlopLoad is the loader. Add a game and the tape takes the game's name: with
the Flappy Bird-style game it is **Flappy-Load**, with the Crossy Road-style
one **Crossy-Load**, the way Mastertronic's loader with Space Invaders was
Invade-a-Load. A game is a module: whatever runs while the program loads.
A loading screen is one too, and others can be dropped in.

How it works, what was taken from Invade-a-Load, slushload and Gyrospeed,
and the tape format: [DESIGN.md](DESIGN.md).

No PC? **SlopLoad 64** masters the same tapes on a C64 itself, straight to
a cassette or to a .tap file: see [SlopLoad 64](#slopload-64-mastering-on-a-c64).
Many programs on one cassette: see [Tape sides](#tape-sides-many-programs-on-a-cassette).

## Quick start

From a release (`slopload-0.4.0.zip`: unpack it anywhere) everything is
built already: go straight to mastering. You need Python 3.8 or later;
MP3 output also needs GStreamer (`gst-launch-1.0`). The C64 side is on
`build/slopload64.d64` and `.d81`. What's new in each release:
[CHANGES.md](CHANGES.md).

From the sources:

```bash
python3 tools/build.py
```
Builds stage 1, the core and the modules into `build/`
(`python3 tools/c64build.py` then makes SlopLoad 64 and its disks, with
VICE's `c1541`).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -filename "MY GAME"
```
Masters a tape: `LOAD` (or SHIFT+RUN/STOP) loads it. After the KERNAL
finds the file, the screen goes to border stripes for a few seconds while
the game loads, then Flappy-Load starts with a loading bar under it. When
the program is in, the status line says **LOADED! PRESS SPACE TO START THE
GAME**: SPACE starts it at once, or play on, and it starts when the bird
crashes. If you never started a round (the bird still bobbing on the title
screen), the program starts as soon as it's in.

Controls: fire on the joystick in port 2 to flap. S turns the music on and
off.

`-module crossy` gives **Crossy-Load** instead: hop a white hen up an
endless run of lanes (grass, roads, rivers with logs to ride, railways
with trains). Fire hops one lane forward; left and right on the
joystick walk her sideways (on the ground or mid-hop, two columns short
of each edge), so she can step out of a car's way or along a log. The
screen creeps up by itself,
faster as the score grows, and a hen it catches at the bottom is shoved
forward into whatever is in front of her: traffic, or the river if no log
is there. Carried off the edge on a log, she's swept away. Two rivers
side by side always flow opposite ways, so their logs keep coming into
line. When she dies, everything stops where it is. The same rules
for starting the program: SPACE once it's in, or it starts when the hen
dies, or at once if she never left the start.

`-module ozgold` isn't a game: it is **OZ GOLD**, a loading screen in the
style of U.S. Gold's Novaload one, for Australians. The Australian flag
in PETSCII (the C64's own character set), OZ GOLD in U.S. Gold's own
block letters, ALL AUSTRALIAN SOFTWARE on green and gold, and BLOCKS TO
LOAD counting down to 000 as the program comes in. It plays its own
medley (Advance Australia Fair, Waltzing Matilda and Bound for Botany
Bay; `-sid` plays your tune instead, S turns it off). Once the program
is in, BLOCKS TO LOAD stays at 000 while the music fades out, about 2
seconds, as Novaload's did, and then the program starts (with
`-autorun`, at once). It's an example of a module that does something
other than play a game (MODULES.md).

**A PETSCII screen of your own** shows the same way: give the file as
the module.

```bash
python3 tools/slopload.py prog.prg prog.tap -module myscreen.petmate
```

It's PETSCII-Load: your screen, the music (`-music N`, `-sid FILE` or
`-music none`; S turns it off), and the border red during a tape error.
Once the program is in, the counter stays at 000 while the music fades
out (about 2.6 seconds; with no music, 000 for 1.3 seconds), and then the
program starts. With `-autorun`, or `-nomotor` when part of the program
loads after the screen goes, it starts at once instead (the counter at
000 for a frame first): the tape can't wait. Two things can go on it, as on
U.S. Gold's Novaload screens:

```bash
python3 tools/slopload.py prog.prg prog.tap -module myscreen.petmate \
    -scroll "WELCOME TO MY GAME ... " -scrollrow 24 -counter 22,25
```

- **A scrolling message** (`-scroll TEXT`): smooth, across one row
  (`-scrollrow`, 0-24, default 24), `-scrollspeed` 1-4 pixels a frame
  (default 2). It takes that row's colours from your screen, so a row
  painted in a rainbow in Petmate gives a rainbow scroller. The colours
  stay where they are while the message moves through them (colour
  memory doesn't scroll). `-scrollcolours HEX` sets them instead,
  whatever the screen has there (a row of spaces in Petmate hides its
  colours): a hex digit a column (the C64's colour numbers, 0-f) from
  column 1 on, repeated if shorter than the row's 39 (`7`: all yellow;
  `e3e1`: light blue, cyan, light blue, white by turns). Column 0 is
  always the background's: the message leaves the row there. The rows
  next to it are cleared (spaces) if anything is on them, and the tool
  says so: the scroller splits the screen, and while the loader runs
  the split can land a few lines late, so whatever is on those rows
  would shake. The note lists the rows that need nothing cleared. `{n}`
  in the text is screen code n (`{83}`: a heart).
- **A block counter** (`-counter ROW,COL`): three digits there, in the
  screen's colours, counting the program's disk blocks down to 000 as it
  loads (the ones that load while the screen shows: a program that
  reaches into the screen's memory loads that part after it, with the
  screen off). Draw `BLOCKS TO LOAD` (and a box, as U.S. Gold did) on the
  screen yourself, and leave the three cells for the digits.

Draw the screen in
[Petmate](https://github.com/nurpax/petmate) (its own `.petmate` file,
the first screen in it, or `-module` with a `.pet` export) or Marq's
PETSCII editor (its `.c` file): 40 x 25 characters in the C64's own
upper case or lower case set, or in a font of your own. `-module petscii` shows the demo screen
(`modules/petscii/demo.pet`). For SlopLoad 64, make the screen into a
module: `python3 tools/petscii.py myscreen.petmate myscreen.lm` (or
PETSCII-LM on the C64, below); it takes the same `-scroll`,
`-scrollrow`, `-scrollspeed`, `-scrollcolours`, `-counter` and `-font`.

**A font of your own.** A screen drawn in a font imported into Petmate
(a `.64c` file) brings the font with it in its `.petmate` file. For a
`.pet` export or a `.c` file, give the font as well:

```bash
python3 tools/slopload.py prog.prg prog.tap -module myscreen.pet -font myfont.64c
```

A `.64c` is read as Petmate reads one: a load address, then up to 2,048
bytes, 8 a character (a shorter file leaves the rest blank). The module
keeps only the characters it shows (the screen's, the message's, a
space with a message and the digits 0-9 with a counter), numbered
again from 0, so a font usually costs a few hundred bytes rather than
2 KB: up to 128 characters sit at $B800, just below the screen, and
more at $B000-$B7FF. A program reaching into them loads that part after
the screen goes, as for the screen's own memory. The tool says how many
it kept. The message's letters, its spaces and the counter's digits are
the font's characters at the C64's own places (A at 1, the space at 32,
0 at 48); `{n}` gives any other.

A program can be up to 250 disk blocks: $0801-$FFF9. The report says how
many blocks it is and how many load while the module runs; the rest (the
part that falls in the module's memory) loads after it.

## Options

| option | default | |
|---|---|---|
| `-filename "NAME"` | the .prg's name | what the KERNAL shows when it finds the file |
| `-show MODE` | `module` | what shows while loading: `module`, `none`, `picture`, `picmusic`, `music` (below) |
| `-picture FILE.koa` | | the Koala picture for `-show picture` and `picmusic` |
| `-module NAME\|FILE\|none` | `flappy` | the module for `-show module`: `flappy`, `crossy`, `template`, `ozgold` or `petscii` (built ones live in `build/modules/`; your own: MODULES.md), a module's `.prg` or `.lm`, or a PETSCII screen (`.petmate`, `.pet`, Marq's `.c`): shown while it loads; `none` = `-show none` |
| `-speed N` | 0 | -12 (the most margin) to 13: slushload's speed scale, and below it (below) |
| `-bootspeed N` | as `-speed` | the same for the parts loaded with the screen off |
| `-music N\|NAME\|none` | the first song | the built-in music: `0` Enigma Street, `1` SlopLoad; `none` frees its memory |
| `-scroll TEXT` | | with a PETSCII screen: a scrolling message; `-scrollrow N` (default 24), `-scrollspeed N` (1-4, default 2), `-scrollcolours HEX` (its row's colours, a hex digit a column from column 1, repeated; default: the screen's) |
| `-counter ROW,COL` | | with a PETSCII screen: a block counter's three digits there |
| `-font FONT.64c` | | with a PETSCII screen: drawn in a font of its own (a `.petmate` screen in an imported font brings it with it) |
| `-sid FILE` | | your own SID tune instead (`.sid`, or a `.slm` from `tools/sidstrip.py`): see Your own music |
| `-song N` | the file's start song | which song of the SID file |
| `-stripes STYLE` | `rainbow` | the border stripes' colours while the screen is off (below) |
| `-start ADDR` | RUN | start with JMP ADDR instead (needed if the program isn't at $0801) |
| `-status VAL` | $37 | $01 for `-start` |
| `-autorun` | off | start the program the moment it's loaded, cutting the module off |
| `-nomotor` | off | for players the C64 can't stop (CD, MP3, PC): see below |
| `-blocksize N` | 4096 | bytes per block; a tape error costs rewinding about one block |
| `-leader N` | 27136 | KERNAL leader pulses (the standard 10 seconds) |
| `-precomp FILE` | | pulses written against a measured deck (see below) |
| `-hires` | | exact cycle counts in the .tap |
| `-rate N` | 44100 | sample rate of a .wav or .mp3 |
| `-bitrate N` | 320 | MP3 bitrate (kbit/s, constant) |
| `-invert` | | the sound's polarity swapped |
| `-info FILE` | | decode a SlopLoad .tap, .wav or .mp3 and list its blocks |

### What shows while loading

| `-show` | the C64 shows | Battle Royale, speed 0 |
|---|---|---|
| `none` | border stripes, screen off: the fastest | 75 s |
| `music` | music, screen off (the border lightens as it loads) | 79 s |
| `picture` | a Koala picture (`-picture FILE.koa`) | 113 s |
| `picmusic` | the picture and music | 117 s |
| `module` | Flappy-Load (and its music) | 111 s |
| `module`, `-module crossy` | Crossy-Load (here with `-sid` and the SlopLoad tune) | 115 s |

From PLAY to the program running, with the 18-second KERNAL boot. The
screen being on is what costs: the VIC's bad lines delay the loader, so
with a picture or a module each pulse needs more margin. Music alone keeps
the screen off and loads nearly as fast as `none`. With a picture or
music, the program starts by itself once it's in; with the game, SPACE
starts it, or it starts when the bird crashes (or at once, if no round was
started). A tape error shows as a
red border (as TAPE ERROR on the game's status line).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -show picmusic -picture loading.koa -music 1
```

For a picture to try, `pictures/slopload.koa` is SLOPLOAD in rainbow
letters (drawn by `pictures/mkslopload.py`); it is on SlopLoad 64's
disks too.

### Speeds

The speed numbers mean what they mean in slushload: speed N leaves a
margin of ±(19 − N) × 4 cycles for timing errors in playback. Speed 0
(±76) is the default: on a real datasette a little out of alignment it
loaded every time, speed 5 needed a rewind once, and speed 13 didn't load;
and the faster speeds save less than the margin they give away (table
below). The higher speeds are for playback without a tape's wow and
flutter.

**Below 0**, for a deck that speed 0 is too tight for (or a slower load
on purpose), -1 to -12 go on down the same scale: 4 cycles more margin
a step, to ±124 at -12, whose longest pulses are as long as the loader
takes. Their pulses are longer, so they also sit lower in frequency,
which is what a badly aligned head loses first. Through a modelled dull
head (the sound filtered at one pole), speed 0 loads down to 1.9 kHz,
-6 to 1.6 kHz and -12 to 1.1 kHz. They don't help with wow or flutter,
which stretch every pulse by a share of its length. They slow only the
parts loaded with the screen off: with a module or a picture showing,
speed 0 has the most margin the loader takes already (76 plus the module's
jitter), so below 0 is speed 0 there.

| playing from | speed |
|---|---|
| a cassette | 0; faster after measuring the deck (Real cassettes, below) |
| VICE, an Ultimate, a TAPuino | 13 |
| a CD, or an MP3 at 192 kbit/s or more | 13 |
| an MP3 at 128 kbit/s | 5 |

Every speed is at least as fast as the one below it. A running module
costs speed in two ways:

- **Timing:** the VIC stops the CPU for 40-odd cycles on every 8th raster
  line, which delays the loader's interrupt. So while the module runs, the
  tool adds the module's measured jitter (48 cycles for Flappy-Load) to
  the margin: the tape keeps speed N's margin even at the module's worst
  moment.
- **CPU time:** the loader's interrupt runs on every pulse. The module says
  how much of the CPU it can give up (35% for Flappy-Load), and the tool
  keeps every frame's worth of tape within that, so the module never drops
  a frame.

Rates for a 63 KB program, PAL, bytes per second:

| speed | random data, screen off | with Flappy-Load | zeros, screen off | with Flappy-Load |
|---|---|---|---|---|
| -12 | 455 | 449 (as 0) | 948 | 766 (as 0) |
| -6 | 563 | 449 (as 0) | 1175 | 766 (as 0) |
| **0** | **670** | **449** | **1394** | **766** |
| 5 | 793 | 534 | 1408 | 848 |
| 9 | 832 | 535 | 1408 | 866 |
| 13 | 832 | 585 | 1408 | 866 |

Packed programs behave like random data. Invade-a-Load is about 300.
The top of the scale is flat because the loader's interrupt needs a
pulse of at least 168 cycles (208 with a module) whatever the margin.

### Border stripes

While the screen is off (all of `-show none`, and the few seconds before
a module or picture appears) the border flickers with the tape, a colour
for each pulse length. `-stripes` picks the colours:

| style | colours |
|---|---|
| `rainbow` (default) | the pulse's own timer value: black, white, red, cyan, purple, green, blue, yellow, orange, brown, light red, grey |
| `mono` | black, white |
| `c64` | blue, light blue |
| `blue` | blue, light blue, cyan |
| `red` | red, light red |
| `green` | green, light green |
| `fire` | red, orange, yellow |
| `ice` | blue, light blue, cyan, white |
| `grey` | dark grey, grey, light grey |
| `sunset` | purple, red, orange, yellow |
| `stealth` | black, dark grey |
| `gold` | brown, orange, yellow |
| `candy` | light red, purple, light blue |
| `black` | no stripes: the border black all through |
| `block` | no stripes: the border a colour a block, the next colour with each block (through all 16) |

Or your own: `-stripes 6,14,3` (colours 0-15, up to 12). Each colour
covers two neighbouring pulse lengths, so the bands change with the data.
These styles look the colour up in a table, which makes the loader's
interrupt 4 cycles longer: its shortest pulses grow to match, and a
screen-off load is up to about 7% slower. `rainbow`, `black`, `block`
and a single colour of your own (`-stripes 6`: a flat blue border) cost
nothing.

Every style but `rainbow` also holds the first few seconds (stage 1,
loading the loader) at its first colour, so a black border is black from
the moment the C64's own loader hands over. Before that, while the C64's
own loader reads the tape's first file, the border is the C64's (light
blue unless the program before changed it): nothing of SlopLoad's runs
yet. A tape error turns the border red in every style, until the loader
recovers.

### Your own music: SID tunes

```bash
python3 tools/slopload.py mygame.prg mygame.tap -show picmusic -picture loading.koa -sid tune.sid
```

Any PSID file (the HVSC's format) can play with `-show music`,
`picmusic` or `module`. The tool runs the tune in a 6502 simulator first,
and:

- **makes it safe beside the loader:** stores the loader can't allow are
  turned into no-ops (many tunes set $01 for a moment, which would stop
  the tape motor; CIA-timed ones set a timer, whose rate it keeps), then
  it checks the tune still writes exactly the same to the SID;
- **moves it** where it costs least: a tune at $1000 sits on most
  programs, whose bytes there would have to load after the show. If the
  tune can move, it goes to free memory (high memory, clear of the
  picture and the show module), and the moved tune is checked again in
  the simulator against the original;
- **plays it at its rate:** once a frame, or 60 times a second for a
  CIA-timed tune, or faster (16 times a second at least); on PAL and
  NTSC.

All this takes about 20 seconds; the result is kept (in
`~/.cache/slopload`, by the file's contents and the song), so mastering
with the same tune again takes a second.

What can't play, and the tool says why: RSID tunes (they take over the
interrupts, which the loader owns), tunes for two or three SID chips,
tunes that bank I/O out or call the KERNAL or BASIC ROM, and tunes that
use the loader's zero page ($02-$0F). Of 400 random HVSC tunes, 77% play
as they are; of 200, 90% of the PSID ones can be moved.

With a **module** the tune must also play once a frame, take at
most 3,700 cycles a call (the built-in tune: 2,251), keep its zero page
out of the module's $10-$8F except $70-$7F (the music player's, there for
a tune), and sit clear of the module's memory or be movable (the tool
moves it). A game's sound effects are off with a SID (it uses all
three voices).

The two steps are tools of their own as well:

```bash
python3 tools/sidstrip.py tune.sid tune.slm
```
Checks and patches a tune once and writes it as a `.slm` (SlopLoad
music): the tune, its rate, its zero page and workspace, its longest
play call, and the bytes to move it. `-sid tune.slm` then masters
without simulating again, and SlopLoad 64 takes it as it is. (The
simulator counts real cycles since October 2026; it counted
instructions before, about a quarter as many. An older `.slm` (SLM1)
still works on the PC, its figure times 4; SlopLoad 64 asks for it to be
made again.)

```bash
python3 tools/sidstrip.py big.sid song3.slm -song 3 -cut
```
Keeps only one song of a tune with many. Such a tune is one player and
the data of all its songs, so the whole of it can be well over SlopLoad
64's 4 KB while each song uses only part of it. `-cut` keeps the memory
pages the song uses in five minutes of play (and those of the code its
branches could reach), packs them together, moves every address in them
with its page, and plays the cut tune beside the whole one: the SID
writes must be the same, frame by frame, or it says the tune can't be
cut. Where the tune makes an address by adding pages to one of its
own (a table's base plus 2 pages), the pages between are kept too, and a
copy loop's compare with the page past the end moves with the pages.
Song 3 of Golden Axe (23 songs, 14,070 bytes) comes to 4,577 bytes, 18
of its 55 pages; song 1 of Mono (8,318 bytes) to 1,647. The report says
whether the result fits SlopLoad 64; it can be moved like any `.slm`
from the PC. In a trial of 48 HVSC tunes of 4.4-16 KB with three songs
or more (songs 1-3, a minute of play each), 103 of the 144 songs cut and
passed every check, 55 of them to 4 KB or less, with at least one song
of 24 of the tunes; one was refused by the cut (Fox Fights Back reads
its own code as a table), the other 40 for what the whole tune breaks
too (mostly the loader's zero page). What a song only does after five
minutes isn't seen: `-frames 30000` watches ten. SID-SLM does the same
cut on a C64 (SID-SLM, below), in half an hour or so.

If that cut is still over 4 KB, `-cut` tries once more, **as the tune's
init leaves it**. Some tunes keep every song in one place and have init
copy the chosen one to where the player reads it: The Last Ninja's init
copies the song's 4 KB to $B000, and play only reads that copy, but the
first cut has to keep the source too, since that's where init found the
bytes. So the tune is taken as init left memory, from its first page
(or the lowest one init wrote) to its last (or the highest), with a
short init of its own on the page after: it puts back the zero page
init wrote, repeats init's SID writes and CIA 1's timer if init set
one, and returns. That tune is cut as before, its longest run of pages
kept where it was and the others packed round it, the new init just
after the last byte kept, and it must play exactly as the whole tune
does. The report says when a cut was made this way (`cut to this song
as its init leaves it`). Song 5 of The Last Ninja comes to 3,808 bytes
(the first cut: 4,387), and 10 of its 11 songs fit in 4 KB (song 4
stays 7 bytes over). A tune whose init sets up more than a page's
worth of zero page and SID writes can't be cut this way (Golden Axe).
Song 5 has one more catch: when it ends and starts again, 4 minutes 36
seconds in, one play call takes 12,334 cycles, too long for the loader
to run beside, so SlopLoad refuses it as music (`TOO MUCH CPU FOR
LOADING`). Cut over a shorter time instead, `-cut -frames 13800`: the
same 3,808 bytes, its longest call 5,089 cycles, and it plays beside
the loader for any load shorter than that.

```bash
python3 tools/sidreloc.py tune.sid moved.sid -to C000
```
Moves any SID tune by whole pages and writes a standard `.sid`, checked
song by song against the original over 5 minutes of play, with the code
those minutes don't reach moved too (`-song N` for one, `-info` to see
what would move). It works for most tunes; one that builds addresses in
a way it can't follow is reported, and stays where it was.

### How big things can be

- **The program:** one file, $0801-$FFF9 for a BASIC-started one: 250
  disk blocks. With `-start ADDR` it can sit anywhere in $0800-$FFF9.
  The loader keeps $0000-$07FF and $FFFA-$FFFF. Whatever falls in the
  memory of what shows while loading (the module, the picture, the music)
  loads after that stops, with the screen off: it still loads, just not
  during the show. The report says how many blocks load during the show
  and how many after.
- **The picture:** a standard Koala file (10,003 bytes). It goes in VIC
  bank 3: screen $CC00-$CFE7, bitmap $E000-$FF3F, colours straight into
  colour RAM. It adds about 13 seconds before it appears at speed 0.
- **The music:** the built-in songs are 2.2 KB at $C000. A SID tune can
  be any size that fits beside the program and the show (HVSC tunes:
  3.6 KB typical, 9 KB at the 90th percentile); it loads before the show
  starts, at about 1.5 s a KB.
- **A module:** see Writing a module.

## Tape errors

If a block fails its check, the game's status line says
**TAPE ERROR: REWIND A BIT, PRESS PLAY** (with the screen off, the border
turns red). Rewind a few seconds and press play: blocks carry sequence
numbers, so the loader skips the ones it has and picks up from the bad one.
Keep playing meanwhile. From a CD or MP3, skip back a few seconds.

Stopping the tape just to go on playing Flappy-Load or Crossy-Load is fine too (as
Invade-a-Load's players did, happier with the invaders than the game
being loaded). The game keeps running with the tape stopped. When you
press PLAY again, the block it stopped in is lost: the status line says
TAPE ERROR; rewind a few seconds, press PLAY, and the load carries on.

## CD, MP3 and PC playback

With a cassette adapter in the datasette, or a lead from the player to the
cassette port, a tape can be played from a CD, an MP3 player or a PC.
There is no wow or flutter, but the sound adds its own errors: the samples
(a 44.1 kHz sample is 22 cycles) and, for MP3, the compression. Give the
output file a `.wav` or `.mp3` name:

```bash
python3 tools/slopload.py mygame.prg mygame.mp3 -speed 13 -nomotor
```

The tool synthesises the sound, reads the file it wrote back, decodes it,
and reports how far the edges moved against the margin. It refuses a file
that moves them by half the margin or more:

```
  sound: MP3 320 kbit/s, 44100 Hz; read back, the edges moved at most 4.6 cycles; ...
```

Things to know:

- **Bitrate:** 192 kbit/s or more for any speed; 128 only up to speed 5.
  Below that the encoder loses edges. Use a constant bitrate.
- **`-nomotor`:** the loader stops the motor while the player finishes the
  game, when part of the program still has to load into the module's memory.
  A CD or MP3 player keeps playing, so that part would go by unread. With
  `-nomotor` the module ends as soon as the rest has loaded, and the rest
  follows straight on. (Programs that don't reach the module's memory are
  unaffected.)
- **Polarity:** if nothing loads at all, the lead or player may invert the
  signal (every edge the C64 counts then falls mid-pulse): master again
  with `-invert`.
- **A .wav for a CD:** burn it as an audio CD track (44.1 kHz). For
  recording to a real cassette from a PC, master for the cassette (speed 0, the default,
  no `-nomotor`).

To check an encoder of your own instead of the built-in LAME:

```bash
python3 tools/slopload.py -calibrate cal.wav
# encode cal.wav with your encoder to cal.mp3, then:
python3 tools/slopload.py -analyse cal.mp3
```

`-info` decodes a .wav or .mp3 as well as a .tap.

MP3 encoding and decoding use GStreamer (`gst-launch-1.0` with the
`lamemp3enc` and `mpg123audiodec` or `avdec_mp3` plugins); WAVs need
nothing extra.

## Real cassettes

VICE plays a .tap with perfect timing, so every speed works there. A real
deck has speed error, wow (slow drift), flutter (fast scatter) and peak
shift (a pulse's neighbours move its edges). The loader measures the speed
again on every block and tracks it within the block, so speed error and
wow are covered. The rest needs margin, and that's what you master for:

The quickest test needs nothing but the deck: a test tape with the same
self-checking program at several speeds, each its own file.

```bash
python3 tools/speedtest.py speedtest.tap -show all
```
One tape per mode (`speedtest-module.tap`, `-none`, `-picture`,
`-picmusic`, `-music`), each with six files, `SPEED 3` to `SPEED 13`,
about a minute each; the file name carries the mode (`SPEED 7 PIC+MUS`).
`-show MODE` makes just one, `-speeds 5,6,7,8` picks other speeds,
`-module crossy` another module, `-picture` another picture than
`pictures/slopload.koa`, and `.wav` instead of `.tap` is for
recording from a PC's sound output. The deck can carry different speeds
in different modes: with the screen on (picture, module) the loader's own
timing is looser, so test each mode you'll use. Record it to a cassette, then on the
C64: `LOAD` loads the next file. Each one, when it starts (SPACE, or the
bird crashing), shows PASS on a green border or FAIL on a red one; a TAPE ERROR on the game's
status line is a fail too. Reset and `LOAD` again for the next. Master
with the fastest speed that passes every time, less one or two.

To measure the deck in detail, with a way to dump a cassette back to a
.tap:

```bash
python3 tools/slopload.py -calibrate cal.tap
```
Every speed's test pulses, about 90 seconds. Record cal.tap to a cassette
on the deck you'll use, then dump that cassette back to a .tap (TAPuino,
DC2N, the Ultimate's tape capture...).

```bash
python3 tools/slopload.py -analyse dump.tap -out deck.json
```
For each pulse set: the deck's speed, wow, flutter, the margin left with
and without precompensation, and the fastest `-speed` and `-bootspeed`
it recommends (below 0, if even 0 leaves too little).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -speed N -bootspeed M -precomp deck.json -hires
```
Each pulse is written shorter or longer by what that deck was
measured to do to it after the pulse before.

## Tape sides: many programs on a cassette

A whole cassette of programs, each its own file on the tape, the way
slushload's mixtape did it:

```bash
python3 tools/slopload.py -tapeside games.tap mygames/ -tape C60
```

Every .prg in `mygames/` (alphabetical; or name the files, in the order
you want them) goes onto sides of a C60, 30 minutes each: each program
on the first side with room for it, so the order is kept as far as the
sides allow. One file per side: `games-1A.tap` and `games-1B.tap` (tape
1, sides A and B), then `games-2A.tap` and so on if they don't fit on
one cassette. Without `-tape`, everything goes in one file. The report
lists each side: where each program starts on it (minutes and seconds),
its size in disk blocks, its loading time, and the time left on the side.

On the C64 it's an ordinary tape: `LOAD` loads the first program; after
it, reset and `LOAD` again for the next. `LOAD"NAME"` finds one by name
further on (the KERNAL skips the others, FOUND ...). Each program is
named on tape after its file.

| option | default | |
|---|---|---|
| `-tape CNN` | | the cassette's length: C46, C60, C90 ... (half of it a side) |
| `-side MM:SS` | | or a side's length directly |
| `-margin S` | 10 | seconds kept free on each side: a cassette's clear leader at its start, and slack |
| `-random` | | shuffle the programs first (the order used is printed) |
| `-speed`, `-bootspeed`, `-blocksize`, `-leader`, `-precomp`, `-hires`, `-rate`, `-bitrate`, `-invert` | | as for one program, for every program on the side |

There's no module, music or picture on a tape side: each program
loads with the screen off, as `-show none`, so the side holds as much as
it can. Every program must load at $0801 and start with RUN (master one
that doesn't on a tape of its own, with `-start`). A side can be a .wav
or .mp3 instead, for recording from a PC; each program is checked by
decoding its tape again, and the sound against its margins as usual.

## SlopLoad 64: mastering on a C64

SlopLoad 64 is the mastering tool as a C64 program, for when there's no
PC: a program on disk in, a SlopLoad tape out, written straight to a
cassette by the datasette, or as a .tap file to a drive with room for
one. It makes the same tapes as the PC tool (any SlopLoad loader reads
them), with the same shows while loading: a module, a picture,
music, a picture and music, or nothing. The module, the tune and the
picture are files it reads from disk by name, so any module written to the
standard ([MODULES.md](MODULES.md)), any SID tune that passes its check and
any Koala picture can go on a tape.

### What you need

- A C64 (or a C128 in C64 mode, a C64 with a SuperCPU, an Ultimate 64),
  a disk drive, and the disk image `build/slopload64.d64` (or `.d81`)
  written to a real disk. `python3 tools/c64build.py` makes both; the
  ready-made ones are in `build/`. Besides SlopLoad 64, the disk has the
  TAP writer, PETSCII-LM and SID-SLM, and the demo files: the
  modules (`FLAPPY-LOAD.LM`, `CROSSY-LOAD.LM`, `OZGOLD.LM`,
  `PETSCII.LM`), a PETSCII screen (`DEMO.PET`), a Koala picture
  (`SLOPLOAD.KOA`: SLOPLOAD in rainbow letters), and three tunes, ready
  (`SLOPLOAD.SLM`, `ENIGMA.SLM`, `OZGOLD.SLM`: OZ GOLD's medley, for
  any show) and as `.sid` files for SID-SLM (`SLOPLOAD.SID`,
  `ENIGMA.SID`, `OZGOLD.SID`).
- The program to master, on any disk in any drive (8 to 30). One file,
  as for the PC tool: $0801-$FFF9.
- If you want them, on any disk: a module (a `.lm` file), a SID
  tune as a `.slm` (SID-SLM makes one from a `.sid` on the C64, and
  `tools/sidstrip.py` on a PC), a Koala picture (a `.koa`).
- For a cassette: a datasette and a blank tape (not with a SuperCPU
  switched on: it can't reach the cassette port, so it makes .tap files
  only). Any KERNAL will do, JiffyDOS included (see To a cassette,
  below). For a .tap file: a drive with room for it (below).
- If you have them: an REU writes the tape in one go (as does a
  SuperCPU's SuperRAM, for a .tap file); an accelerator makes the coding
  quicker (below), and SID-SLM's trial run.

### Mastering a tape

```
LOAD"SLOPLOAD64",8
RUN
```

SlopLoad 64 shows its menu: `*** SLOPLOAD ***` at the top, the machine
it found under it in grey (`C64 PAL`; `SUPERCPU NTSC, 15616 KB SUPERRAM`;
`C128 PAL (2 MHZ), 512 KB REU` ...), then lines 1-9 and 0, one setting
each. Press a line's number to change it, as often as you like: its name
appears in reverse under the menu, with its questions below. When they
are answered, **PRESS ANY KEY** clears the screen and shows the menu
again with the change. RETURN writes the tape. Afterwards SlopLoad 64
comes back to the menu with everything as it was, so the next tape is
one change away. Answers are typed key by key (DEL takes one back), so
nothing else on the screen gets into them.

**@** is the disk: a drive [8], its status, then a line at a time
until RETURN alone. `$` lists the directory (`$:SL*` for the names
starting SL, `$0`...; on a 1541 a `*` ends the pattern, so `$:*.SID`
lists every file), 20 lines and then a key for more (RUN/STOP stops it);
anything else goes to the drive's command channel as it is typed
(`S:OLD`, `R:NEW=OLD`, `C:COPY=FILE`, `N:NAME,ID`, `I`, `V`, `UJ`,
an SD2IEC's `CD:FOLDER`...), and the drive's answer is shown
(`00, OK,00,00`, `01, FILES SCRATCHED,01,00`).

| | line | what it asks |
|---|---|---|
| 1 | program | its drive [8] and file name. SlopLoad 64 reads it through once and shows its address and length (`$0801-$9A1C, 37404 BYTES`). A program outside $0801-$FFF9 is refused. |
| 2 | name | the name on tape: what the KERNAL shows after FOUND (16 keys). Control keys are kept as they are typed (CLR, HOME, the colours, RVS ON...), so `{CLR}{WHITE}MY GAME` clears the screen and turns the text white as the file is found; on the menu they show as quote mode shows them (reversed). RETURN alone: the program's name. The PC tool takes the same with `-filename "{clr}{white}my game"` ({name} or {n}, n a code). |
| 3 | show | what shows while it loads, listed one a line: 0 nothing (the screen off), 1 loader module, 2 picture, 3 picture and music, 4 music. Choosing a module, a picture or a tune sets it to go with them. |
| 4 | module | a module: its drive, then the `.lm` files there, numbered; a number or a name. |
| 5 | music | a tune: its drive, then the `.slm` files there; a number or a name, 0 for none. A `.sid` is refused with `A .SID: SID-SLM MAKES THE .SLM`: run SID-SLM on it first (below). |
| 6 | picture | a Koala picture: its drive, then the `.koa` files there; a number or a name. |
| 7 | speed | -12 (the most margin) to 13 [0]: as `-speed` (see Speeds, and Real cassettes for finding what your deck carries). Type a minus for a speed below 0. |
| 8 | start | SYS [its load address], only for a program that doesn't load at $0801 (one at $0801 starts with RUN); then **start as soon as it is loaded?** Y cuts the module or show off the moment the program is in (as `-autorun`); N lets the player finish. |
| 9 | write to | 1 cassette, 2 .tap file; for a .tap file, its drive and file name [the name on tape's printable characters with .TAP]. With an REU or SuperRAM: write it in one go from it? [Y] |
| 0 | colours | the loading lines (the border's stripes as it loads): rainbow (the loader as it is), a style (mono, c64, blue, red, green, fire, ice, grey, sunset, stealth, gold, candy), or no stripes: black, block (the border a colour a block) or one colour (it asks which, 0-15). The list shows each one's colours. As the PC tool's `-stripes`: a style's colour lookup makes the loader's interrupt 4 cycles longer, so with a module or a picture showing every pulse is 212 cycles or more (208 otherwise); rainbow and the three without stripes cost nothing. |

Lines the show doesn't use are grey (a module chosen and then the show
changed to a picture stays chosen, for when you change it back).

**To a cassette:** put a blank tape in, wound past its clear leader, and
press RECORD and PLAY when asked. SlopLoad 64 writes the KERNAL's file
and the loader, then the blocks (4 KB each). The screen goes blank while
it writes (the VIC's bad lines would upset the timing); between blocks it
stops the motor, reads the next block from the disk and works out its
coding, then starts the motor again ("BLOCK 3 OF 16: $2801-$3800"). With
an REU (an Ultimate has one built in: switch it on in its menu) it reads
and codes every block first, then writes the whole tape without stopping.
**DONE.** at the end; press a key for the menu.

**Any KERNAL, JiffyDOS too.** SlopLoad 64 drives the cassette itself:
its own pulse writer, timed by the C64's timer, and its own motor
control, with its own interrupt routine running instead of the KERNAL's
(which, in a stock KERNAL, starts the motor whenever PLAY is down). It
never calls the KERNAL's tape routines. So a C64 with JiffyDOS, or with
any other KERNAL that gave up the tape code for something else, writes
the same cassette as a stock one, and the switch can stay on JiffyDOS
for all the disk reading. Loading the tape is another matter: it starts
with a file the KERNAL loads, so the machine that loads it needs a
KERNAL with its tape routines. On a JiffyDOS machine, switch to the
stock KERNAL to try the tape (JiffyDOS answers a tape LOAD with
`ILLEGAL DEVICE NUMBER`).

**The motor stops.** Each stop leaves a seam on the tape: a gap, then a
stretch recorded while the motor was still speeding up, which plays back
too fast. SlopLoad 64 puts every seam inside a block's pilot (0.5 s of
it, against 0.08 s written in one go): the loader measures the tape's
speed again every 64 pilot pulses and goes by the last measurement, so
the slow start costs nothing as long as about 80 steady pilot pulses
follow it. The data itself is never written while the motor changes
speed (a 0.1 s trailer after each block lets the motor's stop fall after
it). Playing back, the tape runs straight through. In VICE, with the
motor modelled speeding up from standstill over 0.25 to 0.52 seconds at
every seam (`tests/seams.py`), every tape loaded, a 63 KB program's 24
seams included. To see what your deck does, write a tape with SlopLoad
64, dump it back to a .tap (TAPuino, DC2N, an Ultimate's tape capture)
and run:

```bash
python3 tools/seamcheck.py dump.tap
```

For each seam: how long the slow start lasts on the tape, and how many
steady pilot pulses are left before the block (the loader needs about
80; a 0.25-second spin-up leaves about 950).

**To a .tap file:** the drive needs room. A .tap holds every pulse as a
byte, so it is about six times the program: a 6 KB program with
Crossy-Load is about 510 blocks, a 37 KB one about 1,000, a full 63 KB
one about 1,600. A 1541 has 664 free on an empty disk; a 1581 has 3,160;
a CMD drive or an SD2IEC has plenty. SlopLoad 64 works out the size,
reads the drive's BLOCKS FREE and refuses if it won't fit. Without
expansion memory it reads the program twice (once to choose each block's
coding and size the file, once to write it).

### Modules, music and pictures

**Modules** are `.lm` files (loader modules; a `.lg` from 0.4.0 or
before only needs renaming): a module written to the standard in
[MODULES.md](MODULES.md), built by `tools/build.py` (which writes
`build/modules/NAME.lm`) and copied onto any disk. The ones on SlopLoad
64's disk are demos (`flappy-load.lm`, `crossy-load.lm`, `ozgold.lm`,
the OZ GOLD loading screen with its own music, and `petscii.lm`, a
PETSCII screen); a module of your own goes beside them, or on a disk of
its own. A `.lm` is the module alone: Flappy-Load's and Crossy-Load's
built-in songs aren't in it (OZ GOLD's music is part of OZ GOLD, so it
is). Choose a tune (5) to play beside it: the two on the disk are those
songs. On a PC the same goes for `-module flappy.lm`; `-module flappy`
brings the songs. A **PETSCII screen** of your own becomes one with PETSCII-LM
(below) or `tools/petscii.py` on a PC. SlopLoad 64 checks the file is a module, that it keeps
out of the loader's memory and that its timing jitter is within what the
loader allows, and says where its parts go.

**Music** is a SID tune of at most 4 KB (4,096 bytes of tune), as a
`.slm` file: a tune already tried out, with the stores the loader can't
allow taken out. Two ways to make one:

- **On the C64, SID-SLM** (on the same disk; below) tries a `.sid` out
  and writes its `.slm`.
- **On a PC, `tools/sidstrip.py tune.sid tune.slm`**: a five-minute check
  instead of SID-SLM's one, and the tune can then also be moved to
  another page when it is in the module's or the picture's way.

A tune with many songs is often over 4 KB as a whole though each song
uses much less: `tools/sidstrip.py big.sid song3.slm -song 3 -cut` on a
PC keeps only that song's part (Your own music, above), and the `.slm`
goes on the disk for SlopLoad 64.

A tune that can play but not beside the chosen module is refused when you
press RETURN (`REFUSED: THE MODULE'S ZERO PAGE $003B`), so it can still go
with a picture or alone.

The two tunes on SlopLoad 64's disk are the PC tool's built-in songs, as
`.slm` files made on the PC (they can move) and as `.sid` files for
SID-SLM; with a game they play without the game's sound effects (a SID
tune has all three voices).

**Pictures** are Koala Painter files (`.koa`, 10,003 bytes); the disk's
`SLOPLOAD.KOA` is one to try. SlopLoad 64
puts the picture in whichever VIC bank leaves most of the program
loading while it shows, as the PC tool does.

### What's different from the PC tool

- **The same format, coded the same way:** each block's pulse set and
  coding (2 bits a pulse or the prefix code) chosen for its data, the
  module's share of the CPU kept in every frame. The PC tool's
  `tools/c64model.py` is SlopLoad 64 in Python, and the tests compare
  them byte for byte.
- **A little longer on tape:** a 63 KB program with Crossy-Load at speed
  0 is about 188 seconds written a block at a time, 178 in one go (an
  REU, SuperRAM, or a .tap file), against the PC tool's 171: its 2-bit
  coding takes the best key for each pair of bits rather than the best of
  all 256, and written a block at a time each block has a longer pilot
  (0.5 s, for the motor to come up to speed) and a short trailer.
- **Tunes:** 4 KB at most, as a `.slm`; SID-SLM tries a `.sid` for a
  minute (the PC: five); only a `.slm` made on the PC can be moved, and
  only when it must be (the PC tool moves a tune wherever it costs the
  program least).
- **Not there:** the built-in songs as such (they are on the disk as
  `.slm` and `.sid` files), stripes in colours of your own (`-stripes
  6,14,3`; the styles, black, block and one colour are there), sound
  files, precompensation, `-nomotor`, tape sides, and the block size and
  leader length options.

### Expansion memory and accelerators

- **REU** (any Commodore 17xx or compatible, an Ultimate's, one on a
  SuperCPU or a C128), or a **SuperCPU's SuperRAM**: SlopLoad 64 reads
  and codes the whole program into it, then writes the tape in one go.
  On a cassette that means no motor stops: a shorter tape (the pilots
  between blocks are the PC tool's, 0.08 s instead of 0.5 s, and no
  trailers) and writing at tape speed from start to end. For a .tap
  file, the program is read once instead of twice (SuperRAM is for .tap
  files only, see above). It needs about as
  much as the program and the module take, up to twice that for data the
  prefix code suits: a 128 KB REU holds most programs, 256 KB any. If
  it doesn't fit, SlopLoad 64 says so and writes a block at a time. SuperRAM is
  taken from the free area CMD's ROM keeps (so a RAM disk there is
  safe); an REU is written over (what each 64 KB bank held at its first
  byte is put back after sizing it, nothing else).
- **Accelerators** make the coding between disk and tape quicker:
  a **SuperCPU** runs at 20 MHz throughout; an **Ultimate 64** with its
  turbo registers switched on in its menu runs at its top speed while
  coding; a **C128** in C64 mode uses 2 MHz while the picture isn't being
  drawn (the top and bottom borders, about a third of each frame). The disk
  and the tape always run at the C64's own speed (the serial bus fails
  at 2 MHz), so the time spent reading the disk stays the same.

### Messages

| message | means |
|---|---|
| `NO DRIVE THERE` | no drive answered on that number |
| `IT MUST BE IN $0801-$FFF9` | the program loads below $0801 or runs past $FFF9 |
| `READ ERROR` | the program couldn't be read |
| `THE FILE ENDED EARLY` | the program was shorter on the second reading (a disk error) |
| `NOT ENOUGH ROOM ON DRIVE 9: 1602 BLOCKS NEEDED, 664 FREE` | the .tap won't fit: another disk or drive |
| `TOO BIG TO WRITE IN ONE GO: A BLOCK AT A TIME` (too big for the expansion memory) | it goes on without it |
| `THE REU DIDN'T KEEP WHAT WAS WRITTEN` | the REU failed its check: master again without it |
| `NO CODING FITS THE MODULE'S SHARE` | the module asks for less of the CPU than the loader needs: a slower speed |
| `NOT A MODULE (.LM)` | the file isn't a module in the standard's form |
| `NOT A KOALA PICTURE (10,003 BYTES)` | the file isn't a Koala picture |
| `TOO LONG FOR SLOPLOAD 64` | the file is bigger than SlopLoad 64 has room for |
| `REFUSED: ...` | the tune can't be used, and why (it stays chosen with the reason shown, until another is chosen) |
| `CHOOSE A MODULE (4)`, `CHOOSE A PICTURE (6)`, `CHOOSE SOME MUSIC (5)` | the show needs it |
| `NO ROOM FOR THE PICTURE` | the picture, the show module and the tune don't fit together beside the loader |
| `A SUPERCPU CAN'T REACH THE CASSETTE PORT` | choose a .tap file, or switch the SuperCPU off for a cassette |
| `STOPPED.` | after any of these, or RUN/STOP at "press record and play" |

Anything the drive itself says (`62,FILE NOT FOUND,00,00`) is shown as it
is.

### The TAP writer: a .tap to a cassette

The same disk has the **TAP writer**: any .tap file (SlopLoad's, from
the PC tool or SlopLoad 64, or any other) written to a real cassette by a
C64, for when there's no PC with a tape interface. It needs an REU of
512 KB or more (a Commodore 1750 or larger, an Ultimate's, a C128's in
C64 mode): a cassette takes a pulse every few hundred cycles, far faster
than a disk drive can deliver bytes, so the whole file goes into the REU
first.

```
LOAD"TAPWRITER",8
RUN
```

1. **Drive with the .tap file** [8], and **its file name**. At the name,
   `$` lists the drive's directory (`$:SL*` the names starting SL; 20
   lines, then a key for more) and `@` is the disk as in SlopLoad 64:
   its status, then commands (`S:OLD`, `I`, an SD2IEC's `CD:TAPES`...)
   until RETURN alone; then the name is asked again.
2. It reads the file into the REU, a dot every 16 KB (RUN/STOP stops
   it), then says how big and how long it is: `119 KB, 0:47 OF TAPE`.
3. **Press RECORD and PLAY.** The screen goes blank while it writes; the
   border changes colour every 64 KB, so you can see it's going.
4. **DONE.** Then RETURN writes the same tape again, to another cassette
   (the REU still holds it), Q goes back to BASIC, and any other key
   asks for another .tap.

What fits: about 3 to 4 minutes of a SlopLoad tape per 512 KB of REU at
speed 0 (a 63 KB program with Crossy-Load is about 400 KB). The writer
says `TOO BIG FOR THE REU` for one that doesn't.

How it writes: every pulse as long as the file says, each pulse's start
within a few cycles of where it should be (the C64's timer times them).
A pause in a version 1 .tap is written as long as it says; a version 0
file's overflow bytes as 2,048 cycles. A `-hires` .tap (every pulse as an
exact count) is rounded to 8 cycles, finer than the writer's own timing
anyway. The counts are taken at the machine's clock, so write a tape for
PAL machines on a PAL C64.

Reading is at the drive's speed through the KERNAL: slow on a stock
drive, a few hundred bytes a second, and much quicker with JiffyDOS or a
fast SD2IEC. The writing is the TAP writer's own, as in SlopLoad 64
(its own timing, motor control and interrupt routine, never the KERNAL's
tape routines), so JiffyDOS, or any KERNAL without tape code, can stay
switched on for the whole job. Not with a SuperCPU switched on (it can't
reach the cassette port).

In VICE, put the .tap on a disk image (a .d64 or .d81), not in a host
folder: VICE's host-folder drive sees the tape inside a .tap and hands
over its first file instead of the .tap itself (whatever the file is
called), and the writer says `NOT A .TAP FILE`. A real drive or an
SD2IEC gives the file as it is.

### PETSCII-LM: your PETSCII screen as a module

Also on the disk, **PETSCII-LM** makes a PETSCII screen into a
module (`.lm`): choose it in SlopLoad 64 as the module (4), and the screen
shows while the program loads, with the music you choose (5), and the
program starts as soon as it's in.

```
LOAD"PETSCII-LM",8
RUN
```

PETSCII-LM shows a menu, as SlopLoad 64 does: `*** PETSCII-LM ***` at
the top, then lines 1-7, one setting each. Press a line's number to
change it, as often as you like and in any order: its name appears in
reverse under the menu, with its questions below, and the menu comes
back with the change. **S** shows the screen as the module will show
it (the message's start on its row, in its colours, the rows next to
it cleared). **RETURN** writes the module, **Q** goes back to BASIC.
After writing, the menu comes back with everything as it was, so
another screen, or the same screen with another message, is one change
away.

| line | setting | what it asks |
|---|---|---|
| 1 | screen | the **drive with the .pet file** [the one PETSCII-LM loaded from] and **its file name**. A `.pet` file is Petmate's export: 40 x 25 characters in the C64's upper case or lower case set (`demo.pet` on the disk is one). A key shows the screen as it will look; another goes back to the menu. RETURN alone at the name keeps the screen there is. |
| 2 | message | **a scrolling message**, in an editor of its own: a field of five lines (200 characters) in the screen's case, as the module will show it. Typing goes in at the cursor; the cursor keys move it (up and down a line), DEL takes the character before it, INST puts a space in, HOME goes to the start and CLR (SHIFT HOME) empties it. RETURN ends it; empty is no message. The menu shows its start. |
| 3 | row | **its row** [24], listing the rows that need nothing cleared. The rows above and below the message are cleared when the module is written if anything is on them, and it says so here (`ROW 23 WILL BE CLEARED FOR IT`): the message scrolls in a split of the screen (the fine scroll set before its row and put back after it), and while the loader runs that split can come a few lines late, into the rows next to it, where anything drawn would shake sideways. Your screen itself is kept as it is, so choosing another row later brings those rows back. |
| 4 | speed | **its speed** [2], 1-4 pixels a frame |
| 5 | colours | **its row's colours**: RETURN keeps the screen's, `E` edits them (below) |
| 6 | counter | **a block counter: its row** (RETURN: none), then **its column** (the first of its three digits). Not on the message's rows (its own, the one above and the one below). |
| 7 | font | **the drive with the font** and **its file name**: a font of your own, a `.64c` file as Petmate imports one (a load address, then up to 2,048 bytes, 8 a character). With a screen read, a key shows it in the font, as `S` does. RETURN alone at the name keeps the font there is; `-` goes back to the C64's own. The menu shows the font's file, or `THE C64'S OWN`. A Petmate screen drawn in an imported font exports to a `.pet` that says upper case: give it its font here. |

Lines 3-5 are grey while there is no message.

**The message's colours.** The message scrolls through its row's colour
memory, which stays put, so each column keeps its colour as the
letters pass through it. `E` at line 5 opens an editor of its own, on
the screen's own border and background: the row with the message's
start in it, under it a bar showing every column's colour (a column of
spaces shows its colour there too), and an arrow under the column
you're on. LEFT and RIGHT move along columns 1-39, HOME goes to column
1. The C64's colour keys (CTRL or C= with 1-8) put that colour in the
column and move on to the next, so a run of colours is typed like
text. `F` gives every column the colour of the one you're on, `P` puts
the screen's colours back, RETURN ends it. Column 0 always shows the
background: the message leaves the row there, a character at a time.
The edited colours go with the message's row: change the row and they
move with it. RETURN at line 5 goes back to the screen's.

**Writing it** (RETURN at the menu): **the module's name** [the
screen's, ending `.lm`]; RETURN takes it. If the file is there already,
it asks before replacing it. It says which rows it cleared for the
message.

It writes the same file `tools/petscii.py` makes on a PC with the same
settings (about 3.6 KB, 15 blocks, and the message; a font of its own
adds 8 bytes a character the module shows, cut as on the PC). It
refuses a file that isn't a 40 x 25 `.pet`, and a font file too short
to hold a character. The message's editor and the colour editor show
the C64's own set; `S` and the screen's preview show the font.

### SID-SLM: a .sid made ready for SlopLoad 64

Also on the disk, **SID-SLM** tries a SID tune out on the C64 and writes
the `.slm` file SlopLoad 64 reads for its music.

```
LOAD"SID-SLM",8
RUN
```

1. **Drive with the .sid file** [the one it loaded from], and **its file
   name**. At the name, `$` lists the drive's directory (`$:EN*` the
   names starting EN; 20 lines, then a key for more) and `@` is the
   disk as in SlopLoad 64: its status, then commands (`S:OLD`, `I`...)
   until RETURN alone; then the name is asked again. A tune over 4,096
   bytes (SlopLoad 64's limit) can have its song cut down to the part
   it uses: `IT IS 8318 BYTES, OVER 4096: CUT IT DOWN TO ONE SONG
   (UP TO 2 HOURS; Y/N)?` N refuses it (`REFUSED: OVER 4096 BYTES`), Y cuts it
   (below). A tune with more than one song asks which one.
2. It tries the tune out: its init and 3,000 calls of its play routine
   (a minute of music) in a 6502 emulated in memory, noting what it
   touches: its zero page, the memory it writes outside itself, the
   stores the loader can't allow (taken out of the tune when they don't
   change its sound, as the PC tool's are), and its longest play call.
   The screen counts the calls. About two minutes on a C64 (the SlopLoad
   tune: 117 seconds; a C128 too: its 2 MHz needs interrupts the trial
   keeps off), much less with an Ultimate's turbo or a SuperCPU.
   RUN/STOP stops it (`REFUSED: STOPPED (RUN/STOP)`).
3. It says what it found (`PLAYS ONCE A FRAME`, `LONGEST PLAY CALL: 2253
   CYCLES`, `ZERO PAGE: $70-$7F`, `WORKSPACE: NONE`), or why the tune
   can't play beside the loader (`REFUSED: LOADER'S ZERO PAGE $0002`).
4. **The .slm's name** [the tune's, ending `.slm`]: RETURN takes it. If
   the file is there already, it asks before replacing it.
5. Then Q goes back to BASIC, any other key does another tune.

The trial covers a minute; the PC's covers five, so for a tune whose
later minutes do something new, prepare it on the PC. It also refuses
the rarer undocumented opcodes (slo, dcp and the like: about one tune in
400 uses any), which the PC tool runs. A `.slm` from SID-SLM plays where
the tune was written for; one from `tools/sidstrip.py` can also move.

**Cutting a song down.** With Y, SID-SLM does on the C64 what
`tools/sidstrip.py -cut` does on a PC, with the same result (byte for
byte on every tune tested; one that reads the raster or the CIA timers
while it plays may come out a little different, as the PC's cut counts
no time between play calls and SID-SLM counts a frame): it plays
the song for five minutes (15,000 play calls) in its emulated 6502,
noting each byte of the tune the song runs, reads or writes, and the
high byte of each address it uses, followed back to where it came from
(an immediate, a table, zero page, the stack); then the code its
branches could reach. It keeps those pages, packs them together, moves
every address in them with its page (`SONG 1: 1647 BYTES (7 OF 33
PAGES)`), and tries the cut tune as in step 2, over the same five
minutes: it must make exactly the SID writes the whole tune made, or
it's refused (`REFUSED: PLAYS DIFFERENTLY CUT`: Fox Fights Back reads
its own code as a table). A cut tune it writes, it says is one: `NOTE:
CUT DOWN, SONG 1 ONLY (1647 OF THE TUNE'S 8318 BYTES: WHAT ITS FIRST 5
MINUTES OF PLAY USE)`; a song that does something new after five minutes
may need what was cut. The screen counts the play calls of each
step. Song 1 of Mono (8,318 bytes) took 27 minutes on a stock C64 or a
C128, song 1 of Fox Fights Back 16, song 3 of Golden Axe 50, song 11
of The Last Ninja 74 and its song 5, cut twice, 124 (a tune whose play routine does more takes longer); much less with an
Ultimate's turbo or a SuperCPU. RUN/STOP stops it. A cut over 4,096 bytes is made again as the tune's init
leaves it, as `sidstrip.py -cut` does (above): `OVER 4096: AGAIN, AS
INIT LEAVES IT`, its own count of play calls (`AFTER INIT: 15000 OF
15000 PLAY CALLS`), and its size as before (`SONG 5: 3808 BYTES (15 OF
139 PAGES)`). That takes as long again. If that one is over 4,096 bytes
too, or can't be made, the tune is refused (`REFUSED: CUT, STILL OVER
4096 BYTES`: song 3 of Golden Axe), as is a tune that writes more memory
than the C64 has room to follow (`TOO BIG TO CUT ON A C64`): the PC's
`sidstrip.py -cut` takes those, and `-sid big.sid -song 3` on the PC
needs no cut at all.

**A tune bigger than SID-SLM's memory** (a file over about 15 KB: The
Last Ninja's is 35 KB, its 11 songs in one) is cut too. SID-SLM keeps
what fits of it, about 7 KB from its start and its last page, and reads
a page it lacks from the disk again when the song first uses it: the
file from its start to that page, which takes up to a minute and a half
on a 1541 for a big file, and up to 15 pages after it at once, into the
memory of pages the song hasn't used. Leave the disk in the drive until
it's done. If the file can't be read again as it was (another disk, a
read error), the cut is refused (`REFUSED: CAN'T READ THE FILE
AGAIN`). The Last Ninja's songs each use 14-18 of its 139 pages; song 11
cuts to 3,491 bytes, and the others, cut again as init leaves them, to
2,943-3,808 bytes, all but song 4 (as on the PC).

## Writing a module

**Size.** The tool takes any module that stays out of the loader's memory
($0000-$07FF, $FFFA-$FFFF). In practice two things limit it:

- **Time before play:** the module loads first, with the screen off, at
  about 650 bytes a second at speed 0 (1.5 s a KB). Flappy-Load (5 KB)
  and its music (2.2 KB) take 11 seconds; Crossy-Load (9 KB in two
  parts) and a 2 KB tune, 15.
- **The program's memory:** program bytes in the module's memory load only
  after the module ends. Keep the module in $C000-$FFF9 (16 KB, VIC bank 3:
  where Flappy-Load and its music live); programs that start at $0801
  rarely reach it. Battle Royale ends at $9A1C, so it all loads while
  the module runs.

Zero page $10-$8F is the module's ($70-$7F if it uses the music).

Every module follows one standard, written down in
**[MODULES.md](MODULES.md)**, so a tape works the same whichever module it
carries and your own module drops in beside Flappy-Load and Crossy-Load:
the header from `src/modhead.asm`, and the behaviour every module shares
from `src/modkit.asm` (the status line with its bar and messages, SPACE
to start, fire on port 2, S for the music, the debug hooks the tests
use). A module supplies its own screens (a game its play and characters
too), and `init`, `frame` and `stop`. Start from `modules/template/` (Template-Load, a
minimal game that already keeps the standard: `-module template`).
OZ GOLD (`modules/ozgold/`) and PETSCII-Load (`modules/petscii/`) keep the
same standard without being games: loading screens, one with a counter
and its own music, the other any PETSCII screen.

Two header bytes tell the tool what the module can stand:

- **byte 12, jitter:** measure it with `tests/jitter.py`; the tool adds it
  to the margin while the module runs.
- **byte 14, CPU share:** the most of the CPU the loader may take while
  the module runs (percent). Profile the module's frame with
  `tests/frameprof.py` (on NTSC too, which has fewer cycles a frame) and
  lower it if frames overrun.

And the tool tells the module one thing: **byte 26**, the program's size
in disk blocks (OZ GOLD counts it down).

Put the module in `modules/<name>/<name>.asm`; `tools/build.py` builds every
module it finds there, running `modules/<name>/mkdata.py` first if there is
one. Music goes in `modules/<name>/parts.json`.

**A second part.** A module too big for one stretch of memory can have a
second part below its first: put it first in the source between the
labels `lowpart` and `lowend`, and the header at the label `mainpart`.
`tools/build.py` writes it as `build/modules/<name>_low.prg` and lists it in
the module's parts file, and `slopload.py` loads it with the module and keeps
the program out of it as well. Crossy-Load does this: its status line,
sound, keys and some drawing are at $CAEA-$CFFE, the rest at
$E000-$FFF9 (its setting up runs once from a screen it hasn't used yet).

## Making a release

```bash
python3 tools/release.py [--full]
```
Builds everything fresh and puts the release together in
`releases/slopload-<version>/` (the version is `VERSION`'s), with a
`MANIFEST.txt` of every file's SHA-256, then zips it. In the release:
the PC tool and what it reads (`tools/`, `build/`, the demo tunes), the
C64 tools and their disks, the papers, and the sources (`src/`, `modules/`,
`c64/`, with `build.py` and `c64build.py`), so that it can be rebuilt and
new modules made from it. Not in it: the tests (but the two the tools use),
the research, the real-hardware kit and the masters. Before zipping it
checks a copy of the release: it masters with every module and show, a
style of loading lines and a name with control codes, makes a .wav, a
tape side, a .slm and a speed test, rebuilds its own binaries and disks
to the byte, and loads one of its tapes in VICE. `--full` runs the test
suites first. A new release: raise `VERSION`, add its notes to
`CHANGES.md`, and run it again (it won't replace a release of the same
version without `--force`).

## Tests

| script | does |
|---|---|
| `tests/mktest.py out.prg END` | a self-checking test program up to END |
| `tests/loadtest.py file.tap` | load in VICE, PASS if the program's own check passes |
| `tests/petsciicheck.py [--module FILE] [--font F.64c] [--ntsc] [--c128 [--fast]] [--tap T] [--music N\|none] [--sid F] [--scroll TEXT --scrollrow N --scrollspeed N --scrollcolours HEX] [--counter R,C] [--shots DIR] [--autorun]` | PETSCII-Load at every tick of a load (a `.pet`, `.petmate`, `.c` or `.lm`): VIC bank 2 and the case's `$D018` (or a font's, with its cut-down font in memory), border (red on a tape error) and background, screen and colours as the file has them (the message's row's as given, staying put), one tick a frame (5 in 6 on NTSC), the music; the scroller's split, every `$D016` write's line and value (inside the empty rows), its row always the message's next window, and the counter's digits; once loaded, to the module's stop: 000 held, the music still playing with `$D418`'s volume falling 15 to 0 in 16 steps of 8 ticks, `$01` as the loader has it, the RAM under the SID unchanged; then the program's PASS |
| `tests/petsciilm.py [--machine x128] [--ntsc]` | PETSCII-LM on the C64, its menu worked in one session: .pet files made into modules (a default name, a typed one, replace yes and no, the screen it shows checked, RETURN alone keeping it, a message with a counter, the message editor's keys (typing in, cursor keys, DEL after a quote mark, INST, HOME, CLR: the message checked each time, and the menu's line for it), the rows it lists that need nothing cleared against the file, a row whose neighbours it says it will clear, then clears on writing (as the PC tool does) and puts back, lines that need a message or a screen, a counter refused on the message's rows when asked and when written, the message's row's colours edited (colour keys, cursor limits, HOME, F, P; the editor's row, bar and arrow checked), following the row, and back to the screen's, S's preview, two files refused), a font of its own (read and shown in it, written with a message and a counter, a screen of all 256 characters, `-` back to the C64's own, a file too short, one read before a screen), each .lm the same as `tools/petscii.py`'s |
| `tests/petsciifont.py` | PETSCII-Load in a font of its own on the PC (a few seconds): the modules `tools/petscii.py` makes for screens in a test font (each character different), every cell, the message, the space and the counter's digits showing the file's characters through the cut-down font, at $B800 or $B000 as it holds 128 or more; the C64's own set unchanged; a short `.64c` and broken `.petmate` fonts refused |
| `tests/ozgoldcheck.py [--ntsc] [--c128 [--fast]] [--prg P] [--speed N] [--tap T] [--sid F] [--shots DIR] [--autorun]` | OZ GOLD at every frame of a load: the VIC in bank 2 with the ROM font, screen and colours as designed, header byte 26 the blocks the tool says load while it runs, BLOCKS TO LOAD against the load's progress, one tick a frame (5 in 6 on NTSC), its own tune playing; once loaded, to the module's stop: 000 held, the tune's play routine called every tick with `$D418`'s volume falling 15 to 0 in 16 steps of 8 ticks, `$01` as the loader has it, the RAM under the SID unchanged; then the program's PASS (`--tap`: a tape SlopLoad 64 made; `--autorun`: mastered with `-autorun`, the stop's two frames instead of the fade, the second a frame after the first with 000 drawn, the screen on and the SID silent) |
| `tests/memdiff.py file.tap file.prg` | compare memory with the .prg when the loader exits |
| `tests/channeltest.py ...` | load through a modelled deck (wow, flutter, peak shift) or through sound (`--audio wav\|mp3:192`, `--lowpass`, `--highpass`) |
| `tests/suite.py` | all the load cases in parallel (PAL, NTSC, C128, decks, CD, MP3, a dull head below speed 0) |
| `tests/sidcut.py [--quick]` | `tools/sidstrip.py -cut` on HVSC tunes: The Last Ninja song 5 (cut as its init leaves it, 3,808 bytes) and song 11 (the first cut fits), Golden Axe song 3, Mono song 1 (8 KB to 1.6 KB), Parsec song 3 (a copy loop up to the page past the end) and Hades Nebula song 2 (an address made by adding pages) cut, each `.slm` read back, played from the file and moved, against the whole tune (the same SID writes for 3,000 play calls); Fox Fights Back song 1 refused (it reads its own code as data); then Mono's cut song mastered beside Crossy-Load and loaded. In the suite |
| `tests/options.py` | the PC tool's options without VICE (a few seconds): those a run would ignore refused with their reason (a picture with another show, PETSCII options without a screen, a module on a tape side, sound options for a `.tap`...), and the usual ones still mastering |
| `tests/retrytest.py` | a damaged block, then a "rewind": the loader must recover |
| `tests/stoptest.py --where pilot\|header\|data` | the tape stopped and started again mid-block, then a rewind: TAPE ERROR, then a full load |
| `tests/ladderload.py speedtest.tap [N] [mode]` | load every file of a speed test tape in turn (reset, `LOAD`) |
| `tests/showcheck.py --show picture [--picture F.koa] [--shot F.png]` | the picture on screen as in the file, the music playing; `--sid tune.sid`: the tune's play calls keep its rate; `--shot`: a PNG of the frame VICE drew |
| `tests/jitter.py --speed N` | measure the edge timing error with the module running |
| `tests/frameprof.py [--ntsc] [--prg F]` | time each part of Flappy-Load's frame with the loader running |
| `tests/crossyprof.py [--ntsc] [--machine x128] [--sid F] [--auto 2]` | Crossy-Load's frame: when the vertical blank's work starts, when the split starts (by line 85) and ends, frames with it skipped (there must be none), each colour row written before the beam, when the frame's work ends |
| `tests/splitlook.py [--speed N] [--ntsc]` | Crossy-Load's frames as the emulator draws them (its own picture) against the screen memory: the play field where the split puts it, nothing moved sideways |
| `tests/splitmodel.py` | the split's stores against a model of the VIC's rows, for every fine scroll and start line |
| `tests/crossycheck.py [--god] [--ticks N]` | Crossy-Load's screen against its own lane tables as it plays (`--god`: the autopilot never dies) |
| `tests/framecap.py [--ntsc] [--machine x128] [--auto 1\|2] [--walk] [--frames N]` | Crossy-Load as the emulator draws it, every frame: how far the play field moved, frames whose vertical blank work never ran (a frame missed: shown with the split's scroll), pauses; `--walk`: the joystick held right, then left, as she hops; `--plain --tap T` for an older tape |
| `tests/crossyrules.py [--ntsc] [--deaths N] [--ticks N]` | Crossy-Load's world: nothing moves (lanes, the play field's screen and colours) from the tick after the hen dies to the game over; and every river made next to another goes the other way |
| `tests/crosstear.py [--ntsc] [--machine x128] [--walk] [--auto 1\|2] [--frames N] [--save DIR]` | Crossy-Load's play field as the emulator draws it, row by row, against memory just before and just after the frame's changes: a row that is neither was written as the beam crossed it, and a lane whose two rows come from different moments is torn (a train's halves out of line) |
| `tests/crossywalk.py [--ntsc] [--machine x128]` | Crossy-Load's hen walked with the joystick (the monitor's joyport): a pixel a tick each way, stopping two columns from each edge, her block on show where she is; then walking while hopping nonstop, within the play field |
| `tests/lanelag.py [--ntsc] [--machine x128] [--auto 1\|2]` | how far behind Crossy-Load draws each lane on show, and for how many ticks in a row (`--auto 2`: hopping forward nonstop, the screen scrolling every tick) |
| `tests/crossylook.py [--auto] [--ticks a,b,c]` | pictures of Crossy-Load at those ticks, drawn from VICE's memory (`tests/vicshot.py`) |
| `tests/frametime.py [--ntsc]` | count late status-line splits |
| `tests/irqcycles.py` | the core interrupt's cycle counts per path and class, against the shortest pulse and the tool's model |
| `tests/pllsim.py` | Monte Carlo of the speed tracking under wow |
| `tests/sideload.py side.tap a.prg b.prg ...` | load every program on a tape side in turn (reset, `LOAD`), each compared with its .prg |
| `tests/seams.py out.tap SPINUP [--prg F]` | SlopLoad 64's block-at-a-time tape with each motor stop modelled (a gap, switching noise, the next pilot recorded while the motor speeds up over SPINUP seconds), then loaded |
| `tools/seamcheck.py dump.tap` | a real cassette written by SlopLoad 64, dumped back: each seam's slow start and the steady pilot left after it |
| `tests/tapwrite.py in.tap [--reu KB] [--machine x64sc\|x128] [--ntsc] [--kernal FILE] [--load prog.prg] [--expect TEXT] [--browse]` | the TAP writer in VICE: VICE's recording of what it wrote against the .tap, pulse by pulse, then loaded; the motor must be off until it writes (PLAY is down from the start); `--kernal`: another KERNAL, such as JiffyDOS; `--browse`: first `$` (two pages), `$:T*` and `@` with a command at the file question, the text's colour kept after "more" |
| `tests/c64disk.py [--truedrive] [--many]` | SlopLoad 64's @ (the disk) in VICE: the directory listed, a file renamed and scratched through the command channel with the drive's answers checked, then back to the menu; `--many`: a directory long enough to stop for a key; `--truedrive`: an emulated 1541 |
| `tests/c64tool.py [--show S] [--module NAME\|FILE.lm] [--music FILE.sid\|FILE.slm] [--picture FILE.koa] [--out tap\|tape] [--machine x64sc\|x128\|xscpu64] [--xmem reu\|sram] [--reusize KB] [--says TEXT] [--fast] [--tapdisk d64\|d81] [--scpurom cmd] [--lines N] [--tname TEXT] [--expect TEXT] [--then MODULE] [--prgdrive 8\|9] [--ntsc] [--kernal FILE] [--load]` | SlopLoad 64 in VICE, its menu worked through the keyboard (each "press any key" answered): its .tap (or the cassette it recorded) against `tools/c64model.py`'s, then loaded. A `.sid` is made a `.slm` by SID-SLM first, on the same disk. `--fast`: a C128's 2 MHz forced on at the start; `--tapdisk`: the .tap to a 1541 or 1581 image (true drive emulation); `--scpurom cmd`: CMD's SuperCPU ROM; `--lines`: the loading lines (its number in the list; `--fcol N`: one colour's colour); `--tname`: the name on tape typed as keys (`{clr}{white}...`); `--expect`: a refusal it must stop with; `--then`: a second tape in the same session with that module, against the model too; `--prgdrive 9`: the program read from drive 9, with the .tap; `--ntsc`; `--kernal FILE`: another KERNAL (x128: its C64 mode's), such as JiffyDOS: the cassette must come out the same. To the cassette, the motor must be off each time a block is coded (PLAY is down all along) |
| `tests/c64suite.py [--only NAME ...] [--list]` | SlopLoad 64's 53 cases in parallel: every show, speeds below 0, modules (the games, OZ GOLD and PETSCII-Load, and PETSCII-Load in a font of its own, one beside a 63 KB program, loaded), tunes (a `.sid` made a `.slm` by SID-SLM, `.slm` files from the PC and the disk, one moved, then a second tape in the session with another module, one song of a tune too big for SlopLoad 64 cut by `sidstrip.py -cut`), pictures (one in another VIC bank, and the disk's own), loading lines (styles, black, block, one colour), cassette and REU (512 KB, 1 MB, 16 MB: its size said), C128, SuperCPU, 1581, 63 KB, a SYS start, the program read from drive 9 (VICE's host folder, a 1541 image), and seven refusals |
| `tests/c64modes.py` | SlopLoad 64's core made in one loading-lines mode after another in the same session (rainbow, styles, black, block, one colour in two colours, and back): each as that mode alone makes it |
| `tests/trialtest.py` | SID-SLM's trial run (`c64/trial.asm`) in the simulator and in VICE against `tools/sidstrip.py`, tune by tune and instruction by instruction |
| `tests/sidslm.py [--machine x128] [--ntsc] [--quick]` | SID-SLM in VICE, its questions typed: `$`, `$:E*` and `@` with a command at the file question first (the text's colour kept after "more"); tunes made `.slm` files (a song chosen, a CIA-timed tune, a name replaced), each compared with the PC's check of the same 3,000 play calls field by field; six refusals, each with the PC's reason; then songs of tunes over 4 KB cut (Mono song 1 written, against `tests/cuttest.py`'s reference cut tried over 15,000 play calls; Golden Axe song 3 still over 4,096 bytes; Fox Fights Back song 1 plays differently cut; the Last Ninja, 35 KB, its pages read from the disk again: song 11 written, song 5 written as its init leaves it, its first cut over 4,096), with the C64 minutes each took |
| `tests/cuttest.py [tune.sid[:song] ...] [-n CALLS] [--vice] [--pc] [--paged N] [--after]` | SID-SLM's cut (`c64/sidcut.asm`) in the simulator (or VICE) against `tools/sidstrip.py`'s `cut_pages`, step by step: the code run, the bytes used, the trace's marks, spans and compares, the static walk, the ends, the pages kept and their places, the cut's bytes, init and play; its opcode tables against the simulator's. A cut over 4,096 bytes (any, with `--after`) is made again as the tune's init leaves it (`cutafter` against `after_init`): that tune's range and stub, then the same comparisons. `--paged N`: only N of the tune's pages in memory, the rest read in as the cut asks (a tune too big to lie whole, as the Last Ninja, is paged with 40). In the suite (`sid-cut-c64`, and `sid-cut-c64-paged` with 6 pages) |

They start their own headless VICE (`tests/vicerun.py`) with a throwaway
config, so your VICE settings are never touched.

On real hardware: [REALTEST.md](REALTEST.md) lists the tests VICE can't
do (a real datasette's motor and heads, an Ultimate's turbo), and
`python3 tools/realkit.py` puts their files in `realtest/`.
