; ------------------------------------------------------------
; flappy.asm  -  Flappy-Load, a SlopLoad module
;
; Flap through the pipes while the program loads. No sprites:
; sprite DMA would add to the loader's timing jitter, so the bird
; is drawn into a 3x3 block of characters (a soft sprite). Two sets
; of bird characters alternate, so one is drawn while the other is
; on show. The loader's interrupt owns the IRQ line, so everything
; is timed by polling the raster:
;   line 222+  status split: no scroll, black background (rows 21-22
;              are even dirt, so a write anywhere in them is unseen)
;   line 251+  vertical blank: scroll, screen buffer, bird block
;   then       one game tick (5 in 6 frames on ntsc)
;
; Screens (both buffers, 40x25): rows 0-19 sky and pipes, scrolled
; 2 px a tick; 20 grass, 21-22 dirt (never change); 23 score; 24
; loading bar or messages. Messages in the sky go in three 12-cell
; spans (rows 5, 7, 12) that are hi-res white while shown.
;
; Memory (vic bank 3): charset $e000 (this module's header sits in
; characters 0-1, never shown; bird characters 2-19 at run time),
; code $e400, bird images $f000, screens $f400 and $f800 (run time).
; Claims $e000-$fbff: program bytes there load after it stops.
;
; Zero page $10-$8f. Never sei, never touch $01, the cia timers,
; or $fffa-$ffff (src/abi.asm has the rules).
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- the standard parts (src/modhead.asm, src/modkit.asm) ----
g_claim = $fc00                 ; end of the memory claimed
g_jitter = 48                   ; worst edge timing jitter (tests/jitter.py)
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; the status bar: 9 characters, 1 px a step
gk_srow = 24*40                 ; the status line: row 24
c_digit0 = 48                   ; (plain ascii codes: see mkdata.py)
c_pct = 37

; ---- memory ----
scra = $f400
scrb = $f800
d018a = $d8                     ; screen $f400, charset $e000
d018b = $e8                     ; screen $f800
chrset = $e000
bset0 = 2                       ; bird characters: set 0 2-10, set 1 11-19
bset1 = 11

; ---- colours ----
col_sky = 3                     ; cyan
col_white = 1
col_yellow = 7
col_green = 5+8                 ; multicolour, cell colour green
col_bird = 7+8                  ; multicolour, cell colour yellow
col_text = 1                    ; hi-res white

; ---- play ----
birdx = 73                      ; screen x of the bird (odd: see birdpos)
gaprows = 6                     ; rows of open sky between the pipes
pipeevery = 14                  ; columns from one pipe to the next
grav = $26                      ; fall speed added each tick (1/256 px)
flaphi = $fd                    ; velocity after a flap: -2.75 px a tick
flaplo = $40
maxfall = 4                     ; px a tick
hitx0 = 2                       ; bird's box within its image
hitx1 = 16
hity0 = 1
hity1 = 10
groundy = 160                   ; top of the grass, playfield pixels
birdmax = groundy-bird_h        ; bird resting on the grass
lockout = 150                   ; ticks before game over takes fire
txcol = 14                      ; message spans: columns 14-25
txw = 12
txr1 = 5
txr2 = 7
txr3 = 12

st_title = 0
st_play = 1
st_dead = 2
st_over = 3

; ---- zero page ($10-$8f) ----
st = $10                        ; state
tmr = $11                       ; ticks in this state
frm = $12                       ; tick counter
ntscc = $13                     ; ntsc: 5 ticks in 6 frames
xs = $14                        ; fine scroll: 7, 5, 3, 1
front = $15                     ; buffer on show: 0 a, 1 b
nfront = $16                    ; buffer to show at the next vblank
copyrow = $17                   ; 0/10 copy rows, 20 column, 21 done, $ff wait
byl = $18                       ; bird y (8.8, image top, playfield px)
byh = $19
vyl = $1a                       ; bird velocity (8.8, signed)
vyh = $1b
bfrm = $1c                      ; image 0-2: wing up, middle, down
fire = $1d                      ; $10 while held
fpress = $1e                    ; $10: pressed this tick
scl = $1f                       ; score, bcd
sch = $20
bestl = $21
besth = $22
rnd = $23                       ; 2 bytes
gcount = $25                    ; columns to the next pipe
gk = $26                        ; pipe column 0-3 being generated, 4 none
ggap = $27
pend = $28                      ; gap of a pipe entering at the swap, $ff none
exitreq = $29                   ; 1: the player wants the program
smode = $2a                     ; status line drawn: mode
sprog = $2b                     ; ... and progress
v_d016 = $2c                    ; staged for the next vblank
v_d021 = $2d
flash = $2e
sfxtime = $2f                   ; voice 3 effect: frames left
sfxprio = $30                   ; ... its priority (1 flap, 2 point, 3 hit)
musicon = $31                   ; 1: music playing
pc4 = $32                       ; pipe columns + 4 (4 slots, $ff empty)
pgap = $36                      ; their gaps
pdone = $3a                     ; scored
newcol = $3e                    ; 20 chars: the next right-hand column
bcol = $52                      ; bird block on show: column, row
brow = $53
bset = $54                      ; character set on show (0/1)
bsave = $55                     ; 9 chars under the block
ncol = $5e                      ; bird block for the next vblank
nrow = $5f
nset = $60
nsave = $61                     ; 9
nvalid = $6a                    ; 1: a new block is waiting for the vblank
bshift = $6b                    ; image shift 0-3 (multicolour pixels)
bys = $6c                       ; image's row within the block's top row
cell = $6e
skey = $6f                      ; s key held last tick
pt = $80                        ; pointers ($70-$7f: the music player)
pt2 = $82
pt3 = $84
tmp = $86
tmp2 = $87
tmp3 = $88
mdue = $89                      ; 1: the tick wants a music step
sbcell = $8a                    ; bar: the cell the last fill ended in
spc = $8b                       ; 1: space held (start key)
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: non-zero plays by itself

*=$e000
        incasm "modhead.asm"
        incasm "chars.asm"

*=$e400

; ------------------------------------------------------------
; init  set up screen and sound; called once
;   in:   screen off, loader interrupt running
; ------------------------------------------------------------
init    jsr gk_musinit          ; before the bird's characters (2-3) are
        lda #0                  ; drawn over the header
        sta $d015
        sta dbg_auto
        lda #$0b
        sta $d011
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc                ; vic bank 3
        sta $dd00
        lda #0
        sta $d020
        sta $d023               ; black outlines
        lda #col_sky
        sta $d021
        lda #col_white
        sta $d022               ; white highlights
        lda #0
        sta bestl
        sta besth
        sta exitreq
        sta mdue
        sta spc
        sta dbg_space
        sta front
        sta nfront
        lda #6
        sta ntscc
        lda #$a7
        sta rnd
        sta rnd+1
        jsr sidinit
        jsr musicgo
        jsr drawall
        lda #$ff
        sta smode
        lda #64                 ; the bird's first block, in buffer a
        sta byh
        lda #7
        sta xs
        lda #1
        sta bset                ; so the first one drawn is set 0
        lda #1
        sta bfrm
        jsr birdpos
        jsr adopt
        jmp newround

; ------------------------------------------------------------
; stop  silence; the core blanks the screen after
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
@s      lda #0
        sta $d418
        sta $d404
        sta $d40b
        sta $d412
        rts

; ------------------------------------------------------------
; frame  one frame: status split, vblank, one tick
;   out:  carry set when the player has chosen to go on (only
;         asked for once ld_state bit 7 says the load is done)
; ------------------------------------------------------------
frame
@w1     lda $d012               ; status split, lines 222-250
        cmp #222
        bcc @w1
        cmp #251
        bcs @w1
        lda #$10                ; no scroll, multicolour, 38 columns
        sta $d016
        lda #0
        sta $d021
        lda mdue                ; the music here, in the wait for the
        beq @w2                 ; vblank, not in the tick's time
        lda #0
        sta mdue
        jsr mplay
@w2     bit $d011               ; vertical blank: line 251 on
        bmi @vb
        lda $d012
        cmp #222                ; above the split: the music ran on into the
        bcc @vb                 ; next frame (NTSC's 263 lines): its vertical
        cmp #251                ; blank work at once, not a frame later with
        bcc @w2                 ; the split's colours (MODULES.md: still recover)
@vb     lda v_d016
        sta $d016
        lda v_d021
        sta $d021
        jsr show
        lda #$1b
        sta $d011
        lda ld_state
        lsr a
        bcc @tick               ; pal: every frame
        dec ntscc
        bne @tick
        lda #6
        sta ntscc
        bne @held               ; ntsc: hold every sixth
@tick   jsr tick
@held   jsr status
        lda exitreq
        cmp #1
        rts

; ------------------------------------------------------------
; show  (vertical blank) the staged buffer and bird block
;   uses: a, x, y, pt, pt3
; ------------------------------------------------------------
show    lda nvalid
        beq @d18
        jsr unplace             ; the old block out of the old buffer
        lda nfront
        sta front
        jsr adopt               ; the new one into the new buffer
@d18    lda front
        beq @a
        lda #d018b
        bne @b
@a      lda #d018a
@b      sta $d018
        rts

; staged block -> on show
adopt   lda ncol
        sta bcol
        lda nrow
        sta brow
        lda nset
        sta bset
        ldx #8
@c      lda nsave,x
        sta bsave,x
        dex
        bpl @c
        lda #0
        sta nvalid
        ; fall through

; ------------------------------------------------------------
; place  bird characters into the buffer on show; cells over sky
;        yellow, over anything else they keep their green
; unplace  the saved characters back, cells green
;   uses: a, x, y, pt, pt3, tmp
; ------------------------------------------------------------
place   jsr blockptr
        lda #bset0
        ldx bset
        beq @s
        lda #bset1
@s      sta tmp
        ldx #0
@p      ldy cellofs,x
        lda bsave,x
        cmp #c_sky
        bne @g
        lda #col_bird
        bne @c
@g      lda #col_green
@c      sta (pt3),y
        lda cellchr,x           ; numbered down the columns
        clc
        adc tmp
        sta (pt),y
        inx
        cpx #9
        bne @p
        rts

unplace jsr blockptr
        ldx #0
@u      ldy cellofs,x
        lda bsave,x
        sta (pt),y
        lda #col_green
        sta (pt3),y
        inx
        cpx #9
        bne @u
        rts

; pt = the block's top left in the buffer on show, pt3 = colour ram
blockptr
        ldx brow
        lda rowlo,x
        clc
        adc bcol
        sta pt
        sta pt3
        lda rowhi,x
        adc #0
        sta pt3+1
        ora #$d8
        sta pt3+1
        lda pt3+1
        and #3
        ldx front
        ora scrhi,x
        sta pt+1
        rts

; ------------------------------------------------------------
; birdpos  stage the bird's block for the next vblank: where it
; goes in the buffer that will be on show, what is under it, and
; its characters drawn in the set not on show
;   in:   byh, bfrm, xs, nfront (as they will be at the vblank)
;   uses: a, x, y, pt, pt2, tmp-tmp3
; ------------------------------------------------------------
birdpos lda #birdx              ; x in the buffer: always even, as xs
        sec                     ; is odd, so whole multicolour pixels
        sbc xs
        tax
        lsr a
        lsr a
        lsr a
        sta ncol
        txa
        and #7
        lsr a
        sta bshift
        lda byh
        and #7
        sta bys
        lda byh
        lsr a
        lsr a
        lsr a
        sta nrow
        tax                     ; pt = top left in buffer nfront
        lda rowlo,x
        clc
        adc ncol
        sta pt
        lda rowhi,x
        adc #0
        ldx nfront
        ora scrhi,x
        sta pt+1
        ldx #0
@g      ldy cellofs,x
        lda (pt),y
        cmp #bset0              ; a bird character: this buffer is on
        bcc @k                  ; show and the block overlaps itself;
        cmp #bset1+9            ; what is under it is in bsave
        bcs @k
        lda nrow
        clc
        adc celly3,x
        sec
        sbc brow
        sta tmp                 ; row in the old block
        asl a
        adc tmp                 ; x3
        adc ncol
        adc cellx,x
        sec
        sbc bcol
        tay
        lda bsave,y
@k      sta nsave,x
        inx
        cpx #9
        bne @g
        lda bset
        eor #1
        sta nset
        jsr render
        lda #1
        sta nvalid
        rts

; ------------------------------------------------------------
; render  the bird into the 9 characters of set nset. They are
; numbered down the columns (cellchr), so each column's three
; glyphs are 24 bytes in a row: copy the glyphs under the block in,
; then lay the image's 11 rows over each column from its row bys.
;   in:   nsave, nset, bfrm, bshift, bys
;   uses: a, x, y, pt, pt2, pt3, tmp, tmp2, cell
; ------------------------------------------------------------
render  ldx nset                ; pt2 = the set's first glyph
        lda setlo,x
        sta pt2
        lda #>chrset
        sta pt2+1
        ldx #8                  ; x = cell, down the columns
@cell   ldy cellchr,x           ; (the transpose: its nsave index)
        lda nsave,y
        ldy x8p7,x              ; y = the cell's last byte in the set
        cmp #c_sky
        bne @copy
        lda #0                  ; sky: blank
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        dey
        sta (pt2),y
        jmp @next
@copy   sta tmp                 ; pt = glyph - 8 x cell, so that
        lsr a                   ; (pt),y reads it with the same y
        lsr a
        lsr a
        lsr a
        lsr a
        ora #>chrset
        sta pt+1
        lda tmp
        asl a
        asl a
        asl a
        sec
        sbc x8,x
        sta pt
        bcs @c8
        dec pt+1
@c8     lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
        dey
        lda (pt),y
        sta (pt2),y
@next   dex
        bpl @cell
        lda bfrm                ; pt3 = the image's first column, less
        asl a                   ; bys: y = bys + row reads both
        asl a
        adc bshift              ; (carry clear: bfrm x 4 < 12)
        tax
        lda imglo,x
        sec
        sbc bys
        sta pt3
        lda imghi,x
        sbc #0
        sta pt3+1
        lda bys
        clc
        adc #bird_h
        sta tmp                 ; y's end
        lda #3
        sta cell                ; columns to go
@col    ldy bys
@row    lda (pt3),y
        beq @nx                 ; nothing drawn in this byte
        sta tmp2
        tax
        lda (pt2),y
        and invmask,x
        ora tmp2
        sta (pt2),y
@nx     iny
        cpy tmp
        bne @row
        dec cell
        beq @x
        lda pt2                 ; next column: glyphs +24, image +11
        clc
        adc #24
        sta pt2
        lda pt3
        clc
        adc #bird_h
        sta pt3
        bcc @col
        inc pt3+1
        bne @col
@x      rts


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
        lda musicon             ; a music step at the next split (so
        sta mdue                ; at the tick's rate: 5 in 6 on ntsc)
        lda #col_sky
        ldx flash
        beq @nf
        dec flash
        lda #col_white
@nf     sta v_d021
        lda st
        cmp #st_play
        bne @n1
        jmp t_play
@n1     cmp #st_dead
        bne @n2
        jmp t_dead
@n2     cmp #st_over
        bne t_title
        jmp t_over

; ---- get ready: the bird bobs, fire starts; once the program is
; in, a player who hasn't started gets it straight away ----
t_title bit ld_state
        bpl @wait
        lda #1
        sta exitreq
        jmp birdpos
@wait   lda frm
        lsr a
        lsr a
        and #15
        tax
        lda bob,x
        clc
        adc #64
        sta byh
        jsr wings
        lda fpress              ; fire plays
        bne @go
        jmp birdpos
@go     lda #st_play
        sta st
        lda #0
        sta tmr
        sta copyrow             ; build the hidden buffer from now on
        ldx #txr1               ; messages away (early: before the beam)
        jsr clearspan
        ldx #txr2
        jsr clearspan
        ldx #txr3
        jsr clearspan
        jsr flap
        jmp birdpos

; ---- playing ----
t_play  lda fpress
        beq @nf
        jsr flap
@nf     jsr fall
        lda byh
        cmp #groundy-hity1
        bcc @air
        jmp die
@air    jsr scroll
        jsr pipes
        jsr wings
        jmp birdpos

; ---- hit: fall to the ground ----
t_dead  jsr fall
        lda #2
        sta bfrm
        lda byh
        cmp #birdmax
        bcc @s
        lda #birdmax
        sta byh
        lda #st_over
        sta st
        lda #0
        sta tmr
        ldx #<tx_over           ; the messages, over whatever is there
        ldy #>tx_over
        lda #txr1
        jsr span
@s      jmp birdpos

; ---- game over: once loaded, the program starts; before, a
; lockout, then fire plays again ----
t_over  bit ld_state
        bpl @nl
        lda #1
        sta exitreq
        jmp birdpos
@nl     lda tmr
        cmp #lockout
        bcc @x
        bne @ready
        ldx #<tx_again          ; once: "press fire"
        ldy #>tx_again
        lda #txr3
        jsr span
@ready  lda fpress
        bne @again
@x      jmp birdpos
@again  jmp newround

; debug: flap when below the middle of the next gap; once the
; program is loaded, stop flapping so the round ends
;   out:  a = 0 to flap (as if held), $10 not
autopilot
        lda st
        cmp #st_play
        beq @play
        lda frm                 ; title, game over: press now and then
        and #16
        rts
@play   bit ld_state
        bmi @no
        lda #$ff
        sta tmp                 ; nearest pipe still ahead
        ldx #$ff
        ldy #3
@f      lda pc4,y
        cmp #10
        bcc @n
        cmp tmp
        bcs @n
        sta tmp
        lda pgap,y
        tax
@n      dey
        bpl @f
        txa
        bmi @mid
        asl a
        asl a
        asl a
        clc
        adc #(gaprows*8-hity1-hity0)/2
        bne @c
@mid    lda #72
@c      cmp byh
        bcs @no                 ; above the target: let it fall
        lda vyh
        bmi @no                 ; rising already
        lda #0                  ; held
        rts
@no     lda #$10
        rts

; ------------------------------------------------------------
; flap / fall / die
; ------------------------------------------------------------
flap    lda #flaplo
        sta vyl
        lda #flaphi
        sta vyh
        jmp sfxflap

fall    lda vyl
        clc
        adc #grav
        sta vyl
        lda vyh
        adc #0
        bmi @st                 ; rising: no cap
        cmp #maxfall
        bcc @st
        lda #0
        sta vyl
        lda #maxfall
@st     sta vyh
        lda byl
        clc
        adc vyl
        sta byl
        lda byh
        adc vyh
        ldx vyh
        bpl @ok
        bcs @ok                 ; rising, still on screen
        lda #0                  ; at the top: stop there
        sta byl
        sta vyl
        sta vyh
@ok     sta byh
        rts

die     lda #st_dead
        sta st
        lda #0
        sta tmr
        sta vyl
        sta vyh
        lda #3
        sta flash
        jsr sfxhit
        lda sch                 ; best score
        cmp besth
        bcc @x
        bne @new
        lda scl
        cmp bestl
        bcc @x
@new    lda scl
        sta bestl
        lda sch
        sta besth
        jsr drawscore
@x      jmp birdpos

; wings: a frame every 4 ticks, up-mid-down-mid
wings   lda frm
        lsr a
        lsr a
        and #3
        tax
        lda wingseq,x
        sta bfrm
        rts

; ------------------------------------------------------------
; scroll  move the play field 2 px; at a whole character swap
; the buffers and start building the next one
; ------------------------------------------------------------
scroll  lda xs
        sec
        sbc #2
        bpl @nos
        clc
        adc #8
        sta xs
        jsr swap
        jmp @st
@nos    sta xs
@st     lda xs
        ora #$10
        sta v_d016
        jmp build

; the new character column is already in the back buffer
swap    lda front
        eor #1
        sta nfront
        ldx #3                  ; pipes move one column left
@p      lda pc4,x
        bmi @n
        sec
        sbc #1
        bcs @k
        lda #$ff                ; gone off the left
@k      sta pc4,x
@n      dex
        bpl @p
        lda pend                ; a pipe entering on the right
        bmi @np
        ldx #3
@f      lda pc4,x
        bmi @put
        dex
        bpl @f
        bmi @np
@put    lda #43
        sta pc4,x
        lda pend
        sta pgap,x
        lda #0
        sta pdone,x
        lda #$ff
        sta pend
@np     jsr gencol
        lda #$ff
        sta copyrow
        rts

; ------------------------------------------------------------
; build  copy half of the play field into the back buffer, one
; character left (the bird's characters swapped for what is
; under them); then the new column. Never the buffer on show.
; ------------------------------------------------------------
build   lda copyrow
        cmp #$ff
        bne @go
        lda #0                  ; the swap shows at the next vblank:
        sta copyrow             ; start after it
        rts
@go     cmp #20
        bcs @col
        sta tmp                 ; band start: 0, 7 or 14
        ldx #0                  ; x = band + 3 if b is on show
        cmp #7
        bcc @b
        inx
        cmp #14
        bcc @b
        inx
@b      lda bandend,x
        sta copyrow
        lda front
        beq @a
        inx
        inx
        inx
@a      lda cplo,x
        sta @j+1
        lda cphi,x
        sta @j+2
@j      jsr $ffff               ; the band, one run (birdgfx.asm)
        ldx #0                  ; the bird's rows in it: what is under
@bird   txa                     ; them, one character to the left
        clc
        adc brow
        cmp tmp
        bcc @nb
        cmp copyrow
        bcs @nb
        tay
        lda rowlo,y
        sta pt2
        lda rowhi,y
        ldy front
        clc
        adc scrhi,y
        eor #$0c                ; screen a <-> b: the back buffer
        sta pt2+1
        stx tmp2
        txa
        asl a
        adc tmp2                ; x3: the row's first bsave cell
        tax
        ldy bcol
        dey                     ; one to the left in the copy
        lda bsave,x
        sta (pt2),y
        iny
        lda bsave+1,x
        sta (pt2),y
        iny
        lda bsave+2,x
        sta (pt2),y
        ldx tmp2
@nb     inx
        cpx #3
        bne @bird
        lda copyrow
        cmp #20                 ; the last band: the column too, before
        beq @col                ; the swap that the next tick may make
        rts
@col    bne @x                  ; 21: done
        lda #21
        sta copyrow
        ldy front               ; the back buffer's column 39
        lda scrhi,y
        eor #$0c                ; screen a <-> b
        sta pt+1
        lda #39
        sta pt
        ldx #0
@c      ldy #0
        lda newcol,x
        sta (pt),y
        lda pt
        clc
        adc #40
        sta pt
        bcc @nc
        inc pt+1
@nc     inx
        cpx #20
        bne @c
@x      rts

; ------------------------------------------------------------
; gencol  the next column of pipe or sky into newcol
; ------------------------------------------------------------
gencol  lda gk
        cmp #4
        bcc @pipe
        ldx #19
        lda #c_sky
@s      sta newcol,x
        dex
        bpl @s
        jmp @count
@pipe   sta tmp                 ; column 0-3 of the pipe
        cmp #0                  ; (a store sets no flags)
        bne @nr
        lda ggap
        sta pend                ; registers at the next swap
@nr     ldx #0
@r      txa                     ; row - (gap - 2): 0-9 near the gap
        sec
        sbc ggap
        clc
        adc #2
        cmp #gaprows+4
        bcs @body
        tay
        lda gapchars,y
        cmp #c_sky
        beq @put
        bne @add
@body   lda #c_body
@add    clc
        adc tmp
@put    sta newcol,x
        inx
        cpx #20
        bne @r
        inc gk
@count  dec gcount
        bne @x
        lda #pipeevery
        sta gcount
        lda #0
        sta gk
        jsr random
        and #7
        clc
        adc #4                  ; gap top row 4-11
        sta ggap
@x      rts

; chars from two rows above the gap to two below, as offsets
gapchars
        byte c_capt,c_capb,c_sky,c_sky,c_sky,c_sky,c_sky,c_sky,c_capt,c_capb

; ------------------------------------------------------------
; pipes  collisions and scoring against the pipes on show
; ------------------------------------------------------------
pipes   ldx #3
@p      lda pc4,x
        cmp #25
        bcs @n                  ; far right (or empty)
        asl a
        asl a
        asl a
        clc
        adc xs                  ; screen x + 32 of the pipe
        cmp #birdx+hitx1+32-4   ; body starts 4 px in
        bcs @n
        cmp #birdx+hitx0+32-28+1
        bcc @past
        lda pgap,x              ; level with it: in the gap?
        asl a
        asl a
        asl a
        sec
        sbc #hity0
        bcc @hit
        cmp byh
        beq @in                 ; level with the edge: not a hit
        bcs @hit                ; head above the gap
@in     clc
        adc #gaprows*8-hity1+hity0
        cmp byh
        bcc @hit                ; feet below it
        bcs @n
@past   lda pdone,x
        bne @n
        inc pdone,x
        jsr addpoint
@n      dex
        bpl @p
        rts
@hit    pla                     ; leave t_play: die
        pla
        jmp die

addpoint
        txa                     ; score + 1 in bcd, without decimal mode
        pha                     ; (the loader's interrupt doesn't cld)
        inc scl
        lda scl
        and #15
        cmp #10
        bcc @d
        lda scl
        adc #5                  ; (carry set: + 6) the next ten
        sta scl
        cmp #$a0
        bcc @d
        lda #0
        sta scl
        inc sch                 ; the hundreds
@d
        jsr sfxpoint
        jsr drawscore
        pla
        tax
        rts

; ------------------------------------------------------------
; newround  the title scene, drawn in the hidden buffer and shown
; at the next vblank
; ------------------------------------------------------------
newround
        lda #st_title
        sta st
        lda #0
        sta tmr
        sta scl
        sta sch
        sta flash
        sta vyl
        sta vyh
        sta byl
        lda #7
        sta xs
        lda #$17
        sta v_d016
        lda #col_sky
        sta v_d021
        lda #21
        sta copyrow
        lda #$ff
        sta pend
        sta pc4
        sta pc4+1
        sta pc4+2
        sta pc4+3
        lda #4
        sta gk
        lda #3
        sta gcount
        lda #8
        sta ggap
        jsr gencol
        jsr drawscore
        lda front               ; the hidden buffer: sky, messages
        eor #1
        sta nfront
        tax
        lda scrhi,x
        sta pt+1
        lda #0
        sta pt
        ldx #20                 ; rows 0-19: 800 bytes
        ldy #0
        lda #c_sky
@c      sta (pt),y
        iny
        cpy #40
        bne @c
        ldy #0
        lda pt
        clc
        adc #40
        sta pt
        bcc @n
        inc pt+1
@n      lda #c_sky
        dex
        bne @c
        ldx #<tx_title
        ldy #>tx_title
        lda #txr1
        jsr span
        ldx #<tx_ready
        ldy #>tx_ready
        lda #txr2
        jsr span
        ldx #<tx_again
        ldy #>tx_again
        lda #txr3
        jsr span
        lda #64
        sta byh
        jsr wings
        jmp birdpos

; ------------------------------------------------------------
; drawall  both screens and colour ram from scratch (screen off)
; ------------------------------------------------------------
drawall ldx #0
@sky    lda #c_sky
        sta scra,x
        sta scra+$100,x
        sta scra+$200,x
        sta scrb,x
        sta scrb+$100,x
        sta scrb+$200,x
        lda #col_green
        sta $d800,x
        sta $d900,x
        sta $da00,x
        inx
        bne @sky
        ldx #0
@low    lda #c_sky              ; to $..e7: rows 19.2-24
        sta scra+$300,x
        sta scrb+$300,x
        lda #col_green
        sta $db00,x
        inx
        cpx #$e8
        bne @low
        ldx #39
@g      lda #c_grass
        sta scra+800,x
        sta scrb+800,x
        lda #c_dirt
        sta scra+840,x
        sta scrb+840,x
        lda #c_dirte
        sta scra+880,x
        sta scrb+880,x
        lda #col_yellow+8
        sta $d800+840,x
        sta $d800+880,x
        lda #col_text
        sta $d800+920,x
        sta $d800+960,x
        dex
        bpl @g
        lda #$ff
        sta smode
        rts

; ------------------------------------------------------------
; span  a message, centred in its 12-cell span, hi-res white: only
;       the text's own cells change, so a pipe beside it stays whole.
;       Into the buffer on show and the one to be shown next (nfront),
;       early in a tick (before the beam reaches the row).
;   in:   x/y = text (length first), a = row
; clearspan  span x back to sky, multicolour green
; ------------------------------------------------------------
span    stx pt2
        sty pt2+1
        tax
        ldy #0
        lda (pt2),y             ; length
        beq @x
        sta tmp
        lda #txw                ; centred
        sec
        sbc tmp
        lsr a
        clc
        adc #txcol
        adc rowlo,x
        sta tmp3                ; offset of the text's first cell
        sta pt3
        lda rowhi,x
        adc #0
        sta tmp2
        ora #$d8
        sta pt3+1
        ldy tmp                 ; hi-res white
        dey
        lda #col_text
@s      sta (pt3),y
        dey
        bpl @s
        ldx front               ; the buffer on show
        jsr @one
        ldx nfront              ; and the next one, if another
        cpx front
        beq @x
@one    lda tmp3
        sta pt
        lda tmp2
        ora scrhi,x
        sta pt+1
        ldy #0
@t      iny
        lda (pt2),y
        dey
        sta (pt),y
        iny
        cpy tmp
        bne @t
@x      rts

clearspan
        lda rowlo,x
        clc
        adc #txcol
        sta pt
        sta pt3
        lda rowhi,x
        adc #0
        sta tmp2
        ora #$d8
        sta pt3+1
        lda tmp2
        ora #>scra
        sta pt+1
        ldy #txw-1
@c      lda #c_sky
        sta (pt),y
        lda pt+1
        eor #$0c                ; screen a <-> b
        sta pt+1
        lda #c_sky
        sta (pt),y
        lda #col_green
        sta (pt3),y
        dey
        bpl @c
        rts

; ------------------------------------------------------------
; drawscore  row 23: "SCORE nnn" left, "BEST nnn" right, both
; buffers (cells already hi-res white)
; ------------------------------------------------------------
drawscore
        ldx #0
@a      lda tx_score+1,x
        sta scra+920+2,x
        sta scrb+920+2,x
        inx
        cpx #5
        bne @a
        ldx #0
@b      lda tx_best+1,x
        sta scra+920+28,x
        sta scrb+920+28,x
        inx
        cpx #4
        bne @b
        lda scl
        ldy sch
        ldx #8
        jsr bcd3
        lda bestl
        ldy besth
        ldx #33
        ; fall through

; three digits of bcd y:a at row 23, column x (no leading zeros)
bcd3    sta tmp
        sty tmp2
        lda #0
        sta pt                  ; non-zero once a digit was put
        lda tmp2
        and #15
        jsr @dig
        lda tmp
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @dig
        lda #1
        sta pt                  ; the last digit always
        lda tmp
        and #15
@dig    cmp #0
        bne @put
        ldy pt
        bne @put
        lda #c_sky              ; leading zero: blank
        bne @w
@put    ldy #1
        sty pt
        ora #$30
@w      sta scra+920,x
        sta scrb+920,x
        inx
        rts

; effects: a = 1 flap, 2 point, 3 hit; a lower one doesn't cut a
; higher one short
sfxflap lda #1
        bne sfxgo
sfxpoint
        lda #2
        bne sfxgo
sfxhit  lda #3
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
        lda sfxad-1,x
        sta $d413
        lda sfxlen-1,x
        sta sfxtime
        lda sfxwave-1,x
        sta $d412
@x      rts

sfxhi   byte $30,$45,$06
sfxad   byte $08,$09,$0a
sfxlen  byte 3,6,4
sfxwave byte $81,$41,$81

; gate off when the effect's time is up; the point sound steps up
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
        cmp #2
        bne @x
        lda sfxtime
        cmp #3
        bne @x
        lda #$5c
        sta $d40f
        rts

; ---- tables ----
bob     byte 0,1,2,3,3,4,4,4,4,4,3,3,2,1,0,0
wingseq byte 0,1,2,1
scrhi   byte >scra,>scrb
rowlo   byte <0,<40,<80,<120,<160,<200,<240,<280,<320,<360,<400,<440,<480
        byte <520,<560,<600,<640,<680,<720,<760,<800,<840,<880,<920,<960
rowhi   byte >0,>40,>80,>120,>160,>200,>240,>280,>320,>360,>400,>440,>480
        byte >520,>560,>600,>640,>680,>720,>760,>800,>840,>880,>920,>960
cellofs byte 0,1,2,40,41,42,80,81,82
cellx   byte 0,1,2,0,1,2,0,1,2
celly3  byte 0,0,0,1,1,1,2,2,2
bandend byte 7,14,20
cplo    byte <cpa0,<cpa1,<cpa2,<cpb0,<cpb1,<cpb2
cphi    byte >cpa0,>cpa1,>cpa2,>cpb0,>cpb1,>cpb2
cellchr byte 0,3,6,1,4,7,2,5,8    ; cell (row by row) -> character (down the columns), and back
x8      byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152
x8p7    byte 7,15,23,31,39,47,55,63,71
setlo   byte <chrset+bset0*8,<chrset+bset1*8   ; (both in page >chrset)
imglo   byte <birdimg,<birdimg+33,<birdimg+66,<birdimg+99
        byte <birdimg+132,<birdimg+165,<birdimg+198,<birdimg+231
        byte <birdimg+264,<birdimg+297,<birdimg+330,<birdimg+363
imghi   byte >birdimg,>birdimg+33,>birdimg+66,>birdimg+99
        byte >birdimg+132,>birdimg+165,>birdimg+198,>birdimg+231
        byte >birdimg+264,>birdimg+297,>birdimg+330,>birdimg+363

        incasm "modkit.asm"
        incasm "tables.asm"
c_space = c_sky
codeend
        incasm "birdgfx.asm"
