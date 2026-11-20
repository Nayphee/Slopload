# The `.lm` module format

A loader module (a `.lm` file) is everything a SlopLoad tape shows while
it loads: a game, a loading screen, a picture. This file is the format's
full description: the bytes of the file, the module's header, the calls
the loader makes, the memory it may use, and the relocations that let
any module be first or second in a chain. `MODULES.md` is the standard a
module keeps while it runs and the kit that helps it; `LMGUIDE.md` builds
a small one by hand, line by line.

Who reads and writes `.lm` files:

| tool | does |
|---|---|
| `tools/build.py` | writes `build/modules/<name>.lm` for every module in `modules/`, its relocations found by building it twice |
| `tools/slopload.py` | reads one with `-module` and `-then`; moves one a VIC bank down for a chain |
| `tools/petscii.py`, `tools/picturelm.py` | write one: a PETSCII screen, or a picture, in the PETSCII-Load or the show module (`tools/build.py` makes one of a `modules/NAME/NAME.pet` the same way: OZ GOLD) |
| SlopLoad 64 (on a C64) | reads them from disk (lines 3 and 4); moves one for a chain |
| PETSCII-LM, PICTURE-LM (on a C64) | write one, as the two PC tools above |
| `tools/c64model.py` | what SlopLoad 64 does, in Python (the tests' reference) |
| `tools/lmreloc.py` | the relocations: reading, writing, moving (the PC tools use it) |
| `tools/prglm.py`; PRG-LM (on a C64) | write one from the programs (`.prg`) any assembler wrote: a module made without `tools/build.py` |

## The file

A `.lm` is the module's parts one after another, then its relocations.
It is not a program to LOAD: there is no load address in front. Each
part is:

| bytes | what |
|---|---|
| 2 | the part's address, low byte first |
| 2 | its length, low byte first |
| that many | its bytes, as they go into memory |

- **The main part comes first.** It starts with the module's header (32
  bytes, below), at the module's load address.
- **Other parts** follow in any order: a second piece of code below the
  main part (`tools/build.py`'s `lowpart`), a font, a screen. Parts may
  not overlap, and none may be at $0000.
- **The relocations come last** (optional): a block like a part, at
  address $0000, its length and its bytes (below, "A module that
  moves"). Nothing follows it. The header's +27 bit 7 says it is there.

**From a program.** What an assembler writes is a program, a `.prg`: its
load address, then its bytes. A module of one part as a `.lm` is that
file with the part's length put in after the address. `tools/prglm.py`
on a PC and PRG-LM on a C64 (a BASIC program, on SlopLoad 64's B side
and printed in `LMGUIDE.md`) write a `.lm` from an assembler's
programs, one for each part, with its relocations if they are given
the same programs assembled a bank lower ("Making a module that
moves", below). The PC mastering tool also takes a module's `.prg` as
it is (`-module mymodule.prg`: one part, or more with a parts file
beside it, `MODULES.md`); SlopLoad 64 takes a `.lm` only.

A file with no relocation block is a module all the same: it loads and
runs as it is, but the tools can't move it, so it can only share a tape
with a module whose memory it doesn't touch. Every module made with
SlopLoad 0.17.0 or before is such a file: rebuild it (`tools/build.py`),
or make it again (PETSCII-LM, PICTURE-LM, `tools/petscii.py`,
`tools/picturelm.py`).

A `.lg` file from SlopLoad 0.4.0 or before is the same file under its
old name: rename it to end in `.lm`.

### An example

A module of two parts: the main part (its header and code) at $C000,
$0123 bytes long, and a second part at $E000, $0400 bytes:

```
00 C0 23 01   50 4C 47 31 ...      main part: $C000, 291 bytes: "PLG1", ...
00 E0 00 04   ...                  second part: $E000, 1,024 bytes
00 00 06 00   06 02 04 00 00 00    relocations: 6 bytes (below)
```

### Limits

| | the PC tools | SlopLoad 64 |
|---|---|---|
| parts | any number | 4 at most |
| the file | any length | its parts within 12,282 bytes (its pool, $D000-$FFF9); a file longer than that (its relocations past the end) loads, but can't move |
| a chain's second, moved | | its relocations beside the first's file in the pool (12,282 bytes together) or, where the first fills it, 512 bytes at most |

Every part must keep out of the loader's memory, $0000-$07FF and
$FFFA-$FFFF, and code can't run in $D000-$DFFF (the I/O is there while
the tape loads).

## The header

The main part's first 32 bytes. The module sets bytes 0-12, 14 and 27;
the tool sets 13-26 and 28 on the copy it writes to the tape (byte 14
too, from what the module asked), and reads 4-14 and 27.

| byte | what | set by |
|---|---|---|
| +0 | "PLG1" ($50 $4C $47 $31): the standard, version 1 | the module |
| +4 | `init` (word): called once, the screen off | the module |
| +6 | `frame` (word): called once a frame | the module |
| +8 | `stop` (word): called once at the end | the module |
| +10 | the end of the module's memory, run-time buffers included (word; 0: to the top, $FFFF). An address of the module's own: it moves with it | the module |
| +12 | its worst edge-timing jitter, in cycles (0 means 48; 64 at most) | the module (measured: `tests/jitter.py`) |
| +13 | the song to play, A for the tune's init; $FF none | the tool |
| +14 | the most of the CPU (%) the loader may take (0 means 35) | the module, the tool |
| +15 | the show module's picture background ($FF none) | the tool |
| +16 | the tune's init (word) | the tool |
| +18 | the tune's play (word) | the tool |
| +20 | the time between play calls on PAL, in 1/64 raster lines (word) | the tool |
| +22 | ... on NTSC (word) | the tool |
| +24 | the music: 1 SlopLoad's own player at $C000 (voice 3 the module's), 2 any other tune (all three voices) | the tool |
| +25 | the show module's VIC bank ($DD00's two low bits: 0 bank 3, 1 bank 2) | the tool |
| +26 | the program's disk blocks (254 bytes; 250 at most) that load while the module runs; a chain's first: the second's | the tool |
| +27 | what the module keeps, a bit each (below) | the module |
| +28 | the tool's options, a bit each (below) | the tool |
| +29 | to +31: spare (the show module's header runs on) | |

Byte +27, the module's:

| bit | the module ... |
|---|---|
| 0 | leaves the border to the loader while `ld_state` bit 5 is set (`-showstripes`: the loading lines on through it) |
| 1 | makes sound effects on voice 3 when the music lets it (+24 = 1) |
| 2 | keeps `-wait`: once the program is in, it stays until SPACE |
| 3 | keeps `-countdown`: its status line can count blocks |
| 4 | second in a chain, plays on the tune the first started |
| 5 | keeps `-waitgame`: a game played on to its end |
| 6 | (the show module) a picture made to draw in |
| 7 | carries its relocations: the tools may move it a VIC bank down |

Byte +28, the tool's: bit 1 `-wait`, bit 3 `-countdown`, bit 4 the tune
is playing already (a chain's second, or the music first), bit 5
`-waitgame`, bit 6 (the show module) the picture loads after it starts;
the show module's own: bit 0 the fade, bit 2 a hires picture. The tools
refuse `-wait`, `-waitgame` and `-countdown` for a module whose +27
doesn't keep them.

The show module (SlopLoad's own, for pictures: `modules/show/show.asm`)
runs its header on: +29 to +75 its sprites, +76 the place of a Koala
picture's colours in its own memory (word), and +78 to +86 its hand-over
to a module when it plays the music first.

## The calls

The core calls each entry point with `jsr`, interrupts on and decimal
mode off. A, X and Y are the module's; it leaves the stack as it found
it.

- **`init`**: once, the screen off. The module sets up its screens and
  colours, starts the tune (if +13 isn't $FF and +28 bit 4 is clear:
  `jsr` the tune's init with A = +13), and leaves the screen off.
- **`frame`**: in a loop, one call a frame. It waits for the raster
  itself (the core calls it again as soon as it returns), does a tick
  of its work, and returns with the carry set when the program should
  start. A tick is 50 times a second on PAL and NTSC alike (5 frames in
  6 on NTSC), and the tune's play routine is called once a tick (`jsr`
  the address at +18); the show module times its calls from +20 and
  +22 instead. The core looks at the carry only once the program is in
  (`ld_state` bit 7).
- **`stop`**: once, at the end. Silence the SID; the core blanks the
  screen.

The loader's two bytes the module reads, and never writes: `ld_state`
($02: bit 7 loaded, bit 6 a tape error, bit 5 the border is the
loader's, bit 1 autorun, bit 0 NTSC) and `ld_progress` ($03, 0-255).
`MODULES.md` has the rest of the rules: no `sei`, no raster interrupts,
`$01` left alone, two sprites on a line at most.

## Memory

| what | where |
|---|---|
| the loader's: never touched | $00-$0F (bar reading $02-$03), $0259-$07FF, $FFFA-$FFFF |
| the module's zero page | $10-$8F ($70-$7F the music player's, with a tune) |
| scratch | $0200-$0258 |
| the module | VIC bank 3, $C000-$FFF9, not $D000-$DFFF; a bank lower, $8000-$BFF9, when the tools move it |

**Its claims.** The tools take the module's memory to be its main part
from its address to +10's end (or the main part's own end, if that is
further; to $FFFF if +10 is 0), and each other part as it is. Nothing
else may load there while it runs: a tune is placed outside it, and the
program's bytes that fall inside load after the module stops, with the
screen off. A chain's two modules may not share any of it (below).

## A module that moves

In a chain (`slopload.py -module A -then B`, SlopLoad 64's lines 3 and
4) the second module loads while the first runs, so the two must not
share memory. Most modules are built for VIC bank 3, and two of them
would. So each module carries the list of its own addresses, and the
tools move one of the two a VIC bank down, from $C000-$FFF9 to
$8000-$BFF9:

1. If the two share no memory, nothing moves.
2. Else the first moves, if it can (+27 bit 7 and a relocation block)
   and that clears them.
3. Else the second moves, if it can and that clears them (on SlopLoad
   64, its relocations must also fit: beside the first's file, 12,282
   bytes together, or in 512 bytes where the first fills that).
4. Else, with the first as it is or moved, if only the second's parts
   below $C000 are in the first's memory, they are staged: two modules
   that both keep a screen at $BC00 for the C64's own font (PETSCII
   screens: OZ GOLD is one). See "A second's screen, staged" below.
5. Else the chain is refused: "the two modules share memory".

`slopload.py` says which moved (`moved a VIC bank down (from $E000)`)
and where a staged screen waits (`load at $FB00 while the first
shows`); SlopLoad 64 says "the first goes a vic bank lower" or "it goes
a vic bank lower", and "its screen waits at $FB00 till the switch",
under line 4's parts.

### What moving does

- Each part at $C000 or above goes $4000 lower. A part below $C000 (a
  screen at $BC00 shown with the C64's font, a font of the module's own
  at $B000) stays where it is.
- Each byte the relocations list goes $40 lower: the high byte of one
  of the module's own addresses in bank 3.
- Each bank byte goes one higher: $DD00's bank bits (0 for bank 3, 1 for
  bank 2).
- Its claims: each from $C000 on $4000 lower, the main part's end too
  ($FFFF, to the top: $C000). So +10 must move with the module: write it
  relative to the module's base, as every other address.

A moved module runs in VIC bank 2. Everything it shows (its screens,
font, sprites, bitmap) must be at the same offsets in whichever bank it
runs in, and it must choose the bank from its own address, not a number
(the kit's `gk_bank`: `lda #>gk_bank`, its top two bits the bank). In
bank 2 the VIC sees the C64's character ROM at $9000-$9FFF, so a moved
module keeps out of the bank's $1000-$1FFF for its own graphics (in bank
3, $D000-$DFFF, where it can't run code anyway).

### A second's screen, staged

A module that shows the C64's own font keeps its screen in VIC bank 2,
where the VIC sees that font: PETSCII-Load (any PETSCII screen, OZ
GOLD among them) at $BC00, a screen's own font beside it. Two of those in a chain
need the same screen. Moving the second's screen elsewhere would mean
changing every address of it in its code and its `$D018`; instead the
tools stage it. The second's parts below $C000 (not its main part), the
span of them in whole pages, load at the highest free page in memory
(PETSCII-Load's screen, four pages, at $FB00) while the
first still shows its own screen at $BC00. When the second is in, the
switch (`src/chain.asm`, in the tape buffer) turns the screen off,
copies the span to its place a page at a time, and calls the second's
init: the first screen stays whole until then, and the second starts
with its own.

The span and its staging place are both the second's memory as far as
the tune and the program are concerned. Nothing in the module changes:
any module whose parts below $C000 are only screens and fonts can be
staged.

### The relocation block

```
$00 $00          its address (no part is at $0000)
len              its length, a word
for each part, in the file's order:
    gaps         one byte each: 1-254, the next byte to move is that many
                 on (from the part's start, less one); 255, 254 on with
                 nothing moved there; 0, this part's list ends
n                the bank bytes: how many (0 for most modules)
n bytes          their places in the header (0-31)
```

The example above: the main part's bytes +5, +7 and +11 move (the high
bytes of `init`, `frame` and the claim; gaps 6, 2, 4: -1+6 = 5, 5+2 =
7, 7+4 = 11), the second part's none, no bank bytes:

```
00 00 06 00   06 02 04 00   00   00
```

Each list is in its part's order, every offset inside its part. A part
that stays has an empty list (a lone 0).

### Making a module that moves

**From source (`tools/build.py`).** Give the module's bank a name, `mb`,
and write every address of its own in bank 3 from it:

```
mb      = $c000                 ; the module's VIC bank (build.py: $8000 a bank lower)
scr     = mb+$0400              ; its screen
chr     = mb+$0800              ; its font
g_claim = mb+$3c00              ; the end of its memory
*=mb+$2000
```

`tools/build.py` assembles it twice, with `mb = $c000` and with `mb =
$8000`, and compares: every byte that differs must differ by $40 (an
address's high byte). Those bytes are the relocations. A difference of
anything else (an address built from a low byte, a table of offsets that
changes size) stops the build with where it is. It then checks that +10
moves with it, sets +27 bit 7 and writes the block. A part that must
stay (PETSCII-Load's screen at $BC00) is given an address of its own
(its `lowat`), the same in both builds.

**Without the build.** Assemble the module with `mb = $c000` and again
with `mb = $8000`, in any assembler, and give both programs to
`tools/prglm.py` (`prglm.py my.lm my.prg -lower my8.prg`) or, on a C64,
to PRG-LM. They list the bytes that differ as `tools/build.py` does,
with the same checks, set +27 bit 7 and write the block: the same file
`tools/build.py` writes (`tests/prglmtest.py` compares them for every
demo module). `LMGUIDE.md`, "With any assembler, or on a C64 alone",
goes through it.

**Made by a tool.** `tools/petscii.py` and PETSCII-LM, `tools/picturelm.py`
and PICTURE-LM write the PETSCII-Load and show modules' relocations with
the module: the template's own, as `tools/build.py` found them, the
show module's colours' place (+77) when a Koala picture has one, and
+25, the picture's VIC bank.

**Tested.** `tests/movecheck.py MODULE [--second]` masters a chain with
the module moved, whether or not it must be (`slopload.py`'s test hook
`SLOPLOAD_MOVE=first|second`), and runs it in VICE with a stick that
wanders: any read or write of $C000-$CFFF or $E000-$FFF9 by the moved
module's code fails, with the address as built. Its frame must run every
frame, the VIC in bank 2. `tests/stagecheck.py` plays a chain with a
staged screen: the first's screen unchanged by the second's loading for
as long as it shows, the second's bytes in place at its init.

## What the tools do with it

Reading a `.lm`, the PC tools and SlopLoad 64 check: "PLG1", a main part
of 32 bytes or more, a jitter of 64 or less, nothing in the loader's
memory, and (SlopLoad 64) four parts at most, within its pool. Then, on
the copy that goes on the tape:

1. the header's +13 to +26 and +28: the tune, its timing, the blocks,
   the options (and +14, the share, 35 where the module left 0);
2. in a chain, the module moved a bank down if it must, and a second's
   parts below $C000 given their staging place (above);
3. its parts written as tape blocks, the main part last, at the boot's
   speed (the module runs from its first frame after them). A chain's
   switch (`src/chain.asm`: 136 bytes at $0378, in the tape buffer)
   follows the first's parts; the second's blocks load while the first
   runs, the last carrying the block flag that makes the switch. The program's blocks follow, those that fall in
   the module's claims last of all, after it has stopped.

SlopLoad 64 keeps the first module in its pool and moves it there; a
moved second is read from its file block by block as the tape is
written, each block's listed bytes $40 lower as they come (its
relocations kept after the first's file in the pool). It chooses as
the PC tool does, within its memory: a module file longer than its pool
(a picture's, with its relocations) can't move there, so the other
module does, and a moved second's relocations must fit beside the
first's file or, after a first that fills the pool, in 512 bytes (every
demo module's do but Crossy-Load's, 610: it can't follow a picture on a
C64).
