# SlopLoad releases

## 0.17.0 (2026-11-16)

A PETSCII screen editor joins the C64 tools: PETSCII-ED, on both disks.
SlopLoad 64's effect list shows the colours each effect would draw with
line 7's, its line 1 lists the drive's files with `$`, and a tape error
in the loader's first second shows pink on a red border too. Both
suites pass in VICE on the changed build (284 PC cases, 117 SlopLoad 64
cases); PETSCII-ED's test passes on PAL, NTSC and a C128. Not played on
a real C64.

**PETSCII-ED, a PETSCII screen editor, on the disks.** It reads and
writes `.pet` files (the screens PETSCII-LM makes into modules, as
Petmate exports them) and shows a screen in a font of your own, to try
one first. A menu in the other tools' style: the screen (a file, or a
new blank one), its border and background, the pen (the colour typed
in), the case, a font (a `.64c`). RETURN edits the screen, the whole
C64 screen as it will show: the keys type as on the C64 (SHIFT and C=
for the graphics, CTRL 9 and 0 for reverse, CTRL or C= with 1-8 for the
pen's colour), F1 shows all 256 characters to choose one from (in the
font: the way to find a new font's characters), F3 colours the one
under the cursor, F5 takes its colour for the pen, F2, F4 and F6 step
the border, the background and the case on. W writes it (the drive and
the name asked), Q quits, asked first if the screen isn't written. 6,159
bytes (25 blocks; the d64 has 35 free). `tests/petsciied.py` works it
through the keyboard in VICE, every step's screen against a model of
the editor, and reads the file it writes back: three new cases in the
PC suite (284), PAL, NTSC and a C128.

**SlopLoad 64: each effect's colours, and the directory at line 1.**
Line 8's list keeps its few words on each effect and shows, on the row
under them, the colours it would draw with line 7's as they are: no
effect the first; classic and mixed every colour from it; sloppy line
7's by the pulse's length; thin it and the next; and and ora the
colours the value lets through; eor it and it eor the value; line the
border and the line's colour; block all sixteen (and, ora, eor and
line say the value: `VALUE 5`). Black, which wouldn't show on the
black screen, is a dark grey check, on line 7's colours too. At line
1's file name, `$` lists the drive's files and asks again (`@` alone:
its status and commands), as the other tools' file questions do; and
a new drive with RETURN alone at the name no longer moves the program
there is to that drive (it was read from the old one, and mastering
would have looked on the new). The room for it: the machine's
detection, run once at the start, moved where the buffers go
(`machdet.asm`), about 440 bytes; SlopLoad 64 has 274 to spare.
`tests/c64tool.py` checks the list's words and colours each time it
opens line 8 (in every case of SlopLoad 64's suite that sets an
effect), and `--dirfirst` types `$` at line 1 first: a new case (117).

**A tape error in the first second, on red.** In a tape's first
seconds stage 1 loads the loader, the border one colour in every
style but rainbow (the style's first). Its tape error was red, so
where that colour is red (`-stripes 2`, `red`, `fire`, an effect from
red) an error there showed nothing. It is pink there now, as the
loader's own is on a solid red border. `slopload.py`, the model and
SlopLoad 64 change the same byte in the KERNAL header (SlopLoad 64 9
bytes longer: 94 to spare); every other tape is as it was.
`tests/retrytest.py --stage1` damages the loader's own block and wants
stage 1's error in the colour given and a full load after: four new
PC cases (281), red, fire, blue and rainbow, and one in SlopLoad 64's
suite (116), thin from red, its tape the model's.

## 0.16.0 (2026-11-16)

SlopLoad 64's menu comes back whole after a tape, which it has not
since 0.14.0; its effect line starts at 0 NO EFFECT, with CLASSIC 1
and SLOPPY 2; a tape error shows pink where the border is solid red;
and the disks have a mock of Novaload's boot screen, `SERIAL.PET`.
The README was checked against the code, section by section, and
about sixty statements put right (what `-wait` and `-waitgame` do,
when the tune starts, what is on the disks, the messages, the
tests' options). Both suites pass in VICE on the changed build (277
PC cases, 115 SlopLoad 64 cases, each of those now checking the menu
after its tape). The menu's damage was seen on an Ultimate 64
before the fix; nothing else was played on a real C64.

**SlopLoad 64's menu after a tape.** Since 0.14.0 the menu came back
damaged once a tape had been made, any tape: reversed letters where
its title was and across the screen, lines 1 and 2 in reverse, the
machine's line at the bottom. The tape itself was right, and so were
the settings; only the screen was wrong. The title's text (it has the
release's number, so the build has made it since 0.14.0) had been put
last in the program, after the loader's core, where the tool's
buffers go once it has started: every tape fills them with the
KERNAL header's pulses, and the menu printed those for a title,
control codes and all. Seen on an Ultimate 64 after a 51 KB
program's tape, and then in VICE after any. The title is before the
core now, and the build stops if anything but the start's own code
and data is where the buffers go. `tests/c64tool.py` presses a key
after every tape and wants the menu back as it was before it, so
every case of SlopLoad 64's suite checks it. (The buffers start 31
bytes later for it: 103 bytes to spare.)

**SlopLoad 64's effect line: 0 NO EFFECT, 1 CLASSIC, 2 SLOPPY.** Line
8 chooses by the number shown, from 0. 0, no effect, is a plain border
in line 7's first colour (a palette's, your own's, rainbow's black),
with no lines: until now that took a list of one colour on line 7.
Classic is 1, and SlopLoad's own stripes, which were 1 standard, are 2
sloppy: still what it starts with, and the same tapes. Thin to line
are 3-8, block 9. Three new cases in SlopLoad 64's suite (115), its
tapes the model's, one loaded.

With that, two things on lines 7 and 8 said nothing new, and are gone.
The **BLACK palette** (line 7): with sloppy it was rainbow with no
effect, a plain black border, and under any effect it was rainbow
under that effect, both starting from black. (The PC tool keeps
`-stripes black`.) And the question **a colour on each page loaded?**
is asked only where the step shows: a plain border (no effect, or one
colour), thin, eor, and line's own (a colour on each block). Classic,
mixed, and and ora change the border with every pulse, so there it
only made the shortest pulses longer.

**A tape error on a red border is pink.** A tape error turns the
border red until the loader recovers, which said nothing where the
border was red already. Two places can be: a border of one colour
(`-stripes 2`; SlopLoad 64's one colour) and a PETSCII screen with a
red border. Both show pink (light red, 10) there now, and red as
before on any other colour; with `-stripes block`, a red block's own
turn shows pink too. The loader's part fits in the bytes it had (the
flat core's `errshow`, 19 bytes, its padding used: the core is no
longer), so SlopLoad 64 is the same size; PETSCII-Load showed white
on a red border before, and is 4 bytes shorter. The effects (`thin,2`
and the like) are as they were: their lines stop and the border is
red, on a border that was red with lines. So is the first second of a
tape, while the loader itself loads (stage 1): an error there on a
solid red border still shows red, which is no sign.

`tests/retrytest.py` reads the border as the error is flagged, while
it is, and a block after it cleared (`--stripes`, `--border`,
`--expect`), and runs the flat core's `errshow` in the simulator for
every block number: five new cases in the PC suite (277).

**A Novaload-style boot screen to try: `SERIAL.PET`.** A mock of the
screen a Novaload tape shows once its first program is RUN and the
screech begins, taken from Spy Hunter's (Kixx) in VICE at the screech's
first byte: a black border, a dark grey screen, the tape's name in
white on row 8, `NOVALOAD A100222` in light grey on row 23 (columns
12-27), and nothing else. Ours says `SLOPLOAD A000000` (a serial
number of zeros in Novaload's form, a letter and six digits), and
`1234567890123456` stands where the name goes: its 16 characters,
centred, over the bottom line's 16. `modules/petscii/serial.pet`
(written by `mkserial.py` beside it) for the PC tool, and `SERIAL.PET`
on both disks for PETSCII-LM: with the screech (`-screech`,
PETSCII-LM's line 9) it is Novaload's start, sound and all. The d64
has 60 blocks free with it.

PETSCII-Load shows it as the file has it on PAL, NTSC and a C128, and
with the screech; PETSCII-LM reads it from the d64 and the d81, and
the `SERIAL.LM` it writes is the PC tool's, byte for byte.

## 0.15.2 (2026-11-14)

One fix: the loading sprites under a program that loads over their
pointers. Both suites pass in VICE on the changed build (272 PC cases,
112 SlopLoad 64 cases), and a tape without sprites is byte for byte
what 0.15.1 made. Not played on a real C64.

**A loading sprite's pointers.** The VIC reads a sprite's pointer from
the last bytes of the screen's page ($CFF8 and $CFF9 with the picture
in the top bank), and nothing kept those from the program: one that
loads over them turned the sprites to garbage until the picture ended
(in VICE, with a program to $FFEF: 27 3C there at the show's end, not
FD FE). With sprites the picture's screen part is 1,024 bytes now, the
pointers in it, so the program's bytes there load after the show, as
the rest under the picture does. `slopload.py -sprite`,
`tools/picturelm.py` and PICTURE-LM (the same file, byte for byte; 51
bytes longer for it) make it so, and SlopLoad 64 takes such a module as
it is: its own code is unchanged. A picture module with sprites made
before this is as it was: make it again.

`tests/spritecheck.py` reads the pointers again at the show's end, and
the program's own bytes there once it is in, with a program that
covers them (`--prg`), drawn in too (`--drawin`), and on a tape
SlopLoad 64 wrote (`--tap`): four new cases in the PC suite (272), two
in SlopLoad 64's (112), each of those two followed by that check of its
tape.

## 0.15.1 (2026-11-14)

A pass over the whole project: six code reviews, a battery of the tests
neither suite ran, and what they found put right. The tools' own tests
pass on the changed build (SID-SLM, PICTURE-LM, PETSCII-LM, the TAP
writer, the trial and the cut against the PC's), and so do both suites
in VICE: 268 PC cases (25 of them new) and 110 SlopLoad 64 cases (2
new). Not played on a real C64.

**Flappy-Load's texts, and a load that never finished.** Since 0.10.0
the module had grown past $F400, where its own screen begins, and its
texts sat there: drawn over at the first frame. `GET READ` for GET
READY!, no PRESS FIRE, SCORE, BEST, LOADING or GAME OVER, white blocks
and pipe pieces where the messages go. Worse, the status line redrawn
after a tape error took its length from a screen cell: with a pipe
there it wrote 99 characters, over the sprite pointers and CIA 1's
registers, the loader's stopwatch among them, and no further block
loaded. The texts are back below the graphics (84 bytes were free
there; the unused "PRESS FIRE TO FLAP" went), `tools/build.py` refuses
a module whose `runend` is past its screen, and `tests/flappytext.py`
reads the screen through four games. A crash into the ground at full
speed also left three dirt cells green for good (the bird's block is
kept on the grass now).

**The loader.**
- *The slowest speed on NTSC.* Stage 1 timed 128 pilot pulses (512h) on
  a 16-bit timer: at h = 124 (`-speed -12`) that is 65,903 cycles on an
  NTSC machine. It never measured the pilot, and the tape never loaded
  (in VICE: NTSC with the deck 1% slow, PAL with it 4% slow). It times
  64 now, as the core does.
- *The music on NTSC.* The show module (a tune alone, with a picture,
  and the music first) waited for each play call's raster line in a
  loop longer than a line: a call aimed at the frame's last line was
  passed unseen and came a frame late, about 45 times in 75 seconds,
  the tune a frame behind each time. On a 262-line VIC (the first NTSC
  C64s) line 262 never comes: the music stopped after 52 seconds and
  the program never started. Each look at the raster is kept now, so a
  new frame is seen at once. `tests/playgaps.py` times every call.
- *A note left on voice 3.* With the music first, a game takes voice 3
  for its effects when it starts; the note the tune had on it sounded
  on until the first effect. The kit's `sidinit` cuts it.
- *The progress count* could run to 100% for a block when a header's
  interrupt came between two reads in the main loop; it can't now.
- *The screech* droned on through a picture after it in a chain when
  the tape had no tune (the picture's module clears the SID now), and
  PETSCII-Load's tape error is white on a red border as meant (it
  compared with the VIC's register, which never reads as 2).
- *Crossy-Load:* every new game after a game over put two lanes over
  the hen's start lanes (a road or a river under her on the title).
- The interrupt's rarest path is 187 cycles (205 on a block's last
  byte), not the 164 the notes gave: the test timed the commonest
  completing pulse only. It sweeps every state now and bounds the
  overrun; DESIGN.md says what it means (19 cycles of the fastest set's
  44, once in tens of kilobytes, screen off only). Speeds are as they
  were.

**The PC tools.**
- `-analyse` ended in a traceback unless `-jitter` was given.
- A release left out Bounce-Load's and Flappy-Load's second parts
  (`-module build/modules/bounce.prg` failed there; the `.lm` files
  were whole) and `tools/seamcheck.py`, which the papers name.
  `release.py` finds the second parts itself now, masters with each
  such `.prg`, and removes what it rebuilds before comparing.
- `tools/realkit.py` deleted everything in `realtest/` first, other
  tapes kept there too. It removes its own files only.
- `speedtest.py -show all` made three tapes, not five.
- A picture as a chain's first module skipped the option checks
  (`-scroll` and the like dropped in silence, `-countdown` unchecked).
- A tape side's file with braces in its name was refused, or named in
  control codes.
- `-status` without `-start`, `-rate` and `-bitrate` out of range: said,
  not ignored. A program with a byte at $0800 is refused (the start
  clears it). A tune's workspace on stage 1's last bytes ($02F9-$02FF)
  or, with `-then`, on the chain's switch is refused.
- A CIA-timed tune made for NTSC that sets no timer got the PAL
  KERNAL's ($4025: 62.3 a second); it gets $4295 now, in `sidstrip.py`
  and SID-SLM.
- The simulator told sidstrip nothing of stores by SAX, DCP, ISC, SLO,
  RLA, SRE and RRA; the tune caches are keyed by the simulator too.
- `tools/asm6502.py` took an undefined label in `byte`, `word` or
  `text` as 0; it is an error.

**SlopLoad 64 and its tools.**
- *Three drives.* With the program on one drive, a .tap written to a
  second (a block at a time: no REU) and a chain's second module on a
  third, the tape came out cut short and SlopLoad 64 said it was done
  (in VICE: 70,011 bytes of 186,335). Asking the third drive's status
  closed the second's command channel, and a drive closes its files
  with it. Each drive in use keeps a command channel of its own now
  (three, and a .tap's drive's is never given up while it is written):
  the program, the modules, the tune and the .tap can each be on a
  drive of their own.
- A chain whose modules had five parts or more between them, with a
  tune, overflowed a list: the tune could be put where a picture's
  bitmap loads. The lists hold the worst case now.
- A second tape in a session could be silent: the "tune playing
  already" bit stayed in a module's header from the tape before.
- Leaving the TAP writer, SID-SLM, PICTURE-LM or PETSCII-LM left BASIC's
  pointers as the tool had used them: the next `LOAD` went wherever
  they pointed. They are put back (and NEW) on the way out.
- SID-SLM: a tune file within 253 bytes of its buffer's size could be
  cut wrong; a refused cut left BASIC's ROM in, so later cuts in the
  session weren't checked; a branch in a tune's last three bytes was
  refused as code outside it; 7 or 8 play calls a frame made for NTSC
  are refused, as on the PC.
- PETSCII-LM: a blank screen took the case of the last `.pet` read;
  colour bytes over 15 are masked as on the PC. PICTURE-LM: drive 0
  ("none") moved the picture's drive to the last one typed.
- The tools' unused routines went (`io.asm` and `machine.asm` split:
  `iohex.asm`, `ioprg.asm`, `machsay.asm`): with everything above
  added, the TAP writer is 641 bytes shorter than 0.15.0's, SID-SLM
  455, PICTURE-LM 434 and PETSCII-LM 359, and SID-SLM's file buffer is
  13,568 bytes (13,312).

**The module tools' menus, one style.** PICTURE-LM's values start at
column 12 as the others' do; SID-SLM's "made for" is a numbered choice
like every other; no text reaches the 40th column any more (PICTURE-LM's
list of formats had a comma alone on two rows, a few messages left a
blank row, two prompts split their default from its bracket), in
SlopLoad 64 too; "CHOOSE IT IN SLOPLOAD 64: 3, THE MODULE" reads the
same in all three.

**Tests.** Six scripts neither suite ran had gone stale and are
repaired: `stoptest.py` and `retrytest.py` (since the music came first
they stopped the tape in a module's block, before the game was there),
`irqcycles.py` (the 10-byte effect slot), `frametime.py`, `jitter.py`
(the measuring core's ring ran into the music first's player),
`crosstear.py` on a C128 and `c64disk.py`. The PC suite runs the stop
and retry tests, the cycle counts, `options.py`, `c64disk.py` and the new
`c64exit.py` now: 268 cases.

**Known, and left as they are.**
- A loading sprite's two pointers (the last bytes of the picture's
  screen: $CFF8 and $CFF9 with the picture in the top bank) are not
  kept from the program: one that loads over them turns the sprites to
  garbage until the picture ends. The program itself loads right.
- Crossy-Load's difficulty starts again after 256 lanes; a score past
  999 runs out of digits; OZ GOLD's own tune plays 3.8% sharp on NTSC
  (read in the code, not heard).

## 0.15.0 (2026-11-14)

PETSCII-Load can sound like Novaload: its screech, the program's own
bytes played as they load, so that with a screen of your own and the
block counter PETSCII-LM makes a Novaload-style loading screen. Heard on
the C64 and found close enough. Passes the test suites in VICE (243 PC
cases, 108 SlopLoad 64 cases), PETSCII-LM's test on PAL, NTSC and a
C128, and the screech's own on all three. Not played on a real C64
beyond the screech's sound.

**Novaload's screech, for PETSCII-Load.** The noise Novaload made as it
read its data (found in Spy Hunter's Kixx tape: its loader set voice 1
to a sawtooth at full volume and stored each byte it loaded into
`$D401` as well). PETSCII-LM's new line 9 ("the sound while it loads: 1
the music, 2 Novaload's screech"), `tools/petscii.py -screech` and
`slopload.py -module screen.pet -screech` play the program's own bytes
that way as they load, from the loader's running XOR of each block
(`ld_chk`), which the module checks many times a byte in its waits for
the next frame: the new value against the last one seen is the byte.
In VICE about 99% of the bytes come through exactly, on PAL, NTSC and a
C128; the scroller's split lands as before. With the block counter, it
makes a Novaload-style loading screen. The screech has the SID: a tune
isn't started beside it, and one already playing is cut off when the
screen starts; with a second module (`-then`) the PC tool cues the tune
to start with that one (as `-musicstart second`; on SlopLoad 64, the
music line's 3). The PETSCII module grew 127 bytes (its settings' bit
2); PETSCII-LM has about 360 bytes to spare. Tests: `tests/
screechcheck.py` (the SID set as Novaload's, each pitch the byte just
loaded, the gate off at the end; with a tune, the tune cut off), and
`petsciicheck.py --screech` (the split's lines); a SlopLoad 64 suite
case with the screech first in a chain and the tune with the picture
after it.

## 0.14.0 (2026-11-13)

The music comes first now: with a tune and a module, SlopLoad's player
starts the tune before anything else loads, and it plays through to the
end of the load (`-musicstart`, SlopLoad 64's music line, picks the
other two starts). A picture can draw in as it loads (an option).
SID-SLM takes PRG tunes from the C64's music editors (DMC, EMS, Future
Composer and the like), with their init and play given in hex, and the
PC tools take the same. A module's ending is one of three: at once, on
SPACE, or at the game's end. A new loading line effect, `line`.
SID-SLM, PICTURE-LM and PETSCII-LM have menus that work as SlopLoad
64's, and PETSCII-LM a blank screen for a scrolling message alone.
Passes the test suites in VICE (238 PC cases, 107 SlopLoad 64 cases;
one PC case, `cutoff-petscii-ntsc`, timed out once under load and passed
alone), SID-SLM's test (every tune, its cuts and its PRG tunes) and
PICTURE-LM's and PETSCII-LM's on PAL, NTSC and a C128. Not played on a
real C64.

**A new loading line effect: `line`.** `-stripes line:N,B` (SlopLoad 64:
line 8's `line`, its colour asked, the border line 7's first colour):
each pulse a thin line of colour N on a border of B, `LDA #N : STA
$D020 : LDA #B : STA $D020` as classic loaders did it (`line:14,0`:
light blue on black). With `-cycle` (SlopLoad 64: "the border a colour
on each block?") B goes one on at the end of every good block, the
loaders' `INC` of the `LDA #B`'s value. It needs 10 bytes in the
loader's interrupt, so the effect's slot grew from 8: the other effects
end with a `CMP #$00` and take 2 cycles more a pulse (classic 10, thin
and mixed 12, and, ora and eor 8; line 8), the effects core filling
its 1,024 bytes. Tested: `tests/stripecheck.py` (each pulse the line's
colour then the border's), `tests/cyclecheck.py` (the border's colour
one on at each block's end), and SlopLoad 64's tapes with it the same
as the model's, loaded.

**A module's ending: three choices, not one.** Once the program is in, a
game module now starts it at once (no option), when SPACE is pressed
(`-wait`, which is SPACE alone now: a game over starts a new game), or
when the game ends (`-waitgame`, new: the player plays on to the end of
the game). A module keeps `-waitgame` with its header's byte 27 bit 5
(`g_end = 1`; the five demo games do), the tool sets byte 28 bit 5, and
the kit's `gk_done` and `startkey` follow them (MODULES.md). SlopLoad 64
asks it as one question, "once the program is in, it starts: 1 at once,
2 when space is pressed, 3 when the game ends", offering only what the
module keeps, and the menu shows `+space` or `+end`. The kit's status
line says just `LOADED!` when nothing waits for SPACE (it said `LOADED!
PRESS SPACE...` while the music faded out). The kit grew by 36 bytes:
Flappy-Load's sound effects moved into its low part (now $CE10), Crossy-
Load's low part to $C92B, and OZ GOLD's set-up code after its tune.

**The music first, and it plays through to the end.** With a tune and a
module, the tune now starts before anything else loads: SlopLoad's own
player (the show module, the screen off) loads straight after the tune
and plays it while the module's parts load, then hands over to the
module, the tune playing on (the module's header +28 bit 4). It plays
through the whole load and stops only where the modules stop for the
last of the program. `-musicstart` picks when: `before` (the default),
`first` (with the first module, as before) or `second` (with a chain's
second module, the first silent). SlopLoad 64 asks it on lines 3 to 5
once a module and a tune are both chosen ("the music starts: 1 before
the modules load, 2 with the first module, 3 with the second module"),
and shows `+module` or `+second` when it isn't the default. Where the
music first can't be had, the music starts with the module, and the
tools say why: the module doesn't keep a tune that plays on, or (on the
C64) its file is over 10 KB, the show module's room in SlopLoad 64's
memory (pictures: they start the tune themselves). With speed 0 the
tune starts about 5.6 seconds into the turbo load, before the module's
parts (about 8 more for a game).

- **Through the module's set-up too.** A module's set-up draws its
  screens for 2-4 frames; the kit's new `gk_keep` (called in a long
  set-up's loops) and `gk_kend` (its last call) keep the tune in time
  meanwhile, and its end-of-frame hook bridges to the module's own first
  play call. Every demo module calls them. Measured in VICE across the
  hand-over and a chain's switch: play calls 0.27 to 1.31 frames apart
  on PAL (a module's own rhythm is one frame), within the usual two on
  NTSC (5 calls in 6 frames). `tests/musicfirst.py` checks it, on the PC
  tool's tapes and SlopLoad 64's.
- **The show module's music pacing on NTSC.** A play call that ran into
  the next frame (a long tune beside the loader's interrupts) made it
  miss a frame: about one call in ten on NTSC (45 a second, not 50). It
  now notes the line before each call, and plays at once when late.
- The kit grew again: Bounce-Load's sound effects moved into its low
  part (now $CDA0), Flappy-Load's `drawall` into its own (now $CD90),
  Crossy-Load's low part to $C8E0, OZ GOLD's tape-error display and kit
  after its tune.

**`-cycle` keeps the loading bars on through a module or the music.** It
needed `-showstripes` (SlopLoad 64: "the border cycle needs the bars
during the module or music"); the cycle is pointless without them, so it
now implies them and SlopLoad 64 no longer asks the bars question after
a yes to the cycle.

**SlopLoad 64's menu, clearer.**
- The release in its top line (`*** SLOPLOAD 0.13.0 ***`).
- Each line clears the screen and puts its name in a light blue bar at
  the top, its questions under it.
- Line 8's effects one a row, each with a few words on what it does.
- The bars question reworded: "keep the loading bars in the border while
  the module or music plays? (n: a plain border; music plays either
  way)".
- The module's counter question reworded: "the number by the module's
  loading bar: 1 the percent loaded, 2 the blocks still to load" (it was
  "count the blocks down?"); the menu shows `+blocks`. A module's options
  that don't fit on its row go on the next.
- `@` (and PICTURE-LM's and PETSCII-LM's): return alone goes straight
  back to the menu, no "press any key".
- Writing a .tap file to a disk without room for it: "another disk in:
  return to look again; another key stops", so a full disk can be
  swapped without starting over.

**PICTURE-LM and PETSCII-LM's menus work as SlopLoad 64's.** The
release in the top line; each line clears the screen and puts its name
in a light blue bar at the top; their y/n questions are numbered choices
now (PICTURE-LM: the sprites "1 hires, 2 multicolour", their size "1
normal, 2 twice as wide and tall", the ending "1 it starts at once, 2
wait for space or fire"; PETSCII-LM: the message's colours "1 as on the
screen, 2 edit them", where it goes "1 at $e000, 2 at $a000: first in a
chain").

**PETSCII-LM: a blank screen, for a scrolling message alone.** Drive 0
at line 1's question makes a blank screen (spaces, white) on a
background colour asked; the menu shows `BLANK` (the PC tool makes the
same module from a blank screen saved as a .pet: `tests/petsciilm.py`
compares the two). PETSCII-LM's message buffer moved
to $C000 and its screen buffer to $C100 (the kit's growth had pushed it
into its font at $3800); it has about 830 bytes to spare.

**A picture can draw in as it loads.** An option, made with the
picture module: `-drawin` (`slopload.py -module picture -drawin`,
`tools/picturelm.py -drawin`) or PICTURE-LM's new line 9 ("the picture,
as it loads: 1 whole, then shown, 2 drawn in as it loads"). As the first
module, such a picture loads in front of you: the module starts first
(its code, the tune, the sprites), clears the bitmap to 0 and puts the
screen on; then colour RAM, the screen RAM and the bitmap load while it
shows, the bitmap drawing itself down the screen as its bytes come, then
the program. On a Koala picture the colours show nothing until the
bitmap's bytes arrive; a hires picture's screen RAM is cleared too, and
its cells' colours show as it loads. The tune plays from the start,
before the picture (no music-first player needed). It loads at the
screen-on pace, about 6 seconds more at speed 0 (Battle Royale with its
picture: 115 s whole, 121 s drawn in). By default, and second in a
chain, a picture loads whole and then shows, as before. The show
module's header: +27 bit 6 (its maker's choice), +28 bit 6 (the tools'
when it draws in). SlopLoad 64 cuts such a picture's parts at $CC00,
$D000, $E000 and $FF40 and loads the screen and bitmap pieces last; its
own copy of the show module (a tune alone, the music first's player)
now leaves off the picture code, 500 bytes shorter, which gave it the
room.

**PRG tunes, from the music editors on a real C64.** SID-SLM takes a
tune saved as a program by DMC, EMS, Future Composer and the like (its
load address in its first two bytes) as well as a `.sid`: a file that
isn't a PSID is a PRG tune. Its menu (below) has a PRG tune's init,
`LDA #$00 : JSR $1000` (init's A and address, in hex), its play, `JSR
$1003`, its play calls a frame (1-8) and the machine it was made for
(PAL, NTSC). Init at the load address and play three past it are the
defaults, as most editors' players have them, so for those RETURN does
it. It is tried out as a `.sid` is (over 4,096 bytes, the song init's A
picks can be cut down), and the `.slm` is named after its file. On the
PC, `tools/sidstrip.py tune.prg` and `slopload.py -sid tune.prg` take
the same, as `-init 1000 -inita 00 -play 1003 -calls 1 -clock pal` (the
defaults). A tune played more than once a frame plays alone or with a
picture; with a game module it is refused, as a module plays music once
a frame.

**SID-SLM's menu works as SlopLoad 64's.** Its questions in a row are
now a menu: 1 the tune (drive and file, `$` and `@` as before; RETURN
alone keeps it), 2 a `.sid`'s song, 3-6 a PRG tune's init, play, play
calls a frame and clock (grey for a `.sid`, its own shown), RETURN to
try it and write the `.slm`, `@` the disk, Q to quit; the release in
the top line and the light blue bar on each line's screen, as the other
tools. The settings stay after a `.slm` is written: another RETURN reads
the file again and tries it once more.

- **Found on the way.** The three tools' two-choice questions answered
  with something other than 1 or 2 took choice 1, not the default
  (`readline` cleared the byte the default was kept in). Five questions
  were a character too long for the screen's line and wrapped: the file
  question in SID-SLM, PICTURE-LM and PETSCII-LM, PETSCII-LM's block
  counter row and SlopLoad 64's "the border a colour on each block?".
  `slopload.py`'s help for `-musicstart` still said `first` was the
  default.
- **Tests.** `tests/sidslm.py` drives the menu, with four PRG tunes (the
  defaults; init's A, twice a frame and NTSC; init and play typed; and
  Mono cut down) each against `sidstrip.py`'s check of the same tune, and
  a PRG too short to be a tune. `tests/c64tool.py --music tune.prg
  --prgtune a=02,calls=2` makes one on SID-SLM, then masters with it:
  two new SlopLoad 64 suite cases (a PRG tune beside a module, loaded;
  one twice a frame, alone). The PC suite has a Flappy-Load case without
  music (`small-flappy-silent`): its music-first change had called the
  player with no tune there, which only SlopLoad 64's suite caught.

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
