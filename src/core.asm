; ------------------------------------------------------------
; core.asm  -  SlopLoad core, loaded by stage 1 to $0400
;
; An interrupt on every tape edge (cia1 FLAG) decodes the turbo
; blocks while the foreground runs a module. Each pulse is one
; of four lengths, (4 + 2k) quanta, carrying 2 bits. The quantum is
; measured on every block's pilot, so tape speed and pal/ntsc need
; no setting. Cia2 timer a ticks quanta and timer b counts them, so
; the interrupt reads the pulse class straight from timer b.
;
; Blocks:  pilot (class 0 pulses), sync (one class 3 pulse), then a
; 9-byte header, a pad byte, the data, and an xor check byte:
;   +0/1 load address   +2/3 length (lo, pages rounded up)
;   +4 xor key          +5 flags     +6 sequence number
;   +7 progress at block start      +8 header check
; (header check: $a5 xor all 9 bytes = 0). The pad byte is thrown
; away: the header's set-up may make its first edge late.
;
; Phases (foreground):
;   boot     border stripes, screen off, until a block flagged
;            gameready (or last, with no game)
;            (pt_strs, -showstripes: the stripes go on through the
;            game phase too, the border the loader's: ld_state bit 5
;            tells the game to leave it alone, and the interrupt shows
;            a tape error as a red border)
;   game     game_frame called in a loop; mainend stops the motor
;            and sets ld_state bit 7; the game returns carry set to
;            go on
;   final    screen off, stripes, motor on, until the last block
;   exit     KERNAL and BASIC set up again, then RUN or JMP
; ------------------------------------------------------------
        incasm "abi.asm"

stub = $0334                    ; exit code runs from the tape buffer

*=$0400
cstart  jmp cinit

; ---- patch area: written by the mastering tool ----
pt_game byte 0                  ; 1 = a module is on the tape
pt_auto byte 0                  ; 1 = start the program as soon as loaded
pt_init word 0                  ; game entry points
pt_frame word 0
pt_stop word 0
pt_step word 0                  ; progress per 256 bytes (8.8)
pt_strs byte 0                  ; $20 = the stripes on while the game runs too
; (the tool also patches the exit code's operands: x_vt1, x_vt2,
; x_run, x_port, x_irq and x_jmp)

; ------------------------------------------------------------
; irq  one tape edge
;   in:   cia1 FLAG
;   out:  pulse decoded; registers and flags as they were
;   note: ~70 cycles per pulse, ~115 when it completes a byte;
;         d is cleared for the progress sums (rti restores it)
; ------------------------------------------------------------
irq     sta ld_sa
        stx ld_sx
        lda #cia_ta_run
        ldx #cia_tb_count
        sta $dd0e               ; quantum timer back to phase 0
        lda $dd06               ; quanta left (11 - quanta)
        stx $dd0f               ; count again from 11
        tax                     ; (timer a must not run out between
        lda $dc0d               ; its restart and timer b's: 8 cycles)
;measure jsr mrec               ; (measuring build: timestamp the edge)
stripe  stx $d020               ; border stripes ($2c: bit, when off)
                                ; (no cld: games may not use decimal mode)
pmode   jmp pl_pilot            ; pl_pilot or pl_data

; ---- a data pulse: speed vote, then its bits ----
; Speed tracking (wow, drift): a pulse of nominal length sits on the
; boundary between two timer b counts, so each pulse votes "late"
; (on or past it, +4) or "early" (-4). Jitter votes both ways evenly;
; a tape running slow or fast tips the count, and when it passes +-128
; (a net 32 votes: the overflow flag) the quantum moves by a cycle.
; ld_pcount holds the count while a block is read. One entry per
; decoder, so a pulse costs no extra jump.
pl_dib  lda ld_pcount
        clc
pvote1  = *
        adc ptab4,x             ; (the table for this block's pulse set)
        sta ld_pcount
        bvc pd_dibit
        bmi @late               ;-measure (overflow flips the sign)
        dec ld_cal              ;-measure pulses shorter than we think
        bne @set                ;-measure (always)
@late   inc ld_cal              ;-measure longer
@set    lda ld_cal              ;-measure
        sta $dd04               ;-measure from the next edge on
        lda #0                  ;-measure
        sta ld_pcount           ;-measure
        clv                     ; (b_data tests v: clear on every way in)

; ---- 2 bits a pulse (headers, and blocks of data that suit it) ----
pd_dibit
        lda ld_sr
        asl a
        asl a
dclass  = *
        ora ctab4,x             ; class = the 2 bits
        bcs pd_done
        sta ld_sr
irqx    lda ld_sa
        ldx ld_sx
nmi     rti
pd_done ldx #1
        stx ld_sr               ; next byte's marker
        jmp (bvec)              ; b_head, b_pad, b_data or b_check

pl_pfx  lda ld_pcount
        clc
pvote2  = *
        adc ptab4,x
        sta ld_pcount
        bvc pd_pfx
        bmi @late               ;-measure
        dec ld_cal              ;-measure
        bne @set                ;-measure
@late   inc ld_cal              ;-measure
@set    lda ld_cal              ;-measure
        sta $dd04               ;-measure
        lda #0                  ;-measure
        sta ld_pcount           ;-measure
        clv                     ; (b_data tests v: clear on every way in)
; ---- prefix code: class 0 = 1, 1 = 01, 2 = 001, 3 = 000 ----
; ld_sr holds the bits so far over a marker bit; the bit that
; pushes the marker out completes the byte, and the bits of the
; pulse still to come start the next byte (marker plus bits).
pd_pfx
pclass  = *
        lda ctab4,x             ; class 0-3
        beq @c0
        cmp #2
        bcc @c1
        beq @c2
        asl ld_sr               ; 3: 0 0 0
        bcs pf00
        asl ld_sr
        bcs @f0
        asl ld_sr
        bcs @fn
        jmp irqx
@c2     asl ld_sr               ; 2: 0 0 1
        bcs pf01
        asl ld_sr
        bcs @f1
@c0     sec                     ; 0: 1
        rol ld_sr
        bcs @fn
        jmp irqx
@c1     asl ld_sr               ; 1: 0 1
        bcs @f1
        sec
        rol ld_sr
        bcs @fn
        jmp irqx
@fn     ldx #%1                 ; byte complete; then nothing left,
        bne @fx
@f1     ldx #%11                ; "1",
        bne @fx
@f0     ldx #%10                ; or "0" left over
@fx     lda ld_sr               ; the byte
        stx ld_sr
        jmp (bvec)
pf00    lda ld_sr               ; (the two slowest classes' first bit
        ldx #%100               ; completing the byte: direct)
        stx ld_sr               ; "00" left
        jmp (bvec)
pf01    lda ld_sr
        ldx #%101               ; "01" left
        stx ld_sr
        jmp (bvec)

; ---- pilot: count class 0 pulses, measure, wait for the sync ----
pl_pilot
        cpx #7
        bcc @nc0
        cpx #tb_start
        bcs plreset             ; gap or glitch
        inc ld_pcount
        lda ld_pcount
        cmp #cal_start
        beq @go
        cmp #cal_start+cal_len
        bne @x
        lda $dc07               ; 64 pulses of 4h = 256h cycles; counting
        eor #$ff                ; from $ff7f, the high byte is h rounded
        sbc #1                  ; (c set: equal) latch h-1: a period of h
        sta $dd04
        sta ld_cal
        lda #cal_start          ; and measure the next 64: a "pilot" found
        sta ld_pcount           ; in a block's data is measured again on
@go     lda #cia_ta_run         ; the real one
        sta $dc0f               ; stopwatch from $ff7f
@x      jmp irqx
@nc0    cpx #3
        bcs plreset             ; class 1 or 2: noise
        lda ld_cal
        beq plreset             ; class 3 before the measurement
        lda #<pl_dib            ; sync: the header follows, 2 bits a
        sta pmode+1             ; pulse in the (4 + 2k)h pulse set
        lda #>pl_dib
        sta pmode+2
        ldx #2
        jsr setm
        lda #<b_head
        sta bvec
        lda #>b_head
        sta bvec+1
        lda #0
        sta hidx
        sta ld_pcount           ; speed tracking count: 0
        lda #$a5
        sta hchk
        lda #1
        sta ld_sr
        jmp irqx

; ---- back to looking for a pilot ----
plreset lda #<pl_pilot
        sta pmode+1
        lda #>pl_pilot
        sta pmode+2
        lda #0
        sta ld_pcount
        sta ld_cal
        lda #h_def-1
        sta $dd04
        jmp irqx

; setm  the class and vote tables for pulse set m = x + 2 (their low
; bytes: neither table crosses a page, tools/build.py checks)
;   uses: a
setm    txa
        clc
        adc #<cbase
        sta dclass+1
        sta pclass+1
        txa
        adc #<pbase             ; (no carry: the table's page)
        sta pvote1+1
        sta pvote2+1
        rts

; ---- header byte ----
b_head  ldx hidx
        sta hbuf,x
        eor hchk
        sta hchk
        inx
        stx hidx
        cpx #9
        bcs @full
        lda ld_sa
        ldx ld_sx
        rti
@full   lda hchk
        bne plreset             ; bad header: ignore the block
        lda hbuf+6
        cmp ld_seq
        beq @ok
        bcc plreset             ; a block already loaded: skip it
        lda ld_state            ; a later one: one was missed
        ora #$40
        jmp bst
@ok     lda hbuf
        sta bdst+1
        lda hbuf+1
        sta bdst+2
        lda hbuf+2
        sta ld_cnt
        lda hbuf+3
        sta ld_cnt+1
        lda hbuf+4
        sta ld_key
        lda hbuf+7
        sta ld_progress
        lda hbuf+1
        sta ld_pages            ; the page the block starts in
        lda #0
        sta pfrac
        sta ld_chk
        lda hbuf+5              ; flags bits 4-5: pulse set m - 2,
        lsr a                   ; bit 6: prefix code
        lsr a
        lsr a
        lsr a
        and #3
        tax
        jsr setm
        bit hbuf+5
        bvc @d
        lda #<pl_pfx
        sta pmode+1
        lda #>pl_pfx
        sta pmode+2
@d      lda hbuf+5
        and #$08                ; the block touches $d000-$dfff: bank,
        beq @fast
        lda #$a2                ; ldx #port_ram, ldx #port_io
        ldx #port_ram
        bne @put                ; (always)
@fast   lda #$50                ; else bvc +2: skip each stx $01
        ldx #2
@put    sta bbank1
        sta bbank2
        stx bbank1+1
        cpx #port_ram
        bne @s
        inx                     ; port_io
@s      stx bbank2+1
        lda #<b_pad
        sta bvec
        lda #>b_pad
        sta bvec+1
        jmp irqx

; ---- the pad byte after the header: the set-up above may still be
; running at its first edge, so its pulses are thrown away ----
b_pad   lda #<b_data
        sta bvec
        lda #>b_data
        sta bvec+1
        jmp irqx

; ---- data byte ----
b_data  eor ld_key
bbank1  = *                     ; (bvc +2 when the block is clear of i/o:
        ldx #port_ram           ; v is clear here, so it skips the stx)
        stx $01                 ; store into ram, under i/o too
bdst    = *
        sta $ffff
bbank2  = *
        ldx #port_io
        stx $01
        eor ld_chk
        sta ld_chk
        inc bdst+1
        bne @np
        inc bdst+2              ; (the game loop sees it: progress)
cycle   = *                     ; -cycle: inc $d020 here (the tool's), the border
        bne @np                 ; a colour on each page stored; off, a branch
        byte $d0                ; past this byte (3 cycles: the worst path fits)
@np     dec ld_cnt
        bne @x
        dec ld_cnt+1
        bne @x
        lda #<b_check
        sta bvec
        lda #>b_check
        sta bvec+1
@x      lda ld_sa
        ldx ld_sx
        rti

; ---- check byte ----
b_check cmp ld_chk
        bne @bad
        inc ld_seq
        lda hbuf+5
        ora ld_ev
        sta ld_ev
        lda ld_state
        and #$bf                ; a good block clears an error
        jmp bst
@bad    lda ld_state
        ora #$40
bst     sta ld_state            ; the border the loader's (strph): a tape
        lda strph               ; error shown, or its end
        beq @p
        jsr errshow
@p      jmp plreset

; timer b value (11 - quanta) -> class, for pulse sets m = 2, 3, 4:
; class k is (m + 2k)h long, read for (m + 2k - 1)h to (m + 2k + 1)h.
; The three tables are this one from offset m - 2.
pfrac   byte 0                  ; progress fraction
strph   byte 1                  ; not 0: the border the loader's (the boot and
                                ; final phases; the game's with -showstripes)
bvec    word b_head             ; where a completed byte goes
cbase   byte 3,3,3,3,3,2,2,1,1,0,0,0,0,0
; ... and the speed vote: +4 on or past a class's nominal length, -4
; short (the same way; 11, a glitch or gap, votes 0 or -4)
pbase   byte 4,4,4,4,$fc,4,$fc,4,$fc,4,$fc,$fc,$fc,0
ctab4 = cbase+2
ptab4 = pbase+2

hidx    byte 0
hchk    byte 0
hbuf    byte 0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; cinit  set up the interrupt loader and run the phases
;   in:   from stage 1, interrupts off, screen off, motor on
; ------------------------------------------------------------
cinit   sei
        cld
        ldx #$ff
        txs
        lda pt_strs             ; (bit 5: -showstripes, the border the
        sta ld_state            ; loader's all through)
        lda #0
        sta ld_progress
        sta ld_ev
        sta ld_seq
        sta ld_pcount           ; (pmode is pl_pilot as assembled)
        sta ld_cal
        sta $d01a               ; no vic interrupts

; pal or ntsc: a step to the next line leaves a negative difference;
; only the wrap to line 0 leaves a positive one
@r0     lda $d012
@r1     cmp $d012
        beq @r1
        bmi @r0
        cmp #$20                ; last line's low byte: $37 pal, $06/$05 ntsc
        bcs @pal
        inc ld_state            ; bit 0: ntsc
@pal    lda pt_auto
        beq @na
        lda ld_state
        ora #2
        sta ld_state
@na     lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #h_def-1
        sta $dd04
        lda #$7f                ; the stopwatch counts from $ff7f: the
        sta $dc06               ; high byte of 256h is then h rounded
        lda #$90
        sta $dc0d               ; cia1 FLAG interrupt on
        lda $dc0d
        lda #port_io
        sta $01                 ; roms out, motor on
        cli

; ---- boot phase: stripes until the game is in ----
        lda pt_game
        beq final
@w0     lda ld_ev
        and #f_gameready+f_last
        beq @w0
        lda pt_strs             ; the border: the game's, or (-showstripes)
        sta strph               ; the loader's stripes on through it
        bne @ks
        jsr stroff
        lda #0
        sta $d020
@ks     lda bdst+2              ; the game's own blocks move no progress:
        sta ld_pages            ; the game loop counts pages from here
        jsr g_init

; ---- game phase ----
@gl     lda bdst+2              ; the store moved to a new page: the
        cmp ld_pages            ; progress moves on (kept out of the
        beq @gf                 ; interrupt, whose longest path must
        inc ld_pages            ; fit in the shortest pulse)
        lda pfrac
        clc
        adc pt_step
        sta pfrac
        lda ld_progress
        adc pt_step+1
        bcc @p
        lda #$ff
@p      sta ld_progress
@gf     jsr g_frame
        bcc @cont
        bit ld_state            ; carry set counts once loaded
        bmi gend
@cont   bit ld_state
        bmi @gl                 ; already noted
        lda ld_ev
        and #f_mainend+f_last
        beq @gl
        lda #$ff
        sta ld_progress
        lda #port_off           ; stop the tape: the irq is looking
        sta $01                 ; for a pilot, so it won't store
        lda ld_state
        ora #$80
        sta ld_state
        lda pt_auto
        beq @gl
gend    jsr g_stop
        lda #$0b
        sta $d011
        lda #0
        sta $d015
        sta $d418

; ---- final phase: what the game was using, then the end ----
final   lda #port_io
        sta $01                 ; motor on
        sta strph               ; (the border the loader's again)
fstr    lda #$8e
        sta stripe              ; stx: stripes on
@w2     lda ld_ev
        bpl @w2                 ; f_last is bit 7
        jmp exit

; ------------------------------------------------------------
; errshow  at each block's end, from the interrupt, while the border is
;          the loader's (strph): a tape error as a red border, the
;          stripes off; after a good block, on
;   uses: a
; ------------------------------------------------------------
errshow bit ld_state
        bvc @ok
        jsr stroff
        lda #2
        sta $d020
        rts
@ok     lda #$8e                ; stx $d020
        sta stripe
        rts
ersend                          ; (core_flat: errshow to here, rewritten)

; stripes off
stroff  lda #$2c                ; bit $d020
        sta stripe
        rts

g_init  jmp (pt_init)
g_frame jmp (pt_frame)
g_stop  jmp (pt_stop)

; ------------------------------------------------------------
; exit  stop the loader, put the machine back, start the program
; ------------------------------------------------------------
exit    sei                     ; (ioinit in the stub turns the cias off)
        ldx #xstubend-xstub-1
@c      lda xstub,x
        sta stub,x
        dex
        bpl @c
        jmp stub

; position independent: copied to the tape buffer, as CINT clears
; the screen this core lives in
xstub   lda #$37
        sta $01
        ldx #$fb
        txs
        jsr s1ioi               ; ioinit, then the RESTORE lock off (stage 1's)
        ldx #$1f                ; the KERNAL vectors, by hand: RESTOR
x_vec   lda $fd30,x             ; also writes its table back onto
        sta $0314,x             ; itself, into the ram under the
        dex                     ; KERNAL at $fd30-$fd4f
        bpl x_vec
        jsr $ff81               ; cint
        jsr $e453               ; BASIC vectors
        jsr $e3bf               ; BASIC zero page
        lda #0
        sta $c6                 ; empty the keyboard buffer
x_vt1   lda #$01                ; end of the program (the tool sets it)
        sta $2d
x_vt2   lda #$08
        sta $2e
x_run   lda #1                  ; 1: RUN, 0: jmp x_jmp (the tool)
        beq x_port
        cli
        jsr $a659               ; CLR, text pointer to the start
        jmp $a7ae               ; RUN
x_port  lda #$37                ; $01 for the jump (the tool)
        sta $01
x_irq   cli                     ; or sei (the tool)
x_jmp   jmp $0000
xstubend

; ------------------------------------------------------------
; mrec  measuring build only (tools/build.py enables the lines
; starting ";measure"): the time between this edge and the last,
; low byte, from cia1 timer b, into a buffer at $4000-$bfff.
; tests/jitter.py compares it with the pulses on the tape.
;   uses: a
; ------------------------------------------------------------
;measuremrec    lda $dc06               ; stopwatch, counting down
;measure        sta mnow
;measure        lda mprev
;measure        sec
;measure        sbc mnow                ; previous - now
;measuremptr    sta $4000
;measure        lda mnow
;measure        sta mprev
;measure        inc mptr+1
;measure        bne @x
;measure        inc mptr+2
;measure        lda mptr+2
;measure        cmp #$c0
;measure        bne @x
;measure        lda #$40
;measure        sta mptr+2
;measure@x      rts
;measuremnow    byte 0
;measuremprev   byte 0
