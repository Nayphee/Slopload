# SlopLoad releases

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
