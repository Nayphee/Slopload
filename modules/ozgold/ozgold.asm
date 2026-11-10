; ------------------------------------------------------------
; ozgold.asm  -  OZ GOLD: ALL AUSTRALIAN SOFTWARE. A loading screen in
; the style of U.S. Gold's Novaload one: the Australian flag in PETSCII,
; OZ GOLD in U.S. Gold's own letters, BLOCKS TO LOAD counting down, and
; a medley of Advance Australia Fair, Waltzing Matilda and Bound for
; Botany Bay. Not a game: nothing to play. Once the program is in,
; BLOCKS TO LOAD stays at 000 while the music fades out (about 2.6
; seconds; the kit's fadekit.asm), then the program starts.
;
; It keeps the loader's rules (MODULES.md) and uses the kit for the music
; (S turns it off and on). A tune chosen with the tool (-sid) plays in
; place of its own.
;
; The screen is the C64's own character set: the ROM font, which the
; VIC sees in banks 0 and 2 only. So the screen is at $bc00 in bank 2
; (a second part, loaded with the module), and $01 is the loader's
; (only the fade banks the I/O out, once the tape has stopped).
;
; Memory: $bc00-$bfe7 (the screen) and $e000 to modend (the tune, then
; the fade's code). Zero
; page $10-$24 (the tune: $70-$7f).
; Made from: mkscreen.py (screen.asm, colours.asm: the design) and
; mkdata.py (music.asm: the tune from music/build/ozgold.sid).
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
scr = $bc00                     ; the screen: vic bank 2, beside the rom font
scra = scr                      ; (the kit's names for it)
scrb = scr
d018v = $f4                     ; screen $3c00 into the bank, characters $1000 (the rom)

; ---- the standard parts ----
g_claim = modend                ; end of the memory claimed
g_jitter = 49                   ; measured: tests/jitter.py --module ozgold (pal 48, ntsc 49)
g_border = 1                    ; it leaves the border to the loader (gk_bord)
g_sfx = 0                       ; no sound effects: the music keeps all three voices
g_wait = 1                      ; with -wait it holds at 000 until SPACE (then the fade)
g_count = 0                     ; (no status line: its own counter, always)
g_share = 60                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; (the kit's status line: not used, the
gk_srow = 21*40                 ; counter is the status)

; ---- zero page ($10-$8f; $70-$7f is the tune's) ----
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
tmp = $1c                       ; scratch
tmp2 = $1d
tmp3 = $1e
pt2 = $1f                       ; (kit) 2
shown = $21                     ; the number of blocks on screen ($ff: none yet)
emode = $22                     ; 1: TAPE ERROR on screen
sbcell = $23                    ; (kit)
dbg_space = $8e                 ; debug: (no use here: the program starts by itself)
dbg_auto = $8f

; ---- characters (the rom's screen codes) ----
c_space = $20
c_digit0 = $30
c_bar = $20                     ; (the kit's bar: not used)
c_barl = $20
c_barr = $20
c_pct = $25

; ------------------------------------------------------------
; the second part: the screen, where the vic shows it
; ------------------------------------------------------------
*=$bc00
lowpart
        incasm "screen.asm"
lowend

*=$e000
mainpart
        incasm "modhead.asm"

; ------------------------------------------------------------
; init  once, the screen off: vic bank 2, the colours, the music
; ------------------------------------------------------------
init    jsr gk_musinit          ; the header's music (a tune the tool chose)
        lda hsong
        bpl @tune
        lda #<oz_init           ; none: OZ GOLD's own, song 1
        sta minit+1
        lda #>oz_init
        sta minit+2
        lda #<oz_play
        sta mplayr+1
        lda #>oz_play
        sta mplayr+2
        lda #2                  ; (a sid tune: every voice)
        sta mflags
        lda #1                  ; (it sets $d418 at its init only, filter
        sta fdirect             ; off: the fade writes the volume)
        lda #0
        sta hsong
@tune   lda #$0b
        sta $d011               ; (screen off: frame turns it on)
        ldx #$1f                ; zero page $10-$2f clear
        lda #0
@z      sta $10,x
        dex
        bpl @z
        sta $d015               ; no sprites
        jsr gk_bord             ; black border
        sta dbg_space
        sta dbg_auto
        lda #6
        sta $d021               ; blue
        sta ntscc
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        ora #1                  ; vic bank 2: $8000-$bfff, the rom font at $9000
        sta $dd00
        lda #d018v
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
        jsr show                ; the count, before the screen comes on
        jsr sidinit
        jmp musicgo

; ------------------------------------------------------------
; stop  silence; the core blanks the screen after. With -autorun the
; load has only just ended and the counter isn't at 000 yet: two frames
; more (no music), the second showing 000 whole
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
        lda #0
        sta musicon
@s      lda #0
        sta $d418
        lda shown
        beq @x
        jsr frame
        jsr frame
@x      rts

; ------------------------------------------------------------
; frame  one frame: the vertical blank (once a frame), the counter,
; one tick
;   out:  carry set when the program should start
; ------------------------------------------------------------
frame   jsr vbwait
@vb     lda #$1b                ; screen on, 25 rows
        sta $d011
        jsr show                ; (in the vertical blank: nothing tears)
        lda ld_state
        lsr a
        bcc @tick               ; pal: every frame
        dec ntscc
        bne @tick
        lda #6
        sta ntscc
        bne @held               ; ntsc: hold every sixth (the tune at pal speed)
@tick   jsr tick
@held   lda exitreq
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
        ldx #tx_waitend-tx_wait-1 ; PRESS SPACE on the tape error's row
@pw     lda tx_wait,x
        sta scr+o_errrow+14,x
        lda #1                  ; white
        sta $d800+o_errrow+14,x
        dex
        bpl @pw
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
; show  TAPE ERROR on row 21 (flashing) while the tape has one, and
; the blocks left to load in the counter's box
;   uses: a, x, tmp, tmp2
; ------------------------------------------------------------
show    bit ld_state
        bvc @clear              ; no tape error
        lda frm
        and #16
        beq @err                ; 16 ticks on, 16 off
@clear  lda emode
        beq @count
        lda #0
        sta emode
        ldx #39
        lda #c_space
@c      sta scr+o_errrow,x
        dex
        bpl @c
        bmi @count
@err    lda emode
        bne @count
        lda #1
        sta emode
        ldx #tx_errend-tx_err-1
@t      lda tx_err,x
        sta scr+o_errrow+2,x
        lda #1                  ; white
        sta $d800+o_errrow+2,x
        dex
        bpl @t
; the blocks left: the program's blocks less its share loaded
@count  lda ld_state
        bmi @none               ; loaded: 000
        lda hblocks
        bne @b
        lda #100                ; (no size in the header: 100 down, a percentage)
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
        ldx #c_digit0-1         ; three digits
        sec
@h      inx
        sbc #100
        bcs @h
        adc #100
        stx scr+o_digits
        ldx #c_digit0-1
        sec
@tn     inx
        sbc #10
        bcs @tn
        adc #10+c_digit0
        stx scr+o_digits+1
        sta scr+o_digits+2
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
tx_wait byte $10,$12,$05,$13,$13,$20,$13,$10,$01,$03,$05 ; PRESS SPACE (screen codes)
tx_waitend

        incasm "modkit.asm"
        incasm "modinit.asm"
        incasm "colours.asm"
        incasm "music.asm"      ; the tune, on its own page
        incasm "fadekit.asm"    ; (after it: no page to keep to)
modend
