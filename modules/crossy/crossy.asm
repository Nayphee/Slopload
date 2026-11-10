; ------------------------------------------------------------
; crossy.asm  -  Crossy-Load, a SlopLoad module
;
; Hop a white hen up an endless road of lanes while the program
; loads: grass, traffic, rivers with logs to ride, railways with
; trains. Fire hops one lane forward. The screen creeps up by
; itself, and a hen it catches at the bottom is shoved forward into
; whatever is in front of her.
;
; No sprites (sprite dma would add to the loader's timing jitter):
; cars, logs and trains are characters, and the hen is drawn into a
; 3x3 block of characters (a soft sprite). An object slides 2 px at
; a time through pre-shifted end characters, so a move rewrites only
; the cells at its ends. The loader owns the IRQ line, so everything
; is timed by polling the raster:
;   line 251+  vertical blank: status scroll, screen buffer, the hen,
;              colour ram, music, then building the hidden buffer
;   line 75-90 the split, in two blank rows: the play field's fine
;              vertical scroll (the play field starts on the first
;              line matching it, whatever the timing)
;   then       one game tick (5 in 6 frames on ntsc); each lane is
;              redrawn once the beam has passed it, so the screen
;              shows it whole, before or after
;
; Screens (40x25): rows 0-2 status (score and title, messages,
; loading), rows 3-4 blank, rows 5-18 the play field (19-24 blank:
; less to draw, so the lanes keep up on NTSC too), lanes two
; rows high. A whole-row scroll shows the other buffer, which was built
; as a copy of this one a row lower in the time left over before.
;
; Memory (vic bank 3): charset $e000-$e69f (this module's header is
; in characters 0-3, never shown), tables and code from $e6a0,
; screens $e400 and $e800 (run time, in the character set's half
; that is never shown), code from $ec00. Claims $e000-$fbff.
;
; Zero page $10-$8f. Never sei, never touch $01, the cia timers,
; or $fffa-$ffff (src/abi.asm has the rules).
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- the standard parts (src/modhead.asm, src/modkit.asm) ----
g_claim = bssend                ; end of the memory claimed (variables too)
g_jitter = 48                   ; worst edge timing jitter (tests/jitter.py)
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 1                       ; it makes effects on voice 3 (beside SlopLoad's player)
g_wait = 1                      ; with -wait it plays on until SPACE or a game's end (the kit's)
g_count = 1                     ; with -countdown its status line counts blocks (the kit's)
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 1                  ; the status bar: 5 characters, 2 px a step
gk_srow = 2*40                  ; the status line: row 2

; ---- memory ----
scra = $e400                    ; (the character set's half that is never shown)
scrb = $e800
d018a = $98                     ; screen $e400, charset $e000
d018b = $a8                     ; screen $e800
chrset = $e000

; ---- play ----
playlo = 8                      ; the hen's x range (multicolour px):
playhi = 148                    ; carried past it, she is swept away
lastrow = 20                    ; the play field's last row (below: blank)
cutrows = 24-lastrow            ; (rows hidden at the bottom)
htarget = 88                    ; the camera chases a hen higher than this
walkhi = 144                    ; she walks no further right (playlo-walkhi:
                                ; columns 2-37, clear of the edge trees)
hsymax = 122                    ; ... and she can't hop from higher (her block
                                ; would reach the rows above the play field)
hoptime = 8                     ; ticks a hop takes (2 px a tick)
deadtime = 70                   ; ticks from death to game over
lockout = 100                   ; ticks before game over takes fire
warntime = 64                   ; ticks of warning before a train

st_title = 0
st_play = 1
st_dead = 2
st_over = 3
st_build = 4

; ---- zero page ($10-$8f; $70-$7f is the music player's) ----
st = $10                        ; state
tmr = $11                       ; ticks in this state
frm = $12                       ; tick counter
ntscc = $13                     ; ntsc: 5 ticks in 6 frames
front = $14                     ; buffer on show: 0 a, 1 b
nfront = $15                    ; buffer on show from the next vblank
ehi = $16                       ; lanedraw: next lane from the top
elo = $17                       ; ... from the bottom
crow = $18                      ; scrl / 8 (mod 256): whole rows scrolled
vs = $19                        ; fine scroll for the coming frame
cfrac = $1a                     ; camera crawl: fraction of a px
cspd = $1b                      ; ... added each tick
hx = $1c                        ; hen x (multicolour px from the left)
hl = $1d                        ; hen's lane (world, mod 256)
hsy = $1e                       ; her lane's bottom above the screen's (px)
hoff = $1f                      ; hop: px still to rise
hop = $20                       ; hop: ticks left (0 standing)
hopq = $21                      ; a press during a hop: hop again
hfrm = $22                      ; image: 0 standing, 1 flat
hmax = $23                      ; furthest lane reached
scl = $24                       ; score, bcd
sch = $25
bestl = $26
besth = $27
rnd = $28                       ; 2 bytes
fire = $2a                      ; $10 while held
fpress = $2b                    ; $10: pressed this tick
exitreq = $2c                   ; 1: the player wants the program
smode = $2d                     ; status line drawn: mode
sprog = $2e                     ; ... and progress
sfxtime = $2f                   ; voice 3 effect: frames left
sfxprio = $30                   ; ... its priority
musicon = $31                   ; 1: music playing
flipreq = $32                   ; 1: show the other buffer at the vblank
bready = $33                    ; 1: the hidden buffer is a row lower than this
cprow = $34                     ; building it: next row (25 done)
pmode = $35                     ; 0 copy a row down, 1 draw from scratch
colreq = $36                    ; 1: colour ram rows to check
lgen = $37                      ; next lane to make (world)
runt = $38                      ; lane type of the current run
runn = $39                      ; lanes left in it
death = $3b                     ; how she died (0-3)
flash = $3c                     ; frames of white background
hseen = $3d                     ; 1: the hen is drawn
vcur = $3e                      ; fine scroll of the frame on show
bbuf = $3f                      ; buffer the hen's block is in
colr = $6e                      ; colour rows: next to check
crowx = $6f                     ; crow of the buffer being drawn
bcol = $40                      ; hen block on show: column, row
brow = $41
bset = $42                      ; character set on show (0/1)
bsave = $43                     ; 9 chars under the block
ncol = $4c                      ; hen block for the next vblank
nrow = $4d
nset = $4e
nsave = $4f                     ; 9
nvalid = $58                    ; 1: a new block is waiting for the vblank
bshift = $59                    ; image shift 0-3 (multicolour px)
bys = $5a                       ; image's row within the block's top row
cell = $5b
skey = $5c                      ; s key held last tick
spc = $5d                       ; space held (start key)
mntsc = $5e                     ; ntsc: the music's own 5 in 6 (a held tick
                                ; doesn't hold the music)
tmp = $60
tmp2 = $61
tmp3 = $62
tmp4 = $63
lj = $64                        ; lane work: ring index
lrow = $65                      ; screen row of the lane's top
lcode = $66                     ; glyph base for the row (+10 bottom row)
on = $67                        ; object length (cells)
ox = $68                        ; object x (multicolour px)
oi = $69                        ; pattern index
lt = $6a                        ; lane type
lw = $6b                        ; world row
henin = $6d                     ; bits 7/6: the hen's block in the lane's bottom/top row
pt = $80                        ; pointers
pt2 = $82
pt3 = $84
pa = $86                        ; a row in the buffer on show
pb = $88                        ; ... and in the hidden one, a row lower
pa2 = $8a                       ; the lane's bottom row, on show
pb2 = $8c                       ; ... and hidden
hent = $5f                      ; bsave index of column 0 of the lane's top row
erow0 = $3a                     ; lanedraw: the top lane's top row
elast = $6b                     ; ... its last entry (shares lw: regenrow
                                ; never runs inside lanedraw)
ej0 = $6c                       ; ... and its lane
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: non-zero plays by itself

*=$c94f                         ; (past $c000-$c94e: SlopLoad's player there, the effects beside it;
                                ; the low part ends at $cfe8 as before, the fade in it too)
lowpart                         ; (a second part: tools/build.py splits it off)
        incasm "low.asm"
lowend

*=$e000
mainpart
        incasm "modhead.asm"
        incasm "chars.asm"
                                ; characters 125-127, never shown:
hshown  byte 0,0,0              ; the hen's shift, row and image on show
roadspd byte 60,72,84,96,108,120,136,152,168,184  ; road speeds and putv's
pvtab   byte <rput,>rput,$4c,<rputt,>rputt  ; addresses (world.asm's: the
        byte <putc,>putc,$4c,<putt,>putt    ; room); 1 byte spare

*=scra+256                      ; screen a's rows 6-24: setting up, run once
initpart                        ; from here before the screen is used
        incasm "boot.asm"
initend                         ; (scra+1000 at most: lmov; tools/build.py)

*=scra+1016                     ; each screen's last 8 bytes, never shown
imglo   byte <henimg,<henimg+42,<henimg+84,<henimg+126,<henimg+168
holdt   byte 150,115            ; a tick held from this line: PAL, NTSC (vb1)
*=scrb+1016
imghi   byte >henimg,>henimg+42,>henimg+84,>henimg+126,>henimg+168
budt    byte budgetl,130        ; lanedraw starts lanes till: PAL, NTSC (the
                                ; held frames: 180)
*=$ec00

; ------------------------------------------------------------
; frame  one frame: vertical blank, split, one tick
;   out:  carry set when the player has chosen to go on (only
;         asked for once ld_state bit 7 says the load is done)
; ------------------------------------------------------------
frame
@w1     bit $d011               ; the vertical blank: line 251 on
        bmi @vb
        lda $d012
        cmp #251
        bcs @vb
        cmp #41                 ; or late, still above the picture: the
        bcc @vb                 ; last frame's work ran into this one's top
                                ; (it ends after its split, line 60 on, so
                                ; lines 0-40 here mean late): this frame's
                                ; blank work now, its status rows' scroll
                                ; set before line 49, rather than a frame
                                ; shown with the split's scroll (8 px off)
        lda flipreq             ; else, a row's scroll due: the colour rows
        beq @w1                 ; the beam has passed, ahead of the flip
        jsr colrows             ; (c set: cmp)
        jmp @w1
@vb     lda #$1b                ; status rows: fine scroll 3
        sta $d011
        ldx #0
        lda flash
        beq @bg
        ldx #1
@bg     stx $d021
        lda flipreq             ; a whole row scrolled: the other buffer
        beq @nf                 ; (its new lane and top row drawn already:
        lda #0                  ; hen.asm's flipwk)
        sta flipreq
        sta bready              ; ... and this one, a row on, to draw
        sta pmode
        lda nfront
        sta front
        ldx crow
        stx crowd               ; the lanes as this buffer has them
        inx
        stx crowx
        lda #6
        sta cprow
        sta colreq              ; (non-zero) its colours: the rest of them
@nf     ldx front
        lda d018s,x
        sta $d018
        jsr show                ; the hen
        lda colreq
        beq @nc
        sec                     ; until the beam nears the top
        jsr colrows
@nc     lda st                  ; the lanes furthest behind (not dead,
        cmp #st_dead            ; over or building: still)
        bcs @bw
        jsr lanevb
@bw     jsr bgwork              ; the hidden buffer, while there is time
        jsr split
        lda colreq
        beq @nm
        clc                     ; the rest: below the beam already
        jsr colrows
@nm     lda musicon             ; the music (here: it isn't timed, and the
        beq @ct                 ; colour rows before the split get the time):
        lda ld_state            ; every frame, NTSC 5 in 6, whether or not
        lsr a                   ; the tick is held (a camera step, a late
        bcc @mp                 ; frame), or the tune would falter
        dec mntsc
        bne @mp
        lda #6
        sta mntsc
        bne @ct
@mp     jsr mplay
@ct     jsr beam                ; late (past line 150, NTSC 115; or past
        ldx vb1                 ; 251: beam says 255): this tick held, as
        cmp holdt,x             ; NTSC's sixth is, so that the next frame is
        bcs @hold               ; on time (a frame's work can't run into the
                                ; next one's top: that frame would show with
                                ; the split's scroll, 8 px off)
        lda pmode               ; the camera at fine scroll 7 (not in a new
        bne @n7                 ; world's build: its lanes come by the tick):
                                ; the other buffer not ready, the tick
                                ; held for it (its rows get the frame's
        lda vs                  ; time: a hen redrawn every tick, as when
        eor #7                  ; she walks, would leave it none and the
        bne @n7                 ; scroll would stall); bready 2, the
        lda bready              ; whole-row step due
        beq @hold
        cmp #2
        beq @step
@n7     lda ld_state
        lsr a
        bcc @tick               ; pal: every frame
        dec ntscc
        bne @tick
        lda st                  ; ntsc: hold every sixth (pal's speed); the
        cmp #st_dead            ; lanes get its time, starting till line 180
        bcs @hold               ; (71 lines at most: done by the vertical
        lda #180                ; blank)
        sta budop+1
        jsr lanedraw
        ldx vb1                 ; (then the usual: NTSC's earlier, its
        lda budt,x              ; frame shorter)
        sta budop+1
        bne @hold               ; (ntscc: 6 again)
@step   dec bready              ; the step in a frame of its own, the tick
        jsr camstep             ; held (NTSC: as its sixth): the flip's
        jsr henpos              ; blank is left for the colour rows
@hold   lda #6                  ; (NTSC: it counts as its sixth: no slower
        sta ntscc               ; than PAL unless short of time)
        bne @held
@tick   jsr tick
@held   jsr status
        jsr bgtail              ; time left: more of the hidden buffer
        jmp gk_exit             ; (c set: end, the music faded out first)

d018s   byte d018a,d018b
henlate byte 250,200            ; the hen's block left for the next tick
                                ; from this line: PAL, NTSC (t_play)

; ------------------------------------------------------------
; split  the play field's fine scroll (vs + 3), written while the beam is
; in the blank rows 3 and 4. A store to $d011 can be held back by the
; loader's interrupt (and a bad line) by up to 6 lines, so no store is
; made on a guess of where the beam will be: from line 60 a loop reads
; the line y and stores, again and again,
;     y < 85:           3        (as the status rows have it)
;     85 <= y < 85+vs:  (y-1)&7  (the line just passed: its next match is
;                                 8 lines on, so it starts no bad line)
;     y >= 85 + vs:     vs + 3   (then returns)
; Whichever of the last 6 lines' values is in force, every line agrees
; on being a bad line or not: rows 3 and 4 start at 75 and 83, row 5 at
; 91 + vs, never a bad line from mid-line (VSP) or two running, and the
; status rows are untouched (tests/splitmodel.py checks every vs and
; start line). It must start by line 85; later, no store (shown as if vs
; were 0: crossyprof.py counts these, and there must be none).
; Also the 24-row border at the bottom (row 24 can start too late to
; show); the vertical blank puts 25 rows back.
;   uses: a, y, tmp
; ------------------------------------------------------------
split
@w      bit $d011
        bmi @w                  ; 256-311: not yet
        lda $d012
        cmp #200
        bcs @w                  ; the bottom of the last frame
        cmp #60
        bcc @w
        cmp #86
        bcs @late               ; too late to start
        lda vs
        clc
        adc #85
        sta tmp                 ; the final value's first line
@l      ldy $d012
        cpy tmp
        bcs @fin
        cpy #85
        bcc @3
        dey                     ; the line just passed
        tya
        and #7
        ora #$10                ; screen on, 24 rows
        bne @s                  ; (always)
@3      lda #$13
@s      sta $d011
        bne @l                  ; (always: a is $1x)
@fin    lda vs
        sta vcur
        clc
        adc #3
        and #7
        ora #$10
        sta $d011               ; the play field's scroll
@ack    lda #1                  ; the raster latch (line 251: low.asm's
        sta $d019               ; init) cleared: set again, this frame's
        rts                     ; work has run late (bgtail looks)
@late   lda #0                  ; (as if vs were 0: the scroll stays 3)
        sta vcur
        beq @ack

; beamok  in the vertical blank, before line 58 of the next frame
; beamto  ... before line a (the split must start by line 85: work
;         started here must be over by then)
;   out:  carry clear if there is time for more
beamok  lda #58                 ; (a colour row takes up to 19 lines)
beamto  sta oi
        bit $d011
        bmi @ok
        lda $d012
        cmp #200
        bcs @ok
        cmp oi
        rts
@ok     clc
beamx   rts                     ; (t_play's too)

; ------------------------------------------------------------
; tick  one step of the game
; ------------------------------------------------------------
tick    inc frm
        inc tmr
        bne @t
        dec tmr                 ; stays at 255
@t      jsr readfire
        jsr sfxtick
        jsr soundkey
        jsr startkey
        lda flash
        beq @nf
        dec flash
@nf     lda st
        cmp #st_build
        bne @nb
        jmp t_build
@nb     lda st                  ; the hen dead, the game over: everything
        cmp #st_dead            ; stands still
        bcc @mv
        beq t_dead
        bne t_over
@mv     jsr lanemove            ; the title, play: the world moves
        lda st
        bne t_play              ; (else: the title, next)

; ---- title: the hen waits; fire hops ----
t_title jsr lanedraw
        lda fpress
        beq @x
        lda #st_play
        sta st
        lda #0
        sta tmr
        jsr clrmsg
        jsr hopgo
@x      jmp henpos

; ---- playing ----
t_play  jsr henmove             ; hop, ride, collide (may die)
        lda st
        cmp #st_play
        bne @x
        jsr camera              ; (before the lanes: they stop when time runs out)
@x      jsr lanedraw
        jsr beam                ; too late for the hen's block (up to 90
        ldx vb1                 ; lines with her render): the next tick's,
        cmp henlate,x           ; a frame behind, as under a lane's redraw
        bcs beamx               ; (the frame after would be missed)
        jmp henpos

; ---- dead: a while, everything still ----
t_dead  lda tmr
        cmp #deadtime
        bcc @x
        lda #st_over
        sta st
        lda #0
        sta tmr
        ldx #<tx_over
        ldy #>tx_over
        jsr setmsg
@x      jmp henpos

; ---- game over: once loaded, the program starts (gk_done: with -wait,
; the end of a game); before, a lockout, then fire plays again ----
t_over  jsr gk_done
        lda tmr                 ; (everything still: the hen as she was)
        cmp #lockout
        bcc @x
        bne @ready
        ldx #<tx_again          ; once: "press fire"
        ldy #>tx_again
        jsr setmsg
@ready  lda fpress
        beq @x
        jmp newround
@x      rts

; ---- a new world being drawn in the hidden buffer ----
t_build lda lgen                ; its lanes, three a tick
        cmp #16
        bcs @b
        jsr genlane
        jsr genlane
        jmp genlane
@b      lda cprow
        cmp #lastrow+1
        bcc @x
        jsr flipset             ; done: show it at the next vblank
        jsr titlego
        jmp flipwk
@x      rts

; newround  a new world, drawn in the hidden buffer over the next
; few frames (the old one stays still meanwhile)
newround
        jsr newworld
        lda #st_build
        sta st
        lda #0
        sta nvalid
        rts

; titlego  the title scene: the hen on the start lane
titlego lda #st_title
        sta st
        lda #0
        sta tmr
        ldx #<tx_hop
        ldy #>tx_hop
        jsr setmsg
        jmp henpos

; ---- tables ----
scrhi   byte >scra,>scrb
rowlo   byte <0,<40,<80,<120,<160,<200,<240,<280,<320,<360,<400,<440,<480
        byte <520,<560,<600,<640,<680,<720,<760,<800,<840,<880,<920,<960
rowhi   byte >0,>40,>80,>120,>160,>200,>240,>280,>320,>360,>400,>440,>480
        byte >520,>560,>600,>640,>680,>720,>760,>800,>840,>880,>920,>960
cellofs byte 0,1,2,40,41,42,80,81,82
cellx   byte 0,1,2,0,1,2,0,1,2
celly3  byte 0,0,0,1,1,1,2,2,2
cellchr byte 0,3,6,1,4,7,2,5,8    ; cell (row by row) -> character (down the columns), and back
x8      byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152
x8p7    byte 7,15,23,31,39,47,55,63,71
setlo   byte <chrset+hen0*8,<chrset+hen1*8   ; (both in page >chrset)

; ------------------------------------------------------------
; sound effects on voice 3 (none with a sid tune: it has every voice)
; ------------------------------------------------------------
; effects: 1 hop, 2 the railway bell, 3 death; a lower one doesn't
; cut a higher one short
sfxhop  lda #1
        bne sfxgo
sfxding txa
        pha
        lda #2
        jsr sfxgo
        pla
        tax
        rts
sfxdie  lda #3
sfxgo   ldx mflags
        cpx #2
        beq @x                  ; a sid tune has every voice: no effects
        ldx sfxtime
        beq @go
        cmp sfxprio
        bcc @x
@go     sta sfxprio
        tax
        lda #0
        sta $d412               ; restart the envelope
        sta $d40e
        sta $d414
        lda sfxhi-1,x
        sta $d40f
        sta sfxf
        lda sfxad-1,x
        sta $d413
        lda sfxlen-1,x
        sta sfxtime
        lda sfxwave-1,x
        sta $d412
@x      rts

sfxhi   byte $22,$58,$06
sfxad   byte $07,$0a,$0b
sfxlen  byte 3,8,14
sfxwave byte $41,$11,$81

; gate off when the effect's time is up; the hop chirps up
sfxtick lda sfxtime
        beq @x
        dec sfxtime
        bne @s
        ldx sfxprio
        lda sfxwave-1,x
        and #$fe
        sta $d412
        lda #0
        sta sfxprio
@x      rts
@s      lda sfxprio
        cmp #1
        bne @x
        lda sfxf                ; (carry set: + 13 a tick)
        adc #$0c
        sta sfxf
        sta $d40f
        rts

        incasm "world.asm"
        incasm "hen.asm"
        incasm "hengfx.asm"

; ---- variables (not in the file: after its last byte) ----
bss
ltype = bss                     ; lanes, 16 each
lbase = bss+16                  ; first character
lcol = bss+32                   ; colour ram
lspd = bss+48                   ; speed: px/256 a tick
lfrac = bss+64
lx = bss+80                     ; offset of the pattern (multicolour px)
lpat = bss+96                   ; pattern
ltim = lfrac                    ; railway: ticks to the train (or of it)
lhead = lx                      ; ... the train's head cell (signed), nopat none
llen = lspd                     ; ... its length (cells)
bssend = bss+112
trash = $0200                   ; 40: writes to rows that aren't there (in
                                ; $0200-$0258, free for modules: MODULES.md)
rowcol = $0228                  ; colour ram of each row, as written (25)
ldrawn = $0241                  ; road, river: lx as drawn (16; to $0250)
crowd = $0251                   ; crow of the buffer on show
sbcell = $0252                  ; the status bar's last filled cell
vbpick = $0253                  ; lanevb's next lane (picked at the tick)
vb1     = $0254                 ; 1 on NTSC: drawlane a pixel a call
sfxf    = $0255                 ; the effect's frequency, high byte (the sid's
                                ; registers can't be read back)
lmov = scra+1000                ; (the screens' last 24 bytes are never shown)
ldir = scrb+1000
