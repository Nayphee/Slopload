# Writing a SlopLoad module

A module is what runs on the C64 while the tape loads: a game to play,
a loading screen (PETSCII-Load, OZ GOLD), or pictures and music. The
tape takes its name (SlopLoad + Flappy game = **Flappy-Load**, + the
Crossy game = **Crossy-Load**), and any module that keeps this standard
drops in beside them. This file is the standard: what a module may and
may not do while the tape loads, the header that describes it, the
shared kit every module uses, the files it is made of, and the tests it
passes.

Start from `modules/template/`: a small game that already does
everything below. Flappy-Load (`modules/flappy/`), Crossy-Load
(`modules/crossy/`), Squeeze-Load (`modules/squeeze/`), Rubble-Load
(`modules/rubble/`) and Bounce-Load (`modules/bounce/`) are five larger
ones, built quite differently (see the end), on the same standard.

## Quick start

```bash
cp -r modules/template modules/mymodule
mv modules/mymodule/template.asm modules/mymodule/mymodule.asm
python3 tools/build.py
python3 tests/mktest.py build/test_small.prg 0x2000
python3 tools/slopload.py build/test_small.prg mymodule.tap -module mymodule
python3 tests/loadtest.py mymodule.tap
```

`tools/build.py` builds every module in `modules/`, this one to
`build/modules/mymodule.prg`. `mktest.py` makes a small test program
that checks itself once loaded, `slopload.py` puts it on a tape with
your module, and `loadtest.py` loads the tape in VICE and passes when
the program's own check does. To play it,
`x64sc -autostart mymodule.tap`.

Then make it yours: the graphics and tables in `mkdata.py`, the texts,
and the play where the template says "hold fire as long as you can".
Keep the rules below, and pass the tests at the end.

## What the loader gives you, and what it asks

The loader's interrupt reads the tape on every edge while your module
runs. It needs the CPU at once, every time, and your module gets the rest
(at least 65% of every frame; the tool keeps the loader within the
share you declare). So:

- **Never** `sei`, never write `$01` (it stays `$15`: I/O in, ROMs out),
  never touch the CIAs' timers or interrupt registers, never
  `$FFFA-$FFFF`.
- **No raster interrupts:** poll `$D012`. Between reading the line and
  the next store, the loader's interrupt (and a bad line) can hold the
  program back by up to about 6 raster lines when two edges come close,
  3.5 at speed 0: every raster-timed write needs that much slack, and a
  "wait for line N, then write" with less slack than that will miss now
  and then, however rarely.
- **At most two sprites on any raster line, and say so.** A sprite's
  DMA holds the CPU for a few cycles on each line it is on, and the
  loader's interrupt comes that much later. Measured with a picture on
  (`tests/jitter.py`, speed 0, PAL), the worst timing error is 51 cycles
  with no sprite, 59 with one on a line, 64 with two side by side, 68
  with three, 73 with four and 118 with eight double-height ones. Add 8
  for one and 16 for two to your measured `g_jitter`; the tool refuses
  more than 64 in all (the loader's pilot window), so a third on the
  same line is out. Sprites one above the other cost as one. Change a
  sprite's colour or pointer only while the beam is outside its lines
  (the show module's `sprchk` waits for that; Squeeze-Load changes its
  rocket's in the vertical blank). Squeeze-Load's rocket, one
  multicolour sprite, says 56 (48 and 8 for it; measured 52 on PAL, 53
  on NTSC and a C128, 60 at most), and so does Rubble-Load's plane
  (53 on PAL, 54 on NTSC and a C128, 59 at most). No decimal mode (the
  loader's interrupt doesn't `cld`).
- **Vertical scrolling with care.** Writing `$D011`'s scroll so that a
  bad line starts in the middle of a line (VSP: the rest of the screen
  moves sideways, some C64s crash), or so that two bad lines come one
  after the other, stalls the CPU long enough to make the loader
  misread a pulse. To change it mid-screen, copy Crossy-Load's `split`:
  a loop that stores a value for each raster line it reads, chosen so
  that a store landing up to 6 lines late is still right
  (`tests/splitmodel.py` checks such a table). Flappy-Load only writes
  it in the vertical blank.
- Read `ld_state` ($02: bit 7 loaded, bit 6 tape error, bit 5 the
  border is the loader's, bit 1 autorun, bit 0 NTSC) and `ld_progress`
  ($03, 0-255). Never write them.
- **The border is the loader's while bit 5 is set** (the tool's
  `-showstripes`: the loading lines go on through your module). Then
  never write `$D020`: set it with the kit's `gk_bord`, which leaves it
  alone, and declare `g_border = 1` in the header. A module with
  `g_border = 0` is refused with `-showstripes`.

## Memory

| what | where |
|---|---|
| the loader's: never touch | $00-$0F (bar reading $02-$03), $0259-$07FF, $FFFA-$FFFF |
| the stack | $0100-$01FF: `jsr` and `pha` as usual, never `txs` |
| your zero page | $10-$8F ($70-$7F: the music player's, if you play music) |
| debug hooks | $8E `dbg_space`, $8F `dbg_auto` (below): the same in every module |
| scratch | $0200-$0258, the BASIC input buffer: nothing reads it before the program starts. It isn't loaded or claimed, so set it up in `init` |
| your module | VIC bank 3 ($C000-$FFF9), not $D000-$DFFF (I/O) |
| a tune in SlopLoad's own player | $C000 on, when one is chosen and your module makes effects (`g_sfx`, below): keep $C000-$CAE9 free for it |
| a SID tune | placed by the tool clear of your memory (its zero page: $70-$7F at most) |

Your module is one stretch from its load address (the header) to
`g_claim`, plus, if it needs one, a second part below it: put it first
in the source between the labels `lowpart` and `lowend`, and the header
at `mainpart`; `tools/build.py` splits it off and `tools/slopload.py`
loads it with the module. Keep both out of $D000-$DFFF and, if the
module makes sound effects beside the music, clear of $C000-$CAE9, so
SlopLoad's own player can go at $C000 (the demo tunes fit there; a
longer tune goes elsewhere, with no effects).

Program bytes that fall in your memory still load, after your module
stops (with the screen off). A smaller claim means more of the program
loads while your module runs.

## The header: `src/modhead.asm`

Set seven values and include it at the load address:

```
g_claim = $fc00                 ; end of your memory (variables too)
g_jitter = 48                   ; measured: tests/jitter.py
g_share = 35                    ; the most of the CPU the loader may take
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 1                       ; it makes effects on voice 3 (0: it makes none)
g_wait = 1                      ; it keeps -wait: once loaded it stays, until SPACE (or a game's end)
g_count = 1                     ; its status line counts blocks with -countdown (the kit's)
...
*=$e000
        incasm "modhead.asm"
```

It writes the 32-byte header. Byte by byte:

| byte | what | set by |
|---|---|---|
| +0 | "PLG1": the standard, version 1 | `modhead.asm` |
| +4 | `init` (word) | your label |
| +6 | `frame` (word) | your label |
| +8 | `stop` (word) | your label |
| +10 | the end of your memory, run-time buffers included (word) | `g_claim` |
| +12 | your worst edge timing jitter, in cycles: 64 at most | `g_jitter` |
| +13 | the song to play, $FF for none | the tool |
| +14 | the most of the CPU (%) the loader may take; 0 means 35 | `g_share` |
| +15 | (the show module's picture background) | the tool |
| +16 | music init (word): call it with A = byte 13 | the tool |
| +18 | music play (word) | the tool |
| +20 | PAL time between play calls, in 1/64 raster lines (word) | the tool |
| +22 | NTSC time between play calls (word) | the tool |
| +24 | the music: 1 SlopLoad's own player at $C000 (voice 3 is yours for effects; given only to a module with `g_sfx`, and to the show module), 2 any other tune, or the player where it can't go at $C000 (all three voices) | the tool |
| +25 | (the show module's VIC bank) | the tool |
| +26 | the program's disk blocks (254 bytes; 250 at most) that load while the module runs: all of them, unless part of the program loads into the module's memory after it | the tool |
| +27 | bit 0: the module leaves the border alone while `ld_state` bit 5 is set (`-showstripes` needs it); bit 1: it makes sound effects on voice 3 when the music lets it (+24 = 1); bit 2: it keeps `-wait` (+28 bit 1); bit 3: its status line counts blocks with `-countdown` (+28 bit 3); bit 4: second in a chain, it plays on the tune the first started (+28 bit 4) | `g_border`, `g_sfx`, `g_wait`, `g_count`; bit 4 the kit's (`gk_chain`) |
| +28 | the tool's options: bit 1 `-wait`, bit 3 `-countdown`, bit 4 a chain's tune already playing (the show module's own: bit 0 the fade, which the tools now always set, bit 2 a hires picture) | the tool |
| +29 | to +31: spare (the show module's run on) | |

The tool reads bytes 4-14 and 27 and writes 13-26 and 28 on the copy it
puts on the tape, and refuses `-wait` or `-countdown` for a module that
doesn't say it keeps them (byte 27). Byte 27's bit 4 is set by
`modhead.asm` itself: the kit's `sidinit` and `musicgo` keep it (below). If your character set starts at the
load address (as in both games), the header is characters 0-3: never
show them, and call `gk_musinit` first in `init`, before anything draws
over them: it copies the music's fields, the tool's options (`gk_opt`)
and the blocks (`gk_blk`) into the kit, which reads them there.

## The three entry points

The core calls each with `jsr`, interrupts on and decimal mode off. A,
X and Y are yours; leave the stack as you found it.

- **`init`**: once, with the screen off. Set up your screens and
  colours (VIC bank 3: `$DD00` bits 0-1 = 0), call `gk_musinit`,
  `sidinit` and `musicgo`, draw everything, and leave the screen off
  (`$D011` = `$0B`): your frame turns it on.
- **`frame`**: called in a loop, one frame each. It waits for the raster
  itself, does one tick of your module (5 in 6 frames on NTSC: keep its
  speed the same as PAL), calls `status` once, and returns with the
  carry set when the program should start: end it with `jmp gk_exit`,
  the kit's, which sets the carry once `exitreq` is set (below) and the
  music has faded out. The core only looks at the carry once the
  program has loaded.

  The core calls `frame` again as soon as it returns, so "wait for line
  251" is not enough: a short frame returns while the beam is still in
  the vertical blank and runs again in the same one. Wait for the blank
  to end first, then for it to start, as the template does. Read the
  line's low byte (`$D012`) before bit 8 (`$D011`): the other way round,
  line 255 then 256 reads as line 0.

  ```
  frame
  @w0     lda $d012               ; the last vertical blank over (0-250)
          cmp #251
          bcs @w0
          bit $d011
          bmi @w0
  @w      bit $d011               ; then this one: line 251 on
          bmi @vb
          lda $d012
          cmp #251
          bcc @w
  @vb     ...
  ```
- **`stop`**: once at the end. Silence the music (`mstop`) and the SID;
  the core blanks the screen. With `-nomotor` and part of the program
  loading into the module's memory (the core's autorun, `ld_state` bit
  1) it comes as soon as the program is in, with no `frame` seeing bit 7
  first: a module that shows
  the load's end (a counter at 000) draws it here. OZ GOLD and
  PETSCII-Load call their own `frame` twice more when the counter isn't
  at 000 yet, the music off: the second shows a whole frame of 000.

## The frame's time

A PAL frame is 312 raster lines of 63 cycles (19,656 cycles), an NTSC
one 263 lines of 65 (17,095). The loader takes up to your share of that
(35% unless you say otherwise), and the screen's bad lines about 1,000
cycles more, which leaves you at least about 11,800 cycles a frame on
PAL and 10,100 on NTSC. NTSC has 60 frames a second to PAL's 50, so a
module ticks 5 frames in 6 there and has the sixth to itself.

The picture is lines 51-250. Draw what moves while the beam is
elsewhere: in the lines outside the picture (PAL: 251-311 and 0-50, 112
lines; NTSC: 251-262 and 0-50, 63), or in rows the beam has already
passed or won't reach before you are done. Then nothing tears or
flickers.
Crossy-Load draws its lanes this way, and its NTSC frame needed a lane
picked during the tick so that the short vertical blank could start
drawing at once (DESIGN.md, "Keeping every lane drawn").

Squeeze-Load moves its girders down smoothly with no scrolling and
hardly any drawing. Every girder is the same three characters (solid,
and its two ends at the gap) on two rows, and all of them share one
line in their row, so from frame to frame only those characters'
glyphs change: six of them (the three for even rows and for odd ones),
48 bytes, in the vertical blank. Its screen codes change only when the
girders step down a whole row, and the girders being an even number of
rows apart, the cells changed then show a glyph that is blank at that
moment, so those writes go anywhere in the frame, unseen (the top of
`modules/squeeze/squeeze.asm`).

Rubble-Load draws nothing outside the vertical blank but its text
rows: its tick only changes tables (the blocks' heights, the charge's
column and line, a blast's frame, the plane's place), and `vbwork`, the
first thing in each frame, shows them. The charge is two characters
whose glyphs are rewritten for its line in the row each frame, its
screen codes moved as it crosses a row; a blast is four characters where
the storey was; a new town goes up a row a frame. All of it fits in the
vertical blank, NTSC's short one too.

Bounce-Load's ball and bat move a pixel at a time anywhere in the field,
with no sprites: soft sprites in characters, as Flappy-Load's bird, but
without a second screen. Each tick draws them into characters of their
own, eight at most (the bat's three or four on its row, the ball's one
to four, one character where the two share a cell), each started from
the glyph under it. Two sets of eight take turns: the tick draws into
the set that isn't on show, and the vertical blank only writes screen
codes, the old cells put back and the new ones placed. A map of every
cell's code beside the screen says what is under them: their glyphs
come from it, the cells are put back from it, and the ball collides
with it. A brick knocked out, a row of a new wall and a message change
the map at once and the screen in the vertical blank (the score line
too), so nothing tears. The ball moves a pixel at a time and stops at what it
meets, so the frame after a bounce shows it touching what turned it,
and a brick it hit goes a tick later: the player sees it touched before
it goes (the top of `modules/bounce/bounce.asm`).

Profile your frame on PAL and NTSC with the loader running
(`tests/frameprof.py` and `tests/crossyprof.py` are examples). If
frames overrun, do less each frame, or lower byte 14 so the tool lets
the loader take less.

### A frame that runs late

If your module splits the screen (a fine scroll or a mode written
mid-screen), a frame whose work runs past the next frame's top is
worse than a slow one: that next frame never gets its vertical blank
work or its split, and shows with whatever the last split left in the
VIC (in Crossy-Load, the play field 8 pixels off, or the status rows
nudged). With the loader taking its share at unpredictable moments, a
busy frame will sooner or later run long. So:

- **Know when you are late.** The raster line alone can't say: past the
  last line it starts again at the top. The VIC's raster latch can,
  with no interrupt: set the compare line once (`$D012`, e.g. 251), and
  clear the latch (`$D019` = 1) when the frame's split is done; from
  then on `$D019` bit 0 says the beam has passed that line, so a check
  of "is there time?" reads it before trusting `$D012`. (`$D01A` stays
  0: the loader owns the interrupts.)
- **Give up what can wait, not the frame.** Work that has no deadline
  of its own (building a hidden buffer, catching up a lane, a colour
  that flashes) checks the time before it starts and leaves the rest
  for the next frame. When even the essential work won't fit, hold the
  module's tick for that frame: the module loses a fiftieth of a second,
  the picture stays right (Crossy-Load holds a tick that would start
  past line 150, 115 on NTSC). A tick already under way can still give up its
  last costly step: Crossy-Load's hen is redrawn a tick later when her
  redraw would start past line 250 (NTSC 200), so she is a frame behind
  rather than the whole picture.
- **Still recover.** If the frame's work ends in the next frame's top
  border (before about line 41), do that frame's vertical blank work at
  once rather than waiting a whole frame.
- **Give deadline work its time before the deadline.** Colour RAM has no
  second buffer. A coarse scroll's colour rows must each be written
  before the beam reaches them in the new frame. With the loader busy, a
  row takes longer to write than the beam takes to cross it, so a write
  that starts behind the beam never catches up. Crossy-Load makes its
  coarse step in a frame of its own (that frame's tick held), so the
  frame before the flip ends early. It writes each row as soon as the
  beam has passed it in that frame, and the flip's vertical blank is
  left for the rest.

Crossy-Load's check is `tests/framecap.py`: the emulator's real picture,
every frame, while the hen hops nonstop, counting frames that moved the
wrong way and frames whose vertical blank work never ran; a module of
your own can borrow its method.

## Two modules on one tape: a chain

`slopload.py -module A -then B` runs A while B's parts load, then B
while the program loads (a PETSCII screen with a counter, then a
picture). Nothing changes for either module, with two exceptions:

- **Memory.** B's parts load while A runs, so A and B can't share any
  memory, and neither can the tune. The program's bytes in A's memory
  load once B runs.
- **The tune plays on.** The tool writes the music's fields into both
  headers. A starts the tune as usual; B is called with header +28 bit
  4 set, which means the tune is already playing. The kit's `sidinit`
  then leaves the SID alone and its `musicgo` sets `musicon` without
  calling the tune's init (once: S still starts it from the top). A
  module with music code of its own does the same and sets +27 bit 4,
  or it starts the tune again.

The switch is the loader's (`src/chain.asm`, 112 bytes, which the tool
assembles and loads to $0380, in the tape buffer; SlopLoad 64 fills in a
copy's 12 bytes of addresses). B's last block carries the block flag
`f_chain` ($04). At the first frame after it, the switch:

1. moves the core's frame vector to B's frame and starts the progress
   again for the program;
2. waits for the vertical blank, turns the screen off and puts back the
   sprites, `$D016` and the scroll as the KERNAL leaves them;
3. calls B's `init`, as the core would after a boot: the screen off.

SlopLoad 64 chains the same way (its line 4 asks for B after A), reading
B's parts from B's file again as it writes the tape, so the two needn't
fit in its memory together.

A's `stop` is never called. While A runs, `ld_progress` is B's parts'
progress, full (`$FF`) two pages before B is in, and A's +26 is B's
blocks, so a counter counts them down to 000 before B takes over
(PETSCII-Load shows 000 at `$FF`). B's +26 is the program's blocks, as
usual.

## The shared kit: `src/modkit.asm` and `src/modinit.asm`

Include `modkit.asm` after your own equates, and `modinit.asm` (the two
routines only `init` calls) anywhere in your memory: beside the kit, or
where your `init` runs from if that is drawn over afterwards (Crossy-Load
puts it in `boot.asm`, in screen A; Flappy-Load after its texts, in
screen A, which `drawall` draws over once both have run). Together they
are the behaviour every module has, written once:

| routine | does |
|---|---|
| `gk_musinit` | (`modinit.asm`) copy the header's music fields, the tool's options and the blocks (first thing in `init`) |
| `sidinit` | (`modinit.asm`) the SID ready; second in a chain with the tune playing (+28 bit 4), nothing |
| `musicgo`, `mstop` | the chosen song started (second in a chain: played on, not started again), stopped |
| `minit`, `mplay`, `mflags` | the music's entry points; call `mplay` once a tick when `musicon` (once `gk_exit` has begun the fade, it plays the fade); `mflags` 1 = SlopLoad's player at $C000 (voice 3 is yours), 2 = any other tune: leave voice 3 alone too (no effects) |
| `soundkey` | S turns the music off and on (once a tick) |
| `readfire` | fire on joystick port 2: `fpress` = $10 on a fresh press; with `dbg_auto` set, your `autopilot` plays |
| `startkey` | once loaded, sets `exitreq`: at once, or with the tool's `-wait` on a fresh SPACE (call it once a tick) |
| `gk_done` | a game over: once loaded, sets `exitreq` (carry set; carry clear while loading). With `-wait`, the end of a game starts the program too |
| `gk_exit` | the frame's last call (`jmp gk_exit`): carry set when the module may end. With `exitreq` set and music playing, it starts the fade instead (2.6 seconds, `mplay` playing it) and sets the carry once it's done; with no music, at once |
| `status` | the status line (once a frame): with `-countdown` the blocks still to load in place of the percent |
| `random` | 16-bit LFSR, A = a new byte |
| `gk_bord` | the border = A, unless it is the loader's (`ld_state` bit 5); keeps A, X and Y |

It needs from you, by these names:

- zero page: `frm` (tick counter), `fire`, `fpress`, `spc`, `skey`,
  `exitreq`, `smode`, `sprog`, `musicon`, `rnd` (2), `tmp`, `tmp2`,
  `tmp3`, `pt2` (2); and `sbcell` (one byte anywhere);
- `scra`, `scrb`: your two screens (one screen: the same address twice);
- `gk_srow`: the status line's offset in a screen (row × 40);
- `gk_barhalf`: 0 for a bar of 9 characters (0-8 pixels filled), 1
  for 5 (0, 2, 4, 6, 8: four characters spared, as Crossy-Load does);
- character codes: `c_space`, `c_bar` (9 or 5 of them, as `gk_barhalf`),
  `c_barl`, `c_barr`, `c_pct`, `c_digit0` (0-9 in a row): the status
  line is hi-res, white text, a yellow bar;
- texts, a length byte then your codes: `tx_loading` "LOADING",
  `tx_error` "TAPE ERROR: REWIND A BIT, PRESS PLAY", `tx_loaded`
  "LOADED! PRESS SPACE TO START THE GAME";
- `autopilot`: returns A = 0 to press fire, $10 not;
- the fade: `incasm "fadekit.asm"` anywhere it fits (about 300 bytes;
  Flappy-Load and Bounce-Load put it in a second part at $CE80, Crossy-Load
  in its low part), and its scratch `fsh`, `fkn`, `fsv` (25, 25 and 34
  bytes, untouched while the module still runs once the program is in):
  `incasm "fadescr.asm"` makes them bytes; a loading screen can point
  them at memory free by then (OZ GOLD and PETSCII-Load: their colours'
  bytes). The kit sets `fstep` (8: about 2.6 seconds).

## What every module does

A game does all of this. A loading screen keeps the sound, debug hooks
and screens; it shows its own progress and ends by itself once the
program is in (OZ GOLD, below).

- **The status line** (one text row, top or bottom): LOADING, a 20-cell
  bar and the percent while it loads; TAPE ERROR, flashing, after a
  tape error (rewinding a little and pressing PLAY recovers); LOADED!
  PRESS SPACE TO START THE GAME once it's in, with `-wait`. With the tool's
  `-countdown` (header +28 bit 3), the blocks still to load ("024",
  down to 000 as the loader kits of the 1980s and TND's showed them) in
  place of the percent: the kit's `status` does it, from header +26, so
  a module that uses it says `g_count = 1`.
- **When the program starts** (set `exitreq`): as soon as it's in. A
  module doesn't wait for anyone: when the load is done it ends (a game
  mid-round too), and the program starts: the kit's `startkey`, called
  once a tick. Every module's music fades out first (about 2.6 seconds,
  the kit's `gk_exit` and `fadekit.asm`; a game plays on meanwhile);
  with no music, at once. A loading screen ends by itself (OZ GOLD and
  PETSCII-Load show 000 while their music fades).
  Only if whoever masters the tape asks for it, with the tool's `-wait`
  (header +28 bit 1; SlopLoad 64 asks with the module), does the module
  stay (`g_wait = 1` says it can):
  - a game until SPACE (`startkey`) or the end of a game (`gk_done`,
    called at game over), the player playing on round after round, LOADED!
    PRESS SPACE TO START THE GAME on the status line;
  - a loading screen at its end (OZ GOLD and PETSCII-Load: 000 on the
    counter, the music on) until SPACE, then as without it (the fade).
  Whether and how a module tells the player to press SPACE is its own
  choice: the kit's status line says LOADED! PRESS SPACE TO START THE
  GAME, OZ GOLD writes PRESS SPACE on its tape error row, and PETSCII-Load
  leaves it to the screen's author (the screen or its scroller).
  Until then the module goes on, also with the tape stopped: players stop
  the tape just to play (as with Invade-a-Load).
- **The border:** every write to `$D020` through `gk_bord`, so that
  with `-showstripes` the loading lines stay in it (`g_border = 1`).
  A tape error still shows there: with bit 5 set the loader turns the
  border red itself, beside your status line's TAPE ERROR.
- **Controls:** fire on joystick port 2; SPACE to start the program; S
  for the music. Nothing else is needed to play.
- **Sound:** the music through the header's vectors; effects on voice 3
  only when `mflags` is 1: the tune is in SlopLoad's own player
  (`music/player.asm`, marked "SLP1" after its jump table: the demo
  tunes are) and the tool could put it at $C000, where it leaves voice
  3 alone. Any other tune has every voice. A module that makes effects
  says so in its header (`g_sfx = 1`); one that doesn't (OZ GOLD,
  PETSCII-Load) gets every tune with all three voices.
- **Debug hooks** for the tests: `dbg_space` ($8E) non-zero acts as a
  SPACE press once loaded; `dbg_auto` ($8F) non-zero plays by itself
  (your `autopilot`), and stops trying once the program has loaded, so
  the round ends. A value of 2 may mean "never lose" (Crossy-Load's).
- **Screens:** no flicker, no torn moving objects; right on PAL, NTSC and
  a C128 in C64 mode. What the player sees is what the game plays: if
  something is drawn late, collisions go by where it is drawn.

## What a module is made of

Put the module in `modules/<name>/<name>.asm` (its includes beside it);
`python3 tools/build.py` builds every module it finds, running
`modules/<name>/mkdata.py` first if there is one (graphics, tables). It
writes, in `build/modules/`:

| file | what |
|---|---|
| `<name>.prg` | the header and the main part, at its load address |
| `<name>_low.prg` | the second part, if the module has one |
| `<name>.parts.json` | the second part, if the module has one: loaded with it (always) |
| `<name>.lm` | the whole module in one file: what the tools take (`-module build/modules/<name>.lm`) |

A module brings no music of its own unless it is built in (OZ GOLD's):
the tune is a file of its own, chosen when the tape is made (`-sid`).
A path in a parts file is looked for beside the parts file first, then
in the SlopLoad folder, so the three files can be handed to someone
else as they are. They master with the module's path in place of a name:

```bash
python3 tools/slopload.py program.prg program.tap -module path/to/mymodule.prg
```

### On the C64: the `.lm` file

SlopLoad 64 (the mastering tool on a C64) reads a module from disk as one
file, a `.lm` (loader module), which `tools/build.py` also writes: `build/modules/<name>.lm`. Copy
it onto any disk (with VICE's `c1541`, an SD2IEC, or any disk tool),
named as you like with `.lm` at the end (`mymodule-load.lm`), and it
shows in SlopLoad 64's list of modules on that drive. A `.lg` from
SlopLoad 0.4.0 or before is the same file under its old name: rename it
to end in `.lm`.

The file is each part of the module, one after another:

| bytes | what |
|---|---|
| 2 | the part's address (low byte first) |
| 2 | its length |
| that many | its bytes |

The main part (the one starting with the header) comes first, then the
second part if there is one. A `.lm` is not a program to LOAD: SlopLoad
64 reads it into its own memory (12 KB at most, the parts together) and
writes the parts onto the tape. It checks what the PC tool does: the
header's "PLG1", a jitter of 64 or less, and nothing in the loader's
memory. Beside a SID tune, the module must also leave the tune room: SlopLoad
64 refuses a tune that uses the module's zero page ($10-$6F and $80-$8F),
plays other than once a frame, takes more than 3,700 cycles a call, or
sits in the module's memory.

## Tests your module passes

1. The load cases: add your module to `tests/suite.py` (copy the
   `small-crossy*`, `big-crossy-s0` and `sid-crossy-*` lines with your
   name) and run them: PAL, NTSC, C128, a fast speed, MP3, a SID tune,
   each way of starting the program, a 250-block program.
2. `tests/stoptest.py --module NAME` and `tests/retrytest.py --module NAME`:
   a stopped tape and a damaged block, then a rewind.
3. `tests/jitter.py --module NAME` (and `--auto 2` if your module has a mode
   that never ends): header byte 12 is the 99.9% figure; the worst edge
   must stay well under the slowest speed's margin (124 cycles). The
   tool refuses more than 64: a pilot must still fit the loader's
   window before it is measured.
4. A frame profile on PAL, NTSC and a C128 (`x128 -go64`) with the
   loader running (`tests/frameprof.py` and `tests/crossyprof.py` are
   examples): no frame overruns, nothing written where the beam is.
5. If your module keeps tables of what is on screen, a check that the
   screen matches them as it plays (`tests/crossycheck.py` does this for
   Crossy-Load, and `tests/lanelag.py` measures how far its drawing
   falls behind; `tests/squeezecheck.py` draws Squeeze-Load's tables
   into a picture and compares it with the emulator's own, every frame,
   and its collisions with what each frame shows; `tests/rubblecheck.py`
   does the same for Rubble-Load, a town going up included, and
   `tests/bouncecheck.py` for Bounce-Load, every bounce and every brick
   hit shown touching the ball).
6. If it makes sound effects (`g_sfx = 1`), `tests/sfxcheck.py --module
   NAME` (and `--ntsc`): beside a demo tune the effects get voice 3 and
   the tune never touches it; with any other tune, `--expect music`.
7. `tests/waitcheck.py --module NAME --wait --countdown` (and without
   them, `--ntsc`, `--machine x128`): with `-countdown` the number after
   the bar is the blocks still to load at every look, without it the
   percent; without `-wait` the module ends within a few ticks of the
   load (a loading screen after its fade), with no key; with `-wait` it
   stays until SPACE (`--end space`), and a game played on past the load
   ends at its game over (`--end game`).

## Before you share it

- `g_jitter` measured, `g_claim` covering every buffer, `g_share` what
  the profile showed;
- the status line, SPACE, S and fire on port 2 as above, and the program
  starting as soon as it's in, and with `-wait` on SPACE or a game's end;
- no `sei`, no raster interrupts, at most two sprites on a line (in its
  `g_jitter`), nothing at $FFFA-$FFFF;
- the tests above passed on PAL, NTSC and a C128;
- its `.lm` file mastered by SlopLoad 64 (`tests/c64tool.py --module
  path/to/mymodule.lm`) as well as by the PC tool;
- played to the end on a real C64 from a cassette, if you can.

## Not only games: OZ GOLD

A module needn't be a game. `modules/ozgold/` is OZ GOLD, a loading
screen in the style of U.S. Gold's Novaload one, on the same standard
(`-module build/modules/ozgold.lm`, or `ozgold.lm` in SlopLoad 64). It shows some things a
module can do beyond playing:

- **Its own status.** No LOADING bar: BLOCKS TO LOAD counts the program
  down from header byte 26 (the tool's: the blocks that load while it
  shows) and `ld_progress`, and TAPE ERROR flashes on a blank row. The
  kit's `status` isn't called.
- **Its own music, built in.** `mkdata.py` moves `music/build/ozgold.sid`
  to $E900 with `tools/sidreloc.py` (checked as SlopLoad 64 checks a tune
  beside a module) and writes it as source. In `init`, if the tool chose
  no tune (byte 13 $FF), it points `minit`/`mplay` at its own; a `-sid`
  tune still replaces it.
- **The ROM font, in another VIC bank.** A module can't switch the
  character ROM in (`$01` is the loader's), but the VIC sees the ROM font
  in banks 0 and 2 by itself. OZ GOLD's screen is a second part at $BC00
  (bank 2, `$D018` = $F4: the screen at $3C00, the font at $1000), so
  its design is ordinary PETSCII, made by `mkscreen.py`.
- **Once the program is in, 000 and a fade**, as Novaload did: BLOCKS
  TO LOAD stays at 000 while the music fades out (the kit's
  `fadekit.asm`, below), then the program starts. Nobody is playing, so
  nothing waits for a key, unless the tool's `-wait` asks: then it holds
  at 000, the music on, with PRESS SPACE on the tape error's row, and
  fades once SPACE is pressed (PETSCII-Load holds the same way, with no
  prompt of its own: put one in your screen or its scroller). Its own tune sets `$D418` at its init only,
  so `init` sets `fdirect` and the fade writes the volume itself; a
  `-sid` tune is faded as PETSCII-Load fades one.

`tests/ozgoldcheck.py` checks it at every frame of a load.

`modules/petscii/` (PETSCII-Load) is the same idea made general: any
PETSCII screen, written into a module with fixed places for it (the
codes in its second part at $BC00; the border, background, `$D018` and
colours from byte 32 of its main part), so a tool can put a screen in
without assembling anything. `tools/petscii.py` does it on a PC (and the
PC tool takes a `.pet`, `.petmate` or `.c` as `-module`), PETSCII-LM on a
C64. It can also scroll a message across a row and count blocks down.
A screen in a font of its own gets a third part: the tool keeps only
the characters the module shows, numbered again from 0, at $B800 (128
or fewer: right under the screen, `$D018` $FE) or $B000 ($FC), still in
VIC bank 2, and writes the new codes into the screen, the message and
two settings after the message's length (byte 1042: the space the
scroller's row is cleared with, and the counter's digit 0; $20 and $30
in the C64's own set). The module itself doesn't know about fonts: it
sets the `$D018` and uses the codes it is given.
The scroller is a split like Crossy-Load's, kept simple: `$D016` (its
fine scroll) is written while the beam is in the empty row above the
scroller's and put back in the empty row below, so a write the loader
holds up a few lines still lands where nothing shows. It keeps 40
columns: 38 would hide the row's ends smoothly, but the side borders
would then move in on whichever line the write landed, a few pixels of
border flickering beside the empty row. Instead the row's column 0 has
the background's colour, so the message leaves at the left a character
at a time, unseen, and comes in under the right border. The music
goes before the split for a row low on the screen and after it for one
near the top, wherever the frame has the most time; and with a scroller
the module asks the loader for less of the CPU (35%).

Once the program is in, PETSCII-Load (and OZ GOLD) holds the screen
(000 on the counter, the scroller still going) and fades the music out
before it asks to stop, as U.S. Gold's Novaload did; the code is the
kit's `src/fadekit.asm`, which every module includes (a game's fade is
the kit's `gk_exit`): 16 volume steps, 15 to 0, of `fstep` ticks each,
the kit's equate (8, about 2.6 seconds), and with no music 000 alone
for half that. Asking in the same frame as the
counter reached 000, as it first did, blanked the screen before 000
ever showed. The fade has to know the tune's filter mode, the top half
of `$D418`, which is write-only. SlopLoad's own player sets `$D418` at its
init only (filter off), so it plays on and `$D418` is the volume. A SID
tune can write it anywhere, every frame or only at init, directly or
through an index, so the module catches its writes instead: the tape is
stopped by then (no tape interrupts), so each tick runs its play routine
with the I/O banked out (interrupts off, the FLAG interrupt too in case
it plays with `cli`), its SID writes landing in the RAM under the SID,
whose program bytes are saved and put back; the registers it wrote go
to the SID, `$D417` down to `$D400` (a voice's ADSR before its gate),
and `$D418` with its own filter mode and the volume scaled. A register
it hasn't written since is preloaded with a mark ($A5, then $5A each
other tick), so it isn't written to the SID. A tune that hasn't written
`$D418` keeps its own until the first step down and then gets low-pass:
in 376 tunes from the HVSC, 99 never wrote `$D418` after their init,
and of those with voices routed to the filter 30 of 37 had low-pass
(without any routed the mode makes no difference). Two limits, both for
the 2.6 seconds of the fade only: a register a tune changes twice in one
tick (a gate off and on, a test-bit restart) reaches the SID as its last
value, and voices a tune routed to the filter with no mode (5 in 376)
are heard low-passed. With `-nomotor`, when part of the program loads
into the module's memory, the loader stops the module as soon as the
rest of the program is in, so there is no fade (the counter still shows
000 for a frame: `stop`, above). `tests/petsciicheck.py`
follows it to the module's stop: 000 held, the volume ($D418 as VICE
keeps it) falling 15 to 0 in 16 steps of 8 ticks, the music still
playing, `$01` as the loader has it each tick, and the RAM under the SID
unchanged; `tests/ozgoldcheck.py` does the same for OZ GOLD. With
`--cutoff` (that case) both check the stop's two frames instead: the second a frame
after the first, 000 drawn by then, the screen on and the SID silent.

## The five games, on the same standard

| | Flappy-Load | Crossy-Load | Squeeze-Load | Rubble-Load | Bounce-Load |
|---|---|---|---|---|---|
| status line | row 24, split at line 222 | rows 0-2 (score, messages, status), split in blank rows 3-4 | row 24, no split (score row 0, messages row 1) | row 24, no split (score row 0, messages row 1) | row 24, no split (score row 0) |
| play field | scrolls left 2 px a tick, double-buffered | rows 5-20 (eight lanes), scrolls up smoothly, double-buffered; lanes redrawn while the beam is away | rows 2-22, columns 4-35 (a shaft, 256 pixels); girders fall smoothly with no scrolling: six characters redrawn in the vertical blank, one screen | rows 2-22, a town of 16 blocks in columns 4-35 on a street (row 23); nothing scrolls: the charge's two characters, a blast's four and a new town's rows drawn in the vertical blank, one screen | rows 2-23, columns 4-35 in a frame; a wall of 16 bricks by 8 rows (rows 4-11); nothing scrolls: the soft sprites' cells, bricks and rows written in the vertical blank, one screen |
| player | a bird in 9 characters (soft sprite) | a hen in 9 characters | a rocket, one multicolour sprite | a plane, one multicolour sprite (8 lines: one character row) | a bat (12 multicolour pixels by 5 lines) and a ball (3 by 6), soft sprites in up to 8 characters, two sets taking turns |
| characters | 128, ASCII text codes | 128, packed text codes | 128, ASCII text codes; multicolour girders and rock | 128, ASCII text codes; multicolour blocks (three styles), street, charge and blasts | 128, ASCII text codes; multicolour bricks (plain, tough, cracked) and frame; 107-127 hold the wall and the soft sprites' cells at run time |
| memory | $E000-$FBFF, and the fade at $CE80-$CFFB (a second part) | $C94F-$CFFE (the fade in it) and $E000-$FFF9 (two parts), and $0200-$0255 (a buffer, two tables, five variables) | $E000-$F781 | $E000-$F8A6 | $E000-$FBE6, the fade at $CE80-$CFFB (a second part), a map of the field at $FC28-$FFBF (run time: claimed, not on the tape), and $0200-$0253 (two rows' colours) |
| round ends | the bird crashes | the hen dies (traffic, river, swept away, train) | the rocket touches a girder | the plane flies into a block | the last of three balls is lost |
