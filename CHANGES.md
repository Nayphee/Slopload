# SlopLoad releases

## 0.13.0 (2026-11-07)

A picture is a module now, on the PC and in SlopLoad 64, and SlopLoad
64's menu was redone around that: nine lines, the second module of a
chain on a line of its own, the loading lines' colours (a palette, or
your own) apart from their effect. Every module's music fades out at the
end, games included. PICTURE-LM and PETSCII-LM have the disk's `@` and
`$`, and PICTURE-LM a tidier menu and a cassette sprite to try. Two new
game modules: Rubble-Load, a city bomber, and Bounce-Load, a breakout.
Passes the test suites in VICE (211 PC cases, 94 SlopLoad 64 cases; one
PC case, `cutoff-ozgold`, passed its check but VICE then hung closing,
as it did once before 0.12.0), and PETSCII-LM's and PICTURE-LM's own
tests on PAL, NTSC and a C128. Not played on a real C64.

**A picture is a module, and SlopLoad 64's menu is shorter.** Pictures
no longer have options and lines of their own; they go where every other
show goes, the module.

- **On a PC:** `-module loading.koa` makes the picture module there and
  then, in any of PICTURE-LM's 16 formats (it took only Koala, Art
  Studio and Doodle before), with `-wait` and `-sprite` as before, and the picture still placed in the VIC bank that leaves most
  of the program loading. A picture can also start a chain (`-module
  loading.koa -then ...`). `-show picture`, `-show picmusic` and
  `-picture` are refused with a pointer to `-module`. `-sid` alone now
  means the tune alone, so `-show` is seldom needed.
- **SlopLoad 64's menu is nine lines:** 1 program, 2 name, 3 module, 4
  second module, 5 music, 6 speed, 7 colours, 8 effect, 9 write to;
  RETURN: MASTER TAPE.
  - SHOW goes: what shows follows from lines 3 to 5.
  - PICTURE goes: PICTURE-LM's `.lm` is chosen on line 3.
  - START goes: a program that doesn't load at $0801 is asked for its
    SYS address on line 1.
  - The second module of a chain has its own line, 4, which needs line
    3's first; another first module clears it.
  - 0 clears the module, the second or the tune, as the drive or from
    the list.
- **Colours and effects, split:** line 7 is the colours, a palette or
  your own (1-12 colours typed as `6,14,3`, as the PC tool's `-stripes
  6,14,3`); line 8 is the effect, SlopLoad's standard stripes first, then
  classic, thin, mixed, and, ora, eor (starting from line 7's first
  colour) and block, then the colour-a-page cycle and "bars during the
  module or music?" (`+DURING`).
- **The room for it:** SlopLoad 64's own picture reading went, freeing
  about 1,150 bytes (1,243 to spare now, from 91).

**Every module's music fades out at the end.** Once the program is in,
the tune fades over about 2.6 seconds (16 volume steps) before the
program starts, whatever plays it: a game (which plays on meanwhile:
the kit's new `gk_exit`, each game's frame's last call), a picture, the
tune alone, a loading screen (as before). With no music, or S pressed in
a game, the program starts at once. The fade is the loading screens'
`src/fadekit.asm`, which every module now includes where it has room
(about 300 bytes and 84 of scratch, `src/fadescr.asm`): Squeeze-Load,
Rubble-Load and the template after their code; Flappy-Load and
Bounce-Load in a second part at $CE80; Crossy-Load's low part now starts
at $C94F, not $CAEA, and ends where it did. The fade is no longer an
option: `-fade` is kept for old command lines, SlopLoad 64's music line
no longer asks, PICTURE-LM's ending is the wait alone, and a fade with
part of the program loading into the show's memory isn't refused any
more (the show fades, then that part loads).

**PICTURE-LM and PETSCII-LM: the disk, and clearer menus.** Both have
SlopLoad 64's `@` (a drive's status and commands, `$` its files) on the
menu, and `$` and `@` at their file names. PICTURE-LM lists the 16
formats it reads before asking for a picture; its sprites' lines (3-7)
are set in under SPRITES; the sprites' colours show each digit in its
own colour; THE END is ENDING (the wait); drive 0 means no sprites, as
`-` does. Both say RETURN: WRITE THE MODULE.

**A loading sprite to try: a cassette.** `pictures/cassette.spr` (made
by `pictures/mkcassette.py`), one hires sprite, 24 by 15 pixels, is on
SlopLoad 64's disks as `CASSETTE.SPR`; PICTURE-LM's line 2 says what a
sprites' file is (64 bytes a sprite) and names it. On a PC:
`-module pictures/slopload.koa -sprite pictures/cassette.spr`.
`tests/spritecheck.py --sprite FILE` loads a file of your own over a
picture.

Tested: SlopLoad 64's suite, 94 cases (new: your own colours as stripes,
on a cassette and under an effect; a module and a tune chosen then
cleared), every tape the same as `tools/c64model.py`'s to the byte; the
PC tool's option tests and suite.

**PICTURE-LM's menu lines up.** The settings' names were printed with
nothing after them, so each ran into its value (SPRITESNONE,
MULTICOLOURNO, THE ENDTHE PROGRAM STARTS AT ONCE); they are twelve
characters now, and every value starts in column 14, as PETSCII-LM's
do. THE END with both choices reads SPACE OR FIRE; MUSIC FADES, which
fits the line. `tests/piclmtest.py` unchanged and passing (its modules
the PC tool's to the byte).

**Rubble-Load, a new game module.** `-module build/modules/rubble.lm`
(`rubble-load.lm` on SlopLoad 64's disk): the old town is coming down,
and you fly the demolition plane. It crosses the screen back and forth
over sixteen blocks, a row lower at every turn; fire drops a charge from
under it, and the block it lands on loses its top storey. Flatten the
town and the plane glides down and lands on the street; the next town is
taller, the plane faster and the sky another colour. Fly into a block
and the game is over. An original design in the city-bomber genre,
written to MODULES.md like Squeeze-Load: the plane one multicolour
sprite (jitter 56: measured 53 on PAL, 54 on NTSC and a C128, 59 at
most), the town, the charge and the blasts characters, everything on
screen changed in the vertical blank; sound effects on voice 3 beside
SlopLoad's own player; `-wait` and `-countdown`; second in a chain.
`tests/rubblecheck.py` compares VICE's picture with the module's tables
every frame (towns going up, charges, blasts, landings, crashes) on PAL,
NTSC and a C128, at 2 MHz too; the suite has its loading cases (speeds 0
to 13, MP3, a SID tune, each way of starting, a 250-block program),
sound effects, `-wait`/`-countdown` and chain cases, and SlopLoad 64's
suite two more (with a tune and without, loaded). Not yet played on a
real C64.

**Bounce-Load, a new game module.** `-module build/modules/bounce.lm`
(`bounce-load.lm` on SlopLoad 64's disk): knock a wall of bricks down
with a ball, bounced off a bat at the foot of the field. Left and right
on port 2 move the bat; fire serves (or the ball goes by itself); where
it meets the bat sets its angle. Eight walls in turn, some bricks taking
two hits; the ball speeds up with each wall and the longer it is kept in
play; three balls. An original design in the breakout genre (its own
name, pictures, walls and sounds), written to MODULES.md: no hardware
sprites (jitter 48: measured 48 on PAL, NTSC and a C128, 51 at most).
The ball and the bat are soft sprites in characters of their own, two
sets taking turns, drawn during the tick and swapped in the vertical
blank with everything else that changes on screen, so nothing tears.
Collisions go by what is drawn: the ball moves a pixel at a time and
stops at what it meets, so the frame after a bounce shows it touching
what turned it, and a brick is seen touched before it goes. Sound
effects on voice 3 beside SlopLoad's own player; `-wait` and
`-countdown`; second in a chain (the tune pauses 3 frames at the switch,
as for Flappy-Load and Squeeze-Load). `tests/bouncecheck.py` compares
VICE's picture with the module's tables every frame and checks every
bounce and brick hit, through lost balls, games over and new walls, on
PAL, NTSC and a C128, at 2 MHz too; the suite has its loading cases
(speeds 0 to 13, MP3, a SID tune, each way of starting, a 250-block
program), sound effects, `-wait`/`-countdown` and chain cases;
`tests/stoptest.py` and `tests/retrytest.py` pass with it; and SlopLoad
64's suite has two more (with a tune and without, loaded). Not yet
played on a real C64.

`tests/waitcheck.py` now stops at the start of the kit's `status` before
each look at the status line: looking part way through its drawing (the
progress stored, the number not yet written) failed now and then, more
often with some modules' frame timing than others.

## 0.12.0 (2026-11-06)

Two modules on one tape, a PETSCII screen with its scroller and block
counter while a loading picture loads, then the picture while the
program loads: `-then` in the PC tool, and in SlopLoad 64 a second
module on line 4 (with PETSCII-LM's new line 8, a screen made for it).
PICTURE-LM and `tools/picturelm.py` read 16 kinds of C64 picture, tried
on 24 real pictures. SlopLoad 64's messages are packed to make the room.
Passes the test suites in VICE (156 PC cases, 87 SlopLoad 64 cases;
three PC cases that time out or sample late under the suite's load pass
alone), and PETSCII-LM's and PICTURE-LM's own tests on PAL, NTSC and a
C128.

**Two modules on one tape (`-then`).** `slopload.py prog.prg prog.tap
-module title.pet -scroll "..." -counter 20,26 -then loading.koa -sid
tune.sid` shows the PETSCII screen, its scroller going and its counter
counting the picture's 48 blocks down to 000, while the picture loads;
then the picture while the program loads. The tune plays on through the
switch without starting again. `-then` takes a module (`.lm`, a module's
`.prg`, a PETSCII screen) or a picture in any of PICTURE-LM's formats,
which it makes into the picture module (`-wait`, `-fade`, `-sprite` go
to it). The loader core is unchanged: the switch is 93 bytes the tool
loads to the tape buffer, set off by a spare block flag. In a chain a
PETSCII screen is built at $A000 (`petscii.py -chain` makes such a .lm).
The kit and the picture module now keep a chain's tune playing (header
byte 27 and 28, bit 4); PETSCII-Load's counter shows 000 at full
progress. Tested in VICE on PAL, NTSC and a C128 (`tests/chaincheck.py`:
the counter every frame, the switch in the vertical blank, the picture
as in its file, the tune's init called once, the program loaded), into
a multicolour and a hires picture, Flappy-Load and Squeeze-Load, and a
game first with a PETSCII screen second.

SlopLoad 64 chains too: line 4 asks **then a second module, after it?**
once the first is read. The second's bytes are read from its file as the
tape is written, so a PETSCII screen and a 12 KB picture need not fit in
memory together. PETSCII-LM's new line 8 writes the screen at $A000 for
a chain. Its tapes are the model's (`tools/c64model.py`) byte for byte,
to a cassette and a .tap, from an REU, on NTSC and a C128, and load in
VICE as the PC tool's do (`tests/chaincheck.py --tap`). To make room,
SlopLoad 64's messages are packed at the build (a table of 64 pieces:
855 bytes freed, the text on screen unchanged).

Also: with `-wait`, a module's report no longer says PRESS SPACE OR FIRE
across the picture's bottom row, which only a picture does.

**PICTURE-LM takes more C64 picture formats** (and `tools/picturelm.py`,
which makes the same file): Advanced Art Studio, Blazing Paddles, Artist
64, Image System (multicolour and hires), Saracen Paint, Vidcom 64 and
Dolphin Ed, Drazpaint (unpacked), Micro Illustrator, CDU-Paint, Paint
Magic, Hi-Eddi, and Koala's kind up to 10,007 bytes (Face Painter),
beside Koala, Art Studio and Doodle. Each is told apart by its length
(and its load address where two share one); the layouts are RECOIL's,
and ShowVIC's where it lists them. One table in `tools/picturelm.py`,
from which `tools/c64build.py` makes PICTURE-LM's. PICTURE-LM says which
format it found. `-show picture` and SlopLoad 64's picture line keep
their three. Tested with a picture in each format made from the demo's
(`tests/picformats.py`): PICTURE-LM writes the same module as the PC
tool for every one, and modules from five of them load in VICE with the
picture as in the file. Then with 24 real pictures, RECOIL's own
examples in every format: each read as its format and drawn right,
PICTURE-LM's module the PC tool's for all 24, and seven of them loaded
in VICE as in their files. They showed two layouts the first table
missed: Doodle saved at $1C00 (it was taken for Hi-Eddi, which is now
$2000 only) and Dolphin Ed's 10,242-byte files (load address $5800).

## 0.11.0 (2026-11-06)

Features borrowed from TND's Tape Master Pro 5.1: the end of the load
held for SPACE or fire, the music faded out, hires pictures, the border
a colour on each page, and loading sprites over the picture, with a new
C64 tool, PICTURE-LM, that makes a picture with its sprites into a
module; and from TND's Loader Game Tape Master Kits, `-wait` and
`-countdown` for modules and RESTORE locked out while a tape loads.
Passes the test suites in VICE (117 PC cases, 78 SlopLoad 64 cases),
PICTURE-LM's own test on PAL, NTSC and a C128 (each module the same as
`tools/picturelm.py`'s), and the new checks: the ending
(`tests/endcheck.py`), the sprites (`tests/spritecheck.py`) and the
cycle (`tests/cyclecheck.py`).

**The end of the load** (`-wait`, `-fade`; SlopLoad 64: asked with the
picture and the tune). With a picture, `-wait` puts PRESS SPACE OR FIRE
across its bottom row once the program is in, the letters from the
character ROM twice as wide, drawn below the picture so the row changes
whole, and the program starts on SPACE or fire (port 2). With music,
`-fade` fades it out over about 2.6 seconds first (the modules' fade,
src/fadekit.asm). Neither goes where part of the
program loads into the show's memory (both tools say so).

**Hires pictures.** `-picture` (and SlopLoad 64's line 6) takes Art
Studio's layout (a bitmap, then its screen: load address $2000, 9,009
bytes; $4000, $6000, $A000 and $E000 as well) and Doodle's (load address
$5C00), told apart from a Koala picture by size and load address.

**A colour on each page** (`-cycle`; SlopLoad 64's line 0): the
border's colour one on with every 256 bytes loaded, under an effect or
one colour (black, or `-stripes 6`: a plain border through all 16). A
3-byte place in the core's page crossing, which skips itself in 3
cycles when off (the worst path still fits: 167 cycles of the 168) and
is `INC $D020` when on (the shortest pulses 3 cycles longer). With a
module or a show it needs `-showstripes`.

**Loading sprites** (`-sprite FILE`, `-spritepos`, `-spritecolours`,
`-spritespeed`, `-spritemc`, `-spriteexpand`): one or two sprites over
the picture, flashing through up to 32 colours, their colour changed
only while the beam is outside their lines. Measured, a sprite on a
line adds 8 cycles to the worst edge timing error (51 with none, 59
with one, 64 with two side by side, 118 with eight): the tool counts 8
and 16, and two is the most the loader's pilot window allows. At speed
0 with a picture the margin is already at the core's most, so there
the sprites use some of the tape's own margin (the report says how
much).

**PICTURE-LM** (on SlopLoad 64's disks; `tools/picturelm.py` on a PC
makes the same file): a picture, its sprites and its ending made into a
module (`.lm`), with a menu as PETSCII-LM's and S showing the picture,
the joystick moving the sprites over it. SlopLoad 64 had no room left
for sprites; it takes the module as any other, with a tune beside it.

**Found on the way.** The show module was placed by its bytes, not by
the memory it claims (the PC tool, the model and SlopLoad 64 all now use
the claim). `tests/showcheck.py` and other tests read the placed show
module's symbols from a file every run writes: two runs at once could
read each other's (they now work it out from their own report).
SlopLoad 64's model failed on an effect with no show (a key missing).

**From TND's Loader Game Tape Master Kits** (the three loader-game kits
of 2013-2017, studied in VICE; their six games stay TND's and Joonas
Lindberg's: not ported):

- **Nothing waits by default; `-wait` with a module** (the user's rule:
  the loading doesn't wait for the player unless whoever masters the
  tape asks for it). Once the program is in, every module ends and the
  program starts: a game mid-round too (it used to play on to the end
  of the round, or wait for SPACE), OZ GOLD and PETSCII-Load after their
  000 and fade as before. `-wait` (SlopLoad 64: asked with the module,
  when it keeps it) makes it stay, as the kits' games played on until
  their key: a game until SPACE or the end of a game, round after round
  until then; OZ GOLD and PETSCII-Load at 000 with the music on (OZ GOLD
  with PRESS SPACE on its tape error row) until SPACE, then the fade. Not
  with `-nomotor` when part of the program loads into the module's
  memory.
- **`-autorun` is gone** (the user chose it): it is what happens now
  anyway. The tool refuses it with that hint; SlopLoad 64's line 8 no
  longer asks "start as soon as it is loaded?". The loader still cuts a
  module off itself when `-nomotor` leaves part of the program to load
  after it.
- **`-countdown`** (SlopLoad 64: asked the same way): a game's status
  line counts the blocks still to load down to 000 ("024", as the kits'
  games did) where it showed the percent.
- **RESTORE locked out while it loads**: stage 1 enables cia2's timer A
  interrupt and never reads it, so the NMI line stays low and the key
  can't interrupt the loader (a press used to cost the tape's interrupt
  about 13 cycles, at any edge); the exit reads it after ioinit, and the
  program has RESTORE back. Nothing added to the core: stage 1 arms it in
  its header part's spare bytes (its own code 6 bytes shorter), and 7
  bytes at the end of its KERNAL-loaded block release it (about 0.15
  seconds more KERNAL boot).
- **The module standard** (MODULES.md): the header's byte 27 says what a
  module keeps (bit 2 `-wait`: `g_wait`, bit 3 `-countdown`: `g_count`)
  and byte 28 is the tool's options for every module (the show module's
  bits as before); the kit's `startkey` ends the module once the program
  is in (with `-wait`, on SPACE), its `gk_done` at a game over (with
  `-wait`, a game's end starts the program), its `status` counts; `gk_musinit` copies the options and blocks into the
  kit, as Flappy-Load draws over its header. `src/modinit.asm` holds the
  kit's init-only routines (`gk_musinit`, `sidinit`), so a module can run
  them from memory it draws over afterwards: Crossy-Load from its boot
  code in screen A, Flappy-Load after its texts in screen A, which made
  the room. All five modules keep the new rules. The percent is now
  progress × 100 / 256 (it reached 97% at most; now 99%).
- **SlopLoad 64** writes stage 1's block straight from its own copy, its
  length from the build (it was a fixed 58 bytes, in a buffer that
  couldn't grow past $CFFF).
- **Tests**: `tests/waitcheck.py` (the number after the bar at every
  look; without `-wait` the module ended within a few ticks of the load
  with no key, with it held until SPACE or ended at a game over),
  `tests/restorecheck.py` (one NMI in stage 1, the line held through the
  load, freed for the program), suite and SlopLoad 64 suite cases, and
  `tests/options.py`'s refusals; `tests/c64tool.py` answers the module's
  questions on a second tape in the session too; `tests/ozgoldcheck.py`
  and `tests/petsciicheck.py`'s `--autorun` is `--cutoff` (`-nomotor`
  with a program in the module's memory). `tests/crossyprof.py` looked for an
  instruction an earlier change had replaced (it and
  `tests/framecap.py` stopped at their start): fixed.

**Squeeze-Load**, a new game module (`build/modules/squeeze.lm`; an
original design in the falling-rows genre the kits' games come from):
a rocket at the foot of a mine shaft, steel girders falling down it, each
with a gap; left and right on port 2 slip the rocket through. Every five
girders the fall speeds up, the gaps narrow and the girders change
colour (the gaps never move further from one to the next than the
rocket can reach); touching one ends the round. The girders fall
smoothly with no scrolling: they share one line in their row, so only
six characters' glyphs change each frame (in the vertical blank), and
their screen codes change only when the cells show a blank glyph. The
rocket is one multicolour sprite (`g_jitter` 56: measured 52-53 at
99.9%, 60 at most). Collisions go by what each frame shows, the rocket's
rows against the girders' lines. Sound effects only, on voice 3; it ends
once the program is in, or keeps `-wait` (SPACE, or the end of a round)
and `-countdown`. Tests: `tests/squeezecheck.py` (VICE's own picture of
every frame against the module's tables, pixel for pixel; no frame
missed; no frame showing the rocket in a girder while it plays, every
crash showing it), suite cases as Crossy-Load's (PAL, NTSC, C128, speeds
0 and 13, MP3, the whole program, a SID tune, the effects, `-wait` and
`-countdown`), `tests/stoptest.py` and `tests/retrytest.py`, and
SlopLoad 64 mastering it (`tests/c64tool.py --module
build/modules/squeeze.lm --load`).

## 0.10.0 (2026-11-06)

More loading lines: six effects as classic turbo loaders ran them
(`classic`, `thin`, `mixed`, `and:N`, `ora:N`, `eor:N`), and the lines
on through a module, picture or music (`-showstripes`), on the PC and
SlopLoad 64. And nothing is built into the tools any more: modules and
tunes are files, the demos included, and the games keep their sound
effects beside a tune in SlopLoad's own player. Passes the test suites
in VICE (90 PC cases, 64 SlopLoad 64 cases), each loading line effect
checked store by store in the border, a game's effects and a tune's
voices checked store by store on voice 3, and SID-SLM, PETSCII-LM, OZ
GOLD and PETSCII-Load's own checks.

**More loading lines: six effects, as classic loaders did them.**
`-stripes` (and SlopLoad 64's line 0, `EFFECT`) gains the 6502 code old
turbo loaders ran for each pulse: `classic` (`LDA $D020 : EOR #$00 :
INC $D020`, multicolour stripes), `thin` (`INC $D020 : DEC $D020`, thin
lines on a plain border), `mixed` (`INC $D020 : EOR #$00 : INC $D020`),
`and:N` and `ora:N` (the byte coming in off the tape, `AND` or `ORA #N`,
into the border) and `eor:N` (`LDA $D020 : EOR #N : STA $D020`, two
colours by turns). `,B` sets the colour each starts from (`thin,6`: a
blue border with thin lines). They live in a third core, the effect's 8
bytes patched in by the tool (SlopLoad 64 patches its one copy in
place). Each lengthens the loader's interrupt by 6 to 10 cycles, and
the shortest pulses grow to match. Every style from before is still
there.

**The lines on through the module, picture or music** (`-showstripes`;
SlopLoad 64 asks `ON THROUGH THE MODULE OR SHOW?` and shows `+SHOW`):
the loading lines no longer have to stop when the screen comes on. The
border is then the loader's, a tape error turns it red until the loader
recovers, and the module leaves it alone. Modules say so in a new
header byte (+27, `g_border`) and set the border through the kit's
`gk_bord`; the five demo ones and the show module do, and a module
of your own that doesn't is refused with it (MODULES.md).

**Modules and tunes are files: nothing built into the tool.** The PC
tool looked the demo modules up by name (`-module flappy`, the default)
and played two songs built in beside them (`-music N`). Now a module is
always a file (`-module build/modules/flappy.lm`; with no `-module` the
screen stays off) and a tune is always a file (`-sid music/build/enigma.sid`;
`-music` is gone, and says where the songs went). The demos are files
like anyone else's: `build/modules/*.lm` and `music/build/*.sid`, as on
SlopLoad 64's disk. The games keep their sound effects with the demo
tunes: those are in SlopLoad's own player, now marked ("SLP1" after its
jump table), and a tune in it goes at $C000, where the player leaves
voice 3 to the game and plays in tune on NTSC, on the PC and on
SlopLoad 64 (a `.slm` made on the PC). Modules say in their header
whether they make effects (+27 bit 1, `g_sfx`); one that makes none
(OZ GOLD, PETSCII-Load) now plays any tune with all three voices.
`speedtest.py` takes `-module FILE` and `-sid FILE` (the demos by
default). A release carries the new effects core (`core_fx`) too.

**Found on the way:** moving a tune in SlopLoad's own player left its
stop routine pointing at the old place (the tool moves the addresses a
trial run uses, and the trial never stopped the tune). Nothing called it
before; with the tune at $C000 a game's stop jumped into the program and
hung at the hand-over. The trial now also stops the tune and plays it
with each of its flags.

Flappy-Load could write voice 3 once as it started (an effect timer left
over in memory), cutting a note of a tune that has all three voices: it
clears it now.

## 0.9.0 (2026-11-02)

A song of a big tune is cut again as the tune's init leaves it when the
first cut is over 4 KB, so The Last Ninja's song 5 fits in SlopLoad
64's 4 KB (on the PC and the C64, with the same bytes); PETSCII screens
can be drawn in a font of their own, on the PC and in PETSCII-LM; and
SlopLoad 64 says an REU's size up to 16 MB. Passes the test suites in
VICE (76 PC cases, 53 SlopLoad 64 cases), with SID-SLM's cuts on a C64
(The Last Ninja's song 5 in 124 C64 minutes), and PETSCII-LM's menu
with a font on a C64 and a C128 in C64 mode.

**A song cut as its tune's init leaves it: The Last Ninja's song 5
fits.** Cutting a song of a big tune keeps the memory the song uses, but
some tunes keep all their songs in one place and have init copy the
chosen one where the player reads it, so the cut had to keep the
source too: The Last Ninja's song 5 came to 4,387 bytes, over SlopLoad
64's 4,096. Now a cut over 4,096 bytes is made again from memory as
init left it, with a short init of its own (the zero page init wrote,
its SID writes, CIA 1's timer) placed just after the last byte kept,
and the pages packed round their longest run. It must play exactly as
the whole tune does. Song 5 comes to 3,808 bytes, and 10 of the 11
songs fit (song 4 is 7 bytes over). `sidstrip.py -cut` on the PC and
SID-SLM on the C64 both do it, with the same bytes; on the C64 it takes
as long again (`OVER 4096: AGAIN, AS INIT LEAVES IT`). Song 5 still
can't play beside the loader as cut over five minutes: its restart at 4
minutes 36 seconds takes one play call of 12,334 cycles; on the PC,
`-cut -frames 13800` stops short of it. SID-SLM grew to 75 blocks (the disk has
221 free), and keeps about 7 KB of a big file in memory (was 9).

**PETSCII screens in a font of your own.** PETSCII-Load showed the
C64's own character sets only, and refused a Petmate screen drawn in an
imported font. Now such a `.petmate` file brings its font with it, and
`-font myfont.64c` gives one to a `.pet` or `.c` screen (`slopload.py`
and `tools/petscii.py`). On the C64, PETSCII-LM has a seventh line, the
font: a `.64c` file, read as Petmate reads one, shown with the screen
(`-` at its name goes back to the C64's own). The module keeps only the
characters it shows, numbered again from 0, so a font costs 8 bytes a
character shown: 128 or fewer go just under the screen at $B800, more
at $B000, and a program reaching there loads that part after the
screen goes. PETSCII-LM writes the PC tool's file byte for byte. The
module has two more settings (the codes of the space and the digit 0),
so modules made before still work as they are. Tested in VICE: the
loads with a font at $B800 and at $B000 (the second under a 63 KB
program), PETSCII-LM on a C64 and a C128, and SlopLoad 64 writing
tapes with both.

**SlopLoad 64 says an REU's size up to 16 MB.** It measured an REU only
up to 1 MB (more than a tape needs), so an Ultimate's 16 MB REU showed
as `1024 KB REU`. It now measures up to 16 MB and says sizes from 1 MB
on in MB (`16 MB REU`).

## 0.8.0 (2026-11-02)

SID-SLM cuts tunes bigger than its memory, such as The Last Ninja
(35 KB), and says when a .slm is cut down; SlopLoad 64 and the TAP
writer write cassettes with any KERNAL, JiffyDOS active included;
PETSCII-LM has a menu; and a PETSCII screen's scrolling message can
have colours of its own, on the C64 and the PC. Passes the test suites
in VICE (73 PC cases, 49 SlopLoad 64 cases), with both programs'
cassette writing also run under JiffyDOS and stand-in KERNALs, and
PETSCII-LM's menu, on PAL, NTSC and a C128 in C64 mode.

**SID-SLM cuts tunes bigger than its memory.** A .sid file over about
17 KB was refused (`TOO BIG FOR A TUNE`), so a big multi-song tune such
as The Last Ninja (35 KB, 11 songs) couldn't be cut on the C64 at all.
SID-SLM now reads the whole file, keeps what fits (about 9 KB from its
start, and its last page), and when the cut's song first uses a page it
lacks, reads the file again from the disk up to that page, with up to
15 pages after it, into the memory of pages the song hasn't used. The
cut comes out byte for byte as the PC's (`tests/cuttest.py`, now also
with only a few pages in memory: `--paged`, in the suite as
`sid-cut-c64-paged`). The Last Ninja's song 11 cuts to 3,491 bytes; its
other songs stay over 4,096, as on the PC. A file that can't be read
again as it was is refused (`CAN'T READ THE FILE AGAIN`). SID-SLM is 67
blocks (5 more); the disk has 241 free.

**SID-SLM says when a .slm is cut down.** After writing a cut tune:
`NOTE: CUT DOWN, SONG 11 ONLY (3491 OF THE TUNE'S 35491 BYTES: WHAT ITS
FIRST 5 MINUTES OF PLAY USE)`, so it isn't taken for the whole tune.

**Cassettes written with any KERNAL, JiffyDOS too.** SlopLoad 64 and the
TAP writer always wrote the pulses themselves, never through the
KERNAL's tape routines, but they still leaned on a stock KERNAL in one
place: its interrupt routine's motor code, which starts the motor
whenever PLAY is down unless a program sets the interlock byte at $C0.
JiffyDOS skips that code (its IRQ never touches the motor), and another
KERNAL that reuses the tape code's space could do anything there, or
use $C0 for something else. Both programs now run their own interrupt
routine (the KERNAL's clock, STOP key and keyboard, through its jump
table, and nothing else), never write $C0, set the cassette port's write
and motor lines as outputs themselves, and stop the motor when they
start. The TAP writer used to leave a motor that a stock KERNAL had
started at READY running until it wrote; it now starts the motor itself
a frame before the first pulse. A C128's 2 MHz border interrupt passes
on to the interrupt routine that was there before it, not to the
KERNAL's. So a C64 with JiffyDOS active writes the same cassette as a
stock one; loading the tape still needs a KERNAL with tape routines
(switch JiffyDOS off for that). Tested in VICE with JiffyDOS, and with
stock KERNALs changed to lack the tape code, or to run the motor
whenever PLAY is down whatever $C0 says, with the write line left an
input; on PAL, NTSC and a C128 in C64 mode. `tests/c64tool.py` and
`tests/tapwrite.py` take `--kernal FILE` and `--ntsc`, and now check that
the motor stays off while PLAY is down and nothing is being written.

**PETSCII-LM has a menu.** Its questions came in a fixed order, and the
only way back was `M` at the row question, so a slip at the counter
meant starting the screen again. It now shows a menu, as SlopLoad 64
does: the screen, the message, its row, its speed, its colours and the
counter, each on a line of its own, changed by its number at any time
and in any order. `S` shows the screen as the module will show it;
RETURN writes the module, and the menu comes back with everything
kept, so another screen or another message is one change away. The
rows next to the message are cleared only in the module written (said
when the row is chosen, and again when written), so choosing another
row brings them back.

**A scrolling message's colours of its own.** The message scrolls
through its row's colour memory, which stays put. It had the colours
the screen had on that row, and Petmate doesn't show the colours of a
row of spaces. PETSCII-LM's line 5 keeps the screen's colours or edits
them in an editor of their own: the row with the message's start in
it, a bar of every column's colour, the C64's colour keys to colour a
column and move on, `F` to give every column one colour, `P` for the
screen's colours again. The edited colours go with the message's row.
On a PC, `tools/petscii.py` and `tools/slopload.py` take
`-scrollcolours HEX`: a hex digit a column from column 1, repeated if
shorter (`7`: all yellow). PETSCII-LM and `petscii.py` write the same
file for the same colours (`tests/petsciilm.py`), and
`tests/petsciicheck.py --scrollcolours` checks at every tick of a load
that the module shows them, in place, while the message scrolls.
PETSCII-LM is 9,900 bytes (39 blocks, 9 more); the disk has 233 blocks
free.

## 0.7.0 (2026-11-01)

SID-SLM cuts one song of a big multi-song tune down on the C64 itself,
as `sidstrip.py -cut` does on a PC, and tries tunes that write a lot of
memory; the TAP writer shows the disk; and a long directory keeps its
colour after "more". Passes the test suites in VICE (72 PC cases, 49
SlopLoad 64 cases), with SID-SLM's cut also run on NTSC and a C128 and
the TAP writer's directory on a C128.

**SID-SLM cuts one song of a big tune down, on the C64.** A tune over
4,096 bytes no longer just gets `REFUSED: OVER 4096 BYTES`: SID-SLM asks
whether to cut its song down, and with Y does what `sidstrip.py -cut`
does on a PC: the same cut, byte for byte, on every tune tested. It plays the song for
five minutes in its emulated 6502, following every address the song
uses back to where it came from, keeps the pages it uses, packs them
together and moves the addresses in them, then tries the cut tune over
the same five minutes: the same SID writes as the whole tune, or it's
refused. Song 1 of Mono (8,318 bytes) comes to 1,647 in 27 minutes on a
stock C64 or a C128; less with an Ultimate's turbo or a SuperCPU.
RUN/STOP stops it, and any trial. `tests/cuttest.py` checks the C64's
cut against the PC's step by step (in the suite as `sid-cut-c64`).

**SID-SLM tries tunes that write a lot of memory.** Its trial had 21
pages for what a tune writes outside itself, and refused more as `TOO
BIG TO TRY`; it now has 116 (the RAM under the I/O and the KERNAL, and
the file's area once the tune is in place). SID-SLM is 62 blocks (21
more), so the disk has 246 free.

**The TAP writer shows the disk.** At the file name, `$` lists the
drive's directory (`$:SL*` the names starting SL) and `@` gives its
status and takes commands, as in SID-SLM and SlopLoad 64.

**The directory's colour after "more".** "More: a key" left the text
white, so in SID-SLM (whose text is green) the rest of a long directory,
and everything after it, came out white. The text now keeps its own
colour; "more: a key" is still light grey.

## 0.6.0 (2026-10-31)

One song of a big multi-song tune cut down for SlopLoad 64
(`sidstrip.py -cut`), a message editor in PETSCII-LM with any row for
the message, and the disk's directory and commands in SID-SLM. Passes
the test suites in VICE (71 PC cases, 49 SlopLoad 64 cases), with
PETSCII-LM also on a C128 and the scroller beside cleared rows on PAL
and NTSC.

**PETSCII-LM: a message editor, and any row for the message.**
The scrolling message is typed in a field of its own (five lines, in the
screen's case): the cursor keys move through it, typing goes in at the
cursor, DEL, INST, HOME and CLR work as on the C64's screen, and the next
screen starts with the same message. Any row can take it now: the rows
above and below it are cleared if anything is on them, and it says so
(before, such a row was refused and the message thrown away, to be typed
again). The rows that need nothing cleared are listed, and `M` at the
row goes back to the message. The PC tool (`-scrollrow`) clears them the
same way and lists the rows too; the module files are the same.

**One song of a big tune for SlopLoad 64: `sidstrip.py -cut`.** A tune
with many songs is one player and the data of all of them, so it can be
far over SlopLoad 64's 4 KB though each song uses much less.
`tools/sidstrip.py big.sid song.slm -song 3 -cut` keeps the pages that
song uses in five minutes of play (and those of the code its branches could
reach), packs them together, moves every address in them with its page,
and plays the cut tune beside the whole one: the same SID writes, frame
by frame, or it is refused. Song 3 of Golden Axe: 14,070 bytes to 4,577;
song 1 of Mono, 8,318 to 1,647. In a trial of 48 big HVSC tunes (songs
1-3, a minute each), 103 of 144 songs cut and passed every check, 55 of
them to 4 KB or less; one was refused by the cut itself (it reads its
own code as a table), the others for what the whole tune breaks too. The
report says when a tune is over 4 KB, and that `-cut` can help.

**Tunes that copy themselves page by page can move.** A tune whose init
copies its pages in a loop up to a compare with the page past its end
(`cmp #$7E`) ran past it once moved, so it played only where it was.
`tools/sidreloc.py` (and with it the PC tool's and `sidstrip.py`'s
moves) now moves such a compare with the pages. Of song 1 of 48 HVSC
tunes, three more now move (Parsec, Dan Cooper, On Field Football) and
none moves less.

**Tests:** `tests/sidcut.py` (in the PC suite: 71 cases) cuts songs of
five HVSC tunes and checks each against the whole tune, then masters one
beside Crossy-Load and loads it; SlopLoad 64's suite has a case with a
cut song beside Crossy-Load (49).

**SID-SLM shows the disk.** At the file name, `$` lists the drive's
directory (`$:EN*` the names starting EN; 20 lines a page) and `@` is the
disk as in SlopLoad 64's menu: the drive's status, then its commands,
until RETURN alone. The code is shared with SlopLoad 64 (`c64/disk.asm`).
SlopLoad 64's `@` help no longer suggests `$:*.sid`: on a 1541 a `*` ends
the pattern, so that lists every file.

## 0.5.1 (2026-10-31)

The issues 0.5.0 left known, fixed, and the PC tool refuses options a run
would ignore. Passes the test suites in VICE (70 PC cases, 48 SlopLoad 64
cases), with the changed modules and PETSCII-LM also checked on NTSC and
a C128.

**SlopLoad 64 reads a program from VICE's host-folder drive.** A program
on a drive that is a host folder in VICE stopped with THE FILE ENDED
EARLY: after opening the program again the tool asked the drive to talk
while it was talking already, and VICE's host-folder drive drops a byte
then (a 1541 doesn't). The drive's turn is now ended first. Tested with
the program and the `.tap` both on the host folder, and both on a 1541
image in drive 9.

**A second tape in one session places a moved tune as the first did.**
A `.slm` moved out of a module's way stayed where it was moved, so the
next tape in the same session could put it somewhere other than the PC
tool's model does (the tape was still valid). It now goes back to its
own address before each tape is planned.

**The block counter.** OZ GOLD's and PETSCII-Load's counter counted down
from the program's whole size but only counted the part that loads
while the module shows, so with part of a program loading into the
module's memory afterwards (25 blocks of a 250-block program beside OZ
GOLD) it reached 000 early. Header byte 26 is now the blocks that load
while the module runs, in the PC tool, its model and SlopLoad 64, and is
the number the PC tool reports ("226 blocks load while the module
runs"). With `-autorun` (or `-nomotor` when part of the program loads
after the module) the counter was cut off at 001 or 002; the module's
stop now shows a whole frame of 000 first.

**PETSCII-LM:** DEL after a typed quote mark moves back, as it does
without one (it printed a reversed character).

**The TAP writer in VICE:** the README now says to put the .tap on a
disk image. VICE's host-folder drive recognises a tape inside a .tap
and hands over the tape's first file instead (a VICE feature, not a
fault in the writer; a real drive or an SD2IEC gives the file as it is).

**The PC tool refuses options it would ignore:** `-picture` without
`-show picture` or `picmusic`; `-module`, `-scroll`, `-counter` or
`-screen` with another show; `-scrollrow` or `-scrollspeed` without
`-scroll`; `-screen 1` with a `.pet` (it has one screen); `-module`,
`-autorun` and the rest on a tape side; `-tape`, `-side`, `-margin` and
`-random` without `-tapeside`; `-rate`, `-bitrate` and `-invert` with a
`.tap`, and `-bitrate` with a `.wav`; `-out` outside `-analyse`, and
`-jitter` outside `-analyse` and `-calibrate`. `-music` with a `.lm`
says a `.lm` brings no songs (`-module flappy` does); the README says
so too.

**Tests:** `tests/c64tool.py --then MODULE` (a second tape in the same
session) and `--prgdrive 9`, and three SlopLoad 64 cases for them (48);
`--autorun` for `ozgoldcheck.py` and `petsciicheck.py`; `petsciilm.py`
types a quote and then DEL; `tests/options.py` checks the refusals.

## 0.5.0 (2026-10-31)

Modules, not loader games: `-module`, `.lm` files and PETSCII-LM; a demo
Koala picture on the disks; SlopLoad 64 about 14% quicker to the
cassette; and the fixes from a review of the whole system before the
release:
SlopLoad 64 and its tools no longer hang on a drive that isn't there or
master a program short after a read error, the PC tool finishes a
program that lies wholly in the show's memory and refuses bad input
with a message, Flappy-Load no longer shows a frame without its sky on
NTSC, PETSCII-Load's scroller no longer moves the border, Crossy-Load's
music keeps time, and a picture or music no longer makes the grey dot.
Passes the test suites in VICE (70 PC cases, 45 SlopLoad 64 cases) on
PAL, NTSC and a C128.

**Modules, not loader games.** What runs while a program loads is a
module: a game to play is one kind, a loading screen (PETSCII-Load, OZ
GOLD) another, pictures and music a third. The names follow: the PC
tool's `-game` is now `-module` (and `-show game` is `-show module`; the
old spellings are gone), the sources are in `modules/`, the built ones
in `build/modules/`, the guide is `MODULES.md`, the kit is
`src/modkit.asm` and `src/modhead.asm`, and SlopLoad 64's item 4 is
MODULE. A module's file is a `.lm` (loader module) instead of a `.lg`:
the same inside, so an old one only needs renaming (the PC tool says
so when given a `.lg`), and PETSCII-LG, which makes them on the C64, is
PETSCII-LM. PETSCII-Load's demo screen and message say `-MODULE
SCREEN.PET` (they still said `-GAME`).

**SlopLoad 64's show question lists its choices one a line:** 0
nothing, 1 loader module, 2 picture, 3 picture and music, 4 music.

**A demo picture:** `pictures/slopload.koa`, SLOPLOAD in slanted
rainbow letters with a reflection, to try `-show picture` with, and
`SLOPLOAD.KOA` on SlopLoad 64's disks. `pictures/mkslopload.py` draws it
(no fonts needed).

**OZGOLD.SID on SlopLoad 64's disks,** beside `OZGOLD.SLM`, for SID-SLM
to try as it does the other demo tunes.

**PETSCII-Load's and OZ GOLD's fade is a little slower:** the music
fades out over about 2.6 seconds once the program is in (1.9 in 0.4.0),
and with no music 000 stays up for 1.3 seconds. Each loading screen sets
its own fade (`fstep` in its source).

**A program wholly in the show's memory loads.** With nothing of the
program to load while the module or show runs (all of it falling in its
memory, as a program at $C000 does beside the built-in music), the PC
tool's tape never stopped for the module and never finished; SlopLoad 64
already made it right, and the PC tool now makes the same tape.

**Flappy-Load on NTSC:** when the music ran on past the frame's last line
(a few times in a thousand frames, more with a long SID tune) the next
frame showed with a black sky. It now does that frame's vertical blank
work at once, as the module standard says.

**No grey dot with a picture or music:** the show module wrote the
border colour every frame, which a C64C's VIC (8565) shows as a grey dot
on the border; it writes it only when it changes.

**PETSCII-Load's scroller keeps 40 columns:** with 38, the side borders
moved in on whichever line the split's write landed, so a few pixels of
border flickered beside the row above the scroller (with a border unlike
the background). The row's column 0 now has the background's colour: the
message comes in smoothly under the right border and leaves at the left
a character at a time.

**Crossy-Load's music keeps time:** it played only in frames whose game
tick ran, so the tune faltered whenever the screen scrolled a row (and
more on NTSC); it now plays every frame (NTSC 5 in 6). The hop's chirp
read the SID's frequency back, which can't be read: it keeps its own.

**The PC tool refuses what it can't do, and says so:** a bad number
(`-speed abc`) or one out of range (`-start`, `-status`, `-leader`,
`-blocksize`, which hung at 0), a tape over 256 blocks, an output that
isn't `.tap`, `.wav` or `.mp3`, a module whose header is short or whose
`.lm` parts overlap, a module's own music over the module, a `.sid` or
`.slm` cut short, a tune playing fewer than 16 times a second, `-song`
with a `.slm`, and a damaged `.petmate`, each with a message, not a
Python traceback. Names with letters such as ß, or braces in a file's
name, no longer stop it; the report shows a name's control codes and
says when a name is cut to 16. The loader's share of the CPU beside a
show's music is worked out in whole numbers, as SlopLoad 64 does (they
could differ by 1%).

**SlopLoad 64 is quicker:** choosing each block's coding takes about a
third less time (its prefix code worked a symbol at a time in place, and
the code a block was chosen with kept for laying it out, not made
again), so a 63 KB program with a picture and music goes to the
cassette in 13 minutes, not 15, and a 6 KB one with Crossy-Load in 1:56,
not 2:13. The rest is the disk (read the KERNAL's way, which works with
every drive) and the cassette itself.

**SlopLoad 64, PETSCII-LM, SID-SLM and the TAP writer:**
- a drive number with no drive on it hung the C64 (waiting for ever for
  a drive to talk): they now say NO DRIVE THERE;
- a read error part way through the program was taken as its end, and
  the tape mastered short without a word: now READ ERROR (the TAP writer
  too);
- after the program's drive changed, the drive status came from the one
  before, so a `.tap` that couldn't be written (63, FILE EXISTS; a full
  or protected disk) said DONE: each drive's status is its own now, and
  an error as the `.tap` closes counts as one;
- a program ending at $FFFA-$FFFE was taken (and its tape never
  started it): $FFF9 is the end, as on the PC;
- a number over 255 (speed 264) wrapped round to another (9); a SYS
  address of 0 (which meant RUN) or of five digits is asked again;
- an REU or SuperRAM writes the tape in one go from the start, as the
  README says, not only once 9 had been answered;
- SID-SLM wrote a `.slm` for a tune it had just refused for its rate,
  RESTORE no longer crashes it during the trial, and a tune's name shows
  in capitals (its capitals were graphics); PETSCII-LM, SID-SLM and the
  TAP writer leave the KERNAL's vectors as they found them when they
  quit to BASIC.

**A `.sid` is checked once:** the 20 seconds of simulating it are kept
in `~/.cache/slopload`, so mastering with the same tune again takes a
second.

**`tools/speedtest.py`** takes `-module`, and its picture tapes use
`pictures/slopload.koa` (it pointed at a file of the author's).

## 0.4.0 (2026-10-30)

SID-SLM, a tool of its own for trying a `.sid` on the C64; borders
without stripes in SlopLoad 64; PETSCII-Load and OZ GOLD show 000 and
fade their music; Crossy-Load scrolls more smoothly and no longer tears
its trains; and speeds below 0 for decks that need more margin.
OZ GOLD's medley is on SlopLoad 64's disks as `OZGOLD.SLM`, for any
show. Passes the test suites in VICE (70 PC cases, 42 SlopLoad 64
cases) on PAL, NTSC and a C128.

**SID-SLM: the `.sid` trial moved out of SlopLoad 64.** A new program on
SlopLoad 64's disk tries a `.sid` out on the C64 (the same trial, the
same refusals) and writes the `.slm` file SlopLoad 64 now reads for its
music. SlopLoad 64 is 5.4 KB smaller (22,905 bytes), room for features
it had none for. The disk's demo tunes come as `.slm` files made on the
PC (they can move) and as `.sid` files for SID-SLM. A `.sid` given to
SlopLoad 64 is refused with a pointer to SID-SLM.

**Speeds below 0.** `-speed` (and SlopLoad 64's item 7) now go down to
-12, for a deck that speed 0 is too tight for: 4 cycles more margin a
step, to ±124. Speeds 0 to 13 are as they were. The pulses are longer,
which is what a badly aligned head (one losing the highs) needs: through
a modelled dull head, -12 loads a tape that speed 0 can't. Only the
parts loaded with the screen off get slower (a 63 KB program alone, 95 s
at 0, 140 s at -12): with a game or a picture showing, speed 0 has the
most margin the loader takes already. `-calibrate` recommends below 0
when even 0 leaves too little.

**Crossy-Load: a smoother scroll, no torn trains.** With the hen hopping
fast (and steering), the scroll stopped for 2-4 frames at every row
while the game redrew its hidden screen; it now copies that screen from
the one on show, two rows at a time, and the camera asks for the next
row as soon as it gets there. On PAL the field stands still in 3% of the
frames the camera is chasing her, from 27%. The screen's own slow creep
is as it was. A train drawn when the frame was short of time could be
caught by the beam: its top and bottom halves a cell apart, or a piece
of it half drawn, for a frame. It now waits for the beam to pass. The
cars and logs keep up better too (on PAL, at most 4 pixels behind
hopping nonstop, from 10). Setting up moved into a screen the game
hasn't used yet, for the room.

**SlopLoad 64: borders without stripes.** Item 0 (colours) now has the
PC tool's block (the border a colour a block) and one colour (it asks
which, 0-15) after the styles, and black is made as the PC tool makes
it (before, a style of one colour, with the lookup's cost). The three
use `core_flat`, made from the core on the C64 in place, and cost
nothing in speed. The tapes
match `tools/c64model.py`'s byte for byte, and the core and stage 1
match the PC tool's for the same mode. Stage 1 is held at the mode's
colour for the styles too now, as the PC tool has it since 0.3.0.
The three take 317 bytes of the room SID-SLM made (SlopLoad 64: 23,222
bytes).

**PETSCII-Load and OZ GOLD: 000, then the music fades.** Once the
program is in, the counter stays at 000 and the music fades out over
about 2 seconds before the program starts (no music: 000 for a second),
as U.S. Gold's Novaload did. Before, the loader stopped in the frame
the counter reached 000, so it never showed, and the music cut off. A SID tune is faded with its own filter
settings: its play routine runs with the I/O banked out during the fade
and its writes are passed on with the volume scaled (GAMES.md). The
PC tool, `tools/petscii.py` and PETSCII-LG all make the new module,
and SlopLoad 64's disk has both; `-autorun` still starts the program at
once. The fade is in the kit (`src/fadekit.asm`) for any loading screen
to use.

## 0.3.0 (2026-10-26)

New loading borders for the PC tool: one flat colour (a black screen
until the loading screen comes up), or a colour a block; and no more
grey dots on a C64C. Passes the test suites in VICE (68 PC cases, 35
SlopLoad 64 cases) on PAL, NTSC and a C128.

**No stripes: a flat border, or a colour a block.** `-stripes black`
(or any one colour: `-stripes 6`) keeps the border one colour while the
screen is off, from the moment the C64's own loader hands over; `-stripes
block` steps the border's colour once a block. Neither slows the loader
(its own core, `core_flat`); a tape error still turns the border red
until it recovers. Every style but rainbow now also holds the first few
seconds (stage 1) at one colour. The PC tool only: SlopLoad 64 keeps its
styles as they are.

**Fixed: grey dots.** On a newer VIC-II (the 8565 in the C64C) every
write to a colour register leaves a grey dot. A flat border, and
PETSCII-Load's border, are now written only when their colour changes.

## 0.2.0 (2026-10-26)

Loading screens that aren't games: OZ GOLD, and PETSCII screens of your
own with a scrolling message and a block counter, on the PC and on a
C64. Two fixes to the loader's timing for every game. All of it passes
the test suites in VICE (65 PC cases, 35 SlopLoad 64 cases) on PAL,
NTSC and a C128.

**OZ GOLD** (`-game ozgold`, `ozgold.lg` on SlopLoad 64's disks): a
loading screen in the style of U.S. Gold's Novaload one. The Australian
flag in PETSCII, OZ GOLD in U.S. Gold's own letters, ALL AUSTRALIAN
SOFTWARE, BLOCKS TO LOAD counting down, and a medley of Advance
Australia Fair, Waltzing Matilda and Bound for Botany Bay, one part of
each, in the spirit of U.S. Gold's own. A module that isn't a game, on
the same standard (GAMES.md).

**PETSCII screens while loading**: `-game myscreen.petmate` (or a
`.pet`, or Marq's PETSCII editor's `.c`) shows your PETSCII screen while
the program loads, through the game mode (PETSCII-Load). For SlopLoad
64, `tools/petscii.py` or **PETSCII-LG**, a new program on its disk,
makes the screen into a `.lg` module. The PC tool also takes any `.lg`
as `-game`. A PETSCII screen can have a smooth scrolling message
(`-scroll`) and a block counter counting down as it loads (`-counter`),
as U.S. Gold's Novaload screens had; PETSCII-LG asks for them.

**Header byte 26**: both tools now tell a game the program's size in
disk blocks.

**Fixed: the progress jumped as a game started.** The loader counted the
pages of the game's own last block as program loaded, so a game's bar
(and OZ GOLD's counter) jumped on a little, then back when the program's
first block came.

**Fixed: Template-Load ran too fast.** Its frame waited for line 251 but
not for the vertical blank to end, so it ticked three times a frame on
PAL (its music at triple speed) and every frame on NTSC instead of five
in six. GAMES.md now shows the wait a frame needs.

## 0.1.0 (2026-10-26)

The first release: the PC tool, SlopLoad 64 and the TAP writer, with
two loader games and the standard for making more. Everything here
passes its tests in VICE (PAL, NTSC, a C128, a SuperCPU, REU and
SuperRAM); the tests on real cassettes and machines in REALTEST.md are
still to be done.

**The PC tool** (`tools/slopload.py`): a program (`.prg`) in, an
autobooting tape out, as a `.tap`, a `.wav` or an `.mp3`. Speeds 0
(safest) to 13. While it loads: a loader game (Flappy-Load,
Crossy-Load, or your own), a Koala picture, music (two built-in songs,
or a `.sid` of your own, moved where it fits), or nothing. Loading lines
in a style (`-stripes`), control codes in the tape's name (`-filename
"{clr}{white}MY GAME"`), whole tape sides of programs (`-tapeside`), a
deck's limits measured (`-calibrate`, `-analyse`), any tape decoded and
listed (`-info`).

**SlopLoad 64** (on `slopload64.d64` / `.d81`): the same tapes made on
a C64, a C128 or an Ultimate, to a cassette or a `.tap` file. Its menu
reads the program, the game, a tune and a picture from disk by name; a
`.sid` is tried out on the C64 first (4 KB at most); a block at a time
to the cassette, or in one go with an REU or SuperRAM; loading lines in
a style; the drive's directory and commands (@).

**The TAP writer** (on the same disks): any `.tap` file to a cassette,
with an REU of 512 KB or more.

**Loader games**: Flappy-Load and Crossy-Load (hop the hen up the lanes;
walk her with left and right), and Template-Load to start your own.
GAMES.md is the standard a game keeps to, with the shared kit in `src/`.
