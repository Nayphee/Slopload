; ------------------------------------------------------------
; template.asm  -  Template-Load: the smallest SlopLoad module
; that keeps the standard (MODULES.md). Copy modules/template to
; modules/<yours>, rename the files, and put your game where "hold
; fire as long as you can" is.
;
; What it shows: the header (modhead.asm); the shared kit
; (modkit.asm: the status line, SPACE, fire on port 2, S for the
; music); a frame that waits for the raster itself and runs one tick
; (5 in 6 frames on NTSC); the title, play and game over states with
; the standard start rules; the debug hooks. One screen, no scrolling:
; everything is drawn in the vertical blank, so nothing tears.
;
; Memory (vic bank 3): characters $e000-$e3ff (the header is
; characters 0-3), the screen $e400 (the character set's other half,
; never read as glyphs), code from $e800. Zero page $10-$2f.
; ------------------------------------------------------------
        incasm "abi.asm"

; ---- memory ----
scra = $e400                    ; one screen: the kit's two are the same
scrb = scra
d018v = $98                     ; screen $e400, characters $e000

; ---- the standard parts ----
g_claim = codeend               ; end of the memory claimed
g_jitter = 48                   ; measure: tests/jitter.py --module template
g_share = 35                    ; the most of the cpu (%) the loader may take
gk_barhalf = 0                  ; the status bar: 9 characters, 1 px a step
gk_srow = 24*40                 ; the status line: row 24

; ---- play ----
st_title = 0
st_play = 1
st_over = 2
lockout = 50                    ; ticks before game over takes fire
ballrow = 12

; ---- zero page ($10-$8f; $70-$7f is the music player's) ----
st = $10                        ; state
tmr = $11                       ; ticks in this state
frm = $12                       ; tick counter (kit)
ntscc = $13                     ; ntsc: 5 ticks in 6 frames
fire = $14                      ; (kit) $10 while held
fpress = $15                    ; (kit) $10: pressed this tick
spc = $16                       ; (kit) space held
skey = $17                      ; (kit) s held
exitreq = $18                   ; (kit) 1: start the program
smode = $19                     ; (kit) status line drawn: mode
sprog = $1a                     ; (kit) ... and progress
musicon = $1b                   ; (kit) 1: music playing
rnd = $1c                       ; (kit) 2 bytes
tmp = $1e                       ; (kit) scratch
tmp2 = $1f
tmp3 = $20
pt2 = $21                       ; (kit) 2
sbcell = $23                    ; (kit) the bar's last filled cell
pt = $24                        ; 2
scl = $26                       ; score, bcd
sch = $27
ballx = $28                     ; the ball's column
balld = $29                     ; ... and direction (1 or $ff)
sfxtime = $2a                   ; voice 3 effect: frames left
dbg_space = $8e                 ; debug: non-zero presses space once loaded
dbg_auto = $8f                  ; debug: non-zero plays by itself

*=$e000
        incasm "modhead.asm"
        incasm "chars.asm"

*=$e800

; ------------------------------------------------------------
; init  once, the screen off: set up, draw, start the music
; ------------------------------------------------------------
init    jsr gk_musinit          ; first: the header is characters 0-3
        lda #$0b
        sta $d011               ; (screen off: frame turns it on)
        ldx #$1f                ; zero page $10-$2f clear
        lda #0
@z      sta $10,x
        dex
        bpl @z
        sta $d015               ; no sprites
        sta $d020
        sta $d021
        sta dbg_space
        sta dbg_auto
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc                ; vic bank 3
        sta $dd00
        lda #d018v
        sta $d018
        lda #$08
        sta $d016               ; hi-res, 40 columns
        lda #6
        sta ntscc
        lda #$a7
        sta rnd
        sta rnd+1
        lda #$ff
        sta smode               ; (the status line: drawn at the first frame)
        ldx #0                  ; the screen blank, white
@c      lda #c_space
        sta scra,x
        sta scra+$100,x
        sta scra+$200,x
        sta scra+$2e8,x
        lda #1
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne @c
        ldx #<tx_title
        ldy #>tx_title
        lda #0
        jsr centre
        jsr drawscore
        jsr sidinit
        jsr musicgo
        jmp titlego

; ------------------------------------------------------------
; stop  silence; the core blanks the screen after
; ------------------------------------------------------------
stop    lda musicon
        beq @s
        jsr mstop
@s      lda #0
        sta $d418
        sta $d412
        rts

; ------------------------------------------------------------
; frame  one frame: the vertical blank, one tick, the status line
;   out:  carry set when the program should start
; ------------------------------------------------------------
frame
@w0     lda $d012               ; the last vertical blank over (line 0-250):
        cmp #251                ; the low byte first, then bit 8 (read the
        bcs @w0                 ; other way round, line 255 then 256 looks
        bit $d011               ; like line 0)
        bmi @w0
@w      bit $d011               ; then this one: line 251 on
        bmi @vb
        lda $d012
        cmp #251
        bcc @w
@vb     lda #$1b                ; screen on, 25 rows
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
; tick  one step of the game (in the vertical blank: it is short)
; ------------------------------------------------------------
tick    inc frm
        inc tmr
        bne @t
        dec tmr                 ; stays at 255
@t      jsr readfire
        jsr startkey
        jsr soundkey
        lda musicon
        beq @m
        jsr mplay               ; the music: once a tick
@m      lda sfxtime             ; the effect's gate off when it is done
        beq @s
        dec sfxtime
        bne @s
        lda #$20
        sta $d412
@s      lda st
        cmp #st_play
        beq t_play
        cmp #st_over
        beq t_over

; ---- title: once the program is in, a player who hasn't started gets
; it straight away; fire starts a round ----
t_title bit ld_state
        bpl @w
        lda #1
        sta exitreq
@w      lda fpress
        beq @x
        jmp playgo
@x      rts

; ---- playing: the ball runs while fire is held; let go and the
; round is over ----
t_play  lda fire
        beq @over
        lda tmr                 ; a point every 8 ticks
        and #7
        bne @b
        jsr addpoint
@b      jmp ball
@over   lda #st_over
        sta st
        lda #0
        sta tmr
        jsr sfx
        ldx #<tx_over
        ldy #>tx_over
        lda #10
        jmp centre

; ---- game over: once loaded, the program starts; before, after a
; lockout, fire plays again ----
t_over  bit ld_state
        bpl @nl
        lda #1
        sta exitreq
@nl     lda tmr
        cmp #lockout
        bcc @x
        lda fpress
        bne playgo
@x      rts

titlego lda #st_title
        sta st
        lda #0
        sta tmr
        ldx #<tx_start
        ldy #>tx_start
        lda #10
        jmp centre

playgo  lda #st_play
        sta st
        lda #0
        sta tmr
        sta scl
        sta sch
        lda #20
        sta ballx
        lda #1
        sta balld
        jsr drawscore
        jsr clearmsg
        jmp sfx

; ball  one column a tick, back and forth on row 12
ball    ldx ballx
        lda #c_space
        sta scra+ballrow*40,x
        txa
        clc
        adc balld
        cmp #4
        bcc @turn
        cmp #36
        bcc @ok
@turn   lda balld
        eor #$fe                ; 1 <-> $ff
        sta balld
        txa
@ok     sta ballx
        tax
        lda #c_ball
        sta scra+ballrow*40,x
        rts

; ------------------------------------------------------------
; the score: row 2, "SCORE nnn"
; ------------------------------------------------------------
addpoint
        inc scl                 ; bcd, without decimal mode (the loader's
        lda scl                 ; interrupt doesn't cld)
        and #15
        cmp #10
        bcc drawscore
        lda scl
        adc #5                  ; (carry set: + 6)
        sta scl
        cmp #$a0
        bcc drawscore
        lda #0
        sta scl
        inc sch
drawscore
        ldx #4
@t      lda tx_score+1,x
        sta scra+2*40+16,x
        dex
        bpl @t
        lda sch
        and #15
        clc
        adc #c_digit0
        sta scra+2*40+22
        lda scl
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #c_digit0
        sta scra+2*40+23
        lda scl
        and #15
        clc
        adc #c_digit0
        sta scra+2*40+24
        rts

; ------------------------------------------------------------
; centre  text x/y (length first) centred on row a (0-12)
; clearmsg  row 10 blank
; ------------------------------------------------------------
centre  stx pt2
        sty pt2+1
        tax
        lda rowlo,x
        sta pt
        lda rowhi,x
        sta pt+1
        jsr clearrow
        ldy #0
        lda (pt2),y
        sta tmp
        lda #40
        sec
        sbc tmp
        lsr a
        clc
        adc pt
        sta pt
        bcc @t
        inc pt+1
@t      ldy tmp                 ; from its last character back
@c      lda (pt2),y
        dey
        sta (pt),y
        cpy #0
        bne @c
        rts

clearmsg
        lda rowlo+10
        sta pt
        lda rowhi+10
        sta pt+1
clearrow
        ldy #39
        lda #c_space
@c      sta (pt),y
        dey
        bpl @c
        rts

rowlo   byte <scra,<scra+40,<scra+80,<scra+120,<scra+160,<scra+200,<scra+240
        byte <scra+280,<scra+320,<scra+360,<scra+400,<scra+440,<scra+480
rowhi   byte >scra,>scra+40,>scra+80,>scra+120,>scra+160,>scra+200,>scra+240
        byte >scra+280,>scra+320,>scra+360,>scra+400,>scra+440,>scra+480

; ------------------------------------------------------------
; sfx  a blip on voice 3 (only with the built-in player: a sid tune
; has every voice)
; ------------------------------------------------------------
sfx     lda mflags
        cmp #2
        beq @x
        lda #0
        sta $d412
        lda #$30
        sta $d40f
        lda #$09
        sta $d413
        lda #$21
        sta $d412
        lda #6
        sta sfxtime
@x      rts

; ------------------------------------------------------------
; autopilot  (debug) title, game over: press now and then; play: hold
; until the program is in, then let go (the round ends)
;   out:  a = 0 to press fire, $10 not
; ------------------------------------------------------------
autopilot
        lda st
        cmp #st_play
        bne @t
        bit ld_state
        bmi @no
        lda #0
        rts
@t      lda frm
        and #16
        rts
@no     lda #$10
        rts

        incasm "modkit.asm"
        incasm "tables.asm"
codeend
