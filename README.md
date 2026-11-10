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

From a release (`slopload-0.13.0.zip`, or the latest: unpack it anywhere) everything is
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
Masters a tape: `LOAD` (or SHIFT+RUN/STOP) loads it, the screen off and
the border striped (the fastest way), and the program runs.

The tool has no modules or tunes of its own: a module (a game to play
while it loads, a loading screen) is a `.lm` file and a tune a `.sid`
(or `.slm`), given by their paths, yours or the demos that come with
SlopLoad: the modules in `build/modules/` (`flappy.lm`, `crossy.lm`,
`squeeze.lm`, `rubble.lm`, `bounce.lm`, `ozgold.lm`, `petscii.lm`, `template.lm`) and the tunes in
`music/build/` (`enigma.sid`, `slopload.sid`, `ozgold.sid`).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -module build/modules/flappy.lm -sid music/build/enigma.sid
```
After the KERNAL finds the file, the screen goes to border stripes for a
few seconds while the game loads, then Flappy-Load starts with a loading
bar under it, Enigma Street playing. When
the program is in, Flappy-Load ends and the program starts, a game in
progress too: nothing waits for the player unless the tape was mastered
with `-wait`. With `-wait` the status line says **LOADED! PRESS SPACE TO
START THE GAME** and the player plays on: SPACE starts the program, or
the end of a game (the bird crashing) does.

Controls: fire on the joystick in port 2 to flap. S turns the music on and
off.

`-module build/modules/crossy.lm` gives **Crossy-Load** instead: hop a white hen up an
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

`-module build/modules/squeeze.lm` gives **Squeeze-Load**: a rocket at
the foot of a mine shaft, and steel girders falling down it, each with a
gap. Left and right on the joystick in port 2 slip the rocket through
(fire starts a round). A point for every girder passed; every five the
fall speeds up, the gaps narrow and the girders change colour. Touch one
and the round is over, everything stopped where it was; the best score
stays while the tape loads. Once the program is in it starts, a round in
progress too; with `-wait`, on SPACE or when a round ends. It makes
sound effects only, on voice 3: give it a tune with `-sid`
(`music/build/slopload.sid` and `enigma.sid` leave voice 3 to the
effects; any other tune has all three voices, and then no effects).
On SlopLoad 64 it is `squeeze-load.lm` on the tool's disk: pick it as
the module.

`-module build/modules/rubble.lm` gives **Rubble-Load**: the old town is
coming down, and you fly the demolition plane. It crosses the screen
over sixteen blocks of flats and offices, back and forth, a row lower at
each turn. Fire on the joystick in port 2 drops a charge from under it
(one at a time), and the block it lands on loses its top storey. Flatten
every block and the plane glides down and lands on the street, for a
bonus and the next town: taller blocks, a faster plane, another sky. Fly
into a block and the game is over (fire starts the next). The best
score stays while the tape loads. Once the program is in it starts, a
game in progress too; with `-wait`, on SPACE or when a game ends. Like
Squeeze-Load it makes sound effects only, on voice 3, beside a tune
given with `-sid`. On SlopLoad 64 it is `rubble-load.lm` on the tool's
disk.

`-module build/modules/bounce.lm` gives **Bounce-Load**: a wall of
bricks to knock down with a ball, bounced off a bat at the foot of the
field. Left and right on the joystick in port 2 move the bat; fire
serves the ball (or it goes by itself after three seconds). Where the
ball meets the bat sets its angle: the middle sends it up steeply, the
ends off to the side. Some bricks take two hits, cracking at the first.
Clear the wall and the next is built, eight walls in turn, the ball a
little faster each time, and faster still the longer you keep it in
play. Lose the last of three balls and the game is over (fire starts the
next); the best score stays while the tape loads. Once the program is
in it starts, a game in progress too; with `-wait`, on SPACE or when a
game ends. Sound effects only, on voice 3, beside a tune given with
`-sid`. On SlopLoad 64 it is `bounce-load.lm` on the tool's disk.

`-module build/modules/ozgold.lm` isn't a game: it is **OZ GOLD**, a loading screen in the
style of U.S. Gold's Novaload one, for Australians. The Australian flag
in PETSCII (the C64's own character set), OZ GOLD in U.S. Gold's own
block letters, ALL AUSTRALIAN SOFTWARE on green and gold, and BLOCKS TO
LOAD counting down to 000 as the program comes in. It plays its own
medley (Advance Australia Fair, Waltzing Matilda and Bound for Botany
Bay; `-sid` plays your tune instead, S turns it off). Once the program
is in, BLOCKS TO LOAD stays at 000 while the music fades out, about 2
seconds, as Novaload's did, and then the program starts (with `-wait`,
not before SPACE). It's an example of a module that does something
other than play a game (MODULES.md).

**A PETSCII screen of your own** shows the same way: give the file as
the module.

```bash
python3 tools/slopload.py prog.prg prog.tap -module myscreen.petmate
```

It's PETSCII-Load: your screen, music if you give a tune (`-sid FILE`;
S turns it off), and the border red during a tape error.
Once the program is in, the counter stays at 000 while the music fades
out (about 2.6 seconds; with no music, 000 for 1.3 seconds), and then the
program starts. With `-nomotor` when part of the program loads after the
screen goes, it starts at once instead (the counter at 000 for a frame
first): the tape can't wait. Two things can go on it, as on
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
upper case or lower case set, or in a font of your own. `-module
build/modules/petscii.lm` shows the demo screen (`modules/petscii/demo.pet`). For SlopLoad 64, make the screen into a
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
| `-show MODE` | from `-module` and `-sid` | `module`, `none` or `music`, and seldom needed: with `-module` the module shows; without, a `-sid` tune plays alone with the screen off; with neither, nothing (below) |
| `-wait` | | once the program is in, it starts only on a key: with a picture, PRESS SPACE OR FIRE across its bottom row, and it starts on one; with a module, SPACE alone: a game plays on round after round, OZ GOLD and PETSCII screens hold at 000 (below) |
| `-countdown` | | with a game module: its status line shows the blocks still to load, counting down to 000, in place of the percent (below) |
| `-fade` | | kept for old command lines: every module's music fades out at the end now (below) |
| `-sprite FILE` | | with a picture: one or two loading sprites over it; `-spritepos X,Y`, `-spritecolours C,C,...`, `-spritespeed N`, `-spritemc A,B`, `-spriteexpand` (below) |
| `-module FILE\|none` | `none` | what shows while it loads, a file: a `.lm` (the demos: `build/modules/flappy.lm`, `crossy.lm`, `squeeze.lm`, `rubble.lm`, `bounce.lm`, `template.lm`, `ozgold.lm`, `petscii.lm`; your own: MODULES.md), a module's `.prg` with its `.parts.json` beside it, a PETSCII screen (`.petmate`, `.pet`, Marq's `.c`), or a picture (Koala, Art Studio, Doodle or any of PICTURE-LM's 16 formats: below), each made into its module there and then; `none`: no module |
| `-speed N` | 0 | -12 (the most margin) to 13: slushload's speed scale, and below it (below) |
| `-bootspeed N` | as `-speed` | the same for the parts loaded with the screen off |
| `-scroll TEXT` | | with a PETSCII screen: a scrolling message; `-scrollrow N` (default 24), `-scrollspeed N` (1-4, default 2), `-scrollcolours HEX` (its row's colours, a hex digit a column from column 1, repeated; default: the screen's) |
| `-counter ROW,COL` | | with a PETSCII screen: a block counter's three digits there |
| `-font FONT.64c` | | with a PETSCII screen: drawn in a font of its own (a `.petmate` screen in an imported font brings it with it) |
| `-sid FILE` | | the music, a file: a `.sid`, or a `.slm` from `tools/sidstrip.py` (the demos: `music/build/enigma.sid`, `slopload.sid`, `ozgold.sid`); without it, no music. See Your own music |
| `-song N` | the file's start song | which song of the SID file |
| `-stripes STYLE` | `rainbow` | the border stripes' colours while the screen is off, or an effect (`classic`, `thin`, `mixed`, `and:N`, `ora:N`, `eor:N`, each with `,B` its starting colour; below) |
| `-then FILE` | | a second module after the first: the first shows while the second's parts load, then the second while the program loads (a PETSCII screen, then a picture: below) |
| `-showstripes` | | the stripes on through the module (a picture too) or music (below) |
| `-cycle` | | the border's colour one on with every 256 bytes loaded, under an effect or one colour (below) |
| `-start ADDR` | RUN | start with JMP ADDR instead (needed if the program isn't at $0801) |
| `-status VAL` | $37 | $01 for `-start` |
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

| given | the C64 shows | Battle Royale, speed 0 |
|---|---|---|
| nothing | border stripes, screen off: the fastest | 75 s |
| `-sid FILE` | music, screen off (the border lightens as it loads) | 79 s |
| `-module FILE.koa` | a Koala picture | 113 s |
| `-module FILE.koa -sid FILE` | the picture and music | 117 s |
| `-module build/modules/flappy.lm -sid ...` | Flappy-Load, with Enigma Street | 111 s |
| `-module build/modules/crossy.lm -sid ...` | Crossy-Load, with the SlopLoad tune | 115 s |

From PLAY to the program running, with the 18-second KERNAL boot. The
screen being on is what costs: the VIC's bad lines delay the loader, so
with a picture or a module each pulse needs more margin. Music alone keeps
the screen off and loads nearly as fast as `none`. With a picture or
music, the program starts by itself once it's in; with the game too, a
game in progress or not (with `-wait`, SPACE or the bird's crash starts
it instead). A tape error shows as a
red border (as TAPE ERROR on the game's status line).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -module loading.koa -sid music/build/slopload.sid
```

For a picture to try, `pictures/slopload.koa` is SLOPLOAD in rainbow
letters (drawn by `pictures/mkslopload.py`); it is on SlopLoad 64's
disks too.

**A picture is a module.** `-module` takes a picture file and makes it
the picture module there and then: the module PICTURE-LM writes on a
C64 (below), with the picture placed in the VIC bank that leaves most of
the program loading while it shows. It takes every format PICTURE-LM
does, told apart by size and load address: Koala and its kind, Advanced
Art Studio and ten more in multicolour; Art Studio, Doodle and two more
in hires. A hires picture has no colours for colour RAM, so it is a
thousand bytes shorter on tape than a Koala picture. (Up to 0.12.0 this
was `-show picture` or `picmusic` with `-picture FILE`; the tool now
refuses those and points here.)

**The end of the load: the fade, and `-wait`.** Once the program is in,
the music always fades out over about 2.6 seconds (16 volume steps)
before the program starts, whatever is showing: a picture, the tune
alone, a loading screen, or a game, which plays on while it fades. A
tune in SlopLoad's own player fades by its volume, any other SID tune
through the fade's SID path (`src/fadekit.asm`, which every module
includes). With nothing playing (no tune, or S pressed in a game) the
program starts at once. `-fade` is still accepted, for old command
lines. As Tape Master Pro's tapes do, a picture can also hold the
program back: `-wait` puts PRESS SPACE OR FIRE across the picture's
bottom row, the letters from the C64's own character set, twice as
wide, white (black on a white background), and the program starts on
SPACE or fire on joystick port 2, the fade coming after the key. The row
is drawn below the picture, from line 251, in under a frame, so it
changes whole. The wait can't happen when part of the program loads
into the picture's memory (its picture, music or code): that part loads
after it has gone, and the tool says so.

```bash
python3 tools/slopload.py mygame.prg mygame.tap -module loading.koa -sid tune.sid -wait
```

**With a module: `-wait` and `-countdown`.** A module never waits for
the player by itself: once the program is in, it ends (a game mid-round
too) and the program starts. As the loader games of TND's Loader Game
Tape Master Kits played on until a key, `-wait` makes it stay: a game
goes on, round after round, with LOADED! PRESS SPACE TO START THE GAME
on the status line, until SPACE or the end of a game; OZ GOLD and a
PETSCII screen hold at 000, the music on (OZ GOLD with PRESS SPACE on
its tape error row; put a prompt of your own in a PETSCII screen or its
scroller), and fade once SPACE is pressed; a game fades its tune too
before the program starts.
`-countdown` makes a game's status line count the blocks still to load
down to 000 ("024", as those kits' games did) where it showed the
percent. A module says in its header whether it keeps each (all the
demo modules keep `-wait`; the games keep `-countdown`, OZ GOLD and
PETSCII screens count with their own counter), and the tool refuses
them for one that doesn't. `-wait` doesn't go with `-nomotor` when part
of the program loads into the module's memory (the module must end the
moment that part is in).

```bash
python3 tools/slopload.py mygame.prg mygame.tap -module build/modules/crossy.lm -sid music/build/slopload.sid -wait -countdown
```

**Loading sprites: `-sprite FILE`.** One or two sprites over the picture,
as Tape Master Pro's loading sprite: a file of 64 bytes a sprite (3
bytes a row, 21 rows, then a spare byte; 63 will do; a `.prg`'s load
address is skipped). `pictures/cassette.spr` is one to try, a cassette
24 by 15 pixels (on SlopLoad 64's disks too). The second goes beside the
first. `-spritepos X,Y` puts their top left on the picture (0-319,
0-199; default the bottom right corner); `-spritecolours 1,15,12,11,0`
is their colour, or up to 32 they flash through, `-spritespeed N`
frames each (default 2); `-spritemc A,B` makes them multicolour with A
and B the shared colours; `-spriteexpand` twice as wide and tall. Their
colour changes only while the beam is outside their lines, so it never
changes inside one. PICTURE-LM (below) moves them over the picture with
the joystick.

Sprites cost the loader margin: the VIC takes the CPU for a few cycles
on every line a sprite is on, and the loader's interrupt can come that
much later. Measured with a picture at speed 0 (`tests/jitter.py`, PAL),
the worst timing error is 51 cycles with no sprite, 59 with one, 64
with two side by side, 68 with three and 118 with eight double-height
ones. The tool takes one sprite as 8 cycles of jitter more and two as
16; the loader's pilot window allows 64 in all, so two side by side is
the most. At speed 0 a picture already uses the most margin the core
allows (124), so there the sprites can't make the pulses longer: they
use some of the tape's own margin (±60 left with two, as speed 4 has),
and the report says so. On a deck that needs speed 0's margin, leave
them out; at faster speeds they cost time instead.

### Two modules, one after the other: `-then`

A PETSCII screen first, with its scroller and block counter, while a
loading picture loads; then the picture while the program loads:

```bash
python3 tools/slopload.py prog.prg prog.tap -module title.pet -scroll "LOADING THE PICTURE..." \
    -counter 20,26 -then loading.koa -sid music/build/slopload.sid
```

- **The first module** (`-module`) shows while the second's parts load.
  A PETSCII screen's counter counts the second module's blocks down to
  000 (a picture's are 48), then the second takes over.
- **The second module** (`-then FILE`) shows while the program loads,
  and ends the load as a single module would: `-wait` and `-countdown`
  are its own. FILE is a module (a `.lm`, a module's `.prg`, a PETSCII
  screen), or a picture in any of the formats PICTURE-LM takes (below),
  which the tool makes into the picture module there and then: `-wait`,
  `-fade` and `-sprite` (with its options) go to it.
- **The switch** is the loader's own: the second module's last block
  carries a flag, and at the next frame a small piece of code (112 bytes,
  in the tape buffer at $0380) blanks the screen in the vertical blank
  and starts the second module: the first screen, a blank frame or two,
  then the second.
- **The tune** (`-sid`) starts under the first module and plays on
  through the switch: the second module is told it is playing and
  doesn't start it again. A picture takes over within a frame; a game
  sets itself up first (Flappy-Load takes three frames), and the tune
  waits that long. A module built with an older kit starts the tune
  again (its header's byte 27, bit 4, says it won't; the report says
  when it will). Rebuilding it with the kit is enough.
- **Memory:** the second module's parts load while the first runs, so the
  two can't share any. In a chain the tool builds a PETSCII screen at
  $A000, not $E000, clear of a picture's $C000-$FFBF (`petscii.py
  -chain` makes such a `.lm`). The program's bytes in the first module's
  memory load once the second has taken over; only those in the second's
  (and the tune's) load after it, with the screen off.
- **The cost:** the second module's parts load with the screen on, at the
  first module's margin and share of the CPU. A picture's 12 KB take
  about 20 seconds at speed 0 under a PETSCII screen with a scroller.

SlopLoad 64 chains two modules too (line 4: [below](#modules-music-and-pictures)),
and PETSCII-LM writes a screen at $A000 for one (its line 8).

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
for each pulse length; `-showstripes` keeps it going while the module,
picture or music shows too (below). `-stripes` picks the colours:

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

**Effects, as classic loaders did them.** These run the 6502 code the
old loaders ran, once for each pulse off the tape:

| `-stripes` | the code | the border |
|---|---|---|
| `classic` | `LDA $D020 : EOR #$00 : INC $D020` | the next colour with each pulse: multicolour stripes |
| `thin` | `INC $D020 : DEC $D020` | a plain border with a thin line of the next colour each pulse |
| `mixed` | `INC $D020 : EOR #$00 : INC $D020` | a thin line, then two colours on |
| `and:N` | `LDA $0006 : AND #N : STA $D020` | the byte coming in off the tape, its colour bits masked by N (0-15) |
| `ora:N` | `LDA $0006 : ORA #N : STA $D020` | the same, N's bits always set |
| `eor:N` | `LDA $D020 : EOR #N : STA $D020` | two colours by turns: the border's and the border's eor N |

`,B` after any of them (`thin,6`, `eor:8,6`) is the colour the border
starts from (0 if not given): the plain colour under `thin`, the pair
`eor` swaps between (`eor:8,6`: blue and light blue), the start of
`classic`'s run. `$0006` is the loader's byte being put together from
the pulses (classic loaders used a zero-page byte of their own). An
effect lengthens the loader's interrupt more than a style does: `and`,
`ora` and `eor` by 6 cycles, `classic` by 8, `thin` and `mixed` by 10
(`thin` fills its 8 bytes with an `EOR #$00` after the `DEC`), and the
shortest pulses grow to match.

**On through the show** (`-showstripes`): the loading lines go on in the
border while a module, a picture or music shows, not only before it
starts. The border is then the loader's: the module leaves it alone
(PETSCII-Load's border colour, a game's, the show's black or its border
lightening with the music, all give way) and a tape error turns it red
until the loader recovers, as with the screen off. A module of your own
must say in its header that it leaves the border alone (MODULES.md), or
the tool refuses `-showstripes` with it; the demo ones all do. It
goes with any style that has lines (not `black`, `block` or one colour).

```bash
python3 tools/slopload.py prog.prg prog.tap -module loading.koa -stripes thin,14 -showstripes
```

**A colour on each page: `-cycle`** (Tape Master Pro's border cycle).
The border's colour goes one on with every 256 bytes loaded: under
`thin`, the plain colour steps on while the thin lines go on; under
`eor`, both colours of the pair; under one colour (`-stripes black`,
`-stripes 6`), a plain border that steps through all 16 colours, page by
page, with no lines. (Under `classic`, `mixed`, `and` and `ora` the
border changes every pulse anyway, so the step hardly shows.) The core
puts the border back to the effect's own colour at the end of every good
block, so it starts again from there; a block of 4,096 bytes is 16
pages, so with whole blocks that is the same as going on. It costs 3
cycles on a page's last byte: the shortest pulses grow by 3. With a
module or a show it needs `-showstripes` (the border is theirs
otherwise, and the colour would still step on under them). It doesn't
go with the table styles or `block`.

```bash
python3 tools/slopload.py prog.prg prog.tap -stripes black -cycle
```

Every style but `rainbow` also holds the first few seconds (stage 1,
loading the loader) at its first colour (an effect: the colour it starts
from), so a black border is black from the moment the C64's own loader
hands over. Before that, while the C64's own loader reads the tape's
first file, the border is the C64's (light blue unless the program
before changed it): nothing of SlopLoad's runs yet. A tape error turns
the border red in every style, until the loader recovers.

### Your own music: SID tunes

```bash
python3 tools/slopload.py mygame.prg mygame.tap -module loading.koa -sid tune.sid
```

Any PSID file (the HVSC's format) can play alone, beside a picture or
beside a module. The tool runs the tune in a 6502 simulator first,
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
most 3,700 cycles a call (the demo tunes: about 2,300), keep its zero
page out of the module's $10-$8F except $70-$7F (the music player's,
there for a tune), and sit clear of the module's memory or be movable
(the tool moves it). A game's sound effects are off with a SID (it uses
all three voices), but for one: a tune in **SlopLoad's own player**
(`music/player.asm`, as the demo tunes are; `music/tools/sidc.py` makes them
from songs written in Python) goes at $C000, where the player leaves
voice 3 to the game's effects, and plays in tune on NTSC. The report
says so (`SlopLoad's player: voice 3 for the module's effects`). A
module that makes no effects (OZ GOLD, PETSCII-Load) keeps all three
voices for any tune.

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
- **The music:** a tune in SlopLoad's own player goes at $C000 where it
  can (the demos: 1.9 to 2.7 KB). Any tune can
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

The RESTORE key does nothing while a SlopLoad tape loads, from the moment
the loader takes over from the KERNAL until the program starts (as TND's
Loader Game Tape Master Kit 3 did it): the loader leaves an interrupt
pending on the second CIA, which holds the NMI line down, so a press
can't interrupt it and cost the tape an edge. The program gets RESTORE
back when it starts.

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
`-module FILE.lm` another module than the demo Flappy-Load, `-sid
FILE` another tune than Enigma Street (`none`: none with the module),
`-picture` another picture than
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
`C128 PAL (2 MHZ), 512 KB REU` ...), then lines 1-9, one setting
each. Press a line's number to change it, as often as you like: its name
appears in reverse under the menu, with its questions below. When they
are answered, **PRESS ANY KEY** clears the screen and shows the menu
again with the change. RETURN masters the tape. Afterwards SlopLoad 64
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
| 1 | program | its drive [8] and file name. SlopLoad 64 reads it through once and shows its address and length (`$0801-$9A1C, 37404 BYTES`). A program outside $0801-$FFF9 is refused. One that doesn't load at $0801 is asked **start with sys** [its load address] (the menu shows `SYS $1000` after its addresses); one at $0801 starts with RUN. |
| 2 | name | the name on tape: what the KERNAL shows after FOUND (16 keys). Control keys are kept as they are typed (CLR, HOME, the colours, RVS ON...), so `{CLR}{WHITE}MY GAME` clears the screen and turns the text white as the file is found; on the menu they show as quote mode shows them (reversed). RETURN alone: the program's name. The PC tool takes the same with `-filename "{clr}{white}my game"` ({name} or {n}, n a code). |
| 3 | module | what shows while it loads: a game, a loading screen or a picture, as a `.lm` file (PICTURE-LM makes a picture's). Its drive, then the `.lm` files there, numbered; a number or a name. Then the wait and count questions, if it keeps them and ends the load. 0 (as the drive, or from the list): none. Another module here clears line 4. |
| 4 | second | a second module, after the first (a chain: below), chosen the same way; 0: none. It needs a module on line 3 first (`CHOOSE A MODULE FIRST (3)`). Then the wait and count questions, if it keeps them: it ends the load. |
| 5 | music | a tune: its drive, then the `.slm` files there; a number or a name. 0 (as the drive, or from the list): none. A `.sid` is refused with `A .SID: SID-SLM MAKES THE .SLM`: run SID-SLM on it first (below). It fades out at the end, as every module's tune. |
| 6 | speed | -12 (the most margin) to 13 [0]: as `-speed` (see Speeds, and Real cassettes for finding what your deck carries). Type a minus for a speed below 0. |
| 7 | colours | the loading lines' colours (the border's stripes as it loads), listed with each one's colours: rainbow (the loader as it is), a palette (mono, c64, blue, red, green, fire, ice, grey, sunset, stealth, gold, candy, black), or **your own**: 1 to 12 colours, 0-15, typed apart by commas (`6,14,3,1`; the menu offers the last ones); one alone is a plain border. As the PC tool's `-stripes NAME` or `-stripes 6,14,3`. |
| 8 | effect | how the lines are drawn: 1 standard (SlopLoad's own, in line 7's colours), 2 classic, 3 thin, 4 mixed, 5 and, 6 ora, 7 eor (the effects of classic loaders, starting from line 7's first colour; and, ora and eor ask their value, 0-15), 8 block (the border a colour a block, through all 16). Then, for an effect, black or one colour, **a colour on each page loaded?** (`+CYCLE`, the PC tool's `-cycle`), and for anything with bars **bars during the module or music?** (`+DURING`, the PC tool's `-showstripes`; without it the bars stop when the module or the music starts; a module whose header doesn't leave the border alone is refused, `THE MODULE KEEPS ITS BORDER`). As the PC tool's `-stripes`: a palette's colour lookup makes the loader's interrupt 4 cycles longer, so with a module showing every pulse is 212 cycles or more (208 otherwise); an effect 6-10 cycles (218 for thin and mixed); rainbow, black, one colour and block cost nothing. |
| 9 | write to | 1 cassette, 2 .tap file; for a .tap file, its drive and file name [the name on tape's printable characters with .TAP]. With an REU or SuperRAM: write it in one go from it? [Y] |

What shows follows from lines 3 to 5: the module (the tune playing
beside it, if there is one), the tune alone with the screen off, or,
with neither, nothing (the screen off: the fastest). Once the program is
in, the tune fades out and the program starts, unless the module's wait
was asked for (line 3, or line 4 for a second) or a picture module keeps
its own (PICTURE-LM's line 8).

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
64's disk are demos (`flappy-load.lm`, `crossy-load.lm`, `squeeze-load.lm`, `rubble-load.lm`, `bounce-load.lm`, `ozgold.lm`,
the OZ GOLD loading screen with its own music, and `petscii.lm`, a
PETSCII screen); a module of your own goes beside them, or on a disk of
its own. A `.lm` is the module alone, with no music (but OZ GOLD's,
part of OZ GOLD): choose a tune (5) to play beside it, as on a PC
(`-module flappy.lm -sid enigma.sid`). A **PETSCII screen** of your own becomes one with PETSCII-LM
(below) or `tools/petscii.py` on a PC. SlopLoad 64 checks the file is a module, that it keeps
out of the loader's memory and that its timing jitter is within what the
loader allows, and says where its parts go. If the module keeps them, it
then asks **once loaded, wait for space or the game's end?** (`-wait`:
without it the module ends as soon as the program is in; with it a game
plays on, a loading screen holds at 000) and **count the blocks down?**
(`-countdown`); the line shows `+wait` and `+count` after the module's
name. To take the module off again, choose 0 at line 3; 0 at line 4
takes the second off, and at line 5 the tune.

**Two modules, one after the other** (a chain, the PC tool's `-then`):
line 4 is a second module, after the first: choose another `.lm` the same
way (with no first on line 3 it says so). The first shows while the
second's parts load, then the second while the program loads, the tune
playing on through both (as on a PC: [below](#two-modules-one-after-the-other--then)).
The typical pair is a PETSCII screen with a scroller and counter, written by
PETSCII-LM with its line 8 at yes (at $A000), then a picture's module
from PICTURE-LM. The wait and count questions are then the second's. The two
mustn't share memory (SlopLoad 64 says so if they do). The second
needn't fit in memory beside the first: only its header and where its
parts go are kept, and its bytes are read from its file again as the
tape is written, as the program's are, so leave its disk in the drive.
One thing differs from the PC tool, to keep the code small: the
program's bytes in the first module's memory load after the second, with
the screen off, rather than while it runs.

**Music** is a SID tune of at most 4 KB (4,096 bytes of tune), as a
`.slm` file: a tune already tried out, with the stores the loader can't
allow taken out. Two ways to make one:

- **On the C64, SID-SLM** (on the same disk; below) tries a `.sid` out
  and writes its `.slm`.
- **On a PC, `tools/sidstrip.py tune.sid tune.slm`**: a five-minute check
  instead of SID-SLM's one, and the tune can then also be moved to
  another page when it is in the module's way.

A tune with many songs is often over 4 KB as a whole though each song
uses much less: `tools/sidstrip.py big.sid song3.slm -song 3 -cut` on a
PC keeps only that song's part (Your own music, above), and the `.slm`
goes on the disk for SlopLoad 64.

A tune that can play but not beside the chosen module is refused when you
press RETURN (`REFUSED: THE MODULE'S ZERO PAGE $003B`), so it can still go
with another module or alone.

The tunes on SlopLoad 64's disk are the demo tunes (Enigma Street,
SlopLoad, OZ Gold), as `.slm` files made on the PC (they can move) and
as `.sid` files for SID-SLM. They are in SlopLoad's own player: a `.slm`
made on the PC goes at $C000 beside a game, which keeps its sound
effects, as on a PC. A tune that stays where it is (a `.sid`, or a
`.slm` made by SID-SLM) plays with all three voices, without them.

**Pictures** are modules: PICTURE-LM (below, on the same disk) makes a
picture, in any of 16 C64 formats, into a `.lm`, with up to two loading
sprites and its own ending (wait for SPACE or fire), and SlopLoad 64
takes it as any module (3), with a tune beside it (5). The
disk's `SLOPLOAD.KOA` is a picture to try PICTURE-LM with. (Up to 0.12.0
SlopLoad 64 also read Koala and hires pictures itself, on a line of its
own; moving them out made the room for line 7's colours of your own and
line 8.)

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
- **Not there:** sound files, precompensation, `-nomotor`, tape sides,
  and the block size and leader length options. Pictures and their
  loading sprites are PICTURE-LM's: it makes them into a module that
  SlopLoad 64 takes, in VIC bank 3 (the PC tool picks the bank for a
  picture given as `-module`).

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
| `TOO LONG FOR SLOPLOAD 64` | the file is bigger than SlopLoad 64 has room for |
| `REFUSED: ...` | the tune can't be used, and why (it stays chosen with the reason shown, until another is chosen) |
| `THE MUSIC WAS REFUSED: ... CHOOSE ANOTHER, OR NONE (5)` | the tune chosen at line 5 can't be used, and why |
| `NO ROOM BESIDE THE SHOW MODULE` | the tune alone and the show module that plays it don't fit together beside the loader |
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
module (`.lm`): choose it in SlopLoad 64 as the module (3), and the screen
shows while the program loads, with the music you choose (5), and the
program starts as soon as it's in.

```
LOAD"PETSCII-LM",8
RUN
```

PETSCII-LM shows a menu, as SlopLoad 64 does: `*** PETSCII-LM ***` at
the top, then lines 1-8, one setting each. Press a line's number to
change it, as often as you like and in any order: its name appears in
reverse under the menu, with its questions below, and the menu comes
back with the change. **S** shows the screen as the module will show
it (the message's start on its row, in its colours, the rows next to
it cleared). **RETURN** writes the module, **@** is the disk (its status
and commands, `$` its files, as SlopLoad 64's @), **Q** goes back to
BASIC. At a file name, `$` lists the drive's files and `@` alone opens
its commands, and the name is asked again.
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
| 8 | chain | **first in a chain?** `y`: the module is written at $A000, not $E000, clear of a picture module's $C000-$FFBF, so a picture can be the second in a chain after it (SlopLoad 64's line 4, the PC tool's `-then`). The menu shows `FIRST IN A CHAIN: AT $A000` or `NO: AT $E000`. The same file as `tools/petscii.py -chain`. |

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

### PICTURE-LM: a picture with loading sprites, as a module

Also on the disk, **PICTURE-LM** makes a picture, up to two loading
sprites over it and its ending into a module (`.lm`): choose it in
SlopLoad 64 as the module (3), with a tune (5), and it shows while the
program loads. It is the module the PC tool makes of a picture given as
`-module` (the same show module), in VIC bank 3.

```
LOAD"PICTURE-LM",8
RUN
```

The menu works as PETSCII-LM's: a line's number changes it, **S**
shows the picture with the sprites as the module will show them,
**RETURN** writes the module (the picture's name, ending `.lm`), **@**
is the disk (its status and commands, `$` its files, as SlopLoad 64's
@), **Q** goes back to BASIC; the settings stay for the next. At a
file name, `$` lists the drive's files and `@` alone opens its
commands, and the name is asked again.

| line | setting | what it asks |
|---|---|---|
| 1 | picture | the formats it reads (listed first), then the drive and the file: a picture in any of the formats below; it says which it found (`A PICTURE IN ADVANCED ART STUDIO`) |
| 2 | sprites | what a sprites' file is (said first), then the drive and the file: one or two sprites, 64 bytes each (3 bytes a row, 21 rows, a spare byte; 63 will do, a `.prg`'s load address skipped); `-`, or drive 0, for none. `CASSETTE.SPR` on the disk is one: a cassette, white, 24 by 15 pixels (`pictures/cassette.spr`, made by `pictures/mkcassette.py`) |
| 3 | where | the sprites' lines (3-7) are set in under line 2, grey with no sprites. Their top left on the picture: x (0-319) and y (0-199); BOTTOM RIGHT until set |
| 4 | colours | their colour, or up to 32 they flash through, typed as hex digits (`1FCB0BCF`); the menu shows each digit in its own colour |
| 5 | speed | frames a colour [2] |
| 6 | mode | multicolour sprites? then their two shared colours (the menu: HIRES, or MULTICOLOUR and the two) |
| 7 | size | twice as wide and tall? |
| 8 | ending | wait for SPACE or fire once the program is in? (The music fades out after it, as every module's.) |

**Picture formats.** PICTURE-LM, `tools/picturelm.py` and the PC
tool's `-module` take these C64 formats, each told apart by its length,
and by its load address where two share one:

| | format | bytes (with the load address) |
|---|---|---|
| multicolour | Koala Painter, and Interpaint, Face Painter, Run Paint (Koala's layout) | 10,000-10,007 |
| | Advanced Art Studio | 10,018 |
| | Blazing Paddles (load address $A000) | 10,242 |
| | Artist 64 / Wigmore (load address $4000) | 10,242 |
| | Image System | 10,218 |
| | Saracen Paint | 10,219 |
| | Vidcom 64, Dolphin Ed | 10,050 |
| | Dolphin Ed (load address $5800) | 10,242 |
| | Drazpaint (unpacked) | 10,051 |
| | Micro Illustrator | 10,022 |
| | CDU-Paint | 10,277 |
| | Paint Magic (one colour for all of colour RAM) | 9,332 |
| hires | Art Studio, Interpaint hires (load address $2000, $4000, $6000, $A000 or $E000) | 9,002-9,011 |
| | Doodle (load address $1C00 or $5C00) | 9,026-9,218 |
| | Image System | 9,194 |
| | Hi-Eddi (load address $2000) | 9,218 |

The layouts are RECOIL's (and, for those it lists, the ShowVIC
picture viewer's), and pictures from RECOIL's own examples were read
and shown in each of them. Packed files aren't taken (unpack them with the tool
that made them), nor FLI and its kind (the loader can't run under a bad
line on every raster line), nor a picture from another computer: that is
a converter's job.

**S** shows the picture as the module will, with the sprites flashing;
the **joystick in port 2 moves them** a pixel a frame, inside the
picture, and **fire keeps the place** (any key leaves them where they
were), as Tape Master Pro's sprite editor does. Lines 3-7 are grey with
no sprites.

It writes the same file `tools/picturelm.py` makes on a PC with the
same settings (`tools/picturelm.py loading.koa loading.lm -sprite
ball.prg -spritepos 200,40 -wait`), about 12 KB (48 blocks): VIC bank 3,
the module and the colours at $C000, the screen at $CC00, the bitmap
and the sprites from $E000. A program using that memory loads its part
there after the picture has gone (and then the ending can't happen). On
a PC, such a file goes in as `-module loading.lm` too.

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
minimal game that already keeps the standard: `-module build/modules/template.lm`).
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
| `tests/petsciicheck.py [--module FILE] [--font F.64c] [--ntsc] [--c128 [--fast]] [--tap T] [--music N\|none] [--sid F] [--scroll TEXT --scrollrow N --scrollspeed N --scrollcolours HEX] [--counter R,C] [--shots DIR] [--cutoff]` | PETSCII-Load at every tick of a load (a `.pet`, `.petmate`, `.c` or `.lm`): VIC bank 2 and the case's `$D018` (or a font's, with its cut-down font in memory), border (red on a tape error) and background, screen and colours as the file has them (the message's row's as given, staying put), one tick a frame (5 in 6 on NTSC), the music; the scroller's split, every `$D016` write's line and value (inside the empty rows), its row always the message's next window, and the counter's digits; once loaded, to the module's stop: 000 held, the music still playing with `$D418`'s volume falling 15 to 0 in 16 steps of 8 ticks, `$01` as the loader has it, the RAM under the SID unchanged; then the program's PASS (`--cutoff`: mastered with `-nomotor` and a program reaching into the module's memory, so the loader cuts it off: its stop's two frames, as ozgoldcheck's) |
| `tests/petsciilm.py [--machine x128] [--ntsc]` | PETSCII-LM on the C64, its menu worked in one session: .pet files made into modules (a default name, a typed one, replace yes and no, the screen it shows checked, RETURN alone keeping it, a message with a counter, the message editor's keys (typing in, cursor keys, DEL after a quote mark, INST, HOME, CLR: the message checked each time, and the menu's line for it), the rows it lists that need nothing cleared against the file, a row whose neighbours it says it will clear, then clears on writing (as the PC tool does) and puts back, lines that need a message or a screen, a counter refused on the message's rows when asked and when written, the message's row's colours edited (colour keys, cursor limits, HOME, F, P; the editor's row, bar and arrow checked), following the row, and back to the screen's, S's preview, two files refused), a font of its own (read and shown in it, written with a message and a counter, a screen of all 256 characters, `-` back to the C64's own, a file too short, one read before a screen), each .lm the same as `tools/petscii.py`'s |
| `tests/piclmtest.py [--machine x128] [--ntsc]` | PICTURE-LM on the C64, its menu worked in one session: a Koala picture with the defaults, two sprites with every setting, S's preview (the VIC in bank 1, the sprites where line 3 put them) and the joystick moving them, then fire keeping the place, a hires picture (Art Studio's) with one sprite twice as big, a Doodle picture, four files and settings refused; each .lm the same as `tools/picturelm.py`'s |
| `tests/piclmtest.py --formats [--dir DIR]` | PICTURE-LM reading a picture in each of `tools/picturelm.py`'s formats (tests/picformats.py's, on a 1581; `--dir`: the pictures in a folder instead, such as RECOIL's examples) and saying which it is; each module the same as the PC tool's |
| `tests/picformats.py [--out DIR]` | a test picture in each format (the demo Koala's, or the hires test picture, each byte where its format puts it, junk in the rest), read back by `tools/picturelm.py` and made a module: its bitmap, screen, colours and background the picture's (no VICE) |
| `tests/petsciifont.py` | PETSCII-Load in a font of its own on the PC (a few seconds): the modules `tools/petscii.py` makes for screens in a test font (each character different), every cell, the message, the space and the counter's digits showing the file's characters through the cut-down font, at $B800 or $B000 as it holds 128 or more; the C64's own set unchanged; a short `.64c` and broken `.petmate` fonts refused |
| `tests/ozgoldcheck.py [--ntsc] [--c128 [--fast]] [--prg P] [--speed N] [--tap T] [--sid F] [--shots DIR] [--cutoff]` | OZ GOLD at every frame of a load: the VIC in bank 2 with the ROM font, screen and colours as designed, header byte 26 the blocks the tool says load while it runs, BLOCKS TO LOAD against the load's progress, one tick a frame (5 in 6 on NTSC), its own tune playing; once loaded, to the module's stop: 000 held, the tune's play routine called every tick with `$D418`'s volume falling 15 to 0 in 16 steps of 8 ticks, `$01` as the loader has it, the RAM under the SID unchanged; then the program's PASS (`--tap`: a tape SlopLoad 64 made; `--cutoff`: mastered with `-nomotor` and a program reaching into OZ GOLD's memory, so the loader cuts it off: the stop's two frames instead of the fade, the second a frame after the first with 000 drawn, the screen on and the SID silent) |
| `tests/memdiff.py file.tap file.prg` | compare memory with the .prg when the loader exits |
| `tests/channeltest.py ...` | load through a modelled deck (wow, flutter, peak shift) or through sound (`--audio wav\|mp3:192`, `--lowpass`, `--highpass`) |
| `tests/suite.py` | all the load cases in parallel (PAL, NTSC, C128, decks, CD, MP3, a dull head below speed 0) |
| `tests/sidcut.py [--quick]` | `tools/sidstrip.py -cut` on HVSC tunes: The Last Ninja song 5 (cut as its init leaves it, 3,808 bytes) and song 11 (the first cut fits), Golden Axe song 3, Mono song 1 (8 KB to 1.6 KB), Parsec song 3 (a copy loop up to the page past the end) and Hades Nebula song 2 (an address made by adding pages) cut, each `.slm` read back, played from the file and moved, against the whole tune (the same SID writes for 3,000 play calls); Fox Fights Back song 1 refused (it reads its own code as data); then Mono's cut song mastered beside Crossy-Load and loaded. In the suite |
| `tests/options.py` | the PC tool's options without VICE (a few seconds): those a run would ignore refused with their reason (a picture with another show, PETSCII options without a screen, a module on a tape side, sound options for a `.tap`...), and the usual ones still mastering |
| `tests/retrytest.py` | a damaged block, then a "rewind": the loader must recover |
| `tests/stoptest.py --where pilot\|header\|data` | the tape stopped and started again mid-block, then a rewind: TAPE ERROR, then a full load |
| `tests/ladderload.py speedtest.tap [N] [mode]` | load every file of a speed test tape in turn (reset, `LOAD`) |
| `tests/showcheck.py --show picture [--picture F.koa] [--shot F.png]` | the picture on screen as in the file, the music playing; `--sid tune.sid`: the tune's play calls keep its rate; `--shot`: a PNG of the frame VICE drew |
| `tests/endcheck.py [--show picture\|picmusic\|music] [--hires art\|doodle] [--wait] [--fade] [--sid T] [--ntsc] [--c128]` | the show's ending: `-wait`'s PRESS SPACE OR FIRE against the character ROM's letters, doubled, drawn from line 251 and done before the row's lines; the program not starting by itself for three seconds, then on fire (port 2); `-fade` over 128 play calls, the volume only going down; a hires picture (Art Studio's or Doodle's layout) in hires mode as in the file |
| `tests/waitcheck.py [--module NAME] [--wait [--end space\|game]] [--countdown] [--ntsc] [--machine x128] [--poke] [--prg FILE]` | a module's ending and `-countdown`: at every look while it loads, the number after the bar against the progress the kit drew (blocks left, or the percent); without `-wait` the module ending within a few ticks of the load with no key (a game mid-round, a loading screen after its fade); with `-wait` it staying 600 ticks until SPACE (`--end space`; OZ GOLD's PRESS SPACE), or a game played past the load ending at its game over (`--end game`); the program's own check |
| `tests/restorecheck.py [--module NAME\|none] [--ntsc] [--machine x128]` | RESTORE locked out: one NMI in stage 1, cia2's interrupt pending (the NMI line held low) at the core's start, at every look while it loads and at the exit, and clear once the program runs |
| `tests/chaincheck.py [--first FILE] [--then FILE] [--nosid] [--opts "..."] [--ntsc] [--c128] [--shots DIR] [--tap T --picture P]` | `-then` (or `--tap`: a chain SlopLoad 64 or the model wrote, `--first` and `--then` its .lm files): a PETSCII screen with a scroller and counter, then a picture (or a game): the first in VIC bank 2, its counter read every frame counting the second's blocks down to 000, never up; the screen off at the switch in the vertical blank; the core's frame vector then the second's; the picture as in the file; the tune's init called once (no restart) and the second's first play call within 2 frames of the screen going off (4 for a game); the program loaded |
| `tests/spritecheck.py [--sprites 1\|2] [--pos X,Y] [--colours C,...] [--mc A,B] [--expand] [--lm] [--ntsc] [--c128]` | `-sprite`: the VIC's sprite registers, pointers and bytes as asked, every store to the sprites' colour made outside their lines, the flash's colours in order, the program loaded; `--lm`: the same from a picture module file (`tools/picturelm.py`'s, `-module`), its picture, screen and colour RAM as in the file |
| `tests/cyclecheck.py [--stripes thin,6\|black\|eor:N,B] [--show picture] [--ntsc]` | `-cycle`: the border one colour on at each of 40 page crossings (or back to the effect's own at a block's end), the program loaded |
| `tests/jitter.py --speed N` | measure the edge timing error with the module running |
| `tests/frameprof.py [--ntsc] [--prg F]` | time each part of Flappy-Load's frame with the loader running |
| `tests/crossyprof.py [--ntsc] [--machine x128] [--sid F] [--auto 2]` | Crossy-Load's frame: when the vertical blank's work starts, when the split starts (by line 85) and ends, frames with it skipped (there must be none), each colour row written before the beam, when the frame's work ends |
| `tests/splitlook.py [--speed N] [--ntsc]` | Crossy-Load's frames as the emulator draws them (its own picture) against the screen memory: the play field where the split puts it, nothing moved sideways |
| `tests/splitmodel.py` | the split's stores against a model of the VIC's rows, for every fine scroll and start line |
| `tests/crossycheck.py [--god] [--ticks N]` | Crossy-Load's screen against its own lane tables as it plays (`--god`: the autopilot never dies) |
| `tests/squeezecheck.py [--frames N] [--crash N] [--ntsc] [--machine x128]` | Squeeze-Load as the emulator draws it, every frame, against its own tables (the girders' rows, line and gaps, the rocket's place and frame), pixel for pixel; its vertical blank work once a frame (none missed); the rocket never shown touching a girder while it plays, and every crash shown touching one (`--crash N`: every N frames the autopilot lets go of the stick until it hits) |
| `tests/rubblecheck.py [--frames N] [--crash N] [--ntsc] [--machine x128] [--fast]` | Rubble-Load as the emulator draws it, every frame, against its own tables (the blocks' heights, styles and window colours, the charge's column and line, a blast, the plane's place and frame, the town's colours), pixel for pixel, a town going up row by row too; its vertical blank work once a frame (none missed); the plane never shown touching a block while it flies, and every crash shown touching one (`--crash N`: every N frames nobody bombs and the plane is moved down to the tallest block's row); `--fast`: a C128 at 2 MHz |
| `tests/bouncecheck.py [--frames N] [--crash N] [--clear N] [--ntsc] [--machine x128] [--fast]` | Bounce-Load as the emulator draws it, every frame, against its own tables (the wall's bricks, plain, tough or cracked, the bat's and the ball's places), pixel for pixel; its vertical blank work once a frame (none missed); the ball's box never shown over the frame, a brick, or the bat (until it has gone past the bat's top); every turn the ball takes shown with it touching what turned it, and every brick knocked out or cracked shown touched the frame before (`--crash N`: every N frames nobody moves the bat until a ball is lost, games ending too; `--clear N`: the next brick hit ends the wall, the next built and checked); `--fast`: a C128 at 2 MHz (no picture: the tables, collisions and frames) |
| `tests/framecap.py [--ntsc] [--machine x128] [--auto 1\|2] [--walk] [--frames N]` | Crossy-Load as the emulator draws it, every frame: how far the play field moved, frames whose vertical blank work never ran (a frame missed: shown with the split's scroll), pauses; `--walk`: the joystick held right, then left, as she hops; `--plain --tap T` for an older tape |
| `tests/crossyrules.py [--ntsc] [--deaths N] [--ticks N]` | Crossy-Load's world: nothing moves (lanes, the play field's screen and colours) from the tick after the hen dies to the game over; and every river made next to another goes the other way |
| `tests/crosstear.py [--ntsc] [--machine x128] [--walk] [--auto 1\|2] [--frames N] [--save DIR]` | Crossy-Load's play field as the emulator draws it, row by row, against memory just before and just after the frame's changes: a row that is neither was written as the beam crossed it, and a lane whose two rows come from different moments is torn (a train's halves out of line) |
| `tests/crossywalk.py [--ntsc] [--machine x128]` | Crossy-Load's hen walked with the joystick (the monitor's joyport): a pixel a tick each way, stopping two columns from each edge, her block on show where she is; then walking while hopping nonstop, within the play field |
| `tests/lanelag.py [--ntsc] [--machine x128] [--auto 1\|2]` | how far behind Crossy-Load draws each lane on show, and for how many ticks in a row (`--auto 2`: hopping forward nonstop, the screen scrolling every tick) |
| `tests/crossylook.py [--auto] [--ticks a,b,c]` | pictures of Crossy-Load at those ticks, drawn from VICE's memory (`tests/vicshot.py`) |
| `tests/frametime.py [--ntsc]` | count late status-line splits |
| `tests/irqcycles.py` | the core interrupt's cycle counts per path and class, against the shortest pulse and the tool's model, and each loading line effect's cost |
| `tests/sfxcheck.py [--module M] [--sid F] [--ntsc] [--expect effects\|music]` | a game's sound effects beside a tune in VICE: every store to voice 3 while the module runs. With a tune in SlopLoad's own player: the tune at $C000, the header's +24 1, the player's flags handing voice 3 over (and its NTSC pitch table on NTSC), voice 3 written by the effects only; with any other tune, or a module that makes no effects (OZ GOLD): +24 2, voice 3 the tune's |
| `tests/demos.py` | (for the tests) the demo modules and tunes as the files the PC tool takes: a test's `--module flappy` is `build/modules/flappy.lm`, and a module that brought the old built-in songs plays Enigma Street unless told otherwise |
| `tests/stripecheck.py` | the loading lines in VICE: every store to the border caught while a program loads, before the show and during it, and checked against the style or effect (`classic` one colour on a pulse, `eor:N` by turns, `and:N`'s bits...); with `-showstripes` the core's lines go on and nothing else touches the border, without they stop |
| `tests/pllsim.py` | Monte Carlo of the speed tracking under wow |
| `tests/sideload.py side.tap a.prg b.prg ...` | load every program on a tape side in turn (reset, `LOAD`), each compared with its .prg |
| `tests/seams.py out.tap SPINUP [--prg F]` | SlopLoad 64's block-at-a-time tape with each motor stop modelled (a gap, switching noise, the next pilot recorded while the motor speeds up over SPINUP seconds), then loaded |
| `tools/seamcheck.py dump.tap` | a real cassette written by SlopLoad 64, dumped back: each seam's slow start and the steady pilot left after it |
| `tests/tapwrite.py in.tap [--reu KB] [--machine x64sc\|x128] [--ntsc] [--kernal FILE] [--load prog.prg] [--expect TEXT] [--browse]` | the TAP writer in VICE: VICE's recording of what it wrote against the .tap, pulse by pulse, then loaded; the motor must be off until it writes (PLAY is down from the start); `--kernal`: another KERNAL, such as JiffyDOS; `--browse`: first `$` (two pages), `$:T*` and `@` with a command at the file question, the text's colour kept after "more" |
| `tests/c64disk.py [--truedrive] [--many]` | SlopLoad 64's @ (the disk) in VICE: the directory listed, a file renamed and scratched through the command channel with the drive's answers checked, then back to the menu; `--many`: a directory long enough to stop for a key; `--truedrive`: an emulated 1541 |
| `tests/c64tool.py [--module NAME\|FILE.lm] [--chain FILE.lm [--chainrefused TEXT]] [--music FILE.sid\|FILE.slm] [--cleared] [--colours STYLE\|C,C,...] [--effect NAME [--fxn N]] [--cycle] [--showl] [--out tap\|tape] [--machine x64sc\|x128\|xscpu64] [--xmem reu\|sram] [--reusize KB] [--says TEXT] [--fast] [--tapdisk d64\|d81] [--scpurom cmd] [--tname TEXT] [--expect TEXT] [--tuneat HEX,N] [--then MODULE] [--prgdrive 8\|9] [--ntsc] [--kernal FILE] [--load]` | SlopLoad 64 in VICE, its menu worked through the keyboard (each "press any key" answered): its .tap (or the cassette it recorded) against `tools/c64model.py`'s, then loaded. A `.sid` is made a `.slm` by SID-SLM first, on the same disk. `--fast`: a C128's 2 MHz forced on at the start; `--tapdisk`: the .tap to a 1541 or 1581 image (true drive emulation); `--scpurom cmd`: CMD's SuperCPU ROM; `--cleared`: the module and tune chosen, then cleared with 0 (the tape has neither); `--colours`: line 6 (a palette's name, or your own colours: one number, a plain border); `--effect`: line 7 (standard, classic ... eor, block; `--fxn` and, ora and eor's value), `--cycle` and `--showl` its questions; `--tname`: the name on tape typed as keys (`{clr}{white}...`); `--expect`: a refusal it must stop with; `--tuneat c000,1`: where the tune must go and the header's +24; `--then`: a second tape in the same session with that module, against the model too; `--prgdrive 9`: the program read from drive 9, with the .tap; `--ntsc`; `--kernal FILE`: another KERNAL (x128: its C64 mode's), such as JiffyDOS: the cassette must come out the same. To the cassette, the motor must be off each time a block is coded (PLAY is down all along) |
| `tests/c64suite.py [--only NAME ...] [--list]` | SlopLoad 64's 90 cases in parallel: every kind of show, speeds below 0, modules (the games, OZ GOLD and PETSCII-Load, and PETSCII-Load in a font of its own, one beside a 63 KB program, loaded), tunes (a `.sid` made a `.slm` by SID-SLM, `.slm` files from the PC and the disk, one moved, then a second tape in the session with another module, one song of a tune too big for SlopLoad 64 cut by `sidstrip.py -cut`), a module and a tune chosen then cleared, pictures as modules (PICTURE-LM's: Koala, the disk's own, one with a tune that must move, hires ones with their own wait), loading lines (palettes, your own colours, black, block, one colour, the effects from line 6's colours, on through a module, a picture and music), cassette and REU (512 KB, 1 MB, 16 MB: its size said), C128, SuperCPU, 1581, 63 KB, a SYS start, the program read from drive 9 (VICE's host folder, a 1541 image), a tune in SlopLoad's own player (a `.slm` made on the PC at $C000 beside a game, loaded, and for the show's NTSC pitch; a `.sid`, and a module that makes no effects, where the tune is), the tune alone's fade, a picture module's own ending (wait and fade), hires pictures (Art Studio's, loaded; Doodle's on NTSC), the border cycle (under an effect, one colour, black to the cassette), a picture module from `tools/picturelm.py` with two sprites and a tune (loaded), and ten refusals (one a module that keeps its border, with the lines on through it; the cycle under a picture without them; a fade with a program loading into the show) |
| `tests/c64modes.py` | SlopLoad 64's core made in one loading-lines mode after another in the same session (rainbow, styles, black, block, one colour in two colours, and back): each as that mode alone makes it |
| `tests/trialtest.py` | SID-SLM's trial run (`c64/trial.asm`) in the simulator and in VICE against `tools/sidstrip.py`, tune by tune and instruction by instruction |
| `tests/sidslm.py [--machine x128] [--ntsc] [--quick]` | SID-SLM in VICE, its questions typed: `$`, `$:E*` and `@` with a command at the file question first (the text's colour kept after "more"); tunes made `.slm` files (a song chosen, a CIA-timed tune, a name replaced), each compared with the PC's check of the same 3,000 play calls field by field; six refusals, each with the PC's reason; then songs of tunes over 4 KB cut (Mono song 1 written, against `tests/cuttest.py`'s reference cut tried over 15,000 play calls; Golden Axe song 3 still over 4,096 bytes; Fox Fights Back song 1 plays differently cut; the Last Ninja, 35 KB, its pages read from the disk again: song 11 written, song 5 written as its init leaves it, its first cut over 4,096), with the C64 minutes each took |
| `tests/cuttest.py [tune.sid[:song] ...] [-n CALLS] [--vice] [--pc] [--paged N] [--after]` | SID-SLM's cut (`c64/sidcut.asm`) in the simulator (or VICE) against `tools/sidstrip.py`'s `cut_pages`, step by step: the code run, the bytes used, the trace's marks, spans and compares, the static walk, the ends, the pages kept and their places, the cut's bytes, init and play; its opcode tables against the simulator's. A cut over 4,096 bytes (any, with `--after`) is made again as the tune's init leaves it (`cutafter` against `after_init`): that tune's range and stub, then the same comparisons. `--paged N`: only N of the tune's pages in memory, the rest read in as the cut asks (a tune too big to lie whole, as the Last Ninja, is paged with 40). In the suite (`sid-cut-c64`, and `sid-cut-c64-paged` with 6 pages) |

They start their own headless VICE (`tests/vicerun.py`) with a throwaway
config, so your VICE settings are never touched.

On real hardware: [REALTEST.md](REALTEST.md) lists the tests VICE can't
do (a real datasette's motor and heads, an Ultimate's turbo), and
`python3 tools/realkit.py` puts their files in `realtest/`.
