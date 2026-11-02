# SlopLoad: real hardware tests

Everything here passed in VICE. What VICE can't show is a real
datasette: its motor speeding up and running down, its heads, its
wow and flutter. Nor can it run an Ultimate's turbo. These tests cover
those, roughly in order of how much they matter. Use a tape you don't
mind writing over, wound past its clear leader.

## The files

| file | what |
|---|---|
| `slopload-test.d64` | SlopLoad 64 (`SLOPLOAD64`), the TAP writer (`TAPWRITER`), PETSCII-LM and SID-SLM (`PETSCII-LM`, `SID-SLM`), the demo modules, screens and tunes (`FLAPPY-LOAD.LM`, `CROSSY-LOAD.LM`, `OZGOLD.LM`, `PETSCII.LM`, `DEMO.PET`, `SLOPLOAD.SLM`, `ENIGMA.SLM`, and `SLOPLOAD.SID`, `ENIGMA.SID` for SID-SLM), and three test programs: `TEST6K`, `TEST14K` and `TEST63K` (6, 14 and 63 KB) |
| `slopload-test.d81` | the same, plus `CROSSY14K.TAP` and `SIDE.TAP` for the TAP writer |
| `crossy14k.tap` | TEST14K with Crossy-Load at speed 0, from the PC tool |
| `side.tap` | a tape side from the PC tool: TEST6K, then TEST14K |
| `battleroyale-crossy.tap` | Battle Royale with Crossy-Load and the SlopLoad tune, from the PC tool |
| `battleroyale.d81` | SlopLoad 64, the TAP writer, the demo modules and tunes, the game (`BATTLEROYALE`), that tape (`BATTLEROYALE.TAP`) and its loading picture (`LOADING.KOA`) |

A test program, once loaded and started, checks every byte of itself and
shows **PASS** on a green border, or **FAIL** on a red one. With
Crossy-Load, the status line says when the program is in; SPACE starts it.

## The tests

**1. SlopLoad 64 to a cassette, a block at a time** (the main one: the
motor stops between blocks). A C64 with no REU (on an Ultimate: its REU
off), `slopload-test.d64` in drive 8.

    LOAD"SLOPLOAD64",8
    RUN

SlopLoad 64 shows its menu: press a line's number to set it (and any
key after its questions, for the menu again). First **@** (the disk):
8, then `$`: the disk's directory, as BASIC lists it; `I`: `00, OK,00,00`;
RETURN alone, a key. **1** (program): 8,
`TEST14K`. **4** (module): 8, then the number of
`CROSSY-LOAD.LM` from the list. **5** (music): 8, `SLOPLOAD.SLM`. **9**
(write to): 1 (cassette). Then RETURN, and RECORD and PLAY. It takes a
few minutes: the motor stops while each block is read from the disk.
Then rewind, reset, `LOAD` (or SHIFT+RUN/STOP), play Crossy-Load until it
says the program is in, SPACE: PASS?

**1a. SID-SLM, then the same with its tune:** `slopload-test.d64` in
drive 8.

    LOAD"SID-SLM",8
    RUN

8, `SLOPLOAD.SID`. It tries the tune out, counting to 3,000 (about two
minutes), then says `PLAYS ONCE A FRAME`, `LONGEST PLAY CALL: 2253
CYCLES`, `ZERO PAGE: $70-$7F`, `WORKSPACE: NONE`. The .slm's name: `TUNE`
(it adds `.SLM`). Q, then test 1 again with **5** `TUNE.SLM`: PASS, and
the same music?

**2. The same in one go, in colour** (an Ultimate with its REU on, or a
C64 with a 1750 or bigger): the machine under the title should end with
the REU's size (`512 KB REU`; from 1 MB on in MB: an Ultimate's 16 MB
REU says `16 MB REU`), and after **9** (1, cassette) it asks "in one go": Y, and line
9 says so. Then **0** (colours): 6 (fire), and **2** (name): CLR/HOME
with SHIFT, CTRL+2 (white), then `TEST`. No motor stops this time. Load
it back as in 1: the screen should clear at FOUND, TEST in white, and
the border's lines red, orange and yellow as it loads.

**3. A big program, a block at a time:** as in 1, with `TEST63K` and
**3** (show): 0 (nothing). 16 blocks, some of them under the I/O area at
$D000. Load it back: it starts by itself: PASS?

**4. A .tap file, then the TAP writer:** `slopload-test.d81` in a drive
that can hold it (a 1581, an SD2IEC, the Ultimate's 1581). In SlopLoad
64: **1** `TEST14K`, **4** `FLAPPY-LOAD.LM`, **5** `ENIGMA.SLM`, then
**9**: 2 (.tap file) on that drive. Then, with an REU:

    LOAD"TAPWRITER",8
    RUN

The .tap's drive, its name (`TEST14K.TAP`), RECORD and PLAY. Load the
cassette back: PASS?

**5. The TAP writer with the PC's tape:** as in 4, with `CROSSY14K.TAP`
from the .d81. Load it back: PASS?

**6. A tape side:** the TAP writer with `SIDE.TAP`. Load it: TEST6K starts
by itself (PASS). Reset, `LOAD` again: TEST14K (PASS)?

**7. A real game with Crossy-Load:** `battleroyale.d81`. With the TAP
writer, `BATTLEROYALE.TAP` to a cassette; and with SlopLoad 64 (no REU, a
block at a time): **1** `BATTLEROYALE`, **4** `CROSSY-LOAD.LM`, **5**
`SLOPLOAD.SLM`, **9** cassette. Load each back: Crossy-Load with music while it
loads (148 blocks while the module runs, about two minutes), SPACE once it
says so, and Battle Royale's title picture. While you play: every car,
log and train keeps moving, the hen only dies when she visibly meets a
car, a train or the water, and nothing flickers. (The kit before
2026-10-25 had a Crossy-Load whose middle lanes froze: this one is
fixed, with eight lanes instead of ten.)

**8. A picture and music:** `battleroyale.d81`, SlopLoad 64: **1**
`BATTLEROYALE`, **6** `LOADING.KOA`, **5** `ENIGMA.SLM` (the show
becomes 3, a picture and music), **9** cassette. Load it back: the
Battle Royale picture with the tune while it loads, then the game's
title by itself.

**9. Accelerators, if you have them:** test 1 again on an Ultimate with
Turbo Control set to "U64 Turbo Registers" (the pauses between blocks
should be shorter), and on a C128 in C64 mode. A SuperCPU only makes .tap
files (test 4's first half).

## What to send back

For each test: PASS or FAIL, any **TAPE ERROR** on the status line (or a
red border with the screen off), anything that looked wrong, and roughly
how long the writing took.

If you can dump a cassette back to a .tap (TAPuino, DC2N, an Ultimate's
tape capture), the dump of test 1's cassette is the most useful thing of
all: `python3 tools/seamcheck.py dump.tap` shows how your deck took each
motor stop, and the dumps show how close to the tool's timing the pulses
came back.
