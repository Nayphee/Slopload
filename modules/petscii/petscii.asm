; ------------------------------------------------------------
; petscii.asm  -  PETSCII-Load: a PETSCII screen while the program
; loads. Not a game: a module for the game mode, like OZ GOLD, that
; shows a screen drawn in Petmate or Marq's PETSCII editor, plays the
; music the tool chose, and starts the program once it is in: the
; counter at 000 and the music faded out (about 2.6 seconds, fstep;
; 1.3 with no music).
; Two things can go on the screen as well:
;   a scrolling message   on one row, smooth (1-4 pixels a frame), in
;                         that row's colours from the screen
;   a block counter       three digits counting the program's disk
;                         blocks down to 000 as it loads (U.S. Gold's
;                         Novaload had one), in the screen's colours
;
; This source shows the demo screen (demo.pet, with the settings in
; mkdata.py). tools/petscii.py (and the PC tool's -module screen.pet) and
; PETSCII-LM on the C64 make the same module with another screen and
; settings, writing them into fixed places:
;   the second part ($bc00)  the 1,000 screen codes
;   the main part   +32      border, background, $d018 ($f4 upper
;                            case, $f6 lower case), flags (bit 0 the
;                            counter, bit 1 the scroller)
;                   +36      the 1,000 colours
;                   +1036    the scroller's row, its pixels a frame,
;                            the counter's place (a word: row x 40 +
;                            column), the message's length (a word),
;                            the space's code (the scroller's row is
;                            cleared with it) and the digit 0's (the
;                            counter's 0-9 follow it)
;                   the end  the message (screen codes), after the code
; and the header's claim (+10) and cpu share (+14: 35 with a scroller,
; whose split needs more of each frame).
;
; The screen uses the C64's own character set, which the VIC sees in
; banks 0 and 2 only, so it is at $bc00 in bank 2; $01 is the
; loader's (only the fade banks the I/O out, once the tape has stopped).
; A font of its own is a third part the tools add: only the characters
; the module shows, numbered from 0 (the screen's, the message's, the
; space and the digits as they are used), at $b800 ($d018 $fe) for 128
; or fewer, else at $b000 ($fc); the codes, the message, the space and
; the digit 0 renumbered to match.
; A tape error turns the border red (white if it is red) until
; the loader recovers.
;
; The scroller's split: $d016 (40 columns and the fine scroll) is
; written for its row when the beam is in the row above (line 43 +
; 8 x row on), and $08 again when it is in the row below (59 + 8 x row
; on): a write the loader's interrupt holds up a few lines still lands
; in that row, which must be empty (the tools clear it). Row 0 is set in
; the vertical blank, row 24 put back there. 40 columns, not 38: the
; side borders never move (38 would move them on whichever line the
; write lands); the row's column 0 has the background's colour, so the
; message leaves there unseen. The music goes where the
; frame has the most time: before the split for a row low on the
; screen, after it for a row near the top.
;
; The fade is the kit's (src/fadekit.asm, OZ GOLD's too).
;
; Memory: $bc00-$bfe7 and $e000 to modend (and the font's part, if
; there is one: $b000 or $b800 on). Zero page $10-$2f. In a chain
; (slopload.py -then, petscii.py -chain) the main part is at $a000
; (petbase), clear of a picture module's $c000-$ffbf.
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
petbase = $e000                 ; the main part (tools/petscii.py: $a000 in a chain,
                                ; clear of a picture's $c000-$ffbf)
scr = $bc00                     ; the screen: vic bank 2, beside the rom font
lowat = scr                     ; (its part: the chain's build, at $a000, puts a
                                ; copy lower, to assemble in order, and keeps $bc00's)
scra = scr                      ; (the kit's names for it)
scrb = scr

; ---- the standard parts (g_share: colours.asm, as the settings) ----
g_claim = modend                ; end of the memory claimed
g_jitter = 49                   ; measured: tests/jitter.py --module petscii (48)
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 0                       ; no sound effects: the music keeps all three voices
g_wait = 1                      ; with -wait it holds at 000 until SPACE (then the fade)
g_count = 0                     ; (no status line: its own counter, always)
gk_barhalf = 0                  ; (the kit's status line: not used)
gk_srow = 24*40

; ---- zero page ($10-$8f; $70-$7f is the music's) ----
frm = $10                       ; tick counter (kit)
ntscc = $11                     ; ntsc: 5 ticks in 6 frames
fire = $12                      ; (kit)
fpress = $13                    ; (kit)
spc = $14                       ; (kit)
skey = $15                      ; (kit) s held
exitreq = $16                   ; (kit) 1: start the program
smode = $17                     ; (kit)
sprog = $18                     ; (kit)
musicon = $19                   ; (kit) 1: music playing
rnd = $1a                       ; (kit) 2 bytes
tmp = $1c                       ; (kit) scratch
tmp2 = $1d
tmp3 = $1e
pt2 = $1f                       ; (kit) 2
sbcell = $21                    ; (kit)
errcol = $22                    ; the border during a tape error
xs = $23                        ; the scroller's fine scroll (7-0)
mptr = $24                      ; the message's next character (2)
mend = $26                      ; ... its end (2)
rowp = $28                      ; the scroller's row on screen (2)
cntp = $2a                      ; the counter's first digit (2)
l1 = $2c                        ; the line the scroll is set from
l2 = $2d                        ; ... and put back from
slotc = $2e                     ; 1: the music after the split
shown = $2f                     ; the blocks on the counter ($ff: none yet)
dbg_space = $8e                 ; debug: (no use here: the program starts by itself)
dbg_auto = $8f

; ---- characters (the kit's names: its status line isn't used) ----
c_space = $20
c_digit0 = $30
c_bar = $20
c_barl = $20
c_barr = $20
c_pct = $25

; ------------------------------------------------------------
; the second part: the screen, where the vic shows it
; ------------------------------------------------------------
*=lowat
lowpart
        incasm "screen.asm"
lowend

*=petbase
mainpart
        incasm "modhead.asm"
*=petbase+32                    ; (the header is 32 bytes)
        incasm "colours.asm"    ; +32 the settings, +36 the colours, +1036 the rest

; ------------------------------------------------------------
; init  once, the screen off: vic bank 2, the colours, the scroller
; and the counter, the music
; ------------------------------------------------------------
init    jsr gk_musinit          ; the header's music (the tool's choice)
        lda #$0b
        sta $d011               ; (screen off: frame turns it on)
        ldx #$1f                ; zero page $10-$2f clear
        lda #0
@z      sta $10,x
        dex
        bpl @z
        sta $d015               ; no sprites
        sta dbg_space
        sta dbg_auto
        lda pborder
        and #15
        jsr gk_bord
        lda #2                  ; a tape error: red, or white on a red border
        cmp $d020
        bne @e
        lda #1
@e      sta errcol
        lda pbg
        sta $d021
        lda #6
        sta ntscc
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        ora #1                  ; vic bank 2: $8000-$bfff, the rom font at $9000
        sta $dd00
        lda pd018
        sta $d018
        lda #$08
        sta $d016               ; hi-res, 40 columns
        ldx #0                  ; the colours
@c      lda coldata,x
        sta $d800,x
        lda coldata+$100,x
        sta $d900,x
        lda coldata+$200,x
        sta $da00,x
        lda coldata+$2e8,x
        sta $dae8,x
        inx
        bne @c
        lda #$ff
        sta shown
        lda pflags
        and #2
        beq @ns
        jsr scrinit
@ns     lda pflags
        lsr a
        bcc @nc
        lda pcount              ; the counter: its place, the count now
        sta cntp
        lda pcount+1
        clc
        adc #>scr
        sta cntp+1
        jsr count
@nc     jsr sidinit
        jmp musicgo

; scrinit  the scroller: its row's address and lines, the music's slot,
; the row emptied, the message from its start
scrinit lda prow                ; 8 x row
        asl a
        asl a
        asl a
        sta tmp
        clc
        adc #43                 ; the row above's first line
        sta l1
        adc #16                 ; (no carry: 235 at most) the row below's
        sta l2
        lda #0                  ; 40 x row = 32 x row + 8 x row
        sta rowp+1
        lda tmp
        asl a
        rol rowp+1
        asl a
        rol rowp+1
        clc
        adc tmp
        sta rowp
        lda rowp+1
        adc #>scr
        sta rowp+1
        ldx #6                  ; the music: after the split for a row
        lda ld_state            ; above this one (8 on ntsc), else before
        lsr a
        bcc @p
        ldx #8
@p      stx tmp
        lda prow
        cmp tmp
        lda #0
        rol a                   ; (c: row >= the slot's row)
        eor #1
        sta slotc
        lda pspace              ; the row empty: the message comes in
        ldy #39                 ; from the right
@cl     sta (rowp),y
        dey
        bpl @cl
        lda rowp                ; its column 0 in the background's colour:
        sta pt2                 ; the message leaves there a character at a
        lda rowp+1              ; time, unseen (40 columns kept: the side
        sec                     ; borders never change while it scrolls,
        sbc #>scr               ; where 38 would, on a line the loader's
        clc                     ; interrupts move)
        adc #$d8
        sta pt2+1
        lda pbg
        ldy #0
        sta (pt2),y
        lda #7
        sta xs
        lda #<msgdata
        sta mptr
        clc
        adc pmsglen
        sta mend
        lda #>msgdata
        sta mptr+1
        adc pmsglen+1
        sta mend+1
        rts

; ------------------------------------------------------------
; stop  silence; 40 columns again; the core blanks the screen after.
; With -autorun the load has only just ended and the counter isn't at
; 000 yet: two frames more first
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
        lda #0
        sta musicon
@s      lda #0
        sta $d418
        lda pflags              ; a counter not at 000 yet (-autorun: the
        lsr a                   ; load has only just ended): two frames
        bcc @v                  ; more, no music, the second showing 000
        lda shown               ; whole
        beq @v
        jsr frame
        jsr frame
@v      jsr vbwait              ; then, in the vertical blank (no tear in
        lda #$08                ; the scroller's row): 40 columns, no scroll
        sta $d016
        rts

; ------------------------------------------------------------
; frame  one frame: the vertical blank (once a frame): the border,
; the scroller's step, the counter; the split; the music (a tick, 5 in
; 6 frames on NTSC)
;   out:  carry set when the program should start
; ------------------------------------------------------------
frame   jsr vbwait
@vb     lda #$1b                ; screen on, 25 rows
        sta $d011
        lda #$20                ; (the loader's: -showstripes)
        bit ld_state
        bne @nb
        lda pborder             ; the border: the screen's, or the error's,
        bit ld_state            ; written only when it changes (on a newer
        bvc @b                  ; VIC-II, 8565, a write to a colour register
        lda errcol              ; leaves a grey dot on the screen)
@b      tax
        eor $d020
        and #15
        beq @nb
        stx $d020
@nb
        lda pflags
        and #2
        beq @ns
        lda prow
        cmp #24
        bne @n24
        lda #$08                ; row 24: its scroll ends with the picture
@f24    sta $d016
@n24    jsr step
        lda prow
        bne @ns
        lda xs                  ; row 0: its scroll from here (40 columns)
        ora #$08
@f0     sta $d016
@ns     lda pflags
        lsr a
        bcc @nc
        jsr count
@nc     lda slotc
        bne @sp
        jsr tickt               ; the music here: before the split
@sp     lda pflags
        and #2
        beq @x
        lda prow
        beq @r                  ; (row 0: set already)
        lda l1
        jsr waitl
        lda xs                  ; the row's scroll, 40 columns
        ora #$08
@f1     sta $d016
@r      lda prow
        cmp #24
        beq @c                  ; (row 24: put back in the vertical blank)
        lda l2
        jsr waitl
        lda #$08                ; 40 columns, no scroll
@f2     sta $d016
@c      lda slotc
        beq @x
        jsr tickt               ; the music here: after the split
@x      lda exitreq
        cmp #1
        rts

; vbwait  the next vertical blank: the last one over (line 0-250), then
; line 251 on
;   uses: a
vbwait
@w0     lda $d012               ; the last vertical blank over (line 0-250):
        cmp #251                ; the low byte first, then bit 8 (read the
        bcs @w0                 ; other way round, line 255 then 256 looks
        bit $d011               ; like line 0)
        bmi @w0
@w      bit $d011               ; then this one: line 251 on
        bmi @x
        lda $d012
        cmp #251
        bcc @w
@x      rts

; waitl  until line a (0-250) of the picture: its low byte (a to 250:
; 251-255 are the vertical blank), then bit 8
waitl   sta tmp
@w      lda $d012
        cmp tmp
        bcc @w
        cmp #251
        bcs @w
        bit $d011
        bmi @w
        rts

; tickt  a tick, except every sixth frame on NTSC (the music at PAL speed)
tickt   lda ld_state
        lsr a
        bcc tick
        dec ntscc
        bne tick
        lda #6
        sta ntscc
        rts

; ------------------------------------------------------------
; tick  the music; once loaded, the fade (then the program starts).
; With -wait (header +28 bit 1) it holds at 000 first, the music on,
; until SPACE
; ------------------------------------------------------------
tick    inc frm
        bit ld_state
        bpl @p
        lda gk_opt
        and #2
        beq @f                  ; no -wait (or SPACE pressed): the fade
        jsr startkey            ; SPACE: exitreq
        lda exitreq
        bne @go
        jmp @p
@go     lda #0                  ; (exitreq is the fade's end)
        sta exitreq
        lda gk_opt                ; the hold over
        and #$fd
        sta gk_opt
@f      jmp fade
@p      jsr soundkey
        lda musicon
        beq @x
        jmp mplay
@x      rts

; the fade's scratch (fadekit.asm): the colours' bytes, in colour RAM
; since init
fsh = coldata                   ; (25) the tune's SID registers
fkn = coldata+32                ; (25) 1: written
fsv = coldata+64                ; (34) the RAM under $d400-$d41f; $d41b, $d41c

; ------------------------------------------------------------
; step  the scroller, a frame on: pspeed pixels; past a character, the
; row moved one left and the message's next character in at the right
;   uses: a, y
; ------------------------------------------------------------
step    lda xs
        sec
        sbc pspeed
        bcc @c
        sta xs
        rts
@c      adc #8                  ; (carry clear)
        sta xs
        ldy #1
@sh     lda (rowp),y
        dey
        sta (rowp),y
        iny
        iny
        cpy #40
        bne @sh
        ldy #0
        lda (mptr),y
        ldy #39
        sta (rowp),y
        inc mptr
        bne @e
        inc mptr+1
@e      lda mptr                ; past its end: from its start
        cmp mend
        lda mptr+1
        sbc mend+1
        bcc @x
        lda #<msgdata
        sta mptr
        lda #>msgdata
        sta mptr+1
@x      rts

; ------------------------------------------------------------
; count  the blocks left: the program's blocks (header +26) less its
; share loaded, 000 once it is in, or the progress at its top ($ff: in
; a chain, the next module's last page or two; the digits from pdigit0
; on)
;   uses: a, x, y, tmp, tmp2
; ------------------------------------------------------------
count   lda ld_state
        bmi @none
        lda ld_progress
        cmp #$ff
        beq @none
        lda hblocks
        bne @b
        lda #100                ; (no size in the header: 100 down)
@b      sta tmp
        lda ld_progress         ; blocks loaded = blocks x progress / 256
        sta tmp2
        lda #0
        ldx #8
        lsr tmp2
@m      bcc @s
        clc
        adc tmp
@s      ror a
        ror tmp2
        dex
        bne @m
        sta tmp2
        lda tmp
        sec
        sbc tmp2
        jmp @d
@none   lda #0
@d      cmp shown               ; (down only: a block's start can put the
        bcs @x                  ; progress back a hair)
        sta shown
        ldx #$ff                ; three digits (pdigit0: the font's 0)
        sec
@h      inx
        sbc #100
        bcs @h
        adc #100
        pha
        txa
        clc
        adc pdigit0
        ldy #0
        sta (cntp),y
        pla
        ldx #$ff
        sec
@tn     inx
        sbc #10
        bcs @tn
        adc #10                 ; (carry clear: the units, carry set)
        clc
        adc pdigit0
        ldy #2
        sta (cntp),y
        txa
        clc
        adc pdigit0
        dey
        sta (cntp),y
@x      rts

; ------------------------------------------------------------
; the kit's needs
; ------------------------------------------------------------
autopilot
        lda #$10                ; (nothing to play)
        rts
tx_loading
tx_loaded
tx_error
        byte 0

        incasm "modkit.asm"
        incasm "modinit.asm"
        incasm "fadekit.asm"
msgdata                         ; the message: the tools put theirs here
        incasm "message.asm"
modend
